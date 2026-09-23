import 'package:shared_preferences/shared_preferences.dart';

import 'package:kot_luy/models/expense.dart';

const _selectedPeriodKey = 'selected_expense_period';

Future<ExpensePeriod> loadSelectedExpensePeriod() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_selectedPeriodKey);
    return ExpensePeriod.values.firstWhere(
      (period) => period.name == saved,
      orElse: () => ExpensePeriod.month,
    );
  } catch (_) {
    return ExpensePeriod.month;
  }
}

Future<void> saveSelectedExpensePeriod(ExpensePeriod period) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(_selectedPeriodKey, period.name);
}
