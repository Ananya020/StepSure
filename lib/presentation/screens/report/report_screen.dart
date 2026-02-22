import 'package:flutter/material.dart';
import 'package:gait_rehab/core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/risk_badge.dart';
import '../instructions/primary_button.dart';

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final session = report['sessions'] as Map<String, dynamic>?;
    final score = (session?['recovery_score'] as num?)?.toDouble() ?? 0;
    final risk = session?['fall_risk'] as String? ?? 'moderate';
    final date = DateTime.tryParse(report['generated_at'] as String? ?? '') ??
        DateTime.now();
    final summary = report['summary'] as String? ?? '';
    final riskAssessment = report['risk_assessment'] as String? ?? '';
    final improvement =
        (report['improvement_percentage'] as num?)?.toDouble() ?? 0;
    final abnormalities =
        (report['abnormalities'] as List<dynamic>?)?.cast<String>() ?? [];
    final suggestions =
        (report['exercise_suggestions'] as List<dynamic>?)?.cast<String>() ??
            [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                ),
                padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(date),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'AI Rehab Report',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _HeaderPill(
                            label: 'Score ${score.toStringAsFixed(1)}/100'),
                        const SizedBox(width: 10),
                        RiskBadge(risk: risk),
                        const SizedBox(width: 10),
                        if (improvement != 0)
                          _HeaderPill(
                            label:
                                '${improvement > 0 ? '+' : ''}${improvement.toStringAsFixed(1)}%',
                            color: improvement >= 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Summary
                  _Section(
                    icon: Icons.summarize_rounded,
                    title: 'Session Summary',
                    color: AppColors.primary,
                    child: Text(
                      summary,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.65),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Abnormalities
                  if (abnormalities.isNotEmpty)
                    _Section(
                      icon: Icons.warning_amber_rounded,
                      title: 'Gait Abnormalities (${abnormalities.length})',
                      color: AppColors.danger,
                      child: Column(
                        children: abnormalities
                            .map(
                              (a) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.only(
                                          top: 6, right: 10),
                                      decoration: const BoxDecoration(
                                        color: AppColors.danger,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(a,
                                          style: const TextStyle(
                                              fontSize: 13.5,
                                              color: AppColors.textPrimary,
                                              height: 1.5)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                  else
                    const _Section(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Gait Abnormalities',
                      color: AppColors.success,
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 18),
                          SizedBox(width: 8),
                          Text(
                              'No significant gait abnormalities detected.',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),

                  if (abnormalities.isNotEmpty) const SizedBox(height: 20),

                  // Exercise Suggestions
                  if (suggestions.isNotEmpty)
                    _Section(
                      icon: Icons.fitness_center_rounded,
                      title: 'Recommended Exercises',
                      color: AppColors.primary,
                      child: Column(
                        children: suggestions.asMap().entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${e.key + 1}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(e.value,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          color: AppColors.textPrimary,
                                          height: 1.5)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  if (suggestions.isNotEmpty) const SizedBox(height: 20),

                  // Risk Assessment
                  _Section(
                    icon: Icons.health_and_safety_rounded,
                    title: 'Risk Assessment',
                    color: AppColors.riskColor(risk),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RiskBadge(risk: risk, large: true),
                        const SizedBox(height: 12),
                        Text(
                          riskAssessment,
                          style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Export button
                  PrimaryButton(
                    label: 'Export as PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    color: AppColors.primary,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Generating PDF report...')),
                      );
                    },
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

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  const _Section({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.primary, height: 1),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String label;
  final Color? color;

  const _HeaderPill({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (color ?? Colors.white).withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}
