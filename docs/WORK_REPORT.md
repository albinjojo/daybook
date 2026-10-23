# Daybook backend milestone report

Historical backend milestone. For the completed Flutter UI and current status, see [UI_WORK_REPORT.md](UI_WORK_REPORT.md).

Date: 23 October 2026
Project directory: C:\Users\ASUS\Documents\daybook
Supabase project: nneedwxmflhqsbtudmry

## Result

The database schema, Flutter data-access layer, local automated validation, and
installation/architecture documentation are prepared. The hosted database has
NOT been migrated: the available publishable key does not permit administrative
SQL. No real records or hosted permissions were changed.

## Work completed across this project

1. Agreed the product flow: independently named accounts, account dashboard,
   money received/spent/balance, month/search filters, ordered custom details,
   and bottom slide-up entry/detail panels.
2. Built and reviewed the HTML/CSS/JS prototype with the approved ivory/green/red
   visual design, including a mobile account → dashboard → history flow. That
   prototype remains in the separate travel-ledger directory.
3. Created the Flutter Android/web project in the requested directory.
4. Verified Flutter installation. Standard Android licences were already accepted;
   the remaining optional microXR licence was left unaccepted.
5. Added the official Supabase client, build-time JSON configuration, Android
   internet permission and VS Code launch settings. The supplied URL/public key
   previously returned HTTP 200 from Supabase's read-only Auth settings endpoint.
6. Prepared the accounts/transactions schema and indexed account/date/type queries.
7. Added exact paise money storage, required-name/amount validation, ordered JSON
   custom details, date-only entries, database-maintained timestamps and versions.
8. Added a shared-filter history RPC with pagination and full-result totals from
   one database snapshot. Totals are calculated rather than separately stored.
9. Added account archiving, protection against orphan/moved transactions, and
   conflict detection for stale edits. No app hard-delete operation is exposed.
10. Added a repository interface and Supabase adapter. Screens can later use a
    local adapter without embedding backend calls into the UI.
11. Kept authentication deferred. The core schema has closed access; a separate,
    reversible public demo script is available for deliberate no-login testing.

## Architecture decisions

Two business tables are sufficient. Income and expenses share the transactions
 table and differ by type. Accounts have independent UUIDs even when names match.
 No owner_id is added while authentication is deferred; private cloud ownership
 requires a later migration and explicit assignment of any existing records.

Money is stored in integer paise rather than floating-point rupees. Dates are
stored as dates, with Asia/Kolkata used for the database default. Custom details
remain ordered and flexible instead of creating a column for every user label.
Domain models, data access and configuration live in separate directories.

## Verification

- 25 PostgreSQL checks passed locally using PGlite, covering access defaults,
  opt-in/revoked demo access, account separation, dates, totals, search, pagination,
  invalid data, archive behavior, blocked deletion and stale edit versions.
- All 8 Flutter tests passed: 4 domain tests, 3 mocked repository tests, and the
  existing starter widget test.
- Flutter analyzer passed with no issues.
- Flutter web build passed after the backend files were added.

These results validate local code and SQL behavior. They are not a claim that the
schema is deployed, that hosted read/write operations have passed, or that an
Android APK has been built or tested on a phone.

## Remaining work

1. Apply the initial SQL migration in the hosted project's SQL Editor.
2. For disposable no-login tests, explicitly apply the public demo access script.
   Anyone with the project URL/key can then read/add/edit all ledger data. Do not
   use that mode for private financial records. A private access design remains
   required before real cloud use.
3. Port the approved prototype to Flutter and connect its screens to the repository.
4. Verify a live create/read/edit/filter flow after the chosen access setup exists.
5. Add offline storage/sync only if required; it is not implemented now.
6. Arrange backups and verify restoration before real use, then test on an Android
   device and prepare distribution. There is no hosted app deployment yet.

## Apply the backend

Follow docs/DATABASE_SETUP.md. The migration can be pasted directly into Supabase
SQL Editor. The project contains no administrative database credentials.


