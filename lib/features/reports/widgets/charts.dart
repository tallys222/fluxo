import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../reports/providers/reports_provider.dart';

// ── Monthly Bar Chart ─────────────────────────────────────────────────────

class MonthlyBarChart extends StatefulWidget {
  final List<MonthlyBalance> data;

  const MonthlyBarChart({super.key, required this.data});

  @override
  State<MonthlyBarChart> createState() => _MonthlyBarChartState();
}

class _MonthlyBarChartState extends State<MonthlyBarChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxY = widget.data
            .expand((m) => [m.income, m.expense])
            .fold(0.0, (a, b) => a > b ? a : b) *
        1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          children: [
            _LegendDot(color: AppColors.income, label: 'Receitas'),
            const Gap(16),
            _LegendDot(color: AppColors.expense, label: 'Despesas'),
          ],
        ),
        const Gap(16),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 100 : maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      isDark ? AppColors.cardDark : Colors.white,
                  tooltipRoundedRadius: 10,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final isIncome = rodIndex == 0;
                    return BarTooltipItem(
                      '${isIncome ? '↓' : '↑'} ${formatCurrencyCompact(rod.toY)}',
                      TextStyle(
                        color: isIncome ? AppColors.income : AppColors.expense,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
                touchCallback: (event, response) {
                  setState(() {
                    _touchedIndex =
                        response?.spot?.touchedBarGroupIndex ?? -1;
                  });
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                        formatCurrencyCompact(value),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.textLightSecondary
                              : AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= widget.data.length) {
                        return const SizedBox.shrink();
                      }
                      final month = widget.data[i].month;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('MMM', 'pt_BR').format(month),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _touchedIndex == i
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: _touchedIndex == i
                                ? AppColors.accent
                                : isDark
                                    ? AppColors.textLightSecondary
                                    : AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: (isDark ? Colors.white : Colors.black)
                      .withOpacity(0.05),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: widget.data.asMap().entries.map((entry) {
                final i = entry.key;
                final m = entry.value;
                final isTouched = _touchedIndex == i;

                return BarChartGroupData(
                  x: i,
                  groupVertically: false,
                  barRods: [
                    BarChartRodData(
                      toY: m.income,
                      color: AppColors.income
                          .withOpacity(isTouched ? 1 : 0.8),
                      width: isTouched ? 14 : 12,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                    BarChartRodData(
                      toY: m.expense,
                      color: AppColors.expense
                          .withOpacity(isTouched ? 1 : 0.8),
                      width: isTouched ? 14 : 12,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ],
                  barsSpace: 4,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const Gap(6),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontSize: 12)),
      ],
    );
  }
}

// ── Donut Chart ───────────────────────────────────────────────────────────

class DonutChart extends StatefulWidget {
  final List<CategorySummary> data;
  final String centerLabel;
  final String centerValue;

  const DonutChart({
    super.key,
    required this.data,
    required this.centerLabel,
    required this.centerValue,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int _touchedIndex = -1;

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Sem dados no período',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touchedIndex =
                        response?.touchedSection?.touchedSectionIndex ?? -1;
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 52,
              sections: widget.data.asMap().entries.map((entry) {
                final i = entry.key;
                final cat = entry.value;
                final isTouched = i == _touchedIndex;
                final color = _parseColor(cat.color);

                return PieChartSectionData(
                  color: color,
                  value: cat.amount,
                  title: isTouched
                      ? '${cat.percentage.toStringAsFixed(1)}%'
                      : '',
                  radius: isTouched ? 56 : 48,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.centerLabel,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 11),
              ),
              Text(
                widget.centerValue,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Balance Line Chart ────────────────────────────────────────────────────

class BalanceLineChart extends StatelessWidget {
  final List<MonthlyBalance> data;

  const BalanceLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.balance);
    }).toList();

    final minY =
        spots.map((s) => s.y).fold(0.0, (a, b) => a < b ? a : b) * 1.2;
    final maxY =
        spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY == 0 ? 100 : maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  isDark ? AppColors.cardDark : Colors.white,
              tooltipRoundedRadius: 10,
              getTooltipItems: (spots) => spots.map((spot) {
                final month = data[spot.x.toInt()].month;
                final label = DateFormat('MMM', 'pt_BR').format(month);
                return LineTooltipItem(
                  '$label\n${formatCurrency(spot.y)}',
                  TextStyle(
                    color: spot.y >= 0 ? AppColors.income : AppColors.expense,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    formatCurrencyCompact(value),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textLightSecondary
                          : AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('MMM', 'pt_BR').format(data[i].month),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textLightSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.accent,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: spot.y >= 0 ? AppColors.income : AppColors.expense,
                  strokeWidth: 2,
                  strokeColor: isDark ? AppColors.cardDark : Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.2),
                    AppColors.accent.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}