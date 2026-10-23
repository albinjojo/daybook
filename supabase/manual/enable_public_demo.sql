-- OPTIONAL: deliberately public, unauthenticated DEMO access.
-- Anyone with the project URL + publishable key can read, add and edit ALL data.
-- This is not private local storage. Use only disposable test records.
-- Do not run this against real financial records.
begin;
grant usage on schema public to anon;
grant select on public.accounts, public.transactions to anon;
grant insert (id,name,icon,is_archived) on public.accounts to anon;
grant update (name,icon,is_archived) on public.accounts to anon;
grant insert (id,account_id,type,amount_paise,name,transaction_date,custom_details)
  on public.transactions to anon;
grant update (type,amount_paise,name,transaction_date,custom_details,is_deleted)
  on public.transactions to anon;
create policy daybook_demo_read on public.accounts for select to anon using (true);
create policy daybook_demo_add on public.accounts for insert to anon with check (true);
create policy daybook_demo_edit on public.accounts for update to anon using (true) with check (true);
create policy daybook_demo_read on public.transactions for select to anon using (true);
create policy daybook_demo_add on public.transactions for insert to anon with check (true);
create policy daybook_demo_edit on public.transactions for update to anon using (true) with check (true);
grant execute on function public.daybook_valid_details(jsonb),
  public.daybook_filtered_transactions(uuid,date,date,text,text),
  public.daybook_history(uuid,date,date,text,text,integer,integer) to anon;
notify pgrst, 'reload schema';
commit;
