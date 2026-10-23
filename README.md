# Daybook

A Flutter Android/web app for a single-ledger INR expense tracker with independent
vehicle or other named accounts.

## Configuration

The official Supabase Flutter client initializes before the app starts. Public
connection details stay in `config/supabase.json`, excluded from Git. On another
machine copy `config/supabase.example.json` and fill in the project URL and
publishable key. Never put a secret key or database password in the app.

```powershell
flutter run -d chrome
flutter build web
```

For Android, replace `chrome` with a connected device ID from `flutter devices`.
VS Code launch settings already supply the configuration flag. The Android release
manifest includes internet permission.

## Database and architecture

- `supabase/migrations/202610230001_daybook.sql`: atomic schema migration, closed access by default.
- `supabase/manual/`: explicit public demo enable/disable scripts, outside the migration sequence.
- `lib/features/ledger/domain/`: plain Dart models and repository interface.
- `lib/features/ledger/data/`: Supabase implementation, with filtering and edit conflict handling.
- `docs/DATABASE_SETUP.md`: hosted installation steps and access implications.
- `docs/ARCHITECTURE.md`: data model, boundaries, invariants and limitations.
- `docs/WORK_REPORT.md`: completed work, verification, and remaining steps.

Authentication is intentionally deferred. No-login cloud demo access is public
access to all ledger records; it is not enabled automatically. Use disposable
records only if you explicitly apply the demo-access script.

The Supabase publishable key cannot install this schema. Apply the SQL migration
in the Supabase SQL Editor using the setup guide.

## Validation

```powershell
flutter analyze
flutter test
npm ci --prefix tooling
node tooling/database-test.mjs
```

Database tests use a disposable embedded PostgreSQL runtime (PGlite). They do not
read or write hosted project data. Flutter repository tests use mocked HTTP
responses; live API behavior must still be checked after the migration is applied.

## UI status

The approved HTML/CSS/JS mobile prototype has been ported into Flutter. The app
now provides the account list, monthly dashboard, searchable history and bottom sheets,
connected through the Supabase repository. See `docs/UI_WORK_REPORT.md` for verification, preview commands and the live Supabase verification results. The schema and explicitly approved public demo permissions are now applied.



Normal launches require no configuration flags. The public JSON is bundled as a Flutter asset. Both URL and publishable-key build flags can still override it for another deployment. Never place secret keys in that file.

