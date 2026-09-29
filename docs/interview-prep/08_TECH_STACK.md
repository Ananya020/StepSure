# 08 — Technology Stack Defense

Format: **Tech** — Why used · Solves · Alternative (when better) · Trade-off · Likely question.

- **Dart / Flutter (SDK ≥3.0, `flutter_lints`)** — one codebase for iOS/Android, rich custom painting (skeleton overlay), good plugins for camera/ML. Alt: React Native (JS ecosystem), native (best camera/ML control & performance). Trade-off: needed native Kotlin for frame extraction; plugin version churn. Q: "Why Flutter for a camera+ML app?" A: speed of building UI + cross-platform; ML Kit/Camera plugins exist; cost is per-frame platform-channel overhead & the manual Android glue.
- **google_mlkit_pose_detection ^0.14.1** — pre-trained on-device pose. Alt: MediaPipe Tasks (3-D world landmarks, more tuning), MoveNet TFLite, server GPU model (accuracy, privacy cost). Trade-off: black box, no fine-tuning. Q: "Why not train your own model?" (no labelled post-stroke gait data, compute, time; pre-trained is a reasonable baseline).
- **camera ^0.10.5+9** — live `startImageStream`. Alt: `camerax` directly / native. Q: "How do you handle backpressure?" (`_processingFrame` drop flag).
- **video_player, image_picker, file_picker** — preview + pick video; `file_picker` on iOS to bypass PHPicker (code comment).
- **supabase_flutter ^2.3.0** — Auth+Postgres+Storage without a server. Alt: Firebase (Firestore, better offline, proprietary), custom FastAPI/Node (full control, server-side validation). Trade-off: business rules live in the client; security = RLS. Q: "Why Supabase over Firebase?" (SQL/relational metrics, RLS in SQL, open-source; join in reports list.)
- **PostgreSQL** — relational sessions/reports, embedded join. Alt: Firestore (offline sync) / SQLite local-first. Trade-off: needs connectivity; no local cache (`local_storage.dart` empty).
- **provider ^6.1.2** — DI/ChangeNotifier. Alt: Riverpod, Bloc. Honest: mostly unused; state is `setState`. Q: "Where does your app state live?"
- **fl_chart ^0.67.0** — line chart. Alt: syncfusion_flutter_charts, custom paint.
- **flutter_tts ^3.8.5** — spoken cues (accessibility for patients who can't look at screen). Alt: pre-recorded audio (consistent, offline, controllable), vibration.
- **pdf ^3.10.8 + printing ^5.12.0** — client-side PDF & share. Alt: server-generated (branding, signatures).
- **flutter_local_notifications ^17 + timezone** — reminders (⚪ not wired). Alt: FCM/APNs push (server-driven).
- **lottie, confetti, intl** — UI polish/date format. (`google_fonts`, `flutter_animate`, `uuid`, `path_provider`, `shared_preferences`, `permission_handler`, `google_mlkit_commons` are declared but **unused** — dependency bloat/attack surface.)
- **Kotlin `MediaMetadataRetriever`** — native frame extraction because ML Kit consumes images not video. Alt: `video_thumbnail`/`ffmpeg_kit` plugin (cross-platform), `video_player` texture capture (older approach in `Ml.md`).
- **Android Gradle Kotlin DSL** — default Flutter scaffold; release signed with debug key.
- **Testing tools**: `flutter_test` only, default test broken.
- **Docker / cloud / CI**: none present. **Vector DB / LLM provider / embeddings**: none present.
