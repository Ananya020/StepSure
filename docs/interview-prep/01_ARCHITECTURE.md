# 01 — Architecture

## 1. Shape of the system
A **thick-client mobile app + Backend-as-a-Service**. No server code exists in the repo. The phone does capture, ML inference, metric computation, scoring and report text generation; Supabase only stores data and authenticates.

```
                        ┌───────────────────────────── Phone (Flutter, Dart) ─────────────────────────────┐
 Patient                │                                                                                 │
   │  walks in front    │  PRESENTATION (screens, widgets)                                                │
   ▼  of camera / picks │   Splash → AuthGate ─┬─ Login/Register → Onboarding                             │
 ┌────────┐  a video    │                      └─ HomeScreen (4 tabs: Home/Progress/Reports/Profile)      │
 │ Camera │────────────▶│        Home → InstructionsScreen → RecordingScreen ──┐                          │
 └────────┘             │        Home → UploadScreen ──────────────────────────┤                          │
                        │                                                      ▼                          │
                        │  DOMAIN (pure Dart rules)                       ResultsScreen → PdfExporter     │
                        │   GaitAnalysisService ─ AngleCalculator                                          │
                        │   ScoreCalculator · ReportGenerator · FeedbackEngine(TTS)                       │
                        │                    ▲                                                            │
                        │  DATA              │ Pose (33 landmarks)                                        │
                        │   PoseService / VideoAnalysisService ─▶ ML Kit PoseDetector (on-device)         │
                        │   └ MethodChannel "video_frame_extractor" ─▶ MainActivity.kt (Android only)     │
                        │   SupabaseService  ─────────────────────────────┐                               │
                        └─────────────────────────────────────────────────┼───────────────────────────────┘
                                                                          ▼  HTTPS (anon key + user JWT)
                                                              ┌────────────────────────┐
                                                              │ Supabase                │
                                                              │  Auth (email/password)  │
                                                              │  Postgres: profiles,    │
                                                              │   sessions, reports     │
                                                              │  Storage: session-videos│
                                                              └────────────────────────┘
```

Layering is *nominally* clean architecture (`presentation/ domain/ data/ core/`), but it leaks: screens call Supabase directly (`home_screen.dart`, `profile_screen.dart`, `reports_list_screen.dart`, auth screens) and `domain/gait_analysis_service.dart` imports ML Kit types.

## 2. Components: what / why / tech / alternative / tradeoff / if removed

| Component | What & why | Tech (why likely) | Alternatives | Trade-off | If removed |
|---|---|---|---|---|---|
| Flutter app | Single codebase iOS+Android; camera streaming + custom painter overlay | Flutter/Dart — cross-platform, good camera/ML plugins | React Native, native Kotlin/Swift | Plugin gaps (needed a hand-written Android `MethodChannel`; no iOS equivalent) | Everything |
| ML Kit Pose (`google_mlkit_pose_detection ^0.14.1`) | 33 body landmarks per frame, on-device | Free, offline, no training needed | MediaPipe BlazePose (same family, more control), MoveNet/TFLite, OpenPose, server-side inference | Only 2D x/y used (z ignored); generic model not tuned for pathological gait; no temporal smoothing | No landmarks ⇒ no metrics |
| `GaitAnalysisService` + `AngleCalculator` | Angles → step events → cadence/symmetry/consistency | Hand-written rules | Trained sequence model, gait-event detection from ankle/heel trajectories (what README describes but code doesn't do) | Simple/explainable but unvalidated & camera-angle dependent | No metrics |
| `ScoreCalculator` | Weighted score + fall risk | Fixed weights/thresholds | Learned/clinically validated index (e.g., Tinetti, TUG-based) | Explainable, arbitrary | No score |
| `ReportGenerator` | Template report text | if/else + string interpolation | LLM (README claims Gemini) | Deterministic, offline, safe; not "AI" | No report text |
| `FeedbackEngine` | Real-time voice cues (TTS) with 6 s cooldown per key | `flutter_tts` | On-screen only | Live bubble UI is dead (see bugs) | No audio cues |
| Supabase | Auth + Postgres + file storage without writing a server | supabase_flutter | Firebase, custom Node/FastAPI + Postgres | Security lives in RLS you must get right; no server-side validation of scores (client computes & writes them) | No accounts/history |
| Provider | `AuthProvider` (ChangeNotifier) | Simple | Riverpod/Bloc | Barely used: most screens use local `setState` + direct Supabase | Little breaks (AuthGate uses Supabase stream directly) |
| fl_chart | Progress line chart | — | syncfusion, custom paint | — | Progress tab |
| pdf + printing | Client-side PDF, share sheet | — | Server-side render | — | Export button fails |
| flutter_local_notifications + timezone | Intended reminders | ⚪ never wired | FCM push | — | Nothing (unused) |

## 3. Request/response, data, control flow (summary — details in `04_DATA_FLOW.md`)
- **Data flow (record)**: CameraImage → `InputImage` → `PoseService.detectPose` → `Pose` → `GaitAnalysisService.processFrame` (accumulate lists) → on stop `computeSessionMetrics` → `ScoreCalculator` → `SessionModel` → `SupabaseService.saveSession` → `ReportGenerator.generate` → `saveReport` → `ResultsScreen`.
- **Control flow**: imperative, screen-driven. Each screen constructs its own services (`SupabaseService()`, `PoseService()`, …) — no DI container.
- **Auth flow**: `main()` → `Supabase.initialize` → `SplashScreen` (≈4.2 s timer) → `AuthGate` (`StreamBuilder` on `onAuthStateChange`, reads `currentSession`) → Home or Login. Supabase SDK persists the session locally.
- **AI/ML flow**: pre-trained pose model → hand metrics → rules (see `07_AI_ML.md`). No embeddings, vector DB, LLM, or retrieval exist.
- **Deployment**: none in repo. No CI, Dockerfile, Fastlane, or Supabase migrations. Android release build is signed with **debug keys** (`android/app/build.gradle.kts:36-38`), `applicationId com.example.stepsure`. Release/main manifest has **no `INTERNET` permission** (only debug/profile manifests do) ⚠️ VERIFY on a built release APK — would break Supabase in release.

## 4. Two ingestion paths, deliberately different
| | Live (`RecordingScreen`) | Upload (`UploadScreen` → `VideoAnalysisService`) |
|---|---|---|
| Detector | `PoseDetectionMode.stream`, model `base` (fast) | `single`, model `accurate` |
| Input | camera `startImageStream`, drop frames while busy (`_processingFrame`, `_isProcessing`) | 50 JPEGs pulled by Android `MediaMetadataRetriever` |
| Feedback | TTS (`textOnly:false`) | text only (`textOnly:true`) |
| Video stored | No (`videoUrl: null`) | Yes, uploaded to Storage |
| Platforms | Android + iOS | Android only (no iOS channel) |
| Timing source | wall clock (`DateTime.now()`) — OK-ish live but `startSession` missing | wall clock — **wrong** for offline frames |

## 5. What breaks first under change
- Adding iOS video upload ⇒ must implement `video_frame_extractor` in Swift.
- Changing the DB column names ⇒ `SessionModel.toMap/fromMap`, `SupabaseService.saveReport`, and raw-map screens (`home_screen`, `profile_screen`, `report_detail_screen`) all hardcode strings.
- Renaming package: imports mix `package:gait_rehab/…` and relative imports; the test imports `package:stepsure/…`.
