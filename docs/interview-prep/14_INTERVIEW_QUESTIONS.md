# 14 — Interview Question Bank (StepSure-specific)

Format per question: **Q** → *Testing* → **Strong answer** → *Files* → *Follow-up* ⇒ how to answer it.
Honesty rule: never claim the LLM/Gemini/exercise-engine/clinician features; they don't exist in the code.

---
## A. 30-second explanation
**A1. What is your project?** *Testing:* clarity, honesty. **A:** "A Flutter app that uses on-device pose estimation to derive gait metrics from a phone camera for stroke rehab, scores recovery and fall risk with rule-based logic, and stores history/reports in Supabase." *Files:* `main.dart`, `gait_analysis_service.dart`. *Follow-up:* "Is it AI?" ⇒ "The pose model is pre-trained ML Kit; the metrics and scoring are my own deterministic heuristics."
**A2. What problem does it solve?** *Testing:* product sense. **A:** Between-clinic monitoring: patients rarely get physio; app gives objective, repeatable numbers and feedback. *Follow-up:* "Is it clinically validated?" ⇒ "No; validating against a gait mat/IMU is the next step."
**A3. What was your contribution?** *Testing:* ownership. **A:** Be specific & true: the domain layer (angles, step state machine, scoring, feedback), camera→ML Kit integration (NV21/BGRA conversion, skeleton painter), Supabase integration, Android frame-extraction channel, UI. (Adjust to what *you* actually wrote — ⚠️ VERIFY with your git history: `git log --author`.) *Follow-up:* "What did you copy?" ⇒ be candid about AI-assisted/UI scaffolding.

---
## B. Architecture (15)
**B1. Walk me through the architecture.** *T:* system view. **A:** Flutter client (presentation/domain/data) → ML Kit on device → Supabase (Auth/Postgres/Storage). No own server. *Files:* `01_ARCHITECTURE.md`. *FU:* "Where does business logic live?" ⇒ client `domain/`.
**B2. Why no backend?** **A:** BaaS speed; inference on device; cost. Trade-off: no server validation, secrets, jobs. *FU:* "What would force you to add one?" ⇒ trusted scores, LLM key, clinician portal, notifications, transactions.
**B3. Why on-device inference?** **A:** privacy, latency, offline capture, zero inference cost. *FU:* "But you upload videos?" ⇒ "Yes in upload mode — contradicts the privacy claim; I'd make it opt-in/private bucket or drop it."
**B4. Why Flutter?** **A:** single codebase, custom painting for overlays. *FU:* "Cost?" ⇒ platform channel for frame extraction; camera stream overhead.
**B5. How are layers separated?** **A:** `presentation/domain/data/core`; domain has pure Dart rules. Honest: screens bypass the data layer and call Supabase. *Files:* `home_screen.dart`, `profile_screen.dart`. *FU:* "Fix?" ⇒ repositories + Provider/Riverpod, DI.
**B6. Explain the two ingestion paths and why they differ.** *A:* table in `01`. *FU:* "Why single mode for upload?" ⇒ frames non-sequential; stream mode assumes continuity.
**B7. How does state flow?** **A:** `setState` inside screens; `AuthProvider` (mostly unused); Supabase stream for auth. *FU:* "Why Provider at all?" ⇒ scaffolding; candid.
**B8. What is the auth gate?** **A:** `AuthGate` StreamBuilder on `onAuthStateChange` reading `currentSession`. *FU:* "Why ignore snapshot?" ⇒ works because any auth event triggers rebuild, but `snapshot.data?.session` is cleaner.
**B9. How would you add iOS video upload?** **A:** implement `video_frame_extractor` with `AVAssetImageGenerator` in Swift, or use a cross-platform plugin; also pass frame timestamps. *Files:* `MainActivity.kt`, `AppDelegate.swift`.
**B10. How do you keep the UI responsive during ML?** **A:** drop frames while busy; ML Kit runs natively async; but NV21 concat and `setState` per frame still on UI isolate. *FU:* "Improvement?" ⇒ isolates, throttle setState, `ValueNotifier`.
**B11. What is your deployment story?** **A:** none yet: debug-signed, no CI, `com.example` id; plan: Fastlane/GitHub Actions, Play internal testing, separate Supabase projects.
**B12. What are the trust boundaries?** **A:** device (untrusted) ↔ Supabase (RLS). Client computes scores ⇒ forgeable.
**B13. Where would an LLM fit?** **A:** only narrative generation behind an edge function, input = derived metrics JSON, output schema-validated, fallback to `ReportGenerator`.
**B14. What if Supabase is down?** **A:** capture/analysis works; saving fails (unhandled) — need local queue (`local_storage.dart` is empty placeholder). 
**B15. What would you refactor first?** **A:** fix C1/C2 bugs, add tests, timestamped frames, repository layer, server-side scoring, RLS migrations.

---
## C. Backend / domain logic (15)
**C1. Explain step detection.** *T:* algorithm depth. **A:** per-leg state machine; knee >160° fires once and sets `extended`; re-arm when <140°; hysteresis stops repeats; interval filter 0.3–3 s. *Files:* `gait_analysis_service.dart:processFrame,_recordStep`. *FU:* "Why 160/140?" ⇒ heuristic, not tuned; stiff-knee gait breaks it; better: peak detection on smoothed signal.
**C2. How is cadence computed?** **A:** steps/elapsed·60 with steps counted from valid intervals. *FU:* "Bugs?" ⇒ live: `startSession` missing ⇒ 0; video: wall-clock.
**C3. Derive the joint-angle formula.** **A:** vectors BA, BC; cosθ = BA·BC/(|BA||BC|); clamp; acos→deg. *FU:* "Why clamp?" ⇒ float error can push |cos|>1 ⇒ NaN.
**C4. What is your symmetry metric and is it valid?** **A:** per-frame `100−|L−R|/avg·100` of knee angles, averaged. Not valid clinically: legs are out of phase; need step-time/length symmetry ratio per gait cycle. *FU:* "Better?" ⇒ SI = |L−R|/(0.5(L+R)) on step lengths/stance times.
**C5. How is the recovery score built?** **A:** weights .4/.2/.2/.2, normalisations. *Files:* `score_calculator.dart`. *FU:* "Why those weights?" ⇒ judgement; would fit/validate vs clinical outcomes.
**C6. How is fall risk determined?** **A:** points from stride CV, symmetry, consistency. *FU:* "Flaw?" ⇒ CV double-counted; not validated; use TUG/Berg-linked model.
**C7. What does `getLastSession` do and why index 1?** **A:** fetch 2 newest after inserting the current one ⇒ [1] is previous. *FU:* "Race?" ⇒ concurrent inserts break it; store `previous_session_id` or query `session_date < current`.
**C8. How is the report generated?** **A:** deterministic thresholds/templates. *FU:* "README says Gemini" ⇒ "README is aspirational/stale."
**C9. How does TTS avoid spamming?** **A:** per-key cooldown map 6 s. *FU:* "Why per key?" ⇒ different cues can interleave but each repeats slowly.
**C10. What happens on zero detected poses live?** **A:** metrics default to 0 ⇒ score 20/"moderate" saved (bug H1). *FU:* "Fix" ⇒ min-pose/duration guard + retry prompt.
**C11. Why custom `_mySqrt`?** **A:** no good reason; `dart:math.sqrt`. Duplicate in two files. *FU:* "Does Newton converge?" ⇒ yes for x>0; pointless.
**C12. Explain consistency metric.** **A:** `100−CV%` of step intervals; <3 intervals ⇒ 100. *FU:* "Problem?" ⇒ optimistic default; CV≠percent-of-100 scale.
**C13. How is joint deviation computed?** **A:** mean knee angle vs 120–170° range, percent outside, averaged L/R. *FU:* "Flaw?" ⇒ mean over cycle hides ROM; use peak flexion in swing & extension in stance.
**C14. Why is stride length wrong?** **A:** `cadence·0.0028`; no geometry; should use hip/ankle displacement scaled by body height/known calibration.
**C15. How would you unit-test `GaitAnalysisService`?** **A:** inject clock/timestamps, synthetic knee-angle sequence via fake `Pose`/refactor `processFrame` to accept angles.

---
## D. Frontend (15)
**D1. How does the live camera → ML Kit path work?** **A:** `startImageStream` callback → `InputImage.fromBytes` (BGRA on iOS; concatenated planes NV21 on Android; rotation from `sensorOrientation`) → `PoseService`. *Files:* `recording_screen.dart:_inputImageFromCamera`. *FU:* "Why concatenate planes?" ⇒ NV21 = Y plane followed by interleaved VU; ML Kit expects a single byte array.
**D2. How is the skeleton drawn?** **A:** `CustomPainter` scales landmark coords (already in rotated space) proportionally to screen; mirrors x for front cam; confidence threshold 0.4. *FU:* "What if preview is letterboxed?" ⇒ overlay misaligns; need FittedBox/`BoxFit.cover` math.
**D3. Why drop frames?** **A:** avoid queue build-up/latency. *FU:* "Downside?" ⇒ variable sample rate ⇒ need timestamps.
**D4. `setState` on every frame — issue?** **A:** rebuilds entire screen; use `ValueListenable`/`RepaintBoundary`.
**D5. How do you handle camera lifecycle?** **A:** init in `initState`, dispose in `dispose`; gaps: no `didChangeAppLifecycleState`, `_switchCamera` races.
**D6. Navigation structure?** **A:** imperative `Navigator.push/pushReplacement`; Home with 4-tab bottom nav (`_pages` list); no named routes/`go_router`. *FU:* "State kept across tabs?" ⇒ `HomeScreen` uses `IndexedStack`, so tabs stay alive and each loads data once in `initState` ⇒ after a new session the Home/Progress/Reports tabs show **stale data** until app restart (no refresh on return). Fix: refresh on tab select / `await Navigator.push` then reload, or a shared session notifier.
**D7. How do you show progress in upload?** **A:** callback `onProgress` → clamp 0.99 → 4 cosmetic steps via `_updateStep`.
**D8. Why file_picker on iOS?** **A:** code comment: bypass PHPicker issues; `image_picker` elsewhere.
**D9. Where does UI code hurt maintainability?** **A:** 700–1500 line screens; extract widgets, view-models.
**D10. Design system?** **A:** two (`AppColors/AppText/app_theme` and `design_systems.dart`) — accreted; unify.
**D11. How do animations work at results?** **A:** 4 `AnimationController`s; `_particleController.repeat()` never stops ⇒ constant repaint (battery).
**D12. Error UX?** **A:** SnackBars for auth; error card in upload; silent `catch (_)` elsewhere.
**D13. Accessibility?** **A:** TTS cues help; but no semantics labels checked ⚠️ VERIFY; colour-only risk badges.
**D14. How would you test the UI?** **A:** widget tests with fake data maps; golden tests; integration with mocked Supabase.
**D15. Form validation?** **A:** `Form` + validators (email `@`, pw ≥6, confirm match, age 1–120). *FU:* "Weak?" ⇒ yes, rely on server rules too.

---
## E. Database (15)
**E1. What tables exist?** **A:** profiles, sessions, reports (+storage bucket) — inferred, no migrations in repo ⚠️. *Files:* `06`.
**E2. Why flat sessions?** **A:** cheap charts; trade: no raw data.
**E3. Relationship between reports and sessions?** **A:** FK `session_id`; embedded join in `reports_list_screen`.
**E4. What indexes do you need?** **A:** `(user_id, session_date desc)`, `(user_id, generated_at desc)`.
**E5. How is data isolated per user?** **A:** RLS `auth.uid()=user_id` (claimed; show policies). *FU:* "Show me." ⇒ "Not committed — first fix."
**E6. Is saving a session atomic?** **A:** No: multiple calls; fix via RPC/edge function.
**E7. What's the N+1 risk?** **A:** none in reports (embedded select); profile stats O(N) transfer.
**E8. `single()` vs `maybeSingle()`?** **A:** `single` throws on 0/≥2 rows (used in `saveSession` after insert, `AuthProvider.getProfile`); `maybeSingle` returns null.
**E9. How is "previous session" queried?** see C7.
**E10. Timestamps?** **A:** ISO local without offset ⇒ prefer UTC `timestamptz`.
**E11. What's stored for arrays?** **A:** `List<String>` ⇒ `text[]`/`jsonb`.
**E12. Migration strategy?** **A:** none; use Supabase CLI migrations in git.
**E13. Delete/GDPR?** **A:** none; need cascade delete + storage cleanup.
**E14. Would you use a local DB?** **A:** yes—`drift`/sqlite queue for offline saves; README "offline caching" isn't implemented.
**E15. Why not store landmarks?** **A:** privacy/size trade-off vs recomputability; store downsampled features.

---
## F. APIs (10)
**F1. What APIs did you build?** *T:* honesty. **A:** none; used Supabase PostgREST/Auth/Storage + one native MethodChannel.
**F2. Describe the MethodChannel contract.** **A:** `extractFrames{videoPath,fps,width,height,count}` → `List<bytes>`; see `05`.
**F3. Why a channel and not a plugin?** **A:** quick custom need; downside Android only.
**F4. How do you authenticate requests?** **A:** SDK attaches JWT; anon key identifies project.
**F5. How do you version/handle schema drift?** **A:** don't; map keys hardcoded in 6 places.
**F6. Error handling for API calls?** **A:** minimal; see C-level.
**F7. Idempotency of save?** **A:** none; retries duplicate.
**F8. Pagination?** **A:** `limit(30)` only; reports unpaginated.
**F9. Rate limiting?** **A:** Supabase-side only.
**F10. How would you design a server endpoint for scoring?** **A:** `POST /sessions` with features + idempotency key; server recomputes score, validates ranges, writes session+report in a txn.

---
## G. AI/ML (20)
**G1. What model do you use and where does it run?** ML Kit pose, on-device. *FU:* "Did you train it?" ⇒ No.
**G2. Live vs offline configs?** stream/base vs single/accurate; why.
**G3. What are the 33 landmarks, and which do you use?** hips, knees, ankles, shoulders (+ painter uses more). Hip angle computed but unused.
**G4. What do `likelihood` and `z` mean and do you use them?** in-frame likelihood; only painter uses likelihood; z ignored ⇒ improvement.
**G5. How do you know your metrics are accurate?** They're unvalidated; plan: ground-truth study, MAE/Bland–Altman/ICC.
**G6. Why is 2-D knee angle problematic?** projection error; camera plane; straight-on view underestimates flexion.
**G7. Camera placement assumptions?** side view for knee/hip; frontal for trunk/symmetry — the code doesn't enforce/detect view.
**G8. Explain the recovery score's assumptions.** weights arbitrary; cadence normal 100.
**G9. Why is hysteresis needed?** noise around threshold ⇒ multiple counts.
**G10. What about noise/smoothing?** none; add EMA/median/Savitzky–Golay; gate by likelihood.
**G11. What sampling rate is needed to detect steps?** ≥ ~10–15 Hz (Nyquist for ~2 Hz cadence with margin); upload uses ~1.7–5 Hz ⇒ under-sampled.
**G12. Why is cadence wrong for uploaded video?** wall-clock vs video timeline (C2).
**G13. What is your evaluation set?** none.
**G14. How would you validate fall-risk?** compare vs TUG/Berg/fall history; ROC/AUC, sensitivity ≥ specificity for screening; calibration.
**G15. Bias/fairness?** pose models degrade with clothing, skin tone/lighting, body types, assistive devices, atypical gait.
**G16. What's deterministic vs learned here?** only landmarks learned.
**G17. Is there an LLM/RAG?** No. (README claim is false.)
**G18. Failure cases?** see `07 §7`.
**G19. How would you use z / 3-D?** MediaPipe world landmarks, or calibrate with known height.
**G20. How to detect gait events properly?** heel/ankle vertical velocity zero-crossings, foot-strike = local min of ankle-y; peak detection with min distance; per-leg stance/swing times.
**G21. How would you personalise thresholds?** baseline session per patient; z-score vs own history; affected-side awareness (profile stores `affected_side` but it is only displayed in the profile screen; analysis never uses it).
**G22. Would you run a bigger model server-side?** for accuracy/uniformity; costs & privacy.

---
## H. Security (10)
**H1. Is the hardcoded Supabase key a vulnerability?** anon key public by design; risk is RLS gaps; move to dart-define.
**H2. How do you prevent cross-user access?** RLS + storage policies (unverified).
**H3. Public bucket?** health video exposure; use signed URLs.
**H4. Can a user forge scores?** yes; server-side scoring.
**H5. Password handling?** Supabase GoTrue; app trims, min 6.
**H6. What about PII/PHI?** age, stroke date, video, health metrics ⇒ consent, retention, deletion.
**H7. Injection risks?** none; parameterised PostgREST.
**H8. Release hardening?** debug key, obfuscation, no INTERNET perm.
**H9. Logging leakage?** debugPrint of session/report maps.
**H10. Threat model?** stolen phone (session persisted), curious insider, URL leakage, scripted abuse of anon key (storage cost).

---
## I. Scalability / system design (15)
**I1. 10/1k/100k users?** see `11`.
**I2. Biggest cost?** video storage/egress.
**I3. Biggest bottleneck per device?** ML inference & UI-thread conversions.
**I4. Redesign for clinicians?** roles, RLS with care-team table, dashboard web app, aggregated views.
**I5. Offline-first?** local queue (drift), sync worker, conflict-free since append-only sessions.
**I6. Real-time clinician monitoring?** Supabase Realtime on sessions.
**I7. Multi-device sync?** already via Supabase; "previous session" logic needs ordering by time.
**I8. Reminders at scale?** FCM + scheduled edge function vs local notifications (currently unwired).
**I9. Add LLM reports at 100k users?** cost per report, cache by session, queue, rate limits.
**I10. Feature flags/remote thresholds?** remote config so scoring versions can change (`score_version` column).
**I11. Versioning scores?** store `algo_version` + features to recompute.
**I12. Observability?** Sentry, analytics on failures (`No pose`), backend metrics.
**I13. Data retention?** delete videos after N days, keep features.
**I14. Multi-region/latency?** Supabase region near users (India).
**I15. Cross-platform parity plan?** shared pure-Dart core, per-platform video decoder plugin.

---
## J. Debugging (10)
**J1. Cadence is 0 in live mode — how do you debug?** trace `_sessionStart`; grep `startSession`; add unit test.
**J2. Skeleton misaligned?** check rotation, raw vs effective size, mirror, preview aspect.
**J3. Score suspiciously high when standing?** compute example (≈79); missing "walking" detector.
**J4. Upload works on Android but errors on iOS?** MissingPluginException path.
**J5. App crashes after signup?** `currentUser!` with email confirmation.
**J6. No poses detected?** InputImage format/rotation mismatch, lighting; log `_errorLogs`.
**J7. Report improvement shows NaN?** previous score 0.
**J8. Release build can't log in?** INTERNET permission.
**J9. Duplicate sessions?** double tap on stop; no guard.
**J10. Test suite won't compile?** package/name mismatch in `test/widget_test.dart`.

---
## K. Behavioral / ownership (10)
**K1. Hardest technical problem?** camera-frame → ML Kit format/rotation & skeleton alignment (documented in `Ml.md`), or step detection inflating cadence 10–30× (fixed with hysteresis).
**K2. A bug you found?** hysteresis fix; or (now) startSession omission.
**K3. What would you do with another month?** validation study, tests, timestamps, server scoring, iOS.
**K4. Weakest part?** unvalidated metrics + docs drift.
**K5. How did you decide priorities?** demo path first (record→score→report).
**K6. Trade-off you regret?** README claims ahead of implementation.
**K7. How did you use AI tools?** be honest; explain you can defend each formula.
**K8. Feedback you'd expect from a clinician?** thresholds, safety, view placement.
**K9. How do you ensure patient safety?** disclaimers, conservative messaging, not diagnosing.
**K10. What did you learn?** platform channels, ML Kit specifics, RLS thinking, validating heuristics.
