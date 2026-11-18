#!/usr/bin/env python3
"""WoW API audit, the same way addon reviewers do it (for example the r/WoWUI moderators):
the Lua Language Server with Ketho's WoW API annotations (github.com/Ketho/vscode-wow-api),
set up like his VS Code extension (Lua 5.1, the game's known globals accepted).

It fails on what reviewers reject:
  - undefined globals: a misspelled name, an API that no longer exists, or a function
    that only exists on WoW Forever / in another addon and is not read through _G["Name"];
  - deprecated functions (Blizzard replaced or will remove them).
Type warnings (nil checks, parameter types) are listed for information only.

Usage, from the addon folder:
    python3 tools/api_audit.py <lua-language-server binary> <vscode-wow-api folder>
Runs on every push (.github/workflows/checks.yml).
"""
import json, os, re, shutil, subprocess, sys, tempfile

if len(sys.argv) != 3:
    sys.exit(__doc__)
luals, ketho = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
addon = os.getcwd()

# The game's known globals (frames, strings, constants...), as the extension accepts them:
# every name in its globals list that is not part of the documented API.
def names(path):
    with open(path, encoding="utf-8") as f:
        return set(re.findall(r'^\s*"([^"]+)": true', f.read(), re.M))
data = os.path.join(ketho, "src", "data")
known = sorted(names(os.path.join(data, "globals.ts")) - names(os.path.join(data, "globalapi.ts")))

work = tempfile.mkdtemp(prefix="tessera-audit-")
try:
    # the addon's files only (not the tools, docs or workflows)
    # every Lua file of Tessera.toc (they live in folders), except the Locales copied below
    with open(os.path.join(addon, "Tessera.toc"), encoding="utf-8") as f:
        toc = [l.strip().replace("\\", "/") for l in f]
    files = [l for l in toc if re.match(r"^[A-Za-z0-9_/]+\.lua$", l) and not l.startswith("Locales/")]
    if not files:
        sys.exit("api_audit: no Lua file found through Tessera.toc")
    for rel in files:
        os.makedirs(os.path.dirname(os.path.join(work, rel)), exist_ok=True)
        shutil.copy(os.path.join(addon, rel), os.path.join(work, rel))
    shutil.copytree(os.path.join(addon, "Locales"), os.path.join(work, "Locales"))
    builtin = {k: "disable" for k in ("basic", "coroutine", "debug", "io", "math", "os",
                                      "package", "string", "table", "utf8")}
    with open(os.path.join(work, ".luarc.json"), "w") as f:
        json.dump({
            "runtime.version": "Lua 5.1",
            "runtime.builtin": builtin,
            "workspace.library": [os.path.join(ketho, "Annotations", "Core")],
            "workspace.checkThirdParty": False,
            "diagnostics.globals": known,
        }, f)
    log = os.path.join(work, ".log")
    out = subprocess.run([luals, "--check", work, "--checklevel=Information", "--logpath", log],
                         capture_output=True, text=True).stdout
finally:
    shutil.rmtree(work, ignore_errors=True)

out = re.sub(r"\x1b\[[0-9;]*m", "", out)
findings = sorted(set(re.findall(r"^(\S+\.lua:\d+:\d+) \[\w+\] (.*?) \(([\w-]+)\)$", out, re.M)))
blocking = [f for f in findings if f[2] in ("undefined-global", "deprecated")]
info = [f for f in findings if f[2] not in ("undefined-global", "deprecated")]

for where, msg, code in blocking:
    print(f"PROBLEM  {where.replace(work + os.sep, '')}  {msg} ({code})")
if info:
    print(f"(for information: {len(info)} type warning(s), not blocking)")
    for where, msg, code in info:
        print(f"  info   {where.replace(work + os.sep, '')}  {msg} ({code})")
print(f"WoW API audit: {len(blocking)} problem(s) in {len(files)} file(s)")
sys.exit(1 if blocking else 0)
