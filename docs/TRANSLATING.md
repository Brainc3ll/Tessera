# Translating Tessera

Tessera is written in English and French. Every other language lives in this repository, in
`Locales/` (one file per language: `deDE.lua`, `esES.lua`, `esMX.lua`, `ptBR.lua`...). Only the
languages WoW Forever offers have a file: it has no Italian, for one. A text
missing from a file shows in English in the game.

## What to translate

The English texts are in `docs/localization/enUS.lua`, one per line:

```lua
L["BAGS"] = "Bags"
```

Copy a line into your language's file and change only the text between the quotes. Keep:
- `%s`, `%d`, `%.1f`...: the game puts a name or a number there, in the same order;
- `|cff...` and `|r`: a color starts and ends;
- `|T...|t`: an icon;
- `\n`: a new line.

Keep texts short: a label or a button has little room.

## Two ways to send it

1. **Pull request**: change the file in `Locales/` and open a pull request.
2. **Issue**: open a "Translation" issue and paste your lines. We add them for you.

Before a pull request, you can check your file:

```sh
python3 tools/check_translation.py Locales/deDE.lua
```

It lists unknown keys, missing `%s` or colors, and texts that grew a lot.

Your name goes in the About tab of the addon if you wish.
