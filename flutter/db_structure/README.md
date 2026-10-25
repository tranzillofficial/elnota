# ElNota: current database structure

Captured from the live database at 2026-10-20T23:10:04.803438+00:00 (UTC).

Project: `fsmoerttftxcuxpswufk`. PostgreSQL 17.11.

## Contents and limits

- `elnota_schema_reference.sql`: exact current application table, constraint, index, view, function, trigger and RLS policy definitions, plus privileges. A reference export, not a tested ordered restore migration. Do not run against the existing database.
- `schema_catalog.json`: database metadata covering all 11 non-system schemas: 51 tables, 4 views, 168 constraints, 158 indexes, 12 enums, 4 sequences, extensions, ACLs, default privileges, publications and migration names. Includes exact bodies of 16 custom application functions and a signature inventory for managed/extension functions; it does not dump managed function bodies, role passwords or Supabase platform configuration.
- `README.md`: application overview and column reference.

No table row data, customer records, credentials or backup payloads were exported. Cron job configuration is included as application configuration.

## Application storage model

There are 7 public application tables and 2 private administrative tables. There are no dedicated relational customer/product/invoice tables in the current database. Business ledger data is stored as JSONB documents in cloud and backup tables; PostgreSQL catalog metadata describes the JSONB column, not the complete internal document contract. Flutter must preserve the website's document format and RPC revision semantics.

| Schema | Table | Purpose |
|---|---|---|
| public | elnota_accounts | Account identity, activation, subscription, printing, suspension and soft deletion |
| public | elnota_requests | Activation/subscription payment review requests and stamped sender identity |
| public | elnota_cloud | Latest synchronized ledger document and revision |
| public | elnota_backups | Historical synchronized ledger snapshots |
| public | elnota_daily_backups | Latest daily server ledger snapshot per account |
| public | elnota_device_backup_files | Device snapshot files, capture/upload times and size |
| public | elnota_catalog_imports | Account-specific catalog import documents |
| elnota_private | admin_emails | Private administrator allowlist |
| elnota_private | account_actions | Administrative action audit trail |

## Columns and constraints

### elnota_private.account_actions

RLS: enabled; forced: false; owner: postgres.

| Column | PostgreSQL type | Nullable | Default / generated expression |
|---|---|---|---|
| id | `uuid` | No | `gen_random_uuid()` |
| actor_id | `uuid` | No |  |
| target_user | `uuid` | No |  |
| action | `text` | No |  |
| created_at | `timestamp with time zone` | No | `now()` |

- `account_actions_pkey`: `PRIMARY KEY (id)`

### elnota_private.admin_emails

RLS: enabled; forced: false; owner: postgres.

| Column | PostgreSQL type | Nullable | Default / generated expression |
|---|---|---|---|
| email | `text` | No |  |

- `admin_emails_pkey`: `PRIMARY KEY (email)`

### public.elnota_accounts

RLS: enabled; forced: false; owner: postgres.

| Column | PostgreSQL type | Nullable | Default / generated expression |
|---|---|---|---|
| user_id | `uuid` | No |  |
| email | `text` | No |  |
| business_name | `text` | No | `''::text` |
| activated_at | `timestamp with time zone` | Yes |  |
| cloud_until | `timestamp with time zone` | Yes |  |
| created_at | `timestamp with time zone` | No | `now()` |
| printing_enabled | `boolean` | No | `false` |
| cloud_plan | `text` | Yes |  |
| suspended_at | `timestamp with time zone` | Yes |  |
| deleted_at | `timestamp with time zone` | Yes |  |
| suspended_activation_at | `timestamp with time zone` | Yes |  |
| suspended_cloud_until | `timestamp with time zone` | Yes |  |
| suspended_printing | `boolean` | Yes |  |

- `elnota_accounts_cloud_plan_check`: `CHECK (cloud_plan = ANY (ARRAY['month'::text, 'year'::text]))`

- `elnota_accounts_pkey`: `PRIMARY KEY (user_id)`

- `elnota_accounts_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE`

### public.elnota_backups

RLS: enabled; forced: false; owner: postgres.

| Column | PostgreSQL type | Nullable | Default / generated expression |
|---|---|---|---|
| id | `uuid` | No | `gen_random_uuid()` |
| user_id | `uuid` | No |  |
| data | `jsonb` | No |  |
| revision | `bigint` | No |  |
| created_at | `timestamp with time zone` | No | `now()` |

- `elnota_backups_data_check`: `CHECK (octet_length(data::text) <= 10485760)`

- `elnota_backups_pkey`: `PRIMARY KEY (id)`

- `elnota_backups_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES elnota_accounts(user_id) ON DELETE CASCADE`

### public.elnota_catalog_imports

RLS: enabled; forced: false; owner: postgres.

| Column | PostgreSQL type | Nullable | Default / generated expression |
|---|---|---|---|
| id | `text` | No |  |
| user_id | `uuid` | No |  |
| payload | `jsonb` | No |  |
| created_at | `timestamp with time zone` | No | `now()` |

- `elnota_catalog_imports_payload_check`: `CHECK (jsonb_typeof(payload) = 'object'::text)`

- `elnota_catalog_imports_pkey`: `PRIMARY KEY (id)`

- `elnota_catalog_imports_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES elnota_accounts(user_id) ON DELETE CASCADE`

### public.elnota_cloud

RLS: enabled; forced: false; owner: postgres.

| Column | PostgreSQL type | Nullable | Default / generated expression |
|---|---|---|---|
| user_id | `uuid` | No |  |
| data | `jsonb` | No |  |
| revision | `bigint` | No | `1` |
| updated_at | `timestamp with time zone` | No | `now()` |

- `elnota_cloud_data_check`: `CHECK (octet_length(data::text) <= 10485760)`

- `elnota_cloud_pkey`: `PRIMARY KEY (user_id)`

- `elnota_cloud_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES elnota_accounts(user_id) ON DELETE CASCADE`

### public.elnota_daily_backups

RLS: enabled; forced: false; owner: postgres.

| Column | PostgreSQL type | Nullable | Default / generated expression |
|---|---|---|---|
| user_id | `uuid` | No |  |
| data | `jsonb` | No |  |
| revision | `bigint` | No |  |
| updated_at | `timestamp with time zone` | No | `now()` |

- `elnota_daily_backups_data_check`: `CHECK (octet_length(data::text) <= 10485760)`

- `elnota_daily_backups_pkey`: `PRIMARY KEY (user_id)`

- `elnota_daily_backups_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES elnota_accounts(user_id) ON DELETE CASCADE`

### public.elnota_device_backup_files

RLS: enabled; forced: false; owner: postgres.

| Column | PostgreSQL type | Nullable | Default / generated expression |
|---|---|---|---|
| id | `uuid` | No |  |
| user_id | `uuid` | No |  |
| device_id | `uuid` | No |  |
| backup_day | `date` | No |  |
| captured_at | `timestamp with time zone` | No |  |
| uploaded_at | `timestamp with time zone` | No | `clock_timestamp()` |
| data | `jsonb` | No |  |
| size_bytes | `integer` | Yes | Generated: `octet_length((data)::text)` |

- `elnota_device_backup_files_data_check`: `CHECK (octet_length(data::text) <= 10485760)`

- `elnota_device_backup_files_pkey`: `PRIMARY KEY (id)`

- `elnota_device_backup_files_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES elnota_accounts(user_id) ON DELETE CASCADE`

### public.elnota_requests

RLS: enabled; forced: false; owner: postgres.

| Column | PostgreSQL type | Nullable | Default / generated expression |
|---|---|---|---|
| id | `uuid` | No | `gen_random_uuid()` |
| user_id | `uuid` | No |  |
| plan | `text` | No |  |
| amount | `integer` | Yes | Generated: ` CASE plan     WHEN 'basic'::text THEN 1000     WHEN 'cloud_month'::text THEN 50     ELSE 500 END` |
| phone | `text` | No |  |
| reference | `text` | No |  |
| status | `text` | No | `'pending'::text` |
| created_at | `timestamp with time zone` | No | `now()` |
| reviewed_at | `timestamp with time zone` | Yes |  |
| reviewed_by | `uuid` | Yes |  |
| submitted_email | `text` | Yes |  |
| submitted_business_name | `text` | Yes |  |

- `elnota_requests_phone_check`: `CHECK (length(phone) >= 7 AND length(phone) <= 30)`

- `elnota_requests_pkey`: `PRIMARY KEY (id)`

- `elnota_requests_plan_check`: `CHECK (plan = ANY (ARRAY['basic'::text, 'cloud_month'::text, 'cloud_year'::text]))`

- `elnota_requests_reference_check`: `CHECK (length(reference) >= 3 AND length(reference) <= 500)`

- `elnota_requests_reviewed_by_fkey`: `FOREIGN KEY (reviewed_by) REFERENCES auth.users(id)`

- `elnota_requests_status_check`: `CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]))`

- `elnota_requests_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES elnota_accounts(user_id)`

## Callable functions and internal functions

| Schema | Function | Arguments | Returns | Security definer |
|---|---|---|---|---|
| elnota_private | guard_account_state | `` | `trigger` | false |
| elnota_private | is_admin | `` | `boolean` | true |
| elnota_private | manage_account | `target_user uuid, operation text` | `void` | true |
| elnota_private | midnight_cloud_snapshot | `` | `integer` | true |
| elnota_private | stamp_activation_sender | `` | `trigger` | true |
| elnota_private | upload_device_backup | `expected_user uuid, backup_id uuid, device_id uuid, backup_day date, captured_at timestamp with time zone, payload jsonb` | `jsonb` | true |
| public | elnota_daily_snapshot | `` | `timestamp with time zone` | true |
| public | elnota_is_admin | `` | `boolean` | false |
| public | elnota_manage_account | `target_user uuid, operation text` | `void` | false |
| public | elnota_manage_cloud | `target_user uuid, plan text` | `timestamp with time zone` | true |
| public | elnota_register | `business text` | `elnota_accounts` | true |
| public | elnota_restore_daily | `target_user uuid, expected_revision bigint` | `bigint` | true |
| public | elnota_review | `request_id uuid, approve boolean` | `void` | true |
| public | elnota_set_printing | `target_user uuid, enabled boolean` | `void` | true |
| public | elnota_sync | `payload jsonb, expected_revision bigint` | `bigint` | true |
| public | elnota_upload_device_backup | `expected_user uuid, backup_id uuid, device_id uuid, backup_day date, captured_at timestamp with time zone, payload jsonb` | `jsonb` | false |

Full function definitions and exact grants are in the SQL reference. Private schema functions are internal, not direct Flutter API entry points. Review public wrapper definitions and grants before calling RPCs.

## RLS policies

### cron.job: cron_job_policy

Command: ALL. Roles: public. Mode: PERMISSIVE.

```sql
USING: (username = CURRENT_USER)
WITH CHECK: (none)
```

### cron.job_run_details: cron_job_run_details_policy

Command: ALL. Roles: public. Mode: PERMISSIVE.

```sql
USING: (username = CURRENT_USER)
WITH CHECK: (none)
```

### public.elnota_accounts: accounts_read

Command: SELECT. Roles: authenticated. Mode: PERMISSIVE.

```sql
USING: ((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT elnota_private.is_admin() AS is_admin))
WITH CHECK: (none)
```

### public.elnota_backups: backups_read

Command: SELECT. Roles: authenticated. Mode: PERMISSIVE.

```sql
USING: (user_id = ( SELECT auth.uid() AS uid))
WITH CHECK: (none)
```

### public.elnota_catalog_imports: catalog_imports_owner_read

Command: SELECT. Roles: authenticated. Mode: PERMISSIVE.

```sql
USING: ((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM elnota_accounts a
  WHERE ((a.user_id = elnota_catalog_imports.user_id) AND (a.activated_at IS NOT NULL)))))
WITH CHECK: (none)
```

### public.elnota_cloud: cloud_admin_read

Command: SELECT. Roles: authenticated. Mode: PERMISSIVE.

```sql
USING: ( SELECT elnota_private.is_admin() AS is_admin)
WITH CHECK: (none)
```

### public.elnota_cloud: cloud_read

Command: SELECT. Roles: authenticated. Mode: PERMISSIVE.

```sql
USING: (user_id = ( SELECT auth.uid() AS uid))
WITH CHECK: (none)
```

### public.elnota_daily_backups: daily_read

Command: SELECT. Roles: authenticated. Mode: PERMISSIVE.

```sql
USING: ((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT elnota_private.is_admin() AS is_admin))
WITH CHECK: (none)
```

### public.elnota_device_backup_files: owner_or_admin_read

Command: SELECT. Roles: authenticated. Mode: PERMISSIVE.

```sql
USING: ((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT elnota_private.is_admin() AS is_admin))
WITH CHECK: (none)
```

### public.elnota_requests: requests_insert

Command: INSERT. Roles: authenticated. Mode: PERMISSIVE.

```sql
USING: (none)
WITH CHECK: ((user_id = ( SELECT auth.uid() AS uid)) AND (status = 'pending'::text) AND (reviewed_at IS NULL) AND (reviewed_by IS NULL))
```

### public.elnota_requests: requests_read

Command: SELECT. Roles: authenticated. Mode: PERMISSIVE.

```sql
USING: ((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT elnota_private.is_admin() AS is_admin))
WITH CHECK: (none)
```

## Views

### public.elnota_latest_device_backups

Options: security_invoker=true.

```sql
 SELECT DISTINCT ON (user_id) user_id,
    id,
    backup_day,
    captured_at,
    uploaded_at,
    size_bytes
   FROM elnota_device_backup_files
  ORDER BY user_id, uploaded_at DESC, id DESC;
```

## Scheduler

`elnota-midnight-cairo`: `0 * * * *`, active=true. Executes `select elnota_private.midnight_cloud_snapshot();`. The hourly UTC job checks Cairo local midnight inside the function; it only copies data already present on the server.

## Applied migrations

| Version | Name |
|---|---|
| 20261014045804 | elnota_initial |
| 20261014131129 | account_catalog_imports |
| 20261018113753 | account_printing_permission |
| 20261018114801 | daily_cloud_backups_and_subscriptions |
| 20261019162930 | midnight_backups |
| 20261019164416 | admin_account_controls |

## All schema inventory

| Schema | Tables | Views |
|---|---|---|
| auth | 27 | 0 |
| cron | 2 | 0 |
| elnota_private | 2 | 0 |
| extensions | 0 | 2 |
| graphql | 0 | 0 |
| graphql_public | 0 | 0 |
| public | 7 | 1 |
| realtime | 3 | 0 |
| storage | 8 | 0 |
| supabase_migrations | 1 | 0 |
| vault | 1 | 1 |

