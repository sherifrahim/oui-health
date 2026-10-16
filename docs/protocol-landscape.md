# Protocol landscape: Galaxy Watch 4+ ⇄ phone

What is publicly known about how a Wear OS Galaxy Watch talks to an Android phone, and where the
Samsung-specific behaviour lives. This is the map we refine with evidence from the APKs you supply;
unverified claims are marked.

## The watch is Wear OS, not Tizen

Galaxy Watch 4, 5, 6, 7 and Ultra run **Wear OS "Powered by Samsung"** (One UI Watch). This matters:

- The **transport and pairing** are standard Wear OS — the same Bluetooth companion link the Google
  **Wear OS** app uses. Any Android phone can establish it. There is **no SAP** (Samsung Accessory
  Protocol) layer the way Tizen Gear/Watch3 had; SAP is out of scope for this project.
- So the gap between "Samsung phone" and "any phone" is **not** the radio link. It is the
  **phone-side software** that decides which features to light up.

## The phone-side suite

Roughly three cooperating pieces on the phone (confirm exact package names from the manifests you
extract — see `docs/reverse-engineering.md`):

| Piece | Typical package(s) | Role |
|---|---|---|
| **Galaxy Wearable** (host) | `com.samsung.android.app.watchmanager`, host/`HostManager` service | Finds, pairs and manages the watch; loads per-model **plugins** |
| **Galaxy Wearable plugins** | `com.samsung.android.waterplugin`, `...geartplugin`, `...wearupdate`, etc. | Per-feature/per-model logic: settings, watch-face sync, updates, notifications relay |
| **Samsung Health** | `com.sec.android.app.shealth` | Phone-side health hub; aggregates watch sensor data |
| **Health Platform** | `com.samsung.android.service.health` (a.k.a. Samsung Health bridge) | Moves health data between the watch, Samsung Health, and **Health Connect** |

> **Unverified until measured:** the exact package names, which plugins exist for Watch 4+, and the
> division of labour between them. The manifest + class inventory from `scan-blockers.sh` fills
> this in with evidence.

## Where features are gated (hypotheses to confirm)

These are the usual mechanisms a Samsung app uses to tell "am I on a Samsung phone?". The
blocker-hunt plan (`docs/blocker-hunt.md`) is organized around finding each one in the decompiled
code:

1. **Build fingerprint checks** — `Build.MANUFACTURER` / `Build.BRAND` compared to `"samsung"`,
   `Build.MODEL`, `SystemProperties.get("ro.product.*")`.
2. **Samsung system-feature checks** — `PackageManager.hasSystemFeature("com.sec.feature.*"` /
   `"com.samsung.feature.*")`; these features only exist on One UI.
3. **Samsung-only framework APIs** — calls into `com.samsung.android.*` SDKs (SemClassName,
   `android.util.SemSystemProperties`, Knox, `Sem*` reflection) that throw/return null on stock
   Android and are used as an implicit gate.
4. **Signature / package presence checks** — requiring a Samsung-signed package (e.g. Samsung
   Account `com.osp.app.signin`, `com.samsung.android.authfw`) to be installed and signed with
   Samsung's key.
5. **Server-side entitlement** — some features phone a Samsung server that keys off the account or
   device; these cannot be un-gated purely on-device and must be identified so we set expectations
   honestly.
6. **Samsung Account requirement** — a feature refusing to run until a Samsung account is present.

For each gate we find, `docs/architecture.md` describes how the interop layer answers it (supply a
truthful-enough environment, provide the missing channel ourselves, or — where it is pure
server-side entitlement — document it as a hard limit).

## The health data path (already open)

Independently of the gates above, health data has a documented route to **every** Android app:

- **Watch → Samsung Health → Health Connect → your app.** Health Connect is an on-device store
  (no server API); an app reads locally and does what it likes with it. Samsung Health writes to
  Health Connect per data type once the user allows it in *Samsung Health → Settings → Health
  Connect*. (Source: Samsung developer docs; Google Health Connect docs.)
- **Known gaps in that route:** Google's own Health app does not receive HRV, skin temperature,
  VO2 max, detailed exercise sessions, or ECG from connected devices — so a "parity" app must get
  those either from Samsung Health directly or from the watch-side sensor stream, not from Health
  Connect alone. (Source: Google Health help center.)
- **Raw sensors** (accelerometer, ECG, EDA, HR+IBI, PPG green/red/IR, skin temp, SpO2) are exposed
  by the **Samsung Health Sensor SDK** — but that is a **watch-side** SDK talking to the watch's
  Health Platform, and its version must match the watch's Health Platform. (Source: Samsung Health
  Sensor SDK docs.)

## Battery / connection (already open)

- Android's own reported level (status-bar battery) and standard **BLE Battery Service 0x180F**.
- The **Wear OS data layer** (`MessageClient` / `DataClient`) for a small watch-side companion to
  report what the standard profiles don't (e.g. Wear OS watch battery).

## Sources

- Gadgetbridge BT protocol reverse-engineering method (HCI snoop + Wireshark):
  <https://gadgetbridge.org/internals/development/new-gadget/>,
  <https://codeberg.org/Freeyourgadget/Gadgetbridge/wiki/BT-Protocol-Reverse-Engineering>
- Samsung Accessory Protocol (Tizen; out of scope here, for contrast):
  <https://developer.samsung.com/galaxy-accessory/overview.html>;
  community notes <https://xdaforums.com/t/figuring-out-samsung-accesory-protocol-internals.2857377/>
- Health Connect data path:
  <https://support.google.com/googlehealth/answer/14236613>
- Samsung Health Sensor SDK (watch-side raw sensors):
  <https://developer.samsung.com/health/sensor/api-reference/overview-summary.html>
- Method template from academic SmartTag/Find-My analysis (HCI snoop + JADX):
  <https://arxiv.org/pdf/2210.14702>
