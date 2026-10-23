import 'ledger_models.dart';

abstract interface class LedgerRepository {
  Future<List<LedgerAccount>> listAccounts({bool includeArchived = false});

  /// Caller generates one UUID per save attempt and retains it for retries.
  Future<LedgerAccount> createAccount({
    required String id,
    required String name,
    String icon = 'account',
  });
  Future<LedgerAccount> updateAccount(
    LedgerAccount account, {
    required String name,
    required String icon,
    required bool archived,
  });
  Future<LedgerEntry> createEntry({
    required String id,
    required String accountId,
    required EntryDraft draft,
  });
  Future<LedgerEntry> updateEntry(LedgerEntry entry, EntryDraft draft);
  Future<HistoryPage> history(
    HistoryFilter filter, {
    int limit = 50,
    int offset = 0,
  });
}

final class LedgerFailure implements Exception {
  const LedgerFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}
