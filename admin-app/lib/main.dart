import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/review_screen.dart';
import 'screens/manual_entry_screen.dart';
import 'screens/payments_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(adminAuthProvider);

    final router = GoRouter(
      initialLocation: auth.isAuthenticated ? '/dashboard' : '/login',
      redirect: (context, state) {
        final loggedIn = auth.isAuthenticated;
        final onLogin = state.matchedLocation == '/login';
        if (!loggedIn && !onLogin) return '/login';
        if (loggedIn && onLogin) return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/review', builder: (_, __) => const ReviewScreen()),
        GoRoute(
            path: '/manual-entry',
            builder: (_, __) => const ManualEntryScreen()),
        GoRoute(path: '/payments', builder: (_, __) => const PaymentsScreen()),
      ],
    );

    return MaterialApp.router(
      title: 'MarketPulse Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF59E0B),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0D1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0D1A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      routerConfig: router,
    );
  }
}
