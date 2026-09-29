# 05 — API / Interface Reference

**There is no HTTP API authored in this repo.** The "backend API" is Supabase's auto-generated PostgREST/Auth/Storage endpoints called through `supabase_flutter`. Below: every call site, plus the one native bridge. Auth column: all data calls carry the user's JWT (RLS-dependent ⚠️ VERIFY policies, not in repo).

## A. Supabase Auth
| Call | Where | Notes |
|---|---|---|
| `auth.signUp(email,password)` | `register_screen._register`, `AuthProvider.signUp`, `SupabaseService.signUp` | Client validators: email must contain `@`, password ≥6 chars, confirm must match. Password is validated untrimmed but sent `.trim()`med (a password with leading/trailing space is silently altered). Email-confirmation setting unknown |
| `auth.signInWithPassword` | `login_screen._login` (+ 2 duplicates) | Error → `AuthException.message` |
| `auth.signOut` | `profile_screen._signOut` | pushes `LoginScreen` and clears stack |
| `auth.onAuthStateChange` | `AuthGate` | session persistence handled by SDK |

## B. Postgres via PostgREST (table access)
| Operation | Call | File:function | Purpose / failure |
|---|---|---|---|
| INSERT sessions | `.from('sessions').insert(map).select('id').single()` | `SupabaseService.saveSession` | Body: `user_id, session_date(ISO), duration_seconds, recovery_score, fall_risk, stride_length, cadence, symmetry, stride_consistency, joint_deviation, video_url`. Returns new `id`. `user_id` comes from client (RLS must enforce `= auth.uid()`). |
| SELECT sessions (history) | `.eq('user_id').order('session_date',desc).limit(30)` | `getUserSessions` | `currentUserId!` NPE if logged out |
| SELECT sessions (previous) | same, `limit(2)` → `list[1]` | `getLastSession` | Must be called **after** inserting the current session |
| UPDATE sessions | `.update({'video_url'}).eq('id')` | `updateSessionVideoUrl` | second write to same row |
| INSERT reports | `session_id,user_id,summary,abnormalities,exercise_suggestions,risk_assessment,improvement_percentage` | `saveReport` | `abnormalities`/`exercise_suggestions` are `List<String>` ⇒ column types must be `text[]` or `jsonb` ⚠️ VERIFY |
| SELECT reports | `getUserReports` (unused) and `reports_list_screen._load` with `select('*, sessions(recovery_score,fall_risk,duration_seconds)')` | embedded join needs FK |
| SELECT/UPSERT/UPDATE profiles | `home_screen._load`, `profile_screen._load/_saveReminder`, `onboarding_screen._save`, `AuthProvider.getProfile` | `maybeSingle` (null ok) vs `.single()` (throws if 0 rows) |
| SELECT sessions (stats) | `select('recovery_score, duration_seconds').eq('user_id')` — **no limit** | `profile_screen._load` | O(N) transfer |

## C. Storage
`storage.from('session-videos').upload('{uid}/{sessionId}.mp4', File)` then `getPublicUrl(...)` — `SupabaseService.uploadVideo`. Always writes `.mp4` even if the source is `.mov/.avi/.m4v`. No size limit/timeout/progress. Public URL ⇒ bucket must be public ⚠️ VERIFY.

## D. Native bridge (the only custom "endpoint")
`MethodChannel('video_frame_extractor')`, method `extractFrames`
- Request: `{videoPath:String, fps:int (ignored natively), width:int, height:int, count:int}`
- Response: `List<Uint8List>` JPEG bytes (may contain fewer than `count` if `getFrameAtTime` returns null); error code `frame_extraction_failed`; `notImplemented` for other methods.
- Android only (`MainActivity.kt`). iOS ⇒ `MissingPluginException` handled in Dart.

## E. Example payloads
`INSERT sessions` (illustrative values):
```json
{"user_id":"<uuid>","session_date":"2026-02-22T10:31:04.120","duration_seconds":34,"recovery_score":57.3,"fall_risk":"moderate","stride_length":0.8,"cadence":0.0,"symmetry":71.2,"stride_consistency":100.0,"joint_deviation":12.5,"video_url":null}
```
(Note the live-mode artefacts: `cadence 0`, `stride_length 0.8` fallback, `stride_consistency 100` default.)
Note `session_date` is `toIso8601String()` of a **local** DateTime (no `Z`) ⇒ timezone ambiguity if the column is `timestamptz` ⚠️ VERIFY.

## F. Interview-friendly summary
"We didn't write an API. The Flutter client talks straight to Supabase: PostgREST for CRUD, GoTrue for auth, Storage for videos. Authorization is therefore *entirely* RLS policies; the client is untrusted, which also means anyone can write any `recovery_score` for themselves — fine for a personal tracker, not for clinician-trusted data."
