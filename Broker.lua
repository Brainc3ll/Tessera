local _, ns = ...
local L = ns.L

-- ========================================================================
-- Broker.lua: LibDataBroker (DataBroker) support
-- ========================================================================
-- DataBroker is the common format addons use to share a small piece of data
-- ("data source": a text, an icon, a tooltip) or a button ("launcher"). Display
-- addons such as Titan Panel, ChocolateBar or Bazooka show these objects in bars.
-- Tessera never embeds the library: it uses the copy another addon loaded
-- (LibStub("LibDataBroker-1.1")), which may appear after Tessera itself.
--
-- This file does three things:
--   1. Consumer: the player adds another addon's data object as a Tessera block
--      (Launchers tab, "Add a DataBroker block"). These blocks use keys
--      "broker:<object name>" and share ns.brokerModule. Like launchers they store
--      only the object's name and look it up each time, so a block whose addon is
--      disabled keeps its settings and simply hides (shown as "missing" while
--      placing blocks).
--   2. Publisher: Tessera's own data blocks published as data objects named
--      "Tessera_<block key>" (plus a "Tessera" launcher that opens the options),
--      so display addons can show them. Only blocks with cfg.brokerShare are
--      published. The library has no way to remove an object: unsharing a block
--      empties its text, and it disappears after a /reload.
--   3. DataBroker mode: when a display addon is loaded, Tessera shows no block of
--      its own and its options only offer what concerns the published objects.
--      The player can leave this mode (sv.brokerMode = false) and use both.
--
-- Data object fields used (LibDataBroker-1.1 specification): type, text, value,
-- suffix, label, icon, iconCoords, iconR/G/B, tooltip (a frame), OnTooltipShow,
-- OnEnter, OnLeave, OnClick, tocname.

local OWN_PREFIX = "Tessera_" -- names of the objects Tessera publishes
local OWN_LAUNCHER = "Tessera"

-- Display addons that switch Tessera to DataBroker mode: { folder name, shown name }
local DISPLAYS = {
    { "Titan", "Titan Panel" }, { "ChocolateBar", "ChocolateBar" }, { "Bazooka", "Bazooka" },
    { "ButtonBin", "ButtonBin" }, { "Fortress", "Fortress" }, { "NinjaPanel", "Ninja Panel" },
    { "DockingStation", "DockingStation" }, { "StatBlockCore", "StatBlock" },
    { "Broker2FuBar", "Broker2FuBar" },
}

-- The library, when a loaded addon provides it
local function LDB()
    return LibStub and LibStub("LibDataBroker-1.1", true)
end
ns.GetLDB = LDB

local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

-- Values given by other addons may be anything, even secret values: read safely
local function SafeString(v)
    if v == nil then return nil end
    local ok, s = pcall(tostring, v)
    if ok and type(s) == "string" then return s end
end

local function IsOwnObject(name, obj)
    if name == OWN_LAUNCHER or (type(name) == "string" and name:sub(1, #OWN_PREFIX) == OWN_PREFIX) then
        return true
    end
    local ok, toc = pcall(function() return obj.tocname end)
    return ok and toc == "Tessera"
end

-- Readable name of the addon that owns an object (its TOC title), or nil
local function AddonTitle(obj)
    local ok, toc = pcall(function() return obj.tocname end)
    if not ok or type(toc) ~= "string" then return nil end
    local okTitle, title = false, nil
    if GetMetadata then okTitle, title = pcall(GetMetadata, toc, "Title") end
    if not okTitle then title = nil end
    title = ns.StripText(type(title) == "string" and title or toc)
    return title ~= "" and title or toc
end

-- The data object of a DataBroker block, or nil when its addon is not loaded
local function Resolve(cfg)
    local lib, b = LDB(), cfg and cfg.broker
    if not (lib and b and type(b.name) == "string") then return nil end
    return lib:GetDataObjectByName(b.name)
end

---------------------------------------------------------------------------
-- 1. Consumer: other addons' objects as blocks
---------------------------------------------------------------------------
-- Is this data object already placed, as a DataBroker block or a LibDBIcon launcher?
function ns:IsBrokerObjectPlaced(obj)
    for key, cfg in pairs(self.db.blocks) do
        if ns.IsBrokerKey(key) and Resolve(cfg) == obj then return true end
    end
    return false
end

local function PlacedAsLauncher(obj)
    for key, cfg in pairs(ns.db.blocks) do
        if ns.IsLauncherKey(key) and ns:GetLauncherDataObject(cfg) == obj then return true end
    end
    return false
end

-- Every data object of other addons that can be added: { key, name, label, kind, addon },
-- sorted by label. Objects already placed (here or as a minimap launcher) are left out.
function ns:GetBrokerSources()
    local list, lib = {}, LDB()
    if not lib then return list end
    for name, obj in lib:DataObjectIterator() do
        local key = ns.BROKER_PREFIX .. tostring(name)
        if type(name) == "string" and not IsOwnObject(name, obj) and not self.db.blocks[key]
            and not PlacedAsLauncher(obj) then
            local label = ns.StripText(SafeString(obj.label) or "")
            local kind = obj.type == "launcher" and "launcher" or "data source"
            table.insert(list, { key = key, name = name, label = label ~= "" and label or name,
                kind = kind, addon = AddonTitle(obj) })
        end
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end

-- Creates the block for a source (if it does not exist yet) and returns its key
function ns:AddBroker(entry)
    if not self.db.blocks[entry.key] then
        local cfg = self:GetBlockDefaults(entry.key)
        cfg.broker = { name = entry.name, label = entry.label, kind = entry.kind, addon = entry.addon }
        -- a launcher-type object: icon and name, like the other launchers
        if entry.kind == "launcher" then cfg.showLabel = true end
        self.db.blocks[entry.key] = cfg
    end
    self:RefreshAllBlocks()
    return entry.key
end

-- Deletes a DataBroker block and its saved settings
function ns:RemoveBroker(key)
    if not ns.IsBrokerKey(key) then return end
    self:DetachChildren(key)
    self.db.blocks[key] = nil
    if self.frames[key] then self.frames[key]:Hide() end
    self:RefreshAllBlocks()
end

local function SimpleTooltip(owner, cfg)
    ns.AnchorTooltip(owner)
    GameTooltip:AddLine(cfg.broker.label or cfg.broker.name, 1, 1, 1)
    if not Resolve(cfg) then GameTooltip:AddLine(L.BROKER_MISSING_TIP, 1, 0.3, 0.3, true) end
    GameTooltip:Show()
end

-- Module shared by all DataBroker blocks; every callback looks the object up again
ns.brokerModule = {
    defaults = { hideEmpty = true },
    forced = { colorize = false },

    -- the addon is not loaded: the block hides (its settings are kept)
    isEmpty = function(cfg) return Resolve(cfg) == nil end,

    -- the object's text, or its value and unit; nothing for a launcher
    update = function(cfg)
        local obj = Resolve(cfg)
        if not obj then return L.BROKER_MISSING, 3 end
        local label = ns.StripText(SafeString(obj.label) or "")
        if label ~= "" then cfg.broker.label = label end
        cfg.broker.kind = obj.type == "launcher" and "launcher" or "data source"
        if cfg.broker.kind == "launcher" then return "" end
        local text = SafeString(obj.text)
        if text == nil and obj.value ~= nil then
            text = SafeString(obj.value) or ""
            local suffix = SafeString(obj.suffix)
            if suffix and suffix ~= "" then text = text .. " " .. suffix end
        end
        return text or ""
    end,

    getIcon = function(cfg)
        local obj = Resolve(cfg)
        if not obj then return "Interface\\Icons\\INV_Misc_QuestionMark" end
        return ns.IconFromValue(obj.icon, obj)
    end,

    -- every click goes to the other addon, as on its own button
    onClick = function(self, button, cfg)
        local obj = Resolve(cfg)
        if obj and obj.OnClick then obj.OnClick(self, button) end
    end,

    -- the three ways an object can provide a tooltip: a ready-made frame, a
    -- function that fills the game tooltip, or its own OnEnter handler
    customTooltip = function(self, cfg)
        local obj = Resolve(cfg)
        if not obj then return SimpleTooltip(self, cfg) end
        local tip = obj.tooltip
        if type(tip) == "table" and tip.Show and tip.ClearAllPoints then
            -- only placed next to the block: SetOwner would clear a tooltip the addon filled
            if tip == GameTooltip then
                ns.AnchorTooltip(self, tip)
            else
                ns.MoveTooltip(self, tip)
            end
            tip:Show()
            self.brokerTip = tip
        elseif obj.OnTooltipShow then
            ns.AnchorTooltip(self)
            obj.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        elseif obj.OnEnter then
            obj.OnEnter(self)
        else
            SimpleTooltip(self, cfg)
        end
    end,

    onLeave = function(self, cfg)
        if self.brokerTip then
            self.brokerTip:Hide()
            self.brokerTip = nil
        end
        local obj = Resolve(cfg)
        if obj and obj.OnLeave then obj.OnLeave(self) end
    end,
}

-- Changes reported by the library are grouped: an object that changes many times a
-- second (an FPS counter...) updates its block at most ten times a second
local dirty, flushPending = {}, false
local function Flush()
    flushPending = false
    for key in pairs(dirty) do
        if ns.db.blocks[key] and ns.frames[key] then
            ns:UpdateVisibility(key)
            ns:UpdateBlock(key)
        end
    end
    wipe(dirty)
end

local function MarkDirty(name)
    local key = ns.BROKER_PREFIX .. tostring(name)
    if not (ns.db and ns.db.blocks[key]) then return end
    dirty[key] = true
    if not flushPending then
        flushPending = true
        C_Timer.After(0.1, Flush)
    end
end

---------------------------------------------------------------------------
-- 2. Publisher: Tessera's blocks as data objects
---------------------------------------------------------------------------
local published = {}   -- block key -> data object
local lastText = {}    -- block key -> published text (for Shift + click)
local pubDirty = {}    -- block keys to refresh at the next tick
local nextRun = {}
local pubEvents = {}   -- event -> block keys
local pubFrame = CreateFrame("Frame")
local launcherObj

-- Is this block published right now?
function ns:IsPublished(key)
    return published[key] ~= nil and self:IsSharing() and self.db.blocks[key] and self.db.blocks[key].brokerShare
end

-- Publishing is on in DataBroker mode, or when the player asked for it
function ns:IsSharing()
    return LDB() ~= nil and self.sv ~= nil and (self.brokerModeActive or self.sv.brokerShare == true)
end

-- True when a published block is no longer shared: it only disappears after a /reload
function ns:BrokerNeedsReload()
    for key in pairs(published) do
        local cfg = self.db.blocks[key]
        if not (self:IsSharing() and cfg and cfg.brokerShare) then return true end
    end
    return false
end

-- Text of a published block: the module's value, colored like the block
local function ComputeText(key)
    local mod, cfg = ns.modules[key], ns.db.blocks[key]
    if mod.isEmpty and cfg.hideEmpty then
        local ok, empty = pcall(mod.isEmpty, cfg)
        if ok and empty then return "" end
    end
    local ok, value, level = pcall(mod.update, cfg, key)
    if not ok or value == nil then value, level = L.NA, nil end
    value = SafeString(value) or L.NA
    if cfg.colorize and level and ns.LEVEL_COLORS[level] and value ~= "" then
        value = "|cff" .. ns.LEVEL_COLORS[level] .. value .. "|r"
    end
    return value
end

local function RefreshPublished(key)
    local obj, mod = published[key], ns.modules[key]
    local cfg = ns.db.blocks[key]
    if not (obj and mod and cfg) then return end
    if not (ns:IsSharing() and cfg.brokerShare) then
        obj.text = "" -- objects cannot be removed: emptied until the next /reload
        return
    end
    local text = ComputeText(key)
    lastText[key] = text
    obj.text = text -- the library only notifies displays when the value changes
    local okIcon, icon = pcall(function() return mod.getIcon and mod.getIcon(cfg) or mod.icon end)
    if okIcon and icon then
        if type(icon) == "table" then
            if icon.file then
                obj.icon = icon.file
                obj.iconCoords = icon.coords
            end
        else
            obj.icon = icon
        end
    end
end

-- Tooltip of a published block, filled like the block's own tooltip
local function PublishedTooltip(key, tt)
    local mod, cfg = ns.modules[key], ns.db.blocks[key]
    tt:AddLine(ns:GetBlockName(key), 1, 0.82, 0)
    if mod.tooltip then pcall(mod.tooltip, tt, cfg) end
    if ns.db.tooltipHints ~= false then
        tt:AddLine(" ")
        if mod.onClick and mod.clickHint then
            tt:AddLine(mod.clickHint, 0.5, 0.8, 1)
        elseif mod.secureMacro then
            tt:AddLine(L.BROKER_HINT_NO_CLICK, 0.6, 0.6, 0.6) -- needs Tessera's secure buttons
        end
        tt:AddLine(L.HINT_SHIFT_ACTION:format(L.ACTION_CHAT), 0.5, 0.8, 1)
        tt:AddLine(L.BROKER_HINT_SETTINGS, 0.5, 0.8, 1)
    end
end

-- Clicks on a published block. Blocks that open a Blizzard window cannot do it from
-- here: that needs Tessera's secure buttons, which only exist on its own blocks.
local function PublishedClick(key, frame, button)
    local mod, cfg = ns.modules[key], ns.db.blocks[key]
    if button == "RightButton" then
        if ns.OpenOptionsFor then ns:OpenOptionsFor(key) end
    elseif button == "LeftButton" and IsShiftKeyDown() then
        ns.InsertInChat(ns:GetChatText(key, ns.StripText(lastText[key] or "")))
    elseif button == "LeftButton" and mod.onClick then
        pcall(mod.onClick, frame, button, cfg)
        pubDirty[key] = true
    end
end

local function Publish(key)
    local lib, mod = LDB(), ns.modules[key]
    if published[key] or not (lib and mod) then return end
    local name = OWN_PREFIX .. key
    local obj = lib:GetDataObjectByName(name) or lib:NewDataObject(name, {
        type = "data source",
        label = ns:GetBlockName(key),
        text = "",
        icon = type(mod.icon) ~= "table" and mod.icon or nil,
        tocname = "Tessera",
        OnTooltipShow = function(tt) PublishedTooltip(key, tt) end,
        OnClick = function(frame, button) PublishedClick(key, frame, button) end,
    })
    if not obj then return end
    published[key] = obj
    for _, event in ipairs(mod.events or {}) do
        if not pubEvents[event] then
            pubEvents[event] = {}
            pcall(pubFrame.RegisterEvent, pubFrame, event)
        end
        table.insert(pubEvents[event], key)
    end
    pubDirty[key] = true
end

pubFrame:SetScript("OnEvent", function(_, event)
    for _, key in ipairs(pubEvents[event] or {}) do pubDirty[key] = true end
end)

-- Creates the objects of the shared blocks (and the "Tessera" launcher), empties
-- the others. Called at login and whenever sharing settings change.
function ns:UpdatePublishing()
    local lib = LDB()
    if not (lib and self.db) then return end
    if self:IsSharing() then
        if not launcherObj then
            launcherObj = lib:GetDataObjectByName(OWN_LAUNCHER) or lib:NewDataObject(OWN_LAUNCHER, {
                type = "launcher",
                label = "Tessera",
                icon = "Interface\\AddOns\\Tessera\\Media\\Icon.png",
                tocname = "Tessera",
                OnClick = function() ns:ToggleOptions() end,
                OnTooltipShow = function(tt)
                    tt:AddLine("Tessera", 1, 0.82, 0)
                    tt:AddLine(L.BROKER_LAUNCHER_HINT, 0.5, 0.8, 1)
                end,
            })
        end
        for _, key in ipairs(self.order) do
            local cfg = self.db.blocks[key]
            if cfg and cfg.brokerShare then Publish(key) end
        end
    end
    for key in pairs(published) do pubDirty[key] = true end
end

-- One timer for every published block, each at its module's pace (event-driven
-- modules are also refreshed every 10 s, in case an event was missed)
C_Timer.NewTicker(0.5, function()
    if not ns.built or not next(published) then return end
    local now = GetTime()
    for key in pairs(published) do
        local mod = ns.modules[key]
        local interval = mod.interval or 10
        if pubDirty[key] or now >= (nextRun[key] or 0) then
            pubDirty[key] = nil
            nextRun[key] = now + interval
            RefreshPublished(key)
        end
    end
end)

---------------------------------------------------------------------------
-- 3. DataBroker mode
---------------------------------------------------------------------------
-- Name of the first loaded display addon, or nil
function ns:DetectBrokerDisplay()
    if not IsLoaded then return nil end
    for _, d in ipairs(DISPLAYS) do
        local ok, loaded = pcall(IsLoaded, d[1])
        if ok and loaded then return d[2] end
    end
end

-- Recomputes ns.brokerModeActive: on when a display addon is loaded (or the player
-- turned it on), unless the player turned it off. Never on without the library.
function ns:RefreshBrokerMode()
    local sv = self.sv or {}
    local active = LDB() ~= nil and sv.brokerMode ~= false
        and (sv.brokerMode == true or self.brokerDisplay ~= nil)
    local changed = (active and true or false) ~= (self.brokerModeActive and true or false)
    -- in combat, the secure click buttons of blocks cannot be hidden: wait for the end
    -- (not for the first decision at login: no secure button exists yet)
    if changed and self.built and self.brokerModeActive ~= nil and InCombatLockdown() then
        self.brokerRefreshPending = true
        return false
    end
    self.brokerRefreshPending = nil
    self.brokerModeActive = active and true or false
    if changed and self.built then
        self:UpdatePublishing()
        self:RefreshLockState()
        if self.ApplyOptionsMode then self:ApplyOptionsMode() end
        if self.RefreshOptions then self:RefreshOptions() end
    end
    return changed
end

-- Turns DataBroker mode on or off (button in the options, /tessera broker)
function ns:SetBrokerMode(on)
    if on and not LDB() then
        ns.Print(L.BROKER_NO_LIBRARY)
        return
    end
    self.sv.brokerMode = on and true or false
    self.brokerRequested = true -- the end-of-combat message is only for a change the player asked for
    self:RefreshBrokerMode()
    self:UpdatePublishing()
    if self.brokerRefreshPending then
        ns.Print(L.BROKER_AFTER_COMBAT)
    else
        self.brokerRequested = nil -- applied at once: nothing to announce after combat
        ns.Print(on and L.BROKER_MODE_ENABLED or L.BROKER_MODE_DISABLED)
    end
    if self.RefreshOptions then self:RefreshOptions() end
end

-- (while a change waits for the end of combat, toggles the requested state)
function ns:ToggleBrokerMode()
    local current = self.brokerModeActive
    if self.brokerRefreshPending then current = self.sv.brokerMode ~= false end
    self:SetBrokerMode(not current)
end

-- Listens to the library's notifications (once it is loaded, possibly late)
local hooked = false
local consumer = {}
local function Hook()
    local lib = LDB()
    if hooked or not lib then return end
    hooked = true
    lib.RegisterCallback(consumer, "LibDataBroker_AttributeChanged", function(_, name) MarkDirty(name) end)
    lib.RegisterCallback(consumer, "LibDataBroker_DataObjectCreated", function(_, name)
        MarkDirty(name) -- a block waiting for its addon's object comes back
        if ns.RefreshOptions then ns:RefreshOptions() end
    end)
    -- blocks already waiting for objects created before the hook
    for key in pairs(ns.db.blocks) do
        if ns.IsBrokerKey(key) then MarkDirty(key:sub(#ns.BROKER_PREFIX + 1)) end
    end
end

-- Called by Core.lua at login, once the profile is loaded
function ns:InitBroker()
    self.brokerDisplay = self:DetectBrokerDisplay()
    Hook()
    self:RefreshBrokerMode()
    self:UpdatePublishing()
    self:NotifyBrokerModeIfNeeded()
end

-- Explained once (popup), the first time a display addon turns DataBroker mode on by itself.
-- The popup marks itself as seen when it shows (sv.brokerModeNotified, see Options.lua),
-- so a /reload before it appears does not lose it.
local notifyScheduled = false
local function WantsNotice()
    return ns.brokerModeActive and ns.sv.brokerMode == nil and not ns.sv.brokerModeNotified
end
function ns:NotifyBrokerModeIfNeeded()
    if notifyScheduled or not WantsNotice() then return end
    notifyScheduled = true
    -- a few seconds after login, once the screen has settled
    C_Timer.After(5, function()
        notifyScheduled = false
        if WantsNotice() then StaticPopup_Show("TESSERA_BROKER_MODE", ns.brokerDisplay or "DataBroker") end
    end)
end

-- An addon loaded after login may bring the library (and display addons load-on-demand)
-- (also: a mode change delayed by combat is applied when combat ends)
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:SetScript("OnEvent", function(_, event)
    if not ns.built then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if ns.brokerRefreshPending then
            ns:RefreshBrokerMode()
            if ns.brokerRequested then
                ns.Print(ns.brokerModeActive and L.BROKER_MODE_ENABLED or L.BROKER_MODE_DISABLED)
            end
            ns:NotifyBrokerModeIfNeeded()
        end
        ns.brokerRequested = nil
        return
    end
    Hook()
    ns.brokerDisplay = ns:DetectBrokerDisplay()
    ns:RefreshBrokerMode() -- the display addon, or the library itself, may have just arrived
    ns:NotifyBrokerModeIfNeeded()
    if ns:IsSharing() then ns:UpdatePublishing() end
end)
