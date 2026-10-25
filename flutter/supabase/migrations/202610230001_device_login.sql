-- Additive QR device pairing only. Review and stage-test before deployment.
-- Existing ledger documents, accounts, and subscription policies are untouched.
create table if not exists public.elnota_device_links (
  id uuid primary key,
  browser_hash text not null check(length(browser_hash) = 64),
  requester_hash text not null check(length(requester_hash) = 64),
  verification_code text not null check(verification_code ~ '^[0-9]{6}$'),
  browser_label text not null,
  approved_user uuid references auth.users(id) on delete cascade,
  approved_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '3 minutes'
);
alter table public.elnota_device_links enable row level security;
revoke all on public.elnota_device_links from public, anon, authenticated;
grant select, insert, update, delete on public.elnota_device_links to service_role;
create index if not exists device_links_rate on public.elnota_device_links(requester_hash, created_at);

create or replace function public.elnota_create_device_link(p_id uuid, p_browser_hash text, p_requester_hash text, p_code text, p_label text)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(p_requester_hash));
  if (select count(*) from public.elnota_device_links where requester_hash = p_requester_hash and created_at > now() - interval '1 minute') >= 5 then
    raise exception 'Too many attempts';
  end if;
  insert into public.elnota_device_links(id, browser_hash, requester_hash, verification_code, browser_label)
    values(p_id, p_browser_hash, p_requester_hash, p_code, left(p_label, 120));
end;
$$;
revoke all on function public.elnota_create_device_link(uuid,text,text,text,text) from public, anon, authenticated;
grant execute on function public.elnota_create_device_link(uuid,text,text,text,text) to service_role;

create or replace function public.elnota_consume_device_link(p_id uuid, p_browser_hash text)
returns table(approved_user uuid) language sql security invoker set search_path = '' as $$
  update public.elnota_device_links set consumed_at = now()
  where id = p_id and browser_hash = p_browser_hash and approved_user is not null
    and consumed_at is null and expires_at > now()
  returning approved_user;
$$;
revoke all on function public.elnota_consume_device_link(uuid,text) from public, anon, authenticated;
grant execute on function public.elnota_consume_device_link(uuid,text) to service_role;
