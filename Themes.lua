local ADDON, ns = ...
local L = ns.L

-- Themes: the look of the blocks and of the options window.
-- Each theme copies the values found in the code of the UI it imitates:
--   FlareUI     : FlareUI 2.x, like its XP bar: black background at 80%, light bronze
--                 "FlareUI Thin" border (#CC9957), the XP bar's font (Arial Narrow, outlined); window like its
--                 settings panel (tooltip border in that bronze over Blizzard's Collections tile)
--   FlareUI 1.x : dark dialog background, bronze "FlareUI Thin" border (#A67D45),
--                 the XP bar's font (Arial Narrow, outlined, unless changed in FlareUI)
--   The FlareUI style matching the installed version is the default. FlareUI 1.x is only
--   listed with FlareUI 1.x installed, or for a profile that already uses it.
--   EllesmereUI : very dark flat grey background (0.067, 0.95 opacity), 1 px black border
--                 at 80%, EllesmereUI's global font (Expressway by default), as on its data bars,
--                 and its accent color (#0CD29F) on the lines between merged blocks
--   ElvUI       : background color, border color, font and value color (the text) read from
--                 ElvUI's settings (defaults from its Defaults/Profile.lua without ElvUI)
--   Blizzard modern  : the game's current tooltips ("TooltipDefaultLayout" atlas), identical
--                      on Retail and Forever according to Blizzard's source code
--   Blizzard classic : the game's original tooltip background and border
--   Flat        : dark flat background and thin black border, no dependencies
--   Transparent : no background, no border, only outlined text and icons
--   Fantasy styles, with the game's fonts: Runestone (black and white, text only, silver
--   edge), Grimoire (dark leather, gold), Parchment (light parchment, brown ink),
--   Arcane (deep violet, pale blue letters)
--   Styles made of the game's own frames: Royal Seal (gold dialog border, marble),
--   Ironforge (stone dialog border, rock), and the tooltip border tinted: Runeblade (icy
--   blue), Ember (fire), Sylvan (green)
--
-- Every style can be picked, also when its UI is not installed: it is then an imitation
-- (FlareUI's thin border replaced by a plain one, the default fonts and colors of ElvUI
-- and EllesmereUI), labeled in the menu and explained in the chat (missingNote).
-- Tessera only offers a style by itself (popup) when its UI is installed.
--
-- The imitated UIs are optional addons: Tessera never requires them. Each theme checks
-- at runtime whether its UI is loaded (installed/available) and falls back to safe
-- defaults otherwise. Fonts, borders and backgrounds shared by other addons are looked
-- up through LibSharedMedia (LSM), the common media registry; "lsm:<name>" values
-- refer to such media and are resolved when the style is applied.

-- Builds an {r, g, b, a} color from either named or indexed fields, using fallback if c is nil
local function Color(c, fallback)
    c = c or fallback
    return { r = c.r or c[1] or 0, g = c.g or c[2] or 0, b = c.b or c[3] or 0, a = c.a or c[4] or 1 }
end

-- Returns "lsm:<name>" if LibSharedMedia knows this font, otherwise nil
local function LSMFont(name)
    local LSM = ns:GetLSM()
    if name and LSM and LSM:Fetch("font", name, true) then return "lsm:" .. name end
end

-- Font of FlareUI's XP bar: FlareUI writes it with its action bar key bind font (Arial Narrow
-- with an outline by default, in 1.x and 2.x). Read from FlareUI's saved settings (AceDB:
-- only the values the player changed are saved), so a font picked in FlareUI is followed.
-- Returns a Tessera font key and an outline.
local OUTLINES = { OUTLINE = true, THICKOUTLINE = true, NONE = true }
local function FlareFont()
    local face, flags = "Arial Narrow", "OUTLINE"
    for _, name in ipairs({ "FlareUI2_DB", "FlareUI_DB" }) do
        local db = _G[name]
        if type(db) == "table" and type(db.profiles) == "table" then
            -- AceDB's key for this character: "Name - Realm", or on WoW Forever the full
            -- name alone (same rule as ns.CharacterKey, written by AceDB)
            local keys = type(db.profileKeys) == "table" and db.profileKeys or {}
            local full = ns.CharacterKey and ns.CharacterKey()
            local profileName = (full and keys[full])
                or keys[(UnitName("player") or "") .. " - " .. (GetRealmName() or "")] or "Default"
            local profile = db.profiles[profileName]
            local font = type(profile) == "table" and type(profile.actionbars) == "table"
                and profile.actionbars.hotkeyFont
            if type(font) == "table" then
                if type(font.face) == "string" then face = font.face end
                if OUTLINES[font.flags] then flags = font.flags end
            end
            break
        end
    end
    return LSMFont(face) or "arial", flags
end

-- ElvUI's main engine object (ElvUI[1]), or nil if ElvUI is not loaded
local function ElvEngine()
    return type(_G["ElvUI"]) == "table" and type(_G["ElvUI"][1]) == "table" and _G["ElvUI"][1] or nil
end

-- EllesmereUI's global font as an LSM reference (Expressway if it cannot be read)
local function EllesmereFont()
    local name = "Expressway"
    if _G["EllesmereUI"] and _G["EllesmereUI"].GetFontsDB then
        local ok, db = pcall(_G["EllesmereUI"].GetFontsDB)
        if ok and type(db) == "table" and type(db.global) == "string" then name = db.global end
    end
    return LSMFont(name)
end

-- "Flat" options window (EllesmereUI, ElvUI, Flat)
local function FlatWindow(bg, border, title)
    return {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1, inset = 1,
        bg = bg, border = border, title = title or { 1, 0.82, 0 },
    }
end

-- Major version of the installed FlareUI (from its TOC), or nil
local function FlareUIMajor()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or function() end
    local ok, version = false, nil
    if get then ok, version = pcall(get, "FlareUI", "Version") end
    local major = ok and type(version) == "string" and tonumber(version:match("^%D*(%d+)"))
    if major then return major end
    if _G["FlareUI2_DB"] ~= nil then return 2 end -- saved variables only FlareUI 2 has
    return nil
end
ns.FlareUIMajor = FlareUIMajor

-- Theme list, in menu order. Each entry has:
--   available() whether it can be offered, installed() whether its UI is loaded (optional),
--   block(cfg) writes the block style into cfg, window() returns the options window style
ns.themes = {
    {
        key = "flareui2",
        name = "FlareUI",
        installed = function() return ns:HasFlareUIMedia() end,
        available = function() return true end,
        missingNote = "THEME_NOTE_FLAREUI",
        block = function(cfg)
            cfg.bg = "solid"
            cfg.bgColor = { r = 0, g = 0, b = 0, a = 0.8 }
            -- without FlareUI, its thin border is imitated by a plain one
            local thin = ns:HasFlareUIMedia()
            cfg.border = thin and "lsm:FlareUI Thin" or "solid"
            cfg.borderSize = thin and 8 or 1
            cfg.borderColor = { r = 0.80, g = 0.60, b = 0.34, a = 1 }
            cfg.font, cfg.outline = FlareFont() -- like FlareUI's XP bar
        end,
        window = function()
            -- the Collections tile under a 50% black wash = the tile tinted at half brightness
            return {
                bgFile = "Interface\\Collections\\CollectionsBackgroundTile",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 16, inset = 5, tile = true, tileSize = 256,
                bg = { 0.5, 0.5, 0.5, 1 }, border = { 0.80, 0.60, 0.34, 1 },
                title = { 0.80, 0.60, 0.34 },
            }
        end,
    },
    {
        key = "flareui", -- key kept from earlier versions: saved profiles refer to it
        name = "FlareUI 1.x",
        installed = function() return ns:HasFlareUIMedia() end,
        -- no longer in the list, except for FlareUI 1.x itself or a profile that uses it
        hidden = function() return FlareUIMajor() ~= 1 end,
        available = function() return true end,
        missingNote = "THEME_NOTE_FLAREUI",
        block = function(cfg)
            cfg.bg = "dialogDark"
            cfg.bgColor = { r = 1, g = 1, b = 1, a = 0.85 }
            local thin = ns:HasFlareUIMedia()
            cfg.border = thin and "lsm:FlareUI Thin" or "solid"
            cfg.borderSize = thin and 8 or 1
            cfg.borderColor = { r = 0.65, g = 0.49, b = 0.27, a = 1 }
            cfg.font, cfg.outline = FlareFont() -- like FlareUI's XP bar
        end,
        window = function()
            local LSM = ns:GetLSM()
            return {
                bgFile = (LSM and LSM:Fetch("background", "Blizzard Dialog Background Dark", true))
                    or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = (LSM and LSM:Fetch("border", "FlareUI Frames", true))
                    or "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 16, inset = 3,
                bg = { 1, 1, 1, 0.92 }, border = { 0.65, 0.49, 0.27, 1 },
                title = { 0.8, 0.6, 0.34 },
            }
        end,
    },
    {
        key = "ellesmere",
        name = "EllesmereUI",
        installed = function() return type(_G["EllesmereUI"]) == "table" end,
        available = function() return true end,
        missingNote = "THEME_NOTE_ELLESMERE",
        block = function(cfg)
            cfg.bg = "solid"
            cfg.bgColor = { r = 0.067, g = 0.067, b = 0.067, a = 0.95 }
            cfg.border = "solid"
            cfg.borderSize = 1
            cfg.borderColor = { r = 0, g = 0, b = 0, a = 0.8 }
            -- EllesmereUI's accent color (#0CD29F) on the lines between merged blocks
            cfg.separators = true
            cfg.separatorColor = { r = 0.05, g = 0.82, b = 0.62, a = 0.85 }
            cfg.font = EllesmereFont() or "arial" -- without EllesmereUI: the game's condensed font
            cfg.outline = "NONE"
        end,
        window = function()
            -- title in EllesmereUI's accent color (#0CD29F)
            return FlatWindow({ 0.067, 0.067, 0.067, 0.97 }, { 0, 0, 0, 0.8 }, { 0.05, 0.82, 0.62 })
        end,
    },
    {
        key = "elvui",
        name = "ElvUI",
        installed = function()
            local E = ElvEngine()
            return E ~= nil and type(E.media) == "table"
        end,
        available = function() return true end,
        missingNote = "THEME_NOTE_ELVUI",
        block = function(cfg)
            local E = ElvEngine()
            local m = E and E.media or {}
            cfg.bg = "solid"
            cfg.bgColor = Color(m.backdropfadecolor, { 0.06, 0.06, 0.06, 0.8 })
            cfg.border = "solid"
            cfg.borderSize = 1
            cfg.borderColor = Color(m.bordercolor, { 0, 0, 0, 1 })
            local general = E and E.db and E.db.general
            -- like ElvUI's data texts: the values in its "value color" (blue by default,
            -- or the class color picked in its installer)
            local value = Color(general and general.valuecolor, { 0.09, 0.52, 0.82, 1 })
            cfg.textTint = { r = value.r, g = value.g, b = value.b, a = 1 }
            cfg.font = LSMFont(general and general.font) or "arial"
            cfg.outline = (general and general.fontStyle) or "OUTLINE"
            if cfg.outline ~= "NONE" and cfg.outline ~= "OUTLINE" and cfg.outline ~= "THICKOUTLINE" then
                cfg.outline = "OUTLINE"
            end
        end,
        window = function()
            local E = ElvEngine()
            local m = E and E.media or {}
            local bg = Color(m.backdropcolor, { 0.1, 0.1, 0.1, 1 })
            local border = Color(m.bordercolor, { 0, 0, 0, 1 })
            return FlatWindow({ bg.r, bg.g, bg.b, 0.95 }, { border.r, border.g, border.b, 1 })
        end,
    },
    {
        key = "blizzardModern",
        name = L.THEME_BLIZZARD_MODERN,
        available = function() return NineSliceUtil ~= nil and NineSliceUtil.ApplyLayoutByName ~= nil end,
        block = function(cfg)
            cfg.bg = "tooltip"           -- shows the center of the atlas
            local r, g, b = ns.TooltipBackgroundRGB()
            cfg.bgColor = { r = r, g = g, b = b, a = 0.9 }
            cfg.border = "modernTooltip"
            cfg.borderSize = 16
            cfg.borderColor = { r = 1, g = 1, b = 1, a = 1 }
            cfg.font, cfg.outline = "friz", "OUTLINE"
        end,
        window = function()
            local r, g, b = ns.TooltipBackgroundRGB()
            return { nineSlice = "TooltipDefaultLayout", title = { 1, 0.82, 0 },
                     bg = { r, g, b, 0.95 }, border = { 1, 1, 1, 1 } }
        end,
    },
    {
        key = "blizzard",
        name = L.THEME_BLIZZARD_CLASSIC,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "tooltip"
            cfg.bgColor = { r = 0.09, g = 0.09, b = 0.19, a = 0.9 }
            cfg.border = "tooltip"
            cfg.borderSize = 16
            cfg.borderColor = { r = 1, g = 1, b = 1, a = 1 }
            cfg.font, cfg.outline = "friz", "OUTLINE"
        end,
        window = function()
            return {
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                edgeSize = 32, inset = 11,
                bg = { 1, 1, 1, 1 }, border = { 1, 1, 1, 1 },
                title = { 1, 0.82, 0 },
            }
        end,
    },
    -- "Square" styles: square corners, a plain dark background, a thin solid border
    -- and a thin line between merged blocks (the look of Tessera's banners)
    {
        key = "flareSquare",
        name = L.THEME_FLARE_SQUARE,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "solid"
            cfg.bgColor = { r = 0.04, g = 0.035, b = 0.03, a = 0.92 }
            cfg.border = "solid"
            cfg.borderSize = 2
            cfg.borderColor = { r = 0.48, g = 0.35, b = 0.19, a = 1 } -- dark bronze
            cfg.separators = true
            cfg.separatorColor = { r = 0.62, g = 0.46, b = 0.25, a = 0.5 }
            cfg.font, cfg.outline = FlareFont() -- like FlareUI's XP bar
        end,
        window = function()
            return FlatWindow({ 0.055, 0.047, 0.04, 0.96 }, { 0.80, 0.60, 0.34, 1 }, { 0.80, 0.60, 0.34 })
        end,
    },
    {
        key = "modernSquare",
        name = L.THEME_MODERN_SQUARE,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "solid"
            cfg.bgColor = { r = 0.025, g = 0.05, b = 0.11, a = 0.92 }
            cfg.border = "solid"
            cfg.borderSize = 2
            cfg.borderColor = { r = 0.56, g = 0.41, b = 0.13, a = 1 } -- dark gold
            cfg.separators = true
            cfg.separatorColor = { r = 0.50, g = 0.37, b = 0.14, a = 0.7 }
            cfg.font, cfg.outline = "friz", "OUTLINE"
        end,
        window = function()
            return FlatWindow({ 0.03, 0.07, 0.16, 0.96 }, { 1, 0.77, 0.25, 1 }, { 1, 0.77, 0.25 })
        end,
    },
    {
        key = "classicSquare",
        name = L.THEME_CLASSIC_SQUARE,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "solid"
            -- the classic tooltip's colors: dark blue background, grey border
            cfg.bgColor = { r = 0.07, g = 0.07, b = 0.15, a = 0.9 }
            cfg.border = "solid"
            cfg.borderSize = 2
            cfg.borderColor = { r = 0.47, g = 0.47, b = 0.47, a = 1 } -- grey
            cfg.separators = true
            cfg.separatorColor = { r = 0.62, g = 0.62, b = 0.62, a = 0.45 }
            cfg.font, cfg.outline = "friz", "OUTLINE"
        end,
        window = function()
            return FlatWindow({ 0.07, 0.07, 0.15, 0.96 }, { 0.55, 0.55, 0.55, 1 }, { 1, 0.82, 0 })
        end,
    },
    {
        key = "flat",
        name = L.THEME_FLAT,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "solid"
            cfg.bgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.75 }
            cfg.border = "solid"
            cfg.borderSize = 1
            cfg.borderColor = { r = 0, g = 0, b = 0, a = 1 }
            cfg.font, cfg.outline = "friz", "OUTLINE"
        end,
        window = function()
            return FlatWindow({ 0.05, 0.05, 0.05, 0.95 }, { 0, 0, 0, 1 })
        end,
    },
    {
        -- Transparent: no background and no border, only the text and icons, outlined so
        -- they stay readable over the game world. The options window keeps a flat frame.
        key = "transparent",
        name = L.THEME_TRANSPARENT,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "none"
            cfg.bgColor = { r = 0, g = 0, b = 0, a = 0 }
            cfg.border = "none"
            cfg.borderSize = 1
            cfg.borderColor = { r = 0, g = 0, b = 0, a = 0 }
            cfg.font, cfg.outline = "friz", "OUTLINE"
            -- without a frame around the blocks, framed icons of one size keep the bar tidy
            cfg.iconShape, cfg.iconSize = "square", 16
        end,
        window = function()
            return FlatWindow({ 0.05, 0.05, 0.05, 0.95 }, { 0, 0, 0, 1 })
        end,
    },
    -- Fantasy styles, with the game's own fonts (Morpheus: the quest titles' font)
    {
        -- Runestone: black and white, text only: white letters on deep black, a thin
        -- silver line around the blocks and between them; launchers keep a grey icon
        key = "runestone",
        name = L.THEME_RUNESTONE,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "solid"
            cfg.bgColor = { r = 0.025, g = 0.025, b = 0.03, a = 0.93 }
            cfg.border = "solid"
            cfg.borderSize = 1
            cfg.borderColor = { r = 0.72, g = 0.72, b = 0.75, a = 1 } -- silver
            cfg.separators = true
            cfg.separatorColor = { r = 0.72, g = 0.72, b = 0.75, a = 0.45 }
            cfg.font, cfg.outline = "morpheus", "NONE"
            cfg.hideIcons, cfg.monochrome = true, true
        end,
        window = function()
            return FlatWindow({ 0.025, 0.025, 0.03, 0.97 }, { 0.72, 0.72, 0.75, 1 }, { 0.92, 0.92, 0.94 })
        end,
    },
    {
        -- Grimoire: an old spell book: dark leather, gold edges and golden letters
        key = "grimoire",
        name = L.THEME_GRIMOIRE,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "solid"
            cfg.bgColor = { r = 0.12, g = 0.07, b = 0.035, a = 0.94 } -- dark leather
            cfg.border = "solid"
            cfg.borderSize = 2
            cfg.borderColor = { r = 0.78, g = 0.6, b = 0.22, a = 1 } -- gold
            cfg.separators = true
            cfg.separatorColor = { r = 0.78, g = 0.6, b = 0.22, a = 0.45 }
            cfg.font, cfg.outline = "morpheus", "OUTLINE"
            cfg.textTint = { r = 1, g = 0.86, b = 0.5, a = 1 }
            cfg.iconShape, cfg.iconBorderColor = "square", { r = 0.78, g = 0.6, b = 0.22, a = 1 }
        end,
        window = function()
            return FlatWindow({ 0.11, 0.065, 0.035, 0.97 }, { 0.78, 0.6, 0.22, 1 }, { 1, 0.86, 0.5 })
        end,
    },
    {
        -- Parchment: light parchment, dark brown ink, a copper edge. The options window
        -- stays dark (its texts are light)
        key = "parchment",
        name = L.THEME_PARCHMENT,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "solid"
            cfg.bgColor = { r = 0.80, g = 0.70, b = 0.50, a = 0.97 }
            cfg.border = "solid"
            cfg.borderSize = 2
            cfg.borderColor = { r = 0.45, g = 0.29, b = 0.13, a = 1 } -- copper brown
            cfg.separators = true
            cfg.separatorColor = { r = 0.45, g = 0.29, b = 0.13, a = 0.5 }
            cfg.font, cfg.outline = "morpheus", "NONE" -- ink: no outline
            cfg.textTint = { r = 0.1, g = 0.06, b = 0.025, a = 1 } -- almost black ink
            cfg.inkColors = true -- the colors in the values, darkened like ink
        end,
        window = function()
            return FlatWindow({ 0.16, 0.11, 0.06, 0.97 }, { 0.62, 0.42, 0.2, 1 }, { 0.93, 0.83, 0.62 })
        end,
    },
    {
        -- Arcane: the mages of Dalaran: deep violet, a violet edge, pale glowing blue letters
        key = "arcane",
        name = L.THEME_ARCANE,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "solid"
            cfg.bgColor = { r = 0.07, g = 0.03, b = 0.13, a = 0.92 }
            cfg.border = "solid"
            cfg.borderSize = 2
            cfg.borderColor = { r = 0.56, g = 0.32, b = 0.88, a = 1 }
            cfg.separators = true
            cfg.separatorColor = { r = 0.56, g = 0.32, b = 0.88, a = 0.5 }
            cfg.font, cfg.outline = "friz", "OUTLINE"
            cfg.textTint = { r = 0.72, g = 0.86, b = 1, a = 1 }
            cfg.iconShape, cfg.iconBorderColor = "round", { r = 0.56, g = 0.32, b = 0.88, a = 1 }
        end,
        window = function()
            return FlatWindow({ 0.07, 0.035, 0.13, 0.97 }, { 0.56, 0.32, 0.88, 1 }, { 0.72, 0.86, 1 })
        end,
    },
    -- Styles made of the game's own frames (dialog borders, tooltip border, marble and
    -- rock backgrounds) with a fantasy touch
    {
        -- Royal Seal: a Stormwind charter: the gold dialog border on dark marble, golden letters
        key = "royalSeal",
        name = L.THEME_ROYAL_SEAL,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "marble"
            cfg.bgColor = { r = 0.42, g = 0.38, b = 0.35, a = 0.96 }
            cfg.border = "gold"
            cfg.borderSize = 14
            cfg.borderColor = { r = 1, g = 1, b = 1, a = 1 }
            cfg.separators = true
            cfg.separatorColor = { r = 0.9, g = 0.72, b = 0.3, a = 0.45 }
            cfg.font, cfg.outline = "morpheus", "OUTLINE"
            cfg.textTint = { r = 1, g = 0.86, b = 0.45, a = 1 }
        end,
        window = function()
            return {
                bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
                edgeSize = 32, inset = 11, tile = true, tileSize = 256,
                bg = { 0.5, 0.46, 0.43, 1 }, border = { 1, 1, 1, 1 }, title = { 1, 0.86, 0.45 },
            }
        end,
    },
    {
        -- Ironforge: the stone dialog border on rock, warm white letters
        key = "ironforge",
        name = L.THEME_IRONFORGE,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "rock"
            cfg.bgColor = { r = 0.6, g = 0.55, b = 0.5, a = 0.96 }
            cfg.border = "dialog"
            cfg.borderSize = 14
            cfg.borderColor = { r = 1, g = 1, b = 1, a = 1 }
            cfg.separators = true
            cfg.separatorColor = { r = 0.7, g = 0.66, b = 0.6, a = 0.45 }
            cfg.font, cfg.outline = "friz", "OUTLINE"
            cfg.textTint = { r = 1, g = 0.93, b = 0.82, a = 1 }
        end,
        window = function()
            return {
                bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                edgeSize = 32, inset = 11, tile = true, tileSize = 256,
                bg = { 0.6, 0.55, 0.5, 1 }, border = { 1, 1, 1, 1 }, title = { 1, 0.82, 0 },
            }
        end,
    },
}

-- Three more styles with the game's tooltip border, tinted: they only differ by their
-- colors (background, border, text)
local function TooltipStyle(key, name, bg, edge, text)
    return {
        key = key,
        name = name,
        available = function() return true end,
        block = function(cfg)
            cfg.bg = "solid"
            cfg.bgColor = { r = bg[1], g = bg[2], b = bg[3], a = 0.92 }
            cfg.border = "tooltip"
            cfg.borderSize = 12
            cfg.borderColor = { r = edge[1], g = edge[2], b = edge[3], a = 1 }
            cfg.separators = true
            cfg.separatorColor = { r = edge[1], g = edge[2], b = edge[3], a = 0.45 }
            cfg.font, cfg.outline = "friz", "OUTLINE"
            cfg.textTint = { r = text[1], g = text[2], b = text[3], a = 1 }
        end,
        window = function()
            return {
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 16, inset = 5,
                bg = { bg[1], bg[2], bg[3], 0.97 }, border = { edge[1], edge[2], edge[3], 1 }, title = text,
            }
        end,
    }
end
-- Runeblade: icy blue (death knights, Northrend); Ember: fire and forge; Sylvan: night elves, druids
table.insert(ns.themes, TooltipStyle("runeblade", L.THEME_RUNEBLADE, { 0.03, 0.05, 0.09 }, { 0.55, 0.8, 1 }, { 0.75, 0.9, 1 }))
table.insert(ns.themes, TooltipStyle("ember", L.THEME_EMBER, { 0.1, 0.04, 0.02 }, { 1, 0.45, 0.15 }, { 1, 0.72, 0.4 }))
table.insert(ns.themes, TooltipStyle("sylvan", L.THEME_SYLVAN, { 0.03, 0.08, 0.04 }, { 0.45, 0.8, 0.4 }, { 0.75, 1, 0.7 }))

-- The center of modern tooltips is a white texture that the game tints with
-- TOOLTIP_DEFAULT_BACKGROUND_COLOR (SharedTooltipTemplates.lua); we do the same
function ns.TooltipBackgroundRGB()
    local c = TOOLTIP_DEFAULT_BACKGROUND_COLOR
    if c and c.GetRGB then return c:GetRGB() end
    return 0.09, 0.09, 0.19
end

local byKey = {}
for _, t in ipairs(ns.themes) do byKey[t.key] = t end

-- Returns the theme definition for a key
function ns:GetThemeInfo(key)
    return byKey[key]
end

-- A theme counts as installed if its UI is loaded; themes without installed() use available()
local function IsInstalled(t)
    if t.installed then return t.installed() end
    return t.available()
end

-- The style of a UI that is not installed: what differs from the real one (or nil)
function ns:GetThemeNote(key)
    local t = byKey[key or self:GetTheme()]
    if t and t.missingNote and not IsInstalled(t) then return L[t.missingNote] end
end

-- Is the UI this theme matches loaded? (checked on import)
function ns:IsThemeInstalled(key)
    local t = byKey[key]
    return t ~= nil and IsInstalled(t)
end

-- Themes offered in the menu: every style; those of a UI that is not installed are
-- labeled (an imitation, see GetThemeNote)
function ns:GetAvailableThemes()
    local list = {}
    local current = self:GetTheme()
    for _, t in ipairs(self.themes) do
        if t.available() and not (t.hidden and t.hidden() and t.key ~= current) then
            local name = IsInstalled(t) and t.name or (t.name .. " " .. L.THEME_NOT_INSTALLED)
            table.insert(list, { key = t.key, name = name })
        end
    end
    return list
end

-- The profile's theme; by default, the theme of the installed UI
-- (FlareUI, then EllesmereUI, then ElvUI), otherwise Blizzard modern
function ns:GetTheme()
    local chosen = self.db and self.db.theme
    if chosen and byKey[chosen] and byKey[chosen].available() then return chosen end
    local flare = (FlareUIMajor() or 2) >= 2 and "flareui2" or "flareui"
    for _, key in ipairs({ flare, "ellesmere", "elvui" }) do
        if IsInstalled(byKey[key]) then return key end
    end
    if byKey.blizzardModern.available() then return "blizzardModern" end
    return "blizzard"
end

-- Writes a theme's block style into one block's settings (current theme if key is nil)
-- (icons go back to their plain look first: only some themes frame them)
function ns:ApplyThemeToCfg(cfg, key)
    local theme = byKey[key or self:GetTheme()] or byKey.blizzard
    cfg.iconShape, cfg.iconSize = "none", 0
    cfg.iconBorderColor = { r = 0, g = 0, b = 0, a = 1 }
    cfg.separators = false -- only some styles draw lines between merged blocks
    -- text only, black and white, the style's text color: only some styles
    cfg.hideIcons, cfg.monochrome, cfg.inkColors = false, false, false
    cfg.textTint = { r = 1, g = 1, b = 1, a = 0 }
    theme.block(cfg)
end

-- Writes a theme into every block of the profile and clears the style overrides of the
-- group and launcher defaults (restyle = also apply it to the frames now)
local function RestyleProfile(self, key, restyle)
    for _, field in ipairs({ "bg", "bgColor", "border", "borderSize", "borderColor", "font", "outline",
                             "iconShape", "iconSize", "iconBorderColor", "separators", "separatorColor",
                             "hideIcons", "monochrome", "textTint", "inkColors" }) do
        if self.db.groupDefaults then self.db.groupDefaults[field] = nil end
        if self.db.launcherDefaults then self.db.launcherDefaults[field] = nil end
    end
    for _, blockKey in ipairs(self:GetBlockKeys()) do
        if self.db.blocks[blockKey] then
            self:ApplyThemeToCfg(self.db.blocks[blockKey], key)
            if restyle then self:ApplyStyle(blockKey) end
        end
    end
end

-- Switches the profile to a theme: clears style overrides from the group and launcher
-- defaults, restyles every block and the options window. Returns false if unavailable.
function ns:ApplyTheme(key)
    if not byKey[key] or not byKey[key].available() then return false end
    self.db.theme = key
    RestyleProfile(self, key, true)
    if self.SkinOptions then self:SkinOptions() end
    return true
end

-- The automatic style (no style picked by the player) is the one of the installed UI.
-- Tessera never changes the look of existing blocks without asking: when the automatic
-- style changes (e.g. FlareUI 1.x updated to 2.x, or a UI installed later), the current
-- look is kept as the profile's choice and the new style is offered in a popup
-- (ns:OfferStylesIfNeeded, Options.lua). Called by Core.lua when a profile is loaded,
-- before the blocks are drawn. db.autoTheme remembers which style the blocks were given.
function ns:SyncAutoTheme()
    local db = self.db
    if not db then return end
    -- before 1.0.0-rc1 "flareui" was the only FlareUI style: such a profile gets the automatic one
    if db.theme == "flareui" and not db.flareStylesSplit then db.theme = nil end
    db.flareStylesSplit = true
    if db.theme then return end
    local key = self:GetTheme()
    -- an interface whose style was replaced while it was missing (disabled for one
    -- session or one character) is back: its style comes back too
    if db.autoThemeMissing then
        if db.autoThemeMissing == key then
            RestyleProfile(self, key, false)
            db.autoTheme, db.autoThemeMissing = key, nil
            return
        end
    end
    local applied = db.autoTheme
    if applied == nil then
        -- profile from an earlier version: its blocks have the FlareUI 1.x bronze if that was the style
        local gold = db.blocks and db.blocks.gold
        local c = gold and gold.borderColor
        local old = gold and gold.border == "lsm:FlareUI Thin" and type(c) == "table"
            and math.abs((c.r or 0) - 0.65) < 0.01
        applied = old and "flareui" or key
    end
    db.autoTheme = key
    if applied == key then return end
    if byKey[applied] and IsInstalled(byKey[applied]) then
        db.theme = applied -- keep the current look; the new style is offered instead
    else
        -- the old style is unavailable (its interface is missing): replaced for now, and
        -- given back automatically if that interface returns
        RestyleProfile(self, key, false)
        db.autoThemeMissing = db.autoThemeMissing or applied
    end
end

-- Styles of the UIs installed now (FlareUI in its installed version), by priority
function ns:GetDetectedUIStyles()
    local list = {}
    local flare = (FlareUIMajor() or 2) >= 2 and "flareui2" or "flareui"
    for _, key in ipairs({ flare, "ellesmere", "elvui" }) do
        if IsInstalled(byKey[key]) then table.insert(list, key) end
    end
    return list
end

-- Name of the UI behind a style, with FlareUI's version (e.g. "FlareUI 2.0")
function ns:GetUIName(key)
    if key == "flareui" or key == "flareui2" then
        local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or function() end
        local ok, version = false, nil
        if get then ok, version = pcall(get, "FlareUI", "Version") end
        if ok and type(version) == "string" and version ~= "" then return "FlareUI " .. version end
        return "FlareUI"
    end
    return byKey[key] and byKey[key].name or key
end

-- Styles of installed UIs that were never offered (account-wide memory sv.uiOffered).
-- A UI whose style is already in use counts as offered.
function ns:GetStylesToOffer()
    local list = {}
    if not (self.sv and self.db) then return list end
    self.sv.uiOffered = self.sv.uiOffered or {}
    local current = self:GetTheme()
    for _, key in ipairs(self:GetDetectedUIStyles()) do
        if key == current then
            self.sv.uiOffered[key] = true
        elseif not self.sv.uiOffered[key] then
            table.insert(list, key)
        end
    end
    return list
end

-- Remembers that these styles were offered (accepted or not): they are not offered again
function ns:MarkStylesOffered(list)
    self.sv.uiOffered = self.sv.uiOffered or {}
    for _, key in ipairs(list) do self.sv.uiOffered[key] = true end
end
