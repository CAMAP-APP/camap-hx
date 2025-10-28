#!/bin/bash
set -e

# ----------------------------------------------------------------------
# 0) Variables chemins
# ----------------------------------------------------------------------
ENVJS="/srv/www/env.js"
DOTENV="/srv/camapts.env"

echo "[entrypoint] Starting CAMAP container…"

# ----------------------------------------------------------------------
# 1) Charger camapts.env si présent
# ----------------------------------------------------------------------
if [ -f "$DOTENV" ]; then
  echo "[entrypoint] Loading environment from $DOTENV"

  # Normaliser fin de lignes Windows → Unix
  tr -d '\r' < "$DOTENV" > "${DOTENV}.tmp" && mv "${DOTENV}.tmp" "$DOTENV"

  set -a
  . "$DOTENV"
  set +a
else
  echo "[entrypoint] No $DOTENV found — skipping"
fi

# ----------------------------------------------------------------------
# 2) Préparer valeurs runtime (fallbacks)
# ----------------------------------------------------------------------
PUBLIC_PATH_RT="${PUBLIC_PATH:-/neostatic/}"

API_HOSTNAME_RT="${API_HOSTNAME:-}"
API_PORT_RT="${API_PORT:-}"
CAMAP_HOST_RT="${CAMAP_HOST:-}"
CAMAP_BRIDGE_API_RT="${CAMAP_BRIDGE_API:-}"
FRONT_URL_RT="${FRONT_URL:-}"
FRONT_GRAPHQL_URL_RT="${FRONT_GRAPHQL_URL:-}"

echo "[entrypoint] Generating env.js at $ENVJS"

# ----------------------------------------------------------------------
# 3) Générer env.js (JavaScript valide)
#    - pas de virgules finales
#    - échappement minimal
#    - valeurs vides ignorées
# ----------------------------------------------------------------------
{
  printf '(function (w, cfg) { w.__APP_CONFIG__ = Object.assign({}, w.__APP_CONFIG__ || {}, cfg); })(window, {'

  first=1
  emit() {
    key="$1"; val="$2"
    [ -n "$val" ] || return 0

    # Échappement simple JS
    esc=${val//\\/\\\\}
    esc=${esc//\"/\\\"}
    esc=${esc//$'\n'/\\n}

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
  emit "CAMAP_BRIDGE_API"  "$CAMAP_BRIDGE_API_RT"
  emit "FRONT_URL"         "$FRONT_URL_RT"
  emit "FRONT_GRAPHQL_URL" "$FRONT_GRAPHQL_URL_RT"

  printf '\n});\n'
} > "$ENVJS"

echo "[entrypoint] env.js generated. Size: $(wc -c < "$ENVJS") bytes"
head -n 10 "$ENVJS" || true

# ----------------------------------------------------------------------
# 4) Lancer Apache
# ----------------------------------------------------------------------
echo "[entrypoint] Starting Apache…"
exec /usr/sbin/apache2ctl -D FOREGROUND
