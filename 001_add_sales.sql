-- Migrazione per aggiungere il registro vendite a un progetto Campo esistente.
-- Incolla questo file nel SQL Editor di Supabase ed eseguilo una sola volta.

create table if not exists public.sales (
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

create index if not exists sales_company_season_date_idx
  on public.sales(company_id, season_id, sale_date);

alter table public.sales enable row level security;
revoke all on public.sales from anon;
grant select, insert, update, delete on public.sales to authenticated;

drop policy if exists "owner manages own sales" on public.sales;
create policy "owner manages own sales" on public.sales
  for all to authenticated using (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  )) with check (exists (
    select 1 from public.companies c where c.id = company_id and c.owner_id = (select auth.uid())
  ));
