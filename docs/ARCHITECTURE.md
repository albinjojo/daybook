# Daybook architecture

## Scope

A single-ledger INR expense tracker with independent named accounts. Accounts may
represent vehicles, office expenses, or anything else. No billing, dues, user
registration, or authentication has been implemented. No real financial records
should be entered into the public demo access mode.

## Boundaries

```text
Flutter accounts / dashboard / history / entry sheets
    ↓ injected LedgerRepository interface
Domain models: account, entry, money, custom details, history filter/page
    ↓ SupabaseLedgerRepository
Supabase Data API → accounts / transactions / daybook_history RPC
    ↓ constraints + triggers + grants + row-level security
PostgreSQL storage
```

`lib/config` contains deployment settings. `features/ledger/domain` has no Flutter
or Supabase dependency. `features/ledger/data` is the Supabase adapter. Screens
should receive a `LedgerRepository` through their constructor rather than issuing
SQL or Supabase calls. Create the adapter with `Supabase.instance.client` after
startup. This also permits a local repository later without changing screen logic.

## Database

`accounts`: UUID, name, icon, archive flag, created/updated timestamps, version.

`transactions`: UUID, account foreign key, received/spent type, positive amount in
paise, name, date-only transaction date, JSON custom details, timestamps, version.

Amounts use integer paise (₹10.50 = 1050), not binary floating point. The maximum
entry is ₹9,999,999,999.99. Aggregate totals are returned as strings and parsed to
Dart BigInt so large totals stay exact on the web. Currency is INR throughout;
multiple currencies would require an explicit conversion design.

Custom details are ordered `{label, value}` objects; duplicate labels are allowed.
Each entry supports up to 50 details, labels up to 80 characters, values up to
4000 characters. Names are trimmed, mandatory and bounded. The database enforces
these rules independently of the Flutter forms.

One account has many entries. Foreign keys prevent orphan records and cascading
deletion. Archive hides an account without losing history; restore it before
adding/editing its entries. No hard-delete capability is exposed to the app.
Transactions cannot move between accounts. The database owns timestamps/version.

`daybook_history` returns one page and totals over **all** matching entries in one
database snapshot. Account, date range, type and text search use a shared filter.
The end date is exclusive, so October is October 1 through November 1 excluded.
Search matches names, amounts, and custom labels/values; symbols such as `%` are
literal. Account/date/type indexes support ordinary ledger queries. Substring
search scans that account's date range; add measured search indexing only if needed.
Pagination is deterministic but offset-based: refresh after edits because pages
can shift when new records arrive between separate requests.

Edits include the last-read version; a stale edit returns a conflict rather than
overwriting a newer edit. UUIDs must be generated once per create action and kept
for retries. A repeated ID is rejected, not inserted twice. After an uncertain
network result or duplicate error, refresh and reconcile before creating a new ID.
There is no automatic offline queue or conflict merge yet.

## Access modes

The core migration enables RLS and revokes anonymous/authenticated access to the
new tables and functions. RPCs use `security invoker`, so they cannot bypass RLS.
No owner/user table is created because authentication is deferred by request.

The separately named `manual/enable_public_demo.sql` deliberately grants the
anonymous role read/insert/update access to every record, with limited writable
columns. This is an opt-in development mode, not ownership protection. Anyone with
the project URL and publishable key can use those operations, even outside the app.
`disable_public_demo.sql` revokes access without deleting data. Neither script is
automatically applied by the Flutter app or the core migration.

Before private cloud use, add a recoverable identity/access mechanism. With
Supabase Auth, add ownership to accounts, assign existing records deliberately,
and replace demo policies with account-owner policies. A phone-only local database
with a backup plan is the other option if no cloud identity is desired.

## Current implementation limits

The Flutter screens use the injected repository. Explicit sample preview mode uses an in-memory adapter and never falls back from a failed live connection. The hosted migration is applied and verified; public no-login read/add/edit access is enabled by explicit user approval and verified through Flutter. No offline queue or local persistence is implemented. See UI_WORK_REPORT.md for current verification and running instructions.

## Validation

Run `flutter analyze` and `flutter test` from the project directory.
Run `npm ci --prefix tooling`, then `node tooling/database-test.mjs` to execute the
SQL migration, constraints, queries and access scripts in disposable local
PostgreSQL via PGlite. These tests do not contact the hosted Supabase project.




Entry deletion uses transactions.is_deleted (migration 202610230002). Deleted records are excluded centrally by daybook_filtered_transactions; hard-delete stays denied. Delete/Undo use the same repository boundary and optimistic versions as editing. Undo is offered for 10 seconds; no trash screen is implemented.
