import 'package:flutter/material.dart';
import 'package:gait_rehab/core/constants/app_text.dart';
import 'package:gait_rehab/core/constants/design_systems.dart' hide AppText;

import 'package:gait_rehab/core/widgets/widgets.dart';
import 'package:intl/intl.dart';

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  const ReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final session = report['sessions'] as Map<String, dynamic>?;
    final score = (session?['recovery_score'] as num?)?.toDouble() ?? 0;
    final risk = session?['fall_risk'] as String? ?? 'moderate';
    final date =
        DateTime.tryParse(report['generated_at'] ?? '') ?? DateTime.now();
    final summary = report['summary'] as String? ?? '';
    final riskText = report['risk_assessment'] as String? ?? '';
    final imp = (report['improvement_percentage'] as num?)?.toDouble() ?? 0;
    final abnorm = (report['abnormalities'] as List?)?.cast<String>() ?? [];
    final sugg =
        (report['exercise_suggestions'] as List?)?.cast<String>() ?? [];

    return GradientScaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.heroEnd,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    const BoxDecoration(gradient: AppColors.heroGradient),
                padding: const EdgeInsets.fromLTRB(22, 80, 22, 22),
                child: Stack(
                  children: [
                    Positioned.fill(
                        child: CustomPaint(painter: _DotPatternPainter())),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(DateFormat('EEE, d MMMM yyyy').format(date),
                            style: AppText.heroSubtitle),
                        const SizedBox(height: 4),
                        const Text('AI Rehab Report', style: AppText.heroTitle),
                        const SizedBox(height: 12),
                        Row(children: [
                          _Pill('${score.toStringAsFixed(1)}/100'),
                          const SizedBox(width: 8),
                          RiskBadge(risk: risk),
                          if (imp != 0) ...[
                            const SizedBox(width: 8),
                            _Pill(
                              '${imp > 0 ? '+' : ''}${imp.toStringAsFixed(1)}%',
                              color:
                                  imp >= 0 ? AppColors.teal : AppColors.danger,
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(
                    icon: Icons.summarize_rounded,
                    title: 'Session Summary',
                    child: Text(summary, style: AppText.body),
                  ),
                  const SizedBox(height: 16),
                  if (abnorm.isNotEmpty) ...[
                    _Section(
                      icon: Icons.warning_amber_rounded,
                      title: 'Gait Abnormalities',
                      iconColor: AppColors.warning,
                      child: Column(
                        children: abnorm
                            .map((a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(
                                            top: 6, right: 10),
                                        decoration: const BoxDecoration(
                                            color: AppColors.warning,
                                            shape: BoxShape.circle),
                                      ),
                                      Expanded(
                                          child: Text(a, style: AppText.body)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (sugg.isNotEmpty) ...[
                    _Section(
                      icon: Icons.fitness_center_rounded,
                      title: 'Recommended Exercises',
                      iconColor: AppColors.teal,
                      child: Column(
                        children: sugg
                            .asMap()
                            .entries
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: AppColors.tealPale,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text('${e.key + 1}',
                                            style: const TextStyle(
                                                fontFamily: AppText.fontFamily,
                                                fontSize: 10,
                                                color: AppColors.teal,
                                                fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child:
                                            Text(e.value, style: AppText.body)),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _Section(
                    icon: Icons.health_and_safety_rounded,
                    title: 'Risk Assessment',
                    iconColor: AppColors.riskColor(risk),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RiskBadge(risk: risk),
                        const SizedBox(height: 10),
                        Text(riskText, style: AppText.body),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TealButton(
                    label: 'Export as PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    onTap: () {},
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color? color;
  const _Pill(this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (color ?? Colors.white).withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontFamily: AppText.fontFamily,
              fontSize: 12,
              color: color ?? Colors.white,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final Widget child;
  const _Section(
      {required this.icon,
      required this.title,
      this.iconColor,
      required this.child});

  @override
  Widget build(BuildContext context) {
    final c = iconColor ?? AppColors.teal;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: c.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: c, size: 16),
            ),
            const SizedBox(width: 8),
            Text(title, style: AppText.h4),
          ]),
          const SizedBox(height: 12),
          const Divider(color: AppColors.cardBorder, height: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.07);
    for (double x = 0; x < size.width; x += 18) {
      for (double y = 0; y < size.height; y += 18) {
        canvas.drawCircle(Offset(x, y), 2, p);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
