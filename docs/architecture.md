# oui-health interop layer — architecture

Design of the thing that makes a non-Samsung phone behave, to the watch, like a Samsung one. It is
written **against findings**, so sections firm up as `tools/findings/` grows. Today it reflects
finding 0001 (the `isSamsungDevice()` / `SemFloatingFeature` gates).

## Principle

Do not rewrite Samsung's suite. For each gate we find, choose the **least invasive** answer:

1. **Satisfy the environment** the suite checks (preferred): present the expected
   `Build.MANUFACTURER`, Samsung system-features, and `SemFloatingFeature` answers to the specific
   callers that gate on them.
2. **Supply the missing channel** ourselves when the suite simply won't open it on a non-Samsung
   phone (Wear OS data layer companion, standard BLE, Health Connect bridge).
3. **Document the limit** when a gate is a real server-side entitlement (Samsung-account token) and
   route the underlying capability through an open path instead.

## Components

### 1. Compatibility shim (`shim/`) — answers the manufacturer gates (G1, G2)

The on-device layer that makes `FeatureUtil.isSamsungDevice()` and the `SemFloatingFeature`
lookups return what the watch features expect. Candidate mechanisms, in order of invasiveness —
chosen per finding, and only after the branch is confirmed by decompilation:

- a hooking layer (e.g. an Xposed/LSPosed-style module on rooted devices) that patches
  `isSamsungDevice()` and provides a stand-in `SemFloatingFeature` answering the specific
  `SEC_FLOATING_FEATURE_*` keys enumerated from the plugins;
- a repackaged host build with those methods patched (note: breaks signing — see finding 0001
  risks);
- a clean-room reimplementation of just the host flow (no Samsung code), for non-rooted phones.

The shim is **not** a blanket "pretend to be Samsung everywhere" — it answers only the specific
calls the findings identify, to limit breakage.

### 2. Health bridge (`health/`) — the already-open route

Phone-side service that reads watch health data and exposes it to every app via **Health Connect**,
plus a direct Samsung Health read for the data types Health Connect drops (HRV, skin temp, VO2 max,
ECG — see protocol-landscape). Mirrors Samsung Health's own Health-Connect writer so apps see
parity regardless of phone brand.

### 3. Wear companion (`wear/`) — fills gaps over the data layer

A small Wear OS app (shared with the sibling **Halo** project's `WearBridge`) that reports what the
standard profiles don't — battery, and any watch-side signal we choose to surface — over
`MessageClient`/`DataClient`. Works on any phone because it rides Google's Wear OS link, not
Samsung's.

### 4. Connection/pairing assist (`pairing/`)

Where the host's pairing flow (`twatchmanager.setupwizard.*`, `connectionmanager.*`) degrades on
non-Samsung, provide the missing step. Scope depends on findings from the per-model plugins.

## What stays a hard limit (be honest)

- Features that require a **valid Samsung-account server token** (G3) cannot be forged on-device.
  Where the feature's *data* has an open path (health → Health Connect), we take it; where it does
  not, it is documented as unavailable.
- **Signature-pinned IPC**: if a Samsung package insists its peer is Samsung-signed, a repackaged
  or clean-room peer may be rejected; the shim approach (satisfy the environment of the *real*
  package) avoids this where feasible.

## Relationship to Halo

[Halo](https://github.com/sherifrahim/Halo-battery-Widget) already does Bluetooth battery +
Wear OS battery via a companion. oui-health reuses that `WearBridge` pattern for component 3 and
focuses on the health + gate-removal pieces Halo doesn't cover.
