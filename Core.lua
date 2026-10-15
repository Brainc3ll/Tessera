-- Tessera - Core.lua
-- ===========================================================================
-- Heart of the addon. Tessera shows small movable "blocks" on screen: data
-- blocks (gold, bags, FPS, time...) and launcher blocks (buttons that open
-- something). This file owns everything those blocks have in common.
--
-- Main responsibilities:
--   * Shared namespace `ns` (module registry, frames, runtime state) and Print.
--   * Media lists (backgrounds, borders, fonts), from the game itself and from
--     LibSharedMedia when another addon (e.g. FlareUI) provides some.
--   * Frame skinning (modern Blizzard nine-slice atlases or classic backdrops).
--   * Saved variables (TesseraDB): profiles, per-block defaults, account-wide
--     settings.
--   * Block creation, styling, visibility, text/icon updates, mouse handlers.
--   * Positioning: snapping to other blocks and to an optional grid.
--   * The default layout created on first install (a compact bar at the top).
--   * Event handling, the periodic update timer, slash commands and the
--     minimap / addon compartment button.
--
-- Related files (loaded after this one, see Tessera.toc):
--   Themes.lua       visual themes (ApplyThemeToCfg, theme previews).
--   Merge.lua        docking/merging blocks into groups, drag handling and the
--                    border seams drawn where merged blocks meet
--                    (AnchorDocked, FindDock, GetSubtree, Reroot, RequestLayout).
--   SecureClicks.lua secure click overlays, needed for actions that would be
--                    blocked (tainted) when triggered from insecure addon code.
--   Changelog.lua    version history shown in the options "Version" tab.
--   Modules.lua      data block definitions (registered with ns:RegisterModule).
--   Launchers.lua    launcher blocks (ns.launcherModule).
--   Broker.lua       DataBroker: other addons' data objects shown as blocks
--                    (ns.brokerModule), Tessera's blocks published as data
--                    objects, and the DataBroker mode.
--   Options.lua      the options window, welcome screen and debug report.
--   Locales/         translated strings, exposed as ns.L.
-- ===========================================================================

local ADDON, ns = ...
local L = ns.L

ns.modules = {}
ns.order = {}
ns.frames = {}
ns.errors = {}
ns.state = { inCombat = false, inInstance = false }

local DEFAULT_PROFILE = "Default"
local LAUNCHER_PREFIX = "launcher:"
ns.DEFAULT_PROFILE = DEFAULT_PROFILE
ns.LAUNCHER_PREFIX = LAUNCHER_PREFIX

-- Chat output. In quiet mode nothing is printed, except in reply to a typed
-- command (/tessera ...) or in debug mode.
local function Print(msg)
    if ns.sv and ns.sv.quiet and not ns.inCommand and not ns.debug then return end
    print("|cff33aaffTessera|r : " .. msg)
end
ns.Print = Print

---------------------------------------------------------------------------
-- Media shipped with the game
---------------------------------------------------------------------------
ns.backgrounds = {
    { key = "none",       name = L.MEDIA_NONE },
    { key = "solid",      name = L.MEDIA_SOLID,       file = "Interface\\Buttons\\WHITE8X8" },
    { key = "tooltip",    name = L.MEDIA_TOOLTIP,     file = "Interface\\Tooltips\\UI-Tooltip-Background" },
    { key = "dialog",     name = L.MEDIA_DIALOG,      file = "Interface\\DialogFrame\\UI-DialogBox-Background" },
    { key = "dialogDark", name = L.MEDIA_DIALOG_DARK, file = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" },
    { key = "marble",     name = L.MEDIA_MARBLE,      file = "Interface\\FrameGeneral\\UI-Background-Marble", tile = true },
    { key = "rock",       name = L.MEDIA_ROCK,        file = "Interface\\FrameGeneral\\UI-Background-Rock", tile = true },
}

-- Border fields:
--   insetRatio: share of the border thickness that overlaps the background.
--   reach: length of the seam patch at inner corners of merged blocks (Merge.lua).
--   size: native border thickness in pixels.
ns.borders = {
    { key = "none",    name = L.MEDIA_NONE },
    { key = "solid",   name = L.MEDIA_SOLID,   file = "Interface\\Buttons\\WHITE8X8", insetRatio = 1, reach = 1, size = 1 },
    { key = "tooltip", name = L.MEDIA_TOOLTIP, file = "Interface\\Tooltips\\UI-Tooltip-Border", insetRatio = 0.25, reach = 0.15, size = 16 },
    { key = "dialog",  name = L.MEDIA_DIALOG,  file = "Interface\\DialogFrame\\UI-DialogBox-Border", insetRatio = 0.35, reach = 0.23, size = 32 },
    { key = "gold",    name = L.MEDIA_GOLD,    file = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", insetRatio = 0.35, reach = 0.2, size = 32 },
    -- Modern tooltip (Retail and Forever): Blizzard's atlas-based nine-slice frame
    { key = "modernTooltip", name = L.MEDIA_MODERN_TOOLTIP, nineSlice = "TooltipDefaultLayout", reach = 0.33, size = 16 },
}

ns.fonts = {
    { key = "friz",     name = "Friz Quadrata", file = "Fonts\\FRIZQT__.TTF" },
    { key = "arial",    name = "Arial Narrow",  file = "Fonts\\ARIALN.TTF" },
    -- Morpheus draws small letters: shown 2 points larger to read like the others
    { key = "morpheus", name = "Morpheus",      file = "Fonts\\MORPHEUS.TTF", sizeBoost = 2 },
    { key = "skurri",   name = "Skurri",        file = "Fonts\\SKURRI.TTF" },
}

---------------------------------------------------------------------------
-- Media from other addons (FlareUI, etc.) via LibSharedMedia, if present
---------------------------------------------------------------------------
local BUILTIN = { background = ns.backgrounds, border = ns.borders, font = ns.fonts }
-- Saved media keys starting with this prefix refer to a LibSharedMedia entry
local LSM_PREFIX = "lsm:"
ns.LSM_PREFIX = LSM_PREFIX -- media from LibSharedMedia (checked on import, Profiles.lua)

-- Returns LibSharedMedia if some addon loaded it (silent = true: no error if missing)
function ns:GetLSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- Normalizes a texture path so the same file is detected under any spelling
local function NormalizePath(path)
    return type(path) == "string" and path:gsub("/", "\\"):lower() or path
end

-- Gap between border and background, depending on the border image
local function LSMInsetRatio(file)
    if type(file) == "string" and file:find("FlareUI%-Thin") then
        return 3 / 8  -- FlareUI: 8 px Thin border, 3 px gap
    end
    return 3 / 16     -- FlareUI: 16 px borders, 3 px gap
end

-- Full list for one media kind: the game's media, then LibSharedMedia's
-- (files already listed are skipped to avoid duplicates)
function ns:GetMediaList(kind)
    local list, known = {}, {}
    for _, item in ipairs(BUILTIN[kind]) do
        table.insert(list, item)
        if item.file then known[NormalizePath(item.file)] = true end
    end
    local LSM = self:GetLSM()
    if LSM then
        for _, name in ipairs(LSM:List(kind)) do
            local file = LSM:Fetch(kind, name, true)
            if file and not known[NormalizePath(file)] then
                known[NormalizePath(file)] = true
                table.insert(list, { key = LSM_PREFIX .. name, name = name })
            end
        end
    end
    return list
end

-- The eight border pieces (corners and edges) of a frame's nine-slice / backdrop
ns.EDGE_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
}

-- Frame skin (block or options window): "modern" (Blizzard atlases),
-- "backdrop" (classic textures) or "none". Both systems use the same texture
-- pieces; when switching systems we reset them so nothing of the old one is
-- left over (edge tiling, positions, colors).
local ALL_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}

-- Clears every skin piece of a frame back to a blank, hidden state
local function ResetPieces(frame)
    for _, name in ipairs(ALL_PIECES) do
        local piece = frame[name]
        if piece then
            piece:ClearAllPoints()
            piece:SetTexture(nil)
            piece:SetTexCoord(0, 1, 0, 1)
            if piece.SetHorizTile then piece:SetHorizTile(false) end
            if piece.SetVertTile then piece:SetVertTile(false) end
            piece:SetVertexColor(1, 1, 1, 1)
            piece:Hide()
        end
    end
end

-- Unpacks a color given as {r=,g=,b=,a=} or {1,2,3,4}; missing values default to 1
local function Rgba(c)
    if not c then return 1, 1, 1, 1 end
    return c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1, c.a or c[4] or 1
end

-- Applies a skin to a frame. spec.kind is "modern" (spec.layout = nine-slice
-- layout name), "backdrop" (spec.info = backdrop table) or "none"; spec.border
-- and spec.bg are colors. Returns the border thickness for "modern" skins
-- (used to compute insets and seams), 0 otherwise.
function ns:ApplySkin(frame, spec)
    if frame.skinKind and frame.skinKind ~= spec.kind then
        if frame.backdropInfo then frame:SetBackdrop(nil) end
        ResetPieces(frame)
    end
    frame.skinKind = spec.kind

    if spec.kind == "modern" then
        if frame.backdropInfo then frame:SetBackdrop(nil) end
        NineSliceUtil.ApplyLayoutByName(frame, spec.layout)
        for _, name in ipairs(ns.EDGE_PIECES) do
            local piece = frame[name]
            if piece then
                piece:SetVertexColor(Rgba(spec.border))
                piece:Show()
            end
        end
        if frame.Center then
            frame.Center:SetVertexColor(Rgba(spec.bg))
            frame.Center:SetShown(spec.showCenter ~= false)
        end
        -- Thickness: read from the corner's atlas info. Right after applying the
        -- layout, the corner's size may still be the previous theme's (or 0).
        local corner = frame.TopLeftCorner
        local atlas = corner and corner.GetAtlas and corner:GetAtlas()
        local info = atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
        if info and info.width and info.width > 0 then return info.width end
        return corner and corner:GetWidth() or 0
    elseif spec.kind == "backdrop" then
        frame:SetBackdrop(spec.info)
        if spec.info.bgFile then
            frame:SetBackdropColor(Rgba(spec.bg))
            if frame.Center then frame.Center:Show() end
        end
        if spec.info.edgeFile then
            frame:SetBackdropBorderColor(Rgba(spec.border))
            for _, name in ipairs(ns.EDGE_PIECES) do
                if frame[name] then frame[name]:Show() end
            end
        end
    else
        if frame.backdropInfo then frame:SetBackdrop(nil) end
        ResetPieces(frame)
    end
    return 0
end

-- Resolves a saved media key to its description table. "lsm:" keys are
-- looked up in LibSharedMedia; unknown keys fall back to the first entry.
function ns:FindMedia(kind, key)
    if type(key) == "string" and key:sub(1, #LSM_PREFIX) == LSM_PREFIX then
        local LSM = self:GetLSM()
        local file = LSM and LSM:Fetch(kind, key:sub(#LSM_PREFIX + 1), true)
        if file then
            -- Values tuned in game: FlareUI Thick and Frames 0.10, FlareUI Thin 0.4; otherwise the middle
            local reach = 0.5
            if type(file) == "string" then
                if file:find("FlareUI%-Thick") or file:find("FlareUI%-Frames") then reach = 0.10
                elseif file:find("FlareUI") then reach = 0.4 end
            end
            -- Native thickness: 8 px for FlareUI Thin (as in FlareUI), 16 px otherwise
            local size = (type(file) == "string" and file:find("FlareUI%-Thin")) and 8 or 16
            return { key = key, file = file, insetRatio = LSMInsetRatio(file), reach = reach, size = size }
        end
        -- Providing addon missing: fall back to a game media
        key = (kind == "font") and "friz" or "solid"
    end
    local list = BUILTIN[kind]
    for _, item in ipairs(list) do
        if item.key == key then return item end
    end
    return list[1]
end

-- True when FlareUI's media are registered (used to pick the FlareUI-style default layout)
function ns:HasFlareUIMedia()
    local LSM = self:GetLSM()
    return LSM and LSM:Fetch("border", "FlareUI Thin", true) ~= nil
end

---------------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------------
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = DeepCopy(v) end
    return t
end
ns.DeepCopy = DeepCopy

-- Fills missing values of dst from src (recursively), never overwriting existing ones
local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- Launcher blocks are stored under keys like "launcher:<id>"
function ns.IsLauncherKey(key)
    return type(key) == "string" and key:sub(1, #LAUNCHER_PREFIX) == LAUNCHER_PREFIX
end

-- DataBroker blocks (another addon's LibDataBroker object) use keys like "broker:<object name>"
local BROKER_PREFIX = "broker:"
ns.BROKER_PREFIX = BROKER_PREFIX
function ns.IsBrokerKey(key)
    return type(key) == "string" and key:sub(1, #BROKER_PREFIX) == BROKER_PREFIX
end

-- Launchers and DataBroker blocks pass every click on to the other addon
function ns.IsForwardingKey(key)
    return ns.IsLauncherKey(key) or ns.IsBrokerKey(key)
end

-- A group can hang below (second row) or above (bottom bar) another block:
-- cfg.anchor.below / cfg.anchor.above = that block's key. Returns that key.
function ns.HangTarget(anchor)
    return anchor and (anchor.below or anchor.above) or nil
end

-- Spacer blocks (empty, separator line or free text) use keys like "spacer:<n>"
local SPACER_PREFIX = "spacer:"
ns.SPACER_PREFIX = SPACER_PREFIX
function ns.IsSpacerKey(key)
    return type(key) == "string" and key:sub(1, #SPACER_PREFIX) == SPACER_PREFIX
end

-- Threshold colors: 1 = good, 2 = warning, 3 = critical. The colorblind-friendly
-- palette (blue / orange / purple) replaces them when that option is on.
ns.LEVEL_COLORS = { "4dff4d", "ffd933", "ff4d4d" }
local PALETTES = {
    normal = { "4dff4d", "ffd933", "ff4d4d" },
    colorblind = { "4da6ff", "ffb000", "c060ff" },
}
function ns:ApplyLevelPalette()
    local palette = (self.sv and self.sv.colorblind) and PALETTES.colorblind or PALETTES.normal
    for i, hex in ipairs(palette) do ns.LEVEL_COLORS[i] = hex end
end

-- Color of the player's class (for the "class color" options)
function ns:GetClassColor()
    local _, class = UnitClass("player")
    local c = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if c then return { r = c.r, g = c.g, b = c.b, a = 1 } end
end

-- Sets a texture from an icon spec: a file path / file ID, or a table
-- { file | atlas, coords, color }. 134400 is the "question mark" icon.
function ns:SetIcon(tex, icon)
    tex:SetVertexColor(1, 1, 1)
    tex:SetTexCoord(0, 1, 0, 1)
    if type(icon) ~= "table" then icon = { file = icon } end
    if icon.atlas then
        tex:SetAtlas(icon.atlas)
    else
        tex:SetTexture(icon.file or 134400)
        if icon.coords and #icon.coords >= 4 then
            tex:SetTexCoord(unpack(icon.coords))
        elseif type(icon.file) == "string" and icon.file:gsub("/", "\\"):lower():find("interface\\icons\\", 1, true) then
            tex:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- crops the built-in frame of spell icons
        end
    end
    if icon.color then
        tex:SetVertexColor(icon.color[1] or 1, icon.color[2] or 1, icon.color[3] or 1)
    end
end

-- Icon frame, shape and color (Frame tab, "Icon" section), applied after SetIcon:
--   square: icon cropped (no built-in edge) inside a thin colored square
--   round:  icon cut into a circle inside a thin colored ring
--   black and white: desaturated icon
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
function ns:StyleIcon(f, cfg)
    local tex, shape = f.icon, cfg.iconShape or "none"
    if tex.SetDesaturated then tex:SetDesaturated((cfg.iconDesaturate or cfg.monochrome) and true or false) end
    -- crop the icon's own edge when it gets a frame (only if it is not cropped already)
    if shape ~= "none" and tex.GetTexCoord then
        local l, t, _, _, _, _, r, b = tex:GetTexCoord()
        if l and r and b and l <= 0.01 and r >= 0.99 then
            local dx, dy = (r - l) * 0.08, (b - t) * 0.08
            tex:SetTexCoord(l + dx, r - dx, t + dy, b - dy)
        end
    end
    -- the frame: a colored texture just larger than the icon, behind it
    if not f.iconBorder then
        f.iconBorder = f:CreateTexture(nil, "ARTWORK", nil, -1)
        f.iconBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    local border = f.iconBorder
    local edge = self:PixelSize(1, f)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", tex, "TOPLEFT", -edge, edge)
    border:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", edge, -edge)
    local c = cfg.iconBorderColor or {}
    border:SetVertexColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
    border:SetShown(shape ~= "none" and tex:IsShown())
    -- round: a circle mask on both the icon and its frame
    if f.CreateMaskTexture and tex.AddMaskTexture then
        if not f.iconMask then
            f.iconMask = f:CreateMaskTexture()
            if not f.iconMask then return end
            f.iconMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            f.iconMask:SetAllPoints(tex)
            f.borderMask = f:CreateMaskTexture()
            f.borderMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            f.borderMask:SetAllPoints(border)
        end
        local round = shape == "round"
        if round ~= (f.iconMasked or false) then
            if round then
                tex:AddMaskTexture(f.iconMask)
                border:AddMaskTexture(f.borderMask)
            else
                tex:RemoveMaskTexture(f.iconMask)
                border:RemoveMaskTexture(f.borderMask)
            end
            f.iconMasked = round
        end
    end
end

-- Places the tooltip below or above the block, toward the screen center
-- Tooltip size chosen in the General tab ("Tooltip size"), for block tooltips only.
-- GameTooltip is shared with the whole game: its own scale is remembered and given
-- back as soon as it hides, so other tooltips are never affected.
local tooltipBaseScale, tooltipHooked = {}, {}
local function ScaleTooltip(owner, tooltip)
    local scale = (owner and owner.key and ns.db and ns.db.tooltipScale) or 1
    if scale == 1 and not tooltipBaseScale[tooltip] then return end
    if not tooltipHooked[tooltip] then
        tooltipHooked[tooltip] = true
        tooltip:HookScript("OnHide", function(self)
            if tooltipBaseScale[self] then
                self:SetScale(tooltipBaseScale[self])
                tooltipBaseScale[self] = nil
            end
        end)
    end
    tooltipBaseScale[tooltip] = tooltipBaseScale[tooltip] or tooltip:GetScale()
    tooltip:SetScale(tooltipBaseScale[tooltip] * scale)
end

function ns.AnchorTooltip(owner, tooltip)
    tooltip = tooltip or GameTooltip
    tooltip:SetOwner(owner, "ANCHOR_NONE")
    ScaleTooltip(owner, tooltip)
    ns.MoveTooltip(owner, tooltip)
end

-- Repositions an already-owned tooltip (also used when the block moves)
function ns.MoveTooltip(owner, tooltip)
    tooltip = tooltip or GameTooltip
    -- center of the block in UIParent units (the block may have its own scale)
    local l, b, r, t = ns:GetRectUI(owner)
    if not l then return end
    local x, y = (l + r) / 2, (b + t) / 2
    local h = x > UIParent:GetWidth() / 2 and "RIGHT" or "LEFT"
    -- the block's "tooltip position" option can force above or below
    local cfg = owner.key and ns.db and ns.db.blocks[owner.key]
    local below = y > UIParent:GetHeight() / 2
    if cfg and cfg.tooltipAnchor == "top" then below = false end
    if cfg and cfg.tooltipAnchor == "bottom" then below = true end
    tooltip:ClearAllPoints()
    if below then
        tooltip:SetPoint("TOP" .. h, owner, "BOTTOM" .. h, 0, -4)
    else
        tooltip:SetPoint("BOTTOM" .. h, owner, "TOP" .. h, 0, 4)
    end
end

---------------------------------------------------------------------------
-- Default settings
---------------------------------------------------------------------------
-- Per-block settings (stored in profile.blocks[key])
local BLOCK_DEFAULTS = {
    enabled = true,
    showLabel = false, -- icon + value, like the stock bar
    showIcon = true,
    tooltip = true,
    colorize = true,
    hideInCombat = false,
    hideInInstance = false,
    hideEmpty = true,       -- friends, guild: hidden when there is nothing to show
    timeSource = "auto",    -- time: auto (the one WoW does not display), local, server
    shiftClick = "chat",    -- Shift + click: none, chat, options, hide
    middleClick = "none",   -- middle click: none, open, chat, options, hide (+ module action)
    clock24 = true,         -- time blocks: 24-hour clock
    goldFormat = "full",    -- gold: full, gold, short
    progressBar = false,    -- background fills with the block's progress (XP, reputation...)
    alpha = 1,              -- opacity of the block
    fadeOut = false,        -- hidden (or faint) until the mouse is over its group
    fadeAlpha = 0,          -- opacity while faded out
    fadeShowCombat = true,  -- faded blocks are fully shown in combat
    alert = true,           -- flash when the block turns red, or when it appears (mail...)
    tooltipAnchor = "auto", -- tooltip: auto, top, bottom
    hideInVehicle = false,
    hideWhenResting = false, -- in an inn or a capital city
    classColorText = false,
    classColorBorder = false,
    iconSize = 0,             -- icon size in pixels, 0 = follows the block's height
    iconShape = "none",       -- icon frame: none (as is), square, round
    iconBorderColor = { r = 0, g = 0, b = 0, a = 1 },
    iconDesaturate = false,   -- black and white icon
    separators = false,       -- thin line between merged blocks (see Merge.lua, DrawSeparators)
    separatorColor = { r = 0.8, g = 0.6, b = 0.34, a = 0.5 },
    -- set by some styles (Themes.lua), cleared by the others:
    hideIcons = false,        -- text only (launchers keep their icon)
    monochrome = false,       -- black and white: grey text, no colors in the values, grey icons
    inkColors = false,        -- light background: the colors in the values darkened like ink
    textTint = { r = 1, g = 1, b = 1, a = 0 }, -- text color of the style (a = 0: none), used
                                               -- while the block's own text color is white
    width = 60,   -- minimum width: the block grows if its text is longer
    autoWidth = true, -- false: fixed width, overly long text is cut off
    height = 24,
    justify = "CENTER",
    strata = "HIGH",        -- above Blizzard's action bars and their ornaments (gryphons)
    font = "friz",
    fontSize = 12,
    outline = "OUTLINE",
    textColor = { r = 1, g = 1, b = 1, a = 1 },
    bg = "solid",
    bgColor = { r = 0, g = 0, b = 0, a = 0.6 },
    border = "solid",
    borderSize = 1,
    borderColor = { r = 0.35, g = 0.35, b = 0.35, a = 1 },
    -- point = { point, relativePoint, x, y } (nil = default position)
    -- launcher = { kind, source, label } (launcher blocks only)
    -- broker = { name, label, kind, addon } (DataBroker blocks only, see Broker.lua)
    -- brokerShare = published as a DataBroker object (data blocks only, see Broker.lua)
}

-- Appearance settings copied by "Copy this style to all blocks"
local STYLE_KEYS = {
    "height", "justify", "strata", "font", "fontSize", "outline", "textColor",
    "bg", "bgColor", "border", "borderSize", "borderColor", "classColorText", "classColorBorder", "alpha",
    "iconSize", "iconShape", "iconBorderColor", "iconDesaturate", "separators", "separatorColor",
    "hideIcons", "monochrome", "textTint", "inkColors",
}
ns.STYLE_KEYS = STYLE_KEYS -- also what a style export carries (Profiles.lua)

-- Gives block "to" the look of block "from" (size, font, frame...): used for spacers
-- added to a bar so they blend in
function ns:CopyBlockStyle(from, to)
    local a, b = self.db.blocks[from], self.db.blocks[to]
    if not a or not b then return end
    for _, k in ipairs(STYLE_KEYS) do b[k] = DeepCopy(a[k]) end
end

-- Per-profile settings
local PROFILE_DEFAULTS = {
    locked = true,
    lockInCombat = true,     -- blocks frozen in combat
    tooltipInCombat = true,  -- tooltips shown in combat
    tooltipHints = true,     -- blue help lines about clicks at the bottom of tooltips
    tooltipAltOnly = false,  -- tooltips only while Alt is held
    tooltipScale = 1,        -- size of block tooltips (1 = the game's size)
    snap = true,
    snapBlizzard = true,     -- also snap to some Blizzard frames (minimap, chat, bars...)
    editModeSync = true,     -- Blizzard's Edit Mode also unlocks the blocks
    edgeSnap = "ask",        -- a group dropped against a screen edge: "ask", "always" or "never" stick it
    scale = 1,               -- global scale of all blocks
    merge = true,
    grid = 0,
    groupDefaults = {},      -- settings made on "All blocks", inherited by new blocks
    launcherDefaults = { tooltip = true, showLabel = true, showIcon = true },
    blocks = {},
}

ns.PROFILE_DEFAULTS = PROFILE_DEFAULTS -- used to validate imported profiles (Profiles.lua)

-- Locked by the user, or frozen automatically in combat
function ns:IsLocked()
    return self.db.locked or (self.db.lockInCombat and self.state.inCombat) or false
end

-- Called by Modules.lua for each data block definition (order of calls = display order)
function ns:RegisterModule(key, def)
    def.key = key
    self.modules[key] = def
    table.insert(self.order, key)
end

-- Default values for a block: the profile's style (see Themes.lua),
-- plus the shared launcher settings for a new launcher
function ns:GetBlockDefaults(key)
    local d = DeepCopy(BLOCK_DEFAULTS)
    self:ApplyThemeToCfg(d)
    local launcher = ns.IsLauncherKey(key)
    if launcher then
        d.showIcon = true
        d.showLabel = true
        d.colorize = false
    elseif ns.IsBrokerKey(key) then
        d.showIcon = true
        d.showLabel = false -- the other addon's text usually says what it is
        d.colorize = false
    elseif self.modules[key] and self.modules[key].defaultEnabled == false then
        d.enabled = false
    end
    -- data blocks shown by default are also the ones shared with DataBroker addons
    if self.modules[key] then d.brokerShare = self.modules[key].defaultEnabled ~= false end
    -- Module-specific defaults (e.g. progress bar on for XP), before the user's choices
    local mod = self:GetModule(key)
    for field, value in pairs(mod and mod.defaults or {}) do d[field] = DeepCopy(value) end
    -- Shared settings chosen by the user: "All blocks", then "All launchers"
    local db = self.db
    for field, value in pairs(db and db.groupDefaults or {}) do d[field] = DeepCopy(value) end
    if launcher then
        for field, value in pairs(db and db.launcherDefaults or {}) do d[field] = DeepCopy(value) end
    end
    -- Settings a module always forces (e.g. a spacer never shows an icon)
    for field, value in pairs(mod and mod.forced or {}) do d[field] = DeepCopy(value) end
    return d
end

-- All launchers share one module definition (Launchers.lua)
function ns:GetModule(key)
    if ns.IsLauncherKey(key) then return self.launcherModule end
    if ns.IsSpacerKey(key) then return self.spacerModule end
    if ns.IsBrokerKey(key) then return self.brokerModule end
    return self.modules[key]
end

-- Display name: the launcher's own label, or the module's localized label
function ns:GetBlockName(key)
    if ns.IsLauncherKey(key) then
        local cfg = self.db.blocks[key]
        return cfg and cfg.launcher and cfg.launcher.label or key
    end
    if ns.IsBrokerKey(key) then
        local cfg = self.db.blocks[key]
        return cfg and cfg.broker and cfg.broker.label or key:sub(#BROKER_PREFIX + 1)
    end
    if ns.IsSpacerKey(key) then
        local cfg = self.db.blocks[key]
        if cfg and cfg.spacerMode == "text" and cfg.spacerText and cfg.spacerText ~= "" then
            return cfg.spacerText
        end
        return L.SPACER_NAME:format(tonumber(key:sub(#SPACER_PREFIX + 1)) or 0)
    end
    local mod = self.modules[key]
    return mod and L[mod.label] or key
end

-- Blocks of the active profile: game data modules, then launchers and DataBroker
-- blocks sorted by name, then spacers by number
function ns:GetBlockKeys()
    local keys = {}
    for _, key in ipairs(self.order) do table.insert(keys, key) end
    local launchers, brokers, spacers = {}, {}, {}
    for key in pairs(self.db.blocks) do
        if ns.IsLauncherKey(key) then table.insert(launchers, key) end
        if ns.IsBrokerKey(key) then table.insert(brokers, key) end
        if ns.IsSpacerKey(key) then table.insert(spacers, key) end
    end
    local function byName(a, b) return self:GetBlockName(a):lower() < self:GetBlockName(b):lower() end
    table.sort(launchers, byName)
    table.sort(brokers, byName)
    table.sort(spacers, function(a, b)
        return (tonumber(a:sub(#SPACER_PREFIX + 1)) or 0) < (tonumber(b:sub(#SPACER_PREFIX + 1)) or 0)
    end)
    for _, key in ipairs(launchers) do table.insert(keys, key) end
    for _, key in ipairs(brokers) do table.insert(keys, key) end
    for _, key in ipairs(spacers) do table.insert(keys, key) end
    return keys
end

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------
-- Saved variables layout (TesseraDB):
--   profiles[name]       profile tables (see PROFILE_DEFAULTS)
--   useGlobal            true: one profile for the whole account
--   globalProfile        profile used when useGlobal is true
--   charProfiles[char]   per-character profile when useGlobal is false
--   chars[char]          gold and class of each character (gold tooltip)
--   Account-wide options: borderReach[border] (corner join tuning), quiet (no chat
--   output), hideMinimapButton, welcomed (welcome popup shown), demoBackup (the
--   player's profile while the demo mode is on, see Demo.lua).
local function InitDB()
    TesseraDB = TesseraDB or {}
    local sv = TesseraDB

    sv.profiles = sv.profiles or {}
    sv.profiles[DEFAULT_PROFILE] = sv.profiles[DEFAULT_PROFILE] or {}
    if sv.useGlobal == nil then sv.useGlobal = true end
    sv.globalProfile = sv.globalProfile or DEFAULT_PROFILE
    sv.charProfiles = sv.charProfiles or {}
    sv.chars = sv.chars or {}

    ns.sv = sv
    ns.charKey = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    ns:ApplyLevelPalette()
    -- already in a dungeon at login / reload: start directly with its profile
    if ns.GetSituationProfile then ns.profileOverride = ns:GetSituationProfile() end
    -- a demo left open (reload, logout): the player's profile comes back (Demo.lua)
    if ns.RestoreDemoBackup then ns:RestoreDemoBackup() end
    ns:LoadProfile()
end

-- Fills in missing settings of a profile and of each of its blocks
function ns:PrepareProfile(p)
    -- Brand-new profile (first install or reset): apply the default layout
    local fresh = not p.initialized and (type(p.blocks) ~= "table" or next(p.blocks) == nil)
    CopyDefaults(PROFILE_DEFAULTS, p)
    local created = {}
    for _, key in ipairs(self.order) do
        if not p.blocks[key] then created[key] = true end
        p.blocks[key] = CopyDefaults(self:GetBlockDefaults(key), p.blocks[key] or {})
    end
    for key, cfg in pairs(p.blocks) do
        if ns.IsLauncherKey(key) or ns.IsBrokerKey(key) or ns.IsSpacerKey(key) then CopyDefaults(self:GetBlockDefaults(key), cfg) end
    end
    if fresh then
        self:ApplyBaseLayout(p, p.pendingPreset)
        p.pendingPreset = nil
    elseif p.initialized then
        -- a block added by an update: shown in the second row if it belongs there
        for key in pairs(created) do self:AttachNewBlock(p, key) end
    end
    p.initialized = true
end

-- Name of the profile in use (account-wide or per character), falling back to Default
-- The player's usual profile (account-wide or this character's)
function ns:GetBaseProfileName()
    local sv = self.sv
    local name
    if sv.useGlobal then
        name = sv.globalProfile
    else
        name = sv.charProfiles[self.charKey]
    end
    if not name or not sv.profiles[name] then name = DEFAULT_PROFILE end
    return name
end

-- Profile in use: the usual one, or the automatic profile for the situation
-- (dungeon / raid, see Profiles.lua)
function ns:GetActiveProfileName()
    if self.profileOverride and self.sv.profiles[self.profileOverride] then return self.profileOverride end
    return self:GetBaseProfileName()
end

-- Makes the active profile current (ns.db) and redraws everything
function ns:LoadProfile()
    self.profileName = self:GetActiveProfileName()
    self.db = self.sv.profiles[self.profileName]
    -- safety net: a damaged profile (e.g. a bad import) falls back to Default
    local ok, err = pcall(self.PrepareProfile, self, self.db)
    if not ok and self.profileName ~= DEFAULT_PROFILE then
        Print(L.PROFILE_DAMAGED:format(self.profileName, tostring(err)))
        self.profileOverride = nil
        if self.sv.useGlobal then self.sv.globalProfile = DEFAULT_PROFILE
        else self.sv.charProfiles[self.charKey] = DEFAULT_PROFILE end
        self.profileName = DEFAULT_PROFILE
        self.db = self.sv.profiles[DEFAULT_PROFILE]
        self:PrepareProfile(self.db)
    elseif not ok then
        error(err)
    end
    -- the automatic style follows the installed UI (e.g. FlareUI 1.x updated to 2.x)
    if self.SyncAutoTheme then pcall(self.SyncAutoTheme, self) end
    if self.ClearUndo then self:ClearUndo() end
    if self.built then
        self:RefreshAllBlocks()
        C_Timer.After(1, function() ns:MigratePositions() end)
    end
    if self.SkinOptions then self:SkinOptions() end
    -- each profile chooses which blocks are shared with DataBroker addons
    if self.built and self.UpdatePublishing then self:UpdatePublishing() end
end

-- Profile names sorted alphabetically, with Default first
function ns:GetProfileNames()
    local names = {}
    for name in pairs(self.sv.profiles) do table.insert(names, name) end
    table.sort(names, function(a, b)
        if a == DEFAULT_PROFILE then return true end
        if b == DEFAULT_PROFILE then return false end
        return a:lower() < b:lower()
    end)
    return names
end

function ns:ProfileDisplayName(name)
    return name == DEFAULT_PROFILE and L.DEFAULT_PROFILE or name
end

function ns:SetProfile(name)
    if not self.sv.profiles[name] then return end
    -- an explicit choice wins over the automatic profile until the next zone change
    self.profileOverride = nil
    if self.sv.useGlobal then
        self.sv.globalProfile = name
    else
        self.sv.charProfiles[self.charKey] = name
    end
    self:LoadProfile()
    -- the Edit Mode layout made for this profile, if any (EditMode.lua)
    C_Timer.After(1, function() if ns.CheckEditModeForProfile then ns:CheckEditModeForProfile() end end)
end

-- Switches between account-wide and per-character profiles, keeping the current one
function ns:SetUseGlobal(value)
    local current = self:GetBaseProfileName()
    self.sv.useGlobal = value
    if value then
        self.sv.globalProfile = current
    elseif not self.sv.charProfiles[self.charKey] then
        self.sv.charProfiles[self.charKey] = current
    end
    self:LoadProfile()
end

-- New profile, starting from the default layout; returns false if the name is invalid or taken
function ns:CreateProfile(name)
    name = name and strtrim(name) or ""
    if name == "" or name == DEFAULT_PROFILE or self.sv.profiles[name] then return false end
    self.sv.profiles[name] = {} -- a new profile starts from the default layout
    self:SetProfile(name)
    return true
end

-- Deletes a profile (never Default); characters using it go back to Default
function ns:DeleteProfile(name)
    if name == DEFAULT_PROFILE or not self.sv.profiles[name] then return false end
    self.sv.profiles[name] = nil
    if self.sv.globalProfile == name then self.sv.globalProfile = DEFAULT_PROFILE end
    if self.sv.instanceProfile == name then self.sv.instanceProfile = nil end
    if self.profileOverride == name then self.profileOverride = nil end
    for char, profile in pairs(self.sv.charProfiles) do
        if profile == name then self.sv.charProfiles[char] = nil end
    end
    self:LoadProfile()
    return true
end

---------------------------------------------------------------------------
-- Positioning, snapping and grid
---------------------------------------------------------------------------
local SNAP_DISTANCE = 10

-- Position of a block that was never placed: data blocks in a row at the top
-- of the screen, launchers and DataBroker blocks stacked around the screen center
local function DefaultPoint(key)
    if ns.IsForwardingKey(key) then
        local i = 0
        for k in pairs(ns.db.blocks) do
            if ns.IsForwardingKey(k) and k <= key then i = i + 1 end
        end
        return "CENTER", "CENTER", 0, 60 - i * 30
    end
    -- data blocks never placed: rows of 10 under the top center of the screen
    local index = 1
    for i, k in ipairs(ns.order) do
        if k == key then index = i end
    end
    local col, row = (index - 1) % 10, math.floor((index - 1) / 10)
    return "TOP", "TOP", math.floor((col - 4.5) * 106 + 0.5), -60 - row * 30
end

-- Called at the end of a drag: aligns the block with the edges of other blocks,
-- then with the grid, merges it if it touches another block, saves the
-- position and re-anchors the whole moved group
function ns:SnapAndSave(f)
    if not f:GetLeft() then return end
    local group = self:GetSubtree(f.key) -- the block and its group
    -- blocks that move along (the group and any second row hanging below it):
    -- they must not be snapped to or merged with
    local exclude = self:GetDragSet(f.key)

    -- Rectangle of each block of the moved group, in UIParent units (blocks can
    -- have different scales, so every comparison below is done in these units)
    local members = {}
    for key in pairs(group) do
        local m = self.frames[key]
        if m and m:IsShown() then
            local l, b, r, t = self:GetRectUI(m)
            if l then members[key] = { left = l, top = t, w = r - l, h = t - b } end
        end
    end
    if not members[f.key] then return end

    -- Snapping: the shortest offset, whichever block of the group gets aligned,
    -- against other blocks (and Blizzard frames if that option is on)
    local dx, dy, snappedX, snappedY = 0, 0, false, false
    if self.db.snap or self.db.merge then
        local bestX, bestY = SNAP_DISTANCE + 1, SNAP_DISTANCE + 1
        for _, o in ipairs(self:GetSnapRects(exclude)) do
            local ol, ob, or_, ot = o[1], o[2], o[3], o[4]
            for _, m in pairs(members) do
                for _, x in ipairs({ ol, or_, ol - m.w, or_ - m.w }) do
                    local d = math.abs(m.left - x)
                    if d < bestX then bestX, dx = d, x - m.left end
                end
                for _, y in ipairs({ ot, ob, ot + m.h, ob + m.h }) do
                    local d = math.abs(m.top - y)
                    if d < bestY then bestY, dy = d, y - m.top end
                end
            end
        end
        snappedX, snappedY = bestX <= SNAP_DISTANCE, bestY <= SNAP_DISTANCE
        if not snappedX then dx = 0 end
        if not snappedY then dy = 0 end
    end

    -- Grid: only on the axes that did not snap to another block
    local grid = self.db.grid or 0
    if grid > 0 then
        local root = members[f.key]
        if not snappedX then dx = math.floor(root.left / grid + 0.5) * grid - root.left end
        if not snappedY then dy = math.floor(root.top / grid + 0.5) * grid - root.top end
    end

    -- Merging: the group's block closest to another block becomes the group head
    local headKey, dock = f.key, nil
    if self.db.merge then
        local bestDist
        -- a single block may be slipped between two merged blocks (FindDock)
        local alone = next(group) ~= nil and next(group, next(group)) == nil
        for key, m in pairs(members) do
            local d, dist = self:FindDock(m.left + dx, m.top + dy, m.w, m.h, exclude, alone)
            if d and (not bestDist or dist < bestDist) then headKey, dock, bestDist = key, d, dist end
        end
    end

    -- A second row (hanging below or above another group) dropped back against that
    -- group, roughly where it hangs: it keeps hanging there (centered, full width), as if
    -- it had not moved. Otherwise it would become an ordinary group and lose its place.
    if not dock then
        local rowRoot = self:GetRoot(f.key)
        local rowCfg = self.db.blocks[rowRoot]
        local base = rowCfg and rowCfg.anchor and ns.HangTarget(rowCfg.anchor)
        if base and self.db.blocks[base] and not group[base] then
            local gl, gb, gr, gt
            for _, m in pairs(members) do
                local l, t = m.left + dx, m.top + dy
                gl, gr = math.min(gl or l, l), math.max(gr or l + m.w, l + m.w)
                gt, gb = math.max(gt or t, t), math.min(gb or t - m.h, t - m.h)
            end
            local bl, bb, br, bt
            for k in pairs(self:GetSubtree(self:GetRoot(base))) do
                local o = self.frames[k]
                local l, b, r, t
                if o and o:IsShown() then l, b, r, t = self:GetRectUI(o) end
                if l and b and r and t then
                    bl, bb = math.min(bl or l, l), math.min(bb or b, b)
                    br, bt = math.max(br or r, r), math.max(bt or t, t)
                end
            end
            if gl and bl then
                local gap = rowCfg.anchor.below and math.abs(gt - bb) or math.abs(gb - bt)
                local overlap = math.min(gr, br) - math.max(gl, bl)
                if gap <= 2 * SNAP_DISTANCE and overlap > (gr - gl) / 2 then
                    self:ReanchorAll()
                    self:RequestLayout()
                    return
                end
            end
        end
    end

    -- A moved group is no longer tied to the automatic default-layout anchor, nor
    -- stuck to a screen edge (it may be stuck again below, once dropped)
    for key in pairs(group) do
        local c = self.db.blocks[key]
        if c then c.anchor, c.edges, c.stretch = nil, nil, nil end
    end
    if headKey ~= f.key then self:Reroot(headKey) end
    if dock then
        -- merged into another group: it takes that group's scale (stored on its root)
        for key in pairs(group) do
            if self.db.blocks[key] then self.db.blocks[key].scale = nil end
        end
    end

    local head = members[headKey]
    local cfg = self.db.blocks[headKey]
    -- saved relative to the nearest screen anchor (fallback position if docked)
    local hl, ht = head.left + dx, head.top + dy
    cfg.point = self:MakeRelativePoint(hl, ht - head.h, hl + head.w, ht,
        self.frames[headKey]:GetEffectiveScale() / UIParent:GetEffectiveScale())
    local pushed = dock and dock.insert
    cfg.dock = dock and { to = dock.to, side = dock.side }
    -- slipped between two blocks: the block that was on that side now docks to this one
    if pushed and self.db.blocks[pushed] then
        self.db.blocks[pushed].dock = { to = headKey, side = dock.side }
    end

    -- Re-anchor the whole group (merges may have changed direction): first
    -- detach everything, then anchor from the head outward (never a loop)
    for key in pairs(group) do
        if self.frames[key] then
            self.frames[key]:ClearAllPoints()
            self.frames[key]:SetScale(self:GetBlockScale(key))
        end
    end
    local done, queue = {}, { headKey }
    while #queue > 0 do
        local key = table.remove(queue, 1)
        if not done[key] then
            done[key] = true
            local m, mcfg = self.frames[key], self.db.blocks[key]
            if m and mcfg and not self:AnchorDocked(m, mcfg) then
                local pt = mcfg.point or cfg.point
                m:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
            end
            for k in pairs(group) do
                if not done[k] and self:GetDockTarget(k) == key then table.insert(queue, k) end
            end
        end
    end
    if pushed then self:ReanchorAll() end
    self:RequestLayout()
    -- dropped against a screen edge: offer to stick it there (once the layout settled)
    if not dock then
        C_Timer.After(0.1, function() ns:CheckScreenEdges(headKey) end)
    end
end

-- Draws (or hides) the placement grid; only visible while blocks are unlocked.
-- Line textures are reused between redraws.
function ns:UpdateGrid()
    local grid = self.db.grid or 0
    local g = self.gridFrame
    -- (Blizzard's Edit Mode draws its own grid)
    if self:IsLocked() or grid <= 0 or self.brokerModeActive or self.db.unlockedByEditMode then
        if g then g:Hide() end
        return
    end
    if not g then
        g = CreateFrame("Frame", nil, UIParent)
        g:SetAllPoints()
        g:SetFrameStrata("BACKGROUND")
        g.lines = {}
        self.gridFrame = g
    end
    if g.size ~= grid then
        for _, t in ipairs(g.lines) do t:Hide() end
        local w, h = UIParent:GetWidth(), UIParent:GetHeight()
        local n = 0
        local function Line(vertical, pos)
            n = n + 1
            local t = g.lines[n] or g:CreateTexture(nil, "BACKGROUND")
            g.lines[n] = t
            t:SetColorTexture(1, 1, 1, 0.12)
            t:ClearAllPoints()
            if vertical then
                t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", pos, 0)
                t:SetSize(1, h)
            else
                t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, pos)
                t:SetSize(w, 1)
            end
            t:Show()
        end
        for x = 0, w, grid do Line(true, x) end
        for y = 0, h, grid do Line(false, y) end
        g.size = grid
    end
    g:Show()
end

---------------------------------------------------------------------------
-- Blocks
---------------------------------------------------------------------------
-- Placement mode: reminder of the available gestures on the block
-- (in the panel under the placement banner, so nothing covers the block's buttons;
-- in a tooltip when the banner is not shown, e.g. while the options window is open)
local function ShowPlacementHelp(self)
    local lines = { L.HINT_DRAG, L.HINT_SHIFT_DRAG, L.HINT_CTRL_CLICK, L.HINT_REPLACE_BUTTON,
        L.HINT_QUICK_MENU_PLACEMENT, L.HINT_UNDO }
    if ns:IsFrozen(self.key) then lines = { L.HINT_FROZEN } end
    if ns.ShowPlacementInfo and ns:ShowPlacementInfo(lines, ns:GetBlockName(self.key)) then return end
    ns.AnchorTooltip(self)
    GameTooltip:AddLine(ns:GetBlockName(self.key), 1, 0.82, 0)
    for _, line in ipairs(lines) do GameTooltip:AddLine(line, 1, 1, 1, true) end
    GameTooltip:Show()
end

-- Mouse-over: placement help when unlocked, otherwise the module's tooltip.
-- Module callbacks run in pcall so a broken module cannot break the addon.
local function OnEnter(self)
    local key = self.key
    local cfg, mod = ns.db.blocks[key], ns:GetModule(key)
    if not cfg or not mod then return end
    ns.hoveredBlock = self -- for "tooltips only while Alt is held" (watcher below)
    if not ns:IsLocked() then
        ShowPlacementHelp(self)
        ns:ShowBlockControls(self)
        return
    end
    if not cfg.tooltip then return end
    if ns.db.tooltipAltOnly and not IsAltKeyDown() then return end
    if ns.state.inCombat and not ns.db.tooltipInCombat then return end
    if mod.customTooltip then
        pcall(mod.customTooltip, self, cfg)
        return
    end
    if not mod.tooltip and not mod.clickHint then return end
    ns.AnchorTooltip(self)
    GameTooltip:AddLine(ns:GetBlockName(key), 1, 0.82, 0)
    if mod.tooltip then pcall(mod.tooltip, GameTooltip, cfg) end
    -- blue help lines about clicks (can be turned off in the General tab)
    if ns.db.tooltipHints ~= false then
        GameTooltip:AddLine(" ")
        if mod.clickHint then GameTooltip:AddLine(mod.clickHint, 0.5, 0.8, 1) end
        if not ns.IsForwardingKey(key) then
            local shift = ns:GetActionName(key, cfg.shiftClick)
            if shift then GameTooltip:AddLine(L.HINT_SHIFT_ACTION:format(shift), 0.5, 0.8, 1) end
            local middle = ns:GetActionName(key, cfg.middleClick)
            if middle then GameTooltip:AddLine(L.HINT_MIDDLE_ACTION:format(middle), 0.5, 0.8, 1) end
            GameTooltip:AddLine(L.HINT_RIGHT_CLICK, 0.5, 0.8, 1)
        end
        GameTooltip:AddLine(L.HINT_QUICK_MENU, 0.5, 0.8, 1)
    end
    GameTooltip:Show()
end

local function OnLeave(self)
    if ns.hoveredBlock == self then ns.hoveredBlock = nil end
    if not ns:IsLocked() and ns.ClearPlacementInfo then ns:ClearPlacementInfo() end
    local cfg, mod = ns.db.blocks[self.key], ns:GetModule(self.key)
    if mod and mod.onLeave then pcall(mod.onLeave, self, cfg) end
    GameTooltip:Hide()
end

-- "Tooltips only while Alt is held": pressing or releasing Alt over a block shows or
-- hides its tooltip without having to move the mouse again
local altWatcher = CreateFrame("Frame")
altWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
altWatcher:SetScript("OnEvent", function(_, _, key, down)
    local f = ns.hoveredBlock
    if not (f and ns.db and ns.db.tooltipAltOnly) or (key ~= "LALT" and key ~= "RALT") then return end
    if not (f:IsShown() and f:IsMouseOver()) then
        ns.hoveredBlock = nil
        return
    end
    if down == 1 then
        OnEnter(f)
    else
        OnLeave(f)
        ns.hoveredBlock = f -- still under the mouse: Alt can show it again
    end
end)

-- dragMoved is set by the drag code (Merge.lua) so a drag is not taken for a click
local function OnMouseDown(self)
    self.dragMoved = false
end

-- Click: when unlocked, Ctrl + left click hides the block and right click (with or
-- without Alt) opens the quick menu; when locked, right click opens its options and
-- other clicks go to the module's onClick
local function OnMouseUp(self, button)
    if not ns:IsLocked() then
        if button == "LeftButton" and IsControlKeyDown() and not self.dragMoved
            and not ns:IsFrozen(self.key) then
            ns:PushUndo()
            ns:HideBlock(self.key)
        elseif button == "RightButton" then
            ns:OpenQuickMenu(self.key)
        end
        return
    end
    -- Right click (settings), Alt + right click (quick menu), Shift + click and
    -- middle click (configurable actions): see Placement.lua
    if ns:HandleLockedClick(self.key, button, self) then return end
    if button ~= "LeftButton" and not ns.IsForwardingKey(self.key) then return end
    local cfg, mod = ns.db.blocks[self.key], ns:GetModule(self.key)
    if mod and mod.onClick then
        GameTooltip:Hide()
        local ok, err = pcall(mod.onClick, self, button, cfg)
        if not ok then Print(tostring(err)) end
        ns:UpdateBlock(self.key)
    end
end

-- Mouse wheel (e.g. volume): only while blocks are locked
local function OnMouseWheel(self, delta)
    local mod = ns:GetModule(self.key)
    if not (mod and mod.onWheel) or not ns:IsLocked() then return end
    local ok, err = pcall(mod.onWheel, delta, ns.db.blocks[self.key])
    if not ok then Print(tostring(err)) end
    ns:UpdateBlock(self.key)
    if GameTooltip:IsOwned(self) then OnEnter(self) end
end

-- Placement mode: two small buttons on the hovered block, so nobody has to know the
-- shortcuts: a cross (top-right corner) hides the block, an arrow (top-left corner)
-- puts another block in its place. They show while the mouse is over the block or
-- over them, and go away on their own (OnUpdate) when it leaves, when the blocks
-- are locked, during a drag or a fight.
local function ControlsWanted(f)
    if ns:IsLocked() or ns:IsFrozen(f.key) or InCombatLockdown() or ns.dragging
        or not f:IsShown() then
        return false
    end
    return f:IsMouseOver() or f.closeBtn:IsMouseOver() or f.replaceBtn:IsMouseOver()
end

function ns:ShowBlockControls(f)
    if not f.closeBtn then return end
    local show = ControlsWanted(f)
    f.closeBtn:SetShown(show)
    f.replaceBtn:SetShown(show)
end

local function ControlTooltip(btn, text, f)
    if ns.ShowPlacementInfo and ns:ShowPlacementInfo({ text }, ns:GetBlockName(f.key)) then return end
    GameTooltip:SetOwner(btn, "ANCHOR_TOP")
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
end

local function CreateControl(f, path, corner, x, tip, onClick)
    local b = CreateFrame("Button", nil, f)
    b:SetSize(20, 20)
    b:SetPoint("CENTER", f, corner, x, -2)
    b:SetFrameStrata("FULLSCREEN_DIALOG")
    b:SetNormalTexture(path .. "-Up")
    b:SetPushedTexture(path .. "-Down")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Round", "ADD")
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", function(self) ControlTooltip(self, L[tip], f) end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if f:IsMouseOver() then OnEnter(f) elseif ns.ClearPlacementInfo then ns:ClearPlacementInfo() end
    end)
    b:SetScript("OnClick", function(self)
        if ns:IsLocked() or ns:IsFrozen(f.key) or InCombatLockdown() then return end
        GameTooltip:Hide()
        onClick(self)
    end)
    b:Hide()
    return b
end

local function CreateControls(f)
    f.closeBtn = CreateControl(f, "Interface\\Buttons\\UI-Panel-MinimizeButton", "TOPRIGHT", -2,
        "CLOSE_BUTTON_TIP", function()
            ns:PushUndo()
            ns:HideBlock(f.key)
        end)
    f.replaceBtn = CreateControl(f, "Interface\\Buttons\\UI-RotationRight-Button", "TOPLEFT", 2,
        "REPLACE_BUTTON_TIP", function()
            -- the menu belongs to the block, not to the arrows: they hide as soon as the
            -- mouse leaves the block, and a menu closes with the frame it belongs to
            ns:OpenReplaceMenu(f.key, f)
        end)
    -- the cross watches the mouse while shown and hides both buttons when it leaves
    f.closeBtn:SetScript("OnUpdate", function()
        if not ControlsWanted(f) then
            f.closeBtn:Hide()
            f.replaceBtn:Hide()
        end
    end)
end

-- Creates the frame of a block (icon, text, unlock highlight and name tag).
-- Styling and positioning are done afterwards by ApplyStyle.
local function CreateBlock(key)
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f.key = key
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) ns:BeginDrag(self) end)
    f:SetScript("OnDragStop", function(self) ns:EndDrag(self) end)
    f:SetScript("OnEnter", OnEnter)
    f:SetScript("OnLeave", OnLeave)
    f:SetScript("OnMouseDown", OnMouseDown)
    f:SetScript("OnMouseUp", OnMouseUp)
    if ns.modules[key] and ns.modules[key].onWheel then
        f:EnableMouseWheel(true)
        f:SetScript("OnMouseWheel", OnMouseWheel)
    end

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetWordWrap(false)

    -- Visual cue while blocks are unlocked
    f.highlight = f:CreateTexture(nil, "OVERLAY")
    f.highlight:SetAllPoints()
    f.highlight:SetColorTexture(0.2, 0.6, 1, 0.25)
    f.highlight:Hide()

    f.tag = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.tag:SetPoint("BOTTOM", f, "TOP", 0, 2)
    f.tag:Hide()

    CreateControls(f)

    ns.frames[key] = f
    return f
end

function ns:EnsureFrame(key)
    return self.frames[key] or CreateBlock(key)
end

-- Background, border and font of a block frame from its settings (also used for the
-- style previews of Options.lua). f needs a .text FontString. Returns the inset: the
-- space the border takes inside the frame.
function ns:SkinBlockFrame(f, cfg)
    local bg = self:FindMedia("background", cfg.bg)
    local border = self:FindMedia("border", cfg.border)
    -- colors after the class-color and high-contrast options
    local sv = self.sv or {}
    local borderColor = (cfg.classColorBorder and self:GetClassColor()) or cfg.borderColor
    local bgColor = cfg.bgColor
    if sv.highContrast then
        bgColor = { r = bgColor.r, g = bgColor.g, b = bgColor.b, a = math.max(bgColor.a or 1, 0.9) }
    end
    local inset = border.file and math.floor(cfg.borderSize * border.insetRatio + 0.5) or 0

    f.nineSliceInfo = nil
    if border.nineSlice and NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
        -- Modern Blizzard frame: border and background come from its atlases, tinted
        -- with the block's colors (the chosen background only decides whether it shows)
        local edge = self:ApplySkin(f, {
            kind = "modern", layout = border.nineSlice,
            border = borderColor, bg = bgColor, showCenter = bg.file ~= nil,
        })
        inset = math.max(0, math.floor(edge - 4 + 0.5))
        f.nineSliceInfo = { edge = edge }
    elseif bg.file or border.file then
        self:ApplySkin(f, {
            kind = "backdrop",
            info = {
                bgFile = bg.file,
                edgeFile = border.file,
                edgeSize = border.file and self:PixelSize(cfg.borderSize, f) or nil,
                tile = bg.tile or false,
                tileSize = bg.tile and 32 or nil,
                insets = { left = inset, right = inset, top = inset, bottom = inset },
            },
            border = borderColor, bg = bgColor,
        })
    else
        self:ApplySkin(f, { kind = "none" })
    end

    -- SetFont returns false if the font file cannot be loaded: fall back to the game font
    -- accessibility: minimum text size, thick outline in high contrast mode
    local font = self:FindMedia("font", cfg.font)
    local flags = cfg.outline ~= "NONE" and cfg.outline or ""
    if sv.highContrast then flags = "THICKOUTLINE" end
    local size = math.max(cfg.fontSize + (font.sizeBoost or 0), sv.minFontSize or 0)
    if not f.text:SetFont(font.file, size, flags) then
        f.text:SetFont(STANDARD_TEXT_FONT, size, flags)
    end
    local tc = (cfg.classColorText and self:GetClassColor()) or cfg.textColor
    -- the style's text color, unless the block has a text color of its own
    local tint = cfg.textTint
    if tint and (tint.a or 0) > 0 and tc == cfg.textColor and tc.r == 1 and tc.g == 1 and tc.b == 1 then
        tc = tint
    end
    if cfg.monochrome then
        local v = 0.3 * tc.r + 0.59 * tc.g + 0.11 * tc.b
        tc = { r = v, g = v, b = v, a = tc.a }
    end
    f.text:SetTextColor(tc.r, tc.g, tc.b, tc.a or 1)
    f.text:SetJustifyH(cfg.justify)
    return inset
end

-- Applies a block's saved settings to its frame: size, strata, position
-- (docked, default-layout anchor, saved point or default point), skin,
-- font, icon/text layout. Then refreshes visibility and the group layout.
function ns:ApplyStyle(key)
    local f, cfg = self.frames[key], self.db.blocks[key]
    if not f or not cfg then return end

    f:SetScale(self:GetBlockScale(key))
    f:SetSize(cfg.width, cfg.height)
    f:SetFrameStrata(cfg.strata)

    f:ClearAllPoints()
    if not self:AnchorDocked(f, cfg) and not self:AnchorToFrame(f, cfg) then
        if cfg.point then
            f:SetPoint(cfg.point[1], UIParent, cfg.point[2], cfg.point[3], cfg.point[4])
        else
            local p, rp, x, y = DefaultPoint(key)
            f:SetPoint(p, UIParent, rp, x, y)
        end
    end

    local inset = self:SkinBlockFrame(f, cfg)

    -- Icon to the left of the text, or alone in the center (launcher without label)
    local launcherLike = ns.IsLauncherKey(key) or (cfg.broker and cfg.broker.kind == "launcher")
    -- a "text only" style hides the icons, except the launchers' (they are the point)
    local showIcon = cfg.showIcon and not (cfg.hideIcons and not launcherLike)
    local iconOnly = showIcon and launcherLike and not cfg.showLabel
    -- icon size: chosen in pixels (to make every icon the same), or following the height
    local iconSize = (cfg.iconSize or 0) > 0 and math.min(cfg.iconSize, cfg.height * 2)
        or math.max(8, cfg.height - 2 * inset - 4)
    f.inset, f.iconSize, f.iconOnly = inset, iconSize, iconOnly
    f.borderKey = cfg.border
    f.lineReach = self:GetBorderReach(cfg.border)
    f.icon:SetSize(iconSize, iconSize)
    f.icon:ClearAllPoints()
    f.text:ClearAllPoints()
    if iconOnly then
        f.icon:SetPoint("CENTER")
    elseif showIcon then
        f.icon:SetPoint("LEFT", f, "LEFT", 4 + inset, 0)
        f.text:SetPoint("LEFT", f.icon, "RIGHT", 4, 0)
        f.text:SetPoint("RIGHT", f, "RIGHT", -4 - inset, 0)
    else
        f.text:SetPoint("LEFT", f, "LEFT", 4 + inset, 0)
        f.text:SetPoint("RIGHT", f, "RIGHT", -4 - inset, 0)
    end
    f.icon:SetShown(showIcon and true or false)
    self:StyleIcon(f, cfg)
    f.text:SetShown(not iconOnly)

    -- separator line of a spacer block in "line" mode
    if ns.IsSpacerKey(key) and cfg.spacerMode == "line" then
        f.sep = f.sep or f:CreateTexture(nil, "ARTWORK")
        local c = cfg.spacerColor or {}
        f.sep:SetColorTexture(c.r or 1, c.g or 0.82, c.b or 0, c.a or 0.6)
        f.sep:ClearAllPoints()
        -- whole screen pixels: a line thinner than a pixel can vanish when it moves
        local thin = self:PixelSize(cfg.spacerThickness or 2, f)
        if cfg.spacerOrientation == "horizontal" then
            f.sep:SetPoint("LEFT", f, "LEFT", 4 + inset, 0)
            f.sep:SetPoint("RIGHT", f, "RIGHT", -4 - inset, 0)
            f.sep:SetHeight(thin)
        else
            f.sep:SetPoint("TOP", f, "TOP", 0, -4 - inset)
            f.sep:SetPoint("BOTTOM", f, "BOTTOM", 0, 4 + inset)
            f.sep:SetWidth(thin)
        end
        f.sep:Show()
    elseif f.sep then
        f.sep:Hide()
    end

    -- progress bar: a band behind the text, filled by UpdateBlock
    f.bar = f.bar or f:CreateTexture(nil, "BACKGROUND", nil, 7)
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    f.bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", inset, inset)
    f.bar:Hide()
    f.barFraction = nil

    f.tag:SetText(self:GetBlockName(key))
    f.lastText = nil -- the text will be rewritten (otherwise the alignment does not follow)
    f.fade = f.fade or 1
    self:ApplyAlpha(f)
    self:ApplyLock(f)
    self:UpdateVisibility(key, true)
    self:RequestLayout()
end

-- Shows the unlock highlight and name tag while blocks are unlocked
-- (tagHidden is set by Merge.lua to avoid overlapping tags in a group)
function ns:ApplyLock(f)
    local unlocked = not self:IsLocked()
    -- placement mode: blue tint, grey for a frozen group
    if self:IsFrozen(f.key) then
        f.highlight:SetColorTexture(0.6, 0.6, 0.6, 0.3)
    else
        f.highlight:SetColorTexture(0.2, 0.6, 1, 0.25)
    end
    f.highlight:SetShown(unlocked)
    f.tag:SetShown(unlocked and not f.tagHidden)
    if not unlocked and f.closeBtn then
        f.closeBtn:Hide()
        f.replaceBtn:Hide()
    end
end

-- Should this block be visible right now (enabled, combat/instance/empty rules)?
function ns:ShouldShow(key)
    local cfg = self.db.blocks[key]
    if not cfg or not cfg.enabled then return false end
    if self.allHidden then return false end -- key binding "show / hide all blocks"
    if self.brokerModeActive then return false end -- DataBroker mode: another addon shows the data
    if self:IsLocked() then -- when unlocked, everything is visible for placement
        if cfg.hideInCombat and self.state.inCombat then return false end
        if cfg.hideInInstance and self.state.inInstance then return false end
        if cfg.hideInVehicle and self.state.inVehicle then return false end
        if cfg.hideWhenResting and IsResting and IsResting() then return false end
        -- a spacer merged with other blocks hides when none of them is shown
        -- (e.g. in the second row when every block in it is empty)
        if ns.IsSpacerKey(key) and not self.previewMode then
            local others, anyShown = 0, false
            for k in pairs(self:GetSubtree(self:GetRoot(key))) do
                if not ns.IsSpacerKey(k) then
                    others = others + 1
                    if self:ShouldShow(k) then anyShown = true break end
                end
            end
            if others > 0 and not anyShown then return false end
        end
        local mod = self:GetModule(key)
        if cfg.hideEmpty and mod and mod.isEmpty and not self.previewMode then
            local ok, empty = pcall(mod.isEmpty, cfg)
            if ok and empty then return false end
        end
    end
    return true
end

-- Shows or hides a block; refreshes its content when it appears (or when forced)
function ns:UpdateVisibility(key, forceUpdate)
    local f = self.frames[key]
    if not f then return end
    local show = self:ShouldShow(key)
    local wasShown = f:IsShown()
    f:SetShown(show)
    if show ~= wasShown then self:RequestLayout() end
    if show and (forceUpdate or not wasShown) then self:UpdateBlock(key) end
end

function ns:UpdateAllVisibility()
    for _, key in ipairs(self:GetBlockKeys()) do self:UpdateVisibility(key) end
end

-- Everything that depends on the locked state: highlights, visibility, grid,
-- placement banner, and the secure click overlays (SecureClicks.lua)
function ns:RefreshLockState()
    for _, f in pairs(self.frames) do self:ApplyLock(f) end
    self:UpdateAllVisibility()
    self:UpdateGrid()
    if self.UpdatePlacementBanner then self:UpdatePlacementBanner() end
    self:RequestOverlaySync()
end

-- (silent: no chat message, e.g. when Blizzard's Edit Mode opens or closes)
function ns:SetLocked(locked, silent)
    if not locked and self.DemoBlocksUnlock and self:DemoBlocksUnlock() then return end
    self.db.locked = locked
    self:RefreshLockState()
    if self.RefreshOptions then self:RefreshOptions() end
    if not silent then Print(locked and L.CMD_LOCKED or L.CMD_UNLOCKED) end
end

-- Refreshes a block's text and icon from its module. mod.update(cfg, key)
-- returns the value to display and an optional threshold level (1-3).
-- Errors are reported once per block, then the block shows "N/A".
function ns:UpdateBlock(key)
    local f, cfg = self.frames[key], self.db.blocks[key]
    if not f or not cfg then return end
    local mod = self:GetModule(key)
    if not mod then return end
    -- Block that hides itself when empty: re-check its visibility on every update
    if mod.isEmpty and cfg.enabled then
        local show = self:ShouldShow(key)
        if show ~= f:IsShown() then
            f:SetShown(show)
            self:RequestLayout()
            -- e.g. new mail: flash the block once when it appears (not at login)
            if show and mod.alertOnShow and cfg.alert and self.alertsReady then self:Flash(f) end
            -- spacers merged with it may have to appear / disappear too
            for k in pairs(self.db.blocks) do
                if ns.IsSpacerKey(k) then self:UpdateVisibility(k) end
            end
        end
    end
    if not f:IsShown() then return end

    local ok, value, level
    if self.previewMode and mod.sample then
        -- preview mode: sample value (a function or a plain text)
        if type(mod.sample) == "function" then
            ok, value, level = pcall(mod.sample, cfg)
        else
            ok, value, level = true, mod.sample, 1
        end
    else
        ok, value, level = pcall(mod.update, cfg, key)
    end
    if not ok then
        if not self.errors[key] then
            self.errors[key] = tostring(value) -- kept for /tessera bug
            Print("[" .. self:GetBlockName(key) .. "] " .. tostring(value))
        end
        value, level = nil, nil
    end
    -- turning red: flash once (not at login, nor while placing blocks)
    -- (at most once a minute per block, so a value hovering around the threshold does not blink)
    if cfg.alert and level == 3 and f.lastLevel ~= 3 and self.alertsReady and self:IsLocked()
        and GetTime() - (f.lastFlash or 0) > 60 then
        f.lastFlash = GetTime()
        self:Flash(f)
    end
    f.lastLevel = level
    self:UpdateBar(f, cfg, mod, level)
    if value == nil then value = L.NA end
    value = tostring(value)
    if cfg.monochrome then
        -- black and white style: the colors and the small pictures (coins, currencies)
        -- written into the value go away
        value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    elseif cfg.colorize and level and self.LEVEL_COLORS[level] and value ~= "" then
        value = "|cff" .. self.LEVEL_COLORS[level] .. value .. "|r"
    end
    if cfg.inkColors then
        -- light background (Parchment): bright colors would not read, they get darker
        value = value:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", function(a, r, g, b)
            local function ink(h) return math.floor(tonumber(h, 16) * 0.38) end
            return ("|c%s%02x%02x%02x"):format(a, ink(r), ink(g), ink(b))
        end)
    end

    local text = value
    if cfg.showLabel then
        local label = self:GetBlockName(key)
        text = (value ~= "") and L.LABEL_FORMAT:format(label, value) or label
    end
    -- Only touch the FontString when the text changed (avoids needless relayouts)
    if f.lastText ~= text then
        if f.lastText == nil then f.text:SetText("") end -- forces a redraw
        f.lastText = text
        f.text:SetText(text)
        self:RequestLayout()
    end

    if cfg.showIcon then
        local okIcon, icon = pcall(function()
            if mod.getIcon then return mod.getIcon(cfg) end
            return mod.icon
        end)
        if okIcon and icon then
            self:SetIcon(f.icon, icon)
            self:StyleIcon(f, cfg)
        end
    end
end

-- Progress bar behind the text (option "progress bar", for modules with progress()).
-- Colored like the block's level, or blue-grey when the module gives no level.
function ns:UpdateBar(f, cfg, mod, level)
    if not f.bar then return end
    local fraction
    if cfg.progressBar and mod.progress then
        local ok, value = pcall(mod.progress, cfg)
        if ok and type(value) == "number" then fraction = math.max(0, math.min(1, value)) end
    end
    if not fraction then
        f.bar:Hide()
        f.barFraction = nil
        return
    end
    f.barFraction = fraction
    local hex = level and not cfg.monochrome and self.LEVEL_COLORS[level]
    if cfg.monochrome then
        f.bar:SetColorTexture(0.7, 0.7, 0.7, 0.3)
    elseif hex then
        f.bar:SetColorTexture(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
            tonumber(hex:sub(5, 6), 16) / 255, 0.35)
    else
        f.bar:SetColorTexture(0.35, 0.6, 1, 0.35)
    end
    self:ResizeBar(f)
end

-- Bar width follows the block's width (also called after a layout pass)
function ns:ResizeBar(f)
    if not (f.bar and f.barFraction) then return end
    local inner = f:GetWidth() - 2 * (f.inset or 0)
    local w = inner * f.barFraction
    f.bar:SetWidth(math.max(0.01, w))
    f.bar:SetShown(w >= 0.5)
end

-- Short flash (three pulses) to draw attention to a block
function ns:Flash(f)
    if not f.flash then
        f.flash = f:CreateTexture(nil, "OVERLAY")
        f.flash:SetAllPoints()
        f.flash:SetColorTexture(1, 1, 1, 1)
        f.flash:SetBlendMode("ADD")
        f.flash:SetAlpha(0)
        local group = f.flash:CreateAnimationGroup()
        for i = 1, 3 do
            local up = group:CreateAnimation("Alpha")
            up:SetFromAlpha(0)
            up:SetToAlpha(0.5)
            up:SetDuration(0.2)
            up:SetOrder(2 * i - 1)
            local down = group:CreateAnimation("Alpha")
            down:SetFromAlpha(0.5)
            down:SetToAlpha(0)
            down:SetDuration(0.3)
            down:SetOrder(2 * i)
        end
        f.flashGroup = group
    end
    f.flashGroup:Stop()
    f.flashGroup:Play()
end

-- Opacity of a block: its own opacity x the hover-fade factor
function ns:ApplyAlpha(f)
    local cfg = self.db.blocks[f.key]
    if not cfg then return end
    f:SetAlpha((cfg.alpha or 1) * (f.fade or 1))
end

-- Hover fade: blocks with "fade out" stay faint until the mouse is over their
-- group (a merged group, plus its second row, reacts as one), and show in combat
-- if asked. Always fully shown while placing blocks.
local FADE_STEP = 0.25
function ns:UpdateFades()
    local hovered = {}
    for key, f in pairs(self.frames) do
        if f:IsShown() and f:IsMouseOver() then hovered[self:GetVisualRoot(key)] = true end
    end
    local locked = self:IsLocked()
    for key, f in pairs(self.frames) do
        local cfg = self.db.blocks[key]
        if cfg and f:IsShown() then
            local target = 1
            if cfg.fadeOut and locked and not hovered[self:GetVisualRoot(key)]
                and not (cfg.fadeShowCombat and self.state.inCombat) then
                target = cfg.fadeAlpha or 0
            end
            local current = f.fade or 1
            if math.abs(current - target) > 0.001 then
                if current < target then
                    f.fade = math.min(target, current + FADE_STEP)
                else
                    f.fade = math.max(target, current - FADE_STEP)
                end
                self:ApplyAlpha(f)
            end
        end
    end
end

-- In a vehicle, or on a flight path (taxi): used by "Hide in a vehicle / on a flight"
function ns:UpdateVehicleState()
    self.state.inVehicle = (UnitHasVehicleUI and UnitHasVehicleUI("player"))
        or (UnitInVehicle and UnitInVehicle("player"))
        or (UnitOnTaxi and UnitOnTaxi("player")) or false
end

-- Preview mode: every block shows a sample value (and the blocks that hide when
-- empty are shown), to take screenshots for the addon's page
function ns:SetPreview(on)
    self.previewMode = on or nil
    self:UpdateAllVisibility()
    self:UpdateAll()
    Print(on and L.PREVIEW_ON or L.PREVIEW_OFF)
end

function ns:UpdateAll()
    for _, key in ipairs(self:GetBlockKeys()) do self:UpdateBlock(key) end
end

-- Creates, skins or hides blocks according to the active profile
function ns:RefreshAllBlocks()
    local active = {}
    local keys = self:GetBlockKeys()
    for _, key in ipairs(keys) do
        active[key] = true
        self:EnsureFrame(key)
    end
    -- forget every old anchor first: after a profile or layout change, a block may
    -- now be docked to a block that was docked to it before, and anchoring it while
    -- the old anchor still exists would make a loop (the game refuses it)
    for _, f in pairs(self.frames) do f:ClearAllPoints() end
    for _, key in ipairs(keys) do self:ApplyStyle(key) end
    for key, f in pairs(self.frames) do
        if not active[key] then f:Hide() end
    end
    self:UpdateGrid()
    if self.RefreshOptions then self:RefreshOptions() end
end

-- Seam length at inner corners, specific to each border: the value chosen by
-- the user (saved account-wide) or the border's original value
function ns:GetBorderReach(borderKey)
    local custom = self.sv and self.sv.borderReach and self.sv.borderReach[borderKey]
    if custom then return custom end
    return self:FindMedia("border", borderKey).reach or 0.5
end

function ns:HasCustomBorderReach(borderKey)
    return self.sv and self.sv.borderReach and self.sv.borderReach[borderKey] ~= nil
end

-- value = nil: back to the original value
function ns:SetBorderReach(borderKey, value)
    self.sv.borderReach = self.sv.borderReach or {}
    self.sv.borderReach[borderKey] = value
    for _, key in ipairs(self:GetBlockKeys()) do self:ApplyStyle(key) end
end

-- Disables a block (Ctrl+click in placement mode); it can be re-enabled in the options
function ns:HideBlock(key)
    local cfg = self.db.blocks[key]
    if not cfg then return end
    GameTooltip:Hide()
    cfg.enabled = false
    self:ApplyStyle(key)
    Print(L.BLOCK_HIDDEN:format(self:GetBlockName(key)))
    if self.RefreshOptions then self:RefreshOptions() end
end

-- Restores a block's default settings (a launcher keeps what it launches)
-- Puts a block's settings back to their defaults. Its place is kept (position,
-- merges, visibility, group scale): otherwise the block and every block merged
-- with it would jump to a default spot.
local KEEP_ON_RESET = { "point", "dock", "anchor", "enabled", "scale", "frozen", "launcher", "broker", "brokerShare" }
-- Puts block newKey exactly where block oldKey is, without moving anything else:
--   * newKey takes oldKey's place (its dock, or its free position / anchor if it
--     heads a group, with the group's scale and frozen state), and every block
--     docked or hanging on oldKey now follows newKey;
--   * newKey takes oldKey's look (size, font, frame...) so it fits in the group;
--   * oldKey is hidden. If newKey was shown somewhere else, the two blocks swap
--     places instead (each keeps its own look).
--   * a spacer replaced by a block is deleted (the ready-made layouts leave spacers
--     in their bars for this); the block takes its font and frame, not its size.
-- Undoable with Ctrl + Z in placement mode. Returns true when done.
-- The group's own settings (screen edges, stretch, group look) are carried by its
-- first block, so they move with the place too.
local PLACE_FIELDS = { "point", "dock", "anchor", "scale", "frozen", "edges", "stretch", "look" }
function ns:ReplaceBlock(oldKey, newKey)
    local blocks = self.db.blocks
    local old, new = blocks[oldKey], blocks[newKey]
    if not old or not new or oldKey == newKey or InCombatLockdown() then return false end
    self:PushUndo()
    local swap = new.enabled and self.frames[newKey] ~= nil
    -- every reference to one of the two blocks now points to the other
    -- (a swap) or to the new one (a replacement)
    local function Relabel(k)
        if k == oldKey then return newKey end
        if swap and k == newKey then return oldKey end
        return k
    end
    for _, cfg in pairs(blocks) do
        if cfg.dock then cfg.dock.to = Relabel(cfg.dock.to) end
        if cfg.anchor then
            if cfg.anchor.below then cfg.anchor.below = Relabel(cfg.anchor.below) end
            if cfg.anchor.above then cfg.anchor.above = Relabel(cfg.anchor.above) end
        end
    end
    -- then the place itself moves (both ways for a swap)
    local oldPlace, newPlace = {}, {}
    for _, field in ipairs(PLACE_FIELDS) do
        oldPlace[field], newPlace[field] = old[field], new[field]
    end
    for _, field in ipairs(PLACE_FIELDS) do
        new[field] = oldPlace[field]
        old[field] = swap and newPlace[field] or nil
    end
    new.enabled = true
    local spacer = not swap and ns.IsSpacerKey(oldKey)
    if not swap then
        old.enabled = false
        -- the new block blends in: same size and look as the one it replaces
        -- (a spacer only gives its look: its size is just some room)
        for _, k in ipairs(STYLE_KEYS) do
            if not (spacer and k == "height") then new[k] = DeepCopy(old[k]) end
        end
        if not spacer then new.width = old.width end
    end
    if spacer then
        blocks[oldKey] = nil
        if self.frames[oldKey] then self.frames[oldKey]:Hide() end
    end
    self:RefreshAllBlocks()
    self:RequestLayout()
    if swap then
        Print(L.REPLACE_SWAPPED:format(self:GetBlockName(oldKey), self:GetBlockName(newKey)))
    else
        Print(L.REPLACE_DONE:format(self:GetBlockName(newKey), self:GetBlockName(oldKey)))
    end
    return true
end

function ns:ResetBlock(key)
    local cfg = self:GetBlockDefaults(key)
    local old = self.db.blocks[key]
    if old then
        for _, field in ipairs(KEEP_ON_RESET) do cfg[field] = self.DeepCopy(old[field]) end
    end
    self.db.blocks[key] = cfg
    self:ApplyStyle(key)
end

-- Copies the appearance settings (STYLE_KEYS) of one block to all others
function ns:CopyStyleToAll(sourceKey)
    local src = self.db.blocks[sourceKey]
    for _, key in ipairs(self:GetBlockKeys()) do
        if key ~= sourceKey then
            local cfg = self.db.blocks[key]
            for _, k in ipairs(STYLE_KEYS) do cfg[k] = DeepCopy(src[k]) end
            self:ApplyStyle(key)
        end
    end
end

---------------------------------------------------------------------------
-- Default layout: a compact bar centered at the top of the screen
-- (icon + value), in FlareUI style if FlareUI is installed
---------------------------------------------------------------------------
-- Total width 568 px and position (top, centered, 6 px from the edge): those of
-- FlareUI's default XP bar. Without FlareUI, the bar takes that spot;
-- with FlareUI, it sits 6 px below its XP bar.
-- Widths are minimums; below FlareUI's XP bar, the visible blocks share its
-- full width (friends and guild hide themselves when empty)
local BASE_ROW = {
    { key = "gold",       width = 120 },
    { key = "bags",       width = 64 },
    { key = "durability", width = 64 },
    { key = "fps",        width = 72 },
    { key = "latency",    width = 72 },
    { key = "guild",      width = 64 },
    { key = "friends",    width = 52 },
    { key = "time",       width = 60 },
}
-- Second row, under the base bar: blocks that hide themselves when they have
-- nothing to show. The row only appears when one of them has something to show,
-- and its visible blocks share the base bar's width.
local SECOND_ROW = { "mail", "whispers", "reputation", "currency", "reagents", "ammo", "instances" }
local SECOND_ROW_WIDTH = 60
-- "Double bar" layout: the same top bar, and a second bar always shown with WoW
-- Forever's own blocks (the blocks of the usual second row join it when they have
-- something to show)
local FOREVER_ROW = { "legacy", "comprehension", "camping", "honor", "weaponSkills",
    "mail", "whispers", "reputation", "currency", "reagents", "ammo", "instances" }
local FOREVER_ROW_HIDE_EMPTY = { mail = true, whispers = true, reputation = true, currency = true,
    reagents = true, ammo = true, instances = true }
local IN_SECOND_ROW = {}
for _, key in ipairs(SECOND_ROW) do IN_SECOND_ROW[key] = true end
local BASE_TOP, BASE_HEIGHT = -6, 24
local BASE_GAP = 6                     -- space below FlareUI's XP bar
local FLAREUI_XPBAR = "FlareUI_XPBar"

-- Default group, centered automatically (cfg.anchor = { frame, gap, top }):
--   frame exists and is shown: below that frame (FlareUI's XP bar), "gap" px away
--   frame hidden (max level):  in its place
--   no frame:                  at the top of the screen, "top" px from the edge
-- f.centerOffset (computed by UpdateLayout) centers the whole group on the reference.
-- Returns false when the block has no such anchor (caller then uses cfg.point).
-- The frame a top bar follows: its own, or FlareUI's XP bar for a bar of the default
-- layout made before this was saved (anchor.top without a frame)
function ns.AnchorFrameName(anchor)
    if not anchor then return nil end
    return anchor.frame or (anchor.top and FLAREUI_XPBAR) or nil
end

local hookedFrames = {}
function ns:AnchorToFrame(f, cfg)
    local anchor = cfg.anchor
    if not anchor then return false end
    local offset = f.centerOffset or 0
    -- second row: below another group's head block (centering offset from Merge.lua)
    -- bottom bar: centered at the bottom of the screen
    if anchor.bottom then
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", offset, anchor.bottom)
        return true
    end
    local hang = ns.HangTarget(anchor)
    if hang then
        local base = self.frames[hang]
        if base and hang ~= f.key then
            -- row aligned on one edge of the block below instead of centered
            -- (above a group in a screen corner: starts at the screen's edge)
            if anchor.align == "LEFT" then
                f:SetPoint("BOTTOMLEFT", base, "TOPLEFT", 0, anchor.gap or 0)
            elseif anchor.align == "RIGHT" then
                f:SetPoint("BOTTOMRIGHT", base, "TOPRIGHT", 0, anchor.gap or 0)
            elseif anchor.above then
                f:SetPoint("BOTTOMLEFT", base, "TOPLEFT", offset, anchor.gap or 0)
            else
                f:SetPoint("TOPLEFT", base, "BOTTOMLEFT", offset, -(anchor.gap or 0))
            end
            return true
        end
        return false
    end
    local name = ns.AnchorFrameName(anchor)
    local target = name and _G[name]
    if not target or not target.GetBottom then
        f:SetPoint("TOPLEFT", UIParent, "TOP", offset, anchor.top or BASE_TOP)
        return true
    end
    -- Follow the target showing/hiding (e.g. XP bar hidden at max level).
    -- HookScript is used rather than SetScript so the other addon's frame is not tainted.
    if not hookedFrames[target] then
        hookedFrames[target] = true
        local function Reanchor()
            if ns.built then
                for _, key in ipairs(ns:GetBlockKeys()) do
                    local c = ns.db.blocks[key]
                    if c and c.anchor and not c.dock then ns:ApplyStyle(key) end
                end
            end
        end
        target:HookScript("OnShow", Reanchor)
        target:HookScript("OnHide", Reanchor)
        -- its width changes (FlareUI's settings): the bar is laid out again
        target:HookScript("OnSizeChanged", function() if ns.built then ns:RequestLayout() end end)
    end
    if target:IsShown() then
        f:SetPoint("TOPLEFT", target, "BOTTOMLEFT", offset, -(anchor.gap or BASE_GAP))
    else
        f:SetPoint("TOPLEFT", target, "TOPLEFT", offset, 0)
    end
    return true
end

-- Horizontal offset that centers the group (width groupWidth, head at headX
-- from the group's left edge) on its anchor's reference
function ns:GetCenterOffset(cfg, groupWidth, headX, f)
    local name = ns.AnchorFrameName(cfg.anchor)
    local target = name and _G[name]
    if target and target.GetWidth and target:GetWidth() > 0 then
        -- the target's width, converted to the block's own units (it may have its own scale)
        local width = target:GetWidth()
        if f then width = width * target:GetEffectiveScale() / f:GetEffectiveScale() end
        return (width - groupWidth) / 2 + headX
    end
    return -groupWidth / 2 + headX
end

-- Builds the default layout (BASE_ROW) into profile p: one row of merged blocks
-- Ready-made layouts (Profiles tab). "top" is the default one.
--   top      bar at the top of the screen (under FlareUI's XP bar if present)
--   forever  the same bar, and a second bar always shown with WoW Forever's own blocks
--   bottom   bar at the bottom of the screen, its second row above it
--   left     column on the left of the screen, every block stacked
--   compact  top bar with small blocks, sized to their content
--   gryphons two groups in the bottom corners of the screen, WoW Forever blocks included
--   stormwind, cathedral, tirisfal, gnomeregan   bars stuck to a screen edge, like
--            the taskbars and menu bars of desktop systems (see OS_LAYOUTS)
ns.PRESETS = { "top", "forever", "bottom", "left", "compact", "gryphons", "stormwind", "cathedral", "tirisfal",
    "gnomeregan" }

-- Last step of every ready-made layout: icon without label on all data blocks
-- (even hidden ones), the theme's look, remembered for future blocks
local function FinishBaseLayout(self, p)
    for _, cfg in pairs(p.blocks) do
        if not cfg.launcher then cfg.showIcon, cfg.showLabel = true, false end
        self:ApplyThemeToCfg(cfg)
    end
    p.groupDefaults = p.groupDefaults or {}
    p.groupDefaults.showIcon, p.groupDefaults.showLabel = true, false
    p.initialized = true
end

-- "Around the gryphons": one group in each bottom corner of the screen, on both
-- sides of the action bars. Anchored to the screen's corners (a plain cfg.point),
-- so it fits every resolution and interface, whatever the action bars look like.
-- Each group is 2 blocks wide and 3 rows high (about the height of two action
-- bars). "rows" go from the bottom up, each row from the corner toward the center.
-- The first block of each row never hides itself: the bottom one is the group's
-- head, in the corner, the others are docked above it; the second block of a row
-- may hide (Comprehension, Camping...) without leaving a gap. Blocks that hide when
-- empty ("hide") form a small row above the group, starting at the screen's edge.
-- Blocks that do not exist on this client (WoW Forever ones elsewhere) are skipped.
local GRYPHON_GROUPS = {
    { corner = "BOTTOMLEFT", x = 4, inward = "RIGHT", align = "LEFT",
      rows = { { "legacy", "comprehension" }, { "durability", "camping" }, { "gold", "bags" } },
      hide = { "mail", "whispers", "reputation" } },
    { corner = "BOTTOMRIGHT", x = -4, inward = "LEFT", align = "RIGHT",
      rows = { { "honor", "weaponSkills" }, { "latency", "fps" }, { "time", "xp" } },
      hide = { "friends", "guild", "group", "talents" } },
}
local GRYPHON_HIDE_EMPTY = { comprehension = true, camping = true }
local GRYPHON_WIDTH, GRYPHON_Y = 56, 4

function ns:ApplyGryphonsLayout(p)
    local used = {}
    local function Present(list)
        local out = {}
        for _, key in ipairs(list) do
            if p.blocks[key] and self.modules[key] then table.insert(out, key) end
        end
        return out
    end
    local function Prepare(key)
        local cfg = p.blocks[key]
        cfg.enabled = true
        cfg.width, cfg.height = GRYPHON_WIDTH, BASE_HEIGHT
        cfg.anchor, cfg.point, cfg.dock = nil, nil, nil
        if GRYPHON_HIDE_EMPTY[key] then cfg.hideEmpty = true end
        used[key] = true
        return cfg
    end
    for _, g in ipairs(GRYPHON_GROUPS) do
        local head, below -- group head, first block of the row below
        for _, row in ipairs(g.rows) do
            local keys = Present(row)
            for i, key in ipairs(keys) do
                local cfg = Prepare(key)
                if i > 1 then
                    cfg.dock = { to = keys[i - 1], side = g.inward }
                elseif below then
                    cfg.dock = { to = below, side = "TOP" }
                else
                    cfg.point = { g.corner, g.corner, g.x, GRYPHON_Y }
                    head = key
                end
            end
            if keys[1] then below = keys[1] end
        end
        -- blocks that hide when empty: above the top row, from the screen's edge inward
        if head then
            local hide = Present(g.hide)
            for i, key in ipairs(hide) do
                local cfg = Prepare(key)
                cfg.hideEmpty = true
                if i == 1 then
                    cfg.anchor = { above = below, gap = 0, align = g.align }
                else
                    cfg.dock = { to = hide[i - 1], side = g.inward }
                end
            end
        end
    end
    -- every other data block starts hidden (the player can turn it on in the Blocks tab)
    for key, cfg in pairs(p.blocks) do
        if self.modules[key] and not used[key] then cfg.enabled = false end
    end
end

-- Layouts in the spirit of desktop systems (Warcraft-flavored names). Each bar is a list of blocks from left
-- to right (or top to bottom for a column); SPACER marks an empty spacer block,
-- several in a row rather than one huge one, so each can later be replaced by a
-- block ("Replace with..."). A bar along the top or bottom edge is stuck to it and
-- stretched over the whole width: only its spacers stretch (see Merge.lua), the
-- blocks keep their size. Placed like the real ones: clock at the right end of the
-- taskbar / menu bar (in the center of the top bar for Gnomeregan), network (latency),
-- volume and FPS next to it.
local SPACER = "|spacer"
local OS_LAYOUTS = {
    stormwind = { -- a taskbar along the bottom, pinned blocks on the left
        { edge = "BOTTOM", items = { "bags", "legacy", "comprehension", "camping", "honor",
            SPACER, SPACER, SPACER, SPACER, "fps", "latency", "volume", "time", "mail", "whispers" } },
    },
    cathedral = { -- the same taskbar with its blocks in the center
        { edge = "BOTTOM", items = { "zone", SPACER, SPACER, SPACER, "gold", "bags", "legacy", "comprehension",
            "camping", SPACER, SPACER, SPACER, "fps", "latency", "volume", "time", "mail", "whispers" } },
    },
    tirisfal = { -- a menu bar along the top and a dock
        { edge = "TOP", items = { "zone", "subzone", "coords", SPACER, SPACER, SPACER, SPACER,
            "bags", "durability", "fps", "latency", "volume", "time" } },
        -- the Dock, on the left edge (an option of the real one): the bottom of the
        -- screen belongs to the action bars
        { edge = "LEFT", items = { "legacy", "comprehension", "camping", "honor", "weaponSkills", "gold" } },
    },
    gnomeregan = { -- a top bar with the clock in the center
        { edge = "TOP", items = { "zone", SPACER, SPACER, SPACER, "time", SPACER, SPACER, SPACER,
            "gold", "bags", "fps", "latency", "volume" } },
    },
}
local OS_HIDE_EMPTY = { comprehension = true, camping = true, mail = true, whispers = true }
local OS_WIDTH = 56

function ns:ApplyOSLayout(p, preset)
    local used = {}
    local function NewSpacer()
        local n = 1
        while p.blocks[self.SPACER_PREFIX .. n] do n = n + 1 end
        local key = self.SPACER_PREFIX .. n
        p.blocks[key] = self:GetBlockDefaults(key)
        p.blocks[key].width = 8 -- a stretched bar gives its spacers the room left
        return key
    end
    for _, bar in ipairs(OS_LAYOUTS[preset] or {}) do
        local keys = {}
        for _, item in ipairs(bar.items) do
            if item == SPACER then
                table.insert(keys, NewSpacer())
            elseif p.blocks[item] and self.modules[item] then
                table.insert(keys, item)
            end
        end
        local column = bar.edge == "LEFT" or bar.edge == "RIGHT"
        for i, key in ipairs(keys) do
            local cfg = p.blocks[key]
            cfg.enabled = true
            cfg.height = BASE_HEIGHT
            if not self.IsSpacerKey(key) then cfg.width = OS_WIDTH end
            cfg.anchor, cfg.point, cfg.dock, cfg.edges, cfg.stretch = nil, nil, nil, nil, nil
            if OS_HIDE_EMPTY[key] then cfg.hideEmpty = true end
            used[key] = true
            if i > 1 then
                cfg.dock = { to = keys[i - 1], side = column and "BOTTOM" or "RIGHT" }
            elseif column then
                cfg.point = { bar.edge, bar.edge, 0, 60 }
                cfg.edges = { [bar.edge] = true }
            else
                local corner = bar.edge .. "LEFT"
                cfg.point = { corner, corner, 0, 0 }
                cfg.edges = { [bar.edge] = true, LEFT = true, RIGHT = true }
                cfg.stretch = bar.edge
            end
        end
    end
    for key, cfg in pairs(p.blocks) do
        if self.modules[key] and not used[key] then cfg.enabled = false end
    end
end

function ns:ApplyBaseLayout(p, preset)
    preset = preset or "top"
    -- layouts showing off the WoW Forever blocks: lines between merged blocks, in
    -- the color of the style's border
    local function WithSeparators()
        for _, cfg in pairs(p.blocks) do
            if not cfg.launcher then
                local c = cfg.borderColor or { r = 1, g = 1, b = 1 }
                cfg.separators = true
                cfg.separatorColor = { r = c.r, g = c.g, b = c.b, a = 0.5 }
            end
        end
    end
    if OS_LAYOUTS[preset] then
        self:ApplyOSLayout(p, preset)
        FinishBaseLayout(self, p)
        WithSeparators()
        return
    end
    if preset == "gryphons" then
        self:ApplyGryphonsLayout(p)
        FinishBaseLayout(self, p)
        WithSeparators()
        return
    end
    local vertical = preset == "left"
    local compact = preset == "compact"
    local height = compact and 20 or BASE_HEIGHT
    local total = 0
    for _, item in ipairs(BASE_ROW) do total = total + item.width end

    -- First block placed, the following ones merged to it (right, or below in a column)
    local x, previous = -total / 2, nil
    for _, item in ipairs(BASE_ROW) do
        local cfg = p.blocks[item.key]
        if cfg then
            cfg.enabled = true
            cfg.width = compact and 16 or item.width
            cfg.height = height
            if compact then cfg.fontSize = 11 end
            cfg.showIcon = true
            cfg.showLabel = false
            cfg.anchor, cfg.point, cfg.dock = nil, nil, nil
            if previous then
                cfg.dock = { to = previous, side = vertical and "BOTTOM" or "RIGHT" }
            elseif preset == "left" then
                cfg.point = { "TOPLEFT", "LEFT", 12, 160 }
            elseif preset == "bottom" then
                cfg.point = { "BOTTOMLEFT", "BOTTOM", math.floor(x + 0.5), 140 }
                cfg.anchor = { bottom = 140 } -- kept centered at the bottom of the screen
            else
                cfg.point = { "TOPLEFT", "TOP", math.floor(x + 0.5), BASE_TOP }
                -- under FlareUI's XP bar whenever it exists, also when FlareUI or its XP bar
                -- is turned on later (without it, at the top of the screen)
                cfg.anchor = { top = BASE_TOP, frame = FLAREUI_XPBAR, gap = BASE_GAP, fill = not compact }
            end
            previous = item.key
        end
        x = x + item.width
    end

    -- Second row (blocks that hide when empty): below the bar, above it for a
    -- bottom bar, or simply further down the column
    local last = previous
    previous = nil
    local forever = preset == "forever"
    for _, key in ipairs(forever and FOREVER_ROW or SECOND_ROW) do
        local cfg = p.blocks[key]
        if cfg then
            cfg.enabled = true
            if forever then cfg.hideEmpty = FOREVER_ROW_HIDE_EMPTY[key] or false end
            cfg.width = compact and 16 or SECOND_ROW_WIDTH
            cfg.height = height
            if compact then cfg.fontSize = 11 end
            cfg.point, cfg.anchor, cfg.dock = nil, nil, nil
            if vertical then
                cfg.dock = { to = previous or last, side = "BOTTOM" }
            elseif previous then
                cfg.dock = { to = previous, side = "RIGHT" }
            elseif preset == "bottom" then
                cfg.anchor = { above = BASE_ROW[1].key, fill = true, gap = 0 }
            else
                cfg.anchor = { below = BASE_ROW[1].key, fill = not compact, gap = 0 }
            end
            previous = key
        end
    end

    FinishBaseLayout(self, p)
end

-- Settings taken from a visible block when a never-placed block appears
local ADOPT_KEYS = {
    "showIcon", "showLabel", "tooltip", "colorize", "autoWidth",
    "hideInCombat", "hideInInstance",
}

-- Visible data block used as a model (default row first)
function ns:GetReferenceBlock(exclude)
    local blocks = self.db.blocks
    for _, item in ipairs(BASE_ROW) do
        local cfg = blocks[item.key]
        if item.key ~= exclude and cfg and cfg.enabled and not cfg.launcher then return item.key end
    end
    local keys = {}
    for key, cfg in pairs(blocks) do
        if key ~= exclude and cfg.enabled and not cfg.launcher and not ns.IsSpacerKey(key) then keys[#keys + 1] = key end
    end
    table.sort(keys)
    return keys[1]
end

-- Gives a data block the look and behavior settings of the reference block
function ns:AdoptReferenceStyle(key, refKey)
    local cfg, ref = self.db.blocks[key], refKey and self.db.blocks[refKey]
    if not cfg or not ref or cfg.launcher then return end
    for _, k in ipairs(STYLE_KEYS) do cfg[k] = self.DeepCopy(ref[k]) end
    for _, k in ipairs(ADOPT_KEYS) do cfg[k] = self.DeepCopy(ref[k]) end
end

-- A block added by an update to an existing profile: second-row blocks join the
-- end of the second row (created if needed, under the base bar); the others stay
-- hidden until the player enables them
function ns:AttachNewBlock(p, key)
    local cfg = p.blocks[key]
    if not cfg or not cfg.enabled then return end
    if not IN_SECOND_ROW[key] then
        cfg.enabled = false
        return
    end
    -- find the second row's head, then the end of its chain to the right
    local head
    for k, c in pairs(p.blocks) do
        if ns.HangTarget(c.anchor) and k ~= key then head = k end
    end
    -- end of a chain of blocks docked one after the other on `side`
    local function ChainEnd(start, side)
        local last, found = start, true
        while found do
            found = false
            for k, c in pairs(p.blocks) do
                if k ~= key and c.dock and c.dock.to == last and c.dock.side == side then
                    last, found = k, true
                    break
                end
            end
        end
        return last
    end
    -- same size and font as the blocks it joins (a compact bar stays compact)
    local function Match(model)
        cfg.width = model.width
        cfg.height, cfg.fontSize = model.height, model.fontSize
    end
    local baseKey = BASE_ROW[1].key
    local base = p.blocks[baseKey]
    if head then
        Match(p.blocks[head])
        cfg.dock = { to = ChainEnd(head, "RIGHT"), side = "RIGHT" }
    elseif base and not base.dock and base.anchor then
        Match(base)
        cfg.width = SECOND_ROW_WIDTH
        -- bottom bar: the second row goes above it
        cfg.anchor = base.anchor.bottom and { above = baseKey, fill = true, gap = 0 }
            or { below = baseKey, fill = true, gap = 0 }
    elseif base and not base.dock and ChainEnd(baseKey, "BOTTOM") ~= baseKey then
        -- column layout: added at the bottom of the column
        Match(base)
        cfg.dock = { to = ChainEnd(baseKey, "BOTTOM"), side = "BOTTOM" }
    else
        cfg.enabled = false -- the player moved the base bar away: no automatic place
    end
end

-- Resets the active profile to the default layout (launchers included)
-- (preset: one of ns.PRESETS, "top" by default)
-- Resets EVERYTHING: the saved variables are emptied (every profile, block, launcher,
-- setting, gold history, offers already shown...) and the interface reloads, so
-- Tessera starts again exactly as on a first install. Used by every "reset" button
-- and by /tessera reset (the ready-made layouts use ResetProfile instead).
function ns:ResetEverything()
    if InCombatLockdown() then
        Print(L.RESET_IN_COMBAT)
        return
    end
    -- nothing may write into the old table on the way out: the global is cleared, and
    -- the game saves "no data" for Tessera
    TesseraDB = nil
    Print(L.CMD_RESET)
    ReloadUI()
end

-- Shows a ready-made layout, without the message nor the Edit Mode offer: the quick
-- tour tries them one after the other, then the player keeps one or gets theirs back
function ns:TryPreset(preset)
    self.sv.profiles[self.profileName] = { pendingPreset = preset }
    self:LoadProfile()
end

-- Replaces the current profile with a ready-made layout (preset: one of ns.PRESETS)
function ns:ResetProfile(preset)
    self:TryPreset(preset)
    local name = L["PRESET_" .. (preset or "top"):upper()] or preset
    Print(L.PRESET_APPLIED:format(name))
    -- a bar stuck to an edge may cover Blizzard frames: offer to make room (EditMode.lua)
    C_Timer.After(1.5, function() if ns.OfferEditModeRoom then ns:OfferEditModeRoom(true) end end)
end

---------------------------------------------------------------------------
-- Characters' gold (for the Gold block tooltip)
---------------------------------------------------------------------------
function ns:RecordMoney()
    if not self.sv then return end
    local _, class = UnitClass("player")
    local money = GetMoney() or 0
    self.sv.chars[self.charKey] = { money = money, class = class }

    -- daily history (net gain / loss per day, last 7 days) for the gold tooltip
    if self.lastMoney then
        local diff = money - self.lastMoney
        if diff ~= 0 then
            self.sv.goldHistory = self.sv.goldHistory or {}
            local days = self.sv.goldHistory[self.charKey] or {}
            self.sv.goldHistory[self.charKey] = days
            local today = date("%Y-%m-%d")
            days[today] = (days[today] or 0) + diff
            local oldest = date("%Y-%m-%d", time() - 7 * 86400)
            for day in pairs(days) do
                if day < oldest then days[day] = nil end
            end
        end
    end
    self.lastMoney = money
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
-- event name -> list of block keys to update when it fires
local eventMap = {}

-- Runs once at login (after saved variables are loaded): registers module
-- events and data requests, starts the update timer, then creates the blocks
local function Build()
    ns:UpdateMinimapButton()
    for _, key in ipairs(ns.order) do
        local mod = ns.modules[key]
        for _, event in ipairs(mod.events or {}) do
            if not eventMap[event] then
                eventMap[event] = {}
                -- pcall: an event that does not exist in this client would raise an error
                pcall(eventFrame.RegisterEvent, eventFrame, event)
            end
            table.insert(eventMap[event], key)
        end
        -- Modules whose data must be requested from the server (e.g. guild/friends rosters)
        if mod.request then
            local function Request()
                local cfg = ns.db.blocks[key]
                -- also when the block is only shared with a DataBroker addon
                if cfg and (cfg.enabled or (ns.IsPublished and ns:IsPublished(key))) then pcall(mod.request) end
            end
            C_Timer.After(5, Request)
            C_Timer.NewTicker(mod.requestInterval or 60, Request)
        end
    end

    -- A single timer for all periodically updated blocks: it only wakes the
    -- blocks being shown (or those that hide when empty, so they can
    -- reappear), each at its own pace
    local LAUNCHER_INTERVAL = 2
    local TICK = 0.25   -- the fastest module interval (coordinates)
    local MARGIN = 0.05 -- a tick landing a hair early must not skip an update
    local nextRun = {}
    C_Timer.NewTicker(TICK, function()
        local now = GetTime()
        for key, cfg in pairs(ns.db.blocks) do
            local f = ns.frames[key]
            local mod = ns:GetModule(key)
            local interval = ns.IsForwardingKey(key) and LAUNCHER_INTERVAL or (mod and mod.interval)
            if interval and f and cfg.enabled and (f:IsShown() or (mod and mod.isEmpty))
                and now + MARGIN >= (nextRun[key] or 0) then
                nextRun[key] = now + interval
                ns:UpdateBlock(key)
            end
        end
    end)

    ns.built = true
    -- blocks left unlocked by Edit Mode (reload or logout while it was open): lock again
    if ns.db.unlockedByEditMode then
        ns.db.unlockedByEditMode = nil
        ns.db.locked = true
    end
    if ns.HookEditMode then ns:HookEditMode() end
    -- DataBroker: detect display addons (DataBroker mode), listen to data objects
    if ns.InitBroker then ns:InitBroker() end
    ns:RefreshAllBlocks()
    -- hover fade, 10 times per second
    C_Timer.NewTicker(0.1, function() ns:UpdateFades() end)
    -- alerts (flashes) only once the login values have settled
    C_Timer.After(10, function() ns.alertsReady = true end)
    -- positions saved by older versions -> relative to the nearest screen anchor
    C_Timer.After(2, function() ns:MigratePositions() end)
    if ns.UpdatePlacementBanner then ns:UpdatePlacementBanner() end
    C_Timer.After(5, function()
        if ns.ShowWelcomeIfNeeded then ns:ShowWelcomeIfNeeded() end
    end)
    -- the style of an interface installed since last time is offered (after the popups above)
    C_Timer.After(8, function()
        if ns.OfferStylesIfNeeded then ns:OfferStylesIfNeeded() end
    end)

    -- An addon loaded later registers a media: re-apply the styles
    local LSM = ns:GetLSM()
    if LSM and LSM.RegisterCallback then
        LSM.RegisterCallback(ns, "LibSharedMedia_Registered", function()
            for _, key in ipairs(ns:GetBlockKeys()) do ns:ApplyStyle(key) end
        end)
    end
end

-- Core events. PLAYER_REGEN_DISABLED / ENABLED = entering / leaving combat.
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
pcall(eventFrame.RegisterUnitEvent, eventFrame, "UNIT_ENTERED_VEHICLE", "player")
pcall(eventFrame.RegisterUnitEvent, eventFrame, "UNIT_EXITED_VEHICLE", "player")
eventFrame:RegisterEvent("PLAYER_CONTROL_LOST")   -- start of a flight path
eventFrame:RegisterEvent("PLAYER_CONTROL_GAINED") -- end of a flight path
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        InitDB()
        ns.sessionMoney = GetMoney() or 0
        ns:RecordMoney()
        Build()
        return
    end
    if not ns.built then return end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        ns.state.inCombat = (event == "PLAYER_REGEN_DISABLED")
        -- Combat started mid-drag with "lock in combat": drop the block where it is
        if ns.state.inCombat and ns.dragging and ns.db.lockInCombat then
            local mover = ns.dragging
            ns.dragging = nil
            mover:StopMovingOrSizing()
            ns:SnapAndSave(mover)
        end
        ns:RefreshLockState()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        ns.state.inInstance = IsInInstance() and true or false
        ns:CheckSituationProfile()
        ns:UpdateVehicleState()
        ns:UpdateAllVisibility()
        if event == "PLAYER_ENTERING_WORLD" then
            -- Once, shortly after the first loading screen: re-apply all blocks so
            -- anchors to other addons' frames (created late) resolve correctly
            if not ns.reanchored then
                ns.reanchored = true
                C_Timer.After(1, function() ns:RefreshAllBlocks() end)
            end
            ns:UpdateAll()
        end
    elseif event == "PLAYER_MONEY" then
        ns:RecordMoney()
    elseif event == "PLAYER_UPDATE_RESTING" or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        ns:UpdateVehicleState()
        ns:UpdateAllVisibility()
    elseif event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" then
        -- the taxi state is only reliable a moment after these events
        C_Timer.After(0.5, function()
            ns:UpdateVehicleState()
            ns:UpdateAllVisibility()
        end)
    end

    for _, key in ipairs(eventMap[event] or {}) do ns:UpdateBlock(key) end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_TESSERA1 = "/tessera"
SLASH_TESSERA2 = "/tes"
local RunCommand
-- ns.inCommand lets Print talk even in quiet mode while a typed command runs;
-- pcall guarantees the flag is reset, then the error is re-raised
SlashCmdList.TESSERA = function(msg)
    ns.inCommand = true
    local ok, err = pcall(RunCommand, msg)
    ns.inCommand = false
    if not ok then error(err, 0) end
end
RunCommand = function(msg)
    if not ns.built then return end
    msg = strtrim(msg or ""):lower()
    -- test builds only: their extra file (not in released versions) handles its own commands
    if ns.DevCommand and ns.DevCommand(msg) then return end
    if msg == "lock" then
        ns:SetLocked(true)
    elseif msg == "unlock" then
        ns:SetLocked(false)
    elseif msg == "reset" then
        ns:ResetEverything()
    elseif msg == "minimap" or msg == "minicarte" then
        ns:SetMinimapButtonShown(ns.sv.hideMinimapButton and true or false)
        if ns.RefreshOptions then ns:RefreshOptions() end
    elseif msg == "bug" then
        -- the same report, to paste in a bug report (see README / GitHub)
        if ns.BugReport then ns:BugReport() end
    elseif msg:match("^preview forever") or msg:match("^apercu forever") or msg:match("^aperçu forever") then
        -- screenshots: only the WoW Forever blocks (Placement.lua)
        ns:PreviewForever(strtrim(msg:match("forever(.*)") or ""))
    elseif msg == "demo" or msg == "démo" then
        -- every block by category, with sample values and a style switcher (Demo.lua)
        if ns:IsDemoActive() then ns:StopDemo() else ns:StartDemo() end
    elseif msg == "preview" or msg == "apercu" or msg == "aperçu" then
        ns:SetPreview(not ns.previewMode)
    elseif msg == "recover" or msg == "recuperer" or msg == "récupérer" then
        -- groups that stick out of the screen come back inside
        ns:RecoverBlocksCommand()
    elseif msg == "broker" then
        -- DataBroker mode on / off (also in the options, DataBroker tab)
        if ns.ToggleBrokerMode then ns:ToggleBrokerMode() end
    elseif msg == "help" then
        Print(L.CMD_HELP)
    else
        ns:ToggleOptions()
    end
end

-- Global called by the addon compartment entry (see UpdateMinimapButton)
function Tessera_OnAddonCompartmentClick()
    if ns.built then ns:ToggleOptions() end
end

---------------------------------------------------------------------------
-- Minimap button: an entry in the addon compartment (also picked up by
-- FlareUI's button bag) plus a round button on the edge of the minimap, which
-- can be dragged around it. With FlareUI, its bag already shows the entry, so
-- the round button is not created (no duplicate). Both can be hidden;
-- /tessera minimap toggles them.
---------------------------------------------------------------------------
local compartmentInfo
local minimapButton

local IsAddOnLoadedFn = C_AddOns and C_AddOns.IsAddOnLoaded
local function FlareUIBag()
    return IsAddOnLoadedFn and IsAddOnLoadedFn("FlareUI") and true or false
end

-- Places the button on the minimap's edge at the saved angle (degrees)
local function PlaceMinimapButton()
    local angle = math.rad(ns.sv.minimapAngle or 215)
    local radius = (Minimap:GetWidth() / 2) + 5
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function CreateMinimapButton()
    local b = CreateFrame("Button", "TesseraMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\Tessera\\Media\\Icon.png")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns:SetLocked(not ns.db.locked)
        else
            Tessera_OnAddonCompartmentClick()
        end
    end)
    -- dragging moves the button around the minimap
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            ns.sv.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            PlaceMinimapButton()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Tessera", 1, 0.82, 0)
        GameTooltip:AddLine(L.MINIMAP_TT_LEFT, 1, 1, 1)
        GameTooltip:AddLine(ns:IsLocked() and L.MINIMAP_TT_RIGHT_UNLOCK or L.MINIMAP_TT_RIGHT_LOCK, 1, 1, 1)
        GameTooltip:AddLine(L.MINIMAP_TT_DRAG, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Shows or hides the round button as the setting (and FlareUI's presence) wants
local function UpdateRoundButton(wanted)
    if not Minimap then return end
    wanted = wanted and not FlareUIBag()
    if wanted and not minimapButton then minimapButton = CreateMinimapButton() end
    if minimapButton then
        if wanted then PlaceMinimapButton() end
        minimapButton:SetShown(wanted)
    end
end

-- Registers or removes Tessera's entry in the addon compartment, as the
-- hideMinimapButton setting requires. Calls into Blizzard's frame are wrapped
-- in pcall since its internals vary between client versions.
function ns:UpdateMinimapButton()
    if not self.sv then return end
    UpdateRoundButton(not self.sv.hideMinimapButton)
    local frame = AddonCompartmentFrame
    if not frame or not frame.RegisterAddon then return end
    local list = frame.registeredAddons or {}
    local index
    for i, entry in ipairs(list) do
        if entry == compartmentInfo then index = i end
    end
    local wanted = not self.sv.hideMinimapButton
    if wanted and not index then
        compartmentInfo = compartmentInfo or {
            text = "Tessera",
            icon = "Interface\\AddOns\\Tessera\\Media\\Icon.png",
            notCheckable = true,
            registerForAnyClick = true,
            func = function() Tessera_OnAddonCompartmentClick() end,
        }
        pcall(frame.RegisterAddon, frame, compartmentInfo)
    elseif not wanted and index then
        -- There is no unregister API: remove the entry from Blizzard's list directly
        table.remove(list, index)
        if frame.UpdateDisplay then pcall(frame.UpdateDisplay, frame) end
    end
end

function ns:SetMinimapButtonShown(shown)
    self.sv.hideMinimapButton = (not shown) or nil
    self:UpdateMinimapButton()
    Print(shown and L.MINIMAP_SHOWN or L.MINIMAP_HIDDEN)
end
