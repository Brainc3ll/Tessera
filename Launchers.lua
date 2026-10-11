local ADDON, ns = ...
local L = ns.L

-- Launcher blocks
-- A launcher block copies the icon, name, tooltip and click action of another addon's
-- minimap button or addon-compartment entry, so it can be placed anywhere on screen.
-- Sources:
--   "libdbicon"   standard minimap buttons (LibDBIcon), read through their data object
--   "frame"       other buttons placed on the minimap, used as they are
--   "compartment" entries in Blizzard's addon compartment (the minimap addon menu)
-- Launchers store only the source name and look it up again each time (see Resolve),
-- because the original buttons may be created late or disappear when an addon is disabled.

-- Name patterns of minimap buttons that belong to the game (or FlareUI) and are not launchers
local SKIP = {
    "^Minimap", "^MiniMap", "^GameTime", "^TimeManager", "^QueueStatus", "^Expansion",
    "^GarrisonLandingPage", "^AddonCompartment", "^HybridMinimap", "^LibDBIcon10_", "^FlareUI", "^Tessera",
}

-- Decorative minimap button textures (frames, backgrounds), never the actual icon
local DECOR = { "border", "background", "highlight", "trackingborder" }
local DECOR_IDS = { [136430] = true, [136467] = true } -- MiniMap-TrackingBorder, UI-Minimap-Background

-- Removes color codes and inline textures/atlases from a label
local function StripText(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return strtrim(s)
end
ns.StripText = StripText -- also used by Broker.lua

-- Returns LibDBIcon if any loaded addon ships it, otherwise nil
local function LibDBIcon()
    return LibStub and LibStub("LibDBIcon-1.0", true)
end

-- Data object behind a LibDBIcon launcher block (nil for other launchers), so
-- Broker.lua can avoid offering the same object twice
function ns:GetLauncherDataObject(cfg)
    local l = cfg and cfg.launcher
    if not (l and l.kind == "libdbicon") then return nil end
    local lib = LibDBIcon()
    local button = lib and lib.GetMinimapButton and lib:GetMinimapButton(l.source)
    return button and button.dataObject
end

-- Entries registered in Blizzard's addon compartment (empty list if unavailable)
local function CompartmentEntries()
    return AddonCompartmentFrame and AddonCompartmentFrame.registeredAddons or {}
end

-- True for an icon-sized, unprotected, named button that is not on the SKIP list
local function IsForeignButton(frame)
    if not (frame and frame.IsObjectType and frame:IsObjectType("Button")) then return false end
    if frame:IsForbidden() or frame:IsProtected() then return false end
    local name = frame:GetName()
    if not name then return false end
    for _, pattern in ipairs(SKIP) do
        if name:find(pattern) then return false end
    end
    local w, h = frame:GetSize()
    return (w or 0) > 8 and (w or 0) <= 48 and (h or 0) > 8 and (h or 0) <= 48
end

-- Builds a readable name: "MyAddonMinimapButton" -> "MyAddon"
local function NiceFrameName(name)
    local nice = name:gsub("_?[Mm]ini[Mm]ap_?", ""):gsub("_?[Bb]utton_?", ""):gsub("_", " ")
    nice = strtrim(nice)
    return nice ~= "" and nice or name
end

---------------------------------------------------------------------------
-- Available sources (for the "Add a launcher block" menu)
---------------------------------------------------------------------------
-- Returns every launchable source, deduplicated by key and by label, sorted by label
function ns:GetLauncherSources()
    local list, seenIds, seenLabels = {}, {}, {}
    local function Add(kind, source, label)
        local key = ns.LAUNCHER_PREFIX .. kind .. ":" .. source
        if seenIds[key] or seenLabels[label:lower()] then return end
        seenIds[key], seenLabels[label:lower()] = true, true
        table.insert(list, { key = key, kind = kind, source = source, label = label })
    end

    local lib = LibDBIcon()
    if lib and lib.GetButtonList then
        for _, name in ipairs(lib:GetButtonList() or {}) do
            local button = lib:GetMinimapButton(name)
            local obj = button and button.dataObject
            -- the same data object already placed as a DataBroker block: not twice
            if not (obj and ns.IsBrokerObjectPlaced and ns:IsBrokerObjectPlaced(obj)) then
                local label = StripText(obj and (obj.label or obj.text) or "")
                Add("libdbicon", name, label ~= "" and label or name)
            end
        end
    end

    -- Buttons placed on the minimap (or stored in FlareUI's minimap button bag)
    for _, parent in ipairs({ Minimap, MinimapCluster, _G.FlareUI_MinimapBag }) do
        if parent and parent.GetChildren then
            for _, child in ipairs({ parent:GetChildren() }) do
                if IsForeignButton(child) then
                    Add("frame", child:GetName(), NiceFrameName(child:GetName()))
                end
            end
        end
    end

    for _, data in ipairs(CompartmentEntries()) do
        local label = StripText(data.text)
        if label ~= "" and label ~= "Tessera" then
            Add("compartment", label, label)
        end
    end

    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end

-- Creates the launcher block for a source (if it does not exist yet) and returns its key
function ns:AddLauncher(entry)
    if not self.db.blocks[entry.key] then
        local cfg = self:GetBlockDefaults(entry.key)
        cfg.launcher = { kind = entry.kind, source = entry.source, label = entry.label }
        self.db.blocks[entry.key] = cfg
    end
    self:RefreshAllBlocks()
    return entry.key
end

-- Deletes a launcher block and its saved settings
function ns:RemoveLauncher(key)
    if not ns.IsLauncherKey(key) then return end
    self:DetachChildren(key)
    self.db.blocks[key] = nil
    if self.frames[key] then self.frames[key]:Hide() end
    self:RefreshAllBlocks()
end

---------------------------------------------------------------------------
-- Resolving a launcher to its current source
---------------------------------------------------------------------------
-- Returns: button, data object (libdbicon), compartment entry
local function Resolve(cfg)
    local l = cfg.launcher
    if not l then return end
    if l.kind == "libdbicon" then
        local lib = LibDBIcon()
        local button = lib and lib:GetMinimapButton(l.source)
        return button, button and button.dataObject
    elseif l.kind == "frame" then
        -- only real minimap buttons of other addons (an imported profile could name anything)
        local frame = type(l.source) == "string" and _G[l.source]
        if frame and IsForeignButton(frame) then return frame end
    elseif l.kind == "compartment" then
        for _, data in ipairs(CompartmentEntries()) do
            if StripText(data.text) == l.source then return nil, nil, data end
        end
    end
end

-- Is the minimap button behind this launcher present? (checked on import)
function ns:IsLauncherAvailable(cfg)
    if type(cfg) ~= "table" or type(cfg.launcher) ~= "table" or type(cfg.launcher.source) ~= "string" then
        return false
    end
    local ok, a, b, c = pcall(Resolve, cfg)
    return ok and (a or b or c) ~= nil
end

-- Converts an icon value (atlas name, file path or file ID) into the block icon format
local function IconFromValue(icon, extra)
    if not icon then return nil end
    if type(icon) == "string" and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(icon) then
        return { atlas = icon }
    end
    local result = { file = icon }
    if extra then
        result.coords = extra.iconCoords
        if extra.iconR then result.color = { extra.iconR, extra.iconG, extra.iconB } end
    end
    return result
end
ns.IconFromValue = IconFromValue -- also used by Broker.lua

-- True if a texture is minimap button decoration rather than the icon
local function IsDecor(tex)
    local file = tex:GetTexture()
    if type(file) == "number" and DECOR_IDS[file] then return true end
    if type(file) == "string" then
        local lower = file:lower()
        for _, word in ipairs(DECOR) do
            if lower:find(word, 1, true) then return true end
        end
    end
    local atlas = tex.GetAtlas and tex:GetAtlas()
    if atlas then
        local lower = atlas:lower()
        for _, word in ipairs(DECOR) do
            if lower:find(word, 1, true) then return true end
        end
    end
    return false
end

-- Copies a texture's atlas, or its file, coordinates and color, into the block icon format
local function IconFromTexture(tex)
    if not tex or not tex.GetTexture then return nil end
    local atlas = tex.GetAtlas and tex:GetAtlas()
    if atlas then return { atlas = atlas } end
    local file = tex:GetTexture()
    if not file then return nil end
    local r, g, b = tex:GetVertexColor()
    return { file = file, coords = { tex:GetTexCoord() }, color = { r, g, b } }
end

-- Finds the icon of any button: a known field, then the normal texture, then the first non-decorative texture
local function FrameIcon(frame)
    for _, field in ipairs({ "icon", "Icon", "texture", "Texture" }) do
        local tex = frame[field]
        if type(tex) == "table" and tex.GetObjectType and tex:GetObjectType() == "Texture" and not IsDecor(tex) then
            local icon = IconFromTexture(tex)
            if icon then return icon end
        end
    end
    local normal = frame.GetNormalTexture and frame:GetNormalTexture()
    if normal and not IsDecor(normal) then
        local icon = IconFromTexture(normal)
        if icon then return icon end
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "Texture" and region:GetDrawLayer() ~= "HIGHLIGHT" and not IsDecor(region) then
            local icon = IconFromTexture(region)
            if icon then return icon end
        end
    end
end

---------------------------------------------------------------------------
-- Module shared by all launcher blocks
---------------------------------------------------------------------------
-- Fallback tooltip that only shows the launcher's name
local function SimpleTooltip(owner, cfg)
    ns.AnchorTooltip(owner)
    GameTooltip:AddLine(cfg.launcher.label, 1, 1, 1)
    GameTooltip:Show()
end

-- Each callback resolves the source again and forwards to it
ns.launcherModule = {
    -- Block text: empty when the source exists (refreshing the saved label), else a "missing" warning
    update = function(cfg)
        local frame, obj, data = Resolve(cfg)
        if not frame and not data then return L.LAUNCHER_MISSING, 3 end
        if obj then
            local label = StripText(obj.label or "")
            if label ~= "" then cfg.launcher.label = label end
        end
        return ""
    end,

    -- Icon taken from the source, or a question mark if nothing is found
    getIcon = function(cfg)
        local frame, obj, data = Resolve(cfg)
        if obj then return IconFromValue(obj.icon, obj) end
        if data then return IconFromValue(data.icon) end
        if frame then return FrameIcon(frame) end
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end,

    -- Passes the click on to the source, as if the original button had been clicked
    onClick = function(self, button, cfg)
        local frame, obj, data = Resolve(cfg)
        if obj then
            if obj.OnClick then obj.OnClick(self, button) end
        elseif data then
            if data.func then data.func(data, { buttonName = button }, nil) end
        elseif frame then
            if frame:GetScript("OnClick") then
                frame:Click(button)
            elseif frame:GetScript("OnMouseUp") then
                frame:GetScript("OnMouseUp")(frame, button)
            elseif frame:GetScript("OnMouseDown") then
                frame:GetScript("OnMouseDown")(frame, button)
            end
        end
    end,

    -- Shows the source's own tooltip, anchored to the block
    customTooltip = function(self, cfg)
        local frame, obj, data = Resolve(cfg)
        if obj then
            if obj.OnTooltipShow then
                ns.AnchorTooltip(self)
                obj.OnTooltipShow(GameTooltip)
                GameTooltip:Show()
            elseif obj.OnEnter then
                obj.OnEnter(self)
            else
                SimpleTooltip(self, cfg)
            end
        elseif data then
            if data.funcOnEnter then data.funcOnEnter(self) else SimpleTooltip(self, cfg) end
        elseif frame then
            local script = frame:GetScript("OnEnter")
            if script then
                script(frame)
                -- Move the original button's tooltip next to the block
                if GameTooltip:IsShown() and GameTooltip:GetOwner() == frame then
                    ns.MoveTooltip(self)
                end
            else
                SimpleTooltip(self, cfg)
            end
        else
            SimpleTooltip(self, cfg)
        end
    end,

    -- Lets the source clean up when the mouse leaves
    onLeave = function(self, cfg)
        local frame, obj, data = Resolve(cfg)
        if obj and obj.OnLeave then
            obj.OnLeave(self)
        elseif data and data.funcOnLeave then
            data.funcOnLeave(self)
        elseif frame and frame:GetScript("OnLeave") then
            frame:GetScript("OnLeave")(frame)
        end
    end,
}
