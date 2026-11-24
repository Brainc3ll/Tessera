local _, ns = ...
local L = ns.L

-- "See all" window of the Blocks tab (1.8): every block in one window, a green dot on the
-- ones on your screen, a search box. A click selects the block and closes the window.
-- The entries come from the selection list (SelectionOptions, OptionsBlocks.lua).
local Tools = ns.OptionsTools
local S = Tools.S
local SortKey = ns.SortKey

local WINDOW_W, WINDOW_H, PAD = 660, 480, 18
local ROW_H, GAP, MIN_BUTTON_W = 26, 6, 150
local picker

-- How many blocks are on screen, out of how many (groups and "All ..." entries do not count)
function Tools.CountBlocks()
    local shown, total = 0, 0
    for _, entry in ipairs(Tools.SelectionOptions()) do
        if entry.block then
            total = total + 1
            if entry.shown then shown = shown + 1 end
        end
    end
    return shown, total
end

-- The rows to draw for a search text: titles and entries, a title only when an entry follows it
local function Rows(query)
    local rows, title = {}, nil
    for _, entry in ipairs(Tools.SelectionOptions()) do
        if entry.isTitle then
            title = entry
        elseif query == "" or SortKey(entry.plain or ""):find(query, 1, true) then
            if title then
                rows[#rows + 1] = title
                title = nil
            end
            rows[#rows + 1] = entry
        end
    end
    return rows
end

local function NewButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(ROW_H)
    b.selected = b:CreateTexture(nil, "BACKGROUND")
    b.selected:SetAllPoints()
    b.selected:SetColorTexture(0.2, 0.5, 0.9, 0.25)
    b.hover = b:CreateTexture(nil, "HIGHLIGHT")
    b.hover:SetAllPoints()
    b.hover:SetColorTexture(1, 1, 1, 0.12)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("LEFT", 6, 0)
    b.text:SetPoint("RIGHT", -4, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b:SetScript("OnClick", function(self)
        S.selected = self.entryKey
        picker:Hide()
        ns:RefreshOptions()
    end)
    return b
end

local function Refresh()
    local rows = Rows(SortKey(picker.search:GetText() or ""))
    -- the buttons are as wide as the longest name, so a bigger text still fits (fewer columns)
    local widest = MIN_BUTTON_W
    for _, row in ipairs(rows) do
        if not row.isTitle then
            picker.measure:SetText(row.name)
            widest = math.max(widest, math.ceil(picker.measure:GetStringWidth() or 0) + 24)
        end
    end
    local usable = WINDOW_W - PAD - 34 - PAD
    local columns = math.max(1, math.floor((usable + GAP) / (widest + GAP)))
    local buttonW = math.floor((usable - GAP * (columns - 1)) / columns)
    local nButtons, nTitles, y, col = 0, 0, 0, 0
    picker.firstKey = nil
    for _, row in ipairs(rows) do
        if row.isTitle then
            if col > 0 then y = y + ROW_H + GAP end
            col = 0
            nTitles = nTitles + 1
            local t = picker.titles[nTitles]
            if not t then
                t = picker.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                picker.titles[nTitles] = t
            end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", picker.content, "TOPLEFT", 2, -y - 4)
            t:SetText(row.name)
            t:Show()
            y = y + ROW_H
        else
            nButtons = nButtons + 1
            local b = picker.buttons[nButtons]
            if not b then
                b = NewButton(picker.content)
                picker.buttons[nButtons] = b
            end
            b.entryKey = row.key
            picker.firstKey = picker.firstKey or row.key
            b:SetWidth(buttonW)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", picker.content, "TOPLEFT", col * (buttonW + GAP), -y)
            b.text:SetText(row.name)
            b.selected:SetShown(row.key == S.selected)
            b:Show()
            col = col + 1
            if col >= columns then
                col = 0
                y = y + ROW_H + GAP
            end
        end
    end
    if col > 0 then y = y + ROW_H end
    for i = nButtons + 1, #picker.buttons do picker.buttons[i]:Hide() end
    for i = nTitles + 1, #picker.titles do picker.titles[i]:Hide() end
    picker.empty:SetShown(#rows == 0)
    picker.content:SetSize(usable, math.max(y, 1))
end

local function Build()
    local f = CreateFrame("Frame", "TesseraBlockPicker", UIParent, "BackdropTemplate")
    picker = f
    f:SetSize(WINDOW_W, WINDOW_H)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    table.insert(UISpecialFrames, "TesseraBlockPicker")
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", PAD, -14)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    f.search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.search:SetSize(240, 22)
    f.search:SetPoint("TOPLEFT", PAD + 6, -42)
    f.search:SetAutoFocus(false)
    f.search:SetScript("OnTextChanged", function() if f:IsShown() then Refresh() end end)
    f.search:SetScript("OnEscapePressed", function() f:Hide() end)
    -- Enter picks the first block found: a block in two keystrokes, without a mouse
    f.search:SetScript("OnEnterPressed", function()
        if f.firstKey then
            S.selected = f.firstKey
            f:Hide()
            ns:RefreshOptions()
        end
    end)
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.hint:SetPoint("LEFT", f.search, "RIGHT", 10, 0)
    f.measure = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.measure:Hide()
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, f, "ScrollFrameTemplate")
    if not ok then scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate") end
    scroll:SetPoint("TOPLEFT", PAD, -76)
    scroll:SetPoint("BOTTOMRIGHT", -34, PAD)
    f.content = CreateFrame("Frame", nil, scroll)
    f.content:SetSize(WINDOW_W - PAD - 34 - PAD, 10)
    scroll:SetScrollChild(f.content)
    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.empty:SetPoint("TOPLEFT", PAD + 4, -86)
    f.buttons, f.titles = {}, {}
    f:SetScript("OnShow", function()
        f.search:SetText("")
        f.search:SetFocus()
        Refresh()
    end)
    f:Hide() -- a new frame is shown: the window opens through ns:ShowBlockPicker
end

-- Opens the window (a second call closes it)
function ns:ShowBlockPicker()
    if not picker then Build() end
    if picker:IsShown() then
        picker:Hide()
        return
    end
    ns:SkinWindow(picker, picker.title)
    picker.title:SetText(L.BLOCK_PICKER_TITLE)
    picker.hint:SetText(L.BLOCK_PICKER_SEARCH)
    picker.empty:SetText(L.BLOCK_PICKER_NONE)
    picker:Show()
end
function ns.BlockPicker() return picker end -- (tools/mock_run.lua)
