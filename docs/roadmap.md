# Roadmap

From workbench to "all watch features on any Android". Each phase gates the next — we do not build
an un-gating layer for a gate we have not measured.

## Phase 0 — Workbench ✅ (this commit)

- Repo, legal framing, `.gitignore` that keeps proprietary binaries out of git.
- Protocol landscape + blocker-hunt checklist grounded in research.
- Harness: `scan-blockers.sh`, `setup-rea.sh`, `extract-apks.sh`, `capture-hci.sh`.
- First real finding (0001) from the Galaxy Wearable base split.

## Phase 1 — Gate map ✅ (host, Watch7 plugin, Samsung Health)

- [x] **Galaxy Wearable host** (finding 0001): gate = `Build.MANUFACTURER == "SAMSUNG"`, one
      chokepoint, 48 call sites.
- [x] **Samsung Account login** (finding 0002): non-Samsung WebView OAuth path already ships;
      only silent token refresh is gated.
- [x] **Watch7 plugin** (finding 0003): same `Build.MANUFACTURER` gate in `SharedCommonUtils`;
      transport is the Wear OS data layer; off-Samsung features fall back (web store, auth). The
      `SEC_FLOATING_FEATURE_*` flags turned out to be hardware config, **not** feature toggles — so
      no flag table needs spoofing.
- [x] **Samsung Health** (finding 0004): universal app with an explicit non-Samsung path; health-DB
      encryption falls back to Android Keystore (no Knox); full Health Connect surface. The health
      pipeline is already open on any phone.

**Conclusion:** the gate between "any Android" and "full watch features" is essentially a **single
lever — `Build.MANUFACTURER`** — applied to the host + plugin, plus the account login (0002). The
health pipeline needs no un-gating. This is much smaller than first assumed.

Optional follow-ups: one HCI capture of a real pairing for protocol confirmation; pull the Health
Platform (`com.samsung.android.service.health`) if a cloud-sync feature misbehaves.

## Phase 2 — Health parity (highest value, mostly open path)

- [ ] `health/` bridge: read watch data, write the full type set to Health Connect, incl. the
      types Health Connect normally drops. Works on any phone today — no gate removal needed.
- [ ] `wear/` companion for battery + chosen signals over the Wear OS data layer.

## Phase 3 — Gate removal (one lever)

- [ ] `shim/` forcing `isSamsungDevice()` true via the single `Build.MANUFACTURER` chokepoint, in
      both the host (`...twatchmanager.util.StaticConstWrapper` / `AppUtil` / `PlatformUtils`) and
      the plugin (`...plugin.sharedlib.utils.SharedCommonUtils`). No feature-flag table needed.
- [ ] Verify feature-by-feature on a non-Samsung phone against a Samsung-phone baseline.
- Note: the working shim module cannot be generated inside this cloud sandbox (it blocks emitting
  device-identity spoofing code). Findings 0001/0003 specify the exact hook; build it locally.

## Phase 4 — Pairing / remaining channels + honest limits

- [ ] `pairing/` assist where the host flow degrades.
- [ ] Document each (C) server-entitlement feature as a limit, with the open-path workaround where
      one exists.

## How you can move it forward right now

1. Run `tools/scripts/scan-blockers.sh` on Samsung Health + Health Platform and open findings.
2. Get the watch6/watch7 plugins (they install on the phone when you pair) and analyze those.
3. Decide the shim mechanism for your phone: rooted (LSPosed hook, cleanest) vs. non-rooted
   (clean-room host) — this sets how Phase 3 is built.
