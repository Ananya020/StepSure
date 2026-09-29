# 16 — INTERVIEW CHEAT SHEET (15–20 min)

**1. Pitch:** Flutter app: phone camera → on-device ML Kit pose → my rule-based gait metrics → weighted recovery score + fall-risk → Supabase history, template reports, PDF.
**2. Problem:** stroke patients lack between-visit gait monitoring.
**3. Architecture:** presentation/domain/data layers → ML Kit (device) → Supabase (Auth, Postgres `profiles/sessions/reports`, Storage `session-videos`). No own server, no LLM.
**4. Stack:** Flutter/Dart, google_mlkit_pose_detection, camera, video_player, supabase_flutter, provider (light), fl_chart, flutter_tts, pdf/printing, lottie; Kotlin MethodChannel.
**5. Contribution:** (state yours) — domain metrics + camera/ML integration + Supabase + UI.
**6. Top 5 decisions:** on-device inference · BaaS not server · rule-based explainable scoring · hysteresis step detector · two detector modes (stream/base vs single/accurate).
**7. Hardest challenges:** camera→InputImage format/rotation & skeleton alignment · inflated cadence (hysteresis fix) · video → frames for an image-only model (native extractor) · iOS/Android divergence · keeping UI smooth with per-frame ML.
**8. Algorithms:** 2-D joint angle via dot product; symmetry `100−|L−R|/avg·100`; step state machine (>160 fire, <140 re-arm, 0.3–3 s); cadence = steps/s·60; consistency = 100−CV; joint deviation vs 120–170°; score `.4S+.2C+.2Cons+.2(100−Dev)`; risk points (CV, symmetry, consistency) ≥4 high ≥2 moderate.
**9. "APIs":** Supabase `sessions` insert/select, `reports` insert/select(+embedded sessions), `profiles` upsert/update, Storage upload/getPublicUrl, Auth email/password; native `video_frame_extractor.extractFrames`.
**10. DB:** profiles(id, full_name, age, stroke_date, affected_side, reminder_*) · sessions(id,user_id,session_date,duration_seconds,recovery_score,fall_risk,stride_length,cadence,symmetry,stride_consistency,joint_deviation,video_url) · reports(id,session_id,user_id,summary,abnormalities,exercise_suggestions,risk_assessment,improvement_percentage,generated_at). ⚠️ inferred; no migrations in repo.
**11. ML pipeline:** frame → ML Kit 33 landmarks → angles → step events → aggregates → score → template report. Pre-trained model only; no training/eval.
**12. Performance:** no measured numbers in repo (don't invent). Upload analysis = 50 frames. Inference cost is on-device. Cost driver = video storage.
**13. Known limitations:** live cadence = 0 (startSession missing) · video cadence uses wall clock · fake stride length · unvalidated thresholds/no disclaimer · no tests · Android-only upload · reminders unwired · stale tabs · README overclaims.
**14. Security:** anon key hardcoded (OK only with RLS) · RLS/policies not in repo · public video URLs · client-forgeable scores · debug-signed release · no consent/deletion.
**15. Scalability:** stateless clients, BaaS; fix aggregates/indexes; drop raw video; server-side scoring.
**16. Future:** timestamped frames, smoothing, heel-strike detection, 3-D landmarks, validation study, private storage + RLS migrations, iOS extractor, FCM reminders, optional server-side LLM narrative.

**17. Top 20 likely questions:** (1) architecture walk-through (2) why on-device (3) why Supabase (4) did you train a model (5) explain step detection (6) explain score weights (7) how validated (8) fall-risk logic (9) camera→ML Kit conversion (10) skeleton overlay math (11) live vs upload differences (12) what if no pose (13) security of health data/RLS (14) public bucket (15) offline support (16) scale to 100k (17) biggest bug (18) tests (19) what would you change (20) README says Gemini?

**18. Terminology:** pose estimation, landmark, BlazePose, likelihood, NV21/YUV_420_888/BGRA8888, sensor orientation, hysteresis, cadence (steps/min), stride vs step, symmetry index, coefficient of variation (CV), gait cycle (stance/swing), heel strike, hemiparesis, TUG/Berg, RLS, anon key vs service key, PostgREST, MethodChannel, isolate, backpressure, Bland–Altman, ICC, SaMD.
