local ADDON, ns = ...

-- 2.0 skin of Tessera's windows, "stone and metal": the game's rock under a wash of the
-- style's color, the metal frame of the game's dialogs and a soft shadow; boxes take the
-- tooltip border. High contrast: plain black, thick white edge, no decoration.
-- Every style keeps its colors (background, edge, title); the blocks do not change.
-- The white drawings in Media/Skin are made by tools/gen_skin_media.py and tinted here.
local Skin = {}
ns.Skin = Skin

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Skin\\"
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local ROCK = "Interface\\FrameGeneral\\UI-Background-Rock"
local METAL = "Interface\\DialogFrame\\UI-DialogBox-Border"
local TOOLTIP_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
-- how bright the rock is, how much of the style's background covers it, how much of the
-- style's edge color the metal takes (values judged in game on the preview, test222)
local ROCK_LIGHT, ROCK_WASH, METAL_TINT = 0.80, 0.40, 0.35
local SMALL_WINDOW = 220 -- shorter windows take a thinner metal frame
local WHITE, BLACK = { 1, 1, 1 }, { 0, 0, 0 }
Skin.MEDIA = MEDIA

-- background, edge, title of each style (a style not listed takes its window colors)
local GOLD = { { 0.085, 0.058, 0.036 }, { 0.70, 0.47, 0.20 }, { 0.95, 0.72, 0.36 } } -- every gold style: one warm, deep gold
local STYLE_COLORS = {
    tessera = { { 0.086, 0.133, 0.165 }, { 0.122, 0.702, 0.639 }, { 0.957, 0.945, 0.918 } },
    ember = { { 0.102, 0.039, 0.020 }, { 1.00, 0.45, 0.15 }, { 1.00, 0.72, 0.40 } },
    sylvan = { { 0.031, 0.078, 0.039 }, { 0.45, 0.80, 0.40 }, { 0.75, 1.00, 0.70 } },
    runeblade = { { 0.03, 0.05, 0.09 }, { 0.55, 0.80, 1.00 }, { 0.75, 0.90, 1.00 } },
    warWithin = GOLD,
    midnight = { { 0.07, 0.045, 0.12 }, { 0.62, 0.45, 0.95 }, { 1.00, 0.92, 0.75 } },
    flareui2 = GOLD,
    flareui = GOLD,
    flareui6 = GOLD,
    flareSquare = GOLD,
    ellesmere = { { 0.067, 0.067, 0.067 }, { 0.047, 0.824, 0.616 }, { 0.80, 1.00, 0.94 } },
    elvui = { { 0.085, 0.085, 0.090 }, { 0.09, 0.52, 0.82 }, { 0.55, 0.82, 1.00 } },
    aurore = { { 0.085, 0.090, 0.125 }, { 0.62, 0.68, 0.92 }, { 0.90, 0.92, 1.00 } },
    blizzardModern = GOLD,
    modernSquare = GOLD,
    blizzardForever = GOLD,
    foreverSquare = GOLD,
    blizzard = GOLD,
    classicSquare = GOLD,
    flat = { { 0.080, 0.080, 0.080 }, { 0.52, 0.52, 0.54 }, { 0.96, 0.96, 0.96 } },
    transparent = { { 0.050, 0.055, 0.060 }, { 0.45, 0.50, 0.55 }, { 0.95, 0.97, 1.00 } },
    runestone = { { 0.070, 0.070, 0.075 }, { 0.75, 0.76, 0.80 }, { 0.95, 0.95, 0.98 } },
    grimoire = GOLD,
    -- dark, as its former window: the game's texts are white or gold (decided 25/11)
    parchment = { { 0.16, 0.11, 0.06 }, { 0.62, 0.42, 0.20 }, { 0.93, 0.83, 0.62 } },
    arcane = { { 0.065, 0.035, 0.115 }, { 0.62, 0.42, 0.92 }, { 0.78, 0.86, 1.00 } },
    royalSeal = GOLD,
    ironforge = { { 0.095, 0.085, 0.080 }, { 0.66, 0.60, 0.52 }, { 1.00, 0.80, 0.52 } },
}

local function Mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
local function Alpha(c, a) return { c[1], c[2], c[3], a } end
local function Luma(c) return 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3] end
Skin.Mix = Mix
-- black or white text, whichever reads on this fill
function Skin.Readable(fill) return Luma(fill) > 0.55 and BLACK or WHITE end

local function StyleColors(key)
    local c = STYLE_COLORS[key]
    if c then return c end
    local info = key and ns:GetThemeInfo(key)
    local w = info and info.window and info.window() or {}
    local edge = w.border or { 0.6, 0.6, 0.6 }
    return { Mix(BLACK, edge, 0.12), edge, w.title or WHITE }
end

-- The colors of the open style (or of high contrast), kept until either changes
local palette, paletteKey
function Skin.Palette()
    local contrast = ns.sv and ns.sv.highContrast and true or false
    local style = ns.GetTheme and ns:GetTheme() or "tessera"
    local key = tostring(style) .. (contrast and ":contrast" or "")
    if palette and paletteKey == key then return palette end
    paletteKey = key
    if contrast then
        local gold = { 1, 0.82, 0 }
        palette = {
            contrast = true, light = false, bg = BLACK, edge = WHITE, title = gold, ink = WHITE, soft = WHITE,
            box = { 0, 0, 0, 1 }, field = BLACK, line = WHITE, button = BLACK, buttonOn = gold,
            hover = { 1, 1, 1, 0.22 }, select = { 1, 0.82, 0, 0.28 }, bar = gold,
        }
        return palette
    end
    local c = StyleColors(style)
    local bg, edge, light = c[1], c[2], c.light
    palette = {
        bg = bg, edge = edge, title = c[3], light = light,
        ink = light and { 0.16, 0.09, 0.03 } or { 0.93, 0.92, 0.89 },
        soft = light and { 0.36, 0.26, 0.15 } or { 0.72, 0.73, 0.74 },
        box = light and { 1, 0.95, 0.82, 0.50 } or { 0, 0, 0, 0.48 },
        field = light and Mix(bg, WHITE, 0.4) or Mix(bg, BLACK, 0.45),
        line = Mix(bg, edge, 0.80), button = Mix(bg, edge, 0.18), buttonOn = Mix(bg, edge, light and 0.75 or 0.5),
        hover = Alpha(edge, 0.16), select = Alpha(edge, 0.28), bar = edge,
    }
    return palette
end

-- Painters: each part of a skinned window registers how it takes the colors; a change of
-- style or of high contrast repaints them all (ns:RepaintAccents)
local painters = {}
function Skin.Paint(fn)
    table.insert(painters, fn)
    fn(Skin.Palette())
end
function Skin.Repaint()
    local p = Skin.Palette()
    for _, fn in ipairs(painters) do fn(p) end
end

function Skin.Tint(tex, c, a) tex:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1) end
local Tint = Skin.Tint
function Skin.TextColor(fs, c) fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end

-- A white drawing stretched by its edges (corners kept round)
local function Sliced(f, layer, file, margin, sub)
    local t = f:CreateTexture(nil, layer, nil, sub or 0)
    t:SetTexture(MEDIA .. file)
    if t.SetTextureSliceMargins then
        t:SetTextureSliceMargins(margin, margin, margin, margin)
        if t.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
            t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        end
    end
    t:SetAllPoints(f)
    return t
end

-- A white drawing of Media/Skin (icon, arrow...), colored by color(p)
function Skin.Image(f, file, size, color, layer)
    local t = f:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(MEDIA .. file)
    t:SetSize(size, size)
    if color then Skin.Paint(function(p) Tint(t, color(p)) end) end
    return t
end

-- A surface (f needs BackdropTemplate): the tooltip border over a see-through fill; in high
-- contrast a plain fill and a thick edge. Returns a function (p, color) that changes the fill.
function Skin.Surface(f, radius, fill, edge)
    local plain = Sliced(f, "BACKGROUND", "fill" .. radius, radius + 2)
    local thick = Sliced(f, "BORDER", "frame" .. radius .. "b", radius + 2)
    local function SetFill(p, c)
        if p.contrast then Tint(plain, c) else f:SetBackdropColor(c[1], c[2], c[3], c[4] or 1) end
    end
    Skin.Paint(function(p)
        local c = edge(p)
        plain:SetShown(p.contrast and true or false)
        thick:SetShown(p.contrast and true or false)
        -- the backdrop is only rebuilt when the mode changes
        local mode = p.contrast and "contrast" or "decor"
        if f.skinMode ~= mode then
            f.skinMode = mode
            f:SetBackdrop(not p.contrast and { bgFile = WHITE8, edgeFile = TOOLTIP_EDGE,
                edgeSize = radius > 8 and 16 or 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } } or nil)
        end
        if p.contrast then Tint(thick, c) else f:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
        SetFill(p, fill(p))
    end)
    return SetFill
end

-- A box behind a part of a window (the list of pages, the help)
function Skin.Box(f, radius)
    return Skin.Surface(f, radius or 8, function(p) return p.box end, function(p) return p.line end)
end

-- The light behind a line of a list: the soft light of the quest log; a flat shape in high
-- contrast. Returns the texture and light(p, color), which paints it.
function Skin.Glow(f, layer)
    local t = f:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(f)
    return t, function(p, c)
        if p.contrast then
            t:SetColorTexture(1, 1, 1, 1)
            t:SetBlendMode("BLEND")
            Tint(t, c)
        else
            t:SetTexture(HIGHLIGHT)
            t:SetBlendMode(p.light and "BLEND" or "ADD")
            t:SetVertexColor(p.edge[1], p.edge[2], p.edge[3], p.light and 0.55 or 0.85)
        end
    end
end

-- A line across a window at y px from its top, fading at both ends (solid in high contrast).
-- Returns SetShown(on) for both halves.
function Skin.EdgeLine(f, y, side)
    side = side or 14
    local halves = {}
    for half = 1, 2 do
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetHeight(2)
        if half == 1 then
            t:SetPoint("TOPLEFT", f, "TOPLEFT", side, -y)
            t:SetPoint("TOPRIGHT", f, "TOP", 0, -y)
        else
            t:SetPoint("TOPLEFT", f, "TOP", 0, -y)
            t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -side, -y)
        end
        t:SetColorTexture(1, 1, 1, 1)
        halves[half] = t
        Skin.Paint(function(p)
            local c = p.edge
            if t.SetGradient and CreateColor and not p.contrast then
                local a, b = 0, 1
                if half == 2 then a, b = 1, 0 end
                t:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], a), CreateColor(c[1], c[2], c[3], b))
            else
                t:SetVertexColor(c[1], c[2], c[3], p.contrast and 1 or 0.8)
            end
        end)
    end
    return function(on)
        for _, t in ipairs(halves) do t:SetShown(on) end
    end
end

-- Gives a frame made without BackdropTemplate the backdrop functions
local function EnsureBackdrop(f)
    if f.SetBackdrop then return end
    local mixin = _G["BackdropTemplateMixin"]
    if not (mixin and Mixin) then return end
    Mixin(f, mixin)
    f:HookScript("OnSizeChanged", f.OnBackdropSizeChanged)
end
Skin.EnsureBackdrop = EnsureBackdrop

-- The window itself: soft shadow, rock washed in the style's background, a darker top, the
-- metal frame; title (a font string, optional) in the style's title color. Built once; later
-- calls only repaint.
function Skin.Window(f, title)
    f.stoneTitle = title or f.stoneTitle
    if f.stoneSkin then return end
    f.stoneSkin = true
    EnsureBackdrop(f)
    if not f.SetBackdrop then return end
    local shade = Sliced(f, "BACKGROUND", "shadow", 24, -8)
    shade:ClearAllPoints()
    shade:SetPoint("TOPLEFT", f, "TOPLEFT", -30, 28)
    shade:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 30, -32)
    local plain = Sliced(f, "BACKGROUND", "fill14", 16, -6)
    local plainEdge = Sliced(f, "BORDER", "frame14b", 16)
    local function Layer(sub)
        local t = f:CreateTexture(nil, "BACKGROUND", nil, sub)
        t:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
        t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
        return t
    end
    local rock, wash, depth = Layer(-5), Layer(-4), Layer(-3)
    rock:SetTexture(ROCK, "REPEAT", "REPEAT")
    if rock.SetHorizTile then
        rock:SetHorizTile(true)
        rock:SetVertTile(true)
    end
    wash:SetColorTexture(1, 1, 1, 1)
    depth:SetColorTexture(1, 1, 1, 1)
    Skin.Paint(function(p)
        local decor = not p.contrast
        -- the shadow: off in high contrast, or when the player takes it off (Accessibility)
        Tint(shade, BLACK, decor and not (ns.sv and ns.sv.noWindowShadow) and 0.85 or 0)
        Tint(plain, p.bg, 1)
        Tint(plainEdge, p.edge, 1)
        plain:SetShown(not decor)
        plainEdge:SetShown(not decor)
        rock:SetShown(decor)
        wash:SetShown(decor)
        depth:SetShown(decor)
        if decor then
            local k = p.light and 1 or ROCK_LIGHT
            Tint(rock, Mix({ k, k, k }, p.edge, 0.15), 1)
            wash:SetVertexColor(p.bg[1], p.bg[2], p.bg[3], p.light and 0.80 or ROCK_WASH)
            if depth.SetGradient and CreateColor then
                depth:SetGradient("VERTICAL", CreateColor(0, 0, 0, p.light and 0.20 or 0.45), CreateColor(0, 0, 0, 0))
            else
                depth:Hide()
            end
        end
        -- a small window (a banner, a dialog) takes a thinner metal: it keeps room for its text
        local small = (f:GetHeight() or 0) < SMALL_WINDOW
        local mode = decor and (small and "small" or "decor") or "contrast"
        if f.skinMode ~= mode then
            f.skinMode = mode
            local inset = small and 8 or 11
            f:SetBackdrop(decor and { edgeFile = METAL, edgeSize = small and 24 or 32,
                insets = { left = inset, right = inset, top = inset, bottom = inset } } or nil)
        end
        if decor then
            local c = Mix(WHITE, p.edge, METAL_TINT)
            f:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        end
        if f.stoneTitle then Skin.TextColor(f.stoneTitle, p.title) end
    end)
end

---------------------------------------------------------------------------
-- Controls: the game's own buttons, fields, lists and sliders keep their behavior; only
-- their drawings change (the template's textures turn see-through, ours go under the text)
---------------------------------------------------------------------------
-- Button texts in the style's colors: copies of the game's fonts (they follow its sizes)
local buttonFonts
local function ButtonFonts()
    if buttonFonts then return buttonFonts end
    buttonFonts = {}
    for key, parent in pairs({ normal = "GameFontNormal", high = "GameFontHighlight", off = "GameFontDisable",
        normalSmall = "GameFontNormalSmall", highSmall = "GameFontHighlightSmall", offSmall = "GameFontDisableSmall" }) do
        local f = CreateFont("TesseraSkinFont_" .. key)
        if _G[parent] then f:SetFontObject(_G[parent]) end
        buttonFonts[key] = f
    end
    Skin.Paint(function(p)
        local high = p.contrast and WHITE or Mix(p.title, WHITE, 0.35)
        local off = p.contrast and { 0.6, 0.6, 0.6 } or Mix(p.soft, BLACK, 0.25)
        for _, size in ipairs({ "", "Small" }) do
            buttonFonts["normal" .. size]:SetTextColor(p.title[1], p.title[2], p.title[3], 1)
            buttonFonts["high" .. size]:SetTextColor(high[1], high[2], high[3], 1)
            buttonFonts["off" .. size]:SetTextColor(off[1], off[2], off[3], 1)
        end
    end)
    return buttonFonts
end

-- Puts a button's text in the style's colors (small: the smaller fonts, for long texts)
function Skin.ButtonFonts(b, small)
    local fonts, size = ButtonFonts(), small and "Small" or ""
    b:SetNormalFontObject(fonts["normal" .. size])
    b:SetHighlightFontObject(fonts["high" .. size])
    b:SetDisabledFontObject(fonts["off" .. size])
end

-- The template's own drawings turn see-through (they change texture, never alpha)
local function HideTemplate(f, keys)
    for _, k in ipairs(keys) do
        local t = f[k]
        if type(t) == "table" and t.SetAlpha then t:SetAlpha(0) end
    end
end

-- A rounded control that lights up under the mouse and darkens when pressed or off
local function Pressable(b, base)
    local over, down = false, false
    local function Fill(p)
        local c = base(p)
        if b.IsEnabled and not b:IsEnabled() then return Alpha(c, 0.45) end
        if down then return Mix(c, p.edge, 0.40) end
        if over then return Mix(c, p.edge, 0.22) end
        return c
    end
    local setFill = Skin.Surface(b, 8, Fill, function(p) return p.line end)
    local function Update() setFill(Skin.Palette(), Fill(Skin.Palette())) end
    b:HookScript("OnEnter", function() over = true Update() end)
    b:HookScript("OnLeave", function() over, down = false, false Update() end)
    b:HookScript("OnMouseDown", function() down = true Update() end)
    b:HookScript("OnMouseUp", function() down = false Update() end)
    b:HookScript("OnEnable", Update)
    b:HookScript("OnDisable", Update)
    b:HookScript("OnShow", Update)
end

-- A game button (UIPanelButtonTemplate) in stone and metal. Returns the button.
function Skin.Button(b)
    if not b or b.stoneButton then return b end
    b.stoneButton = true
    HideTemplate(b, { "Left", "Middle", "Right" })
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    local small = b.GetNormalFontObject and _G.GameFontNormalSmall and b:GetNormalFontObject() == _G.GameFontNormalSmall
    Skin.ButtonFonts(b, small)
    EnsureBackdrop(b)
    if b.SetBackdrop then Pressable(b, function(p) return p.button end) end
    return b
end

-- A text field (InputBoxTemplate, SearchBoxTemplate): a darker rounded box. Returns it.
function Skin.Field(box)
    if not box or box.stoneField then return box end
    box.stoneField = true
    HideTemplate(box, { "Left", "Middle", "Right" })
    EnsureBackdrop(box)
    if not box.SetBackdrop then return box end
    Skin.Surface(box, 8, function(p) return p.field end, function(p) return p.line end)
    -- the template drew its edge outside the box: the text keeps clear of ours
    local left, right, top, bottom = 0, 0, 0, 0
    if box.GetTextInsets then left, right, top, bottom = box:GetTextInsets() end
    box:SetTextInsets(math.max(left or 0, 6), math.max(right or 0, 6), top or 0, bottom or 0)
    return box
end

-- A list button (WowStyle1 / WowStyle2 DropdownTemplate): a rounded button; the game's
-- arrow and texts stay. Returns it.
function Skin.Dropdown(dd)
    if not dd or dd.stoneDropdown then return dd end
    dd.stoneDropdown = true
    HideTemplate(dd, { "Background" })
    EnsureBackdrop(dd)
    if dd.SetBackdrop then Pressable(dd, function(p) return p.button end) end
    return dd
end

-- The game's slider with arrows (MinimalSliderWithSteppersTemplate): a thin track in the
-- style's line color, the classic knob, the spell book's arrows; in high contrast a diamond
-- and plain arrows. Returns it.
local function StepArrow(b, forward)
    if type(b) ~= "table" then return end
    local t = b.GetRegions and b:GetRegions()
    if not (t and t.SetTexture) then return end
    b:SetSize(20, 20)
    t:ClearAllPoints()
    t:SetAllPoints(b)
    Skin.Paint(function(p)
        if p.contrast then
            t:SetTexture(MEDIA .. (forward and "right" or "left"))
            Tint(t, p.title, 1)
        else
            t:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. (forward and "NextPage" or "PrevPage") .. "-Up")
            Tint(t, WHITE, 1)
        end
    end)
end
function Skin.Slider(sl)
    if not sl or sl.stoneSlider then return sl end
    sl.stoneSlider = true
    local bar = sl.Slider
    if type(bar) == "table" then
        HideTemplate(bar, { "Left", "Middle", "Right" })
        local track = bar:CreateTexture(nil, "BACKGROUND")
        track:SetHeight(4)
        track:SetPoint("LEFT", bar, "LEFT", 0, 0)
        track:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
        track:SetColorTexture(1, 1, 1, 1)
        local thumb = bar.GetThumbTexture and bar:GetThumbTexture()
        Skin.Paint(function(p)
            Tint(track, p.line, 1)
            if thumb then
                thumb:SetTexture(p.contrast and (MEDIA .. "diamond") or "Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
                thumb:SetSize(p.contrast and 16 or 28, p.contrast and 16 or 28)
                Tint(thumb, p.contrast and p.title or WHITE, 1)
            end
        end)
    end
    StepArrow(sl.Back, false)
    StepArrow(sl.Forward, true)
    if type(sl.RightText) == "table" then Skin.Paint(function(p) Skin.TextColor(sl.RightText, p.title) end) end
    return sl
end
