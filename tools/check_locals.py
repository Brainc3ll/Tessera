#!/usr/bin/env python3
"""Local-variable and upvalue limits of Lua 5.1 (the game's Lua).

A function (a whole file counts as one, its "main chunk") may have at most 200 local
variables alive at the same time and 60 upvalues. Past that, the file does not load and the
addon is dead. We stay well under: a margin leaves room for the next blocks and options.

Usage: python3 tools/check_locals.py [folder]     (needs luac5.1, installed with lua5.1)
Fails (exit 1) when a function has more than MAX_LOCALS locals alive at once or more than
MAX_UPVALUES upvalues. Reads the files listed in Tessera.toc.
"""
import re
import subprocess
import sys
from pathlib import Path

MAX_LOCALS = 160    # Lua refuses 200; 160 keeps a margin (rule of 13/11/2026)
MAX_UPVALUES = 50   # Lua refuses 60
# Files already over the limit, waiting to be split (docs/A-REPRENDRE.md): they may not grow.
# Remove the line when the file is split.
KNOWN_DEBT = {}

HEADER = re.compile(r"^(main|function) <([^:>]+):(\d+),\d+> ")
COUNTS = re.compile(r"(\d+) upvalues?, (\d+) locals?")
LOCAL = re.compile(r"^\s+\d+\s+\S+\s+(\d+)\s+(\d+)\s*$")


def alive_peak(spans):
    events = []
    for start, end in spans:
        events.append((start, 1))
        events.append((end, -1))
    events.sort(key=lambda e: (e[0], e[1]))  # at the same instruction, a local ends before another starts
    now = peak = 0
    for _, delta in events:
        now += delta
        peak = max(peak, now)
    return peak


def check_file(path):
    out = subprocess.run(["luac5.1", "-p", "-l", "-l", str(path)], capture_output=True, text=True)
    if out.returncode != 0:
        return None, out.stderr.strip()
    worst = []  # (locals alive at once, upvalues, line of the function)
    spans, head, in_locals = [], None, False
    lines = out.stdout.splitlines() + ["main <end:0,0> (0 instructions)"]
    for line in lines:
        m = HEADER.match(line)
        if m:
            if head:
                worst.append((alive_peak(spans), head[1], head[0]))
            head, spans, in_locals = [int(m.group(3)), 0], [], False
            continue
        m = COUNTS.search(line)
        if m and head and not in_locals and head[1] == 0:
            head[1] = int(m.group(1))
            continue
        if line.startswith("locals ("):
            in_locals = True
        elif line.startswith("constants (") or line.startswith("upvalues ("):
            in_locals = False
        elif in_locals:
            m = LOCAL.match(line)
            if m:
                spans.append((int(m.group(1)), int(m.group(2))))
    return worst, None


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    toc = (root / "Tessera.toc").read_text(encoding="utf-8").splitlines()
    files = [l.strip().replace("\\", "/") for l in toc if re.match(r"^[A-Za-z0-9_/\\]+\.lua\s*$", l.strip())]
    files = [f for f in files if not f.startswith("Locales/")]
    failed = False
    for name in files:
        worst, error = check_file(root / name)
        if worst is None:
            print(f"{name}: luac refuses it: {error}")
            failed = True
            continue
        top_locals = max(w[0] for w in worst)
        top_up = max(w[1] for w in worst)
        flag = ""
        debt = KNOWN_DEBT.get(name)
        max_locals, max_up = debt if debt else (MAX_LOCALS, MAX_UPVALUES)
        if top_locals > max_locals:
            flag += f"  <-- more than {max_locals} locals alive at once: split the file"
        if top_up > max_up:
            flag += f"  <-- a function uses more than {max_up} upvalues: split it"
        if debt and not flag:
            flag = "  (known debt: to split, may not grow)"
        if "<--" in flag:
            failed = True
        print(f"{name}: {top_locals} locals, {top_up} upvalues at most{flag}")
    print("Locals check: " + ("FAILED" if failed else f"OK (limit {MAX_LOCALS} locals, {MAX_UPVALUES} upvalues)"))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
