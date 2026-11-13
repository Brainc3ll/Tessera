local _, ns = ...
local L = ns.L

-- Pages part of the options window: the Look, General, Accessibility, Launchers, Broker and Profiles tabs, with their popups.
-- Shared with the other Options*.lua files through ns.OptionsTools (see Options.lua).
local Tools = ns.OptionsTools
local S = Tools.S
local AttachTip, BuildModuleOptions, COL_W, COL_X = Tools.AttachTip, Tools.BuildModuleOptions, Tools.COL_W, Tools.COL_X
local CreateActionDropdown, CreateButton, CreateCheck = Tools.CreateActionDropdown, Tools.CreateButton, Tools.CreateCheck
local CreateDropdown, CreateEditBox, CreateHeader, CreateNote = Tools.CreateDropdown, Tools.CreateEditBox, Tools.CreateHeader, Tools.CreateNote
local CreateSlider, FULL_W, Field, FitButtonText = Tools.CreateSlider, Tools.FULL_W, Tools.Field, Tools.FitButtonText
local LAUNCHERS, LauncherKeys, NewLayout, Register = Tools.LAUNCHERS, Tools.LauncherKeys, Tools.NewLayout, Tools.Register
local SPACING, ScrollArea, SelectedModuleKey, SortKey = Tools.SPACING, Tools.ScrollArea, Tools.SelectedModuleKey, Tools.SortKey


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
end

---------------------------------------------------------------------------
-- "Accessibility" tab (1.3): what Tessera adds to the game's own accessibility settings
-- (account-wide: they concern the player, not a layout). The game's settings are not
-- redone here: a note points to them.
---------------------------------------------------------------------------
local function BuildAccessPage(page)
    page = ScrollArea(page, 16)
    local P = NewLayout(page)
    local function Place(w, col) return P.Place(w, col) end

    Place(CreateNote(page, L.ACCESS_GAME_NOTE), 1)
    -- colors and motion
    Place(CreateHeader(page, L.SECTION_ACCESS_SEE), 1)
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
        end, nil, nil, L.TIP_LEVEL_PALETTE), 1)
    Place(CreateCheck(page, L.HIGH_CONTRAST,
        function() return ns.sv.highContrast end,
        function(v)
            ns.sv.highContrast = v or nil
            ns:RefreshAllBlocks()
        end, nil, L.TIP_HIGH_CONTRAST), 1)
    -- no fade, no flash, no pulse: blocks and windows change at once
    Place(CreateCheck(page, L.REDUCE_MOTION,
        function() return ns.sv.reduceMotion end,
        function(v)
            ns.sv.reduceMotion = v or nil
            if ns.UpdateFades then ns:UpdateFades() end
        end, nil, L.TIP_REDUCE_MOTION), 1)

    -- text sizes
    Place(CreateHeader(page, L.SECTION_ACCESS_TEXT), 1)
    Place(CreateSlider(page, L.MIN_FONT_SIZE, 0, 24, 1,
        function() return ns.sv.minFontSize or 0 end,
        function(v)
            ns.sv.minFontSize = v > 0 and v or nil
            ns:RefreshAllBlocks()
        end, nil, L.TIP_MIN_FONT_SIZE), 1)
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
                        S.selected = ns:AddLauncher(source)
                        ns:PlaceNearOptions(S.selected)
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
                S.selected = LAUNCHERS
                showBlockPage()
            end })
        end
        for _, key in ipairs(LauncherKeys()) do
            table.insert(entries, { name = ns:GetBlockName(key), func = function()
                S.selected = key
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
                        S.selected = ns:AddBroker(source)
                        ns:PlaceNearOptions(S.selected)
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
                    S.selected = key
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
    -- DaylightUI has panels of its own that take DataBroker objects: how to use them with Tessera
    local daylight = Place(CreateNote(page, L.BROKER_NOTE_DAYLIGHT), 1)
    daylight.isShown = function() return hasLib() and ns:GetDaylightAPI() ~= nil end

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
    end, function() return S.selected end, function(v)
        S.selected = v
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
    Place(CreateDropdown(page, L.THEME, function() return ns:GetStyleChoices() end,
       function() return ns:GetStyleChoice() end,
       function(v)
           ns:PickStyleChoice(v)
           -- the style of a UI that is not installed: say what differs from the real one
           local note = ns:GetThemeNote()
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

-- Shared with the files loaded after this one
Tools.BuildAccessPage = BuildAccessPage
Tools.BuildBrokerPage = BuildBrokerPage
Tools.BuildGeneralPage = BuildGeneralPage
Tools.BuildLaunchersPage = BuildLaunchersPage
Tools.BuildLookPage = BuildLookPage
Tools.BuildProfilesPage = BuildProfilesPage
Tools.DataModuleKeys = DataModuleKeys

