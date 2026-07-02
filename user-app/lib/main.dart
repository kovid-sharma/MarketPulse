import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/login_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/article_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/auth_service.dart';

// ── FCM Background Handler ────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background notifications are handled by the OS notification tray
}

// ── Router ────────────────────────────────────────────────────────────────────

GoRouter _buildRouter(WidgetRef ref) {
  final auth = ref.watch(authServiceProvider);
  return GoRouter(
    initialLocation: auth.isAuthenticated ? '/feed' : '/login',
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final goingToLogin = state.matchedLocation == '/login';
      if (!loggedIn && !goingToLogin) return '/login';
      if (loggedIn && goingToLogin) return '/feed';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
      GoRoute(
        path: '/article/:id',
        builder: (_, state) =>
            ArticleDetailScreen(articleId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen()),
    ],
  );
}

// ── App ───────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NOTE: To enable Firebase, add google-services.json (Android) and
  // GoogleService-Info.plist (iOS) to the respective platform directories.
  // Uncomment the following lines once those files are in place:
  //
  // await Firebase.initializeApp();
  // FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  runApp(const ProviderScope(child: MarketPulseApp()));
}

class MarketPulseApp extends ConsumerWidget {
  const MarketPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = _buildRouter(ref);

    return MaterialApp.router(
      title: 'MarketPulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0D1A),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0D1A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF13162A),
          selectedItemColor: Color(0xFF6366F1),
          unselectedItemColor: Color(0xFF6B7280),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),
      routerConfig: router,
    );
  }
}
