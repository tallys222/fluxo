import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../home/widgets/dashboard_widgets.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import 'add_transaction_sheet.dart';
import 'transaction_detail_sheet.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final filteredAsync = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterProvider);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançamentos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openAddSheet(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body: Column(
        children: [
          // ── Month selector ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: _MonthBar(
              selected: selectedMonth,
              currentMonth: currentMonth,
              onChanged: (m) =>
                  ref.read(selectedMonthProvider.notifier).state = m,
            ),
          ),

          // ── Summary row ────────────────────────────────────────────────
          filteredAsync.whenData((list) {
            final income = list
                .where((t) => t.type == TransactionType.income)
                .fold(0.0, (s, t) => s + t.amount);
            final expense = list
                .where((t) => t.type == TransactionType.expense)
                .fold(0.0, (s, t) => s + t.amount);
            return _SummaryRow(income: income, expense: expense);
          }).valueOrNull ?? const SizedBox.shrink(),

          // ── Filter chips ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: TransactionFilter.values.map((f) {
                final isSelected = filter == f;
                final label = switch (f) {
                  TransactionFilter.all => 'Todos',
                  TransactionFilter.income => 'Receitas',
                  TransactionFilter.expense => 'Despesas',
                };
                final color = switch (f) {
                  TransactionFilter.all => AppColors.primary,
                  TransactionFilter.income => AppColors.income,
                  TransactionFilter.expense => AppColors.expense,
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => ref
                        .read(transactionFilterProvider.notifier)
                        .state = f,
                    selectedColor: color.withOpacity(0.15),
                    checkmarkColor: color,
                    labelStyle: TextStyle(
                      color: isSelected ? color : AppColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    side: BorderSide(
                      color: isSelected ? color : Colors.transparent,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── List ───────────────────────────────────────────────────────
          Expanded(
            child: filteredAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return _EmptyTransactions(
                    onAdd: () => _openAddSheet(context),
                  );
                }

                // Group by date
                final grouped = _groupByDate(transactions);

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final entry = grouped[index];
                    return _DateGroup(
                      date: entry.key,
                      transactions: entry.value,
                      onEdit: (t) => _openEditSheet(context, t),
                      onDelete: (t) => _confirmDelete(context, ref, t),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionSheet(),
    );
  }

  void _openEditSheet(BuildContext context, TransactionModel t) {
    // Se tem NF-e vinculada, abre o detalhe com os itens
    if (t.receiptId != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TransactionDetailSheet(
          transaction: t,
          onEdit: () => _openFormSheet(context, t),
        ),
      );
    } else {
      _openFormSheet(context, t);
    }
  }

  void _openFormSheet(BuildContext context, TransactionModel t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(existing: t),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, TransactionModel t) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: Text(
            'Deseja excluir "${t.title}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref
                  .read(transactionFormProvider.notifier)
                  .delete(t.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  List<MapEntry<DateTime, List<TransactionModel>>> _groupByDate(
      List<TransactionModel> transactions) {
    final map = <DateTime, List<TransactionModel>>{};
    for (final t in transactions) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      map.putIfAbsent(key, () => []).add(t);
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return sorted;
  }
}

// ── Month bar ─────────────────────────────────────────────────────────────

class _MonthBar extends StatelessWidget {
  final DateTime selected;
  final DateTime currentMonth;
  final ValueChanged<DateTime> onChanged;

  const _MonthBar({
    required this.selected,
    required this.currentMonth,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canGoForward = selected.isBefore(currentMonth);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () =>
              onChanged(DateTime(selected.year, selected.month - 1)),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
          ),
          child: Text(
            formatMonthYearCapitalized(selected),
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.chevron_right,
            color: canGoForward ? null : Colors.transparent,
          ),
          onPressed: canGoForward
              ? () =>
                  onChanged(DateTime(selected.year, selected.month + 1))
              : null,
        ),
      ],
    );
  }
}

// ── Summary Row ───────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final double income;
  final double expense;

  const _SummaryRow({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Expanded(child: _SummaryCard(
            label: 'Receitas',
            value: income,
            color: AppColors.income,
            icon: Icons.arrow_downward_rounded,
          )),
          const Gap(12),
          Expanded(child: _SummaryCard(
            label: 'Despesas',
            value: expense,
            color: AppColors.expense,
            icon: Icons.arrow_upward_rounded,
          )),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.w500)),
                Text(
                  formatCurrency(value),
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date Group ────────────────────────────────────────────────────────────

class _DateGroup extends StatelessWidget {
  final DateTime date;
  final List<TransactionModel> transactions;
  final ValueChanged<TransactionModel> onEdit;
  final ValueChanged<TransactionModel> onDelete;

  const _DateGroup({
    required this.date,
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayTotal = transactions.fold(0.0, (sum, t) {
      return t.type == TransactionType.expense
          ? sum - t.amount
          : sum + t.amount;
    });
    final isPositive = dayTotal >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatRelativeDate(date),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                '${isPositive ? '+' : ''}${formatCurrency(dayTotal)}',
                style: TextStyle(
                  color: isPositive ? AppColors.income : AppColors.expense,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Transaction tiles
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF263D52)
                  : const Color(0xFFE8ECF0),
            ),
          ),
          child: Column(
            children: transactions.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              return Column(
                children: [
                  _SwipeableTransactionTile(
                    transaction: t,
                    onEdit: () => onEdit(t),
                    onDelete: () => onDelete(t),
                  ),
                  if (i < transactions.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.05),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Swipeable Transaction Tile ────────────────────────────────────────────

class _SwipeableTransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SwipeableTransactionTile({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // Let the dialog handle actual deletion
      },
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TransactionTile(transaction: transaction),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyTransactions({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Text('💸', style: TextStyle(fontSize: 48)),
            ),
            const Gap(20),
            Text(
              'Nenhum lançamento',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Gap(8),
            Text(
              'Adicione receitas e despesas\npara acompanhar suas finanças.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const Gap(28),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}