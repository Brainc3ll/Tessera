#!/usr/bin/env python3
"""Checks a translation before it is imported into CurseForge's localization tool.

A translation lives in CurseForge, not in this repository; this script checks a file in the
format of docs/localization/enUS.lua (one `L["KEY"] = "text"` per line) against the English one:
- every key exists in English (no typo, no removed key);
- the format codes (%s, %d, %.1f...) are the same and in the same order: string.format would
  raise a Lua error otherwise;
- color codes (|cAARRGGBB ... |r), textures (|T...|t) and line breaks (\\n) match;
- short texts (labels, buttons) that grew a lot are listed as warnings: they may not fit.
Usage: python3 tools/check_translation.py <translation.lua> [docs/localization/enUS.lua]
"""
import os
import re
import sys

LINE = re.compile(r'^L\["([^"]+)"\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*$')
FORMAT = re.compile(r'%[-+#0]*\d*(?:\.\d+)?[sdifgxXcq%]')
COLOR = re.compile(r'\|c[0-9a-fA-F]{8}')
TEXTURE = re.compile(r'\|T[^|]*\|t')


def read(path):
    strings, bad = {}, []
    with open(path, encoding="utf-8") as f:
        for number, line in enumerate(f, 1):
            line = line.rstrip("\n")
            if not line.strip() or line.startswith("--"):
                continue
            m = LINE.match(line)
            if not m:
                bad.append(f"{os.path.basename(path)}:{number}: not a `L[\"KEY\"] = \"text\"` line")
                continue
            strings[m.group(1)] = m.group(2)
    return strings, bad


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    here = os.path.dirname(os.path.abspath(__file__))
    english_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "..", "docs", "localization", "enUS.lua")
    english, _ = read(english_path)
    tr, errors = read(sys.argv[1])
    warnings = []
    for key, text in tr.items():
        if key not in english:
            errors.append(f"{key}: unknown key (not in English)")
            continue
        en = english[key]
        if en and not text:
            errors.append(f"{key}: empty translation")
        if FORMAT.findall(en) != FORMAT.findall(text):
            errors.append(f"{key}: format codes {FORMAT.findall(en)} in English, {FORMAT.findall(text)} here")
        if len(COLOR.findall(en)) != len(COLOR.findall(text)) or en.count("|r") != text.count("|r"):
            errors.append(f"{key}: color codes differ from English")
        if len(TEXTURE.findall(en)) != len(TEXTURE.findall(text)):
            errors.append(f"{key}: textures differ from English")
        if en.count("\\n") != text.count("\\n"):
            warnings.append(f"{key}: {en.count(chr(92) + 'n')} line break(s) in English, {text.count(chr(92) + 'n')} here")
        if 0 < len(en) <= 24 and len(text) > max(len(en) * 1.6, len(en) + 8):
            warnings.append(f"{key}: short text grew from {len(en)} to {len(text)} characters (may not fit)")
    missing = [k for k, v in english.items() if v and k not in tr]
    for w in warnings:
        print("warning: " + w)
    for e in errors:
        print("ERROR: " + e)
    print(f"{os.path.basename(sys.argv[1])}: {len(tr)} strings, {len(missing)} not translated, "
          f"{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
