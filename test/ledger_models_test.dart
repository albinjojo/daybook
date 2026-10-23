import 'package:flutter_test/flutter_test.dart';
import 'package:daybook/features/ledger/domain/ledger_models.dart';

void main() {
  test('money preserves paise without floating point rounding', () {
    expect(Money.parse('0.01').paise, 1);
    expect(Money.parse('10.5').paise, 1050);
    expect(Money.parse('9999999999.99').paise, 999999999999);
    expect(Money.parse('3200').rupees, '3200.00');
    for (final input in ['0', '-1', '1.005', 'NaN', '1e3', '10000000000']) {
      expect(
        () => Money.parse(input),
        throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>())),
      );
    }
  });
  test('month ranges include leap days and cross year boundaries', () {
    final leap = HistoryFilter.month(accountId: 'a', year: 2024, month: 2);
    expect(leap.startDate, '2024-02-01');
    expect(leap.endDate, '2024-03-01');
    expect(
      HistoryFilter.month(accountId: 'a', year: 2026, month: 12).endDate,
      '2027-01-01',
    );
    expect(() => checkedDate('2026-02-30'), throwsFormatException);
  });
  test('custom details preserve duplicate labels and ordering', () {
    final draft = EntryDraft(
      type: EntryType.spent,
      amount: Money.parse('10.25'),
      name: ' Fuel ',
      date: '2026-10-23',
      details: [
        CustomDetail(label: 'Stop', value: 'Chennai'),
        CustomDetail(label: 'Stop', value: 'Pondicherry'),
      ],
    );
    expect(draft.toJson()['name'], 'Fuel');
    expect(draft.toJson()['custom_details'], [
      {'label': 'Stop', 'value': 'Chennai'},
      {'label': 'Stop', 'value': 'Pondicherry'},
    ]);
    expect(draft.toJson().containsKey('account_id'), false);
    expect(() => CustomDetail(label: ' ', value: 'x'), throwsArgumentError);
  });
  test('aggregate totals support values larger than web safe integers', () {
    final page = HistoryPage.fromJson({
      'entries': [],
      'count': 0,
      'received_paise': '9007199254740993',
      'spent_paise': '2',
      'balance_paise': '9007199254740991',
    });
    expect(page.receivedPaise - page.spentPaise, page.balancePaise);
  });
}
