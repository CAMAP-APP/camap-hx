#!/bin/bash
set -e
umask 022
ENVJS="/srv/www/env.js"
DOTENV="/srv/camapts.env"

echo "[entrypoint] Starting CAMAP container…"

if [ -f "$DOTENV" ]; then
  echo "[entrypoint] Loading environment from $DOTENV"
  SANITIZED="/tmp/camapts.env.$$"
  trap 'rm -f "$SANITIZED" "$SANITIZED.tmp" 2>/dev/null || true' EXIT
  tr -d '\r' < "$DOTENV" > "$SANITIZED"
  if grep -qE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:' "$SANITIZED"; then
    echo "[entrypoint] Detected YAML-like env; converting to KEY=VALUE"
    sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:[[:space:]]*/\1=/' -i "$SANITIZED"
  fi
  set -a; . "$SANITIZED"; set +a
else
  echo "[entrypoint] No $DOTENV found — skipping"
fi

# Valeurs runtime avec fallback
PUBLIC_PATH_RT="${PUBLIC_PATH:-/neostatic/}"
API_HOSTNAME_RT="${API_HOSTNAME:-}"
API_PORT_RT="${API_PORT:-}"
CAMAP_HOST_RT="${CAMAP_HOST:-}"
# CAMAP_BRIDGE_API_RT="${CAMAP_BRIDGE_API:-}"
FRONT_URL_RT="${FRONT_URL:-}"
FRONT_GRAPHQL_URL_RT="${FRONT_GRAPHQL_URL:-}"
# MAPBOX_KEY_RT="${MAPBOX_KEY:-}"

echo "[entrypoint] Generating env.js at $ENVJS"
{
  printf '(function (w, cfg) { w.__APP_CONFIG__ = Object.assign({}, w.__APP_CONFIG__ || {}, cfg); })(window, {'
  first=1
  emit() {
    key="$1"; val="$2"; [ -n "$val" ] || return 0
    esc=${val//\\/\\\\}; esc=${esc//\"/\\\"}; esc=${esc//$'\n'/\\n}
    if [ "$first" -eq 1 ]; then
      printf '\n  %s: "%s"' "$key" "$esc"
      first=0
    else
      printf ',\n  %s: "%s"' "$key" "$esc"
    fi
  }
  emit "PUBLIC_PATH"       "$PUBLIC_PATH_RT"
  emit "API_HOSTNAME"      "$API_HOSTNAME_RT"
  emit "API_PORT"          "$API_PORT_RT"
  emit "CAMAP_HOST"        "$CAMAP_HOST_RT"
  # emit "CAMAP_BRIDGE_API"  "$CAMAP_BRIDGE_API_RT"
  emit "FRONT_URL"         "$FRONT_URL_RT"
  emit "FRONT_GRAPHQL_URL" "$FRONT_GRAPHQL_URL_RT"
  # emit "MAPBOX_KEY"        "$MAPBOX_KEY_RT"
  printf '\n});\n'
} > "$ENVJS"

echo "[entrypoint] env.js generated. Size: $(wc -c < "$ENVJS") bytes"
exec /usr/sbin/apache2ctl -D FOREGROUND
