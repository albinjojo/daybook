import 'package:daybook/app.dart';
import 'package:daybook/features/ledger/data/preview_ledger_repository.dart';
import 'package:daybook/features/ledger/domain/ledger_models.dart';
import 'package:daybook/features/ledger/domain/ledger_repository.dart';
import 'package:daybook/features/ledger/presentation/entry_sheets.dart';
import 'package:daybook/features/ledger/presentation/history_screen.dart';
import 'package:daybook/features/ledger/presentation/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> start(
    WidgetTester tester, {
    double width = 390,
    PreviewLedgerRepository? repository,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      DaybookApp(repository: repository ?? PreviewLedgerRepository()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('whole total cards open the matching entry list', (tester) async {
    await start(tester);
    await tester.tap(find.text('Innova'));
    await tester.pumpAndSettle();
    for (final title in ['Money received', 'Money spent', 'Balance']) {
      for (final tapAmount in [true, false]) {
        final card = find.byKey(ValueKey('total-card-$title'));
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        final bounds = tester.getRect(card);
        // Exercise the amount area and blank bottom padding, away from the arrow.
        await tester.tapAt(
          tapAmount
              ? Offset(bounds.left + 65, bounds.bottom - 30)
              : Offset(bounds.center.dx, bounds.bottom - 5),
        );
        await tester.pumpAndSettle();
        final history = tester.widget<HistoryScreen>(
          find.byType(HistoryScreen),
        );
        expect(history.account.name, 'Innova');
        expect(history.month.month, DateTime.now().month);
        expect(
          history.type,
          title == 'Money received'
              ? EntryType.received
              : title == 'Money spent'
              ? EntryType.spent
              : null,
        );
        expect(
          find.text('Diesel'),
          title == 'Money received' ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Chennai airport trip'),
          title == 'Money spent' ? findsNothing : findsOneWidget,
        );
        Navigator.of(tester.element(find.byType(HistoryScreen))).pop();
        await tester.pumpAndSettle();
      }
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('entry cards remain readable on a narrow phone', (tester) async {
    await start(tester, width: 320);
    await tester.tap(find.text('Innova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View expenses'));
    await tester.pumpAndSettle();
    expect(find.text('Tap an entry to view or edit it.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Diesel'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Diesel'));
    await tester.pumpAndSettle();
    expect(find.text('Indian Oil, Adyar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('delete confirmation, updated total and Undo', (tester) async {
    final repo = PreviewLedgerRepository();
    await start(tester, repository: repo);
    await tester.tap(find.text('Innova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View expenses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diesel'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete entry'));
    await tester.tap(find.text('Delete entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deletedIds, isEmpty);
    await tester.tap(find.text('Diesel'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete entry'));
    await tester.tap(find.text('Delete entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Diesel'), findsNothing);
    expect(find.text('₹6,350'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Diesel'), findsOneWidget);
    expect(find.text('₹9,550'), findsOneWidget);
    expect(repo.deletedIds, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('phone navigation, filtered totals, search, details and edit', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('Innova'));
    await tester.pumpAndSettle();
    expect(find.text('₹56,500'), findsOneWidget);
    expect(find.text('₹9,550'), findsOneWidget);
    await tester.tap(find.text('View expenses'));
    await tester.pumpAndSettle();
    expect(find.text('Diesel'), findsOneWidget);
    expect(find.text('Chennai airport trip'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Diesel');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('₹3,200'), findsOneWidget);
    expect(find.text('Oil change & service'), findsNothing);
    await tester.tap(find.text('Diesel').last);
    await tester.pumpAndSettle();
    expect(find.text('Indian Oil, Adyar'), findsOneWidget);
    await tester.tap(find.text('Edit entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('entry-amount')), '3300.25');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('₹3,300.25'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('creates an independent account on a narrow phone', (
    tester,
  ) async {
    final repo = PreviewLedgerRepository();
    await start(tester, width: 320, repository: repo);
    await tester.ensureVisible(find.text('Add account'));
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Personal');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Personal'), findsOneWidget);
    expect(repo.accounts.last.name, 'Personal');
    expect(find.text('₹0'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed save keeps the amount and name in the sheet', (
    tester,
  ) async {
    final repo = _FailingRepository();
    await start(tester, repository: repo);
    await tester.tap(find.text('Innova'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Money received'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Money received'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('entry-amount')), '250');
    await tester.enterText(find.byKey(const Key('entry-name')), 'Airport');
    await tester.ensureVisible(find.text('Save entry'));
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditor), findsOneWidget);
    expect(find.text('Airport'), findsOneWidget);
    expect(find.text('250'), findsOneWidget);
    await tester.ensureVisible(find.text('Save entry'));
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(repo.ids.length, 2);
    expect(repo.ids.toSet().length, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('new entry saves custom details to the selected account', (
    tester,
  ) async {
    final repo = PreviewLedgerRepository();
    await start(tester, repository: repo);
    await tester.tap(find.text('Kia Carens'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Money spent'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Money spent'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('entry-amount')), '250.75');
    await tester.enterText(find.byKey(const Key('entry-name')), 'Toll');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Detail name'),
      'Route',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Write anything…'),
      'Chennai',
    );
    await tester.ensureVisible(find.text('Save entry'));
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(repo.entries.last.accountId, 'Kia Carens');
    expect(repo.entries.last.draft.amount.paise, 25075);
    expect(repo.entries.last.draft.details.single.label, 'Route');
    expect(find.text('₹250.75'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('CSV preserves custom details and neutralises spreadsheet formulas', () {
    final e = LedgerEntry(
      id: '1',
      accountId: 'a',
      version: 1,
      draft: EntryDraft(
        type: EntryType.spent,
        amount: Money.parse('50.25'),
        name: '=SUM(A1)',
        date: '2026-10-23',
        details: [CustomDetail(label: 'Note', value: 'line one\nline two')],
      ),
    );
    final csv = buildCsv('Office', [e]);
    expect(csv, contains("'=SUM(A1)"));
    expect(csv, contains('50.25'));
    expect(csv, contains('line one'));
    expect(
      money(BigInt.parse('1234567890123456789')),
      '₹12,34,56,78,90,12,34,567.89',
    );
  });
}

class _FailingRepository extends PreviewLedgerRepository {
  final ids = <String>[];
  @override
  Future<LedgerEntry> createEntry({
    required String id,
    required String accountId,
    required EntryDraft draft,
  }) async {
    ids.add(id);
    throw const LedgerFailure(
      'access_denied',
      'Database access is not enabled for this app.',
    );
  }
}
