# 09 — Design Decisions & Trade-offs

For each: Decision · Why it makes sense · Alternative · Trade-off · When alternative wins.

1. **On-device pose inference** — privacy, zero server cost, works offline for capture; alt: server inference (higher accuracy/consistency, central model updates); trade: device variance, battery/heat; alt wins when accuracy/regulatory auditability matter.
2. **BaaS (Supabase) instead of own backend** — fastest path for auth/DB/storage; alt: FastAPI/Node; trade: no server-side validation/anti-tamper, RLS complexity; alt wins when scores are clinician-trusted or you need transactions/jobs/LLM keys.
3. **Rule-based metrics & scoring** — explainable, no data needed; alt: learned models validated on clinical data; trade: arbitrary weights/thresholds; alt wins once ground-truth data exists.
4. **Hysteresis state machine for steps** — kills repeated counts; alt: peak detection on smoothed ankle-y/knee signal (Savitzky–Golay + `find_peaks`); trade: fixed 140/160° ill-suited to stroke gait; alt wins for stiff-knee gait.
5. **Two detector configs (stream/base live, single/accurate offline)** — speed vs accuracy per use-case; sound.
6. **Frame dropping under load (`_processingFrame`, `_isProcessing`)** — bounded latency; trade: irregular sampling ⇒ needs real timestamps (not used) — questionable given cadence relies on wall clock.
7. **Wall-clock timing (`DateTime.now()`)** — simplest; ✗ questionable: breaks offline analysis, sensitive to jank; use camera/frame timestamps.
8. **Sampling exactly 50 frames regardless of duration** — bounded compute/memory; ✗ wrong for gait (sample rate must be fixed in Hz: ≥10–15 fps to see steps).
9. **Store derived metrics only** — small & private; trade: can't recompute, can't audit.
10. **Client computes score & inserts** — simple; trade: forgeable; alt: Postgres function/edge function computing from raw features.
11. **Template report instead of LLM** — safe, deterministic, free; README oversells it. Alt: LLM for narrative only, with template fallback.
12. **Flat `sessions` table** — simple charts; alt: `gait_metrics` split table as in README (cleaner separation of recording vs metrics).
13. **Screens talk to Supabase directly** — fast; ✗ breaks the presented clean-architecture story; repository layer exists (`SupabaseService`) but is bypassed.
14. **Provider present but unused** — accretion, not design.
15. **Public video URLs** — ✗ questionable for health data; use private bucket + signed URLs (short expiry).
16. **Two ingestion modes** — live gives feedback; upload lets users use pre-recorded clips; upload path is Android-only.
17. **TTS with per-key cooldown** — prevents audio spam; ✗ cues evaluated per frame with noisy metrics; consider windowed (e.g. 3 s median) decisions.
18. **Custom `_mySqrt`/extension** — unnecessary; `dart:math` exists (dup ×2).

## Questionable / improvable (be candid)
Fake stride length; double-counted variability; default "100" consistency; no guard for empty live sessions; no error handling on network writes; no tests; no CI; README/docs drift; debug-signed release; hardcoded config (`--dart-define` better); no data-deletion path; UI files of 700–1500 lines with logic mixed in.
