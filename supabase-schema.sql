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
