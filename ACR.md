---
rating: E4d
spec: "0.1"
updated: 2026-10-25
---

# AI Code Rating

**ACR E4d** (Maintainer: Non-programmer · AI Share: 76–100% · Oversight: Tested Only)

This project is rated with [AI Code Rating](https://aicoderating.com/spec/0.1/), spec version 0.1.

## How AI Was Used

Tessera's maintainer, Braincell1980, does not write code. He decides what the addon does, how it
looks and when a version ships. Claude (an AI by Anthropic) writes all the Lua code, the automated
tests and the release tools from his instructions. No human reads the code line by line. Before
each push, every change goes through automated checks: luacheck, a run of the whole addon against
an imitation of the game API in English and French, and an audit of every WoW API call. Before each
release, Braincell1980 tests the version in WoW Forever. Found a bug? Type `/tessera bug` and post
the report on GitHub or CurseForge.
