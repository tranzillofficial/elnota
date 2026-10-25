create table public.elnota_v2_device_backups (
 user_id uuid not null references auth.users(id), device_id uuid not null,
 backup_day date not null, data jsonb not null,
 uploaded_at timestamptz not null default now(),
 primary key(user_id,device_id,backup_day)
);
alter table public.elnota_v2_device_backups enable row level security;
revoke all on public.elnota_v2_device_backups from public,anon,authenticated;
grant select on public.elnota_v2_device_backups to authenticated;
create policy v2_backup_read on public.elnota_v2_device_backups for select to authenticated using(
 (user_id=(select auth.uid()) and exists(select 1 from public.elnota_accounts a where a.user_id=(select auth.uid()) and a.activated_at is not null and a.suspended_at is null and a.deleted_at is null)) or (select public.elnota_is_admin())
);
create function elnota_private.upload_v2_backup(expected_user uuid,device uuid,backup_day date,payload jsonb) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or auth.uid()<>expected_user then raise exception 'USER_MISMATCH';end if;
 perform 1 from public.elnota_accounts a where a.user_id=auth.uid() and a.activated_at is not null and a.cloud_until>now() and a.suspended_at is null and a.deleted_at is null for share;
 if not found then raise exception 'CLOUD_REQUIRED';end if;
 if device is null or backup_day is null or backup_day<current_date-1 or backup_day>current_date+1 then raise exception 'INVALID_BACKUP_DAY';end if;
 perform elnota_private.validate_v2_snapshot(payload);
 insert into public.elnota_v2_device_backups(user_id,device_id,backup_day,data)
 values(auth.uid(),device,backup_day,payload) on conflict on constraint elnota_v2_device_backups_pkey do update set data=excluded.data,uploaded_at=now();
end;$$;
revoke all on function elnota_private.upload_v2_backup(uuid,uuid,date,jsonb) from public,anon;
grant execute on function elnota_private.upload_v2_backup(uuid,uuid,date,jsonb) to authenticated;
create function public.elnota_v2_upload_backup(expected_user uuid,device uuid,backup_day date,payload jsonb) returns void
language sql security invoker set search_path='' as $$select elnota_private.upload_v2_backup(expected_user,device,backup_day,payload);$$;
revoke all on function public.elnota_v2_upload_backup(uuid,uuid,date,jsonb) from public,anon;
grant execute on function public.elnota_v2_upload_backup(uuid,uuid,date,jsonb) to authenticated;
