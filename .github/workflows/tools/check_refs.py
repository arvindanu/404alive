#!/usr/bin/env python3
"""Cross-reference check (no Godot needed): every `Class.func(...)` call to one of OUR classes/autoloads
must exist, with an acceptable argument count. Also checks preload()/load()/ExtResource paths exist."""
import re, glob, os, sys
root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
files = sorted(glob.glob(root + "/scripts/**/*.gd", recursive=True))
src = {f: open(f, encoding="utf-8").read() for f in files}

def split_args(s):
    depth = 0; cur = ""; out = []; q = None
    for ch in s:
        if q:
            cur += ch
            if ch == q: q = None
            continue
        if ch in "\"'": q = ch; cur += ch; continue
        if ch in "([{": depth += 1
        if ch in ")]}": depth -= 1
        if ch == "," and depth == 0: out.append(cur); cur = ""
        else: cur += ch
    if cur.strip(): out.append(cur)
    return out

# class name -> {func: (min_args, max_args)}
classes = {}
autoloads = {"GameState": "scripts/autoload/game_state.gd", "Audio": "scripts/autoload/audio_manager.gd", "Transition": "scripts/autoload/transition.gd"}
def collect(text):
    d = {}
    for m in re.finditer(r"^(static )?func (\w+)\((.*?)\)\s*(->\s*[\w\[\]\.]+)?\s*:", text, re.M | re.S):
        params = [p for p in split_args(m.group(3)) if p.strip()]
        d[m.group(2)] = (sum(1 for p in params if "=" not in p), len(params), bool(m.group(1)))
    return d
for f, t in src.items():
    m = re.search(r"^class_name (\w+)", t, re.M)
    if m: classes[m.group(1)] = collect(t)
for name, path in autoloads.items():
    classes[name] = collect(src[os.path.join(root, path)])

bad = 0
for f, t in src.items():
    rel = os.path.relpath(f, root)
    code = re.sub(r"#.*", "", t)
    for cname, funcs in classes.items():
        for m in re.finditer(r"\b" + cname + r"\.(\w+)\(", code):
            fn = m.group(1)
            # extract argument text with paren matching
            i = m.end(); depth = 1; j = i
            while j < len(code) and depth:
                depth += (code[j] == "(") - (code[j] == ")"); j += 1
            args = [a for a in split_args(code[i:j-1]) if a.strip()]
            line = code[:m.start()].count("\n") + 1
            if fn not in funcs:
                if fn in ("new", "bind", "connect", "get", "set") or fn[0].isupper(): continue
                print(f"{rel}:{line}: {cname}.{fn}() does not exist"); bad += 1; continue
            lo, hi, _ = funcs[fn]
            if not (lo <= len(args) <= hi):
                print(f"{rel}:{line}: {cname}.{fn}() called with {len(args)} args, expects {lo}..{hi}"); bad += 1

# resource paths
for f in files + glob.glob(root + "/scenes/*.tscn") + [root + "/project.godot", root + "/export_presets.cfg"]:
    t = open(f, encoding="utf-8").read()
    for m in re.finditer(r"res://([\w/\.\-]+)", t):
        p = os.path.join(root, m.group(1))
        if not os.path.exists(p) and not m.group(1).endswith("/"):
            print(f"{os.path.relpath(f, root)}: missing resource res://{m.group(1)}"); bad += 1
print("OK - all cross-references resolve" if not bad else f"{bad} problem(s)")
sys.exit(1 if bad else 0)
