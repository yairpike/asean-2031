#!/usr/bin/env bash
# Copy the service worker next to a single-threaded Compatibility export and
# register it. Does not add cross-origin isolation headers.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/build/web"
# Optional trees. Set AUDIO_SRC, CAMEO_SRC, and MENU_SRC in the environment, or pass
# --audio DIR, --cameos DIR, and --menu DIR. Without them, folders already
# next to the export are left in place.
if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
  DEST="$1"
  shift
fi
while [ $# -gt 0 ]; do
  case "$1" in
    --audio)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --audio needs a directory"
        exit 1
      fi
      AUDIO_SRC="$2"
      shift 2
      ;;
    --cameos)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --cameos needs a directory"
        exit 1
      fi
      CAMEO_SRC="$2"
      shift 2
      ;;
    --menu)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --menu needs a directory"
        exit 1
      fi
      MENU_SRC="$2"
      shift 2
      ;;
    --terrain)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --terrain needs a directory"
        exit 1
      fi
      TERRAIN_SRC="$2"
      shift 2
      ;;
    --ui)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --ui needs a directory"
        exit 1
      fi
      UI_SRC="$2"
      shift 2
      ;;
    *)
      echo "finish_web_export: unknown argument $1"
      exit 1
      ;;
  esac
done
AUDIO_SRC="${AUDIO_SRC:-}"
CAMEO_SRC="${CAMEO_SRC:-}"
MENU_SRC="${MENU_SRC:-}"
TERRAIN_SRC="${TERRAIN_SRC:-}"
UI_SRC="${UI_SRC:-}"
# Keep the project worker. Godot's exported worker reloads every open client
# when it receives "update", which boots a match back to the menu.
cp "$ROOT/web/sw.js" "$DEST/sw.js"
if [ -f "$DEST/index.service.worker.js" ]; then
  python3 - "$DEST/index.service.worker.js" << 'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
old = "self.skipWaiting().then(() => self.clients.claim()).then(() => self.clients.matchAll()).then((all) => all.forEach((c) => c.navigate(c.url)));"
new = "self.skipWaiting().then(() => self.clients.claim());"
if old in text:
    text = text.replace(old, new, 1)
elif "c.navigate(c.url)" in text:
    raise SystemExit("finish_web_export: service worker navigate hook moved")
open(path, "w", encoding="utf-8").write(text)
PY
fi
if [ -f "$DEST/index.html" ]; then
  python3 - "$DEST/index.html" << 'PY'
import sys
path = sys.argv[1]
html = open(path, encoding="utf-8").read()
old = '"serviceWorker":"index.service.worker.js"'
new = '"serviceWorker":""'
if old in html:
    html = html.replace(old, new, 1)
elif '"serviceWorker":""' not in html:
    raise SystemExit("finish_web_export: serviceWorker config moved")
open(path, "w", encoding="utf-8").write(html)
PY
fi
if [ -f "$DEST/index.manifest.json" ]; then
  python3 - "$DEST/index.manifest.json" << 'PY'
import json
import sys
path = sys.argv[1]
data = json.loads(open(path, encoding="utf-8").read())
data["name"] = "ASEAN 2031"
data["short_name"] = "ASEAN 2031"
data["start_url"] = "./index.html"
data["scope"] = "./"
icons = data.get("icons", [])
if isinstance(icons, list):
    for icon in icons:
        src = str(icon.get("src", ""))
        if src.startswith("/"):
            icon["src"] = src.lstrip("/")
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, separators=(",", ":"))
    handle.write("\n")
PY
  cp "$DEST/index.manifest.json" "$DEST/manifest.webmanifest"
fi
if [ -f "$DEST/index.html" ] && ! grep -q 'id="status-title"' "$DEST/index.html"; then
  python3 - "$DEST/index.html" << 'PY'
import sys
path = sys.argv[1]
html = open(path, encoding="utf-8").read()
needle = '<div id="status">'
title = needle + '\n\t\t\t<p id="status-title" style="font-family: sans-serif; font-size: 28px; letter-spacing: 0.08em; margin: 0 0 16px;">ASEAN 2031</p>'
if needle in html:
    html = html.replace(needle, title, 1)
    open(path, "w", encoding="utf-8").write(html)
PY
fi
if ! grep -q 'serviceWorker.register("sw.js")' "$DEST/index.html"; then
  sed -i 's#</body>#<script>if("serviceWorker" in navigator){navigator.serviceWorker.register("sw.js");}</script></body>#' "$DEST/index.html"
fi
cp "$ROOT/web/audio_unlock.js" "$DEST/audio_unlock.js"
if [ -f "$DEST/index.html" ] && ! grep -q 'audio_unlock.js' "$DEST/index.html"; then
  python3 - "$DEST/index.html" << 'PY'
import sys
path = sys.argv[1]
html = open(path, encoding="utf-8").read()
needle = "<head>"
tag = '<head>\n\t\t<script src="audio_unlock.js"></script>'
if needle not in html:
    raise SystemExit("finish_web_export: index.html has no head")
open(path, "w", encoding="utf-8").write(html.replace(needle, tag, 1))
PY
fi
cp "$ROOT/tools/brotli_host.conf" "$DEST/brotli_host.conf"
if [ -n "$AUDIO_SRC" ]; then
  if [ ! -d "$AUDIO_SRC/music" ] && [ ! -d "$AUDIO_SRC/barks" ]; then
    echo "finish_web_export: audio source has no music or barks"
    exit 1
  fi
  mkdir -p "$DEST/audio"
  if [ -d "$AUDIO_SRC/music" ]; then
    rm -rf "$DEST/audio/music"
    cp -R "$AUDIO_SRC/music" "$DEST/audio/music"
  fi
  if [ -d "$AUDIO_SRC/barks" ]; then
    rm -rf "$DEST/audio/barks"
    cp -R "$AUDIO_SRC/barks" "$DEST/audio/barks"
  fi
  if [ -f "$AUDIO_SRC/manifest.json" ]; then
    cp "$AUDIO_SRC/manifest.json" "$DEST/audio/manifest.json"
  fi
  if [ -d "$AUDIO_SRC/announcer" ]; then
    rm -rf "$DEST/audio/announcer"
    cp -R "$AUDIO_SRC/announcer" "$DEST/audio/announcer"
  fi
  # music/user/ is fetched when a song starts, not with the startup clip list.
  find "$DEST/audio/music" "$DEST/audio/barks" -type f -name '*.ogg' ! -path '*/music/user/*' 2>/dev/null \
    | sed "s#^$DEST/audio/##" \
    | sort > "$DEST/audio/clips.txt"
  if ! grep -q "music/menu.ogg" "$DEST/audio/clips.txt"; then
    echo "finish_web_export: clips.txt missing menu"
    exit 1
  fi
  if ! grep -q "barks/crimson_sapper_select_2.ogg" "$DEST/audio/clips.txt"; then
    echo "finish_web_export: clips.txt is missing the sapper select line"
    exit 1
  fi
  : > "$DEST/audio/.gdignore"
fi
if [ -n "$CAMEO_SRC" ]; then
  if [ ! -d "$CAMEO_SRC" ]; then
    echo "finish_web_export: cameo source is not a directory"
    exit 1
  fi
  rm -rf "$DEST/cameos"
  mkdir -p "$DEST/cameos"
  find "$CAMEO_SRC" -maxdepth 1 -type f -name '*.webp' -exec cp {} "$DEST/cameos/" \;
  find "$DEST/cameos" -maxdepth 1 -type f -name '*.webp' -printf '%f\n' | sort > "$DEST/cameos/index.txt"
  : > "$DEST/cameos/.gdignore"
  if ! grep -q "militia.webp" "$DEST/cameos/index.txt"; then
    echo "finish_web_export: cameo index is missing militia"
    exit 1
  fi
fi
if [ -n "$MENU_SRC" ]; then
  if [ ! -d "$MENU_SRC" ]; then
    echo "finish_web_export: menu source is not a directory"
    exit 1
  fi
  if [ ! -d "$MENU_SRC/cinematic" ]; then
    echo "finish_web_export: menu source has no cinematic folder"
    exit 1
  fi
  rm -rf "$DEST/ui/menu"
  mkdir -p "$DEST/ui/menu/cinematic"
  find "$MENU_SRC/cinematic" -maxdepth 1 -type f \( -name '*.webp' -o -name '*.png' -o -name '*.jpg' \) -exec cp {} "$DEST/ui/menu/cinematic/" \;
  find "$DEST/ui/menu/cinematic" -maxdepth 1 -type f \( -name '*.webp' -o -name '*.png' -o -name '*.jpg' \) -printf 'cinematic/%f\n' | sort > "$DEST/ui/menu/index.txt"
  : > "$DEST/ui/menu/.gdignore"
  : > "$DEST/ui/menu/cinematic/.gdignore"
fi
if [ -n "$TERRAIN_SRC" ]; then
  if [ ! -d "$TERRAIN_SRC" ]; then
    echo "finish_web_export: terrain source is not a directory"
    exit 1
  fi
  mkdir -p "$DEST/terrain"
  find "$TERRAIN_SRC" -maxdepth 1 -type f -name '*.webp' -exec cp {} "$DEST/terrain/" \;
  : > "$DEST/terrain/.gdignore"
fi
if [ -n "$UI_SRC" ]; then
  if [ ! -d "$UI_SRC/frames" ] || [ ! -d "$UI_SRC/icons" ]; then
    echo "finish_web_export: ui source needs frames and icons"
    exit 1
  fi
  mkdir -p "$DEST/ui/frames" "$DEST/ui/icons" "$DEST/ui/emblems"
  find "$UI_SRC/frames" -maxdepth 1 -type f -name '*.webp' -exec cp {} "$DEST/ui/frames/" \;
  find "$UI_SRC/icons" -maxdepth 1 -type f -name '*.webp' -exec cp {} "$DEST/ui/icons/" \;
  if [ -d "$UI_SRC/emblems" ]; then
    find "$UI_SRC/emblems" -maxdepth 1 -type f -name '*.webp' -exec cp {} "$DEST/ui/emblems/" \;
  fi
  : > "$DEST/ui/frames/.gdignore"
  : > "$DEST/ui/icons/.gdignore"
  : > "$DEST/ui/emblems/.gdignore"
fi
if ! grep -q "brotli" "$DEST/brotli_host.conf" || ! grep -q "wasm" "$DEST/brotli_host.conf"; then
  echo "finish_web_export: brotli host config is missing"
  exit 1
fi
if ! grep -q "GODOT_THREADS_ENABLED = false" "$DEST/index.html"; then
  echo "finish_web_export: export is not single-threaded"
  exit 1
fi
for f in index.html index.wasm index.pck index.manifest.json sw.js manifest.webmanifest brotli_host.conf audio_unlock.js; do
  if [ ! -f "$DEST/$f" ]; then
    echo "finish_web_export: missing $f"
    exit 1
  fi
done
echo "web export files:"
ls -la "$DEST"
