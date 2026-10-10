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
--   General    theme, moving, combat, chat, minimap
--   Launchers  add and edit launcher blocks and DataBroker blocks
--   Broker     share Tessera's blocks with DataBroker addons, DataBroker mode
--   Profiles   profiles and reset
--   Help       help text
--   Version    installed version and changelog
-- In DataBroker mode (Broker.lua) only the Broker, Help and Version tabs are shown.

local panel
local widgets = {}
local PAGE_BLOCKS, PAGE_GENERAL, PAGE_LAUNCHERS, PAGE_BROKER, PAGE_PROFILES, PAGE_HELP, PAGE_VERSION = 1, 2, 3, 4, 5, 6, 7
local HIDDEN_IN_BROKER_MODE = { [PAGE_BLOCKS] = true, [PAGE_GENERAL] = true, [PAGE_LAUNCHERS] = true, [PAGE_PROFILES] = true }
local pages, tabs, currentPage = {}, {}, PAGE_BLOCKS

-- Layout: 600 px window, two 250 px columns, 32 px left margin
local PANEL_W, PANEL_H = 600, 670
local COL_W = 250
local COL_X = { 32, 318 }
local FULL_W = COL_X[2] + COL_W - COL_X[1]
local SPACING = 6 -- vertical space between two settings
local dropdowns = {} -- { label, dd } entries, for the debug report

local ALL = "*all"            -- selection value "All blocks"
local LAUNCHERS = "*launchers" -- selection value "All launchers"
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

-- True when the selection is a group (all blocks / all launchers) rather than one block
local function IsGroup() return selected == ALL or selected == LAUNCHERS end

-- Blocks affected by a setting change
local function Targets()
    if selected == ALL then
        -- spacers keep their own look: "All blocks" does not change them
        local keys = {}
        for _, key in ipairs(ns:GetBlockKeys()) do
            if not ns.IsSpacerKey(key) then table.insert(keys, key) end
        end
        return keys
    end
    if selected == LAUNCHERS then return LauncherKeys() end
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
        if w.isShown then w:SetShown(w.isShown() and true or false) end
        w:Refresh()
    end
    if ns.RelayoutBlockOptions then ns.RelayoutBlockOptions() end
end

-- Per-block settings, never stored as defaults for other blocks
local PER_BLOCK_FIELDS = { enabled = true, width = true, height = true }

-- Writes a setting to every selected block. Newly shown blocks get a style and a
-- free position; group changes are also saved as defaults for future blocks.
local function SetField(name, value)
    -- style template picked before the change: a block that is already visible
    local refKey = name == "enabled" and value and ns:GetReferenceBlock()
    if name == "enabled" then ns:PushUndo() end -- showing / hiding blocks can be undone
    for _, key in ipairs(Targets()) do
        local cfg = ns.db.blocks[key]
        local appearing = name == "enabled" and value and not cfg.enabled
        cfg[name] = ns.DeepCopy(value)
        if appearing and not cfg.point and not cfg.dock and not cfg.anchor then
            if refKey and refKey ~= key then ns:AdoptReferenceStyle(key, refKey) end
            ns:PlaceNearOptions(key)
        elseif appearing and not cfg.dock and not cfg.anchor and ns:OverlapsOtherBlock(key) then
            ns:PlaceNearOptions(key) -- its old spot is taken: find a free one
        end
        ns:ApplyStyle(key)
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
    if not frame or not tip then return end
    frame:HookScript("OnEnter", function(self)
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

-- Section header: gold text with a thin line underneath
local function CreateHeader(parent, text)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(COL_W, 24)
    local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("BOTTOMLEFT", 0, 4)
    fs:SetText(text)
    local line = holder:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    holder.Refresh = function() end
    holder.layoutHeight = 30
    return Register(holder)
end

-- Multi-line help text (default width: one column)
local function CreateNote(parent, text, width)
    local holder = CreateFrame("Frame", nil, parent)
    local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT")
    fs:SetWidth(width or COL_W)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    holder.fs = fs
    holder:SetSize(width or COL_W, math.max(14, fs:GetStringHeight()))
    holder.Refresh = function() end
    holder.layoutHeight = holder:GetHeight() + 8
    return Register(holder)
end

-- Checkbox bound to a getter/setter pair
local function CreateCheck(parent, label, getter, setter, isShown, tip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local fs = cb.text or cb.Text
    if not fs then
        fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    end
    fs:SetText(label)
    cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    AttachTip(cb, label, tip)
    cb.Refresh = function(self) self:SetChecked(getter() and true or false) end
    cb.layoutHeight = 26
    return Register(cb, isShown)
end

-- Slider with stepper arrows; values are rounded to integers
local function CreateSlider(parent, label, minV, maxV, step, getter, setter, isShown, tip)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(COL_W, 40)
    local title = AddTitle(holder, label)

    local slider = CreateFrame("Frame", nil, holder, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    slider:SetWidth(COL_W - 14)
    slider:Init(getter() or minV, minV, maxV, (maxV - minV) / step, {
        [MinimalSliderWithSteppersMixin.Label.Right] = function(v)
            return tostring(math.floor(v + 0.5))
        end,
    })
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if holder.updating then return end
        setter(math.floor(value + 0.5))
    end, holder)

    if tip then
        holder:EnableMouse(true)
        AttachTip(holder, label, tip)
        AttachTip(slider.Slider, label, tip)
    end

    holder.Refresh = function(self)
        self.updating = true
        slider:SetValue(getter() or minV)
        self.updating = false
    end
    holder.layoutHeight = 46
    return Register(holder, isShown)
end

-- Single-choice dropdown; options = list of {key, name} or a function returning it
local function CreateDropdown(parent, label, options, getter, setter, isShown, width, tip)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width or COL_W, 44)
    local title = AddTitle(holder, label)

    local dd = CreateFrame("DropdownButton", nil, holder, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    dd:SetWidth((width or COL_W) - 12)
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
    table.insert(dropdowns, { label = label, dd = dd })
    dd:HookScript("OnMouseDown", function(self, button)
        if not ns.debug then return end
        ns.Print(("[debug] clic sur le menu « %s » (%s)"):format(label, tostring(button)))
        C_Timer.After(0.2, function()
            local open = self.IsMenuOpen and self:IsMenuOpen()
            ns.Print(("[debug] menu « %s » ouvert : %s"):format(label, tostring(open)))
        end)
    end)

    if tip then
        holder:EnableMouse(true)
        AttachTip(holder, label, tip)
        AttachTip(dd, label, tip)
    end

    holder.Refresh = function() dd:GenerateMenu() end
    holder.layoutHeight = 50
    return Register(holder, isShown)
end

-- Action dropdown (each entry is a button)
local function CreateActionDropdown(parent, label, buildEntries, emptyText, tip)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(COL_W, 44)
    local title = AddTitle(holder, label)

    local dd = CreateFrame("DropdownButton", nil, holder, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    dd:SetWidth(COL_W - 12)
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

    if tip then
        holder:EnableMouse(true)
        AttachTip(holder, label, tip)
        AttachTip(dd, label, tip)
    end

    holder.Refresh = function() dd:GenerateMenu() end
    holder.layoutHeight = 50
    return Register(holder)
end

-- Color swatch opening Blizzard's color picker (Cancel restores the previous color)
local function CreateColor(parent, label, hasAlpha, getter, setter, isShown, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(COL_W, 22)

    local edge = b:CreateTexture(nil, "BACKGROUND")
    edge:SetSize(20, 20)
    edge:SetPoint("LEFT")
    edge:SetColorTexture(1, 1, 1, 1)

    local swatch = b:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(16, 16)
    swatch:SetPoint("CENTER", edge)

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", edge, "RIGHT", 6, 0)
    fs:SetText(label)

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

    AttachTip(b, label, tip)
    b.layoutHeight = 28
    return Register(b, isShown)
end

-- Plain push button
-- Text box (free text, or numbers only); the value is saved on Enter or when
-- the box loses focus, Escape restores the saved value
local function CreateEditBox(parent, label, getter, setter, isShown, tip, numeric)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(COL_W, 44)
    local title = AddTitle(holder, label)
    local box = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
    box:SetSize(COL_W - 20, 20)
    box:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 6, -4)
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
    if tip then
        holder:EnableMouse(true)
        AttachTip(holder, label, tip)
        AttachTip(box, label, tip)
    end
    holder.box = box
    holder.layoutHeight = 46
    return Register(holder, isShown)
end

local function CreateButton(parent, text, onClick, isShown, width, tip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or COL_W, 24)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    AttachTip(b, text, tip)
    b.Refresh = function() end
    b.layoutHeight = 30
    return Register(b, isShown)
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
-- Column layout
---------------------------------------------------------------------------
-- Returns a layout helper for a page: Place(w, col) stacks a widget in column 1 or 2,
-- Gap(col, h) adds (or, if negative, removes) vertical space, Bottom(col) gives the current y.
local function NewLayout(page, top)
    local y = { top or -6, top or -6 }
    local layout = {}
    function layout.Place(w, col)
        w:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[col], y[col])
        y[col] = y[col] - w.layoutHeight - SPACING
        return w
    end
    function layout.Gap(col, h) y[col] = y[col] - h end
    function layout.Bottom(col) return y[col] end
    return layout
end

---------------------------------------------------------------------------
-- "Blocks" tab
---------------------------------------------------------------------------
-- Entries of the selection dropdown: groups first, then data blocks, then launchers
-- Sort key for names: lower case without accents, so "Écran" sorts with the E's
local ACCENTS = { ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
    ["î"] = "i", ["ï"] = "i", ["ô"] = "o", ["ö"] = "o", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ç"] = "c",
    ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["À"] = "a", ["Ç"] = "c", ["Ô"] = "o", ["Î"] = "i" }
local function SortKey(name)
    local key = tostring(name)
    for accented, plain in pairs(ACCENTS) do key = key:gsub(accented, plain) end
    return key:lower()
end

local function SelectionOptions()
    local list = { { key = ALL, name = L.ALL_BLOCKS } }
    if #LauncherKeys() > 0 then
        table.insert(list, { key = LAUNCHERS, name = L.ALL_LAUNCHERS })
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
        table.insert(list, { key = key, name = ns:GetBlockName(key) })
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
local function BuildModuleOptions(sub, P, col, keys, condition)
    local function ModuleOf(key)
        return key == "spacer" and ns.spacerModule or ns.modules[key]
    end
    local stackTop = P.Bottom(col)
    local stacks = {}
    local hasOptions = {}
    for _, key in ipairs(keys) do
        local mod = ModuleOf(key)
        local list = {}
        for _, opt in ipairs(mod.options or {}) do table.insert(list, opt) end
        if mod.isEmpty then
            table.insert(list, { kind = "check", field = "hideEmpty", label = "HIDE_EMPTY", tip = "TIP_HIDE_EMPTY",
                after = function() ns:UpdateAllVisibility() end })
        end
        if mod.thresholds then
            local t = mod.thresholds
            local tip = t.low and "TIP_THRESHOLD_LOW" or "TIP_THRESHOLD_HIGH"
            table.insert(list, { kind = "slider", field = "warnAt", label = "THRESHOLD_WARN", tip = tip,
                min = t.min, max = t.max, step = t.step, default = t.warn })
            table.insert(list, { kind = "slider", field = "badAt", label = "THRESHOLD_BAD", tip = tip,
                min = t.min, max = t.max, step = t.step, default = t.bad })
        end
        if #list > 0 then hasOptions[key] = true end
        local firstWidget = #widgets + 1
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
                local values = {}
                for _, v in ipairs(opt.values) do table.insert(values, { key = v.key, name = L[v.label] or v.label }) end
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
    end
    -- packs the visible widgets of each stack from the top (called after every refresh)
    table.insert(relayouts, function()
        for _, stack in ipairs(stacks) do
            local y = stackTop
            for _, w in ipairs(stack) do
                if w:IsShown() then
                    w:ClearAllPoints()
                    w:SetPoint("TOPLEFT", sub, "TOPLEFT", COL_X[col], y)
                    y = y - w.layoutHeight - SPACING
                end
            end
        end
    end)
    return hasOptions
end

local blockSub = 1 -- open sub-tab: 1 Display, 2 Text, 3 Frame

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
    local ShowSub -- defined below (sub-tabs); a spacer's settings are in the Behaviour tab
    top.Place(CreateDropdown(page, L.SELECTION, SelectionOptions,
        function() return selected end,
        function(v)
            selected = v
            if ns.IsSpacerKey(v) and ShowSub then ShowSub(4) end
            ns:RefreshOptions()
        end, nil, FULL_W, L.TIP_SELECTION), 1)
    top.Place(CreateNote(page, L.GROUP_HINT, FULL_W), 1)

    -- Sub-tabs
    local subY = top.Bottom(1) - 4
    local subs, buttons = {}, {}
    ShowSub = function(index)
        blockSub = index
        for i, sub in ipairs(subs) do
            sub:SetShown(i == index)
            buttons[i]:SetEnabled(i ~= index)
        end
    end
    local subNames = { L.SUB_DISPLAY, L.SUB_TEXT, L.SUB_FRAME, L.SUB_BEHAVIOUR }
    local subW = (FULL_W - 6 * (#subNames - 1)) / #subNames
    for i, text in ipairs(subNames) do
        local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        b:SetSize(subW, 22)
        b:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[1] + (i - 1) * (subW + 6), subY)
        b:SetText(text)
        b:SetScript("OnClick", function() ShowSub(i) end)
        buttons[i] = b
        local sub = CreateFrame("Frame", nil, page)
        sub:SetPoint("TOPLEFT", page, "TOPLEFT", 0, subY - 36)
        sub:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 56)
        subs[i] = sub
    end
    local line = page:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[1], subY - 28)
    line:SetPoint("TOPRIGHT", page, "TOPLEFT", COL_X[1] + FULL_W, subY - 28)

    -- 1. Display: what is shown, and the size
    do
        local sub = subs[1]
        local P = NewLayout(sub)
        P.Place(CreateHeader(sub, L.SECTION_DISPLAY), 1)
        local spacerNote = P.Place(CreateNote(sub, L.SPACER_SETTINGS_HINT), 1)
        spacerNote.isShown = function() return ns.IsSpacerKey(selected) end
        P.Place(Check(sub, L.ENABLED, "enabled", L.TIP_ENABLED), 1)
        P.Place(Check(sub, L.SHOW_LABEL, "showLabel", L.TIP_SHOW_LABEL), 1)
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
        local sub = subs[2]
        local P = NewLayout(sub)
        P.Place(CreateHeader(sub, L.SECTION_TEXT), 1)
        P.Place(Dropdown(sub, L.FONT, function() return ns:GetMediaList("font") end, "font", L.TIP_FONT), 1)
        P.Place(Slider(sub, L.FONT_SIZE, 6, 32, "fontSize", L.TIP_FONT_SIZE), 1)
        P.Place(Dropdown(sub, L.OUTLINE, {
            { key = "NONE", name = L.OUTLINE_NONE },
            { key = "OUTLINE", name = L.OUTLINE_THIN },
            { key = "THICKOUTLINE", name = L.OUTLINE_THICK },
        }, "outline", L.TIP_OUTLINE), 1)

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
        local sub = subs[3]
        local P = NewLayout(sub)
        P.Place(CreateHeader(sub, L.BACKGROUND), 1)
        P.Place(Dropdown(sub, L.BACKGROUND, function() return ns:GetMediaList("background") end, "bg", L.TIP_BACKGROUND), 1)
        P.Place(Color(sub, L.BG_COLOR, true, "bgColor", L.TIP_BG_COLOR), 1)

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
        default:SetPoint("TOPRIGHT", corner, "TOPRIGHT", -12, 2)
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
    end

    -- 4. Behaviour: settings specific to the selected block (left), visibility and
    -- clicks (right)
    do
        local sub = subs[4]
        local P = NewLayout(sub)
        P.Place(CreateHeader(sub, L.SECTION_VISIBILITY), 1)
        P.Place(Check(sub, L.HIDE_COMBAT, "hideInCombat", L.TIP_HIDE_COMBAT), 1)
        P.Place(Check(sub, L.HIDE_INSTANCE, "hideInInstance", L.TIP_HIDE_INSTANCE), 1)
        P.Place(Check(sub, L.HIDE_VEHICLE, "hideInVehicle", L.TIP_HIDE_VEHICLE), 1)
        P.Place(Check(sub, L.HIDE_RESTING, "hideWhenResting", L.TIP_HIDE_RESTING), 1)
        P.Gap(1, 6)
        P.Place(CreateHeader(sub, L.SECTION_THIS_BLOCK), 1)
        local none = P.Place(CreateNote(sub, L.NO_BLOCK_OPTIONS), 1)
        P.Gap(1, -(none.layoutHeight + SPACING))

        -- the selected block's own options (left column)
        local keys = { "spacer" }
        for _, key in ipairs(ns.order) do table.insert(keys, key) end
        local hasOptions = BuildModuleOptions(sub, P, 1, keys)
        none.isShown = function()
            local key = SelectedModuleKey()
            return not (key and hasOptions[key])
        end

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
        P.Place(CreateHeader(sub, L.SECTION_CLICKS), 2)
        local clickShown = function() return not ns.IsForwardingKey(selected) end
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
                                 { "options", L.ACTION_OPTIONS }, { "hide", L.ACTION_HIDE } }) do
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
        P.Place(Check(sub, L.ALERT, "alert", L.TIP_ALERT), 2)
        P.Place(Dropdown(sub, L.TOOLTIP_ANCHOR, {
            { key = "auto", name = L.TOOLTIP_AUTO },
            { key = "top", name = L.TOOLTIP_TOP },
            { key = "bottom", name = L.TOOLTIP_BOTTOM },
        }, "tooltipAnchor", L.TIP_TOOLTIP_ANCHOR), 2)
    end

    ShowSub(blockSub)
    ns.ShowBlockSub = ShowSub

    -- Single-block actions, at the bottom
    local bw = math.floor((FULL_W - 2 * 12) / 3)
    local reset = CreateButton(page, L.RESET_BLOCK, function()
        ns:ResetBlock(selected)
        ns:RefreshOptions()
    end, single, bw, L.TIP_RESET_BLOCK)
    reset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1], 22)

    local copy = CreateButton(page, L.COPY_STYLE, function()
        ns:CopyStyleToAll(selected)
    end, single, bw, L.TIP_COPY_STYLE)
    copy:SetPoint("LEFT", reset, "RIGHT", 12, 0)

    -- third slot: remove the launcher / the spacer, or add a spacer
    local isSpacer = function() return ns.IsSpacerKey(selected) end
    local remove = CreateButton(page, L.REMOVE_LAUNCHER, function()
        ns:RemoveLauncher(selected)
        ns:RefreshOptions()
    end, isLauncher, bw, L.TIP_REMOVE_LAUNCHER)
    remove:SetPoint("LEFT", copy, "RIGHT", 12, 0)
    local removeSpacer = CreateButton(page, L.REMOVE_SPACER, function()
        ns:RemoveSpacer(selected)
        ns:RefreshOptions()
    end, isSpacer, bw, L.TIP_REMOVE_SPACER)
    removeSpacer:SetPoint("LEFT", copy, "RIGHT", 12, 0)
    local removeBroker = CreateButton(page, L.REMOVE_BROKER, function()
        ns:RemoveBroker(selected)
        ns:RefreshOptions()
    end, function() return ns.IsBrokerKey(selected) end, bw, L.TIP_REMOVE_BROKER)
    removeBroker:SetPoint("LEFT", copy, "RIGHT", 12, 0)
    local addSpacer = CreateButton(page, L.ADD_SPACER, function()
        selected = ns:AddSpacer()
        ns:PlaceNearOptions(selected)
        ShowSub(4) -- the spacer's settings (type, text, line) are in the Behaviour tab
        if ns.db.locked then ns:SetLocked(false) end
        ns:RefreshOptions()
    end, function() return not ns.IsForwardingKey(selected) and not isSpacer() end, bw, L.TIP_ADD_SPACER)
    addSpacer:SetPoint("LEFT", copy, "RIGHT", 12, 0)
end

---------------------------------------------------------------------------
-- "General" tab
---------------------------------------------------------------------------
-- Builds the "General" tab: global settings shared by all blocks
local function BuildGeneralPage(page)
    local P = NewLayout(page)
    local function Place(w, col) return P.Place(w, col) end

    -- Left column: theme and moving
    Place(CreateHeader(page, L.SECTION_THEME), 1)
    Place(CreateNote(page, L.THEME_HINT), 1)
    Place(CreateDropdown(page, L.THEME, function()
        local list = {}
        for _, t in ipairs(ns:GetAvailableThemes()) do
            table.insert(list, { key = t.key, name = t.name })
        end
        return list
    end, function() return ns:GetTheme() end,
       function(v) ns:ApplyTheme(v); ns:RefreshOptions() end, nil, nil, L.TIP_THEME), 1)
    Place(CreateSlider(page, L.GLOBAL_SCALE, 50, 300, 5,
        function() return math.floor((ns.db.scale or 1) * 100 + 0.5) end,
        function(v) ns:SetGlobalScale(v / 100) end, nil, L.TIP_GLOBAL_SCALE), 1)
    P.Gap(1, 8)
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
    Place(CreateCheck(page, L.MERGE,
        function() return ns.db.merge end,
        function(v) ns.db.merge = v end, nil, L.TIP_MERGE), 1)
    Place(CreateNote(page, L.MERGE_HINT), 1)
    Place(CreateDropdown(page, L.GRID, {
        { key = 0, name = L.GRID_OFF },
        { key = 8, name = "8 px" },
        { key = 16, name = "16 px" },
        { key = 32, name = "32 px" },
    }, function() return ns.db.grid or 0 end,
       function(v) ns.db.grid = v; ns:UpdateGrid() end, nil, nil, L.TIP_GRID), 1)
    Place(CreateButton(page, L.RECOVER_BUTTON, function() ns:RecoverBlocksCommand() end,
        nil, nil, L.TIP_RECOVER), 1)

    -- Right column: combat
    Place(CreateHeader(page, L.SECTION_COMBAT), 2)
    Place(CreateCheck(page, L.LOCK_IN_COMBAT,
        function() return ns.db.lockInCombat end,
        function(v) ns.db.lockInCombat = v; ns:RefreshLockState() end, nil, L.LOCK_IN_COMBAT_TIP), 2)
    Place(CreateCheck(page, L.TOOLTIP_HINTS,
        function() return ns.db.tooltipHints ~= false end,
        function(v) ns.db.tooltipHints = v end, nil, L.TIP_TOOLTIP_HINTS), 2)
    Place(CreateCheck(page, L.TOOLTIP_IN_COMBAT,
        function() return ns.db.tooltipInCombat end,
        function(v) ns.db.tooltipInCombat = v end, nil, L.TOOLTIP_IN_COMBAT_TIP), 2)
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
    Place(CreateCheck(page, L.COLORBLIND,
        function() return ns.sv.colorblind end,
        function(v)
            ns.sv.colorblind = v or nil
            ns:ApplyLevelPalette()
            ns:UpdateAll()
        end, nil, L.TIP_COLORBLIND), 2)
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

    -- DataBroker blocks: other addons' data objects (Broker.lua), in their own menus
    P.Gap(1, 10)
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

local function BuildBrokerPage(page)
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
    local hasOptions = BuildModuleOptions(page, P, 2, ns.order, sharing)
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

-- Window where the player pastes a profile text; then asks for the new profile's name
function ns:OpenImportWindow(prefill)
    self:ShowTextWindow(L.IMPORT_TITLE, prefill or "", function(text)
        if not ns:DecodeProfile(text) then
            ns.Print(L.IMPORT_INVALID)
            return
        end
        ns:HideTextWindow() -- the name popup would be hidden behind this window
        StaticPopup_Show("TESSERA_IMPORT_PROFILE", nil, nil, text)
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

-- Confirmation popup before resetting the current profile
StaticPopupDialogs["TESSERA_RESET_PROFILE"] = {
    text = L.RESET_PROFILE_CONFIRM,
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function() ns:ResetProfile() end,
}

-- Builds the "Profiles" tab
local function BuildProfilesPage(page)
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

    -- ready-made layouts: replace the current profile after a confirmation
    P.Gap(2, 8)
    Place(CreateHeader(page, L.SECTION_PRESETS), 2)
    Place(CreateNote(page, L.PRESETS_HINT), 2)
    for _, preset in ipairs(ns.PRESETS) do
        Place(CreateButton(page, L["PRESET_" .. preset:upper()], function()
            StaticPopup_Show("TESSERA_APPLY_PRESET", nil, nil, preset)
        end, nil, nil, L["TIP_PRESET_" .. preset:upper()]), 2)
    end
end

---------------------------------------------------------------------------
-- Window, skinned according to the theme (FlareUI or Blizzard)
---------------------------------------------------------------------------
-- Skins a Tessera window with the chosen theme (options window, placement banner, ...)
function ns:SkinWindow(frame, title)
    local t = self:GetThemeInfo(self:GetTheme()).window()
    if title then title:SetTextColor(unpack(t.title)) end
    if t.nineSlice and NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
        self:ApplySkin(frame, { kind = "modern", layout = t.nineSlice, border = t.border, bg = t.bg })
    else
        self:ApplySkin(frame, {
            kind = "backdrop",
            info = {
                bgFile = t.bgFile,
                edgeFile = t.edgeFile,
                edgeSize = t.edgeSize,
                tile = t.tile or false,
                tileSize = t.tileSize,
                insets = { left = t.inset, right = t.inset, top = t.inset, bottom = t.inset },
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
local function BuildHelpPage(page)
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, page, "ScrollFrameTemplate")
    if not ok then scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate") end
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[1], -6)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -48, 24)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(FULL_W - 30, 10)
    scroll:SetScrollChild(content)

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT")
    text:SetWidth(FULL_W - 30)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)
    -- in DataBroker mode, only the help of that mode (how to leave it comes first)
    local shownText
    content.Refresh = function()
        local wanted = ns.brokerModeActive and L.HELP_TEXT_BROKER or L.HELP_TEXT
        if wanted == shownText then return end
        shownText = wanted
        text:SetText(wanted)
        content:SetHeight(text:GetStringHeight() + 20)
        if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
    end
    content:Refresh()
    Register(content)
end

---------------------------------------------------------------------------
-- "Version" tab: installed version and changelog (Changelog.lua)
---------------------------------------------------------------------------
local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

local function ChangelogText()
    local lang = GetLocale() == "frFR" and "fr" or "en"
    local lines = {}
    for _, entry in ipairs(ns.CHANGELOG or {}) do
        table.insert(lines, ("|cffffd100%s|r  |cff999999%s|r"):format(entry.version, entry.date or ""))
        for _, change in ipairs(entry[lang] or entry.en or {}) do
            table.insert(lines, "- " .. change)
        end
        table.insert(lines, "")
    end
    return table.concat(lines, "\n")
end

local function BuildVersionPage(page)
    local version = GetMetadata and GetMetadata(ADDON, "Version") or "?"
    local header = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[1], -6)
    header:SetText(L.VERSION_LABEL:format(version))

    local sub = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -14)
    sub:SetText(L.CHANGELOG_TITLE)

    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, page, "ScrollFrameTemplate")
    if not ok then scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate") end
    scroll:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -48, 24)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(FULL_W - 30, 10)
    scroll:SetScrollChild(content)

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT")
    text:SetWidth(FULL_W - 30)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)
    text:SetText(ChangelogText())
    content:SetHeight(text:GetStringHeight() + 20)
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
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    table.insert(UISpecialFrames, panel:GetName()) -- close with Escape
    -- the placement banner steps aside while this window is open
    panel:HookScript("OnShow", function() ns:UpdatePlacementBanner() end)
    panel:HookScript("OnHide", function() ns:UpdatePlacementBanner() end)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", COL_X[1], -24)
    panel.title:SetText(L.OPTIONS_TITLE)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)

    local lockButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    lockButton:SetSize(170, 22)
    lockButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -46, -20)
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
        for i, p in ipairs(pages) do
            p:SetShown(i == index)
            tabs[i]:SetEnabled(i ~= index)
        end
        ns:RefreshOptions()
    end

    local names = { L.TAB_BLOCK, L.TAB_GENERAL, L.LAUNCHERS, L.TAB_BROKER, L.PROFILES, L.TAB_HELP, L.TAB_VERSION }
    for i, text in ipairs(names) do
        local tab = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        tab:SetHeight(24)
        tab:SetText(text)
        tab:SetScript("OnClick", function() ShowPage(i) end)
        tabs[i] = tab

        local page = CreateFrame("Frame", nil, panel)
        page:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -98)
        page:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
        pages[i] = page
    end

    BuildBlockPage(pages[PAGE_BLOCKS])
    BuildGeneralPage(pages[PAGE_GENERAL])
    BuildLaunchersPage(pages[PAGE_LAUNCHERS], function() ShowPage(PAGE_BLOCKS) end)
    BuildBrokerPage(pages[PAGE_BROKER])
    BuildProfilesPage(pages[PAGE_PROFILES])
    BuildHelpPage(pages[PAGE_HELP])
    BuildVersionPage(pages[PAGE_VERSION])
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
    local gap = 6
    local tabW = (FULL_W - gap * (#visible - 1)) / #visible
    for n, i in ipairs(visible) do
        tabs[i]:SetWidth(tabW)
        tabs[i]:ClearAllPoints()
        tabs[i]:SetPoint("TOPLEFT", panel, "TOPLEFT", COL_X[1] + (n - 1) * (tabW + gap), -58)
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
        if ns.IsSpacerKey(blockKey) and ns.ShowBlockSub then ns.ShowBlockSub(4) end
    end
    ns:SkinOptions()
    panel:Show()
    ns:ApplyOptionsMode()
    ns.ShowOptionsPage(pageIndex or PAGE_BLOCKS)
end

-- Opens the Blocks tab with a given block selected (the DataBroker tab in DataBroker mode)
function ns:OpenOptionsFor(key)
    self:OpenOptions(self.brokerModeActive and PAGE_BROKER or PAGE_BLOCKS, key)
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
    b:Show()
    self:UpdateUndoButton()
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
    button1 = L.WELCOME_HELP,
    button2 = L.WELCOME_LATER,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function() ns:OpenOptions(PAGE_HELP) end,
}

-- After an update: offers to read what's new (Version tab), once per version
StaticPopupDialogs["TESSERA_WHATS_NEW"] = {
    text = L.WHATS_NEW_TEXT,
    button1 = L.WHATS_NEW_SHOW,
    button2 = L.WELCOME_LATER,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function() ns:OpenOptions(PAGE_VERSION) end,
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
    offer:Show()
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
-- Diagnostics: /tessera debug (state useful for development, and dropdown tracing)
---------------------------------------------------------------------------
-- Short description of a frame for debug output: name [strata level]
local function Describe(frame)
    if not frame then return "aucun" end
    local name = frame.GetDebugName and frame:GetDebugName() or frame:GetName() or tostring(frame)
    local strata = frame.GetFrameStrata and frame:GetFrameStrata() or "?"
    local level = frame.GetFrameLevel and frame:GetFrameLevel() or "?"
    return ("%s [%s %s]"):format(name, strata, tostring(level))
end

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
    copyFrame:Show()
    copyFrame.box:SetFocus()
    copyFrame.box:HighlightText()
end

function ns:HideTextWindow()
    if copyFrame then copyFrame:Hide() end
end

local function ShowCopyWindow(text)
    ns:ShowTextWindow("Tessera debug : Ctrl+C pour copier", text)
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

    -- other loaded addons (interface addons often explain display problems)
    local addons = {}
    local count = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or (GetNumAddOns and GetNumAddOns()) or 0
    for i = 1, count do
        local name = C_AddOns and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnInfo(i)
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(i)
        if name and loaded and name ~= ADDON then table.insert(addons, name) end
    end
    Add("Other addons: %s", #addons > 0 and table.concat(addons, ", ") or "none")

    ns:ShowTextWindow(L.BUG_TITLE, table.concat(lines, "\n"))
end

-- Toggles debug mode; when turning it on, prints a report and opens it in the copy window
function ns:DebugReport()
    ns.debug = not ns.debug
    local lines = {}
    local P = function(msg)
        ns.Print(msg)
        table.insert(lines, (tostring(msg):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
    end
    P("|cffffd100[debug] mode " .. (ns.debug and "activé" or "désactivé") .. "|r")
    if not ns.debug then return end

    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
    local _, build, _, interface = GetBuildInfo()
    P(("[debug] Tessera %s, client %s (%s), langue %s"):format(tostring(version), tostring(interface), tostring(build), GetLocale()))
    P(("[debug] style %s, profil %s, verrouillé %s, figé %s, combat %s"):format(
        tostring(ns:GetTheme()), tostring(ns.profileName), tostring(ns.db.locked), tostring(ns:IsLocked()), tostring(ns.state.inCombat)))

    if panel then
        P(("[debug] fenêtre : affichée %s, %s, échelle %.2f, habillage %s"):format(
            tostring(panel:IsShown()), Describe(panel), panel:GetEffectiveScale(), tostring(panel.skinKind)))
    else
        P("[debug] fenêtre : pas encore créée")
    end
    for i, d in ipairs(dropdowns) do
        if i > 3 then break end
        local dd = d.dd
        P(("[debug] menu « %s » : visible %s, souris %s, %s"):format(
            d.label, tostring(dd:IsVisible()), tostring(dd:IsMouseEnabled()), Describe(dd)))
    end

    -- what is under the mouse (hover a menu, then type the command)
    local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
    for i, f in ipairs(foci) do
        if i > 4 then break end
        P("[debug] sous la souris : " .. Describe(f))
    end

    -- merged blocks: border, thickness, corner join and inner corners
    for _, key in ipairs(ns:GetBlockKeys()) do
        local f = ns.frames[key]
        if f and f:IsShown() and f.sharedSides and f.sharedSides ~= "" then
            local info = f.backdropInfo
            local edge = f.nineSliceInfo and f.nineSliceInfo.edge or (info and info.edgeSize) or 0
            P(("[debug] %s : bordure %s, épaisseur %s, raccord %.2f, côtés fusionnés %s, angles rentrants %s"):format(
                ns:GetBlockName(key), tostring(f.borderKey), tostring(edge), f.lineReach or 0,
                f.sharedSides, (f.notchList and f.notchList ~= "") and f.notchList or "aucun"))
        end
    end

    if Menu and Menu.GetManager then
        local ok, manager = pcall(Menu.GetManager)
        local open = ok and manager and manager.GetOpenMenu and manager:GetOpenMenu()
        P("[debug] menu ouvert : " .. (open and Describe(open) or "aucun"))
    else
        P("[debug] système de menus de Blizzard introuvable")
    end
    P("[debug] clique maintenant sur un menu de Tessera : chaque clic sera détaillé ici.")
    P("[debug] raccords d'angle : /tessera debug raccord 0.4 (essaie entre 0 et 1)")
    ShowCopyWindow(table.concat(lines, "\n"))
end
