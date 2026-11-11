-- Options.lua
-- Tessera's options window and everything around it.
--
-- Main parts, in file order:
--   Selection        which block(s) the "Blocks" tab edits: all blocks, all launchers or one block;
--                    smart placement of newly shown blocks (PlaceNearOptions) and SetField,
--                    which writes a setting to every selected block and remembers it as a default.
--   Widgets          small widget factory (header, note, checkbox, slider, dropdown, action
--                    dropdown, color swatch, button). Every widget has a Refresh() method and a
--                    layoutHeight, and is registered so RefreshOptions() can update them all.
--   Column layout    NewLayout(): stacks widgets top-down in two columns.
--   Tab builders     BuildBlockPage (Display / Text / Frame sub-tabs), BuildGeneralPage,
--                    BuildLaunchersPage, BuildProfilesPage, BuildHelpPage.
--   Window           SkinWindow() themes a Tessera window (FlareUI or Blizzard look);
--                    BuildPanel() creates the main window and its tabs; Open/Toggle functions.
--   Blizzard page    a small page under Options > AddOns that opens the real options window.
--   Placement banner shown while blocks are unlocked; hides the options window meanwhile.
--   Welcome popup    shown once on first launch.
--   Debug report     /tessera debug: prints diagnostics and shows them in a copyable window.
--
-- Note: some debug messages below are intentionally left in French (they are string literals).

local ADDON, ns = ...
local L = ns.L

-- Options window tabs:
--   Blocks     selection (all blocks, all launchers or a single block) and its settings
--   Look       style, how groups look, ready-made layouts, screen edges
--   General    moving, combat, chat, minimap, accessibility
--   Launchers  add and edit launcher blocks and DataBroker blocks
--   Broker     share Tessera's blocks with DataBroker addons, DataBroker mode
--   Profiles   profiles and reset
--   Help       help topics (list on the left, selected topic on the right)
--   About      author, translators, license, links, and the changelog (same layout as Help)
-- In DataBroker mode (Broker.lua) only the Broker, Help and About tabs are shown.

local panel
local widgets = {}
local PAGE_BLOCKS, PAGE_LOOK, PAGE_GENERAL, PAGE_LAUNCHERS, PAGE_BROKER, PAGE_PROFILES, PAGE_HELP, PAGE_ABOUT =
    1, 2, 3, 4, 5, 6, 7, 8
local HIDDEN_IN_BROKER_MODE = { [PAGE_BLOCKS] = true, [PAGE_LOOK] = true, [PAGE_GENERAL] = true,
    [PAGE_LAUNCHERS] = true, [PAGE_PROFILES] = true }
local pages, tabs, currentPage = {}, {}, PAGE_BLOCKS

-- Layout: 720 px window, two 300 px columns, 40 px margins (scaled down on small
-- screens, see FitPanelToScreen)
-- The window: a navigation list on the left (like the game's own settings), the page on the
-- right. Pages keep their own coordinates (COL_X): only their frame moves.
local NAV_W = 176            -- navigation list, on the left
local PAGE_TOP = -64         -- top of the pages, under the title
ns.OPTIONS_PAGE_TOP = PAGE_TOP
local SEARCH_W = 200         -- search box, in the top bar
local HELP_W = 260           -- help panel, on the right (1.3): explains the setting under the mouse
local PANEL_W, PANEL_H = 720 + NAV_W + HELP_W, 780
local COL_W = 300
local COL_X = { 40, 380 }
local FULL_W = COL_X[2] + COL_W - COL_X[1]
local SPACING = 4 -- vertical space between two rows (each row has its own air, ROW_PAD)

local ALL = "*all"            -- selection value "All blocks"
local LAUNCHERS = "*launchers" -- selection value "All launchers"
local GROUP_PREFIX = "*group:" -- selection value of a group: the prefix, then its head block
local selected = ALL

---------------------------------------------------------------------------
-- Selection
---------------------------------------------------------------------------
-- Keys of all launcher blocks, in display order
local function LauncherKeys()
    local keys = {}
    for _, key in ipairs(ns:GetBlockKeys()) do
        if ns.IsLauncherKey(key) then table.insert(keys, key) end
    end
    return keys
end

-- Head block of the selected group of blocks (a bar and its rows), nil otherwise
local function GroupHead()
    if type(selected) == "string" and selected:sub(1, #GROUP_PREFIX) == GROUP_PREFIX then
        return selected:sub(#GROUP_PREFIX + 1)
    end
end

-- Members of a group that "All blocks"-like settings change: spacers keep their own look
local function GroupStyleKeys(head)
    local keys = {}
    for _, key in ipairs(ns:GetStyleGroup(head)) do
        if not ns.IsSpacerKey(key) then table.insert(keys, key) end
    end
    return keys
end

-- True when the selection is several blocks (all blocks, all launchers, one group)
-- rather than one block
local function IsGroup() return selected == ALL or selected == LAUNCHERS or GroupHead() ~= nil end

-- Blocks affected by a setting change
local function Targets()
    if selected == ALL then
        -- spacers keep their own look: "All blocks" does not change them
        -- (except their layer and visibility, see SPACER_SHARED_FIELDS)
        local keys = {}
        for _, key in ipairs(ns:GetBlockKeys()) do
            if not ns.IsSpacerKey(key) then table.insert(keys, key) end
        end
        return keys
    end
    if selected == LAUNCHERS then return LauncherKeys() end
    local head = GroupHead()
    if head then return GroupStyleKeys(head) end
    return { selected }
end

-- Block whose values are displayed (the first one of the selection)
local function Cfg()
    local key = Targets()[1]
    return key and ns.db.blocks[key]
end

-- Falls back to "All blocks" if the selected block or group no longer exists
local function ValidateSelection()
    if selected == ALL then return end
    if selected == LAUNCHERS then
        if #LauncherKeys() == 0 then selected = ALL end
        return
    end
    local head = GroupHead()
    if head then
        -- the group keeps its entry when its head changes (a block merged on its left)
        if ns.db.blocks[head] then head = ns:GetVisualRoot(head) end
        selected = (ns.db.blocks[head] and #GroupStyleKeys(head) >= 2) and (GROUP_PREFIX .. head) or ALL
        return
    end
    if not ns.db.blocks[selected] then selected = ALL end
end

-- State used by PlaceNearOptions: a counter for the fallback position, and the areas
-- of blocks placed during the last second (cleared by a timer)
local placedCount = 0
local recentPlaced, recentTimer = {}, nil

-- Does a block's saved position overlap another visible block?
function ns:OverlapsOtherBlock(key)
    local cfg, f = ns.db.blocks[key], ns.frames[key]
    if not cfg or not cfg.point or not f then return false end
    local ratio = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local l, b, r, t = ns:PointToRect(cfg.point, f:GetWidth() > 1 and f:GetWidth() or cfg.width or 60,
        cfg.height or 24, ratio)
    for k, o in pairs(ns.frames) do
        if k ~= key and o:IsShown() then
            local ol, ob, or_, ot = ns:GetRectUI(o)
            if ol and l < or_ - 2 and r > ol + 2 and b < ot - 2 and t > ob + 2 then return true end
        end
    end
    return false
end

-- Places a block that appears (never placed, or its old spot is taken) in a free
-- spot next to the options window: columns alternate right / left of the window,
-- nearest first, each scanned top to bottom. All maths in UIParent units.
function ns:PlaceNearOptions(key)
    local cfg = ns.db.blocks[key]
    if not cfg then return end
    cfg.dock, cfg.anchor = nil, nil
    -- real block width (text included): shown off-screen for a moment to measure it
    cfg.point = { "TOPLEFT", "BOTTOMLEFT", -2000, -2000 }
    ns:ApplyStyle(key)
    ns:UpdateBlock(key)
    local f = ns.frames[key]
    if not f then return end
    local ratio = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local needed = 0
    if f.text then
        local tw = f.text.GetUnboundedStringWidth and f.text:GetUnboundedStringWidth() or f.text:GetStringWidth()
        needed = math.ceil(tw or 0) + 8 + 2 * (f.inset or 0) + (cfg.showIcon and ((f.iconSize or 0) + 4) or 0)
    end
    local width = math.max(cfg.width or 60, needed, 100) * ratio
    local height = (cfg.height or 24) * ratio
    local step = height + 22 -- room for the block name above it
    local screenW = UIParent:GetWidth()

    -- areas already taken: visible blocks, blocks placed in the same click (the game
    -- has not recomputed their position yet), the options window
    local taken = {}
    for k, o in pairs(ns.frames) do
        if k ~= key and o:IsShown() and not recentPlaced[k] then
            local l, b, r, t = ns:GetRectUI(o)
            if l then table.insert(taken, { l, b, r, t + 18 }) end
        end
    end
    for k, z in pairs(recentPlaced) do
        if k ~= key then table.insert(taken, z) end
    end
    local pl, pb, pr, pt
    if panel and panel:IsShown() then
        pl, pb, pr, pt = ns:GetRectUI(panel)
        if pl then table.insert(taken, { pl, pb, pr, pt }) end
    end
    -- Blizzard's action bars, minimap, chat...: a block placed on them could be hidden
    for _, z in ipairs(ns:GetBlizzardRects()) do table.insert(taken, z) end
    local function Free(x, y)
        local l, b, r, t = x - 4, y - height - 4, x + width + 4, y + 18
        for _, z in ipairs(taken) do
            if l < z[3] and r > z[1] and b < z[4] and t > z[2] then return false end
        end
        return true
    end

    -- candidate columns: right 1, left 1, right 2, left 2... (around the screen
    -- center when the options window is closed)
    local right0, left0, top
    if pl then
        right0, left0, top = pr + 20, pl - 20 - width, pt - 20
    else
        right0 = screenW / 2 + 10
        left0 = screenW / 2 - 10 - width
        top = UIParent:GetHeight() / 2 + 160
    end
    -- highest free slot of a column, above the bottom of the screen (action bars area)
    local BOTTOM = 140
    local function FirstFree(cx)
        if not cx then return nil end
        for row = 0, math.floor((top - height - BOTTOM) / step) do
            local cy = top - row * step
            if Free(cx, cy) then return cy end
        end
    end
    -- columns go in pairs (right n, left n): the side with the higher free slot wins, so
    -- both sides of the window fill up evenly instead of one long column on the right
    local x, y
    for i = 0, 12 do
        local rx, lx = right0 + i * (width + 16), left0 - i * (width + 16)
        local ry = (rx + width <= screenW) and FirstFree(rx) or nil
        local ly = (lx >= 0) and FirstFree(lx) or nil
        if ry and (not ly or ry >= ly) then
            x, y = rx, ry
        elseif ly then
            x, y = lx, ly
        end
        if x then break end
    end
    if not x then -- screen full: fallback position
        x, y = math.max(0, math.min(right0, screenW - width)), top - (placedCount % 10) * step
    end
    placedCount = placedCount + 1
    recentPlaced[key] = { x, y - height, x + width, y + 18 }
    if not recentTimer then
        recentTimer = true
        C_Timer.After(1, function()
            recentTimer = nil
            wipe(recentPlaced)
        end)
    end
    cfg.point = ns:MakeRelativePoint(x, y - height, x + width, y, ratio)
    ns:ApplyStyle(key)
end

function ns:RefreshOptions()
    if not panel then return end
    ValidateSelection()
    for _, w in ipairs(widgets) do
        if w.isShown then
            local shown = w.isShown() and true or false
            w:SetShown(shown)
            if w.check then w.check:SetShown(shown) end -- a check box follows its row
        end
        if w.Refresh then w:Refresh() end
    end
    if ns.RelayoutBlockOptions then ns.RelayoutBlockOptions() end
    if ns.ReflowOptionLayouts then ns.ReflowOptionLayouts() end -- folded sections, column 2
end

-- Per-block settings, never stored as defaults for other blocks
local PER_BLOCK_FIELDS = { enabled = true, width = true, height = true }

-- Writes a setting to every selected block. Newly shown blocks get a style and a
-- free position; group changes are also saved as defaults for future blocks.
-- Settings that "All blocks" also gives to spacers: a spacer keeps its own look
-- (colors, frame), but it must stay on the same layer as the blocks around it, and
-- show, hide and fade with them
local SPACER_SHARED_FIELDS = {
    strata = true, alpha = true, fadeOut = true, fadeAlpha = true, fadeShowCombat = true,
    hideInCombat = true, hideInInstance = true, hideInVehicle = true, hideWhenResting = true,
}

-- Puts blocks on the screen or takes them off it ("On screen" checkbox). Undoable.
--   * off: each block leaves its group (the blocks around it close the gap) and keeps
--     its look and settings;
--   * on: a block with no place appears next to the options window; one that was never
--     on screen takes the look of the reference block, one that comes back keeps its own.
function ns:SetBlocksOnScreen(keys, on)
    local refKey = on and self:GetReferenceBlock()
    self:PushUndo()
    local regroup = false
    for _, key in ipairs(keys) do
        local cfg = self.db.blocks[key]
        if cfg then
            if on and not cfg.enabled then
                cfg.enabled = true
                if not cfg.point and not cfg.dock and not cfg.anchor then
                    if not cfg.keepLook and refKey and refKey ~= key then self:AdoptReferenceStyle(key, refKey) end
                    self:PlaceNearOptions(key)
                elseif not cfg.dock and not cfg.anchor and self:OverlapsOtherBlock(key) then
                    self:PlaceNearOptions(key) -- its old spot is taken: find a free one
                end
            elseif not on and cfg.enabled then
                if ns.LeaveGroupData(self.db.blocks, key) then regroup = true end
                cfg.enabled = false
                cfg.keepLook = true
            end
            self:ApplyStyle(key)
        end
    end
    if regroup then
        self:RefreshAllBlocks()
        self:RequestLayout()
    end
end

-- Taking several blocks off the screen at once (a group, "All blocks") asks first
StaticPopupDialogs["TESSERA_REMOVE_BLOCKS"] = {
    text = L.REMOVE_BLOCKS_CONFIRM,
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, keys)
        ns:SetBlocksOnScreen(keys, false)
        if ns.RefreshOptions then ns:RefreshOptions() end
    end,
    OnCancel = function() if ns.RefreshOptions then ns:RefreshOptions() end end,
}

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
    if (selected == ALL or GroupHead()) and SPACER_SHARED_FIELDS[name] then
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
        if selected == ALL then ns.db.groupDefaults[name] = ns.DeepCopy(value) end
        if selected == ALL or selected == LAUNCHERS then
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
    holder:SetSize(FULL_W, 30) -- room above the text: sections stand apart
    local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("BOTTOMLEFT", 0, 5)
    fs:SetText(text)
    local line = holder:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.4)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    holder.Refresh = function() end
    holder.layoutHeight = 34
    holder.isHeader, holder.headerText = true, text
    return Register(holder)
end

-- Section that folds: a header with a + / - button (a shape, not only a color).
-- The rows placed under it, up to the next header of the same column, hide when it
-- is folded and the rows below move up (see NewLayout). Not saved: decided per page.
local function CreateSection(parent, text, folded)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(FULL_W, 30)
    local sign = b:CreateTexture(nil, "ARTWORK")
    sign:SetSize(16, 16)
    sign:SetPoint("BOTTOMLEFT", 0, 5)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", sign, "RIGHT", 6, 0)
    fs:SetText(text)
    local line = b:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.4)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    b.hover = b:CreateTexture(nil, "BACKGROUND")
    b.hover:SetAllPoints()
    b.hover:SetColorTexture(1, 1, 1, 0.08)
    b.hover:Hide()
    b:SetScript("OnEnter", function(self) self.hover:Show() end)
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
    b.layoutHeight = 34
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
    local folded = { 0, 0 }  -- height hidden by folded sections in each column
    local used = {}
    local section = {}       -- current section title of each column
    local layout = {}
    local anchor = CreateFrame("Frame", nil, page)
    anchor:SetSize(1, 1)

    -- lowest virtual y of a column: its shown widgets (two can share a slot, the one
    -- shown counts) and its option stacks; nothing shown: its top
    local function Low(col)
        local low = packed[col] or top0
        for _, it in ipairs(items[col]) do
            if not it.w.foldedAway and it.w:IsShown() then
                low = math.min(low, it.vy - it.w.layoutHeight - SPACING)
            end
        end
        return low
    end

    -- y of column 2's anchor; the lowest point of the page
    local function Settle()
        local ay = 0
        if used[1] then ay = Low(1) + folded[1] - COLUMN_GAP - top0 end
        anchor:ClearAllPoints()
        anchor:SetPoint("TOPLEFT", page, "TOPLEFT", 0, ay)
        local lowest = used[2] and (ay + Low(2) + folded[2]) or (Low(1) + folded[1])
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
        if w.optionLabel then
            table.insert(ns.optionRows, { frame = w, label = w.optionLabel, tip = w.optionTip,
                kind = w.optionKind, page = page.pageIndex, sub = page.subIndex, section = section[col],
                content = page, block = layout.currentBlock })
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
    -- lowest virtual y of the shown widgets of a column's option stacks
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
                if w.isHeader then
                    layout.Point(w, col, it.vy + shift)
                    current = nil
                    if w.isSection and w.folded and w:IsShown() then
                        local nextVy = Low(col)
                        for j = idx + 1, #list do
                            if list[j].w.isHeader then nextVy = list[j].vy break end
                        end
                        local hidden = (it.vy - w.layoutHeight - SPACING) - nextVy
                        if hidden > 0 then
                            current = w
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
            folded[col] = shift
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
    table.insert(list, { isTitle = true, name = L.DATA_BLOCKS })
    -- data blocks in alphabetical order of their (translated) name, whatever the
    -- order they were registered in; then launchers and spacers, as GetBlockKeys sorts them
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
    local launchersTitle, brokersTitle, spacersTitle = false, false, false
    for _, key in ipairs(keys) do
        if ns.IsLauncherKey(key) and not launchersTitle then
            launchersTitle = true
            table.insert(list, { isTitle = true, name = L.LAUNCHERS })
        end
        if ns.IsBrokerKey(key) and not brokersTitle then
            brokersTitle = true
            table.insert(list, { isTitle = true, name = L.BROKERS })
        end
        if ns.IsSpacerKey(key) and not spacersTitle then
            spacersTitle = true
            table.insert(list, { isTitle = true, name = L.SPACERS })
        end
        -- shown blocks are easy to spot: a green dot; the others are greyed
        local cfg = ns.db.blocks[key]
        local name = ns:GetBlockName(key)
        if cfg and cfg.enabled then
            name = "|TInterface\\COMMON\\Indicator-Green:14:14|t " .. name
        else
            name = "|cff8c8c8c" .. name .. "|r"
        end
        table.insert(list, { key = key, name = name })
    end
    return list
end

-- Module key of the selection ("spacer" for every spacer), nil for a group, a
-- launcher or a DataBroker block (they have no module options)
local function SelectedModuleKey()
    if IsGroup() then return nil end
    if ns.IsSpacerKey(selected) then return "spacer" end
    if ns.IsForwardingKey(selected) then return nil end
    return selected
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
                    ns:ApplyStyle(selected)
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
        P.SetPacked(col, low)
    end)
    return hasOptions
end

local blockSub = 5 -- open sub-tab: 5 This block (first), 1 Display, 2 Text, 3 Frame, 4 Behaviour

-- Builds the "Blocks" tab: selection dropdown, three sub-tabs and single-block actions
local function BuildBlockPage(page)
    local single = function() return not IsGroup() end
    local isLauncher = function() return ns.IsLauncherKey(selected) end

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

    -- Block selection, full width
    local top = NewLayout(page)
    local ShowSub -- defined below (sub-tabs); a spacer's settings are in "This block"
    local REPLACE_W = 140
    local selection = CreateDropdown(page, L.SELECTION, SelectionOptions,
        function() return selected end,
        function(v)
            selected = v
            if ns.IsSpacerKey(v) and ShowSub then ShowSub(5) end
            ns:RefreshOptions()
        end, nil, FULL_W - REPLACE_W, L.TIP_SELECTION)
    top.Place(selection, 1)
    -- "Replace with...": another block takes the selected block's place
    local replace = CreateButton(page, L.REPLACE_BLOCK, function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        ns:OpenReplaceMenu(selected, self)
    end, function() return single() and ns.db.blocks[selected] ~= nil end, REPLACE_W - 8, L.TIP_REPLACE_BLOCK)
    replace:SetPoint("BOTTOMLEFT", selection, "BOTTOMRIGHT", 0, 1)
    top.Place(CreateNote(page, L.GROUP_HINT, FULL_W), 1)

    -- Sub-tabs
    local subY = top.Bottom(1) - 4
    local subs, buttons, contents = {}, {}, {}
    ShowSub = function(index)
        blockSub = index
        for i, sub in ipairs(subs) do
            sub:SetShown(i == index)
            buttons[i]:SetEnabled(i ~= index)
        end
    end
    -- index = what the code refers to (saved in blockSub); order = where the button sits:
    -- "This block" (5) comes first, everything the selected block has of its own
    local subNames = { L.SUB_DISPLAY, L.SUB_TEXT, L.SUB_FRAME, L.SUB_BEHAVIOUR, L.SUB_THIS_BLOCK }
    local SUB_ORDER = { 5, 1, 2, 3, 4 }
    local subW = (FULL_W - 6 * (#subNames - 1)) / #subNames
    for i, text in ipairs(subNames) do
        local slot = 1
        for n, index in ipairs(SUB_ORDER) do if index == i then slot = n end end
        local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        b:SetSize(subW, 22)
        b:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[1] + (slot - 1) * (subW + 6), subY)
        b:SetText(text)
        b:SetScript("OnClick", function() ShowSub(i) end)
        buttons[i] = b
        local sub = CreateFrame("Frame", nil, page)
        sub:SetPoint("TOPLEFT", page, "TOPLEFT", 0, subY - 36)
        sub.layoutBase = subY - 36
        sub:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 56)
        sub.pageIndex, sub.subIndex = page.pageIndex, i
        subs[i] = sub
        contents[i] = ScrollArea(sub) -- the sub-tab scrolls (one column of rows)
    end
    local line = page:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[1], subY - 28)
    line:SetPoint("TOPRIGHT", page, "TOPLEFT", COL_X[1] + FULL_W, subY - 28)

    -- 1. Display: what is shown, and the size
    do
        local sub = contents[1]
        local P = NewLayout(sub)
        P.Place(CreateHeader(sub, L.SECTION_DISPLAY), 1)
        local spacerNote = P.Place(CreateNote(sub, L.SPACER_SETTINGS_HINT), 1)
        spacerNote.isShown = function() return ns.IsSpacerKey(selected) end
        P.Place(Check(sub, L.ENABLED, "enabled", L.TIP_ENABLED), 1)
        P.Place(Check(sub, L.SHOW_LABEL, "showLabel", L.TIP_SHOW_LABEL), 1)
        P.Place(Check(sub, L.SHOW_VALUE, "showValue", L.TIP_SHOW_VALUE), 1)
        P.Place(Check(sub, L.SHOW_ICON, "showIcon", L.TIP_SHOW_ICON), 1)
        P.Place(Check(sub, L.SHOW_TOOLTIP, "tooltip", L.TIP_SHOW_TOOLTIP), 1)
        P.Place(Check(sub, L.COLORIZE, "colorize", L.TIP_COLORIZE), 1)
        -- progress bar: only for blocks that have a progress (or a group selection)
        local getP, setP = Field("progressBar")
        P.Place(CreateCheck(sub, L.PROGRESS_BAR, getP, setP, function()
            if IsGroup() then return true end
            local mod = ns:GetModule(selected)
            return mod and mod.progress ~= nil or false
        end, L.TIP_PROGRESS_BAR), 1)
        P.Gap(1, 6)
        local getA, setA = Field("alpha")
        P.Place(CreateSlider(sub, L.OPACITY, 10, 100, 5,
            function() return math.floor((getA() or 1) * 100 + 0.5) end,
            function(v) setA(v / 100) end, nil, L.TIP_OPACITY), 1)
        P.Place(Dropdown(sub, L.STRATA, {
            { key = "BACKGROUND", name = L.STRATA_BACKGROUND },
            { key = "LOW", name = L.STRATA_LOW },
            { key = "MEDIUM", name = L.STRATA_MEDIUM },
            { key = "HIGH", name = L.STRATA_HIGH },
        }, "strata", L.TIP_STRATA), 1)

        P.Place(CreateHeader(sub, L.SECTION_SIZE), 2)
        P.Place(Check(sub, L.AUTO_WIDTH, "autoWidth", L.AUTO_WIDTH_TIP), 2)
        local sizeNote = P.Place(CreateNote(sub, L.SIZE_GROUP_HINT), 2)
        sizeNote.isShown = IsGroup
        -- a group selection shows the note in place of the sliders (same slot)
        P.Gap(2, -(sizeNote.layoutHeight + SPACING))
        P.Place(Slider(sub, L.WIDTH, 16, 600, "width", L.TIP_WIDTH, single), 2)
        P.Place(Slider(sub, L.HEIGHT, 10, 100, "height", L.TIP_HEIGHT, single), 2)
        -- scale of the whole merged group the block belongs to (stored on its root)
        P.Place(CreateSlider(sub, L.GROUP_SCALE, 50, 300, 5,
            function()
                local root = not IsGroup() and ns.db.blocks[ns:GetRoot(selected)]
                return math.floor(((root and root.scale) or 1) * 100 + 0.5)
            end,
            function(v) if not IsGroup() then ns:SetGroupScale(selected, v / 100) end end,
            single, L.TIP_GROUP_SCALE), 2)
    end

    -- 2. Text
    do
        local sub = contents[2]
        local P = NewLayout(sub)
        P.Place(CreateHeader(sub, L.SECTION_TEXT), 1)
        P.Place(Dropdown(sub, L.FONT, function() return ns:GetMediaList("font") end, "font", L.TIP_FONT), 1)
        P.Place(Slider(sub, L.FONT_SIZE, 6, 32, "fontSize", L.TIP_FONT_SIZE), 1)
        P.Place(Dropdown(sub, L.OUTLINE, {
            { key = "NONE", name = L.OUTLINE_NONE },
            { key = "OUTLINE", name = L.OUTLINE_THIN },
            { key = "THICKOUTLINE", name = L.OUTLINE_THICK },
        }, "outline", L.TIP_OUTLINE), 1)
        P.Place(Check(sub, L.TEXT_SHADOW, "textShadow", L.TIP_TEXT_SHADOW), 1)

        P.Place(CreateHeader(sub, L.SECTION_LAYOUT_TEXT), 2)
        P.Place(Dropdown(sub, L.JUSTIFY, {
            { key = "LEFT", name = L.LEFT },
            { key = "CENTER", name = L.CENTER },
            { key = "RIGHT", name = L.RIGHT },
        }, "justify", L.TIP_JUSTIFY), 2)
        P.Place(Color(sub, L.TEXT_COLOR, false, "textColor", L.TIP_TEXT_COLOR), 2)
        P.Place(Check(sub, L.CLASS_COLOR_TEXT, "classColorText", L.TIP_CLASS_COLOR_TEXT), 2)

    end

    -- 3. Frame: background on the left, border on the right
    do
        local sub = contents[3]
        local P = NewLayout(sub)
        P.Place(CreateHeader(sub, L.BACKGROUND), 1)
        P.Place(Dropdown(sub, L.BACKGROUND, function() return ns:GetMediaList("background") end, "bg", L.TIP_BACKGROUND), 1)
        P.Place(Color(sub, L.BG_COLOR, true, "bgColor", L.TIP_BG_COLOR), 1)
        P.Place(Check(sub, L.CLASS_COLOR_BG, "classColorBg", L.TIP_CLASS_COLOR_BG), 1)

        -- the icon: same size, frame and colors for every block (e.g. with "All blocks")
        P.Gap(1, 8)
        P.Place(CreateHeader(sub, L.SECTION_ICON), 1)
        P.Place(Slider(sub, L.ICON_SIZE, 0, 200, "iconSize", L.TIP_ICON_SIZE), 1)
        P.Place(Dropdown(sub, L.ICON_SHAPE, {
            { key = "none", name = L.ICON_SHAPE_NONE },
            { key = "square", name = L.ICON_SHAPE_SQUARE },
            { key = "round", name = L.ICON_SHAPE_ROUND },
        }, "iconShape", L.TIP_ICON_SHAPE), 1)
        P.Place(Color(sub, L.ICON_BORDER_COLOR, true, "iconBorderColor", L.TIP_ICON_BORDER_COLOR), 1)
        P.Place(Check(sub, L.CLASS_COLOR_ICON, "classColorIcon", L.TIP_CLASS_COLOR_ICON), 1)
        P.Place(Check(sub, L.ICON_DESATURATE, "iconDesaturate", L.TIP_ICON_DESATURATE), 1)

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
        local refresh = corner.Refresh
        corner.Refresh = function(self)
            refresh(self)
            local b = CurrentBorder()
            default:SetEnabled(b ~= nil and ns:HasCustomBorderReach(b))
        end
        P.Place(corner, 2)
        P.Place(Color(sub, L.BORDER_COLOR, true, "borderColor", L.TIP_BORDER_COLOR), 2)
        P.Place(Check(sub, L.CLASS_COLOR_BORDER, "classColorBorder", L.TIP_CLASS_COLOR_BORDER), 2)
        -- thin lines between merged blocks
        P.Gap(2, 8)
        P.Place(CreateHeader(sub, L.SECTION_SEPARATORS), 2)
        P.Place(Check(sub, L.SEPARATORS, "separators", L.TIP_SEPARATORS), 2)
        P.Place(Color(sub, L.SEPARATOR_COLOR, true, "separatorColor", L.TIP_SEPARATOR_COLOR), 2)
        P.Place(Check(sub, L.CLASS_COLOR_SEPARATOR, "classColorSeparator", L.TIP_CLASS_COLOR_SEPARATOR), 2)
    end

    -- 4. Behaviour: settings specific to the selected block (left), visibility and
    -- clicks (right)
    do
        local sub = contents[4]
        local P = NewLayout(sub)
        P.Place(CreateHeader(sub, L.SECTION_VISIBILITY), 1)
        P.Place(Check(sub, L.HIDE_COMBAT, "hideInCombat", L.TIP_HIDE_COMBAT), 1)
        P.Place(Check(sub, L.HIDE_INSTANCE, "hideInInstance", L.TIP_HIDE_INSTANCE), 1)
        P.Place(Check(sub, L.HIDE_VEHICLE, "hideInVehicle", L.TIP_HIDE_VEHICLE), 1)
        P.Place(Check(sub, L.HIDE_RESTING, "hideWhenResting", L.TIP_HIDE_RESTING), 1)
        -- right column: hover fade, clicks, alerts, tooltip
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

        P.Gap(2, 6)
        local notSpacer = function() return not ns.IsSpacerKey(selected) end
        P.Place(Check(sub, L.ALERT, "alert", L.TIP_ALERT), 2).isShown = notSpacer
        P.Place(Dropdown(sub, L.TOOLTIP_ANCHOR, {
            { key = "auto", name = L.TOOLTIP_AUTO },
            { key = "top", name = L.TOOLTIP_TOP },
            { key = "bottom", name = L.TOOLTIP_BOTTOM },
        }, "tooltipAnchor", L.TIP_TOOLTIP_ANCHOR), 2).isShown = notSpacer
    end

    -- 5. This block (first button): everything the selected block has of its own: what it
    -- shows and its settings (left), its name, its clicks and its pinned tooltip (right).
    -- A group selection ("All blocks") gets a note: these settings belong to one block.
    do
        local sub = contents[5]
        local P = NewLayout(sub)
        local notSpacer = function() return not ns.IsSpacerKey(selected) end
        P.Place(CreateHeader(sub, L.SECTION_THIS_BLOCK), 1)
        local pick = P.Place(CreateNote(sub, L.THIS_BLOCK_PICK), 1)
        pick.isShown = IsGroup
        local none = P.Place(CreateNote(sub, L.NO_BLOCK_OPTIONS), 1)
        P.Gap(1, -(pick.layoutHeight + none.layoutHeight + 2 * SPACING))
        -- what the value looks like (gold format, clock...), then the block's own settings
        local keys = {}
        for _, key in ipairs(ns.order) do table.insert(keys, key) end
        -- (one stack per block: two builds in the same column would draw over each other)
        local hasOptions = BuildModuleOptions(sub, P, 1, keys, nil, function() return true end)
        none.isShown = function()
            local key = SelectedModuleKey()
            return not IsGroup() and not (key and (hasOptions[key] or key == "spacer"))
        end
        -- a spacer's settings (type, text, line): right column, in place of the clicks
        BuildModuleOptions(sub, P, 2, { "spacer" })

        -- right column: the name, the clicks, the pinned tooltip
        local named = function() return not IsGroup() and notSpacer() end
        P.Place(CreateHeader(sub, L.CUSTOM_NAME), 2).isShown = named
        local getN = Field("customName")
        P.Place(CreateEditBox(sub, L.CUSTOM_NAME, getN, function(v)
            v = type(v) == "string" and strtrim(v) or ""
            SetField("customName", v ~= "" and v or nil)
        end, named, L.TIP_CUSTOM_NAME), 2)
        P.Gap(2, 6)
        local clicksHeader = P.Place(CreateHeader(sub, L.SECTION_CLICKS), 2)
        local clickShown = function() return not ns.IsForwardingKey(selected) and notSpacer() end
        local getS, setS = Field("shiftClick")
        local getM, setM = Field("middleClick")
        local function Actions(withOpen)
            local list = {}
            if withOpen then table.insert(list, { key = "open", name = L.ACTION_OPEN }) end
            -- the block's own extra action (e.g. coordinates: place a map pin)
            local mod = not IsGroup() and ns:GetModule(selected)
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
        P.Gap(2, 6)
        local pin = P.Place(CreateButton(sub, L.MENU_PIN, function()
            ns:TogglePin(selected)
            ns:RefreshOptions()
        end, function() return named() and ns.CanPinTooltip and ns.CanPinTooltip(selected) or false end,
            COL_W - 8, L.TIP_PIN_BUTTON), 2)
        -- the header only when a click setting or the pin button is under it
        -- (a DataBroker block keeps its own clicks)
        clicksHeader.isShown = function() return clickShown() or pin.isShown() end
        pin.Refresh = function(self)
            self:SetText(ns.IsPinned and ns:IsPinned(selected) and L.MENU_UNPIN or L.MENU_PIN)
        end
    end

    ShowSub(blockSub)
    ns.ShowBlockSub = ShowSub

    -- Single-block actions, at the bottom (four slots; "Copy to group" only for a
    -- block in a group, the fourth button takes its slot otherwise)
    local bw = math.floor((FULL_W - 3 * 12) / 4)
    local reset = CreateButton(page, L.RESET_BLOCK, function()
        ns:ResetBlock(selected)
        ns:RefreshOptions()
    end, single, bw, L.TIP_RESET_BLOCK)
    reset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1], 22)

    local copy = CreateButton(page, L.COPY_STYLE, function()
        ns:CopyStyleToAll(selected)
    end, single, bw, L.TIP_COPY_STYLE)
    copy:SetPoint("LEFT", reset, "RIGHT", 12, 0)

    local inGroup = function() return single() and #ns:GetStyleGroup(selected) >= 2 end
    local copyGroup = CreateButton(page, L.COPY_STYLE_GROUP, function()
        ns:CopyStyleToGroup(selected)
    end, inGroup, bw, L.TIP_COPY_STYLE_GROUP)
    copyGroup:SetPoint("LEFT", copy, "RIGHT", 12, 0)
    local lastSlot = {} -- buttons of the last slot, placed after "Copy to group" when it is shown

    -- third slot: remove the launcher / the spacer, or add a spacer
    local isSpacer = function() return ns.IsSpacerKey(selected) end
    local remove = CreateButton(page, L.REMOVE_LAUNCHER, function()
        ns:RemoveLauncher(selected)
        ns:RefreshOptions()
    end, isLauncher, bw, L.TIP_REMOVE_LAUNCHER)
    table.insert(lastSlot, remove)
    local removeSpacer = CreateButton(page, L.REMOVE_SPACER, function()
        ns:RemoveSpacer(selected)
        ns:RefreshOptions()
    end, isSpacer, bw, L.TIP_REMOVE_SPACER)
    table.insert(lastSlot, removeSpacer)
    local removeBroker = CreateButton(page, L.REMOVE_BROKER, function()
        ns:RemoveBroker(selected)
        ns:RefreshOptions()
    end, function() return ns.IsBrokerKey(selected) end, bw, L.TIP_REMOVE_BROKER)
    table.insert(lastSlot, removeBroker)
    local addSpacer = CreateButton(page, L.ADD_SPACER, function()
        selected = ns:AddSpacer()
        ns:PlaceNearOptions(selected)
        ShowSub(5) -- the spacer's settings (type, text, line) are in "This block"
        if ns.db.locked then ns:SetLocked(false) end
        ns:RefreshOptions()
    end, function() return not ns.IsForwardingKey(selected) and not isSpacer() end, bw, L.TIP_ADD_SPACER)
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

---------------------------------------------------------------------------
-- "General" tab
---------------------------------------------------------------------------
-- Builds the "General" tab: global settings shared by all blocks
local function BuildGeneralPage(page)
    page = ScrollArea(page, 16)
    local P = NewLayout(page)
    local function Place(w, col) return P.Place(w, col) end

    -- Left column: moving
    Place(CreateHeader(page, L.SECTION_MOVE), 1)
    Place(CreateCheck(page, L.LOCKED,
        function() return ns.db.locked end,
        function(v) ns:SetLocked(v) end, nil, L.TIP_LOCKED), 1)
    Place(CreateCheck(page, L.SNAP,
        function() return ns.db.snap end,
        function(v) ns.db.snap = v end, nil, L.TIP_SNAP), 1)
    Place(CreateCheck(page, L.SNAP_BLIZZARD,
        function() return ns.db.snapBlizzard end,
        function(v) ns.db.snapBlizzard = v end, nil, L.TIP_SNAP_BLIZZARD), 1)
    Place(CreateCheck(page, L.EDIT_MODE_SYNC,
        function() return ns.db.editModeSync ~= false end,
        function(v) ns.db.editModeSync = v end, nil, L.TIP_EDIT_MODE_SYNC), 1)
    Place(CreateDropdown(page, L.GRID, {
        { key = 0, name = L.GRID_OFF },
        { key = 8, name = "8 px" },
        { key = 16, name = "16 px" },
        { key = 32, name = "32 px" },
    }, function() return ns.db.grid or 0 end,
       function(v) ns.db.grid = v; ns:UpdateGrid() end, nil, nil, L.TIP_GRID), 1)
    Place(CreateButton(page, L.RECOVER_BUTTON, function() ns:RecoverBlocksCommand() end,
        nil, nil, L.TIP_RECOVER), 1)

    -- Left column: tooltips of the blocks
    P.Gap(1, 8)
    Place(CreateHeader(page, L.SECTION_TOOLTIPS), 1)
    Place(CreateCheck(page, L.TOOLTIP_HINTS,
        function() return ns.db.tooltipHints ~= false end,
        function(v) ns.db.tooltipHints = v end, nil, L.TIP_TOOLTIP_HINTS), 1)
    Place(CreateCheck(page, L.TOOLTIP_IN_COMBAT,
        function() return ns.db.tooltipInCombat end,
        function(v) ns.db.tooltipInCombat = v end, nil, L.TOOLTIP_IN_COMBAT_TIP), 1)
    Place(CreateCheck(page, L.TOOLTIP_ALT_ONLY,
        function() return ns.db.tooltipAltOnly end,
        function(v) ns.db.tooltipAltOnly = v or false end, nil, L.TIP_TOOLTIP_ALT_ONLY), 1)
    Place(CreateSlider(page, L.TOOLTIP_SCALE, 50, 150, 5,
        function() return math.floor((ns.db.tooltipScale or 1) * 100 + 0.5) end,
        function(v) ns.db.tooltipScale = v / 100 end, nil, L.TIP_TOOLTIP_SCALE), 1)

    P.Gap(1, 8)
    Place(CreateHeader(page, L.SECTION_STREAMER), 1)
    Place(CreateCheck(page, L.STREAMER_MODE,
        function() return ns:IsStreamer() end,
        function(v) ns:SetStreamerMode(v) end, nil, L.TIP_STREAMER_MODE), 1)
    Place(CreateNote(page, L.STREAMER_NOTE), 1)

    -- Right column: combat
    Place(CreateHeader(page, L.SECTION_COMBAT), 2)
    Place(CreateCheck(page, L.LOCK_IN_COMBAT,
        function() return ns.db.lockInCombat end,
        function(v) ns.db.lockInCombat = v; ns:RefreshLockState() end, nil, L.LOCK_IN_COMBAT_TIP), 2)
    Place(CreateNote(page, L.COMBAT_HINT), 2)

    P.Gap(2, 8)
    Place(CreateHeader(page, L.SECTION_CHAT), 2)
    Place(CreateCheck(page, L.QUIET,
        function() return ns.sv.quiet end,
        function(v) ns.sv.quiet = v or nil end, nil, L.TIP_QUIET), 2)

    P.Gap(2, 8)
    Place(CreateHeader(page, L.SECTION_MINIMAP), 2)
    Place(CreateCheck(page, L.SHOW_MINIMAP_BUTTON,
        function() return not ns.sv.hideMinimapButton end,
        function(v) ns:SetMinimapButtonShown(v) end, nil, L.TIP_MINIMAP_BUTTON), 2)

    -- Accessibility (account-wide: they concern the player, not a layout)
    P.Gap(2, 8)
    Place(CreateHeader(page, L.SECTION_ACCESSIBILITY), 2)
    -- threshold colors: automatic (soft with a FlareUI style), bright, soft, colorblind
    Place(CreateDropdown(page, L.LEVEL_PALETTE, {
            { key = "auto", name = L.LEVEL_PALETTE_AUTO },
            { key = "bright", name = L.LEVEL_PALETTE_BRIGHT },
            { key = "soft", name = L.LEVEL_PALETTE_SOFT },
            { key = "colorblind", name = L.COLORBLIND },
        },
        function() return ns:GetLevelPalette() end,
        function(v)
            ns.sv.levelPalette = v ~= "auto" and v or nil
            ns:ApplyLevelPalette()
            ns:RefreshAllBlocks() -- the class colors of frames and lines too
            ns:UpdateAll()
        end, nil, nil, L.TIP_LEVEL_PALETTE), 2)
    Place(CreateCheck(page, L.HIGH_CONTRAST,
        function() return ns.sv.highContrast end,
        function(v)
            ns.sv.highContrast = v or nil
            ns:RefreshAllBlocks()
        end, nil, L.TIP_HIGH_CONTRAST), 2)
    Place(CreateSlider(page, L.MIN_FONT_SIZE, 0, 24, 1,
        function() return ns.sv.minFontSize or 0 end,
        function(v)
            ns.sv.minFontSize = v > 0 and v or nil
            ns:RefreshAllBlocks()
        end, nil, L.TIP_MIN_FONT_SIZE), 2)
end

---------------------------------------------------------------------------
-- "Launchers" tab
---------------------------------------------------------------------------
-- Builds the "Launchers" tab; showBlockPage switches to the Blocks tab after a choice
local function BuildLaunchersPage(page, showBlockPage)
    page = ScrollArea(page, 16)
    local P = NewLayout(page)
    local function Place(w, col) return P.Place(w, col) end

    Place(CreateHeader(page, L.LAUNCHERS), 1)
    Place(CreateNote(page, L.LAUNCHERS_HINT, FULL_W), 1)

    Place(CreateActionDropdown(page, L.ADD_LAUNCHER, function()
        local entries = {}
        for _, source in ipairs(ns:GetLauncherSources()) do
            if not ns.db.blocks[source.key] then
                table.insert(entries, {
                    name = source.label,
                    func = function()
                        selected = ns:AddLauncher(source)
                        ns:PlaceNearOptions(selected)
                        if ns.db.locked then ns:SetLocked(false) end
                        showBlockPage()
                    end,
                })
            end
        end
        return entries
    end, L.NO_LAUNCHER_SOURCE, L.TIP_ADD_LAUNCHER), 1)

    Place(CreateActionDropdown(page, L.EDIT_LAUNCHER, function()
        local entries = {}
        if #LauncherKeys() > 0 then
            table.insert(entries, { name = L.ALL_LAUNCHERS, func = function()
                selected = LAUNCHERS
                showBlockPage()
            end })
        end
        for _, key in ipairs(LauncherKeys()) do
            table.insert(entries, { name = ns:GetBlockName(key), func = function()
                selected = key
                showBlockPage()
            end })
        end
        return entries
    end, L.NO_LAUNCHER, L.TIP_EDIT_LAUNCHER), 1)

end

---------------------------------------------------------------------------
-- "DataBroker" tab: sharing Tessera's blocks, DataBroker mode
---------------------------------------------------------------------------
-- Data blocks (game modules) sorted by name
local function DataModuleKeys()
    local keys = {}
    for _, key in ipairs(ns.order) do table.insert(keys, key) end
    table.sort(keys, function(a, b) return SortKey(ns:GetBlockName(a)) < SortKey(ns:GetBlockName(b)) end)
    return keys
end

-- Other addons' DataBroker objects as Tessera blocks (Broker.lua): search, add, edit.
-- First part of the DataBroker tab.
local function BuildBrokerPlugins(page, showBlockPage)
    page = ScrollArea(page, 16)
    local P = NewLayout(page)
    local function Place(w, col) return P.Place(w, col) end
    Place(CreateHeader(page, L.BROKERS), 1)
    Place(CreateNote(page, L.BROKERS_HINT, FULL_W), 1)
    local noLib = Place(CreateNote(page, L.BROKER_NOTE_NONE, FULL_W), 1)
    noLib.isShown = function() return not ns.GetLDB() end
    local hasLib = function() return ns.GetLDB() ~= nil end

    -- search: filters the "Add" menu by name or addon while typing
    local filter = ""
    local search = Place(CreateEditBox(page, L.BROKER_SEARCH, function() return filter end,
        function(v) filter = strtrim(v or "") end, hasLib, L.TIP_BROKER_SEARCH), 1)
    local add
    search.box:HookScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        filter = strtrim(self:GetText() or "")
        if add then add:Refresh() end
    end)
    -- small button that empties the search
    local clear = CreateFrame("Button", nil, search, "UIPanelButtonTemplate")
    clear:SetSize(22, 20)
    clear:SetPoint("LEFT", search.box, "RIGHT", 4, 0)
    clear:SetText("x")
    clear:SetScript("OnClick", function()
        filter = ""
        search.box:SetText("")
        search.box:ClearFocus()
        if add then add:Refresh() end
    end)
    AttachTip(clear, L.BROKER_SEARCH, L.BROKER_SEARCH_CLEAR)
    search.box:SetWidth(COL_W - 48)
    add = Place(CreateActionDropdown(page, L.ADD_BROKER, function()
        local entries, needle = {}, filter:lower()
        for _, source in ipairs(ns:GetBrokerSources()) do
            local haystack = (source.label .. " " .. (source.addon or "") .. " " .. source.name):lower()
            if needle == "" or haystack:find(needle, 1, true) then
                local name = source.label
                if source.addon and source.addon ~= source.label then
                    name = name .. "  |cff999999(" .. source.addon .. ")|r"
                end
                table.insert(entries, {
                    name = name,
                    func = function()
                        selected = ns:AddBroker(source)
                        ns:PlaceNearOptions(selected)
                        if ns.db.locked then ns:SetLocked(false) end
                        showBlockPage()
                    end,
                })
            end
        end
        return entries
    end, L.NO_BROKER_SOURCE, L.TIP_ADD_BROKER), 1)
    add.isShown = hasLib

    local edit = Place(CreateActionDropdown(page, L.EDIT_BROKER, function()
        local entries = {}
        for _, key in ipairs(ns:GetBlockKeys()) do
            if ns.IsBrokerKey(key) then
                table.insert(entries, { name = ns:GetBlockName(key), func = function()
                    selected = key
                    showBlockPage()
                end })
            end
        end
        return entries
    end, L.NO_BROKER, L.TIP_EDIT_BROKER), 1)
    edit.isShown = hasLib
end

local function BuildBrokerPage(tabPage, showBlockPage)
    -- two parts: other addons' plugins as blocks, and sharing Tessera's blocks
    -- (with DataBroker mode). In DataBroker mode Tessera shows no block, so only
    -- the second part is offered.
    local SUB_TOP = -40
    local subs, buttons, current = {}, {}, 1
    local subNames = { L.BROKER_SUB_PLUGINS, L.BROKER_SUB_SHARE }
    local subW = (FULL_W - 6) / 2
    local function ShowSub(i)
        if ns.brokerModeActive then i = 2 end
        current = i
        for n, sub in ipairs(subs) do
            sub:SetShown(n == i)
            buttons[n]:SetEnabled(n ~= i)
        end
    end
    for i, name in ipairs(subNames) do
        local b = CreateFrame("Button", nil, tabPage, "UIPanelButtonTemplate")
        b:SetSize(subW, 22)
        b:SetPoint("TOPLEFT", tabPage, "TOPLEFT", COL_X[1] + (i - 1) * (subW + 6), -6)
        b:SetText(name)
        FitButtonText(b)
        b:SetScript("OnClick", function() ShowSub(i) end)
        b.Refresh = function() end
        Register(b, function() return not ns.brokerModeActive end)
        buttons[i] = b
        local sub = CreateFrame("Frame", nil, tabPage)
        sub:SetPoint("TOPLEFT", tabPage, "TOPLEFT", 0, SUB_TOP)
        sub:SetPoint("BOTTOMRIGHT", tabPage, "BOTTOMRIGHT", 0, 0)
        sub.layoutBase = SUB_TOP
        sub.pageIndex, sub.subIndex = tabPage.pageIndex, i
        subs[i] = sub
    end
    -- keeps the right part shown when DataBroker mode changes
    local keeper = CreateFrame("Frame", nil, tabPage)
    keeper.Refresh = function() ShowSub(current) end
    Register(keeper)

    ns.ShowBrokerSub = ShowSub -- (search: opens the part a setting is in)
    BuildBrokerPlugins(subs[1], showBlockPage)
    local page = ScrollArea(subs[2], 16)
    local P = NewLayout(page)
    local function Place(w, col) return P.Place(w, col) end
    local sharing = function() return ns:IsSharing() and true or false end
    local hasLib = function() return ns.GetLDB() ~= nil end

    -- Left column: state, mode, sharing
    Place(CreateHeader(page, L.BROKER_TITLE), 1)
    -- one explanation per state, in the same slot
    local notes = {
        { L.BROKER_NOTE_NONE, function() return not hasLib() end },
        { L.BROKER_NOTE_MODE:format(ns.brokerDisplay or "DataBroker"), function() return ns.brokerModeActive end },
        { L.BROKER_NOTE_NORMAL, function() return hasLib() and not ns.brokerModeActive end },
    }
    local top, height = P.Bottom(1), 0
    for i, n in ipairs(notes) do
        local w = CreateNote(page, n[1])
        w.isShown = n[2]
        if i == 2 then -- names the display addon detected now
            w.Refresh = function() w.fs:SetText(L.BROKER_NOTE_MODE:format(ns.brokerDisplay or "DataBroker")) end
        end
        w:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[1], top)
        height = math.max(height, w.layoutHeight)
    end
    P.Gap(1, height)

    -- current state in one sentence (e.g. "off: your choice for Bazooka")
    local status = Place(CreateNote(page, "\n"), 1)
    status.isShown = hasLib
    status.Refresh = function() status.fs:SetText("|cffffd100" .. (ns:GetBrokerStatus() or "") .. "|r") end

    -- mode button: leave or enter DataBroker mode (same slot)
    local leave = Place(CreateButton(page, L.BROKER_MODE_OFF_BUTTON, function() ns:SetBrokerMode(false) end,
        function() return ns.brokerModeActive end, nil, L.TIP_BROKER_MODE_OFF), 1)
    local enter = CreateButton(page, L.BROKER_MODE_ON_BUTTON, function() ns:SetBrokerMode(true) end,
        function() return hasLib() and not ns.brokerModeActive end, nil, L.TIP_BROKER_MODE_ON)
    enter:SetPoint("TOPLEFT", leave, "TOPLEFT")
    -- forget the choices made for each display addon
    Place(CreateButton(page, L.BROKER_RESET_CHOICES, function() ns:ResetBrokerChoices() end,
        function() return hasLib() and ns:HasBrokerChoices() end, nil, L.TIP_BROKER_RESET_CHOICES), 1)

    Place(CreateCheck(page, L.BROKER_SHARE_ALL,
        function() return ns.sv.brokerShare end,
        function(v)
            ns.sv.brokerShare = v or nil
            ns:UpdatePublishing()
            ns:RefreshOptions()
        end, function() return hasLib() and not ns.brokerModeActive end, L.TIP_BROKER_SHARE_ALL), 1)
    P.Gap(1, 6)

    -- the shared block being edited (shares the selection with the Blocks tab)
    Place(CreateDropdown(page, L.BROKER_BLOCK, function()
        local list = {}
        for _, key in ipairs(DataModuleKeys()) do
            local cfg = ns.db.blocks[key]
            local name = ns:GetBlockName(key)
            if cfg and cfg.brokerShare then name = name .. "  |cff4dff4d(" .. L.BROKER_SHARED_MARK .. ")|r" end
            table.insert(list, { key = key, name = name })
        end
        return list
    end, function() return selected end, function(v)
        selected = v
        ns:RefreshOptions()
    end, sharing, nil, L.TIP_BROKER_BLOCK), 1)
    local getS, setS = Field("brokerShare")
    Place(CreateCheck(page, L.BROKER_SHARE_BLOCK, getS, function(v)
        setS(v)
        ns:UpdatePublishing()
        ns:RefreshOptions()
    end, sharing, L.TIP_BROKER_SHARE_BLOCK), 1)
    local getC, setC = Field("colorize")
    Place(CreateCheck(page, L.COLORIZE, getC, function(v)
        setC(v)
        ns:UpdatePublishing()
    end, sharing, L.TIP_COLORIZE), 1)
    local reload = Place(CreateNote(page, L.BROKER_RELOAD_NOTE), 1)
    -- also shown with the Reload button below, which it explains
    reload.isShown = function() return sharing() or ns:BrokerNeedsReload() end
    -- only useful once a published block was unshared
    Place(CreateButton(page, L.RELOAD_SHORT, function() ReloadUI() end,
        function() return ns:BrokerNeedsReload() end, nil, L.TIP_BROKER_RELOAD), 1)

    -- Right column: the selected block's own settings (formats, thresholds...)
    local header = Place(CreateHeader(page, L.SECTION_THIS_BLOCK), 2)
    header.isShown = sharing
    local none = Place(CreateNote(page, L.NO_BLOCK_OPTIONS), 2)
    P.Gap(2, -(none.layoutHeight + SPACING))
    local hasOptions = BuildModuleOptions(page, P, 2, ns.order, sharing, function() return true end)
    none.isShown = function()
        local key = SelectedModuleKey()
        return sharing() and not (key and hasOptions[key])
    end
end

---------------------------------------------------------------------------
-- "Profiles" tab
---------------------------------------------------------------------------
-- Popup asking for a new profile name
StaticPopupDialogs["TESSERA_NEW_PROFILE"] = {
    text = L.NEW_PROFILE_PROMPT,
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(self)
        local box = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
        local name = box and box:GetText() or ""
        if not ns:CreateProfile(name) then ns.Print(L.PROFILE_EXISTS) end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["TESSERA_NEW_PROFILE"].OnAccept(parent)
        parent:Hide()
    end,
}

-- Same popup shape for "duplicate" and "name of the imported profile"
local function NamePopup(text, onName)
    local dialog = {
        text = text,
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    dialog.OnAccept = function(self, data)
        local box = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
        onName(box and box:GetText() or "", data)
    end
    dialog.EditBoxOnEnterPressed = function(self, data)
        local parent = self:GetParent()
        dialog.OnAccept(parent, data or parent.data)
        parent:Hide()
    end
    return dialog
end

StaticPopupDialogs["TESSERA_DUPLICATE_PROFILE"] = NamePopup(L.DUPLICATE_PROFILE_PROMPT, function(name)
    if not ns:DuplicateProfile(name) then ns.Print(L.PROFILE_EXISTS) end
end)

StaticPopupDialogs["TESSERA_IMPORT_PROFILE"] = NamePopup(L.IMPORT_PROFILE_PROMPT, function(name, text)
    local ok, err = ns:ImportProfile(text, name)
    if ok then
        ns.Print(L.IMPORT_DONE:format(strtrim(name)))
    else
        ns.Print(err)
        ns:OpenImportWindow(text) -- give the text back to try another name
    end
end)

-- Confirmation before an import: what the text needs and this computer lacks,
-- then what will happen. data = { text, kind }
StaticPopupDialogs["TESSERA_IMPORT_CONFIRM"] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, data) ns:FinishImport(data.text, data.kind) end,
}

-- Applies a checked import text: a style or a layout at once, a profile after
-- asking for its name
function ns:FinishImport(text, kind)
    if kind == "style" then
        if self:ImportStyle(text) then self.Print(L.STYLE_IMPORTED) end
    elseif kind == "layout" then
        if self:ImportLayout(text) then self.Print(L.LAYOUT_IMPORTED) end
    else
        StaticPopup_Show("TESSERA_IMPORT_PROFILE", nil, nil, text)
    end
    self:RefreshOptions()
end

-- Window where the player pastes an exported text (profile, style or layout:
-- the kind is read from the text); then confirms, or names the new profile
function ns:OpenImportWindow(prefill)
    self:ShowTextWindow(L.IMPORT_TITLE, prefill or "", function(text)
        local kind = ns:GetExportKind(text)
        if not kind or (kind == "profile" and not ns:DecodeProfile(text)) then
            ns.Print(L.IMPORT_INVALID)
            return
        end
        ns:HideTextWindow() -- the popups would be hidden behind this window
        local missing = ns:FindMissing(text)
        local msg = {}
        if #missing > 0 then table.insert(msg, L.IMPORT_MISSING:format(table.concat(missing, "\n"))) end
        if kind == "style" then
            table.insert(msg, L.IMPORT_CONFIRM_STYLE)
        elseif kind == "layout" then
            table.insert(msg, L.IMPORT_CONFIRM_LAYOUT)
        elseif #missing > 0 then
            table.insert(msg, L.IMPORT_CONFIRM_PROFILE)
        end
        if #msg == 0 then
            ns:FinishImport(text, kind)
        else
            StaticPopup_Show("TESSERA_IMPORT_CONFIRM", table.concat(msg, "\n\n"), nil, { text = text, kind = kind })
        end
    end, L.IMPORT_BUTTON)
end

-- Confirmation before applying a ready-made layout (replaces the current profile)
StaticPopupDialogs["TESSERA_APPLY_PRESET"] = {
    text = L.PRESET_CONFIRM,
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, preset) ns:ResetProfile(preset) end,
}

-- Confirmation popup before resetting everything (all saved data, then reload)
StaticPopupDialogs["TESSERA_RESET_PROFILE"] = {
    text = L.RESET_PROFILE_CONFIRM,
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function() ns:ResetEverything() end,
}

---------------------------------------------------------------------------
-- "Look" tab: style of the blocks, how groups look, ready-made layouts, screen edges
---------------------------------------------------------------------------
local function BuildLookPage(page)
    page = ScrollArea(page, 16)
    local P = NewLayout(page)
    local function Place(w, col) return P.Place(w, col) end

    -- Left column: style and how groups look
    Place(CreateHeader(page, L.SECTION_THEME), 1)
    Place(CreateNote(page, L.THEME_HINT), 1)
    Place(CreateDropdown(page, L.THEME, function()
        local list = {}
        for _, t in ipairs(ns:GetAvailableThemes()) do
            table.insert(list, { key = t.key, name = t.name })
        end
        return list
    end, function() return ns:GetTheme() end,
       function(v)
           ns:ApplyTheme(v)
           -- the style of a UI that is not installed: say what differs from the real one
           local note = ns:GetThemeNote(v)
           if note then ns.Print(note) end
           ns:RefreshOptions()
       end, nil, nil, L.TIP_THEME), 1)
    Place(CreateSlider(page, L.GLOBAL_SCALE, 50, 300, 5,
        function() return math.floor((ns.db.scale or 1) * 100 + 0.5) end,
        function(v) ns:SetGlobalScale(v / 100) end, nil, L.TIP_GLOBAL_SCALE), 1)
    -- the frame and text of every block are set in the Blocks tab ("All blocks"): two
    -- shortcuts here, where players look first (not in DataBroker mode: no blocks)
    -- side by side, on one row
    local function HasBlocks() return not ns.brokerModeActive end
    local half = (COL_W - 6) / 2
    local frameAll = Place(CreateButton(page, L.LOOK_ALL_FRAME, function() ns:OpenAllBlocks(3) end,
        HasBlocks, half, L.TIP_LOOK_ALL_FRAME), 1)
    local textAll = CreateButton(page, L.LOOK_ALL_TEXT, function() ns:OpenAllBlocks(2) end,
        HasBlocks, half, L.TIP_LOOK_ALL_TEXT)
    textAll:SetPoint("LEFT", frameAll, "RIGHT", 6, 0)

    P.Gap(1, 10)
    Place(CreateHeader(page, L.SECTION_GROUP_LOOK), 1)
    Place(CreateDropdown(page, L.GROUP_LOOK, {
            { key = "fused", name = L.GROUP_LOOK_FUSED },
            { key = "tiles", name = L.GROUP_LOOK_TILES },
            { key = "separate", name = L.GROUP_LOOK_SEPARATE },
        },
        function() return ns:GetGroupLook() end,
        function(v) ns:SetGroupLook(v); ns:RefreshOptions() end, nil, nil, L.TIP_GROUP_LOOK), 1)
    Place(CreateSlider(page, L.JOINT_GAP, 2, 12, 1,
        function() return ns.db.jointGap or 3 end,
        function(v) ns.db.jointGap = v; ns:ReanchorAll(); ns:RequestLayout() end,
        nil, L.TIP_JOINT_GAP), 1) -- always shown: a single group can use tiles too

    -- sharing the style or the layout alone (the import window reads both, and profiles)
    P.Gap(1, 10)
    Place(CreateHeader(page, L.SECTION_SHARE), 1)
    -- the two exports side by side, on one row
    local exportStyle = Place(CreateButton(page, L.EXPORT_STYLE, function()
        ns:ShowTextWindow(L.EXPORT_STYLE_TITLE, ns:ExportStyle())
    end, nil, half, L.TIP_EXPORT_STYLE), 1)
    local exportLayout = CreateButton(page, L.EXPORT_LAYOUT, function()
        ns:ShowTextWindow(L.EXPORT_LAYOUT_TITLE, ns:ExportLayout())
    end, nil, half, L.TIP_EXPORT_LAYOUT)
    exportLayout:SetPoint("LEFT", exportStyle, "RIGHT", 6, 0)
    Place(CreateButton(page, L.IMPORT_SHARED, function() ns:OpenImportWindow() end,
        nil, nil, L.TIP_IMPORT_SHARED), 1)

    -- Right column: screen edges and ready-made layouts
    Place(CreateHeader(page, L.SECTION_EDGES), 2)
    Place(CreateDropdown(page, L.EDGE_SNAP, {
            { key = "ask", name = L.EDGE_SNAP_ASK },
            { key = "always", name = L.EDGE_SNAP_ALWAYS },
            { key = "never", name = L.EDGE_SNAP_NEVER },
        },
        function() return ns.db.edgeSnap or "ask" end,
        function(v) ns.db.edgeSnap = v end, nil, nil, L.TIP_EDGE_SNAP), 2)

    -- ready-made layouts: pick one in the list, then apply it (replaces the current
    -- profile after a confirmation). The note below the list describes the choice.
    P.Gap(2, 10)
    Place(CreateHeader(page, L.SECTION_PRESETS), 2)
    Place(CreateNote(page, L.PRESETS_HINT), 2)
    local chosenPreset = ns.PRESETS[1]
    local presetOptions = {}
    for _, preset in ipairs(ns.PRESETS) do
        table.insert(presetOptions, { key = preset, name = L["PRESET_" .. preset:upper()] })
    end
    -- the note keeps the height of the longest description, so nothing moves
    local longest = ""
    for _, preset in ipairs(ns.PRESETS) do
        local tip = L["TIP_PRESET_" .. preset:upper()] or ""
        if #tip > #longest then longest = tip end
    end
    local presetNote = CreateNote(page, longest)
    presetNote.Refresh = function()
        presetNote.fs:SetText(L["TIP_PRESET_" .. chosenPreset:upper()] or "")
    end
    Place(CreateDropdown(page, L.PRESET_CHOOSE, presetOptions,
        function() return chosenPreset end,
        function(v)
            chosenPreset = v
            presetNote:Refresh()
        end, nil, nil, L.PRESETS_HINT), 2)
    Place(presetNote, 2)
    presetNote:Refresh()
    Place(CreateButton(page, L.PRESET_APPLY, function()
        StaticPopup_Show("TESSERA_APPLY_PRESET", nil, nil, chosenPreset)
    end, nil, nil, L.TIP_PRESET_APPLY), 2)

    -- Blizzard's frames: all blocks in front of them or behind them (Layers.lua)
    P.Gap(2, 10)
    Place(CreateHeader(page, L.SECTION_LAYER), 2)
    Place(CreateButton(page, L.LAYER_ALL_FRONT, function() ns:SetLayer("front") end,
        nil, nil, L.TIP_LAYER_ALL_FRONT), 2)
    Place(CreateButton(page, L.LAYER_ALL_BEHIND, function() ns:SetLayer("behind") end,
        nil, nil, L.TIP_LAYER_ALL_BEHIND), 2)
end

-- Builds the "Profiles" tab
local function BuildProfilesPage(page)
    page = ScrollArea(page, 16)
    local P = NewLayout(page)
    local function Place(w, col) return P.Place(w, col) end

    Place(CreateHeader(page, L.PROFILES), 1)
    Place(CreateCheck(page, L.USE_GLOBAL,
        function() return ns.sv.useGlobal end,
        function(v) ns:SetUseGlobal(v) end, nil, L.TIP_USE_GLOBAL), 1)
    P.Gap(1, 4)
    Place(CreateDropdown(page, L.PROFILE, function()
        local list = {}
        for _, name in ipairs(ns:GetProfileNames()) do
            table.insert(list, { key = name, name = ns:ProfileDisplayName(name) })
        end
        return list
    end, function() return ns.profileName end,
       function(v) ns:SetProfile(v) end, nil, nil, L.TIP_PROFILE), 1)
    P.Gap(1, 4)
    Place(CreateButton(page, L.NEW_PROFILE, function()
        StaticPopup_Show("TESSERA_NEW_PROFILE")
    end, nil, nil, L.TIP_NEW_PROFILE), 1)
    Place(CreateButton(page, L.DUPLICATE_PROFILE, function()
        StaticPopup_Show("TESSERA_DUPLICATE_PROFILE")
    end, nil, nil, L.TIP_DUPLICATE_PROFILE), 1)
    Place(CreateButton(page, L.DELETE_PROFILE, function()
        if not ns:DeleteProfile(ns.profileName) then ns.Print(L.CANNOT_DELETE_DEFAULT) end
    end, function() return ns.profileName ~= ns.DEFAULT_PROFILE end, nil, L.TIP_DELETE_PROFILE), 1)

    -- sharing a layout as a line of text
    P.Gap(1, 8)
    Place(CreateHeader(page, L.SECTION_SHARE), 1)
    Place(CreateButton(page, L.EXPORT_PROFILE, function()
        ns:ShowTextWindow(L.EXPORT_TITLE, ns:ExportProfile())
    end, nil, nil, L.TIP_EXPORT_PROFILE), 1)
    Place(CreateButton(page, L.IMPORT_PROFILE, function() ns:OpenImportWindow() end,
        nil, nil, L.TIP_IMPORT_PROFILE), 1)

    -- automatic profile in dungeons and raids
    P.Gap(1, 8)
    Place(CreateDropdown(page, L.INSTANCE_PROFILE, function()
        local list = { { key = "", name = L.NONE } }
        for _, name in ipairs(ns:GetProfileNames()) do
            table.insert(list, { key = name, name = ns:ProfileDisplayName(name) })
        end
        return list
    end, function() return ns.sv.instanceProfile or "" end,
       function(v)
           ns.sv.instanceProfile = v ~= "" and v or nil
           ns:CheckSituationProfile()
       end, nil, nil, L.TIP_INSTANCE_PROFILE), 1)

    Place(CreateHeader(page, L.SECTION_RESET), 2)
    Place(CreateNote(page, L.RESET_HINT), 2)
    Place(CreateButton(page, L.RESET_PROFILE, function()
        StaticPopup_Show("TESSERA_RESET_PROFILE")
    end, nil, nil, L.TIP_RESET_PROFILE), 2)

end

---------------------------------------------------------------------------
-- Window, skinned according to the theme (FlareUI or Blizzard)
---------------------------------------------------------------------------
-- The window's background reaches under the border's line: the textures' own insets (made
-- for tooltips and dialogs) leave a see-through line a few pixels wide on a large window
local WINDOW_FILL = 3
local ATLAS_MIN_HEIGHT = 220 -- smallest window that gets an expansion's art frame
local function WindowInset(t)
    local inset = t.inset or 0
    if t.edgeFile and inset >= 4 then return inset - 2 end
    return inset
end

-- Skins a Tessera window with the chosen theme (options window, placement banner, ...)
function ns:SkinWindow(frame, title)
    local t = self:GetThemeInfo(self:GetTheme()).window()
    if title then title:SetTextColor(unpack(t.title)) end
    -- the expansion frames (The War Within, Midnight) are drawn for large windows: on a small
    -- one (placement banner, its info panel) their thick border crowds the text, so a small
    -- window takes the style's plain frame in the same colors
    local small = (frame:GetHeight() or 0) < ATLAS_MIN_HEIGHT
    if t.borderAtlas and not small and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(t.borderAtlas) then
        self:ApplySkin(frame, { kind = "atlas", borderAtlas = t.borderAtlas, bgAtlas = t.bgAtlas, bg = t.atlasBg or t.bg, bgInset = t.bgInset })
    elseif t.nineSlice and NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
        self:ApplySkin(frame, { kind = "modern", layout = t.nineSlice, border = t.border, bg = t.bg, desaturate = t.desaturate })
        -- the tooltip layout keeps its center a few pixels inside the border (made for small
        -- tooltips): on a large window that leaves a see-through line, so the center fills up to it
        if frame.Center then
            frame.Center:ClearAllPoints()
            frame.Center:SetPoint("TOPLEFT", WINDOW_FILL, -WINDOW_FILL)
            frame.Center:SetPoint("BOTTOMRIGHT", -WINDOW_FILL, WINDOW_FILL)
        end
    else
        self:ApplySkin(frame, {
            kind = "backdrop",
            info = {
                bgFile = t.bgFile,
                edgeFile = t.edgeFile,
                edgeSize = t.edgeSize,
                tile = t.tile or false,
                tileSize = t.tileSize,
                insets = { left = WindowInset(t), right = WindowInset(t), top = WindowInset(t), bottom = WindowInset(t) },
            },
            border = t.border, bg = t.bg,
        })
    end
end

-- Re-skins the open Tessera windows after a theme change
function ns:SkinOptions()
    if panel then self:SkinWindow(panel, panel.title) end
    if self.banner then self:SkinWindow(self.banner, self.banner.text) end
end

---------------------------------------------------------------------------
-- "Help" tab
---------------------------------------------------------------------------
-- Builds the "Help" tab: scrollable help text
-- Splits a help text into sections. A section starts with a header line
-- written in the help title color (|cffffd100Title|r). Returns a list of
-- { title = "...", body = "..." }; text before the first header, if any,
-- becomes an untitled first section.
local HEADER_PATTERN = "|cffffd100(.-)|r\n"
local function SplitHelp(fullText)
    local sections = {}
    local pos = 1
    local headerStart, headerEnd, title = fullText:find(HEADER_PATTERN, pos)
    if headerStart and headerStart > 1 then
        local intro = strtrim(fullText:sub(1, headerStart - 1))
        if intro ~= "" then table.insert(sections, { title = "", body = intro }) end
    end
    if not headerStart then
        return { { title = "", body = fullText } }
    end
    while headerStart do
        local nextStart, nextEnd, nextTitle = fullText:find(HEADER_PATTERN, headerEnd + 1)
        local body = fullText:sub(headerEnd + 1, (nextStart or #fullText + 1) - 1)
        table.insert(sections, { title = title, body = strtrim(body) })
        headerStart, headerEnd, title = nextStart, nextEnd, nextTitle
    end
    return sections
end
ns.SplitHelp = SplitHelp -- used by tools/mock_run.lua

-- Joins the help from its translation keys: each topic of the layout (ns.HELP_LAYOUT,
-- written at the end of Locales/enUS.lua) is a title key and a list of line keys, "" being
-- an empty line. One key per line, so changing a line only asks translators to redo that line.
function ns.HelpText(layout)
    local parts = {}
    for _, topic in ipairs(layout or {}) do
        parts[#parts + 1] = "|cffffd100" .. (L[topic.title] or "") .. "|r"
        for _, key in ipairs(topic.lines) do
            parts[#parts + 1] = key == "" and "" or (L[key] or "")
        end
        parts[#parts + 1] = ""
    end
    return table.concat(parts, "\n")
end

-- Topic page (Help and About tabs): a list of topics on the left, the selected
-- topic on the right. This keeps each screen short instead of one long wall of text.
-- getSections() returns a key and the list of { title, body, raw } sections; the
-- topics are rebuilt only when the key changes. Unless "raw" is set, an empty line
-- is added between the paragraphs of a topic. Returns the content frame, with
-- Refresh() and ShowTopic(index).
local TOPIC_W, TOPIC_H = 165, 22
local function BuildTopicPage(page, getSections, bottomRoom)
    bottomRoom = bottomRoom or 0 -- room kept free at the bottom (About: the links)
    local topicList = CreateFrame("Frame", nil, page)
    topicList:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[1] - 12, -6)
    topicList:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1] - 12, 70 + bottomRoom)
    topicList:SetWidth(TOPIC_W)

    -- thin vertical line between the topics and the text
    local divider = page:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 0.82, 0, 0.25)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", topicList, "TOPRIGHT", 6, 0)
    divider:SetPoint("BOTTOMLEFT", topicList, "BOTTOMRIGHT", 6, 0)

    local textX = COL_X[1] - 12 + TOPIC_W + 18
    local textW = PANEL_W - NAV_W - HELP_W - textX - 48
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, page, "ScrollFrameTemplate")
    if not ok then scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate") end
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", textX, -6)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -40, 24 + bottomRoom)
    if ns.OptionsZoomOnShiftWheel then ns.OptionsZoomOnShiftWheel(scroll) end

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(textW, 10)
    scroll:SetScrollChild(content)

    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetWidth(textW)
    title:SetJustifyH("LEFT")

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetWidth(textW)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)

    local buttons, sections = {}, {}

    local function ShowSection(index)
        local section = sections[index]
        if not section then return end
        title:SetText(section.title)
        -- an empty line between paragraphs (each line of the text), for more air
        text:SetText(section.raw and section.body or (section.body:gsub("\n+", "\n\n")))
        content:SetHeight(title:GetStringHeight() + 10 + text:GetStringHeight() + 20)
        if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
        for i, b in ipairs(buttons) do
            local selectedTopic = (i == index)
            b.mark:SetShown(selectedTopic)
            if selectedTopic then
                b.label:SetTextColor(1, 0.82, 0)
            else
                b.label:SetTextColor(0.9, 0.9, 0.9)
            end
        end
    end

    local function TopicButton(i)
        if buttons[i] then return buttons[i] end
        local b = CreateFrame("Button", nil, topicList)
        b:SetSize(TOPIC_W, TOPIC_H)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        b.mark = b:CreateTexture(nil, "ARTWORK")
        b.mark:SetColorTexture(1, 0.82, 0, 0.9)
        b.mark:SetSize(3, TOPIC_H - 6)
        b.mark:SetPoint("LEFT", b, "LEFT", 0, 0)
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.label:SetPoint("LEFT", b, "LEFT", 10, 0)
        b.label:SetPoint("RIGHT", b, "RIGHT", -4, 0)
        b.label:SetJustifyH("LEFT")
        b.label:SetWordWrap(true) -- long titles wrap on two lines
        b:SetScript("OnClick", function() ShowSection(i) end)
        buttons[i] = b
        return b
    end

    local shownKey
    content.Refresh = function()
        local key, wanted = getSections()
        if key == shownKey then return end
        shownKey = key
        sections = wanted
        local y = 0
        for i, section in ipairs(sections) do
            local b = TopicButton(i)
            b.label:SetText(section.title ~= "" and section.title or "...")
            b:SetHeight(math.max(TOPIC_H, (b.label:GetStringHeight() or 0) + 8))
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", topicList, "TOPLEFT", 0, -y)
            y = y + b:GetHeight() + 2
            b:Show()
        end
        for i = #sections + 1, #buttons do buttons[i]:Hide() end
        ShowSection(1)
    end
    content.ShowTopic = function(_, index) ShowSection(index) end
    content:Refresh()
    Register(content)
    return content
end

-- Help tab. In DataBroker mode, only the help of that mode (how to leave it comes first).
local function BuildHelpPage(page)
    local cache = {}
    BuildTopicPage(page, function()
        local wanted = ns.brokerModeActive and "broker" or "normal"
        cache[wanted] = cache[wanted]
            or SplitHelp(ns.HelpText(ns.brokerModeActive and ns.HELP_LAYOUT_BROKER or ns.HELP_LAYOUT))
        return wanted, cache[wanted]
    end)
    -- the quick tour can be started again from here (not in DataBroker mode: no blocks)
    local tour = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    tour:SetSize(TOPIC_W, 22)
    tour:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1] - 12, 14)
    tour:SetText(L.TUTORIAL_START)
    tour:SetScript("OnClick", function() ns:StartTutorial() end)
    AttachTip(tour, L.TUTORIAL_START, L.TIP_TUTORIAL_START)
    tour.Refresh = function() end
    Register(tour, function() return not ns.brokerModeActive end)
    -- demo mode: every block, by category, with sample values (Demo.lua)
    local demo = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    demo:SetSize(TOPIC_W, 22)
    demo:SetPoint("BOTTOMLEFT", tour, "TOPLEFT", 0, 4)
    demo:SetText(L.DEMO_BUTTON)
    demo:SetScript("OnClick", function()
        if panel and panel:IsShown() then ns:ToggleOptions() end -- the blocks must be visible
        ns:StartDemo()
    end)
    AttachTip(demo, L.DEMO_BUTTON, L.TIP_DEMO_BUTTON)
    demo.Refresh = function() end
    Register(demo, function() return not ns.brokerModeActive end)
end

---------------------------------------------------------------------------
-- "About" tab: author, translators, license, links (topic "About") and the
-- changelog from Changelog.lua (topic "Changelog")
---------------------------------------------------------------------------
local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or function() end
local SOURCE_URL = "https://github.com/Brainc3ll/Tessera"
local CHANGELOG_TOPIC = 2 -- second topic of the About tab
local aboutContent -- content frame of the About tab, to open the changelog topic

local function ChangelogText()
    local lang = GetLocale() == "frFR" and "fr" or "en"
    local lines = {}
    for _, entry in ipairs(ns.CHANGELOG or {}) do
        -- an empty line after the version title and between changes, for more air
        table.insert(lines, ("|cffffd100%s|r  |cff999999%s|r"):format(entry.version, entry.date or ""))
        -- changes sorted by kind (new, improvements, fixes) since 1.0.0
        for _, section in ipairs(ns.ChangelogSections(entry, lang)) do
            if section.title then
                table.insert(lines, "")
                table.insert(lines, ("|cff8fc7ff%s|r"):format(section.title))
            end
            for _, change in ipairs(section.lines) do
                table.insert(lines, "")
                table.insert(lines, "- " .. change)
            end
        end
        table.insert(lines, "")
        table.insert(lines, "")
    end
    return table.concat(lines, "\n")
end

local function AboutText()
    local function InfoLine(label, value)
        return ("|cffffd100%s|r  %s"):format(label, value)
    end
    local version = GetMetadata and GetMetadata(ADDON, "Version") or "?"
    local author = GetMetadata and GetMetadata(ADDON, "Author") or "Braincell1980"
    local lines = {
        InfoLine(L.ABOUT_VERSION, version),
        InfoLine(L.ABOUT_AUTHOR, author),
    }
    -- translators of the current language (empty in English: the line is hidden)
    if L.ABOUT_TRANSLATORS and L.ABOUT_TRANSLATORS ~= "" then
        table.insert(lines, InfoLine(L.ABOUT_TRANSLATION, L.ABOUT_TRANSLATORS))
    end
    -- a translation made by Claude and not reviewed by a player yet says so (empty in English
    -- and French; the translator who reviews a language empties it)
    if L.ABOUT_TRANSLATION_NOTE and L.ABOUT_TRANSLATION_NOTE ~= "" then
        table.insert(lines, "|cffffb040" .. L.ABOUT_TRANSLATION_NOTE .. "|r")
    end
    table.insert(lines, InfoLine(L.ABOUT_GAME, "WoW Forever"))
    table.insert(lines, InfoLine(L.ABOUT_LICENSE, "MIT"))
    table.insert(lines, InfoLine(L.ABOUT_SOURCE, SOURCE_URL))
    table.insert(lines, "")
    table.insert(lines, L.ABOUT_AI)
    table.insert(lines, "")
    if L.ABOUT_THANKS and L.ABOUT_THANKS ~= "" then
        table.insert(lines, L.ABOUT_THANKS)
        table.insert(lines, "")
    end
    if L.ABOUT_THANKS_2 and L.ABOUT_THANKS_2 ~= "" then
        table.insert(lines, L.ABOUT_THANKS_2)
        table.insert(lines, "")
    end
    table.insert(lines, L.ABOUT_BUGS)
    table.insert(lines, "")
    table.insert(lines, L.ABOUT_TRANSLATE)
    return table.concat(lines, "\n")
end

-- Links of the About tab (1.3): the game opens no browser, so a button per link puts
-- it, selected, in one copy box of the page (inside the window: never behind it)
local ABOUT_LINKS = {
    { "GitHub", SOURCE_URL },
    { "ABOUT_LINK_ISSUES", SOURCE_URL .. "/issues" },
    { "CurseForge", "https://www.curseforge.com/wow/addons/tessera" },
    { "Wago", "https://addons.wago.io/addons/tessera" },
}

-- A copy box: shows a link, selected on focus; typing changes nothing
local function CopyBox(parent, width, getText)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(getText())
            self:HighlightText()
        end
    end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end
local function BuildAboutLinks(page)
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1], 88)
    title:SetText(L.ABOUT_LINKS)
    -- Tessera's links: a button puts its link in the shared box
    local current = ""
    local box = CopyBox(page, FULL_W - 150, function() return current end)
    box:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1] + 6, 26)
    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("LEFT", box, "RIGHT", 10, 0)
    hint:SetText(L.ABOUT_COPY_HINT)
    local w = math.floor((FULL_W - 3 * 6) / #ABOUT_LINKS)
    for i, link in ipairs(ABOUT_LINKS) do
        local name = L[link[1]] or link[1]
        local b = CreateButton(page, name, function()
            current = link[2]
            box:SetText(current)
            box:SetFocus()
            box:HighlightText()
        end, nil, w, L.TIP_ABOUT_COPY)
        b:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1] + (i - 1) * (w + 6), 54)
    end
    AttachTip(box, L.ABOUT_LINKS, L.TIP_ABOUT_COPY)
end

local function BuildAboutPage(page)
    local sections -- built once: the version and language do not change in a session
    aboutContent = BuildTopicPage(page, function()
        sections = sections or {
            { title = L.TAB_ABOUT, body = AboutText(), raw = true },
            { title = L.CHANGELOG_TITLE, body = ChangelogText(), raw = true },
        }
        return "about", sections
    end, 88)
    BuildAboutLinks(page)
    -- the tab always opens on "About" (the "what's new" popup then asks for the changelog)
    page:HookScript("OnShow", function() aboutContent:ShowTopic(1) end)
end

-- Small screens: the window shrinks so a column of blocks still fits on each side
-- of it (blocks shown from the options appear left and right of the window), and
-- it never gets taller than the screen. Full size on large screens.
---------------------------------------------------------------------------
-- No window over another: Tessera's other windows (quick tour, text / import window,
-- style offer) open one at a time, and beside the options window, never on it.
---------------------------------------------------------------------------
local sideWindows = {}

-- true when two frames cover a common part of the screen (any scales)
function ns.FramesOverlap(a, b)
    local sa, sb = a:GetEffectiveScale(), b:GetEffectiveScale()
    local al, ar, at, ab = a:GetLeft(), a:GetRight(), a:GetTop(), a:GetBottom()
    local bl, br, bt, bb = b:GetLeft(), b:GetRight(), b:GetTop(), b:GetBottom()
    if not (al and ar and at and ab and bl and br and bt and bb) then return false end
    return al * sa < br * sb and bl * sb < ar * sa and ab * sa < bt * sb and bb * sb < at * sa
end

-- Puts a side window next to the options window (right, else left; with no room on either
-- side the options window moves to the screen's left edge first)
function ns:DockBesidePanel(frame)
    if not (panel and panel:IsShown() and frame and frame:IsShown()) then return end
    local screenW = UIParent:GetWidth() * UIParent:GetEffectiveScale()
    local ps, fs = panel:GetEffectiveScale(), frame:GetEffectiveScale()
    local left, right = (panel:GetLeft() or 0) * ps, (panel:GetRight() or 0) * ps
    local need = (frame:GetWidth() + 12) * fs
    frame:ClearAllPoints()
    if screenW - right >= need then
        frame:SetPoint("TOPLEFT", panel, "TOPRIGHT", 8, 0)
    elseif left >= need then
        frame:SetPoint("TOPRIGHT", panel, "TOPLEFT", -8, 0)
    else
        panel:ClearAllPoints()
        panel:SetPoint("LEFT", UIParent, "LEFT", 0, 0)
        frame:SetPoint("TOPLEFT", panel, "TOPRIGHT", 8, 0)
    end
end

-- Shows a side window, docked beside the options. One at a time: one already open steps
-- aside and comes back when this one closes (the welcome tour and the style offer can both
-- open at the first login: neither is lost).
local waiting = {}
function ns:ShowSideWindow(frame)
    if not frame then return end
    local known = false
    for _, f in ipairs(sideWindows) do
        if f == frame then
            known = true
        elseif f:IsShown() then
            table.insert(waiting, f)
            f.sideHidden = true
            f:Hide()
            f.sideHidden = nil
        end
    end
    if not known then
        table.insert(sideWindows, frame)
        frame:HookScript("OnHide", function(window)
            if window.sideHidden then return end -- stepped aside, not closed
            local back = table.remove(waiting)
            if back then
                back:Show()
                ns:DockBesidePanel(back)
            end
        end)
    end
    for i = #waiting, 1, -1 do if waiting[i] == frame then table.remove(waiting, i) end end
    frame:Show()
    self:DockBesidePanel(frame)
end

-- The options window opens or moves: the open side window follows it
local function DockSideWindows()
    for _, f in ipairs(sideWindows) do
        if f:IsShown() then ns:DockBesidePanel(f) end
    end
end

local SIDE_ROOM = 200 -- UI units kept free on each side
local function FitPanelToScreen()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if not (w and h and w > 0 and h > 0) then return end
    local scale = math.min(1, (w - 2 * SIDE_ROOM) / PANEL_W, (h - 40) / PANEL_H)
    -- the player's own size (Shift + mouse wheel on the window), on top
    local zoom = ns.sv and ns.sv.optionsZoom or 1
    panel:SetScale(math.max(0.5, math.max(0.6, scale) * zoom))
end

---------------------------------------------------------------------------
-- Window frame (1.3): help panel on the right, fold to the top bar, search, size
-- with Shift + mouse wheel. Every part is a child of the window, on its layer:
-- nothing of it stays in front of another addon's window.
---------------------------------------------------------------------------
local TOPBAR_H = 64
local ZOOM_MIN, ZOOM_MAX, ZOOM_STEP = 0.7, 1.3, 0.05

-- Help panel: the setting under the mouse (its name and tooltip); at rest, the logo
-- and two hints. Tooltips still show on hover.
local function BuildHelpPanel()
    local help = CreateFrame("Frame", nil, panel)
    help:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_W - HELP_W, PAGE_TOP)
    help:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)
    local line = help:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetWidth(1)
    line:SetPoint("TOPLEFT", -10, 0)
    line:SetPoint("BOTTOMLEFT", -10, 0)
    local textW = HELP_W - 32
    local logo = help:CreateTexture(nil, "ARTWORK")
    logo:SetSize(96, 96)
    logo:SetPoint("TOP", help, "TOP", -8, -24)
    logo:SetTexture("Interface\\AddOns\\Tessera\\Media\\Icon.png")
    local title = help:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetWidth(textW)
    title:SetJustifyH("LEFT")
    if title.SetWordWrap then title:SetWordWrap(true) end
    local body = help:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    body:SetWidth(textW)
    body:SetJustifyH("LEFT")
    if body.SetSpacing then body:SetSpacing(3) end
    help.title, help.body = title, body
    -- true when the panel shows it (owner, if given, must be in the unfolded window)
    function ns:ShowOptionHelp(name, tip, owner)
        if owner then
            if not help:IsVisible() then return false end
            local f = owner
            while f and f ~= panel do f = f.GetParent and f:GetParent() or nil end
            if f ~= panel then return false end
        end
        title:ClearAllPoints()
        if name and tip then
            logo:Hide()
            title:SetPoint("TOPLEFT", help, "TOPLEFT", 0, -6)
            title:SetText(name)
            body:SetText(tip)
        else
            logo:Show()
            title:SetPoint("TOPLEFT", help, "TOPLEFT", 0, -136)
            title:SetText(L.OPTIONS_TITLE)
            body:SetText(L.HELP_PANEL_REST .. "\n\n" .. L.HELP_PANEL_ZOOM)
        end
        return true
    end
    ns:ShowOptionHelp()
    panel.help = help
end

-- Folds the window to its top bar (to see what is behind it), or unfolds it. Not
-- saved: the window always opens unfolded. The top edge stays where it is.
local function SetFolded(on)
    if (panel.folded and true or false) == (on and true or false) then return end
    panel.folded = on and true or nil
    local left, top = panel:GetLeft(), panel:GetTop()
    panel:SetHeight(on and TOPBAR_H or PANEL_H)
    if left and top then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
    panel.nav:SetShown(not on)
    panel.help:SetShown(not on)
    for i, p in ipairs(pages) do p:SetShown(not on and i == currentPage) end
    if on and panel.results then panel.results:Hide() end
    panel.fold:Refresh()
    DockSideWindows()
end
ns.SetOptionsFolded = function(_, on) if panel then SetFolded(on) end end

local function BuildFoldButton()
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(28, 28)
    b:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -40, -17)
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b.Refresh = function(self)
        -- arrow up: fold; arrow down: unfold (a shape, the tooltip names it)
        local name = panel.folded and "ScrollDown" or "ScrollUp"
        self:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-" .. name .. "-Up")
        self:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-" .. name .. "-Down")
    end
    b:SetScript("OnClick", function() SetFolded(not panel.folded) end)
    b.Activate = function(self) self:Click() end
    AttachTip(b, L.FOLD_WINDOW, L.TIP_FOLD_WINDOW)
    b:Refresh()
    panel.fold = b
end

-- Size of the window: Shift + mouse wheel anywhere on it, 70 % to 130 %, saved for
-- the account (on top of the automatic fit to small screens)
local function ApplyZoom()
    FitPanelToScreen()
end
local function Zoom(delta)
    local z = (ns.sv.optionsZoom or 1) + (delta > 0 and ZOOM_STEP or -ZOOM_STEP)
    z = math.max(ZOOM_MIN, math.min(ZOOM_MAX, math.floor(z * 100 + 0.5) / 100))
    ns.sv.optionsZoom = (math.abs(z - 1) > 0.001) and z or nil
    ApplyZoom()
    DockSideWindows()
end
-- a scroll area passes Shift + wheel on to the window, and scrolls otherwise
local function ZoomOnShiftWheel(frame)
    local scroll = frame:GetScript("OnMouseWheel")
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        if IsShiftKeyDown() then Zoom(delta) elseif scroll then scroll(self, delta) end
    end)
end
ns.OptionsZoomOnShiftWheel = ZoomOnShiftWheel

---------------------------------------------------------------------------
-- Search (1.3): finds a setting by its name, its tooltip, its section or an old
-- name ("Show" finds "On screen"), without minding accents or capitals. A result
-- opens its page (and the block it belongs to), scrolls to the row and makes it blink.
---------------------------------------------------------------------------
local SEARCH_MAX = 8
-- old names of renamed settings (key: the label of today)
local function OldNames(label)
    if label == L.ENABLED then return L.SEARCH_OLD_ENABLED end
end

local function PlaceName(r)
    local names = { [PAGE_BLOCKS] = L.TAB_BLOCK, [PAGE_LOOK] = L.TAB_LOOK, [PAGE_GENERAL] = L.TAB_GENERAL,
        [PAGE_LAUNCHERS] = L.LAUNCHERS, [PAGE_BROKER] = L.TAB_BROKER, [PAGE_PROFILES] = L.PROFILES }
    local where = names[r.page] or ""
    if r.block then where = where .. " › " .. ns:GetBlockName(r.block)
    elseif r.section then where = where .. " › " .. r.section end
    return where
end

-- Results: settings first whose name matches, then the others; one per name and place
function ns.SearchOptions(text)
    local needle = ns.SortKey(strtrim(text or ""))
    local found, seen = {}, {}
    if #needle < 2 then return found end
    for pass = 1, 2 do
        for _, r in ipairs(ns.optionRows) do
            local inName = ns.SortKey(r.label or ""):find(needle, 1, true)
                or ns.SortKey(OldNames(r.label) or ""):find(needle, 1, true)
            local inRest = ns.SortKey((r.tip or "") .. " " .. (r.section or "")):find(needle, 1, true)
            local id = (r.label or "") .. "|" .. tostring(r.page) .. "|" .. tostring(r.sub) .. "|" .. tostring(r.block)
            if not seen[id] and ((pass == 1 and inName) or (pass == 2 and inRest)) then
                seen[id] = true
                table.insert(found, r)
            end
        end
    end
    return found
end

-- the row lights up three times
local function Blink(w)
    local light = w.hover
    if not light then return end
    local n = 0
    local function Step()
        n = n + 1
        light:SetAlpha(2.5)
        light:SetShown(n % 2 == 1)
        if n < 6 then C_Timer.After(0.25, Step) end
    end
    Step()
end

-- Opens the page of a setting, its block when it belongs to one, and shows it
function ns.GoToOption(r, showPage)
    if not r then return end
    if r.block then
        ns:OpenOptionsFor(r.block)
    else
        showPage(r.page)
        if r.page == PAGE_BLOCKS and r.sub and ns.ShowBlockSub then ns.ShowBlockSub(r.sub) end
        if r.page == PAGE_BROKER and r.sub and ns.ShowBrokerSub then ns.ShowBrokerSub(r.sub) end
    end
    if r.page == PAGE_BLOCKS and r.sub and ns.ShowBlockSub then ns.ShowBlockSub(r.sub) end
    ns:RefreshOptions()
    ns:ShowOptionHelp(r.label, r.tip)
    -- positions are known on the next frame
    C_Timer.After(0, function()
        local content, w = r.content, r.frame
        if content and content.scroll and w:IsShown() then
            local top, rowTop = content:GetTop(), w:GetTop()
            if top and rowTop then
                local scroll = content.scroll
                local range = scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or 0
                scroll:SetVerticalScroll(math.max(0, math.min(range, top - rowTop - 20)))
            end
        end
        if w:IsShown() then Blink(w) end
    end)
end

local function BuildSearch(showPage)
    local ok, box = pcall(CreateFrame, "EditBox", nil, panel, "SearchBoxTemplate")
    if not ok then box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate") end
    box:SetSize(SEARCH_W, 20)
    box:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(76 + 170 + 12), -21)
    box:SetAutoFocus(false)
    if type(box.Instructions) == "table" then box.Instructions:SetText(L.SEARCH) end
    AttachTip(box, L.SEARCH, L.TIP_SEARCH)
    panel.search = box

    -- result list under the box, over the page (a child of the window, raised)
    local results = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    results:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -4)
    results:SetWidth(SEARCH_W + 160)
    results:SetFrameLevel(panel:GetFrameLevel() + 30)
    if results.SetBackdrop then
        results:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        results:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
        results:SetBackdropBorderColor(1, 0.82, 0, 0.6)
    end
    results:Hide()
    panel.results = results
    local lines, list, chosen = {}, {}, 1
    local empty = results:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 10, -8)
    empty:SetText(L.SEARCH_NONE)

    local function Open(index)
        local r = list[index]
        if not r then return end
        results:Hide()
        box:ClearFocus()
        ns.GoToOption(r, showPage)
    end
    local function Mark()
        for i, b in ipairs(lines) do
            -- the chosen line: a bar on its left and a light (keyboard)
            b.bar:SetShown(i == chosen)
            b.light:SetShown(i == chosen)
        end
    end
    for i = 1, SEARCH_MAX do
        local b = CreateFrame("Button", nil, results)
        b:SetHeight(34)
        b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 36)
        b:SetPoint("RIGHT", -4, 0)
        b.light = b:CreateTexture(nil, "BACKGROUND")
        b.light:SetAllPoints()
        b.light:SetColorTexture(1, 1, 1, 0.12)
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT")
        b.bar:SetWidth(3)
        b.bar:SetColorTexture(1, 0.82, 0, 1)
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.name:SetPoint("TOPLEFT", 10, -3)
        b.name:SetPoint("RIGHT", -6, 0)
        b.name:SetJustifyH("LEFT")
        if b.name.SetWordWrap then b.name:SetWordWrap(false) end
        b.place = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        b.place:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
        b.place:SetPoint("RIGHT", -6, 0)
        b.place:SetJustifyH("LEFT")
        if b.place.SetWordWrap then b.place:SetWordWrap(false) end
        b:SetScript("OnClick", function() Open(i) end)
        lines[i] = b
    end

    local function Update()
        local text = box:GetText() or ""
        if ns.SortKey(strtrim(text)) == "" or #ns.SortKey(strtrim(text)) < 2 then
            results:Hide()
            return
        end
        list = ns.SearchOptions(text)
        chosen = 1
        local shown = math.min(#list, SEARCH_MAX)
        for i, b in ipairs(lines) do
            local r = list[i]
            b:SetShown(i <= shown)
            if r then
                b.name:SetText(r.label)
                b.place:SetText(PlaceName(r))
            end
        end
        empty:SetShown(shown == 0)
        results:SetHeight(shown == 0 and 30 or (shown * 36 + 6))
        results:Show()
        Mark()
    end
    box:HookScript("OnTextChanged", function(_, userInput) if userInput then Update() end end)
    box:HookScript("OnEnterPressed", function() Open(chosen) end)
    box:HookScript("OnEscapePressed", function(self)
        self:SetText("")
        results:Hide()
        self:ClearFocus()
    end)
    -- keyboard: up and down choose a result, Enter opens it
    if box.SetAltArrowKeyMode then box:SetAltArrowKeyMode(false) end
    box:HookScript("OnArrowPressed", function(_, key)
        if not results:IsShown() then return end
        local n = math.min(#list, SEARCH_MAX)
        if n == 0 then return end
        if key == "DOWN" then chosen = chosen % n + 1 elseif key == "UP" then chosen = (chosen - 2) % n + 1 end
        Mark()
    end)
    box:HookScript("OnEditFocusLost", function()
        -- a click on a result arrives after the focus is lost: hide a moment later
        C_Timer.After(0.2, function() if not box:HasFocus() then results:Hide() end end)
    end)
end

local function BuildWindowFrame(showPage)
    BuildHelpPanel()
    BuildFoldButton()
    BuildSearch(showPage)
    -- Shift + wheel over the window: its size
    ZoomOnShiftWheel(panel)
    -- always opens unfolded
    panel:HookScript("OnShow", function() SetFolded(false) end)
end

-- Creates the main options window, its tabs and pages (called once, lazily)
local function BuildPanel()
    ValidateSelection()

    panel = CreateFrame("Frame", "TesseraOptions", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        DockSideWindows()
    end)
    table.insert(UISpecialFrames, panel:GetName()) -- close with Escape
    -- the placement banner steps aside while this window is open
    panel:HookScript("OnShow", function()
        FitPanelToScreen()
        ns:UpdatePlacementBanner()
        DockSideWindows()
        if ns.HideMicroMenuList then ns:HideMicroMenuList() end
        if ns.RefreshPins then ns:RefreshPins() end -- a pinned tooltip under the window steps aside
    end)
    panel:HookScript("OnHide", function()
        if ns.RefreshPins then ns:RefreshPins() end -- the pinned tooltips it covered come back
        ns:UpdatePlacementBanner()
        ns:CleanMemorySoon() -- the memory the window used is freed once it is closed
    end)

    -- top bar (1.3): logo, title, the page's sentence, search, lock, fold, close
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(32, 32)
    logo:SetPoint("TOPLEFT", 18, -16)
    logo:SetTexture("Interface\\AddOns\\Tessera\\Media\\Icon.png")
    panel.logo = logo
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    panel.title:SetText(L.OPTIONS_TITLE)
    -- one plain sentence on what the open page is for, next to the title
    panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.hint:SetPoint("TOPLEFT", panel, "TOPLEFT", NAV_W, -20)
    panel.hint:SetPoint("RIGHT", panel, "RIGHT", -(SEARCH_W + 170 + 76 + 16), 0)
    panel.hint:SetHeight(30)
    panel.hint:SetJustifyH("LEFT")
    panel.hint:SetJustifyV("MIDDLE")
    panel.hint:SetTextColor(0.85, 0.8, 0.68)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)

    local lockButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    lockButton:SetSize(170, 22)
    lockButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -76, -20)
    lockButton:SetScript("OnClick", function() ns:SetLocked(not ns.db.locked) end)
    lockButton.Refresh = function(self)
        self:SetText(ns.db.locked and L.UNLOCK_BUTTON or L.LOCK_BUTTON)
    end
    AttachTip(lockButton, L.UNLOCK_BUTTON, L.TIP_LOCK_BUTTON)
    Register(lockButton, function() return not ns.brokerModeActive end) -- nothing to place in DataBroker mode

    -- Tabs
    local function ShowPage(index)
        if ns.brokerModeActive and HIDDEN_IN_BROKER_MODE[index] then index = PAGE_BROKER end
        -- the DataBroker tab edits a data block: pick one if the selection is something else
        if index == PAGE_BROKER and not ns.modules[selected] then selected = DataModuleKeys()[1] or ALL end
        currentPage = index
        panel.hint:SetText(L["PAGE_HINT_" .. index] or "")
        if ns.ShowOptionHelp then ns:ShowOptionHelp() end -- help panel back to rest
        for i, p in ipairs(pages) do
            p:SetShown(i == index)
            tabs[i]:SetSelected(i == index)
        end
        ns:RefreshOptions()
    end

    local names = { L.TAB_BLOCK, L.TAB_LOOK, L.TAB_GENERAL, L.LAUNCHERS, L.TAB_BROKER, L.PROFILES, L.TAB_HELP,
        L.TAB_ABOUT }
    -- the navigation list: a thin frame, one line per page, the open one marked by a gold
    -- bar and white text (also a shape, not only a color: the bar)
    local nav = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    nav:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, PAGE_TOP)
    nav:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16)
    nav:SetWidth(NAV_W - 24)
    if nav.SetBackdrop then
        nav:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        nav:SetBackdropColor(1, 1, 1, 0.03)
        nav:SetBackdropBorderColor(0.55, 0.43, 0.2, 0.6)
    end
    panel.nav = nav
    local NAV_LINE = 30
    for i, text in ipairs(names) do
        local tab = CreateFrame("Button", nil, nav)
        tab:SetSize(NAV_W - 32, NAV_LINE - 4)
        tab.bar = tab:CreateTexture(nil, "BACKGROUND")
        tab.bar:SetAllPoints()
        tab.bar:SetColorTexture(1, 0.82, 0, 0.18)
        tab.edge = tab:CreateTexture(nil, "ARTWORK")
        tab.edge:SetPoint("TOPLEFT"); tab.edge:SetPoint("BOTTOMLEFT")
        tab.edge:SetWidth(3)
        tab.edge:SetColorTexture(1, 0.82, 0, 1)
        local hover = tab:CreateTexture(nil, "HIGHLIGHT") -- shown by the game while hovered
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.07)
        tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        tab.label:SetPoint("LEFT", 12, 0)
        tab.label:SetPoint("RIGHT", -4, 0)
        tab.label:SetJustifyH("LEFT")
        tab.label:SetWordWrap(false)
        tab.label:SetText(text)
        function tab:SetSelected(on)
            self.bar:SetShown(on)
            self.edge:SetShown(on)
            self.label:SetTextColor(on and 1 or 0.88, on and 1 or 0.84, on and 1 or 0.75)
        end
        tab:SetSelected(false)
        tab:SetScript("OnClick", function() ShowPage(i) end)
        tabs[i] = tab

        local page = CreateFrame("Frame", nil, panel)
        page:SetPoint("TOPLEFT", panel, "TOPLEFT", NAV_W, PAGE_TOP)
        page:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -HELP_W, 0)
        page.pageIndex = i
        pages[i] = page
    end

    BuildBlockPage(pages[PAGE_BLOCKS])
    BuildLookPage(pages[PAGE_LOOK])
    BuildGeneralPage(pages[PAGE_GENERAL])
    BuildLaunchersPage(pages[PAGE_LAUNCHERS], function() ShowPage(PAGE_BLOCKS) end)
    BuildBrokerPage(pages[PAGE_BROKER], function() ShowPage(PAGE_BLOCKS) end)
    BuildProfilesPage(pages[PAGE_PROFILES])
    BuildHelpPage(pages[PAGE_HELP])
    BuildAboutPage(pages[PAGE_ABOUT])
    BuildWindowFrame(ShowPage)
    ns.ShowOptionsPage = ShowPage
    ns:SkinOptions()
    ns:ApplyOptionsMode()
    ShowPage(ns.brokerModeActive and PAGE_BROKER or PAGE_BLOCKS)
    panel:Hide() -- frames are visible on creation: ToggleOptions will show it
end

-- Shows the tabs of the current mode (all of them, or only DataBroker, Help and
-- Version in DataBroker mode), sharing the full content width
function ns:ApplyOptionsMode()
    if not panel then return end
    local visible = {}
    for i, tab in ipairs(tabs) do
        local shown = not (ns.brokerModeActive and HIDDEN_IN_BROKER_MODE[i])
        tab:SetShown(shown)
        if shown then table.insert(visible, i) end
    end
    -- one line per visible page; a small gap before Profiles and before Help (three groups:
    -- the blocks, your profiles, help)
    local y = -8
    for _, i in ipairs(visible) do
        if i == PAGE_PROFILES or i == PAGE_HELP then y = y - 12 end
        tabs[i]:ClearAllPoints()
        tabs[i]:SetPoint("TOPLEFT", tabs[i]:GetParent(), "TOPLEFT", 4, y)
        y = y - 30
    end
    -- leaves a tab that this mode hides
    if ns.ShowOptionsPage and ns.brokerModeActive and HIDDEN_IN_BROKER_MODE[currentPage] then
        ns.ShowOptionsPage(PAGE_BROKER)
    end
end

-- Opens the options on a tab (PAGE_* above), and optionally on a given block
function ns:OpenOptions(pageIndex, blockKey)
    if not panel then BuildPanel() end
    if blockKey and ns.db.blocks[blockKey] then
        selected = blockKey
        if ns.IsSpacerKey(blockKey) and ns.ShowBlockSub then ns.ShowBlockSub(5) end
    elseif type(blockKey) == "string" and blockKey:sub(1, #GROUP_PREFIX) == GROUP_PREFIX then
        selected = blockKey -- a group ("*group:" and its head block), checked by ValidateSelection
        ValidateSelection()
    end
    ns:SkinOptions()
    panel:Show()
    ns:ApplyOptionsMode()
    ns.ShowOptionsPage(pageIndex or PAGE_BLOCKS)
end

-- Opens the Blocks tab on "All blocks", at a sub-tab (2 Text, 3 Frame): the shortcuts
-- of the Look tab, where players look first for the look of every block
function ns:OpenAllBlocks(sub)
    selected = ALL
    self:OpenOptions(PAGE_BLOCKS)
    if ns.ShowBlockSub then ns.ShowBlockSub(sub) end
    ns:RefreshOptions()
end

-- Opens the Blocks tab with a given block selected (the DataBroker tab in DataBroker mode)
-- (a right-click on a block: the options open on "This block", its own settings)
function ns:OpenOptionsFor(key)
    self:OpenOptions(self.brokerModeActive and PAGE_BROKER or PAGE_BLOCKS, key)
    if not self.brokerModeActive and self.ShowBlockSub then self.ShowBlockSub(5) end
end

-- Shows or hides the options window
function ns:ToggleOptions()
    if not panel then BuildPanel() end
    if panel:IsShown() then
        panel:Hide()
    else
        ns:SkinOptions()
        panel:Show()
        ns:ApplyOptionsMode()
        ns:RefreshOptions()
    end
end

---------------------------------------------------------------------------
-- Page in Blizzard's settings (Options > AddOns)
---------------------------------------------------------------------------
-- Registers a simple canvas page in Blizzard's settings with buttons to open
-- Tessera's own options window and to reset the profile
local function RegisterBlizzardSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end

    local canvas = CreateFrame("Frame")

    local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.OPTIONS_TITLE)

    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
    local sub = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText(version and ("Version " .. version) or "")

    local desc = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText(L.SETTINGS_DESC)

    local open = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    open:SetSize(260, 26)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    open:SetText(L.OPEN_OPTIONS)
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then
            if not pcall(HideUIPanel, SettingsPanel) then SettingsPanel:Hide() end
        end
        if not ns.built then return end
        if not panel or not panel:IsShown() then ns:ToggleOptions() end
    end)

    local reset = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    reset:SetSize(260, 26)
    reset:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -10)
    reset:SetText(L.RESET_PROFILE)
    reset:SetScript("OnClick", function()
        if ns.built then StaticPopup_Show("TESSERA_RESET_PROFILE") end
    end)

    local category = Settings.RegisterCanvasLayoutCategory(canvas, L.OPTIONS_TITLE)
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end

RegisterBlizzardSettings()

---------------------------------------------------------------------------
-- "Placement mode" banner: visible while blocks are unlocked
---------------------------------------------------------------------------
-- Creates one button of the placement banner
local function BannerButton(b, text, tip, onClick)
    local btn = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
    btn:SetSize(104, 22)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    AttachTip(btn, text, tip)
    return btn
end

-- Shows or hides the placement banner depending on the lock state (created on first use)
function ns:UpdatePlacementBanner()
    -- (never in DataBroker mode: Tessera shows no block of its own; nor while Blizzard's
    -- Edit Mode unlocked the blocks: its own window is open at the same place)
    local placing = self.db and not self:IsLocked() and not self.brokerModeActive
        and not self.db.unlockedByEditMode and true or false

    -- the options window is tucked away during placement and comes back on lock
    if placing and not self.placementActive then
        if panel and panel:IsShown() then
            panel:Hide()
            self.optionsTucked = true
        end
    elseif not placing and self.placementActive then
        if self.optionsTucked and self.db and self.db.locked then
            self.optionsTucked = nil
            if panel then
                ns:SkinOptions()
                ns:RefreshOptions()
                panel:Show()
            end
        end
    end
    self.placementActive = placing

    -- while the options window is open (it has its own lock button), the banner steps aside
    local show = placing and not (panel and panel:IsShown())
    if not show then
        if self.banner then self.banner:Hide() end
        return
    end
    local b = self.banner
    if not b then
        b = CreateFrame("Frame", "TesseraPlacementBanner", UIParent, "BackdropTemplate")
        b:SetSize(400, 104)
        -- where the player last dragged it (account-wide), else near the top of the screen
        local pos = self.sv.bannerPoint
        if type(pos) == "table" and type(pos[1]) == "string" then
            b:SetPoint(pos[1], UIParent, pos[1], tonumber(pos[2]) or 0, tonumber(pos[3]) or 0)
        else
            b:SetPoint("TOP", UIParent, "TOP", 0, -140)
        end
        b:SetFrameStrata("DIALOG")
        b:SetClampedToScreen(true)
        b:EnableMouse(true)
        b:SetMovable(true)
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", b.StartMoving)
        b:SetScript("OnDragStop", function(frame)
            frame:StopMovingOrSizing()
            -- remembered as an offset from the screen center
            local x, y = frame:GetCenter()
            local cx, cy = UIParent:GetCenter()
            local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            ns.sv.bannerPoint = { "CENTER", math.floor(x * k - cx + 0.5), math.floor(y * k - cy + 0.5) }
        end)

        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.text:SetPoint("TOPLEFT", 14, -11)
        b.text:SetText(L.PLACEMENT_TITLE)

        -- every block in front of or behind Blizzard's frames for a while (Layers.lua)
        b.layer = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
        b.layer:SetSize(150, 20)
        b.layer:SetPoint("TOPRIGHT", -12, -8)
        b.layer:SetScript("OnClick", function() ns:ToggleTempLayer() end)
        AttachTip(b.layer, L.LAYER_TOGGLE, L.TIP_LAYER_TOGGLE)

        b.hint = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.hint:SetPoint("TOPLEFT", 14, -30)
        b.hint:SetWidth(372)
        b.hint:SetJustifyH("LEFT")
        b.hint:SetText(L.PLACEMENT_HINT)

        -- four buttons in a row: Options, Undo, Reload, Lock
        local buttons = {
            BannerButton(b, L.BANNER_OPTIONS, L.TIP_BANNER_OPTIONS, function()
                ns.optionsTucked = nil
                ns:ToggleOptions()
            end),
            BannerButton(b, L.UNDO_SHORT, L.TIP_UNDO, function() ns:Undo() end),
            BannerButton(b, L.RELOAD_SHORT, L.TIP_RELOAD, function() ReloadUI() end),
            BannerButton(b, L.LOCK_SHORT, L.TIP_LOCKED, function() ns:SetLocked(true) end),
        }
        for i, btn in ipairs(buttons) do
            btn:SetWidth(88)
            btn:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 12 + (i - 1) * 94, 12)
        end
        b.undo = buttons[2]

        -- Ctrl + Z undoes while the banner is shown; every other key goes on to the
        -- game. Keyboard propagation can only be changed out of combat, so the banner
        -- stops listening to the keyboard during combat (never swallowing a key).
        local function ListenKeyboard(listen)
            if InCombatLockdown() then return end
            b:SetPropagateKeyboardInput(true)
            b:EnableKeyboard(listen)
        end
        b:SetScript("OnKeyDown", function(frame, key)
            if InCombatLockdown() then return end
            local undo = key == "Z" and IsControlKeyDown()
            frame:SetPropagateKeyboardInput(not undo)
            if undo then ns:Undo() end
        end)
        b:SetScript("OnKeyUp", function(frame)
            if not InCombatLockdown() then frame:SetPropagateKeyboardInput(true) end
        end)
        b:RegisterEvent("PLAYER_REGEN_DISABLED")
        b:RegisterEvent("PLAYER_REGEN_ENABLED")
        b:SetScript("OnEvent", function(frame, event)
            if event == "PLAYER_REGEN_DISABLED" then
                frame:EnableKeyboard(false)
            else
                ListenKeyboard(frame:IsShown())
            end
        end)
        b:SetScript("OnShow", function() ListenKeyboard(true) end)
        b:SetScript("OnHide", function() ListenKeyboard(false) end)
        ListenKeyboard(true)
        self.banner = b
    end
    self:SkinWindow(b, b.text)
    b.layer:SetText(self:LayerShown() == "behind" and L.LAYER_BEHIND_STATE or L.LAYER_FRONT_STATE)
    b:Show()
    self:ClearPlacementInfo()
    self:UpdateUndoButton()
end

-- Placement mode: what can be done with the hovered block, in a panel stuck to the
-- banner (above it when the banner is low on the screen) rather than in a tooltip
-- next to the block, where it covered the block's cross and arrows. Dragging the
-- panel moves the banner with it. When nothing is hovered, it says so in one line.
-- Returns false when the banner is not shown (the caller then uses a tooltip).
local function HintLine(text)
    -- "Drag: move the block" -> the gesture in gold, then what it does
    local gesture, rest = text:match("^(.-)%s?:%s(.*)$")
    if not gesture then return text end
    return "|cffffd100" .. gesture .. "|r   " .. rest
end

function ns:ShowPlacementInfo(lines, title)
    local b = self.banner
    if not (b and b:IsShown()) then return false end
    local info = b.info
    if not info then
        info = CreateFrame("Frame", nil, b, "BackdropTemplate")
        info:SetWidth(b:GetWidth())
        info:EnableMouse(true)
        info:RegisterForDrag("LeftButton")
        info:SetScript("OnDragStart", function() b:StartMoving() end)
        info:SetScript("OnDragStop", function() b:GetScript("OnDragStop")(b) end)
        info.title = info:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        info.title:SetPoint("TOPLEFT", 14, -10)
        info.title:SetWidth(b:GetWidth() - 28)
        info.title:SetJustifyH("LEFT")
        info.text = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        info.text:SetWidth(b:GetWidth() - 28)
        info.text:SetJustifyH("LEFT")
        info.text:SetSpacing(3)
        b.info = info
    end
    self:SkinWindow(info, info.title)
    info.title:SetText(title or "")
    info.title:SetShown(title ~= nil)
    info.text:ClearAllPoints()
    if title then
        info.text:SetPoint("TOPLEFT", info.title, "BOTTOMLEFT", 0, -6)
    else
        info.text:SetPoint("TOPLEFT", 14, -10)
    end
    local out = {}
    for i, line in ipairs(lines) do out[i] = HintLine(line) end
    info.text:SetText(table.concat(out, "\n"))
    info:SetHeight(20 + (title and (info.title:GetStringHeight() + 6) or 0) + info.text:GetStringHeight())
    -- below the banner, or above it when the banner is in the lower half of the screen
    info:ClearAllPoints()
    local _, y = b:GetCenter()
    if y and y < UIParent:GetHeight() / 2 then
        info:SetPoint("BOTTOM", b, "TOP", 0, 4)
    else
        info:SetPoint("TOP", b, "BOTTOM", 0, -4)
    end
    info:Show()
    return true
end

-- Back to "hover a block" when the mouse leaves the block
function ns:ClearPlacementInfo()
    if self.banner and self.banner:IsShown() then
        self:ShowPlacementInfo({ L.PLACEMENT_INFO_IDLE })
    end
end

-- The banner's Undo button is only clickable when there is something to undo
function ns:UpdateUndoButton()
    if self.banner and self.banner.undo then
        self.banner.undo:SetEnabled(self:CanUndo())
    end
end

---------------------------------------------------------------------------
-- Welcome popup on first launch
---------------------------------------------------------------------------
StaticPopupDialogs["TESSERA_WELCOME"] = {
    text = L.WELCOME_TEXT,
    button1 = L.TUTORIAL_START,
    button2 = L.WELCOME_LATER,
    button3 = L.DEMO_BUTTON,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function() ns:StartTutorial() end,
    OnAlt = function() ns:StartDemo() end,
}

---------------------------------------------------------------------------
-- Quick tour: a few short steps in a small window (first launch, or the button
-- of the Help tab). Some steps offer a button that does the action for the player.
---------------------------------------------------------------------------
local TUTORIAL_STEPS = {
    { text = "TUTORIAL_1" },
    { text = "TUTORIAL_8", layouts = true, action = "TUTORIAL_DO_KEEP", run = function() ns:KeepTourLayout() end },
    { text = "TUTORIAL_9", action = "TUTORIAL_DO_BLOCK", run = function()
        local key = ns.db.blocks.gold and "gold" or ns.order[1]
        ns:OpenOptionsFor(key)
        if ns.ShowBlockSub then ns.ShowBlockSub(5) end
    end },
    { text = "TUTORIAL_2", action = "TUTORIAL_DO_UNLOCK", run = function() ns:SetLocked(false) end },
    { text = "TUTORIAL_3" },
    { text = "TUTORIAL_4" },
    { text = "TUTORIAL_5" },
    { text = "TUTORIAL_6", action = "TUTORIAL_DO_LOOK", run = function() ns:OpenOptions(PAGE_LOOK) end },
    { text = "TUTORIAL_10" },
    { text = "TUTORIAL_7", action = "TUTORIAL_DO_LOCK", run = function() ns:SetLocked(true) end },
}
local tutorial

-- The "ready-made layouts" step: the arrows show each layout at once on the screen.
-- The player's profile is copied first and comes back when the step is left (or the
-- tour closed), unless "Keep this layout" was clicked. Not during combat.
-- The copy is kept in the saved variables with the profile's name (sv.tourBackup), like
-- the demo's: a /reload, a crash or a logout during the step gives it back at login, and
-- it goes back to its own profile even if another one is active by then (a dungeon's).
local function TourBackup()
    return ns.sv and ns.sv.tourBackup
end

-- Puts the copied profile back (nothing to do without a copy). Returns true when the
-- active profile was the one given back.
local function GiveBackTourProfile()
    local backup = TourBackup()
    if not backup then return false end
    ns.sv.tourBackup = nil
    if type(backup.profile) == "string" and type(backup.data) == "table" and ns.sv.profiles[backup.profile] then
        ns.sv.profiles[backup.profile] = backup.data
        return backup.profile == ns.profileName
    end
    return false
end

-- At login, before the profile is loaded (Core.lua): a tour left in the layouts step
function ns:RestoreTourBackup()
    GiveBackTourProfile()
end

local function UpdateLayoutRow()
    local row = tutorial.layouts
    local i = tutorial.layoutIndex
    if i then
        local preset = ns.PRESETS[i]:upper()
        row.name:SetText(("%s  |cff999999(%d/%d)|r"):format(L["PRESET_" .. preset] or preset, i, #ns.PRESETS))
        row.desc:SetText(TourBackup() and (L["TIP_PRESET_" .. preset] or "") or L.TUTORIAL_LAYOUT_KEPT)
    else
        row.name:SetText(L.TUTORIAL_LAYOUT_CURRENT)
        row.desc:SetText(L.TUTORIAL_LAYOUT_ARROWS)
    end
    row:SetHeight(30 + row.desc:GetStringHeight())
    tutorial.action:SetEnabled(i ~= nil and TourBackup() ~= nil)
end

local function TryTourLayout(delta)
    if InCombatLockdown() then
        ns.Print(L.REPLACE_IN_COMBAT)
        return
    end
    -- the active profile changed since the copy (a dungeon's profile): the copy goes back
    -- to its own profile first, then this one is copied
    local backup = TourBackup()
    if backup and backup.profile ~= ns.profileName then
        GiveBackTourProfile()
        tutorial.layoutIndex = nil
    end
    if not TourBackup() then
        ns.sv.tourBackup = { profile = ns.profileName, data = ns.DeepCopy(ns.sv.profiles[ns.profileName]) }
    end
    local n, i = #ns.PRESETS, tutorial.layoutIndex
    i = i and ((i - 1 + delta) % n + 1) or (delta > 0 and 1 or n)
    tutorial.layoutIndex = i
    ns:TryPreset(ns.PRESETS[i])
    UpdateLayoutRow()
    if tutorial.ShowStep then tutorial.ShowStep(tutorial.index) end -- new height
end

-- the player's own profile comes back (after the fight if one is going on)
local function RestoreTourLayout()
    if not tutorial or not TourBackup() then return end
    if InCombatLockdown() then
        tutorial:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    tutorial.layoutIndex = nil
    if GiveBackTourProfile() then ns:LoadProfile() end
end

function ns:KeepTourLayout()
    if not (tutorial and TourBackup() and tutorial.layoutIndex) then return end
    self.sv.tourBackup = nil
    local preset = ns.PRESETS[tutorial.layoutIndex]
    self.Print(L.PRESET_APPLIED:format(L["PRESET_" .. preset:upper()] or preset))
    C_Timer.After(1.5, function() if ns.AskLayer then ns:AskLayer() end end)
    UpdateLayoutRow()
end

local function ShowTutorialStep(index)
    local step = TUTORIAL_STEPS[index]
    if not step.layouts then RestoreTourLayout() end
    tutorial.index = index
    tutorial.title:SetText(L.TUTORIAL_TITLE:format(index, #TUTORIAL_STEPS))
    tutorial.text:SetText(L[step.text])
    tutorial.back:SetEnabled(index > 1)
    tutorial.next:SetText(index < #TUTORIAL_STEPS and L.TUTORIAL_NEXT or L.TUTORIAL_DONE)
    tutorial.action:SetShown(step.action ~= nil)
    -- the button is shared by the steps: the layouts step greys it out until a layout is
    -- tried, the other steps always use it
    tutorial.action:SetEnabled(true)
    if step.action then
        -- the button fits its text (translations can be long), on its own row
        tutorial.action:SetText(L[step.action])
        local w = (tutorial.action:GetFontString() and tutorial.action:GetFontString():GetStringWidth() or 120) + 32
        tutorial.action:SetWidth(math.min(348, math.max(150, w)))
    end
    tutorial.layouts:SetShown(step.layouts == true)
    local extra = 0
    if step.layouts then
        UpdateLayoutRow()
        extra = tutorial.layouts:GetHeight() + 8
    end
    tutorial:SetHeight(tutorial.text:GetStringHeight() + 96 + (step.action and 30 or 0) + extra)
end

function ns:StartTutorial()
    if self.brokerModeActive then return end -- no blocks of its own to place
    if not tutorial then
        tutorial = CreateFrame("Frame", "TesseraTutorial", UIParent, "BackdropTemplate")
        tutorial:SetSize(380, 160)
        -- below the placement banner (and its panel), which step 3 shows
        tutorial:SetPoint("TOP", UIParent, "TOP", 0, -340)
        tutorial:SetFrameStrata("FULLSCREEN_DIALOG")
        tutorial:SetClampedToScreen(true)
        tutorial:SetMovable(true)
        tutorial:EnableMouse(true)
        tutorial:RegisterForDrag("LeftButton")
        tutorial:SetScript("OnDragStart", tutorial.StartMoving)
        tutorial:SetScript("OnDragStop", tutorial.StopMovingOrSizing)
        tutorial.title = tutorial:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tutorial.title:SetPoint("TOPLEFT", 16, -14)
        tutorial.text = tutorial:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        tutorial.text:SetPoint("TOPLEFT", 16, -38)
        tutorial.text:SetWidth(348)
        tutorial.text:SetJustifyH("LEFT")
        tutorial.text:SetSpacing(3)
        local close = CreateFrame("Button", nil, tutorial, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        local function Button(label, onClick)
            local b = CreateFrame("Button", nil, tutorial, "UIPanelButtonTemplate")
            b:SetSize(96, 22)
            b:SetText(label)
            b:SetScript("OnClick", onClick)
            return b
        end
        tutorial.next = Button(L.TUTORIAL_NEXT, function()
            if tutorial.index < #TUTORIAL_STEPS then ShowTutorialStep(tutorial.index + 1) else tutorial:Hide() end
        end)
        tutorial.next:SetPoint("BOTTOMRIGHT", -14, 14)
        tutorial.back = Button(L.TUTORIAL_BACK, function() ShowTutorialStep(tutorial.index - 1) end)
        tutorial.back:SetPoint("RIGHT", tutorial.next, "LEFT", -6, 0)
        tutorial.action = Button("", function() TUTORIAL_STEPS[tutorial.index].run() end)
        tutorial.action:SetPoint("BOTTOMLEFT", 16, 44) -- above the Back / Next row

        -- ready-made layouts: < name > and the layout's description, under the text
        local row = CreateFrame("Frame", nil, tutorial)
        row:SetPoint("TOPLEFT", tutorial.text, "BOTTOMLEFT", 0, -10)
        row:SetWidth(348)
        local prev = Button("<", function() TryTourLayout(-1) end)
        prev:SetParent(row)
        prev:SetSize(28, 22)
        prev:ClearAllPoints()
        prev:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        local nextLayout = Button(">", function() TryTourLayout(1) end)
        nextLayout:SetParent(row)
        nextLayout:SetSize(28, 22)
        nextLayout:ClearAllPoints()
        nextLayout:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("LEFT", prev, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", nextLayout, "LEFT", -6, 0)
        row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.desc:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8)
        row.desc:SetWidth(348)
        row.desc:SetJustifyH("LEFT")
        row.desc:SetSpacing(2)
        row.prev, row.nextLayout = prev, nextLayout
        tutorial.layouts = row
        tutorial.ShowStep = ShowTutorialStep
        -- closing the tour gives the player's layout back too
        tutorial:HookScript("OnHide", RestoreTourLayout)
        tutorial:SetScript("OnEvent", function(frame)
            frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
            RestoreTourLayout()
        end)
    end
    self:SkinWindow(tutorial, tutorial.title)
    if panel and panel:IsShown() then panel:Hide() end -- the blocks must be visible
    ShowTutorialStep(1)
    ns:ShowSideWindow(tutorial)
end

-- After an update: offers to read what's new (About tab, Changelog topic), once per version
StaticPopupDialogs["TESSERA_WHATS_NEW"] = {
    text = L.WHATS_NEW_TEXT,
    button1 = L.WHATS_NEW_SHOW,
    button2 = L.WELCOME_LATER,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function()
        ns:OpenOptions(PAGE_ABOUT)
        if aboutContent then aboutContent:ShowTopic(CHANGELOG_TOPIC) end
    end,
}

-- Shows the welcome popup once per saved-variables file (first install), or the
-- "what's new" popup when the installed version changed since last time
function ns:ShowWelcomeIfNeeded()
    if not self.sv then return end
    local version = GetMetadata and GetMetadata(ADDON, "Version") or nil
    -- (welcomed but no version saved: installed before this popup existed, i.e. updated)
    if self.sv.welcomed and version and self.sv.lastVersion ~= version then
        self.sv.lastVersion = version
        StaticPopup_Show("TESSERA_WHATS_NEW", version)
        return
    end
    if version then self.sv.lastVersion = version end
    if self.sv.welcomed then return end
    self.sv.welcomed = true
    if self.brokerModeActive then return end -- the DataBroker mode popup says what matters
    StaticPopup_Show("TESSERA_WELCOME")
end

-- Shown once, the first time DataBroker mode turns itself on: explains it and offers
-- to turn it off at once (no Escape: the player has to choose)
StaticPopupDialogs["TESSERA_BROKER_MODE"] = {
    text = L.BROKER_POPUP_TEXT,
    button1 = L.BROKER_POPUP_KEEP,
    button2 = L.BROKER_MODE_OFF_BUTTON,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
    OnShow = function()
        if ns.brokerDisplay and ns.sv.brokerNotified then ns.sv.brokerNotified[ns.brokerDisplay] = true end
    end,
    OnCancel = function(_, _, reason)
        if reason == nil or reason == "clicked" then ns:SetBrokerMode(false) end
    end,
}

---------------------------------------------------------------------------
-- Style offer: when an interface with a matching style is installed (FlareUI,
-- EllesmereUI, ElvUI), a window shows that style on sample blocks and offers to apply
-- it. Each interface is offered once (ns:GetStylesToOffer, Themes.lua).
---------------------------------------------------------------------------
local offer
local PREVIEW_SAMPLES = { { "gold", "1234" }, { "fps", "60 i/s" }, { "time", "20:45" } }

-- A sample block: same frame parts as a real block (Core.lua CreateBlock)
local function PreviewBlock(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetWordWrap(false)
    return f
end

-- Draws the sample blocks in a style, side by side and centered
local function DrawPreview(key)
    local x = 0
    for i, f in ipairs(offer.blocks) do
        local cfg = ns:GetBlockDefaults(PREVIEW_SAMPLES[i][1])
        ns:ApplyThemeToCfg(cfg, key)
        cfg.showIcon, cfg.showLabel = true, false
        local inset = ns:SkinBlockFrame(f, cfg)
        local mod = ns.modules[PREVIEW_SAMPLES[i][1]]
        ns:SetIcon(f.icon, mod and type(mod.icon) ~= "function" and mod.icon or 134400)
        local iconSize = math.max(8, cfg.height - 2 * inset - 4)
        f.icon:SetSize(iconSize, iconSize)
        f.icon:ClearAllPoints()
        f.icon:SetPoint("LEFT", f, "LEFT", 4 + inset, 0)
        f.text:ClearAllPoints()
        f.text:SetPoint("LEFT", f.icon, "RIGHT", 4, 0)
        f.text:SetText(PREVIEW_SAMPLES[i][2])
        local width = math.ceil(f.text:GetStringWidth()) + iconSize + 12 + 2 * inset
        f:SetSize(math.max(width, 60), cfg.height)
        f:ClearAllPoints()
        f:SetPoint("LEFT", offer.preview, "LEFT", x, 0)
        x = x + f:GetWidth() + 6
    end
    offer.preview:SetWidth(math.max(1, x - 6))
end

local function UpdateOffer()
    local key = offer.selected
    offer.text:SetText(L.STYLE_OFFER_TEXT:format(ns:GetUIName(key)))
    for _, b in ipairs(offer.choices) do b:SetEnabled(b.key ~= key) end
    DrawPreview(key)
end

local function BuildOffer()
    local f = CreateFrame("Frame", "TesseraStyleOffer", UIParent, "BackdropTemplate")
    f:SetSize(460, 250)
    f:SetPoint("CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    table.insert(UISpecialFrames, f:GetName()) -- Escape = keep the current style

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -18)
    f.title:SetText("Tessera")
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("TOP", f.title, "BOTTOM", 0, -10)
    f.text:SetWidth(420)
    f.choices = {}
    f.preview = CreateFrame("Frame", nil, f)
    f.preview:SetHeight(30)
    f.blocks = {}
    for i = 1, #PREVIEW_SAMPLES do f.blocks[i] = PreviewBlock(f.preview) end
    f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.note:SetWidth(420)
    f.note:SetText(L.STYLE_OFFER_NOTE)

    local apply = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    apply:SetSize(200, 24)
    apply:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 18)
    apply:SetText(L.STYLE_OFFER_APPLY)
    apply:SetScript("OnClick", function()
        local key = offer.selected
        if ns:ApplyTheme(key) then
            ns.Print(L.STYLE_APPLIED:format(ns:GetUIName(key)))
            ns:RefreshOptions()
        end
        f:Hide()
    end)
    local keep = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    keep:SetSize(200, 24)
    keep:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 18)
    keep:SetText(L.STYLE_OFFER_KEEP)
    keep:SetScript("OnClick", function() f:Hide() end)

    -- accepted, kept or closed: these interfaces are not offered again
    f:SetScript("OnHide", function() if f.list then ns:MarkStylesOffered(f.list) end end)
    f:Hide()
    return f
end

-- Shows the window for a list of style keys (several = one button per interface)
function ns:ShowStyleOffer(list)
    if not offer then offer = BuildOffer() end
    offer.list, offer.selected = list, list[1]
    ns:SkinWindow(offer, offer.title)
    for _, b in ipairs(offer.choices) do b:Hide() end
    local y = -84
    if #list > 1 then
        local width = math.floor((420 - 6 * (#list - 1)) / #list)
        for i, key in ipairs(list) do
            local b = offer.choices[i]
            if not b then
                b = CreateFrame("Button", nil, offer, "UIPanelButtonTemplate")
                b:SetHeight(22)
                b:SetScript("OnClick", function(button)
                    offer.selected = button.key
                    UpdateOffer()
                end)
                offer.choices[i] = b
            end
            b.key = key
            b:SetWidth(width)
            b:SetText(ns:GetUIName(key))
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", offer, "TOPLEFT", 20 + (i - 1) * (width + 6), y)
            b:Show()
        end
        y = y - 34
    end
    offer.preview:ClearAllPoints()
    offer.preview:SetPoint("TOP", offer, "TOP", 0, y - 6)
    offer.note:ClearAllPoints()
    offer.note:SetPoint("TOP", offer, "TOP", 0, y - 50)
    offer:SetHeight(-y + 50 + 30 + 60)
    UpdateOffer()
    ns:ShowSideWindow(offer)
end

-- Offers the style of a newly detected interface (not in DataBroker mode: Tessera then
-- shows no block of its own; not in combat: retried a bit later)
function ns:OfferStylesIfNeeded()
    if not self.built or self.brokerModeActive then return end
    if offer and offer:IsShown() then return end
    -- not on top of Tessera's other popups (welcome, DataBroker mode, what's new)
    local busy = StaticPopup_Visible and (StaticPopup_Visible("TESSERA_WELCOME")
        or StaticPopup_Visible("TESSERA_BROKER_MODE") or StaticPopup_Visible("TESSERA_WHATS_NEW"))
    if InCombatLockdown() or busy then
        C_Timer.After(10, function() ns:OfferStylesIfNeeded() end)
        return
    end
    local list = self:GetStylesToOffer()
    if #list > 0 then self:ShowStyleOffer(list) end
end

---------------------------------------------------------------------------
-- Bug report (/tessera bug) and text window
---------------------------------------------------------------------------

-- Text window, used to copy (debug report, profile export: the text is already
-- selected, Ctrl + C is enough) or to paste (profile import: onAccept receives
-- the pasted text when the button is clicked)
local copyFrame
function ns:ShowTextWindow(title, text, onAccept, acceptLabel)
    if not copyFrame then
        copyFrame = CreateFrame("Frame", "TesseraDebugCopy", UIParent, "BackdropTemplate")
        copyFrame:SetSize(560, 340)
        copyFrame:SetPoint("CENTER", 0, 120)
        copyFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        copyFrame:EnableMouse(true)
        copyFrame:SetMovable(true)
        copyFrame:RegisterForDrag("LeftButton")
        copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
        copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)
        table.insert(UISpecialFrames, "TesseraDebugCopy")
        copyFrame.title = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        copyFrame.title:SetPoint("TOPLEFT", 16, -14)
        local close = CreateFrame("Button", nil, copyFrame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, copyFrame, "ScrollFrameTemplate")
        if not ok then scroll = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate") end
        scroll:SetPoint("TOPLEFT", 16, -38)
        scroll:SetPoint("BOTTOMRIGHT", -34, 46)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject(ChatFontNormal)
        box:SetWidth(500)
        box:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
        scroll:SetScrollChild(box)
        copyFrame.box = box
        local accept = CreateFrame("Button", nil, copyFrame, "UIPanelButtonTemplate")
        accept:SetSize(160, 24)
        accept:SetPoint("BOTTOMRIGHT", -16, 14)
        accept:SetScript("OnClick", function()
            if copyFrame.onAccept then copyFrame.onAccept(copyFrame.box:GetText()) end
        end)
        copyFrame.accept = accept
    end
    ns:SkinWindow(copyFrame, copyFrame.title)
    copyFrame.title:SetText(title)
    copyFrame.onAccept = onAccept
    copyFrame.accept:SetShown(onAccept ~= nil)
    copyFrame.accept:SetText(acceptLabel or ACCEPT)
    copyFrame.box:SetText(text or "")
    ns:ShowSideWindow(copyFrame)
    copyFrame.box:SetFocus()
    copyFrame.box:HighlightText()
end

function ns:HideTextWindow()
    if copyFrame then copyFrame:Hide() end
end

-- Report for a bug report (/tessera bug): short, in English (for GitHub), shown
-- in the copy window only; it does not print in the chat nor touch debug mode
function ns:BugReport()
    local lines = {}
    local function Add(fmt, ...) table.insert(lines, fmt:format(...)) end
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
    local _, build, _, interface = GetBuildInfo()
    Add("Tessera %s - client %s (build %s) - %s", tostring(version), tostring(interface), tostring(build), GetLocale())
    Add("Theme: %s - profile: %s - locked: %s - scale: %s - in combat: %s", tostring(ns:GetTheme()),
        tostring(ns.profileName), tostring(ns.db.locked), tostring(ns.db.scale or 1), tostring(ns.state.inCombat))
    -- DataBroker: library, display addon, mode, sharing, DataBroker blocks
    local brokers = {}
    for _, key in ipairs(ns:GetBlockKeys()) do
        if ns.IsBrokerKey(key) then table.insert(brokers, key:sub(#ns.BROKER_PREFIX + 1)) end
    end
    local refused = {}
    for name in pairs(ns.sv.brokerRefused or {}) do table.insert(refused, name) end
    Add("DataBroker: library %s - display addon: %s - mode: %s (forced %s, refused for: %s) - sharing: %s - blocks: %s",
        tostring(ns.GetLDB() ~= nil), tostring(ns.brokerDisplay or "none"), tostring(ns.brokerModeActive),
        tostring(ns.sv.brokerForced == true), #refused > 0 and table.concat(refused, ", ") or "none",
        tostring(ns:IsSharing() and true or false),
        #brokers > 0 and table.concat(brokers, ", ") or "none")

    -- shown blocks, with how they are placed
    local shown = {}
    for _, key in ipairs(ns:GetBlockKeys()) do
        local cfg, f = ns.db.blocks[key], ns.frames[key]
        if cfg and cfg.enabled then
            local where = cfg.dock and ("docked " .. cfg.dock.side .. " of " .. cfg.dock.to)
                or (cfg.anchor and ("anchored " .. (ns.HangTarget(cfg.anchor) or cfg.anchor.frame or "screen")))
                or (cfg.point and table.concat({ tostring(cfg.point[1]), tostring(cfg.point[3]), tostring(cfg.point[4]) }, " "))
                or "default"
            table.insert(shown, ("  %s%s: %s"):format(key, (f and f:IsShown()) and "" or " (hidden)", where))
        end
    end
    Add("Enabled blocks (%d):", #shown)
    for _, line in ipairs(shown) do table.insert(lines, line) end

    -- errors caught in block updates
    local errors = {}
    for key, err in pairs(ns.errors) do table.insert(errors, ("  %s: %s"):format(key, tostring(err))) end
    Add("Errors: %s", #errors == 0 and "none" or "")
    for _, line in ipairs(errors) do table.insert(lines, line) end

    Add("Edit Mode layout: %s", ns.GetEditModeStatus and ns:GetEditModeStatus() or "?")

    -- other loaded addons (interface addons often explain display problems)
    local addons = {}
    local count = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or 0
    for i = 1, count do
        local name = C_AddOns and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnInfo(i)
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(i)
        if name and loaded and name ~= ADDON then table.insert(addons, name) end
    end
    Add("Other addons: %s", #addons > 0 and table.concat(addons, ", ") or "none")

    ns:ShowTextWindow(L.BUG_TITLE, table.concat(lines, "\n"))
end
