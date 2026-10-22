"""Builds Locales/enUS.lua and Locales/frFR.lua from the texts in this folder.

Run from the addon folder:   python3 tools/gen/build.py
On main, leave out the strings of the rows beta branch:
    TESSERA_EXCLUDE="ROWS_,MENU_ROW_ALIGN,ROW_ALIGN_" python3 tools/gen/build.py
Then: lua5.1 tools/export_locales.lua . enUS docs/localization/enUS.lua (and frFR).

Files: en.py (base strings), fr.py (their French), tips.py (option tooltips, EN and FR),
help_texts.py (newer strings, EN list and FR table), help_struct.py (in-game help: one key per
topic title and per line, in display order). English and French only: other languages come
from CurseForge's translation tool.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from en import EN  # noqa: E402
from fr import FR  # noqa: E402
from tips import TIPS_EN, TIPS_FR  # noqa: E402
from help_texts import NEW_EN, NEW_FR  # noqa: E402
from help_struct import HELP, HELP_BROKER  # noqa: E402

# In-game help: one key per topic title and per line (help_struct.py)
HELP_EN_KEYS, HELP_FR_KEYS = [], {}
for layout in (HELP, HELP_BROKER):
    for slug, te, tf, lines in layout:
        if ("HELP_T_" + slug) not in HELP_FR_KEYS:
            HELP_EN_KEYS.append(("HELP_T_" + slug, te))
            HELP_FR_KEYS["HELP_T_" + slug] = tf
        for k, a, b in lines:
            if k:
                HELP_EN_KEYS.append((k, a))
                HELP_FR_KEYS[k] = b
base = list(EN) + list(TIPS_EN.items()) + NEW_EN + HELP_EN_KEYS
# keys left out of a build (TESSERA_EXCLUDE="PREFIX1,PREFIX2"): strings of a beta branch kept out of main
excl = [p for p in os.environ.get("TESSERA_EXCLUDE", "").split(",") if p]
if excl:
    base = [(k, v) for k, v in base if not any(k.startswith(p) for p in excl)]
keys = [k for k, _ in base]
en = dict(base)
fr = {**FR, **TIPS_FR, **NEW_FR, **HELP_FR_KEYS}
for k in [k for k in fr if any(k.startswith(p) for p in excl)]:
    del fr[k]


def lua(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'


# checks: every key translated, no stray key, the same %s / %d in both languages
spec = re.compile(r'%[-0-9.]*[sdf]')
missing = [k for k in keys if k not in fr]
extra = [k for k in fr if k not in en]
bad = [k for k in keys if k in fr and spec.findall(fr[k]) != spec.findall(en[k])]
if missing or extra or bad:
    print("frFR missing", missing, "extra", extra, "format mismatch", bad)
    sys.exit(1)

out = os.path.join(HERE, "..", "..", "Locales")
with open(os.path.join(out, "enUS.lua"), "w") as f:
    f.write("local _, ns = ...\n\n-- Base English strings; every key here must exist. Other languages override keys and fall back to English.\nlocal L = {\n")
    for k, v in base:
        f.write(f"    {k} = {lua(v)},\n")
    f.write("}\n\nns.L = L\n")

    # order of the help: topics (title key) and their lines (keys, "" = empty line)
    def layout_lua(name, layout):
        rows = [f"ns.{name} = {{"]
        for slug, _, _, lines in layout:
            ks = ", ".join(lua(k) for k, _, _ in lines)
            rows.append(f'    {{ title = "HELP_T_{slug}", lines = {{ {ks} }} }},')
        rows.append("}")
        return "\n".join(rows)
    f.write("\n-- Help topics in display order (Options.lua joins the lines). One key per line, so a\n"
            "-- change to one line only asks translators to redo that line.\n")
    f.write(layout_lua("HELP_LAYOUT", HELP) + "\n")
    f.write(layout_lua("HELP_LAYOUT_BROKER", HELP_BROKER) + "\n")
with open(os.path.join(out, "frFR.lua"), "w") as f:
    f.write('local _, ns = ...\n\n-- French translation; missing keys fall back to English.\nlocal locale = GetLocale()\n'
            'if locale ~= "frFR" then return end\n\nlocal L = ns.L\n')
    for k in keys:
        f.write(f"L.{k} = {lua(fr[k])}\n")
print("generated", len(keys), "strings (enUS, frFR)")
