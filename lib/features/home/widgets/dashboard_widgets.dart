import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../transactions/models/transaction_model.dart';

// ── Balance Card ──────────────────────────────────────────────────────────

class BalanceCard extends StatefulWidget {
  final double balance;
  final double income;
  final double expense;
  final String month;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
    required this.month,
  });

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF2D5F9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.month,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _hidden = !_hidden),
                child: Icon(
                  _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const Gap(8),
          const Text(
            'Saldo do mês',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const Gap(4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _hidden ? '••••••' : formatCurrency(widget.balance),
              key: ValueKey(_hidden),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const Gap(24),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Receitas',
                  value: _hidden ? '••••' : formatCurrencyCompact(widget.income),
                  color: AppColors.accent,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _MiniStat(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Despesas',
                  value: _hidden ? '••••' : formatCurrencyCompact(widget.expense),
                  color: const Color(0xFFFF7070),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const Gap(8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

// ── Summary Chip ──────────────────────────────────────────────────────────

class SavingsChip extends StatelessWidget {
  final double savingsRate;

  const SavingsChip({super.key, required this.savingsRate});

  @override
  Widget build(BuildContext context) {
    final isPositive = savingsRate >= 0;
    final color = isPositive ? AppColors.income : AppColors.expense;
    final emoji = savingsRate >= 30
        ? '🚀'
        : savingsRate >= 10
            ? '✅'
            : savingsRate >= 0
                ? '⚠️'
                : '🔴';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const Gap(6),
          Text(
            'Economia: ${savingsRate.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Bar ──────────────────────────────────────────────────────────

class CategoryProgressBar extends StatelessWidget {
  final String icon;
  final String name;
  final double amount;
  final double percentage;
  final String color;

  const CategoryProgressBar({
    super.key,
    required this.icon,
    required this.name,
    required this.amount,
    required this.percentage,
    required this.color,
  });

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final c = _parseColor(color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const Gap(10),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                formatCurrency(amount),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Gap(8),
              SizedBox(
                width: 40,
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: c,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Gap(6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: c.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(c),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction Tile ──────────────────────────────────────────────────────

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionTile({super.key, required this.transaction, this.onTap});

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final color = _parseColor(transaction.categoryColor);
    final amountColor = isExpense ? AppColors.expense : AppColors.income;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  transaction.categoryIcon,
                  style: const TextStyle(fontSize: 20),
                ),
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
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(2),
                  Text(
                    '${transaction.categoryName} · ${formatRelativeDate(transaction.date)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const Gap(8),
            Text(
              '${isExpense ? '-' : '+'} ${formatCurrency(transaction.amount)}',
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

// ── Loading Shimmer Card ──────────────────────────────────────────────────

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(_anim.value * 0.15),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}