# 11 — Performance & Scalability

## Complexity of key operations
| Operation | Time | Space | Note |
|---|---|---|---|
| `processFrame` | O(1) angle math + O(k) `_computeConsistency` where k = #intervals (recomputed **every frame**: 2 passes) | O(frames) lists grow unbounded (4 lists) | at 15–30 fps for 30–60 s ⇒ ≤ ~2k entries: trivial |
| `computeSessionMetrics` | O(n) | O(k) copy | |
| Upload analysis | 50 × (ML Kit `accurate` single-image ≈ 100s ms) | 50 JPEG byte arrays in one channel message (≈ 3–8 MB) + temp files | analysis ≈ 5–20 s (⚠️ VERIFY on device) |
| Progress/Home queries | index scan if `(user_id, session_date)` index exists | 30 rows | |
| Profile stats | O(N sessions) download | O(N) | grows with usage |
| `setState` per frame in recording | rebuilds `RecordingScreen` subtree ~ camera fps | — | can jank; use `ValueNotifier`/`CustomPaint` repaint listenable |

## Client (phone) bottlenecks
1. **ML Kit inference** per frame (base model ~ real-time on mid phones; `_isProcessing` drops frames ⇒ effective fps lower and irregular).
2. **Main-thread work**: NV21 plane concatenation via `WriteBuffer` on the Dart UI isolate per frame; Kotlin frame extraction on the platform main thread (ANR risk).
3. **Memory**: 720×405 JPEG copies; all frames in memory before writing.
4. **Battery/thermal**: continuous camera + ML + TTS.
5. **Screens**: 700–1500 line widget files, multiple always-running `AnimationController`s (`_particleController.repeat()` in Results, pulse/shimmer in Upload).

## Backend/network
- Each session end: 3–5 sequential round trips (insert, [upload + update], select, insert) ⇒ latency = sum; the user waits. Video upload of tens of MB over mobile data dominates and has no progress, retry, resumable upload or timeout.
- No caching (no `local_storage`, no `shared_preferences` use); every tab open re-queries. No offline mode though README says "no internet needed during analysis" (true only for capture/analysis; **saving requires network and failure isn't handled**).
- Costs: Supabase storage + egress for videos (biggest cost driver); no LLM cost; no model hosting cost.

## Scalability answers
**10 users**: everything works on free tier; only bugs matter.
**1,000 users**: DB fine (small rows; ensure indexes `(user_id, session_date desc)` on sessions, `(user_id, generated_at desc)` on reports). Storage grows: 1,000 users × several videos × 20–100 MB ⇒ tens–hundreds GB; free/pro tier limits and egress become the cost. Profile-stats query still ok. Need: private bucket lifecycle rules, compress video on-device before upload.
**100,000 users**: PostgREST/Supabase compute needs sizing (connection pooling handled by supavisor); per-user heavy reads (`profile_screen` reading all sessions) → replace with SQL aggregates/materialised view; reports table growth ⇒ partition/archival; video storage/egress dominates ⇒ don't store raw video by default (store landmarks/time series ~KBs), CDN/signed URLs, background upload queue. Because inference is on-device, **compute cost does not scale with users** — the best scaling property of the design. Auth: email rate limits/SMTP provider. Observability (Sentry/Crashlytics), remote config for thresholds, and server-side scoring (edge function) for consistency across app versions.

## Quick wins
Fixed-Hz sampling with real timestamps; move NV21 conversion & JPEG decode to isolates; throttle `setState` to ≤10 Hz; replace profile stats with `select count, avg`; add `try/catch` + local pending-queue (retry) for saves; compress video (e.g., 720p H.264) before upload; index columns.
