local _, ns = ...
local L = ns.L

-- Blocks part of the options window: the Blocks tab: selection options, the options of every block, style targets.
-- Shared with the other Options*.lua files through ns.OptionsTools (see Options.lua).
local Tools = ns.OptionsTools
local S = Tools.S
local ALL, AsSetting, AttachTip, COL_W = Tools.ALL, Tools.AsSetting, Tools.AttachTip, Tools.COL_W
local COL_X, Cfg, ColorField, CreateButton = Tools.COL_X, Tools.Cfg, Tools.ColorField, Tools.CreateButton
local CreateCheck, CreateColor, CreateDropdown, CreateEditBox = Tools.CreateCheck, Tools.CreateColor, Tools.CreateDropdown, Tools.CreateEditBox
local CreateNote, CreateSlider, CreateTabs, NewFlow = Tools.CreateNote, Tools.CreateSlider, Tools.CreateTabs, Tools.NewFlow
local CreateSwitch, FULL_W, Field, FitButtonText = Tools.CreateSwitch, Tools.FULL_W, Tools.Field, Tools.FitButtonText
local FitRow, GROUP_PREFIX, GroupHead, IsGroup = Tools.FitRow, Tools.GROUP_PREFIX, Tools.GroupHead, Tools.IsGroup
local LAUNCHERS, LauncherKeys, NewLayout, NewRow = Tools.LAUNCHERS, Tools.LauncherKeys, Tools.NewLayout, Tools.NewRow
local PAGE_LOOK, ROW_CONTROL_W, ROW_CONTROL_X, ROW_LABEL_W = Tools.PAGE_LOOK, Tools.ROW_CONTROL_W, Tools.ROW_CONTROL_X, Tools.ROW_LABEL_W
local Register, RowHover, RowLabel, ScrollToBox = Tools.Register, Tools.RowHover, Tools.RowLabel, Tools.ScrollToBox
local ScrollArea, SetField = Tools.ScrollArea, Tools.SetField


---------------------------------------------------------------------------
-- "Blocks" tab
---------------------------------------------------------------------------
-- Entries of the selection dropdown: groups first, then data blocks, then launchers
-- Sort key for names: lower case without accents, so "Écran" sorts with the E's
local SortKey = ns.SortKey

local function SelectionOptions()
    -- plain: the name without markup (the "See all" window searches it); block: a real block
    -- (counted in "x of y blocks on screen"), shown: on the screen
    local list = { { key = ALL, name = L.ALL_BLOCKS, plain = L.ALL_BLOCKS } }
    if #LauncherKeys() > 0 then
        table.insert(list, { key = LAUNCHERS, name = L.ALL_LAUNCHERS, plain = L.ALL_LAUNCHERS })
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
            table.insert(list, { key = g.key, name = name, plain = L.GROUP_ENTRY:format(g.label) })
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
                table.insert(list, { key = key, name = name, plain = ns:GetBlockName(key), block = true, shown = on })
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

-- Builds every module's own options (Modules.lua "options", "Hide when empty", thresholds)
-- into boxes (OptionsBoxes.lua): route(opt) gives the box of an option (opt.where = "when"
-- for "Hide when empty", "alerts" for the thresholds, opt.section = "tooltip" for what the
-- tooltip shows). Only the selected block's options show. condition (optional) must also be
-- true for them to show. Returns the set of module keys that have options.
local function BuildModuleOptions(keys, route, condition)
    local function ModuleOf(key)
        return key == "spacer" and ns.spacerModule or ns.modules[key]
    end
    local hasOptions = {}
    for _, key in ipairs(keys) do
        local mod = ModuleOf(key)
        local list = {}
        for _, opt in ipairs(mod.options or {}) do table.insert(list, opt) end
        if mod.isEmpty then
            table.insert(list, { kind = "check", field = "hideEmpty", label = "HIDE_EMPTY", tip = "TIP_HIDE_EMPTY",
                where = "when", after = function() ns:UpdateAllVisibility() end })
        end
        if mod.thresholds then
            local t = mod.thresholds
            local tip = t.low and "TIP_THRESHOLD_LOW" or "TIP_THRESHOLD_HIGH"
            table.insert(list, { kind = "slider", field = "warnAt", label = "THRESHOLD_WARN", tip = tip,
                min = t.min, max = t.max, step = t.step, default = t.warn, where = "alerts" })
            table.insert(list, { kind = "slider", field = "badAt", label = "THRESHOLD_BAD", tip = tip,
                min = t.min, max = t.max, step = t.step, default = t.bad, where = "alerts" })
        end
        if #list > 0 then hasOptions[key] = true end
        for _, opt in ipairs(list) do
            local box = route(opt)
            local sub = box.content
            local shown = function()
                if SelectedModuleKey() ~= key then return false end
                if condition and not condition() then return false end
                local cfg = Cfg()
                return not opt.shown or (cfg and opt.shown(cfg)) or false
            end
            local get, set = Field(opt.field)
            -- a value kept outside the block's settings (the volume presets are account-wide)
            if opt.get then get, set = opt.get, opt.set or function() end end
            local label, tip = L[opt.label] or opt.label, L[opt.tip]
            if type(opt.label) == "function" then label = opt.label() end -- (a name the game gives: reagents)
            local setter = function(v)
                set(v)
                if opt.after then opt.after() end
                if ns.UpdatePublishing then ns:UpdatePublishing() end -- shared value follows
                ns:RefreshOptions() -- an option can show or hide others (spacer mode)
            end
            local w
            if opt.kind == "check" then
                w = CreateCheck(sub, label, get, setter, shown, tip)
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
                w = CreateDropdown(sub, label, values, get, setter, shown, nil, tip)
            elseif opt.kind == "slider" then
                w = CreateSlider(sub, label, opt.min, opt.max, opt.step or 1,
                    function() return get() or opt.default end, setter, shown, tip)
            elseif opt.kind == "number" or opt.kind == "text" then
                w = CreateEditBox(sub, label, get, function(v)
                    if opt.kind == "number" then
                        v = tonumber(v)
                        if not v then return end
                        if opt.min then v = math.max(opt.min, v) end
                    end
                    setter(v)
                end, shown, tip, opt.kind == "number")
            elseif opt.kind == "button" then
                -- an action in the block's box (save a preset...); the options redraw after it
                w = CreateButton(sub, label, function()
                    if opt.onClick then opt.onClick() end
                    ns:RefreshOptions()
                end, shown, nil, tip)
            elseif opt.kind == "note" then
                -- a short explanation in the block's own box (how to use it), shown like the others
                w = CreateNote(sub, opt.text and opt.text() or L[opt.label])
                w.isShown = shown
            elseif opt.kind == "color" then
                local getC, setC = ColorField(opt.field)
                w = CreateColor(sub, label, true, getC, function(...)
                    setC(...)
                    ns:ApplyStyle(S.selected)
                end, shown, tip)
            end
            if w then
                box.flow.currentBlock = key -- (search: a setting of this block opens it)
                -- check boxes two by two (a short list with arrows too, when its label is short)
                box.Add(w, { half = opt.kind == "check", field = opt.field })
                box.flow.currentBlock = nil
            end
        end
    end
    return hasOptions
end


-- Applies a style to some blocks and says what it needs (the warning about locked blocks is asked before)
function ns:ApplyStyleToBlocksNow(keys, style)
    if self:ApplyThemeToBlocks(keys, style) then
        local note = self:GetThemeNote(style)
        if note then self.Print(note) end
    end
    self:RefreshOptions()
end

ns.OnLanguage(function()
    StaticPopupDialogs["TESSERA_STYLE_LOCKED_APPLY"] = {
        text = L.STYLE_LOCKED_APPLY,
        button1 = YES,
        button2 = NO,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(_, data) ns:ApplyStyleToBlocksNow(data.keys, data.style) end,
    }
end)

-- "Copy style to all" / "Copy this style to the group" with locked blocks among the targets: asks first,
-- then copies (they stay locked)
ns.OnLanguage(function()
    StaticPopupDialogs["TESSERA_STYLE_LOCKED_COPY"] = {
        text = L.STYLE_LOCKED_APPLY,
        button1 = YES,
        button2 = NO,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(_, data)
            if data.group then ns:CopyStyleToGroup(data.source, true) else ns:CopyStyleToAll(data.source, true) end
            ns:RefreshOptions()
        end,
    }
end)

-- Unlocking a block's style: follow the profile's style now, or keep the current look
ns.OnLanguage(function()
    StaticPopupDialogs["TESSERA_STYLE_UNLOCK"] = {
        text = L.STYLE_UNLOCK_FOLLOW,
        button1 = YES,
        button2 = NO,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(_, keys) ns:ApplyStyleToBlocksNow(keys, ns:GetTheme()) end,
    }
end)

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
    local function Apply(target, style)
        local keys = Keys(target)
        style = style or getStyle()
        local locked = 0
        for _, key in ipairs(keys) do
            if ns.db.blocks[key] and ns.db.blocks[key].styleLocked then locked = locked + 1 end
        end
        -- a block whose style is locked takes the style only after a warning (it stays locked)
        if locked > 0 then
            StaticPopup_Show("TESSERA_STYLE_LOCKED_APPLY", locked, nil, { keys = keys, style = style })
            return
        end
        ns:ApplyStyleToBlocksNow(keys, style)
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
        local b = ns.Skin.Button(CreateFrame("Button", nil, row, "UIPanelButtonTemplate"))
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
    local goLook = ns.Skin.Button(CreateFrame("Button", nil, row, "UIPanelButtonTemplate"))
    goLook:SetSize(ROW_CONTROL_W - 10, 24)
    goLook:SetPoint("LEFT", row, "LEFT", ROW_CONTROL_X, 0)
    goLook:SetText(L.STYLE_OPEN_LOOK)
    FitButtonText(goLook)
    goLook:SetScript("OnClick", function()
        if ns.ShowOptionsPage then ns.ShowOptionsPage(PAGE_LOOK) end
    end)
    AttachTip(goLook, L.STYLE_OPEN_LOOK, L.TIP_STYLE_OPEN_LOOK)
    row.goLook, row.buttons = goLook, buttons -- (tools/mock_run.lua)
    row.specs, row.Apply = specs, Apply -- the same buttons in the style gallery
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

-- Builds the "Blocks" tab (1.5, as FlareUI's pages): the head (switch, selection, Replace,
-- Place), three tabs (Content, Appearance, Behaviour) whose settings sit in boxes, and the
-- single-block actions at the bottom
local function BuildBlockPage(page)
    local single = function() return not IsGroup() end
    local isLauncher = function() return ns.IsLauncherKey(S.selected) end
    local notSpacer = function() return not ns.IsSpacerKey(S.selected) end

    -- shortcuts: a widget bound to a block field, with its help tooltip (the field: for Reset)
    local function Check(parent, label, field, tip, isShown)
        local get, set = Field(field)
        local w = CreateCheck(parent, label, get, set, isShown, tip)
        w.field = field
        return w
    end
    local function Slider(parent, label, minV, maxV, field, tip, isShown)
        local get, set = Field(field)
        local w = CreateSlider(parent, label, minV, maxV, 1, get, set, isShown, tip)
        w.field = field
        return w
    end
    local function Dropdown(parent, label, options, field, tip, isShown)
        local get, set = Field(field)
        local w = CreateDropdown(parent, label, options, get, set, isShown, nil, tip)
        w.field = field
        return w
    end
    local function Color(parent, label, hasAlpha, field, tip)
        local get, set = ColorField(field)
        local w = CreateColor(parent, label, hasAlpha, get, set, nil, tip)
        w.field = field
        return w
    end
    local function IsOn(field) return function() local cfg = Cfg() return cfg and cfg[field] and true or false end end

    -- Head, above the tabs: the "On screen" switch, left of the block's name (the
    -- selection list), then "Replace with..." and "Place by pixel"
    local top = NewLayout(page)
    local REPLACE_W, PLACE_W = 140, 140
    local ENABLED_W, HIDE_W = 96, 112 -- the two switches stay narrow: the list needs room for a block name
    local getE, setE = Field("enabled")
    local switch = top.Place(CreateSwitch(page, L.ENABLED, function() return getE() end, setE, nil, L.TIP_ENABLED, ENABLED_W), 1)
    ns.blockSwitch = switch -- (tools/mock_run.lua)
    -- "Hide when empty", right of it: same setting as the Behaviour tab's check, within reach.
    -- Only for blocks that can be empty (friends, guild, mail...) or for a group / all blocks.
    local getH, setH = Field("hideEmpty")
    local function CanBeEmpty()
        if not single() then return true end
        local mod = ns.modules[S.selected]
        return mod ~= nil and mod.isEmpty ~= nil
    end
    local hideSwitch = CreateSwitch(page, L.HIDE_EMPTY, function() return getH() end, function(v)
        setH(v)
        ns:UpdateAllVisibility()
    end, CanBeEmpty, L.TIP_HIDE_EMPTY, HIDE_W)
    hideSwitch:SetPoint("TOPLEFT", switch, "TOPRIGHT", 6, 0)
    ns.hideEmptySwitch = hideSwitch -- (tools/mock_run.lua)
    -- the list sits right of the switches, on the same line (not a row of the page)
    local selection = CreateDropdown(page, L.SELECTION, SelectionOptions,
        function() return S.selected end,
        function(v)
            S.selected = v
            ns:RefreshOptions()
        end, nil, math.max(170, FULL_W - REPLACE_W - PLACE_W - ENABLED_W - HIDE_W - 16), L.TIP_SELECTION)
    -- next to "Hide when empty", or next to "Enabled" when that one is not shown for this block
    local origRefresh = hideSwitch.Refresh
    hideSwitch.Refresh = function(self)
        origRefresh(self)
        selection:ClearAllPoints()
        selection:SetPoint("TOPLEFT", CanBeEmpty() and self or switch, "TOPRIGHT", 10, 0)
    end
    selection:SetPoint("TOPLEFT", hideSwitch, "TOPRIGHT", 10, 0)
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
    -- "See all": a window with every block at once, and how many are on screen (1.8)
    local seeAll = top.Place(CreateButton(page, L.SEE_ALL_BLOCKS, function() ns:ShowBlockPicker() end, nil, 130, L.TIP_SEE_ALL_BLOCKS), 1)
    local count = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    count:SetPoint("LEFT", seeAll, "RIGHT", 10, 0)
    seeAll.Refresh = function() count:SetText(L.BLOCK_COUNT:format(Tools.CountBlocks())) end
    ns.seeAllButton = seeAll -- (tools/mock_run.lua)
    top.Gap(1, 4)

    -- The tabs, then one page per tab that scrolls (only when it has to)
    local names = { L.BLOCK_TAB_CONTENT, L.BLOCK_TAB_LOOK, L.BLOCK_TAB_BEHAVIOUR }
    local tips = { L.TIP_BLOCK_TAB_CONTENT, L.TIP_BLOCK_TAB_LOOK, L.TIP_BLOCK_TAB_BEHAVIOUR }
    local bodies, flows = {}, {}
    local tabBar
    local function ShowTab(i)
        S.blockTab = i -- kept while the window is open: another block opens on the same tab
        for n, body in ipairs(bodies) do body:SetShown(n == i) end
        tabBar.Select(i)
    end
    tabBar = CreateTabs(page, names, tips, function(i)
        ShowTab(i)
        ns:RefreshOptions()
    end)
    tabBar:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[1], top.Bottom(1))
    local bodyY = top.Bottom(1) - 34
    for i = 1, #names do
        local body = CreateFrame("Frame", nil, page)
        body:SetPoint("TOPLEFT", page, "TOPLEFT", 0, bodyY)
        body:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 56)
        body.layoutBase = bodyY
        body.pageIndex, body.subIndex = page.pageIndex, i
        local sub = ScrollArea(body)
        sub.tabName = names[i]
        bodies[i], flows[i] = body, NewFlow(sub)
    end
    local C, A, B = flows[1], flows[2], flows[3]
    local c, a, b = C.content, A.content, B.content

    -- 1. Content: what the block shows (its name, value, icon, style and its own settings),
    -- then what its tooltip shows
    -- first what only this block has (its own settings and what its tooltip lists), then the
    -- settings every block has (name, label, value, icon, style, tooltip)
    local ownBox = C.Box(L.BOX_OWN, { reset = true })
    local standardNote = C.Box(nil)
    standardNote.Add(CreateNote(c, L.NOTE_STANDARD))
    local valueBox = C.Box(L.BOX_VALUE, { reset = true })
    local named = function() return not IsGroup() and notSpacer() end
    local getN = Field("customName")
    valueBox.Add(CreateEditBox(c, L.CUSTOM_NAME, getN, function(v)
        v = type(v) == "string" and strtrim(v) or ""
        SetField("customName", v ~= "" and v or nil)
    end, named, L.TIP_CUSTOM_NAME), { field = "customName" })
    valueBox.Add(Check(c, L.SHOW_LABEL, "showLabel", L.TIP_SHOW_LABEL), { half = true })
    valueBox.Add(Check(c, L.SHOW_VALUE, "showValue", L.TIP_SHOW_VALUE), { half = true })
    valueBox.Add(Check(c, L.SHOW_ICON, "showIcon", L.TIP_SHOW_ICON), { half = true })
    -- style of this block, its group or every block: an action (written into their
    -- settings, Ctrl + Z undoes it); the window keeps the style of the Look tab
    local pickStyle
    local function StyleChoices()
        local list = {}
        for _, t in ipairs(ns:GetAvailableThemes()) do table.insert(list, { key = t.key, name = t.name }) end
        return list
    end
    local styleDropdown = valueBox.Add(CreateDropdown(c, L.BLOCK_STYLE, StyleChoices,
        function() return pickStyle or ns:GetTheme() end,
        function(v) pickStyle = v end, nil, nil, L.TIP_BLOCK_STYLE))
    -- greyed on the "All blocks" page: the Look tab picks that style (see CreateStyleTargets)
    local styleRefresh = styleDropdown.Refresh
    styleDropdown.Refresh = function(self)
        styleRefresh(self)
        local off = S.selected == ALL
        self.dropdown:SetEnabled(not off)
        self:SetAlpha(off and 0.45 or 1)
    end
    local styleTargets = CreateStyleTargets(c, function() return pickStyle or ns:GetTheme() end)
    -- the style gallery (OptionsStyleGallery.lua), with the three buttons of "Apply this style to"
    local galleryButton = valueBox.Add(CreateButton(c, L.STYLE_GALLERY_OPEN, function()
        local actions = {}
        for _, spec in ipairs(styleTargets.specs) do
            actions[#actions + 1] = {
                text = spec[2], tip = spec[3],
                enabled = function(key) return key ~= nil and spec[4]() and true or false end,
                run = function(_, style)
                    pickStyle = style
                    styleTargets.Apply(spec[1], style)
                end,
            }
        end
        ns:ShowStyleGallery({
            chosen = pickStyle or ns:GetTheme(),
            current = function() return ns:GetTheme() end,
            currentLabel = L.STYLE_GALLERY_PROFILE,
            actions = actions,
        })
    end, nil, nil, L.TIP_STYLE_GALLERY_OPEN_BLOCK))
    -- greyed on the "All blocks" page, as the list above
    galleryButton.Refresh = function(self)
        local off = S.selected == ALL
        self:SetEnabled(not off)
        self:SetAlpha(off and 0.45 or 1)
    end
    ns.blockGalleryButton = galleryButton -- (tools/mock_run.lua)
    valueBox.Add(styleTargets)

    local tipBox = C.Box(L.SECTION_TOOLTIP, { reset = true })
    local showTip = tipBox.Add(Check(c, L.SHOW_TOOLTIP, "tooltip", L.TIP_SHOW_TOOLTIP))
    tipBox.Add(Dropdown(c, L.TOOLTIP_ANCHOR, {
        { key = "auto", name = L.TOOLTIP_AUTO },
        { key = "top", name = L.TOOLTIP_TOP },
        { key = "bottom", name = L.TOOLTIP_BOTTOM },
    }, "tooltipAnchor", L.TIP_TOOLTIP_ANCHOR, notSpacer), { parent = IsOn("tooltip") })
    tipBox.Add(Dropdown(c, L.TOOLTIP_ALIGN, {
        { key = "auto", name = L.TOOLTIP_AUTO },
        { key = "left", name = L.TOOLTIP_ALIGN_LEFT },
        { key = "center", name = L.TOOLTIP_ALIGN_CENTER },
        { key = "right", name = L.TOOLTIP_ALIGN_RIGHT },
    }, "tooltipAlign", L.TIP_TOOLTIP_ALIGN, notSpacer), { parent = IsOn("tooltip") })
    ns.blockTooltipCheck = showTip -- (tools/mock_run.lua)

    -- 2. Appearance: size, text, background, icon, border, separators, opacity and layer,
    -- colors by level and progress bar
    -- locked: a style change for the whole profile (Look tab, an interface missing or back) leaves it
    -- as it is. Its own section at the top of Appearance, so it is seen before the settings it protects
    local lockBox = A.Box(L.SECTION_STYLE_LOCK)
    local lockCheck = lockBox.Add(CreateCheck(a, L.STYLE_LOCK, Field("styleLocked"), function(v)
        local keys = Tools.Targets()
        SetField("styleLocked", v and true or nil)
        if not v then StaticPopup_Show("TESSERA_STYLE_UNLOCK", nil, nil, keys) end
    end, nil, L.TIP_STYLE_LOCK))
    lockCheck.field = "styleLocked"

    local sizeBox = A.Box(L.SECTION_SIZE, { reset = true })
    sizeBox.Add(Check(a, L.AUTO_WIDTH, "autoWidth", L.AUTO_WIDTH_TIP))
    -- a group selection shows the note in place of the sliders
    local sizeNote = sizeBox.Add(CreateNote(a, L.SIZE_GROUP_HINT))
    sizeNote.isShown = IsGroup
    sizeBox.Add(Slider(a, L.WIDTH, 16, 600, "width", L.TIP_WIDTH, single))
    sizeBox.Add(Slider(a, L.HEIGHT, 10, 100, "height", L.TIP_HEIGHT, single))
    sizeBox.Add(Slider(a, L.ICON_SIZE, 0, 200, "iconSize", L.TIP_ICON_SIZE))
    -- scale of the whole merged group the block belongs to (stored on its root)
    sizeBox.Add(CreateSlider(a, L.GROUP_SCALE, 50, 300, 5,
        function()
            local root = not IsGroup() and ns.db.blocks[ns:GetRoot(S.selected)]
            return math.floor(((root and root.scale) or 1) * 100 + 0.5)
        end,
        function(v) if not IsGroup() then ns:SetGroupScale(S.selected, v / 100) end end,
        single, L.TIP_GROUP_SCALE))

    local textBox = A.Box(L.SECTION_TEXT, { reset = true })
    textBox.Add(Dropdown(a, L.FONT, function() return ns:GetMediaList("font") end, "font", L.TIP_FONT))
    textBox.Add(Slider(a, L.FONT_SIZE, 6, 32, "fontSize", L.TIP_FONT_SIZE))
    textBox.Add(Dropdown(a, L.OUTLINE, {
        { key = "NONE", name = L.OUTLINE_NONE },
        { key = "OUTLINE", name = L.OUTLINE_THIN },
        { key = "THICKOUTLINE", name = L.OUTLINE_THICK },
    }, "outline", L.TIP_OUTLINE), { half = true })
    textBox.Add(Dropdown(a, L.JUSTIFY, {
        { key = "LEFT", name = L.LEFT },
        { key = "CENTER", name = L.CENTER },
        { key = "RIGHT", name = L.RIGHT },
    }, "justify", L.TIP_JUSTIFY), { half = true })
    textBox.Add(Color(a, L.TEXT_COLOR, false, "textColor", L.TIP_TEXT_COLOR))
    textBox.Add(Check(a, L.CLASS_COLOR_TEXT, "classColorText", L.TIP_CLASS_COLOR_TEXT), { half = true })
    textBox.Add(Check(a, L.TEXT_SHADOW, "textShadow", L.TIP_TEXT_SHADOW), { half = true })

    local bgBox = A.Box(L.BACKGROUND, { reset = true })
    bgBox.Add(Dropdown(a, L.BACKGROUND, function() return ns:GetMediaList("background") end, "bg", L.TIP_BACKGROUND))
    bgBox.Add(Color(a, L.BG_COLOR, true, "bgColor", L.TIP_BG_COLOR))
    bgBox.Add(Check(a, L.CLASS_COLOR_BG, "classColorBg", L.TIP_CLASS_COLOR_BG))

    -- the icon: same frame and colors for every block (e.g. with "All blocks"); its size is in Size
    local iconBox = A.Box(L.SECTION_ICON, { reset = true })
    iconBox.Add(Dropdown(a, L.ICON_SHAPE, {
        { key = "none", name = L.ICON_SHAPE_NONE },
        { key = "square", name = L.ICON_SHAPE_SQUARE },
        { key = "round", name = L.ICON_SHAPE_ROUND },
    }, "iconShape", L.TIP_ICON_SHAPE))
    iconBox.Add(Dropdown(a, L.ICON_SET, {
        { key = "classic", name = L.ICON_SET_CLASSIC },
        { key = "hd", name = L.ICON_SET_HD },
        { key = "hdTint", name = L.ICON_SET_HD_TINT },
    }, "iconSet", L.TIP_ICON_SET, function() return ns.HD_ICONS_ON end))
    iconBox.Add(Color(a, L.ICON_BORDER_COLOR, true, "iconBorderColor", L.TIP_ICON_BORDER_COLOR))
    iconBox.Add(Check(a, L.CLASS_COLOR_ICON, "classColorIcon", L.TIP_CLASS_COLOR_ICON), { half = true })
    iconBox.Add(Check(a, L.ICON_DESATURATE, "iconDesaturate", L.TIP_ICON_DESATURATE), { half = true })

    -- a little life: the edge lights up under the mouse, numbers count to their new value
    local lifeBox = A.Box(L.SECTION_LIFE, { reset = true })
    lifeBox.Add(Check(a, L.HOVER_GLOW, "hoverGlow", L.TIP_HOVER_GLOW), { half = true })
    lifeBox.Add(Check(a, L.VALUE_GLIDE, "valueGlide", L.TIP_VALUE_GLIDE), { half = true })

    local borderBox = A.Box(L.BORDER, { reset = true })
    -- picking a border also restores its original thickness
    local border = CreateDropdown(a, L.BORDER, function() return ns:GetMediaList("border") end,
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
        end, nil, nil, L.TIP_BORDER)
    borderBox.Add(border, { field = "border" })
    borderBox.Add(Slider(a, L.BORDER_SIZE, 1, 32, "borderSize", L.TIP_BORDER_SIZE))
    -- 2.0 borders: rounded corners or a plain line one screen pixel wide
    borderBox.Add(Dropdown(a, L.EDGE_SHAPE, {
        { key = "round", name = L.EDGE_SHAPE_ROUND },
        { key = "pixel", name = L.EDGE_SHAPE_PIXEL },
    }, "edgeShape", L.TIP_EDGE_SHAPE, function()
        local cfg = Cfg()
        return cfg and ns:FindMedia("border", cfg.border).hd and true or false
    end))

    -- Corner join: belongs to the border (not the block), with a reset to the original value
    local function CurrentBorder()
        local cfg = Cfg()
        return cfg and cfg.border
    end
    local function HasCorners()
        local bd = CurrentBorder()
        return bd and bd ~= "none" and bd ~= "solid"
    end
    local corner = CreateSlider(a, L.CORNER_JOIN, 0, 100, 1,
        function()
            local bd = CurrentBorder()
            return bd and math.floor(ns:GetBorderReach(bd) * 100 + 0.5) or 0
        end,
        function(v)
            local bd = CurrentBorder()
            if bd then ns:SetBorderReach(bd, v / 100) end
        end, HasCorners, L.TIP_CORNER_JOIN)
    local default = ns.Skin.Button(CreateFrame("Button", nil, corner, "UIPanelButtonTemplate"))
    default:SetSize(64, 18)
    default:SetPoint("RIGHT", corner.slider, "LEFT", -8, 0) -- between the label and the slider
    corner.labelW = ROW_LABEL_W - 80
    corner.label:SetWidth(corner.labelW)
    default:SetText(L.DEFAULT_SHORT)
    default:SetScript("OnClick", function()
        local bd = CurrentBorder()
        if bd then
            ns:SetBorderReach(bd, nil)
            ns:RefreshOptions()
        end
    end)
    AttachTip(default, L.DEFAULT_SHORT, L.TIP_CORNER_DEFAULT)
    local refreshCorner = corner.Refresh
    corner.Refresh = function(self)
        refreshCorner(self)
        local bd = CurrentBorder()
        default:SetEnabled(bd ~= nil and ns:HasCustomBorderReach(bd))
    end
    borderBox.Add(corner)
    borderBox.Add(Color(a, L.BORDER_COLOR, true, "borderColor", L.TIP_BORDER_COLOR))
    borderBox.Add(Check(a, L.CLASS_COLOR_BORDER, "classColorBorder", L.TIP_CLASS_COLOR_BORDER))

    -- thin lines between merged blocks: their color only matters when they are on
    local sepBox = A.Box(L.SECTION_SEPARATORS, { reset = true })
    sepBox.Add(Check(a, L.SEPARATORS, "separators", L.TIP_SEPARATORS))
    sepBox.Add(Color(a, L.SEPARATOR_COLOR, true, "separatorColor", L.TIP_SEPARATOR_COLOR), { parent = IsOn("separators") })
    sepBox.Add(Check(a, L.CLASS_COLOR_SEPARATOR, "classColorSeparator", L.TIP_CLASS_COLOR_SEPARATOR),
        { parent = IsOn("separators") })

    local layerBox = A.Box(L.BOX_OPACITY_LAYER, { reset = true })
    local getA, setA = Field("alpha")
    layerBox.Add(CreateSlider(a, L.OPACITY, 10, 100, 5,
        function() return math.floor((getA() or 1) * 100 + 0.5) end,
        function(v) setA(v / 100) end, nil, L.TIP_OPACITY), { field = "alpha" })
    layerBox.Add(Dropdown(a, L.STRATA, {
        { key = "BACKGROUND", name = L.STRATA_BACKGROUND },
        { key = "LOW", name = L.STRATA_LOW },
        { key = "MEDIUM", name = L.STRATA_MEDIUM },
        { key = "HIGH", name = L.STRATA_HIGH },
    }, "strata", L.TIP_STRATA))

    -- colors by level (green, yellow, red) and the progress bar, only for blocks that have a
    -- progress (or a group selection)
    local levelBox = A.Box(L.BOX_LEVELS, { reset = true })
    levelBox.Add(Check(a, L.COLORIZE, "colorize", L.TIP_COLORIZE), { half = true })
    levelBox.Add(Check(a, L.PROGRESS_BAR, "progressBar", L.TIP_PROGRESS_BAR, function()
        if IsGroup() then return true end
        local mod = ns:GetModule(S.selected)
        return mod and mod.progress ~= nil or false
    end), { half = true })
    -- the bar's look: a band behind the text, or a thin line under it
    levelBox.Add(Dropdown(a, L.PROGRESS_LOOK, {
        { key = "fill", name = L.PROGRESS_LOOK_FILL },
        { key = "thin", name = L.PROGRESS_LOOK_THIN },
    }, "progressLook", L.TIP_PROGRESS_LOOK, function()
        local cfg = Cfg()
        if not (cfg and cfg.progressBar) then return false end
        if IsGroup() then return true end
        local mod = ns:GetModule(S.selected)
        return mod and mod.progress ~= nil or false
    end))

    -- 3. Behaviour: when to show it, hover fade, clicks, alerts and thresholds
    local whenBox = B.Box(L.SECTION_WHEN, { reset = true })
    whenBox.Add(Check(b, L.HIDE_COMBAT, "hideInCombat", L.TIP_HIDE_COMBAT), { half = true })
    whenBox.Add(Check(b, L.HIDE_INSTANCE, "hideInInstance", L.TIP_HIDE_INSTANCE), { half = true })
    whenBox.Add(Check(b, L.HIDE_VEHICLE, "hideInVehicle", L.TIP_HIDE_VEHICLE), { half = true })
    whenBox.Add(Check(b, L.HIDE_RESTING, "hideWhenResting", L.TIP_HIDE_RESTING), { half = true })

    local fadeBox = B.Box(L.SECTION_FADE, { reset = true })
    local getF, setF = Field("fadeOut")
    fadeBox.Add(CreateCheck(b, L.FADE_OUT, getF, function(v)
        setF(v)
        ns:RefreshOptions()
    end, nil, L.TIP_FADE_OUT), { field = "fadeOut" })
    local getFA, setFA = Field("fadeAlpha")
    fadeBox.Add(CreateSlider(b, L.FADE_ALPHA, 0, 90, 5,
        function() return math.floor((getFA() or 0) * 100 + 0.5) end,
        function(v) setFA(v / 100) end, nil, L.TIP_FADE_ALPHA), { field = "fadeAlpha", parent = IsOn("fadeOut") })
    fadeBox.Add(Check(b, L.FADE_COMBAT, "fadeShowCombat", L.TIP_FADE_COMBAT), { parent = IsOn("fadeOut") })

    -- the group of the selected block: frozen, it keeps its place and takes no new block
    local placeBox = B.Box(L.SECTION_PLACEMENT)
    placeBox.Add(CreateCheck(b, L.FREEZE_GROUP,
        function() return ns:IsFrozen(S.selected) end,
        function(v)
            ns:SetFrozen(S.selected, v)
            ns:RefreshOptions()
        end, single, L.TIP_FREEZE_GROUP))

    local clicksBox = B.Box(L.SECTION_CLICKS, { reset = true })
    local clickShown = function() return not ns.IsForwardingKey(S.selected) and notSpacer() end
    local function Actions(withOpen)
        local list = {}
        if withOpen then table.insert(list, { key = "open", name = L.ACTION_OPEN }) end
        -- the block's own extra action (e.g. coordinates: place a map pin)
        local mod = not IsGroup() and ns:GetModule(S.selected)
        if mod and mod.extraAction then
            table.insert(list, { key = mod.extraAction.key, name = L[mod.extraAction.label] })
        end
        for _, act in ipairs({ { "none", L.ACTION_NONE }, { "chat", L.ACTION_CHAT },
                               { "options", L.ACTION_OPTIONS }, { "hide", L.ACTION_HIDE },
                               { "pin", L.ACTION_PIN } }) do
            table.insert(list, { key = act[1], name = act[2] })
        end
        return list
    end
    local getS, setS = Field("shiftClick")
    local getM, setM = Field("middleClick")
    clicksBox.Add(CreateDropdown(b, L.SHIFT_CLICK, function() return Actions(false) end, getS, setS,
        clickShown, nil, L.TIP_SHIFT_CLICK), { field = "shiftClick" })
    clicksBox.Add(CreateDropdown(b, L.MIDDLE_CLICK, function() return Actions(true) end, getM, function(v)
        setM(v)
        ns:RequestOverlaySync() -- the secure button listens to middle clicks only for "open"
    end, clickShown, nil, L.TIP_MIDDLE_CLICK), { field = "middleClick" })

    local alertBox = B.Box(L.BOX_ALERTS, { reset = true })
    alertBox.Add(Check(b, L.ALERT, "alert", L.TIP_ALERT, notSpacer))

    -- the block's own settings: what the value looks like (gold format, clock...), a spacer's
    -- type, text and line, what its tooltip shows, "Hide when empty", its thresholds
    local keys = { "spacer" }
    for _, key in ipairs(ns.order) do table.insert(keys, key) end
    BuildModuleOptions(keys, function(opt)
        if opt.where == "when" then return whenBox end
        if opt.where == "alerts" then return alertBox end
        return ownBox
    end)
    -- a group selection: its own settings belong to one block
    local pick = ownBox.Add(CreateNote(c, L.THIS_BLOCK_PICK))
    pick.isShown = IsGroup
    -- a pinned tooltip stays on the screen (last in the Tooltip box)
    local pin = tipBox.Add(CreateButton(c, L.MENU_PIN, function()
        ns:TogglePin(S.selected)
        ns:RefreshOptions()
    end, function() return named() and ns.CanPinTooltip and ns.CanPinTooltip(S.selected) or false end,
        COL_W - 8, L.TIP_PIN_BUTTON))
    pin.Refresh = function(self)
        self:SetText(ns.IsPinned and ns:IsPinned(S.selected) and L.MENU_UNPIN or L.MENU_PIN)
    end

    -- Opens a tab (the old sub-tabs, still used by the Look tab, the tour and the search):
    -- 1, 5 and 6 Content, 2 and 3 Appearance (at Text and at Background), 4 Behaviour
    local SUB_TAB = { 1, 2, 2, 3, 1, 1 }
    local SUB_BOX = { [2] = textBox, [3] = bgBox }
    local function ShowSub(index)
        local tab = SUB_TAB[index] or 1
        ShowTab(tab)
        ns:RefreshOptions()
        ScrollToBox(flows[tab].content, SUB_BOX[index])
    end
    ns.ShowBlockSub = ShowSub
    ns.ShowBlockTab = function(i)
        ShowTab(i)
        ns:RefreshOptions()
    end
    ns.blockTabs = { bar = tabBar, flows = flows } -- (tools/mock_run.lua)
    ShowTab(S.blockTab or 1)

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
        ShowSub(5) -- the spacer's settings (type, text, line): its own settings, in Content
        if ns.db.locked then ns:SetLocked(false) end
        ns:RefreshOptions()
    end, function() return not ns.IsForwardingKey(S.selected) and not isSpacer() end, bw, L.TIP_ADD_SPACER)
    table.insert(lastSlot, addSpacer)
    copyGroup.Refresh = function(self)
        local after = self:IsShown() and self or copy
        for _, btn in ipairs(lastSlot) do
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", after, "RIGHT", 12, 0)
        end
    end
    copyGroup:Refresh()
end

-- Shared with the files loaded after this one
Tools.BuildBlockPage = BuildBlockPage
Tools.BuildModuleOptions = BuildModuleOptions
Tools.SelectedModuleKey = SelectedModuleKey
Tools.SelectionOptions = SelectionOptions
Tools.SortKey = SortKey

