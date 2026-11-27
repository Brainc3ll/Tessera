local _, ns = ...

-- Style samples: two merged blocks (gold, then bags) drawn by Tessera in a style, as real blocks
-- are. Used by the style gallery's thumbnails (OptionsStyleGallery.lua) and by the demo of the
-- new styles in the update window (OptionsNewsDemo.lua, 2.0.0). Nothing here is saved.
local Skin = ns.Skin
local MEDIA = Skin.MEDIA

local Sample = {}
ns.StyleSample = Sample

-- (27/11) the animation moves the numbers through these values
Sample.TEXTS = { { "1 234", "1 289", "1 247" }, { "42/80", "45/80", "43/80" } }
-- seconds: the first block lights up, then the second, then the numbers change
Sample.PERIOD = 2.4

-- A white drawing of Media/Skin stretched by its edges
function Sample.Sliced(f, layer, file, margin, sub)
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

-- The frames of a sample on a card: two blocks, and the separator between them on a layer above both
function Sample.NewPair(c)
    for _, name in ipairs({ "sample", "sample2" }) do
        local f = CreateFrame("Frame", nil, c, "BackdropTemplate")
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.text = f:CreateFontString(nil, "OVERLAY")
        f.text:SetWordWrap(false)
        f:EnableMouse(false)
        c[name] = f
    end
    c.joinLayer = CreateFrame("Frame", nil, c)
    c.joinLayer:SetAllPoints(c)
    c.joinLayer:SetFrameLevel(c:GetFrameLevel() + 20)
    c.joinLayer.line = c.joinLayer:CreateTexture(nil, "OVERLAY")
    c.joinLayer.line:SetTexture("Interface\\Buttons\\WHITE8X8")
    c.joinLayer.ornate = c.joinLayer:CreateTexture(nil, "OVERLAY")
end

-- The thin progress bar of a sample (the demo: the bags fill up), as UpdateBar draws it on a real
-- block (Core/Looks.lua PlaceThinBar, ColorThinBar). frac: 0 to 1, nil = no bar.
local function DrawBar(f, cfg, inset, left, frac)
    if not f.bar then
        f.bar = f:CreateTexture(nil, "BACKGROUND", nil, 7)
        f.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    if not frac or cfg.progressLook ~= "thin" then
        f.bar:Hide()
        if f.barTrack then f.barTrack:Hide() end
        f.barFrac = nil
        return
    end
    ns.PlaceThinBar(f, cfg, inset, left, true)
    ns.ColorThinBar(f, cfg, nil)
    f.barFrac = frac
    Sample.SetBar(f, frac)
    f.bar:Show()
end

-- The bar's length for a share (0 to 1); the track stays the full width
function Sample.SetBar(f, frac)
    if not (f.bar and f.barThin and f.barFrac) then return end
    local room = (f:GetWidth() or 0) - f.barThin.left - f.barThin.right
    f.bar:SetWidth(math.max(1, room * math.max(0, math.min(1, frac))))
    f.barFrac = frac
end

-- "42/80" gives 0.525
local function Share(text)
    local a, b = tostring(text or ""):match("(%d+)%s*/%s*(%d+)")
    a, b = tonumber(a), tonumber(b)
    if a and b and b > 0 then return a / b end
end
Sample.Share = Share

-- One block of a sample: same frame parts as a real block (Core.lua CreateBlock), skinned by
-- ns:SkinBlockFrame as the style offer does (OptionsTour.lua). Returns its width.
local function DrawBlock(f, cfg, moduleKey, text, h, withBar)
    local ok, inset = pcall(ns.SkinBlockFrame, ns, f, cfg)
    if not ok then inset = 0 end
    local mod = ns.modules and ns.modules[moduleKey]
    ns:SetIcon(f.icon, mod and type(mod.icon) ~= "function" and mod.icon or 134400)
    -- as a real block (Core.lua ApplyStyle): a "text only" style (Runestone) hides the icon,
    -- and the icon takes the style's frame, shape and black and white
    local showIcon = not cfg.hideIcons
    local iconSize = (cfg.iconSize or 0) > 0 and cfg.iconSize or math.max(8, h - 2 * inset - 4)
    f.icon:SetShown(showIcon)
    f.icon:SetSize(iconSize, iconSize)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("LEFT", f, "LEFT", 4 + inset, 0)
    if showIcon then pcall(ns.StyleIcon, ns, f, cfg) elseif f.iconBorder then f.iconBorder:Hide() end
    f.text:ClearAllPoints()
    local left
    if showIcon then
        f.text:SetPoint("LEFT", f.icon, "RIGHT", 4, 0)
        left = 4 + inset + iconSize + 4
    else
        f.text:SetPoint("LEFT", f, "LEFT", 6 + inset, 0)
        left = 6 + inset
        iconSize = -2
    end
    f.glide, f.glideLast = nil, text
    f.text:SetText(text)
    local w = math.ceil(f.text:GetStringWidth() or 0) + iconSize + 14 + 2 * inset
    f:SetSize(w, h)
    DrawBar(f, cfg, inset, left, withBar and Share(text) or nil)
    -- the glow under the mouse, as on a real block (Core/Looks.lua reads f.lifeCfg)
    f.lifeCfg = cfg
    pcall(ns.PrepareLife, f, cfg, f.nineSliceInfo and f.nineSliceInfo.edge or 6)
    return w
end

-- The separator between the two blocks, on a layer above both (Merge.lua DrawSeparators draws
-- it for real blocks: a line, or an ornament centered on the join)
local function DrawJoin(card, cfg, h)
    local layer = card.joinLayer
    local line, ornate = layer.line, layer.ornate
    line:Hide()
    ornate:Hide()
    if not cfg.separators then return end
    local c = cfg.separatorColor or { r = 1, g = 1, b = 1, a = 0.4 }
    if cfg.classColorSeparator then c = ns:GetClassColor(c.a) or c end
    local a = card.sample
    if ns.SEPARATOR_FILES[cfg.separatorStyle or "line"] then
        local len = math.min(h - 6, 18)
        if len < 6 then return end
        ns.SetOrnateSeparator(ornate, cfg.separatorStyle, false)
        ornate:SetVertexColor(c.r, c.g, c.b, c.a)
        ornate:SetSize(len / 2, len)
        ornate:ClearAllPoints()
        ornate:SetPoint("CENTER", a, "RIGHT", 0, 0)
        ornate:Show()
    else
        local inset = math.min(6, h / 4)
        line:SetVertexColor(c.r, c.g, c.b, c.a)
        line:SetSize(ns:PixelSize(1, a), math.max(2, h - 2 * inset))
        line:ClearAllPoints()
        line:SetPoint("RIGHT", a, "RIGHT", 0, 0)
        line:Show()
    end
end

-- The two merged blocks of a card (gold, then bags) in a style. tweak(cfg): the gallery's
-- workshop settings (what the player will get). withBar: the bags show their thin bar when
-- the style has one (the demo). Returns their total width and their height.
function Sample.Draw(card, style, tweak, withBar)
    local cfg = ns:GetBlockDefaults("gold")
    ns:ApplyThemeToCfg(cfg, style)
    if tweak then tweak(cfg) end
    cfg.showIcon, cfg.showLabel = true, false
    local h = math.max(18, cfg.height or 22)
    local step = card.animStep or 0
    local a, b = card.sample, card.sample2
    local wA = DrawBlock(a, cfg, "gold", Sample.TEXTS[1][step % 3 + 1], h)
    local wB = DrawBlock(b, ns.DeepCopy(cfg), "bags", Sample.TEXTS[2][step % 3 + 1], h, withBar)
    b:ClearAllPoints()
    b:SetPoint("LEFT", a, "RIGHT", 0, 0)
    -- merged as in a group (Merge.lua ApplySeams): the touching sides open
    a.seamKey, b.seamKey = nil, nil
    pcall(ns.ApplySeams, ns, a, { W = wA, H = h, TOP = {}, BOTTOM = {}, LEFT = {}, RIGHT = { { 0, h } }, cornerNotch = {} })
    pcall(ns.ApplySeams, ns, b, { W = wB, H = h, TOP = {}, BOTTOM = {}, LEFT = { { 0, h } }, RIGHT = {}, cornerNotch = {} })
    DrawJoin(card, cfg, h)
    card.pairW = wA + wB
    return wA + wB, h
end

-- Under the mouse: both blocks light up
function Sample.Hover(card, on)
    card.hovered = on or nil
    ns.GlowTo(card.sample, on and 1 or 0)
    ns.GlowTo(card.sample2, on and 1 or 0)
end

-- One frame of the animation for cards[1..n]: the first block lights up, then the second, then
-- both numbers change (gliding when the style asks for it) and the bar follows. state keeps the
-- time (animT, animStep, animFirst). "Fewer animations" keeps them still (ns.GlowTo,
-- ns.SetBlockText); the caller checks it first.
function Sample.Tick(state, cards, n, elapsed)
    state.animT = (state.animT or 0) + (elapsed or 0)
    local t = state.animT
    local step = math.floor(t / Sample.PERIOD)
    local first = (t % Sample.PERIOD) < Sample.PERIOD / 2
    local stepped = step ~= state.animStep
    if first == state.animFirst and not stepped then return end
    state.animFirst, state.animStep = first, step
    for i = 1, n do
        local c = cards[i]
        if c:IsShown() and not c.hovered then
            ns.GlowTo(c.sample, first and 1 or 0)
            ns.GlowTo(c.sample2, first and 0 or 1)
            if stepped then
                c.animStep = step
                local text = Sample.TEXTS[2][step % 3 + 1]
                ns.SetBlockText(c.sample, c.sample.lifeCfg, Sample.TEXTS[1][step % 3 + 1])
                ns.SetBlockText(c.sample2, c.sample2.lifeCfg, text)
                if c.sample2.barFrac then Sample.SetBar(c.sample2, Share(text) or c.sample2.barFrac) end
            end
        end
    end
end

-- The animation stops: both blocks dark again (off = at once, the window is closing)
function Sample.Still(state, cards, n, off)
    state.animFirst = nil
    for i = 1, n or 0 do
        local c = cards[i]
        for _, f in ipairs({ c.sample, c.sample2 }) do
            if off then ns.GlowOff(f) else ns.GlowTo(f, 0) end
        end
    end
end

-- The animation starts again from the first values
function Sample.Restart(state, cards)
    state.animT, state.animStep, state.animFirst = 0, nil, nil
    for _, c in ipairs(cards) do c.animStep = 0 end
end
