-- Restore the intended pending-request submission contract.
-- Only client submission columns are writable; approval fields remain protected.
-- Existing RLS and stamp_activation_sender continue to enforce ownership,
-- confirmed identity, suspension checks and status='pending'.
do $$
begin
  if not (select relrowsecurity from pg_class where oid='public.elnota_requests'::regclass) then
    raise exception 'Activation requests require RLS before client inserts';
  end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='elnota_requests' and cmd='INSERT') then
    raise exception 'Activation request insert policy is missing';
  end if;
end $$;
grant insert(user_id,plan,phone,reference,status,submitted_email,submitted_business_name)
on public.elnota_requests to authenticated;
