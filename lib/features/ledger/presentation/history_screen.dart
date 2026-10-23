import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/ledger_models.dart';
import '../domain/ledger_repository.dart';
import 'design.dart';
import 'entry_sheets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.repository,
    required this.account,
    required this.month,
    required this.type,
    required this.onMonthChanged,
  });
  final LedgerRepository repository;
  final LedgerAccount account;
  final DateTime month;
  final EntryType? type;
  final ValueChanged<DateTime> onMonthChanged;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime month = widget.month;
  final search = TextEditingController();
  Timer? debounce;
  int request = 0;
  HistoryPage? page;
  List<LedgerEntry> entries = [];
  Object? error;
  bool loading = false, exporting = false;
  HistoryFilter get filter => HistoryFilter.month(
    accountId: widget.account.id,
    year: month.year,
    month: month.month,
    type: widget.type,
    search: search.text,
  );
  BigInt get total => widget.type == EntryType.received
      ? page!.receivedPaise
      : widget.type == EntryType.spent
      ? page!.spentPaise
      : page!.balancePaise;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    final token = ++request;
    setState(() {
      error = null;
      loading = true;
      if (!more) {
        entries = [];
        page = null;
      }
    });
    try {
      final result = await widget.repository.history(
        filter,
        offset: more ? entries.length : 0,
      );
      if (mounted && token == request) {
        setState(() {
          entries = [if (more) ...entries, ...result.entries];
          page = result;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted && token == request) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> inspect(LedgerEntry entry) async {
    final edit = await showEntryDetails(context, widget.account, entry);
    if (edit == true && mounted) {
      final result = await showEntryEditor(
        context,
        widget.repository,
        widget.account,
        entry.draft.type,
        entry: entry,
      );
      if (result != null && mounted) {
        month = DateTime.parse(result.draft.date);
        widget.onMonthChanged(month);
        load();
      }
    }
  }

  Future<void> export(BuildContext buttonContext) async {
    if (exporting || loading || page == null) return;
    final snapshot = filter;
    final box = buttonContext.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => exporting = true);
    try {
      final all = <LedgerEntry>[];
      for (var offset = 0; ;) {
        final batch = await widget.repository.history(
          snapshot,
          limit: 100,
          offset: offset,
        );
        all.addAll(batch.entries);
        offset += batch.entries.length;
        if (offset >= batch.count || batch.entries.isEmpty) break;
      }
      final csv = buildCsv(widget.account.name, all);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(csv)),
              mimeType: 'text/csv',
            ),
          ],
          fileNameOverrides: ['daybook-${snapshot.startDate}.csv'],
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export. ${failureMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spent = widget.type == EntryType.spent;
    final color = spent ? red : green;
    return PageFrame(
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            MonthFilter(
              value: month,
              onChanged: (m) {
                debounce?.cancel();
                month = m;
                widget.onMonthChanged(m);
                load();
              },
            ),
            Eyebrow(widget.account.name),
            const SizedBox(height: 9),
            Text(
              widget.type == null
                  ? 'All entries'
                  : spent
                  ? 'Money spent'
                  : 'Money received',
              style: heading(31),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(21),
              decoration: BoxDecoration(
                color: spent ? spentBg : receivedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.type == null ? 'Balance' : 'Total',
                        style: TextStyle(color: color, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        period(month),
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      page == null ? '—' : money(total),
                      style: heading(33, color: color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your transactions',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                if (page != null)
                  Text(
                    '${page!.count}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                Builder(
                  builder: (buttonContext) => TextButton(
                    onPressed: page == null || loading || exporting
                        ? null
                        : () => export(buttonContext),
                    child: Text(
                      exporting ? 'Exporting…' : 'Export CSV',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: search,
              maxLength: 200,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 22),
                hintText: 'Search your entries…',
                counterText: '',
              ),
              onChanged: (_) {
                debounce?.cancel();
                ++request;
                setState(() {
                  page = null;
                  entries = [];
                  loading = true;
                  error = null;
                });
                debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => load(),
                );
              },
            ),
            const SizedBox(height: 9),
            if (error != null)
              Problem(error!, retry: () => load())
            else ...[
              ...entries.map(
                (e) => _EntryRow(entry: e, onTap: () => inspect(e)),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'No entries here yet.\nTry another month or a different search.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.8),
                  ),
                ),
              if (page != null && entries.length < page!.count && !loading)
                OutlinedButton(
                  onPressed: () => load(more: true),
                  child: const Text('Load more'),
                ),
              if (page != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    widget.type == null
                        ? '${page!.count} entries · Received ${money(page!.receivedPaise)}\nSpent ${money(page!.spentPaise)}'
                        : '${page!.count} entries · Total ${money(total)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: muted,
                      height: 1.6,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap});
  final LedgerEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final draft = entry.draft;
    final received = draft.type == EntryType.received;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 21),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: line)),
        ),
        child: Row(
          children: [
            Container(
              width: 33,
              height: 38,
              decoration: BoxDecoration(
                color: received ? receivedBg : spentBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                received ? Icons.south_west : Icons.north_east,
                size: 16,
                color: received ? green : red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${draft.details.isEmpty ? '' : '${draft.details.first.label} · ${draft.details.first.value} · '}${displayDate(draft.date)}',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${received ? '+' : '−'} ${money(BigInt.from(draft.amount.paise))}',
                style: TextStyle(color: received ? green : red, fontSize: 14),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right, size: 15, color: muted),
          ],
        ),
      ),
    );
  }
}

String buildCsv(String account, List<LedgerEntry> entries) {
  String cell(String text) {
    final safe = RegExp(r'^\s*[=+@\-\t\r\n]').hasMatch(text) ? "'$text" : text;
    return '"${safe.replaceAll('"', '""')}"';
  }

  final rows = <List<String>>[
    ['Account', 'Type', 'Name', 'Amount (INR)', 'Date', 'Details'],
    ...entries.map(
      (e) => [
        account,
        e.draft.type.name,
        e.draft.name,
        e.draft.amount.rupees,
        e.draft.date,
        jsonEncode(e.draft.details.map((d) => d.toJson()).toList()),
      ],
    ),
  ];
  return '\uFEFF${rows.map((r) => r.map(cell).join(',')).join('\r\n')}';
}
