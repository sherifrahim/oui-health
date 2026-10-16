# Finding 0001 — Galaxy Wearable gates the experience on `Build.MANUFACTURER`

- **Target:** `com.samsung.android.app.watchmanager` — Galaxy Wearable **v2.2.72.26092361**, base
  split (single `classes.dex`, 7.76 MB), compiled against One UI 17 / SDK 37, `sharedUserId`
  `com.samsung.accessory.wmanager`. Per-model plugins are **not** in this APK (see §Scope).
- **Category:** **(A) on-device satisfiable** (the manufacturer gate), with **(C)** server/account
  edges that are not.
- **Feature affected:** broad — pairing, Samsung-Account token, unified permissions, plugin
  download/update, and the welcome/UI flow all branch on `isSamsungDevice()`.
- **Status:** **CONFIRMED** by decompilation (androguard). Method bodies below are the decompiled
  source, not inference.

## The whole gate collapses to one value

`isSamsungDevice()` is the hub, and it resolves to a single system value.

```java
// com.samsung.android.app.twatchmanager.AppUtil  (and .global.utils.PlatformUtils, identical)
public static boolean isSamsungDevice() {
    if (!isSamsungGEDModel()) {
        return "SAMSUNG".equalsIgnoreCase(StaticConstWrapper.getManufacturer());
    }
    return false;
}

// com.samsung.android.app.twatchmanager.util.StaticConstWrapper   ← THE chokepoint
public static final String getManufacturer() {
    return android.os.Build.MANUFACTURER;
}

// isSamsungGEDModel() only matches two 2014 Google-Edition phones (SM-G900FG, GT-I9505G),
// so on any modern phone it returns false and the line above is the entire decision.
```

So **`isSamsungDevice()` ≡ `Build.MANUFACTURER.equalsIgnoreCase("SAMSUNG")`**. One lever flips the
whole host into "Samsung" mode.

## Samsung already ships a non-Samsung support rule

The host has an explicit, per-model notion of running off-Samsung:

```java
// com.samsung.android.app.twatchmanager.connectionmanager.define.WearableDevice
public final boolean isSupportedNonSamsungDevice() {
    if (rule != null) return PlatformUtils.isSamsungDevice() || rule.i;  // rule.i = allowed off-Samsung
    return true;
}
```

Each watch model carries a `rule` with a boolean (`.i`) saying whether it is allowed on a
non-Samsung phone. That rule table (from `provideWearableDeviceRuleFactory`) is a second lever: a
watch can be made "supported" either by satisfying `isSamsungDevice()` or by its rule.

## What `isSamsungDevice()` actually gates (confirmed caller list, 48 call sites)

Grouped by what the user loses on a non-Samsung phone:

- **Pairing / connection:** `DevicePairingManager.requestPairing`, `PairingFragment*`,
  `WatchDataManager.sendInitialData`, `DeviceListHelper.addPairedDevice/addRestoredDevice`.
- **Samsung Account + token (server-backed, category C):** `SALoginHelper.requestSALogin`,
  `QAStoreTokenGenerator.{requestSATokenDataOnBackground,tokenProcessAfterSignIn}`,
  `SAGUIDHelper.requestGUIDProcess`.
- **Permissions:** `CDMUnifiedPermissionHelper.checkSupportUnifiedPermission`,
  `PermissionUtils.{canRequestPermissionCorrection,requestPermissionCorrection}`.
- **Plugin download / update:** `UpdateManager.checkUpdatablePackages`, `UpdatePackageSet.init`,
  `DownloadInstallCoordinator`, `CNDownloadHelper`, `InstallationUtils.getPackageInstallerInfo`.
- **UI / misc:** `WelcomeFragment`, `NetworkUsageManager`, `ContactUsUtils`, `SmartSwitchManager`,
  SAK verification (`VerificationManager.isSupportSAKVerify`).

## `SemFloatingFeature` is a dual-library fallback (confirmed)

```java
// selibrary/FloatingFeature  (Samsung path)
public boolean getEnableStatus(String k){ return SemFloatingFeature.getInstance().getBoolean(k); }
// sdllibrary/FloatingFeature  (fallback path)
public boolean getEnableStatus(String k){ return FloatingFeature.getInstance().getEnableStatus(k); }
```

A `FloatingFeatureFactory` picks the impl behind a `FloatingFeatureInterface`. On stock Android the
real `SemFloatingFeature` is absent, so the fallback returns defaults. **But the base split only
queries 3 generic framework flags** (`..._FOLDABLE_TYPE_FLIP`, `..._ENABLE_SURVEY_MODE`,
`..._3D_SURFACE_TRANSITION_FLAG`) — none are watch features. The watch-feature flags live in the
per-model plugins (next finding).

## Un-gating strategy

- **Primary (category A):** make `isSamsungDevice()` true. Cleanest levers, in order:
  1. hook `StaticConstWrapper.getManufacturer()` (or `AppUtil.isSamsungDevice()` /
     `PlatformUtils.isSamsungDevice()`) to return the Samsung value — one method, flips all 48 call
     sites. On rooted phones an LSPosed module; otherwise a repackaged host (breaks signing — see
     risks).
  2. or set the `WearableDevice` rule's `.i = true` for your model, which un-gates the
     connection-support path without touching the manufacturer check.
- **Floating features (category A, later):** enumerate the real `SEC_FLOATING_FEATURE_*` keys from
  the plugins and have the fallback `FloatingFeature` return the Samsung defaults for exactly those.
- **Samsung Account token (category C):** `SALoginHelper`/`QAStoreTokenGenerator` want a
  server-issued token; cannot be forged on-device. Health data routes around this via Health
  Connect; anything strictly needing the token is a documented limit.

## Scope / risks

- **Base split only.** Per-model logic is in downloaded plugins (`com.samsung.wearable.watch6plugin`
  / `watch7plugin`, via `setupwizard/downloadinstall`). The feature flags to satisfy are there —
  analyze next (roadmap Phase 1).
- Repackaging the host breaks its signature and its `sharedUserId com.samsung.accessory.wmanager`
  tie to the plugins; prefer a hook over a resign where possible.
- Reproduce: `LOGURU_LEVEL=CRITICAL python3 tools/scripts/decompile_targets.py \
  tools/inputs/GalaxyWearable.apk isSamsungDevice getManufacturer isSupportedNonSamsungDevice`.
