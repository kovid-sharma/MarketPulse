import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/api_client.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final List<String> _allSectors = [
    'banking', 'it', 'pharma', 'fmcg', 'auto', 'realty',
    'oil & gas', 'broad market'
  ];
  final Set<String> _selectedSectors = {};
  String? _geography;
  bool _isSaving = false;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(apiClientProvider).savePreferences({
        'sectors': _selectedSectors.toList(),
        'geography': _geography,
        'sentiments': [],
        'alert_threshold': 'all',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved'),
            backgroundColor: Color(0xFF00C851),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'),
              backgroundColor: const Color(0xFFFF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D1A),
        elevation: 0,
        title: const Text('Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Account section
          _SectionHeader(title: 'Account'),
          _SettingsCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.person,
                        color: Color(0xFF6366F1), size: 20),
                  ),
                  title: Text(
                    auth.userId ?? 'User',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    auth.role?.toUpperCase() ?? '',
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11),
                  ),
                ),
                const Divider(color: Color(0xFF2A2D3E)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded,
                      color: Color(0xFFFF4444), size: 20),
                  title: const Text('Sign Out',
                      style: TextStyle(color: Color(0xFFFF4444), fontSize: 14)),
                  onTap: () async {
                    await ref.read(authServiceProvider.notifier).logout();
                    if (mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Sectors
          _SectionHeader(title: 'Sectors of Interest'),
          _SettingsCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allSectors.map((sector) {
                final selected = _selectedSectors.contains(sector);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedSectors.remove(sector);
                    } else {
                      _selectedSectors.add(sector);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF2A2D3E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      sector,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF8B8FA8),
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          // Geography
          _SectionHeader(title: 'Default Geography'),
          _SettingsCard(
            child: Row(
              children: ['india', 'global', 'both (default)'].map((g) {
                final val = g == 'both (default)' ? null : g;
                final selected = _geography == val;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _geography = val),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF2A2D3E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        g,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : const Color(0xFF8B8FA8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save Preferences',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D3E)),
      ),
      child: child,
    );
  }
}
