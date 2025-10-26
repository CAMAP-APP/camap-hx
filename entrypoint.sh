#!/bin/sh
set -eu

CONFIG="/srv/config.xml"
OUT="/srv/lang/master/tmp"
MARK="$OUT/.config.md5"
TPL="/srv/lang/master/tpl"
GEN="/usr/local/lib/camap/temploc2.n"

mkdir -p "$OUT"

need_regen=1
if [ -f "$CONFIG" ]; then
  md5sum "$CONFIG" | awk '{print $1}' > /tmp/config.md5
  if [ -f "$MARK" ] && cmp -s /tmp/config.md5 "$MARK"; then
    need_regen=0
  fi
fi

if [ "$need_regen" -eq 1 ]; then
  echo "[camap-hx] (re)génération des templates Templo…"
  if [ ! -f "$GEN" ]; then
    echo "[camap-hx] ERREUR: $GEN introuvable" >&2
    exit 1
  fi
  cd "$TPL"
  neko "$GEN" -macros macros.mtt -output ../tmp/ *.mtt */*.mtt */*/*.mtt
  [ -f /tmp/config.md5 ] && mv /tmp/config.md5 "$MARK" || true
fi

# ====== Génération de /srv/www/env.js (depuis /srv/camapts.env) ======
set -eu

ENVJS="/srv/www/env.js"
DOTENV="/srv/camapts.env"

# 1) Charger les variables depuis camapts.env si présent (priorité runtime > fichier)
#    ⚠️ le fichier doit être maîtrisé (pas d'input non fiable)
if [ -f "$DOTENV" ]; then
  # exporte toutes les variables définies dans le fichier
  set -a
  # shellcheck disable=SC1090
  . "$DOTENV"
  set +a
fi

# 2) Appliquer éventuellement une priorité aux variables d'env explicites
#    (si tu continues d'en passer via docker-compose, elles écrasent le .env)
API_HOSTNAME_RT="${API_HOSTNAME:-${API_HOSTNAME:-}}"
API_PORT_RT="${API_PORT:-${API_PORT:-}}"
CAMAP_HOST_RT="${CAMAP_HOST:-${CAMAP_HOST:-}}"
CAMAP_BRIDGE_API_RT="${CAMAP_BRIDGE_API:-${CAMAP_BRIDGE_API:-}}"
FRONT_URL_RT="${FRONT_URL:-${FRONT_URL:-}}"
FRONT_GRAPHQL_URL_RT="${FRONT_GRAPHQL_URL:-${FRONT_GRAPHQL_URL:-}}"
PUBLIC_PATH_RT="${PUBLIC_PATH:-/neostatic/}"  # défaut sûr

# 3) Écrire /srv/www/env.js (JSON sécurisé via printf + python json.dumps si dispo)
mkdir -p /srv/www
cat > "$ENVJS" <<'EOF'
(function (w, cfg) {
  w.__APP_CONFIG__ = Object.assign({}, w.__APP_CONFIG__ || {}, cfg);
})(window, {
EOF

json_quote() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

append_kv () {
  key="$1"; val="$2"
  [ -n "$val" ] || return 0
  printf '  %s: %s,\n' "$key" "$(printf '%s' "$val" | json_quote)" >> "$ENVJS"
}

append_kv "PUBLIC_PATH"         "$PUBLIC_PATH_RT"
append_kv "API_HOSTNAME"        "$API_HOSTNAME_RT"
append_kv "API_PORT"            "$API_PORT_RT"
append_kv "CAMAP_HOST"          "$CAMAP_HOST_RT"
append_kv "CAMAP_BRIDGE_API"    "$CAMAP_BRIDGE_API_RT"
append_kv "FRONT_URL"           "$FRONT_URL_RT"
append_kv "FRONT_GRAPHQL_URL"   "$FRONT_GRAPHQL_URL_RT"

printf '});\n' >> "$ENVJS"

# 4) Désactiver le cache côté Apache pour env.js (mise à jour immédiate)
a2enmod headers >/dev/null 2>&1 || true
cat >/etc/apache2/conf-available/camap-envjs.conf <<'APACHE'
<Files "env.js">
  Header set Cache-Control "no-store, must-revalidate"
  Header set Pragma "no-cache"
</Files>
APACHE
a2enconf camap-envjs >/dev/null 2>&1 || true


exec /usr/sbin/apache2ctl -D FOREGROUND
