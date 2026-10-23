import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:daybook/features/ledger/data/supabase_ledger_repository.dart';
import 'package:daybook/features/ledger/domain/ledger_models.dart';
import 'package:daybook/features/ledger/domain/ledger_repository.dart';

void main() {
  SupabaseLedgerRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = SupabaseClient(
      'https://test.supabase.co',
      'test-public-key',
      httpClient: MockClient(handler),
    );
    addTearDown(client.dispose);
    return SupabaseLedgerRepository(client);
  }

  test('delete and undo match identity, version and previous state', () async {
    final draft = EntryDraft(
      type: EntryType.spent,
      amount: Money.parse('20'),
      name: 'Fuel',
      date: '2026-10-23',
    );
    var calls = 0;
    final repo = repository((request) async {
      final deleting = calls++ == 0;
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['id'], 'eq.entry');
      expect(request.url.queryParameters['account_id'], 'eq.account');
      expect(
        request.url.queryParameters['version'],
        deleting ? 'eq.1' : 'eq.2',
      );
      expect(
        request.url.queryParameters['is_deleted'],
        deleting ? 'eq.false' : 'eq.true',
      );
      expect(jsonDecode(request.body), {'is_deleted': deleting});
      return http.Response(
        jsonEncode({
          'id': 'entry',
          'account_id': 'account',
          'version': deleting ? 2 : 3,
          ...draft.toJson(),
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final entry = LedgerEntry(
      id: 'entry',
      accountId: 'account',
      draft: draft,
      version: 1,
    );
    final deleted = await repo.setEntryDeleted(entry, deleted: true);
    final restored = await repo.setEntryDeleted(deleted, deleted: false);
    expect(restored.version, 3);
  });
  test(
    'history sends the same account/date/search/type with page bounds',
    () async {
      final repo = repository((request) async {
        expect(request.url.path, '/rest/v1/rpc/daybook_history');
        expect(jsonDecode(request.body), {
          'p_account_id': 'a',
          'p_start_date': '2026-10-01',
          'p_end_date': '2026-11-01',
          'p_type': 'spent',
          'p_search': 'Fuel %',
          'p_limit': 20,
          'p_offset': 40,
        });
        return http.Response(
          jsonEncode({
            'entries': [],
            'count': 60,
            'received_paise': '0',
            'spent_paise': '10001',
            'balance_paise': '-10001',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final page = await repo.history(
        HistoryFilter.month(
          accountId: 'a',
          year: 2026,
          month: 10,
          type: EntryType.spent,
          search: 'Fuel %',
        ),
        limit: 20,
        offset: 40,
      );
      expect(page.count, 60);
      expect(page.balancePaise, BigInt.from(-10001));
    },
  );

  test(
    'entry edits match account, ID and version; empty match is a conflict',
    () async {
      final draft = EntryDraft(
        type: EntryType.spent,
        amount: Money.parse('3.50'),
        name: 'Fuel',
        date: '2026-10-23',
      );
      final repo = repository((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.queryParameters['id'], 'eq.entry');
        expect(request.url.queryParameters['account_id'], 'eq.account');
        expect(request.url.queryParameters['version'], 'eq.2');
        expect(
          (jsonDecode(request.body) as Map).containsKey('account_id'),
          false,
        );
        return http.Response(
          jsonEncode({
            'code': 'PGRST116',
            'message': 'Cannot coerce the result to a single JSON object',
            'details': 'Results contain 0 rows',
            'hint': null,
          }),
          406,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      await expectLater(
        repo.updateEntry(
          LedgerEntry(
            id: 'entry',
            accountId: 'account',
            draft: draft,
            version: 2,
          ),
          draft,
        ),
        throwsA(isA<LedgerFailure>().having((e) => e.code, 'code', 'conflict')),
      );
    },
  );

  test(
    'permission errors are reported instead of returning an empty ledger',
    () async {
      final repo = repository(
        (request) async => http.Response(
          jsonEncode({
            'code': '42501',
            'message': 'permission denied',
            'details': null,
            'hint': null,
          }),
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      await expectLater(
        repo.listAccounts(),
        throwsA(
          isA<LedgerFailure>().having((e) => e.code, 'code', 'access_denied'),
        ),
      );
    },
  );
}
