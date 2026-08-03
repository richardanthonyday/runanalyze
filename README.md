# runSimple mobile

This repository contains a minimal Flutter mobile app scaffold implementing a basic dashboard for **runSimple**. It is an SDD-driven starting point to view weekly, monthly, and annual activity statistics on an Android Pixel 10 (or physical phone/emulator).

See /sdd/SPEC.md for the SDD specification used to drive development.

## runSimple web backend

The repository includes the backend for the runSimple web and mobile platform:

- Product direction: small Basic subset for casual runners (not a full Runalyze/Strava clone)
- Core metrics focus: distance, duration, activity count, and week/month/year summaries
- Auth approach: social login only (Google first), no local username/password storage

- Path: backend/
- Stack: FastAPI + PostgreSQL
- Current endpoints:
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

### Backend local setup

1. Start PostgreSQL with schema:

```bash
cd backend
docker compose up -d
```

2. Create and activate a Python environment, then install dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

3. Run API service:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

4. Open API docs:

```bash
http://localhost:8000/docs
```

Use backend/.env.example as the template for environment variables.

For local Strava & Google OAuth testing, set the following environment variables in `backend/.env` (or pass them when running Docker Compose):

```env
# Strava OAuth Configuration
STRAVA_CLIENT_ID=your_strava_client_id
STRAVA_CLIENT_SECRET=your_strava_client_secret

# Google OAuth Configuration
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GOOGLE_REDIRECT_URI=http://localhost:8000/v1/auth/google/callback
```

### Current web track status

- Implemented: data schema, Strava OAuth connect/callback token persistence, CRUD API, summary API, sync-job trigger endpoint.
- Next: webhook ingestion, sync worker execution, and aggregate refresh pipeline.

## Local dev environment

The mobile app connects to the FastAPI backend service (`http://10.0.2.2:8000` by default in the Android emulator).

1. Optional: Create a local secrets file (`.env.local`, gitignored) to customize the backend URL:

```bash
echo 'BACKEND_URL=http://10.0.2.2:8000' > .env.local
```

2. Use the dev run script:

```bash
./run.sh -d <DEVICE_ID>
# e.g. ./run.sh -d emulator-5554
```

The backend URL is passed via `--dart-define=BACKEND_URL=...`.

> **Important:** `.env.local` is gitignored. Never commit real secrets.

---

## Wireless debugging (WSL) & Physical Device Setup

### On the phone

1. Enable Developer options (Settings → About phone → tap Build number 7 times)
2. Turn on **Wireless debugging**
3. Tap **Wireless debugging** → **Pair device with pairing code**
4. Keep that screen open — note the IP address, pair port, and ADB port shown

### In WSL terminal

```bash
adb kill-server
adb start-server
adb pair <PHONE_IP>:<PAIR_PORT>   # enter pairing code when prompted
adb connect <PHONE_IP>:<ADB_PORT> # use the port shown on the main Wireless debugging screen
adb reverse tcp:8000 tcp:8000     # forwards phone's localhost:8000 to WSL host's localhost:8000
adb devices -l
flutter devices
./run.sh -d <DEVICE_ID>
```

> **Note on Network Routing & Ports:**
> - `adb pair` uses the **Pairing Port** shown in the popup dialog.
> - `adb connect` uses the **ADB Port** shown on the main Wireless Debugging screen.
> - `adb reverse tcp:8000 tcp:8000` routes `http://localhost:8000` from the physical phone through ADB back to the WSL host, bypassing Hyper-V firewall/subnet restrictions. `run.sh` runs this automatically.

---

## Debug startup (API probe mode)

You can launch directly into the API Probe screen for request/response diagnostics.

```bash
flutter run --dart-define=API_PROBE_MODE=true
```

In probe mode you can:

- Run a single API call for page 1 with configurable `itemsPerPage`
- Switch between latest payload and window-filtered analysis
- Dump full probe payload to Flutter console (request URL/headers, status, response headers/body, errors)

### Save probe logs to a file

```bash
mkdir -p logs
flutter run --dart-define=API_PROBE_MODE=true | tee logs/api_probe.log
```

Probe dumps are wrapped with markers for easy searching:

- `=== RUNANALYZE_API_PROBE_START ===`
- `=== RUNANALYZE_API_PROBE_END ===`
