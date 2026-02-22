// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gait_rehab/core/constants/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';
import '../../../data/video_analysis_service.dart';
import '../../../data/supabase_service.dart';
import '../../../domain/score_calculator.dart';
import '../../../domain/report_generator.dart';
import '../../../domain/models/session_model.dart';
import '../instructions/primary_button.dart';
import '../results/results_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {
  File? _videoFile;
  bool _analyzing = false;
  double _progress = 0.0;
  String? _errorMessage;
  int _analysisStep = 0;

  // Deduplicated live feedback messages
  final List<String> _feedbackMessages = [];
  final Set<String> _seenFeedback = {};

  final _picker = ImagePicker();
  final _repaintKey = GlobalKey();
  final _supabase = SupabaseService();
  late final VideoAnalysisService _analysisService;
  VideoPlayerController? _videoController;

  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _stepController;
  late AnimationController _entryController;

  late Animation<double> _pulseAnim;
  late Animation<double> _shimmerAnim;
  late Animation<double> _entryAnim;

  static const _analysisSteps = [
    'Loading video frames…',
    'Detecting pose landmarks…',
    'Computing gait metrics…',
    'Saving your session…',
  ];

  static const _analysisIcons = [
    Icons.movie_filter_outlined,
    Icons.accessibility_new_rounded,
    Icons.analytics_outlined,
    Icons.cloud_upload_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _analysisService = VideoAnalysisService();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _pulseAnim = Tween(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shimmerAnim = Tween(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
    _entryAnim =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _analysisService.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _stepController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _updateStep(double progress) {
    final newStep = progress < 0.30
        ? 0
        : progress < 0.60
            ? 1
            : progress < 0.85
                ? 2
                : 3;
    if (newStep != _analysisStep) {
      setState(() => _analysisStep = newStep);
      _stepController.forward(from: 0);
    }
  }

  /// Add a feedback message only if it hasn't been shown before
  void _addFeedback(String msg) {
    final trimmed = msg.trim();
    if (trimmed.isEmpty) return;
    if (_seenFeedback.contains(trimmed)) return;
    _seenFeedback.add(trimmed);
    if (mounted) {
      setState(() {
        _feedbackMessages.insert(0, trimmed); // newest on top
        // keep max 5 unique messages visible
        if (_feedbackMessages.length > 5) {
          _feedbackMessages.removeLast();
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    String? pickedPath;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        pickedPath = result.files.single.path;
      }
    } else {
      final picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) pickedPath = picked.path;
    }
    if (pickedPath == null) return;

    final pickedFile = File(pickedPath);
    if (!pickedFile.existsSync()) {
      setState(() {
        _errorMessage = 'Picked video file does not exist at $pickedPath';
      });
      return;
    }

    await _videoController?.dispose();
    final controller = VideoPlayerController.file(pickedFile);
    await controller.initialize();

    setState(() {
      _videoFile = pickedFile;
      _videoController = controller;
      _errorMessage = null;
      _progress = 0.0;
      _analysisStep = 0;
      _feedbackMessages.clear();
      _seenFeedback.clear();
    });
  }

  Future<void> _analyzeVideo() async {
    if (_videoFile == null || _videoController == null || _analyzing) return;

    setState(() {
      _analyzing = true;
      _progress = 0.0;
      _errorMessage = null;
      _analysisStep = 0;
      _feedbackMessages.clear();
      _seenFeedback.clear();
    });

    final List<String> frameLogs = [];
    List<String> feedbackMessages = [];

    try {
      final metrics = await _analysisService.analyzeVideo(
        videoPath: _videoFile!.path,
        repaintKey: _repaintKey,
        onProgress: (p) {
          if (mounted) {
            // Clamp to max 0.99 during analysis — only show 100% when truly done
            final clamped = p.clamp(0.0, 0.99);
            setState(() => _progress = clamped);
            _updateStep(clamped);
          }
        },
        onLog: (msg) {
          frameLogs.add(msg);
          // Surface feedback messages from the log stream in real-time
          if (msg.startsWith('[FEEDBACK]')) {
            final clean = msg.replaceFirst('[FEEDBACK]', '').trim();
            _addFeedback(clean);
          }
        },
      );

      feedbackMessages = _analysisService.feedbackEngine.feedbackMessages;

      // Also deduplicate final feedback list and surface any new ones
      for (final msg in feedbackMessages) {
        _addFeedback(msg);
      }

      // Now truly at 100%
      if (mounted) setState(() => _progress = 1.0);
      await Future.delayed(const Duration(milliseconds: 400));

      final score = ScoreCalculator.computeRecoveryScore(metrics);
      final fallRisk = ScoreCalculator.computeFallRisk(metrics);
      final userId = _supabase.currentUserId!;

      final session = SessionModel(
        userId: userId,
        sessionDate: DateTime.now(),
        durationSeconds: _videoController!.value.duration.inSeconds,
        recoveryScore: score,
        fallRisk: fallRisk,
        strideLength: metrics.strideLength,
        cadence: metrics.cadence,
        symmetry: metrics.symmetry,
        strideConsistency: metrics.strideConsistency,
        jointDeviation: metrics.jointDeviation,
      );

      final sessionId = await _supabase.saveSession(session);
      final videoUrl = await _supabase.uploadVideo(_videoFile!.path, sessionId);
      if (videoUrl != null) {
        await _supabase.updateSessionVideoUrl(sessionId, videoUrl);
      }
      final sessionWithVideo =
          session.copyWith(id: sessionId, videoUrl: videoUrl);
      final prev = await _supabase.getLastSession();
      final report =
          ReportGenerator.generate(current: sessionWithVideo, previous: prev);
      await _supabase.saveReport(sessionId: sessionId, report: report);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultsScreen(
              session: sessionWithVideo.toMap(),
              report: report,
              feedbackMessages: feedbackMessages,
            ),
          ),
        );
      }
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '') +
          (frameLogs.isNotEmpty
              ? '\n\nFrame logs:\n${frameLogs.take(10).join('\n')}'
              : '');
      debugPrint('[ANALYZE ERROR] $errorMsg');
      if (mounted) {
        setState(() {
          _analyzing = false;
          _errorMessage = errorMsg;
          _progress = 0.0;
        });
      }
    }
  }

  String get _fileName => _videoFile!.path.split('/').last;
  String get _fileSizeLabel {
    try {
      final bytes = _videoFile!.lengthSync();
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_analyzing) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F7FA),
        body: _AnalyzingOverlay(
          progress: _progress,
          step: _analysisStep,
          steps: _analysisSteps,
          icons: _analysisIcons,
          pulseAnim: _pulseAnim,
          shimmerAnim: _shimmerAnim,
          stepController: _stepController,
          repaintKey: _repaintKey,
          videoController: _videoController,
          feedbackMessages: _feedbackMessages,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      body: Stack(
        children: [
          if (_videoController != null)
            Opacity(
              opacity: 0.01,
              child: SizedBox(
                width: 320,
                height: 240,
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _entryAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: _videoFile == null
                        ? _DropZoneEmpty(onTap: _pickVideo)
                        : _DropZoneSelected(
                            file: _videoFile!,
                            fileName: _fileName,
                            fileSize: _fileSizeLabel,
                            duration: _videoController?.value.duration,
                            onReplace: _pickVideo,
                          ),
                  ),
                ),
              ),
              if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _ErrorCard(message: _errorMessage!),
                  ),
                ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: _RequirementsCard(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                  child: _ActionButton(
                    hasVideo: _videoFile != null,
                    onPickVideo: _pickVideo,
                    onAnalyze: _analyzeVideo,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00A890), Color(0xFF07B5A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.07))),
            ),
            Positioned(
              bottom: 10,
              right: 60,
              child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.upload_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 5),
                            Text('Upload',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Analyse Video',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                                height: 1.0)),
                        SizedBox(height: 6),
                        Text(
                            'Upload a walking video for a full gait analysis report',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Analyzing Overlay ────────────────────────────────────────────────────────
class _AnalyzingOverlay extends StatelessWidget {
  final double progress;
  final int step;
  final List<String> steps;
  final List<IconData> icons;
  final Animation<double> pulseAnim;
  final Animation<double> shimmerAnim;
  final AnimationController stepController;
  final GlobalKey repaintKey;
  final VideoPlayerController? videoController;
  final List<String> feedbackMessages;

  const _AnalyzingOverlay({
    required this.progress,
    required this.step,
    required this.steps,
    required this.icons,
    required this.pulseAnim,
    required this.shimmerAnim,
    required this.stepController,
    required this.repaintKey,
    required this.videoController,
    required this.feedbackMessages,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Hidden video player
        if (videoController != null)
          Opacity(
            opacity: 0.01,
            child: SizedBox(
              width: 320,
              height: 240,
              child: RepaintBoundary(
                key: repaintKey,
                child: VideoPlayer(videoController!),
              ),
            ),
          ),

        // Gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A7EA4), Color(0xFF07B5A0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // Decorative blobs
        Positioned(
            top: -80,
            right: -80,
            child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07)))),
        Positioned(
            bottom: -60,
            left: -60,
            child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05)))),

        // Main content (scrollable)
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Feedback notification stack (top) ──────────────────
                if (feedbackMessages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _FeedbackStack(messages: feedbackMessages),
                  ),

                const SizedBox(height: 12),

                // ── Pulsing ring + walking animation ──────────
                AnimatedBuilder(
                  animation: pulseAnim,
                  builder: (_, child) => Transform.scale(
                    scale: pulseAnim.value,
                    child: child,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.20),
                                  width: 2))),
                      Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.10),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.30),
                                  width: 1.5))),
                      Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.18)),
                          child: Center(
                              child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: Lottie.asset(
                                      'assets/animations/walking2.json',
                                      repeat: true,
                                      fit: BoxFit.contain)))),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Percentage ────────────────────────────────
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress * 100),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (_, val, __) => Text(
                    '${val.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        height: 1),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Analysing your gait…',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),

                const SizedBox(height: 28),

                // ── Shimmer progress bar ──────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Container(
                          height: 10,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12))),
                      AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 400),
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: AnimatedBuilder(
                          animation: shimmerAnim,
                          builder: (_, __) => Container(
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment(shimmerAnim.value - 1, 0),
                                end: Alignment(shimmerAnim.value + 1, 0),
                                colors: [
                                  Colors.white.withOpacity(0.5),
                                  Colors.white.withOpacity(0.95),
                                  Colors.white.withOpacity(0.5),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Step indicators ───────────────────────────
                _StepIndicators(
                  steps: steps,
                  icons: icons,
                  currentStep: step,
                  controller: stepController,
                ),

                const SizedBox(height: 28),

                // ── Bottom hint ───────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.20)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.white60, size: 16),
                      SizedBox(width: 8),
                      Text('Please keep the app open during analysis',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Feedback Notification Stack ──────────────────────────────────────────────
class _FeedbackStack extends StatelessWidget {
  final List<String> messages;
  const _FeedbackStack({required this.messages});

  IconData _iconFor(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('great') ||
        lower.contains('good') ||
        lower.contains('keep it up')) {
      return Icons.thumb_up_rounded;
    }
    if (lower.contains('faster') ||
        lower.contains('speed') ||
        lower.contains('cadence')) {
      return Icons.speed_rounded;
    }
    if (lower.contains('symmetr')) return Icons.balance_rounded;
    if (lower.contains('stride')) return Icons.straighten_rounded;
    if (lower.contains('posture') || lower.contains('upright')) {
      return Icons.accessibility_new_rounded;
    }
    return Icons.tips_and_updates_rounded;
  }

  Color _colorFor(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('great') ||
        lower.contains('good') ||
        lower.contains('keep it up')) {
      return const Color(0xFF00C9AA);
    }
    if (lower.contains('try') ||
        lower.contains('improve') ||
        lower.contains('faster')) {
      return const Color(0xFFFFD166);
    }
    return const Color(0xFF64DFDF);
  }

  @override
  Widget build(BuildContext context) {
    // Show max 3 bubbles, newest on top
    final visible = messages.take(3).toList();

    return Column(
      children: visible.asMap().entries.map((e) {
        final i = e.key;
        final msg = e.value;
        final color = _colorFor(msg);
        final icon = _iconFor(msg);
        final isLatest = i == 0;

        return _FeedbackBubble(
          message: msg,
          icon: icon,
          color: color,
          isLatest: isLatest,
          index: i,
        );
      }).toList(),
    );
  }
}

class _FeedbackBubble extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final bool isLatest;
  final int index;

  const _FeedbackBubble({
    required this.message,
    required this.icon,
    required this.color,
    required this.isLatest,
    required this.index,
  });

  @override
  State<_FeedbackBubble> createState() => _FeedbackBubbleState();
}

class _FeedbackBubbleState extends State<_FeedbackBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Older bubbles are slightly smaller and less opaque
    final scale = widget.isLatest ? 1.0 : (widget.index == 1 ? 0.97 : 0.94);
    final opacity = widget.isLatest ? 1.0 : (widget.index == 1 ? 0.75 : 0.50);

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // Glassmorphic white with subtle tint
                color: Colors.white.withOpacity(widget.isLatest ? 0.22 : 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isLatest
                      ? widget.color.withOpacity(0.50)
                      : Colors.white.withOpacity(0.20),
                  width: widget.isLatest ? 1.5 : 1.0,
                ),
                boxShadow: widget.isLatest
                    ? [
                        BoxShadow(
                          color: widget.color.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // Icon badge
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: widget.isLatest ? Colors.white : Colors.white70,
                        fontSize: widget.isLatest ? 13.5 : 12.5,
                        fontWeight:
                            widget.isLatest ? FontWeight.w700 : FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                  // Latest indicator dot
                  if (widget.isLatest) ...[
                    const SizedBox(width: 8),
                    _PulsingDot(color: widget.color),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Step Indicators ──────────────────────────────────────────────────────────
class _StepIndicators extends StatelessWidget {
  final List<String> steps;
  final List<IconData> icons;
  final int currentStep;
  final AnimationController controller;

  const _StepIndicators({
    required this.steps,
    required this.icons,
    required this.currentStep,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (i) {
        final isDone = i < currentStep;
        final isActive = i == currentStep;
        final isPending = i > currentStep;

        return AnimatedOpacity(
          opacity: isPending ? 0.35 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withOpacity(0.18)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: isActive
                  ? Border.all(color: Colors.white.withOpacity(0.35))
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDone
                        ? Colors.white.withOpacity(0.90)
                        : isActive
                            ? Colors.white.withOpacity(0.25)
                            : Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFF07B5A0), size: 18)
                        : Icon(icons[i],
                            color: isActive
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            size: 17),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(steps[i],
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : isDone
                                ? Colors.white70
                                : Colors.white38,
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                      )),
                ),
                if (isActive)
                  const _PulsingDot(color: Colors.white)
                else if (isDone)
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white70, size: 16),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── Pulsing Dot ──────────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Drop Zone Empty ──────────────────────────────────────────────────────────
class _DropZoneEmpty extends StatefulWidget {
  final VoidCallback onTap;
  const _DropZoneEmpty({required this.onTap});

  @override
  State<_DropZoneEmpty> createState() => _DropZoneEmptyState();
}

class _DropZoneEmptyState extends State<_DropZoneEmpty>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _float = Tween(begin: -6.0, end: 6.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF00A890).withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
          border: Border.all(
              color: const Color(0xFF00A890).withOpacity(0.25),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned.fill(
                  child: CustomPaint(painter: _DashedBorderPainter())),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _float,
                      builder: (_, child) => Transform.translate(
                          offset: Offset(0, _float.value), child: child),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF00A890), Color(0xFF07B5A0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    const Color(0xFF00A890).withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        child: const Icon(Icons.video_library_rounded,
                            color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Tap to select video',
                        style: TextStyle(
                            color: Color(0xFF1A2332),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 5),
                    Text('MP4 · MOV · AVI supported',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Drop Zone Selected ───────────────────────────────────────────────────────
class _DropZoneSelected extends StatelessWidget {
  final File file;
  final String fileName;
  final String fileSize;
  final Duration? duration;
  final VoidCallback onReplace;

  const _DropZoneSelected({
    required this.file,
    required this.fileName,
    required this.fileSize,
    required this.duration,
    required this.onReplace,
  });

  String _formatDuration(Duration? d) {
    if (d == null) return '—';
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0A7EA4).withOpacity(0.10),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
        border: Border.all(
            color: const Color(0xFF0A7EA4).withOpacity(0.25), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF0A7EA4), Color(0xFF0D9FCC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.videocam_rounded,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName,
                    style: const TextStyle(
                        color: Color(0xFF1A2332),
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  _MetaChip(icon: Icons.storage_rounded, label: fileSize),
                  const SizedBox(width: 8),
                  _MetaChip(
                      icon: Icons.timer_outlined,
                      label: _formatDuration(duration)),
                ]),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onReplace,
                  child: const Text('Replace video',
                      style: TextStyle(
                          color: Color(0xFF0A7EA4),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFF00A890).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check_rounded,
                color: Color(0xFF00A890), size: 20),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFF0A7EA4).withOpacity(0.07),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF0A7EA4)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF0A7EA4),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Requirements Card ────────────────────────────────────────────────────────
class _RequirementsCard extends StatelessWidget {
  static const _items = [
    (Icons.directions_walk_rounded, 'Full body visible throughout the video'),
    (Icons.wb_sunny_outlined, 'Good lighting — avoid dark or blurry footage'),
    (Icons.phone_android_rounded, 'Side view or front-on view supported'),
    (Icons.straighten_rounded, 'At least 10 seconds of walking footage'),
  ];

  const _RequirementsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: const Color(0xFF0A7EA4).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.checklist_rounded,
                    color: Color(0xFF0A7EA4), size: 18)),
            const SizedBox(width: 10),
            const Text('Requirements',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2332),
                    letterSpacing: -0.3)),
          ]),
          const SizedBox(height: 16),
          ..._items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < _items.length - 1 ? 12 : 0),
              child: Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: const Color(0xFF00A890).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(item.$1,
                        color: const Color(0xFF00A890), size: 17)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(item.$2,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.4))),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final bool hasVideo;
  final VoidCallback onPickVideo;
  final VoidCallback onAnalyze;

  const _ActionButton(
      {required this.hasVideo,
      required this.onPickVideo,
      required this.onAnalyze});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: hasVideo ? onAnalyze : onPickVideo,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: hasVideo
                  ? const [Color(0xFF0A7EA4), Color(0xFF0D9FCC)]
                  : const [Color(0xFF00A890), Color(0xFF07B5A0)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: (hasVideo
                        ? const Color(0xFF0A7EA4)
                        : const Color(0xFF00A890))
                    .withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                hasVideo
                    ? Icons.play_circle_outline_rounded
                    : Icons.video_library_rounded,
                color: Colors.white,
                size: 22),
            const SizedBox(width: 10),
            Text(hasVideo ? 'Start Analysis' : 'Select Video',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2)),
          ],
        ),
      ),
    );
  }
}

// ─── Error Card ───────────────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.30))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFF6B6B), size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                      child: Text(message,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFCC3333),
                              height: 1.5))))),
        ],
      ),
    );
  }
}

// ─── Dashed Border Painter ────────────────────────────────────────────────────
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00A890).withOpacity(0.30)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 6.0;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(28)));

    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, dist + dashWidth), paint);
        dist += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
