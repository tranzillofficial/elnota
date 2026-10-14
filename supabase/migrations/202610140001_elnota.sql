-- Dedicated ElNota project. Never apply this migration to an existing application's database.
create schema if not exists elnota_private;
revoke all on schema elnota_private from public, anon, authenticated;
create table public.elnota_accounts (
 user_id uuid primary key references auth.users(id) on delete cascade,
 email text not null, business_name text not null default '',
 activated_at timestamptz, cloud_until timestamptz,
 created_at timestamptz not null default now()
);
create table elnota_private.admin_emails (email text primary key);
-- Seed administrator identities privately after deployment, never in public source.
create function elnota_private.is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.users u join elnota_private.admin_emails a on lower(u.email)=a.email where u.id=(select auth.uid()) and u.email_confirmed_at is not null);
$$;
revoke all on function elnota_private.is_admin() from public;
grant usage on schema elnota_private to authenticated;
grant execute on function elnota_private.is_admin() to authenticated;
create table public.elnota_requests (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.elnota_accounts(user_id),
 plan text not null check(plan in ('basic','cloud_month','cloud_year')),
 amount integer generated always as (case plan when 'basic' then 1000 when 'cloud_month' then 50 else 500 end) stored,
 phone text not null check(length(phone) between 7 and 30), reference text not null check(length(reference) between 3 and 500),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 created_at timestamptz not null default now(), reviewed_at timestamptz, reviewed_by uuid references auth.users(id)
);
create unique index elnota_one_pending_plan on public.elnota_requests(user_id,plan) where status='pending';
create index elnota_request_created on public.elnota_requests(created_at desc);
create table public.elnota_cloud (
 user_id uuid primary key references public.elnota_accounts(user_id) on delete cascade,
 data jsonb not null, revision bigint not null default 1, updated_at timestamptz not null default now(),
 check(octet_length(data::text)<=10485760)
);
create table public.elnota_backups (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.elnota_accounts(user_id) on delete cascade,
 data jsonb not null, revision bigint not null, created_at timestamptz not null default now(),
 check(octet_length(data::text)<=10485760)
);
create index elnota_backups_owner on public.elnota_backups(user_id,created_at desc);
alter table public.elnota_accounts enable row level security;
alter table public.elnota_requests enable row level security;
alter table public.elnota_cloud enable row level security;
alter table public.elnota_backups enable row level security;
alter table elnota_private.admin_emails enable row level security;
create policy accounts_read on public.elnota_accounts for select to authenticated using(user_id=(select auth.uid()) or (select elnota_private.is_admin()));
create policy requests_read on public.elnota_requests for select to authenticated using(user_id=(select auth.uid()) or (select elnota_private.is_admin()));
create policy requests_insert on public.elnota_requests for insert to authenticated with check(user_id=(select auth.uid()) and status='pending' and reviewed_at is null and reviewed_by is null);
create policy cloud_read on public.elnota_cloud for select to authenticated using(user_id=(select auth.uid()));
create policy backups_read on public.elnota_backups for select to authenticated using(user_id=(select auth.uid()));
revoke all on public.elnota_accounts,public.elnota_requests,public.elnota_cloud,public.elnota_backups from anon,authenticated;
grant select on public.elnota_accounts,public.elnota_requests,public.elnota_cloud,public.elnota_backups to authenticated;
grant insert(user_id,plan,phone,reference) on public.elnota_requests to authenticated;
-- Privileged mutations are limited to functions with an explicit verified identity and entitlement check.
create function public.elnota_register(business text) returns public.elnota_accounts language plpgsql security definer set search_path='' as $$
declare account public.elnota_accounts; uid uuid := (select auth.uid());
begin
 if uid is null or not exists(select 1 from auth.users where id=uid and email_confirmed_at is not null) then raise exception 'AUTH_REQUIRED';end if;
 if length(business)>150 then raise exception 'INVALID_BUSINESS';end if;
 insert into public.elnota_accounts(user_id,email,business_name) select id,email,business from auth.users where id=uid on conflict(user_id) do nothing;
 select * into account from public.elnota_accounts where user_id=uid;return account;
end;$$;
create function public.elnota_is_admin() returns boolean language sql security invoker set search_path='' as $$select elnota_private.is_admin();$$;
create function public.elnota_review(request_id uuid,approve boolean) returns void language plpgsql security definer set search_path='' as $$
declare req public.elnota_requests;begin
 if not elnota_private.is_admin() then raise exception 'ADMIN_REQUIRED';end if;
 select * into req from public.elnota_requests where id=request_id for update;
 if req.id is null or req.status<>'pending' then raise exception 'INVALID_REQUEST';end if;
 if approve then
  if req.plan='basic' then update public.elnota_accounts set activated_at=coalesce(activated_at,now()) where user_id=req.user_id;
  else
   if not exists(select 1 from public.elnota_accounts where user_id=req.user_id and activated_at is not null) then raise exception 'ACTIVATE_BASIC_FIRST';end if;
   update public.elnota_accounts set cloud_until=greatest(coalesce(cloud_until,now()),now())+case req.plan when 'cloud_month' then interval '1 month' else interval '1 year' end where user_id=req.user_id;
  end if;
 end if;
 update public.elnota_requests set status=case when approve then 'approved' else 'rejected' end,reviewed_at=now(),reviewed_by=auth.uid() where id=request_id;
end;$$;
-- Compare-and-swap protects data from stale-device overwrites. Three previous snapshots retained.
create function public.elnota_sync(payload jsonb,expected_revision bigint) returns bigint language plpgsql security definer set search_path='' as $$
declare uid uuid := auth.uid(); current_row public.elnota_cloud; next_revision bigint;
begin
 if uid is null then raise exception 'AUTH_REQUIRED';end if;
 perform 1 from public.elnota_accounts where user_id=uid and activated_at is not null and cloud_until>now() for update;
 if not found then raise exception 'CLOUD_SUBSCRIPTION_REQUIRED';end if;
 if jsonb_typeof(payload)<>'object' or payload->>'schemaVersion'<>'1' or jsonb_typeof(payload->'customers') is distinct from 'array' or jsonb_typeof(payload->'invoices') is distinct from 'array' or jsonb_typeof(payload->'products') is distinct from 'array' then raise exception 'INVALID_BACKUP';end if;
 if octet_length(payload::text)>10485760 then raise exception 'CLOUD_LIMIT_10MB';end if;
 select * into current_row from public.elnota_cloud where user_id=uid for update;
 if coalesce(current_row.revision,0)<>expected_revision then raise exception 'SYNC_CONFLICT';end if;
 next_revision := coalesce(current_row.revision,0)+1;
 if current_row.user_id is not null then
  insert into public.elnota_backups(user_id,data,revision) values(uid,current_row.data,current_row.revision);
  delete from public.elnota_backups where user_id=uid and id not in(select id from public.elnota_backups where user_id=uid order by created_at desc,id desc limit 3);
 end if;
 insert into public.elnota_cloud(user_id,data,revision) values(uid,payload,next_revision) on conflict(user_id) do update set data=excluded.data,revision=excluded.revision,updated_at=now();
 return next_revision;
end;$$;
revoke all on function public.elnota_register(text),public.elnota_is_admin(),public.elnota_review(uuid,boolean),public.elnota_sync(jsonb,bigint) from public,anon;
grant execute on function public.elnota_register(text),public.elnota_is_admin(),public.elnota_review(uuid,boolean),public.elnota_sync(jsonb,bigint) to authenticated;
