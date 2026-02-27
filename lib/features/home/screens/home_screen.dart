import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_widgets.dart';
import '../../profile/providers/profile_provider.dart';
import 'budget_detail_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final userName = ref.watch(userNameProvider);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            userName,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: Stack(
                              children: [
                                const Icon(Icons.notifications_outlined, size: 26),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Month selector ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _MonthSelector(
                    selected: selectedMonth,
                    currentMonth: currentMonth,
                    onChanged: (m) =>
                        ref.read(selectedMonthProvider.notifier).state = m,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: Gap(16)),

              // ── Balance card ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: dashboardAsync.when(
                    loading: () => _BalanceCardSkeleton(),
                    error: (e, _) => _ErrorCard(message: e.toString()),
                    data: (data) => BalanceCard(
                      balance: data.balance,
                      income: data.totalIncome,
                      expense: data.totalExpense,
                      month: formatMonthYearCapitalized(data.month),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: Gap(12)),

              // ── Savings chip ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: dashboardAsync.whenData((data) => Row(
                        children: [
                          SavingsChip(savingsRate: data.savingsRate),
                        ],
                      )).valueOrNull,
                ),
              ),

              const SliverToBoxAdapter(child: Gap(16)),

              // ── Budget progress ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _BudgetProgressCard(
                    dashboardAsync: dashboardAsync,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: Gap(28)),

              // ── Quick actions ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _QuickAction(
                        icon: Icons.add_circle_outline,
                        label: 'Receita',
                        color: AppColors.income,
                        onTap: () => context.go('/transactions'),
                      ),
                      const Gap(12),
                      _QuickAction(
                        icon: Icons.remove_circle_outline,
                        label: 'Despesa',
                        color: AppColors.expense,
                        onTap: () => context.go('/transactions'),
                      ),
                      const Gap(12),
                      _QuickAction(
                        icon: Icons.qr_code_scanner,
                        label: 'Escanear',
                        color: AppColors.primary,
                        onTap: () => context.go('/scanner'),
                      ),
                      const Gap(12),
                      _QuickAction(
                        icon: Icons.pie_chart_outline,
                        label: 'Relatório',
                        color: const Color(0xFF9C27B0),
                        onTap: () => context.go('/reports'),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: Gap(28)),

              // ── Top categories ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      SectionHeader(
                        title: 'Por categoria',
                        actionLabel: 'Ver tudo',
                        onAction: () => context.go('/reports'),
                      ),
                      const Gap(12),
                      dashboardAsync.when(
                        loading: () => const _CategoriesSkeleton(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (data) => data.topCategories.isEmpty
                            ? _EmptyState(
                                icon: '📊',
                                message: 'Nenhum gasto registrado este mês',
                              )
                            : Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: data.topCategories
                                        .map((c) => CategoryProgressBar(
                                              icon: c.icon,
                                              name: c.name,
                                              amount: c.amount,
                                              percentage: c.percentage,
                                              color: c.color,
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: Gap(28)),

              // ── Recent transactions ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SectionHeader(
                    title: 'Últimas transações',
                    actionLabel: 'Ver todas',
                    onAction: () => context.go('/transactions'),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: Gap(12)),

              dashboardAsync.when(
                loading: () => SliverToBoxAdapter(child: _TransactionsSkeleton()),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                data: (data) => data.recentTransactions.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _EmptyState(
                            icon: '💸',
                            message: 'Nenhuma transação este mês',
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final t = data.recentTransactions[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  TransactionTile(transaction: t),
                                  if (index < data.recentTransactions.length - 1)
                                    Divider(
                                      height: 1,
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.black.withOpacity(0.06),
                                    ),
                                ],
                              ),
                            );
                          },
                          childCount: data.recentTransactions.length,
                        ),
                      ),
              ),

              const SliverToBoxAdapter(child: Gap(100)),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia,';
    if (hour < 18) return 'Boa tarde,';
    return 'Boa noite,';
  }
}

// ── Month Selector ─────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  final DateTime selected;
  final DateTime currentMonth;
  final ValueChanged<DateTime> onChanged;

  const _MonthSelector({
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
        GestureDetector(
          onTap: () => _showMonthPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 16, color: AppColors.accent),
                const Gap(6),
                Text(
                  formatMonthYearCapitalized(selected),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.chevron_right,
            color: canGoForward ? null : Colors.transparent,
          ),
          onPressed: canGoForward
              ? () => onChanged(DateTime(selected.year, selected.month + 1))
              : null,
        ),
      ],
    );
  }

  void _showMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MonthPickerSheet(
        selected: selected,
        currentMonth: currentMonth,
        onChanged: (m) {
          onChanged(m);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _MonthPickerSheet extends StatelessWidget {
  final DateTime selected;
  final DateTime currentMonth;
  final ValueChanged<DateTime> onChanged;

  const _MonthPickerSheet({
    required this.selected,
    required this.currentMonth,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final months = List.generate(12, (i) {
      final d = DateTime(currentMonth.year, currentMonth.month - i);
      return d;
    }).where((d) => d.year >= 2024).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selecionar mês',
              style: Theme.of(context).textTheme.titleLarge),
          const Gap(16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: months.map((m) {
              final isSelected =
                  m.month == selected.month && m.year == selected.year;
              return GestureDetector(
                onTap: () => onChanged(m),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.accent.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    formatMonthYearCapitalized(m),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Gap(24),
        ],
      ),
    );
  }
}

// ── Quick Action ──────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const Gap(6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 36)),
          const Gap(12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Error Card ───────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const Gap(12),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Skeletons ─────────────────────────────────────────────────────────────

class _BalanceCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 100, height: 14),
          const Gap(12),
          ShimmerBox(width: 200, height: 36),
          const Spacer(),
          Row(children: [
            ShimmerBox(width: 100, height: 40),
            const Gap(16),
            ShimmerBox(width: 100, height: 40),
          ]),
        ],
      ),
    );
  }
}

class _CategoriesSkeleton extends StatelessWidget {
  const _CategoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ShimmerBox(width: 36, height: 36, radius: 10),
              const Gap(12),
              Expanded(child: ShimmerBox(width: double.infinity, height: 14)),
              const Gap(12),
              ShimmerBox(width: 60, height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              ShimmerBox(width: 44, height: 44, radius: 12),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 160, height: 14),
                    const Gap(6),
                    ShimmerBox(width: 100, height: 12),
                  ],
                ),
              ),
              ShimmerBox(width: 80, height: 14),
            ],
          ),
        ),
      ),
    );
  }
}


// ── Budget Progress Card ──────────────────────────────────────────────────

class _BudgetProgressCard extends ConsumerWidget {
  final AsyncValue<DashboardSummary> dashboardAsync;
  const _BudgetProgressCard({required this.dashboardAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final budget = (profileAsync.valueOrNull?.monthlyBudget ?? 0.0).toDouble();

    // Sem orçamento configurado: não mostra nada
    if (budget <= 0) return const SizedBox.shrink();

    final expense = (dashboardAsync.valueOrNull?.totalExpense ?? 0.0).toDouble();
    final percent = (expense / budget).clamp(0.0, 1.0);
    final remaining = budget - expense;
    final isOver = expense > budget;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Cor da barra muda conforme uso
    final Color barColor;
    if (percent >= 1.0) {
      barColor = AppColors.error;
    } else if (percent >= 0.8) {
      barColor = const Color(0xFFFF9800); // laranja
    } else {
      barColor = AppColors.income;
    }

    void openDetail() => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetDetailSheet(
        budget: budget,
        totalExpense: expense,
        categories: dashboardAsync.valueOrNull?.topCategories ?? [],
        month: dashboardAsync.valueOrNull?.month ?? DateTime.now(),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: openDetail,
        borderRadius: BorderRadius.circular(16),
        child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOver
              ? AppColors.error.withOpacity(0.4)
              : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isOver
                        ? Icons.warning_amber_rounded
                        : Icons.account_balance_wallet_outlined,
                    size: 16,
                    color: isOver ? AppColors.error : AppColors.textSecondary,
                  ),
                  const Gap(6),
                  Text(
                    'Orçamento mensal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isOver ? AppColors.error : null,
                    ),
                  ),
                ],
              ),
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ],
          ),
          const Gap(10),
          // Barra de progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: Colors.grey.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const Gap(10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gasto: ${formatCurrency(expense)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                isOver
                    ? 'Excedido em ${formatCurrency(expense - budget)}'
                    : 'Restam ${formatCurrency(remaining)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOver ? AppColors.error : AppColors.income,
                ),
              ),
            ],
          ),
        ],
      ),
    ), // Container
      ), // InkWell
    ); // Material
  }
}