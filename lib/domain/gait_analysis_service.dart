import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/utils/angle_calculator.dart';
import 'score_calculator.dart';
import 'feedback_engine.dart';

class GaitAnalysisService {
  final FeedbackEngine feedbackEngine;

  // Accumulate data during session
  final List<double> _leftKneeAngles = [];
  final List<double> _rightKneeAngles = [];
  final List<double> _strideIntervals = [];
  final List<double> _symmetryScores = [];
  DateTime? _lastStride;
  int _stepCount = 0;
  DateTime? _sessionStart;
  bool _leftExtended = false;
  bool _rightExtended = false;

  GaitAnalysisService({required this.feedbackEngine});

  void startSession() {
    _leftKneeAngles.clear();
    _rightKneeAngles.clear();
    _strideIntervals.clear();
    _symmetryScores.clear();
    _stepCount = 0;
    _sessionStart = DateTime.now();
    _lastStride = null;
    _leftExtended = false;
    _rightExtended = false;
  }

  void processFrame(Pose pose) {
    final angles = AngleCalculator.extractAngles(pose);

    final lk = angles['left_knee'] ?? 0;
    final rk = angles['right_knee'] ?? 0;
    final trunk = angles['trunk_lean'] ?? 0;

    _leftKneeAngles.add(lk);
    _rightKneeAngles.add(rk);

    final sym = AngleCalculator.computeSymmetry(lk, rk);
    _symmetryScores.add(sym);

    // Step detection: rising-edge state machine with hysteresis
    // Only count a step on the transition from flexed → extended (prevents
    // counting the same step on every frame while the knee stays extended).
    if (!_leftExtended && lk > 160) {
      _leftExtended = true;
      _recordStep();
    } else if (lk < 140) {
      _leftExtended = false; // re-arm once knee bends back past 140°
    }
    if (!_rightExtended && rk > 160) {
      _rightExtended = true;
      _recordStep();
    } else if (rk < 140) {
      _rightExtended = false;
    }

    final currentCadence = _computeCurrentCadence();

    feedbackEngine.analyze(
      symmetry: sym,
      cadence: currentCadence,
      leftKneeAngle: lk,
      rightKneeAngle: rk,
      trunkLean: trunk,
      strideConsistency: _computeConsistency(),
    );
  }

  void _recordStep() {
    final now = DateTime.now();
    if (_lastStride != null) {
      final interval = now.difference(_lastStride!).inMilliseconds / 1000.0;
      if (interval > 0.3 && interval < 3.0) {
        _strideIntervals.add(interval);
        _stepCount++;
      }
    }
    _lastStride = now;
  }

  double _computeCurrentCadence() {
    if (_sessionStart == null) return 0;
    final elapsed = DateTime.now().difference(_sessionStart!).inSeconds;
    if (elapsed == 0) return 0;
    return (_stepCount / elapsed) * 60;
  }

  double _computeConsistency() {
    if (_strideIntervals.length < 3) return 100;
    final mean =
        _strideIntervals.reduce((a, b) => a + b) / _strideIntervals.length;
    final variance = _strideIntervals
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        _strideIntervals.length;
    final cv = (variance < 0 ? 0 : _mySqrt(variance)) / mean * 100;
    return (100 - cv).clamp(0, 100);
  }

  double _mySqrt(double x) {
    if (x <= 0) return 0;
    double z = x;
    for (int i = 0; i < 50; i++) {
      z -= (z * z - x) / (2 * z);
    }
    return z;
  }

  GaitMetrics computeSessionMetrics() {
    final avgLeftKnee = _avg(_leftKneeAngles);
    final avgRightKnee = _avg(_rightKneeAngles);
    final avgSymmetry = _avg(_symmetryScores);
    final cadence = _computeCurrentCadence();
    final consistency = _computeConsistency();

    // Joint deviation: how far knee angles deviate from normal range (120-170)
    final leftDev = _deviationFromRange(avgLeftKnee, 120, 170);
    final rightDev = _deviationFromRange(avgRightKnee, 120, 170);
    final jointDeviation = (leftDev + rightDev) / 2;

    // Estimated stride length (simplified — use hip keypoint delta ideally)
    final strideLength = cadence > 0 ? (cadence * 0.0028) : 0.8;

    return GaitMetrics(
      symmetry: avgSymmetry,
      cadence: cadence,
      strideConsistency: consistency,
      jointDeviation: jointDeviation,
      strideLength: strideLength,
      strideIntervals: List.from(_strideIntervals),
    );
  }

  double _avg(List<double> list) =>
      list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;

  double _deviationFromRange(double value, double min, double max) {
    if (value >= min && value <= max) return 0;
    if (value < min) return ((min - value) / min * 100).clamp(0, 100);
    return ((value - max) / max * 100).clamp(0, 100);
  }
}
