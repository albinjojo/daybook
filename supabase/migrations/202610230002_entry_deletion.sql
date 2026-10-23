-- Reversible entry deletion; hard DELETE remains denied.
begin;
alter table public.transactions add column is_deleted boolean not null default false;
create or replace function public.daybook_filtered_transactions(
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
    where not t.is_deleted and t.account_id = p_account_id
      and t.transaction_date >= p_start_date and t.transaction_date < p_end_date
      and (p_type is null or t.type = p_type)
      and (coalesce(btrim(p_search),'') = ''
        or strpos(lower(t.name), lower(btrim(p_search))) > 0
        or strpos((t.amount_paise::numeric / 100)::text, btrim(p_search)) > 0
        or exists (select 1 from jsonb_array_elements(t.custom_details) d
          where strpos(lower(d->>'label'), lower(btrim(p_search))) > 0
             or strpos(lower(d->>'value'), lower(btrim(p_search))) > 0));
end $$;


-- Extend only roles that already have entry-edit access. Closed mode stays closed.
do $$ begin
  if has_column_privilege('anon', 'public.transactions', 'name', 'UPDATE') then
    grant update (is_deleted) on public.transactions to anon;
  end if;
end $$;
notify pgrst, 'reload schema';
commit;
