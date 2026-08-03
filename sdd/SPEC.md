# SDD specification for RunAnalyze mobile

This document captures the initial Software Design Description (SDD) for a small mobile app that mirrors the basic statistics dashboard from https://runalyze.com/dashboard.

Goals
- Provide weekly, monthly, and annual overviews of running/cycling activities.
- Display totals for distance, duration, and average pace.
- Show a simple chart of activity counts or distances per time unit.
- Work on Android (Pixel 10) as primary target device.

Scope (MVP)
- Local mock data store (JSON) with sample activities.
- Three timeframe views: Week (last 7 days), Month (last 30 days), Year (last 365 days).
- Summary cards: Total distance, Total duration, Average pace.
- Simple bar chart showing distance per day/week/month.
- Activity list showing date, distance, duration.

Non-functional
- Offline-first: app works with local data (MVP uses embedded JSON).
- Responsive layout for phone screen sizes (Pixel 10 as baseline).

Data model
- Activity: id, date (ISO 8601), type (run/ride), distance_km (double), duration_seconds (int)

Example acceptance criteria (for SDD-driven tasks)
- Given the app has 10 activities in the last 30 days, When user switches to "Month", Then total distance should equal the sum of distance_km for those activities.
- Given activities across a year, When user selects "Year", Then the annual total distance and average pace are displayed.

Next steps for Copilot-driven implementation
1. Create Flutter scaffold and wire up the SDD acceptance tests as unit/widget tests.
2. Implement import of real workout files (GPX/TCX) and local persistence (sqflite) after MVP.

---

# SDD extension for runSimple web platform

This section defines the new platform direction: a runalyze-like website called runSimple
(fallback name runBasic) that syncs initially from Strava and supports fast per-user
weekly/monthly/yearly dashboard rendering.

Goals
- Build a web platform with Strava-first syncing and app-level CRUD for workouts.
- Keep dashboard queries fast at scale with pre-aggregated daily rollups.
- Support growth on a free-start managed hosting stack.
- Add monetization later via simple non-intrusive ad banners.

Simple scope guardrails
- Keep only the core subset from the current phone app: distance, duration, count,
  and week/month/year summaries.
- Sports subset for v1: Running, Cycling, Walking, Sets (map everything else to Other).
- No social graph, segments, route analysis, workout planning, or coaching features.
- Login uses external providers only (Google first, Meta optional later), with no local
	username/password credential storage.

Scope (v1)
- User account and Strava connection flow (OAuth integration endpoint contracts).
- Initial backfill and incremental sync job pipeline.
- Workout CRUD in the app API.
- Dashboard summary endpoints for week/month/year per user.
- Conflict-aware handling for provider-sourced activities:
	local edits/deletes are stored as overrides/tombstones when direct provider mutation is unavailable.

Non-goals (v1)
- Direct Zepp integration.
- Subscription billing.
- Advanced training analytics beyond distance/time/count rollups.

Architecture overview
- Frontend: web app (implementation pending).
- Backend API: FastAPI service under backend/app.
- Worker: sync job executor (skeleton queue contract implemented, worker execution pending).
- Database: PostgreSQL with normalized tables + daily aggregate table.

Data model (initial)
- users: app identities and timezone defaults.
- connected_accounts: provider tokens (Strava) and token lifecycle metadata.
- activities: canonical activity store with source ids and soft-delete/override flags.
- activity_edits: audit trail for local edits.
- daily_user_metrics: per-day, per-user, per-sport rollups for fast summaries.
- sync_cursors: incremental sync checkpoint by provider and user.
- sync_jobs: queued/running/failed/succeeded jobs and retry state.

Canonical units
- distance stored in meters.
- durations stored in seconds.
- timestamps stored in UTC and projected to user timezone at read time.

Dashboard performance strategy
- Default summary queries should hit daily_user_metrics.
- Raw activities table is fallback for rollup rebuild and verification.
- Initial target: p95 server-side summary response below 250 ms under warm cache.

Sync pipeline strategy
- Event path: Strava webhook (to be added) triggers sync job enqueue.
- Reconciliation path: scheduled poller to close webhook gaps.
- Upsert policy: idempotent by (user_id, source, source_activity_id).
- Retry policy: exponential backoff with capped retries and dead-letter logging.
- Conflict policy:
	provider-origin records can receive local overrides without losing upstream source data.

API contracts (initial scaffold)
- GET /health
- GET /v1/auth/google/connect
- GET /v1/auth/google/callback
- GET /v1/auth/session
- POST /v1/auth/logout
- GET /v1/auth/strava/connect
- GET /v1/auth/strava/callback
- POST /v1/activities
- GET /v1/activities
- PATCH /v1/activities/{id}
- DELETE /v1/activities/{id}
- GET /v1/dashboard/summary?timeframe=week|month|year
- POST /v1/sync/strava
- POST /v1/metrics/rebuild

Hosting research direction (free-start and resume-friendly)
- Preferred path:
	Azure Static Web Apps (frontend), Azure Container Apps (API + worker),
	Azure Database for PostgreSQL Flexible Server, Azure Storage, Azure Monitor.
- Migration path:
	start with lowest-cost managed tiers, then add replicas/materialized views when p95 grows.

Monetization roadmap (post-MVP)
- Add one simple banner slot per major dashboard surface.
- Keep ad rendering behind feature flags.
- Track ad_impression and ad_click events for revenue analytics.
- Preserve privacy controls and consent flow before ad rollout.

Initial acceptance criteria for web track
- Given a user with synced Strava workouts, when requesting week/month/year summary,
	then totals are returned correctly from aggregated metrics.
- Given an activity created in-app, when listing activities, then it appears with source=app.
- Given a provider activity locally deleted, when listing activities, then it is hidden by default.
- Given a sync job trigger request, when POST /v1/sync/strava is called,
	then a queued job record is created.

Current implementation status
- Implemented:
	backend FastAPI scaffold, PostgreSQL schema script, Strava OAuth connect/callback token
	persistence, CRUD endpoints, summary endpoint, and sync job queue trigger endpoint.
- Pending next:
	worker executor, webhook endpoint, aggregate table updater,
	and production deployment manifests.
