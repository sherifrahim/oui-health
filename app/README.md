# oui-health app — watch health on any Android

A minimal Android app that reads your Galaxy Watch's health data (heart rate, resting HR, HRV,
SpO2, skin temperature, steps, calories, sleep, workouts) from **Health Connect** and shows a
24-hour summary.

This is the **legitimate, no-un-gating** route. Finding 0004 confirmed Samsung Health writes this
full data set to Health Connect on *any* phone — so this app just uses the official
`androidx.health.connect` API to read your own data. Nothing here spoofs a device or patches a
Samsung app.

## Data flow

```
Galaxy Watch 7 ──Wear OS──► Samsung Health ──writes──► Health Connect ──reads──► oui-health app
                                                                         (official API)
```

## Prerequisites on the phone

1. **Health Connect** present (built into Android 14+, else install "Health Connect by Android").
2. **Samsung Health** installed and signed in, with **Settings → Health Connect** enabled and the
   data types you want toggled on to sync. (Samsung Health runs on non-Samsung phones — finding
   0004.)
3. Your watch paired and syncing into Samsung Health.

## Build

Open the repo root in **Android Studio** (it supplies the Android SDK + Gradle wrapper), let it
sync, and Run the `app` configuration. Or from a machine with the SDK:

```bash
./gradlew :app:assembleDebug        # app/build/outputs/apk/debug/app-debug.apk
```

On first launch tap **Read my watch health data**, approve the Health Connect permission sheet,
and the summary fills in.

## Extend

- Add record types in `HealthRepo.recordTypes` *and* the matching `<uses-permission>` in
  `AndroidManifest.xml`; the permission set is derived from the type list.
- For a live tile/widget or background sync, add a worker that calls `HealthRepo.summarize()` and
  keep the `READ_HEALTH_DATA_IN_BACKGROUND` permission.

## Scope

This app covers the **health slice** — the part that works on any phone with no modification. Watch
faces, watch apps, Bixby, eSIM, calls/notifications relay and the rest come from Samsung's companion
suite, which gates on `Build.MANUFACTURER` (findings 0001/0003); un-gating those is a device-side
step documented in the findings, not part of this app.
