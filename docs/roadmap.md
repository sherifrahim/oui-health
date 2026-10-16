# Roadmap

From workbench to "all watch features on any Android". Each phase gates the next — we do not build
an un-gating layer for a gate we have not measured.

## Phase 0 — Workbench ✅ (this commit)

- Repo, legal framing, `.gitignore` that keeps proprietary binaries out of git.
- Protocol landscape + blocker-hunt checklist grounded in research.
- Harness: `scan-blockers.sh`, `setup-rea.sh`, `extract-apks.sh`, `capture-hci.sh`.
- First real finding (0001) from the Galaxy Wearable base split.

## Phase 1 — Complete the gate map (needs your inputs)

- [ ] Analyze **Samsung Health** (`com.sec.android.app.shealth`) and **Health Platform**
      (`com.samsung.android.service.health`) — the health gates + Health-Connect writer behaviour.
- [ ] Pull and analyze the **per-model plugins** (`com.samsung.wearable.watch6plugin` /
      `watch7plugin`) — this is where the real `SEC_FLOATING_FEATURE_*` keys to satisfy live.
- [ ] Decompile `FeatureUtil.isSamsungDevice()` and its callers with REA to confirm branch
      behaviour (currently inferred).
- [ ] Optional: one HCI capture of a real pairing + a health sync, for protocol-level confirmation.
- **Exit:** every gate between "any Android" and "full features" is written up in `tools/findings/`
  and sorted into (A) satisfiable / (B) missing-channel / (C) server-limit.

## Phase 2 — Health parity (highest value, mostly open path)

- [ ] `health/` bridge: read watch data, write the full type set to Health Connect, incl. the
      types Health Connect normally drops. Works on any phone today — no gate removal needed.
- [ ] `wear/` companion reused from Halo for battery + chosen signals.

## Phase 3 — Gate removal (the (A) findings)

- [ ] `shim/` answering `isSamsungDevice()` + the enumerated `SemFloatingFeature` keys to the
      specific callers, confirmed against Phase 1 decompilation.
- [ ] Verify feature-by-feature on a non-Samsung phone against a Samsung-phone baseline.

## Phase 4 — Pairing / remaining channels + honest limits

- [ ] `pairing/` assist where the host flow degrades.
- [ ] Document each (C) server-entitlement feature as a limit, with the open-path workaround where
      one exists.

## How you can move it forward right now

1. Run `tools/scripts/scan-blockers.sh` on Samsung Health + Health Platform and open findings.
2. Get the watch6/watch7 plugins (they install on the phone when you pair) and analyze those.
3. Decide the shim mechanism for your phone: rooted (LSPosed hook, cleanest) vs. non-rooted
   (clean-room host) — this sets how Phase 3 is built.
