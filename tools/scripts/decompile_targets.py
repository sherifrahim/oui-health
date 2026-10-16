#!/usr/bin/env python3
"""Decompile specific methods by name across all classes. Reads APK as data.

Usage: python3 decompile_targets.py APK name1 [name2 ...]
"""
import sys
from androguard.misc import AnalyzeAPK

apk_path, names = sys.argv[1], sys.argv[2:]
a, dvms, dx = AnalyzeAPK(apk_path)

for name in names:
    print("\n" + "#" * 78 + f"\n# methods matching: {name}\n" + "#" * 78)
    for m in dx.find_methods(methodname=f".*{name}.*", classname=r".*samsung.*"):
        meth = m.get_method()
        # skip abstract/external
        try:
            src = meth.get_source()
        except Exception:
            continue
        if not src or not src.strip():
            continue
        print(f"\n--- {meth.get_class_name()} -> {meth.get_name()}{meth.get_descriptor()}")
        print(src)
