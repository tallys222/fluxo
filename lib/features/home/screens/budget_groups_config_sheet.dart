import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/budget_allocations_provider.dart';

// Lista dos grupos macro (deve bater com budget_detail_sheet.dart)
const _groupDefs = [
  ('🛒', 'Alimentação'),
  ('🏠', 'Moradia'),
  ('⚡', 'Contas da Casa'),
  ('🚗', 'Transporte'),
  ('🏥', 'Saúde'),
  ('📚', 'Educação'),
  ('🎮', 'Lazer'),
  ('👕', 'Vestuário & Beleza'),
  ('📦', 'Compras & Casa'),
  ('💳', 'Financeiro'),
  ('🤝', 'Doações'),
  ('📌', 'Outros'),
];

class BudgetGroupsConfigSheet extends ConsumerStatefulWidget {
  const BudgetGroupsConfigSheet({super.key});

  @override
  ConsumerState<BudgetGroupsConfigSheet> createState() =>
      _BudgetGroupsConfigSheetState();
}

class _BudgetGroupsConfigSheetState
    extends ConsumerState<BudgetGroupsConfigSheet> {
  // percentuais editáveis: groupName -> percent
  final Map<String, double> _percents = {};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final existing = ref.read(budgetAllocationsProvider).valueOrNull ?? [];
      for (final def in _groupDefs) {
        final saved = existing.where((a) => a.groupName == def.$2).firstOrNull;
        _percents[def.$2] = saved?.percent ?? 0.0;
      }
      _initialized = true;
    }
  }

  double get _totalPercent =>
      _percents.values.fold(0.0, (s, v) => s + v);

  double get _remaining => 100.0 - _totalPercent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final budget = ref.watch(userProfileProvider).valueOrNull?.monthlyBudget ?? 0.0;
    final total = _totalPercent;
    final over = total > 100;
    final exact = (total - 100).abs() < 0.1;

    // Cor do indicador
    final Color indicatorColor =
        over ? AppColors.error : exact ? AppColors.income : AppColors.accent;

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
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Center(
                      child: Icon(Icons.pie_chart_outline,
                          color: AppColors.accent, size: 20)),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Distribuição do orçamento',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        budget > 0
                            ? 'Orçamento: ${formatCurrency(budget)}'
                            : 'Configure o orçamento mensal no perfil',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
          ),

          // Indicador de total alocado
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: indicatorColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: indicatorColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    over
                        ? '⚠️ Excedeu o orçamento'
                        : exact
                            ? '✅ Orçamento distribuído'
                            : '📊 Alocado: ${total.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: indicatorColor),
                  ),
                  Text(
                    over
                        ? '+${(total - 100).toStringAsFixed(1)}%'
                        : 'Restam ${_remaining.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: indicatorColor),
                  ),
                ],
              ),
            ),
          ),

          Divider(
              height: 20,
              indent: 20,
              endIndent: 20,
              color: Colors.grey.withOpacity(0.15)),

          // Lista de grupos
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              children: _groupDefs.map((def) {
                final icon = def.$1;
                final name = def.$2;
                final pct = _percents[name] ?? 0.0;
                final value =
                    budget > 0 ? budget * pct / 100 : 0.0;

                return _GroupSlider(
                  isDark: isDark,
                  icon: icon,
                  name: name,
                  percent: pct,
                  valueAmount: value,
                  budget: budget,
                  onChanged: (v) => setState(() => _percents[name] = v),
                );
              }).toList(),
            ),
          ),

          // Botão salvar
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: over ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  disabledBackgroundColor: AppColors.error.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  over ? 'Reduza o total para salvar' : 'Salvar distribuição',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final allocations = _percents.entries
        .where((e) => e.value > 0)
        .map((e) => BudgetGroupAllocation(groupName: e.key, percent: e.value))
        .toList();

    final ok = await ref
        .read(budgetAllocationsNotifierProvider.notifier)
        .save(allocations);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Distribuição salva!' : 'Erro ao salvar.'),
        backgroundColor: ok ? AppColors.income : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      if (ok) Navigator.pop(context);
    }
  }
}

// ── Group Slider ──────────────────────────────────────────────────────────

class _GroupSlider extends StatelessWidget {
  final bool isDark;
  final String icon;
  final String name;
  final double percent;
  final double valueAmount;
  final double budget;
  final ValueChanged<double> onChanged;

  const _GroupSlider({
    required this.isDark,
    required this.icon,
    required this.name,
    required this.percent,
    required this.valueAmount,
    required this.budget,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const Gap(10),
              Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14))),
              // Percentual editável ao tocar
              GestureDetector(
                onTap: () => _editManually(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: Colors.grey.withOpacity(0.2),
              thumbColor: AppColors.accent,
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: percent.clamp(0.0, 100.0),
              min: 0,
              max: 100,
              divisions: 200, // 0.5% steps
              onChanged: (v) => onChanged(
                  double.parse(v.toStringAsFixed(1))),
            ),
          ),
          if (budget > 0 && percent > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Text(
                '≈ ${formatCurrency(valueAmount)} / mês',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editManually(BuildContext context) async {
    final ctrl =
        TextEditingController(text: percent > 0 ? percent.toStringAsFixed(1) : '');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$icon $name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(labelText: 'Percentual (%)', suffixText: '%'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(
                      ctrl.text.replaceAll(',', '.')) ??
                  0.0;
              Navigator.pop(ctx, v.clamp(0.0, 100.0));
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null) onChanged(result);
  }
}