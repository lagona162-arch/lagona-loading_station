import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/registration_page.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/deliveries/presentation/deliveries_page.dart';
import '../../features/merchants/presentation/merchants_page.dart';
import '../../features/riders/presentation/riders_page.dart';
import '../../features/shell/home_shell_page.dart';
import '../../features/topup/presentation/topup_page.dart';
import '../config/supabase_config.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_goRouterRefreshNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final session = ref.read(sessionStreamProvider).valueOrNull;
      final loggingIn = state.fullPath == '/login';
      final registering = state.fullPath == '/register';
      final configMissing = state.fullPath == '/config-missing';

      if (!SupabaseConfig.isConfigured) {
        return configMissing ? null : '/config-missing';
      }

      final isLoggedIn = session != null;
      if (!isLoggedIn && !loggingIn && !registering) {
        return '/login';
      }
      if (isLoggedIn && (loggingIn || registering)) {
        return state.fullPath == '/' ? null : '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/config-missing',
        builder: (context, state) => const MissingConfigPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const LoadingStationRegistrationPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => HomeShellPage(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/deliveries',
                builder: (context, state) => const DeliveriesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/riders',
                builder: (context, state) => const RidersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                builder: (context, state) => const TopUpPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/merchants',
                builder: (context, state) => const MerchantsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

final _goRouterRefreshNotifierProvider = Provider<ChangeNotifier>((ref) {
  final notifier = _GoRouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(this._ref) {
    _subscription = _ref.listen<AsyncValue<Session?>>(
      sessionStreamProvider,
      (previous, next) => notifyListeners(),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<Session?>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

class MissingConfigPage extends StatelessWidget {
  const MissingConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 72, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Supabase credentials missing',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Run the app with:\n'
                  'flutter run --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Retry'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

