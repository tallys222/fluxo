import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../scanner/models/receipt_model.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import '../../home/providers/dashboard_provider.dart';

// ── Selected month (shared with dashboard) ────────────────────────────────

// reuses selectedMonthProvider from dashboard_provider.dart

// ── Transactions stream ───────────────────────────────────────────────────

final transactionsStreamProvider =
    StreamProvider.autoDispose<List<TransactionModel>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final month = ref.watch(selectedMonthProvider);
  return repo.watchTransactionsByMonth(month);
});

// ── Categories stream ─────────────────────────────────────────────────────

final categoriesStreamProvider =
    StreamProvider.autoDispose<List<CategoryModel>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchCategories();
});

// ── Filter (all / income / expense) ──────────────────────────────────────

enum TransactionFilter { all, income, expense }

final transactionFilterProvider =
    StateProvider<TransactionFilter>((ref) => TransactionFilter.all);

final filteredTransactionsProvider =
    Provider.autoDispose<AsyncValue<List<TransactionModel>>>((ref) {
  final transactions = ref.watch(transactionsStreamProvider);
  final filter = ref.watch(transactionFilterProvider);

  return transactions.whenData((list) {
    switch (filter) {
      case TransactionFilter.income:
        return list.where((t) => t.type == TransactionType.income).toList();
      case TransactionFilter.expense:
        return list.where((t) => t.type == TransactionType.expense).toList();
      case TransactionFilter.all:
        return list;
    }
  });
});

// ── Add / Edit transaction notifier ──────────────────────────────────────

class TransactionFormNotifier extends StateNotifier<AsyncValue<void>> {
  final TransactionRepository _repo;
  final Ref _ref;

  TransactionFormNotifier(this._repo, this._ref)
      : super(const AsyncValue.data(null));

  Future<bool> save(TransactionModel transaction) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addTransaction(transaction);
      // Invalidate dashboard so it refreshes
      _ref.invalidate(dashboardProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> update(TransactionModel transaction) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateTransaction(transaction);
      _ref.invalidate(dashboardProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteTransaction(id);
      _ref.invalidate(dashboardProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

// ── Remove item from receipt ──────────────────────────────────────────────

final removeReceiptItemProvider = Provider<RemoveReceiptItemService>((ref) {
  return RemoveReceiptItemService(ref);
});

class RemoveReceiptItemService {
  final Ref _ref;
  RemoveReceiptItemService(this._ref);

  /// Remove um item do receipt e recalcula o total da transação vinculada.
  Future<void> removeItem({
    required String uid,
    required String receiptId,
    required String transactionId,
    required int itemIndex,
    required List<ReceiptItem> currentItems,
    required double currentTransactionAmount,
  }) async {
    final firestore = _ref.read(firestoreProvider);

    // Calcula o valor do item removido
    final removedItem = currentItems[itemIndex];
    final removedValue = removedItem.totalPrice;

    // Nova lista de itens
    final updatedItems = List<ReceiptItem>.from(currentItems)
      ..removeAt(itemIndex);

    // Novo total do receipt
    final newTotal = updatedItems.fold(0.0, (sum, i) => sum + i.totalPrice);

    // Novo valor da transação
    final newAmount = (currentTransactionAmount - removedValue).clamp(0.0, double.infinity);

    // Batch update
    final batch = firestore.batch();

    // Atualiza o receipt
    final receiptRef = firestore
        .collection('users').doc(uid)
        .collection('receipts').doc(receiptId);
    batch.update(receiptRef, {
      'items': updatedItems.map((i) => i.toMap()).toList(),
      'total': newTotal,
    });

    // Atualiza o valor da transação
    final txRef = firestore
        .collection('users').doc(uid)
        .collection('transactions').doc(transactionId);
    batch.update(txRef, {'amount': newAmount});

    await batch.commit();

    // Invalida providers
    _ref.invalidate(dashboardProvider);
  }
}

final transactionFormProvider =
    StateNotifierProvider.autoDispose<TransactionFormNotifier, AsyncValue<void>>(
        (ref) {
  return TransactionFormNotifier(
    ref.watch(transactionRepositoryProvider),
    ref,
  );
});