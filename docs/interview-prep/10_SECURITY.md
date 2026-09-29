# 10 — Security Review

Scope: what's in the repo. Secrets are **redacted** here. Server-side config (RLS, bucket policy, auth settings) is not in the repo ⇒ many items are ⚠️ VERIFY.

| # | Severity | Issue | Evidence | Why it matters | Fix | Likely interview Q |
|---|---|---|---|---|---|---|
| 1 | HIGH ⚠️VERIFY | Patient gait videos via **public URLs** | `SupabaseService.uploadVideo` → `getPublicUrl`; path `{uid}/{sessionId}.mp4` | Health/biometric video readable by anyone with the URL; storage RLS does not gate public buckets; ids are UUIDs (hard to guess but leak via logs/share) | Private bucket + `createSignedUrl` w/ short TTL; storage policies `(storage.foldername(name))[1] = auth.uid()`; consider not uploading video at all | "Is uploading videos compatible with your 'on-device/private' claim?" |
| 2 | HIGH ⚠️VERIFY | **All authorization = RLS you can't show** | no SQL in repo; README claims RLS | Missing/lax policy ⇒ any authenticated (or anon) user can read others' health data via the public anon key | Commit migrations with policies; add tests (pgTAP); use `WITH CHECK` on inserts | "How do you prevent user A reading user B's sessions?" |
| 3 | MEDIUM | Supabase URL + publishable anon key **hardcoded** in `main.dart:16-19` (value redacted: `sb_publishable_…`) | file | Anon keys are designed to be public, but hardcoding blocks rotation/env separation, and is only safe with correct RLS; it is committed in git history | `--dart-define`/`envied`; separate dev/prod projects | "Is that key a secret?" (No—but why is it still OK/not OK?) |
| 4 | MEDIUM | Client-computed, client-inserted scores | `saveSession` inserts `recovery_score`, `fall_risk` | Users can forge results; clinicians can't trust them | Server function computes from raw features; or sign results | "What if a user edits requests?" |
| 5 | MEDIUM | Unhandled errors leak raw exceptions to UI | `onboarding_screen` shows `'Error: $e'`; upload shows exception + logs | Info leakage (paths/SQL errors) | Map to user messages; log to Crashlytics/Sentry | — |
| 6 | MEDIUM | Health-data compliance gaps | no consent screen, no delete-account/data, no disclaimer in PDF/results, no encryption at rest beyond Supabase defaults | DPDP (India)/GDPR/HIPAA-style exposure; "fall risk" output without disclaimer | Consent, retention policy, deletion RPC, medical-device disclaimer | "Is this a medical device? What regulation applies?" |
| 7 | MEDIUM | Release signed with **debug keystore** | `build.gradle.kts:36-38` | Can't publish; debug key is public/known ⇒ APK spoofing | Proper upload key + Play App Signing | — |
| 8 | LOW–MED | Auth hardening absent | email/password only; min length 6; no rate-limit UI; no email verification handling; `signUp`→`currentUser!` crash if confirmation on | Weak passwords; account enumeration via Supabase messages | Password policy ≥8–12, MFA, verify email flow | "How are passwords stored?" (Supabase GoTrue bcrypt — not by this app) |
| 9 | LOW | Password `.trim()` on submit but not in validation | `register_screen._register` | Silent password change for edge cases | Don't trim passwords | — |
| 10 | LOW | Debug logging of PII-ish data | `results_screen` `debugPrint(session/report)`; `pose_service` logs | Logs readable via adb on debug builds | Strip in release / use `kDebugMode` | — |
| 11 | LOW | No certificate pinning / no jailbreak checks / no obfuscation | absent | Only relevant for high-threat models | `--obfuscate --split-debug-info` | — |
| 12 | LOW | Missing Android `INTERNET` in main manifest | only debug/profile manifests | Not security, but ⚠️ release build cannot reach backend | Add `<uses-permission android:name="android.permission.INTERNET"/>` | — |
| 13 | INFO | Unused dependencies (7) | see `02` | Larger supply-chain surface | remove | "How do you audit dependencies?" (`flutter pub outdated`, `dart pub audit`-style tooling, Dependabot) |
| 14 | INFO | `android/build/reports/problems-report.html` committed | git ls-files | Leaks local paths | delete + .gitignore | — |

## Checklist coverage
- **SQL/NoSQL injection**: no string-built queries; PostgREST parameterised `.eq()` ⇒ low risk. **Command injection**: none (no shell). **XSS/CSRF**: N/A for native app (no WebView found). **CORS**: N/A.
- **File upload**: any picked video is uploaded with a fixed `.mp4` name; no type/size/duration validation server-side ⚠️ VERIFY bucket limits ⇒ storage abuse/cost.
- **JWT/session**: managed by supabase_flutter (secure storage handling is SDK-internal ⚠️ VERIFY platform storage).
- **Rate limiting**: none in-app; rely on Supabase defaults.
- **Input validation**: client-only (email contains `@`, age 1–120, password ≥6).
- **Secrets scan result**: only the publishable anon key and project URL (redacted); no service-role key found in repo.

## Interview-ready answer
"Security posture is 'BaaS with RLS as the whole authorization layer'. The anon key is public by design; what protects data is RLS and storage policies, which aren't checked into the repo — that's a gap I'd close first, plus making the bucket private and computing scores server-side."
