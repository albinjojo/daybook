import 'package:flutter/material.dart';

import 'features/ledger/domain/ledger_repository.dart';
import 'features/ledger/presentation/accounts_screen.dart';
import 'features/ledger/presentation/design.dart';

class DaybookApp extends StatelessWidget {
  const DaybookApp({super.key, this.repository, this.startupError});
  final LedgerRepository? repository;
  final Object? startupError;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Daybook',
    debugShowCheckedModeBanner: false,
    theme: daybookTheme(),
    builder: (context, child) => ColoredBox(
      color: const Color(0xffe8ebe3),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: child!,
        ),
      ),
    ),
    home: repository != null
        ? AccountsScreen(repository: repository!)
        : Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Brand(full: true),
                    const SizedBox(height: 30),
                    Text('Let’s finish setting up', style: heading(27)),
                    const SizedBox(height: 12),
                    const Text(
                      'The app could not start its database connection. Check the Supabase configuration and restart the app.',
                      style: TextStyle(color: muted, height: 1.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}
