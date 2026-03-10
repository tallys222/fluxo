import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final TransactionModel? existing; // null = new transaction

  const AddTransactionSheet({super.key, this.existing});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  CategoryModel? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isInstallment = false;
  int _installments = 2;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (_isEditing) {
      final t = widget.existing!;
      _titleController.text = t.title;
      _amountController.text = t.amount.toStringAsFixed(2).replaceAll('.', ',');
      _noteController.text = t.note ?? '';
      _type = t.type;
      _selectedDate = t.date;
      _tabController.index = t.type == TransactionType.expense ? 0 : 1;
    }

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _type = _tabController.index == 0
              ? TransactionType.expense
              : TransactionType.income;
          _selectedCategory = null;
        });
      }
    });

    // Rebuilda ao digitar o valor para atualizar preview das parcelas
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _parseAmount() {
    final raw = _amountController.text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma categoria'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final transaction = TransactionModel(
      id: widget.existing?.id ?? '',
      title: _titleController.text.trim(),
      amount: _parseAmount(),
      type: _type,
      categoryId: _selectedCategory!.id,
      categoryName: _selectedCategory!.name,
      categoryIcon: _selectedCategory!.icon,
      categoryColor: _selectedCategory!.color,
      date: _selectedDate,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    final notifier = ref.read(transactionFormProvider.notifier);
    final bool success;

    if (!_isEditing && _isInstallment && _installments > 1) {
      success = await notifier.saveInstallments(transaction, _installments);
    } else {
      success = _isEditing
          ? await notifier.update(transaction)
          : await notifier.save(transaction);
    }

    if (success && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(transactionFormProvider);
    final isLoading = formState.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(transactionFormProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        _isEditing ? 'Editar lançamento' : 'Novo lançamento',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Gap(20),

                      // Type tab
                      _TypeTabBar(controller: _tabController),
                      const Gap(20),

                      // Amount field
                      _AmountField(controller: _amountController, type: _type),
                      const Gap(16),

                      // Title field
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          prefixIcon: Icon(Icons.edit_outlined),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Informe a descrição' : null,
                      ),
                      const Gap(16),

                      // Category selector
                      _CategorySelector(
                        type: _type,
                        selected: _selectedCategory,
                        onChanged: (c) => setState(() => _selectedCategory = c),
                        initialCategoryName: widget.existing?.categoryName,
                      ),
                      const Gap(16),

                      // Date picker
                      _DateSelector(
                        date: _selectedDate,
                        onChanged: (d) => setState(() => _selectedDate = d),
                      ),
                      const Gap(16),

                      // Note field
                      TextFormField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observação (opcional)',
                          prefixIcon: Icon(Icons.note_outlined),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const Gap(16),

                      // Installment selector (only for new expenses)
                      if (!_isEditing && _type == TransactionType.expense)
                        _InstallmentSelector(
                          enabled: _isInstallment,
                          installments: _installments,
                          amount: _parseAmount(),
                          onToggle: (v) => setState(() => _isInstallment = v),
                          onChanged: (v) => setState(() => _installments = v),
                        ),
                      if (!_isEditing && _type == TransactionType.expense)
                        const Gap(16),

                      // Save button
                      ElevatedButton(
                        onPressed: isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _type == TransactionType.expense
                              ? AppColors.expense
                              : AppColors.income,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(_isEditing
                                ? 'Salvar alterações'
                                : (_isInstallment && _installments > 1)
                                    ? 'Lançar $_installments parcelas'
                                    : 'Adicionar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Type Tab Bar ──────────────────────────────────────────────────────────

class _TypeTabBar extends StatelessWidget {
  final TabController controller;
  const _TypeTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: controller.index == 0 ? AppColors.expense : AppColors.income,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: 'Despesa'),
          Tab(text: 'Receita'),
        ],
      ),
    );
  }
}

// ── Amount Field ──────────────────────────────────────────────────────────

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final TransactionType type;

  const _AmountField({required this.controller, required this.type});

  @override
  Widget build(BuildContext context) {
    final color =
        type == TransactionType.expense ? AppColors.expense : AppColors.income;

    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_CurrencyInputFormatter()],
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      decoration: InputDecoration(
        labelText: 'Valor',
        prefixText: 'R\$ ',
        prefixStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        filled: true,
        fillColor: color.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Informe o valor';
        final parsed = double.tryParse(v.replaceAll('.', '').replaceAll(',', '.'));
        if (parsed == null || parsed <= 0) return 'Valor inválido';
        return null;
      },
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    final value = int.parse(digits);
    final formatted = (value / 100).toStringAsFixed(2).replaceAll('.', ',');
    final withDots = _addThousandSeparator(formatted);

    return TextEditingValue(
      text: withDots,
      selection: TextSelection.collapsed(offset: withDots.length),
    );
  }

  String _addThousandSeparator(String value) {
    final parts = value.split(',');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? ',${parts[1]}' : '';
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
    }
    return '$buffer$decPart';
  }
}

// ── Category Selector ─────────────────────────────────────────────────────

class _CategorySelector extends ConsumerStatefulWidget {
  final TransactionType type;
  final CategoryModel? selected;
  final ValueChanged<CategoryModel> onChanged;
  final String? initialCategoryName;

  const _CategorySelector({
    required this.type,
    required this.selected,
    required this.onChanged,
    this.initialCategoryName,
  });

  @override
  ConsumerState<_CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends ConsumerState<_CategorySelector> {
  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return categoriesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
      data: (allCategories) {
        final filtered = allCategories
            .where((c) => c.type == widget.type)
            .toList();

        // Auto-select if editing and category matches
        if (widget.selected == null && widget.initialCategoryName != null) {
          final match = filtered
              .where((c) => c.name == widget.initialCategoryName)
              .firstOrNull;
          if (match != null) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => widget.onChanged(match));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Categoria',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Gap(10),
            SizedBox(
              height: 180,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.4,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final cat = filtered[index];
                  final isSelected = widget.selected?.id == cat.id;
                  final color = _parseColor(cat.color);
                  return GestureDetector(
                    onTap: () => widget.onChanged(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
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
                          Text(cat.icon, style: const TextStyle(fontSize: 14)),
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
            ),
          ],
        );
      },
    );
  }

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

// ── Date Selector ─────────────────────────────────────────────────────────

class _DateSelector extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _DateSelector({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat("dd 'de' MMMM 'de' yyyy", 'pt_BR').format(date);

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          locale: const Locale('pt', 'BR'),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context)
                  .colorScheme
                  .copyWith(primary: AppColors.accent),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 20, color: AppColors.textSecondary),
            const Gap(12),
            Text(
              formatted,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
// ── Installment Selector ──────────────────────────────────────────────────

class _InstallmentSelector extends StatelessWidget {
  final bool enabled;
  final int installments;
  final double amount;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onChanged;

  const _InstallmentSelector({
    required this.enabled,
    required this.installments,
    required this.amount,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parcelValue = amount > 0 && installments > 0
        ? amount / installments
        : 0.0;

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
          // Toggle row
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
                        if (enabled && amount > 0)
                          Text(
                            '$installments × R\$ ${parcelValue.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.expense.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          const Text(
                            'Lançar automaticamente nos próximos meses',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
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

          // Installments picker — visible only when enabled
          if (enabled) ...[
            Divider(
              height: 1,
              color: AppColors.expense.withOpacity(0.15),
              indent: 16,
              endIndent: 16,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Número de parcelas',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(10),
                  // Quick select chips: 2 3 4 5 6 10 12 18 24
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [2, 3, 4, 5, 6, 10, 12, 18, 24].map((n) {
                      final selected = installments == n;
                      return GestureDetector(
                        onTap: () => onChanged(n),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.expense
                                : AppColors.expense.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${n}x',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.expense,
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