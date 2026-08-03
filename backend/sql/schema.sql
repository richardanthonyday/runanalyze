CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  email VARCHAR(254) UNIQUE NOT NULL,
  display_name VARCHAR(120),
  avatar_url VARCHAR(512),
  timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS external_identities (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider VARCHAR(32) NOT NULL,
  external_user_id VARCHAR(128) NOT NULL,
  email VARCHAR(254),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_external_identity_provider_user UNIQUE (provider, external_user_id)
);

CREATE INDEX IF NOT EXISTS ix_external_identity_user_provider
  ON external_identities(user_id, provider);

CREATE TABLE IF NOT EXISTS user_sessions (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(128) NOT NULL UNIQUE,
  provider VARCHAR(32) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_user_sessions_user_expires
  ON user_sessions(user_id, expires_at DESC);

CREATE TABLE IF NOT EXISTS connected_accounts (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider VARCHAR(32) NOT NULL,
  provider_athlete_id VARCHAR(64) NOT NULL,
  access_token TEXT NOT NULL,
  refresh_token TEXT NOT NULL,
  token_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_provider_athlete UNIQUE (provider, provider_athlete_id)
);

CREATE TABLE IF NOT EXISTS activities (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source VARCHAR(32) NOT NULL,
  source_activity_id VARCHAR(64),
  sport VARCHAR(32) NOT NULL,
  title VARCHAR(255),
  started_at_utc TIMESTAMPTZ NOT NULL,
  distance_m DOUBLE PRECISION NOT NULL DEFAULT 0,
  moving_time_s INTEGER NOT NULL DEFAULT 0,
  elapsed_time_s INTEGER NOT NULL DEFAULT 0,
  locally_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  local_override BOOLEAN NOT NULL DEFAULT FALSE,
  raw_payload TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_activities_source_uniqueness
  ON activities(user_id, source, source_activity_id)
  WHERE source_activity_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_activities_user_started
  ON activities(user_id, started_at_utc DESC);

CREATE TABLE IF NOT EXISTS activity_edits (
  id BIGSERIAL PRIMARY KEY,
  activity_id BIGINT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  patch_json TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS daily_user_metrics (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  metric_date DATE NOT NULL,
  sport VARCHAR(32) NOT NULL DEFAULT 'all',
  distance_m_sum DOUBLE PRECISION NOT NULL DEFAULT 0,
  moving_time_s_sum INTEGER NOT NULL DEFAULT 0,
  activity_count INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_daily_metric_row UNIQUE (user_id, metric_date, sport)
);

CREATE INDEX IF NOT EXISTS ix_daily_user_metrics_user_date
  ON daily_user_metrics(user_id, metric_date DESC);

CREATE TABLE IF NOT EXISTS sync_cursors (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider VARCHAR(32) NOT NULL,
  last_synced_at_utc TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_sync_cursor UNIQUE (user_id, provider)
);

CREATE TABLE IF NOT EXISTS sync_jobs (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider VARCHAR(32) NOT NULL,
  status VARCHAR(24) NOT NULL,
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  error_message TEXT,
  retries INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_sync_jobs_user_created
  ON sync_jobs(user_id, created_at DESC);
