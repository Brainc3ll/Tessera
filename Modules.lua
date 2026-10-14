local ADDON, ns = ...
local L = ns.L

-- Modules.lua: every data block (gold, bags, FPS, ...) is defined here.
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
local ignoreFPSUntil = GetTime() + 10 -- loading screens skew the FPS numbers

-- "1 hr 5 min" style duration (game API if available, else "1h 05m")
local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if SecondsToTime then return SecondsToTime(seconds) end
    return ("%dh %02dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

-- Records XP gained this session (handles level-ups, where the XP bar resets)
local tracker = CreateFrame("Frame")
tracker:RegisterEvent("PLAYER_ENTERING_WORLD")
tracker:RegisterEvent("PLAYER_XP_UPDATE")
tracker:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        ignoreFPSUntil = GetTime() + 5
        session.lastXP, session.lastXPMax = UnitXP("player"), UnitXPMax("player")
    else
        local cur, max = UnitXP("player"), UnitXPMax("player")
        local last, lastMax = session.lastXP, session.lastXPMax
        if last then
            -- level gained: rest of the previous level + start of the new one
            local gained = cur >= last and (cur - last) or ((lastMax or last) - last + cur)
            session.xpGained = session.xpGained + gained
        end
        session.lastXP, session.lastXPMax = cur, max
    end
end)

-- History for the tooltip graphs: one point every 5 seconds, last 5 minutes
local GRAPH_POINTS, GRAPH_STEP = 60, 5
local history = { fps = {}, latency = {} }
local fpsBucket = { sum = 0, count = 0 }

local function PushHistory(list, value)
    table.insert(list, value)
    if #list > GRAPH_POINTS then table.remove(list, 1) end
end

-- Samples FPS once per second for the session average / min / max (and the graph)
C_Timer.NewTicker(1, function()
    if GetTime() < ignoreFPSUntil then return end
    local fps = GetFramerate()
    if not fps or fps <= 0 then return end
    local f = session.fps
    f.sum, f.count = f.sum + fps, f.count + 1
    f.min = f.min and math.min(f.min, fps) or fps
    f.max = f.max and math.max(f.max, fps) or fps
    fpsBucket.sum, fpsBucket.count = fpsBucket.sum + fps, fpsBucket.count + 1
    if fpsBucket.count >= GRAPH_STEP then
        PushHistory(history.fps, fpsBucket.sum / fpsBucket.count)
        fpsBucket.sum, fpsBucket.count = 0, 0
    end
end)

-- Samples the world latency every 5 seconds for its graph
C_Timer.NewTicker(GRAPH_STEP, function()
    local _, _, _, world = GetNetStats()
    if world and world > 0 then PushHistory(history.latency, world) end
end)

-- Small bar graph drawn inside the tooltip, under a title line. Space is reserved
-- with blank lines, then a frame with one bar per point is laid over them.
local GRAPH_W, GRAPH_H = 200, 34
local graph

local function AddGraph(tt, title, values, levelOf)
    if #values < 2 or not tt.GetName or not tt:GetName() then return end
    tt:AddLine(" ")
    tt:AddLine(title, 0.8, 0.8, 0.8)
    local first = tt:NumLines() + 1
    for _ = 1, 3 do tt:AddLine(" ") end
    local line = _G[tt:GetName() .. "TextLeft" .. first]
    if not line then return end
    if not graph then
        graph = CreateFrame("Frame", nil, tt)
        graph.bars = {}
        -- the graph belongs to one tooltip display only
        tt:HookScript("OnHide", function() graph:Hide() end)
        tt:HookScript("OnTooltipCleared", function(self)
            graph:Hide()
            if graph.widened and self.SetMinimumWidth then
                self:SetMinimumWidth(0)
                graph.widened = nil
            end
        end)
    end
    graph:SetParent(tt)
    graph:ClearAllPoints()
    graph:SetPoint("TOPLEFT", line, "TOPLEFT", 0, -2)
    graph:SetSize(GRAPH_W, GRAPH_H)
    if tt.SetMinimumWidth then
        tt:SetMinimumWidth(GRAPH_W + 24)
        graph.widened = true
    end
    local maxV = 1
    for _, v in ipairs(values) do maxV = math.max(maxV, v) end
    local barW = GRAPH_W / GRAPH_POINTS
    for i = 1, GRAPH_POINTS do
        local bar = graph.bars[i]
        if not bar then
            bar = graph:CreateTexture(nil, "ARTWORK")
            graph.bars[i] = bar
        end
        local v = values[#values - GRAPH_POINTS + i]
        if v then
            local hex = ns.LEVEL_COLORS[levelOf(v)] or "ffffff"
            bar:SetColorTexture(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
                tonumber(hex:sub(5, 6), 16) / 255, 0.85)
            bar:ClearAllPoints()
            bar:SetSize(math.max(1, barW - 1), math.max(1, v / maxV * GRAPH_H))
            bar:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", (i - 1) * barW, 0)
            bar:Show()
        else
            bar:Hide()
        end
    end
    graph:Show()
end

-- Game frame rate cap (0 or disabled = unlimited). pcall: the CVar may not exist on every client
local function FPSCap(useVar, valueVar)
    local ok, use = pcall(GetCVar, useVar)
    local ok2, value = pcall(GetCVar, valueVar)
    value = ok2 and tonumber(value)
    if (ok and use == "0") or not value or value <= 0 then return L.TT_UNLIMITED end
    return L.FPS_FORMAT:format(value)
end

-- r, g, b of a class ("WARRIOR"...). Modern C_ClassColor API, else the classic RAID_CLASS_COLORS table; white if unknown
local function ClassColor(class)
    local c = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if c then return c.r, c.g, c.b end
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

-- Signed amount with colored + / - (tooltip lines)
local function SignedMoney(diff)
    local sign = diff >= 0 and "|cff4dff4d+|r " or "|cffff4d4d-|r "
    return sign .. ns.FormatMoney(math.abs(diff))
end

ns:RegisterModule("gold", {
    label = "GOLD",
    icon = COIN_ICONS.gold,
    events = { "PLAYER_MONEY" },
    update = function(cfg)
        return FormatGold(GetMoney() or 0, cfg)
    end,
    -- Shift + click "copy to chat": plain text, without coin textures
    chatText = function()
        local money = GetMoney() or 0
        return L.CHAT_MONEY:format(math.floor(money / 10000), math.floor(money % 10000 / 100), money % 100)
    end,
    defaults = { goldIcons = true, goldRound = false, goldSeparator = true },
    options = {
        { kind = "dropdown", field = "goldFormat", tab = "text", label = "GOLD_FORMAT", tip = "TIP_GOLD_FORMAT",
          values = { { key = "full", label = "GOLD_FULL" }, { key = "goldSilver", label = "GOLD_SILVER" },
                     { key = "gold", label = "GOLD_ONLY" }, { key = "short", label = "GOLD_SHORT" } } },
        { kind = "check", field = "goldIcons", tab = "text", label = "GOLD_ICONS", tip = "TIP_GOLD_ICONS" },
        { kind = "check", field = "goldRound", tab = "text", label = "GOLD_ROUND", tip = "TIP_GOLD_ROUND",
          shown = function(cfg) return cfg.goldFormat == "gold" or cfg.goldFormat == "goldSilver" end },
        { kind = "check", field = "goldSeparator", tab = "text", label = "GOLD_SEPARATOR", tip = "TIP_GOLD_SEPARATOR" },
    },
    tooltip = function(tt)
        local money = GetMoney() or 0
        local diff = money - (ns.sessionMoney or money)
        tt:AddDoubleLine(L.TT_SESSION, SignedMoney(diff), 1, 1, 1, 1, 1, 1)
        local hours = (GetTime() - session.start) / 3600
        if hours >= 0.1 and diff ~= 0 then
            tt:AddDoubleLine(L.TT_GOLD_HOUR, SignedMoney(math.floor(diff / hours)), 1, 1, 1, 1, 1, 1)
        end

        -- last 7 days for this character (net gain or loss per day), newest first
        local days = ns.sv.goldHistory and ns.sv.goldHistory[ns.charKey]
        if days then
            local list = {}
            for day, net in pairs(days) do table.insert(list, { day = day, net = net }) end
            table.sort(list, function(a, b) return a.day > b.day end)
            if #list > 0 then
                tt:AddLine(" ")
                tt:AddLine(L.TT_GOLD_HISTORY, 1, 0.82, 0)
                for i = 1, math.min(7, #list) do
                    local m, d = list[i].day:match("%d+-(%d+)-(%d+)")
                    tt:AddDoubleLine(d and (d .. "/" .. m) or list[i].day, SignedMoney(list[i].net), 1, 1, 1, 1, 1, 1)
                end
            end
        end

        local chars, total = {}, 0
        for name, data in pairs(ns.sv.chars) do
            table.insert(chars, { name = name, money = data.money or 0, class = data.class })
            total = total + (data.money or 0)
        end
        if #chars > 1 then
            table.sort(chars, function(a, b) return a.money > b.money end)
            local realm = "-" .. (GetRealmName() or "")
            tt:AddLine(" ")
            tt:AddLine(L.TT_CHARACTERS, 1, 0.82, 0)
            for _, c in ipairs(chars) do
                local r, g, b = ClassColor(c.class)
                local shortName = c.name:sub(-#realm) == realm and c.name:sub(1, -#realm - 1) or c.name
                tt:AddDoubleLine(shortName, ns.FormatMoney(c.money), r, g, b, 1, 1, 1)
            end
            tt:AddDoubleLine(L.TT_TOTAL, ns.FormatMoney(total), 1, 0.82, 0, 1, 1, 1)
        end
    end,
    secureMacro = "/run ToggleAllBags()",
    clickHint = L.HINT_BAGS,
})

---------------------------------------------------------------------------
-- Bags
---------------------------------------------------------------------------
-- Index of the last equipped bag (0 = backpack); the global's name differs between clients
local function LastBag()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

ns:RegisterModule("bags", {
    label = "BAGS",
    icon = "Interface\\Icons\\INV_Misc_Bag_08",
    events = { "BAG_UPDATE_DELAYED" },
    update = function(cfg)
        local free, total = 0, 0
        for bag = 0, LastBag() do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            if slots > 0 then
                total = total + slots
                free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
            end
        end
        local level = Threshold(cfg, free, THRESHOLDS.bags)
        local mode = cfg and cfg.bagsFormat or "freeTotal"
        if mode == "free" then return tostring(free), level end
        if mode == "usedTotal" then return L.BAGS_FORMAT:format(total - free, total), level end
        return L.BAGS_FORMAT:format(free, total), level
    end,
    defaults = { bagsFormat = "freeTotal" },
    options = {
        { kind = "dropdown", field = "bagsFormat", tab = "text", label = "BAGS_SHOWN", tip = "TIP_BAGS_SHOWN",
          values = { { key = "freeTotal", label = "BAGS_FREE_TOTAL" }, { key = "free", label = "BAGS_FREE" },
                     { key = "usedTotal", label = "BAGS_USED_TOTAL" } } },
    },
    thresholds = THRESHOLDS.bags,
    -- progress bar: how full the bags are
    progress = function()
        local free, total = 0, 0
        for bag = 0, LastBag() do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            total = total + slots
            if slots > 0 then free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0) end
        end
        return total > 0 and (total - free) / total or 0
    end,
    tooltip = function(tt)
        local junk = 0
        for bag = 0, LastBag() do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            if slots > 0 then
                local free = C_Container.GetContainerNumFreeSlots(bag) or 0
                local name = C_Container.GetBagName and C_Container.GetBagName(bag)
                name = name or (bag == 0 and L.TT_BACKPACK or L.TT_BAG:format(bag))
                tt:AddDoubleLine(name, L.BAGS_FORMAT:format(free, slots), 1, 1, 1, 1, 1, 1)
                -- junk (grey items) sell value; the price is only known once the item is cached
                for slot = 1, slots do
                    local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
                    if info and info.quality == 0 and info.itemID then
                        local price = select(11, GetItemInfoFn(info.itemID))
                        if price then junk = junk + price * (info.stackCount or 1) end
                    end
                end
            end
        end
        if junk > 0 then
            tt:AddLine(" ")
            tt:AddDoubleLine(L.TT_JUNK, ns.FormatMoney(junk), 0.62, 0.62, 0.62, 1, 1, 1)
        end
    end,
    secureMacro = "/run ToggleAllBags()",
    clickHint = L.HINT_BAGS,
})

---------------------------------------------------------------------------
-- Durability (the lowest equipped item is shown)
---------------------------------------------------------------------------
local function DurabilityLevel(pct, cfg)
    return Threshold(cfg, pct, THRESHOLDS.durability)
end

-- Lowest durability of the equipped items, in % (nil when nothing has durability)
local function LowestDurability()
    local lowest
    for slot = 1, 19 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            local pct = Percent(cur, max)
            if not lowest or pct < lowest then lowest = pct end
        end
    end
    return lowest
end

-- Average durability of the equipped items that have one (percent), or nil
local function AverageDurability()
    local sum, count = 0, 0
    for slot = 1, 19 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            sum, count = sum + Percent(cur, max), count + 1
        end
    end
    return count > 0 and sum / count or nil
end

-- The durability the block shows: the most worn item (default) or the average
local function ShownDurability(cfg)
    if cfg and cfg.durabilityMode == "average" then return AverageDurability() end
    return LowestDurability()
end

-- Repair cost of the equipped items, in copper, or nil when this client gives no way to
-- read it. The game gives the cost with each item's tooltip: modern tooltip data first,
-- then a hidden tooltip (older API, 3rd return value of SetInventoryItem).
local repairScanner
local function RepairCost()
    local total, known = 0, false
    for slot = 1, 19 do
        local cost
        if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
            local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
            if ok and type(data) == "table" and type(data.repairCost) == "number" then cost = data.repairCost end
        end
        if cost == nil then
            if not repairScanner then
                repairScanner = CreateFrame("GameTooltip", "TesseraRepairScanner", nil, "GameTooltipTemplate")
            end
            repairScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
            local ok, hasItem, _, c = pcall(repairScanner.SetInventoryItem, repairScanner, "player", slot)
            if ok and hasItem and type(c) == "number" then cost = c end
            repairScanner:Hide()
        end
        if cost then
            known = true
            total = total + cost
        end
    end
    return known and total or nil
end

ns:RegisterModule("durability", {
    label = "DURABILITY",
    icon = "Interface\\Icons\\Trade_BlackSmithing",
    events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" },
    update = function(cfg)
        local pct = ShownDurability(cfg)
        if not pct then return nil end
        return ("%d%%"):format(math.floor(pct + 0.5)), DurabilityLevel(pct, cfg)
    end,
    defaults = { durabilityMode = "lowest" },
    options = {
        { kind = "dropdown", field = "durabilityMode", tab = "text", label = "DURABILITY_SHOWN", tip = "TIP_DURABILITY_SHOWN",
          values = { { key = "lowest", label = "DURABILITY_LOWEST" }, { key = "average", label = "DURABILITY_AVERAGE" } } },
    },
    thresholds = THRESHOLDS.durability,
    progress = function(cfg)
        local lowest = ShownDurability(cfg)
        return lowest and lowest / 100 or nil
    end,
    tooltip = function(tt, cfg)
        for slot = 1, 19 do
            local cur, max = GetInventoryItemDurability(slot)
            if cur and max and max > 0 then
                local pct = Percent(cur, max)
                local ok, link = pcall(GetInventoryItemLink, "player", slot)
                link = ok and link or "?"
                tt:AddDoubleLine(link, LevelColor(DurabilityLevel(pct, cfg)) .. ("%d%%"):format(math.floor(pct + 0.5)) .. "|r")
            end
        end
        local cost = RepairCost()
        if cost and cost > 0 then
            tt:AddLine(" ")
            tt:AddDoubleLine(L.TT_REPAIR_COST, ns.FormatMoney(cost), 1, 1, 1, 1, 1, 1)
        end
    end,
    secureMacro = "/click CharacterMicroButton",
    clickHint = L.HINT_CHARACTER,
})

---------------------------------------------------------------------------
-- FPS and latency
---------------------------------------------------------------------------
ns:RegisterModule("fps", {
    label = "FPS",
    icon = "Interface\\Icons\\Ability_Rogue_Sprint",
    interval = 1,
    update = function(cfg)
        local fps = GetFramerate() or 0
        local text = (cfg and cfg.showUnit == false) and ("%.0f"):format(fps) or L.FPS_FORMAT:format(fps)
        return text, Threshold(cfg, fps, THRESHOLDS.fps)
    end,
    defaults = { showUnit = true },
    options = { { kind = "check", field = "showUnit", tab = "text", label = "SHOW_UNIT", tip = "TIP_SHOW_UNIT" } },
    thresholds = THRESHOLDS.fps,
    tooltip = function(tt, cfg)
        local f = session.fps
        tt:AddDoubleLine(L.TT_FPS_NOW, L.FPS_FORMAT:format(GetFramerate() or 0), 1, 1, 1, 1, 1, 1)
        if f.count > 0 then
            tt:AddDoubleLine(L.TT_FPS_AVG, L.FPS_FORMAT:format(f.sum / f.count), 1, 1, 1, 1, 1, 1)
            tt:AddDoubleLine(L.TT_FPS_MIN, L.FPS_FORMAT:format(f.min), 1, 1, 1, 1, 0.3, 0.3)
            tt:AddDoubleLine(L.TT_FPS_MAX, L.FPS_FORMAT:format(f.max), 1, 1, 1, 0.3, 1, 0.3)
        end
        tt:AddLine(" ")
        tt:AddDoubleLine(L.TT_FPS_CAP, FPSCap("useMaxFPS", "maxFPS"), 1, 1, 1, 1, 1, 1)
        tt:AddDoubleLine(L.TT_FPS_CAP_BG, FPSCap("useMaxFPSBk", "maxFPSBk"), 1, 1, 1, 1, 1, 1)
        if GetPhysicalScreenSize then
            local w, h = GetPhysicalScreenSize()
            if w and h then tt:AddDoubleLine(L.TT_RESOLUTION, ("%d x %d"):format(w, h), 1, 1, 1, 1, 1, 1) end
        end
        AddGraph(tt, L.TT_GRAPH_FPS, history.fps, function(v) return Threshold(cfg, v, THRESHOLDS.fps) end)
    end,
})

-- GOOD under 100 ms, WARN under 250 ms, BAD above
local function LatencyLevel(ms, cfg)
    return Threshold(cfg, ms, THRESHOLDS.latency)
end

ns:RegisterModule("latency", {
    label = "LATENCY",
    icon = "Interface\\Icons\\Spell_Nature_Lightning",
    interval = 5,
    update = function(cfg)
        local _, _, home, world = GetNetStats()
        home, world = home or 0, world or 0
        local function Ms(v)
            if cfg and cfg.showUnit == false then return tostring(v) end
            return L.LATENCY_FORMAT:format(v)
        end
        local source = cfg and cfg.latencySource or "world"
        if source == "home" then return Ms(home), LatencyLevel(home, cfg) end
        if source == "both" then
            return Ms(home) .. " / " .. Ms(world), LatencyLevel(math.max(home, world), cfg)
        end
        return Ms(world), LatencyLevel(world, cfg)
    end,
    defaults = { showUnit = true, latencySource = "world" },
    options = {
        { kind = "dropdown", field = "latencySource", tab = "text", label = "LATENCY_SHOWN", tip = "TIP_LATENCY_SHOWN",
          values = { { key = "world", label = "TT_WORLD" }, { key = "home", label = "TT_HOME" },
                     { key = "both", label = "LATENCY_BOTH" } } },
        { kind = "check", field = "showUnit", tab = "text", label = "SHOW_UNIT", tip = "TIP_SHOW_UNIT" },
    },
    thresholds = THRESHOLDS.latency,
    tooltip = function(tt, cfg)
        local bwIn, bwOut, home, world = GetNetStats()
        tt:AddDoubleLine(L.TT_HOME, LevelColor(LatencyLevel(home or 0, cfg)) .. L.LATENCY_FORMAT:format(home or 0) .. "|r",
            1, 1, 1)
        tt:AddDoubleLine(L.TT_WORLD, LevelColor(LatencyLevel(world or 0, cfg)) .. L.LATENCY_FORMAT:format(world or 0)
            .. "|r", 1, 1, 1)
        tt:AddDoubleLine(L.TT_BANDWIDTH_IN, L.BANDWIDTH_FORMAT:format(bwIn or 0), 1, 1, 1, 1, 1, 1)
        tt:AddDoubleLine(L.TT_BANDWIDTH_OUT, L.BANDWIDTH_FORMAT:format(bwOut or 0), 1, 1, 1, 1, 1, 1)
        AddGraph(tt, L.TT_GRAPH_LATENCY, history.latency, function(v) return LatencyLevel(v, cfg) end)
    end,
})

---------------------------------------------------------------------------
-- Local time and server time
---------------------------------------------------------------------------
-- "HH:MM" (24 h) or "H:MM AM/PM" (12 h), per the block's "24-hour clock" option,
-- with ":SS" when the block shows the seconds
local function FormatClock(h, m, cfg, sec)
    h, m = h or 0, m or 0
    local seconds = (cfg and cfg.showSeconds and sec) and (":%02d"):format(sec) or ""
    if cfg and cfg.clock24 == false then
        local suffix = h >= 12 and "PM" or "AM"
        h = h % 12
        if h == 0 then h = 12 end
        return ("%d:%02d%s %s"):format(h, m, seconds, suffix)
    end
    return ("%02d:%02d%s"):format(h, m, seconds)
end

-- Local time of the computer
local function LocalTime(cfg)
    local t = date("*t")
    return FormatClock(t.hour, t.min, cfg, t.sec)
end

-- Server (realm) time; the game gives hours and minutes only: the seconds come from
-- the server's clock (time zones are whole minutes, so its seconds are the realm's)
local function ServerTime(cfg)
    local h, m = GetGameTime()
    local now = GetServerTime and GetServerTime() or time()
    return FormatClock(h, m, cfg, now % 60)
end

local CLOCK_OPTION = { kind = "check", field = "clock24", tab = "text", label = "CLOCK_24", tip = "TIP_CLOCK_24" }
local SECONDS_OPTION = { kind = "check", field = "showSeconds", tab = "text", label = "SHOW_SECONDS", tip = "TIP_SHOW_SECONDS" }

-- Tooltip shared by both time blocks
local function TimeTooltip(tt, cfg)
    tt:AddDoubleLine(L.TT_LOCAL_TIME, LocalTime(cfg), 1, 1, 1, 1, 1, 1)
    tt:AddDoubleLine(L.TT_SERVER_TIME, ServerTime(cfg), 1, 1, 1, 1, 1, 1)
    tt:AddDoubleLine(L.TT_SESSION_TIME, FormatDuration(GetTime() - session.start), 1, 1, 1, 1, 1, 1)
    tt:AddLine(date("%d/%m/%Y"), 0.8, 0.8, 0.8)
end

-- Does WoW's own clock show local time? (otherwise it shows server time)
-- Modern C_CVar API first, classic GetCVar global as fallback
local function WowClockIsLocal()
    local v = (C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("timeMgrUseLocalTime"))
        or (GetCVar and GetCVar("timeMgrUseLocalTime"))
    return v == "1"
end

-- Which time the "time" block shows: "server", "local", or "auto" = the one
-- WoW's clock does not already show
local function ShowsServerTime(cfg)
    local source = cfg and cfg.timeSource or "auto"
    if source == "server" then return true end
    if source == "local" then return false end
    return WowClockIsLocal()
end
ns.ShowsServerTime = ShowsServerTime

ns:RegisterModule("time", {
    label = "TIME",
    icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    interval = 1,
    update = function(cfg)
        if ShowsServerTime(cfg) then return ServerTime(cfg) end
        return LocalTime(cfg)
    end,
    options = {
        { kind = "dropdown", field = "timeSource", tab = "text", label = "TIME_SOURCE", tip = "TIP_TIME_SOURCE",
          values = { { key = "auto", label = "TIME_AUTO" }, { key = "local", label = "TT_LOCAL_TIME" },
                     { key = "server", label = "TT_SERVER_TIME" } } },
        CLOCK_OPTION,
        SECONDS_OPTION,
    },
    defaults = { showSeconds = false },
    tooltip = TimeTooltip,
    secureMacro = "/run if ToggleCalendar then ToggleCalendar() end",
    clickHint = L.HINT_CALENDAR,
})

ns:RegisterModule("serverTime", {
    label = "SERVER_TIME",
    icon = "Interface\\Icons\\INV_Misc_PocketWatch_02",
    interval = 1,
    defaultEnabled = false,
    update = ServerTime,
    options = { CLOCK_OPTION, SECONDS_OPTION },
    defaults = { showSeconds = false },
    tooltip = TimeTooltip,
    secureMacro = "/run if ToggleCalendar then ToggleCalendar() end",
    clickHint = L.HINT_CALENDAR,
})

---------------------------------------------------------------------------
-- Experience
---------------------------------------------------------------------------
-- True at max level. Uses the modern API if present, else "no XP bar" means max level
local function AtMaxLevel()
    local level = UnitLevel("player")
    if IsLevelAtEffectiveMaxLevel then return IsLevelAtEffectiveMaxLevel(level) end
    local max = UnitXPMax("player")
    return not max or max == 0
end

ns:RegisterModule("xp", {
    label = "XP",
    icon = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
    events = { "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP" },
    defaultEnabled = false,
    defaults = { progressBar = true, xpFormat = "percent", xpRested = true },
    progress = function()
        if AtMaxLevel() then return nil end
        local max = UnitXPMax("player")
        return max and max > 0 and UnitXP("player") / max or nil
    end,
    update = function(cfg)
        if AtMaxLevel() then return L.MAX_LEVEL end
        local cur, max = UnitXP("player"), UnitXPMax("player")
        local fmt = BreakUpLargeNumbers or tostring
        local mode = cfg and cfg.xpFormat or "percent"
        local text
        if mode == "values" then
            text = ("%s / %s"):format(fmt(cur), fmt(max))
        elseif mode == "remaining" then
            text = L.XP_TO_GO:format(fmt(max - cur))
        else
            text = ("%.1f%%"):format(Percent(cur, max))
        end
        local rested = GetXPExhaustion()
        if rested and rested > 0 and not (cfg and cfg.xpRested == false) then
            text = text .. (" |cff4da6ff+%.0f%%|r"):format(Percent(rested, max))
        end
        return text
    end,
    options = {
        { kind = "dropdown", field = "xpFormat", tab = "text", label = "XP_SHOWN", tip = "TIP_XP_SHOWN",
          values = { { key = "percent", label = "XP_PERCENT" }, { key = "values", label = "XP_VALUES" },
                     { key = "remaining", label = "XP_REMAINING" } } },
        { kind = "check", field = "xpRested", tab = "text", label = "XP_RESTED", tip = "TIP_XP_RESTED" },
    },
    tooltip = function(tt)
        tt:AddLine(L.TT_LEVEL:format(UnitLevel("player")), 1, 1, 1)
        if AtMaxLevel() then return end
        local cur, max = UnitXP("player"), UnitXPMax("player")
        local fmt = BreakUpLargeNumbers or tostring
        tt:AddDoubleLine(L.TT_XP_CURRENT, ("%s / %s"):format(fmt(cur), fmt(max)), 1, 1, 1, 1, 1, 1)
        tt:AddDoubleLine(L.TT_XP_REMAINING, fmt(max - cur), 1, 1, 1, 1, 1, 1)
        local rested = GetXPExhaustion()
        if rested and rested > 0 then
            tt:AddDoubleLine(L.TT_XP_RESTED, fmt(rested), 1, 1, 1, 0.3, 0.65, 1)
        end

        local elapsed = GetTime() - session.start
        if session.xpGained > 0 then
            tt:AddLine(" ")
            tt:AddDoubleLine(L.TT_XP_SESSION, fmt(session.xpGained), 1, 1, 1, 1, 1, 1)
            if elapsed >= 60 then
                local perSecond = session.xpGained / elapsed
                tt:AddDoubleLine(L.TT_XP_HOUR, fmt(math.floor(perSecond * 3600)), 1, 1, 1, 1, 1, 1)
                tt:AddDoubleLine(L.TT_XP_TO_LEVEL, FormatDuration((max - cur) / perSecond), 1, 1, 1, 1, 0.82, 0)
            end
        end
    end,
})

---------------------------------------------------------------------------
-- Coordinates and zone
---------------------------------------------------------------------------
ns:RegisterModule("coords", {
    label = "COORDS",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
    interval = 0.25,
    defaultEnabled = false,
    update = function(cfg)
        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return nil end
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if not pos then return nil end
        local x, y = pos:GetXY()
        if not x or (x == 0 and y == 0) then return nil end
        local d = math.max(0, math.min(2, math.floor(tonumber(cfg and cfg.coordDecimals) or 1)))
        local f = "%." .. d .. "f"
        return (f .. ", " .. f):format(x * 100, y * 100)
    end,
    options = {
        { kind = "slider", field = "coordDecimals", tab = "text", label = "COORD_DECIMALS", tip = "TIP_COORD_DECIMALS",
          min = 0, max = 2, step = 1, default = 1 },
    },
    tooltip = function(tt)
        local mapID = C_Map.GetBestMapForUnit("player")
        local info = mapID and C_Map.GetMapInfo(mapID)
        if info then tt:AddLine(info.name, 1, 1, 1) end
        local sub = GetSubZoneText()
        if sub and sub ~= "" then tt:AddDoubleLine(L.TT_SUBZONE, sub, 0.8, 0.8, 0.8, 1, 1, 1) end
    end,
    secureMacro = "/run ToggleWorldMap()",
    clickHint = L.HINT_MAP,
    -- "Zone (x, y)" for Shift + click "copy to chat"
    chatText = function()
        local mapID = C_Map.GetBestMapForUnit("player")
        local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        if not pos then return nil end
        local x, y = pos:GetXY()
        local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
        return ("%s (%.1f, %.1f)"):format(zone or "", x * 100, y * 100)
    end,
    -- extra click action: place a map pin on the player's position (middle click by default)
    extraAction = {
        key = "waypoint", label = "ACTION_WAYPOINT",
        run = function()
            local mapID = C_Map.GetBestMapForUnit("player")
            local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
            if not (pos and C_Map.SetUserWaypoint and UiMapPoint) then return end
            local x, y = pos:GetXY()
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
        end,
    },
    defaults = { middleClick = "waypoint", coordDecimals = 1 },
})

-- Tooltip shared by the zone and subzone blocks
local function ZoneTooltip(tt)
    tt:AddDoubleLine(L.ZONE, GetRealZoneText() or "", 0.8, 0.8, 0.8, 1, 1, 1)
    local sub = GetSubZoneText()
    if sub and sub ~= "" then tt:AddDoubleLine(L.TT_SUBZONE, sub, 0.8, 0.8, 0.8, 1, 1, 1) end
end

ns:RegisterModule("zone", {
    label = "ZONE",
    icon = "Interface\\Icons\\Ability_Hunter_Pathfinding",
    events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" },
    defaultEnabled = false,
    -- main zone (e.g. Stormwind), without the subzone
    update = function()
        local text = GetRealZoneText and GetRealZoneText() or GetZoneText()
        return text ~= "" and text or nil
    end,
    tooltip = ZoneTooltip,
    secureMacro = "/run ToggleWorldMap()",
    clickHint = L.HINT_MAP,
})

ns:RegisterModule("subzone", {
    label = "SUBZONE",
    icon = "Interface\\Icons\\INV_Misc_Map02",
    events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" },
    defaultEnabled = false,
    -- subzone (e.g. Trade District); the zone when there is no subzone
    update = function()
        local sub = GetSubZoneText()
        if sub and sub ~= "" then return sub end
        local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
        return zone ~= "" and zone or nil
    end,
    tooltip = ZoneTooltip,
    secureMacro = "/run ToggleWorldMap()",
    clickHint = L.HINT_MAP,
})

---------------------------------------------------------------------------
-- Friends and guild
---------------------------------------------------------------------------
-- Maximum names listed in a tooltip (the rest is shown as "and N more")
local MAX_LINES = 20

-- Friends and guild: members online only, or online / total
local COUNT_OPTION = { kind = "dropdown", field = "countFormat", tab = "text", label = "COUNT_SHOWN", tip = "TIP_COUNT_SHOWN",
    values = { { key = "online", label = "COUNT_ONLINE" }, { key = "onlineTotal", label = "COUNT_ONLINE_TOTAL" } } }

ns:RegisterModule("friends", {
    label = "FRIENDS",
    icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
    events = { "FRIENDLIST_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "BN_CONNECTED" },
    defaultEnabled = false,
    -- nobody online: block hidden ("Hide when empty" option)
    isEmpty = function()
        local online = C_FriendList.GetNumOnlineFriends() or 0
        if BNGetNumFriends then
            local _, bnOnline = BNGetNumFriends()
            online = online + (bnOnline or 0)
        end
        return online == 0
    end,
    update = function(cfg)
        local online = C_FriendList.GetNumOnlineFriends() or 0
        local total = C_FriendList.GetNumFriends() or 0
        if BNGetNumFriends then
            local bnTotal, bnOnline = BNGetNumFriends()
            online = online + (bnOnline or 0)
            total = total + (bnTotal or 0)
        end
        if cfg and cfg.countFormat == "onlineTotal" then return ("%d / %d"):format(online, total) end
        return tostring(online)
    end,
    defaults = { countFormat = "online" },
    options = { COUNT_OPTION },
    tooltip = function(tt)
        local shown = 0
        local count = C_FriendList.GetNumFriends() or 0
        for i = 1, count do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected then
                shown = shown + 1
                if shown <= MAX_LINES then
                    local r, g, b = ClassColor(info.className and info.className:upper())
                    tt:AddDoubleLine(("%s (%d)"):format(info.name or "?", info.level or 0), info.area or "", r, g, b, 0.8, 0.8, 0.8)
                end
            end
        end
        if shown > MAX_LINES then tt:AddLine(L.TT_MORE:format(shown - MAX_LINES), 0.8, 0.8, 0.8) end
        if BNGetNumFriends then
            local _, bnOnline = BNGetNumFriends()
            tt:AddDoubleLine(L.TT_BNET_ONLINE, tostring(bnOnline or 0), 0.3, 0.75, 1, 1, 1, 1)
        elseif shown == 0 then
            tt:AddLine(L.TT_NO_FRIEND, 0.8, 0.8, 0.8)
        end
    end,
    secureMacro = "/run ToggleFriendsFrame(1)",
    clickHint = L.HINT_FRIENDS,
})

ns:RegisterModule("guild", {
    label = "GUILD",
    icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
    events = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" },
    defaultEnabled = false,
    -- ask the server for the guild roster every minute (answer: GUILD_ROSTER_UPDATE)
    request = function()
        if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
    end,
    requestInterval = 60,
    -- no guild: block hidden ("Hide when empty" option)
    isEmpty = function() return not IsInGuild() end,
    update = function(cfg)
        if not IsInGuild() then return L.NO_GUILD end
        local total, online = GetNumGuildMembers()
        if cfg and cfg.countFormat == "online" then return tostring(online or 0) end
        return ("%d / %d"):format(online or 0, total or 0)
    end,
    defaults = { countFormat = "onlineTotal" },
    options = { COUNT_OPTION },
    tooltip = function(tt)
        if not IsInGuild() then return end
        local guildName = GetGuildInfo("player")
        if guildName then tt:AddLine(guildName, 0.3, 1, 0.3) end
        local total = GetNumGuildMembers() or 0
        local shown = 0
        for i = 1, total do
            local name, _, _, level, _, zone, _, _, online, _, class = GetGuildRosterInfo(i)
            if online and name then
                shown = shown + 1
                if shown <= MAX_LINES then
                    local r, g, b = ClassColor(class)
                    tt:AddDoubleLine(("%s (%d)"):format(Ambiguate and Ambiguate(name, "guild") or name, level or 0), zone or "", r, g, b, 0.8, 0.8, 0.8)
                end
            end
        end
        if shown > MAX_LINES then tt:AddLine(L.TT_MORE:format(shown - MAX_LINES), 0.8, 0.8, 0.8) end
    end,
    secureMacro = "/click GuildMicroButton",
    clickHint = L.HINT_GUILD,
})

---------------------------------------------------------------------------
-- Addon memory
---------------------------------------------------------------------------
-- Modern clients moved these functions into C_AddOns; classic clients keep the globals
local GetNumAddOnsFn = (C_AddOns and C_AddOns.GetNumAddOns) or function() return 0 end
local GetAddOnInfoFn = (C_AddOns and C_AddOns.GetAddOnInfo) or function() end
local GetMemoryFn = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage

-- Last measurement, reused by the tooltip (measuring is expensive)
local memoryCache = { total = 0, list = {} }

local function RefreshMemory()
    if InCombatLockdown() then return end -- avoid a stutter during combat
    UpdateAddOnMemoryUsage()
    local total, list = 0, {}
    for i = 1, GetNumAddOnsFn() do
        local kb = GetMemoryFn(i) or 0
        if kb > 0 then
            local name, title = GetAddOnInfoFn(i)
            total = total + kb
            table.insert(list, { name = title or name, folder = name, kb = kb })
        end
    end
    table.sort(list, function(a, b) return a.kb > b.kb end)
    memoryCache.total, memoryCache.list = total, list
end

-- "512 KB" or "1.5 MB"
local function FormatMemory(kb)
    if kb >= 1024 then return L.MEMORY_MB:format(kb / 1024) end
    return L.MEMORY_KB:format(kb)
end

ns:RegisterModule("memory", {
    label = "MEMORY",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    interval = 30,
    defaultEnabled = false,
    update = function()
        pcall(RefreshMemory) -- on failure, keep showing the last known total
        return FormatMemory(memoryCache.total)
    end,
    tooltip = function(tt)
        -- Tessera's own footprint first, then the heaviest addons
        local own = 0
        for _, e in ipairs(memoryCache.list) do
            if e.name == "Tessera" or e.folder == "Tessera" then own = e.kb end
        end
        tt:AddDoubleLine(L.TT_TESSERA_MEMORY, FormatMemory(own), 0.4, 0.75, 1, 1, 1, 1)
        tt:AddLine(" ")
        tt:AddLine(L.TT_TOP_ADDONS, 1, 0.82, 0)
        for i = 1, math.min(10, #memoryCache.list) do
            local e = memoryCache.list[i]
            tt:AddDoubleLine(e.name, FormatMemory(e.kb), 1, 1, 1, 1, 1, 1)
        end
    end,
})

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
-- Hearthstone: bound location and cooldown; click = use it
---------------------------------------------------------------------------
-- Hearthstone item id
local HEARTHSTONE = 6948

-- Seconds left on the Hearthstone cooldown (0 = ready). Modern C_Container API first,
-- classic global as fallback. The math runs in pcall because on Midnight-era clients
-- the values can be "secret" and comparing them throws an error
local function HearthCooldown()
    local start, duration
    if C_Container and C_Container.GetItemCooldown then
        start, duration = Try(C_Container.GetItemCooldown, HEARTHSTONE)
    end
    local ok, remaining = pcall(function()
        if start and duration and start > 0 and duration > 1.5 then
            return math.max(0, start + duration - GetTime())
        end
        return 0
    end)
    return ok and remaining or 0
end

ns:RegisterModule("hearthstone", {
    label = "HEARTHSTONE",
    icon = "Interface\\Icons\\INV_Misc_Rune_01",
    interval = 1,
    defaultEnabled = false,
    update = function()
        local location = Try(GetBindLocation) or "?"
        local cd = HearthCooldown()
        if cd > 0 then return ("%s · %s"):format(location, ShortTime(cd)), WARN end
        return location, GOOD
    end,
    tooltip = function(tt)
        WHITE(tt, L.TT_BIND_LOCATION, Try(GetBindLocation) or "?")
        local cd = HearthCooldown()
        if cd > 0 then
            tt:AddDoubleLine(L.TT_COOLDOWN, ShortTime(cd), 1, 1, 1, 1, 0.6, 0.2)
        else
            tt:AddDoubleLine(L.TT_COOLDOWN, L.TT_READY, 1, 1, 1, 0.3, 1, 0.3)
        end
    end,
    secureMacro = "/use item:" .. HEARTHSTONE,
    clickHint = L.HINT_HEARTH,
})

---------------------------------------------------------------------------
-- Mail: with "Hide when empty", only shown when mail is waiting
---------------------------------------------------------------------------
ns:RegisterModule("mail", {
    label = "MAIL",
    icon = "Interface\\Icons\\INV_Letter_15",
    events = { "UPDATE_PENDING_MAIL", "MAIL_INBOX_UPDATE", "MAIL_CLOSED" },
    interval = 30,
    alertOnShow = true, -- flash when new mail arrives
    isEmpty = function() return not Try(HasNewMail) end,
    update = function()
        if Try(HasNewMail) then return L.MAIL_NEW, GOOD end
        return L.NONE
    end,
    tooltip = function(tt)
        local senders = { Try(GetLatestThreeSenders) }
        if #senders == 0 then
            tt:AddLine(Try(HasNewMail) and L.MAIL_NEW or L.TT_NO_MAIL, 0.8, 0.8, 0.8)
        end
        for _, name in ipairs(senders) do tt:AddLine(name, 1, 1, 1) end
    end,
})

---------------------------------------------------------------------------
-- Quests: count in the quest log, list in the tooltip
---------------------------------------------------------------------------
-- Quests in the log (headers excluded) as { title, level, complete }.
-- (C_QuestLog API)
local function QuestList()
    local list = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local n = Try(C_QuestLog.GetNumQuestLogEntries) or 0
        for i = 1, n do
            local info = Try(C_QuestLog.GetInfo, i)
            if info and not info.isHeader and not info.isHidden and not info.isTask then
                local complete = info.questID and C_QuestLog.IsComplete and Try(C_QuestLog.IsComplete, info.questID)
                table.insert(list, { title = info.title, level = info.level, complete = complete })
            end
        end
    end
    return list
end

-- Quest log capacity (modern API, else the MAX_QUESTS global, else 25)
local function MaxQuests()
    if C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept then
        local max = Try(C_QuestLog.GetMaxNumQuestsCanAccept)
        if max and max > 0 then return max end
    end
    return MAX_QUESTS or 25
end

ns:RegisterModule("quests", {
    label = "QUESTS",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    events = { "QUEST_LOG_UPDATE" },
    defaultEnabled = false,
    update = function()
        local count, max = #QuestList(), MaxQuests()
        local level = count >= max and BAD or (count >= max - 2 and WARN or GOOD)
        return ("%d / %d"):format(count, max), level
    end,
    tooltip = function(tt)
        local list = QuestList()
        for i = 1, math.min(#list, MAX_LINES) do
            local q = list[i]
            local right = q.complete and ("|cff4dff4d" .. L.TT_COMPLETE .. "|r") or ""
            local color = q.level and GetQuestDifficultyColor and GetQuestDifficultyColor(q.level)
            local r, g, b = 1, 1, 1
            if color then r, g, b = color.r, color.g, color.b end
            tt:AddDoubleLine(("[%s] %s"):format(q.level or "?", q.title or "?"), right, r, g, b)
        end
        if #list > MAX_LINES then tt:AddLine(L.TT_MORE:format(#list - MAX_LINES), 0.8, 0.8, 0.8) end
        if #list == 0 then tt:AddLine(L.NONE, 0.8, 0.8, 0.8) end
    end,
    secureMacro = "/run if ToggleQuestLog then ToggleQuestLog() end",
    clickHint = L.HINT_QUESTS,
})

---------------------------------------------------------------------------
-- Watched reputation (the one shown on the experience bar)
---------------------------------------------------------------------------
-- name, reaction (standing id), min, max, value of the watched faction, or nil.
-- (C_Reputation API)
local function WatchedFaction()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local d = Try(C_Reputation.GetWatchedFactionData)
        if d and d.name then
            return d.name, d.reaction, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding
        end
    end
    return nil
end

-- Localized standing name ("Friendly", "Honored"...) from the game's globals
local function StandingLabel(reaction)
    return reaction and (_G["FACTION_STANDING_LABEL" .. reaction]) or "?"
end

ns:RegisterModule("reputation", {
    label = "REPUTATION",
    icon = "Interface\\Icons\\INV_BannerPVP_02",
    events = { "UPDATE_FACTION" },
    isEmpty = function() return WatchedFaction() == nil end,
    defaults = { progressBar = true, repFormat = "standingPercent" },
    progress = function()
        local name, _, min, max, value = WatchedFaction()
        if not name or not (max and min and max > min) then return nil end
        return (value - min) / (max - min)
    end,
    update = function(cfg)
        local name, reaction, min, max, value = WatchedFaction()
        if not name then return L.NONE end
        local pct = math.floor((max and min and max > min) and Percent(value - min, max - min) or 100)
        local mode = cfg and cfg.repFormat or "standingPercent"
        if mode == "namePercent" then return ("%s %d%%"):format(name, pct) end
        if mode == "percent" then return ("%d%%"):format(pct) end
        if mode == "standing" then return StandingLabel(reaction) end
        return ("%s %d%%"):format(StandingLabel(reaction), pct)
    end,
    options = {
        { kind = "dropdown", field = "repFormat", tab = "text", label = "REP_SHOWN", tip = "TIP_REP_SHOWN",
          values = { { key = "standingPercent", label = "REP_STANDING_PERCENT" },
                     { key = "namePercent", label = "REP_NAME_PERCENT" },
                     { key = "percent", label = "REP_PERCENT" }, { key = "standing", label = "REP_STANDING" } } },
    },
    tooltip = function(tt)
        local name, reaction, min, max, value = WatchedFaction()
        if not name then
            tt:AddLine(L.TT_NO_WATCHED, 0.8, 0.8, 0.8, true)
            return
        end
        tt:AddLine(name, 1, 1, 1)
        WHITE(tt, StandingLabel(reaction),
            (max and min and max > min) and ("%d / %d"):format(value - min, max - min) or "")
    end,
    secureMacro = "/run if ToggleCharacter then ToggleCharacter('ReputationFrame') end",
    clickHint = L.HINT_REPUTATION,
})

---------------------------------------------------------------------------
-- Tracked currencies (the ones shown on the backpack)
---------------------------------------------------------------------------
-- Up to 3 backpack currencies as { name, count, icon }.
-- (C_CurrencyInfo API)
local function TrackedCurrencies()
    local list = {}
    for i = 1, 3 do
        local name, count, icon
        if C_CurrencyInfo and C_CurrencyInfo.GetBackpackCurrencyInfo then
            local info = Try(C_CurrencyInfo.GetBackpackCurrencyInfo, i)
            if info then name, count, icon = info.name, info.quantity, info.iconFileID end
        end
        if name then table.insert(list, { name = name, count = count or 0, icon = icon }) end
    end
    return list
end

ns:RegisterModule("currency", {
    label = "CURRENCY",
    icon = "Interface\\Icons\\INV_Misc_Coin_01",
    events = { "CURRENCY_DISPLAY_UPDATE" },
    isEmpty = function() return #TrackedCurrencies() == 0 end,
    update = function(cfg)
        local list = TrackedCurrencies()
        if #list == 0 then return L.NONE end
        local size = cfg.fontSize or 12
        local parts = {}
        for _, c in ipairs(list) do
            local icon = c.icon and ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(c.icon, size, size) or ""
            table.insert(parts, (BreakUpLargeNumbers and BreakUpLargeNumbers(c.count) or c.count) .. icon)
        end
        return table.concat(parts, "  ")
    end,
    tooltip = function(tt)
        local list = TrackedCurrencies()
        if #list == 0 then tt:AddLine(L.TT_NO_CURRENCY, 0.8, 0.8, 0.8, true) end
        for _, c in ipairs(list) do
            WHITE(tt, c.name, BreakUpLargeNumbers and BreakUpLargeNumbers(c.count) or tostring(c.count))
        end
    end,
    secureMacro = "/run if ToggleCharacter then ToggleCharacter('TokenFrame') end",
    clickHint = L.HINT_CURRENCY,
})

---------------------------------------------------------------------------
-- Ammo (hunters' ammo slot)
---------------------------------------------------------------------------
-- Inventory slot id of the ammo slot on Classic-style clients
local AMMO_SLOT = 0

-- Ammo count, or nil when no ammo is equipped
local function AmmoCount()
    local texture = Try(GetInventoryItemTexture, "player", AMMO_SLOT)
    if not texture then return nil end
    return Try(GetInventoryItemCount, "player", AMMO_SLOT) or 0
end

ns:RegisterModule("ammo", {
    label = "AMMO",
    icon = "Interface\\Icons\\INV_Ammo_Arrow_02",
    getIcon = function() return Try(GetInventoryItemTexture, "player", AMMO_SLOT) or "Interface\\Icons\\INV_Ammo_Arrow_02" end,
    events = { "BAG_UPDATE_DELAYED", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED" },
    isEmpty = function() return AmmoCount() == nil end,
    thresholds = THRESHOLDS.ammo,
    update = function(cfg)
        local count = AmmoCount()
        if not count then return L.NONE end
        return tostring(count), Threshold(cfg, count, THRESHOLDS.ammo)
    end,
    tooltip = function(tt)
        local link = Try(GetInventoryItemLink, "player", AMMO_SLOT)
        if link then WHITE(tt, link, tostring(AmmoCount() or 0)) else tt:AddLine(L.NONE, 0.8, 0.8, 0.8) end
    end,
})

---------------------------------------------------------------------------
-- Average item level (only registered if the client has GetAverageItemLevel)
---------------------------------------------------------------------------
if GetAverageItemLevel then
    ns:RegisterModule("itemLevel", {
        label = "ITEM_LEVEL",
        icon = "Interface\\Icons\\INV_Chest_Plate06",
        events = { "PLAYER_EQUIPMENT_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE" },
        defaultEnabled = false,
        update = function()
            local _, equipped = Try(GetAverageItemLevel)
            if not equipped then return nil end
            return ("%.1f"):format(equipped)
        end,
        tooltip = function(tt)
            local overall, equipped = Try(GetAverageItemLevel)
            WHITE(tt, L.TT_EQUIPPED, ("%.1f"):format(equipped or 0))
            WHITE(tt, L.TT_OVERALL, ("%.1f"):format(overall or 0))
            tt:AddLine(" ")
            for slot = 1, 19 do
                local link = Try(GetInventoryItemLink, "player", slot)
                if link and slot ~= 4 and slot ~= 19 then
                    local getLevel = C_Item and C_Item.GetDetailedItemLevelInfo
                    local ilvl = getLevel and Try(getLevel, link)
                    tt:AddDoubleLine(link, ilvl and tostring(ilvl) or "", 1, 1, 1, 1, 1, 1)
                end
            end
        end,
        secureMacro = "/click CharacterMicroButton",
        clickHint = L.HINT_CHARACTER,
    })
end

---------------------------------------------------------------------------
-- Movement speed (100% = normal run speed)
---------------------------------------------------------------------------
-- Normal run speed in yards per second
local BASE_SPEED = BASE_MOVEMENT_SPEED or 7

-- Speed in yards/s -> percent of normal run speed
local function SpeedPercent(speed)
    return math.floor((speed or 0) / BASE_SPEED * 100 + 0.5)
end

ns:RegisterModule("speed", {
    label = "SPEED",
    icon = "Interface\\Icons\\Spell_Nature_Swiftness",
    interval = 0.5,
    defaultEnabled = false,
    update = function()
        local current, run = Try(GetUnitSpeed, "player")
        if not current then return nil end
        -- pcall: the speed can be a "secret" value on Midnight-era clients; comparing it errors
        local ok, speed = pcall(function() return current > 0 and current or run end)
        return ("%d%%"):format(SpeedPercent(ok and speed or run))
    end,
    tooltip = function(tt)
        local current, run, flight, swim = Try(GetUnitSpeed, "player")
        -- each line on its own pcall: any of these values may be "secret"
        local function Line(label, speed)
            local ok, text = pcall(function() return ("%d%%"):format(SpeedPercent(speed)) end)
            if speed and ok then WHITE(tt, label, text) end
        end
        Line(L.TT_CURRENT, current)
        Line(L.TT_RUN, run)
        Line(L.TT_SWIM, swim)
        Line(L.TT_FLIGHT, flight)
    end,
})

---------------------------------------------------------------------------
-- Volume: wheel = master volume, click = mute / unmute
---------------------------------------------------------------------------
-- A CVar read as a number (0 if missing)
local function CVarNumber(name)
    return tonumber(Try(GetCVar, name)) or 0
end

-- Volume CVars listed in the tooltip, with their Locale key
local VOLUMES = {
    { "Sound_MasterVolume", "TT_MASTER" },
    { "Sound_MusicVolume", "TT_MUSIC" },
    { "Sound_SFXVolume", "TT_EFFECTS" },
    { "Sound_AmbienceVolume", "TT_AMBIENCE" },
    { "Sound_DialogVolume", "TT_DIALOG" },
}

ns:RegisterModule("volume", {
    label = "VOLUME",
    icon = "Interface\\Icons\\INV_Misc_Drum_01",
    events = { "CVAR_UPDATE" },
    interval = 5,
    defaultEnabled = false,
    update = function()
        if Try(GetCVar, "Sound_EnableAllSound") == "0" then return L.MUTED, BAD end
        return ("%d%%"):format(math.floor(CVarNumber("Sound_MasterVolume") * 100 + 0.5))
    end,
    tooltip = function(tt)
        for _, v in ipairs(VOLUMES) do
            WHITE(tt, L[v[2]], ("%d%%"):format(math.floor(CVarNumber(v[1]) * 100 + 0.5)))
        end
    end,
    clickHint = L.HINT_VOLUME,
    onClick = function(_, button)
        if button ~= "LeftButton" then return end
        local enabled = Try(GetCVar, "Sound_EnableAllSound") ~= "0"
        SetCVar("Sound_EnableAllSound", enabled and "0" or "1")
    end,
    onWheel = function(delta)
        local v = CVarNumber("Sound_MasterVolume") + (delta > 0 and 0.05 or -0.05)
        v = math.max(0, math.min(1, math.floor(v * 20 + 0.5) / 20))
        SetCVar("Sound_MasterVolume", tostring(v))
    end,
})

---------------------------------------------------------------------------
-- Mana regeneration, per 5 seconds (as classic players count it)
---------------------------------------------------------------------------
-- Mana regained per second out of combat and while casting, or nil for a character
-- without mana (warrior, rogue...). GetManaRegen first; GetPowerRegen as fallback only
-- when the current power is mana (it reads the current power type).
local function ManaRegen()
    local maxMana = Try(UnitPowerMax, "player", 0) or 0
    if maxMana <= 0 then return nil end
    local base, casting = Try(GetManaRegen)
    if not base and Try(UnitPowerType, "player") == 0 then base, casting = Try(GetPowerRegen) end
    if not base then return nil end
    return base, casting or base
end

ns:RegisterModule("regen", {
    label = "REGEN",
    icon = "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
    interval = 2,
    defaultEnabled = false,
    isEmpty = function() return ManaRegen() == nil end,
    update = function()
        local base, casting = ManaRegen()
        if not base then return nil end
        -- in combat, the regeneration that applies while casting
        local value = (ns.state.inCombat and casting or base) * 5
        return L.REGEN_FORMAT:format(math.floor(value + 0.5))
    end,
    tooltip = function(tt)
        local base, casting = ManaRegen()
        if not base then
            tt:AddLine(L.TT_REGEN_NO_MANA, 1, 1, 1, true)
            return
        end
        WHITE(tt, L.TT_REGEN_OUT, L.REGEN_FORMAT:format(math.floor(base * 5 + 0.5)))
        WHITE(tt, L.TT_REGEN_CASTING, L.REGEN_FORMAT:format(math.floor(casting * 5 + 0.5)))
        local mana, maxMana = Try(UnitPower, "player", 0), Try(UnitPowerMax, "player", 0)
        if mana and maxMana then WHITE(tt, L.TT_MANA, ("%d / %d"):format(mana, maxMana)) end
        tt:AddLine(" ")
        tt:AddLine(L.TT_REGEN_NOTE, 0.8, 0.8, 0.8, true)
    end,
    secureMacro = "/click CharacterMicroButton",
    clickHint = L.HINT_CHARACTER,
})

---------------------------------------------------------------------------
-- Character stats: one stat on the block, all of them in the tooltip
---------------------------------------------------------------------------
-- Total attack power (melee or ranged), or nil
local function AttackPower(ranged)
    local base, pos, neg = Try(ranged and UnitRangedAttackPower or UnitAttackPower, "player")
    if not base then return nil end
    return base + (pos or 0) + (neg or 0)
end

-- Best value over the magic schools (2 holy ... 7 arcane), or nil
local function BestSchool(fn)
    local best
    for school = 2, 7 do
        local v = Try(fn, school)
        if type(v) == "number" and (not best or v > best) then best = v end
    end
    return best
end

-- Hit chance bonus: classic API first, then the combat rating API
local function HitBonus()
    local v = Try(GetHitModifier)
    if type(v) == "number" then return v end
    if CR_HIT_MELEE then return Try(GetCombatRatingBonus, CR_HIT_MELEE) end
end

-- Every stat: locale keys of its full and short names, how to read it, how to show it.
-- A stat this client cannot read (nil) is simply left out.
local STATS = {
    { key = "ap",        name = "STAT_AP",         short = "STAT_SHORT_AP",         fmt = "%d",
      get = function() return AttackPower(false) end },
    { key = "rap",       name = "STAT_RAP",        short = "STAT_SHORT_RAP",        fmt = "%d",
      get = function() return AttackPower(true) end },
    { key = "sp",        name = "STAT_SP",         short = "STAT_SHORT_SP",         fmt = "%d",
      get = function() return BestSchool(GetSpellBonusDamage) end },
    { key = "crit",      name = "STAT_CRIT",       short = "STAT_SHORT_CRIT",       fmt = "%.2f%%",
      get = function() return Try(GetCritChance) end },
    { key = "spellCrit", name = "STAT_SPELL_CRIT", short = "STAT_SHORT_SPELL_CRIT", fmt = "%.2f%%",
      get = function() return BestSchool(GetSpellCritChance) end },
    { key = "haste",     name = "STAT_HASTE",      short = "STAT_SHORT_HASTE",      fmt = "%.2f%%",
      get = function() return Try(GetHaste) end },
    { key = "hit",       name = "STAT_HIT",        short = "STAT_SHORT_HIT",        fmt = "%.2f%%",
      get = HitBonus },
    { key = "armor",     name = "STAT_ARMOR",      short = "STAT_SHORT_ARMOR",      fmt = "%d",
      get = function() local _, effective = Try(UnitArmor, "player") return effective end },
    { key = "dodge",     name = "STAT_DODGE",      short = "STAT_SHORT_DODGE",      fmt = "%.2f%%",
      get = function() return Try(GetDodgeChance) end },
    { key = "parry",     name = "STAT_PARRY",      short = "STAT_SHORT_PARRY",      fmt = "%.2f%%",
      get = function() return Try(GetParryChance) end },
    { key = "block",     name = "STAT_BLOCK",      short = "STAT_SHORT_BLOCK",      fmt = "%.2f%%",
      get = function() return Try(GetBlockChance) end },
}
local STAT_BY_KEY = {}
for _, stat in ipairs(STATS) do STAT_BY_KEY[stat.key] = stat end

-- "Automatic": spell power for casters, ranged attack power for hunters, attack power otherwise
local AUTO_STAT = { MAGE = "sp", PRIEST = "sp", WARLOCK = "sp", HUNTER = "rap" }
local function ChosenStat(cfg)
    local key = cfg and cfg.stat or "auto"
    if key == "auto" then
        local _, class = Try(UnitClass, "player")
        key = AUTO_STAT[class or ""] or "ap"
    end
    return STAT_BY_KEY[key] or STAT_BY_KEY.ap
end

local function FormatStat(stat, value)
    if stat.fmt == "%d" then return BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(value + 0.5)) or ("%d"):format(value) end
    return stat.fmt:format(value)
end

local STAT_VALUES = { { key = "auto", label = "STAT_AUTO" } }
for _, stat in ipairs(STATS) do table.insert(STAT_VALUES, { key = stat.key, label = stat.name }) end

ns:RegisterModule("stats", {
    label = "STATS",
    icon = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
    interval = 2,
    defaultEnabled = false,
    options = {
        { kind = "dropdown", field = "stat", tab = "text", label = "STAT_SHOWN", tip = "TIP_STAT_SHOWN", values = STAT_VALUES },
    },
    update = function(cfg)
        local stat = ChosenStat(cfg)
        local value = stat.get()
        if type(value) ~= "number" then return nil end
        return ("%s %s"):format(L[stat.short], FormatStat(stat, value))
    end,
    tooltip = function(tt)
        for _, stat in ipairs(STATS) do
            local value = stat.get()
            -- ranged attack power only matters when there is some
            if type(value) == "number" and not (stat.key == "rap" and value <= 0) then
                WHITE(tt, L[stat.name], FormatStat(stat, value))
            end
        end
    end,
    secureMacro = "/click CharacterMicroButton",
    clickHint = L.HINT_CHARACTER,
})

---------------------------------------------------------------------------
-- Group loot: loot method and quality threshold; click = /roll
---------------------------------------------------------------------------
-- Modern clients give a number (Enum.LootMethod), older ones a string
local LOOT_METHODS = {
    [0] = "LOOT_FFA", [1] = "LOOT_RR", [2] = "LOOT_MASTER", [3] = "LOOT_GROUP",
    [4] = "LOOT_NBG", [5] = "LOOT_PERSONAL",
    freeforall = "LOOT_FFA", roundrobin = "LOOT_RR", master = "LOOT_MASTER",
    group = "LOOT_GROUP", needbeforegreed = "LOOT_NBG", personal = "LOOT_PERSONAL",
}

-- method, threshold (item quality), master looter's name; nil when not in a group
local function LootInfo()
    if not Try(IsInGroup) then return nil end
    local method, partyID, raidID
    if C_PartyInfo and C_PartyInfo.GetLootMethod then method, partyID, raidID = Try(C_PartyInfo.GetLootMethod) end
    local master
    if raidID then
        master = Try(GetRaidRosterInfo, raidID)
    elseif partyID == 0 then
        master = UnitName("player")
    elseif partyID then
        master = UnitName("party" .. partyID)
    end
    return method, Try(GetLootThreshold), master
end

-- The game's own names first (official in every language), Tessera's as a fallback.
-- The game writes them for the chat ("Loot: Group Loot", "Butin : Butin de groupe"):
-- only the part after the colon is kept, with a capital letter.
local GAME_LOOT_NAMES = {
    LOOT_FFA = "LOOT_FREE_FOR_ALL", LOOT_RR = "LOOT_ROUND_ROBIN", LOOT_MASTER = "LOOT_MASTER_LOOTER",
    LOOT_GROUP = "LOOT_GROUP_LOOT", LOOT_NBG = "LOOT_NEED_BEFORE_GREED", LOOT_PERSONAL = "LOOT_PERSONAL_LOOT",
}
local function GameText(name, fallback)
    local text = _G[name]
    if type(text) ~= "string" or text == "" then return fallback end
    text = text:match("^[^:]+:%s*(.+)$") or text
    return (text:gsub("^%l", string.upper))
end
local function LootMethodName(method)
    local key = method ~= nil and LOOT_METHODS[method]
    return key and GameText(GAME_LOOT_NAMES[key], L[key]) or L.NA
end

-- Name of an item quality in its own color ("Uncommon" in green)
local function QualityText(quality)
    local name = quality and _G["ITEM_QUALITY" .. quality .. "_DESC"]
    if not name then return nil end
    local r, g, b = Try(C_Item and C_Item.GetItemQualityColor, quality)
    if type(r) == "number" then
        return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, name)
    end
    return name
end

ns:RegisterModule("loot", {
    label = "LOOT",
    icon = "Interface\\Icons\\INV_Misc_Bag_10",
    events = { "PARTY_LOOT_METHOD_CHANGED", "GROUP_ROSTER_UPDATE" },
    defaultEnabled = false,
    isEmpty = function() return not Try(IsInGroup) end,
    update = function()
        if not Try(IsInGroup) then return L.LOOT_SOLO end
        return LootMethodName((LootInfo()))
    end,
    tooltip = function(tt)
        if not Try(IsInGroup) then
            tt:AddLine(L.TT_LOOT_SOLO, 1, 1, 1, true)
            return
        end
        local method, threshold, master = LootInfo()
        WHITE(tt, L.TT_LOOT_METHOD, LootMethodName(method))
        local quality = QualityText(threshold)
        if quality then WHITE(tt, L.TT_LOOT_THRESHOLD, quality) end
        if master then WHITE(tt, L.TT_LOOT_MASTER, master) end
    end,
    clickHint = L.HINT_ROLL,
    onClick = function(_, button)
        if button ~= "LeftButton" then return end
        if RandomRoll then RandomRoll(1, 100) end
    end,
})

---------------------------------------------------------------------------
-- Instances: the current one, and the instances you are saved to
---------------------------------------------------------------------------
-- Instance lockouts as { name, reset (seconds), difficulty, total, done }
local function SavedInstances()
    local list = {}
    local n = Try(GetNumSavedInstances) or 0
    for i = 1, n do
        local name, _, reset, _, locked, extended, _, _, _, difficultyName, numEncounters, progress = Try(GetSavedInstanceInfo, i)
        if name and (locked or extended) then
            table.insert(list, { name = name, reset = reset, difficulty = difficultyName,
                total = numEncounters, done = progress })
        end
    end
    return list
end

-- name, difficulty of the instance you are in, or nil outside instances
local function CurrentInstance()
    if not IsInInstance() then return nil end
    local name, _, _, difficultyName = Try(GetInstanceInfo)
    return name, difficultyName
end

ns:RegisterModule("instances", {
    label = "INSTANCES",
    icon = "Interface\\Icons\\INV_Misc_Key_03",
    events = { "UPDATE_INSTANCE_INFO", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" },
    request = function() if RequestRaidInfo then RequestRaidInfo() end end,
    requestInterval = 60,
    isEmpty = function() return CurrentInstance() == nil and #SavedInstances() == 0 end,
    update = function()
        local name, difficulty = CurrentInstance()
        if name then
            return (difficulty and difficulty ~= "") and ("%s (%s)"):format(name, difficulty) or name
        end
        local count = #SavedInstances()
        if count == 0 then return L.NONE end
        return L.INSTANCES_SAVED:format(count)
    end,
    tooltip = function(tt)
        local name, difficulty = CurrentInstance()
        if name then
            tt:AddLine(name, 1, 1, 1)
            if difficulty and difficulty ~= "" then tt:AddLine(difficulty, 0.8, 0.8, 0.8) end
            tt:AddLine(" ")
        end
        local list = SavedInstances()
        if #list == 0 then tt:AddLine(L.TT_NO_SAVES, 0.8, 0.8, 0.8) end
        for _, s in ipairs(list) do
            local left = s.difficulty and ("%s (%s)"):format(s.name, s.difficulty) or s.name
            local right = (s.total and s.total > 0) and ("%d / %d"):format(s.done or 0, s.total) or ""
            WHITE(tt, left, right)
            if s.reset then tt:AddLine(L.TT_RESET:format(FormatDuration(s.reset)), 0.6, 0.6, 0.6) end
        end
    end,
})

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

-- Profession spells, used to recognize professions whatever the game language:
-- the spell name is the profession name in the player's language, and its icon
-- is the profession icon. Gathering professions have no window to open.
-- (Jewelcrafting and Inscription are listed in case WoW Forever adds them.)
local PROFESSION_SPELLS = {
    { id = 2259 },                    -- Alchemy
    { id = 2018 },                    -- Blacksmithing
    { id = 7411 },                    -- Enchanting
    { id = 4036 },                    -- Engineering
    { id = 2366, gathering = true },  -- Herbalism
    { id = 2108 },                    -- Leatherworking
    { id = 2575, gathering = true },  -- Mining
    { id = 8613, gathering = true },  -- Skinning
    { id = 3908 },                    -- Tailoring
    { id = 25229 },                   -- Jewelcrafting
    { id = 45357 },                   -- Inscription
    { id = 2550, secondary = "cooking" },
    { id = 3273, secondary = "firstAid" },
    { id = 7620, secondary = "fishing", gathering = true },
}

local GetSpellNameFn = (C_Spell and C_Spell.GetSpellName) or function() end
local GetSpellIconFn = (C_Spell and C_Spell.GetSpellTexture) or function() end

-- Localized profession name -> { icon, secondary, gathering } (built once, on first use)
local professionInfo
local function ProfessionInfo(name)
    if not professionInfo then
        professionInfo = {}
        for _, p in ipairs(PROFESSION_SPELLS) do
            local spellName = Try(GetSpellNameFn, p.id)
            if spellName then
                professionInfo[spellName] = { icon = Try(GetSpellIconFn, p.id), secondary = p.secondary,
                    gathering = p.gathering }
            end
        end
    end
    return professionInfo[name]
end

-- The character's professions: { primary = { first, second }, cooking = ..., firstAid = ...,
-- fishing = ... }, each entry { name, rank, max }. Modern API (GetProfessions) when
-- available, else the skill window (professions are the skills that can be unlearned).
local function Professions()
    local list = {}
    if GetProfessions and GetProfessionInfo then
        local indices = { Try(GetProfessions) } -- indices with holes (nil = none)
        for i = 1, 6 do
            if indices[i] then
                local name, _, rank, max = Try(GetProfessionInfo, indices[i])
                if name then table.insert(list, { name = name, rank = rank or 0, max = max or 0 }) end
            end
        end
    end
    if #list == 0 then list = SkillLines().professions end
    local result = { primary = {} }
    for _, p in ipairs(list) do
        local info = ProfessionInfo(p.name)
        if info and info.secondary then
            result[info.secondary] = p
        else
            table.insert(result.primary, p)
        end
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
local SKILL_FRAME_MACRO = "/run if ToggleCharacter then ToggleCharacter('SkillFrame') end"

local function SkillTooltip(tt, list)
    for _, s in ipairs(list) do
        local color = s.rank >= s.max and "|cff4dff4d" or "|cffffffff"
        tt:AddDoubleLine(s.name, ("%s%d / %d|r"):format(color, s.rank, s.max), 1, 1, 1)
    end
end

-- One block per profession slot: first and second primary profession, then the
-- secondary ones. Each block hides itself while the character has no such profession.
local PROFESSION_BLOCKS = {
    { key = "profession1", label = "PROFESSION_1", get = function(p) return p.primary[1] end, showName = true },
    { key = "profession2", label = "PROFESSION_2", get = function(p) return p.primary[2] end, showName = true },
    { key = "cooking", label = "COOKING", get = function(p) return p.cooking end },
    { key = "firstAid", label = "FIRST_AID", get = function(p) return p.firstAid end },
    { key = "fishing", label = "FISHING", get = function(p) return p.fishing end },
}

for _, def in ipairs(PROFESSION_BLOCKS) do
    local function Current() return def.get(Professions()) end
    ns:RegisterModule(def.key, {
        label = def.label,
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        getIcon = function()
            local p = Current()
            local info = p and ProfessionInfo(p.name)
            return info and info.icon or "Interface\\Icons\\INV_Misc_Note_01"
        end,
        events = { "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "CHAT_MSG_SKILL" },
        defaultEnabled = false,
        isEmpty = function() return Current() == nil end,
        update = function()
            local p = Current()
            if not p then return L.NONE end
            local text = ("%d / %d"):format(p.rank, p.max)
            if def.showName then text = p.name .. " " .. text end
            return text, p.rank >= p.max and GOOD or nil
        end,
        progress = function()
            local p = Current()
            return p and p.max > 0 and p.rank / p.max or nil
        end,
        tooltip = function(tt)
            local p = Current()
            if p then SkillTooltip(tt, { p }) else tt:AddLine(L.NONE, 0.8, 0.8, 0.8) end
        end,
        -- click: opens the profession window (/cast <profession>); gathering professions
        -- have none, so the professions book opens instead (the skill window on clients
        -- without it). Rebuilt out of combat when it changes.
        secureMacro = function()
            local p = Current()
            local info = p and ProfessionInfo(p.name)
            if p and info and not info.gathering then return "/cast " .. p.name end
            return MicroButtonMacro("ProfessionMicroButton", SKILL_FRAME_MACRO)
        end,
        clickHint = L.HINT_PROFESSION,
    })
end

-- Weapon skill matching the main-hand weapon (its type name contains the skill name,
-- e.g. "One-Handed Swords" / "Swords"), else the weapon skill furthest from its max
local function CurrentWeaponSkill(weapons)
    local link = Try(GetInventoryItemLink, "player", 16)
    local subType = link and select(7, GetItemInfoFn(link))
    local best
    for _, w in ipairs(weapons) do
        if subType and (subType:find(w.name, 1, true) or w.name:find(subType, 1, true)) then return w end
        -- (defense, skill 95, is listed with the weapons but is not one)
        if w.id ~= 95 and (not best or (w.max - w.rank) > (best.max - best.rank)) then best = w end
    end
    return best
end

-- Weapon skills only exist on clients with a skill list (C_SkillInfo on WoW Forever):
-- the block is offered only there
local HAS_SKILL_LIST = _G["C_SkillInfo"] and _G["C_SkillInfo"].GetNumSkillLines and _G["C_SkillInfo"].GetSkillLineInfo
-- WoW Forever's skills window is SkillsFrame, a tab of the character window
local SKILLS_MACRO = "/run if ToggleCharacter then ToggleCharacter(SkillsFrame and 'SkillsFrame' or 'SkillFrame') end"
if HAS_SKILL_LIST then
ns:RegisterModule("weaponSkills", {
    label = "WEAPON_SKILLS",
    icon = "Interface\\Icons\\INV_Sword_04",
    events = { "SKILL_LINES_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "CHAT_MSG_SKILL" },
    defaultEnabled = false,
    isEmpty = function() return #SkillLines().weapons == 0 end,
    update = function()
        local w = CurrentWeaponSkill(SkillLines().weapons)
        if not w then return L.NONE end
        return ("%s %d/%d"):format(w.name, w.rank, w.max), w.rank >= w.max and GOOD or WARN
    end,
    progress = function()
        local w = CurrentWeaponSkill(SkillLines().weapons)
        return w and w.max > 0 and w.rank / w.max or nil
    end,
    tooltip = function(tt) SkillTooltip(tt, SkillLines().weapons) end,
    secureMacro = SKILLS_MACRO,
    clickHint = L.HINT_SKILLS,
})
end

---------------------------------------------------------------------------
-- WoW Forever: Legacy points ("Parcours Héritage")
---------------------------------------------------------------------------
-- The Legacy reward track is a renown track (Blizzard's major factions system): the
-- points are its renown level, its rewards are renown rewards. Found with the
-- /tessera debug legacy probe (Placement.lua); no official documentation yet.
local LEGACY_FACTION = 2802
local LEGACY_ICON = 4279397 -- icon of the Legacy micro button

local function LegacyData()
    if not (C_MajorFactions and C_MajorFactions.GetMajorFactionData) then return nil end
    local data = Try(C_MajorFactions.GetMajorFactionData, LEGACY_FACTION)
    if type(data) ~= "table" or type(data.renownLevel) ~= "number" then return nil end
    return data
end

-- Reward levels of the track, each { level, name, reached }
local function LegacyRewards(points)
    local list = {}
    local levels = C_MajorFactions.GetRenownLevels and Try(C_MajorFactions.GetRenownLevels, LEGACY_FACTION)
    for _, info in ipairs(type(levels) == "table" and levels or {}) do
        local rewards = C_MajorFactions.GetRenownRewardsForLevel
            and Try(C_MajorFactions.GetRenownRewardsForLevel, LEGACY_FACTION, info.level)
        local reward = type(rewards) == "table" and rewards[1]
        -- a reward may come without its name (item not cached yet, or already collected):
        -- then its toast text, or the item's name
        local name = reward and (reward.name ~= "" and reward.name or nil)
        if reward and not name and reward.toastDescription and reward.toastDescription ~= "" then
            name = reward.toastDescription
        end
        if reward and not name and reward.itemID then
            local getName = (C_Item and C_Item.GetItemNameByID) or function(id) return (GetItemInfoFn(id)) end
            name = Try(getName, reward.itemID)
        end
        table.insert(list, { level = info.level, name = name or "?", reached = points >= info.level })
    end
    table.sort(list, function(a, b) return a.level < b.level end)
    return list
end

-- Legacy challenges by main category: { { name, done, total } }. On WoW Forever the
-- achievement categories are the Legacy challenge categories (Classes, Crafting, PvP,
-- Dungeons, Raids, Adventure); a main category also counts its sub-categories.
local function LegacyChallenges()
    local list = {}
    local cats = type(GetCategoryList) == "function" and Try(GetCategoryList)
    if type(cats) ~= "table" then return list end
    local byId, mains = {}, {}
    for _, id in ipairs(cats) do
        local name, parent = Try(GetCategoryInfo, id)
        local total, done = Try(GetCategoryNumAchievements, id, true)
        byId[id] = { name = name, parent = parent, total = total or 0, done = done or 0 }
        if parent == -1 then table.insert(mains, id) end
    end
    for _, id in ipairs(mains) do
        local c = byId[id]
        local entry = { name = c.name or "?", total = c.total, done = c.done }
        for _, sub in pairs(byId) do
            if sub.parent == id then
                entry.total, entry.done = entry.total + sub.total, entry.done + sub.done
            end
        end
        if entry.total > 0 then table.insert(list, entry) end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function NextLegacyReward(points)
    for _, r in ipairs(LegacyRewards(points)) do
        if not r.reached then return r end
    end
end

-- Offered on clients with the Legacy system only (WoW Forever)
if C_MajorFactions and (_G["ToggleLegacySystemUI"] or _G["LegacySystemFrame_LoadUI"]) then
ns:RegisterModule("legacy", {
    label = "LEGACY",
    icon = LEGACY_ICON,
    events = { "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "MAJOR_FACTION_UNLOCKED", "UPDATE_FACTION" },
    interval = 60, -- in case the renown events are not sent for this track
    defaultEnabled = false,
    update = function()
        local data = LegacyData()
        if not data then return L.NA end
        return tostring(data.renownLevel)
    end,
    -- progress toward the next reward
    progress = function()
        local data = LegacyData()
        if not data then return nil end
        local previous, nextReward = 0, nil
        for _, r in ipairs(LegacyRewards(data.renownLevel)) do
            if r.reached then previous = r.level elseif not nextReward then nextReward = r end
        end
        if not nextReward then return 1 end
        return (data.renownLevel - previous) / math.max(1, nextReward.level - previous)
    end,
    tooltip = function(tt)
        local data = LegacyData()
        if not data then
            tt:AddLine(L.NA, 0.8, 0.8, 0.8)
            return
        end
        WHITE(tt, L.LEGACY, tostring(data.renownLevel))
        local nextReward = NextLegacyReward(data.renownLevel)
        if nextReward then
            tt:AddLine(L.TT_LEGACY_NEXT:format(nextReward.name, nextReward.level), 1, 0.82, 0, true)
        else
            tt:AddLine(L.TT_LEGACY_ALL, 0.3, 1, 0.3)
        end
        tt:AddLine(" ")
        for _, r in ipairs(LegacyRewards(data.renownLevel)) do
            local color = r.reached and "|cff4dff4d" or "|cff999999"
            tt:AddDoubleLine(color .. r.name .. "|r", color .. r.level .. "|r")
        end
        -- Legacy challenges are achievements: completed / total per main category
        local categories = LegacyChallenges()
        if #categories > 0 then
            tt:AddLine(" ")
            tt:AddLine(L.TT_LEGACY_CHALLENGES, 1, 0.82, 0)
            for _, c in ipairs(categories) do
                local color = c.done >= c.total and "|cff4dff4d" or "|cffffffff"
                tt:AddDoubleLine(c.name, color .. c.done .. " / " .. c.total .. "|r", 1, 1, 1)
            end
        end
    end,
    chatText = function()
        local data = LegacyData()
        return data and (L.LEGACY .. " : " .. data.renownLevel) or nil
    end,
    secureMacro = function()
        return MicroButtonMacro("LegacyMicroButton", "/run if ToggleLegacySystemUI then ToggleLegacySystemUI() end")
    end,
    clickHint = L.HINT_LEGACY,
})
end

---------------------------------------------------------------------------
-- Unspent talent points (shows only when some are left)
---------------------------------------------------------------------------
-- UnitCharacterPoints is the classic talent function (WoW Forever's talents are classic
-- style); it is not in Blizzard's documentation of the modern API, hence _G
local function FreeTalentPoints()
    return Try(_G["UnitCharacterPoints"], "player") or 0
end

ns:RegisterModule("talents", {
    label = "TALENTS",
    icon = "Interface\\Icons\\Ability_Marksmanship",
    events = { "CHARACTER_POINTS_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE" },
    defaultEnabled = false,
    alertOnShow = true,
    isEmpty = function() return FreeTalentPoints() <= 0 end,
    update = function()
        local points = FreeTalentPoints()
        return tostring(points), points > 0 and WARN or GOOD
    end,
    tooltip = function(tt)
        tt:AddDoubleLine(L.TT_FREE_TALENTS, tostring(FreeTalentPoints()), 1, 1, 1, 1, 1, 1)
    end,
    secureMacro = function()
        return MicroButtonMacro("TalentMicroButton", "/run if ToggleTalentFrame then ToggleTalentFrame() end")
    end,
    clickHint = L.HINT_TALENTS,
})

---------------------------------------------------------------------------
-- Rested experience (shows while there is some)
---------------------------------------------------------------------------
local function RestedPercent()
    if AtMaxLevel() then return 0 end
    local rested, max = GetXPExhaustion(), UnitXPMax("player")
    if not rested or not max or max == 0 then return 0 end
    return rested / max * 100
end

ns:RegisterModule("rested", {
    label = "RESTED",
    icon = "Interface\\Icons\\Spell_Nature_Sleep",
    events = { "UPDATE_EXHAUSTION", "PLAYER_XP_UPDATE", "PLAYER_UPDATE_RESTING", "PLAYER_LEVEL_UP" },
    defaultEnabled = false,
    isEmpty = function() return RestedPercent() <= 0 end,
    update = function()
        return ("%d%%"):format(math.floor(RestedPercent() + 0.5))
    end,
    progress = function() return math.min(1, RestedPercent() / 150) end, -- rested XP caps at 150 %
    tooltip = function(tt)
        local fmt = BreakUpLargeNumbers or tostring
        tt:AddDoubleLine(L.TT_XP_RESTED, fmt(GetXPExhaustion() or 0), 1, 1, 1, 0.3, 0.65, 1)
        tt:AddLine(IsResting() and L.TT_RESTING or L.TT_NOT_RESTING, 0.8, 0.8, 0.8)
    end,
})

---------------------------------------------------------------------------
-- Played time. The game only answers RequestTimePlayed() with an event that
-- the chat frames also print; that printing is muted for Tessera's own request.
---------------------------------------------------------------------------
local played = { total = nil, level = nil, at = 0, requested = false }
local mutedChatFrames = {}

local playedFrame = CreateFrame("Frame")
playedFrame:RegisterEvent("TIME_PLAYED_MSG")
playedFrame:SetScript("OnEvent", function(_, _, total, level)
    played.total, played.level, played.at = total, level, GetTime()
    played.requested = false
    -- give the chat frames their event back, after this event has been delivered
    C_Timer.After(0, function()
        for _, chat in ipairs(mutedChatFrames) do chat:RegisterEvent("TIME_PLAYED_MSG") end
        wipe(mutedChatFrames)
    end)
    ns:UpdateBlock("played")
end)

local function RequestPlayed()
    if played.requested or not RequestTimePlayed then return end
    played.requested = true
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local chat = _G["ChatFrame" .. i]
        if chat and chat.IsEventRegistered and chat:IsEventRegistered("TIME_PLAYED_MSG") then
            chat:UnregisterEvent("TIME_PLAYED_MSG")
            table.insert(mutedChatFrames, chat)
        end
    end
    RequestTimePlayed()
end

local function PlayedNow(base)
    return base and (base + GetTime() - played.at) or nil
end

ns:RegisterModule("played", {
    label = "PLAYED",
    icon = "Interface\\Icons\\INV_Misc_PocketWatch_03",
    interval = 30,
    defaultEnabled = false,
    request = RequestPlayed,
    requestInterval = 3600,
    update = function()
        local level = PlayedNow(played.level)
        return level and ShortDuration(level) or ShortDuration(GetTime() - session.start)
    end,
    tooltip = function(tt)
        WHITE(tt, L.TT_SESSION_TIME, FormatDuration(GetTime() - session.start))
        if played.level then WHITE(tt, L.TT_PLAYED_LEVEL, FormatDuration(PlayedNow(played.level))) end
        if played.total then WHITE(tt, L.TT_PLAYED_TOTAL, FormatDuration(PlayedNow(played.total))) end
    end,
})

---------------------------------------------------------------------------
-- Group (shows only in a group or raid)
---------------------------------------------------------------------------
local function GroupUnits()
    local units, raid = {}, IsInRaid and IsInRaid()
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    if raid then
        for i = 1, count do table.insert(units, "raid" .. i) end
    elseif count > 0 then
        table.insert(units, "player")
        for i = 1, count - 1 do table.insert(units, "party" .. i) end
    end
    return units, raid
end

ns:RegisterModule("group", {
    label = "GROUP",
    icon = "Interface\\Icons\\INV_Misc_GroupLooking",
    events = { "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED" },
    defaultEnabled = false,
    isEmpty = function() return not (IsInGroup and IsInGroup()) end,
    update = function()
        local units, raid = GroupUnits()
        return ("%d / %d"):format(#units, raid and 40 or 5)
    end,
    tooltip = function(tt)
        local units = GroupUnits()
        for i = 1, math.min(#units, MAX_LINES) do
            local unit = units[i]
            local name = Try(UnitName, unit)
            if name then
                local _, class = Try(UnitClass, unit)
                local r, g, b = ClassColor(class)
                local leader = UnitIsGroupLeader and Try(UnitIsGroupLeader, unit) and " |cffffd100(" .. L.TT_LEADER .. ")|r" or ""
                tt:AddDoubleLine(name .. leader, tostring(Try(UnitLevel, unit) or ""), r, g, b, 0.8, 0.8, 0.8)
            end
        end
        if #units > MAX_LINES then tt:AddLine(L.TT_MORE:format(#units - MAX_LINES), 0.8, 0.8, 0.8) end
    end,
})

---------------------------------------------------------------------------
-- Daily / weekly reset timers (only if the client provides them)
---------------------------------------------------------------------------
if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
    ns:RegisterModule("reset", {
        label = "RESET",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_02",
        interval = 30,
        defaultEnabled = false,
        update = function()
            local daily = Try(C_DateAndTime.GetSecondsUntilDailyReset)
            return daily and ShortDuration(daily) or nil
        end,
        tooltip = function(tt)
            local daily = Try(C_DateAndTime.GetSecondsUntilDailyReset)
            local weekly = C_DateAndTime.GetSecondsUntilWeeklyReset and Try(C_DateAndTime.GetSecondsUntilWeeklyReset)
            if daily then WHITE(tt, L.TT_RESET_DAILY, FormatDuration(daily)) end
            if weekly then WHITE(tt, L.TT_RESET_WEEKLY, FormatDuration(weekly)) end
        end,
    })
end

---------------------------------------------------------------------------
-- Goal: progress towards an amount of gold or a level, chosen by the player
---------------------------------------------------------------------------
-- Returns progress (0..1), current value text, target text
local function GoalProgress(cfg)
    local target = cfg.goalValue or 1000
    if cfg.goalType == "level" then
        local level = UnitLevel("player") or 1
        local max = UnitXPMax("player")
        local frac = (max and max > 0) and UnitXP("player") / max or 0
        local progress = target > 1 and (level - 1 + frac) / (target - 1) or 1
        return math.min(1, progress), tostring(level), tostring(target)
    end
    local gold = (GetMoney() or 0) / 10000
    return math.min(1, target > 0 and gold / target or 1), FormatGold(GetMoney() or 0, { goldFormat = "gold" }),
        FormatGold(target * 10000, { goldFormat = "gold" })
end

ns:RegisterModule("goal", {
    label = "GOAL",
    icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_04",
    events = { "PLAYER_MONEY", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP" },
    defaultEnabled = false,
    defaults = { progressBar = true, goalType = "gold", goalValue = 1000 },
    options = {
        { kind = "dropdown", field = "goalType", label = "GOAL_TYPE", tip = "TIP_GOAL_TYPE",
          values = { { key = "gold", label = "GOAL_GOLD" }, { key = "level", label = "GOAL_LEVEL" } } },
        { kind = "number", field = "goalValue", label = "GOAL_VALUE", tip = "TIP_GOAL_VALUE", min = 1 },
    },
    progress = function(cfg) return (GoalProgress(cfg)) end,
    update = function(cfg)
        local progress = GoalProgress(cfg)
        return ("%d%%"):format(math.floor(progress * 100)), progress >= 1 and GOOD or nil
    end,
    tooltip = function(tt, cfg)
        local progress, current, target = GoalProgress(cfg)
        WHITE(tt, L.TT_GOAL_CURRENT, current)
        WHITE(tt, L.TT_GOAL_TARGET, target)
        WHITE(tt, L.TT_GOAL_PROGRESS, ("%d%%"):format(math.floor(progress * 100)))
    end,
})

---------------------------------------------------------------------------
-- Class reagents: shows the reagents of your class that you carry, in orange
-- when the stock runs low. Item IDs are the Classic ones.
---------------------------------------------------------------------------
local REAGENTS = {
    WARLOCK = { 6265 },                                   -- Soul Shard
    ROGUE   = { 5140, 5530 },                             -- Flash Powder, Blinding Powder
    MAGE    = { 17031, 17032, 17020, 17056 },             -- Runes of Teleportation / Portals, Arcane Powder, Light Feather
    SHAMAN  = { 17030 },                                  -- Ankh
    PRIEST  = { 17028, 17029, 17056 },                    -- Holy / Sacred Candle, Light Feather
    PALADIN = { 17033, 21177 },                           -- Symbol of Divinity, Symbol of Kings
    DRUID   = { 17034, 17035, 17036, 17037, 17038, 17021, 17026 }, -- seeds, Wild Berries, Wild Thornroot
}
local REAGENT_LOW = 5

local GetItemCountFn = (C_Item and C_Item.GetItemCount) or function() return 0 end
local GetItemIconFn = (C_Item and C_Item.GetItemIconByID) or function() end

-- Reagents of the player's class that are in the bags: { id, count, icon }
local function CarriedReagents()
    local _, class = UnitClass("player")
    local list = {}
    for _, id in ipairs(REAGENTS[class] or {}) do
        local count = GetItemCountFn and Try(GetItemCountFn, id) or 0
        if count and count > 0 then
            table.insert(list, { id = id, count = count, icon = GetItemIconFn and Try(GetItemIconFn, id) })
        end
    end
    return list
end

ns:RegisterModule("reagents", {
    label = "REAGENTS",
    icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
    events = { "BAG_UPDATE_DELAYED" },
    isEmpty = function() return #CarriedReagents() == 0 end,
    update = function(cfg)
        local list = CarriedReagents()
        if #list == 0 then return L.NONE end
        local size, parts, level = cfg.fontSize or 12, {}, GOOD
        for _, r in ipairs(list) do
            local icon = r.icon and ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(r.icon, size, size) or ""
            table.insert(parts, r.count .. icon)
            if r.count <= REAGENT_LOW then level = WARN end
        end
        return table.concat(parts, "  "), level
    end,
    tooltip = function(tt)
        local list = CarriedReagents()
        if #list == 0 then tt:AddLine(L.NONE, 0.8, 0.8, 0.8) end
        for _, r in ipairs(list) do
            local name = GetItemInfoFn(r.id) or ("#" .. r.id)
            tt:AddDoubleLine(name, tostring(r.count), 1, 1, 1, r.count <= REAGENT_LOW and 1 or 1,
                r.count <= REAGENT_LOW and 0.6 or 1, r.count <= REAGENT_LOW and 0.2 or 1)
        end
    end,
})

---------------------------------------------------------------------------
-- Unread whispers: counts whispers received since you last answered each
-- sender; a click replies to the most recent one. Names are read through
-- pcall/tostring because chat data can be protected on Midnight-era clients.
---------------------------------------------------------------------------
local whispers = {} -- ordered list of { name, count, at, bnet }

local function FindWhisper(name)
    for i, w in ipairs(whispers) do
        if w.name == name then return i, w end
    end
end

local function OnWhisper(name, bnet)
    if issecretvalue and issecretvalue(name) then return end -- protected chat data: ignore
    local ok, text = pcall(tostring, name)
    if not ok or not text or text == "" then return end
    local i, w = FindWhisper(text)
    if w then table.remove(whispers, i) else w = { name = text, count = 0, bnet = bnet } end
    w.count, w.at = w.count + 1, GetTime()
    table.insert(whispers, w)
end

local function ClearWhisper(name)
    if issecretvalue and issecretvalue(name) then return end
    local ok, text = pcall(tostring, name)
    local i = ok and FindWhisper(text)
    if i then table.remove(whispers, i) end
end

local whisperFrame = CreateFrame("Frame")
for _, event in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER",
                         "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER_INFORM" }) do
    pcall(whisperFrame.RegisterEvent, whisperFrame, event)
end
whisperFrame:SetScript("OnEvent", function(_, event, _, sender)
    if event == "CHAT_MSG_WHISPER" then
        OnWhisper(sender, false)
    elseif event == "CHAT_MSG_BN_WHISPER" then
        OnWhisper(sender, true)
    else
        ClearWhisper(sender) -- you answered: that conversation is read
    end
    ns:UpdateBlock("whispers")
end)

local function UnreadCount()
    local n = 0
    for _, w in ipairs(whispers) do n = n + w.count end
    return n
end

ns:RegisterModule("whispers", {
    label = "WHISPERS",
    icon = "Interface\\Icons\\INV_Letter_02",
    alertOnShow = true,
    isEmpty = function() return #whispers == 0 end,
    update = function()
        local n = UnreadCount()
        return tostring(n), n > 0 and WARN or GOOD
    end,
    tooltip = function(tt)
        if #whispers == 0 then tt:AddLine(L.NONE, 0.8, 0.8, 0.8) end
        for i = #whispers, 1, -1 do
            local w = whispers[i]
            tt:AddDoubleLine(("%s (%d)"):format(w.name, w.count),
                L.TT_AGO:format(ShortDuration(GetTime() - w.at)), 1, 1, 1, 0.7, 0.7, 0.7)
        end
    end,
    clickHint = L.HINT_WHISPER,
    -- left click: reply to the most recent sender, and mark it as read
    onClick = function(_, button)
        if button ~= "LeftButton" then return end
        local w = whispers[#whispers]
        if not w then return end
        local tell = w.bnet and (ChatFrame_SendBNetTell or (ChatFrameUtil and ChatFrameUtil.SendBNetTell))
            or (ChatFrame_SendTell or (ChatFrameUtil and ChatFrameUtil.SendTell))
        if tell then pcall(tell, w.name) end
        table.remove(whispers)
    end,
})

---------------------------------------------------------------------------
-- WoW Forever: Comprehension, Camping and Honor blocks
---------------------------------------------------------------------------
-- These systems have no documented API yet: the IDs below were found in game
-- with a debug probe on the WoW Forever beta (October 2026) and may change.
-- The blocks are offered only on WoW Forever (where the Legacy system exists).
local IS_FOREVER = C_MajorFactions and (_G["ToggleLegacySystemUI"] or _G["LegacySystemFrame_LoadUI"]) and true or false

local COMPREHENSION_SKILL = 3012    -- secondary skill: reading magical scrolls
local COMPREHENSION_SPELL = 1296017 -- "Scroll Comprehension"
local CAMP_KIT = 279981             -- Basic Campfire Kit
local CAMP_PERKS = 1229741          -- "Camp Perks": buffs of the camp objects (1 hour)
local CAMP_WELCOMING = 1229739      -- "Welcoming Campfire": sit 1 minute to get the buffs
local CAMP_NEAR = 1283391           -- "Nearby Campfire"
local HONOR_CURRENCY = 1792         -- Honor points
local SCROLL_SUBCLASS = 4           -- consumable subclass "Scroll"

local function SpellName(id)
    return Try(C_Spell and C_Spell.GetSpellName, id)
end

-- Comprehension skill: { rank, max } or nil (learned from level 6)
local function ComprehensionSkill()
    local S = _G["C_SkillInfo"] -- WoW Forever only (not in the modern API docs)
    if not (S and S.GetNumSkillLines and S.GetSkillLineInfo) then return nil end
    for i = 1, tonumber((Try(S.GetNumSkillLines))) or 0 do
        local info = Try(S.GetSkillLineInfo, i)
        if type(info) == "table" and info.skillID == COMPREHENSION_SKILL then
            return { name = info.name, rank = info.rank or 0, max = info.maxRank or 0 }
        end
    end
end

-- Scrolls in the bags: { { name, count } }, by item class (Scroll), or by the
-- localized word "scroll" in the name (weapon imbue scrolls are item enhancements)
local function ScrollsInBags()
    local C = C_Container
    local found, list = {}, {}
    local word = (L.SCROLL_WORD or "scroll"):lower()
    for bag = 0, 4 do
        local slots = C and C.GetContainerNumSlots and Try(C.GetContainerNumSlots, bag) or 0
        for slot = 1, slots do
            local info = Try(C.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.itemID and info.hyperlink then
                local name = info.hyperlink:match("%[(.-)%]") or "?"
                local _, _, _, _, _, classID, subClassID = Try(C_Item and C_Item.GetItemInfoInstant,
                    info.itemID)
                if (classID == 0 and subClassID == SCROLL_SUBCLASS) or name:lower():find(word, 1, true) then
                    if not found[name] then
                        found[name] = { name = name, count = 0 }
                        table.insert(list, found[name])
                    end
                    found[name].count = found[name].count + (info.stackCount or 1)
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Aura on the player by spell ID: { name, left (seconds, nil = no duration) } or nil
local function PlayerAura(spellID)
    local UA = C_UnitAuras
    local aura
    if UA and UA.GetPlayerAuraBySpellID then
        aura = Try(UA.GetPlayerAuraBySpellID, spellID)
    elseif UA and UA.GetAuraDataByIndex then
        for i = 1, 40 do
            local a = Try(UA.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not a then break end
            if a.spellId == spellID then aura = a break end
        end
    end
    if type(aura) ~= "table" then return nil end
    local ok, left = pcall(function()
        if aura.expirationTime and aura.expirationTime > 0 then return math.max(0, aura.expirationTime - GetTime()) end
    end)
    return { name = aura.name, left = ok and left or nil }
end

-- Seconds left on the campfire kit cooldown (0 = ready); same safety as the Hearthstone
local function KitCooldown()
    local start, duration
    if C_Container and C_Container.GetItemCooldown then start, duration = Try(C_Container.GetItemCooldown, CAMP_KIT) end
    local ok, remaining = pcall(function()
        if start and duration and start > 0 and duration > 1.5 then return math.max(0, start + duration - GetTime()) end
        return 0
    end)
    return ok and remaining or 0
end

local function KitCount()
    return GetItemCountFn and Try(GetItemCountFn, CAMP_KIT) or 0
end

local function HonorInfo()
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local info = Try(C_CurrencyInfo.GetCurrencyInfo, HONOR_CURRENCY)
    if type(info) ~= "table" or not info.name or info.name == "" then return nil end
    return info
end

if IS_FOREVER then
ns:RegisterModule("comprehension", {
    label = "COMPREHENSION",
    icon = "Interface\\Icons\\INV_Scroll_03",
    events = { "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "BAG_UPDATE_DELAYED" },
    defaultEnabled = false,
    isEmpty = function() return ComprehensionSkill() == nil end,
    update = function()
        local s = ComprehensionSkill()
        if not s then return L.NONE end
        return ("%d/%d"):format(s.rank, s.max), s.rank >= s.max and GOOD or WARN
    end,
    progress = function()
        local s = ComprehensionSkill()
        return s and s.max > 0 and s.rank / s.max or nil
    end,
    tooltip = function(tt)
        local s = ComprehensionSkill()
        if not s then
            tt:AddLine(L.TT_COMPREHENSION_NONE, 0.8, 0.8, 0.8, true)
            return
        end
        WHITE(tt, s.name, ("%d / %d"):format(s.rank, s.max))
        tt:AddLine(" ")
        local scrolls = ScrollsInBags()
        if #scrolls == 0 then
            tt:AddLine(L.TT_NO_SCROLLS, 0.6, 0.6, 0.6)
        else
            tt:AddLine(L.TT_SCROLLS, 1, 0.82, 0)
            for _, sc in ipairs(scrolls) do WHITE(tt, sc.name, "x" .. sc.count) end
        end
    end,
    chatText = function()
        local s = ComprehensionSkill()
        return s and ("%s : %d/%d"):format(s.name, s.rank, s.max) or nil
    end,
    -- click: the Comprehension spell, or the skills window if it is not known yet
    secureMacro = function()
        local name = SpellName(COMPREHENSION_SPELL)
        if name and ComprehensionSkill() then return "/cast " .. name end
        return SKILLS_MACRO
    end,
    clickHint = L.HINT_COMPREHENSION,
})

ns:RegisterModule("camping", {
    label = "CAMPING",
    icon = "Interface\\Icons\\Spell_Fire_Fire",
    events = { "UNIT_AURA", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN" },
    interval = 1,
    defaultEnabled = false,
    -- hidden when there is no camp buff and no campfire kit
    isEmpty = function()
        return not PlayerAura(CAMP_PERKS) and not PlayerAura(CAMP_WELCOMING) and not PlayerAura(CAMP_NEAR)
            and KitCount() == 0
    end,
    update = function()
        local perks = PlayerAura(CAMP_PERKS)
        -- each value says what it is: camp buffs, resting countdown or campfire kit
        if perks and perks.left then return L.CAMP_BUFFS_LEFT:format(ShortDuration(perks.left)), GOOD end
        local welcoming = PlayerAura(CAMP_WELCOMING)
        if welcoming and welcoming.left then return L.CAMP_RESTING:format(ShortTime(welcoming.left)), WARN end
        if KitCount() > 0 then
            local cd = KitCooldown()
            if cd > 0 then return L.CAMP_KIT_COOLDOWN:format(ShortTime(cd)), WARN end
            return L.CAMP_KIT_READY, GOOD
        end
        return L.NONE
    end,
    tooltip = function(tt)
        local any = false
        for _, id in ipairs({ CAMP_PERKS, CAMP_WELCOMING, CAMP_NEAR }) do
            local aura = PlayerAura(id)
            if aura then
                if not any then tt:AddLine(L.TT_CAMP_BUFFS, 1, 0.82, 0) end
                any = true
                WHITE(tt, aura.name or "?", aura.left and ShortTime(aura.left) or "")
            end
        end
        if not any then tt:AddLine(L.TT_CAMP_NONE, 0.8, 0.8, 0.8, true) end
        tt:AddLine(" ")
        local count = KitCount()
        WHITE(tt, L.TT_CAMP_KITS, tostring(count))
        if count > 0 then
            local cd = KitCooldown()
            if cd > 0 then
                tt:AddDoubleLine(L.TT_COOLDOWN, ShortTime(cd), 1, 1, 1, 1, 0.6, 0.2)
            else
                tt:AddDoubleLine(L.TT_COOLDOWN, L.TT_READY, 1, 1, 1, 0.3, 1, 0.3)
            end
        end
    end,
    -- click: light a campfire with the kit
    secureMacro = "/use item:" .. CAMP_KIT,
    clickHint = L.HINT_CAMPING,
})

ns:RegisterModule("honor", {
    label = "HONOR",
    icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
    events = { "CURRENCY_DISPLAY_UPDATE", "PLAYER_PVP_KILLS_CHANGED" },
    interval = 60,
    defaultEnabled = false,
    update = function()
        local info = HonorInfo()
        if not info then return L.NA end
        local fmt = BreakUpLargeNumbers or tostring
        local capped = info.maxQuantity and info.maxQuantity > 0 and info.quantity >= info.maxQuantity
        return fmt(info.quantity or 0), capped and WARN or nil
    end,
    progress = function()
        local info = HonorInfo()
        if not (info and info.maxQuantity and info.maxQuantity > 0) then return nil end
        return (info.quantity or 0) / info.maxQuantity
    end,
    tooltip = function(tt)
        local info = HonorInfo()
        if not info then
            tt:AddLine(L.NA, 0.8, 0.8, 0.8)
            return
        end
        local fmt = BreakUpLargeNumbers or tostring
        WHITE(tt, info.name, fmt(info.quantity or 0))
        if info.maxQuantity and info.maxQuantity > 0 then WHITE(tt, L.TT_HONOR_MAX, fmt(info.maxQuantity)) end
        if info.canEarnPerWeek then WHITE(tt, L.TT_HONOR_WEEK, fmt(info.quantityEarnedThisWeek or 0)) end
        local hk = Try(GetPVPLifetimeStats)
        if hk then WHITE(tt, L.TT_HONOR_KILLS, fmt(hk)) end
        tt:AddLine(" ")
        tt:AddLine(L.TT_HONOR_RANKS_LATER, 0.6, 0.6, 0.6, true)
    end,
    chatText = function()
        local info = HonorInfo()
        return info and ("%s : %s"):format(info.name, info.quantity or 0) or nil
    end,
})
end

---------------------------------------------------------------------------
-- Sample values for the preview mode (/tessera preview): used for screenshots,
-- they show what each block looks like with typical values. Blocks without a
-- sample keep showing their real value.
---------------------------------------------------------------------------
local SAMPLES = {
    gold        = function(cfg) return FormatGold(12345678, cfg) end,
    bags        = function() return L.BAGS_FORMAT:format(18, 64), GOOD end,
    durability  = function() return "87%", GOOD end,
    fps         = function() return L.FPS_FORMAT:format(144), GOOD end,
    latency     = function() return L.LATENCY_FORMAT:format(42), GOOD end,
    time        = function(cfg) return FormatClock(20, 45, cfg) end,
    serverTime  = function(cfg) return FormatClock(14, 45, cfg) end,
    xp          = function() return "45.3% |cff4da6ff+12%|r" end,
    coords      = function() return "48.2, 61.7" end,
    friends     = function() return "3" end,
    guild       = function() return "12 / 87" end,
    memory      = function() return FormatMemory(24576) end,
    mail        = function() return L.MAIL_NEW, GOOD end,
    quests      = function() return "12 / 25", GOOD end,
    reputation  = function() return (_G.FACTION_STANDING_LABEL6 or "Honored") .. " 64%" end,
    ammo        = function() return "842", GOOD end,
    itemLevel   = function() return "52.4" end,
    speed       = function() return "160%" end,
    volume      = function() return "80%" end,
    instances   = function() return L.INSTANCES_SAVED:format(2) end,
    talents     = function() return "1", WARN end,
    rested      = function() return "85%" end,
    played      = function() return ShortDuration(2 * 86400 + 4 * 3600) end,
    group       = function() return "4 / 5" end,
    reset       = function() return ShortDuration(5 * 3600 + 12 * 60) end,
    goal        = function() return "65%" end,
    whispers    = function() return "2", WARN end,
    regen       = function() return L.REGEN_FORMAT:format(48) end,
    stats       = function() return L.STAT_SHORT_AP .. " 1 250" end,
    loot        = function() return GameText("LOOT_GROUP_LOOT", L.LOOT_GROUP) end,
}
for key, sample in pairs(SAMPLES) do
    if ns.modules[key] then ns.modules[key].sample = sample end
end

-- more samples (added after the table above, same rules)
local MORE_SAMPLES = {
    currency     = function(cfg)
        local size = cfg.fontSize or 12
        return ("250|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format("Interface\\Icons\\INV_Misc_Coin_01", size, size)
    end,
    reagents     = function(cfg)
        local size = cfg.fontSize or 12
        return ("18|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format("Interface\\Icons\\INV_Misc_Gem_Amethyst_02", size, size)
    end,
    hearthstone  = function() return (Try(GetBindLocation) or "Goldshire"), GOOD end,
    profession1  = function() return L.SAMPLE_PROFESSION .. " 215 / 225" end,
    cooking      = function() return "150 / 150", GOOD end,
    weaponSkills = function() return "115/120", WARN end,
    legacy       = function() return "16" end,
    comprehension = function() return "42/65", WARN end,
    camping      = function() return L.CAMP_BUFFS_LEFT:format("52m"), GOOD end,
    honor        = function() return "3 250" end,
}
for key, sample in pairs(MORE_SAMPLES) do
    if ns.modules[key] then ns.modules[key].sample = sample end
end
