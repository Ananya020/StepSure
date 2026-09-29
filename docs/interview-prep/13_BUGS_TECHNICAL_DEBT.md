# 13 — Bugs / Suspicious Logic / Technical Debt

Severity reflects impact on the app's stated purpose. "VERIFIED" = proven by reading code paths (grep confirmed); no runtime execution possible here.

## CRITICAL
**C1 — Live cadence always 0 (VERIFIED).** `GaitAnalysisService.startSession()` is called only in `video_analysis_service.dart:117`; `RecordingScreen` never calls it (`grep startSession lib/` ⇒ 2 hits). `_sessionStart` stays `null` ⇒ `_computeCurrentCadence()` (`gait_analysis_service.dart:87-92`) returns 0 ⇒ stored `cadence=0`, cadence score 0 (score ≤ 80), `strideLength` falls back to 0.8, and `FeedbackEngine` says "walk a little faster" constantly. Fix: call `_gaitService.startSession()` in `_startRecording` (and clear on camera switch).
**C2 — Offline-video timing uses wall-clock (VERIFIED by reading).** `_recordStep` uses `DateTime.now()`; frames are processed back-to-back ⇒ intervals ≈ inference latency; cadence = steps / real elapsed processing time. All timing-derived metrics (cadence, consistency, stride variability ⇒ fall risk) are artifacts in upload mode. Fix: `processFrame(pose, Duration frameTime)`.
**C3 — Health outputs presented without validation/disclaimer.** "Fall risk", "recovery score" have no clinical basis in repo; PDF has no disclaimer. (Product/regulatory risk.)

## HIGH
- **H1 Empty/failed session saved as data** (`recording_screen._stopRecording`): no pose-count/duration guard ⇒ score 20/"moderate" record; user can tap stop instantly.
- **H2 Live feedback bubble never shows** (`FeedbackEngine._addFeedback` only when `textOnly`, `RecordingScreen` builds it with `textOnly:false`).
- **H3 No error handling around saves** in `_stopRecording` (3 awaits) ⇒ unhandled exception, stuck UI, lost session.
- **H4 Fabricated stride length** (`cadence*0.0028`, fallback 0.8 m) stored, displayed and put in PDF/summary as if measured.
- **H5 Upload path Android-only** — no iOS `video_frame_extractor`; Android impl on UI thread, forces 16:9 resize (distorts portrait video ⇒ distorted angles), ignores `fps`, samples fixed 50 frames.
- **H6 Release build likely can't reach network**: `INTERNET` permission only in debug/profile manifests ⚠️ VERIFY on release APK; also debug signing.
- **H7 Broken test / package-name mismatch** (`stepsure` vs `gait_rehab`).
- **H8 Videos public / RLS unverified** (see `10`).

## MEDIUM
- **Stale tabs**: `HomeScreen` uses `IndexedStack` (`home_screen.dart:37`); `_HomeTab`, `ProgressScreen`, `ReportsListScreen`, `ProfileScreen` fetch only in `initState` ⇒ new sessions don't appear until restart (logically certain from code; not run).
- `ReportGenerator`: divide by zero when previous score 0; `improvement==0` ⇒ "first session" text.
- Fall-risk double counts variability (CV and 100−CV).
- `computeConsistency` returns 100 for <3 intervals (rewards no data); symmetry of `0/0` returns 100; `getAngle` returns 0 for missing landmark.
- Symmetry metric conceptually weak; `likelihood` ignored; `poses.first`.
- `FeedbackEngine` emits contradictory advice (e.g. knee cue picks *smaller* angle leg), feedback list unbounded in upload mode; `[FEEDBACK]` log branch dead.
- Step thresholds (140/160°) unsuitable for stiff-knee gait; standing still scores ~79.
- `onboarding_screen._save` uses `currentUser!` (null if email confirmation on); `SupabaseService` uses `currentUserId!`.
- Non-atomic session→video→report writes; duplicate reports on retry; orphan rows.
- `session_date` local ISO string without offset.
- `Storage.upload` always `.mp4`; no `upsert` handling ⇒ re-upload with same id would 409.
- Dispose issues: `_cameraController?.dispose()` without awaiting `stopImageStream`; `_switchCamera` mutates state without `mounted` checks; no `WidgetsBindingObserver` pause handling; `_stopRecording` re-entrant.
- `AuthProvider.signIn` etc. unused; `SupabaseService.getUserReports` unused.
- Profile stats load all sessions.

## LOW
- `Future.delayed(400 ms)` cosmetic waits; 4.2 s mandatory splash.
- `_HomeTab` swallows all errors (`catch (_)`).
- Commit hygiene: build report committed; "final fix(es)" commits; `.vscode/` tracked.
- Mixed import styles (`package:gait_rehab/…` vs relative).

## TECHNICAL DEBT / DEAD CODE
Empty files (6), unused files (`app_widgets.dart`, `report_screen.dart`, `report_model.dart`, `features/notifications/*`, `notification_service.dart`, `session_provider.dart`), duplicated `sqrt`, duplicated auth code (3 places), two design systems, two notification screens, 7 unused dependencies, `assets/images/` declared but missing, README/Ml.md drift (Gemini, exercise engine, RepaintBoundary, PDF layout, DB schema, dependency versions, `supabase_config.dart` instructions), screens of 700–1500 lines mixing UI + data access, hardcoded colors/strings, no i18n, no DI.

## Hardcoded values that matter
Thresholds: 160/140° (steps), 0.3–3.0 s interval, 120–170° knee range, 100 spm normal cadence, weights 0.4/0.2/0.2/0.2, risk cut-offs, feedback cut-offs, `0.0028`, `0.8`, 50 frames, 720×405, ≥5 poses, ≥10 frames, ≥2 s video, 6 s TTS cooldown, limit 30.
