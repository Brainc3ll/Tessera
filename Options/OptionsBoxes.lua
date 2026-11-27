local _, ns = ...
local L = ns.L

-- Boxes part of the options window (1.5): every page is laid out like FlareUI's settings panel
-- (FlareUI 6.5.1 by Malkkav, MIT, Settings/Panel.lua): each section in its own box, its title on
-- the left and a Reset button on the right; two short settings share a line ("half" rows); a
-- setting that depends on another sits under it, its label indented, and greys out while the
-- other is off. Only the rows shown are placed, so a hidden row leaves no gap and a box with
-- nothing to show disappears. Tabs at the top of a page (CreateTabs) replace the sections that
-- folded in 1.3 and 1.4.
-- Shared with the other Options*.lua files through ns.OptionsTools (see Options.lua).
local Tools = ns.OptionsTools
local S = Tools.S
local ALL, AttachTip, COL_X, Cfg = Tools.ALL, Tools.AttachTip, Tools.COL_X, Tools.Cfg
local FitButtonText, FitRow, FULL_W, LAUNCHERS = Tools.FitButtonText, Tools.FitRow, Tools.FULL_W, Tools.LAUNCHERS
local OnAccents, ROW_CONTROL_W, ROW_CONTROL_X = Tools.OnAccents, Tools.ROW_CONTROL_W, Tools.ROW_CONTROL_X
local ROW_LABEL_W, SetRowShown, SPACING, Targets = Tools.ROW_LABEL_W, Tools.SetRowShown, Tools.SPACING, Tools.Targets

-- Sizes (FlareUI: SEC_X, SEC_TOP, SEC_BOTTOM, SEC_GAP = 10, 2, 10, 10; INDENT 18)
local BOX_X = 10                                    -- rows from the box's left edge
local BOX_TOP = 2                                   -- between the title and the first row
local BOX_BOTTOM = 10                               -- under the last row
local BOX_GAP = 10                                  -- between two boxes
local PAGE_TOP = -6                                 -- first box, from the top of the page
local INDENT = 18                                   -- label of a row that depends on the one above
local HALF_GAP = 20                                 -- between the two settings of a line
local INNER_W = FULL_W - BOX_X                      -- rows inside a box (630 px)
local HALF_W = math.floor((INNER_W - HALF_GAP) / 2) -- one setting of a shared line (305 px)
local BOX_LEFT = COL_X[1] - BOX_X                   -- the box, from the left of the page
local BOX_W = INNER_W + 2 * BOX_X                   -- (30 to 680: the width of a page's content)
local HALF_CHECK_X = HALF_W - 32                    -- check box of a half row
local HALF_ARROWS_W = 150                           -- a short list with ◄ ► arrows, in a half row
local GREY = 0.45                                   -- a row whose parent setting is off
local WHITE = "Interface\\Buttons\\WHITE8X8"

---------------------------------------------------------------------------
-- Reset of a box: its shown settings go back to what a new block (or a new profile) gets.
-- Block settings (w.field) take the defaults of each selected block; other settings
-- (w.resetTo) are set with their own setter, so what they do still happens.
---------------------------------------------------------------------------
local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- Defaults of a block. On "All blocks" (or "All launchers") the shared choices made there
-- are what Reset clears, so they are left out of the comparison.
-- (kept for one layout pass: every box of a refresh compares with the same defaults)
local defaultsCache = {}
local function DefaultsOf(key)
    if defaultsCache[key] then return defaultsCache[key] end
    local db = ns.db
    local d
    if S.selected ~= ALL and S.selected ~= LAUNCHERS then
        d = ns:GetBlockDefaults(key)
    else
        local group, launcher = db.groupDefaults, db.launcherDefaults
        db.groupDefaults = {}
        db.launcherDefaults = ns.DeepCopy(ns.PROFILE_DEFAULTS.launcherDefaults)
        local ok, res = pcall(ns.GetBlockDefaults, ns, key)
        db.groupDefaults, db.launcherDefaults = group, launcher
        d = ok and res or {}
    end
    defaultsCache[key] = d
    return d
end

local function ResettableRows(box)
    local list = {}
    for _, w in ipairs(box.rows) do
        -- (w.noReset: the style lock, in the Style box: Reset puts the look back, it does not unlock)
        if w:IsShown() and not w.noReset and (w.field or (w.resetTo ~= nil and w.setter)) then table.insert(list, w) end
    end
    return list
end

-- Something in the box differs from its default (the first selected block is the one shown)
local function CanReset(box)
    local cfg, def
    for _, w in ipairs(ResettableRows(box)) do
        if w.field then
            cfg = cfg or Cfg()
            if cfg then
                def = def or DefaultsOf(Targets()[1])
                if not Same(cfg[w.field], def[w.field]) then return true end
            end
        elseif w.getter and not Same(w.getter(), w.resetTo) then
            return true
        end
    end
    return false
end

local function ResetBox(box)
    defaultsCache = {}
    local rows = ResettableRows(box)
    local fields = {}
    for _, w in ipairs(rows) do
        if w.field then table.insert(fields, w.field) end
        if w.field == "border" then table.insert(fields, "borderSize") end
    end
    if #fields > 0 then
        if ns.PushUndo then ns:PushUndo(true) end -- Ctrl + Z brings the look back
        local db = ns.db
        for _, f in ipairs(fields) do
            if S.selected == ALL then db.groupDefaults[f] = nil end
            if S.selected == ALL or S.selected == LAUNCHERS then
                db.launcherDefaults[f] = ns.DeepCopy(ns.PROFILE_DEFAULTS.launcherDefaults[f])
            end
        end
        for _, key in ipairs(Tools.WriteTargets()) do -- a locked block is left as it is on a page with several blocks
            local cfg = db.blocks[key]
            if cfg then
                local def = ns:GetBlockDefaults(key)
                for _, f in ipairs(fields) do cfg[f] = ns.DeepCopy(def[f]) end
                -- the progress bar comes back with who turned it on (the style or the block)
                if def.progressBar ~= nil and cfg.progressBar == def.progressBar then cfg.progressByStyle = def.progressByStyle end
                ns:ApplyStyle(key)
            end
        end
        if ns.UpdateAllVisibility then ns:UpdateAllVisibility() end
        if ns.UpdatePublishing then ns:UpdatePublishing() end
        if ns.RequestLayout then ns:RequestLayout() end
    end
    for _, w in ipairs(rows) do
        if not w.field then w.setter(ns.DeepCopy(w.resetTo)) end
    end
    ns:RefreshOptions()
end

-- asks first: a box can hold many settings
ns.OnLanguage(function()
    ns.Dialogs["TESSERA_RESET_BOX"] = {
        text = L.RESET_BOX_CONFIRM,
        button1 = YES,
        button2 = NO,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(_, box) if box then ResetBox(box) end end,
    }
end)
ns.ResetOptionsBox = ResetBox -- (tools/mock_run.lua)
ns.CanResetOptionsBox = CanReset

---------------------------------------------------------------------------
-- Rows: a half row, an indented one, a full one
---------------------------------------------------------------------------
-- What a row can do in half a line: a check box, a short list with arrows, a button
local function HalfLabelW(w)
    if w.check then return HALF_CHECK_X - 8 end
    if w.arrows then return HALF_W - HALF_ARROWS_W - 8 end
end

-- A half row whose label would take more than two lines (long translations, bigger
-- text) takes the whole line
local function HalfFits(w)
    if not w.half then return false end
    if w.optionKind == "button" and not w.label then return true end
    local labelW = HalfLabelW(w)
    if not (labelW and w.label) then return false end
    local fs = w.label
    local width = (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth() or 0
    return width <= 2 * (labelW - (w.indented and INDENT or 0))
end

-- Sizes a row for a half or a whole line; indented: its label moves right
local function Shape(w, half, indented)
    if w.optionKind == "button" and not w.label then
        w.fullW = w.fullW or w:GetWidth()
        w:SetWidth(half and HALF_W or w.fullW)
        FitButtonText(w)
        return
    end
    if w.fs and not w.optionLabel then -- a note: as wide as the box, as tall as its text
        w.fs:SetWidth(INNER_W)
        local h = math.max(14, w.fs:GetStringHeight() or 14, w.minNoteH or 0)
        w:SetSize(INNER_W, h)
        w.layoutHeight = h + 8
        return
    end
    w:SetWidth(half and HALF_W or INNER_W)
    local x = indented and INDENT or 0
    if w.label and not w.fixedLabel then
        w.label:ClearAllPoints()
        w.label:SetPoint("LEFT", w, "LEFT", x, 0)
    end
    if w.check then
        w.check:ClearAllPoints()
        w.check:SetPoint("LEFT", w, "LEFT", half and HALF_CHECK_X or ROW_CONTROL_X, 0)
        w.label:SetWidth((half and HALF_CHECK_X - 8 or ROW_LABEL_W) - x)
    elseif w.arrows then
        w.arrows:ClearAllPoints()
        if half then
            w.arrows:SetSize(HALF_ARROWS_W, 30)
            w.arrows:SetPoint("LEFT", w, "LEFT", HALF_W - HALF_ARROWS_W, 0)
            w.dropdown:SetWidth(HALF_ARROWS_W - 60)
            w.label:SetWidth(HALF_W - HALF_ARROWS_W - 8 - x)
        else
            w.arrows:SetSize(ROW_CONTROL_W - 10, 30)
            w.arrows:SetPoint("LEFT", w, "LEFT", ROW_CONTROL_X, 0)
            w.dropdown:SetWidth(ROW_CONTROL_W - 70)
            w.label:SetWidth(ROW_LABEL_W - x)
        end
    elseif w.label and not w.fixedLabel then
        w.label:SetWidth((w.labelW or ROW_LABEL_W) - x)
    end
    if w.controlH then FitRow(w, w.controlH) end
end

-- A row whose parent setting is off: greyed, its control does nothing (a shape: the
-- label is indented too, so it is not only a color)
local function SetRowEnabled(w, on)
    if w.enabledByParent == on then return end
    w.enabledByParent = on
    w:SetAlpha(on and 1 or GREY)
    for _, c in ipairs({ w.check, w.dropdown, w.box, w.slider }) do
        if c and c.SetEnabled then c:SetEnabled(on) end
    end
    if w.arrows then
        for _, b in ipairs({ w.arrows.IncrementButton, w.arrows.DecrementButton }) do
            if b and b.SetEnabled then b:SetEnabled(on) end
        end
        if on and w.dropdown and w.dropdown.GenerateMenu then w.dropdown:GenerateMenu() end
    end
    if w:GetObjectType() == "Button" and w.SetEnabled then w:SetEnabled(on) end
    if not w.activateIfOn and w.Activate then
        local activate = w.Activate
        w.activateIfOn = true
        w.Activate = function(...) if w.enabledByParent ~= false then return activate(...) end end
    end
end

---------------------------------------------------------------------------
-- Boxes and the page that holds them
---------------------------------------------------------------------------
local function PaintBox(box)
    local a = ns:WindowAccents()
    if box.frame.SetBackdropColor and not box.stone then
        box.frame:SetBackdropColor(0, 0, 0, ns.sv and ns.sv.highContrast and 0.45 or 0.25)
        local l = a.line
        box.frame:SetBackdropBorderColor(l[1], l[2], l[3], math.min(1, (l[4] or 0.4) + 0.2))
    end
    if box.title then
        if a.text then box.titleFS:SetTextColor(unpack(a.text)) else box.titleFS:SetTextColor(1, 0.82, 0) end
    end
end

-- The Reset button of a box: gold text, white under the mouse, grey when nothing differs
local function PaintReset(b)
    local a = ns:WindowAccents()
    if not b:IsEnabled() then b.label:SetTextColor(0.5, 0.48, 0.42)
    elseif b.hovered then b.label:SetTextColor(1, 1, 1)
    else b.label:SetTextColor(unpack(a.text or { 1, 0.82, 0 })) end
end

local function NewBox(flow, title, opts)
    opts = opts or {}
    local content = flow.content
    local box = { flow = flow, content = content, title = title, rows = {}, isShown = opts.isShown }
    box.frame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    box.frame:SetFrameLevel(math.max(0, content:GetFrameLevel() or 0)) -- under its rows
    -- 2.0: a rounded box with the tooltip border, in the style's colors (OptionsSkin.lua)
    if ns.Skin and box.frame.SetBackdrop then
        ns.Skin.Box(box.frame)
        box.stone = true
    elseif box.frame.SetBackdrop then
        box.frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    end
    box.framed = title ~= nil
    if title then
        local head = CreateFrame("Frame", nil, content)
        head:SetSize(INNER_W, 22)
        local fs = head:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") -- 2.0: bigger titles
        fs:SetPoint("TOPLEFT", head, "TOPLEFT", 0, -7)
        fs:SetJustifyH("LEFT")
        if fs.SetWordWrap then fs:SetWordWrap(true) end
        fs:SetText(title)
        box.titleFS, box.head = fs, head
        head.isHeader, head.headerText = true, title
        if opts.reset then
            local b = CreateFrame("Button", nil, head)
            b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.label:SetPoint("RIGHT")
            b.label:SetText(L.RESET_BOX)
            b:SetSize(math.ceil(b.label:GetStringWidth() or 40) + 8, 18)
            b:SetPoint("TOPRIGHT", head, "TOPRIGHT", 0, -6)
            if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
            b:SetScript("OnEnter", function(self) self.hovered = true PaintReset(self) end)
            b:SetScript("OnLeave", function(self) self.hovered = nil PaintReset(self) end)
            b:SetScript("OnClick", function() ns:ShowDialog("TESSERA_RESET_BOX", title, nil, box) end)
            b.Activate = function(self) if self:IsEnabled() then self:Click() end end
            AttachTip(b, L.RESET_BOX, L.TIP_RESET_BOX)
            box.reset = b
            fs:SetWidth(INNER_W - b:GetWidth() - 8)
        else
            fs:SetWidth(INNER_W)
        end
        -- (tools/mock_run.lua: the title takes its place among the rows, nothing overlaps it)
        ns.optionWidgets = ns.optionWidgets or {}
        table.insert(ns.optionWidgets, { frame = head, label = title, content = content, box = box })
    end
    OnAccents(function() PaintBox(box) end)
    -- adds a row (opts: half = shares a line, parent = function: on when the setting above is
    -- on, field = the block field it edits, default = its value after Reset)
    function box.Add(w, o)
        o = o or {}
        if o.half then w.half = true end
        if o.parent then w.parentOn, w.indented = o.parent, not o.half end
        if o.field then w.field = o.field end
        if o.default ~= nil then w.resetTo = o.default end
        table.insert(box.rows, w)
        w.ownerBox = box
        if w.optionLabel then
            table.insert(ns.optionRows, { frame = w, label = w.optionLabel, tip = w.optionTip,
                kind = w.optionKind, page = content.pageIndex, sub = content.subIndex, tabName = content.tabName,
                section = title, box = box, content = content, block = flow.currentBlock })
        end
        ns.optionWidgets = ns.optionWidgets or {}
        table.insert(ns.optionWidgets, { frame = w, label = w.optionLabel or "note", content = content, box = box })
        return w
    end
    return box
end

-- Height of a box title (it wraps: long translations, bigger text)
local function FitHead(box)
    local h = math.max(26, (box.titleFS:GetStringHeight() or 14) + 12)
    box.head:SetHeight(h)
    return h
end

local allFlows = {}
-- A page laid out in boxes: content is the frame the page is built in (ScrollArea).
-- flow.Box(title, opts) starts a box (opts.reset: a Reset button; opts.isShown); a box
-- without a title has no frame (a note at the top of a page).
local function NewFlow(content)
    local flow = { content = content, boxes = {} }
    function flow.Box(title, opts)
        local box = NewBox(flow, title, opts)
        table.insert(flow.boxes, box)
        return box
    end

    -- after every refresh: places the shown rows, box by box, from the top
    function flow.Reflow()
        local y = PAGE_TOP
        for _, box in ipairs(flow.boxes) do
            local want = not box.isShown or box.isShown()
            local shown = {}
            for _, w in ipairs(box.rows) do
                if w.boxHidden then -- the box hid it: back to what it decides itself
                    w.boxHidden = nil
                    SetRowShown(w, not w.isShown or w.isShown())
                end
                if w:IsShown() then
                    if want then table.insert(shown, w) else
                        w.boxHidden = true
                        SetRowShown(w, false)
                    end
                end
            end
            if #shown == 0 then
                box.frame:Hide()
                if box.head then box.head:Hide() end
                box.top = nil
            else
                local top = y
                box.top = top
                if box.head then
                    box.head:Show()
                    box.head:ClearAllPoints()
                    box.head:SetPoint("TOPLEFT", content, "TOPLEFT", COL_X[1], y)
                    y = y - FitHead(box) - BOX_TOP
                end
                local left -- a half row waiting for its neighbour: { y, h }
                for _, w in ipairs(shown) do
                    if w.parentOn then SetRowEnabled(w, w.parentOn() and true or false) end
                    local half = HalfFits(w)
                    Shape(w, half, w.indented)
                    w.halfRight = nil
                    w:ClearAllPoints()
                    local h = w.layoutHeight or 24
                    if half and left then
                        w:SetPoint("TOPLEFT", content, "TOPLEFT", COL_X[1] + HALF_W + HALF_GAP, left.y)
                        w.halfRight = true
                        y = left.y - math.max(left.h, h) - SPACING
                        left = nil
                    else
                        if left then y = left.y - left.h - SPACING end
                        left = nil
                        w:SetPoint("TOPLEFT", content, "TOPLEFT", COL_X[1], y)
                        if half then left = { y = y, h = h } else y = y - h - SPACING end
                    end
                end
                if left then y = left.y - left.h - SPACING end
                local bottom = y + SPACING - (box.framed and BOX_BOTTOM or 0)
                if box.framed then
                    box.frame:ClearAllPoints()
                    box.frame:SetPoint("TOPLEFT", content, "TOPLEFT", BOX_LEFT, top)
                    box.frame:SetSize(BOX_W, top - bottom)
                    box.frame:Show()
                else
                    box.frame:Hide()
                end
                if box.reset then
                    box.reset:SetEnabled(CanReset(box))
                    PaintReset(box.reset)
                end
                y = bottom - BOX_GAP
            end
        end
        content:SetHeight(math.max(10, -y + 6))
        flow.lowest = y
    end
    table.insert(allFlows, flow)
    return flow
end

function ns.ReflowOptionLayouts()
    defaultsCache = {}
    for _, flow in ipairs(allFlows) do flow.Reflow() end
    defaultsCache = {}
end

-- Rows of a page in the order a keyboard or a gamepad steps through them: left to right,
-- then the next line (tools/mock_run.lua checks it follows the order they were added in)
function ns.OptionsFocusOrder(content)
    local list = {}
    for _, flow in ipairs(allFlows) do
        if flow.content == content then
            for _, box in ipairs(flow.boxes) do
                for _, w in ipairs(box.rows) do
                    if w:IsShown() and w.optionLabel then table.insert(list, w) end
                end
            end
        end
    end
    return list
end

-- Scrolls a page to a box (after the next frame: positions are known then)
local function ScrollToBox(content, box)
    C_Timer.After(0, function()
        local scroll = content.scroll
        if not (scroll and scroll.SetVerticalScroll) then return end
        local y = 0
        if box and box.top then y = math.max(0, -box.top - 10) end
        local range = scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or 0
        scroll:SetVerticalScroll(math.max(0, math.min(range, y)))
    end)
end

---------------------------------------------------------------------------
-- Tabs at the top of a page (the Blocks tab: Content, Appearance, Behaviour; the DataBroker
-- tab: its two parts). The open one: white text, a light behind it and a bar under it (a
-- shape, not only a color). onSelect(i) opens tab i.
---------------------------------------------------------------------------
local function CreateTabs(parent, names, tips, onSelect)
    local bar = CreateFrame("Frame", nil, parent)
    bar.buttons = {}
    local x = 0
    for i, name in ipairs(names) do
        local b = CreateFrame("Button", nil, bar)
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.label:SetPoint("CENTER", 0, 1)
        b.label:SetText(name)
        local w = math.max(120, math.ceil(b.label:GetStringWidth() or 60) + 32)
        b:SetSize(w, 26)
        b:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
        x = x + w + 4
        b.light = b:CreateTexture(nil, "BACKGROUND")
        b.light:SetAllPoints()
        b.edge = b:CreateTexture(nil, "ARTWORK")
        b.edge:SetPoint("BOTTOMLEFT")
        b.edge:SetPoint("BOTTOMRIGHT")
        b.edge:SetHeight(3)
        local hover = b:CreateTexture(nil, "HIGHLIGHT") -- shown by the game while hovered
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.07)
        b:SetScript("OnClick", function() onSelect(i) end)
        b.Activate = function() onSelect(i) end
        if tips and tips[i] then AttachTip(b, name, tips[i]) end
        bar.buttons[i] = b
    end
    bar.line = bar:CreateTexture(nil, "ARTWORK")
    bar.line:SetHeight(1)
    bar.line:SetPoint("BOTTOMLEFT")
    bar:SetSize(FULL_W, 28)
    bar.line:SetWidth(FULL_W)
    local function Paint()
        local a = ns:WindowAccents()
        bar.line:SetColorTexture(unpack(a.line))
        for i, b in ipairs(bar.buttons) do
            local on = bar.selected == i
            b.light:SetColorTexture(a.lit[1], a.lit[2], a.lit[3], on and 0.18 or 0.04)
            b.edge:SetColorTexture(unpack(a.lit))
            b.edge:SetShown(on)
            local c = on and a.text or a.ink
            if c then b.label:SetTextColor(c[1], c[2], c[3]) else b.label:SetTextColor(on and 1 or 0.88, on and 1 or 0.84, on and 1 or 0.75) end
        end
    end
    function bar.Select(i)
        bar.selected = i
        Paint()
    end
    -- the next or previous tab (keyboard or gamepad, later)
    function bar.Step(dir)
        local n = #bar.buttons
        onSelect(((bar.selected or 1) - 1 + dir) % n + 1)
    end
    OnAccents(Paint)
    return bar
end

-- Shared with the files loaded after this one
Tools.BOX_INNER_W = INNER_W
Tools.CreateTabs = CreateTabs
Tools.NewFlow = NewFlow
Tools.ScrollToBox = ScrollToBox
