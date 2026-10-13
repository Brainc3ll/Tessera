-- Checks that the documentation follows the code, so it never falls behind.
-- Run from the addon folder:   lua5.1 tools/check_docs.lua .
--   (add "release" as 2nd argument before publishing: the newest changelog entry must be dated)
-- It runs on every push (.github/workflows/checks.yml) and before every release
-- (.github/workflows/release.yml): a failure stops the release.
--
-- What it checks:
--   1. Version: Tessera.toc, Changelog.lua and CHANGELOG.md name the same newest version.
--   2. CHANGELOG.md is exactly what tools/changelog_md.lua makes from Changelog.lua.
--   3. docs/localization/enUS.lua and frFR.lua (sent to CurseForge) match the Locales files.
--   4. Every public slash command is documented in the README, the in-game help (English
--      and French), the chat command list and the CurseForge / Wago descriptions; a new
--      command in Core.lua must be added to PUBLIC or HIDDEN below.
--   5. Every block is named in the README and in the English and French parts of the
--      CurseForge / Wago descriptions (its name as shown in the game, or an alias below).
--   6. Every Lua file of Tessera.toc has a line in the README's file table.
--   7. Every option tab is described in the in-game help (English and French).
--   8. No text is too long to translate comfortably (MAX_LENGTH characters): long texts are
--      split into one key per line or paragraph (the help: Locales/enUS.lua, HELP_LAYOUT), so a
--      change to one line never asks translators to redo a whole page.
local dir, mode = arg[1] or ".", arg[2]
local errors = {}
local function fail(msg) errors[#errors + 1] = msg end

local function read(path)
    local f = io.open(dir .. "/" .. path, "r")
    if not f then fail("missing file: " .. path) return "" end
    local s = f:read("*a")
    f:close()
    return s
end

local function run(cmd)
    local p = io.popen("cd " .. dir .. " && " .. cmd .. " 2>&1")
    local out = p:read("*a")
    p:close()
    return out
end

-- Case-insensitive search; line breaks and repeated spaces count as one space
local function has(text, word)
    return (text:lower():gsub("%s+", " ")):find((word:lower():gsub("%s+", " ")), 1, true) ~= nil
end

-- Locale tables, English and French (French overrides English)
-- The help as one text, joined from its keys like Options.lua does (ns.HelpText)
local function helpText(L, layout)
    local parts = {}
    for _, topic in ipairs(layout or {}) do
        parts[#parts + 1] = L[topic.title] or ""
        for _, key in ipairs(topic.lines) do parts[#parts + 1] = key == "" and "" or (L[key] or "") end
    end
    return table.concat(parts, "\n")
end

local function loadLocale(code)
    local ns = {}
    _G.GetLocale = function() return code end
    assert(loadfile(dir .. "/Locales/enUS.lua"))("Tessera", ns)
    if code ~= "enUS" then assert(loadfile(dir .. "/Locales/" .. code .. ".lua"))("Tessera", ns) end
    ns.L.HELP_TEXT = helpText(ns.L, ns.HELP_LAYOUT) -- for the checks below only
    return ns.L, ns
end
local EN, enNS = loadLocale("enUS")
local FR = loadLocale("frFR")

local readme = read("README.md")
-- descriptions: English part, then French part after the "---" line
local descriptions = {}
for _, name in ipairs({ "docs/curseforge-description.md", "docs/wago-description.md" }) do
    local text = read(name)
    local en, fr = text:match("^(.-)\n%-%-%-\n(.*)$")
    if not en then fail(name .. ": no '---' line between the English and French parts") end
    descriptions[#descriptions + 1] = { name = name, en = en or text, fr = fr or "" }
end

---------------------------------------------------------------------------
-- 1. Version
---------------------------------------------------------------------------
local toc = read("Tessera.toc")
local version = toc:match("## Version:%s*([^\r\n]+)")
local changelogLua = read("Changelog.lua")
local luaVersion, luaDate = changelogLua:match('version = "([^"]+)",%s*date = "([^"]*)"')
local mdVersion = read("CHANGELOG.md"):match("\n## (%S+)")
if version ~= luaVersion then fail(("version: Tessera.toc says %s, Changelog.lua %s"):format(tostring(version), tostring(luaVersion))) end
if version ~= mdVersion then fail(("version: Tessera.toc says %s, CHANGELOG.md %s"):format(tostring(version), tostring(mdVersion))) end
if mode == "release" and (luaDate or "") == "" then fail("release: the newest entry of Changelog.lua has no date") end

---------------------------------------------------------------------------
-- 2. CHANGELOG.md made from Changelog.lua
---------------------------------------------------------------------------
if run("lua5.1 tools/changelog_md.lua") ~= read("CHANGELOG.md") then
    fail("CHANGELOG.md differs from Changelog.lua: run  lua5.1 tools/changelog_md.lua > CHANGELOG.md")
end

---------------------------------------------------------------------------
-- 3. Strings sent to CurseForge
---------------------------------------------------------------------------
for _, code in ipairs({ "enUS", "frFR" }) do
    local tmp = os.tmpname()
    run(("lua5.1 tools/export_locales.lua . %s %s"):format(code, tmp))
    local f = io.open(tmp, "r")
    local fresh = f and f:read("*a") or ""
    if f then f:close() end
    os.remove(tmp)
    if fresh ~= read("docs/localization/" .. code .. ".lua") then
        fail(("docs/localization/%s.lua is out of date: run  lua5.1 tools/export_locales.lua . %s docs/localization/%s.lua"):format(code, code, code))
    end
end

---------------------------------------------------------------------------
-- 4. Slash commands
---------------------------------------------------------------------------
-- documented commands (what follows "/tessera ")
local PUBLIC = { "lock", "unlock", "reset", "minimap", "preview", "preview forever", "recover", "broker", "bug", "help" }
-- never documented: French aliases and development commands
local HIDDEN = { minicarte = true, apercu = true, ["aperçu"] = true, recuperer = true, ["récupérer"] = true,
    debug = true, ["debug skills"] = true, ["debug legacy"] = true, atelier = true }
local isPublic = {}
for _, c in ipairs(PUBLIC) do isPublic[c] = true end
local core = read("Core.lua")
for c in core:gmatch('msg == "([^"]+)"') do
    if not isPublic[c] and not HIDDEN[c] then
        fail(("command /tessera %s (Core.lua) is neither documented nor listed as hidden in tools/check_docs.lua"):format(c))
    end
end
local places = {
    { "README.md", readme },
    { "help (English)", EN.HELP_TEXT or "" },
    { "help (French)", FR.HELP_TEXT or "" },
    { "chat command list (English)", EN.CMD_HELP or "" },
    { "chat command list (French)", FR.CMD_HELP or "" },
}
for _, d in ipairs(descriptions) do
    places[#places + 1] = { d.name .. " (English)", d.en }
    places[#places + 1] = { d.name .. " (French)", d.fr }
end
for _, c in ipairs(PUBLIC) do
    for _, p in ipairs(places) do
        if not has(p[2], "/tessera " .. c) then fail(("command /tessera %s missing from %s"):format(c, p[1])) end
    end
end

---------------------------------------------------------------------------
-- 5. Blocks
---------------------------------------------------------------------------
-- Other words accepted for a block when its in-game name reads badly in a sentence
-- (locale key -> { English, French })
local ALIASES = {
    PROFESSION_1 = { "profession", "métier" }, PROFESSION_2 = { "profession", "métier" },
    MEMORY = { "memory", "mémoire" }, WEAPON_SKILLS = { "weapon skills", "compétences d'armes" },
    LEGACY = { "legacy", "héritage" }, RESET = { "reset", "réinitialisation" },
}
local out = run("TESSERA_LIST_MODULES=1 lua5.1 tools/mock_run.lua . enUS")
local count = 0
for key, label in out:gmatch("MODULE (%S+) (%S+)") do
    count = count + 1
    local en, fr = EN[label], FR[label]
    local alias = ALIASES[label] or {}
    local function found(text, name, other) return (name and has(text, name)) or (other and has(text, other)) end
    if not found(readme, en, alias[1]) then fail(("block %s (%s) is not named in README.md"):format(key, tostring(en))) end
    for _, d in ipairs(descriptions) do
        if not found(d.en, en, alias[1]) then fail(("block %s (%s) is not named in %s (English)"):format(key, tostring(en), d.name)) end
        if not found(d.fr, fr, alias[2]) then fail(("block %s (%s) is not named in %s (French)"):format(key, tostring(fr), d.name)) end
    end
end
if count == 0 then fail("could not get the list of blocks from tools/mock_run.lua") end

---------------------------------------------------------------------------
-- 6. Files of the TOC in the README
---------------------------------------------------------------------------
for file in toc:gmatch("\n([%w_/]+%.lua)") do
    if not readme:find("`" .. file .. "`", 1, true) then fail(("file %s (Tessera.toc) has no line in the README's file table"):format(file)) end
end

---------------------------------------------------------------------------
-- 7. Option tabs in the help
---------------------------------------------------------------------------
local TABS = { "TAB_BLOCK", "TAB_LOOK", "TAB_GENERAL", "LAUNCHERS", "TAB_BROKER", "PROFILES" }
for _, tab in ipairs(TABS) do
    for _, loc in ipairs({ { "English", EN }, { "French", FR } }) do
        local name = loc[2][tab]
        if name and not has(loc[2].HELP_TEXT or "", name) then
            fail(("the %s tab (%s) is not described in the help (%s)"):format(tab, name, loc[1]))
        end
    end
end

---------------------------------------------------------------------------
-- 8. Texts short enough to translate
---------------------------------------------------------------------------
local MAX_LENGTH = 600
for key, text in pairs(EN) do
    if key ~= "HELP_TEXT" and type(text) == "string" and #text > MAX_LENGTH then
        fail(("text %s is %d characters long (max %d): split it into several keys"):format(key, #text, MAX_LENGTH))
    end
end
-- every help line exists in French too (a missing one would show in English)
for _, layout in ipairs({ enNS.HELP_LAYOUT or {}, enNS.HELP_LAYOUT_BROKER or {} }) do
    for _, topic in ipairs(layout) do
        for _, key in ipairs({ topic.title, unpack(topic.lines) }) do
            if key ~= "" and (FR[key] == nil or FR[key] == EN[key] and #EN[key] > 20) then
                fail(("help line %s has no French translation"):format(key))
            end
        end
    end
end

---------------------------------------------------------------------------
if #errors > 0 then
    print(("Documentation check: %d problem(s)"):format(#errors))
    for _, e in ipairs(errors) do print("  - " .. e) end
    os.exit(1)
end
print("Documentation check: OK (" .. count .. " blocks, " .. #PUBLIC .. " commands)")
