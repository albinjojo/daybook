# Flutter UI implementation report

Date: 23 October 2026
Project: `C:\Users\ASUS\Documents\daybook`

## Implemented

The approved mobile prototype has been rebuilt with native Flutter widgets.
It uses the original ivory, forest green and muted terracotta palette, bundled
DM Sans and Manrope fonts, account cards, vertical summary cards and large buttons.
The normal app connects through the existing Supabase repository and JSON config.

- Independently named accounts; add a vehicle, office or any other account.
- Account dashboard: current month, money received, money spent and balance.
- Month picker shared with history; changes stay consistent when going back.
- Separate received/spent histories and all transactions, with search and pagination.
- Totals cover all matching entries, including those beyond the visible page.
- Bottom sheets for adding accounts, adding transactions, details and editing.
- Required amount and name, editable date defaulting to the phone's current date.
- Optional ordered custom label/value fields with add/remove, including duplicate labels.
- Successful saves refresh totals; failed saves retain input and show a retryable error.
- One UUID per create form, retained across retries; version checks for edits.
- CSV export of all filtered pages through the platform share/download interface.
- Loading, empty, connection and database-setup states; pull to refresh.

## Architecture

`main.dart` chooses the repository and handles startup configuration errors.
`app.dart` owns theme, navigation container and the explicit preview banner.
`features/ledger/presentation` contains independent screens, shared design widgets
and entry sheets. Screens only depend on the `LedgerRepository` interface.
`features/ledger/domain` keeps amounts, validation and filters independent of Flutter.
`features/ledger/data` contains the Supabase adapter and a separate in-memory preview
adapter. No screen issues Supabase calls directly. SQL remains in versioned migrations.

Preview mode is selected explicitly with `DAYBOOK_DEMO=true`; it never activates
because a live request failed. Sample data resets on restart and never reaches Supabase.
The live build does not contain a sample-data fallback.

## Verification

- 12 Flutter tests passed, including navigation/editing, searched totals, creating
  an account at 320px width, successful account-specific saves with custom details,
  failed-save retention and UUID reuse, CSV escaping, exact money/date handling,
  repository filtering, conflict detection and permission errors.
- Flutter analyzer: no issues.
- Live web build and separate sample-data preview build passed.
- Android debug APK built successfully: build/app/outputs/flutter-apk/app-debug.apk.
- Browser inspected at mobile size: accounts, dashboard, expense history, details sheet and edit form.
- Previously established SQL validation: 25 local PGlite checks passed. SQL was not
  changed in this UI implementation.

## Hosted connection status

The initial migration was applied successfully through the signed-in Supabase SQL Editor on 23 October 2026. Both public.accounts and public.transactions were verified with row-level security enabled. The daybook_history function returned an empty result count correctly. No business records were inserted. After explicit user confirmation, enable_public_demo.sql was applied on 23 October 2026. The Flutter app can now read, insert and update accounts and entries using its publishable key. Hard-delete permission is not granted.

Authentication remains deferred as requested. The enabled public demo SQL exposes
the entire ledger for disposable testing; it is not private cloud storage. No new
authentication or access policy was silently introduced.

## Running

Live app:
```powershell
flutter run -d chrome --dart-define-from-file=config/supabase.json
```

Design preview (no credentials or hosted tables required):
```powershell
flutter run -d chrome --dart-define=DAYBOOK_DEMO=true
```

Standalone phone preview:
```powershell
flutter build web --output=build/web-preview --dart-define=DAYBOOK_DEMO=true
Copy-Item tooling/phone-preview.html build/web-preview/phone.html
node tooling/preview-server.cjs build/web-preview 4175
```
Open `http://127.0.0.1:4175/phone.html`. VS Code also has live and preview launch choices.

## Limits

No offline persistence/sync, authentication, attachments, hard delete or account
management UI beyond creation. Existing backend archive/rename APIs remain available
for future screens. Export uses multiple reads, so concurrent external edits can
change rows while exporting; it is not a database snapshot or full backup. The app
has not been tested on a physical Android phone. Release signing/package identity
still require configuration before distribution.



## Live Flutter verification — 23 October 2026

Tested the real Flutter web build against the hosted database (not the HTML
prototype and not the in-memory preview). Created account `TEST ONLY · Supabase check`
and two dummy entries through Flutter. Received INR 1,250.50 with a custom detail;
spent INR 200.25, then edited the expense to INR 225.75 through Flutter's edit sheet.
Reloaded the app completely and reopened the account: received 1,250.50, spent
225.75 and balance 1,024.75 persisted. An independent read of the hosted Data API
confirmed both rows, custom details and expense version 2. The dummy received entry
was then renamed to `DUMMY trip income` to match the ledger-only terminology.
Dummy records remain in the clearly labelled test account for review.

All 12 Flutter tests passed again after the wording change. Public read/add/edit
access is enabled for now at the user's request. This remains a public no-login
configuration; revoke it using supabase/manual/disable_public_demo.sql when needed.

The Android package uses the current development signing key. Physical-device
installation has not been verified. It is a personal testing build, not a
Play Store release with production signing.

Android release-mode APK built successfully (52 MB): releases/Daybook.apk. It connects to the live Supabase project; DAYBOOK_DEMO is not enabled.

Startup configuration fix: ordinary Flutter launches now load config/supabase.json as a bundled asset; paired build-time overrides remain supported. This removes the missing-build-flag startup failure. Public client settings only; no secret keys are bundled.

## Entry deletion

Added Delete entry below Edit entry in the transaction details sheet. The user
confirms the action, then history and totals refresh. A 10-second Undo action
restores the entry. Both operations match account, ID, current version and prior
deleted state, protecting against stale edits. Failed requests show an error.
Deleted records remain in Supabase with is_deleted=true; no permanent DELETE
permission is granted. The history RPC excludes those records from search,
pagination, totals and export. Old installed apps also receive filtered history.
After the Undo message expires, recovery requires a database restore of the flag;
there is no trash screen yet. Archived accounts must be restored before changing
entries, including deletion and Undo.

Migration 202610230002_entry_deletion.sql is applied to the hosted project.
Validation: 17 Flutter tests and 31 local PostgreSQL checks passed; analyzer clean.

Live Flutter verification passed: deleted the existing DUMMY fuel expense, observed zero entries and zero expense total, then used Undo and observed the same entry and INR 225.75 restored. No business records were touched.
