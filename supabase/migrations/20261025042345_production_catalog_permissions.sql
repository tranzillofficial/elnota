-- Production additive catalog permission only. No ledger, account activation or legacy cloud rows are modified.
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

