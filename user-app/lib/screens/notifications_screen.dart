import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple in-memory notification store (replaced by FCM integration in production)
final notificationsProvider = StateProvider<List<_Notification>>((ref) => [
      _Notification(
        title: 'RBI holds repo rate at 6.5%',
        body: 'Bearish for banking sector. HDFC Bank, ICICI Bank may face pressure.',
        time: DateTime.now().subtract(const Duration(hours: 2)),
        sentiment: 'bearish',
      ),
      _Notification(
        title: 'Nifty hits all-time high of 24,500',
        body: 'Broad market bullish. FII buying continues at record pace.',
        time: DateTime.now().subtract(const Duration(hours: 6)),
        sentiment: 'bullish',
      ),
      _Notification(
        title: 'Rupee at 3-month high vs USD',
        body: 'Potential headwind for IT exporters. TCS, Infosys may see margin pressure.',
        time: DateTime.now().subtract(const Duration(days: 1)),
        sentiment: 'neutral',
      ),
    ]);

class _Notification {
  final String title;
  final String body;
  final DateTime time;
  final String sentiment;
  bool isRead = false;

  _Notification({
    required this.title,
    required this.body,
    required this.time,
    required this.sentiment,
  });
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D1A),
        elevation: 0,
        title: const Text('Alerts',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () {
                ref.read(notificationsProvider.notifier).update(
                    (state) => state.map((n) => n..isRead = true).toList());
              },
              child: const Text('Mark all read',
                  style: TextStyle(
                      color: Color(0xFF6366F1), fontSize: 13)),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      color: Color(0xFF4B5563), size: 56),
                  SizedBox(height: 16),
                  Text('No alerts yet',
                      style: TextStyle(color: Color(0xFF8B8FA8), fontSize: 16)),
                  SizedBox(height: 8),
                  Text(
                    'High-impact articles matching\nyour preferences will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _NotificationTile(
                notification: notifications[i],
                onTap: () {
                  ref.read(notificationsProvider.notifier).update((state) {
                    state[i].isRead = true;
                    return [...state];
                  });
                },
              ),
            ),
      bottomNavigationBar: _BottomNav(currentIndex: 1),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final _Notification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sentimentColor = switch (notification.sentiment) {
      'bullish' => const Color(0xFF00C851),
      'bearish' => const Color(0xFFFF4444),
      _ => const Color(0xFF8B8FA8),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead
              ? const Color(0xFF1A1D2E)
              : const Color(0xFF1E2040),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xFF2A2D3E)
                : const Color(0xFF6366F1).withOpacity(0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: sentimentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                notification.sentiment == 'bullish'
                    ? Icons.trending_up
                    : notification.sentiment == 'bearish'
                        ? Icons.trending_down
                        : Icons.trending_flat,
                color: sentimentColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: notification.isRead
                          ? FontWeight.w400
                          : FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: const TextStyle(
                        color: Color(0xFF8B8FA8), fontSize: 12, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notification.time),
                    style: const TextStyle(
                        color: Color(0xFF4B5563), fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// Re-export for use in other screens
class _BottomNav extends ConsumerWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13162A),
        border: Border(top: BorderSide(color: Color(0xFF2A2D3E))),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: const Color(0xFF6B7280),
        elevation: 0,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/feed');
            case 1:
              break; // already here
            case 2:
              context.go('/settings');
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined), label: 'Feed'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
          BottomNavigationBarItem(
              icon: Icon(Icons.tune_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
