# Finding 0004 — Samsung Health already runs off-Samsung; health pipeline is open

- **Target:** `com.sec.android.app.shealth` (base.apk, 354 MB, 8 dex). Samsung Health. Package roots
  `com.samsung.android.app.shealth.*`, `com.samsung.android.service.health.*`,
  `com.samsung.android.sdk.healthdata.privileged`, `com.samsung.android.sdk.health.data`.
- **Category:** mostly **open already** — Samsung Health is a universal Play Store app with explicit
  non-Samsung support. Remaining edges are **(C)** account/cloud features.
- **Status:** CONFIRMED (non-Samsung key path disassembled; Health Connect surface from manifest +
  strings).

## It is built for non-Samsung and says so

Dedicated non-Samsung code: `NON_SAMSUNG_DEVICE`, `requestKeyInitForNonSamsung`,
`handleKeyInitializationForNonSamsung`, `getFixedNameOfNonSamsungDevice`,
`setAuthTypeListForNonSamsungDevice`. 142 `MANUFACTURER` / 36 `isSamsung` hits, but they branch to
working non-Samsung paths, not refusals.

### Health-DB encryption works without Samsung hardware (confirmed)

```
// KnoxAdapter.handleKeyInitializationForNonSamsung(Context)   [smali]
KeyRetriever r = KeyRetrieverFactory.getKeyRetriever(ctx);
if (r != null) return true;                          // key already initialized
KeyInitializer ki = new KeyInitializer(ctx);
if (!ki.initializeAks()) return false;               // AKS = Android Keystore, no Knox needed
return true;
```

On a Samsung phone the health store is keyed via **Knox**; off-Samsung it falls back to the
**Android Keystore (`initializeAks`)**. So the encrypted health database initializes and works on
any phone — no Samsung secure hardware required. `getFixedNameOfNonSamsungDevice()` just labels the
device by its `BluetoothAdapter.getName()`.

## The health data pipeline to every app is open

Confirmed in the manifest/strings — Samsung Health declares the full Health Connect surface:

- `android.health.connect.*`, `androidx.health.*`, and the complete
  `android.permission.health.READ_*` set, **including the types Health Connect normally drops from
  other sources**: `READ_HEART_RATE_VARIABILITY`, `READ_BODY_TEMPERATURE`, `READ_BLOOD_OXYGEN`,
  `READ_EXERCISE`, `READ_HEALTH_DATA_IN_BACKGROUND`, etc.
- `android.health.wearable.data.*` / `android.health.wearable.deleteinfo.*` — a wearable-data
  ingestion channel.
- 164 `HealthConnect` / 447 `health.connect` / 3638 `healthdata` references — the integration is
  pervasive, not token.

**Implication for "watch works 100%":** once the watch is paired and the plugin relays sensor data
into Samsung Health (finding 0003), Samsung Health reads/writes Health Connect on any phone, so
watch health data reaches every Android health app through the documented store. No un-gating is
needed for the health pipeline itself.

## What still needs the account / stays a limit

- `com.osp.app.signin` (90 hits), `com.samsung.android.service.health.server`, `partner` (359) —
  **cloud sync, partner programs, and server features** need the Samsung-account token (finding
  0002). Local health tracking + Health Connect do not.
- Anything server-validated against the account is category (C): use the real login (0002); where a
  feature cannot authenticate, it is a documented limit, but the on-device health data is unaffected.

## Un-gating strategy

1. **Nothing required for local health + Health Connect** — it already works off-Samsung.
2. **Pairing/relay** comes from the host + plugin (findings 0001/0003); apply the manufacturer
   lever there so the watch connects and the plugin relays into Samsung Health.
3. **Cloud/partner features** — sign in per finding 0002.

## Scope / risks

- Base split only (config splits not pulled); 354 MB app, analyzed via string table + targeted
  smali rather than whole-APK decompilation.
- The Samsung Health Sensor SDK path (raw watch sensors) is a watch-side concern and version-matched
  to the watch's Health Platform — out of scope for this phone-side APK.
- Reproduce: `decompile_dex.py handleKeyInitializationForNonSamsung tools/work/com.sec.android.app.shealth/classes6.dex`.
