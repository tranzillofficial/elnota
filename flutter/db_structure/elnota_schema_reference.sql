-- ElNota live application schema reference
-- Project: fsmoerttftxcuxpswufk
-- Captured: 2026-10-20T23:10:04.803438+00:00
-- PostgreSQL: PostgreSQL 17.11 on aarch64-unknown-linux-gnu, compiled by gcc (GCC) 15.2.0, 64-bit
-- REFERENCE ONLY: not an ordered migration or a tested restore script.
-- Managed Supabase schemas and extension internals are inventoried in schema_catalog.json.
-- No customer rows, passwords, API keys or tokens are included.

CREATE SCHEMA "elnota_private";

CREATE TABLE "elnota_private"."account_actions" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "actor_id" uuid NOT NULL,
  "target_user" uuid NOT NULL,
  "action" text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "elnota_private"."admin_emails" (
  "email" text NOT NULL
);

CREATE TABLE "public"."elnota_accounts" (
  "user_id" uuid NOT NULL,
  "email" text NOT NULL,
  "business_name" text DEFAULT ''::text NOT NULL,
  "activated_at" timestamp with time zone,
  "cloud_until" timestamp with time zone,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "printing_enabled" boolean DEFAULT false NOT NULL,
  "cloud_plan" text,
  "suspended_at" timestamp with time zone,
  "deleted_at" timestamp with time zone,
  "suspended_activation_at" timestamp with time zone,
  "suspended_cloud_until" timestamp with time zone,
  "suspended_printing" boolean
);

CREATE TABLE "public"."elnota_backups" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "data" jsonb NOT NULL,
  "revision" bigint NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."elnota_catalog_imports" (
  "id" text NOT NULL,
  "user_id" uuid NOT NULL,
  "payload" jsonb NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."elnota_cloud" (
  "user_id" uuid NOT NULL,
  "data" jsonb NOT NULL,
  "revision" bigint DEFAULT 1 NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."elnota_daily_backups" (
  "user_id" uuid NOT NULL,
  "data" jsonb NOT NULL,
  "revision" bigint NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."elnota_device_backup_files" (
  "id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "device_id" uuid NOT NULL,
  "backup_day" date NOT NULL,
  "captured_at" timestamp with time zone NOT NULL,
  "uploaded_at" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
  "data" jsonb NOT NULL,
  "size_bytes" integer GENERATED ALWAYS AS (octet_length((data)::text)) STORED
);

CREATE TABLE "public"."elnota_requests" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "plan" text NOT NULL,
  "amount" integer GENERATED ALWAYS AS (
CASE plan
    WHEN 'basic'::text THEN 1000
    WHEN 'cloud_month'::text THEN 50
    ELSE 500
END) STORED,
  "phone" text NOT NULL,
  "reference" text NOT NULL,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "reviewed_at" timestamp with time zone,
  "reviewed_by" uuid,
  "submitted_email" text,
  "submitted_business_name" text
);

-- Constraints, including cross-schema references to managed auth.users.
ALTER TABLE "elnota_private"."account_actions" ADD CONSTRAINT "account_actions_pkey" PRIMARY KEY (id);
ALTER TABLE "elnota_private"."admin_emails" ADD CONSTRAINT "admin_emails_pkey" PRIMARY KEY (email);
ALTER TABLE "public"."elnota_accounts" ADD CONSTRAINT "elnota_accounts_cloud_plan_check" CHECK (cloud_plan = ANY (ARRAY['month'::text, 'year'::text]));
ALTER TABLE "public"."elnota_accounts" ADD CONSTRAINT "elnota_accounts_pkey" PRIMARY KEY (user_id);
ALTER TABLE "public"."elnota_accounts" ADD CONSTRAINT "elnota_accounts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE "public"."elnota_backups" ADD CONSTRAINT "elnota_backups_data_check" CHECK (octet_length(data::text) <= 10485760);
ALTER TABLE "public"."elnota_backups" ADD CONSTRAINT "elnota_backups_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."elnota_backups" ADD CONSTRAINT "elnota_backups_user_id_fkey" FOREIGN KEY (user_id) REFERENCES elnota_accounts(user_id) ON DELETE CASCADE;
ALTER TABLE "public"."elnota_catalog_imports" ADD CONSTRAINT "elnota_catalog_imports_payload_check" CHECK (jsonb_typeof(payload) = 'object'::text);
ALTER TABLE "public"."elnota_catalog_imports" ADD CONSTRAINT "elnota_catalog_imports_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."elnota_catalog_imports" ADD CONSTRAINT "elnota_catalog_imports_user_id_fkey" FOREIGN KEY (user_id) REFERENCES elnota_accounts(user_id) ON DELETE CASCADE;
ALTER TABLE "public"."elnota_cloud" ADD CONSTRAINT "elnota_cloud_data_check" CHECK (octet_length(data::text) <= 10485760);
ALTER TABLE "public"."elnota_cloud" ADD CONSTRAINT "elnota_cloud_pkey" PRIMARY KEY (user_id);
ALTER TABLE "public"."elnota_cloud" ADD CONSTRAINT "elnota_cloud_user_id_fkey" FOREIGN KEY (user_id) REFERENCES elnota_accounts(user_id) ON DELETE CASCADE;
ALTER TABLE "public"."elnota_daily_backups" ADD CONSTRAINT "elnota_daily_backups_data_check" CHECK (octet_length(data::text) <= 10485760);
ALTER TABLE "public"."elnota_daily_backups" ADD CONSTRAINT "elnota_daily_backups_pkey" PRIMARY KEY (user_id);
ALTER TABLE "public"."elnota_daily_backups" ADD CONSTRAINT "elnota_daily_backups_user_id_fkey" FOREIGN KEY (user_id) REFERENCES elnota_accounts(user_id) ON DELETE CASCADE;
ALTER TABLE "public"."elnota_device_backup_files" ADD CONSTRAINT "elnota_device_backup_files_data_check" CHECK (octet_length(data::text) <= 10485760);
ALTER TABLE "public"."elnota_device_backup_files" ADD CONSTRAINT "elnota_device_backup_files_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."elnota_device_backup_files" ADD CONSTRAINT "elnota_device_backup_files_user_id_fkey" FOREIGN KEY (user_id) REFERENCES elnota_accounts(user_id) ON DELETE CASCADE;
ALTER TABLE "public"."elnota_requests" ADD CONSTRAINT "elnota_requests_phone_check" CHECK (length(phone) >= 7 AND length(phone) <= 30);
ALTER TABLE "public"."elnota_requests" ADD CONSTRAINT "elnota_requests_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."elnota_requests" ADD CONSTRAINT "elnota_requests_plan_check" CHECK (plan = ANY (ARRAY['basic'::text, 'cloud_month'::text, 'cloud_year'::text]));
ALTER TABLE "public"."elnota_requests" ADD CONSTRAINT "elnota_requests_reference_check" CHECK (length(reference) >= 3 AND length(reference) <= 500);
ALTER TABLE "public"."elnota_requests" ADD CONSTRAINT "elnota_requests_reviewed_by_fkey" FOREIGN KEY (reviewed_by) REFERENCES auth.users(id);
ALTER TABLE "public"."elnota_requests" ADD CONSTRAINT "elnota_requests_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]));
ALTER TABLE "public"."elnota_requests" ADD CONSTRAINT "elnota_requests_user_id_fkey" FOREIGN KEY (user_id) REFERENCES elnota_accounts(user_id);

-- Indexes (constraint-backed indexes already covered above).
CREATE INDEX elnota_backups_owner ON public.elnota_backups USING btree (user_id, created_at DESC);
CREATE INDEX elnota_catalog_imports_owner ON public.elnota_catalog_imports USING btree (user_id);
CREATE INDEX elnota_device_backup_latest ON public.elnota_device_backup_files USING btree (user_id, uploaded_at DESC, id DESC);
CREATE UNIQUE INDEX elnota_one_pending_plan ON public.elnota_requests USING btree (user_id, plan) WHERE (status = 'pending'::text);
CREATE INDEX elnota_request_created ON public.elnota_requests USING btree (created_at DESC);

-- Custom functions: exact definitions from pg_get_functiondef.

CREATE OR REPLACE FUNCTION elnota_private.guard_account_state()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if (new.suspended_at is not null or new.deleted_at is not null) and (new.activated_at is not null or new.cloud_until is not null or coalesce(new.printing_enabled,false)) then raise exception 'ACCOUNT_SUSPENDED_OR_DELETED';end if;
 return new;
end;$function$
;

CREATE OR REPLACE FUNCTION elnota_private.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select exists(select 1 from auth.users u join elnota_private.admin_emails a on lower(u.email)=a.email where u.id=(select auth.uid()) and u.email_confirmed_at is not null);
$function$
;

CREATE OR REPLACE FUNCTION elnota_private.manage_account(target_user uuid, operation text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$
;

CREATE OR REPLACE FUNCTION elnota_private.midnight_cloud_snapshot()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare affected integer;
begin
 if extract(hour from now() at time zone 'Africa/Cairo')<>0 then return 0;end if;
 insert into public.elnota_daily_backups(user_id,data,revision,updated_at)
 select c.user_id,c.data,c.revision,now() from public.elnota_cloud c join public.elnota_accounts a using(user_id)
 where a.activated_at is not null and a.cloud_until>now()
 on conflict(user_id) do update set data=excluded.data,revision=excluded.revision,updated_at=excluded.updated_at
 where (elnota_daily_backups.updated_at at time zone 'Africa/Cairo')::date < (now() at time zone 'Africa/Cairo')::date;
 get diagnostics affected=row_count;return affected;
end;$function$
;

CREATE OR REPLACE FUNCTION elnota_private.stamp_activation_sender()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if auth.uid() is null or new.user_id is distinct from auth.uid() then raise exception 'AUTH_REQUIRED';end if;
 if exists(select 1 from public.elnota_accounts where user_id=auth.uid() and (suspended_at is not null or deleted_at is not null)) then raise exception 'ACCOUNT_SUSPENDED_OR_DELETED';end if;
 select u.email,a.business_name into new.submitted_email,new.submitted_business_name from auth.users u join public.elnota_accounts a on a.user_id=u.id where u.id=auth.uid() and u.email_confirmed_at is not null;
 if not found then raise exception 'AUTH_REQUIRED';end if;
 return new;
end;$function$
;

CREATE OR REPLACE FUNCTION elnota_private.upload_device_backup(expected_user uuid, backup_id uuid, device_id uuid, backup_day date, captured_at timestamp with time zone, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$
;

CREATE OR REPLACE FUNCTION public.elnota_daily_snapshot()
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$
;

CREATE OR REPLACE FUNCTION public.elnota_is_admin()
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO ''
AS $function$select elnota_private.is_admin();$function$
;

CREATE OR REPLACE FUNCTION public.elnota_manage_account(target_user uuid, operation text)
 RETURNS void
 LANGUAGE sql
 SET search_path TO ''
AS $function$select elnota_private.manage_account(target_user,operation);$function$
;

CREATE OR REPLACE FUNCTION public.elnota_manage_cloud(target_user uuid, plan text)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$
;

CREATE OR REPLACE FUNCTION public.elnota_register(business text)
 RETURNS elnota_accounts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare account public.elnota_accounts; uid uuid := (select auth.uid());
begin
 if uid is null or not exists(select 1 from auth.users where id=uid and email_confirmed_at is not null) then raise exception 'AUTH_REQUIRED';end if;
 if length(business)>150 then raise exception 'INVALID_BUSINESS';end if;
 insert into public.elnota_accounts(user_id,email,business_name) select id,email,business from auth.users where id=uid on conflict(user_id) do nothing;
 select * into account from public.elnota_accounts where user_id=uid;return account;
end;$function$
;

CREATE OR REPLACE FUNCTION public.elnota_restore_daily(target_user uuid, expected_revision bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$
;

CREATE OR REPLACE FUNCTION public.elnota_review(request_id uuid, approve boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$
;

CREATE OR REPLACE FUNCTION public.elnota_set_printing(target_user uuid, enabled boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if (select auth.uid()) is null or not elnota_private.is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
 if enabled is null then raise exception 'INVALID_PERMISSION'; end if;
 update public.elnota_accounts set printing_enabled=enabled where user_id=target_user;
 if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.elnota_sync(payload jsonb, expected_revision bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$
;

CREATE OR REPLACE FUNCTION public.elnota_upload_device_backup(expected_user uuid, backup_id uuid, device_id uuid, backup_day date, captured_at timestamp with time zone, payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select elnota_private.upload_device_backup(expected_user,backup_id,device_id,backup_day,captured_at,payload);$function$
;

-- Application views.
CREATE VIEW "public"."elnota_latest_device_backups" WITH (security_invoker=true) AS
 SELECT DISTINCT ON (user_id) user_id,
    id,
    backup_day,
    captured_at,
    uploaded_at,
    size_bytes
   FROM elnota_device_backup_files
  ORDER BY user_id, uploaded_at DESC, id DESC;

-- Custom triggers, including hooks on managed tables.
CREATE TRIGGER guard_account_state BEFORE INSERT OR UPDATE ON elnota_accounts FOR EACH ROW EXECUTE FUNCTION elnota_private.guard_account_state();
CREATE TRIGGER stamp_activation_sender BEFORE INSERT ON elnota_requests FOR EACH ROW EXECUTE FUNCTION elnota_private.stamp_activation_sender();

-- Row-level security and policies.
ALTER TABLE "elnota_private"."account_actions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "elnota_private"."admin_emails" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."elnota_accounts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."elnota_backups" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."elnota_catalog_imports" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."elnota_cloud" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."elnota_daily_backups" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."elnota_device_backup_files" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."elnota_requests" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "accounts_read" ON "public"."elnota_accounts" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT elnota_private.is_admin() AS is_admin)));
CREATE POLICY "backups_read" ON "public"."elnota_backups" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((user_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "catalog_imports_owner_read" ON "public"."elnota_catalog_imports" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM elnota_accounts a
  WHERE ((a.user_id = elnota_catalog_imports.user_id) AND (a.activated_at IS NOT NULL))))));
CREATE POLICY "cloud_admin_read" ON "public"."elnota_cloud" AS PERMISSIVE FOR SELECT TO "authenticated" USING (( SELECT elnota_private.is_admin() AS is_admin));
CREATE POLICY "cloud_read" ON "public"."elnota_cloud" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((user_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "daily_read" ON "public"."elnota_daily_backups" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT elnota_private.is_admin() AS is_admin)));
CREATE POLICY "owner_or_admin_read" ON "public"."elnota_device_backup_files" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT elnota_private.is_admin() AS is_admin)));
CREATE POLICY "requests_insert" ON "public"."elnota_requests" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (status = 'pending'::text) AND (reviewed_at IS NULL) AND (reviewed_by IS NULL)));
CREATE POLICY "requests_read" ON "public"."elnota_requests" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT elnota_private.is_admin() AS is_admin)));

-- Effective explicit table/view privileges (owners included).
-- On a fresh database, also restore raw ACL/default ACL metadata from the catalog.
REVOKE ALL ON TABLE "elnota_private"."account_actions" FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE "elnota_private"."admin_emails" FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE "public"."elnota_accounts" FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE "public"."elnota_backups" FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE "public"."elnota_catalog_imports" FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE "public"."elnota_cloud" FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE "public"."elnota_daily_backups" FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE "public"."elnota_device_backup_files" FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE "public"."elnota_requests" FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE "public"."elnota_latest_device_backups" FROM PUBLIC, anon, authenticated, service_role;
GRANT INSERT ON TABLE "elnota_private"."account_actions" TO "postgres";
GRANT SELECT ON TABLE "elnota_private"."account_actions" TO "postgres";
GRANT UPDATE ON TABLE "elnota_private"."account_actions" TO "postgres";
GRANT DELETE ON TABLE "elnota_private"."account_actions" TO "postgres";
GRANT TRUNCATE ON TABLE "elnota_private"."account_actions" TO "postgres";
GRANT REFERENCES ON TABLE "elnota_private"."account_actions" TO "postgres";
GRANT TRIGGER ON TABLE "elnota_private"."account_actions" TO "postgres";
GRANT MAINTAIN ON TABLE "elnota_private"."account_actions" TO "postgres";
GRANT INSERT ON TABLE "elnota_private"."admin_emails" TO "postgres";
GRANT SELECT ON TABLE "elnota_private"."admin_emails" TO "postgres";
GRANT UPDATE ON TABLE "elnota_private"."admin_emails" TO "postgres";
GRANT DELETE ON TABLE "elnota_private"."admin_emails" TO "postgres";
GRANT TRUNCATE ON TABLE "elnota_private"."admin_emails" TO "postgres";
GRANT REFERENCES ON TABLE "elnota_private"."admin_emails" TO "postgres";
GRANT TRIGGER ON TABLE "elnota_private"."admin_emails" TO "postgres";
GRANT MAINTAIN ON TABLE "elnota_private"."admin_emails" TO "postgres";
GRANT INSERT ON TABLE "public"."elnota_device_backup_files" TO "postgres";
GRANT SELECT ON TABLE "public"."elnota_device_backup_files" TO "postgres";
GRANT UPDATE ON TABLE "public"."elnota_device_backup_files" TO "postgres";
GRANT DELETE ON TABLE "public"."elnota_device_backup_files" TO "postgres";
GRANT TRUNCATE ON TABLE "public"."elnota_device_backup_files" TO "postgres";
GRANT REFERENCES ON TABLE "public"."elnota_device_backup_files" TO "postgres";
GRANT TRIGGER ON TABLE "public"."elnota_device_backup_files" TO "postgres";
GRANT MAINTAIN ON TABLE "public"."elnota_device_backup_files" TO "postgres";
GRANT INSERT ON TABLE "public"."elnota_device_backup_files" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_device_backup_files" TO "service_role";
GRANT UPDATE ON TABLE "public"."elnota_device_backup_files" TO "service_role";
GRANT DELETE ON TABLE "public"."elnota_device_backup_files" TO "service_role";
GRANT TRUNCATE ON TABLE "public"."elnota_device_backup_files" TO "service_role";
GRANT REFERENCES ON TABLE "public"."elnota_device_backup_files" TO "service_role";
GRANT TRIGGER ON TABLE "public"."elnota_device_backup_files" TO "service_role";
GRANT MAINTAIN ON TABLE "public"."elnota_device_backup_files" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_device_backup_files" TO "authenticated";
GRANT INSERT ON TABLE "public"."elnota_cloud" TO "postgres";
GRANT SELECT ON TABLE "public"."elnota_cloud" TO "postgres";
GRANT UPDATE ON TABLE "public"."elnota_cloud" TO "postgres";
GRANT DELETE ON TABLE "public"."elnota_cloud" TO "postgres";
GRANT TRUNCATE ON TABLE "public"."elnota_cloud" TO "postgres";
GRANT REFERENCES ON TABLE "public"."elnota_cloud" TO "postgres";
GRANT TRIGGER ON TABLE "public"."elnota_cloud" TO "postgres";
GRANT MAINTAIN ON TABLE "public"."elnota_cloud" TO "postgres";
GRANT INSERT ON TABLE "public"."elnota_cloud" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_cloud" TO "service_role";
GRANT UPDATE ON TABLE "public"."elnota_cloud" TO "service_role";
GRANT DELETE ON TABLE "public"."elnota_cloud" TO "service_role";
GRANT TRUNCATE ON TABLE "public"."elnota_cloud" TO "service_role";
GRANT REFERENCES ON TABLE "public"."elnota_cloud" TO "service_role";
GRANT TRIGGER ON TABLE "public"."elnota_cloud" TO "service_role";
GRANT MAINTAIN ON TABLE "public"."elnota_cloud" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_cloud" TO "authenticated";
GRANT INSERT ON TABLE "public"."elnota_backups" TO "postgres";
GRANT SELECT ON TABLE "public"."elnota_backups" TO "postgres";
GRANT UPDATE ON TABLE "public"."elnota_backups" TO "postgres";
GRANT DELETE ON TABLE "public"."elnota_backups" TO "postgres";
GRANT TRUNCATE ON TABLE "public"."elnota_backups" TO "postgres";
GRANT REFERENCES ON TABLE "public"."elnota_backups" TO "postgres";
GRANT TRIGGER ON TABLE "public"."elnota_backups" TO "postgres";
GRANT MAINTAIN ON TABLE "public"."elnota_backups" TO "postgres";
GRANT INSERT ON TABLE "public"."elnota_backups" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_backups" TO "service_role";
GRANT UPDATE ON TABLE "public"."elnota_backups" TO "service_role";
GRANT DELETE ON TABLE "public"."elnota_backups" TO "service_role";
GRANT TRUNCATE ON TABLE "public"."elnota_backups" TO "service_role";
GRANT REFERENCES ON TABLE "public"."elnota_backups" TO "service_role";
GRANT TRIGGER ON TABLE "public"."elnota_backups" TO "service_role";
GRANT MAINTAIN ON TABLE "public"."elnota_backups" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_backups" TO "authenticated";
GRANT INSERT ON TABLE "public"."elnota_catalog_imports" TO "postgres";
GRANT SELECT ON TABLE "public"."elnota_catalog_imports" TO "postgres";
GRANT UPDATE ON TABLE "public"."elnota_catalog_imports" TO "postgres";
GRANT DELETE ON TABLE "public"."elnota_catalog_imports" TO "postgres";
GRANT TRUNCATE ON TABLE "public"."elnota_catalog_imports" TO "postgres";
GRANT REFERENCES ON TABLE "public"."elnota_catalog_imports" TO "postgres";
GRANT TRIGGER ON TABLE "public"."elnota_catalog_imports" TO "postgres";
GRANT MAINTAIN ON TABLE "public"."elnota_catalog_imports" TO "postgres";
GRANT INSERT ON TABLE "public"."elnota_catalog_imports" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_catalog_imports" TO "service_role";
GRANT UPDATE ON TABLE "public"."elnota_catalog_imports" TO "service_role";
GRANT DELETE ON TABLE "public"."elnota_catalog_imports" TO "service_role";
GRANT TRUNCATE ON TABLE "public"."elnota_catalog_imports" TO "service_role";
GRANT REFERENCES ON TABLE "public"."elnota_catalog_imports" TO "service_role";
GRANT TRIGGER ON TABLE "public"."elnota_catalog_imports" TO "service_role";
GRANT MAINTAIN ON TABLE "public"."elnota_catalog_imports" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_catalog_imports" TO "authenticated";
GRANT INSERT ON TABLE "public"."elnota_accounts" TO "postgres";
GRANT SELECT ON TABLE "public"."elnota_accounts" TO "postgres";
GRANT UPDATE ON TABLE "public"."elnota_accounts" TO "postgres";
GRANT DELETE ON TABLE "public"."elnota_accounts" TO "postgres";
GRANT TRUNCATE ON TABLE "public"."elnota_accounts" TO "postgres";
GRANT REFERENCES ON TABLE "public"."elnota_accounts" TO "postgres";
GRANT TRIGGER ON TABLE "public"."elnota_accounts" TO "postgres";
GRANT MAINTAIN ON TABLE "public"."elnota_accounts" TO "postgres";
GRANT INSERT ON TABLE "public"."elnota_accounts" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_accounts" TO "service_role";
GRANT UPDATE ON TABLE "public"."elnota_accounts" TO "service_role";
GRANT DELETE ON TABLE "public"."elnota_accounts" TO "service_role";
GRANT TRUNCATE ON TABLE "public"."elnota_accounts" TO "service_role";
GRANT REFERENCES ON TABLE "public"."elnota_accounts" TO "service_role";
GRANT TRIGGER ON TABLE "public"."elnota_accounts" TO "service_role";
GRANT MAINTAIN ON TABLE "public"."elnota_accounts" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_accounts" TO "authenticated";
GRANT INSERT ON TABLE "public"."elnota_daily_backups" TO "postgres";
GRANT SELECT ON TABLE "public"."elnota_daily_backups" TO "postgres";
GRANT UPDATE ON TABLE "public"."elnota_daily_backups" TO "postgres";
GRANT DELETE ON TABLE "public"."elnota_daily_backups" TO "postgres";
GRANT TRUNCATE ON TABLE "public"."elnota_daily_backups" TO "postgres";
GRANT REFERENCES ON TABLE "public"."elnota_daily_backups" TO "postgres";
GRANT TRIGGER ON TABLE "public"."elnota_daily_backups" TO "postgres";
GRANT MAINTAIN ON TABLE "public"."elnota_daily_backups" TO "postgres";
GRANT INSERT ON TABLE "public"."elnota_daily_backups" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_daily_backups" TO "service_role";
GRANT UPDATE ON TABLE "public"."elnota_daily_backups" TO "service_role";
GRANT DELETE ON TABLE "public"."elnota_daily_backups" TO "service_role";
GRANT TRUNCATE ON TABLE "public"."elnota_daily_backups" TO "service_role";
GRANT REFERENCES ON TABLE "public"."elnota_daily_backups" TO "service_role";
GRANT TRIGGER ON TABLE "public"."elnota_daily_backups" TO "service_role";
GRANT MAINTAIN ON TABLE "public"."elnota_daily_backups" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_daily_backups" TO "authenticated";
GRANT INSERT ON TABLE "public"."elnota_requests" TO "postgres";
GRANT SELECT ON TABLE "public"."elnota_requests" TO "postgres";
GRANT UPDATE ON TABLE "public"."elnota_requests" TO "postgres";
GRANT DELETE ON TABLE "public"."elnota_requests" TO "postgres";
GRANT TRUNCATE ON TABLE "public"."elnota_requests" TO "postgres";
GRANT REFERENCES ON TABLE "public"."elnota_requests" TO "postgres";
GRANT TRIGGER ON TABLE "public"."elnota_requests" TO "postgres";
GRANT MAINTAIN ON TABLE "public"."elnota_requests" TO "postgres";
GRANT INSERT ON TABLE "public"."elnota_requests" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_requests" TO "service_role";
GRANT UPDATE ON TABLE "public"."elnota_requests" TO "service_role";
GRANT DELETE ON TABLE "public"."elnota_requests" TO "service_role";
GRANT TRUNCATE ON TABLE "public"."elnota_requests" TO "service_role";
GRANT REFERENCES ON TABLE "public"."elnota_requests" TO "service_role";
GRANT TRIGGER ON TABLE "public"."elnota_requests" TO "service_role";
GRANT MAINTAIN ON TABLE "public"."elnota_requests" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_requests" TO "authenticated";
GRANT INSERT ON TABLE "public"."elnota_latest_device_backups" TO "postgres";
GRANT SELECT ON TABLE "public"."elnota_latest_device_backups" TO "postgres";
GRANT UPDATE ON TABLE "public"."elnota_latest_device_backups" TO "postgres";
GRANT DELETE ON TABLE "public"."elnota_latest_device_backups" TO "postgres";
GRANT TRUNCATE ON TABLE "public"."elnota_latest_device_backups" TO "postgres";
GRANT REFERENCES ON TABLE "public"."elnota_latest_device_backups" TO "postgres";
GRANT TRIGGER ON TABLE "public"."elnota_latest_device_backups" TO "postgres";
GRANT MAINTAIN ON TABLE "public"."elnota_latest_device_backups" TO "postgres";
GRANT INSERT ON TABLE "public"."elnota_latest_device_backups" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_latest_device_backups" TO "service_role";
GRANT UPDATE ON TABLE "public"."elnota_latest_device_backups" TO "service_role";
GRANT DELETE ON TABLE "public"."elnota_latest_device_backups" TO "service_role";
GRANT TRUNCATE ON TABLE "public"."elnota_latest_device_backups" TO "service_role";
GRANT REFERENCES ON TABLE "public"."elnota_latest_device_backups" TO "service_role";
GRANT TRIGGER ON TABLE "public"."elnota_latest_device_backups" TO "service_role";
GRANT MAINTAIN ON TABLE "public"."elnota_latest_device_backups" TO "service_role";
GRANT SELECT ON TABLE "public"."elnota_latest_device_backups" TO "authenticated";
GRANT INSERT ("user_id") ON TABLE "public"."elnota_requests" TO "authenticated";
GRANT INSERT ("plan") ON TABLE "public"."elnota_requests" TO "authenticated";
GRANT INSERT ("phone") ON TABLE "public"."elnota_requests" TO "authenticated";
GRANT INSERT ("reference") ON TABLE "public"."elnota_requests" TO "authenticated";
REVOKE ALL ON FUNCTION "elnota_private"."guard_account_state"() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "elnota_private"."is_admin"() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "elnota_private"."manage_account"(target_user uuid, operation text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "elnota_private"."midnight_cloud_snapshot"() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "elnota_private"."stamp_activation_sender"() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "elnota_private"."upload_device_backup"(expected_user uuid, backup_id uuid, device_id uuid, backup_day date, captured_at timestamp with time zone, payload jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "public"."elnota_daily_snapshot"() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "public"."elnota_is_admin"() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "public"."elnota_manage_account"(target_user uuid, operation text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "public"."elnota_manage_cloud"(target_user uuid, plan text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "public"."elnota_register"(business text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "public"."elnota_restore_daily"(target_user uuid, expected_revision bigint) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "public"."elnota_review"(request_id uuid, approve boolean) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "public"."elnota_set_printing"(target_user uuid, enabled boolean) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "public"."elnota_sync"(payload jsonb, expected_revision bigint) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION "public"."elnota_upload_device_backup"(expected_user uuid, backup_id uuid, device_id uuid, backup_day date, captured_at timestamp with time zone, payload jsonb) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION "public"."elnota_set_printing"(target_user uuid, enabled boolean) TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."elnota_set_printing"(target_user uuid, enabled boolean) TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."elnota_set_printing"(target_user uuid, enabled boolean) TO "authenticated";
GRANT EXECUTE ON FUNCTION "elnota_private"."is_admin"() TO "postgres";
GRANT EXECUTE ON FUNCTION "elnota_private"."is_admin"() TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."elnota_is_admin"() TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."elnota_is_admin"() TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."elnota_is_admin"() TO "service_role";
GRANT EXECUTE ON FUNCTION "elnota_private"."midnight_cloud_snapshot"() TO "postgres";
GRANT EXECUTE ON FUNCTION "elnota_private"."guard_account_state"() TO "postgres";
GRANT EXECUTE ON FUNCTION "elnota_private"."stamp_activation_sender"() TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."elnota_register"(business text) TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."elnota_register"(business text) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."elnota_register"(business text) TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."elnota_sync"(payload jsonb, expected_revision bigint) TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."elnota_sync"(payload jsonb, expected_revision bigint) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."elnota_sync"(payload jsonb, expected_revision bigint) TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."elnota_manage_cloud"(target_user uuid, plan text) TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."elnota_manage_cloud"(target_user uuid, plan text) TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."elnota_manage_cloud"(target_user uuid, plan text) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."elnota_restore_daily"(target_user uuid, expected_revision bigint) TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."elnota_restore_daily"(target_user uuid, expected_revision bigint) TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."elnota_restore_daily"(target_user uuid, expected_revision bigint) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."elnota_review"(request_id uuid, approve boolean) TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."elnota_review"(request_id uuid, approve boolean) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."elnota_review"(request_id uuid, approve boolean) TO "service_role";
GRANT EXECUTE ON FUNCTION "elnota_private"."upload_device_backup"(expected_user uuid, backup_id uuid, device_id uuid, backup_day date, captured_at timestamp with time zone, payload jsonb) TO "postgres";
GRANT EXECUTE ON FUNCTION "elnota_private"."upload_device_backup"(expected_user uuid, backup_id uuid, device_id uuid, backup_day date, captured_at timestamp with time zone, payload jsonb) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."elnota_upload_device_backup"(expected_user uuid, backup_id uuid, device_id uuid, backup_day date, captured_at timestamp with time zone, payload jsonb) TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."elnota_upload_device_backup"(expected_user uuid, backup_id uuid, device_id uuid, backup_day date, captured_at timestamp with time zone, payload jsonb) TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."elnota_upload_device_backup"(expected_user uuid, backup_id uuid, device_id uuid, backup_day date, captured_at timestamp with time zone, payload jsonb) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."elnota_daily_snapshot"() TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."elnota_daily_snapshot"() TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."elnota_daily_snapshot"() TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."elnota_manage_account"(target_user uuid, operation text) TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."elnota_manage_account"(target_user uuid, operation text) TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."elnota_manage_account"(target_user uuid, operation text) TO "authenticated";
GRANT EXECUTE ON FUNCTION "elnota_private"."manage_account"(target_user uuid, operation text) TO "postgres";
GRANT EXECUTE ON FUNCTION "elnota_private"."manage_account"(target_user uuid, operation text) TO "authenticated";

-- Scheduled jobs (reference, not auto-executed).
-- elnota-midnight-cairo: 0 * * * *; active=true; database=postgres; user=postgres
-- select elnota_private.midnight_cloud_snapshot();

