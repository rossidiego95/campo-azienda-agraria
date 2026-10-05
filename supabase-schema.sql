-- Struttura iniziale dell'archivio Campo.
-- Da eseguire nel SQL Editor del proprio progetto Supabase.
-- L'accesso è riservato all'utente autenticato proprietario dei dati.

create extension if not exists pgcrypto;

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  label text not null,
  starts_on date,
  ends_on date,
  created_at timestamptz not null default now(),
  unique (company_id, label),
  unique (id, company_id)
);

create table public.parcels (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  crop text,
  hectares numeric(12,4) not null check (hectares > 0),
  reference text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, company_id)
);

create table public.crop_plans (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  season_id uuid not null,
  parcel_id uuid,
  crop text not null,
  variety text,
  hectares numeric(12,4) not null check (hectares > 0),
  notes text,
  created_at timestamptz not null default now(),
  foreign key (season_id, company_id) references public.seasons(id, company_id) on delete cascade,
  foreign key (parcel_id, company_id) references public.parcels(id, company_id)
);

create table public.field_operations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  season_id uuid,
  parcel_id uuid,
  planned_date date not null,
  operation text not null,
  crop text,
  responsible text,
  notes text,
  status text not null default 'Programmata' check (status in ('Programmata', 'Completata', 'Annullata')),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (season_id, company_id) references public.seasons(id, company_id),
  foreign key (parcel_id, company_id) references public.parcels(id, company_id)
);

-- Struttura comune, filtrabile per campagna, per registrazioni di magazzino,
-- fitosanitari, quaderno di campagna e cantina.
create table public.register_entries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  season_id uuid,
  parcel_id uuid,
  register_type text not null check (register_type in ('magazzino', 'fitosanitari', 'campagna', 'cantina')),
  entry_date date not null default current_date,
  activity text not null,
  product text,
  quantity numeric(14,4),
  unit text,
  lot text,
  location text,
  operator text,
  notes text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (season_id, company_id) references public.seasons(id, company_id),
  foreign key (parcel_id, company_id) references public.parcels(id, company_id)
);

-- Registro commerciale delle vendite per cliente e campagna.
create table public.sales (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  season_id uuid not null,
  sale_date date not null default current_date,
  customer text not null,
  product text not null,
  quantity numeric(14,4) not null check (quantity > 0),
  unit text not null default 'pz',
  unit_price numeric(14,4) not null check (unit_price >= 0),
  total_amount numeric(14,2) generated always as (round(quantity * unit_price, 2)) stored,
  payment_status text not null default 'Da incassare' check (payment_status in ('Da incassare', 'Incassata')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (season_id, company_id) references public.seasons(id, company_id) on delete cascade
);

create index crop_plans_company_season_idx on public.crop_plans(company_id, season_id);
create index field_operations_company_date_idx on public.field_operations(company_id, planned_date);
create index register_entries_company_type_date_idx on public.register_entries(company_id, register_type, entry_date);
create index sales_company_season_date_idx on public.sales(company_id, season_id, sale_date);

alter table public.companies enable row level security;
alter table public.seasons enable row level security;
alter table public.parcels enable row level security;
alter table public.crop_plans enable row level security;
alter table public.field_operations enable row level security;
alter table public.register_entries enable row level security;
alter table public.sales enable row level security;

revoke all on public.companies, public.seasons, public.parcels,
  public.crop_plans, public.field_operations, public.register_entries from anon;
revoke all on public.sales from anon;
grant select, insert, update, delete on public.companies, public.seasons,
  public.parcels, public.crop_plans, public.field_operations,
  public.register_entries, public.sales to authenticated;

create policy "owner manages own company" on public.companies
  for all to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "owner manages own seasons" on public.seasons
  for all to authenticated using (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  )) with check (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  ));

create policy "owner manages own parcels" on public.parcels
  for all to authenticated using (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  )) with check (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  ));

create policy "owner manages own crop plans" on public.crop_plans
  for all to authenticated using (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  )) with check (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  ));

create policy "owner manages own field operations" on public.field_operations
  for all to authenticated using (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  )) with check (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  ));

create policy "owner manages own register entries" on public.register_entries
  for all to authenticated using (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  )) with check (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  ));

create policy "owner manages own sales" on public.sales
  for all to authenticated using (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  )) with check (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  ));
-- Prodotti aziendali, tracciabilita per appezzamento e manutenzioni attrezzature.
create table public.farm_products (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  season_id uuid not null,
  parcel_id uuid not null,
  name text not null,
  harvest_date date not null default current_date,
  quantity numeric(14,4) not null check (quantity > 0),
  unit text not null default 'kg',
  batch text,
  notes text,
  created_at timestamptz not null default now(),
  foreign key (season_id, company_id) references public.seasons(id, company_id) on delete cascade,
  foreign key (parcel_id, company_id) references public.parcels(id, company_id)
);

create table public.equipment (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  category text,
  model text,
  serial_number text,
  notes text,
  created_at timestamptz not null default now(),
  unique (id, company_id)
);

create table public.equipment_maintenance (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  equipment_id uuid,
  equipment_name text not null,
  maintenance_date date not null default current_date,
  description text not null,
  notes text,
  created_at timestamptz not null default now(),
  foreign key (equipment_id) references public.equipment(id) on delete set null
);

create table public.maintenance_materials (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  maintenance_id uuid not null references public.equipment_maintenance(id) on delete cascade,
  product text not null,
  quantity numeric(14,4) not null check (quantity > 0),
  unit text not null,
  created_at timestamptz not null default now()
);

create index farm_products_company_season_idx on public.farm_products(company_id, season_id, harvest_date);
create index equipment_company_idx on public.equipment(company_id, name);
create index equipment_maintenance_company_date_idx on public.equipment_maintenance(company_id, maintenance_date);

alter table public.farm_products enable row level security;
alter table public.equipment enable row level security;
alter table public.equipment_maintenance enable row level security;
alter table public.maintenance_materials enable row level security;
revoke all on public.farm_products, public.equipment, public.equipment_maintenance, public.maintenance_materials from anon;
grant select, insert, update, delete on public.farm_products, public.equipment, public.equipment_maintenance, public.maintenance_materials to authenticated;

create policy "owner manages own farm products" on public.farm_products for all to authenticated
  using (exists (select 1 from public.companies c where c.id=company_id and c.owner_id=(select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id=company_id and c.owner_id=(select auth.uid())));
create policy "owner manages own equipment" on public.equipment for all to authenticated
  using (exists (select 1 from public.companies c where c.id=company_id and c.owner_id=(select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id=company_id and c.owner_id=(select auth.uid())));
create policy "owner manages own equipment maintenance" on public.equipment_maintenance for all to authenticated
  using (exists (select 1 from public.companies c where c.id=company_id and c.owner_id=(select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id=company_id and c.owner_id=(select auth.uid())));
create policy "owner manages own maintenance materials" on public.maintenance_materials for all to authenticated
  using (exists (select 1 from public.companies c where c.id=company_id and c.owner_id=(select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id=company_id and c.owner_id=(select auth.uid())));

-- Registra l'intervento e tutti gli scarichi con una sola transazione: se la
-- giacenza non basta, non viene salvato né l'intervento né alcuno scarico.
create or replace function public.save_equipment_maintenance(
  p_company_id uuid,
  p_equipment_id uuid,
  p_date date,
  p_description text,
  p_notes text,
  p_materials jsonb default '[]'::jsonb
) returns uuid
language plpgsql security invoker set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_equipment_name text;
  v_material jsonb;
  v_product text;
  v_unit text;
  v_quantity numeric;
  v_available numeric;
begin
  if not exists (select 1 from public.companies c where c.id=p_company_id and c.owner_id=(select auth.uid())) then
    raise exception 'Azienda non autorizzata';
  end if;
  select name into v_equipment_name from public.equipment where id=p_equipment_id and company_id=p_company_id;
  if v_equipment_name is null then raise exception 'Attrezzatura non trovata'; end if;
  if jsonb_typeof(coalesce(p_materials,'[]'::jsonb)) <> 'array' then raise exception 'Elenco materiali non valido'; end if;
  perform pg_advisory_xact_lock(hashtext(p_company_id::text));
  insert into public.equipment_maintenance(company_id,equipment_id,equipment_name,maintenance_date,description,notes)
    values(p_company_id,p_equipment_id,v_equipment_name,p_date,nullif(trim(p_description),''),nullif(trim(p_notes),'')) returning id into v_id;
  for v_material in select value from jsonb_array_elements(coalesce(p_materials,'[]'::jsonb)) loop
    v_product := nullif(trim(v_material->>'product'),'');
    v_unit := nullif(trim(v_material->>'unit'),'');
    v_quantity := (v_material->>'quantity')::numeric;
    if v_product is null or v_unit is null or v_quantity is null or v_quantity <= 0 then raise exception 'Materiale o quantità non validi'; end if;
    select coalesce(sum(case when details->>'movement_type'='scarico' then -abs(quantity)
                             when quantity < 0 then quantity else abs(quantity) end),0)
      into v_available from public.register_entries
      where company_id=p_company_id and register_type='magazzino' and product=v_product and coalesce(unit,'')=v_unit;
    if v_available < v_quantity then raise exception 'Giacenza insufficiente per %: disponibili % %',v_product,v_available,v_unit; end if;
    insert into public.maintenance_materials(company_id,maintenance_id,product,quantity,unit)
      values(p_company_id,v_id,v_product,v_quantity,v_unit);
    insert into public.register_entries(company_id,season_id,register_type,entry_date,activity,product,quantity,unit,location,notes,details)
      values(p_company_id,null,'magazzino',p_date,'Scarico manutenzione',v_product,v_quantity,v_unit,v_equipment_name,
             'Manutenzione: '||v_equipment_name,jsonb_build_object('movement_type','scarico','maintenance_id',v_id));
  end loop;
  return v_id;
end;
$$;
revoke all on function public.save_equipment_maintenance(uuid,uuid,date,text,text,jsonb) from public, anon;
grant execute on function public.save_equipment_maintenance(uuid,uuid,date,text,text,jsonb) to authenticated;

-- Migrazione 003: ruoli, richieste materiali e attivita personale.
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
 created_by uuid not null references auth.users(id), created_at timestamptz not null default now(), completed_at timestamptz
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
declare v_code text:=encode(gen_random_bytes(18),'hex'); v_expiry timestamptz:=now()+interval '14 days';
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

create policy "staff read tasks" on public.work_tasks for select to authenticated using(private.has_company_role(company_id,array['owner','referente','itp']));
create policy "admins manage tasks" on public.work_tasks for all to authenticated
 using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
create policy "admins and author read work logs" on public.work_logs for select to authenticated
 using((staff_id=(select auth.uid()) and private.has_company_role(company_id,array['itp'])) or private.has_company_role(company_id,array['owner','referente']));
create policy "itp records own work" on public.work_logs for insert to authenticated
 with check(staff_id=(select auth.uid()) and private.has_company_role(company_id,array['itp'])
 and (task_id is null or exists(select 1 from public.work_tasks t where t.id=task_id and t.company_id=work_logs.company_id)));
create policy "admins manage work logs" on public.work_logs for all to authenticated
 using(private.has_company_role(company_id,array['owner','referente'])) with check(private.has_company_role(company_id,array['owner','referente']));
