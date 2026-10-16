local _, ns = ...
local L = ns.L

-- ========================================================================
-- Layers.lua: Tessera's blocks in front of or behind Blizzard's frames
-- ========================================================================
-- Tessera never moves Blizzard's frames. When its blocks cover some of them (action
-- bars, minimap, buffs...), the player chooses whether the blocks are drawn in front
-- of them or behind them (the frame strata of the blocks, cfg.strata):
--   * in placement mode, a button of the banner (and a small one under Blizzard's Edit
--     Mode window) puts every block in front or behind for a while, to see what is
--     underneath (nothing is saved);
--   * when the blocks are locked again, or a ready-made layout is applied, and blocks
--     cover Blizzard frames, Tessera asks which to keep (once for the same situation);
--   * the Look tab puts all blocks in front or behind at any time.
-- Older test versions could make a copy of the player's Edit Mode layout: a player
-- still on such a copy is offered, once, to go back to his own layout (end of file).
-- ========================================================================

local STRATA = { front = "HIGH", behind = "BACKGROUND" }
ns.LAYER_STRATA = STRATA

local function EditModeAvailable()
    return C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts and C_EditMode.SetActiveLayout
        and EditModeManagerFrame and true or false
end

---------------------------------------------------------------------------
-- Which Blizzard frames the blocks cover
---------------------------------------------------------------------------
-- The game's ready-made Edit Mode layouts come first in the numbering of activeLayout
local function Presets()
    local ok, list = pcall(function() return EditModePresetLayoutManager:GetCopyOfPresetLayouts() end)
    return (ok and type(list) == "table") and list or {}
end

-- The current Edit Mode layouts: info (C_EditMode.GetLayouts), the presets, and the
-- active layout (table, index in info.layouts or nil for a preset)
local function ReadLayouts()
    if not EditModeAvailable() then return nil end
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

local function SystemFrame(sys)
    local ok, f = pcall(EditModeManagerFrame.GetRegisteredSystemFrame, EditModeManagerFrame, sys.system, sys.systemIndex)
    return ok and f or nil
end

-- Plain names for the kinds of frames, used in the question ("action bars", "menu"...)
local FRIENDLY = { ActionBar = "EM_ACTION_BARS", MicroMenu = "EM_MENU", Bags = "EM_BAGS", Minimap = "EM_MINIMAP",
    AuraFrame = "EM_BUFFS", StatusTrackingBar = "EM_XP_BAR", DamageMeter = "EM_DAMAGE_METER",
    ChatFrame = "EM_CHAT", ObjectiveTracker = "EM_OBJECTIVES", UnitFrame = "EM_UNIT_FRAMES",
    CastBar = "EM_CAST_BAR", TotemActionBar = "EM_ACTION_BARS" }
local FLARE_FRIENDLY = { XPBar = "EM_XP_BAR", Buffs = "EM_BUFFS", Debuffs = "EM_BUFFS", ObjectiveTracker = "EM_OBJECTIVES",
    UF_Player = "EM_UNIT_FRAMES", UF_Target = "EM_UNIT_FRAMES", UF_Focus = "EM_UNIT_FRAMES", UF_Pet = "EM_UNIT_FRAMES",
    UF_PlayerCastBar = "EM_CAST_BAR", Totems = "EM_TOTEMS", Toasts = "EM_TOASTS", LootRolls = "EM_LOOT_ROLLS" }
-- The gryphons (end caps) are decoration: blocks over them are no problem
local DECORATION = { [26] = true } -- Enum.EditModeSystem.MainActionBarEndCap

local function SystemLabel(f, sys)
    for label, id in pairs(Enum and Enum.EditModeSystem or {}) do
        if id == sys.system and FRIENDLY[label] then return L[FRIENDLY[label]] end
    end
    local name = type(f.systemNameString) == "string" and f.systemNameString or (f.GetName and f:GetName())
    if name and name:find("%%d") then
        local ok, text = pcall(string.format, name, sys.systemIndex or 1)
        name = ok and text or name:gsub("%%d", "")
    end
    return name
end

-- Blizzard frames to check: { frame, label } (Edit Mode systems, else a fixed list;
-- FlareUI's own frames too)
local FALLBACK = { MainActionBar = "EM_ACTION_BARS", MainMenuBar = "EM_ACTION_BARS",
    MultiBarBottomLeft = "EM_ACTION_BARS", MultiBarBottomRight = "EM_ACTION_BARS", MultiBarRight = "EM_ACTION_BARS",
    MultiBarLeft = "EM_ACTION_BARS", MinimapCluster = "EM_MINIMAP", BuffFrame = "EM_BUFFS",
    MicroMenuContainer = "EM_MENU", BagsBar = "EM_BAGS", PlayerFrame = "EM_UNIT_FRAMES", TargetFrame = "EM_UNIT_FRAMES",
    ChatFrame1 = "EM_CHAT", ObjectiveTrackerFrame = "EM_OBJECTIVES" }
local function BlizzardFrames()
    local list = {}
    local state = ReadLayouts()
    if state and state.active then
        for _, sys in ipairs(state.active.systems or {}) do
            local f = not DECORATION[sys.system] and SystemFrame(sys)
            if f then table.insert(list, { frame = f, label = SystemLabel(f, sys) }) end
        end
    else
        for name, label in pairs(FALLBACK) do
            local f = _G[name]
            if type(f) == "table" and f.GetRect then table.insert(list, { frame = f, label = L[label] }) end
        end
    end
    for name, f in pairs(_G) do
        if type(name) == "string" and name:find("^FlareUI_") and type(f) == "table" and f.GetRect
            and not (f.IsForbidden and f:IsForbidden()) then
            local short = name:gsub("^FlareUI_", "")
            if FLARE_FRIENDLY[short] then table.insert(list, { frame = f, label = L[FLARE_FRIENDLY[short]] }) end
        end
    end
    return list
end

-- The frames covered by shown blocks: sorted labels, the covering groups (root keys)
-- and a signature of the situation (to ask only once for the same one)
function ns:GetCoveredFrames()
    local groups = {}
    for key, f in pairs(self.frames) do
        if f:IsShown() and self.db.blocks[key] then groups[self:GetRoot(key)] = true end
    end
    local rects = {}
    for root in pairs(groups) do
        local l, b, r, t = self:GroupRectUI(root)
        if l then rects[root] = { l, b, r, t } end
    end
    local labels, seen, covering = {}, {}, {}
    for _, entry in ipairs(BlizzardFrames()) do
        local f = entry.frame
        local shown = (f.IsVisible or f.IsShown)(f)
        local l, b, r, t
        if shown then l, b, r, t = self:GetRectUI(f) end
        if l and r - l > 1 and t - b > 1 then
            for root, g in pairs(rects) do
                -- a real overlap, not just touching edges
                if math.min(r, g[3]) - math.max(l, g[1]) > 2 and math.min(t, g[4]) - math.max(b, g[2]) > 2 then
                    covering[root] = true
                    local label = entry.label
                    if label and not seen[label] then
                        seen[label] = true
                        table.insert(labels, label)
                    end
                end
            end
        end
    end
    table.sort(labels)
    local roots = {}
    for root in pairs(covering) do table.insert(roots, root) end
    table.sort(roots)
    return labels, covering, table.concat(roots, ",") .. "|" .. table.concat(labels, ",")
end

---------------------------------------------------------------------------
-- In front or behind
---------------------------------------------------------------------------
-- Gives the blocks their saved layer, or the temporary one of placement mode
function ns:ApplyLayers()
    for key, f in pairs(self.frames) do
        local cfg = self.db.blocks[key]
        if cfg then f:SetFrameStrata(self.tempStrata or cfg.strata) end
    end
    self:RequestOverlaySync()
end

-- Is every shown block (or the temporary layer) behind?
function ns:LayerShown()
    if self.tempStrata then return self.tempStrata == STRATA.behind and "behind" or "front" end
    for key, f in pairs(self.frames) do
        local cfg = self.db.blocks[key]
        if f:IsShown() and cfg and cfg.strata ~= STRATA.behind then return "front" end
    end
    return next(self.frames) and "behind" or "front"
end

-- Placement mode: every block in front or behind for a while (nothing saved)
function ns:ToggleTempLayer()
    if InCombatLockdown() then return end
    self.tempStrata = self:LayerShown() == "front" and STRATA.behind or STRATA.front
    self:ApplyLayers()
    if self.UpdatePlacementBanner then self:UpdatePlacementBanner() end
end

-- Saves a layer for some groups (roots = set of root keys) or for every block
function ns:SetLayer(layer, roots)
    local strata = STRATA[layer]
    if not strata then return end
    for key, cfg in pairs(self.db.blocks) do
        if not roots or roots[self:GetRoot(key)] then cfg.strata = strata end
    end
    if not roots then
        self.db.groupDefaults = self.db.groupDefaults or {}
        self.db.groupDefaults.strata = strata
    end
    self.tempStrata = nil
    self:ApplyLayers()
    self.Print(layer == "front" and L.LAYER_DONE_FRONT or L.LAYER_DONE_BEHIND)
    if self.RefreshOptions then self:RefreshOptions() end
end

-- After locking or applying a layout: blocks over Blizzard frames? Ask which layer to
-- keep, once for the same situation (force: ask even if already answered)
function ns:AskLayer(force)
    if not self.db or self.brokerModeActive or (self.IsDemoActive and self:IsDemoActive()) then return end
    if InCombatLockdown() then return end
    local labels, covering, signature = self:GetCoveredFrames()
    if #labels == 0 then return end
    if not force and self.db.layerAsked == signature then return end
    self.db.layerAsked = signature
    StaticPopup_Show("TESSERA_LAYER", table.concat(labels, ", "), nil, covering)
end

-- When the blocks are locked: the temporary layer ends, then the question
function ns:OnBlocksLocked()
    if self.tempStrata then
        self.tempStrata = nil
        self:ApplyLayers()
    end
    C_Timer.After(0.3, function() ns:AskLayer() end)
end

-- Blizzard's Edit Mode: a small button under its window (above it when the window is
-- near the bottom of the screen), never over it. Same switch as the placement banner;
-- closing Edit Mode ends it and asks which layer to keep.
local emButton
function ns:ShowEditModeLayerButton(show)
    local em = EditModeManagerFrame
    if not show or not em or self.brokerModeActive or InCombatLockdown() then
        if emButton then emButton:Hide() end
        return
    end
    if not emButton then
        emButton = CreateFrame("Button", "TesseraEditModeLayerButton", UIParent, "UIPanelButtonTemplate")
        emButton:SetSize(170, 24)
        emButton:SetScript("OnClick", function()
            ns:ToggleTempLayer()
            ns:ShowEditModeLayerButton(true)
        end)
        emButton:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
            GameTooltip:SetText(L.LAYER_TOGGLE)
            GameTooltip:AddLine(L.TIP_LAYER_TOGGLE, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        emButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    emButton:SetFrameStrata(em.GetFrameStrata and em:GetFrameStrata() or "DIALOG")
    emButton:SetFrameLevel((em.GetFrameLevel and em:GetFrameLevel() or 1) + 5)
    emButton:ClearAllPoints()
    if ((em.GetBottom and em:GetBottom()) or 100) > 40 then
        emButton:SetPoint("TOP", em, "BOTTOM", 0, -4)
    else
        emButton:SetPoint("BOTTOM", em, "TOP", 0, 4)
    end
    emButton:SetText(self:LayerShown() == "behind" and L.LAYER_BEHIND_STATE or L.LAYER_FRONT_STATE)
    emButton:Show()
end

StaticPopupDialogs["TESSERA_LAYER"] = {
    text = L.LAYER_ASK,
    button1 = L.LAYER_FRONT,
    button2 = L.LAYER_BEHIND,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false, -- a real choice: one of the two buttons
    OnAccept = function(_, covering) ns:SetLayer("front", covering) end,
    OnCancel = function(_, covering, reason)
        if reason == "clicked" then ns:SetLayer("behind", covering) end
    end,
}

---------------------------------------------------------------------------
-- Edit Mode copies made by older test versions
---------------------------------------------------------------------------
-- A copy made by Tessera, unchanged since (saved fingerprint, never the name alone)
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
    local text, h = table.concat(parts, "|"), 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
    return ("%08x"):format(h)
end
ns.EditModeFingerprint = Fingerprint

local function IsOurCopy(layout)
    local saved = layout and ns.sv.editModeCopies and ns.sv.editModeCopies[layout.layoutName]
    return saved ~= nil and saved.layoutType == layout.layoutType and saved.fingerprint == Fingerprint(layout)
end

-- Name of the active Edit Mode layout (bug report)
function ns:GetEditModeStatus()
    local state = ReadLayouts()
    if not (state and state.active) then return "unavailable" end
    return ("%s%s"):format(tostring(state.active.layoutName), IsOurCopy(state.active) and " (Tessera copy)" or "")
end

-- Forgets everything about the copies (they become ordinary layouts of the player)
local function ForgetCopies()
    ns.sv.editModeCopies, ns.sv.editModeOriginal = nil, nil
    for _, profile in pairs(ns.sv.profiles or {}) do
        if type(profile) == "table" then profile.editModeLayout = nil end
    end
end

-- Deletes Tessera's unchanged copies that are not active
local function DeleteCopies()
    local state = ReadLayouts()
    if not state then return end
    local activeLayout = state.activeIndex > #state.presets and state.info.layouts[state.activeIndex - #state.presets]
    local kept, removed = {}, 0
    for _, layout in ipairs(state.info.layouts) do
        if layout ~= activeLayout and IsOurCopy(layout) then
            removed = removed + 1
        else
            table.insert(kept, layout)
        end
    end
    if removed == 0 then return end
    state.info.layouts = kept
    for i, layout in ipairs(kept) do
        if layout == activeLayout then state.info.activeLayout = #state.presets + i end
    end
    pcall(C_EditMode.SaveLayouts, state.info)
end

-- Back to the layout the active copy was made from, then the copies are deleted
function ns:LeaveEditModeCopy()
    if InCombatLockdown() then return end
    local original = self.sv.editModeOriginal
    local state = ReadLayouts()
    if original and state then
        local index
        if original.layoutType == Enum.EditModeLayoutType.Preset then
            for i, layout in ipairs(state.presets) do
                if layout.layoutName == original.name then index = i end
            end
        else
            for i, layout in ipairs(state.info.layouts) do
                if layout.layoutName == original.name and layout.layoutType == original.layoutType then
                    index = #state.presets + i
                end
            end
        end
        if index then pcall(C_EditMode.SetActiveLayout, index) end
    end
    C_Timer.After(0.5, function()
        DeleteCopies()
        ForgetCopies()
    end)
end

StaticPopupDialogs["TESSERA_EDITMODE_LEGACY"] = {
    text = L.EDITMODE_LEGACY,
    button1 = L.EDITMODE_REVERT,
    button2 = L.EDITMODE_KEEP_LAYOUT,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
    OnAccept = function() ns:LeaveEditModeCopy() end,
    OnCancel = function(_, _, reason)
        if reason == "clicked" then
            DeleteCopies()
            ForgetCopies()
        end
    end,
}

-- At login: copies left by an older test version. On a copy: offer to go back to
-- the player's layout. Copies not in use are deleted (unchanged ones only).
function ns:CheckEditModeCopies()
    if not (self.sv and self.sv.editModeCopies and next(self.sv.editModeCopies)) then return end
    if InCombatLockdown() then return end
    local state = ReadLayouts()
    if not state then return end
    if state.active and IsOurCopy(state.active) and self.sv.editModeOriginal then
        StaticPopup_Show("TESSERA_EDITMODE_LEGACY", self.sv.editModeOriginal.name)
    else
        DeleteCopies()
        ForgetCopies()
    end
end
