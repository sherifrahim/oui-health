# Un-gating playbook — make all watch features work on your non-Samsung phone

This is the device-side step the oui-health analysis points to. It is written for **personal
interoperability on hardware you own** (your Galaxy Watch 7 + your phone). You run it on your own
device; nothing here is distributed.

It consolidates findings 0001–0004 into an actionable procedure and flags the real traps. It points
to the standard, publicly documented tools for the exact boilerplate/commands rather than shipping a
finished patched binary.

---

## What you are changing (recap from the findings)

The entire "not a Samsung phone → disable features" behaviour funnels through **one boolean**:

```java
isSamsungDevice()  ==  Build.MANUFACTURER.equalsIgnoreCase("SAMSUNG")
```

Confirmed in two packages:

| Package | Class → method | Finding |
|---|---|---|
| `com.samsung.android.app.watchmanager` (host) | `...twatchmanager.util.StaticConstWrapper.getManufacturer()` → returns `Build.MANUFACTURER` | 0001 |
| same | `...twatchmanager.AppUtil.isSamsungDevice()` and `...global.utils.PlatformUtils.isSamsungDevice()` | 0001 |
| `com.samsung.wearable.watch7plugin` (Watch7 plugin) | `...plugin.sharedlib.utils.SharedCommonUtils.isSamsungDevice()` | 0003 |

Make those report "Samsung" (or make the `isSamsungDevice()` methods return `true`) **scoped to
those apps only**, and the host + plugin take the Samsung branch: native pairing, native
watch-app/watch-face install, eSIM, settings, health relay. Transport is already standard Wear OS,
so nothing else is needed there. Samsung Health needs no change (finding 0004). Account login uses
the built-in web flow (finding 0002).

There is **no feature-flag table to fake** — the `SEC_FLOATING_FEATURE_*` values turned out to be
hardware descriptors, not feature switches (finding 0003).

---

## Approach A — Runtime hook with LSPosed (recommended)

Hooking at runtime leaves every APK **unmodified**, so you keep Samsung's signatures and the
`sharedUserId` trust between the host and its plugins intact (see the trap in Approach B). This is
the clean route.

### Prerequisites
- A rooted phone with **Magisk**, plus **LSPosed** (Zygisk flavour). LSPosed is the current
  maintained Xposed framework — get it and its documentation from its official project
  (`github.com/LSPosed/LSPosed`, releases + wiki).
- Android Studio (to build a tiny module APK).

### What the module does
An LSPosed module is a normal app that declares itself an Xposed module and implements one hook
callback (`IXposedHookLoadPackage`). In that callback you:

1. Return early unless the loaded package is one of:
   `com.samsung.android.app.watchmanager`, `com.samsung.wearable.watch7plugin`
   (add `com.samsung.wearable.watch6plugin` etc. if you also use other watches).
2. Replace the return value of the gate methods with the Samsung answer:
   - host: `StaticConstWrapper.getManufacturer()` → return `"samsung"`; and/or
     `AppUtil.isSamsungDevice()` and `PlatformUtils.isSamsungDevice()` → return `true`.
   - plugin: `SharedCommonUtils.isSamsungDevice()` → return `true`.

   The Xposed API for "force a method to return a constant" is
   `XC_MethodReplacement.returnConstant(value)` wired via `XposedBridge.hookAllMethods(...)`.
   Use `XposedHelpers.findClass(name, classLoader)` to resolve each class; wrap each hook in
   try/catch so a class that is absent in a given build is skipped, not fatal.
3. Set the module's **scope** to exactly those two packages (LSPosed lets you pick per-app scope —
   do not hook system-wide).

For the current module manifest keys (`xposedminversion`, `xposedscope`, the `xposed_init` asset)
and a working skeleton, follow the **LSPosed module developer guide / sample module** in the
LSPosed wiki — it carries the up-to-date boilerplate. The hook body is the handful of
`returnConstant` lines above against the targets in the table.

### Install & activate
1. Build the module APK in Android Studio, install it (`adb install`), open **LSPosed → Modules**,
   enable it, tick the two packages in its scope, and **force-stop Galaxy Wearable + the plugin**
   (or reboot) so they reload with the hook.

### Verify
- `adb logcat | grep -i oui-health` — your module should log that it hooked each method.
- In Galaxy Wearable, the features that were missing (native watch-app/face install, settings
  pages, eSIM setup) should now appear. If a screen still routes to the "web store" fallback, the
  plugin hook did not take — re-check the scope includes the plugin and that you force-stopped it.

### Rollback
Disable the module in LSPosed (or uninstall it) and force-stop the apps. Nothing was modified on
disk, so there is nothing else to undo.

---

## Approach B — Static patch with apktool (no root, but fragile)

If you cannot root, you can edit the APK itself. This works but has a sharp edge, below.

### Steps (standard apktool workflow — see `apktool.org` docs)
1. `apktool d GalaxyWearable.apk -o gw` to disassemble to smali.
2. In `gw/`, open the gate method's smali (e.g. `.../twatchmanager/AppUtil.smali`, method
   `isSamsungDevice()Z`) and make it return true — i.e. the method body loads the constant `1` into
   the result register and returns it. Do the same for `PlatformUtils.isSamsungDevice()` and, in the
   plugin, `SharedCommonUtils.isSamsungDevice()`. (The decompiled bodies are in findings 0001/0003
   so you know exactly what you are replacing.)
3. `apktool b gw -o gw-patched.apk` to rebuild.
4. `zipalign -p 4 gw-patched.apk gw-aligned.apk`.
5. Sign with **your own** key using `apksigner` (Android SDK build-tools; `keytool` to make the key).

### The trap I found (finding 0001) — read before you do this
The host declares `sharedUserId="com.samsung.accessory.wmanager"` and shares it with the plugins.
Android only lets apps share a UID **if they are signed by the same key**. The moment you re-sign
the host with your key:

- every cooperating package (host **and** all its plugins) must be re-signed with the **same** key,
  or they can no longer share the UID and the suite breaks; and
- any signature-pinned IPC (and the Samsung-signed on-device services) may reject your re-signed
  build anyway.

This is precisely why **Approach A (runtime hook) is preferred** — it changes behaviour without
touching signatures, so the `sharedUserId` trust is preserved. Only go static if you cannot root,
and then re-sign the host and all its plugins together with one key.

---

## Samsung Account — closing the silent-refresh gap (finding 0002)

Interactive login already works off-Samsung via the built-in `SAWebViewActivity`
(`account.samsung.com/.../signInGate`). To get silent background token refresh too, install the
**standalone Samsung Account app** `com.osp.app.signin` (it installs on non-Samsung phones). With it
present *and* the manufacturer hook active, `requestSATokenDataOnBackground()` takes the on-device
`REQUEST_ACCESSTOKEN` path and refreshes quietly, exactly like a Samsung phone. Always your real
account via Samsung's official OAuth — no token is forged.

---

## After un-gating — what should now work

| Capability | Route | Needs the hook? |
|---|---|---|
| Watch health (HR/HRV/SpO2/sleep/…) | Samsung Health → Health Connect → oui-health app | No (finding 0004) |
| Pairing / connection | Wear OS data layer | No (already works) |
| Native watch-app & watch-face install | Galaxy Wearable + plugin | **Yes** |
| eSIM / LTE setup, settings screens | plugin | **Yes** |
| Galaxy Store purchases, cloud sync | plugin + account token | Yes + account (0002) |
| Interactive Samsung Account login | built-in WebView | No |
| Silent account token refresh | on-device SA app + hook | Yes + install `com.osp.app.signin` |

---

## Risks & honest limits

- A future Galaxy Wearable/plugin update can rename the gate methods; re-run
  `tools/scripts/decompile_dex.py isSamsungDevice <dex>` to re-locate them.
- Server-side features validated against Samsung's servers (some partner programs) may still refuse
  if the account/device is not recognised — those are genuine limits, not something a local hook can
  change.
- Rooting and modifying system behaviour can affect banking-app attestation (SafetyNet/Play
  Integrity) and may void warranty/support. That is your call on your device.
- Keep everything scoped to the watch apps; do not hook `isSamsungDevice()`/`Build.MANUFACTURER`
  system-wide.
