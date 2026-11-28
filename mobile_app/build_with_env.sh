#!/usr/bin/env bash
# Build the Flutter APK with default Settings values taken from the repo's .env.
# Values are passed as dart-defines, so no secret is stored in Dart source or
# in a committed file. A plain `flutter build` still works with empty defaults.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"

get_env() {
  local key="$1"
  local line
  line="$(grep -m1 "^${key}=" "$ENV_FILE" 2>/dev/null || true)"
  local value="${line#*=}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  printf '%s' "$value"
}

DOMAIN="$(get_env DOMAIN)"
MOBILE_TOKEN="$(get_env MOBILE_API_TOKEN)"
ADMIN_TOKEN="$(get_env MOBILE_ADMIN_TOKEN)"
SERVER_URL=""
if [[ -n "$DOMAIN" ]]; then
  SERVER_URL="https://${DOMAIN}"
fi

export PATH="$HOME/.flutter/bin:$PATH"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
cd "$ROOT/mobile_app"

flutter build apk --debug \
  --dart-define=DEFAULT_SERVER_URL="$SERVER_URL" \
  --dart-define=DEFAULT_MOBILE_TOKEN="$MOBILE_TOKEN" \
  --dart-define=DEFAULT_ADMIN_TOKEN="$ADMIN_TOKEN" \
  "$@"
