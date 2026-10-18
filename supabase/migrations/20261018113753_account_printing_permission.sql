alter table public.elnota_accounts add column if not exists printing_enabled boolean not null default false;
-- Account updates remain unavailable to ordinary authenticated users.
create or replace function public.elnota_set_printing(target_user uuid, enabled boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not elnota_private.is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
 if enabled is null then raise exception 'INVALID_PERMISSION'; end if;
 update public.elnota_accounts set printing_enabled=enabled where user_id=target_user;
 if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
end;
$$;
revoke all on function public.elnota_set_printing(uuid,boolean) from public,anon,authenticated;
grant execute on function public.elnota_set_printing(uuid,boolean) to authenticated;
