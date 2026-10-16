# inputs (gitignored)

Drop the Samsung companion APKs you supplied here, e.g.:
- `GalaxyWearable.apk`  (com.samsung.android.app.watchmanager)
- `SamsungHealth.apk`   (com.sec.android.app.shealth)
- `HealthPlatform.apk`  (com.samsung.android.service.health)
- per-model plugins pulled by `extract-apks.sh`

Nothing in this folder is committed (see repo `.gitignore`). Analyze with
`tools/scripts/scan-blockers.sh`, confirm with REA (`tools/scripts/setup-rea.sh`).
