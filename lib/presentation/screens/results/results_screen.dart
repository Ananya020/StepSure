import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gait_rehab/core/constants/app_colors.dart';
import 'package:gait_rehab/domain/pdf_generator.dart';
import 'package:gait_rehab/domain/models/session_model.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/score_ring.dart';
import '../../core/widgets/risk_badge.dart';
import '../home/metric_card.dart';
import '../instructions/primary_button.dart';

class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  final Map<String, dynamic> report;
  final List<String>? feedbackMessages;

  const ResultsScreen({
    super.key,
    required this.session,
    required this.report,
    this.feedbackMessages,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _contentController;
  late AnimationController _scoreController;
  late AnimationController _particleController;

  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _scorePop;
  late Animation<double> _scoreArc;

  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();

    debugPrint('[ResultsScreen] session: ${widget.session}');
    debugPrint('[ResultsScreen] report: ${widget.report}');

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(begin: const Offset(0, -0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _heroController, curve: Curves.easeOutCubic));

    _scorePop = CurvedAnimation(
      parent: _scoreController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );
    _scoreArc = CurvedAnimation(
      parent: _scoreController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _heroController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _scoreController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _contentController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _contentController.dispose();
    _scoreController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _exportPdf() async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final sessionModel = SessionModel.fromMap(widget.session);
      await PdfExporter.exportReport(
          session: sessionModel, report: widget.report);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export failed: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Color _scoreColor(double score) {
    if (score >= 75) return const Color(0xFF00C9AA);
    if (score >= 50) return const Color(0xFF0A7EA4);
    return const Color(0xFFFF6B6B);
  }

  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
        return const Color(0xFF00C9AA);
      case 'high':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFFFFD166);
    }
  }

  String _riskEmoji(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
        return '✅';
      case 'high':
        return '⚠️';
      default:
        return '🔶';
    }
  }

  String _scoreLabel(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 65) return 'Good';
    if (score >= 50) return 'Fair';
    return 'Needs Work';
  }

  @override
  Widget build(BuildContext context) {
    final score = (widget.session['recovery_score'] as num?)?.toDouble() ?? 0;
    final risk = widget.session['fall_risk'] as String? ?? 'moderate';
    final symmetry = (widget.session['symmetry'] as num?)?.toDouble() ?? 0;
    final cadence = (widget.session['cadence'] as num?)?.toDouble() ?? 0;
    final consistency =
        (widget.session['stride_consistency'] as num?)?.toDouble() ?? 0;
    final strideLen =
        (widget.session['stride_length'] as num?)?.toDouble() ?? 0;
    final duration = (widget.session['duration_seconds'] as int?) ?? 0;
    final improvement =
        (widget.report['improvement_percentage'] as num?)?.toDouble() ?? 0;
    final abnormalities =
        (widget.report['abnormalities'] as List<dynamic>?)?.cast<String>() ??
            [];
    final suggestions =
        (widget.report['exercise_suggestions'] as List<dynamic>?)
                ?.cast<String>() ??
            [];
    final summary = widget.report['summary'] as String? ?? '';
    final riskAssessment = widget.report['risk_assessment'] as String? ?? '';

    final sc = _scoreColor(score);
    final rc = _riskColor(risk);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HERO ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _heroSlide,
              child: FadeTransition(
                opacity: _heroFade,
                child: _HeroSection(
                  score: score,
                  scoreColor: sc,
                  scoreLabel: _scoreLabel(score),
                  risk: risk,
                  riskColor: rc,
                  riskEmoji: _riskEmoji(risk),
                  durationSeconds: duration,
                  improvement: improvement,
                  scoreArcAnim: _scoreArc,
                  scorePopAnim: _scorePop,
                  particleController: _particleController,
                ),
              ),
            ),
          ),

          // ── CONTENT ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _contentController,
                curve: Curves.easeOut,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Metrics ──────────────────────────────────────────
                    const _SectionLabel(
                        title: 'Gait Metrics',
                        icon: Icons.analytics_rounded,
                        color: Color(0xFF0A7EA4)),
                    const SizedBox(height: 14),
                    _MetricsGrid(
                      symmetry: symmetry,
                      cadence: cadence,
                      consistency: consistency,
                      strideLen: strideLen,
                    ),

                    const SizedBox(height: 22),

                    // ── AI Summary ───────────────────────────────────────
                    const _SectionLabel(
                        title: 'AI Analysis',
                        icon: Icons.auto_awesome_rounded,
                        color: Color(0xFF6C63FF)),
                    const SizedBox(height: 14),
                    _SummaryCard(summary: summary),

                    // ── Abnormalities ────────────────────────────────────
                    if (abnormalities.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const _SectionLabel(
                          title: 'Identified Issues',
                          icon: Icons.warning_amber_rounded,
                          color: Color(0xFFFF6B6B)),
                      const SizedBox(height: 14),
                      ...abnormalities
                          .asMap()
                          .entries
                          .map((e) => _IssueItem(text: e.value, index: e.key)),
                    ],

                    // ── Exercises ────────────────────────────────────────
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const _SectionLabel(
                          title: 'Recommended Exercises',
                          icon: Icons.fitness_center_rounded,
                          color: Color(0xFF00C9AA)),
                      const SizedBox(height: 14),
                      ...suggestions.asMap().entries.map((e) =>
                          _ExerciseItem(text: e.value, number: e.key + 1)),
                    ],

                    // ── Risk ─────────────────────────────────────────────
                    const SizedBox(height: 28),
                    _SectionLabel(
                        title: 'Risk Assessment',
                        icon: Icons.shield_outlined,
                        color: rc),
                    const SizedBox(height: 14),
                    _RiskCard(
                        risk: risk,
                        riskColor: rc,
                        riskEmoji: _riskEmoji(risk),
                        assessment: riskAssessment),

                    const SizedBox(height: 32),

                    // ── Actions ──────────────────────────────────────────
                    _ExportButton(
                      loading: _exportingPdf,
                      onTap: _exportingPdf ? () {} : _exportPdf,
                    ),
                    const SizedBox(height: 12),
                    _HomeButton(
                      onTap: () =>
                          Navigator.popUntil(context, (r) => r.isFirst),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Section ─────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final double score;
  final Color scoreColor;
  final String scoreLabel;
  final String risk;
  final Color riskColor;
  final String riskEmoji;
  final int durationSeconds;
  final double improvement;
  final Animation<double> scoreArcAnim;
  final Animation<double> scorePopAnim;
  final AnimationController particleController;

  const _HeroSection({
    required this.score,
    required this.scoreColor,
    required this.scoreLabel,
    required this.risk,
    required this.riskColor,
    required this.riskEmoji,
    required this.durationSeconds,
    required this.improvement,
    required this.scoreArcAnim,
    required this.scorePopAnim,
    required this.particleController,
  });

  @override
  Widget build(BuildContext context) {
    final mins = (durationSeconds / 60).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withOpacity(0.92),
            scoreColor.withOpacity(0.70),
            const Color(0xFF0A7EA4).withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
              top: -60,
              right: -60,
              child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06)))),
          Positioned(
              bottom: 30,
              left: -40,
              child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05)))),
          Positioned(
              top: 100,
              right: 20,
              child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04)))),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                children: [
                  // ── Top row ──────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🎉', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 6),
                            Text('Session Complete',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.20)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 5),
                            Text('$mins min',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── Animated Score Ring ───────────────────────────────
                  AnimatedBuilder(
                    animation: scorePopAnim,
                    builder: (_, child) => Transform.scale(
                      scale: scorePopAnim.value,
                      child: child,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow ring
                        Container(
                          width: 186,
                          height: 186,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.15),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        // Arc ring
                        SizedBox(
                          width: 174,
                          height: 174,
                          child: AnimatedBuilder(
                            animation: scoreArcAnim,
                            builder: (_, __) => CustomPaint(
                              painter: _ScoreArcPainter(
                                progress: scoreArcAnim.value * (score / 100),
                                color: Colors.white,
                                bgColor: Colors.white.withOpacity(0.18),
                                strokeWidth: 13,
                              ),
                            ),
                          ),
                        ),
                        // Center content
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: score),
                              duration: const Duration(milliseconds: 1200),
                              curve: Curves.easeOutCubic,
                              builder: (_, val, __) => Text(
                                val.toStringAsFixed(0),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -2,
                                  height: 1,
                                ),
                              ),
                            ),
                            const Text('/100',
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                scoreLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Chips row ─────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Risk chip
                      _HeroChip(
                        emoji: riskEmoji,
                        label: 'Fall Risk',
                        value: '${risk[0].toUpperCase()}${risk.substring(1)}',
                        valueColor: riskColor,
                      ),
                      if (improvement != 0) ...[
                        const SizedBox(width: 12),
                        _HeroChip(
                          icon: improvement > 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          label: 'vs Last',
                          value:
                              '${improvement > 0 ? '+' : ''}${improvement.toStringAsFixed(1)}%',
                          valueColor: improvement > 0
                              ? const Color(0xFF64DFDF)
                              : const Color(0xFFFF9F9F),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String? emoji;
  final IconData? icon;
  final String label;
  final String value;
  final Color valueColor;

  const _HeroChip({
    this.emoji,
    this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 13)),
              if (icon != null) Icon(icon, color: valueColor, size: 14),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ─── Score Arc Painter ────────────────────────────────────────────────────────
class _ScoreArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  const _ScoreArcPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = bgColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    const sweepAngle = 2 * math.pi;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle, false, bgPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle * progress.clamp(0, 1), false, fgPaint);
  }

  @override
  bool shouldRepaint(_ScoreArcPainter old) => old.progress != progress;
}

// ─── Section Label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionLabel(
      {required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A2332),
              letterSpacing: -0.4,
            )),
      ],
    );
  }
}

// ─── Metrics Grid ─────────────────────────────────────────────────────────────
class _MetricsGrid extends StatelessWidget {
  final double symmetry, cadence, consistency, strideLen;

  const _MetricsGrid({
    required this.symmetry,
    required this.cadence,
    required this.consistency,
    required this.strideLen,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.balance_rounded,
        'Symmetry',
        symmetry.toStringAsFixed(0),
        '%',
        const Color(0xFF0A7EA4)
      ),
      (
        Icons.speed_rounded,
        'Cadence',
        cadence.toStringAsFixed(0),
        'spm',
        const Color(0xFF6C63FF)
      ),
      (
        Icons.timeline_rounded,
        'Consistency',
        consistency.toStringAsFixed(0),
        '%',
        const Color(0xFF00C9AA)
      ),
      (
        Icons.straighten_rounded,
        'Stride',
        strideLen.toStringAsFixed(2),
        'm',
        const Color(0xFFFFD166)
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: items
          .map((item) => _MetricTile(
                icon: item.$1,
                label: item.$2,
                value: item.$3,
                unit: item.$4,
                color: item.$5,
              ))
          .toList(),
    );
  }
}

class _MetricTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  State<_MetricTile> createState() => _MetricTileState();
}

class _MetricTileState extends State<_MetricTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    Future.delayed(const Duration(milliseconds: 500), () {
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
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: widget.color, size: 17),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(widget.value,
                    style: const TextStyle(
                      color: Color(0xFF1A2332),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1,
                    )),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(widget.unit,
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Text(widget.label,
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border:
            const Border(left: BorderSide(color: Color(0xFF6C63FF), width: 4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF6C63FF), size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(summary,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4A5568),
                  height: 1.65,
                )),
          ),
        ],
      ),
    );
  }
}

// ─── Issue Item ───────────────────────────────────────────────────────────────
class _IssueItem extends StatelessWidget {
  final String text;
  final int index;
  const _IssueItem({required this.text, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B).withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Center(
              child: Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF6B6B), size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF1A2332),
                  height: 1.5,
                )),
          ),
        ],
      ),
    );
  }
}

// ─── Exercise Item ────────────────────────────────────────────────────────────
class _ExerciseItem extends StatelessWidget {
  final String text;
  final int number;
  const _ExerciseItem({required this.text, required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00C9AA).withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00C9AA).withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00A890), Color(0xFF00C9AA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text('$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF1A2332),
                  height: 1.5,
                )),
          ),
        ],
      ),
    );
  }
}

// ─── Risk Card ────────────────────────────────────────────────────────────────
class _RiskCard extends StatelessWidget {
  final String risk;
  final Color riskColor;
  final String riskEmoji;
  final String assessment;

  const _RiskCard({
    required this.risk,
    required this.riskColor,
    required this.riskEmoji,
    required this.assessment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: riskColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(riskEmoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  '${risk[0].toUpperCase()}${risk.substring(1)}',
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(assessment,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF4A5568),
                  height: 1.55,
                )),
          ),
        ],
      ),
    );
  }
}

// ─── Export Button ────────────────────────────────────────────────────────────
class _ExportButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _ExportButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 58,
        decoration: BoxDecoration(
          gradient: loading
              ? const LinearGradient(
                  colors: [Color(0xFF999999), Color(0xFFAAAAAA)])
              : const LinearGradient(
                  colors: [Color(0xFF0A7EA4), Color(0xFF0D9FCC)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: loading
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF0A7EA4).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
            else
              const Icon(Icons.picture_as_pdf_rounded,
                  color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              loading ? 'Generating PDF…' : 'Export PDF Report',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Home Button ──────────────────────────────────────────────────────────────
class _HomeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HomeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF0A7EA4).withOpacity(0.30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_rounded, color: Color(0xFF0A7EA4), size: 20),
            SizedBox(width: 8),
            Text('Back to Home',
                style: TextStyle(
                  color: Color(0xFF0A7EA4),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}
