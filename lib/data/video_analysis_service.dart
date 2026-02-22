import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:video_player/video_player.dart';
import '../domain/feedback_engine.dart';
import '../domain/gait_analysis_service.dart';
import '../domain/score_calculator.dart';

/// Analyses a video file for gait metrics using Google ML Kit pose detection.
///
/// Because ML Kit processes images (not video), frames are extracted by
/// seeking a [VideoPlayerController] and capturing the rendered widget via a
/// [RenderRepaintBoundary] whose [GlobalKey] is owned by [UploadScreen].
///
/// Sampling rate: 5 fps (one frame every 200 ms).
class VideoAnalysisService {
  FeedbackEngine get feedbackEngine => _feedbackEngine;
  late final PoseDetector _detector;
  late final GaitAnalysisService _gaitService;
  late final FeedbackEngine _feedbackEngine;

  VideoAnalysisService() {
    // Use singleImage mode for non-sequential video frames (more accurate
    // than stream mode which assumes temporal continuity between frames).
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.accurate,
      ),
    );
    _feedbackEngine = FeedbackEngine(textOnly: true);
    _gaitService = GaitAnalysisService(feedbackEngine: _feedbackEngine);
  }

  /// Processes [videoPath] frame-by-frame and returns [GaitMetrics].
  ///
  /// [repaintKey] must be attached to a [RepaintBoundary] that wraps a
  /// [VideoPlayer] widget rendered somewhere in the active widget tree.
  ///
  /// [onProgress] is called after each frame with a value in [0.0, 1.0].
  ///
  /// Throws an [Exception] when video duration is unreadable or fewer than
  /// 5 poses are successfully detected (too short / body not visible).
  Future<GaitMetrics> analyzeVideo({
    required String videoPath,
    required GlobalKey repaintKey,
    void Function(double progress)? onProgress,
    void Function(String log)? onLog, // Optional log callback
  }) async {
    // ── Check if video file exists and is long enough ──
    final videoFile = File(videoPath);
    if (!videoFile.existsSync()) {
      onLog?.call('[ERROR] Video file does not exist at $videoPath');
      throw Exception('Video file does not exist at $videoPath');
    }
    // Check video duration (requires video_player)
    final controller = VideoPlayerController.file(videoFile);
    try {
      await controller.initialize();
    } catch (e) {
      onLog?.call('[ERROR] Could not initialize video: $e');
      throw Exception('Could not initialize video: $e');
    }
    final duration = controller.value.duration;
    if (duration.inSeconds < 2) {
      onLog?.call(
          '[ERROR] Video is too short (${duration.inSeconds}s). Minimum 2 seconds required.');
      throw Exception(
          'Video is too short (${duration.inSeconds}s). Minimum 2 seconds required.');
    }
    await controller.dispose();

    // ── Extract frames using platform channel ──────────────────────────────
    final tempDir = await Directory.systemTemp.createTemp();
    final frameFiles = <File>[];
    const totalFrames = 50;
    try {
      const MethodChannel channel = MethodChannel('video_frame_extractor');
      final List<dynamic>? thumbnails =
          await channel.invokeMethod('extractFrames', {
        'videoPath': videoPath,
        'fps': 5,
        'width': 720,
        'height': 405,
        'count': totalFrames,
      });
      if (thumbnails != null) {
        for (int i = 0; i < thumbnails.length; i++) {
          final bytes = thumbnails[i] as Uint8List;
          final file = File('${tempDir.path}/frame_$i.jpg');
          await file.writeAsBytes(bytes);
          frameFiles.add(file);
          onProgress?.call((i + 1) / totalFrames);
        }
      } else {
        onLog?.call('[ERROR] Frame extraction returned null.');
        throw Exception('Frame extraction failed: No frames returned.');
      }
    } on MissingPluginException catch (e) {
      onLog?.call(
          '[ERROR] Frame extraction not implemented on this platform: $e');
      throw Exception(
          'Frame extraction is not supported on this platform. Please ensure the video_frame_extractor plugin is implemented for your device.');
    } catch (e, stack) {
      onLog?.call('[ERROR] Frame extraction failed: $e\n$stack');
      throw Exception('Frame extraction failed: $e');
    }
    if (frameFiles.length < 10) {
      onLog?.call('[ERROR] Video is too short or frame extraction failed.');
      throw Exception('Video is too short or frame extraction failed.');
    }
    _feedbackEngine.feedbackMessages.clear();
    _gaitService.startSession();
    int posesDetected = 0;
    for (int i = 0; i < frameFiles.length; i++) {
      try {
        final inputImage = InputImage.fromFilePath(frameFiles[i].path);
        final poses = await _detector.processImage(inputImage);
        if (poses.isNotEmpty) {
          _gaitService.processFrame(poses.first);
          posesDetected++;
          onLog?.call(
              '[INFO] Frame $i: Pose detected (${poses.first.landmarks.length} landmarks).');
        } else {
          onLog?.call('[INFO] Frame $i: No pose detected.');
        }
      } catch (e, stack) {
        onLog?.call('[ERROR] Frame $i: Exception: $e\n$stack');
      }
      onProgress?.call((i + 1) / frameFiles.length);
    }
    // Clean up temp frames
    for (final f in frameFiles) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
    if (posesDetected < 5) {
      onLog?.call(
          '[ERROR] Insufficient pose data detected ($posesDetected/${frameFiles.length} frames). Ensure the full body is visible and well-lit throughout the video, and that the video is recorded from a side or front-on view.');
      throw Exception(
          'Insufficient pose data detected ($posesDetected/${frameFiles.length} frames). Ensure the full body is visible and well-lit throughout the video, and that the video is recorded from a side or front-on view.');
    }
    onLog?.call(
        '[SUCCESS] Video analysis complete. $posesDetected poses detected from ${frameFiles.length} frames.');
    return _gaitService.computeSessionMetrics();
  }

  /// Release ML Kit resources. Call from the owning widget's [dispose].
  void dispose() {
    _detector.close();
    _feedbackEngine.dispose();
  }
}
