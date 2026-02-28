create extension if not exists "pgcrypto";

create type app_role as enum ('client','admin');
create type boost_status_type as enum ('active','paused','inactive');
create type subscription_status_type as enum ('active','paused','cancelled','past_due');

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role app_role not null default 'client',
  boost_status boost_status_type not null default 'inactive',
  threeb_id text unique,
  threeb_business_id text,
  stripe_customer_id text unique,
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  client_user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'submitted',
  seo_goals text,
  target_keywords text,
  domain_preference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.project_milestones (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  title text not null,
  due_date date,
  completed boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.project_files (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,
  file_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.tickets (
  id uuid primary key default gen_random_uuid(),
  client_user_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.projects(id) on delete set null,
  subject text not null,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

create table if not exists public.ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);

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

create table if not exists public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  summary text,
  image_url text,
  project_url text,
  is_published boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  stripe_subscription_id text unique not null,
  stripe_customer_id text not null,
  status subscription_status_type not null,
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.boost_events (
  id uuid primary key default gen_random_uuid(),
  stripe_event_id text unique not null,
  stripe_event_type text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_table text,
  target_id text,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin(uid uuid)
returns boolean language sql stable as $$
  select exists(select 1 from public.profiles p where p.id = uid and p.role = 'admin');
$$;

create or replace function public.is_boost_active(uid uuid)
returns boolean language sql stable as $$
  select exists(select 1 from public.profiles p where p.id = uid and p.boost_status = 'active');
$$;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;


alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.project_milestones enable row level security;
alter table public.project_files enable row level security;
alter table public.tickets enable row level security;
alter table public.ticket_messages enable row level security;
alter table public.leads enable row level security;
alter table public.portfolio_items enable row level security;
alter table public.subscriptions enable row level security;
alter table public.boost_events enable row level security;
alter table public.audit_log enable row level security;

drop trigger if exists leads_set_updated_at on public.leads;
create trigger leads_set_updated_at before update on public.leads
for each row execute function public.set_updated_at();

create policy profiles_self_or_admin_select on public.profiles
for select using (id = auth.uid() or public.is_admin(auth.uid()));
create policy profiles_self_or_admin_update on public.profiles
for update using (id = auth.uid() or public.is_admin(auth.uid()))
with check (id = auth.uid() or public.is_admin(auth.uid()));

create policy projects_client_boost_or_admin on public.projects
for all using ((client_user_id = auth.uid() and public.is_boost_active(auth.uid())) or public.is_admin(auth.uid()))
with check ((client_user_id = auth.uid() and public.is_boost_active(auth.uid())) or public.is_admin(auth.uid()));

create policy milestones_client_boost_or_admin on public.project_milestones
for all using (
  public.is_admin(auth.uid()) or exists (
    select 1 from public.projects p where p.id = project_id and p.client_user_id = auth.uid() and public.is_boost_active(auth.uid())
  )
)
with check (
  public.is_admin(auth.uid()) or exists (
    select 1 from public.projects p where p.id = project_id and p.client_user_id = auth.uid() and public.is_boost_active(auth.uid())
  )
);

create policy files_client_boost_or_admin on public.project_files
for all using (
  public.is_admin(auth.uid()) or exists (
    select 1 from public.projects p where p.id = project_id and p.client_user_id = auth.uid() and public.is_boost_active(auth.uid())
  )
)
with check (
  public.is_admin(auth.uid()) or exists (
    select 1 from public.projects p where p.id = project_id and p.client_user_id = auth.uid() and public.is_boost_active(auth.uid())
  )
);

create policy tickets_client_boost_or_admin on public.tickets
for all using ((client_user_id = auth.uid() and public.is_boost_active(auth.uid())) or public.is_admin(auth.uid()))
with check ((client_user_id = auth.uid() and public.is_boost_active(auth.uid())) or public.is_admin(auth.uid()));

create policy ticket_messages_client_boost_or_admin on public.ticket_messages
for all using (
  public.is_admin(auth.uid()) or exists (
    select 1 from public.tickets t where t.id = ticket_id and t.client_user_id = auth.uid() and public.is_boost_active(auth.uid())
  )
)
with check (
  public.is_admin(auth.uid()) or exists (
    select 1 from public.tickets t where t.id = ticket_id and t.client_user_id = auth.uid() and public.is_boost_active(auth.uid())
  )
);

create policy leads_public_cannot_read on public.leads for select to public using (false);
create policy leads_public_cannot_insert on public.leads for insert to public with check (false);
create policy leads_admin_select on public.leads for select to authenticated using (public.is_admin(auth.uid()));
create policy leads_admin_update on public.leads for update to authenticated using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));
create policy leads_admin_delete on public.leads for delete to authenticated using (public.is_admin(auth.uid()));
create policy leads_select_own_boost_active on public.leads for select to authenticated using (auth.uid() is not null and user_id = auth.uid() and public.is_boost_active(auth.uid()));

create policy portfolio_public_read on public.portfolio_items for select using (is_published = true or public.is_admin(auth.uid()));
create policy portfolio_admin_crud on public.portfolio_items
for all using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

create policy subscriptions_admin_read on public.subscriptions
for select using (public.is_admin(auth.uid()));

create policy boost_events_admin_read on public.boost_events
for select using (public.is_admin(auth.uid()));

create policy audit_log_admin_read on public.audit_log
for select using (public.is_admin(auth.uid()));

create policy admin_insert_audit on public.audit_log
for insert with check (public.is_admin(auth.uid()) or auth.uid() is null);
