local _, ns = ...

---------------------------------------------------------------------------
-- 2.0 block styles (gold, blue rune, silver, bronze): a rounded, tinted frame drawn
-- in 9 pieces from Tessera's own 64 px drawings (Media/Looks, tools/gen_looks_media.py).
-- The edge pieces use the frame's usual names (TopLeftCorner, TopEdge...) so the seams
-- of fused groups (Merge.lua, ApplySeams) hide and move them like the other borders;
-- the rounded fill under them follows (ns.SyncHDFill): a corner hidden at a join gets
-- a square fill, so two blocks of a group meet with no gap.
---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\Tessera\\Media\\Looks\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local C = 0.25 -- corner piece: the outer 16 px of the 64 px drawing
ns.HD_MEDIA = MEDIA

-- texture coordinates of each piece (left, right, top, bottom)
local COORDS = {
    TopLeftCorner = { 0, C, 0, C }, TopRightCorner = { 1 - C, 1, 0, C },
    BottomLeftCorner = { 0, C, 1 - C, 1 }, BottomRightCorner = { 1 - C, 1, 1 - C, 1 },
    TopEdge = { C, 1 - C, 0, C }, BottomEdge = { C, 1 - C, 1 - C, 1 },
    LeftEdge = { 0, C, C, 1 - C }, RightEdge = { 1 - C, 1, C, 1 - C },
}
local CORNER_POINT = {
    TopLeftCorner = "TOPLEFT", TopRightCorner = "TOPRIGHT",
    BottomLeftCorner = "BOTTOMLEFT", BottomRightCorner = "BOTTOMRIGHT",
}

local function Rgba(c)
    if not c then return 1, 1, 1, 1 end
    return c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1, c.a or c[4] or 1
end

-- The fill: four corners (rounded or square) and three bands that never overlap, so a
-- see-through color stays even
local function FillPieces(frame)
    local fill = frame.tesseraHDFill
    if fill then return fill end
    fill = {}
    for name in pairs(CORNER_POINT) do
        fill[name] = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    end
    for _, name in ipairs({ "mid", "left", "right" }) do
        local t = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        t:SetTexture(WHITE)
        fill[name] = t
    end
    frame.tesseraHDFill = fill
    return fill
end

-- Hides the 2.0 drawing (another skin takes the frame); the edge pieces are reset by
-- ApplySkin with the other border pieces
function ns.HideHDSkin(frame)
    local fill = frame.tesseraHDFill
    if fill then
        for _, t in pairs(fill) do t:Hide() end
    end
    frame.tesseraHD = nil
end

-- Rounded fill corner where the edge corner shows, square where a join hid it
function ns.SyncHDFill(frame)
    local hd, fill = frame.tesseraHD, frame.tesseraHDFill
    if not (hd and fill) then return end
    for name in pairs(CORNER_POINT) do
        local t, edge = fill[name], frame[name]
        local round = edge and edge:IsShown()
        if round then
            t:SetTexture(MEDIA .. "hd_fill")
            local c = COORDS[name]
            t:SetTexCoord(c[1], c[2], c[3], c[4])
        else
            t:SetTexture(WHITE)
            t:SetTexCoord(0, 1, 0, 1)
        end
        t:SetVertexColor(Rgba(hd.bg))
        t:SetShown(hd.showFill)
    end
end

-- spec: file (edge drawing in Media/Looks), size (corner size, frame units), border and
-- bg (colors), showFill (false: no background). Returns the corner size.
function ns.ApplyHDSkin(frame, spec)
    local e = spec.size
    frame.tesseraHD = { bg = spec.bg, showFill = spec.showFill ~= false }
    for name, c in pairs(COORDS) do
        local piece = frame[name]
        if not piece then
            piece = frame:CreateTexture(nil, "BORDER")
            frame[name] = piece
        end
        piece:SetDrawLayer("BORDER")
        piece:SetTexture(MEDIA .. spec.file)
        piece:SetTexCoord(c[1], c[2], c[3], c[4])
        piece:SetVertexColor(Rgba(spec.border))
        piece:ClearAllPoints()
        local corner = CORNER_POINT[name]
        if corner then
            piece:SetPoint(corner, frame, corner, 0, 0)
            piece:SetSize(e, e)
        elseif name == "TopEdge" or name == "BottomEdge" then
            local side = name == "TopEdge" and "TOP" or "BOTTOM"
            piece:SetPoint(side .. "LEFT", frame, side .. "LEFT", e, 0)
            piece:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", -e, 0)
            piece:SetHeight(e)
        else
            local side = name == "LeftEdge" and "LEFT" or "RIGHT"
            piece:SetPoint("TOP" .. side, frame, "TOP" .. side, 0, -e)
            piece:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, 0, e)
            piece:SetWidth(e)
        end
        piece:Show()
    end

    local fill = FillPieces(frame)
    for name, point in pairs(CORNER_POINT) do
        local t = fill[name]
        t:ClearAllPoints()
        t:SetPoint(point, frame, point, 0, 0)
        t:SetSize(e, e)
    end
    fill.mid:ClearAllPoints()
    fill.mid:SetPoint("TOPLEFT", frame, "TOPLEFT", e, 0)
    fill.mid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -e, 0)
    fill.left:ClearAllPoints()
    fill.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -e)
    fill.left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", e, e)
    fill.right:ClearAllPoints()
    fill.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -e)
    fill.right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -e, e)
    local show = spec.showFill ~= false
    for _, name in ipairs({ "mid", "left", "right" }) do
        fill[name]:SetVertexColor(Rgba(spec.bg))
        fill[name]:SetShown(show)
    end
    ns.SyncHDFill(frame)
    return e
end

-- Alphabet of the game client's names (zones, characters, guilds): a font of a 2.0 style
-- that cannot draw it gives way to the game's font, which the client picks per language
local CLIENT_SCRIPT = { ruRU = "cyrillic", koKR = "korean", zhCN = "chinese", zhTW = "chinese" }
function ns.FontFitsClient(key)
    local item = ns:FindMedia("font", key)
    if not item.scripts then return true end
    local need = CLIENT_SCRIPT[GetLocale and GetLocale() or ""] or "latin"
    for _, script in ipairs(item.scripts) do
        if script == need then return true end
    end
    return false
end

-- Ornate separators of the 2.0 styles (cfg.separatorStyle): the drawing stands upright in
-- the file; a horizontal separator turns it a quarter
ns.SEPARATOR_FILES = { diamond = "hd_sep_diamond", rune = "hd_sep_rune" }
function ns.SetOrnateSeparator(tex, style, horizontal)
    tex:SetTexture(MEDIA .. ns.SEPARATOR_FILES[style])
    if horizontal then
        -- (UL, LL, UR, LR): the file's top goes to the left
        tex:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
    else
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

---------------------------------------------------------------------------
-- HD icons (cfg.iconSet, any style): the game's big drawings, those of the gamepad menus
-- and of the 128 px cursors, in the icon frame the player chose (round ring or square
-- frame over a dark backing; no frame: the drawing alone). A block without one keeps
-- its usual icon. The block's own icon texture stays in place (hidden, alpha 0), so the
-- text and the layout do not move.
-- Every name below is in Forever's atlas list (BlizzardInterfaceResources, AtlasInfo.lua,
-- build 1.60.1); the game is still asked at run time (C_Texture.GetAtlasInfo).
---------------------------------------------------------------------------
-- Off since 27/11 (Braincell1980): the game's drawings looked too small and choosing one per
-- block took too long. The code waits for Tessera's own drawings; turning this on brings
-- back the Icons setting (Look tab, Appearance > Icon) and the HD icons.
ns.HD_ICONS_ON = false
ns.HD_ICONS = {
    gold = "Cursor_buy_128", bags = "gamepad-radial-icon-bags", durability = "Cursor_Repair_128",
    mail = "Cursor_mail_128", loot = "Cursor_lootall_128", hearthstone = "Cursor_innkeeper_128",
    honor = "Cursor_PVP_128", pet = "Cursor_Petting_128",
    time = "gamepad-radial-icon-clock", serverTime = "gamepad-radial-icon-clock",
    date = "gamepad-radial-icon-calendar", played = "gamepad-radial-icon-stopwatch",
    guild = "gamepad-radial-icon-guild", friends = "gamepad-radial-icon-social",
    group = "gamepad-radial-icon-group-up", talents = "gamepad-radial-icon-talents",
    quests = "gamepad-radial-icon-quests", coords = "gamepad-radial-icon-fullmap-up",
    zone = "gamepad-radial-icon-fullmap-up", legacy = "gamepad-radial-icon-legacy",
    whispers = "gamepad-radial-icon-chat", stats = "gamepad-radial-icon-character",
    level = "gamepad-radial-icon-character", instances = "gamepad-radial-icon-adventureguide-up",
}

-- The HD drawing of a block and its size, or nil (usual icons, no drawing for this block,
-- or an atlas this client does not have)
function ns.HDIconAtlas(key, cfg)
    if not ns.HD_ICONS_ON or (cfg.iconSet ~= "hd" and cfg.iconSet ~= "hdTint") then return nil end
    local atlas = key and ns.HD_ICONS[key]
    local info = atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if info then return atlas, info end
end

-- Color of a tinted HD icon: the text's (class color, or the style's tint while the text is
-- white), the same rule as the block's text
local function TintColor(cfg)
    local c, tint = (cfg.classColorText and ns:GetClassColor()) or cfg.textColor or {}, cfg.textTint
    local white = (c.r or 1) >= 0.99 and (c.g or 1) >= 0.99 and (c.b or 1) >= 0.99
    if white and tint and (tint.a or 0) > 0 then c = tint end
    return c.r or 1, c.g or 1, c.b or 1
end

function ns.HideHDIcon(f)
    if not f.hdIcon then return end
    f.hdIcon:Hide()
    f.hdIconRing:Hide()
    f.hdIconDisc:Hide()
    if f.icon then f.icon:SetAlpha(1) end
end

-- Draws the HD icon over the block's icon. ring: color of the ring (the icon frame color).
function ns.DrawHDIcon(f, cfg, atlas, info, ring)
    local icon = f.icon
    if not f.hdIcon then
        f.hdIconDisc = f:CreateTexture(nil, "ARTWORK", nil, 0)
        f.hdIconDisc:SetTexture(MEDIA .. "hd_disc")
        f.hdIcon = f:CreateTexture(nil, "ARTWORK", nil, 1)
        f.hdIconRing = f:CreateTexture(nil, "ARTWORK", nil, 2)
        f.hdIconRing:SetTexture(MEDIA .. "hd_ring")
    end
    -- the icon frame setting shapes the HD icon too: round = ring, square = square frame,
    -- none = the drawing alone, a little bigger
    local shape = cfg.iconShape or "none"
    local framed = shape == "round" or shape == "square"
    f.hdIconDisc:SetTexture(shape == "square" and WHITE or MEDIA .. "hd_disc")
    f.hdIconRing:SetTexture(MEDIA .. (shape == "square" and "hd_box" or "hd_ring"))
    f.hdIconDisc:ClearAllPoints()
    f.hdIconDisc:SetAllPoints(icon)
    f.hdIconRing:ClearAllPoints()
    f.hdIconRing:SetAllPoints(icon)
    f.hdIconRing:SetVertexColor(ring.r or 1, ring.g or 1, ring.b or 1, ring.a or 1)
    local tex = f.hdIcon
    tex:SetAtlas(atlas, false)
    -- not square (91 x 128, 127 x 104...): fits inside the frame without stretching
    local size = icon:GetWidth() or 0
    local w, h = info.width or size, info.height or size
    local s = size * (framed and 0.78 or 1) / math.max(w, h, 1)
    tex:SetSize(w * s, h * s)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", icon, "CENTER", 0, 0)
    -- the disc behind is dark; a dark tint (Parchment's ink) gets a light disc to stand out
    local r, g, b = 1, 1, 1
    if cfg.iconSet == "hdTint" then r, g, b = TintColor(cfg) end
    tex:SetVertexColor(r, g, b, 1)
    if 0.299 * r + 0.587 * g + 0.114 * b < 0.4 then
        f.hdIconDisc:SetVertexColor(1, 0.97, 0.9, 0.7)
    else
        f.hdIconDisc:SetVertexColor(0, 0, 0, 0.6)
    end
    if tex.SetDesaturated then tex:SetDesaturated((cfg.iconDesaturate or cfg.monochrome) and true or false) end
    icon:SetAlpha(0)
    f.hdIconDisc:SetShown(framed)
    tex:Show()
    f.hdIconRing:SetShown(framed)
end
