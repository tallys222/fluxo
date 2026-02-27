import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/transactions/screens/transactions_screen.dart';
import '../../features/scanner/screens/scanner_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            const MaterialPage(child: RegisterScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) =>
            const MaterialPage(child: _ForgotPasswordScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HomeScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/transactions',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: TransactionsScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/scanner',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ScannerScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/reports',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ReportsScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ProfileScreen()),
            ),
          ]),
        ],
      ),
    ],
  );
});

class _ForgotPasswordScreen extends ConsumerStatefulWidget {
  const _ForgotPasswordScreen();
  @override
  ConsumerState<_ForgotPasswordScreen> createState() =>
      __ForgotPasswordScreenState();
}

class __ForgotPasswordScreenState extends ConsumerState<_ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sent
                  ? 'E-mail enviado! Verifique sua caixa de entrada.'
                  : 'Digite seu e-mail para receber o link de redefinição.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (!_sent) ...[
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: authState.isLoading
                    ? null
                    : () async {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .resetPassword(_emailController.text.trim());
                        setState(() => _sent = true);
                      },
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Enviar link'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}