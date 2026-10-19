begin;
alter table public.elnota_accounts add column if not exists suspended_at timestamptz,add column if not exists deleted_at timestamptz,add column if not exists suspended_activation_at timestamptz,add column if not exists suspended_cloud_until timestamptz,add column if not exists suspended_printing boolean;
alter table public.elnota_requests add column if not exists submitted_email text,add column if not exists submitted_business_name text;
-- Historical requests retain their actual sender association; never infer it from payment notes.
update public.elnota_requests r set submitted_email=u.email,submitted_business_name=a.business_name from public.elnota_accounts a join auth.users u on u.id=a.user_id where a.user_id=r.user_id and r.submitted_email is null;
create table if not exists elnota_private.account_actions(id uuid primary key default gen_random_uuid(),actor_id uuid not null,target_user uuid not null,action text not null,created_at timestamptz not null default now());
alter table elnota_private.account_actions enable row level security;
revoke all on elnota_private.account_actions from public,anon,authenticated;
create or replace function elnota_private.manage_account(target_user uuid,operation text) returns void language plpgsql security definer set search_path='' as $$
declare a public.elnota_accounts;
begin
 if auth.uid() is null or not elnota_private.is_admin() then raise exception 'ADMIN_REQUIRED';end if;
 if target_user=auth.uid() or exists(select 1 from auth.users u join elnota_private.admin_emails e on e.email=lower(u.email) where u.id=target_user) then raise exception 'ADMIN_ACCOUNT_PROTECTED';end if;
 select * into a from public.elnota_accounts where user_id=target_user for update;
 if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 if operation='suspend' then
 if a.deleted_at is not null then raise exception 'ACCOUNT_DELETED';end if;
 if a.suspended_at is not null then return;end if;
 update public.elnota_accounts set suspended_activation_at=activated_at,suspended_cloud_until=cloud_until,suspended_printing=printing_enabled,suspended_at=now(),activated_at=null,cloud_until=null,printing_enabled=false where user_id=target_user;
 elsif operation='resume' then
 if a.deleted_at is not null then raise exception 'RESTORE_ACCOUNT_FIRST';end if;
 if a.suspended_at is null then return;end if;
 update public.elnota_accounts set activated_at=suspended_activation_at,cloud_until=suspended_cloud_until,printing_enabled=coalesce(suspended_printing,false),suspended_at=null,suspended_activation_at=null,suspended_cloud_until=null,suspended_printing=null where user_id=target_user;
 elsif operation='delete' then
 if a.deleted_at is not null then return;end if;
 update public.elnota_accounts set suspended_activation_at=coalesce(suspended_activation_at,activated_at),suspended_cloud_until=coalesce(suspended_cloud_until,cloud_until),suspended_printing=coalesce(suspended_printing,printing_enabled),suspended_at=coalesce(suspended_at,now()),deleted_at=now(),activated_at=null,cloud_until=null,printing_enabled=false where user_id=target_user;
 update public.elnota_requests set status='rejected',reviewed_at=now(),reviewed_by=auth.uid() where user_id=target_user and status='pending';
 elsif operation='restore' then
 if a.deleted_at is null then return;end if;
 update public.elnota_accounts set deleted_at=null where user_id=target_user;
 else raise exception 'INVALID_OPERATION';end if;
 insert into elnota_private.account_actions(actor_id,target_user,action) values(auth.uid(),target_user,operation);
end;$$;
create or replace function public.elnota_manage_account(target_user uuid,operation text) returns void language sql security invoker set search_path='' as $$select elnota_private.manage_account(target_user,operation);$$;
revoke all on function public.elnota_manage_account(uuid,text),elnota_private.manage_account(uuid,text) from public,anon,authenticated;
grant execute on function public.elnota_manage_account(uuid,text),elnota_private.manage_account(uuid,text) to authenticated;
-- All existing activation/printing/cloud paths must respect a suspended or deleted account.
create or replace function elnota_private.guard_account_state() returns trigger language plpgsql set search_path='' as $$
begin
 if (new.suspended_at is not null or new.deleted_at is not null) and (new.activated_at is not null or new.cloud_until is not null or coalesce(new.printing_enabled,false)) then raise exception 'ACCOUNT_SUSPENDED_OR_DELETED';end if;
 return new;
end;$$;
revoke all on function elnota_private.guard_account_state() from public,anon,authenticated;
drop trigger if exists guard_account_state on public.elnota_accounts;
create trigger guard_account_state before insert or update on public.elnota_accounts for each row execute function elnota_private.guard_account_state();
create or replace function elnota_private.stamp_activation_sender() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or new.user_id is distinct from auth.uid() then raise exception 'AUTH_REQUIRED';end if;
 if exists(select 1 from public.elnota_accounts where user_id=auth.uid() and (suspended_at is not null or deleted_at is not null)) then raise exception 'ACCOUNT_SUSPENDED_OR_DELETED';end if;
 select u.email,a.business_name into new.submitted_email,new.submitted_business_name from auth.users u join public.elnota_accounts a on a.user_id=u.id where u.id=auth.uid() and u.email_confirmed_at is not null;
 if not found then raise exception 'AUTH_REQUIRED';end if;
 return new;
end;$$;
revoke all on function elnota_private.stamp_activation_sender() from public,anon,authenticated;
drop trigger if exists stamp_activation_sender on public.elnota_requests;
create trigger stamp_activation_sender before insert on public.elnota_requests for each row execute function elnota_private.stamp_activation_sender();
commit;
