alter table public.elnota_accounts add column if not exists cloud_plan text check (cloud_plan in ('month','year'));
create table public.elnota_daily_backups (
 user_id uuid primary key references public.elnota_accounts(user_id) on delete cascade,
 data jsonb not null check(octet_length(data::text)<=10485760),
 revision bigint not null,
 updated_at timestamptz not null default now()
);
alter table public.elnota_daily_backups enable row level security;
revoke all on public.elnota_daily_backups from anon,authenticated;
grant select on public.elnota_daily_backups to authenticated;
create policy daily_read on public.elnota_daily_backups for select to authenticated using(user_id=(select auth.uid()) or (select elnota_private.is_admin()));
create policy cloud_admin_read on public.elnota_cloud for select to authenticated using((select elnota_private.is_admin()));
create function public.elnota_manage_cloud(target_user uuid, plan text) returns timestamptz language plpgsql security definer set search_path='' as $$
declare expiry timestamptz;
begin
 if (select auth.uid()) is null or not elnota_private.is_admin() then raise exception 'ADMIN_REQUIRED';end if;
 if plan is null or plan not in ('month','year','stop') then raise exception 'INVALID_PLAN';end if;
 if plan='stop' then update public.elnota_accounts set cloud_until=now() where user_id=target_user returning cloud_until into expiry;
 else
 update public.elnota_accounts set cloud_plan=plan,cloud_until=greatest(coalesce(cloud_until,now()),now())+case plan when 'month' then interval '1 month' else interval '1 year' end
 where user_id=target_user and activated_at is not null returning cloud_until into expiry;
 end if;
 if not found then raise exception 'ACCOUNT_NOT_FOUND_OR_INACTIVE';end if;
 return expiry;
end;$$;
create function public.elnota_daily_snapshot() returns timestamptz language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); source public.elnota_cloud; saved_at timestamptz;
begin
 if uid is null then raise exception 'AUTH_REQUIRED';end if;
 perform 1 from public.elnota_accounts where user_id=uid and activated_at is not null and cloud_until>now() for update;
 if not found then raise exception 'CLOUD_SUBSCRIPTION_REQUIRED';end if;
 select updated_at into saved_at from public.elnota_daily_backups where user_id=uid;
 if saved_at>now()-interval '24 hours' then return saved_at;end if;
 select * into source from public.elnota_cloud where user_id=uid for update;
 if not found then raise exception 'SYNC_REQUIRED';end if;
 insert into public.elnota_daily_backups(user_id,data,revision,updated_at) values(uid,source.data,source.revision,now())
 on conflict(user_id) do update set data=excluded.data,revision=excluded.revision,updated_at=excluded.updated_at;
 return now();
end;$$;
create function public.elnota_restore_daily(target_user uuid, expected_revision bigint) returns bigint language plpgsql security definer set search_path='' as $$
declare source public.elnota_daily_backups; previous public.elnota_cloud; next_rev bigint;
begin
 if (select auth.uid()) is null or not elnota_private.is_admin() then raise exception 'ADMIN_REQUIRED';end if;
 perform 1 from public.elnota_accounts where user_id=target_user for update;
 if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 select * into source from public.elnota_daily_backups where user_id=target_user;
 if not found then raise exception 'BACKUP_NOT_FOUND';end if;
 select * into previous from public.elnota_cloud where user_id=target_user for update;
 if coalesce(previous.revision,0)<>expected_revision then raise exception 'SYNC_CONFLICT';end if;
 next_rev:=coalesce(previous.revision,0)+1;
 if previous.user_id is not null then
 insert into public.elnota_backups(user_id,data,revision) values(target_user,previous.data,previous.revision);
 delete from public.elnota_backups where user_id=target_user and id not in(select id from public.elnota_backups where user_id=target_user order by created_at desc,id desc limit 3);
 end if;
 insert into public.elnota_cloud(user_id,data,revision) values(target_user,source.data,next_rev) on conflict(user_id) do update set data=excluded.data,revision=excluded.revision,updated_at=now();
 return next_rev;
end;$$;
revoke all on function public.elnota_manage_cloud(uuid,text),public.elnota_daily_snapshot(),public.elnota_restore_daily(uuid,bigint) from public,anon,authenticated;
grant execute on function public.elnota_manage_cloud(uuid,text),public.elnota_daily_snapshot(),public.elnota_restore_daily(uuid,bigint) to authenticated;
create or replace function public.elnota_review(request_id uuid,approve boolean) returns void language plpgsql security definer set search_path='' as $$
declare req public.elnota_requests;begin
 if not elnota_private.is_admin() then raise exception 'ADMIN_REQUIRED';end if;
 select * into req from public.elnota_requests where id=request_id for update;
 if req.id is null or req.status<>'pending' then raise exception 'INVALID_REQUEST';end if;
 if approve then
  if req.plan='basic' then update public.elnota_accounts set activated_at=coalesce(activated_at,now()) where user_id=req.user_id;
  else
   if not exists(select 1 from public.elnota_accounts where user_id=req.user_id and activated_at is not null) then raise exception 'ACTIVATE_BASIC_FIRST';end if;
   update public.elnota_accounts set cloud_plan=case req.plan when 'cloud_month' then 'month' else 'year' end,cloud_until=greatest(coalesce(cloud_until,now()),now())+case req.plan when 'cloud_month' then interval '1 month' else interval '1 year' end where user_id=req.user_id;
  end if;
 end if;
 update public.elnota_requests set status=case when approve then 'approved' else 'rejected' end,reviewed_at=now(),reviewed_by=auth.uid() where id=request_id;
end;$$;
