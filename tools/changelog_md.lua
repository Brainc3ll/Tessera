-- Writes CHANGELOG.md (English) from Changelog.lua, so both stay in sync.
-- Usage, from the addon folder:  lua5.1 tools/changelog_md.lua > CHANGELOG.md
local ns = {}
assert(loadfile("Changelog.lua"))("Tessera", ns)
print("# Changelog")
print("")
print("All notable changes to Tessera. The in-game **About** tab (Changelog topic) shows the same list")
print("(from `Changelog.lua`), in English or French depending on the game language.")
for _, entry in ipairs(ns.CHANGELOG) do
    print("")
    print(("## %s — %s"):format(entry.version, entry.date))
    print("")
    for _, line in ipairs(entry.en) do print("- " .. line) end
end
