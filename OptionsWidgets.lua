local _, ns = ...
local L = ns.L

-- Widgets part of the options window: the widget factory (rows, checkbox, slider, dropdown, color, edit box, button) and the column layout.
-- Shared with the other Options*.lua files through ns.OptionsTools (see Options.lua).
local Tools = ns.OptionsTools
local S = Tools.S
local ALL, COL_W, COL_X, Cfg = Tools.ALL, Tools.COL_W, Tools.COL_X, Tools.Cfg
local FULL_W, GroupHead, IsGroup, LAUNCHERS = Tools.FULL_W, Tools.GroupHead, Tools.IsGroup, Tools.LAUNCHERS
local PER_BLOCK_FIELDS, SPACER_SHARED_FIELDS, SPACING, Targets = Tools.PER_BLOCK_FIELDS, Tools.SPACER_SHARED_FIELDS, Tools.SPACING, Tools.Targets
local widgets = Tools.widgets


local function SetField(name, value)
    if name == "enabled" then
        local keys = Targets()
        if not value and #keys > 1 then
            StaticPopup_Show("TESSERA_REMOVE_BLOCKS", #keys, nil, keys)
            return
        end
        ns:SetBlocksOnScreen(keys, value and true or false)
    else
        for _, key in ipairs(Targets()) do
            ns.db.blocks[key][name] = ns.DeepCopy(value)
            ns:ApplyStyle(key)
        end
    end
    if (S.selected == ALL or GroupHead()) and SPACER_SHARED_FIELDS[name] then
        local all = GroupHead() and ns:GetStyleGroup(GroupHead()) or ns:GetBlockKeys()
        for _, key in ipairs(all) do
            if ns.IsSpacerKey(key) then
                ns.db.blocks[key][name] = ns.DeepCopy(value)
                ns:ApplyStyle(key)
            end
        end
    end
    -- showing a single block: unlock so the user can place it
    if name == "enabled" and value and not IsGroup() and ns.db.locked then ns:SetLocked(false) end
    -- remembered for blocks created or added later (except visibility and sizes)
    if not PER_BLOCK_FIELDS[name] then
        if S.selected == ALL then ns.db.groupDefaults[name] = ns.DeepCopy(value) end
        if S.selected == ALL or S.selected == LAUNCHERS then
            ns.db.launcherDefaults[name] = ns.DeepCopy(value)
        end
    end
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
-- Adds a widget to the refresh list; isShown (optional) decides its visibility
local function Register(w, isShown)
    w.isShown = isShown
    table.insert(widgets, w)
    return w
end

-- Help tooltip shown when hovering an option
local function AttachTip(frame, title, tip)
    -- every option built in this session (read by tools/mock_run.lua: no option may get lost)
    ns.optionsSeen = ns.optionsSeen or {}
    ns.optionsSeen[tostring(title)] = true
    if frame and not tip then
        -- every option explains itself: the mock run lists the ones that do not
        ns.optionsWithoutTip = ns.optionsWithoutTip or {}
        ns.optionsWithoutTip[tostring(title)] = true
    end
    if not frame or not tip then return end
    frame:HookScript("OnEnter", function(self)
        -- in the options window the help panel on the right explains it: no tooltip too
        if ns.ShowOptionHelp and ns:ShowOptionHelp(title, tip, self) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(tip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Small title label at the top-left of a widget holder
local function AddTitle(holder, text)
    local title = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT")
    title:SetText(text)
    return title
end

---------------------------------------------------------------------------
-- Rows (1.3): one setting = one row across the page, the label on the left, the
-- control on the right, like the game's own settings. The label wraps instead of
-- being cut (long translations, bigger text) and the row grows with it. The whole
-- row lights up under the mouse; in high contrast the light is stronger and a bar
-- marks the row (a shape, not only a color).
---------------------------------------------------------------------------
local ROW_LABEL_W = 270                       -- label, on the left
local ROW_CONTROL_X = 290                     -- control, from the row's left edge
local ROW_CONTROL_W = FULL_W - ROW_CONTROL_X  -- room for the control
local ROW_PAD = 4                             -- above and below the taller of label and control
local STEPPER_MAX = 6                         -- lists up to 6 choices get ◄ ► arrows

-- Every setting row of the window, in the order it was placed: label, tooltip,
-- page, sub-tab and section. Read by the search, the help panel and the gamepad
-- (focus order) to come, and by tools/mock_run.lua.
ns.optionRows = ns.optionRows or {}

-- Shows or hides a row (a check box follows its row: tools/mock_run.lua looks for
-- the shown ones)
local function SetRowShown(w, shown)
    w:SetShown(shown and true or false)
    if w.check then w.check:SetShown(shown and true or false) end
end

-- Accent colors of the window's style: row under the mouse, selection mark, lines under
-- section headers (and their text, when the style sets one). Styles without them keep the
-- game's white highlight and yellow.
local DEFAULT_ACCENTS = {
    hover = { 1, 1, 1, 0.1 }, lit = { 1, 0.82, 0, 1 }, line = { 1, 0.82, 0, 0.4 },
}
function ns:WindowAccents()
    local info = self.GetThemeInfo and self:GetThemeInfo(self:GetTheme())
    local w = info and info.window and info.window()
    local a = w and w.accents
    if type(a) ~= "table" then return DEFAULT_ACCENTS end
    return {
        hover = a.hover or DEFAULT_ACCENTS.hover, lit = a.lit or DEFAULT_ACCENTS.lit,
        line = a.line or DEFAULT_ACCENTS.line, text = a.text,
    }
end

-- Header lines (and texts) drawn in the accent colors, recolored when the style changes
local accentLines = {}
local function PaintAccent(line, fs)
    local a = ns:WindowAccents()
    line:SetColorTexture(unpack(a.line))
    if fs then
        if a.text then fs:SetTextColor(unpack(a.text)) else fs:SetTextColor(1, 0.82, 0) end
    end
end
local function AccentLine(line, fs)
    table.insert(accentLines, { line = line, fs = fs })
    PaintAccent(line, fs)
end
function ns:RepaintAccents()
    for _, e in ipairs(accentLines) do PaintAccent(e.line, e.fs) end
end

local function NewRow(parent, frameType)
    local row = CreateFrame(frameType or "Frame", nil, parent)
    row:SetSize(FULL_W, 28)
    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetPoint("TOPLEFT", -6, 0)
    row.hover:SetPoint("BOTTOMRIGHT", 4, 0)
    row.hover:SetColorTexture(1, 1, 1, 0.1)
    row.hover:Hide()
    -- high contrast: a bar on the left of the row under the mouse
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetPoint("TOPLEFT", -6, 0)
    row.mark:SetPoint("BOTTOMLEFT", -6, 0)
    row.mark:SetWidth(3)
    row.mark:SetColorTexture(1, 0.82, 0, 1)
    row.mark:Hide()
    return row
end

-- The row lights up while the mouse is over it or over one of its controls
local function RowHover(row, ...)
    local function Enter()
        local strong = ns.sv and ns.sv.highContrast
        local a = ns:WindowAccents()
        row.hover:SetColorTexture(unpack(a.hover))
        row.mark:SetColorTexture(unpack(a.lit))
        row.hover:SetAlpha(strong and 2.5 or 1)
        row.hover:Show()
        row.mark:SetShown(strong and true or false)
    end
    local function Leave()
        if row:IsMouseOver() then return end -- moved onto one of its controls
        row.hover:Hide()
        row.mark:Hide()
    end
    row:EnableMouse(true)
    for _, f in ipairs({ row, ... }) do
        f:HookScript("OnEnter", Enter)
        f:HookScript("OnLeave", Leave)
    end
end

-- Label on the left of a row; owner (default: the row) makes the font string
local function RowLabel(row, text, owner)
    local fs = (owner or row):CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", row, "LEFT", 0, 0)
    fs:SetWidth(ROW_LABEL_W)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    fs:SetText(text)
    row.label = fs
    return fs
end

-- Row height: the taller of its label and its control, plus some air
local function FitRow(row, controlHeight)
    local h = math.max(controlHeight, row.label and row.label:GetStringHeight() or 0) + ROW_PAD
    row:SetHeight(h)
    row.layoutHeight = h
end

-- Marks a widget as a setting row (see ns.optionRows; filled in by Place)
local function AsSetting(w, label, tip, kind)
    w.optionLabel, w.optionTip, w.optionKind = label, tip, kind
    return w
end

-- Section header: gold text with a thin line underneath
local function CreateHeader(parent, text)
    local holder = CreateFrame("Frame", nil, parent)
    local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("BOTTOMLEFT", 0, 5)
    fs:SetText(text)
    -- room above the text: sections stand apart (more with bigger text)
    local h = math.max(30, (fs:GetStringHeight() or 0) + 16)
    holder:SetSize(FULL_W, h)
    local line = holder:CreateTexture(nil, "ARTWORK")
    AccentLine(line, fs)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    holder.Refresh = function() end
    holder.layoutHeight = h + 4
    holder.isHeader, holder.headerText = true, text
    return Register(holder)
end

-- Section that folds: a header with a + / - button (a shape, not only a color).
-- The rows placed under it, up to the next section of the same column (plain headers
-- inside it fold with it), hide when it is folded and the rows below move up (see
-- NewLayout). Not saved: every section opens folded or not as its page decides.
local function CreateSection(parent, text, folded)
    local b = CreateFrame("Button", nil, parent)
    local sign = b:CreateTexture(nil, "ARTWORK")
    sign:SetSize(16, 16)
    sign:SetPoint("BOTTOMLEFT", 0, 5)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", sign, "RIGHT", 6, 0)
    fs:SetText(text)
    local h = math.max(30, (fs:GetStringHeight() or 0) + 16) -- (bigger text: taller)
    b:SetSize(FULL_W, h)
    local line = b:CreateTexture(nil, "ARTWORK")
    AccentLine(line, fs)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    b.hover = b:CreateTexture(nil, "BACKGROUND")
    b.hover:SetAllPoints()
    b.hover:SetColorTexture(1, 1, 1, 0.08)
    b.hover:Hide()
    b:SetScript("OnEnter", function(self)
        local c = ns:WindowAccents().hover
        self.hover:SetColorTexture(c[1], c[2], c[3], (c[4] or 0.1) * 0.8)
        self.hover:Show()
    end)
    b:SetScript("OnLeave", function(self) self.hover:Hide() end)
    b.folded = folded and true or false
    b.Refresh = function(self)
        sign:SetTexture(self.folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    end
    -- what "confirm" does (mouse, keyboard or gamepad)
    b.Activate = function(self)
        self.folded = not self.folded
        ns:RefreshOptions()
    end
    b:SetScript("OnClick", function(self) self:Activate() end)
    b:Refresh()
    b.layoutHeight = h + 4
    b.isHeader, b.isSection, b.headerText = true, true, text
    return Register(b)
end

-- Multi-line help text (default width: the whole page)
local function CreateNote(parent, text, width)
    local holder = CreateFrame("Frame", nil, parent)
    local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT")
    fs:SetWidth(width or FULL_W)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    holder.fs = fs
    holder:SetSize(width or FULL_W, math.max(14, fs:GetStringHeight()))
    holder.Refresh = function() end
    holder.layoutHeight = holder:GetHeight() + 8
    return Register(holder)
end

-- Check box bound to a getter/setter pair: the game's own check box on the right,
-- the label on the left; a click anywhere on the row ticks it
local function CreateCheck(parent, label, getter, setter, isShown, tip)
    local row = NewRow(parent)
    local ok, cb = pcall(CreateFrame, "CheckButton", nil, row, "SettingsCheckboxTemplate")
    if not ok or not cb then
        cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
    end
    cb:SetPoint("LEFT", row, "LEFT", ROW_CONTROL_X, 0)
    -- the template's own hover and tooltip use the game's settings tooltip: ours instead
    cb:SetScript("OnEnter", nil)
    cb:SetScript("OnLeave", nil)
    -- (the label is made by the check box: tools/mock_run.lua finds a check box by it)
    RowLabel(row, label, cb)
    cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    row:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and cb:IsEnabled() then cb:Click() end
    end)
    AttachTip(cb, label, tip)
    AttachTip(row, label, tip)
    RowHover(row, cb)
    row.check = cb
    row.Activate = function() cb:Click() end
    row.Refresh = function() cb:SetChecked(getter() and true or false) end
    FitRow(row, 29)
    return Register(AsSetting(row, label, tip, "check"), isShown)
end

-- Slider with stepper arrows (the game's own); values are rounded to integers
-- Switch (1.3): "On screen" at the head of a block, left of its name. A title above,
-- then a track with a knob that slides (left: off, right: on) and the word Yes / No:
-- a shape and a word, not only a color. Click, Enter or the gamepad's confirm flips it.
local SWITCH_W = 150
local function CreateSwitch(parent, label, getter, setter, isShown, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SWITCH_W, 44)
    local title = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT")
    title:SetWidth(SWITCH_W)
    title:SetJustifyH("LEFT")
    title:SetText(label)
    local titleH = math.max(12, title:GetStringHeight() or 12)
    local edge = b:CreateTexture(nil, "BACKGROUND")
    edge:SetSize(48, 24)
    edge:SetPoint("TOPLEFT", 0, -(titleH + 4))
    b:SetHeight(titleH + 4 + 24 + 4)
    local track = b:CreateTexture(nil, "BORDER")
    track:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
    track:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
    local knobEdge = b:CreateTexture(nil, "ARTWORK", nil, 1)
    knobEdge:SetSize(18, 18)
    local knob = b:CreateTexture(nil, "ARTWORK", nil, 2)
    knob:SetPoint("TOPLEFT", knobEdge, "TOPLEFT", 1, -1)
    knob:SetPoint("BOTTOMRIGHT", knobEdge, "BOTTOMRIGHT", -1, 1)
    local state = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    state:SetPoint("LEFT", edge, "RIGHT", 8, 0)
    b.hover = b:CreateTexture(nil, "HIGHLIGHT")
    b.hover:SetAllPoints(edge)
    b.hover:SetColorTexture(1, 1, 1, 0.15)
    -- in the colors of the window's style: its title color (gold in most styles) for the
    -- frame and the knob when on; grey when off. High contrast: a white frame.
    b.Refresh = function(self)
        local on = getter() and true or false
        self.on = on
        local info = ns.GetThemeInfo and ns:GetThemeInfo(ns:GetTheme())
        local w = info and info.window and info.window()
        local c = w and w.title or { 1, 0.82, 0 }
        local r, g, bl = c[1] or c.r or 1, c[2] or c.g or 0.82, c[3] or c.b or 0
        if ns.sv and ns.sv.highContrast then
            edge:SetColorTexture(1, 1, 1, 1)
        else
            edge:SetColorTexture(r, g, bl, on and 1 or 0.6)
        end
        if on then
            track:SetColorTexture(r * 0.35, g * 0.35, bl * 0.35, 1)
            knob:SetColorTexture(r, g, bl, 1)
            state:SetTextColor(r, g, bl)
        else
            track:SetColorTexture(0.07, 0.07, 0.07, 1)
            knob:SetColorTexture(0.55, 0.55, 0.55, 1)
            state:SetTextColor(0.75, 0.75, 0.75)
        end
        knobEdge:SetColorTexture(0, 0, 0, 1)
        knobEdge:ClearAllPoints()
        knobEdge:SetPoint(on and "RIGHT" or "LEFT", edge, on and "RIGHT" or "LEFT", on and -3 or 3, 0)
        state:SetText(on and YES or NO)
    end
    b.Activate = function(self)
        setter(not self.on)
        ns:RefreshOptions()
    end
    b:SetScript("OnClick", function(self) self:Activate() end)
    AttachTip(b, label, tip)
    b.layoutHeight = b:GetHeight() + 4
    b:Refresh()
    return Register(AsSetting(b, label, tip, "check"), isShown)
end

local function CreateSlider(parent, label, minV, maxV, step, getter, setter, isShown, tip)
    local holder = NewRow(parent)
    RowLabel(holder, label)

    local slider = CreateFrame("Frame", nil, holder, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("LEFT", holder, "LEFT", ROW_CONTROL_X, 0)
    slider:SetWidth(ROW_CONTROL_W - 50) -- room for the value on the right
    slider:Init(getter() or minV, minV, maxV, (maxV - minV) / step, {
        [MinimalSliderWithSteppersMixin.Label.Right] = function(v)
            return tostring(math.floor(v + 0.5))
        end,
    })
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if holder.updating then return end
        setter(math.floor(value + 0.5))
    end, holder)

    AttachTip(holder, label, tip)
    if tip then AttachTip(slider.Slider, label, tip) end
    RowHover(holder, slider.Slider)
    holder.slider = slider
    -- what left / right do (keyboard or gamepad, later)
    holder.Step = function(_, dir)
        local v = (getter() or minV) + dir * step
        setter(math.max(minV, math.min(maxV, v)))
        holder:Refresh()
    end

    holder.Refresh = function(self)
        self.updating = true
        slider:SetValue(getter() or minV)
        self.updating = false
    end
    FitRow(holder, 24)
    return Register(AsSetting(holder, label, tip, "slider"), isShown)
end

-- Fills a dropdown's menu: radio entries (and titles) from options
local function SetupChoices(dd, label, options, getter, setter)
    dd:SetupMenu(function(_, root)
        -- an error here would stop the menu from opening: print it instead of swallowing it
        local ok, err = pcall(function()
            if root.SetScrollMode then root:SetScrollMode(400) end -- long lists
            local list = type(options) == "function" and options() or options
            for _, opt in ipairs(list) do
                if opt.isTitle then
                    root:CreateTitle(opt.name)
                else
                    root:CreateRadio(opt.name,
                        function(value) return getter() == value end,
                        function(value) setter(value) end,
                        opt.key)
                end
            end
        end)
        if not ok then ns.Print("|cffff5555[debug]|r menu « " .. label .. " » : " .. tostring(err)) end
    end)
end

-- Number of choices of a list (titles make it a long list: no arrows)
local function CountChoices(options)
    local ok, list = pcall(function() return type(options) == "function" and options() or options end)
    if not ok or type(list) ~= "table" or list.mayGrow then return math.huge end
    local n = 0
    for _, opt in ipairs(list) do
        if opt.isTitle then return math.huge end
        n = n + 1
    end
    return n
end

-- Single-choice list; options = list of {key, name} or a function returning it.
-- Up to STEPPER_MAX choices: the game's list with ◄ ► arrows on each side (a click on
-- the value still opens the list); longer lists: a plain dropdown. With a width, the
-- old stacked look (label above), for the block selection at the top of the Blocks tab.
local function CreateDropdown(parent, label, options, getter, setter, isShown, width, tip)
    local holder, dd
    if width then
        holder = CreateFrame("Frame", nil, parent)
        holder:SetSize(width, 44)
        local title = AddTitle(holder, label)
        dd = CreateFrame("DropdownButton", nil, holder, "WowStyle1DropdownTemplate")
        dd:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        dd:SetWidth(width - 12)
        if tip then holder:EnableMouse(true) end
        holder.layoutHeight = 50
    else
        holder = NewRow(parent)
        RowLabel(holder, label)
        local arrows
        if CountChoices(options) <= STEPPER_MAX then
            local ok, frame = pcall(CreateFrame, "Frame", nil, holder, "SettingsDropdownWithButtonsTemplate")
            if ok and frame and type(frame.Dropdown) == "table" then arrows = frame end
        end
        if arrows then
            arrows:SetSize(ROW_CONTROL_W - 10, 30)
            arrows:SetPoint("LEFT", holder, "LEFT", ROW_CONTROL_X, 0)
            if arrows.Label then arrows.Label:Hide() end -- our label is on the left
            dd = arrows.Dropdown
            dd:SetWidth(ROW_CONTROL_W - 70)
            holder.arrows = arrows
            holder.Step = function(_, dir)
                if dir > 0 then arrows:Increment() else arrows:Decrement() end
            end
            RowHover(holder, dd, arrows.IncrementButton, arrows.DecrementButton)
        else
            dd = CreateFrame("DropdownButton", nil, holder, "WowStyle1DropdownTemplate")
            dd:SetPoint("LEFT", holder, "LEFT", ROW_CONTROL_X, 0)
            dd:SetWidth(ROW_CONTROL_W - 10)
            RowHover(holder, dd)
        end
        FitRow(holder, 30)
    end
    SetupChoices(dd, label, options, getter, setter)
    AttachTip(holder, label, tip)
    if tip then AttachTip(dd, label, tip) end
    holder.dropdown = dd
    holder.Activate = function() if dd.OpenMenu then dd:OpenMenu() end end

    holder.Refresh = function() dd:GenerateMenu() end
    return Register(AsSetting(holder, label, tip, "dropdown"), isShown)
end

-- Action list (each entry is a button)
local function CreateActionDropdown(parent, label, buildEntries, emptyText, tip)
    local holder = NewRow(parent)
    RowLabel(holder, label)

    local dd = CreateFrame("DropdownButton", nil, holder, "WowStyle1DropdownTemplate")
    dd:SetPoint("LEFT", holder, "LEFT", ROW_CONTROL_X, 0)
    dd:SetWidth(ROW_CONTROL_W - 10)
    if dd.SetDefaultText then dd:SetDefaultText(L.CHOOSE) end
    dd:SetupMenu(function(_, root)
        if root.SetScrollMode then root:SetScrollMode(400) end
        local entries = buildEntries()
        if #entries == 0 then
            root:CreateTitle(emptyText)
            return
        end
        for _, e in ipairs(entries) do
            root:CreateButton(e.name, e.func)
        end
    end)

    AttachTip(holder, label, tip)
    if tip then AttachTip(dd, label, tip) end
    RowHover(holder, dd)
    holder.dropdown = dd
    holder.Activate = function() if dd.OpenMenu then dd:OpenMenu() end end

    holder.Refresh = function() dd:GenerateMenu() end
    FitRow(holder, 30)
    return Register(AsSetting(holder, label, tip, "action"))
end

-- Color swatch opening Blizzard's color picker (Cancel restores the previous color);
-- the whole row is the button
local function CreateColor(parent, label, hasAlpha, getter, setter, isShown, tip)
    local b = NewRow(parent, "Button")

    local edge = b:CreateTexture(nil, "BORDER")
    edge:SetSize(20, 20)
    edge:SetPoint("LEFT", b, "LEFT", ROW_CONTROL_X + 4, 0)
    edge:SetColorTexture(1, 1, 1, 1)

    local swatch = b:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(16, 16)
    swatch:SetPoint("CENTER", edge)

    RowLabel(b, label)

    b.Refresh = function()
        local c = getter()
        if c then swatch:SetColorTexture(c.r, c.g, c.b, c.a) end
    end

    local function Set(r, g, bl, a)
        setter(r, g, bl, a)
        b:Refresh()
    end

    b:SetScript("OnClick", function()
        local c = getter()
        if not c then return end
        local prev = { r = c.r, g = c.g, b = c.b, a = c.a }
        local function OnChange()
            local r, g, bl = ColorPickerFrame:GetColorRGB()
            local a = hasAlpha and ColorPickerFrame:GetColorAlpha() or 1
            Set(r, g, bl, a)
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b,
            opacity = c.a,
            hasOpacity = hasAlpha,
            swatchFunc = OnChange,
            opacityFunc = OnChange,
            cancelFunc = function() Set(prev.r, prev.g, prev.b, prev.a) end,
        })
    end)
    b.Activate = function(self) self:Click() end

    AttachTip(b, label, tip)
    RowHover(b)
    FitRow(b, 22)
    return Register(AsSetting(b, label, tip, "color"), isShown)
end

-- Plain push button
-- Text box (free text, or numbers only); the value is saved on Enter or when
-- the box loses focus, Escape restores the saved value
local function CreateEditBox(parent, label, getter, setter, isShown, tip, numeric)
    local holder = NewRow(parent)
    RowLabel(holder, label)
    local box = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
    box:SetSize(ROW_CONTROL_W - 20, 20)
    box:SetPoint("LEFT", holder, "LEFT", ROW_CONTROL_X + 6, 0)
    box:SetAutoFocus(false)
    if numeric then box:SetNumeric(true) end
    local cancelling = false
    local function Commit(self)
        if cancelling then return end
        setter(self:GetText())
    end
    box:SetScript("OnEnterPressed", function(self)
        Commit(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", Commit)
    box:SetScript("OnEscapePressed", function(self)
        cancelling = true -- losing focus must not save what was typed
        self:ClearFocus()
        cancelling = false
        holder:Refresh()
    end)
    holder.Refresh = function()
        if not box:HasFocus() then
            local v = getter()
            box:SetText(v ~= nil and tostring(v) or "")
        end
    end
    AttachTip(holder, label, tip)
    if tip then AttachTip(box, label, tip) end
    RowHover(holder, box)
    holder.box = box
    holder.Activate = function() box:SetFocus() end
    FitRow(holder, 22)
    return Register(AsSetting(holder, label, tip, "text"), isShown)
end

-- A button text longer than the button (translations can be long): smaller font,
-- then cut with "..." (the tooltip keeps the full text)
local function FitButtonText(b)
    local fs = b.GetFontString and b:GetFontString()
    local w = b:GetWidth()
    if not (fs and w and w > 0) then return end
    if fs:GetStringWidth() > w - 14 then
        b:SetNormalFontObject("GameFontNormalSmall")
        b:SetHighlightFontObject("GameFontHighlightSmall")
        b:SetDisabledFontObject("GameFontDisableSmall")
        fs = b:GetFontString() or fs
        fs:SetWidth(w - 10)
        if fs.SetWordWrap then fs:SetWordWrap(false) end
    end
end
ns.FitButtonText = FitButtonText

local function CreateButton(parent, text, onClick, isShown, width, tip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or COL_W, 24)
    b:SetText(text)
    FitButtonText(b)
    b:SetScript("OnClick", onClick)
    AttachTip(b, text, tip)
    b.Activate = function(self) self:Click() end
    b.Refresh = function() end
    b.layoutHeight = 30
    return Register(AsSetting(b, text, tip, "button"), isShown)
end

-- getter/setter pair for a block field of the current selection
local function Field(name)
    return function()
               local cfg = Cfg()
               return cfg and cfg[name]
           end,
           function(v) SetField(name, v) end
end

-- Same as Field, for color tables {r, g, b, a}
local function ColorField(name)
    return function()
               local cfg = Cfg()
               return cfg and cfg[name]
           end,
           function(r, g, b, a) SetField(name, { r = r, g = g, b = b, a = a }) end
end

---------------------------------------------------------------------------
-- Scrolling pages (1.3): one column of rows is taller than the window, and so is
-- any page with a bigger text. ScrollArea(holder) fills holder with a scroll frame
-- (mouse wheel, a scroll bar only when needed) and returns the frame to build the
-- page in; its height follows the page (NewLayout).
---------------------------------------------------------------------------
local SCROLL_W = 680 -- page content: rows from 40 to 680, the scroll bar on the right
local function ScrollArea(holder, bottom)
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, holder, "ScrollFrameTemplate")
    if not ok then scroll = CreateFrame("ScrollFrame", nil, holder, "UIPanelScrollFrameTemplate") end
    scroll:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -40, bottom or 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(SCROLL_W, 10)
    scroll:SetScrollChild(content)
    if ns.OptionsZoomOnShiftWheel then ns.OptionsZoomOnShiftWheel(scroll) end -- Shift + wheel: window size
    content.scroll = scroll
    content.pageIndex, content.subIndex = holder.pageIndex, holder.subIndex
    holder.content = content
    return content
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
-- Returns a layout helper for a page. The pages are still written in two columns
-- (Place(w, col)), but since 1.3 they show as ONE column of rows: column 2 follows
-- column 1, under it. Positions are kept "per column" (virtual), so the old tricks
-- still work: Gap(col, h) adds (or, if negative, removes) vertical space, two
-- widgets can share a slot, Bottom(col) gives the current virtual y. Column 2
-- hangs from an anchor that sits under column 1 and moves when column 1 grows or
-- shrinks (stacks of module options, folded sections).
local COLUMN_GAP = 10
local allLayouts = {}
local function NewLayout(page, top)
    local top0 = top or -6
    local y = { top0, top0 }
    local items = { {}, {} } -- placed widgets of each column and their virtual y
    local packed = {}        -- lowest virtual y of the option stacks of a column (BuildModuleOptions)
    local used = {}
    local section = {}       -- current section title of each column
    local foldSection = {}   -- current section that folds, in each column
    local layout = {}
    local anchor = CreateFrame("Frame", nil, page)
    anchor:SetSize(1, 1)

    -- lowest virtual y of a column: its shown widgets (two can share a slot, the one
    -- shown counts) and its option stacks; nothing shown: its top
    -- (real positions: a row's virtual y moved up by the sections folded above it)
    local function Low(col)
        local low = packed[col] or top0
        for _, it in ipairs(items[col]) do
            if not it.w.foldedAway and it.w:IsShown() then
                low = math.min(low, it.vy + (it.shift or 0) - it.w.layoutHeight - SPACING)
            end
        end
        return low
    end

    -- y of column 2's anchor; the lowest point of the page
    local function Settle()
        local ay = 0
        if used[1] then ay = Low(1) - COLUMN_GAP - top0 end
        anchor:ClearAllPoints()
        anchor:SetPoint("TOPLEFT", page, "TOPLEFT", 0, ay)
        local lowest = used[2] and (ay + Low(2)) or Low(1)
        if page.scroll then
            page:SetHeight(math.max(10, -lowest + 12))
        else
            -- lowest point reached by any page (checked by tools/mock_run.lua: must fit the window)
            ns.optionsLowestY = math.min(ns.optionsLowestY or 0, (page.layoutBase or 0) + lowest)
        end
        layout.lowest = lowest
    end

    function layout.Point(w, col, vy)
        w:ClearAllPoints()
        if col == 2 then
            w:SetPoint("TOPLEFT", anchor, "TOPLEFT", COL_X[1], vy)
        else
            w:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[1], vy)
        end
    end

    function layout.Place(w, col)
        col = col or 1
        layout.Point(w, col, y[col])
        if w.isHeader then section[col] = w.headerText end
        if w.isSection then foldSection[col] = w end
        if w.optionLabel then
            table.insert(ns.optionRows, { frame = w, label = w.optionLabel, tip = w.optionTip,
                kind = w.optionKind, page = page.pageIndex, sub = page.subIndex, section = section[col],
                content = page, block = layout.currentBlock, foldSection = foldSection[col] })
        end
        if not layout.untracked then table.insert(items[col], { w = w, vy = y[col] }) end
        -- every placed widget, settings or not (tools/mock_run.lua: nothing overlaps)
        ns.optionWidgets = ns.optionWidgets or {}
        table.insert(ns.optionWidgets, { frame = w, label = w.optionLabel or w.headerText or "note", content = page })
        used[col] = true
        y[col] = y[col] - w.layoutHeight - SPACING
        Settle()
        return w
    end
    function layout.Gap(col, h)
        y[col] = y[col] - h
        Settle()
    end
    function layout.Bottom(col) return y[col] end

    -- height hidden by folded sections above virtual y (stacks of module options)
    local foldedAbove = { {}, {} }
    function layout.FoldedAbove(col, vy)
        local h = 0
        for _, f in ipairs(foldedAbove[col]) do
            if f.vy > vy then h = h + f.h end
        end
        return h
    end
    -- lowest y (real: folded sections above counted) of the shown widgets of a column's option stacks
    function layout.SetPacked(col, low)
        packed[col] = low
        Settle()
    end

    -- after every refresh: folded sections hide their rows, the rows below move up
    function layout.Reflow()
        for col = 1, 2 do
            local list, shift, current = items[col], 0, nil
            foldedAbove[col] = {}
            for idx, it in ipairs(list) do
                local w = it.w
                it.shift = shift
                if w.isSection then
                    layout.Point(w, col, it.vy + shift)
                    current = nil
                    if w.folded and w:IsShown() then
                        -- down to the next section, or to the lowest row that would show
                        -- (rows folded by the last pass count: they are still there)
                        local nextVy
                        for j = idx + 1, #list do
                            if list[j].w.isSection then nextVy = list[j].vy break end
                        end
                        if not nextVy then
                            nextVy = math.min(packed[col] or it.vy, it.vy - w.layoutHeight - SPACING)
                            for j = idx + 1, #list do
                                local o = list[j].w
                                local would = o:IsShown() or (o.foldedAway and (not o.isShown or o.isShown()))
                                if would then nextVy = math.min(nextVy, list[j].vy - o.layoutHeight - SPACING) end
                            end
                        end
                        current = w
                        local hidden = (it.vy - w.layoutHeight - SPACING) - nextVy
                        if hidden > 0 then
                            table.insert(foldedAbove[col], { vy = it.vy, h = hidden })
                            shift = shift + hidden
                        end
                    end
                elseif current then
                    w.foldedAway = true
                    SetRowShown(w, false)
                else
                    if w.foldedAway then
                        w.foldedAway = nil
                        SetRowShown(w, not w.isShown or w.isShown())
                    end
                    layout.Point(w, col, it.vy + shift)
                end
            end
        end
        Settle()
    end
    table.insert(allLayouts, layout)
    return layout
end
-- (sections that fold are placed by the 1.3 page layout; tools/mock_run.lua tests them now)
ns.CreateOptionsSection, ns.NewOptionsLayout, ns.CreateOptionsCheck = CreateSection, NewLayout, CreateCheck
function ns.ReflowOptionLayouts()
    for _, layout in ipairs(allLayouts) do layout.Reflow() end
end

-- Shared with the files loaded after this one
Tools.AsSetting = AsSetting
Tools.AttachTip = AttachTip
Tools.ColorField = ColorField
Tools.CreateActionDropdown = CreateActionDropdown
Tools.CreateButton = CreateButton
Tools.CreateCheck = CreateCheck
Tools.CreateColor = CreateColor
Tools.CreateDropdown = CreateDropdown
Tools.CreateEditBox = CreateEditBox
Tools.CreateHeader = CreateHeader
Tools.CreateNote = CreateNote
Tools.CreateSection = CreateSection
Tools.CreateSlider = CreateSlider
Tools.CreateSwitch = CreateSwitch
Tools.Field = Field
Tools.FitButtonText = FitButtonText
Tools.FitRow = FitRow
Tools.NewLayout = NewLayout
Tools.NewRow = NewRow
Tools.ROW_CONTROL_W = ROW_CONTROL_W
Tools.ROW_CONTROL_X = ROW_CONTROL_X
Tools.ROW_LABEL_W = ROW_LABEL_W
Tools.Register = Register
Tools.RowHover = RowHover
Tools.RowLabel = RowLabel
Tools.SWITCH_W = SWITCH_W
Tools.ScrollArea = ScrollArea
Tools.SetField = SetField

