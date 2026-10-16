#!/usr/bin/env bash
# scan-blockers.sh — first-pass hunt for manufacturer/feature gates in an APK.
#
# Works with nothing but `unzip`, `strings`, `grep` (the pass that produced
# findings/0001). If `jadx` or `rea` is on PATH it will also decompile for
# method-level context. Never executes the APK; only reads it.
#
# Usage: tools/scripts/scan-blockers.sh path/to/App.apk [outdir]
set -euo pipefail

APK="${1:?usage: scan-blockers.sh App.apk [outdir]}"
OUT="${2:-tools/work/$(basename "${APK%.*}")}"
mkdir -p "$OUT"
echo ">> target: $APK"
echo ">> work:   $OUT"

# 1. Extract dex(es) + manifest into an isolated dir (never run anything from it).
unzip -o -q "$APK" 'classes*.dex' AndroidManifest.xml -d "$OUT" || true
DEXES=$(ls "$OUT"/classes*.dex 2>/dev/null || true)
[ -z "$DEXES" ] && { echo "!! no classes.dex (split APK with no code?) — try the base split"; }

STR="$OUT/dex-strings.txt"
: > "$STR"
for d in $DEXES; do strings -n 5 "$d" >> "$STR"; done
echo ">> dex strings: $(wc -l < "$STR") lines"

echo; echo "== manifest: package / Samsung permissions / features =="
{ strings -e l -n 4 "$OUT/AndroidManifest.xml"; strings -n 4 "$OUT/AndroidManifest.xml"; } 2>/dev/null \
  | grep -iE 'samsung|com\.sec|watchmanager|hostmanager|\.permission\.|feature' | sort -u

echo; echo "== gate pattern counts =="
for pat in MANUFACTURER 'ro.product' hasSystemFeature 'com.sec.feature' 'com.samsung.feature' \
           SemSystemProperties SemFloatingFeature 'com.osp.app.signin' authfw SIGNATURE \
           isSamsung checkEntitlement FloatingFeature DeviceUtil FeatureUtil; do
  printf '%6s  %s\n' "$(grep -ic "$pat" "$STR" || true)" "$pat"
done

echo; echo "== gate literals (isSamsung* / feature flags / servers) =="
grep -iE 'isSamsung|SEC_FLOATING_FEATURE_|com\.(sec|samsung)\.feature|https://[a-z.]*samsung' "$STR" | sort -u | head -60

echo; echo "== candidate gate classes =="
grep -oE 'Lcom/samsung/[A-Za-z0-9/_]*(Feature|Device|Compat|Support|Floating)[A-Za-z0-9/_]*;' "$STR" | sort -u | head -40

# 2. Optional deep pass if a decompiler is available.
if command -v rea >/dev/null 2>&1; then
  echo; echo "== REA: inspecting FeatureUtil (evidence-bound) =="
  rea search-android-classes "$APK" FeatureUtil || true
  echo "   drill in with: rea inspect-android-method '$APK' <class> isSamsungDevice"
elif command -v jadx >/dev/null 2>&1; then
  echo; echo "== jadx: decompiling for method-level grep =="
  jadx -q -d "$OUT/src" "$APK" || true
  grep -rInE 'Build\.MANUFACTURER|isSamsungDevice|hasSystemFeature|SemFloatingFeature' "$OUT/src" | head -40
else
  echo; echo "!! no rea/jadx on PATH — run tools/scripts/setup-rea.sh for method-level control flow"
fi

echo; echo ">> done. Write up each real gate in tools/findings/ (see TEMPLATE.md)."
