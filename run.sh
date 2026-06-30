#!/usr/bin/env bash
# Dev run script – reads token from .env.local (gitignored).
# Usage: ./run.sh [extra flutter run args]
#
# .env.local format:
#   RUNALYZE_API_TOKEN=pt#your_token_here

set -euo pipefail

ENV_FILE="$(dirname "$0")/.env.local"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE – create it with:"
  echo "  echo 'RUNALYZE_API_TOKEN=pt#your_token' > .env.local"
  exit 1
fi

# Load only the token line, strip comments and blanks
token=$(grep -E '^RUNALYZE_API_TOKEN=' "$ENV_FILE" | head -n1 | cut -d= -f2-)

if [[ -z "$token" ]]; then
  echo "RUNALYZE_API_TOKEN not found in $ENV_FILE"
  exit 1
fi

flutter run --dart-define="RUNALYZE_API_TOKEN=$token" "$@"
