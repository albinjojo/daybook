import 'package:flutter/material.dart';

import '../domain/ledger_repository.dart';

const ink = Color(0xff253a32);
const muted = Color(0xff82877f);
const paper = Color(0xfff8f9f5);
const accountPaper = Color(0xfff0f2eb);
const line = Color(0xffe5e7df);
const green = Color(0xff265d48);
const red = Color(0xff9e5a48);
const receivedBg = Color(0xffedf2e7);
const spentBg = Color(0xfff7eee8);
const months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

TextStyle heading(double size, {Color color = ink}) => TextStyle(
  fontFamily: 'Manrope',
  fontSize: size,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.8,
  color: color,
);
String period(DateTime date) => '${months[date.month - 1]} ${date.year}';
String displayDate(String value) {
  final d = DateTime.parse(value);
  return '${d.day} ${months[d.month - 1].substring(0, 3)} ${d.year}';
}

String money(BigInt paise) {
  final negative = paise.isNegative;
  final absolute = paise.abs();
  final digits = (absolute ~/ BigInt.from(100)).toString();
  var grouped = digits.length <= 3
      ? digits
      : digits.substring(digits.length - 3);
  var prefix = digits.length <= 3 ? '' : digits.substring(0, digits.length - 3);
  while (prefix.isNotEmpty) {
    final cut = prefix.length > 2 ? prefix.length - 2 : 0;
    grouped = '${prefix.substring(cut)},$grouped';
    prefix = prefix.substring(0, cut);
  }
  final fraction = (absolute % BigInt.from(100)).toInt();
  return '${negative ? '−' : ''}₹$grouped${fraction == 0 ? '' : '.${fraction.toString().padLeft(2, '0')}'}';
}

String failureMessage(Object error) => error is LedgerFailure
    ? error.message
    : 'Could not connect. Check your internet and try again. Your changes have not been confirmed.';

ThemeData daybookTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'DM Sans',
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: green,
    primary: green,
    surface: paper,
    onSurface: ink,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: ink, fontSize: 14),
    bodyLarge: TextStyle(color: ink),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: line),
    ),
    hintStyle: const TextStyle(color: muted, fontSize: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xff2d5943),
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: line),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Color(0xfffafbf7),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  ),
);

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 1.6,
      color: muted,
      fontWeight: FontWeight.w600,
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.full = false});
  final bool full;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('d', style: heading(36)),
      const Text('•', style: TextStyle(color: Color(0xffb89a60), fontSize: 25)),
      if (full) ...[
        const SizedBox(width: 12),
        Text('daybook', style: heading(27)),
      ],
    ],
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child, this.accounts = false});
  final Widget child;
  final bool accounts;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: accounts ? accountPaper : paper,
    body: SafeArea(
      child: Column(
        children: [
          if (!accounts)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 72,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: line)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.outlined(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Go back',
                      icon: const Icon(Icons.chevron_left),
                      style: IconButton.styleFrom(
                        side: const BorderSide(color: line),
                      ),
                    ),
                    const Text('daybook'),
                    const Brand(),
                  ],
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class Problem extends StatelessWidget {
  const Problem(this.error, {super.key, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          error is LedgerFailure &&
                  (error as LedgerFailure).code == 'setup_required'
              ? 'Your daybook is almost ready'
              : 'Couldn’t load your daybook',
          style: heading(21),
        ),
        const SizedBox(height: 10),
        Text(
          failureMessage(error),
          style: const TextStyle(color: muted, height: 1.6),
        ),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: retry, child: const Text('Try again')),
      ],
    ),
  );
}

class MonthFilter extends StatelessWidget {
  const MonthFilter({super.key, required this.value, required this.onChanged});
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text('Showing', style: TextStyle(color: muted, fontSize: 13)),
        ),
        OutlinedButton(
          onPressed: () async {
            final next = await showModalBottomSheet<DateTime>(
              context: context,
              isScrollControlled: true,
              builder: (_) => MonthSheet(value),
            );
            if (next != null) onChanged(next);
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 45),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            backgroundColor: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(period(value), style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 16),
              const Icon(Icons.keyboard_arrow_down, size: 18),
            ],
          ),
        ),
      ],
    ),
  );
}

class MonthSheet extends StatefulWidget {
  const MonthSheet(this.value, {super.key});
  final DateTime value;
  @override
  State<MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends State<MonthSheet> {
  late int year = widget.value.year;
  @override
  Widget build(BuildContext context) => SheetLayout(
    children: [
      const Eyebrow('Choose a month'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: year > 1 ? () => setState(() => year--) : null,
            tooltip: 'Previous year',
            icon: const Icon(Icons.chevron_left),
          ),
          Text('$year', style: heading(27)),
          IconButton(
            onPressed: year < 9998 ? () => setState(() => year++) : null,
            tooltip: 'Next year',
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      const SizedBox(height: 18),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        childAspectRatio: 1.7,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: List.generate(
          12,
          (i) => OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor:
                  year == widget.value.year && i + 1 == widget.value.month
                  ? receivedBg
                  : Colors.white,
            ),
            onPressed: () => Navigator.pop(context, DateTime(year, i + 1)),
            child: Text(months[i].substring(0, 3)),
          ),
        ),
      ),
    ],
  );
}

class SheetLayout extends StatelessWidget {
  const SheetLayout({super.key, required this.children, this.busy = false});
  final List<Widget> children;
  final bool busy;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height * .93 -
              MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            14,
            24,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xffd9ddcf),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 20),
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}
