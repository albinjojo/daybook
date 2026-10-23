/// INR is stored as whole paise throughout the app and database.
final class Money {
  const Money._(this.paise);
  final int paise;
  static const maxPaise = 999999999999;

  factory Money.fromPaise(int value) {
    if (value < 1 || value > maxPaise) {
      throw ArgumentError(
        'Amount must be positive and within the supported range.',
      );
    }
    return Money._(value);
  }

  factory Money.parse(String rupees) {
    final value = rupees.trim();
    if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(value)) {
      throw const FormatException(
        'Enter a positive amount with at most two decimal places.',
      );
    }
    final parts = value.split('.');
    return Money.fromPaise(
      int.parse(parts[0]) * 100 +
          (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'))),
    );
  }

  String get rupees =>
      '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
}

String checkedName(String value, int max) {
  final name = value.trim();
  if (name.isEmpty || name.runes.length > max) {
    throw ArgumentError('Name must contain between 1 and $max characters.');
  }
  return name;
}

/// Date-only values avoid UTC conversions shifting a transaction to another day.
String checkedDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Use YYYY-MM-DD.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || dateOnly(parsed) != value) {
    throw const FormatException('Invalid calendar date.');
  }
  return value;
}

String dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

enum EntryType { received, spent }

final class CustomDetail {
  CustomDetail({required String label, required this.value})
    : label = checkedName(label, 80) {
    if (value.runes.length > 4000) {
      throw ArgumentError('Detail value is too long.');
    }
  }
  final String label;
  final String value;
  Map<String, dynamic> toJson() => {'label': label, 'value': value};
  factory CustomDetail.fromJson(Map<String, dynamic> json) => CustomDetail(
    label: json['label'] as String,
    value: json['value'] as String,
  );
}

final class LedgerAccount {
  const LedgerAccount({
    required this.id,
    required this.name,
    required this.icon,
    required this.isArchived,
    required this.version,
  });
  final String id;
  final String name;
  final String icon;
  final bool isArchived;
  final int version;
  factory LedgerAccount.fromJson(Map<String, dynamic> json) => LedgerAccount(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    isArchived: json['is_archived'] as bool,
    version: json['version'] as int,
  );
}

final class EntryDraft {
  EntryDraft({
    required this.type,
    required this.amount,
    required String name,
    required String date,
    List<CustomDetail> details = const [],
  }) : name = checkedName(name, 150),
       date = checkedDate(date),
       details = List.unmodifiable(details) {
    if (details.length > 50) {
      throw ArgumentError('At most 50 details are allowed.');
    }
  }
  final EntryType type;
  final Money amount;
  final String name;
  final String date;
  final List<CustomDetail> details;
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'amount_paise': amount.paise,
    'name': name,
    'transaction_date': date,
    'custom_details': details.map((d) => d.toJson()).toList(),
  };
}

final class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.accountId,
    required this.draft,
    required this.version,
  });
  final String id;
  final String accountId;
  final EntryDraft draft;
  final int version;
  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    id: json['id'] as String,
    accountId: json['account_id'] as String,
    version: json['version'] as int,
    draft: EntryDraft(
      type: EntryType.values.byName(json['type'] as String),
      amount: Money.fromPaise((json['amount_paise'] as num).toInt()),
      name: json['name'] as String,
      date: json['transaction_date'] as String,
      details: (json['custom_details'] as List)
          .map(
            (d) => CustomDetail.fromJson(Map<String, dynamic>.from(d as Map)),
          )
          .toList(),
    ),
  );
}

final class HistoryFilter {
  HistoryFilter({
    required this.accountId,
    required String startDate,
    required String endDate,
    this.type,
    String search = '',
  }) : startDate = checkedDate(startDate),
       endDate = checkedDate(endDate),
       search = search.trim() {
    if (accountId.isEmpty || startDate.compareTo(endDate) >= 0) {
      throw ArgumentError('Choose an account and a valid date range.');
    }
    if (this.search.runes.length > 200) {
      throw ArgumentError('Search is too long.');
    }
  }
  factory HistoryFilter.month({
    required String accountId,
    required int year,
    required int month,
    EntryType? type,
    String search = '',
  }) {
    if (year < 1 || year > 9998 || month < 1 || month > 12) {
      throw ArgumentError('Invalid month.');
    }
    return HistoryFilter(
      accountId: accountId,
      startDate: dateOnly(DateTime(year, month)),
      endDate: dateOnly(DateTime(year, month + 1)),
      type: type,
      search: search,
    );
  }
  final String accountId;
  final String startDate;
  final String endDate;
  final EntryType? type;
  final String search;
  Map<String, dynamic> toParams() => {
    'p_account_id': accountId,
    'p_start_date': startDate,
    'p_end_date': endDate,
    'p_type': type?.name,
    'p_search': search,
  };
}

final class HistoryPage {
  HistoryPage.fromJson(Map<String, dynamic> json)
    : entries = List.unmodifiable(
        (json['entries'] as List).map(
          (e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      ),
      count = (json['count'] as num).toInt(),
      receivedPaise = BigInt.parse(json['received_paise'] as String),
      spentPaise = BigInt.parse(json['spent_paise'] as String),
      balancePaise = BigInt.parse(json['balance_paise'] as String);
  final List<LedgerEntry> entries;
  final int count;
  // Aggregates may exceed the safe integer range of Flutter web numbers.
  final BigInt receivedPaise;
  final BigInt spentPaise;
  final BigInt balancePaise;
}
