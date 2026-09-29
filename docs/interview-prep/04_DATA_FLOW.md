# 04 — End-to-End Execution Flows

Each step names the real file/function.

## Flow 1 — App start & auth gate
1. `main()` (`main.dart`) → `Supabase.initialize(url, anonKey)` (restores persisted session from device storage).
2. `GaitRehabApp` → `SplashScreen(next: AuthGate())`; splash runs Lottie + `Future.delayed(4200 ms)` then navigates.
3. `AuthGate` → `StreamBuilder(onAuthStateChange)`; builder reads `currentSession` → `HomeScreen` or `LoginScreen`.
4. Login: `login_screen._login` → `auth.signInWithPassword` → success emits auth event → `AuthGate` rebuilds → Home. (No explicit navigation; failure ⇒ `AuthException.message` in a SnackBar; non-Auth exceptions such as no network are **not caught** ⇒ unhandled.)
5. Register: `register_screen._register` → `auth.signUp` → `pushReplacement(OnboardingScreen)` → `_save` → `profiles.upsert({id, full_name, age, stroke_date, affected_side})` → `pushAndRemoveUntil(HomeScreen)`.

## Flow 2 — Live recording → results (the main journey)
```
HomeScreen "Record" → InstructionsScreen (step carousel; last step) → RecordingScreen
initState: FeedbackEngine(), GaitAnalysisService, PoseService; _initializeCamera()
tap ● → _startRecording: _sessionStart=now; 1 s UI timer; camera.startImageStream(cb)
  cb(CameraImage):
    if (!_isRecording || _processingFrame) return          ← frame dropping
    _inputImageFromCamera → InputImage (NV21 / BGRA8888 + rotation)
    PoseService.detectPose → ML Kit stream/base → Pose? (poses.first)
    setState(currentPose, rawImageSize) → SkeletonPainter overlay
    GaitAnalysisService.processFrame(pose):
        AngleCalculator.extractAngles → knee L/R, hip, trunk
        symmetry(lk, rk); step state machine; cadence; consistency
        FeedbackEngine.analyze → TTS (cooldown 6 s/key)
tap ■ → _stopRecording:
    stopImageStream
    GaitAnalysisService.computeSessionMetrics → GaitMetrics
    ScoreCalculator.computeRecoveryScore / computeFallRisk
    SessionModel(...videoUrl:null)
    SupabaseService.saveSession → INSERT sessions … RETURNING id
    SupabaseService.getLastSession → SELECT … ORDER BY session_date DESC LIMIT 2 → row[1]
    ReportGenerator.generate(current, previous)
    SupabaseService.saveReport → INSERT reports
    Navigator.pushReplacement(ResultsScreen(session.toMap(), report))
ResultsScreen: animations + reads raw maps; "Export PDF" → PdfExporter.exportReport → Printing.sharePdf
```
Known defects on this path: `startSession()` never invoked ⇒ cadence 0; feedback bubble dead; no guard for empty/short recordings; no error handling around 3 network calls; two identical `session_date`s impossible (uses `_sessionStart`) but a `previous` of score 0 ⇒ ∞ improvement.

## Flow 3 — Upload video → results
1. `HomeScreen` → `UploadScreen`; `_pickVideo` (iOS `file_picker`, Android `image_picker`) → `VideoPlayerController.initialize` (preview only).
2. `_analyzeVideo` → `VideoAnalysisService.analyzeVideo`:
   1. duration check ≥2 s → 2. `MethodChannel.extractFrames` (Kotlin) → 50 JPEG bytes → 3. write temp files → 4. `startSession()` → 5. loop: `InputImage.fromFilePath` → `PoseDetector.processImage` → `processFrame` → progress callback → 6. ≥5 poses check → 7. `computeSessionMetrics`.
3. Back in `UploadScreen`: score/risk → `SessionModel` → `saveSession` → `Storage.upload('{uid}/{sessionId}.mp4')` → `getPublicUrl` → `sessions.update(video_url)` → `getLastSession` → `ReportGenerator` → `saveReport` → `ResultsScreen(feedbackMessages)`.
4. Errors: any exception ⇒ message + first 10 log lines; UI resets to selection state.
**Why metrics are unreliable here**: frames are processed back-to-back; `GaitAnalysisService` timestamps with `DateTime.now()`; so `_strideIntervals` and cadence measure ML Kit processing latency. The correct fix: pass a `timestamp` (frame time = index·duration/count) into `processFrame`.

## Flow 4 — History & progress
- Progress tab: `ProgressScreen._load` → `getUserSessions()` (30 newest) → reversed → `FlSpot(i, recoveryScore)` → `fl_chart` `LineChart`.
- Reports tab: `_load` → `reports` + embedded `sessions(...)` join filtered by `user_id` → list → tap → `ReportDetailScreen(report: row)`.
- Profile tab: profile row + *all* sessions to compute count/avg/total minutes on-device.

## Flow 5 — Reminder setting (partial)
Profile switch/time → `_saveReminder` → `profiles.update(reminder_enabled, reminder_time)`. **Nothing schedules a notification** (`NotificationService` unused).

## Flow 6 — What the README says vs actual for "AI report"
README: gait → Gemini → PDF. Actual: `ReportGenerator.generate` (string templates) → DB → `PdfExporter` local PDF. No network AI call anywhere.
