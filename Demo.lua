local _, ns = ...
local L = ns.L

-- ========================================================================
-- Demo.lua: demo mode, a big showcase of every block (Help tab, /tessera demo)
-- ========================================================================
-- Every information block, sorted by category in columns, each column under a
-- title (a spacer block in text mode), with sample values (preview mode) and a
-- label. A banner says it is a demo, switches the style with arrows, can hide
-- Blizzard's interface and ends the demo.
-- It is not a layout: the player's profile is copied aside (also in the saved
-- variables, in case of /reload or logout) and comes back intact when the demo
-- ends; blocks stay locked meanwhile. A fight ends the demo (after the fight:
-- blocks with click overlays cannot move during one).
-- Columns are scaled down to fit screens narrower than 1920 pixels.

local CATEGORIES = {
    { title = "DEMO_CAT_CHARACTER", keys = { "gold", "bags", "durability", "xp", "rested", "stats", "regen", "speed",
        "talents", "itemLevel" } },
    { title = "DEMO_CAT_SOCIAL", keys = { "friends", "guild", "group", "whispers", "mail", "loot" } },
    { title = "DEMO_CAT_WORLD", keys = { "zone", "subzone", "coords", "time", "serverTime", "hearthstone", "instances",
        "reset" } },
    { title = "DEMO_CAT_PROGRESS", keys = { "reputation", "currency", "quests", "goal", "profession1", "profession2",
        "cooking", "firstAid", "fishing", "ammo", "reagents" } },
    { title = "DEMO_CAT_SYSTEM", keys = { "fps", "latency", "memory", "volume", "played" } },
    { title = "DEMO_CAT_FOREVER", keys = { "legacy", "comprehension", "camping", "honor", "weaponSkills" } },
}
local COLUMN_W, COLUMN_GAP, TOP = 272, 18, -130


function ns:IsDemoActive()
    return self.sv ~= nil and self.sv.demoBackup ~= nil
end

-- The information blocks of the demo, by category (blocks of a later version that
-- belong to no category go to the System column)
local function Columns()
    local listed, columns = {}, {}
    for _, cat in ipairs(CATEGORIES) do
        local keys = {}
        for _, key in ipairs(cat.keys) do
            if ns.modules[key] then
                table.insert(keys, key)
                listed[key] = true
            end
        end
        table.insert(columns, { title = cat.title, keys = keys })
    end
    for _, key in ipairs(ns.order) do
        if ns.modules[key] and not listed[key] then table.insert(columns[5].keys, key) end
    end
    return columns
end

-- Builds the demo in the (fresh) active profile
local function BuildDemo(self)
    local blocks = self.db.blocks
    for _, cfg in pairs(blocks) do
        cfg.enabled, cfg.point, cfg.dock, cfg.anchor = false, nil, nil, nil
    end
    local columns = Columns()
    local total = #columns * COLUMN_W + (#columns - 1) * COLUMN_GAP
    -- smaller screens: the columns shrink to fit
    local scale = math.min(1, (UIParent:GetWidth() - 40) / total)
    local x = -total / 2
    for i, column in ipairs(columns) do
        -- the column's title: a spacer in text mode
        local title = self.SPACER_PREFIX .. ("demo%d"):format(i)
        blocks[title] = self:GetBlockDefaults(title)
        local t = blocks[title]
        t.spacerMode, t.spacerText = "text", L[column.title]
        t.width, t.autoWidth, t.height, t.justify = COLUMN_W, false, 26, "CENTER"
        t.point = { "TOPLEFT", "TOP", math.floor(x + 0.5), TOP }
        t.scale = scale
        local previous = title
        for _, key in ipairs(column.keys) do
            local cfg = blocks[key]
            if cfg then
                cfg.enabled, cfg.showIcon, cfg.showLabel = true, true, true
                -- fixed width: every column the same, none overlaps the next one
                cfg.width, cfg.autoWidth, cfg.justify, cfg.hideEmpty = COLUMN_W, false, "LEFT", false
                cfg.dock = { to = previous, side = "BOTTOM" }
                previous = key
            end
        end
        x = x + COLUMN_W + COLUMN_GAP
    end
    self.db.locked = true
    self.db.theme = self.demoTheme or self:GetTheme()
    self:ApplyTheme(self.db.theme)
end

-- The style switcher of the banner: the styles of the Look tab, one after the other
local function ThemeIndex(self)
    local list = self:GetAvailableThemes()
    for i, t in ipairs(list) do
        if t.key == self:GetTheme() then return i, list end
    end
    return 1, list
end

local function UpdateBanner(self)
    local b = self.demoBanner
    if not b then return end
    local i, list = ThemeIndex(self)
    b.style:SetText(L.DEMO_STYLE:format(list[i] and list[i].name or "?", i, #list))
    self:SkinWindow(b, b.title)
end

-- Fades the game's interface out, or back in: every frame of the interface (Blizzard's
-- and other addons', e.g. FlareUI's) except Tessera's blocks, the demo banner and the
-- tooltips. Alpha only: nothing is moved or hidden for real.
function ns:SetDemoHideUI(hide)
    self.demoUIHidden = hide or nil
    self.demoAlpha = self.demoAlpha or {}
    if hide then
        local keep = { [self.demoBanner or false] = true, [GameTooltip] = true }
        for _, f in pairs(self.frames) do keep[f] = true end
        for _, f in ipairs({ UIParent:GetChildren() }) do
            -- some of the game's frames are forbidden to addons (store, secure
            -- dialogs): they cannot even be asked their name, so they are skipped
            local forbidden = f.IsForbidden and f:IsForbidden()
            if not forbidden and not keep[f] and self.demoAlpha[f] == nil then
                local ok, name = pcall(f.GetName, f)
                name = ok and name or ""
                -- popups, menus and tooltips stay visible
                local keepIt = name:match("^StaticPopup") or name:match("^DropDownList") or name:match("Tooltip")
                if not keepIt then
                    local okAlpha, alpha = pcall(f.GetAlpha, f)
                    if okAlpha and pcall(f.SetAlpha, f, 0) then self.demoAlpha[f] = alpha end
                end
            end
        end
    else
        for f, alpha in pairs(self.demoAlpha) do pcall(f.SetAlpha, f, alpha) end
        self.demoAlpha = {}
    end
    if self.demoBanner then self.demoBanner.hideUI:SetChecked(hide and true or false) end
end

local function CreateBanner(self)
    local b = CreateFrame("Frame", "TesseraDemoBanner", UIParent, "BackdropTemplate")
    b:SetSize(760, 92)
    b:SetPoint("TOP", UIParent, "TOP", 0, -18)
    b:SetFrameStrata("DIALOG")
    b:SetClampedToScreen(true)
    b:EnableMouse(true)
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", b.StartMoving)
    b:SetScript("OnDragStop", b.StopMovingOrSizing)

    b.title = b:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    b.title:SetPoint("TOPLEFT", 16, -12)
    b.title:SetText(L.DEMO_TITLE)
    b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.sub:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -4)
    b.sub:SetWidth(728)
    b.sub:SetJustifyH("LEFT")
    b.sub:SetText(L.DEMO_SUBTITLE)

    local function Button(text, w, onClick)
        local btn = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
        btn:SetSize(w, 22)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end
    local function Switch(delta)
        if InCombatLockdown() then return end
        local i, list = ThemeIndex(self)
        local t = list[(i - 1 + delta) % #list + 1]
        if t then
            self.demoTheme = t.key
            self:ApplyTheme(t.key)
        end
        UpdateBanner(self)
    end
    local prev = Button("<", 28, function() Switch(-1) end)
    prev:SetPoint("BOTTOMLEFT", 14, 12)
    b.style = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.style:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    b.style:SetWidth(320)
    b.style:SetWordWrap(false)
    local nextStyle = Button(">", 28, function() Switch(1) end)
    nextStyle:SetPoint("LEFT", b.style, "RIGHT", 8, 0)

    local quit = Button(L.DEMO_QUIT, 120, function() self:StopDemo() end)
    quit:SetPoint("BOTTOMRIGHT", -14, 12)
    b.hideUI = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate")
    b.hideUI:SetSize(24, 24)
    b.hideUI:SetPoint("LEFT", nextStyle, "RIGHT", 14, 0)
    b.hideUI.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.hideUI.label:SetPoint("LEFT", b.hideUI, "RIGHT", 2, 0)
    b.hideUI.label:SetPoint("RIGHT", quit, "LEFT", -8, 0)
    b.hideUI.label:SetJustifyH("LEFT")
    b.hideUI.label:SetText(L.DEMO_HIDE_UI)
    b.hideUI:SetScript("OnClick", function(btn) self:SetDemoHideUI(btn:GetChecked() and true or false) end)
    b.prev, b.nextStyle, b.quit = prev, nextStyle, quit

    -- a fight ends the demo (once it is over: blocks cannot move during one)
    b:RegisterEvent("PLAYER_REGEN_DISABLED")
    b:RegisterEvent("PLAYER_REGEN_ENABLED")
    b:SetScript("OnEvent", function(_, event)
        if not self:IsDemoActive() then return end
        if event == "PLAYER_REGEN_DISABLED" then
            self:SetDemoHideUI(false)
            self.Print(L.DEMO_COMBAT)
        else
            self:StopDemo()
        end
    end)
    return b
end

function ns:StartDemo()
    if self:IsDemoActive() then return end
    if InCombatLockdown() then
        self.Print(L.REPLACE_IN_COMBAT)
        return
    end
    if self.brokerModeActive then
        self.Print(L.DEMO_BROKER)
        return
    end
    -- the player's profile, put aside (saved too: /reload or logout give it back)
    self.sv.demoBackup = { profile = self.profileName, data = self.DeepCopy(self.sv.profiles[self.profileName]) }
    self.sv.profiles[self.profileName] = { pendingPreset = "top" }
    self:LoadProfile()
    BuildDemo(self)
    self:RefreshAllBlocks()
    self:ReanchorAll()
    self:RequestLayout()
    self.previewMode = true
    self:UpdateAllVisibility()
    self:UpdateAll()
    self.demoBanner = self.demoBanner or CreateBanner(self)
    self.demoBanner:Show()
    UpdateBanner(self)
    self.Print(L.DEMO_STARTED)
end

-- Gives the player's profile back (also called at login if the demo was left open)
function ns:StopDemo()
    local backup = self.sv and self.sv.demoBackup
    if not backup then return end
    if InCombatLockdown() then
        self.Print(L.DEMO_COMBAT)
        return
    end
    self:SetDemoHideUI(false)
    self.sv.demoBackup = nil
    if type(backup.profile) == "string" and type(backup.data) == "table" then
        self.sv.profiles[backup.profile] = backup.data
    end
    self.previewMode = nil
    if self.demoBanner then self.demoBanner:Hide() end
    self:LoadProfile()
    self:ReanchorAll()
    self:UpdateAllVisibility()
    self:UpdateAll()
    self.Print(L.DEMO_ENDED)
end

-- At login, before the profile is loaded: a demo left open (reload, logout, crash)
-- gives the player's profile back
function ns:RestoreDemoBackup()
    local backup = self.sv and self.sv.demoBackup
    if not backup then return end
    self.sv.demoBackup = nil
    if type(backup.profile) == "string" and type(backup.data) == "table" then
        self.sv.profiles[backup.profile] = backup.data
    end
end

-- No unlocking during the demo: it is not a layout
function ns:DemoBlocksUnlock()
    if self:IsDemoActive() then
        self.Print(L.DEMO_NO_UNLOCK)
        return true
    end
    return false
end
