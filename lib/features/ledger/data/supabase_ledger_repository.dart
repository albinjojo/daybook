import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ledger_models.dart';
import '../domain/ledger_repository.dart';

/// The only ledger layer that knows about Supabase. Inject a client at startup.
final class SupabaseLedgerRepository implements LedgerRepository {
  const SupabaseLedgerRepository(this._client);
  final SupabaseClient _client;

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw switch (e.code) {
        '42501' => const LedgerFailure(
          'access_denied',
          'Database access is not enabled for this app.',
        ),
        '23505' => const LedgerFailure(
          'duplicate',
          'This save ID already exists. Refresh before retrying.',
        ),
        '23503' => const LedgerFailure(
          'missing_account',
          'The account could not be found.',
        ),
        '23514' => const LedgerFailure(
          'invalid_entry',
          'Check the amount, name and custom details.',
        ),
        'P0001' => LedgerFailure('validation', e.message),
        '42P01' || 'PGRST202' || 'PGRST205' => const LedgerFailure(
          'setup_required',
          'The database setup has not been applied yet.',
        ),
        _ => const LedgerFailure(
          'database_error',
          'The save could not be confirmed. Refresh before retrying.',
        ),
      };
    }
    // Transport failures propagate to the caller. Never show a failed save as saved.
  }

  @override
  Future<List<LedgerAccount>> listAccounts({bool includeArchived = false}) =>
      _request(() async {
        var query = _client.from('accounts').select();
        if (!includeArchived) query = query.eq('is_archived', false);
        final rows = await query.order('name').order('id');
        return rows.map(LedgerAccount.fromJson).toList();
      });

  @override
  Future<LedgerAccount> createAccount({
    required String id,
    required String name,
    String icon = 'account',
  }) => _request(() async {
    final row = await _client
        .from('accounts')
        .insert({
          'id': id,
          'name': checkedName(name, 100),
          'icon': checkedName(icon, 40),
        })
        .select()
        .single();
    return LedgerAccount.fromJson(row);
  });

  @override
  Future<LedgerAccount> updateAccount(
    LedgerAccount account, {
    required String name,
    required String icon,
    required bool archived,
  }) => _request(() async {
    final row = await _client
        .from('accounts')
        .update({
          'name': checkedName(name, 100),
          'icon': checkedName(icon, 40),
          'is_archived': archived,
        })
        .eq('id', account.id)
        .eq('version', account.version)
        .select()
        .maybeSingle();
    if (row == null) {
      throw const LedgerFailure(
        'conflict',
        'This account changed. Refresh and try again.',
      );
    }
    return LedgerAccount.fromJson(row);
  });

  @override
  Future<LedgerEntry> createEntry({
    required String id,
    required String accountId,
    required EntryDraft draft,
  }) => _request(() async {
    final row = await _client
        .from('transactions')
        .insert({'id': id, 'account_id': accountId, ...draft.toJson()})
        .select()
        .single();
    return LedgerEntry.fromJson(row);
  });

  @override
  Future<LedgerEntry> updateEntry(LedgerEntry entry, EntryDraft draft) =>
      _request(() async {
        final row = await _client
            .from('transactions')
            .update(draft.toJson())
            .eq('id', entry.id)
            .eq('account_id', entry.accountId)
            .eq('version', entry.version)
            .select()
            .maybeSingle();
        if (row == null) {
          throw const LedgerFailure(
            'conflict',
            'This entry changed. Refresh and try again.',
          );
        }
        return LedgerEntry.fromJson(row);
      });

  @override
  Future<HistoryPage> history(
    HistoryFilter filter, {
    int limit = 50,
    int offset = 0,
  }) => _request(() async {
    if (limit < 1 || limit > 100 || offset < 0) {
      throw ArgumentError('Invalid pagination.');
    }
    final result = await _client.rpc(
      'daybook_history',
      params: {...filter.toParams(), 'p_limit': limit, 'p_offset': offset},
    );
    return HistoryPage.fromJson(Map<String, dynamic>.from(result as Map));
  });
}
