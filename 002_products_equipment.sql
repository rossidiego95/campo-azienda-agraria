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
