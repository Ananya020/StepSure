import 'dart:async';
import 'dart:io';
import '../results/results_screen.dart';
import 'package:gait_rehab/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../../data/pose_service.dart';
import '../../../domain/gait_analysis_service.dart';
import '../../../domain/feedback_engine.dart';
import '../../../domain/score_calculator.dart';
import '../../../domain/report_generator.dart';
import '../../../data/supabase_service.dart';
import '../../../domain/models/session_model.dart';
import 'skeleton_painter.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  InputImage? _inputImageFromCamera(CameraImage image) {
    try {
      if (Platform.isIOS) {
        return InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: _inputRotation,
            format: InputImageFormat.bgra8888,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
      } else {
        final WriteBuffer buffer = WriteBuffer();
        for (final plane in image.planes) {
          buffer.putUint8List(plane.bytes);
        }
        return InputImage.fromBytes(
          bytes: buffer.done().buffer.asUint8List(),
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: _inputRotation,
            format: InputImageFormat.nv21,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
      }
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _feedbackEngine = FeedbackEngine();
    _gaitService = GaitAnalysisService(feedbackEngine: _feedbackEngine);
    _poseService = PoseService();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      _selectedCameraIndex = 0;
      _cameraController = CameraController(
        _cameras![_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      setState(() {});
    } catch (e) {
      setState(() {
        _cameraError = 'Camera error: $e';
      });
    }
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _cameraController?.dispose();
    _cameraController = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    setState(() {});
  }

  void _startRecording() async {
    _sessionStart = DateTime.now();
    _sessionSeconds = 0;
    _errorLogs.clear();
    _isRecording = true;
    setState(() {});

    // Start timer
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      setState(() {
        _sessionSeconds = DateTime.now().difference(_sessionStart).inSeconds;
      });
    });

    // Start image stream for pose detection
    try {
      await _cameraController?.startImageStream((CameraImage image) async {
        if (!_isRecording) return;
        final inputImage = _inputImageFromCamera(image);
        if (inputImage == null) return;
        final pose = await _poseService.detectPose(inputImage);
        setState(() {
          _currentPose = pose;
          _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        });
        // Speech feedback and pose analysis
        if (pose == null) {
          _feedbackEngine.analyze(
            symmetry: 0,
            cadence: 0,
            leftKneeAngle: 0,
            rightKneeAngle: 0,
            trunkLean: 0,
            strideConsistency: 0,
          );
        } else {
          _gaitService.processFrame(pose);
        }
      });
    } catch (e) {
      setState(() {
        _errorLogs.add('Image stream error: $e');
      });
    }
  }

  Timer? _timer;

  Future<void> _stopRecording() async {
    await _cameraController?.stopImageStream();
    setState(() {
      _isRecording = false;
    });

    // Compute session metrics
    final metrics = _gaitService.computeSessionMetrics();
    final score = ScoreCalculator.computeRecoveryScore(metrics);
    final fallRisk = ScoreCalculator.computeFallRisk(metrics);
    final userId = _supabase.currentUserId ?? '';

    final session = SessionModel(
      userId: userId,
      sessionDate: _sessionStart,
      durationSeconds: _sessionSeconds,
      recoveryScore: score,
      fallRisk: fallRisk,
      strideLength: metrics.strideLength,
      cadence: metrics.cadence,
      symmetry: metrics.symmetry,
      strideConsistency: metrics.strideConsistency,
      jointDeviation: metrics.jointDeviation,
      videoUrl: null,
    );

    final sessionId = await _supabase.saveSession(session);
    final prev = await _supabase.getLastSession();
    final report = ReportGenerator.generate(
      current: session,
      previous: prev,
    );
    await _supabase.saveReport(sessionId: sessionId, report: report);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            session: session.copyWith(id: sessionId).toMap(),
            report: report,
          ),
        ),
      );
    }
  }

  final List<String> _errorLogs = [];
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  String? _cameraError;
  Pose? _currentPose;
  Size? _imageSize;
  final InputImageRotation _inputRotation = InputImageRotation.rotation0deg;
  bool _isRecording = false;
  int _sessionSeconds = 0;
  DateTime _sessionStart = DateTime.now();
  late FeedbackEngine _feedbackEngine;
  late GaitAnalysisService _gaitService;
  late PoseService _poseService;
  final SupabaseService _supabase = SupabaseService();

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) {
      return Scaffold(body: Center(child: Text(_cameraError!)));
    }
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Live Gait Recording'),
        actions: [
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              icon: Icon(
                _selectedCameraIndex == 0
                    ? Icons.camera_front
                    : Icons.camera_rear,
                color: Colors.white,
              ),
              tooltip: 'Switch Camera',
              onPressed: _switchCamera,
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          // Skeleton overlay
          if (_currentPose != null && _imageSize != null)
            CustomPaint(
              painter: SkeletonPainter(
                pose: _currentPose!,
                imageSize: _imageSize!,
                rotation: _inputRotation,
              ),
            ),
          // HUD overlay
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _hudChip(Icons.timer, '${_sessionSeconds}s'),
                _hudChip(
                    Icons.directions_walk, _isRecording ? 'LIVE' : 'READY'),
              ],
            ),
          ),
          // Error log overlay
          if (_errorLogs.isNotEmpty)
            Positioned(
              bottom: 140,
              left: 20,
              right: 20,
              child: Container(
                height: 120,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent, width: 1),
                ),
                child: Scrollbar(
                  child: ListView.builder(
                    itemCount: _errorLogs.length,
                    itemBuilder: (context, idx) => Text(
                      _errorLogs[idx],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.fiber_manual_record,
                    color: _isRecording ? Colors.white : Colors.red,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    _poseService.dispose();
    _feedbackEngine.dispose();
    super.dispose();
  }
}
