local _, ns = ...
local L = ns.L

-- Blocks about WoW Forever only: Legacy, Comprehension, Camping, Honor, weapon skills.
-- Shared tools come from Modules.lua (ns.BlockTools); see its header for how to add a block.
local Tools = ns.BlockTools
local GOOD, GetItemCountFn, GetItemInfoFn, MicroButtonMacro = Tools.GOOD, Tools.GetItemCountFn, Tools.GetItemInfoFn, Tools.MicroButtonMacro
local ShortDuration, ShortTime = Tools.ShortDuration, Tools.ShortTime
local SkillLines, SkillTooltip, Try, WARN = Tools.SkillLines, Tools.SkillTooltip, Tools.Try, Tools.WARN
local WHITE = Tools.WHITE

-- Weapon skill matching the main-hand weapon (its type name contains the skill name,
-- e.g. "One-Handed Swords" / "Swords"), else the weapon skill furthest from its max
-- Weapon item subclass (GetItemInfoInstant) -> weapon skill line ID: exact in every language
-- (by name, "Two-Handed Swords" also contains "Swords" and took the one-handed skill)
local WEAPON_SUBCLASS_SKILL = {
    [0] = 44, [1] = 172, [2] = 45, [3] = 46, [4] = 54, [5] = 160, [6] = 229, [7] = 43,
    [8] = 55, [10] = 136, [13] = 473, [15] = 173, [16] = 176, [18] = 226, [19] = 228,
}
local function CurrentWeaponSkill(weapons, slot)
    local link = Try(GetInventoryItemLink, "player", slot or 16)
    local _, _, _, _, _, classID, subClassID = Try(C_Item and C_Item.GetItemInfoInstant, link)
    local skillID = classID == 2 and WEAPON_SUBCLASS_SKILL[subClassID]
    if skillID then
        for _, w in ipairs(weapons) do
            if w.id == skillID then return w end
        end
    end
    local subType = link and select(7, GetItemInfoFn(link))
    local best
    for _, w in ipairs(weapons) do
        if subType and (subType:find(w.name, 1, true) or w.name:find(subType, 1, true)) then return w end
        -- (defense, skill 95, is listed with the weapons but is not one)
        if not slot and w.id ~= 95 and (not best or (w.max - w.rank) > (best.max - best.rank)) then best = w end
    end
    return best
end

-- The skill the block shows (option "skillShown"):
--   weapon  the main-hand weapon's (the old display)
--   combat  the ranged weapon's while you shoot (wand, bow, thrown: auto-repeat), else the main hand's
--   chosen  the one picked in "This block" (cfg.skillChosen, a skill line ID)
local function ShownSkill(cfg)
    local weapons = SkillLines().weapons
    local mode = cfg and cfg.skillShown
    if mode == "chosen" then
        for _, w in ipairs(weapons) do
            if w.id == cfg.skillChosen then return w end
        end
    elseif mode == "combat" and ns.state.autoRepeat then
        local ranged = CurrentWeaponSkill(weapons, 18)
        if ranged then return ranged end
    end
    return CurrentWeaponSkill(weapons)
end

-- auto-repeat (shooting) starts and stops: followed for the "combat" display
local autoRepeatWatch = CreateFrame("Frame")
autoRepeatWatch:RegisterEvent("START_AUTOREPEAT_SPELL")
autoRepeatWatch:RegisterEvent("STOP_AUTOREPEAT_SPELL")
autoRepeatWatch:SetScript("OnEvent", function(_, event)
    ns.state.autoRepeat = event == "START_AUTOREPEAT_SPELL"
    if ns.UpdateBlock and ns.db then ns:UpdateBlock("weaponSkills") end
end)

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
    defaults = { skillShown = "weapon", skillChosen = 0 }, -- (0: none picked yet; a number so imports keep it)
    options = {
        { kind = "dropdown", field = "skillShown", tab = "text", label = "SKILL_SHOWN", tip = "TIP_SKILL_SHOWN",
          values = { { key = "weapon", label = "SKILL_WEAPON" }, { key = "combat", label = "SKILL_COMBAT" },
                     { key = "chosen", label = "SKILL_CHOSEN" } } },
        { kind = "dropdown", field = "skillChosen", tab = "text", label = "SKILL_PICK", tip = "TIP_SKILL_PICK",
          values = function()
              local list = {}
              for _, w in ipairs(SkillLines().weapons) do
                  table.insert(list, { key = w.id, label = ("%s (%d/%d)"):format(w.name, w.rank, w.max) })
              end
              return list
          end,
          shown = function(cfg) return cfg.skillShown == "chosen" end },
    },
    isEmpty = function() return #SkillLines().weapons == 0 end,
    update = function(cfg)
        local w = ShownSkill(cfg)
        if not w then return L.NONE end
        return ("%s %d/%d"):format(w.name, w.rank, w.max), w.rank >= w.max and GOOD or WARN
    end,
    progress = function(cfg)
        local w = ShownSkill(cfg)
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
-- /tessera debug legacy probe; the faction ID matches LegacyConsts.LEGACY_REWARD_TRACK_FACTION_ID in
-- Blizzard's generated API documentation (Blizzard_APIDocumentationGenerated, Forever client).
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
    update = function(cfg)
        local data = LegacyData()
        if not data then return L.NA end
        if cfg and cfg.legacyShown == "next" then
            local nextReward = NextLegacyReward(data.renownLevel)
            if nextReward then return L.LEGACY_NEXT_FORMAT:format(data.renownLevel, nextReward.level) end
        end
        return tostring(data.renownLevel)
    end,
    defaults = { legacyShown = "points" },
    options = {
        { kind = "dropdown", field = "legacyShown", tab = "text", label = "LEGACY_SHOWN", tip = "TIP_LEGACY_SHOWN",
          values = { { key = "points", label = "LEGACY_POINTS" }, { key = "next", label = "LEGACY_NEXT" } } },
    },
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
    -- by its ID first: works even with its category folded in the skills window
    local byID = S and S.GetSkillLineInfoByID and Try(S.GetSkillLineInfoByID, COMPREHENSION_SKILL)
    if type(byID) == "table" and byID.name and (byID.maxRank or 0) > 0 then
        return { name = byID.name, rank = byID.rank or 0, max = byID.maxRank or 0, description = byID.description }
    end
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
    update = function(cfg)
        local s = ComprehensionSkill()
        if not s then return L.NONE end
        if cfg and cfg.comprehensionShown == "scrolls" then
            local count = 0
            for _, sc in ipairs(ScrollsInBags()) do count = count + sc.count end
            return L.SCROLLS_FORMAT:format(count)
        end
        return ("%d/%d"):format(s.rank, s.max), s.rank >= s.max and GOOD or WARN
    end,
    defaults = { comprehensionShown = "rank" },
    options = {
        { kind = "dropdown", field = "comprehensionShown", tab = "text", label = "COMPREHENSION_SHOWN",
          tip = "TIP_COMPREHENSION_SHOWN",
          values = { { key = "rank", label = "COMPREHENSION_RANK" }, { key = "scrolls", label = "COMPREHENSION_SCROLLS" } } },
    },
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
        if type(s.description) == "string" and s.description ~= "" then tt:AddLine(s.description, 0.8, 0.8, 0.8, true) end
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
    playerOnly = { UNIT_AURA = true }, -- the game sends it for every unit around you
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
        -- only near a campfire: its name (the game's own text), not "None"
        local near = PlayerAura(CAMP_NEAR)
        if near and near.name and near.name ~= "" then return near.name end
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
    update = function(cfg)
        local info = HonorInfo()
        if not info then return L.NA end
        local fmt = BreakUpLargeNumbers or tostring
        local hasMax = info.maxQuantity and info.maxQuantity > 0
        local capped = hasMax and info.quantity >= info.maxQuantity
        local mode = cfg and cfg.honorFormat or "current"
        if hasMax and mode == "currentMax" then
            return ("%s / %s"):format(fmt(info.quantity or 0), fmt(info.maxQuantity)), capped and WARN or nil
        elseif hasMax and mode == "percent" then
            return ("%d%%"):format(math.floor((info.quantity or 0) / info.maxQuantity * 100)), capped and WARN or nil
        end
        return fmt(info.quantity or 0), capped and WARN or nil
    end,
    defaults = { honorFormat = "current" },
    options = {
        { kind = "dropdown", field = "honorFormat", tab = "text", label = "HONOR_SHOWN", tip = "TIP_HONOR_SHOWN",
          values = { { key = "current", label = "HONOR_CURRENT" }, { key = "currentMax", label = "HONOR_CURRENT_MAX" },
                     { key = "percent", label = "HONOR_PERCENT" } } },
    },
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
        local yKills, yHonor = Try(_G["GetPVPYesterdayStats"])
        if type(yKills) == "number" then
            WHITE(tt, L.TT_HONOR_YESTERDAY, L.TT_HONOR_YESTERDAY_FORMAT:format(fmt(yKills), fmt(yHonor or 0)))
        end
        tt:AddLine(" ")
        tt:AddLine(L.TT_HONOR_RANKS_LATER, 0.6, 0.6, 0.6, true)
    end,
    chatText = function()
        local info = HonorInfo()
        return info and ("%s : %s"):format(info.name, info.quantity or 0) or nil
    end,
})
end

-- Sample values for the demo and the preview mode
local SAMPLES = {
    weaponSkills = function() return "115/120", WARN end,
    legacy       = function() return "16" end,
    comprehension = function() return "42/65", WARN end,
    camping      = function() return L.CAMP_BUFFS_LEFT:format("52m"), GOOD end,
    honor        = function() return "3 250" end,
}
for key, sample in pairs(SAMPLES) do
    if ns.modules[key] then ns.modules[key].sample = sample end
end
