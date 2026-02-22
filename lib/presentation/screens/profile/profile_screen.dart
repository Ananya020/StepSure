import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:gait_rehab/core/constants/app_colors.dart';
import '../auth/login_screen.dart';

// Minimal StatRow widget for displaying label-value pairs
class StatRow extends StatelessWidget {
  final String label;
  final String value;
  const StatRow({required this.label, required this.value, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _client = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final profile =
          await _client.from('profiles').select().eq('id', uid).maybeSingle();

      final sessions = await _client
          .from('sessions')
          .select('recovery_score, duration_seconds')
          .eq('user_id', uid);

      final sessionList = (sessions as List).cast<Map<String, dynamic>>();

      double avgScore = 0;
      int totalSeconds = 0;
      if (sessionList.isNotEmpty) {
        avgScore = sessionList
                .map((s) => (s['recovery_score'] as num).toDouble())
                .reduce((a, b) => a + b) /
            sessionList.length;
        totalSeconds = sessionList
            .map((s) => (s['duration_seconds'] as int? ?? 0))
            .reduce((a, b) => a + b);
      }

      setState(() {
        _profile = profile;
        _stats = {
          'sessions': sessionList.length,
          'avg_score': avgScore,
          'total_minutes': totalSeconds ~/ 60,
        };
        _reminderEnabled = profile?['reminder_enabled'] as bool? ?? true;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await _client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _saveReminder(bool enabled, TimeOfDay time) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('profiles').update({
      'reminder_enabled': enabled,
      'reminder_time':
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00',
    }).eq('id', uid);
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?['full_name'] as String? ?? 'Patient';
    final age = _profile?['age'] as int?;
    final affectedSide = _profile?['affected_side'] as String? ?? '--';
    final strokeDateStr = _profile?['stroke_date'] as String?;
    final strokeDate =
        strokeDateStr != null ? DateTime.tryParse(strokeDateStr) : null;
    final email = _client.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
                    child: Column(
                      children: [
                        // Glass-like Avatar
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'P',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Stats row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 18),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _StatPill(
                                label: 'Sessions',
                                value: '${_stats?['sessions'] ?? 0}',
                              ),
                              Container(
                                  width: 1, height: 36, color: Colors.white30),
                              _StatPill(
                                label: 'Avg Score',
                                value:
                                    (_stats?['avg_score'] as double? ?? 0).toStringAsFixed(1),
                              ),
                              Container(
                                  width: 1, height: 36, color: Colors.white30),
                              _StatPill(
                                label: 'Minutes',
                                value: '${_stats?['total_minutes'] ?? 0}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // ── Patient Info ──
                        _Card(
                          title: 'Patient Information',
                          icon: Icons.person_outline_rounded,
                          children: [
                            StatRow(label: 'Full Name', value: name),
                            Divider(color: AppColors.danger.withOpacity(0.15)),
                            StatRow(
                                label: 'Age',
                                value: age != null ? '$age years' : '--'),
                            Divider(color: AppColors.danger.withOpacity(0.15)),
                            StatRow(
                              label: 'Stroke Date',
                              value: strokeDate != null
                                  ? DateFormat('d MMM yyyy').format(strokeDate)
                                  : '--',
                            ),
                            Divider(color: AppColors.danger.withOpacity(0.15)),
                            StatRow(
                              label: 'Affected Side',
                              value:
                                  '${affectedSide[0].toUpperCase()}${affectedSide.substring(1)}',
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Reminders ──
                        _Card(
                          title: 'Reminders',
                          icon: Icons.alarm_rounded,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Daily Reminder',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600)),
                                Switch(
                                  value: _reminderEnabled,
                                  onChanged: (val) {
                                    setState(() => _reminderEnabled = val);
                                    _saveReminder(val, _reminderTime);
                                  },
                                  activeThumbColor: AppColors.primary,
                                ),
                              ],
                            ),
                            if (_reminderEnabled) ...[
                              Divider(
                                  color: AppColors.danger.withOpacity(0.15)),
                              GestureDetector(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: _reminderTime,
                                  );
                                  if (time != null) {
                                    setState(() => _reminderTime = time);
                                    _saveReminder(_reminderEnabled, time);
                                  }
                                },
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Reminder Time',
                                        style: TextStyle(
                                            color: AppColors.textSecondary)),
                                    Row(
                                      children: [
                                        Text(
                                          _reminderTime.format(context),
                                          style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.chevron_right_rounded,
                                            color: AppColors.textSecondary,
                                            size: 18),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── App Info ──
                        _Card(
                          title: 'App',
                          icon: Icons.info_outline_rounded,
                          children: [
                            _MenuItem(
                              icon: Icons.privacy_tip_outlined,
                              label: 'Privacy Policy',
                              onTap: () {},
                            ),
                            Divider(color: AppColors.danger.withOpacity(0.15)),
                            _MenuItem(
                              icon: Icons.help_outline_rounded,
                              label: 'Help & Support',
                              onTap: () {},
                            ),
                            Divider(color: AppColors.danger.withOpacity(0.15)),
                            _MenuItem(
                              icon: Icons.info_outline_rounded,
                              label: 'Version 1.0.0',
                              onTap: () {},
                              showArrow: false,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Sign out ──
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _signOut,
                            icon: const Icon(Icons.logout_rounded,
                                color: AppColors.danger),
                            label: const Text('Sign Out',
                                style: TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              side: const BorderSide(color: AppColors.danger),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Card({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withOpacity(0.98),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.danger.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      fontFamily: 'Nunito',
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: AppColors.danger.withOpacity(0.10), height: 1),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showArrow;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14)),
            ),
            if (showArrow)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
