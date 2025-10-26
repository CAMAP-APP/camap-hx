#!/bin/sh
set -eu

CONFIG="/srv/config.xml"
OUT="/srv/lang/master/tmp"
MARK="$OUT/.config.md5"

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
  cd /srv/lang/master/tpl
  neko ../../../backend/temploc2.n -macros macros.mtt -output ../tmp/ *.mtt */*.mtt */*/*.mtt
  [ -f /tmp/config.md5 ] && mv /tmp/config.md5 "$MARK" || true
fi

# Lancer Apache
exec /usr/sbin/apache2ctl -D FOREGROUND
