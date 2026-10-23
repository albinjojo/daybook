import 'package:flutter/material.dart';

import '../domain/ledger_models.dart';
import '../domain/ledger_repository.dart';
import 'design.dart';
import 'entry_sheets.dart';
import 'dashboard_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key, required this.repository});
  final LedgerRepository repository;
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<LedgerAccount>? accounts;
  Object? error;
  int request = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final token = ++request;
    setState(() => error = null);
    try {
      final result = await widget.repository.listAccounts();
      if (mounted && token == request) setState(() => accounts = result);
    } catch (e) {
      if (mounted && token == request) setState(() => error = e);
    }
  }

  Future<void> open(LedgerAccount account) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            DashboardScreen(repository: widget.repository, account: account),
      ),
    );
    if (mounted) load();
  }

  Future<void> add() async {
    final result = await showModalBottomSheet<LedgerAccount>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => AccountEditor(repository: widget.repository),
    );
    if (result != null && mounted) {
      await load();
      if (mounted) open(result);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    accounts: true,
    child: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
        children: [
          const Brand(full: true),
          const SizedBox(height: 51),
          const Eyebrow('Your everyday money book'),
          const SizedBox(height: 12),
          Text('My accounts', style: heading(37)),
          const SizedBox(height: 10),
          const Text(
            'A separate book for everything.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 31),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Eyebrow('Your accounts'),
              Text(
                accounts?.length.toString().padLeft(2, '0') ?? '—',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (error != null)
            Problem(error!, retry: load)
          else if (accounts == null)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (accounts!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Start with a vehicle or any account you’d like to keep.',
                ),
              ),
            ...accounts!.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xffdfe4d7)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => open(a),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: receivedBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              a.icon == 'vehicle'
                                  ? Icons.directions_car_outlined
                                  : Icons.grid_view,
                              size: 21,
                              color: green,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              a.name,
                              style: const TextStyle(fontSize: 17),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: muted,
                            size: 19,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            OutlinedButton(
              onPressed: add,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 22),
                  SizedBox(width: 10),
                  Text('Add account', style: TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 35),
          const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xffdedfcf),
                child: Text('D', style: TextStyle(color: ink, fontSize: 13)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dad’s daybook', style: TextStyle(fontSize: 12)),
                    SizedBox(height: 3),
                    Text(
                      'A little order. Every day.',
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
