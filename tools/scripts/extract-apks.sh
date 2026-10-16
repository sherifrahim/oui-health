#!/usr/bin/env bash
# extract-apks.sh — pull the Samsung companion APKs from YOUR OWN device.
#
# Run this against a device you own (a Samsung phone that is paired with your
# watch gives the richest binaries, but the APKs install on any phone). It only
# copies package files off the device; it changes nothing on it.
#
# Requires adb on PATH and USB debugging enabled on the phone.
set -euo pipefail

DEST="${1:-tools/inputs}"
mkdir -p "$DEST"
command -v adb >/dev/null || { echo "!! install platform-tools (adb) first"; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "!! no device — enable USB debugging and authorize this host"; exit 1; }

# The packages that make up the phone-side suite. Confirm/adjust against your device.
PKGS=(
  com.samsung.android.app.watchmanager   # Galaxy Wearable (host)
  com.sec.android.app.shealth            # Samsung Health
  com.samsung.android.service.health     # Health Platform bridge
  com.samsung.android.wear.shealth       # (if present) watch health relay
  com.samsung.wearable.watch6plugin      # per-model plugins (install as paired)
  com.samsung.wearable.watch7plugin
)

for pkg in "${PKGS[@]}"; do
  if ! adb shell pm path "$pkg" >/dev/null 2>&1; then
    echo "-- $pkg: not installed, skipping"; continue
  fi
  echo "== $pkg"; mkdir -p "$DEST/$pkg"
  # A package can be split into base + config/feature APKs; pull them all.
  adb shell pm path "$pkg" | sed 's/package://' | tr -d '\r' | while read -r p; do
    out="$DEST/$pkg/$(basename "$p")"
    echo "   $p -> $out"
    adb pull "$p" "$out" >/dev/null
  done
done
echo ">> done. (Contents of $DEST are gitignored — binaries never get committed.)"
