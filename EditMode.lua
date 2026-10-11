local _, ns = ...
local L = ns.L

-- ========================================================================
-- EditMode.lua: making room in Blizzard's Edit Mode for Tessera's bars
-- ========================================================================
-- A Tessera bar stuck to the top or bottom edge can cover Blizzard frames (the
-- action bars, the micro menu, the minimap...). On request, Tessera makes a COPY
-- of the player's Edit Mode layout, named "My layout (Tessera 1)", where only the
-- frames that would be covered are moved, by the minimum needed, and activates it.
-- The original layout is never changed. Everything goes through the game's own
-- C_EditMode functions, out of combat, on a click of the player.
--
--   * Only frames anchored to the screen (UIParent) are moved; frames anchored to
--     another frame (the main action bar on the micro menu, the bags...) follow.
--   * Copies are recognized by a fingerprint saved when they are made (name, type
--     and content), never by their name alone: a layout the player made himself,
--     even with the same name, is never deleted or overwritten.
--   * FlareUI saves the positions of its own frames per layout: in a copy they go
--     back to their default place. Tessera says so before making the copy.
--   * Tested on Blizzard's default interface (Modern and Classic layouts) and on an
--     unchanged FlareUI. With other interfaces, results may be unexpected: the
--     confirmation says so when one is loaded.
-- ========================================================================

local MAX_NAME = 30 -- longest layout name the game accepts (characters)
local GAP = 2       -- free space kept between Tessera's bar and the moved frames
local OTHER_UIS = { "ElvUI", "EllesmereUI", "Bartender4", "Dominos", "MoveAny", "EditModeExpanded" }

local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

local function Available()
    return C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts and C_EditMode.SetActiveLayout
        and EditModeManagerFrame and true or false
end

local function Saved()
    ns.sv.editModeCopies = ns.sv.editModeCopies or {}
    return ns.sv.editModeCopies
end

---------------------------------------------------------------------------
-- Layouts
---------------------------------------------------------------------------
-- The game's ready-made layouts (Modern, Classic, Gamepad): they come first in
-- the numbering of activeLayout, before the player's layouts
local function Presets()
    local ok, list = pcall(function() return EditModePresetLayoutManager:GetCopyOfPresetLayouts() end)
    return (ok and type(list) == "table") and list or {}
end

-- Everything about the current layouts: info (from C_EditMode.GetLayouts), the
-- presets, and the active layout (table, index in info.layouts or nil for a preset)
local function ReadLayouts()
    local ok, info = pcall(C_EditMode.GetLayouts)
    if not ok or type(info) ~= "table" or type(info.layouts) ~= "table" then return nil end
    local presets = Presets()
    local index = info.activeLayout or 1
    local active, own
    if index > #presets then
        own = index - #presets
        active = info.layouts[own]
    else
        active = presets[index]
    end
    return { info = info, presets = presets, active = active, own = own, activeIndex = index }
end

-- Number of characters of a UTF-8 string (the name limit counts characters)
local function Length(s)
    local _, count = s:gsub("[^\128-\191]", "")
    return count
end

-- First n characters of a UTF-8 string
local function Cut(s, n)
    local out, count = {}, 0
    for char in s:gmatch("[\1-\127\192-\255][\128-\191]*") do
        if count >= n then break end
        count = count + 1
        out[count] = char
    end
    return table.concat(out)
end

-- "My layout (Tessera N)": the first free number, the base name shortened if
-- needed to stay within the game's limit
function ns.EditModeCopyName(base, taken)
    local n = 1
    while true do
        local suffix = " (Tessera " .. n .. ")"
        local name = strtrim(Cut(base, MAX_NAME - Length(suffix))) .. suffix
        if not taken[name] then return name end
        n = n + 1
    end
end

-- A short text describing a layout's content, to recognize Tessera's copies
local function Fingerprint(layout)
    local parts = { tostring(layout.layoutName), tostring(layout.layoutType) }
    for _, s in ipairs(layout.systems or {}) do
        local a = s.anchorInfo or {}
        table.insert(parts, ("%s.%s:%s:%s:%s:%d:%d:%s"):format(tostring(s.system), tostring(s.systemIndex),
            tostring(a.point), tostring(a.relativeTo), tostring(a.relativePoint),
            math.floor((tonumber(a.offsetX) or 0) + 0.5), math.floor((tonumber(a.offsetY) or 0) + 0.5),
            tostring(s.isInDefaultPosition)))
        for _, setting in ipairs(s.settings or {}) do
            table.insert(parts, tostring(setting.setting) .. "=" .. tostring(setting.value))
        end
    end
    table.sort(parts)
    -- djb2 hash: short to store, enough to notice any change
    local text, h = table.concat(parts, "|"), 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
    return ("%08x"):format(h)
end
ns.EditModeFingerprint = Fingerprint

-- Is this layout a copy made by Tessera, unchanged since?
local function IsOurCopy(layout)
    local saved = layout and Saved()[layout.layoutName]
    return saved ~= nil and saved.layoutType == layout.layoutType and saved.fingerprint == Fingerprint(layout)
end

---------------------------------------------------------------------------
-- What needs to move
---------------------------------------------------------------------------
-- Tessera's bars stuck to the top or bottom edge: { edge, l, r, h } in UIParent units
local function TesseraBars()
    local bars = {}
    for key, cfg in pairs(ns.db.blocks) do
        local f = ns.frames[key]
        if cfg.edges and (cfg.edges.TOP or cfg.edges.BOTTOM) and f and f:IsShown() and not ns:GetDockTarget(key) then
            local l, b, r, t = ns:GroupRectUI(key)
            if l then
                local H = UIParent:GetHeight()
                if cfg.edges.BOTTOM then table.insert(bars, { edge = "BOTTOM", l = l, r = r, h = t }) end
                if cfg.edges.TOP then table.insert(bars, { edge = "TOP", l = l, r = r, h = H - b }) end
            end
        end
    end
    return bars
end

-- The frame of a layout system, or nil
local function SystemFrame(sys)
    local ok, f = pcall(EditModeManagerFrame.GetRegisteredSystemFrame, EditModeManagerFrame, sys.system, sys.systemIndex)
    return ok and f or nil
end

-- Plain names for the kinds of frames, used in the messages ("action bars",
-- "menu"...) rather than the game's technical names
local FRIENDLY = { ActionBar = "EM_ACTION_BARS", MicroMenu = "EM_MENU", Bags = "EM_BAGS", Minimap = "EM_MINIMAP",
    AuraFrame = "EM_BUFFS", StatusTrackingBar = "EM_XP_BAR", DamageMeter = "EM_DAMAGE_METER",
    ChatFrame = "EM_CHAT", ObjectiveTracker = "EM_OBJECTIVES", UnitFrame = "EM_UNIT_FRAMES",
    CastBar = "EM_CAST_BAR", MainActionBarEndCap = "EM_GRYPHONS", TotemActionBar = "EM_ACTION_BARS" }
local FLARE_FRIENDLY = { XPBar = "EM_XP_BAR", Buffs = "EM_BUFFS", Debuffs = "EM_BUFFS", ObjectiveTracker = "EM_OBJECTIVES",
    UF_Player = "EM_UNIT_FRAMES", UF_Target = "EM_UNIT_FRAMES", UF_Focus = "EM_UNIT_FRAMES", UF_Pet = "EM_UNIT_FRAMES",
    UF_PlayerCastBar = "EM_CAST_BAR", Totems = "EM_TOTEMS", Toasts = "EM_TOASTS", LootRolls = "EM_LOOT_ROLLS" }

-- The gryphons (end caps) are decoration: they follow the main action bar, and
-- a bit of them under Tessera's bar (drawn in front of them) is no problem
local DECORATION = { [26] = true } -- Enum.EditModeSystem.MainActionBarEndCap

-- Readable name of a system frame, for the messages
local function FrameLabel(f, sys)
    for label, id in pairs(Enum and Enum.EditModeSystem or {}) do
        if sys and id == sys.system and FRIENDLY[label] then return L[FRIENDLY[label]] end
    end
    local name = type(f.systemNameString) == "string" and f.systemNameString or (f.GetName and f:GetName())
    if name and name:find("%%d") then
        local ok, text = pcall(string.format, name, sys and sys.systemIndex or 1)
        name = ok and text or name:gsub("%%d", "")
    end
    return name or "?"
end

-- For each system anchored to the screen: how far it must move so that it and
-- the frames anchored to it (directly or not) clear Tessera's bars.
-- Returns a list of { sys, dy, label } (dy > 0: up) and the FlareUI frames in the way.
function ns:PlanEditModeRoom(layout)
    local bars = TesseraBars()
    if #bars == 0 or not layout then return {}, {} end
    local H = UIParent:GetHeight()

    -- frame of each system, and which frame each one is anchored to (by name)
    local entries, byName = {}, {}
    for _, sys in ipairs(layout.systems or {}) do
        local f = SystemFrame(sys)
        if f then
            local e = { sys = sys, frame = f, rel = sys.anchorInfo and sys.anchorInfo.relativeTo }
            table.insert(entries, e)
            local name = f.GetName and f:GetName()
            if name then byName[name] = e end
        end
    end
    -- the screen-anchored system each frame finally hangs on
    local function RootOf(e)
        local seen = {}
        while e and e.rel and e.rel ~= "UIParent" and byName[e.rel] and not seen[e] do
            seen[e] = true
            e = byName[e.rel]
        end
        return (e and (e.rel == "UIParent" or e.rel == nil)) and e or nil
    end

    -- how far each frame must move to clear the bars (0 if it does not touch them)
    local function Needed(f)
        if not (f.IsShown and f:IsShown()) then return 0, nil end
        local l, b, r, t = self:GetRectUI(f)
        if not l then return 0, nil end
        local up, down = 0, 0
        for _, bar in ipairs(bars) do
            if r > bar.l and l < bar.r then
                if bar.edge == "BOTTOM" and b < bar.h then up = math.max(up, bar.h + GAP - b) end
                if bar.edge == "TOP" and t > H - bar.h then down = math.max(down, t - (H - bar.h - GAP)) end
            end
        end
        return up, down
    end

    local moves = {}
    for _, e in ipairs(entries) do
        local up, down = 0, 0
        if not DECORATION[e.sys.system] then up, down = Needed(e.frame) end
        if up > 0 or (down or 0) > 0 then
            local root = RootOf(e)
            if root then
                local m = moves[root] or { sys = root.sys, frame = root.frame, up = 0, down = 0, labels = {} }
                moves[root] = m
                m.up, m.down = math.max(m.up, up), math.max(m.down, down or 0)
                m.labels[FrameLabel(e.frame, e.sys)] = true
            end
        end
    end
    local list = {}
    for _, m in pairs(moves) do
        -- a frame squeezed by a bar at the top and one at the bottom: the bottom wins
        local dy = m.up > 0 and m.up or -m.down
        local labels = {}
        for label in pairs(m.labels) do table.insert(labels, label) end
        table.sort(labels)
        table.insert(list, { sys = m.sys, frame = m.frame, dy = math.ceil(math.abs(dy)) * (dy < 0 and -1 or 1),
            label = table.concat(labels, ", ") })
    end
    table.sort(list, function(a, b) return a.label < b.label end)

    -- FlareUI's own frames in the way (Tessera does not move them)
    local flare = {}
    for name, f in pairs(_G) do
        if type(name) == "string" and name:find("^FlareUI_") and type(f) == "table" and f.GetRect then
            local ok, up, down = pcall(Needed, f)
            if ok and (up > 0 or (down or 0) > 0) then
                local short = name:gsub("^FlareUI_", "")
                local label = FLARE_FRIENDLY[short] and L[FLARE_FRIENDLY[short]] or short
                local seen = false
                for _, v in ipairs(flare) do seen = seen or v == label end
                if not seen then table.insert(flare, label) end
            end
        end
    end
    table.sort(flare)
    return list, flare
end

---------------------------------------------------------------------------
-- Making the copy
---------------------------------------------------------------------------
-- Coordinates of an anchor point ("TOPLEFT", "BOTTOM", "CENTER"...) of a rectangle
local function PointXY(point, l, b, r, t)
    point = point or "CENTER"
    local x = point:find("LEFT") and l or point:find("RIGHT") and r or (l + r) / 2
    local y = point:find("TOP") and t or point:find("BOTTOM") and b or (b + t) / 2
    return x, y
end

-- The offsets that put frame f where it is now, for its anchor on the screen,
-- moved by dy (UIParent units, up when positive). Frames in their default place
-- are positioned by the game, not by their saved offsets: reading the real
-- position keeps them exactly where they are before moving them.
local function CurrentOffsets(f, anchor, dy)
    local l, b, r, t = f:GetLeft(), f:GetBottom(), f:GetRight(), f:GetTop()
    if not l then return nil end
    local k = UIParent:GetEffectiveScale() / f:GetEffectiveScale() -- UIParent units -> frame units
    local fx, fy = PointXY(anchor.point, l, b, r, t)
    local ux, uy = PointXY(anchor.relativePoint, 0, 0, UIParent:GetWidth() * k, UIParent:GetHeight() * k)
    return fx - ux, fy - uy + dy * k
end

local pending -- the plan waiting for the player's confirmation

local function Refuse(reason)
    ns.Print(reason)
    return false
end

-- Checks the situation, works out the moves and asks the player.
-- quiet: called after applying a layout (no message when nothing is in the way)
function ns:OfferEditModeRoom(quiet)
    if not Available() then return quiet or Refuse(L.EDITMODE_UNAVAILABLE) end
    if InCombatLockdown() then return Refuse(L.EDITMODE_COMBAT) end
    if EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive() then
        return Refuse(L.EDITMODE_CLOSE_FIRST)
    end
    local state = ReadLayouts()
    if not state or not state.active then return quiet or Refuse(L.EDITMODE_UNAVAILABLE) end
    -- the moves are computed from what is on screen, so they apply to the active
    -- layout; when it is already a Tessera copy, that copy is updated and keeps
    -- the name of its original layout
    local base = state.active
    local saved = IsOurCopy(base) and Saved()[base.layoutName]
    local source = saved and { layoutName = saved.source, layoutType = saved.sourceType } or base
    local moves, flare = self:PlanEditModeRoom(base)
    if #moves == 0 then
        if not quiet then self.Print(L.EDITMODE_NOTHING) end
        return false
    end
    pending = { base = base, source = source, own = saved and state.own or nil, moves = moves, flare = flare }
    local lines = {}
    for _, m in ipairs(moves) do
        local what = m.label:sub(1, 1):upper() .. m.label:sub(2)
        table.insert(lines, "- " .. (m.dy > 0 and L.EDITMODE_MOVE_UP or L.EDITMODE_MOVE_DOWN):format(what, math.abs(m.dy)))
    end
    local text = L.EDITMODE_CONFIRM:format(source.layoutName, table.concat(lines, "\n"), source.layoutName)
    if IsLoaded and IsLoaded("FlareUI") then
        text = text .. "\n\n" .. L.EDITMODE_FLAREUI
        if #flare > 0 then text = text .. " " .. L.EDITMODE_FLAREUI_COVERED:format(table.concat(flare, ", ")) end
    end
    for _, ui in ipairs(OTHER_UIS) do
        if IsLoaded and IsLoaded(ui) then
            text = text .. "\n\n" .. L.EDITMODE_OTHER_UI:format(ui)
            break
        end
    end
    StaticPopup_Show("TESSERA_EDITMODE_ROOM", text)
    return true
end

-- Writes the copy (or updates Tessera's previous copy of the same layout) and
-- activates it, then checks the result
function ns:ApplyEditModeRoom()
    local plan = pending
    pending = nil
    if not plan or InCombatLockdown() then return Refuse(L.EDITMODE_COMBAT) end
    local state = ReadLayouts()
    if not state then return Refuse(L.EDITMODE_UNAVAILABLE) end
    local info, source = state.info, plan.source
    local layoutType = source.layoutType
    if layoutType == Enum.EditModeLayoutType.Preset or layoutType == nil then
        layoutType = Enum.EditModeLayoutType.Account
    end

    -- reuse Tessera's unchanged copy of this layout (the active one when it is a
    -- copy, else an older copy of the same original), or add a new one
    local slot = plan.own
    local base = plan.base
    if not slot then
        for i, layout in ipairs(info.layouts) do
            local saved = Saved()[layout.layoutName]
            if saved and saved.source == source.layoutName and saved.sourceType == source.layoutType
                and IsOurCopy(layout) then
                slot = i
            end
        end
    end
    local copy = ns.DeepCopy(base)
    copy.layoutType = layoutType
    if slot then
        copy.layoutName = info.layouts[slot].layoutName
    else
        local count = 0
        for _, layout in ipairs(info.layouts) do
            if layout.layoutType == layoutType then count = count + 1 end
        end
        local max = Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType or 5
        if count >= max then return Refuse(L.EDITMODE_FULL:format(max)) end
        local taken = {}
        for _, layout in ipairs(info.layouts) do taken[layout.layoutName] = true end
        for _, layout in ipairs(state.presets) do taken[layout.layoutName] = true end
        copy.layoutName = ns.EditModeCopyName(source.layoutName or "Tessera", taken)
    end

    -- move the systems (positive offsets go up, whatever the anchor point)
    for _, m in ipairs(plan.moves) do
        for _, sys in ipairs(copy.systems or {}) do
            if sys.system == m.sys.system and sys.systemIndex == m.sys.systemIndex and sys.anchorInfo then
                local x, y = CurrentOffsets(m.frame, sys.anchorInfo, m.dy)
                if x then
                    sys.anchorInfo.offsetX = math.floor(x * 10 + 0.5) / 10
                    sys.anchorInfo.offsetY = math.floor(y * 10 + 0.5) / 10
                else
                    sys.anchorInfo.offsetY = (tonumber(sys.anchorInfo.offsetY) or 0) + m.dy
                end
                sys.isInDefaultPosition = false
            end
        end
    end

    if slot then info.layouts[slot] = copy else table.insert(info.layouts, copy) slot = #info.layouts end
    local index = #state.presets + slot
    info.activeLayout = index
    local ok = pcall(C_EditMode.SaveLayouts, info)
    if ok then ok = pcall(C_EditMode.SetActiveLayout, index) end
    if not ok then return Refuse(L.EDITMODE_FAILED) end

    Saved()[copy.layoutName] = { layoutType = copy.layoutType, fingerprint = Fingerprint(copy),
        source = source.layoutName, sourceType = source.layoutType }
    self.sv.editModeOriginal = { name = source.layoutName, layoutType = source.layoutType }
    self.db.editModeLayout = copy.layoutName
    self.Print(L.EDITMODE_DONE:format(copy.layoutName, source.layoutName))
    if IsLoaded and IsLoaded("FlareUI") then self.Print(L.EDITMODE_FLAREUI_REMINDER) end
    -- check once the game has moved the frames
    C_Timer.After(1, function() self:CheckEditModeRoom() end)
    return true
end

-- After applying: anything still in the way, or pushed off the screen?
function ns:CheckEditModeRoom()
    local state = ReadLayouts()
    if not (state and state.active) then return end
    local still = self:PlanEditModeRoom(state.active)
    local off = {}
    local H, W = UIParent:GetHeight(), UIParent:GetWidth()
    for _, sys in ipairs(state.active.systems or {}) do
        local f = not DECORATION[sys.system] and SystemFrame(sys)
        if f and f.IsShown and f:IsShown() then
            local l, b, r, t = self:GetRectUI(f)
            if l and (t > H + 1 or b < -1 - 4 or l < -1 or r > W + 1) and not sys.isInDefaultPosition then
                table.insert(off, FrameLabel(f, sys))
            end
        end
    end
    if #still == 0 and #off == 0 then return end
    local names, seen = {}, {}
    for _, m in ipairs(still) do
        if not seen[m.label] then seen[m.label] = true table.insert(names, m.label) end
    end
    for _, n in ipairs(off) do
        if not seen[n] then seen[n] = true table.insert(names, n) end
    end
    StaticPopup_Show("TESSERA_EDITMODE_CHECK", table.concat(names, ", "))
end

---------------------------------------------------------------------------
-- Back to the original, cleaning up, switching with the profile
---------------------------------------------------------------------------
-- Index (for SetActiveLayout) of a layout found by name and type
local function IndexOf(state, name, layoutType)
    if layoutType == Enum.EditModeLayoutType.Preset then
        for i, layout in ipairs(state.presets) do
            if layout.layoutName == name then return i end
        end
        return nil
    end
    for i, layout in ipairs(state.info.layouts) do
        if layout.layoutName == name and layout.layoutType == layoutType then return #state.presets + i end
    end
end

function ns:RevertEditModeLayout()
    if not Available() then return Refuse(L.EDITMODE_UNAVAILABLE) end
    if InCombatLockdown() then return Refuse(L.EDITMODE_COMBAT) end
    local original = self.sv.editModeOriginal
    local state = ReadLayouts()
    local index = original and state and IndexOf(state, original.name, original.layoutType)
    if not index then return Refuse(L.EDITMODE_NO_ORIGINAL) end
    pcall(C_EditMode.SetActiveLayout, index)
    self.db.editModeLayout = nil
    self.Print(L.EDITMODE_REVERTED:format(original.name))
    return true
end

-- Tessera's copies that can be deleted: unchanged since they were made, and not active
function ns:GetEditModeCopies()
    local state = Available() and ReadLayouts()
    local list = {}
    if not state then return list, state end
    for i, layout in ipairs(state.info.layouts) do
        if IsOurCopy(layout) and #state.presets + i ~= state.activeIndex then
            table.insert(list, layout.layoutName)
        end
    end
    table.sort(list)
    return list, state
end

function ns:OfferEditModeCleanup()
    if InCombatLockdown() then return Refuse(L.EDITMODE_COMBAT) end
    local list = self:GetEditModeCopies()
    if #list == 0 then return Refuse(L.EDITMODE_NO_COPIES) end
    StaticPopup_Show("TESSERA_EDITMODE_CLEANUP", table.concat(list, "\n"))
    return true
end

function ns:DeleteEditModeCopies()
    if InCombatLockdown() then return Refuse(L.EDITMODE_COMBAT) end
    local list, state = self:GetEditModeCopies()
    if #list == 0 then return false end
    local remove = {}
    for _, name in ipairs(list) do remove[name] = true end
    local activeLayout = state.activeIndex > #state.presets and state.info.layouts[state.activeIndex - #state.presets]
    local kept = {}
    for _, layout in ipairs(state.info.layouts) do
        if remove[layout.layoutName] and IsOurCopy(layout) then
            Saved()[layout.layoutName] = nil
        else
            table.insert(kept, layout)
        end
    end
    state.info.layouts = kept
    -- the active layout keeps its place in the new numbering
    for i, layout in ipairs(kept) do
        if layout == activeLayout then state.info.activeLayout = #state.presets + i end
    end
    if not pcall(C_EditMode.SaveLayouts, state.info) then return Refuse(L.EDITMODE_FAILED) end
    self.Print(L.EDITMODE_DELETED:format(#list))
    return true
end

-- Name of the active Edit Mode layout, and whether it is a Tessera copy (bug report)
function ns:GetEditModeStatus()
    local state = Available() and ReadLayouts()
    if not (state and state.active) then return "unavailable" end
    return ("%s%s"):format(tostring(state.active.layoutName), IsOurCopy(state.active) and " (Tessera copy)" or "")
end

-- After a profile change: offer the Edit Mode layout that goes with it
function ns:CheckEditModeForProfile()
    if not Available() or InCombatLockdown() or not self.db then return end
    local state = ReadLayouts()
    if not (state and state.active) then return end
    local wanted = self.db.editModeLayout
    if wanted and state.active.layoutName ~= wanted then
        for _, layout in ipairs(state.info.layouts) do
            if layout.layoutName == wanted and IsOurCopy(layout) then
                StaticPopup_Show("TESSERA_EDITMODE_SWITCH", wanted, nil, { name = wanted })
                return
            end
        end
    elseif not wanted and IsOurCopy(state.active) and self.sv.editModeOriginal then
        StaticPopup_Show("TESSERA_EDITMODE_SWITCH", self.sv.editModeOriginal.name, nil, { revert = true })
    end
end

function ns:SwitchEditModeLayout(name)
    local state = ReadLayouts()
    if not state then return end
    for i, layout in ipairs(state.info.layouts) do
        if layout.layoutName == name and IsOurCopy(layout) then
            pcall(C_EditMode.SetActiveLayout, #state.presets + i)
            return
        end
    end
end

---------------------------------------------------------------------------
-- Popups
---------------------------------------------------------------------------
StaticPopupDialogs["TESSERA_EDITMODE_ROOM"] = {
    text = "%s",
    button1 = L.EDITMODE_CREATE,
    button2 = CANCEL,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function() ns:ApplyEditModeRoom() end,
    OnCancel = function() pending = nil end,
}

StaticPopupDialogs["TESSERA_EDITMODE_CHECK"] = {
    text = L.EDITMODE_CHECK_FAILED,
    button1 = L.EDITMODE_REVERT,
    button2 = L.EDITMODE_KEEP,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function() ns:RevertEditModeLayout() end,
}

StaticPopupDialogs["TESSERA_EDITMODE_CLEANUP"] = {
    text = L.EDITMODE_CLEANUP_CONFIRM,
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function() ns:DeleteEditModeCopies() end,
}

StaticPopupDialogs["TESSERA_EDITMODE_SWITCH"] = {
    text = L.EDITMODE_SWITCH,
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, data)
        if data and data.revert then ns:RevertEditModeLayout() elseif data then ns:SwitchEditModeLayout(data.name) end
    end,
}

-- Resolution or interface scale changed while a Tessera copy is active: the
-- moves were computed for the old size, offer to compute them again
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
watcher:RegisterEvent("UI_SCALE_CHANGED")
watcher:SetScript("OnEvent", function()
    if not (ns.sv and ns.built and Available()) then return end
    local state = ReadLayouts()
    if state and IsOurCopy(state.active) then ns.Print(L.EDITMODE_RESIZED) end
end)
