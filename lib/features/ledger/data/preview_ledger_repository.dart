import '../domain/ledger_models.dart';
import '../domain/ledger_repository.dart';

/// Explicit design-preview storage only. Never used as a live-data fallback.
class PreviewLedgerRepository implements LedgerRepository {
  PreviewLedgerRepository({DateTime? today}) {
    final now = today ?? DateTime.now();
    for (final name in ['Innova', 'Kia Carens', 'Etios', 'Office']) {
      accounts.add(
        LedgerAccount(
          id: name,
          name: name,
          icon: name == 'Office' ? 'account' : 'vehicle',
          isArchived: false,
          version: 1,
        ),
      );
    }
    final samples = [
      (
        'Chennai airport trip',
        650000,
        23,
        EntryType.received,
        'Customer',
        'Mr. Suresh',
      ),
      ('Diesel', 320000, 22, EntryType.spent, 'Place', 'Indian Oil, Adyar'),
      (
        'Pondicherry weekend trip',
        1800000,
        20,
        EntryType.received,
        'Customer',
        'Arun & family',
      ),
      (
        'Oil change & service',
        485000,
        18,
        EntryType.spent,
        'Workshop',
        'Toyota service centre',
      ),
      ('Driver allowance', 150000, 18, EntryType.spent, 'Driver', 'Ramesh'),
      (
        'Monthly office pickup',
        3200000,
        15,
        EntryType.received,
        'Customer',
        'Sundaram office',
      ),
    ];
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      entries.add(
        LedgerEntry(
          id: 'sample-$i',
          accountId: 'Innova',
          version: 1,
          draft: EntryDraft(
            type: s.$4,
            amount: Money.fromPaise(s.$2),
            name: s.$1,
            date: dateOnly(DateTime(now.year, now.month, s.$3)),
            details: [CustomDetail(label: s.$5, value: s.$6)],
          ),
        ),
      );
    }
  }
  final accounts = <LedgerAccount>[];
  final entries = <LedgerEntry>[];
  @override
  Future<List<LedgerAccount>> listAccounts({
    bool includeArchived = false,
  }) async => accounts.where((a) => includeArchived || !a.isArchived).toList();
  @override
  Future<LedgerAccount> createAccount({
    required String id,
    required String name,
    String icon = 'account',
  }) async {
    if (accounts.any((a) => a.id == id)) {
      throw const LedgerFailure(
        'duplicate',
        'This account already exists. Refresh your accounts.',
      );
    }
    final a = LedgerAccount(
      id: id,
      name: checkedName(name, 100),
      icon: icon,
      isArchived: false,
      version: 1,
    );
    accounts.add(a);
    return a;
  }

  @override
  Future<LedgerAccount> updateAccount(
    LedgerAccount account, {
    required String name,
    required String icon,
    required bool archived,
  }) async {
    final i = accounts.indexWhere(
      (a) => a.id == account.id && a.version == account.version,
    );
    if (i < 0) {
      throw const LedgerFailure(
        'conflict',
        'This account changed. Refresh and try again.',
      );
    }
    return accounts[i] = LedgerAccount(
      id: account.id,
      name: checkedName(name, 100),
      icon: icon,
      isArchived: archived,
      version: account.version + 1,
    );
  }

  @override
  Future<LedgerEntry> createEntry({
    required String id,
    required String accountId,
    required EntryDraft draft,
  }) async {
    if (entries.any((e) => e.id == id)) {
      throw const LedgerFailure(
        'duplicate',
        'This entry already exists. Refresh your entries.',
      );
    }
    final e = LedgerEntry(
      id: id,
      accountId: accountId,
      draft: draft,
      version: 1,
    );
    entries.add(e);
    return e;
  }

  @override
  Future<LedgerEntry> updateEntry(LedgerEntry entry, EntryDraft draft) async {
    final i = entries.indexWhere(
      (e) => e.id == entry.id && e.version == entry.version,
    );
    if (i < 0 || deletedIds.contains(entry.id)) {
      throw const LedgerFailure(
        'conflict',
        'This entry changed. Refresh and try again.',
      );
    }
    return entries[i] = LedgerEntry(
      id: entry.id,
      accountId: entry.accountId,
      draft: draft,
      version: entry.version + 1,
    );
  }

  @override
  Future<LedgerEntry> setEntryDeleted(
    LedgerEntry entry, {
    required bool deleted,
  }) async {
    final i = entries.indexWhere(
      (e) =>
          e.id == entry.id &&
          e.accountId == entry.accountId &&
          e.version == entry.version,
    );
    if (i < 0 || deletedIds.contains(entry.id) == deleted) {
      throw const LedgerFailure(
        'conflict',
        'This entry changed. Refresh and try again.',
      );
    }
    if (deleted) {
      deletedIds.add(entry.id);
    } else {
      deletedIds.remove(entry.id);
    }
    return entries[i] = LedgerEntry(
      id: entry.id,
      accountId: entry.accountId,
      draft: entry.draft,
      version: entry.version + 1,
    );
  }

  final deletedIds = <String>{};
  @override
  Future<HistoryPage> history(
    HistoryFilter filter, {
    int limit = 50,
    int offset = 0,
  }) async {
    final matching =
        entries
            .where(
              (e) =>
                  !deletedIds.contains(e.id) &&
                  e.accountId == filter.accountId &&
                  e.draft.date.compareTo(filter.startDate) >= 0 &&
                  e.draft.date.compareTo(filter.endDate) < 0 &&
                  (filter.type == null || filter.type == e.draft.type) &&
                  [
                        e.draft.name,
                        e.draft.amount.rupees,
                        ...e.draft.details.expand((d) => [d.label, d.value]),
                      ]
                      .join(' ')
                      .toLowerCase()
                      .contains(filter.search.toLowerCase()),
            )
            .toList()
          ..sort((a, b) {
            final d = b.draft.date.compareTo(a.draft.date);
            return d == 0 ? b.id.compareTo(a.id) : d;
          });
    BigInt total(EntryType type) => matching
        .where((e) => e.draft.type == type)
        .fold(BigInt.zero, (sum, e) => sum + BigInt.from(e.draft.amount.paise));
    final received = total(EntryType.received), spent = total(EntryType.spent);
    return HistoryPage.fromJson({
      'entries': matching
          .skip(offset)
          .take(limit)
          .map(
            (e) => {
              'id': e.id,
              'account_id': e.accountId,
              'version': e.version,
              ...e.draft.toJson(),
            },
          )
          .toList(),
      'count': matching.length,
      'received_paise': '$received',
      'spent_paise': '$spent',
      'balance_paise': '${received - spent}',
    });
  }
}
