import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final statsAsync = ref.watch(profileStatsProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          ref.invalidate(userProfileProvider);
          ref.invalidate(profileStatsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + name
              profileAsync.when(
                loading: () => const _ProfileHeaderSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (profile) => _ProfileHeader(
                  name: profile?.name ?? '',
                  email: profile?.email ?? '',
                  onEditName: () => _showEditNameDialog(
                      context, ref, profile?.name ?? ''),
                ),
              ),
              const Gap(20),

              // Stats
              statsAsync.when(
                loading: () => const SizedBox(height: 72),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => _StatsRow(stats: stats),
              ),
              const Gap(28),

              // Budget
              const _SectionTitle(title: 'Orçamento mensal'),
              const Gap(12),
              profileAsync.when(
                loading: () => const SizedBox(height: 80),
                error: (_, __) => const SizedBox.shrink(),
                data: (profile) => _BudgetCard(
                  current: profile?.monthlyBudget ?? 0,
                  onEdit: () => _showBudgetDialog(
                      context, ref, profile?.monthlyBudget ?? 0),
                ),
              ),
              const Gap(28),

              // Theme
              const _SectionTitle(title: 'Aparência'),
              const Gap(12),
              _ThemeSelector(
                current: themeMode,
                onChanged: (m) =>
                    ref.read(themeModeProvider.notifier).setTheme(m),
              ),
              const Gap(28),

              // Account
              const _SectionTitle(title: 'Conta'),
              const Gap(12),
              _SettingsCard(
                items: [
                  _SettingItem(
                    icon: Icons.person_outline,
                    label: 'Editar nome',
                    onTap: () => _showEditNameDialog(
                        context, ref, profileAsync.valueOrNull?.name ?? ''),
                  ),
                  _SettingItem(
                    icon: Icons.lock_outline,
                    label: 'Alterar senha',
                    onTap: () => _showChangePasswordDialog(context, ref),
                  ),
                  _SettingItem(
                    icon: Icons.email_outlined,
                    label: profileAsync.valueOrNull?.email ?? '',
                    onTap: null,
                    isInfo: true,
                  ),
                ],
              ),
              const Gap(16),

              // Support
              const _SectionTitle(title: 'Suporte'),
              const Gap(12),
              _SettingsCard(
                items: [
                  _SettingItem(
                    icon: Icons.info_outline,
                    label: 'Sobre o Fluxo',
                    onTap: () => _showAboutDialog(context),
                  ),
                  _SettingItem(
                    icon: Icons.bug_report_outlined,
                    label: 'Versão 1.0.0',
                    onTap: null,
                    isInfo: true,
                  ),
                ],
              ),
              const Gap(28),

              // Logout
              _LogoutButton(onTap: () => _confirmLogout(context, ref)),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditNameDialog(
      BuildContext context, WidgetRef ref, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Editar nome'),
        content: TextFormField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome completo'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogCtx);
              final ok = await ref
                  .read(profileNotifierProvider.notifier)
                  .updateName(name);
              if (ok) ref.invalidate(userProfileProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Nome atualizado!' : 'Erro ao atualizar.'),
                  backgroundColor: ok ? AppColors.income : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showBudgetDialog(
      BuildContext context, WidgetRef ref, double current) {
    final controller = TextEditingController(
        text: current > 0
            ? current.toStringAsFixed(2).replaceAll('.', ',')
            : '');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Orçamento mensal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Defina quanto pretende gastar por mês.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const Gap(16),
            TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Valor mensal', prefixText: 'R\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final raw = controller.text.replaceAll('.', '').replaceAll(',', '.');
              final value = double.tryParse(raw) ?? 0;
              Navigator.pop(dialogCtx);
              final ok = await ref
                  .read(profileNotifierProvider.notifier)
                  .updateBudget(value);
              if (ok) ref.invalidate(userProfileProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      ok ? 'Orçamento atualizado!' : 'Erro ao atualizar.'),
                  backgroundColor: ok ? AppColors.income : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Alterar senha'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nova senha'),
                validator: (v) =>
                    v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const Gap(12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmar'),
                validator: (v) =>
                    v != newCtrl.text ? 'Senhas diferentes' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(firebaseAuthProvider)
                    .currentUser!
                    .updatePassword(newCtrl.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Senha atualizada!'),
                    backgroundColor: AppColors.income,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Faça logout e login novamente para alterar a senha.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Fluxo',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.account_balance_wallet,
            color: Colors.white, size: 28),
      ),
      children: const [
        Text('Gestão financeira inteligente com escaneamento de NF-e.'),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Você será desconectado do Fluxo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(profileNotifierProvider.notifier).signOut();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

// ── Profile Header ────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onEditName;

  const _ProfileHeader(
      {required this.name, required this.email, required this.onEditName});

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onEditName,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                    color: AppColors.accent, shape: BoxShape.circle),
                child:
                    const Icon(Icons.edit, size: 12, color: Colors.white),
              ),
            ),
          ),
        ]),
        const Gap(16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.isNotEmpty ? name : 'Usuário',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Gap(2),
              Text(email,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final ProfileStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _StatCard(
                value: stats.transactionCount.toString(),
                label: 'Lançamentos',
                icon: '💸')),
        const Gap(10),
        Expanded(
            child: _StatCard(
                value: stats.receiptCount.toString(),
                label: 'NF-e',
                icon: '🧾')),
        const Gap(10),
        Expanded(
            child: _StatCard(
                value: '${stats.monthsActive}m',
                label: 'No app',
                icon: '📅')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  const _StatCard(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF263D52) : const Color(0xFFE8ECF0),
        ),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const Gap(6),
          Text(value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800, color: AppColors.accent)),
          const Gap(2),
          Text(label,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Budget Card ───────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final double current;
  final VoidCallback onEdit;
  const _BudgetCard({required this.current, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBudget = current > 0;
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDark ? const Color(0xFF263D52) : const Color(0xFFE8ECF0),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.savings_outlined,
                  color: AppColors.accent, size: 22),
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Limite mensal de gastos',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const Gap(2),
                  Text(
                    hasBudget ? formatCurrency(current) : 'Toque para definir',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: hasBudget
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Theme Selector ────────────────────────────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = [
      (ThemeMode.light, Icons.wb_sunny_outlined, 'Claro'),
      (ThemeMode.dark, Icons.nightlight_outlined, 'Escuro'),
      (ThemeMode.system, Icons.phone_android_outlined, 'Sistema'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF263D52) : const Color(0xFFE8ECF0),
        ),
      ),
      child: Row(
        children: options.map((opt) {
          final (mode, icon, label) = opt;
          final isSelected = current == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSelected
                          ? AppColors.accent
                          : Colors.transparent),
                ),
                child: Column(
                  children: [
                    Icon(icon,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        size: 22),
                    const Gap(6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Settings Card ─────────────────────────────────────────────────────────

class _SettingItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isInfo;
  const _SettingItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.isInfo = false});
}

class _SettingsCard extends StatelessWidget {
  final List<_SettingItem> items;
  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF263D52) : const Color(0xFFE8ECF0),
        ),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon,
                            color: AppColors.accent, size: 18),
                      ),
                      const Gap(14),
                      Expanded(
                        child: Text(item.label,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: item.isInfo
                                          ? AppColors.textSecondary
                                          : null,
                                      fontSize: 14,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (item.onTap != null)
                        const Icon(Icons.chevron_right,
                            color: AppColors.textSecondary, size: 20),
                    ],
                  ),
                ),
              ),
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.05),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5));
  }
}

// ── Logout Button ─────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.logout, color: AppColors.error),
        label: const Text('Sair da conta',
            style: TextStyle(color: AppColors.error)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────

class _ProfileHeaderSkeleton extends StatelessWidget {
  const _ProfileHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
        ),
        const Gap(16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                width: 140,
                height: 20,
                decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6))),
            const Gap(8),
            Container(
                width: 200,
                height: 14,
                decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6))),
          ],
        ),
      ],
    );
  }
}