local ADDON, ns = ...

-- Tessera's own confirmation window, in stone and metal (choice of Braincell1980, 27/11). It
-- replaces the game's grey popups (StaticPopup): those frames are shared by the whole game and
-- other addons, so they are never reskinned. The dialogs keep the game's shape, written in
-- ns.Dialogs (Core/Core.lua): text, button1 to button3, OnAccept, OnCancel(self, data, reason),
-- OnAlt, OnButton3 (with selectCallbackByIndex), OnShow, hasEditBox, EditBoxOnEnterPressed,
-- hideOnEscape. Added: defaultButton (the button selected when the window opens).
-- Choices of Braincell1980 (27/11): one window at a time, the next ones wait their turn; at
-- the top of the screen, where the grey ones opened; Cancel selected first when the answer
-- erases something; nothing blocked behind it.
local Skin = ns.Skin

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Skin\\"
local WINDOW_W, PAD, BUTTON_H, BUTTON_GAP, MIN_BUTTON_W = 420, 22, 24, 10, 110
local TOP_OFFSET = -135 -- where the game's first popup opens

local dialog   -- the window, built once
local current  -- { name, def, data } on screen
local queue = {} -- the next ones, in order

local function Sliced(f, layer, file, margin)
    local t = f:CreateTexture(nil, layer)
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

local function Formatted(text, a, b)
    text = text or ""
    if a == nil and b == nil then return text end
    local ok, out = pcall(string.format, text, a, b)
    return ok and out or text
end

-- Escape (with the game's own key, in combat too) closes only the windows that allow it
local function SetEscapable(on)
    local name = dialog:GetName()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == name then table.remove(UISpecialFrames, i) end
    end
    if on then table.insert(UISpecialFrames, name) end
end

local ShowNext

-- Closes the window after an answer (or by code): the callback runs once, then the next one
local function Close(wait)
    if not current then return end
    dialog.closing = true
    dialog:Hide()
    dialog.closing = nil
    current = nil
    if not wait then ShowNext() end
end

-- index 1, 2, 3: the buttons; "escape": Escape or the gamepad's B
local function Answer(index)
    local c = current
    if not c then return end
    local def, data = c.def, c.data
    -- the window hides first (a callback may open another dialog), the field keeps its text
    -- for the callback, and the next dialog opens after it
    if index == "escape" then
        if not def.hideOnEscape then return end
        Close(true)
        if def.OnCancel then def.OnCancel(dialog, data, "clicked") end
        ShowNext()
        return
    end
    -- a reload window reloads before it closes: hiding first can lose the click the game
    -- needs to allow a reload (the mouse goes through the secure button, see SecureReloadButton)
    if index == 1 and def.secureReload and def.OnAccept then
        def.OnAccept(dialog, data)
        return
    end
    Close(true)
    if def.selectCallbackByIndex and def["OnButton" .. index] then
        def["OnButton" .. index](dialog, data)
    elseif index == 1 then
        if def.OnAccept then def.OnAccept(dialog, data) end
    elseif index == 2 then
        if def.OnCancel then def.OnCancel(dialog, data, "clicked") end
    elseif def.OnAlt then
        def.OnAlt(dialog, data)
    end
    ShowNext()
end

-- Keyboard and gamepad focus: a ring around the selected button (a shape, not only a color)
local function ShowRing()
    for i, b in ipairs(dialog.buttons) do b.ring:SetShown(b:IsShown() and dialog.focus == i) end
end

local function Visible()
    local list = {}
    for i, b in ipairs(dialog.buttons) do
        if b:IsShown() then list[#list + 1] = i end
    end
    return list
end

local function MoveFocus(step)
    local list = Visible()
    local at = 1
    for k, i in ipairs(list) do
        if i == dialog.focus then at = k end
    end
    at = (at - 1 + step) % #list + 1
    dialog.focus = list[at]
    ShowRing()
end

local KEYS = {
    LEFT = "prev", RIGHT = "next", UP = "prev", DOWN = "next", TAB = "next",
    PADDLEFT = "prev", PADDRIGHT = "next", PADDUP = "prev", PADDDOWN = "next",
    ENTER = "confirm", SPACE = "confirm", PAD1 = "confirm", ESCAPE = "back", PAD2 = "back",
}

-- One key of the keyboard or gamepad: returns true when the window used it
function ns.DialogKey(key)
    local what = KEYS[key]
    if not (what and current and dialog:IsShown()) then return false end
    if what == "back" then
        -- a window with a real choice keeps Escape too: one of its buttons answers
        Answer("escape")
        return true
    elseif what == "confirm" then
        Answer(dialog.focus)
    elseif what == "next" then
        MoveFocus(IsShiftKeyDown and IsShiftKeyDown() and key == "TAB" and -1 or 1)
    else
        MoveFocus(-1)
    end
    return true
end

-- Keys are taken only while the window is open and out of combat (the game gets them back)
local function Listen(on)
    if InCombatLockdown() then on = false end
    dialog:EnableKeyboard(on)
    if dialog.EnableGamePadButton then dialog:EnableGamePadButton(on) end
end

local function OnKey(self, key)
    if InCombatLockdown() then return end
    self:SetPropagateKeyboardInput(not ns.DialogKey(key))
end

local function NewButton(i)
    local b = Skin.Button(CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate"))
    b:SetHeight(BUTTON_H)
    b:SetScript("OnClick", function() Answer(i) end)
    -- a window that reloads (secureReload) gets the game's own /reload on its first button
    if i == 1 then
        ns:SecureReloadButton(b, function()
            local fn = current and current.def.secureReload
            if type(fn) == "function" then fn() end
        end, function() return current and current.def.secureReload and true end)
    end
    b.ring = CreateFrame("Frame", nil, b)
    b.ring:SetPoint("TOPLEFT", -4, 4)
    b.ring:SetPoint("BOTTOMRIGHT", 4, -4)
    b.ringTex = Sliced(b.ring, "OVERLAY", "frame8", 10)
    Skin.Paint(function(p) Skin.Tint(b.ringTex, p.contrast and p.edge or p.bar, 1) end)
    b.ring:Hide()
    return b
end

local function Build()
    local f = CreateFrame("Frame", "TesseraDialog", UIParent, "BackdropTemplate")
    dialog = f
    f:SetWidth(WINDOW_W)
    f:SetPoint("TOP", UIParent, "TOP", 0, TOP_OFFSET)
    -- above Tessera's other windows (the options, the gallery), like the game's popups
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", 0, -PAD + 4)
    f.title:SetText("Tessera")
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("TOP", f.title, "BOTTOM", 0, -10)
    f.text:SetWidth(WINDOW_W - 2 * PAD)
    f.text:SetSpacing(2)
    Skin.Paint(function(p) Skin.TextColor(f.text, p.ink) end)
    -- the field of the dialogs that ask for a name or a number (the game's boxes are shared:
    -- this one is Tessera's own)
    local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    box:SetSize(WINDOW_W - 2 * PAD - 40, 24)
    box:SetAutoFocus(false)
    box:SetMaxLetters(64)
    Skin.Field(box)
    box:SetScript("OnEnterPressed", function(self)
        local c = current
        if not c then return end
        if c.def.EditBoxOnEnterPressed then
            -- the dialog's own handler answers and hides the window (self:GetParent():Hide())
            dialog.answered = true
            c.def.EditBoxOnEnterPressed(self, c.data)
            dialog.answered = nil
            if current == c then Close() end
        else
            Answer(1)
        end
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        Answer("escape")
    end)
    box:SetScript("OnTabPressed", function(self)
        self:ClearFocus()
        dialog.focus = 1
        ShowRing()
    end)
    f.editBox = box
    function f.GetEditBox() return box end
    f.buttons = { NewButton(1), NewButton(2), NewButton(3) }
    f:SetScript("OnKeyDown", OnKey)
    if f.EnableGamePadButton then f:SetScript("OnGamePadButtonDown", OnKey) end
    f:SetScript("OnShow", function() Listen(true) end)
    f:SetScript("OnHide", function(self)
        Listen(false)
        self.editBox:ClearFocus()
        if self.closing or self.answered or not current then return end
        -- hidden from outside: the game's Escape key (in combat) or the dialog's own code
        local c = current
        current = nil
        if c.def.hideOnEscape and c.def.OnCancel then c.def.OnCancel(self, c.data, "clicked") end
        ShowNext()
    end)
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self:EnableKeyboard(false)
            if self.EnableGamePadButton then self:EnableGamePadButton(false) end
        elseif self:IsShown() then
            Listen(true)
        end
    end)
    f:Hide()
end

-- Fills the window for the dialog on screen and sizes it to its text (a text twice as big
-- gives a taller window, never a cut one)
local function Fill()
    local c = current
    local def = c.def
    ns:SkinWindow(dialog, dialog.title)
    dialog.text:SetText(c.text)
    local box = dialog.editBox
    box:SetShown(def.hasEditBox and true or false)
    box:SetText("")
    box:ClearAllPoints()
    box:SetPoint("TOP", dialog.text, "BOTTOM", 0, -12)
    local labels = { def.button1, def.button2, def.button3 }
    local widths, total, n = {}, 0, 0
    for i, b in ipairs(dialog.buttons) do
        local label = labels[i]
        b:SetShown(label ~= nil)
        if label then
            b:SetText(label)
            local fs = b:GetFontString()
            widths[i] = math.max(MIN_BUTTON_W, math.ceil((fs and fs:GetStringWidth() or 0) + 30))
            b:SetWidth(widths[i])
            total = total + widths[i]
            n = n + 1
        end
    end
    total = total + BUTTON_GAP * math.max(0, n - 1)
    local width = math.max(WINDOW_W, total + 2 * PAD)
    dialog:SetWidth(width)
    dialog.text:SetWidth(width - 2 * PAD)
    local x = -total / 2
    for i, b in ipairs(dialog.buttons) do
        if b:IsShown() then
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", x, PAD - 4)
            x = x + widths[i] + BUTTON_GAP
        end
    end
    local h = (PAD - 4) + dialog.title:GetStringHeight() + 10 + dialog.text:GetStringHeight()
    if box:IsShown() then h = h + 12 + box:GetHeight() end
    dialog:SetHeight(math.floor(h + 18 + BUTTON_H + (PAD - 4) + 0.5))
    local focus = def.defaultButton or 1
    if not dialog.buttons[focus]:IsShown() then focus = 1 end
    dialog.focus = focus
    ShowRing()
    SetEscapable(def.hideOnEscape and true or false)
end

function ShowNext()
    if current or #queue == 0 then return end
    if not dialog then Build() end
    current = table.remove(queue, 1)
    Fill()
    dialog.data = current.data
    dialog:Show()
    dialog:Raise()
    if current.def.OnShow then current.def.OnShow(dialog, current.data) end
    if current.def.hasEditBox then dialog.editBox:SetFocus() end
end

-- Shows the dialog `name` of ns.Dialogs (same arguments as the game's StaticPopup_Show). The
-- same dialog asked again takes the new text and data; another one waits its turn.
function ns:ShowDialog(name, textArg1, textArg2, data)
    local def = ns.Dialogs[name]
    if not def then return end
    local entry = { name = name, def = def, data = data, text = Formatted(def.text, textArg1, textArg2) }
    if current and current.name == name then
        current.def, current.data, current.text = def, data, entry.text
        dialog.data = data
        Fill()
        if def.OnShow then def.OnShow(dialog, data) end
        return dialog
    end
    for i, q in ipairs(queue) do
        if q.name == name then
            queue[i] = entry
            return
        end
    end
    queue[#queue + 1] = entry
    ShowNext()
    return current and current.name == name and dialog or nil
end

-- True when the dialog `name` is on screen (or waiting its turn)
function ns:IsDialogShown(name)
    if current and current.name == name then return true end
    for _, q in ipairs(queue) do
        if q.name == name then return true end
    end
    return false
end

-- Closes the dialog `name` without an answer (no callback)
function ns:HideDialog(name)
    for i = #queue, 1, -1 do
        if queue[i].name == name then table.remove(queue, i) end
    end
    if current and current.name == name then Close() end
end

-- For the tests: the window, the dialog on screen, and a click on one of its buttons
function ns.DialogState()
    return dialog, current and current.name, #queue
end
function ns.DialogClick(index) Answer(index) end
