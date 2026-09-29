# 12 — Testing & Failure Modes

## Existing tests
`test/widget_test.dart` — Flutter template "counter increments" test: imports `package:stepsure/main.dart` (package is actually `gait_rehab`) and `MyApp` (class is `GaitRehabApp`); would fail to compile. **Effective coverage: 0 %.** No integration tests, CI, golden tests, mocks. README's `flutter test integration_test/` refers to a directory that doesn't exist. (Flutter SDK is not installed in this analysis environment, so nothing was executed — statements about behaviour come from reading the code.)

## Highest-value tests to write (pure Dart, no device)
1. `AngleCalculator.computeAngle`: (0,1),(0,0),(1,0)=90°; collinear=180°; zero-length=0.
2. `computeSymmetry`: equal ⇒100; 100 vs 50 ⇒ 33.3.
3. `GaitAnalysisService`: needs an injectable clock; feed sine knee angles ⇒ expected step count/cadence; regression test for hysteresis; test that `startSession` is required (would have caught the live-cadence bug).
4. `ScoreCalculator`: table tests at threshold edges; empty metrics ⇒ ensure not "moderate 20".
5. `ReportGenerator`: previous score 0 ⇒ no ∞/NaN.
6. `SessionModel.toMap/fromMap` round-trip; null numerics.
7. Widget: `AuthGate` with mocked Supabase; `ResultsScreen` with sample maps.

## Scenario matrix
| Scenario | Expected | Actual (code) | Potential failure |
|---|---|---|---|
| Valid walk, live | cadence>0, sensible score | cadence **0**, score ≤80, "walk faster" cue | bug #1 |
| Valid video | metrics from video time | metrics from processing time | bug #2 |
| Invalid/empty input (stop immediately) | reject "too short" | saves session score 20/"moderate" + report | garbage in DB |
| No person in frame | prompt user | live: silent (logs "No pose detected" ≤3); upload: throws after <5 poses | live saves zeros |
| Multiple people | pick the patient | `poses.first` | wrong subject |
| Missing landmark | skip frame | angle = 0 counted | pollutes averages |
| Malformed/short video | friendly error | `<2 s` error, `<10 frames` error | ok |
| iOS upload | works | error "not supported" | feature gap |
| Corrupt/huge video | bounded | 50-frame single channel message; UI-thread decode | ANR/OOM |
| Network down at save | retry/queue | unhandled exception (live) / error card (upload) | data loss; orphan rows |
| Supabase auth expired | re-login | `currentUserId!` NPE | crash |
| Empty DB (new user) | empty states | `maybeSingle` OK; charts with 0 spots — ⚠️ VERIFY fl_chart handles empty list; `getLastSession` returns null ⇒ "first session" text | — |
| Previous score 0 | 0 improvement | ∞/NaN percent | insert error |
| Duplicate taps on stop | idempotent | `_stopRecording` re-entrant ⇒ duplicate sessions/reports | no guard flag |
| Concurrent sessions/devices | correct "previous" | index-1 heuristic | wrong baseline |
| Model failure (`processImage` throws) | skip frame | upload: caught per frame; live: caught, logged in `_errorLogs` | ok |
| TTS failure | ignore | not awaited/unhandled | minor |
| Camera permission denied | explain & retry | `availableCameras()`/init exception ⇒ generic "Camera error" | `permission_handler` unused |
| Screen off/app backgrounded while recording | pause | no lifecycle observer ⇒ camera stream/timers continue or crash ⚠️ VERIFY | — |

## Logging / error handling
`debugPrint` only; `catch (_)` swallows errors in Home/Profile/Reports loads (UI silently shows empty state); no crash reporting; no structured logs.
