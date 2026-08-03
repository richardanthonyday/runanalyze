#!/usr/bin/env bash
# Dev run script – reads tokens from .env.local (gitignored).
# Usage: ./run.sh [-d <DEVICE_ID>] [extra flutter run args]

set -euo pipefail

ENV_FILE="$(dirname "$0")/.env.local"
BACKEND_URL="http://localhost:8000"

if [[ -f "$ENV_FILE" ]]; then
  url_from_file=$(grep -E '^BACKEND_URL=' "$ENV_FILE" | head -n1 | cut -d= -f2- || true)
  if [[ -n "$url_from_file" ]]; then
    BACKEND_URL="$url_from_file"
  fi
fi

# Set up ADB reverse port forwarding for connected Android devices (physical & emulator).
# This forwards port 8000 on the phone directly to port 8000 on the WSL host machine.
if command -v adb >/dev/null 2>&1; then
  echo "Configuring ADB reverse port forwarding (tcp:8000 -> tcp:8000)..."
  adb reverse tcp:8000 tcp:8000 >/dev/null 2>&1 || true
fi

echo "Launching Flutter app connected to $BACKEND_URL..."
flutter run --dart-define="BACKEND_URL=$BACKEND_URL" "$@"

