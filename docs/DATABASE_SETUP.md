# Apply the Daybook database

Target project: `nneedwxmflhqsbtudmry`.

Status: initial migration applied and verified on 23 October 2026. Do not rerun it. Public demo read/add/edit access was explicitly approved and enabled on 23 October 2026. Live Flutter saving, editing and reloading passed. Steps below are retained for reference or fresh environments; do not rerun the enable script.

1. Open that project in Supabase and choose SQL Editor → New query.
2. For a fresh database, run `supabase/migrations/202610230001_daybook.sql`, then `supabase/migrations/202610230002_entry_deletion.sql`, in that order, once each.
   It is atomic: any error rolls back this migration. It does not overwrite or
   drop existing tables. If these table names already exist, stop and reconcile
   their schema instead of deleting data or repeatedly running the migration.
3. Check Table Editor for `accounts` and `transactions`, both with RLS enabled.
4. Choose access deliberately. The core setup is closed; the app will report an
   access error. For disposable, no-login testing ONLY, review and run
   `supabase/manual/enable_public_demo.sql` once. This permits public read/add/edit
   access to the entire ledger. Leave it unapplied for private records.
5. To turn off that access, run `supabase/manual/disable_public_demo.sql`.

The publishable key cannot create tables, run migrations, or configure permissions.
No database password or administrative key belongs in Flutter's configuration.

## Check the installation

In SQL Editor:

```sql
select tablename, rowsecurity
from pg_tables
where schemaname = 'public' and tablename in ('accounts', 'transactions');

select policyname, tablename, roles, cmd
from pg_policies
where schemaname = 'public' and tablename in ('accounts', 'transactions');
```

Both tables should show rowsecurity=true. There should be no policies in closed
mode, or three demo policies on each table after explicitly enabling demo mode.

There is no production seed data. Use disposable entries only when checking demo
mode. Date defaults use Asia/Kolkata; dates selected in the app are sent unchanged.

## Backups and changes

Before storing real records, configure an appropriate backup/export and restore
process. Keep future changes as new migrations rather than editing the installed
initial migration. Test restore separately; CSV exports are useful for reading
transactions but are not a full schema/permissions backup.



The entry-deletion migration was applied to this project on 23 October 2026. Do not rerun it. It adds is_deleted and filters deleted entries out of history, totals and CSV exports. Hard DELETE remains denied. Existing records are preserved; the app offers Undo after deleting.

