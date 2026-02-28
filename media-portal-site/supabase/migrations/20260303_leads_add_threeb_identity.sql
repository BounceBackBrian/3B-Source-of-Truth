begin;

alter table public.leads
  add column if not exists threeb_id text,
  add column if not exists threeb_business_id text;

update public.leads
set threeb_id = coalesce(threeb_id, 'UNKNOWN_3B_ID')
where threeb_id is null;

update public.leads
set threeb_business_id = coalesce(threeb_business_id, 'UNKNOWN_3B_BIZ_ID')
where threeb_business_id is null;

alter table public.leads
  alter column threeb_id set not null,
  alter column threeb_business_id set not null;

create index if not exists leads_threeb_id_idx on public.leads (threeb_id);
create index if not exists leads_threeb_business_id_idx on public.leads (threeb_business_id);

commit;
