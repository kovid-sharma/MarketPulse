import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';

// ── Auth State ────────────────────────────────────────────────────────────────

class AdminAuthState {
  final bool isAuthenticated;
  final String? token;
  final String? role;
  final bool isLoading;
  final String? error;

  const AdminAuthState({
    this.isAuthenticated = false,
    this.token,
    this.role,
    this.isLoading = false,
    this.error,
  });
}

final adminAuthProvider =
    StateNotifierProvider<AdminAuthNotifier, AdminAuthState>((ref) {
  return AdminAuthNotifier(ref.read(apiClientProvider));
});

class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  final AdminApiClient _api;

  AdminAuthNotifier(this._api) : super(const AdminAuthState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('admin_auth_token');
    final role = prefs.getString('admin_role');
    if (token != null && role == 'admin') {
      state = AdminAuthState(isAuthenticated: true, token: token, role: role);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AdminAuthState(isLoading: true);
    try {
      final data = await _api.login(email, password);
      final role = data['role'] as String;
      if (role != 'admin') {
        state = const AdminAuthState(
            error: 'This account does not have admin access.');
        return;
      }
      final token = data['access_token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_auth_token', token);
      await prefs.setString('admin_role', role);
      state = AdminAuthState(isAuthenticated: true, token: token, role: role);
    } catch (_) {
      state = const AdminAuthState(error: 'Login failed. Check credentials.');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_auth_token');
    await prefs.remove('admin_role');
    state = const AdminAuthState();
  }
}

// ── Login Screen ──────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(adminAuthProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
    if (!mounted) return;
    if (ref.read(adminAuthProvider).isAuthenticated) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(adminAuthProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Admin Panel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('MarketPulse Control Centre',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8B8FA8), fontSize: 13)),
              const SizedBox(height: 48),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                          'Admin Email', Icons.email_outlined),
                      validator: (v) =>
                          v != null && v.contains('@') ? null : 'Invalid email',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Password', Icons.lock_outline)
                          .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF6B7280),
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          v != null && v.length >= 6 ? null : 'Min 6 chars',
                    ),
                  ],
                ),
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFFF4444).withOpacity(0.3)),
                  ),
                  child: Text(auth.error!,
                      style: const TextStyle(
                          color: Color(0xFFFF4444), fontSize: 13),
                      textAlign: TextAlign.center),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Sign In as Admin',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF4B5563)),
      prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 20),
      filled: true,
      fillColor: const Color(0xFF1A1D2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A2D3E)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A2D3E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2),
      ),
    );
  }
}
