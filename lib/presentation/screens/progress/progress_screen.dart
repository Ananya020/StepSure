import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/supabase_service.dart';
import '../../../domain/models/session_model.dart';
import '../../../core/constants/app_colors.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _supabase = SupabaseService();
  List<SessionModel> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await _supabase.getUserSessions();
    setState(() {
      _sessions = sessions.reversed.toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final spots = _sessions
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.recoveryScore))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Recovery Progress'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards
            Row(
              children: [
                _statCard(
                    'Sessions', '${_sessions.length}', Icons.calendar_today),
                const SizedBox(width: 12),
                _statCard(
                  'Best Score',
                  _sessions.isEmpty
                      ? '-'
                      : _sessions
                          .map((s) => s.recoveryScore)
                          .reduce((a, b) => a > b ? a : b)
                          .toStringAsFixed(1),
                  Icons.emoji_events,
                ),
                const SizedBox(width: 12),
                _statCard(
                  'Latest',
                  _sessions.isEmpty
                      ? '-'
                      : _sessions.last.recoveryScore.toStringAsFixed(1),
                  Icons.trending_up,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Recovery Score Over Time',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: spots.length < 2
                  ? const Center(
                      child: Text(
                          'Complete at least 2 sessions to see progress graph.'))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 100,
                        gridData:
                            const FlGridData(show: true, horizontalInterval: 20),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, _) => Text(
                                'S${(val + 1).toInt()}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 20,
                              getTitlesWidget: (val, _) => Text(
                                  '${val.toInt()}',
                                  style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.3),
                                  AppColors.secondary.withOpacity(0.05),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
