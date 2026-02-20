#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="org.savoba.iDSACompanion"

# ── Argument check ────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <path-to-hero.json>"
  exit 1
fi

FILE="$1"

if [[ ! -f "$FILE" ]]; then
  echo "Error: file not found: $FILE"
  exit 1
fi

# ── Resolve booted simulator ──────────────────────────────────────────────────
UDID=$(xcrun simctl list devices booted --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for devs in data['devices'].values():
    for d in devs:
        if d['state'] == 'Booted':
            print(d['udid'])
            exit(0)
")

if [[ -z "$UDID" ]]; then
  echo "Error: no booted simulator found. Launch one from Xcode or Simulator.app first."
  exit 1
fi

DEVICE_NAME=$(xcrun simctl list devices booted --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for devs in data['devices'].values():
    for d in devs:
        if d['state'] == 'Booted':
            print(d['name'])
            exit(0)
")

echo "Simulator : $DEVICE_NAME ($UDID)"

# ── Resolve app container ─────────────────────────────────────────────────────
CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data 2>/dev/null || true)

if [[ -z "$CONTAINER" ]]; then
  echo "Error: app '$BUNDLE_ID' not found on this simulator."
  echo "Build and run the app at least once before uploading files."
  exit 1
fi

DEFAULT_DEST="$CONTAINER/Documents"

# ── Ask for target path ───────────────────────────────────────────────────────
echo ""
echo "App container : $CONTAINER"
read -rp "Target path   [${DEFAULT_DEST}]: " DEST
DEST="${DEST:-$DEFAULT_DEST}"

# ── Copy ──────────────────────────────────────────────────────────────────────
mkdir -p "$DEST"
cp "$FILE" "$DEST/$(basename "$FILE")"

echo ""
echo "Done. Uploaded to:"
echo "  $DEST/$(basename "$FILE")"
