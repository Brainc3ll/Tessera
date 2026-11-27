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

-- Ornate separators (cfg.separatorStyle, any style since 27/11): the drawing stands upright in
-- the file; a horizontal separator turns it a quarter
ns.SEPARATOR_FILES = {
    diamond = "hd_sep_diamond", rune = "hd_sep_rune", dot = "hd_sep_dot", smallDot = "hd_sep_dot_small",
    drawn = "hd_sep_drawn", dash = "hd_sep_dash", -- (27/11: a pen stroke, a short dash across; "dot" is the big one)
}
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

---------------------------------------------------------------------------
-- A little life (cfg.hoverGlow, cfg.valueGlide, any style; on with the four new styles):
-- the edge lights up under the mouse, numbers count to their new value. "Fewer
-- animations" (Accessibility) turns both off. One OnUpdate for every block, stopped as
-- soon as nothing moves.
---------------------------------------------------------------------------
local animator, moving = nil, {}
local GLOW_SPEED = 8      -- the glow follows the mouse in about an eighth of a second
local GLIDE_TIME = 0.45   -- seconds for a number to reach its new value
-- values that change on their own every second or minute: shown at once, as before
local NO_GLIDE = { time = true, serverTime = true, date = true, coords = true, played = true,
    fps = true, latency = true, memory = true, speed = true,
    -- durations (cooldowns, timers): minutes and seconds would count apart
    hearthstone = true, camping = true, weaponEnchant = true, longBuffs = true, reset = true }

local function Still() return ns.sv and ns.sv.reduceMotion end

-- the soft glow: 8 pieces of hd_glow around the block (no center), corner size e
local function GlowPieces(f)
    if f.hoverGlowPieces then return f.hoverGlowPieces end
    local pieces = {}
    for name, c in pairs(COORDS) do
        local t = f:CreateTexture(nil, "OVERLAY", nil, -2)
        t:SetTexture(MEDIA .. "hd_glow")
        t:SetTexCoord(c[1], c[2], c[3], c[4])
        t:SetBlendMode("ADD")
        t:SetAlpha(0)
        pieces[name] = t
    end
    f.hoverGlowPieces = pieces
    return pieces
end

local function PlaceGlow(f, e)
    for name, t in pairs(GlowPieces(f)) do
        t:ClearAllPoints()
        local corner = CORNER_POINT[name]
        if corner then
            t:SetPoint(corner, f, corner, 0, 0)
            t:SetSize(e, e)
        elseif name == "TopEdge" or name == "BottomEdge" then
            local side = name == "TopEdge" and "TOP" or "BOTTOM"
            t:SetPoint(side .. "LEFT", f, side .. "LEFT", e, 0)
            t:SetPoint(side .. "RIGHT", f, side .. "RIGHT", -e, 0)
            t:SetHeight(e)
        else
            local side = name == "LeftEdge" and "LEFT" or "RIGHT"
            t:SetPoint("TOP" .. side, f, "TOP" .. side, 0, -e)
            t:SetPoint("BOTTOM" .. side, f, "BOTTOM" .. side, 0, e)
            t:SetWidth(e)
        end
    end
end

local function SetGlowAlpha(f, a)
    if not f.hoverGlowPieces then return end
    for _, t in pairs(f.hoverGlowPieces) do t:SetAlpha(a * 0.9) end
end

-- numbers of a text, outside the game's codes (colors |c, textures |T, atlases |A, links |H):
-- returns its shape (the text with "\1" for each number), its parts (codes and characters
-- as they are, NUM for each number) and the numbers with their written length
local ESCAPES = { "^|c%x%x%x%x%x%x%x%x", "^|r", "^|T.-|t", "^|A.-|a", "^|H.-|h", "^|n", "^||" }
local NUM = {}
local function Numbers(text)
    local shape, parts, nums, i, n = {}, {}, {}, 1, #text
    while i <= n do
        local s, e
        if text:sub(i, i) == "|" then
            for _, pattern in ipairs(ESCAPES) do
                s, e = text:find(pattern, i)
                if s then break end
            end
        end
        if s then
            parts[#parts + 1] = text:sub(s, e)
            shape[#shape + 1] = parts[#parts]
            i = e + 1
        else
            -- a decimal number ("62.9", "1.25k") counts as one, with its decimals
            s, e = text:find("^%d+%.%d+", i)
            local decimals = s and #text:sub(s, e):match("%.(%d+)$") or nil
            if not s then s, e = text:find("^%d+", i) end
            if s then
                local digits = text:sub(s, e)
                -- a group after a separator ("1 234") keeps its leading zeros
                local prev, prev2 = text:sub(s - 1, s - 1), text:sub(s - 2, s - 2)
                local padded = not decimals and (prev == " " or prev == "," or prev == "'") and prev2:match("%d") ~= nil
                nums[#nums + 1] = { value = tonumber(digits) or 0, width = padded and #digits or nil, decimals = decimals }
                parts[#parts + 1] = NUM
                shape[#shape + 1] = "\1"
                i = e + 1
            else
                parts[#parts + 1] = text:sub(i, i)
                shape[#shape + 1] = parts[#parts]
                i = i + 1
            end
        end
    end
    return table.concat(shape), parts, nums
end

-- the text at k (0 = old numbers, 1 = new ones); keeps the numbers shown in glide.current
local function Rebuild(glide, k)
    local out, j = {}, 0
    for i, part in ipairs(glide.parts) do
        if part == NUM then
            j = j + 1
            local a, b = glide.from[j], glide.to[j]
            if b.decimals then
                local v = a.value + (b.value - a.value) * k
                glide.current[j] = { value = v, decimals = b.decimals }
                out[i] = ("%." .. b.decimals .. "f"):format(v)
            else
                local v = math.floor(a.value + (b.value - a.value) * k + 0.5)
                glide.current[j] = { value = v, width = b.width }
                out[i] = b.width and ("%0" .. b.width .. "d"):format(v) or ("%d"):format(v)
            end
        else
            out[i] = part
        end
    end
    return table.concat(out)
end

local function Step(_, elapsed)
    local busy = false
    for f in pairs(moving) do
        local done = true
        -- glow toward its target
        if f.glowTarget then
            local a = f.glowAlpha or 0
            a = a + (f.glowTarget - a) * math.min(1, (elapsed or 0) * GLOW_SPEED)
            if math.abs(a - f.glowTarget) < 0.01 then a = f.glowTarget else done = false end
            f.glowAlpha = a
            SetGlowAlpha(f, a)
        end
        -- number toward its value
        local glide = f.glide
        if glide then
            glide.t = glide.t + (elapsed or 0)
            local k = math.min(1, glide.t / GLIDE_TIME)
            k = 1 - (1 - k) * (1 - k) -- slows down at the end
            if k >= 1 then
                f.text:SetText(glide.final)
                f.glide = nil
            else
                f.text:SetText(Rebuild(glide, k))
                done = false
            end
        end
        if done then moving[f] = nil else busy = true end
    end
    if not busy then animator:SetScript("OnUpdate", nil) end
end

local function Wake(f)
    moving[f] = true
    if not animator then animator = CreateFrame("Frame") end
    animator:SetScript("OnUpdate", Step)
end

-- Called by ApplyStyle: glow pieces where the style asks for them
function ns.PrepareLife(f, cfg, e)
    if cfg.hoverGlow then
        PlaceGlow(f, e)
        local c = cfg.glowColor or {}
        for _, t in pairs(f.hoverGlowPieces) do t:SetVertexColor(c.r or 1, c.g or 0.85, c.b or 0.5, 1) end
        SetGlowAlpha(f, f.glowAlpha or 0)
    else
        f.glowTarget, f.glowAlpha = nil, 0
        SetGlowAlpha(f, 0)
    end
end

function ns.GlowTo(f, target)
    -- (a thumbnail of the style gallery carries its own settings: f.lifeCfg)
    local cfg = f.lifeCfg or ns.db and ns.db.blocks[f.key]
    if not (cfg and cfg.hoverGlow and f.hoverGlowPieces) or Still() then
        f.glowTarget, f.glowAlpha = nil, 0
        SetGlowAlpha(f, 0)
        return
    end
    f.glowTarget = target
    Wake(f)
end

-- Writes a block's text; a number that changed counts to its new value when the block
-- asks for it (the text keeps its shape, only digits move). The text always ends exactly
-- as given.
function ns.SetBlockText(f, cfg, text)
    local glide = f.glide
    local shown = glide and glide.final or f.glideLast
    f.glideLast = text
    -- not a time ("1:05", "3h05": its parts would count apart), whatever the block
    if cfg.valueGlide and not Still() and not NO_GLIDE[f.key] and shown and shown ~= text
        and not text:find("%d[:h]%d") then
        local shapeOld, _, numsOld = Numbers(shown)
        local shapeNew, parts, numsNew = Numbers(text)
        local huge = false
        for _, n in ipairs(numsNew) do if n.value > 1e9 then huge = true end end
        for _, n in ipairs(numsOld) do if n.value > 1e9 then huge = true end end
        if shapeOld == shapeNew and #numsNew > 0 and not huge then
            -- a glide still running goes on from the numbers it shows now
            local from = (glide and glide.current and #glide.current == #numsNew) and glide.current or numsOld
            f.glide = { parts = parts, from = from, to = numsNew, current = {}, t = 0, final = text }
            f.text:SetText(Rebuild(f.glide, 0))
            Wake(f)
            return
        end
    end
    f.glide = nil
    f.text:SetText(text)
end

---------------------------------------------------------------------------
-- Thin progress bar (cfg.progressLook = "thin", any style): a line two screen pixels high
-- under the value, over a faint track, instead of the band that fills the background
---------------------------------------------------------------------------
-- Called by ApplyStyle once the bar exists. left: where the text starts. lift: true when the
-- block will show a bar (the text moves up 2 px to leave it room).
function ns.PlaceThinBar(f, cfg, inset, left, lift)
    if cfg.progressLook ~= "thin" then
        f.barThin = nil
        f.bar:SetDrawLayer("BACKGROUND", 7)
        if f.barTrack then f.barTrack:Hide() end
        return
    end
    local h = ns:PixelSize(2, f)
    local bottom, right = inset + 2, 4 + inset
    f.bar:ClearAllPoints()
    f.bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", left, bottom)
    f.bar:SetHeight(h)
    f.bar:SetDrawLayer("ARTWORK", 1)
    if not f.barTrack then
        f.barTrack = f:CreateTexture(nil, "ARTWORK", nil, 0)
        f.barTrack:SetTexture(WHITE)
    end
    local track = f.barTrack
    track:ClearAllPoints()
    track:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", left, bottom)
    track:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -right, bottom)
    track:SetHeight(h)
    local c = cfg.borderColor or {}
    track:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, 0.22)
    track:Hide()
    f.barThin = { left = left, right = right }
    if lift and f.text.AdjustPointsOffset then f.text:AdjustPointsOffset(0, 2) end
end

-- Colors the thin bar (UpdateBar): the level's color (low durability in red...), otherwise
-- the edge's; never the bar texture. hex: the level color, nil without level.
function ns.ColorThinBar(f, cfg, hex)
    local r, g, b
    if cfg.monochrome then
        r, g, b = 0.75, 0.75, 0.75
    elseif hex then
        r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
    else
        local c = cfg.borderColor or {}
        r, g, b = c.r or 1, c.g or 1, c.b or 1
    end
    f.bar:SetTexture(WHITE)
    f.bar:SetVertexColor(r, g, b, 0.95)
    f.barTextured = nil
    if f.barTrack then f.barTrack:Show() end
end
