#!/bin/sh
set -eu

CONFIG="/srv/config.xml"
OUT="/srv/lang/master/tmp"
MARK="$OUT/.config.md5"
TPL="/srv/lang/master/tpl"
GEN="/usr/local/lib/camap/temploc2.n"   # 👈 chemin absolu

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

exec /usr/sbin/apache2ctl -D FOREGROUND
