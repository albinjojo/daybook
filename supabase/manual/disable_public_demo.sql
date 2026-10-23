-- Revoke demo access without deleting records.
begin;
drop policy if exists daybook_demo_read on public.accounts;
drop policy if exists daybook_demo_add on public.accounts;
drop policy if exists daybook_demo_edit on public.accounts;
drop policy if exists daybook_demo_read on public.transactions;
drop policy if exists daybook_demo_add on public.transactions;
drop policy if exists daybook_demo_edit on public.transactions;
revoke all on public.accounts, public.transactions from anon;
revoke insert (id,name,icon,is_archived), update (name,icon,is_archived) on public.accounts from anon;
revoke insert (id,account_id,type,amount_paise,name,transaction_date,custom_details),
  update (type,amount_paise,name,transaction_date,custom_details,is_deleted) on public.transactions from anon;
revoke all on function public.daybook_valid_details(jsonb),
  public.daybook_filtered_transactions(uuid,date,date,text,text),
  public.daybook_history(uuid,date,date,text,text,integer,integer) from anon;
notify pgrst, 'reload schema';
commit;
