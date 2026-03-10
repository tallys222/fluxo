import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../scanner/models/receipt_model.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

// ── Provider: carrega o receipt pelo ID ───────────────────────────────────

final receiptByIdProvider =
    FutureProvider.autoDispose.family<ReceiptModel?, String>((ref, receiptId) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return null;

  final firestore = ref.watch(firestoreProvider);
  final doc = await firestore
      .collection('users')
      .doc(user.uid)
      .collection('receipts')
      .doc(receiptId)
      .get();

  if (!doc.exists || doc.data() == null) return null;

  final data = doc.data() as Map<String, dynamic>;
  return ReceiptModel(
    id: doc.id,
    qrUrl: data['qrUrl'] ?? '',
    storeName: data['storeName'] ?? '',
    storeCnpj: data['storeCnpj'] ?? '',
    storeAddress: data['storeAddress'] ?? '',
    issuedAt: data['issuedAt'] != null
        ? (data['issuedAt'] as dynamic).toDate()
        : DateTime.now(),
    items: (data['items'] as List<dynamic>? ?? [])
        .map((i) => ReceiptItem.fromMap(i as Map<String, dynamic>))
        .toList(),
    total: (data['total'] ?? 0.0).toDouble(),
    totalDiscount: (data['totalDiscount'] ?? 0.0).toDouble(),
    accessKey: data['accessKey'] ?? '',
  );
});

// ── Sheet ─────────────────────────────────────────────────────────────────

class TransactionDetailSheet extends ConsumerWidget {
  final TransactionModel transaction;
  final VoidCallback onEdit;

  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    required this.onEdit,
  });

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: Text('Deseja excluir "${transaction.title}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (context.mounted) Navigator.pop(context);
      await ref.read(transactionFormProvider.notifier).delete(transaction.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasReceipt = transaction.receiptId != null;
    final receiptAsync = hasReceipt
        ? ref.watch(receiptByIdProvider(transaction.receiptId!))
        : null;

    final categoryColor = _parseColor(transaction.categoryColor);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(transaction.categoryIcon,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        transaction.categoryName,
                        style: TextStyle(
                            color: categoryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Editar',
                ),
                IconButton(
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                  tooltip: 'Excluir',
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          Divider(
              height: 24,
              indent: 20,
              endIndent: 20,
              color: Colors.grey.withOpacity(0.15)),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, hasReceipt ? 40 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Amount card ──────────────────────────────────────────
                  _AmountCard(transaction: transaction),
                  const Gap(20),

                  // ── Info row ─────────────────────────────────────────────
                  _InfoRow(transaction: transaction),
                  const Gap(24),

                  // ── Note ─────────────────────────────────────────────────
                  if (transaction.note != null &&
                      transaction.note!.isNotEmpty &&
                      !hasReceipt) ...[
                    _SectionLabel(label: 'Observação'),
                    const Gap(8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(transaction.note!,
                          style: Theme.of(context).textTheme.bodyLarge),
                    ),
                    const Gap(24),
                  ],

                  // ── Receipt items ─────────────────────────────────────────
                  if (hasReceipt) ...[
                    _SectionLabel(label: 'Itens da compra'),
                    const Gap(12),
                    if (receiptAsync == null)
                      const SizedBox.shrink()
                    else
                      receiptAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.accent),
                          ),
                        ),
                        error: (e, _) => Text('Erro ao carregar itens: $e',
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 12)),
                        data: (receipt) {
                          if (receipt == null) {
                            return const Text('Nota fiscal não encontrada.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13));
                          }
                          return _ReceiptItemsList(
                            receipt: receipt,
                            transaction: transaction,
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
          // Botão de editar visível no rodapé para lançamentos sem NF-e
          if (!hasReceipt)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar lançamento'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

// ── Amount Card ───────────────────────────────────────────────────────────

class _AmountCard extends StatelessWidget {
  final TransactionModel transaction;
  const _AmountCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            isExpense ? 'Despesa' : 'Receita',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const Gap(4),
          Text(
            '${isExpense ? '-' : '+'} ${formatCurrency(transaction.amount)}',
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final TransactionModel transaction;
  const _InfoRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: _InfoChip(
            isDark: isDark,
            icon: Icons.calendar_today_outlined,
            label: 'Data',
            value: formatDate(transaction.date),
          ),
        ),
        const Gap(10),
        Expanded(
          child: _InfoChip(
            isDark: isDark,
            icon: Icons.receipt_outlined,
            label: 'NF-e',
            value: transaction.receiptId != null ? 'Vinculada' : 'Manual',
            valueColor:
                transaction.receiptId != null ? AppColors.income : null,
          ),
        ),
        if (transaction.isInstallment) ...[
          const Gap(10),
          Expanded(
            child: _InfoChip(
              isDark: isDark,
              icon: Icons.credit_card_outlined,
              label: 'Parcela',
              value: '${transaction.installmentCurrent}/${transaction.installmentTotal}',
              valueColor: AppColors.expense,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoChip({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.textSecondary),
              const Gap(4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const Gap(4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Receipt Items List ────────────────────────────────────────────────────

class _ReceiptItemsList extends ConsumerWidget {
  final ReceiptModel receipt;
  final TransactionModel transaction;
  const _ReceiptItemsList({required this.receipt, required this.transaction});

  Future<void> _removeItem(BuildContext context, WidgetRef ref, int index) async {
    final item = receipt.items[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remover item?'),
        content: Text('Remover "${item.name}" da lista? O valor da transação será recalculado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) return;

      await ref.read(removeReceiptItemProvider).removeItem(
        uid: user.uid,
        receiptId: receipt.id,
        transactionId: transaction.id,
        itemIndex: index,
        currentItems: receipt.items,
        currentTransactionAmount: transaction.amount,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${item.name}" removido'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover item: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Store info
        if (receipt.storeCnpj.isNotEmpty || receipt.storeAddress.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (receipt.storeCnpj.isNotEmpty)
                    Text('CNPJ: ${receipt.storeCnpj}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  if (receipt.storeAddress.isNotEmpty) ...[
                    const Gap(2),
                    Text(receipt.storeAddress,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ),

        // Items header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${receipt.items.length} itens',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            Text(formatCurrency(receipt.total),
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.expense,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const Gap(8),

        // Items com swipe para remover
        ...receipt.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Dismissible(
            key: Key('${receipt.id}_item_$index'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
            ),
            confirmDismiss: (_) async {
              await _removeItem(context, ref, index);
              return false; // O provider já atualiza o Firestore, o stream rebuilda
            },
            child: _ItemTile(item: item, isDark: isDark),
          );
        }),

        // Totals footer
        const Gap(8),
        Divider(color: Colors.grey.withOpacity(0.15)),
        const Gap(8),
        if (receipt.totalDiscount > 0) ...[
          _TotalRow(
            label: 'Subtotal',
            value: formatCurrency(receipt.total + receipt.totalDiscount),
            isSecondary: true,
          ),
          const Gap(4),
          _TotalRow(
            label: 'Desconto',
            value: '- ${formatCurrency(receipt.totalDiscount)}',
            valueColor: AppColors.income,
            isSecondary: true,
          ),
          const Gap(8),
        ],
        _TotalRow(
          label: 'Total pago',
          value: formatCurrency(receipt.total),
          valueColor: AppColors.expense,
          bold: true,
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final ReceiptItem item;
  final bool isDark;
  const _ItemTile({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(
                  '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}'
                  ' ${item.unit} × ${formatCurrency(item.unitPrice)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Gap(12),
          Text(
            formatCurrency(item.totalPrice),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isSecondary;
  final bool bold;

  const _TotalRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isSecondary = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSecondary ? 12 : 14,
            color: isSecondary ? AppColors.textSecondary : null,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isSecondary ? 12 : 14,
            color: valueColor,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}