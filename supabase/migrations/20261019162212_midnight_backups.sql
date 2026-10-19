begin;
create table if not exists public.elnota_device_backup_files(
 id uuid primary key,user_id uuid not null references public.elnota_accounts(user_id) on delete cascade,
 device_id uuid not null,backup_day date not null,captured_at timestamptz not null,
 uploaded_at timestamptz not null default clock_timestamp(),data jsonb not null,
 size_bytes integer generated always as(octet_length(data::text)) stored,
 check(octet_length(data::text)<=10485760)
);
create index if not exists elnota_device_backup_latest on public.elnota_device_backup_files(user_id,uploaded_at desc,id desc);
alter table public.elnota_device_backup_files enable row level security;
revoke all on public.elnota_device_backup_files from public,anon,authenticated;
grant select on public.elnota_device_backup_files to authenticated;
drop policy if exists owner_or_admin_read on public.elnota_device_backup_files;
create policy owner_or_admin_read on public.elnota_device_backup_files for select to authenticated using(user_id=(select auth.uid()) or (select elnota_private.is_admin()));
create or replace function elnota_private.upload_device_backup(expected_user uuid,backup_id uuid,device_id uuid,backup_day date,captured_at timestamptz,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); saved public.elnota_device_backup_files;
begin
 if uid is null or uid is distinct from expected_user then raise exception 'AUTH_REQUIRED';end if;
 perform 1 from public.elnota_accounts a where a.user_id=uid and a.activated_at is not null and a.cloud_until>now() for update;
 if not found then raise exception 'CLOUD_SUBSCRIPTION_REQUIRED';end if;
 if backup_id is null or device_id is null or backup_day is null or captured_at is null or payload is null then raise exception 'INVALID_BACKUP';end if;
 if captured_at>now()+interval '5 minutes' or backup_day<>(captured_at at time zone 'Africa/Cairo')::date then raise exception 'INVALID_BACKUP_DATE';end if;
 if jsonb_typeof(payload)<>'object' or (payload->>'schemaVersion') is distinct from '1'
 or jsonb_typeof(payload->'customers') is distinct from 'array' or jsonb_typeof(payload->'products') is distinct from 'array' or jsonb_typeof(payload->'invoices') is distinct from 'array' or jsonb_typeof(payload->'settings') is distinct from 'object' or octet_length(payload::text)>10485760 then raise exception 'INVALID_BACKUP';end if;
 select * into saved from public.elnota_device_backup_files b where b.id=backup_id;
 if found then
 if saved.user_id<>uid then raise exception 'INVALID_BACKUP';end if;
 return jsonb_build_object('id',saved.id,'backup_day',saved.backup_day,'captured_at',saved.captured_at,'uploaded_at',saved.uploaded_at,'size_bytes',saved.size_bytes);
 end if;
 insert into public.elnota_device_backup_files(id,user_id,device_id,backup_day,captured_at,data)
 values(backup_id,uid,device_id,backup_day,captured_at,payload) returning * into saved;
 -- Bounded storage: preserve the latest three uploaded files per account.
 delete from public.elnota_device_backup_files b where b.user_id=uid and b.id not in(select x.id from public.elnota_device_backup_files x where x.user_id=uid order by x.uploaded_at desc,x.id desc limit 3);
 return jsonb_build_object('id',saved.id,'backup_day',saved.backup_day,'captured_at',saved.captured_at,'uploaded_at',saved.uploaded_at,'size_bytes',saved.size_bytes);
end;$$;
create or replace function public.elnota_upload_device_backup(expected_user uuid,backup_id uuid,device_id uuid,backup_day date,captured_at timestamptz,payload jsonb) returns jsonb
language sql security invoker set search_path='' as $$select elnota_private.upload_device_backup(expected_user,backup_id,device_id,backup_day,captured_at,payload);$$;
revoke all on function elnota_private.upload_device_backup(uuid,uuid,uuid,date,timestamptz,jsonb),public.elnota_upload_device_backup(uuid,uuid,uuid,date,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function elnota_private.upload_device_backup(uuid,uuid,uuid,date,timestamptz,jsonb),public.elnota_upload_device_backup(uuid,uuid,uuid,date,timestamptz,jsonb) to authenticated;
create or replace view public.elnota_latest_device_backups with(security_invoker=true) as
select distinct on(user_id) user_id,id,backup_day,captured_at,uploaded_at,size_bytes from public.elnota_device_backup_files order by user_id,uploaded_at desc,id desc;
revoke all on public.elnota_latest_device_backups from public,anon,authenticated;
grant select on public.elnota_latest_device_backups to authenticated;
-- Use Cairo calendar days rather than a rolling 24-hour window for existing clients.
create or replace function public.elnota_daily_snapshot() returns timestamptz language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); source public.elnota_cloud; saved_at timestamptz;
begin
 if uid is null then raise exception 'AUTH_REQUIRED';end if;
 perform 1 from public.elnota_accounts where user_id=uid and activated_at is not null and cloud_until>now() for update;
 if not found then raise exception 'CLOUD_SUBSCRIPTION_REQUIRED';end if;
 select updated_at into saved_at from public.elnota_daily_backups where user_id=uid;
 if (saved_at at time zone 'Africa/Cairo')::date=(now() at time zone 'Africa/Cairo')::date then return saved_at;end if;
 select * into source from public.elnota_cloud where user_id=uid for update;
 if not found then raise exception 'SYNC_REQUIRED';end if;
 insert into public.elnota_daily_backups(user_id,data,revision,updated_at) values(uid,source.data,source.revision,now()) on conflict(user_id) do update set data=excluded.data,revision=excluded.revision,updated_at=excluded.updated_at;
 return now();
end;$$;
-- Server-only job. It copies only the last synchronized cloud data, never unseen offline changes.
create or replace function elnota_private.midnight_cloud_snapshot() returns integer language plpgsql security definer set search_path='' as $$
declare affected integer;
begin
 if extract(hour from now() at time zone 'Africa/Cairo')<>0 then return 0;end if;
 insert into public.elnota_daily_backups(user_id,data,revision,updated_at)
 select c.user_id,c.data,c.revision,now() from public.elnota_cloud c join public.elnota_accounts a using(user_id)
 where a.activated_at is not null and a.cloud_until>now()
 on conflict(user_id) do update set data=excluded.data,revision=excluded.revision,updated_at=excluded.updated_at
 where (elnota_daily_backups.updated_at at time zone 'Africa/Cairo')::date < (now() at time zone 'Africa/Cairo')::date;
 get diagnostics affected=row_count;return affected;
end;$$;
revoke all on function elnota_private.midnight_cloud_snapshot() from public,anon,authenticated;
-- Hourly UTC trigger + Cairo-hour guard handles both Egyptian DST offsets.
create extension if not exists pg_cron;
select cron.schedule('elnota-midnight-cairo','0 * * * *','select elnota_private.midnight_cloud_snapshot();');
commit;
