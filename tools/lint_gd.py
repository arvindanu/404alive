#!/usr/bin/env python3
"""Cheap static sanity checks for the GDScript sources (no Godot needed):
tab indentation, balanced brackets, one-line if/else (invalid in GDScript), trailing junk.
This is NOT a compiler - always open the project in Godot for the real check."""
import sys, glob, os, re
root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
bad = 0
for f in sorted(glob.glob(root + "/scripts/**/*.gd", recursive=True)):
    depth = {"(": 0, "[": 0, "{": 0}; close = {")": "(", "]": "[", "}": "{"}
    for n, line in enumerate(open(f, encoding="utf-8").read().split("\n"), 1):
        rel = os.path.relpath(f, root)
        if re.match(r"^ +\S", line): print(f"{rel}:{n}: space indentation"); bad += 1
        code = re.sub(r'"(\\.|[^"\\])*"', '""', line).split("#")[0]
        code = re.sub(r"&\"\"|\"\"", "", code)
        if re.search(r"\bif\b.*:\s*\S.*\belse\s*:", code) and not re.search(r"\bif\b.*\belse\b", code.replace(": ", "", 1)) : pass
        if re.match(r"^\s*(if|elif|while|for)\b[^#]*:\s*\S", code) and not re.search(r"[\[{(].*:.*[\]})]|\bfunc\b|lambda", code):
            print(f"{rel}:{n}: statement on same line as block header?: {line.strip()}"); bad += 1
        for ch in code:
            if ch in depth: depth[ch] += 1
            elif ch in close: depth[close[ch]] -= 1
    if any(v != 0 for v in depth.values()): print(f"{os.path.relpath(f, root)}: unbalanced brackets {depth}"); bad += 1
print("OK - no issues found" if not bad else f"{bad} issue(s)")
sys.exit(1 if bad else 0)
