# 15 — Defend Your Project (hostile questions, StepSure-specific)

Approach: concede the true weakness in one sentence, then show you know the fix. Never bluff.

1. **"Why this architecture — a fat client and no backend?"** Speed, privacy of inference, zero inference cost. I accept that business logic lives on an untrusted client; for anything a clinician relies on I'd move scoring into a Postgres function/edge function.
2. **"Why didn't you use MediaPipe/TFLite directly?"** ML Kit gave a maintained Flutter plugin in hours. MediaPipe would give world (3-D) landmarks and tuning, and is what I'd move to for real stride length.
3. **"Why Supabase not Firebase?"** Relational data (sessions↔reports join), RLS in SQL, open source. Firebase would give better offline sync.
4. **"Why this ML model / how do you know it's good?"** I didn't train one. The pose model is pre-trained; my metrics are unvalidated heuristics. Validation plan: simultaneous capture with a gait mat/IMU, MAE on step count, Bland–Altman on cadence, ICC test-retest, AUC vs TUG/Berg for fall risk.
5. **"Why should I believe your recovery score?"** You shouldn't yet as a clinical measure; it's a consistent *relative* indicator only if capture conditions are constant. Weights are judgement; I'd calibrate against clinician-rated recovery.
6. **"What happens when the model fails?"** Upload: <5 poses ⇒ error message. Live: no guard ⇒ zero metrics get saved as score 20/moderate — a bug I'd fix with minimum pose count/duration and a retry prompt.
7. **"Your README says Gemini and an exercise library. Where is it?"** Not implemented; README was aspirational. Current reports are template-based (`ReportGenerator`). I'd correct the README rather than defend it.
8. **"Your README says 100% on-device."** Inference is on-device; storage isn't — videos and metrics go to Supabase. I'd reword or make upload opt-in.
9. **"What's your biggest bottleneck?"** Per device: ML inference + UI-thread conversions; per system at scale: video storage/egress cost.
10. **"How would you scale to 100k users?"** Inference cost doesn't scale (on-device). Scale DB with indexes/aggregates, drop raw video by default (store features), signed URLs/CDN, server-side scoring, queue for reports.
11. **"What would you change with another month?"** (1) timestamped frames + startSession fix + tests, (2) proper gait-event detection & smoothing, (3) validation study, (4) private storage + committed RLS migrations, (5) iOS parity, (6) wire reminders.
12. **"Weakest part of your implementation?"** The gait metrics' scientific validity and the two timing bugs (live cadence 0; video wall-clock).
13. **"Tell me about a bug you hit."** Cadence inflated 10–30× because every frame above 160° counted as a step; fixed with a per-leg rising-edge state machine with 20° hysteresis (`Ml.md`). Then be ready to admit the remaining live cadence bug found later in review.
14. **"Hardest technical problem?"** Getting ML Kit landmarks to line up with the camera preview: NV21 plane concatenation, sensor rotation, coordinate spaces, mirroring (`recording_screen.dart`, `skeleton_painter.dart`).
15. **"What if I feed adversarial/invalid input?"** Blank wall, a mannequin, a person standing still: standing still scores ≈79 (straight knees ⇒ high symmetry; consistency defaults to 100). There's no "is this person walking?" gate. Forged API writes are possible because the client inserts scores.
16. **"How would you deploy to production?"** Real keystore + upload key, `--dart-define` config, INTERNET permission, CI (analyze, test, build), Sentry/Crashlytics, staged Play track, separate Supabase envs with migrations and RLS tests.
17. **"How would you reduce cost?"** Don't store raw video / compress and TTL it; aggregate SQL instead of downloading all sessions; avoid LLM or cache per session.
18. **"How would you monitor it?"** Crash reporting, event metrics (pose-detect rate, analysis duration, failures by device), Supabase logs, alert on error rates.
19. **"Is this a medical device?"** Potentially (software as a medical device) if it claims diagnosis/fall-risk. Needs disclaimer, wellness framing, or regulatory pathway (CDSCO/FDA). Currently no disclaimer.
20. **"Why is symmetry 40% of your score?"** Hemiparetic gait is asymmetric, so it's the most face-valid component — but my instantaneous-knee-angle definition is a weak proxy; a step-time/length ratio is the right one.
21. **"Your tests?"** None working; the one template test doesn't compile. I'd start with pure-Dart tests for angle math, step detection with an injected clock, and score edges.
22. **"Why 50 frames?"** Bounded compute; but it's the wrong design: sample at a fixed Hz (≥10) so sampling rate is independent of video length.
23. **"Why is your privacy story consistent with public video URLs?"** It isn't; that's fix #1 on security.
24. **"Explain `getLastSession` returning index 1."** Because the current session was inserted first; brittle; use `session_date < current`.
25. **"Why keep Provider?"** Leftover scaffolding; only `AuthProvider` exists and it's bypassed. I'd either adopt it properly or remove it.
26. **"What did you personally write vs generate?"** Answer truthfully and be able to derive every formula in `angle_calculator.dart` and every threshold in `score_calculator.dart` on a whiteboard.
27. **"Would a physiotherapist accept the exercise advice?"** Text is generic (e.g., "single-leg stance 30 s each side"); needs clinician review & safety screening; high-risk users should be told to consult, not to exercise more.
