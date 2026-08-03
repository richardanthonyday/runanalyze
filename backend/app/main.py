import os
import json
import secrets
import hashlib
import uuid
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode
from typing import Literal
import httpx
from fastapi import Depends, FastAPI, HTTPException, Query
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from .db import Base, engine, get_db
from .sync.strava import StravaClient
from .models import (
    Activity,
    ConnectedAccount,
    DailyUserMetric,
    ExternalIdentity,
    SyncJob,
    User,
    UserSession,
)
from .schemas import (
    ActivityCreate,
    ActivityOut,
    ActivityUpdate,
    AuthSessionResponse,
    DashboardSummary,
    GoogleAuthUrlResponse,
    SessionStatusResponse,
    StravaAuthUrlResponse,
    StravaCallbackResponse,
    SyncTriggerResponse,
)

app = FastAPI(title="runSimple API", version="0.1.0")

# Bootstrap for local development. For production, use migrations.
Base.metadata.create_all(bind=engine)
_oauth_state_store: dict[str, datetime] = {}


def _time_window(timeframe: str) -> tuple[datetime, datetime]:
    now = datetime.now(timezone.utc)
    end = now
    if timeframe == "week":
        start = now - timedelta(days=7)
    elif timeframe == "month":
        start = now - timedelta(days=30)
    else:
        start = now - timedelta(days=365)
    return start, end


def _normalize_sport_name(value: str | None) -> str:
    if value is None:
        return "other"
    sport = value.strip().lower()
    if sport in {"run", "running"}:
        return "running"
    if sport in {"ride", "cycling", "biking", "bike"}:
        return "cycling"
    if sport in {"walk", "walking", "hike", "hiking"}:
        return "walking"
    if sport in {"sets", "strength", "weights", "weight training"}:
        return "sets"
    return "other"


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _issue_session(db: Session, user_id: int, provider: str) -> tuple[str, datetime]:
    token = secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(days=30)

    db.add(
        UserSession(
            user_id=user_id,
            token_hash=_hash_token(token),
            provider=provider,
            expires_at=expires_at,
        )
    )
    db.commit()
    return token, expires_at


def _session_from_token(db: Session, session_token: str) -> UserSession | None:
    hashed = _hash_token(session_token)
    session = db.scalar(select(UserSession).where(UserSession.token_hash == hashed))
    if session is None:
        return None

    if session.expires_at < datetime.now(timezone.utc):
        db.delete(session)
        db.commit()
        return None

    return session


def _rebuild_daily_metrics(db: Session, user_id: int, lookback_days: int = 400) -> None:
    now = datetime.now(timezone.utc)
    window_start = now - timedelta(days=lookback_days)

    db.execute(
        delete(DailyUserMetric)
        .where(DailyUserMetric.user_id == user_id)
        .where(DailyUserMetric.metric_date >= window_start.date())
    )

    grouped_stmt = (
        select(
            func.date(Activity.started_at_utc).label("metric_date"),
            Activity.sport,
            func.coalesce(func.sum(Activity.distance_m), 0.0),
            func.coalesce(func.sum(Activity.moving_time_s), 0),
            func.count(Activity.id),
        )
        .where(Activity.user_id == user_id)
        .where(Activity.locally_deleted.is_(False))
        .where(Activity.started_at_utc >= window_start)
        .group_by(func.date(Activity.started_at_utc), Activity.sport)
    )

    totals_by_day: dict[str, dict[str, float | int]] = {}
    for metric_date, sport, distance_m, moving_time_s, activity_count in db.execute(grouped_stmt):
        normalized_sport = _normalize_sport_name(sport)
        db.add(
            DailyUserMetric(
                user_id=user_id,
                metric_date=metric_date,
                sport=normalized_sport,
                distance_m_sum=float(distance_m),
                moving_time_s_sum=int(moving_time_s),
                activity_count=int(activity_count),
            )
        )

        key = str(metric_date)
        if key not in totals_by_day:
            totals_by_day[key] = {
                "distance": 0.0,
                "moving": 0,
                "count": 0,
            }
        totals_by_day[key]["distance"] = float(totals_by_day[key]["distance"]) + float(distance_m)
        totals_by_day[key]["moving"] = int(totals_by_day[key]["moving"]) + int(moving_time_s)
        totals_by_day[key]["count"] = int(totals_by_day[key]["count"]) + int(activity_count)

    for key, totals in totals_by_day.items():
        db.add(
            DailyUserMetric(
                user_id=user_id,
                metric_date=datetime.strptime(key, "%Y-%m-%d").date(),
                sport="all",
                distance_m_sum=float(totals["distance"]),
                moving_time_s_sum=int(totals["moving"]),
                activity_count=int(totals["count"]),
            )
        )

    db.commit()


@app.get("/health")
def health():
    return {"status": "ok", "service": "runsimple-api"}


@app.get("/v1/auth/google/connect", response_model=GoogleAuthUrlResponse)
def google_connect():
    client_id = os.getenv("GOOGLE_CLIENT_ID", "")
    redirect_uri = os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8000/v1/auth/google/callback")

    if not client_id:
        raise HTTPException(status_code=400, detail="GOOGLE_CLIENT_ID is not configured")

    state = secrets.token_urlsafe(24)
    _oauth_state_store[state] = datetime.now(timezone.utc) + timedelta(minutes=10)

    query = urlencode(
        {
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": "openid email profile",
            "state": state,
            "access_type": "offline",
            "prompt": "consent",
        }
    )
    authorize_url = f"https://accounts.google.com/o/oauth2/v2/auth?{query}"
    return GoogleAuthUrlResponse(provider="google", authorize_url=authorize_url, state=state)


@app.get("/v1/auth/google/callback", response_model=AuthSessionResponse)
def google_callback(
    code: str = Query(...),
    state: str = Query(...),
    db: Session = Depends(get_db),
):
    expires = _oauth_state_store.get(state)
    if expires is None or expires < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Invalid or expired OAuth state")
    del _oauth_state_store[state]

    client_id = os.getenv("GOOGLE_CLIENT_ID", "")
    client_secret = os.getenv("GOOGLE_CLIENT_SECRET", "")
    redirect_uri = os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8000/v1/auth/google/callback")
    if not client_id or not client_secret:
        raise HTTPException(status_code=400, detail="Google credentials are not configured")

    token_resp = httpx.post(
        "https://oauth2.googleapis.com/token",
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirect_uri,
        },
        timeout=20,
    )
    if token_resp.status_code >= 400:
        raise HTTPException(status_code=502, detail="Failed to exchange Google OAuth code")

    token_payload = token_resp.json()
    access_token = token_payload.get("access_token")
    if not access_token:
        raise HTTPException(status_code=502, detail="Missing access token from Google response")

    profile_resp = httpx.get(
        "https://openidconnect.googleapis.com/v1/userinfo",
        headers={"Authorization": f"Bearer {access_token}"},
        timeout=20,
    )
    if profile_resp.status_code >= 400:
        raise HTTPException(status_code=502, detail="Failed to fetch Google user profile")

    profile = profile_resp.json()
    external_user_id = str(profile.get("sub") or "")
    email = (profile.get("email") or "").strip().lower()
    name = profile.get("name")
    avatar_url = profile.get("picture")

    if not external_user_id or not email:
        raise HTTPException(status_code=502, detail="Google profile missing required fields")

    identity = db.scalar(
        select(ExternalIdentity).where(
            ExternalIdentity.provider == "google",
            ExternalIdentity.external_user_id == external_user_id,
        )
    )

    user: User | None
    if identity is not None:
        user = db.get(User, identity.user_id)
    else:
        user = db.scalar(select(User).where(User.email == email))

    if user is None:
        user = User(
            email=email,
            display_name=name,
            avatar_url=avatar_url,
            timezone="UTC",
        )
        db.add(user)
        db.flush()
    else:
        user.display_name = name or user.display_name
        user.avatar_url = avatar_url or user.avatar_url
        db.add(user)

    if identity is None:
        identity = ExternalIdentity(
            user_id=user.id,
            provider="google",
            external_user_id=external_user_id,
            email=email,
        )
    else:
        identity.email = email

    db.add(identity)
    db.commit()

    session_token, expires_at = _issue_session(db, user.id, "google")

    return AuthSessionResponse(
        user_id=user.id,
        provider="google",
        email=user.email,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        session_token=session_token,
        expires_at=expires_at,
    )


@app.get("/v1/auth/session", response_model=SessionStatusResponse)
def session_status(
    session_token: str = Query(...),
    db: Session = Depends(get_db),
):
    session = _session_from_token(db, session_token)
    if session is None:
        return SessionStatusResponse(
            authenticated=False,
            user_id=None,
            provider=None,
            expires_at=None,
        )

    return SessionStatusResponse(
        authenticated=True,
        user_id=session.user_id,
        provider=session.provider,
        expires_at=session.expires_at,
    )


@app.post("/v1/auth/logout")
def logout(
    session_token: str = Query(...),
    db: Session = Depends(get_db),
):
    session = _session_from_token(db, session_token)
    if session is not None:
        db.delete(session)
        db.commit()
    return {"status": "ok", "detail": "Logged out"}


@app.get("/v1/auth/strava/connect", response_model=StravaAuthUrlResponse)
def strava_connect():
    client_id = os.getenv("STRAVA_CLIENT_ID", "")
    redirect_uri = os.getenv("STRAVA_REDIRECT_URI", "http://localhost:8000/v1/auth/strava/callback")

    if not client_id:
        raise HTTPException(
            status_code=400,
            detail="STRAVA_CLIENT_ID is not configured",
        )

    state = str(uuid.uuid4())
    query = urlencode(
        {
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "approval_prompt": "auto",
            "scope": "read,activity:read_all",
            "state": state,
        }
    )
    authorize_url = f"https://www.strava.com/oauth/authorize?{query}"
    return StravaAuthUrlResponse(provider="strava", authorize_url=authorize_url, state=state)


@app.get("/v1/auth/strava/callback", response_model=StravaCallbackResponse)
def strava_callback(
    code: str = Query(...),
    state: str = Query(...),
    user_id: int = Query(default=1),
    db: Session = Depends(get_db),
):
    del state  # State validation storage will be added with session support.

    client_id = os.getenv("STRAVA_CLIENT_ID", "")
    client_secret = os.getenv("STRAVA_CLIENT_SECRET", "")
    if not client_id or not client_secret:
        raise HTTPException(
            status_code=400,
            detail="Strava credentials are not configured",
        )

    token_resp = httpx.post(
        "https://www.strava.com/oauth/token",
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "grant_type": "authorization_code",
        },
        timeout=20,
    )

    if token_resp.status_code >= 400:
        raise HTTPException(status_code=502, detail="Failed to exchange Strava OAuth code")

    payload = token_resp.json()
    athlete = payload.get("athlete") or {}
    athlete_id = str(athlete.get("id")) if athlete.get("id") is not None else None
    expires_at = payload.get("expires_at")
    expires_at_dt = (
        datetime.fromtimestamp(expires_at, tz=timezone.utc)
        if isinstance(expires_at, int)
        else None
    )

    if not athlete_id:
        raise HTTPException(status_code=502, detail="Missing athlete id from Strava response")

    existing = db.scalar(
        select(ConnectedAccount).where(
            ConnectedAccount.user_id == user_id,
            ConnectedAccount.provider == "strava",
        )
    )

    if existing is None:
        existing = ConnectedAccount(
            user_id=user_id,
            provider="strava",
            provider_athlete_id=athlete_id,
            access_token=payload.get("access_token", ""),
            refresh_token=payload.get("refresh_token", ""),
            token_expires_at=expires_at_dt,
        )
    else:
        existing.provider_athlete_id = athlete_id
        existing.access_token = payload.get("access_token", existing.access_token)
        existing.refresh_token = payload.get("refresh_token", existing.refresh_token)
        existing.token_expires_at = expires_at_dt

    db.add(existing)
    db.commit()

    return StravaCallbackResponse(
        provider="strava",
        status="connected",
        athlete_id=athlete_id,
        detail="Strava account connected",
    )


@app.post("/v1/activities", response_model=ActivityOut)
def create_activity(
    payload: ActivityCreate,
    db: Session = Depends(get_db),
    user_id: int = Query(default=1),
):
    row = Activity(
        user_id=user_id,
        source="app",
        source_activity_id=None,
        sport=payload.sport,
        title=payload.title,
        started_at_utc=payload.started_at_utc,
        distance_m=payload.distance_m,
        moving_time_s=payload.moving_time_s,
        elapsed_time_s=payload.elapsed_time_s,
        locally_deleted=False,
        local_override=True,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    _rebuild_daily_metrics(db, user_id)
    return row


@app.get("/v1/activities", response_model=list[ActivityOut])
def list_activities(
    db: Session = Depends(get_db),
    user_id: int = Query(default=1),
    limit: int = Query(default=50, ge=1, le=500),
):
    stmt = (
        select(Activity)
        .where(Activity.user_id == user_id)
        .where(Activity.locally_deleted.is_(False))
        .order_by(Activity.started_at_utc.desc())
        .limit(limit)
    )
    return list(db.scalars(stmt))


@app.patch("/v1/activities/{activity_id}", response_model=ActivityOut)
def update_activity(
    activity_id: int,
    payload: ActivityUpdate,
    db: Session = Depends(get_db),
    user_id: int = Query(default=1),
):
    row = db.get(Activity, activity_id)
    if row is None or row.user_id != user_id:
        raise HTTPException(status_code=404, detail="Activity not found")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(row, field, value)

    row.local_override = True
    db.add(row)
    db.commit()
    db.refresh(row)
    _rebuild_daily_metrics(db, user_id)
    return row


@app.delete("/v1/activities/{activity_id}")
def delete_activity(
    activity_id: int,
    db: Session = Depends(get_db),
    user_id: int = Query(default=1),
):
    row = db.get(Activity, activity_id)
    if row is None or row.user_id != user_id:
        raise HTTPException(status_code=404, detail="Activity not found")

    row.locally_deleted = True
    row.local_override = True
    db.add(row)
    db.commit()
    _rebuild_daily_metrics(db, user_id)
    return {"status": "deleted", "activity_id": activity_id}


@app.get("/v1/dashboard/summary", response_model=DashboardSummary)
def dashboard_summary(
    timeframe: Literal["week", "month", "year"] = Query(default="week"),
    db: Session = Depends(get_db),
    user_id: int = Query(default=1),
):
    start, end = _time_window(timeframe)

    agg_stmt = (
        select(
            func.coalesce(func.sum(DailyUserMetric.distance_m_sum), 0.0),
            func.coalesce(func.sum(DailyUserMetric.moving_time_s_sum), 0),
            func.coalesce(func.sum(DailyUserMetric.activity_count), 0),
        )
        .where(DailyUserMetric.user_id == user_id)
        .where(DailyUserMetric.sport == "all")
        .where(DailyUserMetric.metric_date >= start.date())
        .where(DailyUserMetric.metric_date <= end.date())
    )

    total_distance_m, total_moving_time_s, total_activities = db.execute(agg_stmt).one()

    if int(total_activities) == 0:
      _rebuild_daily_metrics(db, user_id)
      total_distance_m, total_moving_time_s, total_activities = db.execute(agg_stmt).one()

    return DashboardSummary(
        user_id=user_id,
        timeframe=timeframe,
        start_utc=start,
        end_utc=end,
        total_distance_m=float(total_distance_m),
        total_moving_time_s=int(total_moving_time_s),
        total_activities=int(total_activities),
    )


@app.post("/v1/metrics/rebuild")
def rebuild_metrics(
    db: Session = Depends(get_db),
    user_id: int = Query(default=1),
):
    _rebuild_daily_metrics(db, user_id)
    return {"status": "ok", "user_id": user_id, "detail": "Daily metrics rebuilt"}


@app.post("/v1/sync/strava", response_model=SyncTriggerResponse)
def trigger_strava_sync(
    db: Session = Depends(get_db),
    user_id: int = Query(default=1),
):
    account = db.scalars(
        select(ConnectedAccount)
        .where(ConnectedAccount.user_id == user_id)
        .where(ConnectedAccount.provider == "strava")
    ).first()

    if not account:
        raise HTTPException(
            status_code=400,
            detail="Strava account not connected for this user.",
        )

    job = SyncJob(
        user_id=user_id,
        provider="strava",
        status="running",
        started_at=datetime.now(timezone.utc),
        finished_at=None,
        error_message=None,
        retries=0,
    )
    db.add(job)
    db.commit()

    synced_count = 0
    try:
        strava_client = StravaClient()
        activities = strava_client.list_recent_activities(account.access_token, per_page=50)

        for act in activities:
            external_id = str(act["id"])
            existing = db.scalars(
                select(Activity)
                .where(Activity.user_id == user_id)
                .where(Activity.source == "strava")
                .where(Activity.source_activity_id == external_id)
            ).first()

            start_dt = datetime.fromisoformat(act["start_date"].replace("Z", "+00:00"))

            if existing:
                if not existing.local_override and not existing.locally_deleted:
                    existing.title = act.get("name", existing.title)
                    existing.sport = act.get("type", existing.sport)
                    existing.distance_m = float(act.get("distance", 0.0))
                    existing.moving_time_s = int(act.get("moving_time", 0))
                    existing.elapsed_time_s = int(act.get("elapsed_time", 0))
                    existing.started_at_utc = start_dt
                    existing.raw_payload = json.dumps(act)
                    db.add(existing)
                    synced_count += 1
            else:
                new_act = Activity(
                    user_id=user_id,
                    source="strava",
                    source_activity_id=external_id,
                    sport=act.get("type", "Run"),
                    title=act.get("name", "Strava Activity"),
                    distance_m=float(act.get("distance", 0.0)),
                    moving_time_s=int(act.get("moving_time", 0)),
                    elapsed_time_s=int(act.get("elapsed_time", 0)),
                    started_at_utc=start_dt,
                    raw_payload=json.dumps(act),
                    local_override=False,
                    locally_deleted=False,
                )
                db.add(new_act)
                synced_count += 1

        db.commit()

        _rebuild_daily_metrics(db, user_id)

        job.status = "completed"
        job.finished_at = datetime.now(timezone.utc)
        db.add(job)
        db.commit()

        return SyncTriggerResponse(
            user_id=user_id,
            provider="strava",
            status="completed",
            detail=f"Successfully synced {synced_count} activities from Strava.",
        )
    except Exception as exc:
        job.status = "failed"
        job.finished_at = datetime.now(timezone.utc)
        job.error_message = str(exc)
        db.add(job)
        db.commit()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to sync with Strava: {str(exc)}",
        )
