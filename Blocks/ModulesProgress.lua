local _, ns = ...
local L = ns.L

-- Blocks about progress: reputation, currencies, quests, goal, professions, ammo, session gains.
-- Shared tools come from Modules.lua (ns.BlockTools); see its header for how to add a block.
local Tools = ns.BlockTools
local AtMaxLevel, FormatDuration, FormatGold = Tools.AtMaxLevel, Tools.FormatDuration, Tools.FormatGold
local GOOD, GetItemCountFn = Tools.GOOD, Tools.GetItemCountFn
local GetItemInfoFn, MAX_LINES, Masked, MicroButtonMacro = Tools.GetItemInfoFn, Tools.MAX_LINES, Tools.Masked, Tools.MicroButtonMacro
local Percent, ShortDuration = Tools.Percent, Tools.ShortDuration
local SkillLines, SkillTooltip, THRESHOLDS, Threshold = Tools.SkillLines, Tools.SkillTooltip, Tools.THRESHOLDS, Tools.Threshold
local Try, WARN = Tools.Try, Tools.WARN
local WHITE, session = Tools.WHITE, Tools.session

-- A tooltip part is on unless its checkbox was cleared (a profile from before the checkbox keeps it on)
local function On(cfg, field)
    return not cfg or cfg[field] ~= false
end

---------------------------------------------------------------------------
-- Quests: count in the quest log, list in the tooltip
---------------------------------------------------------------------------
-- Quests in the log (headers excluded) as { title, level, complete }.
-- (C_QuestLog API)
local function QuestList()
    local list = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local n = Try(C_QuestLog.GetNumQuestLogEntries) or 0
        local zone -- the quest log groups the quests under a header named after their zone
        for i = 1, n do
            local info = Try(C_QuestLog.GetInfo, i)
            if info and info.isHeader then
                zone = info.title
            elseif info and not info.isHidden and not info.isTask then
                local complete = info.questID and C_QuestLog.IsComplete and Try(C_QuestLog.IsComplete, info.questID)
                table.insert(list, { title = info.title, level = info.level, complete = complete, zone = zone, order = #list + 1 })
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
    icon = "Interface\\Icons\\Achievement_Quests_Completed_01",
    events = { "QUEST_LOG_UPDATE" },
    defaultEnabled = false,
    update = function(cfg)
        local list = QuestList()
        local count, max = #list, MaxQuests()
        local level = Threshold(cfg, math.max(0, max - count), THRESHOLDS.quests) -- free slots: yellow at 2, red at 0
        local mode = cfg and cfg.questsFormat or "countMax"
        if mode == "count" then return tostring(count), level end
        if mode == "complete" then
            local done = 0
            for _, q in ipairs(list) do if q.complete then done = done + 1 end end
            return ("%d / %d"):format(done, count), done > 0 and GOOD or nil
        end
        return ("%d / %d"):format(count, max), level
    end,
    thresholds = THRESHOLDS.quests,
    defaults = { questsFormat = "countMax", questsSort = "game", questsLines = "20", questsTipLevel = true,
                 questsOnlyDone = false, questsTipZone = false },
    options = {
        { kind = "dropdown", field = "questsFormat", tab = "text", label = "QUESTS_SHOWN", tip = "TIP_QUESTS_SHOWN",
          values = { { key = "countMax", label = "QUESTS_COUNT_MAX" }, { key = "count", label = "QUESTS_COUNT" },
                     { key = "complete", label = "QUESTS_COMPLETE" } } },
        { kind = "check", field = "questsTipLevel", section = "tooltip", tab = "text", label = "QUESTS_TIP_LEVEL", tip = "TIP_QUESTS_TIP_LEVEL" },
        { kind = "check", field = "questsTipZone", section = "tooltip", tab = "text", label = "QUESTS_TIP_ZONE", tip = "TIP_QUESTS_TIP_ZONE" },
        { kind = "check", field = "questsOnlyDone", section = "tooltip", tab = "text", label = "QUESTS_ONLY_DONE", tip = "TIP_QUESTS_ONLY_DONE" },
        { kind = "dropdown", field = "questsSort", section = "tooltip", tab = "text", label = "QUESTS_SORT", tip = "TIP_QUESTS_SORT",
          values = { { key = "game", label = "QUESTS_SORT_GAME" }, { key = "level", label = "QUESTS_SORT_LEVEL" },
                     { key = "done", label = "QUESTS_SORT_DONE" } } },
        { kind = "dropdown", field = "questsLines", section = "tooltip", tab = "text", label = "QUESTS_LINES", tip = "TIP_QUESTS_LINES",
          values = { { key = "10", label = "QUESTS_LINES_10" }, { key = "20", label = "QUESTS_LINES_20" }, { key = "all", label = "QUESTS_LINES_ALL" } } },
    },
    tooltip = function(tt, cfg)
        local all = QuestList()
        local list = {}
        for _, q in ipairs(all) do
            if q.complete or not (cfg and cfg.questsOnlyDone) then table.insert(list, q) end
        end
        local sort = cfg and cfg.questsSort
        if sort == "level" then
            table.sort(list, function(a, b)
                if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
                return a.order < b.order
            end)
        elseif sort == "done" then
            table.sort(list, function(a, b)
                if (a.complete and 1 or 0) ~= (b.complete and 1 or 0) then return a.complete and true or false end
                return a.order < b.order
            end)
        end
        local setting = cfg and cfg.questsLines
        local limit = setting == "all" and #list or (tonumber(setting) or MAX_LINES)
        for i = 1, math.min(#list, limit) do
            local q = list[i]
            local right = q.complete and ("|cff4dff4d" .. L.TT_COMPLETE .. "|r") or ""
            local color = q.level and GetQuestDifficultyColor and GetQuestDifficultyColor(q.level)
            local r, g, b = 1, 1, 1
            if color then r, g, b = color.r, color.g, color.b end
            local left = q.title or "?"
            if On(cfg, "questsTipLevel") then left = ("[%s] %s"):format(q.level or "?", left) end
            if cfg and cfg.questsTipZone and q.zone then left = left .. " |cff999999- " .. q.zone .. "|r" end
            tt:AddDoubleLine(left, right, r, g, b)
        end
        if #list > limit then tt:AddLine(L.TT_MORE:format(#list - limit), 0.8, 0.8, 0.8) end
        if #list == 0 then tt:AddLine(L.NONE, 0.8, 0.8, 0.8) end
    end,
    secureMacro = "/run if ToggleQuestLog then ToggleQuestLog() end",
    clickHintKey = "HINT_QUESTS",
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
            return d.name, d.reaction, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding, d.factionID
        end
    end
    return nil
end

-- Reputation gained this session: the standing of each faction when first seen (session.repBase, kept
-- by faction id). Standings are absolute, so a gain that crosses into a new standing still adds up.
-- Reset session (Modules.lua) empties the table and calls ns.RepSnapshot.
local function RepSnapshot(full)
    session.repBase = session.repBase or {}
    local _, _, _, _, value, id = WatchedFaction()
    if id and value and session.repBase[id] == nil then session.repBase[id] = value end
    -- the factions of the reputation list too (the ones under a closed header are not listed)
    if full and C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
        for i = 1, Try(C_Reputation.GetNumFactions) or 0 do
            local d = Try(C_Reputation.GetFactionDataByIndex, i)
            if d and d.factionID and d.currentStanding and session.repBase[d.factionID] == nil then
                session.repBase[d.factionID] = d.currentStanding
            end
        end
    end
end
ns.RepSnapshot = function() RepSnapshot(true) end

local repTracker = CreateFrame("Frame")
repTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
repTracker:RegisterEvent("UPDATE_FACTION")
repTracker:SetScript("OnEvent", function(_, event) RepSnapshot(event == "PLAYER_ENTERING_WORLD") end)

-- Points gained with the watched faction this session, or nil
local function RepGain()
    local _, _, _, _, value, id = WatchedFaction()
    local base = id and session.repBase and session.repBase[id]
    return base and value and (value - base) or nil
end

-- Localized standing name ("Friendly", "Honored"...) from the game's globals
local function StandingLabel(reaction)
    return reaction and (_G["FACTION_STANDING_LABEL" .. reaction]) or "?"
end

ns:RegisterModule("reputation", {
    label = "REPUTATION",
    icon = "Interface\\Icons\\Achievement_reputation_04",
    events = { "UPDATE_FACTION" },
    isEmpty = function() return WatchedFaction() == nil end,
    defaults = { progressBar = true, repFormat = "standingPercent", repLeft = false, repTipName = true,
                 repTipStanding = true, repTipLeft = false, repTipSession = false },
    -- extra click action (Shift / middle click list): gains start again from now
    extraAction = { key = "resetSession", label = "ACTION_RESET_SESSION", run = Tools.ResetSession },
    progress = function()
        local name, _, min, max, value = WatchedFaction()
        if not name or not (max and min and max > min) then return nil end
        return (value - min) / (max - min)
    end,
    update = function(cfg)
        local name, reaction, min, max, value = WatchedFaction()
        if not name then return L.NONE end
        local hasRange = max and min and max > min
        local pct = math.floor(hasRange and Percent(value - min, max - min) or 100)
        local mode = cfg and cfg.repFormat or "standingPercent"
        local text
        if mode == "namePercent" then
            text = ("%s %d%%"):format(name, pct)
        elseif mode == "percent" then
            text = ("%d%%"):format(pct)
        elseif mode == "standing" then
            text = StandingLabel(reaction)
        else
            text = ("%s %d%%"):format(StandingLabel(reaction), pct)
        end
        -- points left: in brackets, so it is not read as part of the percent
        if cfg and cfg.repLeft and hasRange then
            text = text .. (" (%s)"):format((BreakUpLargeNumbers or tostring)(max - value))
        end
        return text
    end,
    options = {
        { kind = "dropdown", field = "repFormat", tab = "text", label = "REP_SHOWN", tip = "TIP_REP_SHOWN",
          values = { { key = "standingPercent", label = "REP_STANDING_PERCENT" },
                     { key = "namePercent", label = "REP_NAME_PERCENT" },
                     { key = "percent", label = "REP_PERCENT" }, { key = "standing", label = "REP_STANDING" } } },
        { kind = "check", field = "repLeft", tab = "text", label = "REP_LEFT", tip = "TIP_REP_LEFT" },
        { kind = "check", field = "repTipName", section = "tooltip", tab = "text", label = "REP_TIP_NAME", tip = "TIP_REP_TIP_NAME" },
        { kind = "check", field = "repTipStanding", section = "tooltip", tab = "text", label = "REP_TIP_STANDING", tip = "TIP_REP_TIP_STANDING" },
        { kind = "check", field = "repTipLeft", section = "tooltip", tab = "text", label = "REP_TIP_LEFT", tip = "TIP_REP_TIP_LEFT" },
        { kind = "check", field = "repTipSession", section = "tooltip", tab = "text", label = "REP_TIP_SESSION", tip = "TIP_REP_TIP_SESSION" },
    },
    tooltip = function(tt, cfg)
        local name, reaction, min, max, value = WatchedFaction()
        if not name then
            tt:AddLine(L.TT_NO_WATCHED, 0.8, 0.8, 0.8, true)
            return
        end
        local fmt = BreakUpLargeNumbers or tostring
        local hasRange = max and min and max > min
        if On(cfg, "repTipName") then tt:AddLine(name, 1, 1, 1) end
        if On(cfg, "repTipStanding") then
            WHITE(tt, StandingLabel(reaction), hasRange and ("%d / %d"):format(value - min, max - min) or "")
        end
        if cfg and cfg.repTipLeft and hasRange then WHITE(tt, L.TT_REP_LEFT, fmt(max - value)) end
        if cfg and cfg.repTipSession then
            local gain = RepGain()
            if gain and gain ~= 0 then WHITE(tt, L.TT_XP_SESSION, (gain > 0 and "+" or "-") .. fmt(math.abs(gain))) end
        end
    end,
    secureMacro = "/run if ToggleCharacter then ToggleCharacter('ReputationFrame') end",
    clickHintKey = "HINT_REPUTATION",
})

---------------------------------------------------------------------------
-- Tracked currencies (the ones shown on the backpack)
---------------------------------------------------------------------------
-- Up to 3 backpack currencies as { id, name, count, icon }.
-- (C_CurrencyInfo API)
local function TrackedCurrencies()
    local list = {}
    for i = 1, 3 do
        local name, count, icon, id
        if C_CurrencyInfo and C_CurrencyInfo.GetBackpackCurrencyInfo then
            local info = Try(C_CurrencyInfo.GetBackpackCurrencyInfo, i)
            if info then name, count, icon, id = info.name, info.quantity, info.iconFileID, info.currencyTypesID end
        end
        if name then table.insert(list, { id = id, name = name, count = count or 0, icon = icon }) end
    end
    return list
end

-- Every currency of the game's list (headers give the category), as the game lists them: the ones under
-- a closed header are not listed. { id, name, count, icon, category }
local function AllCurrencies()
    local list, category = {}, nil
    local CI = C_CurrencyInfo
    if not (CI and CI.GetCurrencyListSize and CI.GetCurrencyListInfo) then return list end
    for i = 1, Try(CI.GetCurrencyListSize) or 0 do
        local d = Try(CI.GetCurrencyListInfo, i)
        if d and d.isHeader then
            category = d.name
        elseif d and d.name and not d.isTypeUnused then
            local link = CI.GetCurrencyListLink and Try(CI.GetCurrencyListLink, i)
            local id = link and CI.GetCurrencyIDFromLink and Try(CI.GetCurrencyIDFromLink, link)
            table.insert(list, { id = id, name = d.name, count = d.quantity or 0, icon = d.iconFileID, category = category })
        end
    end
    return list
end

-- Cap and weekly figures of one currency: max (0 or nil: none), weekly gain and weekly maximum. The fields come
-- from the game; a missing one gives nil and nothing is shown for it.
local function CurrencyLimits(id)
    local d = id and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and Try(C_CurrencyInfo.GetCurrencyInfo, id)
    if type(d) ~= "table" then return nil end
    local max = d.maxQuantity
    if type(max) ~= "number" or max <= 0 then max = nil end
    local weeklyMax = d.maxWeeklyQuantity
    if type(weeklyMax) ~= "number" or weeklyMax <= 0 then weeklyMax = nil end
    return max, weeklyMax and d.quantityEarnedThisWeek or nil, weeklyMax
end

-- Gain of the session per currency: the count of each currency when first seen (session.curBase, by currency id).
-- A gain that arrives with the event is taken off the first count, so the first gain is not lost.
-- Reset session (Modules.lua) empties the table and calls ns.CurrencySnapshot.
local function CurrencySnapshot()
    session.curBase = session.curBase or {}
    for _, c in ipairs(TrackedCurrencies()) do
        if c.id and session.curBase[c.id] == nil then session.curBase[c.id] = c.count end
    end
    for _, c in ipairs(AllCurrencies()) do
        if c.id and session.curBase[c.id] == nil then session.curBase[c.id] = c.count end
    end
end
ns.CurrencySnapshot = CurrencySnapshot

local currencyTracker = CreateFrame("Frame")
currencyTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
currencyTracker:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
currencyTracker:SetScript("OnEvent", function(_, event, id, quantity, change)
    session.curBase = session.curBase or {}
    if event == "CURRENCY_DISPLAY_UPDATE" and type(id) == "number" and type(quantity) == "number"
        and session.curBase[id] == nil then
        session.curBase[id] = quantity - (type(change) == "number" and change or 0)
    end
    if event == "PLAYER_ENTERING_WORLD" then CurrencySnapshot() end
end)

-- Gain of this session for a currency id, or nil
local function CurrencyGain(id, count)
    local base = id and session.curBase and session.curBase[id]
    return base and (count - base) or nil
end

-- The currencies the block shows: "all" tracked, the 1st / 2nd / 3rd tracked, or one chosen currency ("c<id>")
local function ShownCurrencies(cfg)
    local shown = cfg and cfg.currencyShown
    local id = type(shown) == "string" and tonumber(shown:match("^c(%d+)$"))
    if id then
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and Try(C_CurrencyInfo.GetCurrencyInfo, id)
        if type(info) == "table" and info.name then
            return { { id = id, name = info.name, count = info.quantity or 0, icon = info.iconFileID } }
        end
        return {}
    end
    local list = TrackedCurrencies()
    local which = tonumber(shown)
    if which then list = { list[which] } end
    return list
end

local function FormatCount(n)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end

ns:RegisterModule("currency", {
    label = "CURRENCY",
    icon = "Interface\\Icons\\Wow_token02",
    events = { "CURRENCY_DISPLAY_UPDATE" },
    isEmpty = function(cfg) return #ShownCurrencies(cfg) == 0 end,
    update = function(cfg)
        local list = ShownCurrencies(cfg)
        if #list == 0 then return L.NONE end
        local size = cfg.fontSize or 12
        local parts, worst, capped = {}, nil, false
        for _, c in ipairs(list) do
            local icon = c.icon and ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(c.icon, size, size) or ""
            table.insert(parts, FormatCount(c.count) .. icon)
            -- the closest to its cap decides the color (percent of the cap)
            local max = CurrencyLimits(c.id)
            if max then
                local pct = Percent(c.count, max)
                if not worst or pct > worst then worst = pct end
                if c.count >= max then capped = true end
            end
        end
        local text = table.concat(parts, "  ")
        if capped then text = text .. " " .. L.CURRENCY_CAPPED end -- the word too, not only the color
        if worst then return text, Threshold(cfg, worst, THRESHOLDS.currency) end
        return text
    end,
    thresholds = THRESHOLDS.currency,
    -- extra click action (Shift / middle click list): gains start again from now
    extraAction = { key = "resetSession", label = "ACTION_RESET_SESSION", run = Tools.ResetSession },
    tooltip = function(tt, cfg)
        local tracked = TrackedCurrencies()
        local cap, showGain = cfg and cfg.currencyTipCap, cfg and cfg.currencyTipSession
        local function Line(c)
            local right = FormatCount(c.count)
            local max, weekly, weeklyMax = CurrencyLimits(c.id)
            if cap and max then right = right .. " / " .. FormatCount(max) end
            WHITE(tt, c.name, right)
            if cap and weeklyMax then
                tt:AddDoubleLine("   " .. L.TT_CURRENCY_WEEK, ("%s / %s"):format(FormatCount(weekly or 0), FormatCount(weeklyMax)),
                    0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
            end
            local gain = showGain and CurrencyGain(c.id, c.count)
            if gain and gain ~= 0 then
                tt:AddDoubleLine("   " .. L.TT_XP_SESSION, (gain > 0 and "+" or "-") .. FormatCount(math.abs(gain)),
                    0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
            end
        end
        local started = false
        if On(cfg, "currencyTipTracked") then
            if #tracked == 0 then tt:AddLine(L.TT_NO_CURRENCY, 0.8, 0.8, 0.8, true) end
            for _, c in ipairs(tracked) do Line(c) end
            started = true
        end
        -- the other currencies you own, under the game's category names
        if cfg and cfg.currencyTipOthers then
            local seen = {}
            for _, c in ipairs(tracked) do if c.id then seen[c.id] = true end end
            local category
            for _, c in ipairs(AllCurrencies()) do
                if c.count > 0 and not (c.id and seen[c.id]) then
                    if c.category ~= category then
                        category = c.category
                        if started then ns.TooltipGap(tt) end
                        if category then tt:AddLine(category, 1, 0.82, 0) end
                        started = true
                    end
                    Line(c)
                end
            end
        end
    end,
    defaults = { currencyShown = "all", currencyTipTracked = true, currencyTipOthers = false, currencyTipCap = false,
                 currencyTipSession = false },
    options = {
        { kind = "dropdown", field = "currencyShown", tab = "text", label = "CURRENCY_SHOWN", tip = "TIP_CURRENCY_SHOWN",
          values = function()
              local values = { { key = "all", label = "CURRENCY_ALL" }, { key = "1", label = "CURRENCY_1" },
                               { key = "2", label = "CURRENCY_2" }, { key = "3", label = "CURRENCY_3" } }
              for _, c in ipairs(AllCurrencies()) do
                  if c.id then table.insert(values, { key = "c" .. c.id, label = c.name }) end
              end
              return values
          end },
        { kind = "check", field = "currencyTipTracked", section = "tooltip", tab = "text", label = "CURRENCY_TIP_TRACKED", tip = "TIP_CURRENCY_TIP_TRACKED" },
        { kind = "check", field = "currencyTipOthers", section = "tooltip", tab = "text", label = "CURRENCY_TIP_OTHERS", tip = "TIP_CURRENCY_TIP_OTHERS" },
        { kind = "check", field = "currencyTipCap", section = "tooltip", tab = "text", label = "CURRENCY_TIP_CAP", tip = "TIP_CURRENCY_TIP_CAP" },
        { kind = "check", field = "currencyTipSession", section = "tooltip", tab = "text", label = "CURRENCY_TIP_SESSION", tip = "TIP_CURRENCY_TIP_SESSION" },
    },
    secureMacro = "/run if ToggleCharacter then ToggleCharacter('TokenFrame') end",
    clickHintKey = "HINT_CURRENCY",
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
    playerOnly = { UNIT_INVENTORY_CHANGED = true },
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

-- The same professions by skill line ID (GetProfessionInfo's 7th value): reliable on every
-- client, unlike names (on WoW Forever the First Aid spell name differs from the profession name)
local PROFESSION_SKILL_LINES = {
    [182] = { gathering = true },              -- Herbalism
    [186] = { gathering = true },              -- Mining
    [393] = { gathering = true },              -- Skinning
    [185] = { secondary = "cooking" },
    [129] = { secondary = "firstAid" },
    [356] = { secondary = "fishing", gathering = true },
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
                local name, icon, rank, max, _, _, skillLine = Try(GetProfessionInfo, indices[i])
                if name then
                    table.insert(list, { name = name, rank = rank or 0, max = max or 0, icon = icon,
                        skillLine = skillLine })
                end
            end
        end
    end
    if #list == 0 then list = SkillLines().professions end
    local result = { primary = {} }
    for _, p in ipairs(list) do
        local info = PROFESSION_SKILL_LINES[p.skillLine] or ProfessionInfo(p.name)
        if info then p.gathering = info.gathering end
        if info and info.secondary then
            result[info.secondary] = p
        else
            table.insert(result.primary, p)
        end
    end
    return result
end
local SKILL_FRAME_MACRO = "/run if ToggleCharacter then ToggleCharacter('SkillFrame') end"

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
            return (p and p.icon) or (info and info.icon) or "Interface\\Icons\\INV_Misc_Note_01"
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
            if p and not p.gathering then return "/cast " .. p.name end
            -- a gathering profession opens its own page: on WoW Forever the micro button
            -- shows the profession window on the last profession opened (Alchemy, for one)
            -- (a second click closes it, like the crafting professions' spell does)
            if p and p.skillLine and C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
                return ("/run local T,F=C_TradeSkillUI,ProfessionsFrame if F and F:IsShown() and "
                    .. "(T.GetBaseProfessionInfo and T.GetBaseProfessionInfo() or {}).professionID==%d "
                    .. "then HideUIPanel(F) else T.OpenTradeSkill(%d) end"):format(p.skillLine, p.skillLine)
            end
            return MicroButtonMacro("ProfessionMicroButton", SKILL_FRAME_MACRO)
        end,
        clickHintKey = "HINT_PROFESSION",
    })
end

---------------------------------------------------------------------------
-- Goal: progress towards an amount of gold or a level, chosen by the player
---------------------------------------------------------------------------
-- Item goals: up to GOAL_MAX_ITEMS items, cfg.goalItems = { { id =, count = }, ... }, the newest
-- last. The player adds them by dropping an item on the block or from a list of the bags: no
-- item number to type.
local GOAL_MAX_ITEMS = 3
ns.GOAL_MAX_ITEMS = GOAL_MAX_ITEMS
local GOAL_ICON = "Interface\\Icons\\INV_Misc_Gem_Pearl_04"

-- The list, converting the single item of the first 1.1.0 test builds (cfg.goalItem, never
-- published) on first read; a second read finds goalItems and changes nothing
local function GoalItems(cfg)
    if type(cfg.goalItems) ~= "table" then
        cfg.goalItems = {}
        local id = tonumber(cfg.goalItem)
        if id and id > 0 then
            cfg.goalItems[1] = { id = math.floor(id), count = math.max(1, math.floor(tonumber(cfg.goalValue) or 1)) }
        end
    end
    cfg.goalItem = nil
    return cfg.goalItems
end
ns.GoalItems = GoalItems

local function ItemName(id)
    return Try(C_Item and C_Item.GetItemNameByID, id) or ("#" .. id)
end
local function ItemIcon(id)
    return Try(C_Item and C_Item.GetItemIconByID, id) or GOAL_ICON
end
local function ItemCount(id)
    return tonumber((Try(C_Item and C_Item.GetItemCount, id))) or 0
end

-- A currency of the player's list: count, name and icon (nil when the game gives nothing)
local function CurrencyData(id)
    local d = id and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and Try(C_CurrencyInfo.GetCurrencyInfo, id)
    if type(d) ~= "table" then return nil end
    return d.quantity or 0, d.name, d.iconFileID
end

-- Returns progress (0..1), current value text, target text (gold, level and currency goals)
local function GoalProgress(cfg)
    local target = cfg.goalValue or 1000
    if cfg.goalType == "currency" then
        local quantity = CurrencyData(cfg.goalCurrency) or 0
        local fmt = BreakUpLargeNumbers or tostring
        return math.min(1, target > 0 and quantity / target or 1), fmt(quantity), fmt(target)
    end
    if cfg.goalType == "item" then
        -- the whole list: the share of items that reached their target
        local items, sum = GoalItems(cfg), 0
        for _, it in ipairs(items) do sum = sum + math.min(1, ItemCount(it.id) / math.max(1, it.count)) end
        return #items > 0 and sum / #items or 0
    end
    if cfg.goalType == "level" then
        local level = UnitLevel("player") or 1
        local max = UnitXPMax("player")
        local frac = (max and max > 0) and UnitXP("player") / max or 0
        local progress = target > 1 and (level - 1 + frac) / (target - 1) or 1
        return math.min(1, progress), tostring(level), tostring(target)
    end
    local gold = (GetMoney() or 0) / 10000
    return math.min(1, target > 0 and gold / target or 1), Masked(FormatGold(GetMoney() or 0, { goldFormat = "gold" })),
        FormatGold(target * 10000, { goldFormat = "gold" })
end

-- Time left to the goal at this session's pace (gold per hour, XP per hour), and whether it is a rough figure.
-- nil for items and currencies, or while the pace is unknown.
local function GoalEta(cfg)
    local hours = (GetTime() - session.gainStart) / 3600
    if hours < 1 / 60 then return nil end
    local target = cfg.goalValue or 1000
    if cfg.goalType == "level" then
        local level, max = UnitLevel("player") or 1, UnitXPMax("player") or 0
        if level >= target or max <= 0 or session.xpGained <= 0 then return nil end
        -- the levels after this one are counted as long as this one: a rough figure
        local left = (max - UnitXP("player")) + (target - level - 1) * max
        return left / (session.xpGained / hours) * 3600, target - level > 1
    end
    if cfg.goalType == "gold" then
        if ns:IsStreamer("gold") then return nil end
        local money = GetMoney() or 0
        local gain, left = money - (ns.sessionMoney or money), target * 10000 - money
        if gain <= 0 or left <= 0 then return nil end
        return left / (gain / hours) * 3600, false
    end
    return nil
end

-- Reached goal: the block flashes once, when it turns from short of the goal to reached (not at login)
local goalWasReached
local function GoalReached(cfg, progress)
    local done = progress >= 1
    if goalWasReached == false and done and cfg.alert and ns.alertsReady and ns:IsLocked() and ns.frames.goal then
        ns:Flash(ns.frames.goal)
    end
    goalWasReached = done
    return done
end

local function ItemText(it, withIcon)
    local text = ("%d / %d"):format(ItemCount(it.id), it.count)
    if withIcon then text = ("|T%s:0|t %s"):format(ItemIcon(it.id), text) end
    return text
end

-- Adds an item (or changes its target if it is already there); false when the list is full
function ns:AddGoalItem(key, id, count)
    local cfg = self.db.blocks[key]
    id, count = tonumber(id), tonumber(count)
    if not (cfg and id and count and id > 0 and count > 0) then return false end
    local items = GoalItems(cfg)
    id, count = math.floor(id), math.floor(count)
    for i, it in ipairs(items) do
        if it.id == id then
            table.remove(items, i)
            table.insert(items, { id = id, count = count })
            cfg.goalType = "item"
            self:UpdateBlock(key)
            return true
        end
    end
    if #items >= GOAL_MAX_ITEMS then
        self.Print(L.GOAL_FULL:format(GOAL_MAX_ITEMS))
        return false
    end
    table.insert(items, { id = id, count = count })
    cfg.goalType = "item"
    self:UpdateBlock(key)
    return true
end

function ns:RemoveGoalItem(key, id)
    local cfg = self.db.blocks[key]
    if not cfg then return end
    local items = GoalItems(cfg)
    for i, it in ipairs(items) do
        if it.id == id then table.remove(items, i); break end
    end
    self:UpdateBlock(key)
end

-- "How many?" box, then the item goes in the list
ns.OnLanguage(function()
    ns.Dialogs["TESSERA_GOAL_COUNT"] = {
        text = L.GOAL_HOW_MANY,
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(self, data)
            local box = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
            if box and data then box:SetText(tostring(data.count or 20)); box:HighlightText() end
        end,
        OnAccept = function(self, data)
            local box = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
            -- (no SetNumeric: the game shares these boxes with every popup, other addons' too)
            local count = box and tonumber((box:GetText():gsub("%s", "")))
            if data and count then ns:AddGoalItem(data.key, data.id, count) end
        end,
        EditBoxOnEnterPressed = function(self, data)
            local parent = self:GetParent()
            ns.Dialogs["TESSERA_GOAL_COUNT"].OnAccept(parent, data or parent.data)
            parent:Hide()
        end,
    }
end)
function ns:AskGoalCount(key, id, current)
    if not self.ShowDialog then return self:AddGoalItem(key, id, current or 20) end
    ns:ShowDialog("TESSERA_GOAL_COUNT", ItemName(id), nil, { key = key, id = id, count = current })
end

-- The items in the bags, once each, sorted by name (for "Add from my bags")
local function BagItems()
    local seen, list = {}, {}
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return list end
    for bag = 0, 4 do
        for slot = 1, tonumber((Try(C.GetContainerNumSlots, bag))) or 0 do
            local info = Try(C.GetContainerItemInfo, bag, slot)
            local id = type(info) == "table" and info.itemID
            if id and not seen[id] then
                seen[id] = true
                table.insert(list, { id = id, name = ItemName(id), icon = info.iconFileID or ItemIcon(id) })
            end
        end
    end
    table.sort(list, function(x, y) return x.name < y.name end)
    return list
end

-- The block's item entries, in a menu (its click and the quick menu)
function ns:FillGoalMenu(root, key)
    local cfg = self.db.blocks[key]
    if not cfg then return end
    local items = GoalItems(cfg)
    local add = root:CreateButton(L.GOAL_ADD_ITEM)
    if add.SetScrollMode then add:SetScrollMode(400) end
    local bag = BagItems()
    if #bag == 0 then add:CreateTitle(L.GOAL_BAGS_EMPTY) end
    for _, b in ipairs(bag) do
        add:CreateButton(("|T%s:0|t %s"):format(b.icon, b.name), function() self:AskGoalCount(key, b.id) end)
    end
    for _, it in ipairs(items) do
        local sub = root:CreateButton(("|T%s:0|t %s"):format(ItemIcon(it.id), ItemName(it.id)))
        sub:CreateButton(L.GOAL_CHANGE, function() self:AskGoalCount(key, it.id, it.count) end)
        sub:CreateButton(L.GOAL_REMOVE, function() self:RemoveGoalItem(key, it.id) end)
    end
end

ns:RegisterModule("goal", {
    label = "GOAL",
    icon = GOAL_ICON,
    defaultEnabled = false,
    defaults = { progressBar = true, goalType = "gold", goalValue = 1000, goalItemsShown = "last" },
    options = {
        { kind = "dropdown", field = "goalType", label = "GOAL_TYPE", tip = "TIP_GOAL_TYPE",
          values = { { key = "gold", label = "GOAL_GOLD" }, { key = "level", label = "GOAL_LEVEL" },
                     { key = "item", label = "GOAL_ITEM" }, { key = "currency", label = "GOAL_CURRENCY" } } },
        { kind = "dropdown", field = "goalCurrency", label = "GOAL_CURRENCY_CHOICE", tip = "TIP_GOAL_CURRENCY_CHOICE",
          values = function()
              local values = {}
              for _, c in ipairs(AllCurrencies()) do
                  if c.id then table.insert(values, { key = c.id, label = c.name }) end
              end
              return values
          end,
          shown = function(cfg) return cfg.goalType == "currency" end },
        { kind = "number", field = "goalValue", label = "GOAL_VALUE", tip = "TIP_GOAL_VALUE", min = 1,
          shown = function(cfg) return cfg.goalType ~= "item" end },
        { kind = "dropdown", field = "goalItemsShown", label = "GOAL_ITEMS_SHOWN", tip = "TIP_GOAL_ITEMS_SHOWN",
          values = { { key = "last", label = "GOAL_SHOWN_LAST" }, { key = "all", label = "GOAL_SHOWN_ALL" } },
          shown = function(cfg) return cfg.goalType == "item" end },
        -- how to add items, and how many: said in the box, not only in the tooltip
        { kind = "note", label = "GOAL_ITEMS_HOWTO", text = function() return L.GOAL_ITEMS_HOWTO:format(GOAL_MAX_ITEMS) end,
          shown = function(cfg) return cfg.goalType == "item" end },
    },
    extraAction = { key = "resetSession", label = "ACTION_RESET_SESSION", run = Tools.ResetSession },
    -- an item goal shows the newest item's icon, a currency goal the currency's
    getIcon = function(cfg)
        if cfg and cfg.goalType == "currency" then
            local _, _, icon = CurrencyData(cfg.goalCurrency)
            return icon or GOAL_ICON
        end
        if not (cfg and cfg.goalType == "item") then return GOAL_ICON end
        local items = GoalItems(cfg)
        return items[#items] and ItemIcon(items[#items].id) or GOAL_ICON
    end,
    events = { "PLAYER_MONEY", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "BAG_UPDATE_DELAYED", "CURRENCY_DISPLAY_UPDATE" },
    progress = function(cfg) return (GoalProgress(cfg)) end,
    update = function(cfg)
        local progress = GoalProgress(cfg)
        -- "Reached" in words too, not the color alone
        local done = GoalReached(cfg, progress)
        local suffix = done and (" " .. L.GOAL_REACHED) or ""
        if cfg.goalType == "item" then
            local items = GoalItems(cfg)
            if #items == 0 then return L.GOAL_NO_ITEM end
            if cfg.goalItemsShown == "all" then
                local parts = {}
                for _, it in ipairs(items) do table.insert(parts, ItemText(it, true)) end
                return table.concat(parts, "  ") .. suffix, done and GOOD or nil
            end
            return ItemText(items[#items], false) .. suffix, done and GOOD or nil
        end
        return ("%d%%"):format(math.floor(progress * 100)) .. suffix, done and GOOD or nil
    end,
    tooltip = function(tt, cfg)
        if cfg.goalType == "item" then
            local items = GoalItems(cfg)
            if #items == 0 then tt:AddLine(L.GOAL_NO_ITEM, 0.8, 0.8, 0.8) end
            for i = #items, 1, -1 do
                local it = items[i]
                local done = ItemCount(it.id) >= it.count
                tt:AddDoubleLine(("|T%s:0|t %s"):format(ItemIcon(it.id), ItemName(it.id)), ItemText(it, false),
                    1, 1, 1, done and 0.3 or 1, done and 1 or 1, done and 0.3 or 1)
            end
            if GoalProgress(cfg) >= 1 then tt:AddLine(L.GOAL_REACHED, 0.3, 1, 0.3) end
            -- how many items of the most it can follow
            tt:AddLine(L.TT_GOAL_ITEMS:format(#items, GOAL_MAX_ITEMS), 0.8, 0.8, 0.8)
            return
        end
        local progress, current, target = GoalProgress(cfg)
        if cfg.goalType == "currency" then
            local _, name = CurrencyData(cfg.goalCurrency)
            if name then tt:AddLine(name, 1, 1, 1) end
        end
        WHITE(tt, L.TT_GOAL_CURRENT, current)
        WHITE(tt, L.TT_GOAL_TARGET, target)
        WHITE(tt, L.TT_GOAL_PROGRESS, ("%d%%"):format(math.floor(progress * 100)))
        if progress >= 1 then
            tt:AddLine(L.GOAL_REACHED, 0.3, 1, 0.3)
            return
        end
        local eta, rough = GoalEta(cfg)
        if eta then WHITE(tt, L.TT_GOAL_ETA, (rough and "~" or "") .. FormatDuration(eta)) end
    end,
    -- click: the item menu (add from the bags, change, remove)
    onClick = function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle(ns:GetBlockName("goal"))
            ns:FillGoalMenu(root, "goal")
        end)
    end,
    -- an item dropped on the block (from the bags) is added
    onItemDrop = function(id) ns:AskGoalCount("goal", id) end,
    clickHintKey = "HINT_GOAL",
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
local GetItemIconFn = (C_Item and C_Item.GetItemIconByID) or function() end

-- Every reagent of every class once, for the "which reagents" check boxes (a box shows for its own class only)
local REAGENT_CLASS, REAGENT_IDS = {}, {}
for class, ids in pairs(REAGENTS) do
    for _, id in ipairs(ids) do
        if not REAGENT_CLASS[id] then
            REAGENT_CLASS[id] = {}
            table.insert(REAGENT_IDS, id)
        end
        REAGENT_CLASS[id][class] = true
    end
end
table.sort(REAGENT_IDS)

-- A reagent's name for its check box: the game's item name, asked for at login so it is known when the options open
local function ReagentName(id)
    return GetItemInfoFn(id) or ("#" .. id)
end
local reagentLoader = CreateFrame("Frame")
reagentLoader:RegisterEvent("PLAYER_LOGIN")
reagentLoader:SetScript("OnEvent", function()
    local _, class = UnitClass("player")
    for _, id in ipairs(REAGENTS[class] or {}) do
        if C_Item and C_Item.RequestLoadItemDataByID then Try(C_Item.RequestLoadItemDataByID, id) end
    end
end)

-- Reagents of the player's class to show: { id, count, icon }. The ones at zero only when asked for, a reagent
-- the player turned off never.
local function CarriedReagents(cfg)
    local _, class = UnitClass("player")
    local list = {}
    for _, id in ipairs(REAGENTS[class] or {}) do
        local count = GetItemCountFn and Try(GetItemCountFn, id) or 0
        if cfg and cfg["reagent" .. id] == false then
            count = nil
        elseif (count and count > 0) or (cfg and cfg.reagentsZero) then
            count = count or 0
        else
            count = nil
        end
        if count then
            table.insert(list, { id = id, count = count, icon = GetItemIconFn and Try(GetItemIconFn, id) })
        end
    end
    return list
end

local reagentDefaults, reagentOptions = { reagentsZero = false }, {
    { kind = "check", field = "reagentsZero", tab = "text", label = "REAGENTS_ZERO", tip = "TIP_REAGENTS_ZERO" },
}
for _, id in ipairs(REAGENT_IDS) do
    reagentDefaults["reagent" .. id] = true
    table.insert(reagentOptions, { kind = "check", field = "reagent" .. id, tab = "text", label = function() return ReagentName(id) end,
        tip = "TIP_REAGENT_ONE",
        shown = function() local _, class = UnitClass("player"); return REAGENT_CLASS[id][class] or false end })
end

ns:RegisterModule("reagents", {
    label = "REAGENTS",
    icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
    events = { "BAG_UPDATE_DELAYED" },
    isEmpty = function(cfg) return #CarriedReagents(cfg) == 0 end,
    defaults = reagentDefaults,
    options = reagentOptions,
    thresholds = THRESHOLDS.reagents,
    update = function(cfg)
        local list = CarriedReagents(cfg)
        if #list == 0 then return L.NONE end
        local size, parts, level = cfg.fontSize or 12, {}, GOOD
        for _, r in ipairs(list) do
            local icon = r.icon and ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(r.icon, size, size) or ""
            local text = r.count .. icon
            -- a reagent at zero is grayed out
            if r.count == 0 then text = "|cff808080" .. text .. "|r" end
            table.insert(parts, text)
            level = math.max(level, Threshold(cfg, r.count, THRESHOLDS.reagents))
        end
        return table.concat(parts, "  "), level
    end,
    tooltip = function(tt, cfg)
        local list = CarriedReagents(cfg)
        if #list == 0 then tt:AddLine(L.NONE, 0.8, 0.8, 0.8) end
        for _, r in ipairs(list) do
            local level = Threshold(cfg, r.count, THRESHOLDS.reagents)
            -- white, orange when low, red at the red level (the number keeps the same place: no color alone)
            local g, b = 1, 1
            if level == WARN then g, b = 0.6, 0.2 elseif level >= 3 then g, b = 0.3, 0.3 end
            tt:AddDoubleLine(ReagentName(r.id), tostring(r.count), 1, 1, 1, 1, g, b)
        end
    end,
})

---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Session: XP per hour and time to the next level; gold earned since you logged in
---------------------------------------------------------------------------
-- (the gains and the start of the count are the shared session: "Reset session" starts XP per hour again)
local recent, recentStart = {}, nil -- XP of the last 15 minutes: { time, session.xpGained } every 15 seconds
local RECENT_SECONDS = 900
local function RecentCheck()
    if recentStart ~= session.gainStart then
        for i = #recent, 1, -1 do recent[i] = nil end
        recentStart = session.gainStart
    end
end
C_Timer.NewTicker(15, function()
    RecentCheck()
    local now = GetTime()
    table.insert(recent, { now, session.xpGained })
    while #recent > 1 and now - recent[2][1] >= RECENT_SECONDS do table.remove(recent, 1) end
end)

local function XPElapsed()
    return GetTime() - session.gainStart
end
local function XPRate()
    local hours = XPElapsed() / 3600
    if hours < 1 / 60 or session.xpGained <= 0 then return 0 end
    return session.xpGained / hours
end
-- XP per hour over the last 15 minutes at most; nil until a minute of samples
local function XPRecentRate()
    RecentCheck()
    local first = recent[1]
    if not first or GetTime() - first[1] < 60 then return nil end
    return (session.xpGained - first[2]) / ((GetTime() - first[1]) / 3600)
end

ns:RegisterModule("xpRate", {
    label = "XP_RATE",
    icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    events = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP" },
    interval = 15,
    defaultEnabled = false,
    isEmpty = function() return AtMaxLevel() end,
    update = function(cfg)
        if AtMaxLevel() then return L.NA end
        local rate = XPRate()
        local fmt = BreakUpLargeNumbers or tostring
        local rateText = L.XP_RATE_FORMAT:format(rate > 0 and fmt(math.floor(rate)) or "0")
        if rate <= 0 then return rateText end
        local shown = cfg and cfg.xpRateShown
        local left = ShortDuration((UnitXPMax("player") - UnitXP("player")) / rate * 3600)
        if shown == "time" then return left end
        if shown == "both" then return rateText .. "  " .. left end
        return rateText
    end,
    defaults = { xpRateShown = "rate", xpTipTime = true, xpTipGained = true, xpTipRate = true, xpTipRecent = true,
                 xpTipLeft = true },
    options = {
        { kind = "dropdown", field = "xpRateShown", tab = "text", label = "XP_RATE_SHOWN", tip = "TIP_XP_RATE_SHOWN",
          values = { { key = "rate", label = "XP_RATE_PER_HOUR" }, { key = "time", label = "XP_RATE_TIME" },
                     { key = "both", label = "XP_RATE_BOTH" } } },
        { kind = "check", field = "xpTipTime", section = "tooltip", tab = "text", label = "XP_TIP_TIME", tip = "TIP_XP_TIP_TIME" },
        { kind = "check", field = "xpTipGained", section = "tooltip", tab = "text", label = "XP_TIP_GAINED", tip = "TIP_XP_TIP_GAINED" },
        { kind = "check", field = "xpTipRate", section = "tooltip", tab = "text", label = "XP_TIP_PACE", tip = "TIP_XP_TIP_PACE" },
        { kind = "check", field = "xpTipRecent", section = "tooltip", tab = "text", label = "XP_TIP_RECENT", tip = "TIP_XP_TIP_RECENT" },
        { kind = "check", field = "xpTipLeft", section = "tooltip", tab = "text", label = "XP_TIP_LEFT", tip = "TIP_XP_TIP_LEFT" },
    },
    extraAction = { key = "resetSession", label = "ACTION_RESET_SESSION", run = Tools.ResetSession },
    tooltip = function(tt, cfg)
        local rate = XPRate()
        local fmt = BreakUpLargeNumbers or tostring
        if On(cfg, "xpTipTime") then WHITE(tt, L.TT_SESSION_TIME, FormatDuration(XPElapsed())) end
        if On(cfg, "xpTipGained") then WHITE(tt, L.TT_XP_GAINED, fmt(session.xpGained)) end
        if On(cfg, "xpTipRate") then WHITE(tt, L.XP_RATE_PER_HOUR, fmt(math.floor(rate))) end
        if On(cfg, "xpTipRecent") then
            local r = XPRecentRate()
            if r then WHITE(tt, L.TT_XP_RECENT, fmt(math.floor(r))) end
        end
        if On(cfg, "xpTipLeft") and rate > 0 and not AtMaxLevel() then
            WHITE(tt, L.TT_XP_LEVEL_IN, FormatDuration((UnitXPMax("player") - UnitXP("player")) / rate * 3600))
        end
    end,
})

-- the money at login is recorded by Core.lua (ns.sessionMoney)
local function MoneyChange()
    local now = Try(GetMoney) or 0
    return now - (ns.sessionMoney or now)
end

ns:RegisterModule("goldSession", {
    label = "GOLD_SESSION",
    icon = "Interface\\Icons\\INV_Misc_Coin_02",
    events = { "PLAYER_MONEY", "PLAYER_ENTERING_WORLD" },
    defaultEnabled = false,
    update = function(cfg)
        local change = MoneyChange()
        if ns:IsStreamer("gold") then return ns.HIDDEN end
        local text = ns.FormatMoney(math.abs(change), cfg and cfg.fontSize)
        if change < 0 then return "-" .. text, WARN end
        return (change > 0 and "+" or "") .. text, change > 0 and GOOD or nil
    end,
    tooltip = function(tt)
        local change = MoneyChange()
        WHITE(tt, L.TT_SESSION_TIME, FormatDuration(XPElapsed()))
        if ns:IsStreamer("gold") then
            WHITE(tt, L.GOLD_SESSION, ns.HIDDEN)
            return
        end
        WHITE(tt, change < 0 and L.TT_GOLD_LOST or L.TT_GOLD_EARNED, ns.FormatMoney(math.abs(change)))
        local hours = XPElapsed() / 3600
        if hours >= 1 / 60 and change > 0 then WHITE(tt, L.TT_GOLD_PER_HOUR, ns.FormatMoney(math.floor(change / hours))) end
    end,
})

-- Sample values for the demo and the preview mode
local SAMPLES = {
    quests      = function() return "12 / 25", GOOD end,
    reputation  = function() return (_G.FACTION_STANDING_LABEL6 or "Honored") .. " 64%" end,
    ammo        = function() return "842", GOOD end,
    goal        = function() return "65%" end,
    currency     = function(cfg)
        local size = cfg.fontSize or 12
        return ("250|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format("Interface\\Icons\\INV_Misc_Coin_01", size, size)
    end,
    reagents     = function(cfg)
        local size = cfg.fontSize or 12
        return ("18|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format("Interface\\Icons\\INV_Misc_Gem_Amethyst_02", size, size)
    end,
    profession1  = function() return L.SAMPLE_PROFESSION .. " 215 / 225" end,
    cooking      = function() return "150 / 150", GOOD end,
    xpRate       = function() return L.XP_RATE_FORMAT:format("18 450") end,
    goldSession  = function() return "+" .. ns.FormatMoney(1234567), GOOD end,
}
for key, sample in pairs(SAMPLES) do
    if ns.modules[key] then ns.modules[key].sample = sample end
end
