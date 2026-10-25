-- Release distribution only. No legacy tables, customer rows or Auth settings.
create table public.elnota_app_releases (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform in ('android','windows','ios')),
  version text not null check (version ~ '^[0-9]+\.[0-9]+\.[0-9]+([-+][a-zA-Z0-9.-]+)?$'),
  distribution text not null check (distribution in ('file','store')),
  url text not null,
  notes text not null default '',
  published boolean not null default false,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  constraint release_url check (
    (distribution='file' and platform in ('android','windows') and (
      url ~ '^https://fsmoerttftxcuxpswufk\.supabase\.co/storage/v1/object/public/elnota-app-releases/(android|windows)/[a-zA-Z0-9/._-]+$' or
      url ~ '^https://github\.com/tranzillofficial/elnotaapp/releases/download/[a-zA-Z0-9/._-]+$')) or
    (distribution='store' and platform='android' and url ~ '^https://play\.google\.com/store/apps/details\?id=[a-zA-Z0-9._]+$') or
    (distribution='store' and platform='ios' and url ~ '^https://apps\.apple\.com/[a-zA-Z0-9/._?-]+$')
  )
);
create unique index elnota_release_published_platform on public.elnota_app_releases(platform) where published;
alter table public.elnota_app_releases enable row level security;
revoke all on public.elnota_app_releases from anon, authenticated;
grant select on public.elnota_app_releases to anon, authenticated;
create policy release_public_read on public.elnota_app_releases for select to anon, authenticated using (published or (select public.elnota_is_admin()));

create function public.elnota_publish_release(p_platform text, p_version text, p_distribution text, p_url text, p_notes text default '')
returns uuid language plpgsql security definer set search_path='' as $$
declare new_id uuid;
begin
  if auth.uid() is null or not public.elnota_is_admin() then raise exception 'Admin required' using errcode='42501'; end if;
  if length(p_notes)>8000 then raise exception 'Release notes too long'; end if;
  perform pg_advisory_xact_lock(hashtext('elnota-release-' || p_platform));
  update public.elnota_app_releases set published=false where platform=p_platform and published;
  insert into public.elnota_app_releases(platform,version,distribution,url,notes,published,created_by)
  values(p_platform,p_version,p_distribution,p_url,p_notes,true,auth.uid()) returning id into new_id;
  return new_id;
end $$;
revoke all on function public.elnota_publish_release(text,text,text,text,text) from public, anon;
grant execute on function public.elnota_publish_release(text,text,text,text,text) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit) values('elnota-app-releases','elnota-app-releases',true,52428800);
create policy release_admin_upload on storage.objects for insert to authenticated with check (
  bucket_id='elnota-app-releases' and (select public.elnota_is_admin()) and
  name ~ '^(android|windows)/[0-9]+/elnota-[a-zA-Z0-9.+-]+\.(apk|exe|msi|zip)$'
);
-- No overwrite/delete grants. Earlier releases remain recoverable.
