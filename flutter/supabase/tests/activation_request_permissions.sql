-- Read-only deployment regression check. Does not create/approve requests.
do $$
begin
  assert (select relrowsecurity from pg_class where oid='public.elnota_requests'::regclass),
    'Request RLS must remain enabled';
  assert has_column_privilege('authenticated','public.elnota_requests','phone','INSERT'),
    'Authenticated request submission must be permitted';
  assert not has_column_privilege('authenticated','public.elnota_requests','reviewed_by','INSERT'),
    'Clients must not set the reviewer';
  assert not has_column_privilege('authenticated','public.elnota_requests','reviewed_at','INSERT'),
    'Clients must not set the review timestamp';
  assert not has_table_privilege('authenticated','public.elnota_requests','UPDATE'),
    'Approval must remain behind the admin RPC';
  assert not has_column_privilege('anon','public.elnota_requests','phone','INSERT'),
    'Anonymous submissions must remain blocked';
end $$;
