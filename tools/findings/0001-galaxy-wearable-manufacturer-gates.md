# Finding 0001 — Galaxy Wearable gates the experience on `isSamsungDevice()`

- **Target:** `com.samsung.android.app.watchmanager` — Galaxy Wearable, base split
  (`GalaxyWearable.apk`, single `classes.dex`, 7.76 MB). Per-model plugins are **not** in this
  APK (see Limits).
- **Category:** mostly **(A) on-device satisfiable**, with **(C)** server/account edges.
- **Feature affected:** broad — the host app's feature set, pairing flow and Samsung-Account token
  acquisition all branch on whether it believes it is on a Samsung phone.
- **Date / analyst:** 2026-10-16, first static pass (string table + class descriptors; no
  decompiled control flow yet — the REA/JADX engine download was blocked in this environment).

## Gates found

### G1 — `FeatureUtil.isSamsungDevice()` (primary manufacturer gate)

- **Class / method:** `Lcom/samsung/android/app/twatchmanager/featureutil/FeatureUtil;`
  → `isSamsungDevice()`, plus `isSamsungDeviceWithCustomBinary()` and `isSamsungPlatform`.
- **Mechanism:** Build fingerprint (`Build.MANUFACTURER`) → boolean.
- **Evidence (confirmed present in dex string table):**
  ```
  isSamsungDevice() MANUFACTURER :
  isSamsungDevice() return false
  isSamsungPlatform :
  isSamsungDevice=
  isSamsungDeviceWithCustomBinary, res [
  request token to SAClient/WebView isSamsungDevice :     ← account token path also branches here
  ```
- **Inferred (needs decompile to confirm):** on `MANUFACTURER != "samsung"` the method returns
  `false`, and callers across the host disable features / change the pairing + token path.

### G2 — `FloatingFeatureFactory` → `SemFloatingFeature` (One UI feature flags)

- **Classes:** `Lcom/samsung/android/app/twatchmanager/factory/FloatingFeatureFactory;`,
  `Lcom/samsung/android/app/watchmanager/selibrary/FloatingFeature;`,
  `.../sdllibrary/FloatingFeature;`, backed by
  `com.samsung.android.feature.SemFloatingFeature` and `android.os.SemSystemProperties`.
- **Mechanism:** One UI's feature-flag store (`SEC_FLOATING_FEATURE_*`, `getEnableStatus`,
  `getString`). The class does not exist on stock Android.
- **Evidence (confirmed):** descriptors above + tokens `SEC_FLOATING_FEATURE_*`, `getEnableStatus`.
- **Inferred:** the factory returns a real impl on Samsung and a default/stub elsewhere, so every
  feature keyed off a floating-feature flag reads its default (usually "off") on a non-Samsung
  phone.

### G3 — Samsung Account + server entitlement (the hard edges)

- **Account:** `com.osp.app.signin`, intents `com.msc.action.samsungaccount.REQUEST_ACCESSTOKEN` /
  `SIGNIN_POPUP`, `com.samsung.account.SAMSUNGACCOUNT_*`.
- **Servers:** `https://account.samsung.com/accounts/wmanager/signInGate`,
  `https://regi.di.atlas.samsung.com`, `https://dc.di.atlas.samsung.com`,
  `https://vas.samsungapps.com/stub/`.
- **Mechanism:** account presence + server-issued tokens. Partly **(C)**: a valid token is minted
  server-side and cannot be forged on-device.

## Un-gating strategy (to implement + confirm)

- **G1:** satisfiable on-device. Options, cheapest first: (a) run the host inside a compatibility
  layer that reports `Build.MANUFACTURER = "samsung"` to these specific callers; (b) patch
  `FeatureUtil.isSamsungDevice()` to return `true` in a repackaged build; (c) reimplement the host
  flow in oui-health and skip the gate entirely. Confirm each caller's non-Samsung branch by
  decompiling `FeatureUtil` and its callers first.
- **G2:** provide a stand-in `SemFloatingFeature` that answers the specific `SEC_FLOATING_FEATURE_*`
  keys the watch features need (enumerate them from the plugins). This is the load-bearing piece
  for actual feature parity, not just passing the manufacturer check.
- **G3:** real limit for anything needing a valid Samsung-account token. Where a feature only needs
  an account *object* locally, satisfiable; where it needs a server token, document as a limit and
  route the underlying capability (e.g. health data) through the open path (Health Connect / Wear
  OS data layer) instead.

## Limits / risks

- **Only the base split was analyzed.** The per-model feature logic lives in separate plugin
  packages downloaded at pairing — strings seen here: `com.samsung.wearable.watch6plugin`,
  `com.samsung.wearable.watch7plugin`, via `setupwizard/downloadinstall`. The real feature flags to
  satisfy for G2 are inside those plugins; they must be analyzed next.
- **No decompiled control flow yet.** Branch behaviour is inferred from log/identifier strings;
  confirm with REA `inspect-android-method FeatureUtil isSamsungDevice` once the engine is set up
  (`tools/scripts/setup-rea.sh`).
- Repackaging/patching the real host (strategy b) breaks its signature — downstream signature
  checks and Samsung-signed IPC may then fail. Prefer (a) or (c) where possible.
