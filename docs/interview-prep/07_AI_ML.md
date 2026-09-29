# 07 — AI / ML Deep Dive

## 0. Reality check (read first)
| Claimed (README) | Actual (code) |
|---|---|
| "AI exercise prescription", "Gemini-powered reports" | **No LLM.** `ReportGenerator` = if/else + string templates |
| "7 deficit classifications" | 4 abnormality rules in `ReportGenerator` + 5 real-time cue rules in `FeedbackEngine`; no heel-strike, no stride-length geometry, no hip-flexion check |
| "Heel strike detection (ankle vertical minima), stride length from hip-ankle geometry" | Steps from **knee-angle hysteresis**; stride length = `cadence·0.0028` (fake) |
| "Fall risk from stride CV" | CV **+ symmetry + consistency** points (CV counted twice) |
| "Camera confidence scoring prompts re-record" | Only `<5 poses` guard in upload mode; likelihood ignored in metrics |
| "100% on-device" | Pose inference is on-device; **results (and uploaded videos) go to Supabase** |
| "Train/validation/test, metrics" | **No dataset, no training, no evaluation** anywhere in the repo |
Do not describe this as "my ML model". Correct framing: *pre-trained pose estimation + hand-engineered biomechanical features + rule-based scoring*.

## 1. Pipeline (actual)
```
Input: camera frame (live) OR JPEG frame (upload)
→ preprocessing: NV21/BGRA → InputImage (+rotation)   |  file → InputImage.fromFilePath (720×405 forced)
→ model: ML Kit Pose (BlazePose-based; stream+base live, single+accurate offline) → 33 landmarks (x,y,z,likelihood) in image px
→ feature extraction (deterministic): 2-D joint angles (knee, hip), trunk lean
→ event detection: per-leg knee-extension rising edge with hysteresis → step timestamps
→ aggregates: mean angles, mean per-frame symmetry, cadence, CV of step intervals, joint deviation from 120–170°
→ scoring: weighted sum → recovery score; points rule → fall risk
→ report: template strings (ReportGenerator); live: TTS rules (FeedbackEngine)
→ storage: Supabase sessions/reports → UI (Results, Progress chart, PDF)
```
Deterministic vs "AI": only the landmark step is a learned model. Everything else is deterministic application logic. No retrieval, embeddings, vector DB, prompting, or post-processing of model text exists.

## 2. Model: ML Kit Pose Detection
1. **What**: on-device human pose estimator (33 landmarks; BlazePose-derived — ⚠️ VERIFY exact backbone from Google docs, not in repo).
2. **Why here**: free, offline, no training data, runs real-time on phones.
3. **Input**: `InputImage` (bytes+rotation/format, or file). **Output**: `List<Pose>` each with `landmarks[type] → (x,y,z,likelihood)`.
4. **Hyperparameters used**: live `mode: stream, model: base`; offline `mode: single, model: accurate`. (Rationale in code comment: stream mode assumes temporal continuity; single is better for sparse frames.) Skeleton draw threshold likelihood 0.40 (only in painter).
5. **Assumptions**: one person, full body visible, reasonable light, camera roughly perpendicular to walking direction.
6. **Strengths**: fast, private, no infra. 7. **Weaknesses**: generic-population training, atypical/asymmetric post-stroke gait, aids (canes, walkers) & loose clothing, occlusion of the far leg in side view, left/right swaps, jitter (no smoothing), 2-D projection (angles depend on view), `z` unreliable.
8. **Alternatives**: MediaPipe BlazePose with world landmarks (3-D), MoveNet, OpenPose/HRNet server-side, IMU wearables, depth cameras, markerless mocap.
9. **Poor performance causes**: dark scenes, subject too small/large, only upper body in frame, multiple people (`poses.first`), 720×405 squashing of portrait video (aspect distortion changes angles!), fast camera motion.

## 3. Feature engineering (all in `angle_calculator.dart` / `gait_analysis_service.dart`)
| Feature | Formula | Concern |
|---|---|---|
| Knee angle | angle(hip,knee,ankle) 2-D | view-dependent; straight leg ≈ 180° |
| Hip angle | angle(shoulder,hip,knee) | computed but **never used** downstream |
| Trunk lean | `atan2(dx,−dy)` shoulder-mid vs hip-mid | only used for TTS cue |
| Symmetry | `100−|L−R|/avg·100` per frame, averaged | not a gait symmetry index; L/R knees are naturally out of phase during swing; mean over frames of an instantaneous difference is dominated by phase, not pathology |
| Steps | rising edge >160° / re-arm <140° | thresholds hand-picked; stiff-knee gait (common after stroke) may never cross them |
| Cadence | steps/elapsed·60 | live: **0 (bug)**; video: **processing-time based (bug)** |
| Consistency | `100−CV(step intervals)` | needs ≥3 intervals else 100 (optimistic) |
| Joint deviation | mean distance outside 120–170° | "normal" range not sourced; averages over gait cycle so a healthy swing/stance cycle already spans beyond this |
| Stride length | `cadence·0.0028` | not measured |

## 4. Scoring "algorithm"
`recovery = 0.40·symmetry + 0.20·min(cadence/100,1)·100 + 0.20·consistency + 0.20·(100−jointDev)`.
- Why 0.4 on symmetry: asymmetry is the hallmark of hemiparetic gait (rationale plausible, weights arbitrary).
- Cadence "normal" 100 spm with comment "for stroke patients"; healthy adults ≈100–120 — ⚠️ VERIFY source.
- **Fall risk**: `risk = f(CV>25/15, sym<40/60, consist<40/60)`, ≥4 high, ≥2 moderate. Not a validated fall-risk instrument; naming it "fall risk" in a health context is a liability.

## 5. Evaluation
**None.** No labelled data, ground-truth gait metrics, inter-rater or test-retest reliability, no unit tests. "How do you know it's good?" → honest answer: "I don't yet. Plan: record subjects on a GAITRite mat/IMU or manually annotated video, compare step counts (MAE), cadence (Bland-Altman), symmetry vs clinical index; measure test-retest ICC." Metrics you'd choose: step-count MAE, cadence error %, ICC for reliability, Bland–Altman limits, AUC/sensitivity for fall-risk vs Berg/TUG/history of falls.

## 6. Explainability
Fully explainable by construction (every number traces to a threshold), which is the main defensible strength of this design vs a black box.

## 7. Failure cases (concrete)
1. Live cadence 0 ⇒ score capped at 80, "walk faster" nag.
2. Video timing artefacts.
3. No pose ⇒ metrics = 0 defaults ⇒ score 20 "moderate" saved (live).
4. Stiff-knee gait ⇒ steps undercounted ⇒ cadence & consistency wrong.
5. Standing still with straight legs: knee >160 constant, no re-arm ⇒ 1 event, 0 steps (fine) — but symmetry ≈ high ⇒ **high score for not walking**.
6. Multiple people/picking `poses.first`.
7. Landmark with low likelihood still used ⇒ noisy angles.
8. Front camera mirroring irrelevant to angles but affects painter only.

## 8. Improvement roadmap (interview-ready)
Timestamped frames (`processFrame(pose, t)`); Butterworth/EMA smoothing; use `likelihood` gating; heel-strike from ankle/heel vertical trajectory + peak detection; 3-D/world landmarks or camera-calibration for real stride length; symmetry index from step-time/step-length L vs R (`SI = |L−R| / (0.5(L+R))`); per-leg gait-cycle normalisation; validate against ground truth; store raw time series for recomputation; real LLM (server-side edge function, PII-minimised, strict schema output, template fallback) only for *language*, never for the numbers.

## 9. If the interviewer asks "explain your LLM pipeline"
There isn't one — say so, then explain how you *would* add one safely: deterministic metrics → JSON → edge function → prompt with fixed schema and safety instructions → validate JSON → fallback to `ReportGenerator`.
