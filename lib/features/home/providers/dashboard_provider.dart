import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../transactions/models/transaction_model.dart';
import '../../auth/providers/auth_provider.dart';

// ── State ──────────────────────────────────────────────────────────────────

class DashboardSummary {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final List<TransactionModel> recentTransactions;
  final List<CategoryExpense> topCategories;
  final DateTime month;

  const DashboardSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.recentTransactions,
    required this.topCategories,
    required this.month,
  });

  double get savingsRate =>
      totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100) : 0;
}

class CategoryExpense {
  final String name;
  final String icon;
  final String color;
  final double amount;
  final double percentage;

  const CategoryExpense({
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
  });
}

// ── Selected month provider ────────────────────────────────────────────────

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// ── Dashboard provider ─────────────────────────────────────────────────────

final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) throw Exception('Usuário não autenticado');

  final month = ref.watch(selectedMonthProvider);
  final firestore = ref.watch(firestoreProvider);

  final startOfMonth = DateTime(month.year, month.month, 1);
  final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

  final snapshot = await firestore
      .collection('users')
      .doc(user.uid)
      .collection('transactions')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
      .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
      .orderBy('date', descending: true)
      .get();

  final transactions = snapshot.docs
      .map((doc) => TransactionModel.fromFirestore(doc))
      .toList();

  double income = 0;
  double expense = 0;
  final categoryMap = <String, _CategoryAcc>{};

  for (final t in transactions) {
    if (t.type == TransactionType.income) {
      income += t.amount;
    } else {
      expense += t.amount;
      categoryMap.update(
        t.categoryName,
        (acc) => acc..amount += t.amount,
        ifAbsent: () => _CategoryAcc(t.categoryName, t.categoryIcon, t.categoryColor, t.amount),
      );
    }
  }

  final topCategories = categoryMap.values
      .map((c) => CategoryExpense(
            name: c.name,
            icon: c.icon,
            color: c.color,
            amount: c.amount,
            percentage: expense > 0 ? (c.amount / expense * 100) : 0,
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  return DashboardSummary(
    totalIncome: income,
    totalExpense: expense,
    balance: income - expense,
    recentTransactions: transactions.take(5).toList(),
    topCategories: topCategories.toList(),
    month: month,
  );
});

class _CategoryAcc {
  final String name;
  final String icon;
  final String color;
  double amount;
  _CategoryAcc(this.name, this.icon, this.color, this.amount);
}

// ── User name provider ─────────────────────────────────────────────────────

final userNameProvider = Provider<String>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  return user?.displayName?.split(' ').first ?? 'Usuário';
});