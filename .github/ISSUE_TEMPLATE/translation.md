---
name: Translation
about: Send a new translation of Tessera, or correct one
title: "Translation: <language>"
labels: translation
---

**Language:** (for example: German, deDE)

**Your name for the About tab** (or "none"):

Paste your lines below, one per text, in the same form as the files of `Locales/`:

```lua
L["KEY"] = "your text"
```

Keep `%s`, `%d`, `|c...|r` and `|T...|t` as they are: they are filled in by the game.
The English texts to translate are in `docs/localization/enUS.lua`. See `docs/TRANSLATING.md`.
