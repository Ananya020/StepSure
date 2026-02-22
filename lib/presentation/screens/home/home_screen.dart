import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:gait_rehab/core/constants/app_colors.dart';
import 'package:gait_rehab/core/constants/app_text.dart';
import 'package:gait_rehab/core/widgets/widgets.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../instructions/instructions_screen.dart';
import '../progress/progress_screen.dart';
import '../report/reports_list_screen.dart';
import '../profile/profile_screen.dart';
import '../upload/upload_screen.dart';
import 'metric_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _pages = [
    const _HomeTab(),
    const ProgressScreen(),
    const ReportsListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              _navItem(1, Icons.show_chart_rounded, Icons.show_chart_outlined,
                  'Progress'),
              _navItem(2, Icons.description_rounded, Icons.description_outlined,
                  'Reports'),
              _navItem(3, Icons.person_rounded, Icons.person_outline_rounded,
                  'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData active, IconData inactive, String label) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF0A7EA4).withOpacity(0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? active : inactive,
              color: isActive ? const Color(0xFF0A7EA4) : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color:
                    isActive ? const Color(0xFF0A7EA4) : Colors.grey.shade400,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with TickerProviderStateMixin {
  final _client = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _lastSession;
  bool _loading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Staggered slide-up animations for sections
  late AnimationController _staggerController;
  late Animation<Offset> _sessionSlide;
  late Animation<double> _sessionFade;
  late Animation<Offset> _statsSlide;
  late Animation<double> _statsFade;
  late Animation<Offset> _tipSlide;
  late Animation<double> _tipFade;

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _sessionSlide =
        Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _sessionFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _staggerController, curve: const Interval(0.0, 0.55)),
    );
    _statsSlide = Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _statsFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _staggerController, curve: const Interval(0.25, 0.75)),
    );
    _tipSlide = Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.50, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _tipFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _staggerController, curve: const Interval(0.50, 1.0)),
    );

    _load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final profile =
          await _client.from('profiles').select().eq('id', uid).maybeSingle();
      final sessions = await _client
          .from('sessions')
          .select()
          .eq('user_id', uid)
          .order('session_date', ascending: false)
          .limit(1);
      setState(() {
        _profile = profile;
        _lastSession = sessions.isNotEmpty ? sessions.first : null;
        _loading = false;
      });
      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _staggerController.forward();
    } catch (_) {
      setState(() => _loading = false);
      _fadeController.forward();
      _staggerController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?['full_name']?.toString().split(' ').first ?? 'There';
    final score = _toDouble(_lastSession?['recovery_score']);
    final risk = _lastSession?['fall_risk'] as String?;
    final cadence = _toDouble(_lastSession?['cadence']);
    final symmetry = _toDouble(_lastSession?['symmetry']);
    final stride = _toDouble(_lastSession?['stride_length']);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      body: _loading
          ? _LoadingView()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Hero Header with walking animation ─────────────────
                  SliverToBoxAdapter(
                    child: _HeroHeader(name: name, score: score, risk: risk),
                  ),

                  // ── Start Session ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: SlideTransition(
                      position: _sessionSlide,
                      child: FadeTransition(
                        opacity: _sessionFade,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                  title: 'Start Session',
                                  color: Color(0xFF0A7EA4)),
                              const SizedBox(height: 16),
                              _SessionCard(
                                title: 'Live Recording',
                                subtitle:
                                    'Real-time gait analysis with pose overlay & voice feedback',
                                icon: Icons.videocam_rounded,
                                // Walking animation inside this card
                                lottieAsset: 'assets/animations/walking2.json',
                                colors: const [
                                  Color(0xFF0A7EA4),
                                  Color(0xFF0D9FCC)
                                ],
                                tag: 'RECOMMENDED',
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const InstructionsScreen())),
                              ),
                              const SizedBox(height: 12),
                              _SessionCard(
                                title: 'Upload Video',
                                subtitle:
                                    'Analyse an existing walking video from your library',
                                icon: Icons.upload_file_rounded,
                                colors: const [
                                  Color(0xFF00A890),
                                  Color(0xFF00C9AA)
                                ],
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const UploadScreen())),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Stats ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: SlideTransition(
                      position: _statsSlide,
                      child: FadeTransition(
                        opacity: _statsFade,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                  title: 'Last Session Stats',
                                  color: Color(0xFF00A890)),
                              const SizedBox(height: 16),
                              _StatsGrid(
                                cadence: cadence,
                                symmetry: symmetry,
                                stride: stride,
                                score: score,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Daily Tip ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: SlideTransition(
                      position: _tipSlide,
                      child: FadeTransition(
                        opacity: _tipFade,
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
                          child: _TipCard(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Loading View with Lottie ─────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F7FA),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Lottie.asset(
                'assets/animations/walking2.json',
                repeat: true,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading your progress…',
              style: TextStyle(
                color: const Color(0xFF0A7EA4).withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Title ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A2332),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

// ─── Hero Header ──────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final String name;
  final double? score;
  final String? risk;

  const _HeroHeader({required this.name, this.score, this.risk});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Color _riskColor(String? r) {
    switch (r?.toLowerCase()) {
      case 'low':
        return const Color(0xFF00C9AA);
      case 'high':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFFFFD166);
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _riskColor(risk);
    final riskLabel =
        risk != null ? '${risk![0].toUpperCase()}${risk!.substring(1)}' : '—';

    return Stack(
      children: [
        // Gradient background
        Container(
          height: 330,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A7EA4), Color(0xFF07B5A0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // Decorative subtle circles
        Positioned(
          top: -50,
          right: -50,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
        Positioned(
          top: 80,
          right: 50,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        Positioned(
          bottom: 70,
          left: -20,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
        ),

        // ── Walking animation: floats in bottom-right of header ──
        // Positioned(
        //   right: 0,
        //   bottom: 28, // sits just above the curved cutout
        //   child: Opacity(
        //     opacity: 0.22,
        //     child: SizedBox(
        //       width: 130,
        //       height: 130,
        //       child: Lottie.asset(
        //         'assets/animations/walking2.json',
        //         repeat: true,
        //         fit: BoxFit.contain,
        //       ),
        //     ),
        //   ),
        // ),

        // Content
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo + wordmark
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.directions_walk_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Step',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              TextSpan(
                                text: 'Sure',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Notification bell
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () {},
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.30),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF4757),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                '1',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── Greeting + Streak ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Streak pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Fire animation — use Lottie if you have one,
                          // otherwise fall back to the icon
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFFFD166),
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '5 day',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                              Text(
                                'streak',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Score + Risk chips ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _HeaderChip(
                        icon: Icons.timeline_rounded,
                        iconColor: const Color(0xFF64DFDF),
                        label: 'Recovery',
                        value: score != null
                            ? '${score!.toStringAsFixed(1)} / 100'
                            : '—',
                        valueColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeaderChip(
                        icon: Icons.shield_outlined,
                        iconColor: riskColor,
                        label: 'Fall Risk',
                        value: riskLabel,
                        valueColor: riskColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Curved bottom cutout
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F7FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  const _HeaderChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.60),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Session Card (with optional Lottie) ─────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final String? tag;
  final String? lottieAsset;
  final VoidCallback onTap;

  const _SessionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.tag,
    this.lottieAsset,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.30),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon box OR lottie animation
            lottieAsset != null
                ? SizedBox(
                    width: 54,
                    height: 54,
                    child: Lottie.asset(
                      lottieAsset!,
                      repeat: true,
                      fit: BoxFit.contain,
                    ),
                  )
                : Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        tag!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final double? cadence;
  final double? symmetry;
  final double? stride;
  final double? score;

  const _StatsGrid({this.cadence, this.symmetry, this.stride, this.score});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.speed_rounded,
                label: 'Cadence',
                value: cadence != null ? cadence!.toStringAsFixed(0) : '—',
                unit: 'spm',
                color: const Color(0xFF0A7EA4),
                progress:
                    cadence != null ? (cadence! / 200).clamp(0.0, 1.0) : 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.balance_rounded,
                label: 'Symmetry',
                value: symmetry != null ? symmetry!.toStringAsFixed(0) : '—',
                unit: '%',
                color: const Color(0xFF00A890),
                progress:
                    symmetry != null ? (symmetry! / 100).clamp(0.0, 1.0) : 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.straighten_rounded,
                label: 'Stride',
                value: stride != null ? stride!.toStringAsFixed(2) : '—',
                unit: 'm',
                color: const Color(0xFF6C63FF),
                progress: stride != null ? (stride! / 2.0).clamp(0.0, 1.0) : 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.monitor_heart_outlined,
                label: 'Score',
                value: score != null ? score!.toStringAsFixed(1) : '—',
                unit: '/100',
                color: const Color(0xFFFF6B6B),
                progress: score != null ? (score! / 100).clamp(0.0, 1.0) : 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final double progress;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.progress,
  });

  @override
  State<_StatTile> createState() => _StatTileState();
}

class _StatTileState extends State<_StatTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _anim = Tween(begin: 0.0, end: widget.progress)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), () {
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 18),
              ),
              Text(
                widget.unit,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.value,
            style: const TextStyle(
              color: Color(0xFF1A2332),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Stack(
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _anim.value,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Daily Tip ────────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: const Border(
          left: BorderSide(color: Color(0xFF00A890), width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lottie lightbulb — fall back to icon if asset not present
          SizedBox(
            width: 40,
            height: 40,
            child: Lottie.asset(
              'assets/animations/lightbulb.json',
              repeat: true,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A890).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_rounded,
                    color: Color(0xFF00A890), size: 18),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Tip',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2332),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'For best results, record sessions at the same time each day. Consistency helps your AI coach track improvements accurately.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7A8D),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
