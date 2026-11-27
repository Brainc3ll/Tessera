#!/usr/bin/env python3
"""Checks Tessera's calls against WoW Forever's real API.

Ketho's BlizzardInterfaceResources has a `forever` branch: the list of every global function
of the WoW Forever client (Resources/GlobalAPI.lua), taken from the game itself. This script
lists the C_Namespace.Function calls in Tessera's Lua files and reports the ones that client
does not have.

A missing function is only a problem when nothing replaces it: lines like
`(C_X and C_X.Fn) or OtherFn` fall back to another function, so they are reported as notes.
Usage: python3 tools/forever_api_check.py <path to a BlizzardInterfaceResources clone, branch forever>
"""
import os
import re
import sys


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    api_file = os.path.join(sys.argv[1], "Resources", "GlobalAPI.lua")
    with open(api_file, encoding="utf-8") as f:
        api = set(re.findall(r'"([A-Za-z_][\w.]*)"', f.read()))
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    problems, notes = [], []
    # the addon's Lua files: every .lua of Tessera.toc except the Locales
    with open(os.path.join(root, "Tessera.toc"), encoding="utf-8") as f:
        toc = [l.strip().replace("\\", "/") for l in f]
    files = sorted(l for l in toc if re.match(r"^[A-Za-z0-9_/]+\.lua$", l) and not l.startswith("Locales/"))
    if not files:
        sys.exit("forever_api_check: no Lua file found through Tessera.toc")
    for rel in files:
        path = os.path.join(root, rel)
        name = rel
        with open(path, encoding="utf-8") as f:
            for number, line in enumerate(f, 1):
                code = line.split("--", 1)[0]
                for call in re.findall(r"\b(C_[A-Za-z]+\.[A-Za-z]+)\b", code):
                    if call in api:
                        continue
                    entry = f"{name}:{number}: {call}"
                    # "(C_X and C_X.Fn) or Fallback": another function takes over
                    if re.search(r"\bor\b", code):
                        notes.append(entry + " (absent on Forever, a fallback takes over)")
                    else:
                        problems.append(entry + " (absent on Forever)")
    # the HD icons (Core/Looks.lua, ns.HD_ICONS) must be atlases of the Forever client
    atlas_file = os.path.join(sys.argv[1], "Resources", "AtlasInfo.lua")
    if os.path.exists(atlas_file):
        with open(atlas_file, encoding="utf-8") as f:
            atlases = f.read()
        with open(os.path.join(root, "Core", "Looks.lua"), encoding="utf-8") as f:
            looks = f.read()
        block = re.search(r"ns\.HD_ICONS = \{(.*?)\n\}", looks, re.S)
        for key, atlas in re.findall(r'(\w+) = "([^"]+)"', block.group(1) if block else ""):
            if f'"{atlas}"' not in atlases:
                problems.append(f"Core/Looks.lua: HD icon of {key}: atlas {atlas} absent on Forever")
    for note in notes:
        print("note: " + note)
    for problem in problems:
        print("ERROR: " + problem)
    print(f"Forever API check: {len(problems)} problem(s), {len(notes)} note(s), {len(files)} file(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
