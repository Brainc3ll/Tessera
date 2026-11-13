local ADDON, ns = ...
local L = ns.L

-- Modules.lua: the tools shared by the data blocks, and the guide to adding one.
-- The blocks themselves live in ModulesCharacter, ModulesSocial, ModulesWorld, ModulesProgress,
-- ModulesSystem and ModulesForever (the categories of the demo), so no file gets near Lua's limit
-- of 200 local variables (tools/check_locals.py keeps each under 160).
-- A tool used by two categories lives here and is exported in ns.BlockTools at the end of this
-- file; a category file imports what it needs at its top. A tool used by one category stays in
-- its file. A new block goes in the file of its category, after the blocks already there.
--
-- HOW TO ADD A BLOCK
-- Call ns:RegisterModule(key, def). `key` is the unique internal id (also used in
-- saved variables, so never rename it once released). `def` is a table with:
--
--   label           Locale key of the block's name: L[label] is the display name,
--                   so add the key to the Locales files (e.g. label = "GOLD" -> L.GOLD).
--   icon            Icon texture path, shown when the "Show icon" option is checked.
--   getIcon(cfg)    Optional. Returns an icon that changes at runtime; overrides `icon`.
--   events          Optional. List of WoW events that trigger an update.
--   interval        Optional. Periodic update, in seconds (only while the block is shown,
--                   or while it is hidden because empty, so it can come back).
--   update(cfg)     Required. Returns the text to display and an optional level:
--                     1 = good (GOOD), 2 = warning (WARN), 3 = bad (BAD).
--                   The level only colors the text if the user enabled "Colorize".
--                   Returning nil shows "N/A" (L.NA). Errors are caught and printed once.
--                   (Core also passes the block key as a 2nd argument.)
--   tooltip(tt, cfg)  Optional. Adds lines to the tooltip `tt` (GameTooltip). The block
--                   name, click hint and "right-click: settings" lines are added for you.
--   customTooltip(frame, cfg)  Optional. Takes over the whole tooltip (anchor, Show()...);
--                   `tooltip` and `clickHint` are then ignored.
--   isEmpty(cfg)    Optional. Returns true when there is nothing to show; the block then
--                   hides itself if the user enabled "Hide when empty" (cfg.hideEmpty).
--                   Defining it is what makes that option available for the block.
--   secureMacro     Optional. Macro text run by a secure button on left-click. Use it to
--                   open game windows (bags, map, ...) without "tainting" Blizzard's UI.
--   onClick(frame, button, cfg)  Optional. Plain Lua click handler, for things that do
--                   not need a secure button. Right-click is reserved for block settings.
--   onWheel(delta, cfg)  Optional. Mouse wheel handler (delta > 0 = wheel up). Only
--                   active while blocks are locked.
--   clickHint       Optional. Line shown at the bottom of the tooltip ("Click: ...").
--   request()       Optional. Asks the server for fresh data (e.g. guild roster).
--                   Called 5 s after login, then every `requestInterval` seconds
--                   (default 60), only while the block is enabled. The answer comes back
--                   as an event, so list that event in `events`.
--   defaultEnabled  Set to false for a block that is hidden by default.
--   progress(cfg)   Optional. Returns 0..1: enables the "progress bar" option (the
--                   block's background fills accordingly).
--   thresholds      Optional. { warn, bad, low, min, max, step }: default orange / red
--                   thresholds (low = true when LOW values are bad); the player can
--                   change them per block. Use Threshold(cfg, value, def) in update.
--   options         Optional. Settings shown in the Behaviour tab for this block only:
--                   list of { kind = "check" | "dropdown" | "slider" | "number" |
--                   "text" | "color", field, label, tip (locale keys), values (for
--                   dropdowns: { key, label }), min / max / step, shown(cfg) }.
--   defaults        Optional. Default settings for this block (e.g. progressBar = true).
--   forced          Optional. Settings always applied (e.g. a spacer never has an icon).
--   chatText(cfg)   Optional. Plain text for "copy to chat" (Shift + click by default).
--   extraAction     Optional. { key, label, run(cfg) }: an extra choice for the
--                   Shift / middle click actions (e.g. coordinates: place a map pin).
--   alertOnShow     Optional. Flash the block when it appears (new mail, whisper...).
--
-- Minimal example (a block showing the player's level):
--
--   ns:RegisterModule("level", {
--       label = "LEVEL",                     -- needs L.LEVEL in the Locales
--       icon = "Interface\\Icons\\INV_Misc_Note_01",
--       events = { "PLAYER_LEVEL_UP" },
--       update = function(cfg)
--           return tostring(UnitLevel("player")), GOOD
--       end,
--   })

local GOOD, WARN, BAD = 1, 2, 3

-- Streamer mode: a name, realm or amount that must not show on a stream
local function Masked(text)
    if ns:IsStreamer() then return ns.HIDDEN end
    return text
end

-- Item info: modern C_Item API, classic global as fallback
local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or function() end

---------------------------------------------------------------------------
-- Session tracking: FPS and experience, recorded even while the blocks are hidden
---------------------------------------------------------------------------
local session = {
    start = GetTime(),
    fps = { sum = 0, count = 0 },
    xpGained = 0,
}

-- "1 hr 5 min" style duration (game API if available, else "1h 05m")
local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if SecondsToTime then return SecondsToTime(seconds) end
    return ("%dh %02dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

-- r, g, b of a class ("WARRIOR"...). Modern C_ClassColor API, else the classic RAID_CLASS_COLORS table; white if unknown
-- (soft or bright with the rest of the colors: ns:ClassColorRGB, Core.lua)
local function ClassColor(class)
    local r, g, b = ns:ClassColorRGB(class)
    if r then return r, g, b end
    return 1, 1, 1
end

-- value / max as a percentage, safe against max = 0
local function Percent(value, max)
    if not max or max == 0 then return 0 end
    return value / max * 100
end

-- Color code ("|cffRRGGBB") for a level (GOOD / WARN / BAD); close it with "|r"
-- Level (GOOD / WARN / BAD) of a value against thresholds. `def` holds the
-- module's defaults { warn, bad, low } (low = true when LOW values are bad); the
-- player can override them per block (cfg.warnAt / cfg.badAt, Behaviour tab).
local function Threshold(cfg, value, def)
    local warn = (cfg and cfg.warnAt) or def.warn
    local bad = (cfg and cfg.badAt) or def.bad
    if def.low then
        if value <= bad then return BAD end
        if value <= warn then return WARN end
    else
        if value >= bad then return BAD end
        if value >= warn then return WARN end
    end
    return GOOD
end

-- Default thresholds (min / max / step size the sliders in the options)
local THRESHOLDS = {
    bags       = { warn = 8, bad = 2, low = true, min = 0, max = 40, step = 1 },
    durability = { warn = 50, bad = 20, low = true, min = 0, max = 100, step = 5 },
    fps        = { warn = 45, bad = 25, low = true, min = 5, max = 144, step = 1 },
    latency    = { warn = 100, bad = 250, low = false, min = 20, max = 1000, step = 10 },
    ammo       = { warn = 200, bad = 50, low = true, min = 0, max = 1000, step = 10 },
}

local function LevelColor(level)
    return "|cff" .. (ns.LEVEL_COLORS[level] or "ffffff")
end

---------------------------------------------------------------------------
-- Gold
---------------------------------------------------------------------------
local COIN_ICONS = {
    gold = "Interface\\MoneyFrame\\UI-GoldIcon",
    silver = "Interface\\MoneyFrame\\UI-SilverIcon",
    copper = "Interface\\MoneyFrame\\UI-CopperIcon",
}

-- Money as text with coin icons. Uses the game's C_CurrencyInfo API, else our own
-- formatting. Also used by other files (ns.FormatMoney)
function ns.FormatMoney(money, size)
    size = size or 12
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        local ok, text = pcall(C_CurrencyInfo.GetCoinTextureString, money, size)
        if ok and text then return text end
    end

    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    local function Icon(file) return ("|T%s:%d:%d:2:0|t"):format(file, size, size) end

    local parts = {}
    if gold > 0 then
        table.insert(parts, (BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or gold) .. Icon(COIN_ICONS.gold))
    end
    if gold > 0 or silver > 0 then
        table.insert(parts, silver .. Icon(COIN_ICONS.silver))
    end
    table.insert(parts, copper .. Icon(COIN_ICONS.copper))
    return table.concat(parts, " ")
end

-- Gold amount as the block's options say:
--   goldFormat    "full" (gold, silver, copper), "goldSilver", "gold" (gold pieces only)
--                 or "short" (12.3k gold)
--   goldIcons     coin icons (default), or colored letters (g s c / po pa pc)
--   goldRound     rounded to the nearest shown unit instead of cut off
--   goldSeparator thousands separator (default)
local COIN_COLORS = { gold = "ffd100", silver = "c7c7cf", copper = "eda55f" }
local function FormatGold(money, cfg)
    cfg = cfg or {}
    local format = cfg.goldFormat or "full"
    local size = cfg.fontSize or 12
    local function Unit(kind)
        -- coin icons, or letters (black and white styles: the icons cannot turn grey)
        if cfg.goldIcons ~= false and not cfg.monochrome then return ("|T%s:%d:%d:2:0|t"):format(COIN_ICONS[kind], size, size) end
        return "|cff" .. COIN_COLORS[kind] .. L["COIN_" .. kind:upper()] .. "|r"
    end
    local function Number(n)
        if cfg.goldSeparator ~= false and BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
        return tostring(n)
    end
    local round = cfg.goldRound and 0.5 or 0
    if format == "short" then
        local gold = money / 10000
        if gold >= 1000000 then return ("%.1fM"):format(gold / 1000000) .. Unit("gold") end
        if gold >= 1000 then return ("%.1fk"):format(gold / 1000) .. Unit("gold") end
        format = "gold"
    end
    if format == "gold" then return Number(math.floor(money / 10000 + round)) .. Unit("gold") end
    if format == "goldSilver" then money = math.floor(money / 100 + round) * 100 end
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    local parts = {}
    if gold > 0 then table.insert(parts, Number(gold) .. Unit("gold")) end
    if format == "goldSilver" then
        if silver > 0 or gold == 0 then table.insert(parts, silver .. Unit("silver")) end
    else
        if gold > 0 or silver > 0 then table.insert(parts, silver .. Unit("silver")) end
        table.insert(parts, copper .. Unit("copper"))
    end
    return table.concat(parts, " ")
end

---------------------------------------------------------------------------
-- Experience
---------------------------------------------------------------------------
-- True at max level. Uses the modern API if present, else "no XP bar" means max level
local function AtMaxLevel()
    local level = UnitLevel("player")
    if IsLevelAtEffectiveMaxLevel then return IsLevelAtEffectiveMaxLevel(level) end
    -- WoW Forever has no IsLevelAtEffectiveMaxLevel: its max level comes from GetMaxPlayerLevel
    local cap = GetMaxPlayerLevel and GetMaxPlayerLevel()
    if type(cap) == "number" and cap > 0 then return level >= cap end
    local max = UnitXPMax("player")
    return not max or max == 0
end

---------------------------------------------------------------------------
-- Friends and guild
---------------------------------------------------------------------------
-- Maximum names listed in a tooltip (the rest is shown as "and N more")
local MAX_LINES = 20

---------------------------------------------------------------------------
-- Small helpers for the blocks below
---------------------------------------------------------------------------
-- Safe call: returns nil if `fn` does not exist on this client (modern vs classic API)
-- or if it errors (pcall). Returns at most 12 values
local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k, l = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j, k, l end
end

-- Compact duration: "1h05" or "4:32"
local function ShortTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if seconds >= 3600 then return ("%dh%02d"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)) end
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- Compact duration for a block: "45m", "3h12", "2d 5h" (day letter translated)
local function ShortDuration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if seconds >= 86400 then
        return L.DURATION_DAYS:format(math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600))
    end
    if seconds >= 3600 then return ("%dh%02d"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)) end
    return ("%dm"):format(math.floor(seconds / 60))
end

-- Adds a tooltip line with both columns in white
local function WHITE(tt, left, right)
    tt:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
end

---------------------------------------------------------------------------
-- Professions and weapon skills
---------------------------------------------------------------------------
-- Classic clients list skills in the character's skill window. Header names are
-- translated, so skills are sorted by their properties instead:
--   professions (primary and secondary) can be unlearned ("abandonable");
--   weapon skills cannot, and their cap is 5 x the character's level.
-- Skills under a collapsed header in the skill window are not listed by the game.
-- Returns { professions = {...}, weapons = {...} }, each entry { name, rank, max }.
local WEAPON_CATEGORY = 6 -- C_SkillInfo: skill line category of the weapon skills
local function SkillLines()
    local result = { professions = {}, weapons = {} }
    -- WoW Forever: C_SkillInfo returns one table per line (name, rank, maxRank, isHeader,
    -- isAbandonable, skillLineCategoryID, skillID...)
    local S = _G["C_SkillInfo"] -- WoW Forever only (not in the modern API docs)
    if S and S.GetNumSkillLines and S.GetSkillLineInfo then
        for i = 1, tonumber((Try(S.GetNumSkillLines))) or 0 do
            local info = Try(S.GetSkillLineInfo, i)
            if type(info) == "table" and info.name and not info.isHeader then
                local entry = { name = info.name, rank = info.rank or 0, max = info.maxRank or 0, id = info.skillID }
                if info.isAbandonable then
                    table.insert(result.professions, entry)
                elseif info.skillLineCategoryID == WEAPON_CATEGORY then
                    table.insert(result.weapons, entry)
                end
            end
        end
        return result
    end
    return result
end

-- Macro that clicks one of Blizzard's micro buttons when this client has it (WoW Forever
-- has ProfessionMicroButton, TalentMicroButton, LegacyMicroButton...), else the fallback.
-- Clicking the real button opens the panel from Blizzard's own code, without taint.
local function MicroButtonMacro(button, fallback)
    if _G[button] then return "/click " .. button end
    return fallback
end

local function SkillTooltip(tt, list)
    for _, s in ipairs(list) do
        local color = s.rank >= s.max and "|cff4dff4d" or "|cffffffff"
        tt:AddDoubleLine(s.name, ("%s%d / %d|r"):format(color, s.rank, s.max), 1, 1, 1)
    end
end

local GetItemCountFn = (C_Item and C_Item.GetItemCount) or function() return 0 end

-- Shared with ModulesCharacter.lua, ModulesSocial.lua, ... (each file imports what it needs)
ns.BlockTools = {
    AtMaxLevel = AtMaxLevel,
    BAD = BAD,
    COIN_ICONS = COIN_ICONS,
    ClassColor = ClassColor,
    FormatDuration = FormatDuration,
    FormatGold = FormatGold,
    GOOD = GOOD,
    GetItemCountFn = GetItemCountFn,
    GetItemInfoFn = GetItemInfoFn,
    LevelColor = LevelColor,
    MAX_LINES = MAX_LINES,
    Masked = Masked,
    MicroButtonMacro = MicroButtonMacro,
    Percent = Percent,
    ShortDuration = ShortDuration,
    ShortTime = ShortTime,
    SkillLines = SkillLines,
    SkillTooltip = SkillTooltip,
    THRESHOLDS = THRESHOLDS,
    Threshold = Threshold,
    Try = Try,
    WARN = WARN,
    WHITE = WHITE,
    session = session,
}

-- Order of the blocks: the options list and the default place of blocks never placed follow it.
-- It is the order they had when they all lived in one file; a block added later goes after these
-- (in the order its file registers it), so a new block needs no line here.
ns.MODULE_ORDER = {
    "gold", "bags", "durability", "fps", "latency", "time", "serverTime", "date", "xp", "coords", "zone",
    "subzone", "friends", "guild", "memory", "hearthstone", "mail", "quests", "reputation", "currency",
    "ammo", "itemLevel", "speed", "volume", "regen", "stats", "loot", "instances", "profession1",
    "profession2", "cooking", "firstAid", "fishing", "weaponSkills", "legacy", "talents", "rested", "played",
    "group", "reset", "goal", "reagents", "whispers", "comprehension", "camping", "honor", "streamer", "pet",
    "weaponEnchant", "longBuffs", "corpse", "xpRate", "goldSession", "microMenu",
}

function ns:SortModules()
    local rank, pos = {}, {}
    for i, key in ipairs(self.MODULE_ORDER) do rank[key] = i end
    for i, key in ipairs(self.order) do pos[key] = i end
    table.sort(self.order, function(a, b)
        return (rank[a] or 1000 + pos[a]) < (rank[b] or 1000 + pos[b])
    end)
end
