-- STAGING ONLY. Additive namespace; never overwrites elnota_cloud or legacy backups.
create table public.elnota_feature_access (
  user_id uuid primary key references auth.users(id),
  catalog_enabled boolean not null default false,
  changed_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now()
);
alter table public.elnota_feature_access enable row level security;
revoke all on public.elnota_feature_access from anon, authenticated;
grant select, insert, update on public.elnota_feature_access to authenticated;
create policy feature_read on public.elnota_feature_access for select to authenticated using (user_id=(select auth.uid()) or (select public.elnota_is_admin()));
create policy feature_insert_admin on public.elnota_feature_access for insert to authenticated with check ((select public.elnota_is_admin()) and changed_by=(select auth.uid()));
create policy feature_update_admin on public.elnota_feature_access for update to authenticated using ((select public.elnota_is_admin())) with check ((select public.elnota_is_admin()) and changed_by=(select auth.uid()));

create function public.elnota_set_catalog_access(target_user uuid, enabled boolean)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if auth.uid() is null or not public.elnota_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  insert into public.elnota_feature_access(user_id,catalog_enabled,changed_by)
  values(target_user,enabled,auth.uid()) on conflict(user_id) do update
  set catalog_enabled=excluded.catalog_enabled,changed_by=excluded.changed_by,updated_at=now();
end; $$;
revoke all on function public.elnota_set_catalog_access(uuid,boolean) from public,anon;
grant execute on function public.elnota_set_catalog_access(uuid,boolean) to authenticated;

create table public.elnota_v2_device_backups (
  user_id uuid not null references auth.users(id), device_id uuid not null,
  backup_day date not null, data jsonb not null check(octet_length(data::text)<=10485760),
  uploaded_at timestamptz not null default now(),
  primary key(user_id,device_id,backup_day)
);
alter table public.elnota_v2_device_backups enable row level security;
revoke all on public.elnota_v2_device_backups from anon,authenticated;
grant select,insert,update on public.elnota_v2_device_backups to authenticated;
create policy backup_read on public.elnota_v2_device_backups for select to authenticated using(user_id=(select auth.uid()) and exists(select 1 from public.elnota_accounts a where a.user_id=auth.uid() and a.activated_at is not null and a.cloud_until>now() and a.suspended_at is null and a.deleted_at is null));
create policy backup_insert on public.elnota_v2_device_backups for insert to authenticated with check(user_id=(select auth.uid()) and exists(select 1 from public.elnota_accounts a where a.user_id=auth.uid() and a.activated_at is not null and a.cloud_until>now() and a.suspended_at is null and a.deleted_at is null));
create policy backup_update on public.elnota_v2_device_backups for update to authenticated using(user_id=(select auth.uid()) and exists(select 1 from public.elnota_accounts a where a.user_id=auth.uid() and a.activated_at is not null and a.cloud_until>now() and a.suspended_at is null and a.deleted_at is null)) with check(user_id=(select auth.uid()) and exists(select 1 from public.elnota_accounts a where a.user_id=auth.uid() and a.activated_at is not null and a.cloud_until>now() and a.suspended_at is null and a.deleted_at is null));
create function public.elnota_v2_upload_backup(expected_user uuid,device uuid,backup_day date,payload jsonb)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if auth.uid() is null or auth.uid()<>expected_user then raise exception 'USER_MISMATCH';end if;
  if payload->>'schema_version' is distinct from '3' then raise exception 'SCHEMA_MISMATCH';end if;
  if backup_day < current_date-1 or backup_day > current_date+1 then raise exception 'INVALID_BACKUP_DAY';end if;
  insert into public.elnota_v2_device_backups(user_id,device_id,backup_day,data)
  values(expected_user,device,backup_day,payload) on conflict on constraint elnota_v2_device_backups_pkey do update set data=excluded.data,uploaded_at=now();
end; $$;
revoke all on function public.elnota_v2_upload_backup(uuid,uuid,date,jsonb) from public,anon;
grant execute on function public.elnota_v2_upload_backup(uuid,uuid,date,jsonb) to authenticated;
