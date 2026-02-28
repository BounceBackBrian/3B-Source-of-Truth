begin;

create extension if not exists pgcrypto;

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  user_id uuid references auth.users(id) on delete set null,
  name text not null,
  email text not null,
  phone text,
  business_name text,
  website text,
  need text not null,
  timeline text not null,
  budget_range text,
  domain_help boolean not null default false,
  domain_name text,
  business_context text,
  message text not null,
  source text not null default 'start',
  user_agent text,
  ip_hash text,
  status text not null default 'new' check (status in ('new','triaged','contacted','won','lost')),
  notes text
);

alter table public.leads
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists user_id uuid references auth.users(id) on delete set null,
  add column if not exists phone text,
  add column if not exists business_name text,
  add column if not exists website text,
  add column if not exists need text,
  add column if not exists timeline text,
  add column if not exists budget_range text,
  add column if not exists domain_help boolean not null default false,
  add column if not exists domain_name text,
  add column if not exists business_context text,
  add column if not exists source text not null default 'start',
  add column if not exists user_agent text,
  add column if not exists ip_hash text,
  add column if not exists status text not null default 'new',
  add column if not exists notes text;

update public.leads set need = coalesce(need, 'Website + Branding') where need is null;
update public.leads set timeline = coalesce(timeline, 'Not sure yet') where timeline is null;

alter table public.leads alter column need set not null;
alter table public.leads alter column timeline set not null;

alter table public.leads drop constraint if exists leads_status_check;
alter table public.leads add constraint leads_status_check
  check (status in ('new','triaged','contacted','won','lost'));

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists leads_set_updated_at on public.leads;
create trigger leads_set_updated_at
before update on public.leads
for each row execute function public.set_updated_at();

create index if not exists leads_created_at_idx on public.leads (created_at desc);
create index if not exists leads_status_idx on public.leads (status);
create index if not exists leads_email_idx on public.leads (email);

alter table public.leads enable row level security;

drop policy if exists leads_public_insert on public.leads;
drop policy if exists leads_admin_read on public.leads;
drop policy if exists leads_public_cannot_read on public.leads;
drop policy if exists leads_public_cannot_insert on public.leads;
drop policy if exists leads_admin_select on public.leads;
drop policy if exists leads_admin_update on public.leads;
drop policy if exists leads_admin_delete on public.leads;

create policy leads_public_cannot_read
on public.leads for select
to public
using (false);

create policy leads_public_cannot_insert
on public.leads for insert
to public
with check (false);

create policy leads_admin_select
on public.leads for select
to authenticated
using (public.is_admin(auth.uid()));

create policy leads_admin_update
on public.leads for update
to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

create policy leads_admin_delete
on public.leads for delete
to authenticated
using (public.is_admin(auth.uid()));

commit;
