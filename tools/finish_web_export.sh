#!/usr/bin/env bash
# Copy the service worker next to a single-threaded Compatibility export and
# register it. Does not add cross-origin isolation headers.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$ROOT/build/web}"
if [ -f "$DEST/index.service.worker.js" ]; then
  cp "$DEST/index.service.worker.js" "$DEST/sw.js"
else
  cp "$ROOT/web/sw.js" "$DEST/sw.js"
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
