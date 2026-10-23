import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../domain/ledger_models.dart';
import '../domain/ledger_repository.dart';
import 'design.dart';

Future<LedgerEntry?> showEntryEditor(
  BuildContext context,
  LedgerRepository repository,
  LedgerAccount account,
  EntryType type, {
  LedgerEntry? entry,
}) => showModalBottomSheet<LedgerEntry>(
  context: context,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  builder: (_) => EntryEditor(
    repository: repository,
    account: account,
    type: type,
    entry: entry,
  ),
);

class EntryEditor extends StatefulWidget {
  const EntryEditor({
    super.key,
    required this.repository,
    required this.account,
    required this.type,
    this.entry,
  });
  final LedgerRepository repository;
  final LedgerAccount account;
  final EntryType type;
  final LedgerEntry? entry;
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _DetailControllers {
  _DetailControllers([String label = '', String value = ''])
    : label = TextEditingController(text: label),
      value = TextEditingController(text: value);
  final TextEditingController label, value;
  void dispose() {
    label.dispose();
    value.dispose();
  }
}

class _EntryEditorState extends State<EntryEditor> {
  final form = GlobalKey<FormState>();
  final id = const Uuid().v4();
  late final amount = TextEditingController(
    text: widget.entry?.draft.amount.rupees ?? '',
  );
  late final name = TextEditingController(text: widget.entry?.draft.name ?? '');
  late DateTime date = widget.entry == null
      ? DateTime.now()
      : DateTime.parse(widget.entry!.draft.date);
  late final details = widget.entry == null
      ? [_DetailControllers()]
      : widget.entry!.draft.details
            .map((d) => _DetailControllers(d.label, d.value))
            .toList();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    amount.dispose();
    name.dispose();
    for (final d in details) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final draft = EntryDraft(
        type: widget.type,
        amount: Money.parse(amount.text),
        name: name.text,
        date: dateOnly(date),
        details: details
            .where(
              (d) =>
                  d.label.text.trim().isNotEmpty ||
                  d.value.text.trim().isNotEmpty,
            )
            .map((d) => CustomDetail(label: d.label.text, value: d.value.text))
            .toList(),
      );
      final result = widget.entry == null
          ? await widget.repository.createEntry(
              id: id,
              accountId: widget.account.id,
              draft: draft,
            )
          : await widget.repository.updateEntry(widget.entry!, draft);
      if (mounted) {
        setState(() => busy = false);
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = failureMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SheetLayout(
    busy: busy,
    children: [
      Eyebrow(
        '${widget.account.name} / ${widget.type == EntryType.received ? 'Money received' : 'Money spent'}',
      ),
      const SizedBox(height: 10),
      Text(
        widget.entry != null
            ? 'Edit entry'
            : widget.type == EntryType.received
            ? 'Note money received'
            : 'Note money spent',
        style: heading(27),
      ),
      const SizedBox(height: 10),
      const Text(
        'Just the essentials. Add more details if you like.',
        style: TextStyle(color: muted, fontSize: 13, height: 1.6),
      ),
      const SizedBox(height: 24),
      Form(
        key: form,
        child: AbsorbPointer(
          absorbing: busy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Amount (₹)'),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('entry-amount'),
                controller: amount,
                style: heading(34),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(hintText: '0'),
                validator: (value) {
                  try {
                    Money.parse(value ?? '');
                    return null;
                  } catch (_) {
                    return 'Enter an amount greater than 0 (up to 2 decimals).';
                  }
                },
              ),
              const SizedBox(height: 20),
              const Text('Name'),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('entry-name'),
                controller: name,
                maxLength: 150,
                decoration: const InputDecoration(
                  hintText: 'What was it for?',
                  counterText: '',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Give this entry a name.'
                    : null,
              ),
              const SizedBox(height: 20),
              const Text('Date'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final value = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2200),
                  );
                  if (value != null && mounted) setState(() => date = value);
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(displayDate(dateOnly(date))),
                    const Icon(Icons.calendar_today_outlined, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Your details'),
              const SizedBox(height: 5),
              const Text(
                'Give each box any name you like.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ...details.map(
                (d) => Padding(
                  key: ObjectKey(d),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: d.label,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            hintText: 'Detail name',
                            counterText: '',
                          ),
                          validator: (v) =>
                              d.value.text.trim().isNotEmpty &&
                                  (v ?? '').trim().isEmpty
                              ? 'Add a name.'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: d.value,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 4000,
                          decoration: const InputDecoration(
                            hintText: 'Write anything…',
                            counterText: '',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() => details.remove(d));
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              d.dispose();
                            });
                          },
                          tooltip: 'Remove detail',
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: details.length >= 50
                      ? null
                      : () => setState(() => details.add(_DetailControllers())),
                  child: const Text('＋ Add another detail'),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(error!, style: const TextStyle(color: red)),
                ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(
                  busy
                      ? 'Saving…'
                      : widget.entry == null
                      ? 'Save entry'
                      : 'Save changes',
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Future<bool?> showEntryDetails(
  BuildContext context,
  LedgerAccount account,
  LedgerEntry entry,
) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  builder: (_) => SheetLayout(
    children: [
      Eyebrow(
        '${account.name} / ${entry.draft.type == EntryType.received ? 'Money received' : 'Money spent'}',
      ),
      const SizedBox(height: 12),
      Text(entry.draft.name, style: heading(27)),
      const SizedBox(height: 20),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          '${entry.draft.type == EntryType.received ? '+' : '−'} ${money(BigInt.from(entry.draft.amount.paise))}',
          style: heading(
            43,
            color: entry.draft.type == EntryType.received ? green : red,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _DetailRow('Date', displayDate(entry.draft.date)),
      ...entry.draft.details.map((d) => _DetailRow(d.label, d.value)),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Edit entry'),
      ),
    ],
  ),
);

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: muted)),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: SelectableText(value, style: const TextStyle(fontSize: 15)),
        ),
      ],
    ),
  );
}

class AccountEditor extends StatefulWidget {
  const AccountEditor({super.key, required this.repository});
  final LedgerRepository repository;
  @override
  State<AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<AccountEditor> {
  final name = TextEditingController();
  final id = const Uuid().v4();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.createAccount(
        id: id,
        name: name.text,
      );
      if (mounted) {
        setState(() => busy = false);
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = failureMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SheetLayout(
    busy: busy,
    children: [
      const Eyebrow('A fresh page'),
      const SizedBox(height: 12),
      Text('Add an account', style: heading(27)),
      const SizedBox(height: 10),
      const Text(
        'A vehicle, your office, or anything you want to track.',
        style: TextStyle(color: muted, height: 1.6),
      ),
      const SizedBox(height: 24),
      const Text('Account name'),
      const SizedBox(height: 8),
      Form(
        key: form,
        child: TextFormField(
          controller: name,
          enabled: !busy,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: 'e.g. Innova, Office, Personal',
            counterText: '',
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter an account name.' : null,
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(error!, style: const TextStyle(color: red)),
        ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? 'Creating…' : 'Create account'),
      ),
    ],
  );
}
