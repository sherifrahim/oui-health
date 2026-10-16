# oui-health

**Full Galaxy Watch functionality on any Android phone — not just Samsung's.**

A Galaxy Watch 4 or newer is a Wear OS watch. It will *pair* with any Android phone, but the
experience is deliberately uneven: the richest features live behind Samsung's own phone-side
suite — **Galaxy Wearable** (a.k.a. Galaxy Wearable/`HostManager` plus its per-watch plugins),
**Samsung Health**, and the **Health Platform** bridge — and several of those pieces check that
they are running on a *Samsung* phone (One UI) before unlocking everything. On a Pixel, a
OnePlus, a Xiaomi, you get a subset.

This project's goal is to close that gap so a non-Samsung phone behaves, to the watch, like a
Samsung one: **no feature gated, no "not supported on this device".**

It does that the only honest way it can — by **reverse-engineering Samsung's own companion
binaries** to find exactly where and how they gate features on the phone's manufacturer, and
building an open interoperability layer that supplies what they expect. Analysis runs **locally**,
on binaries **you** provide from a device or account **you** own, and every conclusion is backed by
the evidence that produced it.

> **Status:** reverse-engineering workbench + interop plan. The parity app is written *after* the
> gate analysis, because you cannot credibly un-gate what you have not yet measured. See
> [`docs/roadmap.md`](docs/roadmap.md).

---

## Why this is legitimate

Reverse engineering for **interoperability** — making your own device talk to hardware you own —
is a well-established, lawful purpose. This repository:

- analyzes **only** binaries and traffic **you** supply from devices/accounts **you** own;
- never downloads Samsung software from Samsung's servers (that is the owner's job, through
  official channels);
- **never commits** any proprietary binary, decompiled source, or captured traffic — see
  [`.gitignore`](.gitignore). Only *our* findings, written in our own words, and *our* interop
  code live in git;
- produces an independent, clean-room interop layer, not a copy of Samsung's code.

See [`DISCLAIMER.md`](DISCLAIMER.md). If your use is something other than personal interoperability
with hardware you own, stop and check your local law first.

---

## How the pieces fit

```
 Galaxy Watch 4+  ──Wear OS companion + BLE──►  YOUR Android phone
 (Wear OS,                                       │
  "Powered by Samsung")                          ├─ Google Wear OS app        (works anywhere)
                                                  ├─ Galaxy Wearable + plugins (gates on Samsung)
                                                  ├─ Samsung Health            (gates on Samsung)
                                                  └─ Health Platform bridge    (gates on Samsung)
                                                        │
                                   oui-health interop layer sits here:
                                   • answers the manufacturer/feature checks the suite makes
                                   • bridges health data out to Health Connect for every app
                                   • fills the channels the suite won't open on non-Samsung phones
```

Two independent routes, used together:

1. **Documented route (works today, no RE):** watch health data already flows
   Watch → Samsung Health → **Health Connect** → any app, and battery/connection facts come over
   the **Wear OS data layer** and standard **BLE Battery Service (0x180F)**. oui-health uses these
   wherever they suffice.
2. **Un-gated route (the RE target):** everything Samsung's suite *refuses* to do on a non-Samsung
   phone. We find each refusal in their binaries and supply what it wants.

---

## Repository layout

```
docs/
  protocol-landscape.md   What is known (and from where) about how Galaxy Watch 4+ talks to a phone
  blocker-hunt.md         The concrete reverse-engineering plan: every gate to find in the APKs
  reverse-engineering.md  How to run the workbench (REA + JADX) on APKs you supply
  architecture.md         Design of the oui-health interop layer
  roadmap.md              Phased plan from workbench → feature parity
tools/
  scripts/                The harness (see docs/reverse-engineering.md)
  inputs/                 ← you drop APKs / logs here. Contents are gitignored.
  findings/               Our written findings (these DO go in git). TEMPLATE.md to start one.
```

## Quick start

1. Read [`docs/reverse-engineering.md`](docs/reverse-engineering.md) and run
   `tools/scripts/setup-rea.sh` once.
2. Put the Samsung companion APKs you pulled from your own watch-paired Samsung phone into
   `tools/inputs/` (`tools/scripts/extract-apks.sh` lists how to pull them with adb).
3. Run `tools/scripts/scan-blockers.sh tools/inputs/GalaxyWearable.apk` to get the first pass at
   where it gates on the manufacturer.
4. Write up what you find in `tools/findings/` using the template.

Then we build the interop layer against those findings.

---

## License

MIT — see [`LICENSE`](LICENSE). Applies to oui-health's own code and docs only. It does **not**
grant any right over Samsung's or Google's software; those remain under their own licenses and are
never redistributed here.
