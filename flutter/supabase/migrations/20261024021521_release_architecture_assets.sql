-- Architecture download metadata only; customer tables are untouched.
alter table public.elnota_app_releases add column assets jsonb not null default '{}'::jsonb check(jsonb_typeof(assets)='object');
