# IF I HAVE NOT TOUCHED THIS PROJECT IN 6 MONTHS — 45-minute path

| Min | Do this | Goal |
|---|---|---|
| 0–5 | Read `00_PROJECT_OVERVIEW.md` §1, §3, §4 | Reset the truth: pre-trained pose + my rules, no LLM/backend |
| 5–12 | Open `lib/domain/gait_analysis_service.dart` (146 lines) top to bottom | Rebuild step machine (160/140), cadence, consistency, joint deviation in your head; note `startSession` |
| 12–17 | `lib/domain/score_calculator.dart` + `lib/core/utils/angle_calculator.dart` | Write the score formula & risk points from memory; re-derive angle formula |
| 17–24 | `lib/presentation/screens/recording/recording_screen.dart` lines 87–290 | Trace live flow: camera → InputImage → PoseService → processFrame → stop → save → results |
| 24–29 | `lib/data/video_analysis_service.dart` + `android/.../MainActivity.kt` | Trace upload flow; understand the 50-frame/no-timestamp problem |
| 29–33 | `lib/data/supabase_service.dart`, `main.dart` | Tables/columns used, auth gate, hardcoded config |
| 33–37 | `06_DATABASE.md`, `10_SECURITY.md` top table | Schema (inferred), RLS caveat, public URL issue |
| 37–42 | `13_BUGS_TECHNICAL_DEBT.md` CRITICAL/HIGH | Be able to state each bug & fix in one sentence |
| 42–45 | Practice aloud: A1–A3, B1, C1, C4, G1, G5, H3 in `14_INTERVIEW_QUESTIONS.md`; skim `16_CHEAT_SHEET.md` | Deliver the honest 2-minute pitch |

**Config files that matter:** `pubspec.yaml` (package `gait_rehab`, deps), `lib/main.dart` (Supabase init), `android/app/build.gradle.kts` (appId/signing), `android/app/src/main/AndroidManifest.xml` (no INTERNET/CAMERA declared), `ios/Runner/Info.plist` (usage strings).
**Flows to trace:** Flow 2 (live) then Flow 3 (upload) in `04_DATA_FLOW.md`.
**APIs/tables to inspect:** `sessions`, `reports`, `profiles`, bucket `session-videos` (in Supabase dashboard — schema is not in repo; confirm RLS + bucket visibility).
**Algorithms to revise:** angle dot-product, hysteresis step detector, CV, weighted score, risk points.
**Practice first:** "How do you know your score is valid?", "What happens with no pose?", "Why is cadence wrong?", "Is video upload private?", "README says Gemini?".
**Before claiming on a resume, fix or be ready to explain:** C1 (`startSession`), C2 (timestamps), H1 (empty session guard), public bucket, README claims.
