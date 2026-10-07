-- Avoid pgcrypto schema/search_path differences when generating invitation codes.
create or replace function public.create_company_invite(p_company_id uuid,p_role text)
returns table(invite_code text,role text,expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
 v_code text:=pg_catalog.replace(pg_catalog.gen_random_uuid()::text,'-','');
 v_expiry timestamptz:=pg_catalog.now()+interval '14 days';
begin
 if not private.has_company_role(p_company_id,array['owner','referente']) then raise exception 'Non autorizzato'; end if;
 if p_role not in ('referente','richiedente','itp') then raise exception 'Ruolo non valido'; end if;
 insert into public.company_invites(company_id,invite_code,role,expires_at,invited_by)
 values(p_company_id,v_code,p_role,v_expiry,(select auth.uid()));
 return query select v_code,p_role,v_expiry;
end; $$;
revoke all on function public.create_company_invite(uuid,text) from public,anon;
grant execute on function public.create_company_invite(uuid,text) to authenticated;
