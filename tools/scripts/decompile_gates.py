#!/usr/bin/env python3
"""Decompile the specific gate methods/classes in a supplied APK (androguard).

Reads the APK as data; never executes it. Usage:
    python3 -I tools/scripts/decompile_gates.py tools/inputs/GalaxyWearable.apk
"""
import re
import sys

from androguard.misc import AnalyzeAPK

apk_path = sys.argv[1]
print(f">> loading {apk_path} (this takes a moment on a 7MB dex)\n", flush=True)
a, dvms, dx = AnalyzeAPK(apk_path)
print(f">> package: {a.get_package()}  versionName: {a.get_androidversion_name()}\n", flush=True)

WANT_CLASS = re.compile(r"FeatureUtil|FloatingFeature", re.I)
WANT_METHOD = re.compile(r"isSamsung|FloatingFeature|getEnableStatus|getString", re.I)


def show_method(m):
    try:
        src = m.get_method().get_source()
    except Exception as e:  # DAD can choke on some methods
        src = f"<decompile failed: {e}>"
    print(f"\n--- {m.get_method().get_class_name()} -> "
          f"{m.get_method().get_name()}{m.get_method().get_descriptor()}")
    print(src)


# 1. Decompile the gate classes' interesting methods.
for cls in dx.get_classes():
    name = cls.name
    if not WANT_CLASS.search(name):
        continue
    print("=" * 78)
    print("CLASS", name)
    for m in cls.get_methods():
        if WANT_METHOD.search(m.get_method().get_name()):
            show_method(m)

# 2. Who calls isSamsungDevice() — the callers decide what gets disabled.
print("\n" + "=" * 78)
print("CALLERS of *isSamsungDevice* methods:")
seen = set()
for m in dx.find_methods(methodname=r".*isSamsung.*"):
    for _, caller, _ in m.get_xref_from():
        key = (caller.class_name, caller.name)
        if key not in seen:
            seen.add(key)
            print(f"  {caller.class_name} -> {caller.name}")
print(f"  ({len(seen)} distinct callers)")
