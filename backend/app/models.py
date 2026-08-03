from sqlalchemy import (
    BigInteger,
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column
from .db import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True)
    display_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    timezone: Mapped[str] = mapped_column(String(64), default="UTC")
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ExternalIdentity(Base):
    __tablename__ = "external_identities"
    __table_args__ = (
        UniqueConstraint("provider", "external_user_id", name="uq_external_identity_provider_user"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(32), index=True)
    external_user_id: Mapped[str] = mapped_column(String(128), index=True)
    email: Mapped[str | None] = mapped_column(String(254), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class UserSession(Base):
    __tablename__ = "user_sessions"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    provider: Mapped[str] = mapped_column(String(32), index=True)
    expires_at: Mapped[str] = mapped_column(DateTime(timezone=True), index=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ConnectedAccount(Base):
    __tablename__ = "connected_accounts"
    __table_args__ = (
        UniqueConstraint("provider", "provider_athlete_id", name="uq_provider_athlete"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(32), index=True)
    provider_athlete_id: Mapped[str] = mapped_column(String(64), index=True)
    access_token: Mapped[str] = mapped_column(Text)
    refresh_token: Mapped[str] = mapped_column(Text)
    token_expires_at: Mapped[str | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Activity(Base):
    __tablename__ = "activities"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    source: Mapped[str] = mapped_column(String(32), index=True)
    source_activity_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    sport: Mapped[str] = mapped_column(String(32), index=True)
    title: Mapped[str | None] = mapped_column(String(255), nullable=True)
    started_at_utc: Mapped[str] = mapped_column(DateTime(timezone=True), index=True)
    distance_m: Mapped[float] = mapped_column(Float, default=0)
    moving_time_s: Mapped[int] = mapped_column(Integer, default=0)
    elapsed_time_s: Mapped[int] = mapped_column(Integer, default=0)
    locally_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    local_override: Mapped[bool] = mapped_column(Boolean, default=False)
    raw_payload: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


Index("ix_activities_user_started", Activity.user_id, Activity.started_at_utc.desc())
Index(
    "ix_activities_source_uniqueness",
    Activity.user_id,
    Activity.source,
    Activity.source_activity_id,
    unique=True,
    postgresql_where=Activity.source_activity_id.is_not(None),
)


class ActivityEdit(Base):
    __tablename__ = "activity_edits"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    activity_id: Mapped[int] = mapped_column(ForeignKey("activities.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    patch_json: Mapped[str] = mapped_column(Text)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DailyUserMetric(Base):
    __tablename__ = "daily_user_metrics"
    __table_args__ = (
        UniqueConstraint("user_id", "metric_date", "sport", name="uq_daily_metric_row"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    metric_date: Mapped[str] = mapped_column(Date, index=True)
    sport: Mapped[str] = mapped_column(String(32), default="all", index=True)
    distance_m_sum: Mapped[float] = mapped_column(Float, default=0)
    moving_time_s_sum: Mapped[int] = mapped_column(Integer, default=0)
    activity_count: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SyncCursor(Base):
    __tablename__ = "sync_cursors"
    __table_args__ = (
        UniqueConstraint("user_id", "provider", name="uq_sync_cursor"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(32), index=True)
    last_synced_at_utc: Mapped[str | None] = mapped_column(DateTime(timezone=True), nullable=True)
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SyncJob(Base):
    __tablename__ = "sync_jobs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(32), index=True)
    status: Mapped[str] = mapped_column(String(24), index=True)
    started_at: Mapped[str | None] = mapped_column(DateTime(timezone=True), nullable=True)
    finished_at: Mapped[str | None] = mapped_column(DateTime(timezone=True), nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    retries: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
