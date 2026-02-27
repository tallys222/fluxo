import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/reports_provider.dart';
import '../widgets/charts.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final reportsAsync = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(reportsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async => ref.invalidate(reportsProvider),
        child: CustomScrollView(
          slivers: [
            // ── Period selector ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _PeriodSelector(
                  selected: period,
                  onChanged: (p) =>
                      ref.read(reportPeriodProvider.notifier).state = p,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: Gap(20)),

            reportsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text(e.toString())),
              ),
              data: (data) => SliverList(
                delegate: SliverChildListDelegate([
                  // ── KPI cards ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _KpiRow(data: data),
                  ),
                  const Gap(24),

                  // ── Monthly bar chart ──────────────────────────────────
                  if (data.last6Months.length > 1) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _SectionCard(
                        title: 'Receitas vs Despesas',
                        subtitle: _periodLabel(period),
                        child: MonthlyBarChart(data: data.last6Months),
                      ),
                    ),
                    const Gap(16),
                  ],

                  // ── Balance line chart ─────────────────────────────────
                  if (data.last6Months.length > 1) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _SectionCard(
                        title: 'Evolução do saldo',
                        subtitle: 'Saldo mensal acumulado',
                        child: BalanceLineChart(data: data.last6Months),
                      ),
                    ),
                    const Gap(16),
                  ],

                  // ── Expenses donut ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionCard(
                      title: 'Despesas por categoria',
                      subtitle: _periodLabel(period),
                      child: data.expensesByCategory.isEmpty
                          ? const _EmptyChart(message: 'Nenhuma despesa no período')
                          : Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DonutChart(
                                    data: data.expensesByCategory,
                                    centerLabel: 'Total',
                                    centerValue: formatCurrencyCompact(
                                        data.totalExpense),
                                  ),
                                ),
                                const Gap(12),
                                Expanded(
                                  flex: 3,
                                  child: _CategoryLegend(
                                    categories: data.expensesByCategory,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const Gap(16),

                  // ── Income donut ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionCard(
                      title: 'Receitas por categoria',
                      subtitle: _periodLabel(period),
                      child: data.incomeByCategory.isEmpty
                          ? const _EmptyChart(message: 'Nenhuma receita no período')
                          : Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DonutChart(
                                    data: data.incomeByCategory,
                                    centerLabel: 'Total',
                                    centerValue: formatCurrencyCompact(
                                        data.totalIncome),
                                  ),
                                ),
                                const Gap(12),
                                Expanded(
                                  flex: 3,
                                  child: _CategoryLegend(
                                    categories: data.incomeByCategory,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const Gap(16),

                  // ── Top expenses ───────────────────────────────────────
                  if (data.topExpenses.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _SectionCard(
                        title: 'Maiores despesas',
                        subtitle: _periodLabel(period),
                        child: Column(
                          children: data.topExpenses
                              .map((e) => _TopExpenseTile(expense: e))
                              .toList(),
                        ),
                      ),
                    ),
                    const Gap(16),
                  ],

                  // ── Averages ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionCard(
                      title: 'Médias mensais',
                      subtitle: 'Com base no período selecionado',
                      child: _AveragesSection(data: data),
                    ),
                  ),

                  const Gap(100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(ReportPeriod p) => switch (p) {
        ReportPeriod.month1 => 'Último mês',
        ReportPeriod.month3 => 'Últimos 3 meses',
        ReportPeriod.month6 => 'Últimos 6 meses',
        ReportPeriod.month12 => 'Último ano',
      };
}

// ── Period Selector ───────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onChanged;

  const _PeriodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = {
      ReportPeriod.month1: '1M',
      ReportPeriod.month3: '3M',
      ReportPeriod.month6: '6M',
      ReportPeriod.month12: '1A',
    };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: options.entries.map((entry) {
          final isSelected = selected == entry.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── KPI Row ───────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final ReportsData data;
  const _KpiRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Total receitas',
                value: formatCurrency(data.totalIncome),
                icon: Icons.arrow_downward_rounded,
                color: AppColors.income,
              ),
            ),
            const Gap(12),
            Expanded(
              child: _KpiCard(
                label: 'Total despesas',
                value: formatCurrency(data.totalExpense),
                icon: Icons.arrow_upward_rounded,
                color: AppColors.expense,
              ),
            ),
          ],
        ),
        const Gap(12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Saldo período',
                value: formatCurrency(data.totalIncome - data.totalExpense),
                icon: Icons.account_balance_wallet_outlined,
                color: data.totalIncome >= data.totalExpense
                    ? AppColors.income
                    : AppColors.expense,
              ),
            ),
            const Gap(12),
            Expanded(
              child: _KpiCard(
                label: 'Taxa de economia',
                value: '${data.savingsRate.toStringAsFixed(1)}%',
                icon: Icons.savings_outlined,
                color: data.savingsRate >= 20
                    ? AppColors.income
                    : data.savingsRate >= 0
                        ? AppColors.warning
                        : AppColors.expense,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isDark ? const Color(0xFF263D52) : const Color(0xFFE8ECF0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Gap(2),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 12)),
          const Gap(20),
          child,
        ],
      ),
    );
  }
}

// ── Category Legend ───────────────────────────────────────────────────────

class _CategoryLegend extends StatelessWidget {
  final List<CategorySummary> categories;
  const _CategoryLegend({required this.categories});

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final top = categories.take(5).toList();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: top.map((c) {
        final color = _parseColor(c.color);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const Gap(8),
              Text(c.icon, style: const TextStyle(fontSize: 13)),
              const Gap(4),
              Expanded(
                child: Text(
                  c.name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${c.percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Top Expense Tile ──────────────────────────────────────────────────────

class _TopExpenseTile extends StatelessWidget {
  final TopExpense expense;
  const _TopExpenseTile({required this.expense});

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(expense.categoryColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(expense.categoryIcon,
                  style: const TextStyle(fontSize: 18)),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formatRelativeDate(expense.date),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            formatCurrency(expense.amount),
            style: const TextStyle(
              color: AppColors.expense,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Averages ──────────────────────────────────────────────────────────────

class _AveragesSection extends StatelessWidget {
  final ReportsData data;
  const _AveragesSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AverageRow(
          label: 'Média de receitas/mês',
          value: formatCurrency(data.averageMonthlyIncome),
          color: AppColors.income,
          icon: '📈',
        ),
        const Gap(12),
        _AverageRow(
          label: 'Média de despesas/mês',
          value: formatCurrency(data.averageMonthlyExpense),
          color: AppColors.expense,
          icon: '📉',
        ),
        const Gap(12),
        _AverageRow(
          label: 'Média de economia/mês',
          value: formatCurrency(
              data.averageMonthlyIncome - data.averageMonthlyExpense),
          color: data.averageMonthlyIncome >= data.averageMonthlyExpense
              ? AppColors.income
              : AppColors.expense,
          icon: '💰',
        ),
      ],
    );
  }
}

class _AverageRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String icon;

  const _AverageRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const Gap(12),
        Expanded(
          child: Text(label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  )),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ── Empty chart ───────────────────────────────────────────────────────────

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(message,
            style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}