# 06 — Database Deep Dive

⚠️ **The repo contains NO schema, migrations, SQL, or RLS policies** (no `supabase/` dir; README references `supabase/migrations/` which doesn't exist). Everything below is **inferred from client code** and must be verified in the Supabase dashboard.

## Technology
Supabase-hosted PostgreSQL, accessed via PostgREST (`supabase_flutter ^2.3.0`). No ORM; string table/column names in Dart maps. Connection management is the SDK's (HTTP, stateless).

## Inferred tables
### `profiles`
| Column | Type (inferred) | Source |
|---|---|---|
| `id` | uuid PK = `auth.users.id` | `upsert({'id': uid…})`, `.eq('id', uid)` |
| `full_name` text, `age` int, `stroke_date` date (`yyyy-MM-dd`), `affected_side` text | onboarding |
| `reminder_enabled` bool, `reminder_time` time (`HH:mm:00`) | profile screen |
| `email`? | read defensively in profile screen (`profile['email']`) — likely absent |

### `sessions`
`id` (uuid/bigint PK, returned by insert), `user_id` (FK auth.users), `session_date` (timestamp), `duration_seconds` int, `recovery_score` numeric, `fall_risk` text ('low'|'moderate'|'high'), `stride_length` numeric, `cadence` numeric, `symmetry` numeric, `stride_consistency` numeric, `joint_deviation` numeric, `video_url` text null.

### `reports`
`id`, `session_id` (FK sessions.id — required for the embedded select), `user_id`, `summary` text, `abnormalities` text[]/jsonb, `exercise_suggestions` text[]/jsonb, `risk_assessment` text, `improvement_percentage` numeric, `generated_at` timestamptz (**never written by the client ⇒ must have `DEFAULT now()`**; the ordering and detail screen depend on it).

### Storage bucket `session-videos` — object key `{user_id}/{session_id}.mp4`.

**README's schema is different** (`sessions.recorded_at/status`, a separate `gait_metrics` table with `deficit_flags[]`, `reports.content_json/pdf_url`). Code clearly uses a flat `sessions` table ⇒ README is stale/aspirational.

## Relationships
`auth.users 1—1 profiles`; `users 1—N sessions`; `sessions 1—0..1 reports` in practice (a report is created per session, but nothing enforces uniqueness ⇒ potential duplicates if the flow is retried).

## CRUD map
Create: sessions (2 flows), reports, profiles (upsert), storage object. Read: latest session (home), last 30 (progress), reports+join, all sessions (profile). Update: `sessions.video_url`, `profiles.reminder_*`. Delete: **none** (no account/data deletion — relevant for health-data compliance).

## Design rationale
Flat `sessions` row = one snapshot of derived metrics; cheap to chart. Denormalised (raw stride intervals & angle series are **not stored**), so scores cannot be recomputed if the formula changes ⇒ historic scores become incomparable with new ones. Reports are stored text (not regenerated) ⇒ stable history.

## Potential concerns (labelled as such)
| Concern | Evidence | Type |
|---|---|---|
| Non-atomic multi-step write (session → upload → update → report) | `upload_screen._analyzeVideo`, `recording_screen._stopRecording` | consistency: orphan session rows with no report/video on failure; no idempotency ⇒ retry duplicates |
| `getLastSession` race | reads top-2 after own insert; two rapid sessions/devices could pick wrong "previous" | race (low likelihood) |
| Index needs | queries filter `user_id` + order `session_date` ⇒ composite index `(user_id, session_date desc)`; reports `(user_id, generated_at desc)` | **potential** missing index (unknown) |
| Unbounded read | profile stats read all sessions | scalability; better `avg()/sum()` via RPC or view |
| N+1? | reports list uses one embedded join ⇒ **no N+1** | ok |
| Trust | client computes and inserts score & risk | integrity (user can forge) |
| Timestamps | local time without offset | consistency |
| Storage | public URLs, no lifecycle/cleanup, upload of full-res videos | privacy/cost |
| No transactions | PostgREST can't span calls; would need an RPC/edge function | design |

## RLS (claimed, unverified)
README: "RLS enforces `auth.uid() = user_id` on all tables." Needed: `profiles` (`id = auth.uid()`), `sessions`/`reports` (`user_id = auth.uid()` for SELECT/INSERT/UPDATE with `WITH CHECK`), Storage policies on `session-videos` (path prefix = `auth.uid()`). **If the bucket is public (needed by `getPublicUrl`), storage RLS does not protect reads.**

## Questions to be ready for
- "Why not store the raw landmark time series?" (size vs. recomputability.)
- "How would you make session creation atomic?" (Postgres function / edge function that inserts session+report in one transaction, or store report as a column.)
