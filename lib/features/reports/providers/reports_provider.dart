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
        (a) => a..amount += t.amount..count += 1,
        ifAbsent: () =>
            _CatAcc(t.categoryName, t.categoryIcon, t.categoryColor, t.amount),
      );
    } else {
      totalIncome += t.amount;
      incCatMap.update(
        t.categoryName,
        (a) => a..amount += t.amount..count += 1,
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

// ── Trend Models ──────────────────────────────────────────────────────────

enum TrendDirection { up, down, stable }

class CategoryTrend {
  final String name;
  final String icon;
  final String color;
  final double currentMonth;   // gasto no mês atual
  final double previousAvg;   // média dos 3 meses anteriores
  final double changePercent;  // % de variação
  final TrendDirection direction;

  const CategoryTrend({
    required this.name,
    required this.icon,
    required this.color,
    required this.currentMonth,
    required this.previousAvg,
    required this.changePercent,
    required this.direction,
  });
}

class TrendData {
  final List<CategoryTrend> trends;      // ordenado por maior variação absoluta
  final DateTime referenceMonth;         // mês atual de referência
  final double totalCurrentMonth;
  final double totalPreviousAvg;
  final double overallChangePercent;
  final TrendDirection overallDirection;

  const TrendData({
    required this.trends,
    required this.referenceMonth,
    required this.totalCurrentMonth,
    required this.totalPreviousAvg,
    required this.overallChangePercent,
    required this.overallDirection,
  });
}
// ── Trend Provider ────────────────────────────────────────────────────────
// Compara o mês atual com a média dos 3 meses anteriores, por categoria.

final trendProvider = FutureProvider.autoDispose<TrendData>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) throw Exception('Não autenticado');

  final firestore = ref.watch(firestoreProvider);
  final now = DateTime.now();

  // Busca 4 meses: mês atual + 3 anteriores
  final startDate = DateTime(now.year, now.month - 3, 1);
  final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // Filtra só por data (evita índice composto no Firestore)
  // O filtro de tipo é feito em memória abaixo
  final snap = await firestore
      .collection('users')
      .doc(user.uid)
      .collection('transactions')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
      .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
      .get();

  // Filtra apenas despesas em memória
  final transactions = snap.docs
      .map((d) => TransactionModel.fromFirestore(d))
      .where((t) => t.type == TransactionType.expense)
      .toList();

  // Agrupa por mês → categoria → valor
  // Estrutura: { 'yyyy-M' : { 'categoryName': _CatAcc } }
  final monthCatMap = <String, Map<String, _CatAcc>>{};

  for (int i = 0; i <= 3; i++) {
    final m = DateTime(now.year, now.month - i);
    monthCatMap['${m.year}-${m.month}'] = {};
  }

  for (final t in transactions) {
    final key = '${t.date.year}-${t.date.month}';
    if (!monthCatMap.containsKey(key)) continue;
    monthCatMap[key]!.update(
      t.categoryName,
      (a) => a..amount += t.amount..count += 1,
      ifAbsent: () =>
          _CatAcc(t.categoryName, t.categoryIcon, t.categoryColor, t.amount),
    );
  }

  final currentKey = '${now.year}-${now.month}';
  final currentCats = monthCatMap[currentKey] ?? {};

  // Calcula média dos 3 meses anteriores por categoria
  final prevKeys = [
    '${DateTime(now.year, now.month - 1).year}-${DateTime(now.year, now.month - 1).month}',
    '${DateTime(now.year, now.month - 2).year}-${DateTime(now.year, now.month - 2).month}',
    '${DateTime(now.year, now.month - 3).year}-${DateTime(now.year, now.month - 3).month}',
  ];

  // Coleta todas as categorias que apareceram em qualquer mês
  final allCatNames = <String>{};
  for (final key in [currentKey, ...prevKeys]) {
    allCatNames.addAll(monthCatMap[key]?.keys ?? []);
  }

  final trends = <CategoryTrend>[];

  for (final catName in allCatNames) {
    final currentAmount = currentCats[catName]?.amount ?? 0.0;

    double prevTotal = 0;
    int prevCount = 0;
    _CatAcc? meta;

    for (final key in prevKeys) {
      final acc = monthCatMap[key]?[catName];
      if (acc != null) {
        prevTotal += acc.amount;
        prevCount++;
        meta ??= acc;
      }
    }

    // Usa meta do mês atual se disponível
    meta = currentCats[catName] ?? meta;
    if (meta == null) continue;

    final prevAvg = prevCount > 0 ? prevTotal / prevCount : 0.0;

    // Calcula variação
    double changePercent;
    TrendDirection direction;

    if (prevAvg == 0 && currentAmount == 0) continue;

    if (prevAvg == 0) {
      changePercent = 100.0;
      direction = TrendDirection.up;
    } else {
      changePercent = ((currentAmount - prevAvg) / prevAvg) * 100;
      if (changePercent > 5) {
        direction = TrendDirection.up;
      } else if (changePercent < -5) {
        direction = TrendDirection.down;
      } else {
        direction = TrendDirection.stable;
      }
    }

    trends.add(CategoryTrend(
      name: meta.name,
      icon: meta.icon,
      color: meta.color,
      currentMonth: currentAmount,
      previousAvg: prevAvg,
      changePercent: changePercent,
      direction: direction,
    ));
  }

  // Ordena por maior variação absoluta primeiro
  trends.sort((a, b) =>
      b.changePercent.abs().compareTo(a.changePercent.abs()));

  // Totais gerais
  final totalCurrent = currentCats.values.fold(0.0, (s, c) => s + c.amount);
  double prevTotalAll = 0;
  int prevMonthsWithData = 0;
  for (final key in prevKeys) {
    final monthTotal =
        monthCatMap[key]?.values.fold(0.0, (s, c) => s + c.amount) ?? 0.0;
    if (monthTotal > 0) {
      prevTotalAll += monthTotal;
      prevMonthsWithData++;
    }
  }
  final prevAvgAll =
      prevMonthsWithData > 0 ? prevTotalAll / prevMonthsWithData : 0.0;

  double overallChange;
  TrendDirection overallDir;
  if (prevAvgAll == 0) {
    overallChange = 0;
    overallDir = TrendDirection.stable;
  } else {
    overallChange = ((totalCurrent - prevAvgAll) / prevAvgAll) * 100;
    overallDir = overallChange > 5
        ? TrendDirection.up
        : overallChange < -5
            ? TrendDirection.down
            : TrendDirection.stable;
  }

  return TrendData(
    trends: trends,
    referenceMonth: DateTime(now.year, now.month),
    totalCurrentMonth: totalCurrent,
    totalPreviousAvg: prevAvgAll,
    overallChangePercent: overallChange,
    overallDirection: overallDir,
  );
});

// ── Transactions list for PDF export ─────────────────────────────────────

final reportTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
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

  return snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList();
});