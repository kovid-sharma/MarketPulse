import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';

// ── Auth State ────────────────────────────────────────────────────────────────

class AuthState {
  final bool isAuthenticated;
  final String? token;
  final String? role;
  final String? userId;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.token,
    this.role,
    this.userId,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? token,
    String? role,
    String? userId,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      role: role ?? this.role,
      userId: userId ?? this.userId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authServiceProvider =
    StateNotifierProvider<AuthService, AuthState>((ref) {
  return AuthService(ref.read(apiClientProvider));
});

// ── Service ───────────────────────────────────────────────────────────────────

class AuthService extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthService(this._api) : super(const AuthState()) {
    _loadSavedToken();
  }

  Future<void> _loadSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final role = prefs.getString('auth_role');
    final userId = prefs.getString('auth_user_id');
    if (token != null) {
      state = AuthState(
        isAuthenticated: true,
        token: token,
        role: role,
        userId: userId,
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.login(email, password);
      final token = data['access_token'] as String;
      final role = data['role'] as String;
      final userId = data['user_id'] as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('auth_role', role);
      await prefs.setString('auth_user_id', userId);

      state = AuthState(
        isAuthenticated: true,
        token: token,
        role: role,
        userId: userId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed. Please check your credentials.',
      );
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_role');
    await prefs.remove('auth_user_id');
    state = const AuthState();
  }
}
