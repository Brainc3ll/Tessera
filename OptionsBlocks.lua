local _, ns = ...
local L = ns.L

-- Blocks part of the options window: the Blocks tab: selection options, the options of every block, style targets.
-- Shared with the other Options*.lua files through ns.OptionsTools (see Options.lua).
local Tools = ns.OptionsTools
local S = Tools.S
local ALL, AsSetting, AttachTip, COL_W = Tools.ALL, Tools.AsSetting, Tools.AttachTip, Tools.COL_W
local COL_X, Cfg, ColorField, CreateButton = Tools.COL_X, Tools.Cfg, Tools.ColorField, Tools.CreateButton
local CreateCheck, CreateColor, CreateDropdown, CreateEditBox = Tools.CreateCheck, Tools.CreateColor, Tools.CreateDropdown, Tools.CreateEditBox
local CreateHeader, CreateNote, CreateSection, CreateSlider = Tools.CreateHeader, Tools.CreateNote, Tools.CreateSection, Tools.CreateSlider
local CreateSwitch, FULL_W, Field, FitButtonText = Tools.CreateSwitch, Tools.FULL_W, Tools.Field, Tools.FitButtonText
local FitRow, GROUP_PREFIX, GroupHead, IsGroup = Tools.FitRow, Tools.GROUP_PREFIX, Tools.GroupHead, Tools.IsGroup
local LAUNCHERS, LauncherKeys, NewLayout, NewRow = Tools.LAUNCHERS, Tools.LauncherKeys, Tools.NewLayout, Tools.NewRow
local PAGE_LOOK, ROW_CONTROL_W, ROW_CONTROL_X, ROW_LABEL_W = Tools.PAGE_LOOK, Tools.ROW_CONTROL_W, Tools.ROW_CONTROL_X, Tools.ROW_LABEL_W
local Register, RowHover, RowLabel, SPACING = Tools.Register, Tools.RowHover, Tools.RowLabel, Tools.SPACING
local SWITCH_W, ScrollArea, SetField, widgets = Tools.SWITCH_W, Tools.ScrollArea, Tools.SetField, Tools.widgets


---------------------------------------------------------------------------
-- "Blocks" tab
---------------------------------------------------------------------------
-- Entries of the selection dropdown: groups first, then data blocks, then launchers
-- Sort key for names: lower case without accents, so "Écran" sorts with the E's
local SortKey = ns.SortKey

local function SelectionOptions()
    local list = { { key = ALL, name = L.ALL_BLOCKS } }
    if #LauncherKeys() > 0 then
        table.insert(list, { key = LAUNCHERS, name = L.ALL_LAUNCHERS })
    end
    -- groups (a bar and its rows), named after their first block that is not a spacer;
    -- a green dot when one of their blocks is shown
    local groups = {}
    for _, g in ipairs(ns:ListStyleGroups()) do
        local first, shown = nil, false
        for _, key in ipairs(g.keys) do
            if not first and not ns.IsSpacerKey(key) then first = key end
            if ns.db.blocks[key].enabled then shown = true end
        end
        table.insert(groups, { key = GROUP_PREFIX .. g.head, label = ns:GetBlockName(first), shown = shown })
    end
    if #groups > 0 then
        table.sort(groups, function(a, b) return SortKey(a.label) < SortKey(b.label) end)
        table.insert(list, { isTitle = true, name = L.GROUPS_TITLE })
        for _, g in ipairs(groups) do
            local name = L.GROUP_ENTRY:format(g.label)
            if g.shown then
                name = "|TInterface\\COMMON\\Indicator-Green:14:14|t " .. name
            else
                name = "|cff8c8c8c" .. name .. "|r"
            end
            table.insert(list, { key = g.key, name = name })
        end
    end
    -- then every block in two parts (1.3): those on the screen (a green dot), then those
    -- available (greyed). In each part: data blocks in alphabetical order of their
    -- (translated) name, then launchers, DataBroker blocks and spacers, as GetBlockKeys sorts them
    local keys, data = {}, {}
    for _, key in ipairs(ns:GetBlockKeys()) do
        if ns.IsForwardingKey(key) or ns.IsSpacerKey(key) then
            table.insert(keys, key)
        else
            table.insert(data, key)
        end
    end
    table.sort(data, function(a, b) return SortKey(ns:GetBlockName(a)) < SortKey(ns:GetBlockName(b)) end)
    for i = #data, 1, -1 do table.insert(keys, 1, data[i]) end
    for part = 1, 2 do
        local on = part == 1
        local titled = false
        for _, key in ipairs(keys) do
            local cfg = ns.db.blocks[key]
            if (cfg and cfg.enabled and true or false) == on then
                if not titled then
                    titled = true
                    table.insert(list, { isTitle = true, name = on and L.ENABLED or L.AVAILABLE_BLOCKS })
                end
                local name = ns:GetBlockName(key)
                if on then
                    name = "|TInterface\\COMMON\\Indicator-Green:14:14|t " .. name
                else
                    name = "|cff8c8c8c" .. name .. "|r"
                end
                table.insert(list, { key = key, name = name })
            end
        end
    end
    return list
end

-- Module key of the selection ("spacer" for every spacer), nil for a group, a
-- launcher or a DataBroker block (they have no module options)
local function SelectedModuleKey()
    if IsGroup() then return nil end
    if ns.IsSpacerKey(S.selected) then return "spacer" end
    if ns.IsForwardingKey(S.selected) then return nil end
    return S.selected
end

-- Functions that pack the module option stacks (see BuildModuleOptions)
local relayouts = {}
function ns.RelayoutBlockOptions()
    for _, f in ipairs(relayouts) do f() end
end

-- Builds every module's own options (Modules.lua "options", hide when empty,
-- thresholds) in column col of a page, all stacked from the same top: only the
-- selected block's are visible. Used by the Behaviour sub-tab and the DataBroker
-- tab. condition (optional) must also be true for them to show. Returns the set of
-- module keys that have options.
-- filter(opt) picks the options of this page: by default those of the Behaviour tab
-- (options marked tab = "text", how the value is shown, are in the Text tab)
local function BuildModuleOptions(sub, P, col, keys, condition, filter)
    filter = filter or function(opt) return opt.tab ~= "text" end
    -- two stacks in one column of one page draw over each other: the mock run refuses it
    ns.optionStacks = ns.optionStacks or {}
    local slot = tostring(sub) .. col
    ns.optionStacks[slot] = (ns.optionStacks[slot] or 0) + 1
    local function ModuleOf(key)
        return key == "spacer" and ns.spacerModule or ns.modules[key]
    end
    local stackTop = P.Bottom(col)
    local stacks = {}
    local hasOptions = {}
    for _, key in ipairs(keys) do
        local mod = ModuleOf(key)
        local list = {}
        for _, opt in ipairs(mod.options or {}) do
            if filter(opt) then table.insert(list, opt) end
        end
        if mod.isEmpty and filter({}) then
            table.insert(list, { kind = "check", field = "hideEmpty", label = "HIDE_EMPTY", tip = "TIP_HIDE_EMPTY",
                after = function() ns:UpdateAllVisibility() end })
        end
        if mod.thresholds and filter({}) then
            local t = mod.thresholds
            local tip = t.low and "TIP_THRESHOLD_LOW" or "TIP_THRESHOLD_HIGH"
            table.insert(list, { kind = "slider", field = "warnAt", label = "THRESHOLD_WARN", tip = tip,
                min = t.min, max = t.max, step = t.step, default = t.warn })
            table.insert(list, { kind = "slider", field = "badAt", label = "THRESHOLD_BAD", tip = tip,
                min = t.min, max = t.max, step = t.step, default = t.bad })
        end
        if #list > 0 then hasOptions[key] = true end
        local firstWidget = #widgets + 1
        P.currentBlock = key -- (search: a setting of this block opens it)
        P.untracked = true -- stacked widgets: measured when packed (relayout below)
        for _, opt in ipairs(list) do
            local shown = function()
                if SelectedModuleKey() ~= key then return false end
                if condition and not condition() then return false end
                local cfg = Cfg()
                return not opt.shown or (cfg and opt.shown(cfg)) or false
            end
            local get, set = Field(opt.field)
            local label, tip = L[opt.label] or opt.label, L[opt.tip]
            local setter = function(v)
                set(v)
                if opt.after then opt.after() end
                if ns.UpdatePublishing then ns:UpdatePublishing() end -- shared value follows
                ns:RefreshOptions() -- an option can show or hide others (spacer mode)
            end
            if opt.kind == "check" then
                P.Place(CreateCheck(sub, label, get, setter, shown, tip), col)
            elseif opt.kind == "dropdown" then
                -- values: a list, or a function (a list that changes: the player's skills...)
                local values = function()
                    local entries = {}
                    local source = type(opt.values) == "function" and opt.values() or opt.values
                    for _, v in ipairs(source or {}) do
                        table.insert(entries, { key = v.key, name = L[v.label] or v.label })
                    end
                    return entries
                end
                P.Place(CreateDropdown(sub, label, values, get, setter, shown, nil, tip), col)
            elseif opt.kind == "slider" then
                P.Place(CreateSlider(sub, label, opt.min, opt.max, opt.step or 1,
                    function() return get() or opt.default end, setter, shown, tip), col)
            elseif opt.kind == "number" or opt.kind == "text" then
                P.Place(CreateEditBox(sub, label, get, function(v)
                    if opt.kind == "number" then
                        v = tonumber(v)
                        if not v then return end
                        if opt.min then v = math.max(opt.min, v) end
                    end
                    setter(v)
                end, shown, tip, opt.kind == "number"), col)
            elseif opt.kind == "color" then
                local getC, setC = ColorField(opt.field)
                P.Place(CreateColor(sub, label, true, getC, function(...)
                    setC(...)
                    ns:ApplyStyle(S.selected)
                end, shown, tip), col)
            end
        end
        -- remember this module's widgets: hidden ones must not leave a gap
        local stack = {}
        for w = firstWidget, #widgets do table.insert(stack, widgets[w]) end
        table.insert(stacks, stack)
        P.Gap(col, P.Bottom(col) - stackTop) -- back to the top for the next module
        P.untracked, P.currentBlock = nil, nil
    end
    -- packs the visible widgets of each stack from the top (called after every refresh);
    -- the rows under the stacks (column 2 since 1.3) follow its lowest point
    table.insert(relayouts, function()
        local shift = P.FoldedAbove(col, stackTop)
        local low = stackTop
        for _, stack in ipairs(stacks) do
            local y = stackTop
            for _, w in ipairs(stack) do
                if w:IsShown() then
                    P.Point(w, col, y + shift)
                    y = y - w.layoutHeight - SPACING
                end
            end
            low = math.min(low, y)
        end
        P.SetPacked(col, low + shift)
    end)
    return hasOptions
end


-- "Apply this style to": this block, its group, every block (1.3, an action: the style
-- is written into their settings, Ctrl + Z undoes it). For a group selection, "Its
-- group" is that group; "All blocks" and "All launchers" only offer every block.
local function CreateStyleTargets(parent, getStyle)
    local row = NewRow(parent)
    RowLabel(row, L.APPLY_STYLE_TO)
    local w = math.floor((ROW_CONTROL_W - 10 - 2 * 6) / 3)
    local function Keys(target)
        if target == "all" then return ns:GetBlockKeys() end
        if target == "group" then
            local head = GroupHead()
            return ns:GetStyleGroup(head or S.selected)
        end
        return { S.selected }
    end
    local function Apply(target)
        if ns:ApplyThemeToBlocks(Keys(target), getStyle()) then
            local note = ns:GetThemeNote(getStyle())
            if note then ns.Print(note) end
        end
        ns:RefreshOptions()
    end
    local function Single() return not IsGroup() and ns.db.blocks[S.selected] ~= nil end
    local buttons = {}
    local specs = {
        { "block", L.STYLE_TO_BLOCK, L.TIP_STYLE_TO_BLOCK, Single },
        { "group", L.STYLE_TO_GROUP, L.TIP_STYLE_TO_GROUP, function()
            if GroupHead() then return true end
            return Single() and #ns:GetStyleGroup(S.selected) >= 2
        end },
        -- on the "All blocks" page the Look tab does this (and restyles the window too)
        { "all", L.ALL_BLOCKS, L.TIP_STYLE_TO_ALL, function() return S.selected ~= ALL end },
    }
    for i, spec in ipairs(specs) do
        local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        b:SetSize(w, 24)
        b:SetPoint("LEFT", row, "LEFT", ROW_CONTROL_X + (i - 1) * (w + 6), 0)
        b:SetText(spec[2])
        FitButtonText(b)
        b:SetScript("OnClick", function() Apply(spec[1]) end)
        AttachTip(b, spec[2], spec[3])
        b.enabledFor = spec[4]
        buttons[i] = b
    end
    -- "All blocks" page: the three buttons give way to one that opens the Look tab, where
    -- the style of every block (and of this window) is picked; a style applied here would
    -- not show in that tab
    local goLook = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    goLook:SetSize(ROW_CONTROL_W - 10, 24)
    goLook:SetPoint("LEFT", row, "LEFT", ROW_CONTROL_X, 0)
    goLook:SetText(L.STYLE_OPEN_LOOK)
    FitButtonText(goLook)
    goLook:SetScript("OnClick", function()
        if ns.ShowOptionsPage then ns.ShowOptionsPage(PAGE_LOOK) end
    end)
    AttachTip(goLook, L.STYLE_OPEN_LOOK, L.TIP_STYLE_OPEN_LOOK)
    row.goLook, row.buttons = goLook, buttons -- (tools/mock_run.lua)
    RowHover(row, buttons[1], buttons[2], buttons[3], goLook)
    AttachTip(row, L.APPLY_STYLE_TO, L.TIP_APPLY_STYLE_TO)
    row.Refresh = function()
        local everything = S.selected == ALL
        for _, b in ipairs(buttons) do
            b:SetShown(not everything)
            b:SetEnabled(b.enabledFor() and true or false)
        end
        goLook:SetShown(everything)
        row.label:SetText(everything and L.STYLE_ALL_HERE or L.APPLY_STYLE_TO)
    end
    -- confirm: the first button that can be used (the gamepad will step through them)
    row.Activate = function()
        if goLook:IsShown() then goLook:Click() return end
        for _, b in ipairs(buttons) do
            if b:IsEnabled() then b:Click() return end
        end
    end
    FitRow(row, 30)
    return Register(AsSetting(row, L.APPLY_STYLE_TO, L.TIP_APPLY_STYLE_TO, "button"))
end

-- Builds the "Blocks" tab: the head (switch, selection), one page that scrolls, with
-- sections that fold, and the single-block actions at the bottom
local function BuildBlockPage(page)
    local single = function() return not IsGroup() end
    local isLauncher = function() return ns.IsLauncherKey(S.selected) end

    -- shortcuts: a widget bound to a block field, with its help tooltip
    local function Check(parent, label, field, tip)
        local get, set = Field(field)
        return CreateCheck(parent, label, get, set, nil, tip)
    end
    local function Slider(parent, label, minV, maxV, field, tip, isShown)
        local get, set = Field(field)
        return CreateSlider(parent, label, minV, maxV, 1, get, set, isShown, tip)
    end
    local function Dropdown(parent, label, options, field, tip)
        local get, set = Field(field)
        return CreateDropdown(parent, label, options, get, set, nil, nil, tip)
    end
    local function Color(parent, label, hasAlpha, field, tip)
        local get, set = ColorField(field)
        return CreateColor(parent, label, hasAlpha, get, set, nil, tip)
    end

    -- Head, above the part that scrolls: the "On screen" switch, left of the block's
    -- name (the selection list), then "Replace with..."
    local top = NewLayout(page)
    local REPLACE_W, PLACE_W = 140, 140
    local getE, setE = Field("enabled")
    local switch = top.Place(CreateSwitch(page, L.ENABLED, function() return getE() end, setE, nil, L.TIP_ENABLED), 1)
    ns.blockSwitch = switch -- (tools/mock_run.lua)
    -- the list sits right of the switch, on the same line (not a row of the page)
    local selection = CreateDropdown(page, L.SELECTION, SelectionOptions,
        function() return S.selected end,
        function(v)
            S.selected = v
            ns:RefreshOptions()
        end, nil, FULL_W - REPLACE_W - PLACE_W - SWITCH_W - 10, L.TIP_SELECTION)
    selection:SetPoint("TOPLEFT", switch, "TOPRIGHT", 10, 0)
    -- "Replace with...": another block takes the selected block's place
    local replace = CreateButton(page, L.REPLACE_BLOCK, function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        ns:OpenReplaceMenu(S.selected, self)
    end, function() return single() and ns.db.blocks[S.selected] ~= nil end, REPLACE_W - 8, L.TIP_REPLACE_BLOCK)
    replace:SetPoint("BOTTOMLEFT", selection, "BOTTOMRIGHT", 0, 1)
    -- "Place": moves the block's group pixel by pixel (the window folds meanwhile)
    local place = CreateButton(page, L.PLACE_BLOCK, function()
        if not ns:StartNudge(S.selected) then ns.Print(L.NUDGE_NOT_SHOWN) end
    end, single, PLACE_W - 6, L.TIP_PLACE_BLOCK)
    place:SetPoint("LEFT", replace, "RIGHT", 4, 0)
    place:SetNormalFontObject("GameFontNormal") -- gold text: easy to spot among the buttons
    -- usable as soon as the block is on screen: a block just put back is shown a moment
    -- after the window refreshes (test102), so its frame is checked on click
    place.Refresh = function(self)
        local cfg = ns.db.blocks[S.selected]
        self:SetEnabled(cfg and cfg.enabled and not ns:IsFrozen(S.selected) and not ns.brokerModeActive
            and not InCombatLockdown() and true or false)
    end
    ns.placeButton = place -- (tools/mock_run.lua)
    top.Gap(1, 6)

    -- One page that scrolls (1.3, in place of five sub-tabs): what matters first, then
    -- the block's own settings; the rest in sections that fold (closed when the
    -- window is built): its look, when to show it, this block (name, clicks, tooltip).
    local bodyY = top.Bottom(1) - 4
    local body = CreateFrame("Frame", nil, page)
    body:SetPoint("TOPLEFT", page, "TOPLEFT", 0, bodyY)
    body:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 56)
    body.layoutBase = bodyY
    body.pageIndex = page.pageIndex
    local sub = ScrollArea(body)
    local P = NewLayout(sub)
    local notSpacer = function() return not ns.IsSpacerKey(S.selected) end

    -- Column 1: what matters, then the block's own settings (the option stacks: last)
    P.Place(CreateHeader(sub, L.SECTION_ESSENTIAL), 1)
    P.Place(Check(sub, L.SHOW_LABEL, "showLabel", L.TIP_SHOW_LABEL), 1)
    P.Place(Check(sub, L.SHOW_VALUE, "showValue", L.TIP_SHOW_VALUE), 1)
    P.Place(Check(sub, L.SHOW_ICON, "showIcon", L.TIP_SHOW_ICON), 1)
    -- style of this block, its group or every block: an action (written into their
    -- settings, Ctrl + Z undoes it); the window keeps the style of the Look tab
    local pickStyle
    local function StyleChoices()
        local list = {}
        for _, t in ipairs(ns:GetAvailableThemes()) do table.insert(list, { key = t.key, name = t.name }) end
        return list
    end
    local styleDropdown = P.Place(CreateDropdown(sub, L.BLOCK_STYLE, StyleChoices,
        function() return pickStyle or ns:GetTheme() end,
        function(v) pickStyle = v end, nil, nil, L.TIP_BLOCK_STYLE), 1)
    -- greyed on the "All blocks" page: the Look tab picks that style (see CreateStyleTargets)
    local styleRefresh = styleDropdown.Refresh
    styleDropdown.Refresh = function(self)
        styleRefresh(self)
        local off = S.selected == ALL
        self.dropdown:SetEnabled(not off)
        self:SetAlpha(off and 0.45 or 1)
    end
    P.Place(CreateStyleTargets(sub, function() return pickStyle or ns:GetTheme() end), 1)
    P.Place(CreateHeader(sub, L.SECTION_SIZE), 1)
    P.Place(Check(sub, L.AUTO_WIDTH, "autoWidth", L.AUTO_WIDTH_TIP), 1)
    local sizeNote = P.Place(CreateNote(sub, L.SIZE_GROUP_HINT), 1)
    sizeNote.isShown = IsGroup
    -- a group selection shows the note in place of the sliders (same slot)
    P.Gap(1, -(sizeNote.layoutHeight + SPACING))
    P.Place(Slider(sub, L.WIDTH, 16, 600, "width", L.TIP_WIDTH, single), 1)
    P.Place(Slider(sub, L.HEIGHT, 10, 100, "height", L.TIP_HEIGHT, single), 1)
    P.Place(Slider(sub, L.ICON_SIZE, 0, 200, "iconSize", L.TIP_ICON_SIZE), 1)
    -- scale of the whole merged group the block belongs to (stored on its root)
    P.Place(CreateSlider(sub, L.GROUP_SCALE, 50, 300, 5,
        function()
            local root = not IsGroup() and ns.db.blocks[ns:GetRoot(S.selected)]
            return math.floor(((root and root.scale) or 1) * 100 + 0.5)
        end,
        function(v) if not IsGroup() then ns:SetGroupScale(S.selected, v / 100) end end,
        single, L.TIP_GROUP_SCALE), 1)

    -- its own settings: what the value looks like (gold format, clock...), a spacer's
    -- type, text and line. A group selection gets a note: they belong to one block.
    P.Place(CreateHeader(sub, L.SECTION_OWN), 1)
    local pick = P.Place(CreateNote(sub, L.THIS_BLOCK_PICK), 1)
    pick.isShown = IsGroup
    local none = P.Place(CreateNote(sub, L.NO_BLOCK_OPTIONS), 1)
    P.Gap(1, -(pick.layoutHeight + none.layoutHeight + 2 * SPACING))
    local keys = { "spacer" }
    for _, key in ipairs(ns.order) do table.insert(keys, key) end
    -- (one stack per column: two would draw over each other)
    local hasOptions = BuildModuleOptions(sub, P, 1, keys, nil, function() return true end)
    none.isShown = function()
        local key = SelectedModuleKey()
        return not IsGroup() and not (key and hasOptions[key])
    end

    -- Column 2 (shown under column 1): the sections that fold
    -- 1. The look of this block: display, text, background, icon, border, lines
    local lookSection = P.Place(CreateSection(sub, L.SECTION_BLOCK_LOOK, true), 2)
    P.Place(CreateHeader(sub, L.SECTION_DISPLAY), 2)
    P.Place(Check(sub, L.COLORIZE, "colorize", L.TIP_COLORIZE), 2)
    -- progress bar: only for blocks that have a progress (or a group selection)
    local getP, setP = Field("progressBar")
    P.Place(CreateCheck(sub, L.PROGRESS_BAR, getP, setP, function()
        if IsGroup() then return true end
        local mod = ns:GetModule(S.selected)
        return mod and mod.progress ~= nil or false
    end, L.TIP_PROGRESS_BAR), 2)
    local getA, setA = Field("alpha")
    P.Place(CreateSlider(sub, L.OPACITY, 10, 100, 5,
        function() return math.floor((getA() or 1) * 100 + 0.5) end,
        function(v) setA(v / 100) end, nil, L.TIP_OPACITY), 2)
    P.Place(Dropdown(sub, L.STRATA, {
        { key = "BACKGROUND", name = L.STRATA_BACKGROUND },
        { key = "LOW", name = L.STRATA_LOW },
        { key = "MEDIUM", name = L.STRATA_MEDIUM },
        { key = "HIGH", name = L.STRATA_HIGH },
    }, "strata", L.TIP_STRATA), 2)

    P.Place(CreateHeader(sub, L.SECTION_TEXT), 2)
    P.Place(Dropdown(sub, L.FONT, function() return ns:GetMediaList("font") end, "font", L.TIP_FONT), 2)
    P.Place(Slider(sub, L.FONT_SIZE, 6, 32, "fontSize", L.TIP_FONT_SIZE), 2)
    P.Place(Dropdown(sub, L.OUTLINE, {
        { key = "NONE", name = L.OUTLINE_NONE },
        { key = "OUTLINE", name = L.OUTLINE_THIN },
        { key = "THICKOUTLINE", name = L.OUTLINE_THICK },
    }, "outline", L.TIP_OUTLINE), 2)
    P.Place(Check(sub, L.TEXT_SHADOW, "textShadow", L.TIP_TEXT_SHADOW), 2)
    P.Place(Dropdown(sub, L.JUSTIFY, {
        { key = "LEFT", name = L.LEFT },
        { key = "CENTER", name = L.CENTER },
        { key = "RIGHT", name = L.RIGHT },
    }, "justify", L.TIP_JUSTIFY), 2)
    P.Place(Color(sub, L.TEXT_COLOR, false, "textColor", L.TIP_TEXT_COLOR), 2)
    P.Place(Check(sub, L.CLASS_COLOR_TEXT, "classColorText", L.TIP_CLASS_COLOR_TEXT), 2)

    P.Place(CreateHeader(sub, L.BACKGROUND), 2)
    P.Place(Dropdown(sub, L.BACKGROUND, function() return ns:GetMediaList("background") end, "bg", L.TIP_BACKGROUND), 2)
    P.Place(Color(sub, L.BG_COLOR, true, "bgColor", L.TIP_BG_COLOR), 2)
    P.Place(Check(sub, L.CLASS_COLOR_BG, "classColorBg", L.TIP_CLASS_COLOR_BG), 2)

    -- the icon: same frame and colors for every block (e.g. with "All blocks"); its size is above
    P.Place(CreateHeader(sub, L.SECTION_ICON), 2)
    P.Place(Dropdown(sub, L.ICON_SHAPE, {
        { key = "none", name = L.ICON_SHAPE_NONE },
        { key = "square", name = L.ICON_SHAPE_SQUARE },
        { key = "round", name = L.ICON_SHAPE_ROUND },
    }, "iconShape", L.TIP_ICON_SHAPE), 2)
    P.Place(Color(sub, L.ICON_BORDER_COLOR, true, "iconBorderColor", L.TIP_ICON_BORDER_COLOR), 2)
    P.Place(Check(sub, L.CLASS_COLOR_ICON, "classColorIcon", L.TIP_CLASS_COLOR_ICON), 2)
    P.Place(Check(sub, L.ICON_DESATURATE, "iconDesaturate", L.TIP_ICON_DESATURATE), 2)

    P.Place(CreateHeader(sub, L.BORDER), 2)
    -- picking a border also restores its original thickness
    P.Place(CreateDropdown(sub, L.BORDER, function() return ns:GetMediaList("border") end,
        function()
            local cfg = Cfg()
            return cfg and cfg.border
        end,
        function(v)
            SetField("border", v)
            local media = ns:FindMedia("border", v)
            local size = media and media.size
            if size then SetField("borderSize", size) end
            ns:RefreshOptions()
        end, nil, nil, L.TIP_BORDER), 2)
    P.Place(Slider(sub, L.BORDER_SIZE, 1, 32, "borderSize", L.TIP_BORDER_SIZE), 2)

    -- Corner join: belongs to the border (not the block), with a reset to the original value
    local function CurrentBorder()
        local cfg = Cfg()
        return cfg and cfg.border
    end
    local function HasCorners()
        local b = CurrentBorder()
        return b and b ~= "none" and b ~= "solid"
    end
    local corner = CreateSlider(sub, L.CORNER_JOIN, 0, 100, 1,
        function()
            local b = CurrentBorder()
            return b and math.floor(ns:GetBorderReach(b) * 100 + 0.5) or 0
        end,
        function(v)
            local b = CurrentBorder()
            if b then ns:SetBorderReach(b, v / 100) end
        end, HasCorners, L.TIP_CORNER_JOIN)
    local default = CreateFrame("Button", nil, corner, "UIPanelButtonTemplate")
    default:SetSize(64, 18)
    default:SetPoint("RIGHT", corner.slider, "LEFT", -8, 0) -- between the label and the slider
    corner.label:SetWidth(ROW_LABEL_W - 80)
    default:SetText(L.DEFAULT_SHORT)
    default:SetScript("OnClick", function()
        local b = CurrentBorder()
        if b then
            ns:SetBorderReach(b, nil)
            ns:RefreshOptions()
        end
    end)
    AttachTip(default, L.DEFAULT_SHORT, L.TIP_CORNER_DEFAULT)
    local refreshCorner = corner.Refresh
    corner.Refresh = function(self)
        refreshCorner(self)
        local b = CurrentBorder()
        default:SetEnabled(b ~= nil and ns:HasCustomBorderReach(b))
    end
    P.Place(corner, 2)
    P.Place(Color(sub, L.BORDER_COLOR, true, "borderColor", L.TIP_BORDER_COLOR), 2)
    P.Place(Check(sub, L.CLASS_COLOR_BORDER, "classColorBorder", L.TIP_CLASS_COLOR_BORDER), 2)
    -- thin lines between merged blocks
    P.Place(CreateHeader(sub, L.SECTION_SEPARATORS), 2)
    P.Place(Check(sub, L.SEPARATORS, "separators", L.TIP_SEPARATORS), 2)
    P.Place(Color(sub, L.SEPARATOR_COLOR, true, "separatorColor", L.TIP_SEPARATOR_COLOR), 2)
    P.Place(Check(sub, L.CLASS_COLOR_SEPARATOR, "classColorSeparator", L.TIP_CLASS_COLOR_SEPARATOR), 2)

    -- 2. When to show it: hidden in some places, hover fade
    local whenSection = P.Place(CreateSection(sub, L.SECTION_WHEN, true), 2)
    P.Place(Check(sub, L.HIDE_COMBAT, "hideInCombat", L.TIP_HIDE_COMBAT), 2)
    P.Place(Check(sub, L.HIDE_INSTANCE, "hideInInstance", L.TIP_HIDE_INSTANCE), 2)
    P.Place(Check(sub, L.HIDE_VEHICLE, "hideInVehicle", L.TIP_HIDE_VEHICLE), 2)
    P.Place(Check(sub, L.HIDE_RESTING, "hideWhenResting", L.TIP_HIDE_RESTING), 2)
    P.Place(CreateHeader(sub, L.SECTION_FADE), 2)
    local getF, setF = Field("fadeOut")
    P.Place(CreateCheck(sub, L.FADE_OUT, getF, function(v)
        setF(v)
        ns:RefreshOptions()
    end, nil, L.TIP_FADE_OUT), 2)
    local fading = function() local cfg = Cfg() return cfg and cfg.fadeOut or false end
    local getFA, setFA = Field("fadeAlpha")
    P.Place(CreateSlider(sub, L.FADE_ALPHA, 0, 90, 5,
        function() return math.floor((getFA() or 0) * 100 + 0.5) end,
        function(v) setFA(v / 100) end, fading, L.TIP_FADE_ALPHA), 2)
    local getFC, setFC = Field("fadeShowCombat")
    P.Place(CreateCheck(sub, L.FADE_COMBAT, getFC, setFC, fading, L.TIP_FADE_COMBAT), 2)

    -- 3. This block: its name, its tooltip, its alert, its clicks and its pinned tooltip
    local thisSection = P.Place(CreateSection(sub, L.SECTION_THIS_BLOCK, true), 2)
    local named = function() return not IsGroup() and notSpacer() end
    local getN = Field("customName")
    P.Place(CreateEditBox(sub, L.CUSTOM_NAME, getN, function(v)
        v = type(v) == "string" and strtrim(v) or ""
        SetField("customName", v ~= "" and v or nil)
    end, named, L.TIP_CUSTOM_NAME), 2)
    P.Place(Check(sub, L.SHOW_TOOLTIP, "tooltip", L.TIP_SHOW_TOOLTIP), 2)
    P.Place(Dropdown(sub, L.TOOLTIP_ANCHOR, {
        { key = "auto", name = L.TOOLTIP_AUTO },
        { key = "top", name = L.TOOLTIP_TOP },
        { key = "bottom", name = L.TOOLTIP_BOTTOM },
    }, "tooltipAnchor", L.TIP_TOOLTIP_ANCHOR), 2).isShown = notSpacer
    P.Place(Check(sub, L.ALERT, "alert", L.TIP_ALERT), 2).isShown = notSpacer
    local clicksHeader = P.Place(CreateHeader(sub, L.SECTION_CLICKS), 2)
    local clickShown = function() return not ns.IsForwardingKey(S.selected) and notSpacer() end
    local getS, setS = Field("shiftClick")
    local getM, setM = Field("middleClick")
    local function Actions(withOpen)
        local list = {}
        if withOpen then table.insert(list, { key = "open", name = L.ACTION_OPEN }) end
        -- the block's own extra action (e.g. coordinates: place a map pin)
        local mod = not IsGroup() and ns:GetModule(S.selected)
        if mod and mod.extraAction then
            table.insert(list, { key = mod.extraAction.key, name = L[mod.extraAction.label] })
        end
        for _, a in ipairs({ { "none", L.ACTION_NONE }, { "chat", L.ACTION_CHAT },
                             { "options", L.ACTION_OPTIONS }, { "hide", L.ACTION_HIDE },
                             { "pin", L.ACTION_PIN } }) do
            table.insert(list, { key = a[1], name = a[2] })
        end
        return list
    end
    P.Place(CreateDropdown(sub, L.SHIFT_CLICK, function() return Actions(false) end, getS, setS,
        clickShown, nil, L.TIP_SHIFT_CLICK), 2)
    P.Place(CreateDropdown(sub, L.MIDDLE_CLICK, function() return Actions(true) end, getM, function(v)
        setM(v)
        ns:RequestOverlaySync() -- the secure button listens to middle clicks only for "open"
    end, clickShown, nil, L.TIP_MIDDLE_CLICK), 2)
    local pin = P.Place(CreateButton(sub, L.MENU_PIN, function()
        ns:TogglePin(S.selected)
        ns:RefreshOptions()
    end, function() return named() and ns.CanPinTooltip and ns.CanPinTooltip(S.selected) or false end,
        COL_W - 8, L.TIP_PIN_BUTTON), 2)
    -- the header only when a click setting or the pin button is under it
    -- (a DataBroker block keeps its own clicks)
    clicksHeader.isShown = function() return clickShown() or pin.isShown() end
    pin.Refresh = function(self)
        self:SetText(ns.IsPinned and ns:IsPinned(S.selected) and L.MENU_UNPIN or L.MENU_PIN)
    end

    -- Opens a part of the page (the old sub-tabs, still used by other pages and the tour):
    -- 1 and 5 the top (what matters, its own settings), 2 and 3 its look, 4 when to
    -- show it, 6 this block. The section unfolds and the page scrolls to it.
    local SUB_SECTION = { [2] = lookSection, [3] = lookSection, [4] = whenSection, [6] = thisSection }
    local function ShowSub(index)
        local section = SUB_SECTION[index]
        if section then section.folded = false end
        ns:RefreshOptions()
        C_Timer.After(0, function()
            local scroll = sub.scroll
            if not (scroll and scroll.SetVerticalScroll) then return end
            local y = 0
            if section and section:IsShown() then
                local top0, at = sub:GetTop(), section:GetTop()
                if top0 and at then y = top0 - at end
            end
            local range = scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or 0
            scroll:SetVerticalScroll(math.max(0, math.min(range, y)))
        end)
    end
    ns.ShowBlockSub = ShowSub
    ns.blockSections = { lookSection, whenSection, thisSection }

    -- Single-block actions, at the bottom (four slots; "Copy to group" only for a
    -- block in a group, the fourth button takes its slot otherwise)
    local bw = math.floor((FULL_W - 3 * 12) / 4)
    local reset = CreateButton(page, L.RESET_BLOCK, function()
        ns:ResetBlock(S.selected)
        ns:RefreshOptions()
    end, single, bw, L.TIP_RESET_BLOCK)
    reset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1], 22)

    local copy = CreateButton(page, L.COPY_STYLE, function()
        ns:CopyStyleToAll(S.selected)
    end, single, bw, L.TIP_COPY_STYLE)
    copy:SetPoint("LEFT", reset, "RIGHT", 12, 0)

    local inGroup = function() return single() and #ns:GetStyleGroup(S.selected) >= 2 end
    local copyGroup = CreateButton(page, L.COPY_STYLE_GROUP, function()
        ns:CopyStyleToGroup(S.selected)
    end, inGroup, bw, L.TIP_COPY_STYLE_GROUP)
    copyGroup:SetPoint("LEFT", copy, "RIGHT", 12, 0)
    local lastSlot = {} -- buttons of the last slot, placed after "Copy to group" when it is shown

    -- third slot: remove the launcher / the spacer, or add a spacer
    local isSpacer = function() return ns.IsSpacerKey(S.selected) end
    local remove = CreateButton(page, L.REMOVE_LAUNCHER, function()
        ns:RemoveLauncher(S.selected)
        ns:RefreshOptions()
    end, isLauncher, bw, L.TIP_REMOVE_LAUNCHER)
    table.insert(lastSlot, remove)
    local removeSpacer = CreateButton(page, L.REMOVE_SPACER, function()
        ns:RemoveSpacer(S.selected)
        ns:RefreshOptions()
    end, isSpacer, bw, L.TIP_REMOVE_SPACER)
    table.insert(lastSlot, removeSpacer)
    local removeBroker = CreateButton(page, L.REMOVE_BROKER, function()
        ns:RemoveBroker(S.selected)
        ns:RefreshOptions()
    end, function() return ns.IsBrokerKey(S.selected) end, bw, L.TIP_REMOVE_BROKER)
    table.insert(lastSlot, removeBroker)
    local addSpacer = CreateButton(page, L.ADD_SPACER, function()
        S.selected = ns:AddSpacer()
        ns:PlaceNearOptions(S.selected)
        ShowSub(5) -- the spacer's settings (type, text, line): its own settings, at the top
        if ns.db.locked then ns:SetLocked(false) end
        ns:RefreshOptions()
    end, function() return not ns.IsForwardingKey(S.selected) and not isSpacer() end, bw, L.TIP_ADD_SPACER)
    table.insert(lastSlot, addSpacer)
    copyGroup.Refresh = function(self)
        local after = self:IsShown() and self or copy
        for _, b in ipairs(lastSlot) do
            b:ClearAllPoints()
            b:SetPoint("LEFT", after, "RIGHT", 12, 0)
        end
    end
    copyGroup:Refresh()
end

-- Shared with the files loaded after this one
Tools.BuildBlockPage = BuildBlockPage
Tools.BuildModuleOptions = BuildModuleOptions
Tools.SelectedModuleKey = SelectedModuleKey
Tools.SortKey = SortKey

