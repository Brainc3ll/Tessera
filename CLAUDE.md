# Working on Tessera (notes for Claude)

Tessera is written by Claude from the ideas and decisions of Braincell1980, who does not code.
Answer him in French; code, comments and commit messages in English.

## Every change, in the same commit
The documentation is as important as the code. With any new feature, block, option, command
or visible fix, update:
- the in-game help (Help tab, English and French) and the tooltip of every new option;
- `Changelog.lua`, then `lua5.1 tools/changelog_md.lua > CHANGELOG.md`;
- `README.md` (highlights, block list, commands, file table, developer notes);
- `docs/curseforge-description.md` and `docs/wago-description.md` (English and French parts);
- `docs/summary.md` if the core of the addon changes, `docs/A-REPRENDRE.md` (status),
  `docs/IDEES-FUTUR.md` (ideas done or new);
- `docs/localization/` (`lua5.1 tools/export_locales.lua . enUS docs/localization/enUS.lua`, same for frFR).

Then run, and fix everything they report:
```sh
luacheck .
lua5.1 tools/mock_run.lua . enUS      # also: frFR, "frFR broker" (includes a dungeon + combat scenario)
lua5.1 tools/fuzz_blocks.lua .        # WoW Forever's blocks survive a changing game
lua5.1 tools/check_docs.lua .         # add "release" before publishing
python3 tools/api_audit.py <lua-language-server> <vscode-wow-api folder>   # reviewers' audit
```
The WoW API audit (Ketho's annotations) runs on every push. No deprecated function, no unknown
global: WoW Forever-only functions and other addons' globals are read through `_G["Name"]`.
`tools/check_docs.lua` also runs on every push (`.github/workflows/checks.yml`) and stops a
release (`.github/workflows/release.yml`) when the documentation is behind. The release guide
is `docs/RELEASE.md`.

## Texts that are easy to translate
Changing a text on CurseForge makes translators redo all of it. Keep every text short: one key
per line or paragraph (the help: `HELP_<TOPIC>_<n>` keys ordered by `ns.HELP_LAYOUT` at the end
of `Locales/enUS.lua`). Add a line = a NEW key; change a line = keep its key; never renumber,
rename or reuse a key. `tools/check_docs.lua` refuses texts over 600 characters.

## Rules set by Braincell1980
- Never tag, release or publish without his explicit go ("on publie"); hold pushes when he asks to.
- Debug builds are never pushed to git.
- Players' layouts, styles and profiles must keep working after every update; if a big change
  ever has to break them, show a message and convert them.
- English and French only in the repository; other languages come from CurseForge's tool.
- Released versions have no command a player does not need. Test and development commands
  (`/tessera test`, debug report, probes) live only in `TesseraDev.lua`, outside this
  repository, added to the test zips given to Braincell1980 (never pushed, never released).
- No trademarked operating system names in layouts.
- Commit messages end with: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
