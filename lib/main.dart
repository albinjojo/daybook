import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'features/ledger/data/supabase_ledger_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
