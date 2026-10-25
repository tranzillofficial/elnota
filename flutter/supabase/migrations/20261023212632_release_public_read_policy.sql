drop policy release_public_read on public.elnota_app_releases;
create policy release_public_read on public.elnota_app_releases for select to anon,authenticated using (published);
create policy release_admin_read on public.elnota_app_releases for select to authenticated using ((select public.elnota_is_admin()));
