import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../home/widgets/dashboard_widgets.dart';
import '../providers/reports_provider.dart';
import '../services/report_pdf_service.dart';
import '../widgets/charts.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);

    try {
      final period = ref.read(reportPeriodProvider);

      // Força o carregamento dos dados necessários
      final reportsData = await ref.read(reportsProvider.future);
      final transactions = await ref.read(reportTransactionsProvider.future);

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => _ExportOptionsSheet(
          onPreview: () async {
            Navigator.pop(sheetCtx);
            final pdfBytes =
                await _generateBytes(reportsData, period, transactions);
            await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
          },
          onShare: () async {
            Navigator.pop(sheetCtx);
            final file = await ReportPdfService().generate(
              data: reportsData,
              period: period,
              transactions: transactions,
            );
            await Share.shareXFiles(
              [XFile(file.path)],
              subject: 'Relatório Financeiro — Fluxo',
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar relatório: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<Uint8List> _generateBytes(reportsData, period, transactions) async {
    final file = await ReportPdfService().generate(
      data: reportsData,
      period: period,
      transactions: transactions,
    );
    return file.readAsBytesSync();
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(reportPeriodProvider);
    final reportsAsync = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: AppColors.accent, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Exportar relatório',
              onPressed: _export,
            ),
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
                  const Gap(16),

                  // ── Trend Analysis ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _TrendSection(),
                  ),
                  const Gap(8),

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

// ── Export Options Sheet ──────────────────────────────────────────────────

class _ExportOptionsSheet extends StatelessWidget {
  final VoidCallback onPreview;
  final VoidCallback onShare;

  const _ExportOptionsSheet({required this.onPreview, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(20),
          Text('Exportar Relatório',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Gap(6),
          Text(
            'Escolha como deseja exportar o relatório em PDF',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const Gap(24),
          _OptionTile(
            icon: Icons.visibility_outlined,
            color: AppColors.accent,
            title: 'Visualizar PDF',
            subtitle: 'Abre o relatório para visualização e impressão',
            onTap: onPreview,
          ),
          const Gap(12),
          _OptionTile(
            icon: Icons.share_outlined,
            color: AppColors.income,
            title: 'Compartilhar',
            subtitle: 'Compartilha o arquivo PDF via WhatsApp, e-mail, Drive...',
            onTap: onShare,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const Gap(2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

// ── Trend Section ─────────────────────────────────────────────────────────

class _TrendSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(trendProvider);

    return trendAsync.when(
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.trends.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(16),
            // Header com visão geral
            _SectionCard(
              title: 'Análise de tendência',
              subtitle: 'Mês atual vs média dos últimos 3 meses',
              child: Column(
                children: [
                  // Banner geral
                  _OverallTrendBanner(data: data),
                  const Gap(16),
                  const Divider(height: 1),
                  const Gap(16),
                  // Lista de categorias
                  ...data.trends.map((t) => _CategoryTrendTile(trend: t)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OverallTrendBanner extends StatelessWidget {
  final TrendData data;
  const _OverallTrendBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final dir = data.overallDirection;
    final color = dir == TrendDirection.up
        ? AppColors.expense
        : dir == TrendDirection.down
            ? AppColors.income
            : AppColors.textSecondary;

    final icon = dir == TrendDirection.up
        ? Icons.trending_up_rounded
        : dir == TrendDirection.down
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;

    final label = dir == TrendDirection.up
        ? 'Gastos em alta este mês'
        : dir == TrendDirection.down
            ? 'Gastos em queda este mês'
            : 'Gastos estáveis este mês';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14, color: color)),
                const Gap(2),
                Text(
                  'Este mês: ${formatCurrency(data.totalCurrentMonth)}\n'
                  'Média anterior: ${formatCurrency(data.totalPreviousAvg)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Gap(8),
          _TrendBadge(percent: data.overallChangePercent, direction: data.overallDirection),
        ],
      ),
    );
  }
}

class _CategoryTrendTile extends StatelessWidget {
  final CategoryTrend trend;
  const _CategoryTrendTile({required this.trend});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(trend.color);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícone categoria
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(trend.icon, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const Gap(10),
          // Nome + barra + valores
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trend.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const Gap(4),
                _TrendBar(
                  current: trend.currentMonth,
                  previous: trend.previousAvg,
                  color: color,
                ),
                const Gap(3),
                Text(
                  '${formatCurrency(trend.currentMonth)}  vs  ${formatCurrency(trend.previousAvg)} (média)',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Gap(8),
          // Badge — largura fixa para não causar overflow
          SizedBox(
            width: 80,
            child: _TrendBadge(
              percent: trend.changePercent,
              direction: trend.direction,
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

class _TrendBar extends StatelessWidget {
  final double current;
  final double previous;
  final Color color;

  const _TrendBar({
    required this.current,
    required this.previous,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final max = [current, previous].reduce((a, b) => a > b ? a : b);
    if (max == 0) return const SizedBox(height: 6);

    final currentRatio = (current / max).clamp(0.0, 1.0);
    final previousRatio = (previous / max).clamp(0.0, 1.0);

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return SizedBox(
        height: 6,
        child: Stack(
          children: [
            // Fundo (mês anterior = cinza)
            Container(
              width: width * previousRatio,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Frente (mês atual = cor da categoria)
            Container(
              width: width * currentRatio,
              height: 6,
              decoration: BoxDecoration(
                color: color.withOpacity(0.7),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _TrendBadge extends StatelessWidget {
  final double percent;
  final TrendDirection direction;

  const _TrendBadge({required this.percent, required this.direction});

  @override
  Widget build(BuildContext context) {
    final color = direction == TrendDirection.up
        ? AppColors.expense
        : direction == TrendDirection.down
            ? AppColors.income
            : AppColors.textSecondary;

    final icon = direction == TrendDirection.up
        ? Icons.arrow_upward_rounded
        : direction == TrendDirection.down
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded;

    final sign = percent > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const Gap(2),
            Text(
              '$sign${percent.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}