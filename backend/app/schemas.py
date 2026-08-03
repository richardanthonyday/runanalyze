from datetime import datetime
from pydantic import BaseModel, Field


class ActivityCreate(BaseModel):
    sport: str = Field(min_length=2, max_length=32)
    title: str | None = Field(default=None, max_length=255)
    started_at_utc: datetime
    distance_m: float = Field(default=0, ge=0)
    moving_time_s: int = Field(default=0, ge=0)
    elapsed_time_s: int = Field(default=0, ge=0)


class ActivityUpdate(BaseModel):
    sport: str | None = Field(default=None, min_length=2, max_length=32)
    title: str | None = Field(default=None, max_length=255)
    started_at_utc: datetime | None = None
    distance_m: float | None = Field(default=None, ge=0)
    moving_time_s: int | None = Field(default=None, ge=0)
    elapsed_time_s: int | None = Field(default=None, ge=0)


class ActivityOut(BaseModel):
    id: int
    user_id: int
    source: str
    source_activity_id: str | None
    sport: str
    title: str | None
    started_at_utc: datetime
    distance_m: float
    moving_time_s: int
    elapsed_time_s: int
    locally_deleted: bool
    local_override: bool

    model_config = {"from_attributes": True}


class DashboardSummary(BaseModel):
    user_id: int
    timeframe: str
    start_utc: datetime
    end_utc: datetime
    total_distance_m: float
    total_moving_time_s: int
    total_activities: int


class SyncTriggerResponse(BaseModel):
    user_id: int
    provider: str
    status: str
    detail: str


class StravaAuthUrlResponse(BaseModel):
    provider: str
    authorize_url: str
    state: str


class StravaCallbackResponse(BaseModel):
    provider: str
    status: str
    athlete_id: str | None
    detail: str


class GoogleAuthUrlResponse(BaseModel):
    provider: str
    authorize_url: str
    state: str


class AuthSessionResponse(BaseModel):
    user_id: int
    provider: str
    email: str
    display_name: str | None
    avatar_url: str | None
    session_token: str
    expires_at: datetime


class SessionStatusResponse(BaseModel):
    authenticated: bool
    user_id: int | None
    provider: str | None
    expires_at: datetime | None
