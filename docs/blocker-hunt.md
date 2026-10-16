# The blocker hunt

The core reverse-engineering task: find **every point** where Samsung's companion suite decides it
is *not* on a Samsung phone and does less because of it. Each finding gets written up in
`tools/findings/` and mapped to an un-gating strategy in `docs/architecture.md`.

This is a checklist, ordered by how commonly each mechanism is the real gate. Run the searches with
`tools/scripts/scan-blockers.sh` (bulk grep over decompiled sources) and drill in with REA
(`inspect-android-class` / `inspect-android-method`) for evidence-bound confirmation.

## 1. Build fingerprint checks

The simplest and most common gate.

Search decompiled sources for:
```
Build.MANUFACTURER      Build.BRAND        Build.MODEL
"samsung"  "Samsung"  "SAMSUNG"           ro.product.manufacturer
SystemProperties.get(   ro.product.brand   ro.csc.
```
For each hit, record: class + method, the comparison, and what branch the non-Samsung path takes
(returns false? disables a UI element? throws?). These are usually the cheapest wins — the interop
layer satisfies them by presenting the expected values to the specific callers.

## 2. Samsung system-feature checks

Features declared only on One UI:
```
hasSystemFeature(        com.sec.feature.         com.samsung.feature.
com.sec.android.          "android.software.*" (Samsung custom)
```
Record the exact feature string. The un-gating strategy is to make `PackageManager` answer `true`
for those strings to the companion suite (see architecture: feature-shim).

## 3. Samsung-only framework APIs used as a gate

One UI ships `Sem*` extensions and private SDKs absent on stock Android. Calls that throw
`NoSuchMethodError` / `ClassNotFoundException` on a Pixel are sometimes caught and treated as "not
supported":
```
android.util.SemSystemProperties      Sem    semGet   semSet
com.samsung.android.               knox     com.sec.
reflect.*getMethod(... "sem         NoSuchMethodError  ClassNotFoundException
```
Record which capability each guarded call backs. Some are cosmetic; some are load-bearing.

## 4. Package presence + signature checks

A feature that insists a Samsung-signed package is installed:
```
getPackageInfo(   GET_SIGNATURES   GET_SIGNING_CERTIFICATES
com.osp.app.signin        (Samsung Account)
com.samsung.android.authfw               (Samsung auth framework)
com.samsung.android.coreapps / ...mobileservice
checkSignatures(   signingInfo    PackageManager.SIGNATURE_MATCH
```
Record the required package + whether the check is *presence* (satisfiable by installing an open
stand-in or the real package) or *signature-pinned* (harder — needs the real Samsung package, or a
companion that provides the same interface).

## 5. Samsung Account requirement

```
com.osp.app.signin     SamsungAccount    AccountManager.getAccountsByType("com.osp.app.signin")
isSamsungAccountSignedIn    getAccessToken   samsung token
```
Distinguish "needs an account object to exist" (local, satisfiable) from "needs a valid server
token" (server-side, a real limit — document it).

## 6. Server-side entitlement

```
https://   .samsungapps.   .samsung.com   checkEntitlement   provisioning
deviceId  imei  serial  verifyDevice
```
Anything that validates the device/account against a Samsung server **cannot** be un-gated purely
on-device. The honest outcome is to list each such feature as a hard limit, and where possible
route around it with the documented Health Connect / Wear OS paths instead.

## 7. Health pipeline specifics

For Samsung Health + Health Platform, additionally map:
- which permissions/data types it writes to **Health Connect**, and which it withholds;
- whether withholding is gated on manufacturer (→ un-gate) or is simply not-yet-implemented
  upstream (→ we read from Samsung Health directly instead);
- the watch-side **Health Platform** version it expects (sensor SDK version matching).

## Output per finding

Use `tools/findings/TEMPLATE.md`. Each finding must carry its **evidence** (class, method, the
exact decompiled lines or the REA evidence id) so the un-gating code can be reviewed against the
real gate, not a guess. A gate we cannot point at is a gate we have not found yet.

## From findings to parity

When the checklist is worked through for a given APK, we will know — with evidence — the complete
set of gates standing between "any Android" and "full watch features", split into:

- **(A) on-device, satisfiable** gates → the interop layer answers them;
- **(B) missing channels** the suite won't open on non-Samsung → we implement the channel;
- **(C) server-side / signature-pinned** gates → documented limits, routed around where a
  documented path (Health Connect, Wear OS data layer, standard BLE) exists.

Only then do we write the app in `docs/architecture.md`. Building it before this is guesswork.
