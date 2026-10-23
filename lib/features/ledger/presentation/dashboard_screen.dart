import 'package:flutter/material.dart';

import '../domain/ledger_models.dart';
import '../domain/ledger_repository.dart';
import 'design.dart';
import 'entry_sheets.dart';
import 'history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.account,
  });
  final LedgerRepository repository;
  final LedgerAccount account;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime month = DateTime.now();
  HistoryPage? summary;
  Object? error;
  int request = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final token = ++request;
    setState(() {
      error = null;
      summary = null;
    });
    try {
      final result = await widget.repository.history(
        HistoryFilter.month(
          accountId: widget.account.id,
          year: month.year,
          month: month.month,
        ),
        limit: 1,
      );
      if (mounted && token == request) setState(() => summary = result);
    } catch (e) {
      if (mounted && token == request) setState(() => error = e);
    }
  }

  Future<void> history(EntryType? type) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(
          repository: widget.repository,
          account: widget.account,
          month: month,
          type: type,
          onMonthChanged: (value) => month = value,
        ),
      ),
    );
    if (mounted) load();
  }

  Future<void> add(EntryType type) async {
    final result = await showEntryEditor(
      context,
      widget.repository,
      widget.account,
      type,
    );
    if (result != null && mounted) {
      month = DateTime.parse(result.draft.date);
      load();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Entry saved')));
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    child: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 23),
          const Eyebrow('Your account'),
          const SizedBox(height: 7),
          Text(widget.account.name, style: heading(35)),
          const SizedBox(height: 6),
          const Text(
            'A clear picture of what came in and what went out.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.5),
          ),
          MonthFilter(
            value: month,
            onChanged: (m) {
              month = m;
              load();
            },
          ),
          if (error != null)
            Problem(error!, retry: load)
          else ...[
            _TotalCard(
              title: 'Money received',
              amount: summary?.receivedPaise,
              hint: 'View received entries',
              color: green,
              background: receivedBg,
              icon: Icons.south_west,
              onTap: () => history(EntryType.received),
            ),
            const SizedBox(height: 10),
            _TotalCard(
              title: 'Money spent',
              amount: summary?.spentPaise,
              hint: 'View expenses',
              color: red,
              background: spentBg,
              icon: Icons.north_east,
              onTap: () => history(EntryType.spent),
            ),
            const SizedBox(height: 10),
            _TotalCard(
              title: 'Balance',
              amount: summary?.balancePaise,
              hint: 'View all entries',
              color: ink,
              background: Colors.white,
              icon: Icons.drag_handle,
              onTap: () => history(null),
            ),
          ],
          const SizedBox(height: 20),
          const Eyebrow('Add an entry'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => add(EntryType.received),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, size: 20),
                SizedBox(width: 10),
                Flexible(child: Text('Money received')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => add(EntryType.spent),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: red,
              side: const BorderSide(color: Color(0xffdfcfc3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.remove_circle_outline, size: 20),
                SizedBox(width: 10),
                Flexible(
                  child: Text('Money spent', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          TextButton(
            onPressed: () => history(null),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'View all entries',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.north_east, size: 17),
              ],
            ),
          ),
          const Divider(color: line),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 17),
            child: Text(
              'A separate book for every vehicle. A clearer day for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: muted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.title,
    required this.amount,
    required this.hint,
    required this.color,
    required this.background,
    required this.icon,
    required this.onTap,
  });
  final String title, hint;
  final BigInt? amount;
  final Color color, background;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: background == spentBg ? const Color(0xffeddfd6) : line,
      ),
    ),
    child: InkWell(
      key: ValueKey('total-card-$title'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount == null ? '—' : money(amount!),
                style: heading(31, color: color),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hint,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: color, size: 20),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
