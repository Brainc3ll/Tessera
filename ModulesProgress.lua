local _, ns = ...
local L = ns.L

-- Blocks about progress: reputation, currencies, quests, goal, professions, ammo, session gains.
-- Shared tools come from Modules.lua (ns.BlockTools); see its header for how to add a block.
local Tools = ns.BlockTools
local AtMaxLevel, BAD, FormatDuration, FormatGold = Tools.AtMaxLevel, Tools.BAD, Tools.FormatDuration, Tools.FormatGold
local GOOD, GetItemCountFn = Tools.GOOD, Tools.GetItemCountFn
local GetItemInfoFn, MAX_LINES, Masked, MicroButtonMacro = Tools.GetItemInfoFn, Tools.MAX_LINES, Tools.Masked, Tools.MicroButtonMacro
local Percent, ShortDuration = Tools.Percent, Tools.ShortDuration
local SkillLines, SkillTooltip, THRESHOLDS, Threshold = Tools.SkillLines, Tools.SkillTooltip, Tools.THRESHOLDS, Tools.Threshold
local Try, WARN = Tools.Try, Tools.WARN
local WHITE = Tools.WHITE

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
    update = function(cfg)
        local list = QuestList()
        local count, max = #list, MaxQuests()
        local level = count >= max and BAD or (count >= max - 2 and WARN or GOOD)
        local mode = cfg and cfg.questsFormat or "countMax"
        if mode == "count" then return tostring(count), level end
        if mode == "complete" then
            local done = 0
            for _, q in ipairs(list) do if q.complete then done = done + 1 end end
            return ("%d / %d"):format(done, count), done > 0 and GOOD or nil
        end
        return ("%d / %d"):format(count, max), level
    end,
    defaults = { questsFormat = "countMax" },
    options = {
        { kind = "dropdown", field = "questsFormat", tab = "text", label = "QUESTS_SHOWN", tip = "TIP_QUESTS_SHOWN",
          values = { { key = "countMax", label = "QUESTS_COUNT_MAX" }, { key = "count", label = "QUESTS_COUNT" },
                     { key = "complete", label = "QUESTS_COMPLETE" } } },
    },
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
        local which = tonumber(cfg.currencyShown)
        if which then list = { list[which] } end
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
    defaults = { currencyShown = "all" },
    options = {
        { kind = "dropdown", field = "currencyShown", tab = "text", label = "CURRENCY_SHOWN", tip = "TIP_CURRENCY_SHOWN",
          values = { { key = "all", label = "CURRENCY_ALL" }, { key = "1", label = "CURRENCY_1" },
                     { key = "2", label = "CURRENCY_2" }, { key = "3", label = "CURRENCY_3" } } },
    },
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
        clickHint = L.HINT_PROFESSION,
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

-- Returns progress (0..1), current value text, target text (gold and level goals)
local function GoalProgress(cfg)
    local target = cfg.goalValue or 1000
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
StaticPopupDialogs["TESSERA_GOAL_COUNT"] = {
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
        StaticPopupDialogs["TESSERA_GOAL_COUNT"].OnAccept(parent, data or parent.data)
        parent:Hide()
    end,
}
function ns:AskGoalCount(key, id, current)
    if not StaticPopup_Show then return self:AddGoalItem(key, id, current or 20) end
    StaticPopup_Show("TESSERA_GOAL_COUNT", ItemName(id), nil, { key = key, id = id, count = current })
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
                     { key = "item", label = "GOAL_ITEM" } } },
        { kind = "number", field = "goalValue", label = "GOAL_VALUE", tip = "TIP_GOAL_VALUE", min = 1,
          shown = function(cfg) return cfg.goalType ~= "item" end },
        { kind = "dropdown", field = "goalItemsShown", label = "GOAL_ITEMS_SHOWN", tip = "TIP_GOAL_ITEMS_SHOWN",
          values = { { key = "last", label = "GOAL_SHOWN_LAST" }, { key = "all", label = "GOAL_SHOWN_ALL" } },
          shown = function(cfg) return cfg.goalType == "item" end },
    },
    -- an item goal shows the newest item's icon
    getIcon = function(cfg)
        if not (cfg and cfg.goalType == "item") then return GOAL_ICON end
        local items = GoalItems(cfg)
        return items[#items] and ItemIcon(items[#items].id) or GOAL_ICON
    end,
    events = { "PLAYER_MONEY", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "BAG_UPDATE_DELAYED" },
    progress = function(cfg) return (GoalProgress(cfg)) end,
    update = function(cfg)
        local progress = GoalProgress(cfg)
        if cfg.goalType == "item" then
            local items = GoalItems(cfg)
            if #items == 0 then return L.GOAL_NO_ITEM end
            if cfg.goalItemsShown == "all" then
                local parts = {}
                for _, it in ipairs(items) do table.insert(parts, ItemText(it, true)) end
                return table.concat(parts, "  "), progress >= 1 and GOOD or nil
            end
            return ItemText(items[#items], false), progress >= 1 and GOOD or nil
        end
        return ("%d%%"):format(math.floor(progress * 100)), progress >= 1 and GOOD or nil
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
            return
        end
        local progress, current, target = GoalProgress(cfg)
        WHITE(tt, L.TT_GOAL_CURRENT, current)
        WHITE(tt, L.TT_GOAL_TARGET, target)
        WHITE(tt, L.TT_GOAL_PROGRESS, ("%d%%"):format(math.floor(progress * 100)))
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
    clickHint = L.HINT_GOAL,
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
---------------------------------------------------------------------------
-- Session: XP per hour and time to the next level; gold earned since you logged in
---------------------------------------------------------------------------
local xpSession = { start = GetTime(), gained = 0, lastXP = nil, lastMax = nil, lastLevel = nil }
local function TrackXP()
    local xp, max, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    local s = xpSession
    if s.lastXP then
        if level > s.lastLevel then
            s.gained = s.gained + (s.lastMax - s.lastXP) + xp
        elseif xp > s.lastXP then
            s.gained = s.gained + (xp - s.lastXP)
        end
    end
    s.lastXP, s.lastMax, s.lastLevel = xp, max, level
end
local function XPRate()
    TrackXP()
    local hours = (GetTime() - xpSession.start) / 3600
    if hours < 1 / 60 or xpSession.gained <= 0 then return 0 end
    return xpSession.gained / hours
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
        if rate <= 0 then return L.XP_RATE_FORMAT:format("0") end
        if cfg and cfg.xpRateShown == "time" then
            return ShortDuration((UnitXPMax("player") - UnitXP("player")) / rate * 3600)
        end
        return L.XP_RATE_FORMAT:format(fmt(math.floor(rate)))
    end,
    defaults = { xpRateShown = "rate" },
    options = {
        { kind = "dropdown", field = "xpRateShown", tab = "text", label = "XP_RATE_SHOWN", tip = "TIP_XP_RATE_SHOWN",
          values = { { key = "rate", label = "XP_RATE_PER_HOUR" }, { key = "time", label = "XP_RATE_TIME" } } },
    },
    tooltip = function(tt)
        local rate = XPRate()
        local fmt = BreakUpLargeNumbers or tostring
        WHITE(tt, L.TT_SESSION_TIME, FormatDuration(GetTime() - xpSession.start))
        WHITE(tt, L.TT_XP_GAINED, fmt(xpSession.gained))
        WHITE(tt, L.XP_RATE_PER_HOUR, fmt(math.floor(rate)))
        if rate > 0 and not AtMaxLevel() then
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
        if ns:IsStreamer() then return ns.HIDDEN end
        local text = ns.FormatMoney(math.abs(change), cfg and cfg.fontSize)
        if change < 0 then return "-" .. text, WARN end
        return (change > 0 and "+" or "") .. text, change > 0 and GOOD or nil
    end,
    tooltip = function(tt)
        local change = MoneyChange()
        WHITE(tt, L.TT_SESSION_TIME, FormatDuration(GetTime() - xpSession.start))
        if ns:IsStreamer() then
            WHITE(tt, L.GOLD_SESSION, ns.HIDDEN)
            return
        end
        WHITE(tt, change < 0 and L.TT_GOLD_LOST or L.TT_GOLD_EARNED, ns.FormatMoney(math.abs(change)))
        local hours = (GetTime() - xpSession.start) / 3600
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
