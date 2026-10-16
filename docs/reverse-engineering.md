# Running the workbench

Everything here runs **locally**, on binaries **you** supply, and commits nothing proprietary.

## 0. Get the binaries (you, once)

- **APKs:** `tools/scripts/extract-apks.sh` pulls the companion suite off a device you own via
  `adb`. Or drop APKs you obtained legally into `tools/inputs/`. The richest source is a Samsung
  phone already paired with your watch (its per-model plugins are installed).
- **Live traffic (optional but powerful):** `tools/scripts/capture-hci.sh` pulls the Bluetooth HCI
  snoop log so you can watch the real watch⇄phone protocol in Wireshark — the standard
  [Gadgetbridge method](https://codeberg.org/Freeyourgadget/Gadgetbridge/wiki/BT-Protocol-Reverse-Engineering).

## 1. First pass — the blocker hunt (no engine needed)

```bash
tools/scripts/scan-blockers.sh tools/inputs/GalaxyWearable.apk
```

Uses only `unzip` + `strings` + `grep`. Produces the manifest's Samsung permissions/features, gate
pattern counts, the real gate literals, and candidate gate classes. This is exactly the pass that
produced [`tools/findings/0001`](../tools/findings/0001-galaxy-wearable-manufacturer-gates.md).

Work through the checklist in [`blocker-hunt.md`](blocker-hunt.md) and write up each real gate in
`tools/findings/` using the template.

## 2. Second pass — evidence-bound decompilation (REA)

String literals locate a gate; to see the **branch logic** you need decompiled methods.

```bash
tools/scripts/setup-rea.sh        # one-time: pins + verifies the JADX engine jar
export REA_JADX_MCP_JAR="$HOME/.local/share/rea/android/jadx-headless-mcp-0.7.1-all.jar"

rea inspect-android-package tools/inputs/GalaxyWearable.apk
rea search-android-classes  tools/inputs/GalaxyWearable.apk FeatureUtil
rea inspect-android-method  tools/inputs/GalaxyWearable.apk \
    com.samsung.android.app.twatchmanager.featureutil.FeatureUtil isSamsungDevice
```

REA returns results tied to the artifact and the evidence that produced them — paste that evidence
(with its id) into the finding. You can also register REA as an MCP server for your agent
(`npx rea-agents setup`) and ask in natural language; it uses the same engine.

> In some sandboxes the engine-jar download in step 2 is blocked (it is a third-party prebuilt
> binary). That is expected — run `setup-rea.sh` on your own machine. The step-1 pass needs none of
> this and already yields real findings.

## 3. Confirm against live traffic

For anything protocol-level (not just a static gate), correlate with the HCI capture: filter to the
watch's BD_ADDR in Wireshark, trigger the feature on the Samsung phone, and map the packets. Record
the frames as evidence in the finding.

## Ground rules

- **Evidence or it didn't happen.** Every finding points at decompiled lines, an REA evidence id,
  or captured frames. A gate you can't point at is unconfirmed.
- **Mark confirmed vs inferred.** String presence ≠ branch behaviour.
- **Nothing proprietary in git.** `.gitignore` keeps APKs, decompiled source, and captures out.
  Only our own words and our own interop code are committed.
