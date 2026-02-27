begin;

create extension if not exists pgcrypto;

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.memberships (
  user_id uuid not null references auth.users(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  role text not null default 'member',
  created_at timestamptz not null default now(),
  primary key (user_id, business_id)
);

create table if not exists public.admin_override_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.profiles(id) on delete restrict,
  target_user_id uuid not null references public.profiles(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete set null,
  override_type text not null,
  reason text not null,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.admin_override_log
  drop constraint if exists admin_override_expiry_rules;

alter table public.admin_override_log
  add constraint admin_override_expiry_rules
  check (
    (override_type = 'temporary' and expires_at is not null)
    or
    (override_type = 'permanent' and expires_at is null)
  );

alter table public.projects add column if not exists business_id uuid references public.businesses(id) on delete set null;
alter table public.tickets add column if not exists business_id uuid references public.businesses(id) on delete set null;
alter table public.project_files add column if not exists business_id uuid references public.businesses(id) on delete set null;

alter table public.boost_events add column if not exists user_id uuid references public.profiles(id) on delete cascade;
alter table public.boost_events add column if not exists business_id uuid references public.businesses(id) on delete set null;
alter table public.boost_events add column if not exists event_type text;
alter table public.boost_events add column if not exists detail jsonb not null default '{}'::jsonb;

create unique index if not exists boost_events_stripe_event_id_uq
  on public.boost_events (stripe_event_id)
  where stripe_event_id is not null;

create or replace function public.is_member_of_business(bid uuid, uid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where m.business_id = bid
      and m.user_id = uid
  );
$$;

create or replace function public.guard_profile_boost_status_update()
returns trigger
language plpgsql
as $$
begin
  if new.boost_status is distinct from old.boost_status and not public.is_admin(auth.uid()) then
    raise exception 'Only admins/webhooks may change boost_status';
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_boost_status_guard on public.profiles;
create trigger profiles_boost_status_guard
before update on public.profiles
for each row
execute function public.guard_profile_boost_status_update();

alter table public.businesses enable row level security;
alter table public.memberships enable row level security;
alter table public.admin_override_log enable row level security;

alter table public.projects enable row level security;
alter table public.tickets enable row level security;
alter table public.project_files enable row level security;
alter table public.boost_events enable row level security;

-- remove broad self-update policy that allowed boost edits.
drop policy if exists profiles_self_or_admin_update on public.profiles;
drop policy if exists profiles_self_update_limited on public.profiles;
create policy profiles_self_update_limited on public.profiles
for update
using (id = auth.uid() or public.is_admin(auth.uid()))
with check (id = auth.uid() or public.is_admin(auth.uid()));

-- new tenancy tables
drop policy if exists businesses_owner_select on public.businesses;
create policy businesses_owner_select on public.businesses
for select
using (owner_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists businesses_owner_insert on public.businesses;
create policy businesses_owner_insert on public.businesses
for insert
with check (owner_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists memberships_self_or_admin_select on public.memberships;
create policy memberships_self_or_admin_select on public.memberships
for select
using (user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists memberships_admin_manage on public.memberships;
create policy memberships_admin_manage on public.memberships
for all
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists admin_override_log_admin_only on public.admin_override_log;
create policy admin_override_log_admin_only on public.admin_override_log
for all
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

-- strengthen existing client table policies with business scope.
drop policy if exists projects_client_boost_or_admin on public.projects;
create policy projects_client_boost_or_admin on public.projects
for all
using (
  public.is_admin(auth.uid())
  or (
    client_user_id = auth.uid()
    and public.is_boost_active(auth.uid())
    and (business_id is null or public.is_member_of_business(business_id, auth.uid()))
  )
)
with check (
  public.is_admin(auth.uid())
  or (
    client_user_id = auth.uid()
    and public.is_boost_active(auth.uid())
    and (business_id is null or public.is_member_of_business(business_id, auth.uid()))
  )
);

drop policy if exists tickets_client_boost_or_admin on public.tickets;
create policy tickets_client_boost_or_admin on public.tickets
for all
using (
  public.is_admin(auth.uid())
  or (
    client_user_id = auth.uid()
    and public.is_boost_active(auth.uid())
    and (business_id is null or public.is_member_of_business(business_id, auth.uid()))
  )
)
with check (
  public.is_admin(auth.uid())
  or (
    client_user_id = auth.uid()
    and public.is_boost_active(auth.uid())
    and (business_id is null or public.is_member_of_business(business_id, auth.uid()))
  )
);

drop policy if exists files_client_boost_or_admin on public.project_files;
create policy files_client_boost_or_admin on public.project_files
for all
using (
  public.is_admin(auth.uid())
  or exists (
    select 1
    from public.projects p
    where p.id = project_files.project_id
      and p.client_user_id = auth.uid()
      and public.is_boost_active(auth.uid())
      and (p.business_id is null or public.is_member_of_business(p.business_id, auth.uid()))
  )
)
with check (
  public.is_admin(auth.uid())
  or exists (
    select 1
    from public.projects p
    where p.id = project_files.project_id
      and p.client_user_id = auth.uid()
      and public.is_boost_active(auth.uid())
      and (p.business_id is null or public.is_member_of_business(p.business_id, auth.uid()))
  )
);

-- ledger visibility
drop policy if exists boost_events_self_read on public.boost_events;
create policy boost_events_self_read on public.boost_events
for select
using (user_id = auth.uid() or public.is_admin(auth.uid()));

commit;
