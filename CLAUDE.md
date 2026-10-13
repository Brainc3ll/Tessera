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
lua5.1 tools/mock_run.lua . enUS      # also: frFR, "frFR broker"
lua5.1 tools/check_docs.lua .         # add "release" before publishing
```
`tools/check_docs.lua` also runs on every push (`.github/workflows/checks.yml`) and stops a
release (`.github/workflows/release.yml`) when the documentation is behind. The release guide
is `docs/RELEASE.md`.

## Rules set by Braincell1980
- Never tag, release or publish without his explicit go ("on publie"); push only when he agrees.
- Debug builds are never pushed to git.
- Players' layouts, styles and profiles must keep working after every update; if a big change
  ever has to break them, show a message and convert them.
- English and French only in the repository; other languages come from CurseForge's tool.
- Development commands are never mentioned in the interface or the help.
- No trademarked operating system names in layouts.
- Commit messages end with: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
