local ADDON, ns = ...
local L = ns.L

-- Window part of the options window: side windows, folding and zoom, the search box, the main window (BuildPanel), Open / Toggle, the Blizzard settings page.
-- Shared with the other Options*.lua files through ns.OptionsTools (see Options.lua).
local Tools = ns.OptionsTools
local S = Tools.S
local ALL, AttachTip, BuildAboutPage, BuildAccessPage = Tools.ALL, Tools.AttachTip, Tools.BuildAboutPage, Tools.BuildAccessPage
local BuildBlockPage, BuildBrokerPage, BuildGeneralPage = Tools.BuildBlockPage, Tools.BuildBrokerPage, Tools.BuildGeneralPage
local BuildHelpPage, BuildLaunchersPage, BuildLookPage = Tools.BuildHelpPage, Tools.BuildLaunchersPage, Tools.BuildLookPage
local BuildProfilesPage, DataModuleKeys, GROUP_PREFIX, HELP_W = Tools.BuildProfilesPage, Tools.DataModuleKeys, Tools.GROUP_PREFIX, Tools.HELP_W
local HIDDEN_IN_BROKER_MODE, NAV_ORDER, NAV_W, PAGE_ABOUT = Tools.HIDDEN_IN_BROKER_MODE, Tools.NAV_ORDER, Tools.NAV_W, Tools.PAGE_ABOUT
local PAGE_ACCESS, PAGE_BLOCKS, PAGE_BROKER, PAGE_GENERAL = Tools.PAGE_ACCESS, Tools.PAGE_BLOCKS, Tools.PAGE_BROKER, Tools.PAGE_GENERAL
local PAGE_HELP, PAGE_LAUNCHERS, PAGE_LOOK, PAGE_PROFILES = Tools.PAGE_HELP, Tools.PAGE_LAUNCHERS, Tools.PAGE_LOOK, Tools.PAGE_PROFILES
local PAGE_TOP, PANEL_H, PANEL_W, Register = Tools.PAGE_TOP, Tools.PANEL_H, Tools.PANEL_W, Tools.Register
local SEARCH_W, TOPBAR_RIGHT, ValidateSelection, pages = Tools.SEARCH_W, Tools.TOPBAR_RIGHT, Tools.ValidateSelection, Tools.pages
local sideWindows, tabs = Tools.sideWindows, Tools.tabs


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
    if not (S.panel and S.panel:IsShown() and frame and frame:IsShown()) then return end
    if frame.centered then return end -- the copy window sits in front, in the middle
    local screenW = UIParent:GetWidth() * UIParent:GetEffectiveScale()
    local ps, fs = S.panel:GetEffectiveScale(), frame:GetEffectiveScale()
    local left, right = (S.panel:GetLeft() or 0) * ps, (S.panel:GetRight() or 0) * ps
    local need = (frame:GetWidth() + 12) * fs
    frame:ClearAllPoints()
    if screenW - right >= need then
        frame:SetPoint("TOPLEFT", S.panel, "TOPRIGHT", 8, 0)
    elseif left >= need then
        frame:SetPoint("TOPRIGHT", S.panel, "TOPLEFT", -8, 0)
    else
        S.panel:ClearAllPoints()
        S.panel:SetPoint("LEFT", UIParent, "LEFT", 0, 0)
        S.panel.dockMoved = true -- no room beside it: it comes back to the middle when the window closes
        frame:SetPoint("TOPLEFT", S.panel, "TOPRIGHT", 8, 0)
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
            elseif S.panel and S.panel.dockMoved then
                -- the window that pushed the options aside is closed: they go back to the middle
                S.panel.dockMoved = nil
                S.panel:ClearAllPoints()
                S.panel:SetPoint("CENTER")
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
    S.panel:SetScale(math.max(0.5, math.max(0.6, scale) * zoom))
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
    local help = CreateFrame("Frame", nil, S.panel)
    local line = help:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    help:SetPoint("TOPLEFT", S.panel, "TOPLEFT", PANEL_W - HELP_W, PAGE_TOP)
    help:SetPoint("BOTTOMRIGHT", S.panel, "BOTTOMRIGHT", -16, 16)
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
            while f and f ~= S.panel do f = f.GetParent and f:GetParent() or nil end
            if f ~= S.panel then return false end
        end
        title:ClearAllPoints()
        if name and tip then
            logo:Hide()
            title:SetPoint("TOPLEFT", help, "TOPLEFT", 0, -6)
            title:SetText(name)
            body:SetText(tip)
        else
            -- at rest: the hints (on the Blocks tab, what a group selection does first)
            local text = L.HELP_PANEL_REST .. "\n\n" .. L.HELP_PANEL_ZOOM
            if S.currentPage == PAGE_BLOCKS then text = L.GROUP_HINT .. "\n\n" .. text end
            logo:Show()
            title:SetPoint("TOPLEFT", help, "TOPLEFT", 0, -136)
            title:SetText(L.OPTIONS_TITLE)
            body:SetText(text)
        end
        return true
    end
    ns:ShowOptionHelp()
    S.panel.help = help
end

-- Folds the window to its top bar (to see what is behind it), or unfolds it. Not
-- saved: the window always opens unfolded. The top edge stays where it is.
local function SetFolded(on)
    if (S.panel.folded and true or false) == (on and true or false) then return end
    S.panel.folded = on and true or nil
    local left, top = S.panel:GetLeft(), S.panel:GetTop()
    S.panel:SetHeight(on and TOPBAR_H or PANEL_H)
    if left and top then
        S.panel:ClearAllPoints()
        S.panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
    S.panel.nav:SetShown(not on)
    S.panel.help:SetShown(not on)
    for i, p in ipairs(pages) do p:SetShown(not on and i == S.currentPage) end
    if on and S.panel.results then S.panel.results:Hide() end
    S.panel.fold:Refresh()
    DockSideWindows()
end
ns.SetOptionsFolded = function(_, on) if S.panel then SetFolded(on) end end

local function BuildFoldButton()
    local b = CreateFrame("Button", nil, S.panel)
    b:SetSize(28, 28)
    b:SetPoint("TOPRIGHT", S.panel, "TOPRIGHT", -40, -17)
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b.Refresh = function(self)
        -- arrow up: fold; arrow down: unfold (a shape, the tooltip names it)
        local name = S.panel.folded and "ScrollDown" or "ScrollUp"
        self:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-" .. name .. "-Up")
        self:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-" .. name .. "-Down")
    end
    b:SetScript("OnClick", function() SetFolded(not S.panel.folded) end)
    b.Activate = function(self) self:Click() end
    AttachTip(b, L.FOLD_WINDOW, L.TIP_FOLD_WINDOW)
    b:Refresh()
    S.panel.fold = b
end

-- Size of the windows: Shift + mouse wheel on any Tessera window, 70 % to 130 %, saved
-- for the account. The options window takes it on top of its fit to small screens; the
-- other windows (placement banner, tour, copy window...) follow it (ns:FollowWindowSize).
local zoomWindows = {}
local function ApplyZoom()
    FitPanelToScreen()
    local zoom = ns.sv and ns.sv.optionsZoom or 1
    for frame in pairs(zoomWindows) do frame:SetScale(zoom) end
    if S.panel and S.panel.zoomText then S.panel.zoomText:Refresh() end
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

-- A Tessera window other than the options: takes the windows' size and changes it
-- with Shift + mouse wheel (called by SkinWindow)
function ns:FollowWindowSize(frame)
    if not frame or frame == S.panel then return end
    if not zoomWindows[frame] then
        zoomWindows[frame] = true
        ZoomOnShiftWheel(frame)
    end
    frame:SetScale(self.sv and self.sv.optionsZoom or 1)
end

-- Help tooltips of Tessera's windows: bigger than the game's own at 100 % (hard to read
-- next to the pointer), and sized with the windows. The game's tooltip is shared, so its
-- scale is given back as soon as it hides.
local TOOLTIP_BASE = 1.25
local function OwnedByTesseraWindow(tooltip)
    local f = tooltip:GetOwner()
    while f do
        if f == S.panel or zoomWindows[f] then return true end
        f = f.GetParent and f:GetParent() or nil
    end
    return false
end
local windowTipScale
GameTooltip:HookScript("OnShow", function(self)
    if windowTipScale or not OwnedByTesseraWindow(self) then return end
    windowTipScale = self:GetScale()
    self:SetScale(windowTipScale * TOOLTIP_BASE * (ns.sv and ns.sv.optionsZoom or 1))
end)
GameTooltip:HookScript("OnHide", function(self)
    if windowTipScale then self:SetScale(windowTipScale) windowTipScale = nil end
end)

-- The size in the top bar, next to the fold arrow ("100 %"); its tooltip says how to change it
local function BuildZoomText()
    local f = CreateFrame("Frame", nil, S.panel)
    f:SetSize(52, 34)
    f:SetPoint("RIGHT", S.panel.fold, "LEFT", -6, 0)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOP", 0, -2)
    -- a small reminder under the size: how to change it
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOP", fs, "BOTTOM", 0, -1)
    hint:SetText(L.ZOOM_HINT)
    -- never wider than its room (a long translation): the text shrinks, then is cut
    local HINT_W = 62
    hint:SetWidth(HINT_W)
    hint:SetWordWrap(false)
    local font, size, flags = hint:GetFont()
    if font and size and hint.GetUnboundedStringWidth then
        while size > 8 and hint:GetUnboundedStringWidth() > HINT_W do
            size = size - 1
            hint:SetFont(font, size, flags)
        end
    end
    f.Refresh = function()
        fs:SetText(math.floor((ns.sv.optionsZoom or 1) * 100 + 0.5) .. " %")
    end
    f:EnableMouse(true)
    AttachTip(f, L.WINDOW_ZOOM, L.TIP_WINDOW_ZOOM)
    f:Refresh()
    S.panel.zoomText = f
end

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
        [PAGE_LAUNCHERS] = L.LAUNCHERS, [PAGE_BROKER] = L.TAB_BROKER, [PAGE_PROFILES] = L.PROFILES,
        [PAGE_ACCESS] = L.SECTION_ACCESSIBILITY }
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

-- the row lights up three times ("Fewer animations": it stays lit for a moment)
-- A gold frame around a widget: seen whatever its colors (the "On screen" switch,
-- a button), a shape as well as a color (high contrast). Shown and hidden as one.
local function BlinkFrame(w)
    if w.blinkFrame then return w.blinkFrame end
    local f = CreateFrame("Frame", nil, w)
    f:SetPoint("TOPLEFT", -4, 4)
    f:SetPoint("BOTTOMRIGHT", 4, -4)
    f:SetFrameLevel(w:GetFrameLevel() + 10)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                            { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 0.82, 0, 1)
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if side[3] then t:SetHeight(3) else t:SetWidth(3) end
    end
    f:Hide()
    w.blinkFrame = f
    return f
end

local function Blink(w, framed)
    local light = not framed and w.hover
    if not light then light = BlinkFrame(w) end
    if ns.sv and ns.sv.reduceMotion then
        light:SetAlpha(2.5)
        light:Show()
        C_Timer.After(1.5, function() light:Hide() end)
        return
    end
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
        if r.page == PAGE_BROKER and r.sub and ns.ShowBrokerSub then ns.ShowBrokerSub(r.sub) end
    end
    -- a setting in a folded section: the section opens
    if r.foldSection and r.foldSection.folded then r.foldSection.folded = false end
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
    local ok, box = pcall(CreateFrame, "EditBox", nil, S.panel, "SearchBoxTemplate")
    if not ok then box = CreateFrame("EditBox", nil, S.panel, "InputBoxTemplate") end
    box:SetSize(SEARCH_W, 20)
    box:SetPoint("TOPRIGHT", S.panel, "TOPRIGHT", -(TOPBAR_RIGHT + 170 + 12), -21)
    box:SetAutoFocus(false)
    if type(box.Instructions) == "table" then box.Instructions:SetText(L.SEARCH) end
    AttachTip(box, L.SEARCH, L.TIP_SEARCH)
    S.panel.search = box

    -- result list under the box, over the page (a child of the window, raised)
    local results = CreateFrame("Frame", nil, S.panel, "BackdropTemplate")
    results:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -4)
    results:SetWidth(SEARCH_W + 160)
    results:SetFrameLevel(S.panel:GetFrameLevel() + 30)
    if results.SetBackdrop then
        results:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        results:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
        results:SetBackdropBorderColor(1, 0.82, 0, 0.6)
    end
    results:Hide()
    S.panel.results = results
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
    BuildZoomText()
    BuildSearch(showPage)
    -- Shift + wheel over the window: its size
    ZoomOnShiftWheel(S.panel)
    -- always opens unfolded
    S.panel:HookScript("OnShow", function() SetFolded(false) end)
end

-- Ctrl + Z undoes while a frame is shown (placement banner, options window); every
-- other key goes on to the game. Keyboard propagation can only be changed out of
-- combat, so the frame stops listening to the keyboard during combat (never
-- swallowing a key). A text box with the focus keeps its own Ctrl + Z.
local function ListenForUndo(frame)
    local function Listen(on)
        if InCombatLockdown() then return end
        frame:SetPropagateKeyboardInput(true)
        frame:EnableKeyboard(on)
    end
    frame:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end
        -- a frame may take other keys too (placing to the pixel: arrows, Enter, Escape)
        if self.OnOwnKey and self:OnOwnKey(key) then
            self:SetPropagateKeyboardInput(false)
            return
        end
        local undo = key == "Z" and IsControlKeyDown()
        self:SetPropagateKeyboardInput(not undo)
        if undo then ns:Undo() end
    end)
    frame:SetScript("OnKeyUp", function(self, key)
        if self.OnOwnKeyUp then self:OnOwnKeyUp(key) end
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
    end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:HookScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self:EnableKeyboard(false)
        elseif event == "PLAYER_REGEN_ENABLED" then
            Listen(self:IsShown())
        end
    end)
    frame:HookScript("OnShow", function() Listen(true) end)
    frame:HookScript("OnHide", function() Listen(false) end)
    Listen(frame:IsShown())
end
ns.ListenForUndo = ListenForUndo

-- Creates the main options window, its tabs and pages (called once, lazily)
local function BuildPanel()
    ValidateSelection()

    S.panel = CreateFrame("Frame", "TesseraOptions", UIParent, "BackdropTemplate")
    S.panel:SetSize(PANEL_W, PANEL_H)
    S.panel:SetPoint("CENTER")
    S.panel:SetFrameStrata("DIALOG")
    S.panel:SetClampedToScreen(true)
    S.panel:SetMovable(true)
    S.panel:EnableMouse(true)
    S.panel:RegisterForDrag("LeftButton")
    S.panel:SetScript("OnDragStart", S.panel.StartMoving)
    S.panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.dockMoved = nil -- the player put it there
        DockSideWindows()
    end)
    table.insert(UISpecialFrames, S.panel:GetName()) -- close with Escape
    ListenForUndo(S.panel) -- Ctrl + Z: same as in placement mode (taking blocks off, a style...)
    -- the placement banner steps aside while this window is open
    S.panel:HookScript("OnShow", function()
        -- opened again: back in the middle of the screen (not when it only comes back
        -- from placement, where the player had put it)
        S.panel.dockMoved = nil
        if not S.panel.keepPlace then
            S.panel:ClearAllPoints()
            S.panel:SetPoint("CENTER")
        end
        FitPanelToScreen()
        ns:UpdatePlacementBanner()
        DockSideWindows()
        if ns.HideMicroMenuList then ns:HideMicroMenuList() end
        if ns.RefreshPins then ns:RefreshPins() end -- a pinned tooltip under the window steps aside
    end)
    S.panel:HookScript("OnHide", function()
        if ns.RefreshPins then ns:RefreshPins() end -- the pinned tooltips it covered come back
        ns:UpdatePlacementBanner()
        ns:CleanMemorySoon() -- the memory the window used is freed once it is closed
    end)

    -- top bar (1.3): logo, title, the page's sentence, search, lock, fold, close
    local logo = S.panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(32, 32)
    logo:SetPoint("TOPLEFT", 18, -16)
    logo:SetTexture("Interface\\AddOns\\Tessera\\Media\\Icon.png")
    S.panel.logo = logo
    S.panel.title = S.panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    S.panel.title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    S.panel.title:SetText(L.OPTIONS_TITLE)
    -- one plain sentence on what the open page is for, next to the title
    S.panel.hint = S.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    S.panel.hint:SetPoint("TOPLEFT", S.panel, "TOPLEFT", NAV_W, -20)
    S.panel.hint:SetPoint("RIGHT", S.panel, "RIGHT", -(SEARCH_W + 170 + TOPBAR_RIGHT + 16), 0)
    S.panel.hint:SetHeight(30)
    S.panel.hint:SetJustifyH("LEFT")
    S.panel.hint:SetJustifyV("MIDDLE")
    S.panel.hint:SetTextColor(0.85, 0.8, 0.68)

    local close = CreateFrame("Button", nil, S.panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)

    local lockButton = CreateFrame("Button", nil, S.panel, "UIPanelButtonTemplate")
    lockButton:SetSize(170, 22)
    lockButton:SetPoint("TOPRIGHT", S.panel, "TOPRIGHT", -TOPBAR_RIGHT, -20)
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
        if index == PAGE_BROKER and not ns.modules[S.selected] then S.selected = DataModuleKeys()[1] or ALL end
        S.currentPage = index
        S.panel.hint:SetText(L["PAGE_HINT_" .. index] or "")
        if ns.ShowOptionHelp then ns:ShowOptionHelp() end -- help panel back to rest
        for i, p in ipairs(pages) do
            p:SetShown(i == index)
            tabs[i]:SetSelected(i == index)
        end
        ns:RefreshOptions()
    end

    local names = { L.TAB_BLOCK, L.TAB_LOOK, L.TAB_GENERAL, L.LAUNCHERS, L.TAB_BROKER, L.PROFILES, L.TAB_HELP,
        L.TAB_ABOUT, L.SECTION_ACCESSIBILITY }
    -- the navigation list: a thin frame, one line per page, the open one marked by a gold
    -- bar and white text (also a shape, not only a color: the bar)
    local nav = CreateFrame("Frame", nil, S.panel, "BackdropTemplate")
    nav:SetPoint("TOPLEFT", S.panel, "TOPLEFT", 16, PAGE_TOP)
    nav:SetPoint("BOTTOMLEFT", S.panel, "BOTTOMLEFT", 16, 16)
    nav:SetWidth(NAV_W - 24)
    if nav.SetBackdrop then
        nav:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        nav:SetBackdropColor(1, 1, 1, 0.03)
        nav:SetBackdropBorderColor(0.55, 0.43, 0.2, 0.6)
    end
    S.panel.nav = nav
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

        local page = CreateFrame("Frame", nil, S.panel)
        page:SetPoint("TOPLEFT", S.panel, "TOPLEFT", NAV_W, PAGE_TOP)
        page:SetPoint("BOTTOMRIGHT", S.panel, "BOTTOMRIGHT", -HELP_W, 0)
        page.pageIndex = i
        pages[i] = page
    end

    BuildBlockPage(pages[PAGE_BLOCKS])
    BuildLookPage(pages[PAGE_LOOK])
    BuildGeneralPage(pages[PAGE_GENERAL])
    BuildAccessPage(pages[PAGE_ACCESS])
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
    S.panel:Hide() -- frames are visible on creation: ToggleOptions will show it
end

-- Shows the tabs of the current mode (all of them, or only DataBroker, Help and
-- Version in DataBroker mode), sharing the full content width
function ns:ApplyOptionsMode()
    if not S.panel then return end
    local visible = {}
    for _, i in ipairs(NAV_ORDER) do
        local shown = not (ns.brokerModeActive and HIDDEN_IN_BROKER_MODE[i])
        tabs[i]:SetShown(shown)
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
    if ns.ShowOptionsPage and ns.brokerModeActive and HIDDEN_IN_BROKER_MODE[S.currentPage] then
        ns.ShowOptionsPage(PAGE_BROKER)
    end
end

-- Opens the options on a tab (PAGE_* above), and optionally on a given block
function ns:OpenOptions(pageIndex, blockKey)
    if not S.panel then BuildPanel() end
    if blockKey and ns.db.blocks[blockKey] then
        S.selected = blockKey
        if ns.IsSpacerKey(blockKey) and ns.ShowBlockSub then ns.ShowBlockSub(5) end
    elseif type(blockKey) == "string" and blockKey:sub(1, #GROUP_PREFIX) == GROUP_PREFIX then
        S.selected = blockKey -- a group ("*group:" and its head block), checked by ValidateSelection
        ValidateSelection()
    end
    ns:SkinOptions()
    S.panel:Show()
    ns:ApplyOptionsMode()
    ns.ShowOptionsPage(pageIndex or PAGE_BLOCKS)
end

-- Opens the Blocks tab on "All blocks", at a sub-tab (2 Text, 3 Frame): the shortcuts
-- of the Look tab, where players look first for the look of every block
function ns:OpenAllBlocks(sub)
    S.selected = ALL
    self:OpenOptions(PAGE_BLOCKS)
    if ns.ShowBlockSub then ns.ShowBlockSub(sub) end
    ns:RefreshOptions()
end

-- Opens the Blocks tab with a given block selected (the DataBroker tab in DataBroker mode)
-- (a right-click on a block: the options open on "This block", its own settings)
-- Block chosen in the Blocks tab (nil for a group or "All blocks"), and setting it
-- without opening the window (placing to the pixel: a click on another block)
function ns:GetOptionsSelection()
    if S.selected ~= ALL and self.db.blocks[S.selected] then return S.selected end
end
function ns:SetOptionsSelection(key)
    if key == ALL or self.db.blocks[key] then S.selected = key end
end

function ns:OpenOptionsFor(key)
    self:OpenOptions(self.brokerModeActive and PAGE_BROKER or PAGE_BLOCKS, key)
    if not self.brokerModeActive and self.ShowBlockSub then self.ShowBlockSub(5) end
end

-- Shows or hides the options window
function ns:ToggleOptions()
    if not S.panel then BuildPanel() end
    if S.panel:IsShown() then
        S.panel:Hide()
    else
        ns:SkinOptions()
        S.panel:Show()
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
        if not S.panel or not S.panel:IsShown() then ns:ToggleOptions() end
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

-- Shared with the files loaded after this one
Tools.Blink = Blink
Tools.ListenForUndo = ListenForUndo

