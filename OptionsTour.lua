local ADDON, ns = ...
local L = ns.L

-- Tour part of the options window: welcome, tutorial, news, style offer, text window and the bug report.
-- Shared with the other Options*.lua files through ns.OptionsTools (see Options.lua).
local Tools = ns.OptionsTools
local S = Tools.S
local Blink, CHANGELOG_TOPIC, GetMetadata, NEWS_VERSION = Tools.Blink, Tools.CHANGELOG_TOPIC, Tools.GetMetadata, Tools.NEWS_VERSION
local PAGE_ABOUT, PAGE_ACCESS, PAGE_BLOCKS, PAGE_LOOK = Tools.PAGE_ABOUT, Tools.PAGE_ACCESS, Tools.PAGE_BLOCKS, Tools.PAGE_LOOK


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
-- "Show me": opens the place and makes the setting blink, like the search does
local function NewsKey()
    return ns.db.blocks.gold and "gold" or ns.order[1]
end
-- a widget of the Blocks tab head (the "On screen" switch, "Place by pixel")
local function ShowHeadWidget(getWidget, label, tip)
    return function()
        ns:OpenOptionsFor(NewsKey())
        ns:RefreshOptions()
        ns:ShowOptionHelp(label, tip)
        C_Timer.After(0, function()
            local w = getWidget()
            if w and w:IsShown() then Blink(w, true) end
        end)
    end
end
-- a setting row, found by its label (the first one: they are the same for every block)
local function ShowRow(page, label, selectBlock)
    return function()
        if selectBlock then ns:OpenOptionsFor(NewsKey()) end
        for _, r in ipairs(ns.optionRows) do
            if r.label == label and r.page == page then
                ns.GoToOption(r, ns.ShowOptionsPage)
                return
            end
        end
        ns:OpenOptions(page)
    end
end
local TUTORIAL_STEPS = {
    { text = "TUTORIAL_1" },
    { text = "TUTORIAL_8", layouts = true, action = "TUTORIAL_DO_KEEP", run = function() ns:KeepTourLayout() end },
    { text = "TUTORIAL_9", action = "TUTORIAL_DO_BLOCK",
      run = ShowHeadWidget(function() return ns.blockSwitch end, L.ENABLED, L.TIP_ENABLED) },
    { text = "TUTORIAL_11", action = "TUTORIAL_DO_BLOCK",
      run = ShowHeadWidget(function() return ns.placeButton end, L.PLACE_BLOCK, L.TIP_PLACE_BLOCK) },
    { text = "TUTORIAL_2", action = "TUTORIAL_DO_UNLOCK", run = function() ns:SetLocked(false) end },
    { text = "TUTORIAL_3" },
    { text = "TUTORIAL_4" },
    { text = "TUTORIAL_5" },
    { text = "TUTORIAL_6", action = "TUTORIAL_DO_LOOK", run = function() ns:OpenOptions(PAGE_LOOK) end },
    { text = "TUTORIAL_12", action = "TUTORIAL_DO_ACCESS", run = ShowRow(PAGE_ACCESS, L.HIGH_CONTRAST) },
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
    if S.panel and S.panel:IsShown() then S.panel:Hide() end -- the blocks must be visible
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
        if S.aboutContent then S.aboutContent:ShowTopic(CHANGELOG_TOPIC) end
    end,
}

---------------------------------------------------------------------------
-- "What's new in 1.3": a small window after an update (and from the Help tab). One
-- short line per big change, each with a button that opens the right place.
---------------------------------------------------------------------------
local NEWS_ROWS = {
    { text = "NEWS_1", run = ShowHeadWidget(function() return ns.blockSwitch end, L.ENABLED, L.TIP_ENABLED) },
    { text = "NEWS_2", run = ShowHeadWidget(function() return ns.placeButton end, L.PLACE_BLOCK, L.TIP_PLACE_BLOCK) },
    { text = "NEWS_3", run = function()
        ns:OpenOptions(PAGE_BLOCKS)
        ns:ShowOptionHelp(L.SEARCH, L.TIP_SEARCH)
        C_Timer.After(0, function()
            if S.panel and S.panel.search then Blink(S.panel.search, true) end
        end)
    end },
    { text = "NEWS_4", run = ShowRow(PAGE_BLOCKS, L.APPLY_STYLE_TO, true) },
    { text = "NEWS_5", run = ShowRow(PAGE_ACCESS, L.HIGH_CONTRAST) },
}
local news
local NEWS_W, NEWS_TEXT_W, NEWS_BUTTON_W = 440, 290, 96

function ns:ShowNews()
    if not news then
        news = CreateFrame("Frame", "TesseraNews", UIParent, "BackdropTemplate")
        news:SetWidth(NEWS_W)
        news:SetPoint("TOP", UIParent, "TOP", 0, -140)
        news:SetFrameStrata("FULLSCREEN_DIALOG")
        news:SetClampedToScreen(true)
        news:SetMovable(true)
        news:EnableMouse(true)
        news:RegisterForDrag("LeftButton")
        news:SetScript("OnDragStart", news.StartMoving)
        news:SetScript("OnDragStop", news.StopMovingOrSizing)
        news.title = news:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        news.title:SetPoint("TOPLEFT", 16, -14)
        news.title:SetText(L.NEWS_TITLE:format(NEWS_VERSION))
        local close = CreateFrame("Button", nil, news, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        local y = 40
        for _, row in ipairs(NEWS_ROWS) do
            local text = news:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("TOPLEFT", 16, -y)
            text:SetWidth(NEWS_TEXT_W)
            text:SetJustifyH("LEFT")
            text:SetSpacing(3)
            text:SetText(L[row.text])
            local button = CreateFrame("Button", nil, news, "UIPanelButtonTemplate")
            button:SetSize(NEWS_BUTTON_W, 22)
            button:SetText(L.TUTORIAL_DO_BLOCK)
            button:SetPoint("TOPRIGHT", news, "TOPLEFT", NEWS_W - 16, -y)
            button:SetScript("OnClick", row.run)
            y = y + math.max(text:GetStringHeight(), 22) + 12
        end
        local all = CreateFrame("Button", nil, news, "UIPanelButtonTemplate")
        all:SetSize(190, 22)
        all:SetText(L.NEWS_ALL)
        all:SetPoint("BOTTOMLEFT", 16, 14)
        all:SetScript("OnClick", function()
            news:Hide()
            ns:OpenOptions(PAGE_ABOUT)
            if S.aboutContent then S.aboutContent:ShowTopic(CHANGELOG_TOPIC) end
        end)
        local done = CreateFrame("Button", nil, news, "UIPanelButtonTemplate")
        done:SetSize(96, 22)
        done:SetText(L.TUTORIAL_DONE)
        done:SetPoint("BOTTOMRIGHT", -16, 14)
        done:SetScript("OnClick", function() news:Hide() end)
        news:SetHeight(y + 48)
    end
    self:SkinWindow(news, news.title)
    ns:ShowSideWindow(news)
end

-- Shows the welcome popup once per saved-variables file (first install), or the
-- "what's new" popup when the installed version changed since last time
function ns:ShowWelcomeIfNeeded()
    if not self.sv then return end
    local version = GetMetadata and GetMetadata(ADDON, "Version") or nil
    -- (welcomed but no version saved: installed before this popup existed, i.e. updated)
    if self.sv.welcomed and version and self.sv.lastVersion ~= version then
        self.sv.lastVersion = version
        -- a version with its own news window (1.3.x): shown once, instead of the popup
        if version:sub(1, #NEWS_VERSION + 1) == NEWS_VERSION .. "." and self.sv.newsSeen ~= NEWS_VERSION
            and not self.brokerModeActive then
            self.sv.newsSeen = NEWS_VERSION
            self:ShowNews()
            return
        end
        StaticPopup_Show("TESSERA_WHATS_NEW", version)
        return
    end
    -- a new install has nothing to catch up on
    if not self.sv.welcomed and version and version:sub(1, #NEWS_VERSION + 1) == NEWS_VERSION .. "." then
        self.sv.newsSeen = NEWS_VERSION
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
    -- not on top of Tessera's other popups (welcome, DataBroker mode, what's new), nor of another interface's tour
    local busy = StaticPopup_Visible and (StaticPopup_Visible("TESSERA_WELCOME")
        or StaticPopup_Visible("TESSERA_BROKER_MODE") or StaticPopup_Visible("TESSERA_WHATS_NEW"))
    if InCombatLockdown() or busy or self:OtherUIBusy() then
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
    -- in front of the options, in the middle of the screen: it does not push them aside
    copyFrame.centered = true
    ns:ShowSideWindow(copyFrame)
    copyFrame:ClearAllPoints()
    copyFrame:SetPoint("CENTER", 0, 120)
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
