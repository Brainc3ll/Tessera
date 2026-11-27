local _, ns = ...
local L = ns.L

-- Style gallery: every style as a real block drawn by Tessera, in rows by family. Opened by
-- "Pick the style..." under the style lists of the Look tab and of a block's page. A click
-- (or Enter, or A) marks a thumbnail; nothing changes before a button at the bottom is
-- pressed: "Apply" for the profile's style, or "This block / Its group / All blocks" on a
-- block's page. Arrows or d-pad move, Enter or A confirms, Escape or B closes. Nothing is
-- saved by the window itself.
local Tools = ns.OptionsTools
local Skin = ns.Skin
local FitButtonText = Tools.FitButtonText
local AttachTip = Tools.AttachTip

local WINDOW_W, WINDOW_H, PAD = 900, 560, 18
local MIN_CARD_W, GAP, BAR_H = 196, 8, 44
local SAMPLE_TEXT = "1 234   42/80   17:42"
local MEDIA = Skin.MEDIA

-- Families of the gallery, in order (decided 26/11 and 27/11). A style found in none of them
-- goes to "Others", so none is lost when a style is added.
ns.STYLE_FAMILIES = {
    { title = "STYLE_FAMILY_NEW", keys = { "hdGold", "hdRune", "hdSilver", "hdBronze" } },
    { title = "STYLE_FAMILY_FANTASY", keys = { "runestone", "grimoire", "parchment", "arcane" } },
    { title = "STYLE_FAMILY_FRAMES", keys = { "royalSeal", "ironforge", "runeblade", "ember", "sylvan", "warWithin", "midnight" } },
    { title = "STYLE_FAMILY_BLIZZARD", keys = { "blizzardModern", "modernSquare", "blizzardForever", "foreverSquare", "blizzard", "classicSquare" } },
    { title = "STYLE_FAMILY_UIS", keys = { "flareui2", "flareui", "flareui6", "flareSquare", "ellesmere", "elvui", "aurore" } },
    { title = "STYLE_FAMILY_SIMPLE", keys = { "tessera", "flat", "transparent" } },
}

-- The rows to draw: { title = text } then { key, name, style } per thumbnail. withAuto puts
-- "Automatic" first, drawn in the style it gives now.
function ns.StyleGalleryRows(withAuto)
    local rows, byKey, placed = {}, {}, {}
    for _, t in ipairs(ns:GetAvailableThemes()) do byKey[t.key] = t end
    if withAuto then
        local autoKey = ns:GetAutoTheme()
        local info = ns:GetThemeInfo(autoKey)
        rows[#rows + 1] = { title = L.STYLE_FAMILY_AUTO }
        rows[#rows + 1] = { key = "auto", style = autoKey, name = L.THEME_AUTO_FMT:format(info and info.name or "?") }
    end
    local function Family(title, keys)
        local first = true
        for _, key in ipairs(keys) do
            local t = byKey[key]
            if t and not placed[key] then
                placed[key] = true
                if first then rows[#rows + 1] = { title = title } first = false end
                rows[#rows + 1] = { key = key, style = key, name = t.name }
            end
        end
    end
    for _, fam in ipairs(ns.STYLE_FAMILIES) do Family(L[fam.title], fam.keys) end
    local rest = {}
    for _, t in ipairs(ns:GetAvailableThemes()) do
        if not placed[t.key] then rest[#rest + 1] = t.key end
    end
    Family(L.STYLE_FAMILY_OTHER, rest) -- already in alphabetical order
    return rows
end

local gallery
local opts = {}

-- A white drawing of Media/Skin stretched by its edges
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

-- The sample block of a thumbnail: same frame parts as a real block (Core.lua CreateBlock),
-- skinned by ns:SkinBlockFrame as the style offer does (OptionsTour.lua). Returns its width.
local function DrawSample(card, style)
    local f = card.sample
    local cfg = ns:GetBlockDefaults("gold")
    ns:ApplyThemeToCfg(cfg, style)
    cfg.showIcon, cfg.showLabel = true, false
    local ok, inset = pcall(ns.SkinBlockFrame, ns, f, cfg)
    if not ok then inset = 0 end
    local mod = ns.modules and ns.modules.gold
    ns:SetIcon(f.icon, mod and type(mod.icon) ~= "function" and mod.icon or 134400)
    local h = math.max(18, cfg.height or 22)
    local iconSize = math.max(8, h - 2 * inset - 4)
    f.icon:SetSize(iconSize, iconSize)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("LEFT", f, "LEFT", 4 + inset, 0)
    f.text:ClearAllPoints()
    f.text:SetPoint("LEFT", f.icon, "RIGHT", 4, 0)
    f.text:SetText(SAMPLE_TEXT)
    local w = math.ceil(f.text:GetStringWidth() or 0) + iconSize + 14 + 2 * inset
    f:SetSize(w, h)
    return w, h
end

local Refresh, ShowMarks

local function Choose(index)
    local card = gallery.cards[index]
    if not card or not card:IsShown() then return end
    gallery.chosen = card.key
    gallery.focus = index
    ShowMarks()
end

local function NewCard(parent)
    local c = CreateFrame("Button", nil, parent)
    c.fill = c:CreateTexture(nil, "BACKGROUND")
    c.fill:SetAllPoints()
    c.hover = c:CreateTexture(nil, "HIGHLIGHT")
    c.hover:SetAllPoints()
    c.sample = CreateFrame("Frame", nil, c, "BackdropTemplate")
    c.sample.icon = c.sample:CreateTexture(nil, "ARTWORK")
    c.sample.text = c.sample:CreateFontString(nil, "OVERLAY")
    c.sample.text:SetWordWrap(false)
    c.sample:EnableMouse(false)
    c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c.label:SetJustifyH("CENTER")
    c.label:SetWordWrap(true)
    c.tag = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    c.tag:SetJustifyH("CENTER")
    -- chosen: a thick edge and a check mark (a shape, not only a color)
    c.edge = Sliced(c, "BORDER", "frame8b", 10)
    c.check = c:CreateTexture(nil, "OVERLAY", nil, 2)
    c.check:SetTexture(MEDIA .. "check")
    c.check:SetSize(20, 20)
    c.check:SetPoint("TOPRIGHT", -4, -4)
    -- keyboard / gamepad focus: a ring outside the card
    c.ring = CreateFrame("Frame", nil, c)
    c.ring:SetPoint("TOPLEFT", -4, 4)
    c.ring:SetPoint("BOTTOMRIGHT", 4, -4)
    c.ringTex = Sliced(c.ring, "OVERLAY", "frame8", 10)
    Skin.Paint(function(p)
        c.fill:SetColorTexture(p.box[1], p.box[2], p.box[3], p.contrast and 1 or 0.35)
        c.hover:SetColorTexture(p.hover[1], p.hover[2], p.hover[3], p.hover[4] or 0.16)
        Skin.Tint(c.edge, p.title, 1)
        Skin.Tint(c.check, p.title, 1)
        Skin.Tint(c.ringTex, p.contrast and p.edge or p.bar, 1)
        Skin.TextColor(c.tag, p.soft)
    end)
    c:SetScript("OnClick", function(self) Choose(self.index) end)
    return c
end

-- Bottom buttons: the actions given by the opener, then Close
local function NewBarButton(parent)
    local b = Skin.Button(CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"))
    b:SetHeight(26)
    b.ring = CreateFrame("Frame", nil, b)
    b.ring:SetPoint("TOPLEFT", -4, 4)
    b.ring:SetPoint("BOTTOMRIGHT", 4, -4)
    b.ringTex = Sliced(b.ring, "OVERLAY", "frame8", 10)
    Skin.Paint(function(p) Skin.Tint(b.ringTex, p.contrast and p.edge or p.bar, 1) end)
    return b
end

local function ChosenStyle()
    if gallery.chosen == "auto" then return ns:GetAutoTheme() end
    return gallery.chosen
end

local function LayoutButtons()
    local x = WINDOW_W - PAD
    local list = gallery.buttons
    for i = #list, 1, -1 do
        local b = list[i]
        if b:IsShown() then
            gallery.measure:SetText(b:GetText() or "")
            local w = math.max(110, math.ceil(gallery.measure:GetStringWidth() or 0) + 28)
            b:SetWidth(w)
            FitButtonText(b)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMRIGHT", gallery, "BOTTOMLEFT", x, PAD - 4)
            x = x - w - GAP
        end
    end
    gallery.status:SetPoint("RIGHT", gallery, "BOTTOMLEFT", x - GAP, PAD + 9)
end

-- Marks: chosen card, focus ring (only once a key or the d-pad was used), button states
function ShowMarks()
    local focus = gallery.keyboardOn and gallery.focus
    local current = opts.current and opts.current()
    for i, c in ipairs(gallery.cards) do
        if c:IsShown() then
            local chosen = c.key == gallery.chosen
            c.edge:SetShown(chosen)
            c.check:SetShown(chosen)
            c.ring:SetShown(focus == i)
            c.tag:SetText(c.key == current and opts.currentLabel or "")
        end
    end
    local nCards = gallery.nCards or 0
    for i, b in ipairs(gallery.buttons) do
        -- kept on the button too: the keyboard skips a greyed button
        b.usable = not b.action or b.action.enabled == nil or b.action.enabled(gallery.chosen) and true or false
        b:SetEnabled(b.usable)
        b.ring:SetShown(focus == nCards + i)
    end
    local name
    for _, c in ipairs(gallery.cards) do
        if c:IsShown() and c.key == gallery.chosen then name = c.name end
    end
    gallery.status:SetText(name and L.STYLE_GALLERY_CHOSEN:format(name) or L.STYLE_GALLERY_HINT)
end

function Refresh()
    local rows = ns.StyleGalleryRows(opts.auto)
    -- first pass: draw every sample, so every card is as wide as the widest (a text twice as
    -- big gives wider samples and fewer columns, never a cut one)
    local cards, nCards, widest, tallest = gallery.cards, 0, MIN_CARD_W, 18
    for _, row in ipairs(rows) do
        if not row.title then
            nCards = nCards + 1
            local c = cards[nCards]
            if not c then
                c = NewCard(gallery.content)
                cards[nCards] = c
            end
            c.index, c.key, c.name = nCards, row.key, row.name
            local w, h = DrawSample(c, row.style)
            widest = math.max(widest, w + 16)
            tallest = math.max(tallest, h)
            c:Show()
        end
    end
    for i = nCards + 1, #cards do cards[i]:Hide() end
    gallery.nCards = nCards
    local usable = WINDOW_W - PAD - 34 - PAD
    widest = math.min(widest, usable)
    local columns = math.max(1, math.floor((usable + GAP) / (widest + GAP)))
    local cardW = math.floor((usable - GAP * (columns - 1)) / columns)
    -- second pass: place titles and cards; a row is as tall as its tallest name (two lines
    -- rather than a cut name)
    local y, col, nTitles, index, rowCards = 0, 0, 0, 0, {}
    local rowIndex = 0
    gallery.measure:SetText("Ag")
    local tagH = math.ceil(gallery.measure:GetStringHeight() or 12)
    local function CloseRow()
        if #rowCards == 0 then return end
        local labelH = 0
        for _, c in ipairs(rowCards) do labelH = math.max(labelH, c.labelH) end
        local h = 10 + tallest + 8 + labelH + 4 + tagH + 8
        for _, c in ipairs(rowCards) do c:SetHeight(h) end
        y = y + h + GAP + 4
        rowCards = {}
        col = 0
    end
    for _, row in ipairs(rows) do
        if row.title then
            CloseRow()
            nTitles = nTitles + 1
            local t = gallery.titles[nTitles]
            if not t then
                t = gallery.content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                gallery.titles[nTitles] = t
            end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", gallery.content, "TOPLEFT", 2, -y - 4)
            t:SetText(row.title)
            t:Show()
            y = y + math.ceil(t:GetStringHeight() or 16) + 12
        else
            index = index + 1
            local c = cards[index]
            if col == 0 then rowIndex = rowIndex + 1 end
            c.row, c.col, c.y = rowIndex, col, y
            c:SetWidth(cardW)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", gallery.content, "TOPLEFT", col * (cardW + GAP) + 4, -y - 4)
            c.sample:ClearAllPoints()
            c.sample:SetPoint("TOP", c, "TOP", 0, -10 - math.floor((tallest - c.sample:GetHeight()) / 2))
            c.label:SetWidth(cardW - 12)
            c.label:SetText(c.name)
            c.label:ClearAllPoints()
            c.label:SetPoint("TOP", c, "TOP", 0, -10 - tallest - 8)
            c.labelH = math.ceil(c.label:GetStringHeight() or 14)
            c.tag:SetWidth(cardW - 12)
            c.tag:ClearAllPoints()
            c.tag:SetPoint("TOP", c.label, "BOTTOM", 0, -4)
            rowCards[#rowCards + 1] = c
            col = col + 1
            if col >= columns then CloseRow() end
        end
    end
    CloseRow()
    for i = nTitles + 1, #gallery.titles do gallery.titles[i]:Hide() end
    gallery.content:SetSize(usable, math.max(y, 1))
    gallery.columns = columns
    -- the bottom buttons
    local actions = opts.actions or {}
    for i = 1, #actions + 1 do
        local b = gallery.buttons[i]
        if not b then
            b = NewBarButton(gallery)
            gallery.buttons[i] = b
        end
        local a = actions[i]
        b.action = a
        if a then
            b:SetText(a.text)
            AttachTip(b, a.text, a.tip)
            b:SetScript("OnClick", function()
                local key = gallery.chosen
                if not key or (a.enabled and not a.enabled(key)) then return end
                a.run(key, ChosenStyle())
                if gallery:IsShown() then ShowMarks() end
            end)
        else
            b:SetText(L.STYLE_GALLERY_CLOSE)
            b:SetScript("OnClick", function() gallery:Hide() end)
        end
        b:Show()
    end
    for i = #actions + 2, #gallery.buttons do
        gallery.buttons[i]:Hide()
        gallery.buttons[i].action = nil
    end
    LayoutButtons()
    ShowMarks()
end

-- Scrolls so the focused card is in view
local function EnsureVisible(card)
    local scroll = gallery.scroll
    local view = scroll:GetHeight() or 400
    local cur = scroll:GetVerticalScroll() or 0
    local maxScroll = scroll:GetVerticalScrollRange() or 0
    local top, bottom = card.y, card.y + (card:GetHeight() or 80) + 12
    if top < cur + 30 then
        scroll:SetVerticalScroll(math.max(0, top - 36))
    elseif bottom > cur + view then
        scroll:SetVerticalScroll(math.min(maxScroll, bottom - view))
    end
end

-- The usable buttons, in order (a greyed one is skipped)
local function ButtonIndexes()
    local list = {}
    for i, b in ipairs(gallery.buttons) do
        if b:IsShown() and b.usable then list[#list + 1] = gallery.nCards + i end
    end
    return list
end

-- The card of a row closest to a column
local function CardAt(row, col)
    local best
    for i = 1, gallery.nCards do
        local c = gallery.cards[i]
        if c.row == row then
            if not best or math.abs(c.col - col) < math.abs(gallery.cards[best].col - col) then best = i end
        end
    end
    return best
end

local KEYS = {
    LEFT = "left", RIGHT = "right", UP = "up", DOWN = "down", TAB = "tab",
    PADDLEFT = "left", PADDRIGHT = "right", PADDUP = "up", PADDDOWN = "down",
    ENTER = "confirm", SPACE = "confirm", PAD1 = "confirm", ESCAPE = "back", PAD2 = "back",
}

-- One key of the keyboard or gamepad: returns true when the gallery used it
function ns.StyleGalleryKey(key)
    local what = KEYS[key]
    if not (what and gallery and gallery:IsShown()) then return false end
    if what == "back" then
        gallery:Hide()
        return true
    end
    local nCards = gallery.nCards or 0
    if not gallery.keyboardOn then
        -- the first key shows where the focus is, on the chosen card
        gallery.keyboardOn = true
        if what ~= "confirm" then
            ShowMarks()
            if gallery.cards[gallery.focus] then EnsureVisible(gallery.cards[gallery.focus]) end
            return true
        end
    end
    local focus = gallery.focus or 1
    local onButtons = focus > nCards
    local buttons = ButtonIndexes()
    if what == "confirm" then
        if onButtons then
            local b = gallery.buttons[focus - nCards]
            if b and b.usable then b:GetScript("OnClick")(b) end
        else
            Choose(focus)
        end
    elseif what == "tab" then
        if onButtons then
            focus = CardAt(gallery.cards[1] and gallery.cards[1].row or 1, 0) or 1
            for i = 1, nCards do if gallery.cards[i].key == gallery.chosen then focus = i end end
        elseif #buttons > 0 then
            focus = buttons[1]
        end
    elseif onButtons then
        local pos = 1
        for i, idx in ipairs(buttons) do if idx == focus then pos = i end end
        if what == "left" then focus = buttons[math.max(1, pos - 1)] or focus
        elseif what == "right" then focus = buttons[math.min(#buttons, pos + 1)] or focus
        elseif what == "up" then
            local last = gallery.cards[nCards]
            focus = last and CardAt(last.row, 0) or focus
        end
    else
        local c = gallery.cards[focus]
        if what == "left" then focus = math.max(1, focus - 1)
        elseif what == "right" then focus = math.min(nCards, focus + 1)
        elseif what == "up" then focus = CardAt(c.row - 1, c.col) or focus
        elseif what == "down" then
            focus = CardAt(c.row + 1, c.col) or buttons[1] or focus
        end
    end
    gallery.focus = focus
    if focus <= nCards and gallery.cards[focus] then EnsureVisible(gallery.cards[focus]) end
    ShowMarks()
    return true
end

-- Keys are taken only while the window is open and out of combat (the game gets them back)
local function Listen(on)
    if InCombatLockdown() then on = false end
    gallery:EnableKeyboard(on)
    if gallery.EnableGamePadButton then gallery:EnableGamePadButton(on) end
end

local function OnKey(self, key)
    if InCombatLockdown() then return end
    local used = ns.StyleGalleryKey(key)
    self:SetPropagateKeyboardInput(not used)
end

local function Build()
    local f = CreateFrame("Frame", "TesseraStyleGallery", UIParent, "BackdropTemplate")
    gallery = f
    f:SetSize(WINDOW_W, WINDOW_H)
    f:SetPoint("CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    table.insert(UISpecialFrames, "TesseraStyleGallery")
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", PAD, -14)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    f.measure = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.measure:Hide()
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, f, "ScrollFrameTemplate")
    if not ok then scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate") end
    scroll:SetPoint("TOPLEFT", PAD, -44)
    scroll:SetPoint("BOTTOMRIGHT", -34, PAD + BAR_H)
    f.scroll = scroll
    f.content = CreateFrame("Frame", nil, scroll)
    f.content:SetSize(WINDOW_W - PAD - 34 - PAD, 10)
    scroll:SetScrollChild(f.content)
    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.status:SetPoint("LEFT", f, "BOTTOMLEFT", PAD + 4, PAD + 9)
    f.status:SetJustifyH("LEFT")
    f.status:SetWordWrap(true)
    f.cards, f.titles, f.buttons = {}, {}, {}
    f:SetScript("OnKeyDown", OnKey)
    if f.SetScript and f.EnableGamePadButton then f:SetScript("OnGamePadButtonDown", OnKey) end
    f:SetScript("OnShow", function() Listen(true) end)
    f:SetScript("OnHide", function()
        Listen(false)
        f.keyboardOn = false
    end)
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(self, event)
        if not self:IsShown() then return end
        if event == "PLAYER_REGEN_DISABLED" then
            self:EnableKeyboard(false)
            if self.EnableGamePadButton then self:EnableGamePadButton(false) end
        else
            Listen(true)
        end
    end)
    f:Hide() -- a new frame is shown: the window opens through ns:ShowStyleGallery
end

-- Opens the gallery. o = {
--   auto = true to offer "Automatic" first,
--   chosen = the key marked when it opens,
--   current = function returning the key that gets the tag currentLabel,
--   actions = { { text, tip, run = function(key, style), enabled = function(key) } } }
function ns:ShowStyleGallery(o)
    if not gallery then Build() end
    opts = o or {}
    ns:SkinWindow(gallery, gallery.title)
    gallery.title:SetText(L.STYLE_GALLERY_TITLE)
    gallery.chosen = opts.chosen or ns:GetTheme()
    gallery.keyboardOn = false
    gallery:Show()
    gallery:Raise()
    Refresh()
    gallery.focus = 1
    for i = 1, gallery.nCards do
        if gallery.cards[i].key == gallery.chosen then gallery.focus = i end
    end
    local card = gallery.cards[gallery.focus]
    gallery.scroll:SetVerticalScroll(0)
    if card then EnsureVisible(card) end
    ShowMarks()
end
function ns.StyleGallery() return gallery end -- (tools/mock_run.lua)
