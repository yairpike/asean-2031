#!/usr/bin/env bash
# Copy the service worker next to a single-threaded Compatibility export and
# register it. Does not add cross-origin isolation headers.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$ROOT/build/web}"
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
cp "$ROOT/tools/brotli_host.conf" "$DEST/brotli_host.conf"
AUDIO_SRC="/cursor/stores/bc-03b4e731-23cd-492a-9d17-7e9a1ed71677/internal/assets/audio"
if [ -d "$AUDIO_SRC/music" ] || [ -d "$AUDIO_SRC/barks" ]; then
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
fi
if ! grep -q "brotli" "$DEST/brotli_host.conf" || ! grep -q "wasm" "$DEST/brotli_host.conf"; then
  echo "finish_web_export: brotli host config is missing"
  exit 1
fi
if ! grep -q "GODOT_THREADS_ENABLED = false" "$DEST/index.html"; then
  echo "finish_web_export: export is not single-threaded"
  exit 1
fi
for f in index.html index.wasm index.pck index.manifest.json sw.js manifest.webmanifest brotli_host.conf; do
  if [ ! -f "$DEST/$f" ]; then
    echo "finish_web_export: missing $f"
    exit 1
  fi
done
echo "web export files:"
ls -la "$DEST"
