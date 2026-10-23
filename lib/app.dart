import 'package:flutter/material.dart';

import 'features/ledger/domain/ledger_repository.dart';
import 'features/ledger/presentation/accounts_screen.dart';
import 'features/ledger/presentation/design.dart';

class DaybookApp extends StatelessWidget {
  const DaybookApp({
    super.key,
    this.repository,
    this.startupError,
    this.preview = false,
  });
  final LedgerRepository? repository;
  final Object? startupError;
  final bool preview;
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
          child: Column(
            children: [
              if (preview)
                const Material(
                  color: Color(0xffe2e7d9),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 7,
                          horizontal: 12,
                        ),
                        child: Text(
                          'DESIGN PREVIEW · SAMPLE DATA · NOT SAVED',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: .7,
                            color: green,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(child: child!),
            ],
          ),
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
