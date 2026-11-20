local _, ns = ...
local L = ns.L

-- Reads the talent tree (class talents) and the Legacy trees (WoW Forever) for the Talents and
-- Legacy blocks. Everything is read through pcall: the game may change these calls.
-- Exported as ns.Traits.
local Traits = {}
ns.Traits = Traits

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

-- Points of the talent tree at which a new tier opens (seen in game, 20/11)
Traits.TALENT_MILESTONES = { 11, 16, 21, 31 }

-- Legacy trees (config of type Generic): tree ID -> the game's own global name for the tab
local LEGACY_TREE_NAMES = {
    [1187] = "LEGACY_TREE_PROFESSIONS",
    [1188] = "LEGACY_TREE_ADVENTURE",
    [1189] = "LEGACY_TREE_PROGRESSION",
}

-- The nodes of a tree as { rank, max, x, groups }
local function ReadNodes(configID, treeID)
    local list, T = {}, C_Traits
    if not (T and T.GetTreeNodes and T.GetNodeInfo) then return list end
    for _, nodeID in ipairs(Try(T.GetTreeNodes, treeID) or {}) do
        local n = Try(T.GetNodeInfo, configID, nodeID)
        if type(n) == "table" then
            table.insert(list, { rank = tonumber(n.currentRank) or tonumber(n.ranksPurchased) or 0,
                                 max = tonumber(n.maxRanks) or 0, x = tonumber(n.posX) or 0,
                                 groups = type(n.groupIDs) == "table" and n.groupIDs or {} })
        end
    end
    return list
end

-- Currencies of a tree: free points and points spent, one count per currency
local function ReadCurrencies(configID, treeID, seen)
    local free, spent = 0, 0
    local list = C_Traits and C_Traits.GetTreeCurrencyInfo and Try(C_Traits.GetTreeCurrencyInfo, configID, treeID, false)
    for _, c in ipairs(type(list) == "table" and list or {}) do
        local id = c.traitCurrencyID or c
        if not seen[id] then
            seen[id] = true
            free = free + (tonumber(c.quantity) or 0)
            spent = spent + (tonumber(c.spent) or 0)
        end
    end
    return free, spent
end

-- Names of the three trees from the game: C_Traits.GetGroupDisplayInfoByTreeID (read as a list
-- or as a single entry), else the spell book tab of the group's skill line
local function GroupDisplay(treeID)
    local T, out = C_Traits, {}
    local info = T and T.GetGroupDisplayInfoByTreeID and Try(T.GetGroupDisplayInfoByTreeID, treeID)
    if type(info) ~= "table" then return out end
    local entries = info.displayName and { info } or info
    for _, e in pairs(entries) do
        if type(e) == "table" and e.groupID then
            local name = e.displayName
            if (not name or name == "") and e.skillLineID and C_SpellBook and C_SpellBook.GetSkillLineIndexByID then
                local index = Try(C_SpellBook.GetSkillLineIndexByID, e.skillLineID)
                local line = index and Try(C_SpellBook.GetSpellBookSkillLineInfo, index)
                name = type(line) == "table" and line.name or nil
            end
            table.insert(out, { groupID = e.groupID, name = name, order = tonumber(e.orderIndex) or 0 })
        end
    end
    table.sort(out, function(a, b) return a.order < b.order end)
    return out
end

-- Points per tree of the class talents: by the game's groups when it gives them, else by
-- column (a tree is a block of columns, a wide gap on the X axis separates two trees)
local function SplitTrees(configID, treeID)
    local nodes, groups = ReadNodes(configID, treeID), GroupDisplay(treeID)
    local trees = {}
    if #groups > 0 then
        local byGroup, found = {}, false
        for _, n in ipairs(nodes) do
            for _, g in ipairs(n.groups) do byGroup[g] = (byGroup[g] or 0) + n.rank; found = true end
        end
        if found then
            for i, g in ipairs(groups) do
                trees[i] = { name = g.name or L.TALENTS_TREE_N:format(i), points = byGroup[g.groupID] or 0 }
            end
            return trees
        end
    end
    local xs, seen = {}, {}
    for _, n in ipairs(nodes) do
        if not seen[n.x] then seen[n.x] = true; table.insert(xs, n.x) end
    end
    table.sort(xs)
    local columnOf, index = {}, 1
    for i, x in ipairs(xs) do
        if i > 1 and x - xs[i - 1] > 1500 then index = index + 1 end
        columnOf[x] = index
    end
    for _, n in ipairs(nodes) do
        local i = columnOf[n.x] or 1
        trees[i] = trees[i] or { points = 0 }
        trees[i].points = trees[i].points + n.rank
    end
    for i = 1, #trees do
        trees[i] = trees[i] or { points = 0 }
        trees[i].name = (groups[i] and groups[i].name) or L.TALENTS_TREE_N:format(i)
    end
    return trees
end

-- Class talents: { free, spent, total, trees = { { name, points } } }, nil when the client has none
function Traits.Talents()
    local CT, T = C_ClassTalents, C_Traits
    if not (CT and T and CT.GetActiveConfigID and T.GetConfigInfo and T.GetTreeCurrencyInfo) then return nil end
    local configID = Try(CT.GetActiveConfigID)
    local info = configID and Try(T.GetConfigInfo, configID)
    local treeID = type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1]
    if not treeID then return nil end
    local free, spent = ReadCurrencies(configID, treeID, {})
    if free == 0 and CT.HasUnspentTalentPoints and Try(CT.HasUnspentTalentPoints) then free = 1 end
    return { free = free, spent = spent, total = free + spent, trees = SplitTrees(configID, treeID) }
end

-- The tree holding the most points (the first one when they are equal), nil without points
function Traits.MainTree(data)
    local best
    for _, t in ipairs(data and data.trees or {}) do
        if t.points > 0 and (not best or t.points > best.points) then best = t end
    end
    return best
end

-- Next milestone above the points earned: { at, left }
function Traits.NextMilestone(total)
    for _, at in ipairs(Traits.TALENT_MILESTONES) do
        if total < at then return { at = at, left = at - total } end
    end
end

-- Talent groups (specs): active group, number of groups
function Traits.SpecGroups()
    local SI = C_SpecializationInfo
    local active = (SI and Try(SI.GetActiveSpecGroup)) or Try(_G["GetActiveTalentGroup"]) or 1
    local count = Try(_G["GetNumSpecGroups"]) or 1
    return tonumber(active) or 1, tonumber(count) or 1
end

-- The game's name of a spec group ("Primary" / "Secondary")
function Traits.SpecName(group)
    return group == 2 and _G["TALENT_SPEC_SECONDARY"] or _G["TALENT_SPEC_PRIMARY"] or L.TALENTS_SPEC_N:format(group)
end

-- Macro that switches the spec group with the game's own spells (63645 Activate Primary Spec,
-- 63644 Activate Secondary Spec). Not in combat; run by the block's secure overlay.
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return Try(C_Spell.GetSpellName, id) end
    return (Try(_G["GetSpellInfo"], id))
end
function Traits.SpecMacro()
    local primary, secondary = SpellName(63645), SpellName(63644)
    if not (primary and secondary) then return "/stopmacro" end
    return ("/cast [nocombat,spec:1] %s\n/cast [nocombat,spec:2] %s"):format(secondary, primary)
end

-- Legacy points: { free, spent, trees = { { name, ranks, max } } }, nil without the Legacy trees
function Traits.Legacy()
    local T = C_Traits
    local generic = Enum and Enum.TraitConfigType and Enum.TraitConfigType.Generic or 3
    if not (T and T.GetConfigsByType and T.GetConfigInfo) then return nil end
    for _, configID in ipairs(Try(T.GetConfigsByType, generic) or {}) do
        local info = Try(T.GetConfigInfo, configID)
        local ids = type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs or {}
        local data, seen = { free = 0, spent = 0, trees = {} }, {}
        for _, treeID in ipairs(ids) do
            local nodes, ranks, max = ReadNodes(configID, treeID), 0, 0
            for _, n in ipairs(nodes) do ranks, max = ranks + n.rank, max + n.max end
            if max > 0 then
                local global = LEGACY_TREE_NAMES[treeID]
                local name = global and _G[global]
                if type(name) ~= "string" or name == "" then
                    local g = GroupDisplay(treeID)[1]
                    name = g and g.name or L.LEGACY_TREE_N:format(treeID)
                end
                table.insert(data.trees, { name = name, ranks = ranks, max = max })
                local free, spent = ReadCurrencies(configID, treeID, seen)
                data.free, data.spent = data.free + free, data.spent + spent
            end
        end
        if #data.trees > 0 then return data end
    end
    return nil
end
