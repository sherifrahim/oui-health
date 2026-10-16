# Finding 0003 — Watch7 plugin: same gate, Wear-OS transport, non-Samsung fallbacks

- **Target:** `com.samsung.wearable.watch7plugin` (base.apk, 180 MB, 8 dex). Internally the
  **"waterplugin"** — the per-model companion for Galaxy Watch 7. Package root
  `com.samsung.android.app.shealth.watch...` + `com.samsung.android.waterplugin...` +
  `com.samsung.android.companionservice...`.
- **Category:** mostly **(A)** (same manufacturer lever) + **(B)** (features that fall back to a
  web/degraded path off-Samsung).
- **Status:** CONFIRMED (gate disassembled; feature surface and fallbacks from the string table).

## This plugin is the feature surface

Decompiled package roots show it carries most of what "the watch does":

- `companionservice/aidl/watchface`, `waterplugin/watchface/customization`,
  `watch/watchface/data` — **watch face** install/customization
- `companionservice/aidl/watchapps` — **watch app** management
- `companionapps/bixby`, `bixby/companion/*` — **Bixby**
- `companionservice/esimmanager/subscription` — **eSIM / LTE**
- `companionapps/{musictransfer,calendar,contacts,...}` — media + PIM sync
- `waterplugin/settings/module` — the watch **Settings** screens
- 50 `HealthConnect` references — health relay to Samsung Health / Health Connect

## Transport is the standard Wear OS data layer (phone-agnostic)

Confirmed literals: `com.google.android.gms.wearable.{MESSAGE,DATA,CAPABILITY,NODE,CHANNEL,...}`,
`MessageClient`, `DataClient`, `CapabilityClient`. The plugin talks to the watch over **Google's
Wear OS link**, not a Samsung-proprietary channel — so the connection itself is not phone-locked.

## Same manufacturer gate as the host (confirmed)

```java
// com.samsung.android.plugin.sharedlib.utils.SharedCommonUtils.isSamsungDevice()
if (isSamsungGEDModel()) return false;                       // two 2014 phones only
return Build.MANUFACTURER.equalsIgnoreCase("SAMSUNG");
```

Byte-for-byte the same logic as host finding 0001, in a different class
(`...plugin.sharedlib.utils.SharedCommonUtils`). **One lever (`Build.MANUFACTURER`) un-gates both
the host and this plugin.** Gate density here is high: 164 `MANUFACTURER`, 116 `isSamsung` hits.

## It already has non-Samsung code paths (with degradations)

The plugin is explicitly non-Samsung-aware; off-Samsung it swaps in fallbacks rather than failing:

- `GM_FEATURE_NO_DOWNLOAD_NONSAMSUNG`, `isNoDownloadNonSamsung`, `openWebStoreForNonSamsung()`,
  `NONSAMSUNG_RENEWAL_OPEN_MYAPPS_TAB` — off-Samsung it **cannot install watch apps/faces via the
  on-device Galaxy Store path** and opens a web store instead. Satisfying `isSamsungDevice()`
  restores the native install path.
- `setAuthTypeListForNonSamsungDevice`, `ES_OPTION_NON_SAMSUNG_AKA_SUPPORT`,
  `sendCachedInfoForNonSamsungDevice`, `saSyncingHandledForNonSamsungDevice` — different auth and
  sync handling off-Samsung.

## `SEC_FLOATING_FEATURE_*` here is hardware config, not feature toggles

The flags the plugin reads (`..._FRAMEWORK_SUPPORT_FOLDABLE_TYPE_*`, `..._LCD_CONFIG_HFR_MODE`,
`..._CAMERA_SUPPORT_CONTROLLING_WATCH`, `..._COMMON_SUPPORT_AI_AGENT`) are **phone hardware/config
descriptors**, not per-watch-feature on/off switches. Correction to the finding-0001 hypothesis:
the watch feature set is gated by `isSamsungDevice()` + account, **not** by a table of feature
flags we need to spoof. That simplifies the un-gate — the manufacturer lever is the main thing.

## Un-gating strategy

1. **Manufacturer lever** (finding 0001) also covers this plugin — add
   `com.samsung.android.plugin.sharedlib.utils.SharedCommonUtils.isSamsungDevice()` /
   `...getManufacturer()` to the same hook scope. Restores native watch-app/face install and the
   Samsung auth/sync path.
2. **Account** (finding 0002, 91 `com.osp.app.signin` hits) — Galaxy Store / watch-app purchases
   and some sync need the SA token; use the login path from 0002.
3. Transport needs nothing — it is already Wear OS.

## Scope / risks

- Base split only; some feature code may live in config splits not pulled.
- Galaxy-Store-backed installs still require a working SA token (finding 0002) even after the
  manufacturer lever.
- Reproduce gate: `decompile_dex.py isSamsungDevice tools/work/com.samsung.wearable.watch7plugin/classes3.dex`.
