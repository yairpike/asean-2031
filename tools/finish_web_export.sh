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
  cp "$DEST/index.manifest.json" "$DEST/manifest.webmanifest"
fi
if ! grep -q "serviceWorker" "$DEST/index.html"; then
  sed -i 's#</body>#<script>if("serviceWorker" in navigator){navigator.serviceWorker.register("sw.js");}</script></body>#' "$DEST/index.html"
fi
if ! grep -q "GODOT_THREADS_ENABLED = false" "$DEST/index.html"; then
  echo "finish_web_export: export is not single-threaded"
  exit 1
fi
for f in index.html index.wasm index.pck index.manifest.json sw.js manifest.webmanifest; do
  if [ ! -f "$DEST/$f" ]; then
    echo "finish_web_export: missing $f"
    exit 1
  fi
done
echo "web export files:"
ls -la "$DEST"
