import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'features/ledger/data/preview_ledger_repository.dart';
import 'features/ledger/data/supabase_ledger_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const preview = bool.fromEnvironment('DAYBOOK_DEMO');
  if (preview) {
    runApp(DaybookApp(repository: PreviewLedgerRepository(), preview: true));
    return;
  }
  try {
    final config = await SupabaseConfig.load();
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
    );
    runApp(
      DaybookApp(
        repository: SupabaseLedgerRepository(Supabase.instance.client),
      ),
    );
  } catch (error) {
    runApp(DaybookApp(startupError: error));
  }
}
