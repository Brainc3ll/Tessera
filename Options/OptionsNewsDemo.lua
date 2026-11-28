local _, ns = ...
local L = ns.L

-- The demo of the new styles in the update window (2.0.0, zip 6, 27/11): the six rounded styles
-- as real blocks drawn by Tessera, two merged blocks each (gold, bags). They light up in turn,
-- their numbers glide and the bags' thin bar follows. A click marks a style; "Try <style>..."
-- opens the style gallery on it (nothing changes before Apply). "Fewer animations" keeps
-- them still. Nothing here is saved.
-- The keyboard and gamepad of the whole update window live here too (ns.NewsDemo.AttachKeys):
-- Tab or the d-pad puts the focus in the window (the arrows stay the player's until then),
-- arrows or d-pad move, Enter or A presses, Escape or B closes.
local Tools = ns.OptionsTools
local Skin = ns.Skin
local AttachTip = Tools.AttachTip
local Sample = ns.StyleSample
local MEDIA = Skin.MEDIA

local Demo = {}
ns.NewsDemo = Demo

local GAP, MIN_CARD_W, MAX_W, COLUMNS = 8, 150, 760, 3
local NEW_STYLES = { "hdGold", "hdRune", "hdSilver", "hdBronze", "hdJade", "hdAmethyst" }
local demo -- the frame inside the update window
local state = {} -- the animation's time (OptionsStyleSample.lua)

local function Still() return ns.sv and ns.sv.reduceMotion end

-- A ring around a card or a button: where the keyboard or gamepad focus is
local function Ring(owner)
    owner.ring = CreateFrame("Frame", nil, owner)
    owner.ring:SetPoint("TOPLEFT", -4, 4)
    owner.ring:SetPoint("BOTTOMRIGHT", 4, -4)
    owner.ringTex = Sample.Sliced(owner.ring, "OVERLAY", "frame8", 10)
    owner.ring:Hide()
    Skin.Paint(function(p) Skin.Tint(owner.ringTex, p.contrast and p.edge or p.bar, 1) end)
end
Demo.Ring = Ring

local ShowMarks

local function NewCard(parent)
    local c = CreateFrame("Button", nil, parent)
    c.fill = c:CreateTexture(nil, "BACKGROUND")
    c.fill:SetAllPoints()
    c.hover = c:CreateTexture(nil, "HIGHLIGHT")
    c.hover:SetAllPoints()
    Sample.NewPair(c)
    c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c.label:SetJustifyH("CENTER")
    c.label:SetWordWrap(true)
    -- marked: a thick edge and a check mark (a shape, not only a color)
    c.edge = Sample.Sliced(c, "BORDER", "frame8b", 10)
    c.check = c:CreateTexture(nil, "OVERLAY", nil, 2)
    c.check:SetTexture(MEDIA .. "check")
    c.check:SetSize(18, 18)
    c.check:SetPoint("TOPRIGHT", -3, -3)
    Ring(c)
    Skin.Paint(function(p)
        c.fill:SetColorTexture(p.box[1], p.box[2], p.box[3], p.contrast and 1 or 0.35)
        c.hover:SetColorTexture(p.hover[1], p.hover[2], p.hover[3], p.hover[4] or 0.16)
        Skin.Tint(c.edge, p.title, 1)
        Skin.Tint(c.check, p.title, 1)
    end)
    c:SetScript("OnClick", function(self)
        demo.chosen = self.index
        ShowMarks()
    end)
    c:HookScript("OnEnter", function(self) Sample.Hover(self, true) end)
    c:HookScript("OnLeave", function(self) Sample.Hover(self, false) end)
    return c
end

-- The marked style: its card, and its name on the Try button
function ShowMarks()
    if not demo then return end
    local card = demo.cards[demo.chosen or 1]
    for _, c in ipairs(demo.cards) do
        local marked = c == card
        c.edge:SetShown(marked)
        c.check:SetShown(marked)
    end
    demo.try:SetText(L.WHATS_NEW_DEMO_TRY:format(card and card.name or ""))
    demo.measure:SetText(demo.try:GetText() or "")
    demo.try:SetWidth(math.max(160, math.ceil(demo.measure:GetStringWidth() or 0) + 32))
    if demo.onMarks then demo.onMarks() end
end

local function Build(parent)
    demo = CreateFrame("Frame", nil, parent)
    demo.title = demo:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    demo.title:SetJustifyH("CENTER")
    demo.title:SetPoint("TOPLEFT", 0, 0)
    demo.measure = demo:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    demo.measure:Hide()
    demo.cards = {}
    for i = 1, #NEW_STYLES do
        local c = NewCard(demo)
        c.index = i
        demo.cards[i] = c
    end
    demo.try = Skin.Button(CreateFrame("Button", nil, demo, "UIPanelButtonTemplate"))
    demo.try:SetHeight(26)
    Ring(demo.try)
    demo.try:SetScript("OnClick", function()
        local card = demo.cards[demo.chosen or 1]
        if not card then return end
        parent:Hide()
        ns:OpenLookStyleGallery(card.key)
    end)
    AttachTip(demo.try, L.STYLE_GALLERY_TITLE, L.TIP_WHATS_NEW_DEMO_TRY)
    -- a click marks a card: the focus ring follows when the keyboard is in use
    demo.onMarks = function() if parent.keyboardOn and parent.showFocus then parent.showFocus() end end
    -- (runs only while the update window is shown)
    demo:SetScript("OnUpdate", function(_, elapsed)
        if Still() then return end
        Sample.Tick(state, demo.cards, demo.nCards or 0, elapsed)
    end)
    demo:SetScript("OnHide", function() Sample.Still(state, demo.cards, demo.nCards or 0, true) end)
end

-- The styles to show: the six new ones the game can draw (a missing one is left out)
local function Styles()
    local have, list = {}, {}
    for _, t in ipairs(ns:GetAvailableThemes()) do have[t.key] = t.name end
    for _, key in ipairs(NEW_STYLES) do
        if have[key] then list[#list + 1] = { key = key, name = have[key] } end
    end
    return list
end

-- True when the update window should show the demo: an entry of the versions the player has
-- not seen yet asks for it (Extras/Changelog.lua, demo = "styles"), and Tessera shows blocks
function Demo.Wanted(entries)
    if ns.brokerModeActive then return false end
    for _, entry in ipairs(entries or {}) do
        if entry.demo == "styles" then return #Styles() > 0 end
    end
    return false
end

-- The width the demo would like for three cards in a row (the window takes it, within the screen)
local function Measure(list)
    local widest, tallest = MIN_CARD_W, 18
    for i, item in ipairs(list) do
        local c = demo.cards[i]
        c.key, c.name = item.key, item.name
        local w, h = Sample.Draw(c, item.key, nil, true)
        widest = math.max(widest, w + 16)
        tallest = math.max(tallest, h)
    end
    return widest, tallest
end

function Demo.WantedWidth(parent)
    if not demo then Build(parent) end
    local list = Styles()
    local widest = Measure(list)
    return math.min(MAX_W, math.max(1, math.min(#list, COLUMNS)) * (widest + GAP) - GAP)
end

-- Draws the demo under `above` in the update window, `width` wide. Returns its height.
function Demo.Show(parent, above, width)
    if not demo then Build(parent) end
    local list = Styles()
    Sample.Restart(state, demo.cards)
    local widest, tallest = Measure(list)
    demo.nCards = #list
    demo.title:SetWidth(width)
    demo.title:SetText(L.WHATS_NEW_DEMO_TITLE)
    local columns = math.max(1, math.min(COLUMNS, #list, math.floor((width + GAP) / (widest + GAP))))
    local cardW = math.floor((width - GAP * (columns - 1)) / columns)
    -- the marked style: the player's own when it is one of them, otherwise the first
    demo.chosen = 1
    local current = ns.GetTheme and ns:GetTheme()
    for i, item in ipairs(list) do if item.key == current then demo.chosen = i end end
    -- cards in rows; a row is as tall as its tallest name (two lines rather than a cut name)
    local y = math.ceil(demo.title:GetStringHeight() or 14) + 10
    local row, col, rowCards = 0, 0, {}
    local function CloseRow()
        if #rowCards == 0 then return end
        local labelH = 0
        for _, c in ipairs(rowCards) do labelH = math.max(labelH, c.labelH) end
        local h = 10 + tallest + 8 + labelH + 8
        for _, c in ipairs(rowCards) do c:SetHeight(h) end
        y = y + h + GAP
        rowCards, col = {}, 0
    end
    for i, c in ipairs(demo.cards) do
        local shown = i <= #list
        c:SetShown(shown)
        if shown then
            if col == 0 then row = row + 1 end
            c.row, c.col = row, col
            c:SetWidth(cardW)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", demo, "TOPLEFT", col * (cardW + GAP), -y)
            c.sample:ClearAllPoints()
            c.sample:SetPoint("TOPLEFT", c, "TOP", -math.floor((c.pairW or 0) / 2),
                -10 - math.floor((tallest - c.sample:GetHeight()) / 2))
            c.label:SetWidth(cardW - 12)
            c.label:SetText(c.name)
            c.label:ClearAllPoints()
            c.label:SetPoint("TOP", c, "TOP", 0, -10 - tallest - 8)
            c.labelH = math.ceil(c.label:GetStringHeight() or 14)
            rowCards[#rowCards + 1] = c
            col = col + 1
            if col >= columns then CloseRow() end
        end
    end
    CloseRow()
    demo.rows = row
    demo.try:ClearAllPoints()
    demo.try:SetPoint("TOPRIGHT", demo, "TOPRIGHT", 0, -y - 2)
    y = y + 2 + 26
    demo:ClearAllPoints()
    demo:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -16)
    demo:SetSize(width, y)
    demo:Show()
    ShowMarks()
    return 16 + y
end

function Demo.Hide()
    if demo then demo:Hide() end
end
function Demo.Shown() return demo ~= nil and demo:IsShown() end
function Demo.Frame() return demo end -- (tools/mock_run.lua)

---------------------------------------------------------------------------
-- Keyboard and gamepad of the update window
---------------------------------------------------------------------------
local KEYS = {
    LEFT = "left", RIGHT = "right", UP = "up", DOWN = "down", TAB = "tab",
    PADDLEFT = "left", PADDRIGHT = "right", PADDUP = "up", PADDDOWN = "down",
    ENTER = "confirm", SPACE = "confirm", PAD1 = "confirm", ESCAPE = "back", PAD2 = "back",
}
-- the keys that put the focus in the window (the arrows stay the player's until then)
local WAKE = { TAB = true, PADDLEFT = true, PADDRIGHT = true, PADDUP = true, PADDDOWN = true }

-- What can take the focus, in order: the demo's cards, its Try button, then the window's own
-- buttons (buttons() returns the shown ones, in order)
local function Targets(win)
    local list = {}
    if Demo.Shown() then
        for i = 1, demo.nCards or 0 do list[#list + 1] = demo.cards[i] end
        list[#list + 1] = demo.try
    end
    for _, b in ipairs(win.navButtons()) do list[#list + 1] = b end
    return list
end

local function ShowFocus(win)
    local list = Targets(win)
    for i, t in ipairs(list) do
        if t.ring then t.ring:SetShown(win.keyboardOn and i == win.focus) end
    end
    if Demo.Shown() then
        for i = (demo.nCards or 0) + 1, #demo.cards do demo.cards[i].ring:Hide() end
    end
end

-- The card of a row closest to a column
local function CardAt(row, col)
    local best
    for i = 1, demo.nCards or 0 do
        local c = demo.cards[i]
        if c.row == row and (not best or math.abs(c.col - col) < math.abs(demo.cards[best].col - col)) then best = i end
    end
    return best
end

local function Press(b)
    local run = b:GetScript("OnClick")
    if run then run(b, "LeftButton") end
end

-- One key: returns true when the window used it
local function Key(win, key)
    local what = KEYS[key]
    if not what then return false end
    if not win.keyboardOn then
        if not WAKE[key] then return false end
        -- the first Tab or d-pad press shows where the focus is: the marked card, or the first button
        win.keyboardOn = true
        win.focus = Demo.Shown() and (demo.chosen or 1) or 1
        ShowFocus(win)
        return true
    end
    if what == "back" then
        win:Hide()
        return true
    end
    local list = Targets(win)
    local n = #list
    if n == 0 then return false end
    local focus = math.max(1, math.min(n, win.focus or 1))
    local nCards = Demo.Shown() and (demo.nCards or 0) or 0
    local t = list[focus]
    if what == "confirm" then
        if focus <= nCards then
            -- a card: marks it; a marked card tries it
            Press(demo.chosen == focus and demo.try or t)
        elseif t and t:IsEnabled() then
            Press(t)
        end
        return true
    end
    if what == "tab" then
        -- cards, then Try, then the window's buttons, then back to the cards
        if focus <= nCards then focus = nCards + 1
        elseif focus < n then focus = focus + 1
        else focus = nCards > 0 and (demo.chosen or 1) or 1 end
    elseif focus <= nCards then
        local c = demo.cards[focus]
        if what == "left" then focus = math.max(1, focus - 1)
        elseif what == "right" then focus = math.min(nCards, focus + 1)
        elseif what == "up" then focus = CardAt(c.row - 1, c.col) or focus
        elseif what == "down" then focus = CardAt(c.row + 1, c.col) or nCards + 1 end
    else
        if what == "up" and focus == nCards + 1 and nCards > 0 then
            focus = CardAt(demo.rows or 1, 0) or 1
            for i = 1, nCards do if demo.cards[i].row == demo.rows and i == demo.chosen then focus = i end end
        elseif what == "left" or what == "up" then focus = math.max(nCards > 0 and nCards + 1 or 1, focus - 1)
        else focus = math.min(n, focus + 1) end
    end
    win.focus = focus
    ShowFocus(win)
    return true
end
Demo.Key = Key -- (tools/mock_run.lua)

-- Keys are taken only while the window is open and out of combat (the game gets them back)
local function Listen(win, on)
    if InCombatLockdown() then on = false end
    win:EnableKeyboard(on)
    if win.EnableGamePadButton then win:EnableGamePadButton(on) end
end

-- win.navButtons(): the window's own buttons that can take the focus, in order
function Demo.AttachKeys(win)
    local function OnKey(self, key)
        if InCombatLockdown() then return end
        self:SetPropagateKeyboardInput(not Key(self, key))
    end
    win:SetScript("OnKeyDown", OnKey)
    if win.EnableGamePadButton then win:SetScript("OnGamePadButtonDown", OnKey) end
    win:HookScript("OnShow", function(self)
        self.keyboardOn, self.focus = false, 1
        Listen(self, true)
    end)
    win:HookScript("OnHide", function(self)
        Listen(self, false)
        self.keyboardOn = false
        Demo.Hide()
    end)
    win:RegisterEvent("PLAYER_REGEN_DISABLED")
    win:RegisterEvent("PLAYER_REGEN_ENABLED")
    win:SetScript("OnEvent", function(self, event)
        if not self:IsShown() then return end
        Listen(self, event == "PLAYER_REGEN_ENABLED")
    end)
    win.showFocus = function() ShowFocus(win) end
end
