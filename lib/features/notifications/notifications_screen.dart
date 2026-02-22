import 'package:flutter/material.dart';
import 'package:gait_rehab/core/constants/app_colors.dart';
import 'package:gait_rehab/core/constants/app_text.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

enum NotifType { reminder, milestone, tip }

class AppNotification {
  final String id;
  final NotifType type;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;

  // Replace this with real data from your DB / shared_preferences as needed
  final List<AppNotification> _notifications = [
    AppNotification(
      id: '1',
      type: NotifType.reminder,
      title: '🚶 Time for your Gait Session!',
      body: "Let's check your recovery progress today.",
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    AppNotification(
      id: '2',
      type: NotifType.milestone,
      title: '🏆 New Milestone Reached!',
      body: 'Your symmetry score improved by 12% this week. Keep it up!',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
    ),
    AppNotification(
      id: '3',
      type: NotifType.tip,
      title: '💡 Daily Tip',
      body:
          'For best results, record sessions at the same time each day. Consistency helps your AI coach track improvements accurately.',
      timestamp: DateTime.now().subtract(const Duration(hours: 9)),
      isRead: true,
    ),
    AppNotification(
      id: '4',
      type: NotifType.reminder,
      title: '🚶 Don\'t forget your session!',
      body: 'You missed yesterday\'s session. A short walk still counts.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
    AppNotification(
      id: '5',
      type: NotifType.milestone,
      title: '🎯 7-Day Streak!',
      body: 'You\'ve completed 7 sessions in a row. Amazing consistency!',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
    ),
  ];

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
  }

  void _markRead(AppNotification n) {
    setState(() => n.isRead = true);
  }

  void _handleTap(BuildContext context, AppNotification n) {
    // Just mark the notification as read — no further navigation
    _markRead(n);
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // Per-type styling
  _NotifStyle _styleFor(NotifType type) {
    switch (type) {
      case NotifType.reminder:
        return _NotifStyle(
          color: AppColors.primary,
          bg: AppColors.primary.withOpacity(0.10),
          icon: Icons.notifications_active_rounded,
          label: 'Reminder',
        );
      case NotifType.milestone:
        return _NotifStyle(
          color: const Color(0xFFF5A623),
          bg: const Color(0xFFF5A623).withOpacity(0.10),
          icon: Icons.emoji_events_rounded,
          label: 'Milestone',
        );
      case NotifType.tip:
        return _NotifStyle(
          color: AppColors.secondary,
          bg: AppColors.secondary.withOpacity(0.10),
          icon: Icons.lightbulb_outline_rounded,
          label: 'Tip',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                  child: Row(
                    children: [
                      // Back button
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20),
                        color: AppColors.textDark,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: AppText.h1.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (_unreadCount > 0)
                              Text(
                                '$_unreadCount unread',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_unreadCount > 0)
                        TextButton(
                          onPressed: _markAllRead,
                          child: const Text(
                            'Mark all read',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Empty State ──
            if (_notifications.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: AppText.body.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // ── List ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final notif = _notifications[index];
                      final style = _styleFor(notif.type);
                      return _NotifTile(
                        notification: notif,
                        style: style,
                        relativeTime: _relativeTime(notif.timestamp),
                        onTap: () => _handleTap(context, notif),
                        onDismiss: () =>
                            setState(() => _notifications.removeAt(index)),
                        animDelay: Duration(milliseconds: index * 60),
                      );
                    },
                    childCount: _notifications.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _NotifTile extends StatefulWidget {
  final AppNotification notification;
  final _NotifStyle style;
  final String relativeTime;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Duration animDelay;

  const _NotifTile({
    required this.notification,
    required this.style,
    required this.relativeTime,
    required this.onTap,
    required this.onDismiss,
    required this.animDelay,
  });

  @override
  State<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends State<_NotifTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    Future.delayed(widget.animDelay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Dismissible(
          key: ValueKey(widget.notification.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => widget.onDismiss(),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 24),
          ),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.notification.isRead
                    ? AppColors.cardBg
                    : widget.style.bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.notification.isRead
                      ? Colors.white.withOpacity(0.08)
                      : widget.style.color.withOpacity(0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.notification.isRead
                        ? Colors.black.withOpacity(0.04)
                        : widget.style.color.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.style.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.style.icon,
                        color: widget.style.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Type chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: widget.style.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.style.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: widget.style.color,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.relativeTime,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (!widget.notification.isRead) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: widget.style.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          widget.notification.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.notification.body,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _NotifStyle {
  final Color color;
  final Color bg;
  final IconData icon;
  final String label;

  const _NotifStyle({
    required this.color,
    required this.bg,
    required this.icon,
    required this.label,
  });
}
