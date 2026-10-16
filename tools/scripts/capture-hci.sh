#!/usr/bin/env bash
# capture-hci.sh — pull the Bluetooth HCI snoop log from YOUR OWN phone, so the
# live watch<->phone protocol can be decoded in Wireshark (the Gadgetbridge method).
#
# On the phone: Settings > Developer options > "Enable Bluetooth HCI snoop log"
# (set to "Enabled"/"Filtered"), then reproduce the watch action you care about,
# THEN run this. Requires adb.
set -euo pipefail
command -v adb >/dev/null || { echo "!! install platform-tools (adb) first"; exit 1; }

OUT="${1:-tools/work/hci/btsnoop_$(date +%Y%m%d_%H%M%S).log}"
mkdir -p "$(dirname "$OUT")"

# Location varies by OEM/Android version; try the common ones + the bugreport fallback.
CANDIDATES=(
  /data/misc/bluetooth/logs/btsnoop_hci.log
  /sdcard/btsnoop_hci.log
  /data/log/bt/btsnoop_hci.log
)
for c in "${CANDIDATES[@]}"; do
  if adb shell "test -f $c" 2>/dev/null; then
    echo ">> pulling $c"; adb pull "$c" "$OUT" && { echo ">> saved $OUT"; exit 0; }
  fi
done

echo ">> direct path not found; falling back to bugreport (contains the snoop log)"
BR="tools/work/hci/bugreport_$(date +%Y%m%d_%H%M%S).zip"
adb bugreport "$BR"
echo ">> extract FS/data/misc/bluetooth/logs/btsnoop_hci.log from $BR"
echo ">> open in Wireshark; filter traffic to/from the watch's BD_ADDR and map actions to packets."
