-- Saved variables of a 1.0.0-rc9 player on the WoW Forever beta (names made up): the
-- character keys carry the beta's ruleset label. Old-data test of the character keys:
--   TESSERA_SV=tools/fixtures/sv-rc9-forever.lua TESSERA_FULLNAME="Nora Quill" \
--   TESSERA_REALM="Classic PvE" lua5.1 tools/mock_run.lua . enUS | grep "^SV"
-- Expected: every key is the full name alone (Nora Quill, Tobin Harrow, Mira Fenwick).
TesseraDB = {
    ["goldHistory"] = {
        ["Nora Quill-Classic Beta PvE"] = { ["2026-10-22"] = 45000, ["2026-10-23"] = -12000 },
        ["Tobin Harrow-Classic Beta PvE"] = { ["2026-10-22"] = 800 },
    },
    ["charProfiles"] = { ["Mira Fenwick-Classic Beta PvE"] = "Default" },
    ["profiles"] = { ["Default"] = {} },
    ["welcomed"] = true,
    ["lastVersion"] = "1.0.0-rc9-hotfix",
    ["globalProfile"] = "Default",
    ["useGlobal"] = true,
    ["chars"] = {
        ["Tobin Harrow-Classic Beta PvE"] = { ["money"] = 61, ["class"] = "HUNTER" },
        ["Mira Fenwick-Classic Beta PvE"] = { ["money"] = 3200, ["class"] = "DRUID" },
        ["Nora Quill-Classic Beta PvE"] = { ["money"] = 987654, ["class"] = "MAGE" },
    },
}
