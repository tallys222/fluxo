import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/models/transaction_model.dart';

// ── Models ────────────────────────────────────────────────────────────────

class MonthlyBalance {
  final DateTime month;
  final double income;
  final double expense;
  double get balance => income - expense;

  const MonthlyBalance({
    required this.month,
    required this.income,
    required this.expense,
  });
}

class CategorySummary {
  final String name;
  final String icon;
  final String color;
  final double amount;
  final double percentage;
  final int count;

  const CategorySummary({
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
    required this.count,
  });
}

class TopExpense {
  final String title;
  final String categoryIcon;
  final String categoryColor;
  final double amount;
  final DateTime date;

  const TopExpense({
    required this.title,
    required this.categoryIcon,
    required this.categoryColor,
    required this.amount,
    required this.date,
  });
}

class ReportsData {
  final List<MonthlyBalance> last6Months;
  final List<CategorySummary> expensesByCategory;
  final List<CategorySummary> incomeByCategory;
  final List<TopExpense> topExpenses;
  final double totalIncome;
  final double totalExpense;
  final double averageMonthlyExpense;
  final double averageMonthlyIncome;

  const ReportsData({
    required this.last6Months,
    required this.expensesByCategory,
    required this.incomeByCategory,
    required this.topExpenses,
    required this.totalIncome,
    required this.totalExpense,
    required this.averageMonthlyExpense,
    required this.averageMonthlyIncome,
  });

  double get savingsRate =>
      totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100) : 0;
}

// ── Selected period ───────────────────────────────────────────────────────

enum ReportPeriod { month1, month3, month6, month12 }

final reportPeriodProvider =
    StateProvider<ReportPeriod>((ref) => ReportPeriod.month3);

// ── Provider ──────────────────────────────────────────────────────────────

final reportsProvider = FutureProvider.autoDispose<ReportsData>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) throw Exception('Não autenticado');

  final period = ref.watch(reportPeriodProvider);
  final firestore = ref.watch(firestoreProvider);

  final monthCount = switch (period) {
    ReportPeriod.month1 => 1,
    ReportPeriod.month3 => 3,
    ReportPeriod.month6 => 6,
    ReportPeriod.month12 => 12,
  };

  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month - monthCount + 1, 1);
  final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  final snap = await firestore
      .collection('users')
      .doc(user.uid)
      .collection('transactions')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
      .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
      .orderBy('date', descending: true)
      .get();

  final transactions =
      snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList();

  // ── Monthly balances ─────────────────────────────────────────────────

  final monthlyMap = <String, _MonthAcc>{};
  for (int i = monthCount - 1; i >= 0; i--) {
    final m = DateTime(now.year, now.month - i);
    final key = '${m.year}-${m.month}';
    monthlyMap[key] = _MonthAcc(m);
  }

  for (final t in transactions) {
    final key = '${t.date.year}-${t.date.month}';
    if (monthlyMap.containsKey(key)) {
      if (t.type == TransactionType.income) {
        monthlyMap[key]!.income += t.amount;
      } else {
        monthlyMap[key]!.expense += t.amount;
      }
    }
  }

  final last6Months = monthlyMap.values
      .map((m) =>
          MonthlyBalance(month: m.month, income: m.income, expense: m.expense))
      .toList();

  // ── Category breakdown ────────────────────────────────────────────────

  final expCatMap = <String, _CatAcc>{};
  final incCatMap = <String, _CatAcc>{};
  double totalIncome = 0;
  double totalExpense = 0;

  for (final t in transactions) {
    if (t.type == TransactionType.expense) {
      totalExpense += t.amount;
      expCatMap.update(
        t.categoryName,
        (a) {
          a.amount += t.amount;
          a.count++;
          return a;
        },
        ifAbsent: () =>
            _CatAcc(t.categoryName, t.categoryIcon, t.categoryColor, t.amount),
      );
    } else {
      totalIncome += t.amount;
      incCatMap.update(
        t.categoryName,
        (a) {
          a.amount += t.amount;
          a.count++;
          return a;
        },
        ifAbsent: () =>
            _CatAcc(t.categoryName, t.categoryIcon, t.categoryColor, t.amount),
      );
    }
  }

  final expensesByCategory = expCatMap.values
      .map((c) => CategorySummary(
            name: c.name,
            icon: c.icon,
            color: c.color,
            amount: c.amount,
            percentage:
                totalExpense > 0 ? (c.amount / totalExpense * 100) : 0,
            count: c.count,
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  final incomeByCategory = incCatMap.values
      .map((c) => CategorySummary(
            name: c.name,
            icon: c.icon,
            color: c.color,
            amount: c.amount,
            percentage: totalIncome > 0 ? (c.amount / totalIncome * 100) : 0,
            count: c.count,
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  // ── Top expenses ──────────────────────────────────────────────────────

  final topExpenses = transactions
      .where((t) => t.type == TransactionType.expense)
      .take(5)
      .map((t) => TopExpense(
            title: t.title,
            categoryIcon: t.categoryIcon,
            categoryColor: t.categoryColor,
            amount: t.amount,
            date: t.date,
          ))
      .toList();

  // ── Averages ──────────────────────────────────────────────────────────

  final months = monthCount.toDouble();

  return ReportsData(
    last6Months: last6Months,
    expensesByCategory: expensesByCategory,
    incomeByCategory: incomeByCategory,
    topExpenses: topExpenses,
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    averageMonthlyExpense: months > 0 ? totalExpense / months : 0,
    averageMonthlyIncome: months > 0 ? totalIncome / months : 0,
  );
});

class _MonthAcc {
  final DateTime month;
  double income = 0;
  double expense = 0;
  _MonthAcc(this.month);
}

class _CatAcc {
  final String name;
  final String icon;
  final String color;
  double amount;
  int count = 1;
  _CatAcc(this.name, this.icon, this.color, this.amount);
}