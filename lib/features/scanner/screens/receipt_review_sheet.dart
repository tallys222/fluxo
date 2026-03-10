import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/servcice/seed_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/models/transaction_model.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../models/receipt_model.dart';
import '../providers/scanner_provider.dart';

class ReceiptReviewSheet extends ConsumerStatefulWidget {
  final ReceiptModel receipt;
  const ReceiptReviewSheet({super.key, required this.receipt});

  @override
  ConsumerState<ReceiptReviewSheet> createState() => _ReceiptReviewSheetState();
}

class _ReceiptReviewSheetState extends ConsumerState<ReceiptReviewSheet> {
  CategoryModel? _selectedCategory;
  bool _importing = false;
  bool _isInstallment = false;
  int _installments = 2;

  @override
  void initState() {
    super.initState();
    // Garante seed das categorias caso ainda não tenha sido feito
    _ensureCategories();
  }

  Future<void> _ensureCategories() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    final firestore = ref.read(firestoreProvider);
    final seedService = SeedService(firestore);
    await seedService.seedIfNeeded(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receipt = widget.receipt;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long,
                      color: AppColors.accent, size: 22),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receipt.storeName,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        receipt.storeCnpj.isNotEmpty
                            ? 'CNPJ: ${receipt.storeCnpj}'
                            : formatDate(receipt.issuedAt),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Gap(4),
          Divider(color: Colors.grey.withOpacity(0.15)),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _TotalBanner(
                  total: receipt.total,
                  discount: receipt.totalDiscount,
                  itemCount: receipt.items.length,
                  date: receipt.issuedAt,
                ),
                const Gap(20),
                _CategoryPicker(
                  selected: _selectedCategory,
                  onChanged: (c) => setState(() => _selectedCategory = c),
                ),
                const Gap(20),
                // Installment selector
                _InstallmentSelector(
                  enabled: _isInstallment,
                  installments: _installments,
                  total: receipt.total,
                  onToggle: (v) => setState(() => _isInstallment = v),
                  onChanged: (v) => setState(() => _installments = v),
                ),
                const Gap(20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Itens (${receipt.items.length})',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      formatCurrency(receipt.total),
                      style: const TextStyle(
                        color: AppColors.expense,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const Gap(10),
                ...receipt.items.map((item) => _ReceiptItemTile(item: item)),
                const Gap(80),
              ],
            ),
          ),

          // Import button
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
            child: ElevatedButton(
              onPressed: _selectedCategory == null || _importing ? null : _import,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.accent.withOpacity(0.3),
              ),
              child: _importing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.download_done_outlined),
                        const Gap(8),
                        Text(
                          _selectedCategory == null
                              ? 'Selecione uma categoria'
                              : _isInstallment && _installments > 1
                                  ? 'Importar em $_installments parcelas'
                                  : 'Importar ${formatCurrency(receipt.total)}',
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    final success = await ref.read(scannerProvider.notifier).importReceipt(
          receipt: widget.receipt,
          categoryId: _selectedCategory!.id,
          categoryName: _selectedCategory!.name,
          categoryIcon: _selectedCategory!.icon,
          categoryColor: _selectedCategory!.color,
          installments: _isInstallment ? _installments : 1,
        );

    if (!mounted) return;
    setState(() => _importing = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              Gap(8),
              Text('Nota fiscal importada com sucesso!'),
            ],
          ),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao importar. Tente novamente.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ── Total Banner ──────────────────────────────────────────────────────────

class _TotalBanner extends StatelessWidget {
  final double total;
  final double discount;
  final int itemCount;
  final DateTime date;

  const _TotalBanner({
    required this.total,
    required this.discount,
    required this.itemCount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.expense.withOpacity(0.12),
            AppColors.expense.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.expense.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total da compra',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    formatCurrency(total),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _InfoBadge(
                      icon: Icons.shopping_bag_outlined,
                      label: '$itemCount itens'),
                  const Gap(6),
                  _InfoBadge(
                      icon: Icons.calendar_today_outlined,
                      label: formatDate(date)),
                ],
              ),
            ],
          ),
          if (discount > 0) ...[
            const Gap(12),
            Divider(color: AppColors.expense.withOpacity(0.2)),
            const Gap(8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Descontos aplicados',
                    style: TextStyle(color: AppColors.income, fontSize: 13)),
                Text(
                  '- ${formatCurrency(discount)}',
                  style: const TextStyle(
                      color: AppColors.income,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const Gap(4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Category Picker ───────────────────────────────────────────────────────

class _CategoryPicker extends ConsumerWidget {
  final CategoryModel? selected;
  final ValueChanged<CategoryModel> onChanged;

  const _CategoryPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categoria da despesa',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Gap(10),
        categoriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(color: AppColors.accent),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Erro ao carregar categorias: $e',
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ),
          data: (categories) {
            final expenseCategories = categories
                .where((c) => c.type == TransactionType.expense)
                .toList();

            if (expenseCategories.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        color: AppColors.warning, size: 18),
                    Gap(8),
                    Expanded(
                      child: Text(
                        'Categorias ainda sendo carregadas. Aguarde um momento.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 200,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.4,
                ),
                itemCount: expenseCategories.length,
                itemBuilder: (context, index) {
                  final cat = expenseCategories[index];
                  final isSelected = selected?.id == cat.id;
                  final color = _parseColor(cat.color);
                  return GestureDetector(
                    onTap: () => onChanged(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.15)
                            : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat.icon,
                              style: const TextStyle(fontSize: 14)),
                          const Gap(4),
                          Flexible(
                            child: Text(
                              cat.name,
                              style: TextStyle(
                                color: isSelected
                                    ? color
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

// ── Receipt Item Tile ─────────────────────────────────────────────────────

class _ReceiptItemTile extends StatelessWidget {
  final ReceiptItem item;
  const _ReceiptItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(
                  '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}'
                  ' ${item.unit} × ${formatCurrency(item.unitPrice)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const Gap(12),
          Text(
            formatCurrency(item.totalPrice),
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Installment Selector ──────────────────────────────────────────────────

class _InstallmentSelector extends StatelessWidget {
  final bool enabled;
  final int installments;
  final double total;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onChanged;

  const _InstallmentSelector({
    required this.enabled,
    required this.installments,
    required this.total,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parcelValue = total > 0 && installments > 0 ? total / installments : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.expense.withOpacity(0.06)
            : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled ? AppColors.expense.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => onToggle(!enabled),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppColors.expense.withOpacity(0.12)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.credit_card_outlined,
                      size: 18,
                      color: enabled ? AppColors.expense : AppColors.textSecondary,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parcelado',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: enabled ? AppColors.expense : null,
                          ),
                        ),
                        if (enabled && total > 0)
                          Text(
                            '$installments × ${formatCurrency(parcelValue)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.expense.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          const Text(
                            'Lançar automaticamente nos próximos meses',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: onToggle,
                    activeColor: AppColors.expense,
                  ),
                ],
              ),
            ),
          ),
          if (enabled) ...[
            Divider(height: 1, color: AppColors.expense.withOpacity(0.15), indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Número de parcelas',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const Gap(10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [2, 3, 4, 5, 6, 10, 12, 18, 24].map((n) {
                      final selected = installments == n;
                      return GestureDetector(
                        onTap: () => onChanged(n),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.expense : AppColors.expense.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${n}x',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : AppColors.expense,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}