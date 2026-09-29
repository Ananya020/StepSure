# 02 — Repository Map

Tracked files: 246 (≈ 12.3k lines of Dart in 58 files). Platform folders (`android ios linux macos windows web`) are Flutter scaffolding except where noted.

```
StepSure/
├── README.md              Marketing-style; MANY claims not in code (Gemini, exercise library, clinician dashboard…)
├── Ml.md                  Changelog of ML fixes (partly stale: describes a RepaintBoundary frame grabber & a richer PDF that are not what the code does now)
├── pubspec.yaml           package name `gait_rehab` (not stepsure), 25 deps
├── analysis_options.yaml  flutter_lints
├── test/widget_test.dart  default counter test — broken
├── assets/
│   ├── animations/*.json  5 Lottie files (walking, walking2, phone, loading, gradient_loader) + onboarding.mp4
│   └── gifs/loader.gif    (pubspec also declares assets/images/ which DOES NOT EXIST)
├── android/
│   ├── app/build.gradle.kts    appId com.example.stepsure; release signed w/ debug key
│   └── app/src/main/kotlin/.../MainActivity.kt   ★ native MethodChannel "video_frame_extractor" (frame extraction)
├── ios/Runner/AppDelegate.swift   plain — NO frame-extractor channel
├── android/build/reports/problems/problems-report.html   build artefact committed by accident
└── lib/
    ├── main.dart                    ★ init Supabase (hardcoded URL+anon key), providers, AuthGate
    ├── core/
    │   ├── constants/ app_colors, app_text, app_theme, design_systems (279 lines, 2nd colour/text system), app_strings (EMPTY)
    │   ├── utils/     angle_calculator ★, permission_handler (EMPTY)
    │   └── widgets/   widgets.dart (737; used), app_widgets.dart (390; UNUSED), animated_hero_background, confetti, success_overlay, risk_badge (EMPTY), score_badge (EMPTY)
    ├── data/
    │   ├── supabase_service.dart    ★ all session/report/storage calls
    │   ├── pose_service.dart        ★ live ML Kit detector wrapper
    │   ├── video_analysis_service.dart ★ offline pipeline
    │   ├── notification_service.dart   ⚪ never called
    │   └── local_storage.dart          EMPTY
    ├── domain/
    │   ├── gait_analysis_service.dart ★★ metrics engine
    │   ├── score_calculator.dart      ★★ GaitMetrics + score + fall risk
    │   ├── feedback_engine.dart       ★ TTS rules
    │   ├── report_generator.dart      ★ template report
    │   ├── pdf_generator.dart         PdfExporter
    │   └── models/ session_model ★, report_model (UNUSED — no references), gait_metrics_model (EMPTY)
    ├── features/notifications/     mock inbox + badge
    └── presentation/
        ├── providers/  auth_provider ✅ (barely used), session_provider (empty)
        └── screens/    auth/ splash/ home/ instructions/ recording/ (+skeleton_painter ★) upload/ results/ progress/ report/ profile/ notifications/
```
★ = interview-critical. ★★ = must be able to whiteboard.

## Dependency reality check (`pubspec.yaml` vs imports in `lib/`)
Used: supabase_flutter, camera, image_picker, file_picker, video_player, google_mlkit_pose_detection, flutter_tts, fl_chart, flutter_local_notifications (file never invoked), timezone, pdf, printing, provider, intl, lottie, confetti.
**Declared but never imported** (grep of `package:x/` in `lib/`): `uuid`, `path_provider`, `shared_preferences`, `google_fonts`, `flutter_animate`, `permission_handler`, `google_mlkit_commons`. Also README lists different versions (e.g. `flutter_tts ^4.0.2`, pubspec `^3.8.5`).

## Duplicates / dead code
- Two `ReportDetailScreen` classes: `report/report_screen.dart` (unreferenced) and `report/report_detail_screen.dart` (used).
- Two notification screens: `presentation/screens/notifications/notification_screen.dart` (used by Home) and `features/notifications/notifications_screen.dart` (only reachable via `NotificationBadge`, which nothing instantiates ⇒ dead).
- Two `RiskBadge` files (one empty), two colour systems (`AppColors` vs `design_systems.dart`), `sqrt` implemented twice by hand (`_mySqrt` in gait service, `extension on double` in score calculator) instead of `dart:math`.
