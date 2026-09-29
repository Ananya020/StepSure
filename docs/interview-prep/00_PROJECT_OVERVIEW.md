# 00 — Project Overview (StepSure / `gait_rehab`)

> Everything here was derived from the code in this repo (branch `claude/busy-galileo-2auh3s`, 23 commits, 2026-02-20 → 2026-09-08). Where the README/`Ml.md` disagree with the code, **the code wins** and the gap is called out. Legend: ✅ implemented · 🟡 partial · ⚪ configured/declared but unused · 📄 only claimed in docs · ⚠️ VERIFY = could not confirm from the repo.

## 1. One-paragraph truth
StepSure is a **Flutter (Dart) mobile app** that estimates gait metrics for stroke-rehab patients from a smartphone camera. It runs **Google ML Kit Pose Detection on-device** to get body landmarks, turns them into hand-written **rule-based metrics** (knee angles, left/right "symmetry", step-timing cadence, stride "consistency"), combines them into a **weighted recovery score (0–100)** and a **3-level fall-risk label**, generates a **template-based text report** (no LLM), stores everything in **Supabase** (Auth + Postgres + Storage), and lets the user view history/charts and export a PDF.

There is **no custom backend server** and **no trained model of our own**. The only "ML" is the pre-trained ML Kit pose estimator; everything after it is deterministic arithmetic and if/else rules.

## 2. Problem, users
- Problem (from README): post-stroke patients get little physiotherapy between clinic visits; nobody sees how they walk at home.
- Users: stroke patients (primary). Onboarding collects `full_name, age, stroke_date, affected_side`. A "clinician dashboard" is **📄 claimed in README, absent in code**.
- ⚠️ Clinical validity: none of the thresholds are validated against any dataset or clinical study in the repo. Treat outputs as heuristics/demo-grade.

## 3. Feature status matrix (verified against code)
| Feature | Status | Evidence |
|---|---|---|
| Email/password sign-up, login, sign-out | ✅ | `login_screen.dart:_login`, `register_screen.dart:_register`, `AuthProvider` |
| Onboarding profile capture | ✅ | `onboarding_screen.dart:_save` → `profiles.upsert` |
| Live camera pose overlay + metrics | 🟡 (buggy) | `recording_screen.dart`; `startSession()` never called ⇒ cadence always 0 |
| Upload pre-recorded video → analysis | 🟡 (Android only, timing bug) | `upload_screen.dart`, `video_analysis_service.dart`, `MainActivity.kt` |
| Recovery score + fall risk | ✅ (heuristic) | `score_calculator.dart` |
| Rule-based report (summary, issues, exercises) | ✅ | `report_generator.dart` |
| Report history + detail | ✅ | `reports_list_screen.dart`, `report_detail_screen.dart` |
| Progress chart | ✅ | `progress_screen.dart` (fl_chart) |
| PDF export/share | ✅ (basic) | `pdf_generator.dart` (50 lines) |
| Voice feedback (TTS) | ✅ live only | `feedback_engine.dart` |
| Daily reminder notifications | ⚪ | `notification_service.dart` is **never initialised or called**; profile only writes `reminder_*` columns |
| Notifications inbox | 🟡 mock | `features/notifications/notifications_screen.dart` hardcoded list |
| `SessionProvider` state mgmt | ⚪ | 5-line empty class |
| Gemini AI reports / edge function | 📄 | no `gemini`/HTTP/`functions.invoke` anywhere in `lib/` |
| Exercise library / 3D Mixamo videos / Blender pipeline | 📄 | no exercise model/screens/videos; `assets/` has only Lottie JSON + gif |
| Clinician dashboard, offline cache (`local_storage.dart`) | 📄 / empty file | file is 0 bytes |
| Tests | ❌ broken | `test/widget_test.dart` is the default counter test importing `package:stepsure/main.dart` and `MyApp` (neither exist) |

## 2-minute "what I built" script (honest version)
"StepSure is a Flutter app for post-stroke gait tracking. The camera frames go through Google ML Kit pose detection on the phone; I compute knee/hip angles from the landmarks, detect steps with a hysteresis state machine on knee extension, derive cadence, a left-right symmetry index and stride-time consistency, and combine them into a weighted recovery score plus a rule-based fall-risk level. Results and videos are stored in Supabase with row-level security, and users get a template-generated report, a progress chart and a PDF export. The pose model is pre-trained; the metric logic is my own heuristic and not clinically validated — that's the first thing I'd fix."

## 4. Things you MUST understand before claiming this on a resume
1. ML Kit gives **landmarks**, not gait metrics. Every metric is your own math (`angle_calculator.dart`, `gait_analysis_service.dart`).
2. Score formula and weights: `0.4·symmetry + 0.2·cadenceScore + 0.2·consistency + 0.2·(100−jointDeviation)`.
3. Step detection = per-leg knee-angle **hysteresis** (arm <140°, fire >160°).
4. Why **live cadence is 0** (`startSession` never called) and why **video-mode cadence is wall-clock based** (both are real bugs — see `13_BUGS_TECHNICAL_DEBT.md`).
5. There is **no LLM and no backend of your own**; README says otherwise.
6. Supabase RLS is *claimed* but the policies/migrations are **not in the repo** ⚠️ VERIFY — security depends entirely on them, and the anon key is hardcoded (that's normal for anon keys, but only safe with correct RLS).
7. `getPublicUrl` on `session-videos` ⇒ bucket must be public ⚠️ VERIFY ⇒ patient gait videos at guessable URLs.

## Doc index
01 Architecture · 02 Repo map · 03 File-by-file · 04 Data flows · 05 API/interface reference · 06 Database · 07 AI/ML · 08 Tech stack · 09 Design decisions · 10 Security · 11 Performance · 12 Testing/failure modes · 13 Bugs/debt · 14 Question bank · 15 Defend-your-project · 16 Cheat sheet · 17 45-min revision
