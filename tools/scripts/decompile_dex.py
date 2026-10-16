#!/usr/bin/env python3
"""Decompile methods by name from specific dex files (light: one dex at a time).

For big multidex apps where AnalyzeAPK over the whole APK is too heavy. Give it
extracted dex files and method-name substrings; it only builds Analysis for a
dex whose string table mentions the name.

Usage: python3 decompile_dex.py name1[,name2,...] dex1 [dex2 ...]
"""
import re
import sys

from androguard.core.dex import DEX
from androguard.core.analysis.analysis import Analysis

names = [n for n in sys.argv[1].split(",") if n]
dex_files = sys.argv[2:]
pat = re.compile("|".join(re.escape(n) for n in names))

for path in dex_files:
    raw = open(path, "rb").read()
    if not pat.search(raw.decode("latin-1", "ignore")):
        continue
    print(f"\n==== {path} (contains a target name) ====", flush=True)
    d = DEX(raw)
    dx = Analysis(d)
    dx.create_xref()
    for name in names:
        for ma in dx.find_methods(methodname=f".*{re.escape(name)}.*"):
            meth = ma.get_method()
            if not hasattr(meth, "get_source"):
                continue  # external/abstract ref
            try:
                src = meth.get_source()
            except Exception:
                src = None
            print(f"\n--- {meth.get_class_name()} -> {meth.get_name()}{meth.get_descriptor()}")
            if src and src.strip():
                print(src)
            else:  # fall back to smali disassembly (reliable cross-dex)
                try:
                    for ins in meth.get_instructions():
                        print(f"    {ins.get_name():22} {ins.get_output()}")
                except Exception as e:
                    print(f"    <no body: {e}>")
