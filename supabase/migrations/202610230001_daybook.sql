-- Apply once through Supabase SQL Editor. This migration is atomic.
-- Access stays closed by default. No login/user tables are created.
begin;

create function public.daybook_valid_details(details jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare item jsonb;
begin
  if jsonb_typeof(details) <> 'array' then return false; end if;
  if jsonb_array_length(details) > 50 then return false; end if;
  for item in select value from jsonb_array_elements(details) loop
    if jsonb_typeof(item) <> 'object'
       or not (item ? 'label' and item ? 'value')
       or jsonb_typeof(item->'label') <> 'string'
       or jsonb_typeof(item->'value') <> 'string'
       or length(btrim(item->>'label')) not between 1 and 80
       or length(item->>'value') > 4000 then return false; end if;
  end loop;
  return true;
end $$;

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 1 and 100),
  icon text not null default 'account' check (length(icon) between 1 and 40),
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete restrict,
  type text not null check (type in ('received', 'spent')),
  -- INR only for this app. 1050 paise = Rs 10.50. Never floating-point money.
  amount_paise bigint not null check (amount_paise between 1 and 999999999999),
  name text not null check (length(btrim(name)) between 1 and 150),
  transaction_date date not null default ((now() at time zone 'Asia/Kolkata')::date),
  custom_details jsonb not null default '[]'::jsonb
    check (public.daybook_valid_details(custom_details)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0)
);

create index accounts_active_name_idx on public.accounts(is_archived, name, id);
create index transactions_account_date_idx
  on public.transactions(account_id, transaction_date desc, created_at desc, id desc);
create index transactions_account_type_date_idx
  on public.transactions(account_id, type, transaction_date desc);

create function public.daybook_before_write()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.name := btrim(new.name);
  if tg_op = 'UPDATE' then
    if new.id <> old.id then raise exception 'Record identity cannot change'; end if;
    new.created_at := old.created_at;
    new.version := old.version + 1;
  else
    new.created_at := now();
    new.version := 1;
  end if;
  new.updated_at := now();
  return new;
end $$;

create trigger accounts_before_write before insert or update on public.accounts
for each row execute function public.daybook_before_write();
create trigger transactions_before_write before insert or update on public.transactions
for each row execute function public.daybook_before_write();

create function public.daybook_check_account()
returns trigger language plpgsql set search_path = '' as $$
declare archived boolean;
begin
  if tg_op = 'UPDATE' and new.account_id <> old.account_id then
    raise exception 'A transaction cannot be moved to another account';
  end if;
  select is_archived into archived from public.accounts where id = new.account_id for share;
  if not found then raise exception 'Account not found'; end if;
  if archived then raise exception 'Restore the account before changing its entries'; end if;
  return new;
end $$;
create trigger transactions_check_account before insert or update on public.transactions
for each row execute function public.daybook_check_account();

-- One filter implementation for both history and totals. End date is exclusive.
-- strpos treats %, _, quotes, and other search text literally.
create function public.daybook_filtered_transactions(
  p_account_id uuid, p_start_date date, p_end_date date,
  p_type text default null, p_search text default ''
) returns setof public.transactions language plpgsql stable security invoker
set search_path = '' as $$
begin
  if p_account_id is null or p_start_date is null or p_end_date is null
     or p_end_date <= p_start_date then raise exception 'Invalid date range or account'; end if;
  if p_type is not null and p_type not in ('received','spent') then
    raise exception 'Invalid transaction type';
  end if;
  if length(coalesce(p_search,'')) > 200 then raise exception 'Search is too long'; end if;
  return query select t.* from public.transactions t
    where t.account_id = p_account_id
      and t.transaction_date >= p_start_date and t.transaction_date < p_end_date
      and (p_type is null or t.type = p_type)
      and (coalesce(btrim(p_search),'') = ''
        or strpos(lower(t.name), lower(btrim(p_search))) > 0
        or strpos((t.amount_paise::numeric / 100)::text, btrim(p_search)) > 0
        or exists (select 1 from jsonb_array_elements(t.custom_details) d
          where strpos(lower(d->>'label'), lower(btrim(p_search))) > 0
             or strpos(lower(d->>'value'), lower(btrim(p_search))) > 0));
end $$;

-- A single response contains the requested page plus totals for ALL matches.
create function public.daybook_history(
  p_account_id uuid, p_start_date date, p_end_date date,
  p_type text default null, p_search text default '',
  p_limit integer default 50, p_offset integer default 0
) returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare result jsonb;
begin
  if p_limit is null or p_limit not between 1 and 100 or p_offset is null or p_offset < 0 then
    raise exception 'Invalid pagination';
  end if;
  with filtered as materialized (
    select * from public.daybook_filtered_transactions(p_account_id,p_start_date,p_end_date,p_type,p_search)
  ), page as (
    select * from filtered order by transaction_date desc, created_at desc, id desc
    limit p_limit offset p_offset
  ), totals as (
    select count(*) as count,
      coalesce(sum(amount_paise) filter (where type = 'received'),0) as received,
      coalesce(sum(amount_paise) filter (where type = 'spent'),0) as spent from filtered
  ) select jsonb_build_object(
    'entries', coalesce((select jsonb_agg(to_jsonb(page) order by transaction_date desc,created_at desc,id desc) from page),'[]'::jsonb),
    'count',totals.count,
    'received_paise',totals.received::text,
    'spent_paise',totals.spent::text,
    'balance_paise',(totals.received-totals.spent)::text
  ) into result from totals;
  return result;
end $$;

alter table public.accounts enable row level security;
alter table public.transactions enable row level security;
revoke all on public.accounts, public.transactions from public, anon, authenticated;
revoke all on function public.daybook_valid_details(jsonb) from public, anon, authenticated;
revoke all on function public.daybook_before_write() from public, anon, authenticated;
revoke all on function public.daybook_check_account() from public, anon, authenticated;
revoke all on function public.daybook_filtered_transactions(uuid,date,date,text,text) from public, anon, authenticated;
revoke all on function public.daybook_history(uuid,date,date,text,text,integer,integer) from public, anon, authenticated;
-- Supabase administrative tools retain access. No secret key goes in the app.
grant all on public.accounts, public.transactions to service_role;
grant execute on function public.daybook_valid_details(jsonb),
  public.daybook_filtered_transactions(uuid,date,date,text,text),
  public.daybook_history(uuid,date,date,text,text,integer,integer) to service_role;
notify pgrst, 'reload schema';
commit;
