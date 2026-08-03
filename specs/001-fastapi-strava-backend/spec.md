# Feature Specification: 001 FastAPI & Strava Backend Integration

**Feature Branch**: `001-fastapi-strava-backend`

**Created**: 2026-08-02

**Status**: Draft

**Input**: User request to replace slow Runalyze API with local FastAPI + Strava backend integration and specify-framework tracking.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fast Sub-Second Dashboard Summaries (Priority: P1)

As a runner or cyclist using the mobile app,
I want to view my weekly, monthly, and yearly activity summaries instantly when opening the dashboard,
so that I can track my overall training volume without waiting for slow third-party API calls.

**Why this priority**: Fast dashboard loading is the primary reason for moving away from Runalyze API. Pre-aggregated metrics in PostgreSQL ensure p95 response time under 250ms.

**Independent Test**: Can be tested independently by querying `/v1/dashboard/summary?timeframe=week|month|year` against pre-populated database metrics and asserting response time and totals.

**Acceptance Scenarios**:

1. **Given** a user with daily metric rollups in PostgreSQL, **When** requesting `GET /v1/dashboard/summary?timeframe=week`, **Then** the backend returns total distance (meters), duration (seconds), and activity count for the last 7 days.
2. **Given** the mobile app launches, **When** fetching timeframe summaries from `BackendApiClient`, **Then** dashboard cards display formatted distance (km), duration (hh:mm:ss), and average pace (min/km).

---

### User Story 2 - Strava Workout Synchronization (Priority: P2)

As a mobile app user,
I want my Strava activities synchronized into the backend database,
so that my workout statistics reflect my latest Strava runs, rides, and walks.

**Why this priority**: Connects the user's primary source of workout data (Strava) to the backend pipeline.

**Independent Test**: Can be tested independently by invoking `POST /v1/sync/strava` with a connected Strava account, asserting new activities are saved and daily metric rollups updated.

**Acceptance Scenarios**:

1. **Given** a connected Strava account, **When** calling `POST /v1/sync/strava`, **Then** a sync job is queued and processed, pulling recent Strava activities.
2. **Given** a synced Strava activity with distance 5000m and duration 1500s, **When** daily metrics are updated, **Then** `daily_user_metrics` distance sum and duration sum increase accordingly.

---

### User Story 3 - Shared Google OAuth Session across Web & Mobile (Priority: P3)

As a user across mobile phone and web browser,
I want to log in using my Google account,
so that my mobile app and web platform share the same user identity, workouts, and settings.

**Why this priority**: Establishes a single unified account system across platforms without managing local passwords.

**Independent Test**: Can be tested independently by initiating `GET /v1/auth/google/connect` and verifying session token issuance upon callback exchange.

**Acceptance Scenarios**:

1. **Given** an unauthenticated mobile user, **When** completing Google OAuth, **Then** a session token is issued and sent in `Authorization: Bearer <token>` for subsequent API requests.

---

## Edge Cases

- **Offline / Server Unavailable**: How does mobile handle API timeouts? Mobile falls back to cached `shared_preferences` activities and displays an offline indicator.
- **Strava Rate Limit**: What happens when Strava API rate limit ($429$) is reached? Sync job records retry state with exponential backoff.
- **Empty Activities**: How does the dashboard render for new users with 0 activities? Displays zero totals and a "Sync with Strava" prompt without crashing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Backend MUST serve pre-aggregated summary metrics via `GET /v1/dashboard/summary` in under 250ms.
- **FR-002**: Backend MUST sync Strava workouts via `POST /v1/sync/strava` and store activities idempotently by `(user_id, source, source_activity_id)`.
- **FR-003**: Backend MUST update `daily_user_metrics` rollups whenever activities are created, updated, or soft-deleted.
- **FR-004**: Mobile app MUST connect to the FastAPI backend using `BackendApiClient` configured via `--dart-define=BACKEND_URL=...`.
- **FR-005**: Mobile app MUST store backend session tokens securely and include them in authorization headers.
- **FR-006**: Mobile app MUST format distance in kilometers and duration in `hh:mm:ss` or `mm:ss` format.
- **FR-007**: System MUST run completely free in local development using `docker compose up -d` for PostgreSQL and FastAPI.
- **FR-008**: Backend MUST enforce soft-deletes (`locally_deleted = true`) for provider-sourced workouts when deleted locally.
