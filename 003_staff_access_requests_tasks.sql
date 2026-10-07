-- Ruoli aziendali, richieste materiali e registro delle attivita ITP.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table public.company_members (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade, username text not null unique,
 role text not null check (role in ('owner','referente','richiedente','itp')), created_at timestamptz not null default now(),
 unique(company_id,user_id)
);
create table public.company_invites (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete cascade,
 invite_code text not null unique, role text not null check (role in ('referente','richiedente','itp')),
 expires_at timestamptz not null default (now()+interval '14 days'), invited_by uuid not null references auth.users(id), created_at timestamptz not null default now()
);
create table public.material_requests (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete cascade,
 requester_id uuid not null references auth.users(id) on delete cascade, requester_name text not null,
 product_type text not null, quantity numeric(14,4) not null check (quantity > 0), unit text not null, reason text not null,
 status text not null default 'In attesa' check (status in ('In attesa','Approvata','Rifiutata')),
 approved_by uuid references auth.users(id), approved_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.work_tasks (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete cascade,
 title text not null, description text, due_date date, status text not null default 'Da fare' check (status in ('Da fare','Completata')),
 created_by uuid not null references auth.users(id), created_by_name text not null default 'Referente', created_at timestamptz not null default now(), completed_at timestamptz
);
create table public.work_logs (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete cascade,
 task_id uuid references public.work_tasks(id) on delete set null, staff_id uuid not null references auth.users(id) on delete cascade,
 staff_name text not null, activity text not null, activity_date date not null default current_date,
 duration_hours numeric(8,2) check (duration_hours is null or duration_hours >= 0), notes text, created_at timestamptz not null default now()
);
create index company_members_user_idx on public.company_members(user_id,company_id);
create index material_requests_company_status_idx on public.material_requests(company_id,status,created_at desc);
create index work_tasks_company_status_idx on public.work_tasks(company_id,status,due_date);
create index work_logs_company_date_idx on public.work_logs(company_id,activity_date desc);

create or replace function private.set_work_task_creator_name()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 select m.username into new.created_by_name
 from public.company_members m
 where m.company_id=new.company_id and m.user_id=new.created_by;
 if new.created_by_name is null then new.created_by_name:='Personale'; end if;
 return new;
end; $$;
revoke all on function private.set_work_task_creator_name() from public,anon,authenticated;
create trigger work_tasks_set_creator_name before insert on public.work_tasks
 for each row execute function private.set_work_task_creator_name();

insert into public.company_members(company_id,user_id,username,role)
select c.id,c.owner_id,regexp_replace(lower(split_part(u.email,'@',1)),'[^a-z0-9._-]','-','g'),'owner' from public.companies c join auth.users u on u.id=c.owner_id
on conflict(company_id,user_id) do nothing;

create or replace function private.has_company_role(p_company_id uuid,p_roles text[])
returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.company_members m where m.company_id=p_company_id and m.user_id=(select auth.uid()) and m.role=any(p_roles))
 or exists(select 1 from public.companies c where c.id=p_company_id and c.owner_id=(select auth.uid()) and 'owner'=any(p_roles));
$$;
revoke all on function private.has_company_role(uuid,text[]) from public,anon;
grant execute on function private.has_company_role(uuid,text[]) to authenticated;

create or replace function private.add_company_owner_member()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.company_members(company_id,user_id,username,role)
 select new.id,new.owner_id,regexp_replace(lower(split_part(u.email,'@',1)),'[^a-z0-9._-]','-','g'),'owner' from auth.users u where u.id=new.owner_id
 on conflict(company_id,user_id) do nothing;
 return new;
end; $$;
create trigger companies_add_owner_member after insert on public.companies for each row execute function private.add_company_owner_member();

create or replace function public.create_company_invite(p_company_id uuid,p_role text)
returns table(invite_code text,role text,expires_at timestamptz) language plpgsql security definer set search_path = '' as $$
declare v_code text:=pg_catalog.replace(pg_catalog.gen_random_uuid()::text,'-',''); v_expiry timestamptz:=pg_catalog.now()+interval '14 days';
begin
 if not private.has_company_role(p_company_id,array['owner','referente']) then raise exception 'Non autorizzato'; end if;
 if p_role not in ('referente','richiedente','itp') then raise exception 'Ruolo non valido'; end if;
 insert into public.company_invites(company_id,invite_code,role,expires_at,invited_by)
 values(p_company_id,v_code,p_role,v_expiry,(select auth.uid()));
 return query select v_code,p_role,v_expiry;
end; $$;
revoke all on function public.create_company_invite(uuid,text) from public,anon;
grant execute on function public.create_company_invite(uuid,text) to authenticated;

create or replace function private.claim_company_invites()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.company_members(company_id,user_id,username,role)
 select i.company_id,new.id,lower(new.raw_user_meta_data->>'username'),i.role
 from public.company_invites i
 where i.invite_code=new.raw_user_meta_data->>'invite_code' and i.expires_at>now()
 on conflict(company_id,user_id) do nothing;
 delete from public.company_invites where invite_code=new.raw_user_meta_data->>'invite_code';
 return new;
end; $$;
create trigger auth_user_claim_company_invites after insert on auth.users for each row execute function private.claim_company_invites();

alter table public.company_members enable row level security;
alter table public.company_invites enable row level security;
alter table public.material_requests enable row level security;
alter table public.work_tasks enable row level security;
alter table public.work_logs enable row level security;
revoke all on public.company_members,public.company_invites,public.material_requests,public.work_tasks,public.work_logs from anon;
grant select,insert,update,delete on public.company_members,public.company_invites,public.material_requests,public.work_tasks,public.work_logs to authenticated;

create policy "member sees own membership" on public.company_members for select to authenticated
 using(user_id=(select auth.uid()) or private.has_company_role(company_id,array['owner','referente']));
create policy "admins manage non-owner memberships" on public.company_members for all to authenticated
 using(private.has_company_role(company_id,array['owner','referente']) and role <> 'owner')
 with check(private.has_company_role(company_id,array['owner','referente']) and role in ('referente','richiedente','itp'));
create policy "admins manage company invitations" on public.company_invites for all to authenticated
 using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));

create policy "members read own company" on public.companies for select to authenticated
 using(private.has_company_role(id,array['owner','referente','richiedente','itp']));
create policy "owner inserts own company" on public.companies for insert to authenticated with check(owner_id=(select auth.uid()));
create policy "admins update company" on public.companies for update to authenticated
 using(private.has_company_role(id,array['owner','referente'])) with check(private.has_company_role(id,array['owner','referente']));

-- Chi non e owner/referente non legge le registrazioni aziendali.
drop policy if exists "owner manages own company" on public.companies;
drop policy if exists "owner manages own seasons" on public.seasons;
drop policy if exists "owner manages own parcels" on public.parcels;
drop policy if exists "owner manages own crop plans" on public.crop_plans;
drop policy if exists "owner manages own field operations" on public.field_operations;
drop policy if exists "owner manages own register entries" on public.register_entries;
drop policy if exists "owner manages own sales" on public.sales;
drop policy if exists "owner manages own farm products" on public.farm_products;
drop policy if exists "owner manages own equipment" on public.equipment;
drop policy if exists "owner manages own equipment maintenance" on public.equipment_maintenance;
drop policy if exists "owner manages own maintenance materials" on public.maintenance_materials;
create policy "admins manage seasons" on public.seasons for all to authenticated using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
create policy "admins manage parcels" on public.parcels for all to authenticated using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
create policy "admins manage crop plans" on public.crop_plans for all to authenticated using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
create policy "admins manage field operations" on public.field_operations for all to authenticated using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
create policy "admins manage register entries" on public.register_entries for all to authenticated using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
create policy "admins manage sales" on public.sales for all to authenticated using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
create policy "admins manage farm products" on public.farm_products for all to authenticated using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
create policy "admins manage equipment" on public.equipment for all to authenticated using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
create policy "admins manage equipment maintenance" on public.equipment_maintenance for all to authenticated using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
create policy "admins manage maintenance materials" on public.maintenance_materials for all to authenticated using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));

create policy "users read own material requests" on public.material_requests for select to authenticated
 using((requester_id=(select auth.uid()) and private.has_company_role(company_id,array['richiedente'])) or private.has_company_role(company_id,array['owner','referente']));
create policy "requesters create own material requests" on public.material_requests for insert to authenticated
 with check(requester_id=(select auth.uid()) and status='In attesa' and approved_by is null and private.has_company_role(company_id,array['richiedente']));
create policy "admins review material requests" on public.material_requests for update to authenticated
 using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
create policy "admins remove material requests" on public.material_requests for delete to authenticated
 using(private.has_company_role(company_id,array['owner','referente']));

create policy "staff read tasks" on public.work_tasks for select to authenticated using(private.has_company_role(company_id,array['owner','referente','itp','richiedente']));
create policy "admins manage tasks" on public.work_tasks for all to authenticated
 using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
create policy "staff create tasks" on public.work_tasks for insert to authenticated
 with check(created_by=(select auth.uid()) and status='Da fare' and private.has_company_role(company_id,array['itp','richiedente']));
create policy "admins and author read work logs" on public.work_logs for select to authenticated
 using((staff_id=(select auth.uid()) and private.has_company_role(company_id,array['itp','richiedente'])) or private.has_company_role(company_id,array['owner','referente']));
create policy "staff records own work" on public.work_logs for insert to authenticated
 with check(staff_id=(select auth.uid()) and private.has_company_role(company_id,array['itp','richiedente'])
 and (task_id is null or exists(select 1 from public.work_tasks t where t.id=task_id and t.company_id=work_logs.company_id)));
create policy "admins manage work logs" on public.work_logs for all to authenticated
 using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
