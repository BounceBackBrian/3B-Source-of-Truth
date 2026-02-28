-- 3B Media Group Observability v1
-- Adds lead lifecycle event logging on insert/update.

begin;

alter table public.boost_events enable row level security;

create index if not exists idx_boost_events_event_type on public.boost_events (stripe_event_type);
create index if not exists idx_boost_events_created_at on public.boost_events (created_at desc);

create or replace function public.log_lead_submitted()
returns trigger
language plpgsql
as $$
begin
  insert into public.boost_events (stripe_event_id, stripe_event_type, payload)
  values (
    concat('lead_submit_', new.id::text, '_', extract(epoch from now())::bigint::text),
    'lead_submitted',
    jsonb_build_object(
      'lead_id', new.id,
      'user_id', new.user_id,
      'source', coalesce(new.source, 'start'),
      'status', new.status
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_leads_log_submit on public.leads;
create trigger trg_leads_log_submit
after insert on public.leads
for each row execute function public.log_lead_submitted();

create or replace function public.log_lead_updated()
returns trigger
language plpgsql
as $$
declare
  changes jsonb := '{}'::jsonb;
begin
  if new.status is distinct from old.status then
    changes := changes || jsonb_build_object('status_from', old.status, 'status_to', new.status);
  end if;

  if new.notes is distinct from old.notes then
    changes := changes || jsonb_build_object('notes_changed', true);
  end if;

  if changes <> '{}'::jsonb then
    insert into public.boost_events (stripe_event_id, stripe_event_type, payload)
    values (
      concat('lead_update_', new.id::text, '_', extract(epoch from now())::bigint::text),
      'lead_updated',
      changes || jsonb_build_object('lead_id', new.id, 'user_id', new.user_id)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_leads_log_update on public.leads;
create trigger trg_leads_log_update
after update on public.leads
for each row execute function public.log_lead_updated();

commit;
