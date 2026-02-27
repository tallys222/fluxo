import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/dashboard_provider.dart';
import '../providers/budget_allocations_provider.dart';
import 'budget_groups_config_sheet.dart';

// ── Grupos macro ──────────────────────────────────────────────────────────

class _MacroGroup {
  final String name;
  final String icon;
  final Color color;
  final List<String> keys;
  const _MacroGroup({required this.name, required this.icon, required this.color, required this.keys});
}

const _groups = [
  _MacroGroup(name: 'Alimentação',       icon: '🛒', color: Color(0xFF4CAF50), keys: ['alimentação','alimentacao','supermercado','restaurante','lanche']),
  _MacroGroup(name: 'Moradia',           icon: '🏠', color: Color(0xFF2196F3), keys: ['moradia','aluguel','financiamento']),
  _MacroGroup(name: 'Contas da Casa',    icon: '⚡', color: Color(0xFFFF9800), keys: ['condomínio','condominio','água','agua','energia','internet','telefone','gás','gas']),
  _MacroGroup(name: 'Transporte',        icon: '🚗', color: Color(0xFF9C27B0), keys: ['transporte','combustível','combustivel','uber','táxi','taxi','manutenção','manutencao']),
  _MacroGroup(name: 'Saúde',             icon: '🏥', color: Color(0xFFF44336), keys: ['saúde','saude','plano de saúde','plano de saude','farmácia','farmacia','dentista','academia']),
  _MacroGroup(name: 'Educação',          icon: '📚', color: Color(0xFF00BCD4), keys: ['educação','educacao','escola','faculdade','cursos','material escolar']),
  _MacroGroup(name: 'Lazer',             icon: '🎮', color: Color(0xFFE91E63), keys: ['lazer','streaming','viagem','hospedagem']),
  _MacroGroup(name: 'Vestuário & Beleza',icon: '👕', color: Color(0xFFFF5722), keys: ['vestuário','vestuario','calçados','calcados','beleza','cuidados pessoais']),
  _MacroGroup(name: 'Compras & Casa',    icon: '📦', color: Color(0xFF607D8B), keys: ['pets','compras online','eletrônicos','eletronicos','casa','decoração','decoracao']),
  _MacroGroup(name: 'Financeiro',        icon: '💳', color: Color(0xFF795548), keys: ['impostos','iptu','ipva','cartão','cartao','empréstimo','emprestimo','seguros']),
  _MacroGroup(name: 'Doações',           icon: '🤝', color: Color(0xFF9E9E9E), keys: ['doações','doacoes']),
  _MacroGroup(name: 'Outros',            icon: '📌', color: Color(0xFF78909C), keys: ['outros']),
];

class _GroupedExpense {
  final _MacroGroup group;
  final List<CategoryExpense> subs;
  _GroupedExpense({required this.group, required this.subs});
  double get total => subs.fold(0.0, (s, c) => s + c.amount);
}

_MacroGroup _matchGroup(String name) {
  final n = name.toLowerCase().trim();
  for (final g in _groups) {
    if (g.keys.any((k) => n.contains(k) || k.contains(n))) return g;
  }
  return _groups.last;
}

List<_GroupedExpense> _buildGroups(List<CategoryExpense> cats) {
  final map = <String, _GroupedExpense>{};
  for (final c in cats) {
    final g = _matchGroup(c.name);
    map.putIfAbsent(g.name, () => _GroupedExpense(group: g, subs: []));
    map[g.name]!.subs.add(c);
  }
  return map.values.toList()..sort((a, b) => b.total.compareTo(a.total));
}

// ── Sheet ─────────────────────────────────────────────────────────────────

class BudgetDetailSheet extends ConsumerWidget {
  final double budget;
  final double totalExpense;
  final List<CategoryExpense> categories;
  final DateTime month;

  const BudgetDetailSheet({
    super.key,
    required this.budget,
    required this.totalExpense,
    required this.categories,
    required this.month,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allocations = ref.watch(budgetAllocationsProvider).valueOrNull ?? [];
    final remaining = budget - totalExpense;
    final isOver = totalExpense > budget;
    final pct = budget > 0 ? (totalExpense / budget).clamp(0.0, 1.0) : 0.0;
    final barColor = pct >= 1.0 ? AppColors.error : pct >= 0.8 ? const Color(0xFFFF9800) : AppColors.income;
    final grouped = _buildGroups(categories);
    // map groupName -> allocation percent
    final allocMap = {for (final a in allocations) a.groupName: a.percent};

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Icon(Icons.account_balance_wallet_outlined, color: AppColors.accent, size: 20)),
                ),
                const Gap(12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Orçamento Mensal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    Text(formatMonthYearCapitalized(month), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                )),
                IconButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const BudgetGroupsConfigSheet(),
                  ),
                  icon: const Icon(Icons.tune_outlined),
                  tooltip: 'Configurar limites',
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Divider(height: 24, indent: 20, endIndent: 20, color: Colors.grey.withOpacity(0.15)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumo
                  _SummaryCard(isDark: isDark, budget: budget, totalExpense: totalExpense, remaining: remaining, isOver: isOver, pct: pct, barColor: barColor),
                  const Gap(24),
                  if (grouped.isNotEmpty) ...[
                    Text('📊 Distribuição dos gastos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const Gap(12),
                    ...grouped.asMap().entries.map((e) => _GroupCard(isDark: isDark, rank: e.key + 1, ge: e.value, budget: budget, allocPercent: allocMap[e.value.group.name])),
                    const Gap(24),
                    Text('📌 Resumo por grupo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const Gap(12),
                    _SummaryTable(isDark: isDark, groups: grouped, budget: budget),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final bool isDark;
  final double budget, totalExpense, remaining, pct;
  final bool isOver;
  final Color barColor;

  const _SummaryCard({required this.isDark, required this.budget, required this.totalExpense, required this.remaining, required this.isOver, required this.pct, required this.barColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [barColor.withOpacity(0.12), barColor.withOpacity(0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: barColor.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _Stat(label: 'Orçamento', value: formatCurrency(budget), color: AppColors.textSecondary)),
              Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.2)),
              Expanded(child: _Stat(label: 'Gasto', value: formatCurrency(totalExpense), color: AppColors.expense)),
              Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.2)),
              Expanded(child: _Stat(label: isOver ? 'Excedido' : 'Restante', value: formatCurrency(remaining.abs()), color: isOver ? AppColors.error : AppColors.income)),
            ],
          ),
          const Gap(16),
          Row(
            children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: pct, minHeight: 10, backgroundColor: Colors.grey.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(barColor)))),
              const Gap(10),
              Text('${(pct * 100).toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: barColor)),
            ],
          ),
          if (isOver) ...[
            const Gap(10),
            Row(children: [
              const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
              const Gap(6),
              Text('Excedido em ${formatCurrency(totalExpense - budget)}', style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500)),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    const Gap(4),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
  ]);
}

// ── Group Card ────────────────────────────────────────────────────────────

class _GroupCard extends StatefulWidget {
  final bool isDark;
  final int rank;
  final _GroupedExpense ge;
  final double budget;
  final double? allocPercent; // limit defined by user
  const _GroupCard({required this.isDark, required this.rank, required this.ge, required this.budget, this.allocPercent});
  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.ge;
    final color = g.group.color;
    final pct = widget.budget > 0 ? (g.total / widget.budget * 100) : 0.0;
    final canExpand = g.subs.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: canExpand ? () => setState(() => _open = !_open) : null,
            borderRadius: canExpand && _open
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(g.group.icon, style: const TextStyle(fontSize: 18)),
                  const Gap(10),
                  Expanded(child: Text('${widget.rank}. ${g.group.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                  Text(formatCurrency(g.total), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
                  if (canExpand) ...[const Gap(6), Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.textSecondary)],
                ]),
                const Gap(8),
                _GroupProgressBar(
                    spentPercent: pct,
                    limitPercent: widget.allocPercent,
                    color: color,
                    budget: widget.budget,
                  ),
              ]),
            ),
          ),
          if (_open && canExpand) ...[
            Divider(height: 1, indent: 14, endIndent: 14, color: Colors.grey.withOpacity(0.15)),
            ...g.subs.map((sub) => Padding(
              padding: const EdgeInsets.fromLTRB(46, 8, 14, 8),
              child: Row(children: [
                Text(sub.icon, style: const TextStyle(fontSize: 14)),
                const Gap(8),
                Expanded(child: Text(sub.name, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                Text(formatCurrency(sub.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            )),
            const Gap(4),
          ],
        ],
      ),
    );
  }
}

// ── Summary Table ─────────────────────────────────────────────────────────

class _SummaryTable extends StatelessWidget {
  final bool isDark;
  final List<_GroupedExpense> groups;
  final double budget;
  const _SummaryTable({required this.isDark, required this.groups, required this.budget});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: const [
            Expanded(child: Text('Grupo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
            SizedBox(width: 90, child: Text('Valor', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
            SizedBox(width: 50, child: Text('do orç.', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
          ]),
        ),
        Divider(height: 1, color: Colors.grey.withOpacity(0.15)),
        ...groups.asMap().entries.map((e) {
          final g = e.value;
          final pct = budget > 0 ? (g.total / budget * 100) : 0.0;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Text(g.group.icon, style: const TextStyle(fontSize: 14)),
                const Gap(8),
                Expanded(child: Text(g.group.name, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                SizedBox(width: 90, child: Text(formatCurrency(g.total), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                SizedBox(width: 50, child: Text('${pct.toStringAsFixed(1)}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ]),
            ),
            if (e.key < groups.length - 1) Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey.withOpacity(0.1)),
          ]);
        }),
      ]),
    );
  }
}


// ── Group Progress Bar ────────────────────────────────────────────────────

class _GroupProgressBar extends StatelessWidget {
  final double spentPercent;   // % of total budget spent in this group
  final double? limitPercent;  // % limit configured by user
  final Color color;
  final double budget;         // total monthly budget in R$

  const _GroupProgressBar({
    required this.spentPercent,
    required this.limitPercent,
    required this.color,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final hasLimit = limitPercent != null && limitPercent! > 0;
    final limit = limitPercent ?? 0.0;
    final isOver = hasLimit && spentPercent > limit;
    final barValue = hasLimit
        ? (spentPercent / limit).clamp(0.0, 1.0)
        : (spentPercent / 100).clamp(0.0, 1.0);
    final barColor = isOver
        ? AppColors.error
        : (hasLimit && spentPercent >= limit * 0.8)
            ? const Color(0xFFFF9800)
            : color;

    // Valores em reais
    final spentAmount  = budget * spentPercent / 100;
    final limitAmount  = budget * limit / 100;
    final remainAmount = limitAmount - spentAmount;

    // % exibido: relativo à META do grupo (quando configurada), não ao orçamento total
    final displayedPercent = hasLimit
        ? (spentPercent / limit * 100).clamp(0.0, 999.0)
        : spentPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: barValue,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
            const Gap(8),
            Text(
              '${displayedPercent.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: barColor),
            ),
          ],
        ),
        if (hasLimit) ...[
          const Gap(5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Gasto
              Row(children: [
                Icon(Icons.arrow_upward_rounded, size: 11, color: AppColors.textSecondary),
                const Gap(3),
                Text(
                  'Gasto: ${formatCurrency(spentAmount)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ]),
              // Restante ou Excedido
              Row(children: [
                Icon(
                  isOver ? Icons.warning_amber_rounded : Icons.savings_outlined,
                  size: 11,
                  color: isOver ? AppColors.error : AppColors.income,
                ),
                const Gap(3),
                Text(
                  isOver
                      ? 'Excedido: ${formatCurrency(remainAmount.abs())}'
                      : 'Disponível: ${formatCurrency(remainAmount)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isOver ? AppColors.error : AppColors.income,
                  ),
                ),
              ]),
            ],
          ),
        ],
      ],
    );
  }
}