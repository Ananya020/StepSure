class GaitMetrics {
  final double symmetry; // 0-100
  final double cadence; // steps/min
  final double strideConsistency; // 0-100
  final double jointDeviation; // 0-100 (lower = better, invert for score)
  final double strideLength;
  final List<double> strideIntervals;

  GaitMetrics({
    required this.symmetry,
    required this.cadence,
    required this.strideConsistency,
    required this.jointDeviation,
    required this.strideLength,
    required this.strideIntervals,
  });
}

class ScoreCalculator {
  static const double _symmetryWeight = 0.40;
  static const double _cadenceWeight = 0.20;
  static const double _consistencyWeight = 0.20;
  static const double _deviationWeight = 0.20;

  static const double _normalCadence = 100.0; // steps/min for stroke patients

  /// Computes recovery score 0-100
  static double computeRecoveryScore(GaitMetrics metrics) {
    final symmetryScore = metrics.symmetry.clamp(0, 100);
    final cadenceScore = _normalizeCadence(metrics.cadence);
    final consistencyScore = metrics.strideConsistency.clamp(0, 100);
    final deviationScore = (100 - metrics.jointDeviation).clamp(0, 100);

    return (symmetryScore * _symmetryWeight) +
        (cadenceScore * _cadenceWeight) +
        (consistencyScore * _consistencyWeight) +
        (deviationScore * _deviationWeight);
  }

  static double _normalizeCadence(double cadence) {
    if (cadence <= 0) return 0;
    if (cadence >= _normalCadence) return 100;
    return (cadence / _normalCadence) * 100;
  }

  static String computeFallRisk(GaitMetrics metrics) {
    int riskScore = 0;

    final strideVariability = _computeVariability(metrics.strideIntervals);
    if (strideVariability > 25) {
      riskScore += 2;
    } else if (strideVariability > 15) riskScore += 1;

    if (metrics.symmetry < 40) {
      riskScore += 2;
    } else if (metrics.symmetry < 60) riskScore += 1;

    if (metrics.strideConsistency < 40) {
      riskScore += 2;
    } else if (metrics.strideConsistency < 60) riskScore += 1;

    if (riskScore >= 4) return 'high';
    if (riskScore >= 2) return 'moderate';
    return 'low';
  }

  static double _computeVariability(List<double> intervals) {
    if (intervals.length < 2) return 0;
    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    if (mean == 0) return 0;
    final variance =
        intervals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            intervals.length;
    return (variance.abs().sqrt() / mean) * 100; // CV%
  }
}

extension on double {
  double sqrt() => this < 0
      ? 0
      : this == 0
          ? 0
          : _sqrt(this);
  double _sqrt(double x) {
    double z = x;
    for (int i = 0; i < 50; i++) {
      z -= (z * z - x) / (2 * z);
    }
    return z;
  }
}
