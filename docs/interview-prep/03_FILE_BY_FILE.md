# 03 — File-by-File Reverse Engineering

Only files with logic an interviewer can probe. Line numbers refer to the current tree.

---
### `lib/main.dart`
**Purpose**: entry point. **Why**: composition root.
- `main()`: `WidgetsFlutterBinding.ensureInitialized()`, `tz.initializeTimeZones()` (only needed by the never-used `NotificationService`), `Supabase.initialize(url, anonKey)` — **both hardcoded literals** (lines 16-19).
- `GaitRehabApp`: `MultiProvider` with `AuthProvider`, `SessionProvider` (empty); Material3 theme seeded from `AppColors.primary`; `home: SplashScreen(next: AuthGate())`.
- `AuthGate`: `StreamBuilder` on `auth.onAuthStateChange`; **ignores the snapshot** and reads `auth.currentSession` on each rebuild → shows `HomeScreen` or `LoginScreen`.
**Called by**: Flutter runtime. **Calls**: Supabase SDK, screens.
**Interview**: why anon key in client is OK only with RLS; why `AuthGate` reacts to a stream but reads `currentSession` (works, but semantically odd); what happens if Supabase init fails (no try/catch → app crash at startup).

---
### `lib/core/utils/angle_calculator.dart` ★★
**Purpose**: geometry on ML Kit landmarks.
- `computeAngle(a,b,c)`: angle at **b** in 2-D image space using dot product: `acos(BA·BC / (|BA||BC|))`, cos clamped to [-1,1] (guards float error), returns degrees; returns 0 if either vector has zero length. Uses only `x,y` (z ignored).
- `computeSymmetry(l, r)`: `100 − |l−r| / avg(l,r) · 100`, clamped 0–100; both 0 ⇒ 100; avg 0 ⇒ 0. **Instantaneous per-frame** comparison of left vs right knee angle.
- `extractAngles(pose)`: `left_knee`(hip-knee-ankle), `right_knee`, `left_hip`(shoulder-hip-knee), `right_hip`, `trunk_lean`. **Missing landmark ⇒ 0** (indistinguishable from real 0°), and `landmark.likelihood` is **never checked**.
- `_computeTrunkLean`: `atan2(dx, −dy)` from hip-mid to shoulder-mid ⇒ signed degrees from vertical (image y grows downward, hence `−dy`). Only meaningful in a frontal/side view of a roughly upright person.
**Called by**: `GaitAnalysisService.processFrame`. **Interview**: derive the dot-product formula; why clamp; why 2-D angles change with camera view; why per-frame L/R difference is not a clinical symmetry index (legs are naturally out of phase during swing).

### `lib/domain/gait_analysis_service.dart` ★★ (core engine)
State: lists of left/right knee angles, `_strideIntervals`, `_symmetryScores`, `_lastStride`, `_stepCount`, `_sessionStart`, `_leftExtended/_rightExtended`.
- `startSession()`: clears state, sets `_sessionStart`. ⚠️ **Only called from `VideoAnalysisService`; `RecordingScreen` never calls it** ⇒ live `_sessionStart == null` ⇒ `_computeCurrentCadence()` returns 0 forever.
- `processFrame(Pose)`: extract angles → append → symmetry → **step state machine** → cadence → `feedbackEngine.analyze(...)`.
  - Step rule (per leg): if not armed-extended and knee `>160°` ⇒ mark extended + `_recordStep()`; else if knee `<140°` ⇒ re-arm. 20° hysteresis prevents multiple counts while knee stays straight.
- `_recordStep()`: shared `_lastStride` across both legs ⇒ interval = time between successive step events (L→R→L…). Accept only `0.3 s < interval < 3.0 s`; then push interval and `_stepCount++`. The first event only sets `_lastStride` (not counted).
- `_computeCurrentCadence()`: `steps / elapsedSeconds · 60` (integer-second elapsed; 0 if `elapsed==0`).
- `_computeConsistency()`: coefficient of variation of stride intervals; `100 − CV%` clamped; **returns 100 (perfect) if <3 intervals**. Custom Newton `_mySqrt` (50 iterations) instead of `sqrt`.
- `computeSessionMetrics()`: averages knee angles/symmetry; `jointDeviation` = mean of each knee's avg distance outside "normal" 120–170° range as % (`_deviationFromRange`); `strideLength = cadence>0 ? cadence·0.0028 : 0.8` ⇒ **fabricated** (100 spm ⇒ 0.28 m; no geometry involved); returns `GaitMetrics`.
**Wall-clock dependence**: `DateTime.now()` inside `_recordStep` and cadence ⇒ correct-ish for live streaming, **wrong for offline video** (see `04`).
**Interview**: explain hysteresis; why 160/140; limitations for stiff-knee stroke gait (knee may never drop <140 or exceed 160 ⇒ undercount); why average of angles hides variability; unit-test approach (inject clock, feed synthetic sine knee angles).

### `lib/domain/score_calculator.dart` ★★
- `GaitMetrics` data holder (`symmetry, cadence, strideConsistency, jointDeviation, strideLength, strideIntervals`).
- `computeRecoveryScore`: weights 0.40/0.20/0.20/0.20; cadence normalised vs `_normalCadence = 100` spm (linear to 100, capped); deviation inverted.  Note `strideLength` is **not** in the score although README says stride is measured.
- `computeFallRisk`: integer points — stride CV% (>25 ⇒2, >15 ⇒1) + symmetry (<40 ⇒2, <60 ⇒1) + consistency (<40 ⇒2, <60 ⇒1); ≥4 high, ≥2 moderate else low. **Double counting**: consistency is `100−CV` of the same intervals as `_computeVariability` (CV). README says risk is from CV alone.
- `extension on double { sqrt() }`: hand-rolled Newton again (duplicate of `_mySqrt`).
**Worked examples**
- Empty session (no poses/steps): symmetry 0, cadence 0, consistency 100 (default), deviation 100 ⇒ score `0+0+20+0 = 20`, risk points: symmetry<40 ⇒2 ⇒ **"moderate"**. (Video mode blocks this via `<5 poses` guard; live mode does not.)
- Live mode today: cadence always 0 ⇒ **max achievable score is 80**.

### `lib/domain/feedback_engine.dart` ★
- Rules evaluated **every frame**: symmetry <50 / >75, cadence <50 / >110, |trunk|>10, |ΔL/R knee|>20 (says the *smaller-angle* leg should "lift higher" — questionable: smaller knee angle = more flexed), consistency <50, combined "good balance".
- `_speak`: 6 s cooldown **per key**; skipped when `textOnly`.
- `_addFeedback`: appends to `feedbackMessages` **only when `textOnly`** ⇒ in live mode the list stays empty ⇒ `RecordingScreen._updateFeedback` never shows a bubble (dead UI path). In upload mode (`textOnly:true`) the list grows once per triggering frame (unbounded; UI dedups).
- Because cadence is 0 at start (and always live), "walk a little faster" fires immediately.
- `_initTts` is `async` inside a constructor (fire-and-forget); TTS errors unhandled.

### `lib/domain/report_generator.dart`
Pure function `generate(current, previous)`. `improvement = (cur−prev)/prev·100` ⇒ **divide-by-zero if `previous.recoveryScore == 0`** (Infinity/NaN ⇒ JSON encode failure on insert). Threshold rules add abnormality+exercise text (symmetry<60, jointDeviation>40, cadence<60, consistency<60; high risk ⇒ walking-aid advice). Summary label: ≥70 Good, ≥40 Moderate. Output map keys mirror `reports` columns. **This is what README calls "Gemini-powered reports".**
Quirk: `improvement == 0` also prints "This is your first session" even when scores are equal.

### `lib/domain/models/session_model.dart`
Immutable model; `toMap()` (snake_case, no `id`) / `fromMap()` (casts `num→double`, `DateTime.parse`) / `copyWith`. `fromMap` will throw on null numeric columns (`(map[..] as num)`).

### `lib/data/pose_service.dart`
Wraps `PoseDetector` (`stream`, `base`). Re-entrancy guard `_isProcessing` drops frames while a detection is in flight (back-pressure by dropping). Logs each detection with `debugPrint`. Returns `poses.first` (assumes one person; with several people in frame the first is arbitrary).

### `lib/data/video_analysis_service.dart` ★★
Pipeline for uploaded video:
1. File exists → `VideoPlayerController.file(...).initialize()` to read duration; reject `<2 s`.
2. `MethodChannel('video_frame_extractor').invokeMethod('extractFrames', {fps:5, width:720, height:405, count:50})`. **Native side ignores `fps`** and samples `count=50` frames evenly across the whole video (`interval = durationMs/count`).
3. Write JPEGs to temp dir; need ≥10 frames.
4. `_gaitService.startSession()`; for each JPEG `InputImage.fromFilePath` → `PoseDetector(single, accurate).processImage` → `processFrame`.
5. Require ≥5 poses else throw; cleanup temp files; `computeSessionMetrics()`.
**Bug**: `GaitAnalysisService` uses `DateTime.now()` between frames ⇒ intervals reflect **processing speed (~100s of ms)**, not video time ⇒ cadence/consistency/stride are artifacts. Also a 30 s video ⇒ 0.6 s spacing (too coarse to see steps); a 10 s video ⇒ 0.2 s. Doc comment says "5 fps" — not true. `MissingPluginException` on iOS is caught and turned into a friendly error. All 50 frames returned in one platform-channel message (memory heavy: 50×~50–150 KB). `repaintKey` parameter is vestigial (left from the old RepaintBoundary approach described in `Ml.md`). Unused `_gaitService` log tag `[FEEDBACK]` is never emitted, so that UI branch is dead.

### `lib/data/supabase_service.dart` ★
Thin repository over the Supabase client (`saveSession`, `getUserSessions` (limit 30), `getLastSession` (limit 2 → index 1 because the current session was just inserted), `saveReport`, `getUserReports`, `uploadVideo` → `session-videos/{uid}/{sessionId}.mp4` + `getPublicUrl`, `updateSessionVideoUrl`). Uses `currentUserId!` (crashes if logged out). No transactions, no retries, no error handling; `uploadVideo` return type `String?` but never returns null. `signUp/signIn/signOut` here are duplicated by `AuthProvider` and by direct calls in screens.

### `android/.../MainActivity.kt` ★
`MethodChannel "video_frame_extractor"` → `MediaMetadataRetriever.getFrameAtTime(i·interval µs, OPTION_CLOSEST)` → scale to 720×405 (**forces 16:9, distorting portrait videos**) → JPEG q90 → list of byte arrays. Runs on the **main/UI thread** (blocking 50 decodes ⇒ ANR risk on long/HD videos). `retriever.release()` skipped on exception (leak).

### `lib/presentation/screens/recording/recording_screen.dart` ★★
Lifecycle: `initState` builds `FeedbackEngine()`, `GaitAnalysisService`, `PoseService`; `_initializeCamera` picks `availableCameras()[0]`, `ResolutionPreset.high`, `enableAudio:false`.
- `_inputImageFromCamera`: iOS → single-plane BGRA8888; Android → concatenates all planes as NV21 with `sensorOrientation` rotation. (Camera plugin must be configured for NV21 — plugin default on Android is YUV_420_888 unless `imageFormatGroup` is set; ⚠️ VERIFY this actually produces valid NV21 on all devices.)
- `_startRecording`: sets timers; `startImageStream` callback drops frames while `_processingFrame`; → `PoseService.detectPose` → `setState` (every frame!) → `processFrame`.
- `_stopRecording`: stop stream → compute metrics/score/risk → build `SessionModel` → `saveSession` → `getLastSession` → `ReportGenerator` → `saveReport` → `pushReplacement(ResultsScreen)`. **No try/catch** (network failure = unhandled exception, spinner-less frozen screen), **no minimum-duration/pose-count guard**, `userId ?? ''`.
- `_switchCamera` while recording restarts recording (resets `_sessionStart` but not the gait service).
**Interview**: frame-drop strategy, why `enableAudio:false`, coordinate spaces (raw vs rotated), what you'd do to add a "record then analyse" mode.

### `lib/presentation/screens/recording/skeleton_painter.dart`
`CustomPainter` mapping ML Kit landmark pixel coords (already in rotated/portrait space) to screen by proportional scaling; mirrors x for the front camera; draws 20 bones and joints if `likelihood ≥ 0.40`, low-confidence joints as yellow dots. Assumes preview fills the screen with the same aspect as the image (no letterbox/`BoxFit.cover` compensation) ⇒ overlay misalignment on aspect mismatch (⚠️ VERIFY on device). `shouldRepaint` compares `pose` identity (new object each frame ⇒ always repaint).

### `lib/presentation/screens/upload/upload_screen.dart` (1504 lines, mostly UI)
Logic only at `_pickVideo` (iOS uses `file_picker` to avoid PHPicker; Android `image_picker`), `_analyzeVideo` (calls service, computes score/risk, `saveSession` → `uploadVideo` → `updateSessionVideoUrl` → `getLastSession` → report → `ResultsScreen`), `_updateStep` (maps progress % to 4 cosmetic steps). Errors are caught and shown with up to 10 frame logs. Video upload happens **after** metrics; if upload throws, the session row already exists (orphan, no report). `_repaintKey`/hidden player are leftovers.

### `lib/presentation/screens/results/results_screen.dart` (1192 lines)
Renders from raw maps (`widget.session['recovery_score']` etc.) with defaults (`risk ?? 'moderate'`, scores `?? 0`); `_exportPdf` → `SessionModel.fromMap(widget.session)` → `PdfExporter.exportReport`. Heavy animation controllers (4).

### `lib/presentation/screens/home/home_screen.dart` (1273)
`HomeScreen` holds a `_currentIndex` and a plain list of 4 tab pages (`_HomeTab`, `ProgressScreen`, `ReportsListScreen`, `ProfileScreen`) + `_BottomNav`. `_HomeTab._load`: profile (`maybeSingle`) + latest session (`limit(1)`), no loading error surfacing (`catch (_)`).

### `progress_screen.dart` — `getUserSessions()` (latest 30, reversed) → `FlSpot(index, recoveryScore)`. X axis is session index, not date. `reports_list_screen.dart` — `select('*, sessions(recovery_score, fall_risk, duration_seconds)')` (PostgREST embedded join ⇒ requires FK `reports.session_id → sessions.id`). `profile_screen.dart` — loads **all** sessions client-side to average score & sum minutes (`select('recovery_score, duration_seconds')` unbounded); reminder switch/time only `update`s `profiles` (no scheduling). `onboarding_screen.dart` — `upsert` profile with `currentUser!.id` (**null crash if email confirmation is enabled**, since `signUp` then yields no session ⚠️ VERIFY Supabase setting).

### `auth_provider.dart` — wraps signIn/signUp/signOut/getProfile returning `String?` error; **not used by the login/register screens** (they call Supabase directly). `session_provider.dart` — empty.

### `pdf_generator.dart` — one A4 page via `pdf` package; `report['abnormalities'] as List<String>` (works only with the generator's map, not with a DB row); `Printing.sharePdf`. Title says "Gait Rehab AI"; no disclaimer (README/`Ml.md` claim one).

### `notification_service.dart` — correct-looking daily-repeat scheduling (`zonedSchedule`, `matchDateTimeComponents: time`, `exactAllowWhileIdle`) but never initialised or invoked; Android 13 `POST_NOTIFICATIONS` and exact-alarm permissions are not in the manifest ⇒ would not work even if wired.

### Empty / zero-byte files
`app_strings.dart`, `permission_handler.dart`, `local_storage.dart`, `gait_metrics_model.dart`, `core/widgets/risk_badge.dart`, `core/widgets/score_badge.dart`.
