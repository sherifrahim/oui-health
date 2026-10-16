#!/usr/bin/env bash
# setup-rea.sh — one-time local setup of the REA reverse-engineering toolchain.
#
# REA (https://github.com/morluto/rea) drives JADX to decompile APKs and returns
# evidence-bound results. It does NOT bundle JADX; you fetch a pinned, SHA-256
# verified engine jar once. Run this on your own machine (it downloads a
# third-party prebuilt jar, which some sandboxes block — that is expected).
set -euo pipefail

# 1. A full JDK 17+ (needs the compiler module, not just a JRE).
command -v java >/dev/null || { echo "!! install a full JDK 17+ first"; exit 1; }
echo ">> java: $(java -version 2>&1 | head -1)"

# 2. Pinned JADX engine jar (digest from REA's src/android/JadxRelease.ts).
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/rea/android"
JAR="$DEST/jadx-headless-mcp-0.7.1-all.jar"
URL="https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar"
SHA="6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75"
mkdir -p "$DEST"
if [ ! -f "$JAR" ]; then curl -fL -o "$JAR" "$URL"; fi
echo "$SHA  $JAR" | sha256sum -c - || { echo "!! digest mismatch — do not use"; rm -f "$JAR"; exit 1; }
export REA_JADX_MCP_JAR="$JAR"
echo ">> REA_JADX_MCP_JAR=$JAR"

# 3. REA CLI (via npx, no global install needed).
echo ">> smoke test:"
npx -y rea-agents@latest --help | head -5 || true

cat <<EOF

Set this in your shell (or MCP server env) for every REA run:
  export REA_JADX_MCP_JAR="$JAR"

Then analyze an APK you supplied:
  rea inspect-android-package  tools/inputs/GalaxyWearable.apk
  rea search-android-classes   tools/inputs/GalaxyWearable.apk FeatureUtil
  rea inspect-android-method   tools/inputs/GalaxyWearable.apk \\
      com.samsung.android.app.twatchmanager.featureutil.FeatureUtil isSamsungDevice
EOF
