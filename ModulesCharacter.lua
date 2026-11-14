local _, ns = ...
local L = ns.L

-- Blocks about your character: gold, bags, durability, experience, stats, pet, buffs.
-- Shared tools come from Modules.lua (ns.BlockTools); see its header for how to add a block.
local Tools = ns.BlockTools
local AtMaxLevel, BAD, COIN_ICONS, ClassColor = Tools.AtMaxLevel, Tools.BAD, Tools.COIN_ICONS, Tools.ClassColor
local FormatDuration, FormatGold = Tools.FormatDuration, Tools.FormatGold
local GOOD, GetItemInfoFn, LevelColor, MicroButtonMacro = Tools.GOOD, Tools.GetItemInfoFn, Tools.LevelColor, Tools.MicroButtonMacro
local Percent, ShortTime = Tools.Percent, Tools.ShortTime
local THRESHOLDS, Threshold, Try, WARN = Tools.THRESHOLDS, Tools.Threshold, Tools.Try, Tools.WARN
local WHITE, session = Tools.WHITE, Tools.session

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
        if ns:IsStreamer() then return ns.HIDDEN end
        return FormatGold(GetMoney() or 0, cfg)
    end,
    -- Shift + click "copy to chat": plain text, without coin textures
    chatText = function()
        if ns:IsStreamer() then return ns.HIDDEN end
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
        if ns:IsStreamer() then
            tt:AddLine(L.STREAMER_TOOLTIP, 0.8, 0.8, 0.8, true)
            return
        end
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
            tt:AddLine(" ")
            tt:AddLine(L.TT_CHARACTERS, 1, 0.82, 0)
            for _, c in ipairs(chars) do
                local r, g, b = ClassColor(c.class)
                tt:AddDoubleLine(ns.ShortCharName(c.name), ns.FormatMoney(c.money), r, g, b, 1, 1, 1)
            end
            tt:AddDoubleLine(L.TT_TOTAL, ns.FormatMoney(total), 1, 0.82, 0, 1, 1, 1)
            tt:AddLine(L.GOLD_FORGET_HINT, 0.6, 0.6, 0.6)
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

-- Free and total slots of the bags that hold anything: a profession bag (herbs, soul
-- shards, reagents...) only takes its own items, so its free slots do not count
-- (GetContainerNumFreeSlots' second value is the bag family: 0 = any item)
local function GeneralBagSlots()
    local free, total = 0, 0
    for bag = 0, LastBag() do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        if slots > 0 then
            local bagFree, family = C_Container.GetContainerNumFreeSlots(bag)
            if not family or family == 0 then
                total = total + slots
                free = free + (bagFree or 0)
            end
        end
    end
    return free, total
end

ns:RegisterModule("bags", {
    label = "BAGS",
    icon = "Interface\\Icons\\INV_Misc_Bag_08",
    events = { "BAG_UPDATE_DELAYED" },
    update = function(cfg)
        local free, total = GeneralBagSlots()
        local level = Threshold(cfg, free, THRESHOLDS.bags)
        local mode = cfg and cfg.bagsFormat or "freeTotal"
        if mode == "free" then return tostring(free), level end
        if mode == "usedTotal" then return L.BAGS_FORMAT:format(total - free, total), level end
        return L.BAGS_FORMAT:format(free, total), level
    end,
    defaults = { bagsFormat = "usedTotal" }, -- new profiles; saved profiles keep their choice
    options = {
        { kind = "dropdown", field = "bagsFormat", tab = "text", label = "BAGS_SHOWN", tip = "TIP_BAGS_SHOWN",
          values = { { key = "freeTotal", label = "BAGS_FREE_TOTAL" }, { key = "free", label = "BAGS_FREE" },
                     { key = "usedTotal", label = "BAGS_USED_TOTAL" } } },
    },
    thresholds = THRESHOLDS.bags,
    -- progress bar: how full the bags are
    progress = function()
        local free, total = GeneralBagSlots()
        return total > 0 and (total - free) / total or 0
    end,
    tooltip = function(tt)
        local junk = 0
        local special = {} -- profession bags: listed apart, after the bags that take anything
        for bag = 0, LastBag() do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            if slots > 0 then
                local free, family = C_Container.GetContainerNumFreeSlots(bag)
                free = free or 0
                local name = C_Container.GetBagName and C_Container.GetBagName(bag)
                name = name or (bag == 0 and L.TT_BACKPACK or L.TT_BAG:format(bag))
                if family and family ~= 0 then
                    table.insert(special, { name = name, text = L.BAGS_FORMAT:format(free, slots) })
                else
                    tt:AddDoubleLine(name, L.BAGS_FORMAT:format(free, slots), 1, 1, 1, 1, 1, 1)
                end
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
        if #special > 0 then
            tt:AddLine(" ")
            tt:AddLine(L.TT_PROFESSION_BAGS, 0.4, 0.8, 1)
            for _, b in ipairs(special) do tt:AddDoubleLine(b.name, b.text, 0.4, 0.8, 1, 0.4, 0.8, 1) end
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
        -- items with durability carried in the bags, under their own title
        local getDurability = C_Container and C_Container.GetContainerItemDurability
        if getDurability then
            local title = false
            for bag = 0, LastBag() do
                local okS, slots = pcall(C_Container.GetContainerNumSlots, bag)
                for slot = 1, (okS and tonumber(slots)) or 0 do
                    local okD, cur, max = pcall(getDurability, bag, slot)
                    if not okD then cur, max = nil, nil end
                    if type(cur) == "number" and type(max) == "number" and max > 0 then
                        if not title then
                            tt:AddLine(" ")
                            tt:AddLine(L.TT_IN_BAGS, 1, 0.82, 0)
                            title = true
                        end
                        local pct = Percent(cur, max)
                        local okI, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                        if not okI then info = nil end
                        local link = type(info) == "table" and info.hyperlink or "?"
                        tt:AddDoubleLine(link, LevelColor(DurabilityLevel(pct, cfg)) .. ("%d%%"):format(math.floor(pct + 0.5)) .. "|r")
                    end
                end
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
    update = function(cfg)
        local current, run = Try(GetUnitSpeed, "player")
        if not current then return nil end
        -- pcall: the speed can be a "secret" value on Midnight-era clients; comparing it errors
        local ok, text = pcall(function()
            local speed = current > 0 and current or run
            if cfg and cfg.speedUnit == "meters" then return L.SPEED_METERS_FORMAT:format(speed * 0.9144) end
            return ("%d%%"):format(SpeedPercent(speed))
        end)
        return ok and text or nil
    end,
    defaults = { speedUnit = "percent" },
    options = {
        { kind = "dropdown", field = "speedUnit", tab = "text", label = "SPEED_SHOWN", tip = "TIP_SPEED_SHOWN",
          values = { { key = "percent", label = "SPEED_PERCENT" }, { key = "meters", label = "SPEED_METERS" } } },
    },
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
    defaults = { stat = "auto" }, -- (a default also lets an imported profile keep the choice)
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
-- Unspent talent points (shows only when some are left)
---------------------------------------------------------------------------
-- UnitCharacterPoints on classic clients; WoW Forever uses the modern talent trees
-- (C_ClassTalents / C_Traits): the points left are the currencies of the active tree
local function FreeTalentPoints()
    local classic = _G["UnitCharacterPoints"]
    if classic then return Try(classic, "player") or 0 end
    local CT, T = C_ClassTalents, C_Traits
    if not (CT and T and CT.GetActiveConfigID and T.GetConfigInfo and T.GetTreeCurrencyInfo) then return 0 end
    local configID = Try(CT.GetActiveConfigID)
    local info = configID and Try(T.GetConfigInfo, configID)
    local treeID = type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1]
    local currencies = treeID and Try(T.GetTreeCurrencyInfo, configID, treeID, false)
    local points = 0
    for _, c in ipairs(type(currencies) == "table" and currencies or {}) do
        points = points + (tonumber(c.quantity) or 0)
    end
    if points == 0 and CT.HasUnspentTalentPoints and Try(CT.HasUnspentTalentPoints) then points = 1 end
    return points
end

ns:RegisterModule("talents", {
    label = "TALENTS",
    icon = "Interface\\Icons\\Ability_Marksmanship",
    events = { "CHARACTER_POINTS_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
               "TRAIT_TREE_CURRENCY_INFO_UPDATED" },
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
    update = function(cfg)
        if cfg and cfg.restedFormat == "bubbles" then
            return L.BUBBLES_FORMAT:format(RestedPercent() / 5)
        end
        return ("%d%%"):format(math.floor(RestedPercent() + 0.5))
    end,
    defaults = { restedFormat = "percent" },
    options = {
        { kind = "dropdown", field = "restedFormat", tab = "text", label = "RESTED_SHOWN", tip = "TIP_RESTED_SHOWN",
          values = { { key = "percent", label = "RESTED_PERCENT" }, { key = "bubbles", label = "RESTED_BUBBLES" } } },
    },
    progress = function() return math.min(1, RestedPercent() / 150) end, -- rested XP caps at 150 %
    tooltip = function(tt)
        local fmt = BreakUpLargeNumbers or tostring
        tt:AddDoubleLine(L.TT_XP_RESTED, fmt(GetXPExhaustion() or 0), 1, 1, 1, 0.3, 0.65, 1)
        tt:AddLine(IsResting() and L.TT_RESTING or L.TT_NOT_RESTING, 0.8, 0.8, 0.8)
    end,
})

---------------------------------------------------------------------------
-- Sample values for the preview mode (/tessera preview): used for screenshots,
-- they show what each block looks like with typical values. Blocks without a
-- sample keep showing their real value.
-- One reading per moment: a block asks for the same list for "hide when empty", its icon,
-- its text and its tooltip within one refresh; the list is read once and reused
local function PerMoment(read)
    local at, value
    return function()
        local now = GetTime()
        if at ~= now then at, value = now, read() end
        return value
    end
end

---------------------------------------------------------------------------
-- Hunter pet: happiness (Mad / Neutral / Happy, the game's own names) and loyalty
---------------------------------------------------------------------------
local PET_COLORS = { [1] = BAD, [2] = WARN, [3] = GOOD }
local function PetHappiness()
    local P = C_PetInfo
    local _, isHunterPet = Try(HasPetUI)
    if not (isHunterPet and P and P.GetPetHappiness) then return nil end
    local happiness, damage, loyaltyRate = Try(P.GetPetHappiness)
    if not PET_COLORS[happiness] then return nil end
    return happiness, damage, loyaltyRate
end

if C_PetInfo and C_PetInfo.GetPetHappiness then
ns:RegisterModule("pet", {
    label = "PET",
    icon = "Interface\\Icons\\Ability_Hunter_BeastTaming",
    events = { "UNIT_HAPPINESS", "UNIT_PET", "PET_UI_UPDATE" },
    interval = 10,
    defaultEnabled = false,
    isEmpty = function() return PetHappiness() == nil end,
    update = function()
        local happiness = PetHappiness()
        if not happiness then return L.NONE end
        return _G["PET_HAPPINESS" .. happiness] or tostring(happiness), PET_COLORS[happiness]
    end,
    tooltip = function(tt)
        local happiness, damage, loyaltyRate = PetHappiness()
        if not happiness then
            tt:AddLine(L.TT_NO_PET, 0.8, 0.8, 0.8, true)
            return
        end
        WHITE(tt, Try(UnitName, "pet") or L.PET, _G["PET_HAPPINESS" .. happiness] or "")
        if type(damage) == "number" then WHITE(tt, L.TT_PET_DAMAGE, ("%d%%"):format(damage)) end
        local loyalty = C_PetInfo.GetPetLoyalty and Try(C_PetInfo.GetPetLoyalty)
        if type(loyalty) == "string" and loyalty ~= "" then WHITE(tt, L.TT_PET_LOYALTY, loyalty) end
        if type(loyaltyRate) == "number" and loyaltyRate < 0 then
            tt:AddLine(L.TT_PET_LOSING_LOYALTY, 1, 0.6, 0.2, true)
        end
    end,
})
end

---------------------------------------------------------------------------
-- Temporary weapon enchant (poisons, sharpening stones, shaman imbues): time left
---------------------------------------------------------------------------
local WEAPON_SLOT_NAMES = { [0] = "TT_MAIN_HAND", [1] = "TT_OFF_HAND", [2] = "TT_RANGED" }
local function ReadWeaponEnchants()
    local list = {}
    local get = C_Item and C_Item.GetWeaponEnchantInfo
    if not get then return list end
    for slot = 0, 2 do
        local enchants = Try(get, slot)
        for _, e in ipairs(type(enchants) == "table" and enchants or {}) do
            if type(e) == "table" and e.hasEnchant then
                table.insert(list, { slot = slot, left = (tonumber(e.timeLeft) or 0) / 1000,
                                     charges = tonumber(e.charges) or 0 })
            end
        end
    end
    return list
end
local AllWeaponEnchants = PerMoment(ReadWeaponEnchants)
-- option "weaponSlots": both (every weapon, the ranged one too), main hand or off hand only
local function WeaponEnchants(cfg)
    local all, only = AllWeaponEnchants(), cfg and cfg.weaponSlots
    if only ~= "main" and only ~= "off" then return all end
    local slot, list = only == "main" and 0 or 1, {}
    for _, e in ipairs(all) do if e.slot == slot then table.insert(list, e) end end
    return list
end

if C_Item and C_Item.GetWeaponEnchantInfo then
ns:RegisterModule("weaponEnchant", {
    label = "WEAPON_ENCHANT",
    icon = "Interface\\Icons\\INV_Stone_SharpeningStone_01",
    events = { "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED" },
    playerOnly = { UNIT_INVENTORY_CHANGED = true },
    interval = 5,
    defaultEnabled = false,
    defaults = { weaponSlots = "both" },
    options = {
        { kind = "dropdown", field = "weaponSlots", label = "WEAPON_SLOTS", tip = "TIP_WEAPON_SLOTS",
          values = { { key = "both", label = "WEAPON_SLOTS_BOTH" }, { key = "main", label = "TT_MAIN_HAND" },
                     { key = "off", label = "TT_OFF_HAND" } } },
    },
    isEmpty = function(cfg) return #WeaponEnchants(cfg) == 0 end,
    update = function(cfg)
        local list = WeaponEnchants(cfg)
        if #list == 0 then return L.NONE, WARN end
        local shortest = list[1]
        for _, e in ipairs(list) do if e.left < shortest.left then shortest = e end end
        return ShortTime(shortest.left), shortest.left < 300 and WARN or GOOD
    end,
    tooltip = function(tt, cfg)
        local list = WeaponEnchants(cfg)
        if #list == 0 then tt:AddLine(L.TT_NO_WEAPON_ENCHANT, 0.8, 0.8, 0.8, true) end
        for _, e in ipairs(list) do
            local right = ShortTime(e.left)
            if e.charges > 0 then right = right .. "  " .. L.TT_CHARGES:format(e.charges) end
            WHITE(tt, L[WEAPON_SLOT_NAMES[e.slot]], right)
        end
    end,
})
end

---------------------------------------------------------------------------
-- Long buffs (Well Fed, elixirs, world buffs...): buffs of 10 minutes or more, the
-- shortest time left. Aura data can be "secret" in combat: each read is protected.
---------------------------------------------------------------------------
local LONG_BUFF = 600
local function ReadLongBuffs()
    local list, UA = {}, C_UnitAuras
    if not (UA and UA.GetBuffDataByIndex) then return list end
    local now = GetTime()
    for i = 1, 40 do
        local aura = Try(UA.GetBuffDataByIndex, "player", i)
        if type(aura) ~= "table" then break end
        local ok, entry = pcall(function()
            if aura.duration and aura.duration >= LONG_BUFF and aura.expirationTime and aura.expirationTime > 0 then
                return { name = aura.name, icon = aura.icon, left = aura.expirationTime - now }
            end
        end)
        if ok and entry then table.insert(list, entry) end
    end
    table.sort(list, function(a, b) return a.left < b.left end)
    return list
end
local LongBuffs = PerMoment(ReadLongBuffs)

ns:RegisterModule("longBuffs", {
    label = "LONG_BUFFS",
    icon = "Interface\\Icons\\INV_Misc_Food_15",
    getIcon = function()
        local first = LongBuffs()[1]
        return first and first.icon or "Interface\\Icons\\INV_Misc_Food_15"
    end,
    interval = 5, -- (not UNIT_AURA: it fires for every unit around you, and these buffs last 10 minutes or more)
    defaultEnabled = false,
    isEmpty = function() return #LongBuffs() == 0 end,
    update = function()
        local list = LongBuffs()
        if #list == 0 then return L.NONE, WARN end
        local first = list[1]
        local text = ShortTime(first.left)
        if #list > 1 then text = L.LONG_BUFFS_FORMAT:format(#list, text) end
        return text, first.left < 300 and WARN or GOOD
    end,
    tooltip = function(tt)
        local list = LongBuffs()
        if #list == 0 then tt:AddLine(L.TT_NO_LONG_BUFF, 0.8, 0.8, 0.8, true) end
        for _, b in ipairs(list) do
            local icon = b.icon and ("|T%s:14:14:0:0:64:64:5:59:5:59|t "):format(b.icon) or ""
            WHITE(tt, icon .. tostring(b.name or "?"), ShortTime(b.left))
        end
    end,
})

---------------------------------------------------------------------------
-- Corpse: while you are a ghost, the distance and direction to your body
---------------------------------------------------------------------------
-- the direction is the block's icon, turned (the game's fonts have no arrow characters)
local CORPSE_ARROW = "Interface\\Minimap\\MinimapArrow"
local function CorpseInfo()
    if not (UnitIsGhost and Try(UnitIsGhost, "player")) then return nil end
    local M, D = C_Map, C_DeathInfo
    local mapID = M and M.GetBestMapForUnit and Try(M.GetBestMapForUnit, "player")
    local corpse = mapID and D and D.GetCorpseMapPosition and Try(D.GetCorpseMapPosition, mapID)
    local me = mapID and M.GetPlayerMapPosition and Try(M.GetPlayerMapPosition, mapID, "player")
    if not (corpse and me and M.GetWorldPosFromMapPos) then return { mapID = mapID } end
    local _, a = Try(M.GetWorldPosFromMapPos, mapID, corpse)
    local _, b = Try(M.GetWorldPosFromMapPos, mapID, me)
    if not (a and b) then return { mapID = mapID } end
    local ok, info = pcall(function()
        local dx, dy = a.x - b.x, a.y - b.y
        local yards = math.sqrt(dx * dx + dy * dy)
        local angle
        local facing = GetPlayerFacing and GetPlayerFacing()
        if type(facing) == "number" then
            -- world x points north, y points west; facing 0 = north, counter-clockwise, like
            -- a texture's rotation: the angle turns the arrow toward the body
            angle = math.atan2(dy, dx) - facing
        end
        return { mapID = mapID, corpse = corpse, meters = yards * 0.9144, angle = angle }
    end)
    return ok and info or { mapID = mapID }
end

ns:RegisterModule("corpse", {
    label = "CORPSE",
    icon = "Interface\\Icons\\Ability_Rogue_FeignDeath",
    getIcon = function()
        local info = CorpseInfo()
        if info and info.angle then return { file = CORPSE_ARROW, rotation = info.angle, scale = 1.5 } end
        return "Interface\\Icons\\Ability_Rogue_FeignDeath"
    end,
    events = { "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" },
    interval = 0.5,
    defaultEnabled = false,
    isEmpty = function() return CorpseInfo() == nil end,
    update = function()
        local info = CorpseInfo()
        if not info then return L.NONE end
        if not info.meters then return L.CORPSE_GHOST end
        return L.CORPSE_FORMAT:format(info.meters), WARN
    end,
    tooltip = function(tt)
        local info = CorpseInfo()
        if not info then tt:AddLine(L.TT_CORPSE_ALIVE, 0.8, 0.8, 0.8, true) return end
        tt:AddLine(L.TT_CORPSE_HELP, 1, 1, 1, true)
    end,
    -- click: a map pin on your body, tracked on screen
    onClick = function(_, button)
        if button ~= "LeftButton" then return end
        local info = CorpseInfo()
        if not (info and info.corpse and UiMapPoint and C_Map.SetUserWaypoint) then return end
        pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromVector2D(info.mapID, info.corpse))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
    end,
    clickHint = L.HINT_CORPSE,
})

-- Sample values for the demo and the preview mode
local SAMPLES = {
    gold        = function(cfg) return FormatGold(12345678, cfg) end,
    bags        = function() return L.BAGS_FORMAT:format(18, 64), GOOD end,
    durability  = function() return "87%", GOOD end,
    xp          = function() return "45.3% |cff4da6ff+12%|r" end,
    itemLevel   = function() return "52.4" end,
    speed       = function() return "160%" end,
    talents     = function() return "1", WARN end,
    rested      = function() return "85%" end,
    regen       = function() return L.REGEN_FORMAT:format(48) end,
    stats       = function() return L.STAT_SHORT_AP .. " 1 250" end,
    pet          = function() return _G["PET_HAPPINESS3"] or "Happy", GOOD end,
    weaponEnchant = function() return "24:10", GOOD end,
    longBuffs    = function() return L.LONG_BUFFS_FORMAT:format(3, "42:15"), GOOD end,
    corpse       = function() return L.CORPSE_FORMAT:format(84), WARN end,
}
for key, sample in pairs(SAMPLES) do
    if ns.modules[key] then ns.modules[key].sample = sample end
end
