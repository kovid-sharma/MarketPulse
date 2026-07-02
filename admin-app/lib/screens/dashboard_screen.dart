import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/api_client.dart';

final healthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(apiClientProvider).getHealth();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(healthProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D1A),
        elevation: 0,
        title: const Text('Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8B8FA8)),
            onPressed: () => ref.refresh(healthProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFF59E0B),
        onRefresh: () async => ref.refresh(healthProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status indicator
              healthAsync.when(
                loading: () => const _StatusBanner(
                    status: 'loading', message: 'Fetching system status...'),
                error: (_, __) => const _StatusBanner(
                    status: 'error', message: 'Cannot reach backend'),
                data: (h) => _StatusBanner(
                    status: h['status'] as String? ?? 'unknown',
                    message: 'System operational'),
              ),
              const SizedBox(height: 24),
              const Text('System Health',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              // Stat cards
              healthAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFF59E0B))),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style:
                          const TextStyle(color: Color(0xFF8B8FA8))),
                ),
                data: (health) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.queue_rounded,
                            iconColor: const Color(0xFF6366F1),
                            label: 'Queue Size',
                            value:
                                '${health['queue_size'] ?? 0}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.article_rounded,
                            iconColor: const Color(0xFF10B981),
                            label: 'Total Articles',
                            value:
                                '${health['total_articles'] ?? 0}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.error_outline_rounded,
                            iconColor: const Color(0xFFEF4444),
                            label: 'Errors',
                            value:
                                '${health['error_count'] ?? 0}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.schedule_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            label: 'Last Ingestion',
                            value: _formatTime(
                                health['last_ingestion_time'] as String?),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text('Quick Actions',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _QuickActionTile(
                icon: Icons.rate_review_rounded,
                title: 'Review Queue',
                subtitle: 'Approve or reject low-confidence articles',
                color: const Color(0xFF6366F1),
                onTap: () => context.go('/review'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                icon: Icons.add_circle_outline_rounded,
                title: 'Manual Article Entry',
                subtitle: 'Submit an article directly to the pipeline',
                color: const Color(0xFF10B981),
                onTap: () => context.go('/manual-entry'),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                icon: Icons.payments_outlined,
                title: 'Payments Overview',
                subtitle: 'View subscription and revenue summary',
                color: const Color(0xFFF59E0B),
                onTap: () => context.go('/payments'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return 'Never';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    } catch (_) {
      return 'Unknown';
    }
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final String message;
  const _StatusBanner({required this.status, required this.message});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      'healthy' => (const Color(0xFF00C851), Icons.check_circle_rounded),
      'loading' => (const Color(0xFFF59E0B), Icons.hourglass_top_rounded),
      _ => (const Color(0xFFEF4444), Icons.error_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(message,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2D3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF8B8FA8), fontSize: 12)),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2D3E)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF4B5563), size: 14),
          ],
        ),
      ),
    );
  }
}
