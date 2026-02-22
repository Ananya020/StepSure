import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math';

class AngleCalculator {
  /// Computes angle at joint B given points A, B, C
  static double computeAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final ba = [a.x - b.x, a.y - b.y];
    final bc = [c.x - b.x, c.y - b.y];

    final dotProduct = ba[0] * bc[0] + ba[1] * bc[1];
    final magBA = sqrt(ba[0] * ba[0] + ba[1] * ba[1]);
    final magBC = sqrt(bc[0] * bc[0] + bc[1] * bc[1]);

    if (magBA == 0 || magBC == 0) return 0;
    final cosAngle = (dotProduct / (magBA * magBC)).clamp(-1.0, 1.0);
    return acos(cosAngle) * (180 / pi);
  }

  /// Compute symmetry between left and right angles (0-100)
  static double computeSymmetry(double leftAngle, double rightAngle) {
    if (leftAngle == 0 && rightAngle == 0) return 100;
    final diff = (leftAngle - rightAngle).abs();
    final avg = (leftAngle + rightAngle) / 2;
    if (avg == 0) return 0;
    final asymmetry = (diff / avg) * 100;
    return (100 - asymmetry).clamp(0, 100);
  }

  /// Extract gait-relevant angles from pose
  static Map<String, double> extractAngles(Pose pose) {
    final landmarks = pose.landmarks;

    double getAngle(
        PoseLandmarkType a, PoseLandmarkType b, PoseLandmarkType c) {
      final lA = landmarks[a];
      final lB = landmarks[b];
      final lC = landmarks[c];
      if (lA == null || lB == null || lC == null) return 0;
      return computeAngle(lA, lB, lC);
    }

    return {
      'left_knee': getAngle(
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
      ),
      'right_knee': getAngle(
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle,
      ),
      'left_hip': getAngle(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
      ),
      'right_hip': getAngle(
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
      ),
      'trunk_lean': _computeTrunkLean(landmarks),
    };
  }

  static double _computeTrunkLean(Map<PoseLandmarkType, PoseLandmark> lm) {
    final leftShoulder = lm[PoseLandmarkType.leftShoulder];
    final rightShoulder = lm[PoseLandmarkType.rightShoulder];
    final leftHip = lm[PoseLandmarkType.leftHip];
    final rightHip = lm[PoseLandmarkType.rightHip];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return 0;
    }

    final shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2;
    final shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2;
    final hipMidX = (leftHip.x + rightHip.x) / 2;
    final hipMidY = (leftHip.y + rightHip.y) / 2;

    final dx = shoulderMidX - hipMidX;
    final dy = shoulderMidY - hipMidY;

    return atan2(dx, -dy) * (180 / pi); // degrees from vertical
  }
}
