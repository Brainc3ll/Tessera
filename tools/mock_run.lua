-- Very rough WoW API mock, for developers: loads the addon files in TOC order
-- outside the game, fires the login events, opens every options page and block,
-- and prints any Lua error. Usage, from the addon folder:  lua5.1 tools/mock_run.lua . [enUS|frFR] [broker]
-- "broker" pretends a DataBroker display addon (ChocolateBar) is loaded: DataBroker mode.
local addonDir = arg[1]
local frames = {}
local function noop() end
local FrameMT
local function NewObject(kind)
    local o = { __kind = kind, __scripts = {}, __shown = true, __w = 100, __h = 20, __events = {}, __attrs = {} }
    return setmetatable(o, FrameMT)
end
local methods = {
    SetScript = function(self, name, fn) self.__scripts[name] = fn end,
    GetScript = function(self, name) return self.__scripts[name] end,
    HookScript = function(self, name, fn) local old = self.__scripts[name]; self.__scripts[name] = function(...) if old then old(...) end fn(...) end end,
    RegisterEvent = function(self, e) self.__events[e] = true; frames[self] = true end,
    RegisterUnitEvent = function(self, e) self.__events[e] = true; frames[self] = true end,
    UnregisterEvent = function(self, e) self.__events[e] = nil end,
    IsEventRegistered = function(self, e) return self.__events[e] end,
    Show = function(self) self.__shown = true end, Hide = function(self) self.__shown = false end,
    SetShown = function(self, v) self.__shown = v and true or false end,
    IsShown = function(self) return self.__shown end, IsVisible = function(self) return self.__shown end,
    GetWidth = function(self) return self.__w end, GetHeight = function(self) return self.__h end,
    SetWidth = function(self, w) self.__w = w end, SetHeight = function(self, h) self.__h = h end,
    SetSize = function(self, w, h) self.__w, self.__h = w, h end,
    GetLeft = function() return 100 end, GetRight = function(self) return 100 + self.__w end,
    GetTop = function() return 500 end, GetBottom = function(self) return 500 - self.__h end,
    GetCenter = function(self) return 100 + self.__w / 2, 500 - self.__h / 2 end,
    GetEffectiveScale = function() return 1 end, GetScale = function() return 1 end,
    GetName = function(self) return self.__name end,
    CreateTexture = function() return NewObject("Texture") end,
    CreateMaskTexture = function() return NewObject("MaskTexture") end,
    CreateFontString = function() return NewObject("FontString") end,
    CreateAnimationGroup = function() return NewObject("AnimGroup") end,
    CreateAnimation = function() return NewObject("Anim") end,
    GetStringWidth = function() return 40 end, GetUnboundedStringWidth = function() return 40 end,
    -- rough wrapped height (about 5.6 px per character, 13 px per line), so the
    -- options pages can be checked against the window height
    GetStringHeight = function(self)
        local text = tostring(self.__text or "")
        local lines = 0
        for para in (text .. "\n"):gmatch("([^\n]*)\n") do
            lines = lines + math.max(1, math.ceil(#para * 5.6 / math.max(40, self.__w or 250)))
        end
        return 13 * lines
    end,
    SetFont = function() return true end,
    GetText = function(self) return self.__text or "" end, SetText = function(self, t) self.__text = t end,
    NumLines = function() return 3 end,
    SetAttribute = function(self, k, v) self.__attrs[k] = v end,
    GetAttribute = function(self, k) return self.__attrs[k] end,
    IsMouseOver = function() return false end,
    GetChecked = function() return false end,
    HasFocus = function() return false end,
    GetAtlas = function() return nil end, GetTexture = function() return "x" end,
    GetVertexColor = function() return 1, 1, 1, 1 end, GetDrawLayer = function() return "ARTWORK" end,
    GetFrameStrata = function() return "MEDIUM" end, GetFrameLevel = function() return 1 end,
    IsMenuOpen = function() return false end,
    GetObjectType = function(self) return self.__kind end,
    -- anchors are tracked so a loop raises the same error as the game
    -- ("Cannot anchor to a region dependent on it")
    ClearAllPoints = function(self) self.__anchors = nil end,
    SetPoint = function(self, _, rel)
        if type(rel) == "table" and rel ~= self and getmetatable(rel) == FrameMT then
            local seen, queue = {}, { rel }
            while #queue > 0 do
                local cur = table.remove(queue)
                if cur == self then error("Action[SetPoint] failed because[Cannot anchor to a region dependent on it]", 2) end
                if not seen[cur] then
                    seen[cur] = true
                    for other in pairs(cur.__anchors or {}) do table.insert(queue, other) end
                end
            end
            self.__anchors = self.__anchors or {}
            self.__anchors[rel] = true
        end
    end,
}
local PIECES = { TopLeftCorner = 1, TopRightCorner = 1, BottomLeftCorner = 1, BottomRightCorner = 1,
    TopEdge = 1, BottomEdge = 1, LeftEdge = 1, RightEdge = 1, Center = 1, Text = 1, NineSlice = 1, Slider = 1, Back = 1, Forward = 1, ScrollBar = 1 }
-- methods are CamelCase, fields are lowercase (template pieces excluded)
FrameMT = { __index = function(t, k)
    if methods[k] then return methods[k] end
    if type(k) == "string" and k:match("^[A-Z]") and not PIECES[k] then return noop end
    return nil
end }
local G = setmetatable({}, { __index = function(_, k) return _G[k] end })
UIParent = NewObject("Frame"); UIParent.__w, UIParent.__h = 1366, 768
GameTooltip = NewObject("GameTooltip"); GameTooltip.__name = "GameTooltip"
Minimap = NewObject("Frame"); Minimap.__w, Minimap.__h = 140, 140
-- Blizzard's Edit Mode (EditMode.lua): two frames at the bottom of the screen and
-- the chat, a "Modern" preset, the player's layouts saved by SaveLayouts
Enum = { EditModeLayoutType = { Preset = 0, Account = 1, Character = 2, Override = 3 },
    EditModeSystem = { ActionBar = 0, ChatFrame = 8, MicroMenu = 13 } }
Constants = { EditModeConsts = { EditModeMaxLayoutsPerType = 5 } }
local function RectFrame(name, l, b, w, h)
    return { name = name, GetName = function() return name end, IsShown = function() return true end,
        GetLeft = function() return l end, GetBottom = function() return b end,
        GetRight = function() return l + w end, GetTop = function() return b + h end,
        GetEffectiveScale = function() return 1 end, GetRect = function() return l, b, w, h end }
end
local EM_FRAMES = { ["13"] = RectFrame("MicroMenuContainer", 925, 6, 302, 40),
    ["0.1"] = RectFrame("MainActionBar", 359, 2, 562, 45), ["8"] = RectFrame("ChatFrame1", 32, 153, 430, 170) }
local function EMSystems()
    return {
        { system = 13, anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 116.5, offsetY = 6 }, isInDefaultPosition = true, settings = {} },
        { system = 0, systemIndex = 1, anchorInfo = { point = "BOTTOMRIGHT", relativeTo = "MicroMenuContainer", relativePoint = "BOTTOMLEFT", offsetX = -4.5, offsetY = -4 }, isInDefaultPosition = true, settings = {} },
        { system = 8, anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = 32, offsetY = 153 }, isInDefaultPosition = false, settings = {} },
    }
end
EM = { layouts = { activeLayout = 1, layouts = {} }, saves = 0 }
EditModePresetLayoutManager = { GetCopyOfPresetLayouts = function()
    return { { layoutName = "Moderne", layoutType = 0, systems = EMSystems() },
        { layoutName = "Classique", layoutType = 0, systems = EMSystems() },
        { layoutName = "Manette", layoutType = 0, systems = EMSystems() } }
end }
C_EditMode = {
    GetLayouts = function()
        local copy = { activeLayout = EM.layouts.activeLayout, layouts = {} }
        for i, l in ipairs(EM.layouts.layouts) do copy.layouts[i] = l end
        return copy
    end,
    SaveLayouts = function(info) EM.layouts = info; EM.saves = EM.saves + 1 end,
    SetActiveLayout = function(i) EM.layouts.activeLayout = i end,
}
EditModeManagerFrame = { IsEditModeActive = function() return false end,
    GetRegisteredSystemFrame = function(_, system, index)
        return EM_FRAMES[tostring(system) .. (index and ("." .. index) or "")]
    end }
CreateFrame = function(kind, name) local f = NewObject(kind); f.__name = name; if name then _G[name] = f end return f end
C_Timer = { After = function(_, fn) table.insert(_G.__timers, fn) end, NewTicker = function(_, fn) table.insert(_G.__tickers, fn); return NewObject("Ticker") end }
__timers, __tickers = {}, {}
GetLocale = function() return arg[2] or "frFR" end
GetZoneText = function() return "Stormwind City" end
GetSubZoneText = function() return "Trade District" end
GetTime = function() return 1000 end
GetFramerate = function() return 60 end
GetNetStats = function() return 1, 1, 50, 60 end
GetMoney = function() return 123456 end
UnitName = function() return "Ellen" end
GetRealmName = function() return "Realm" end
UnitClass = function() return "Mage", "MAGE" end
UnitLevel = function() return 20 end
UnitXP = function() return 500 end UnitXPMax = function() return 2000 end
GetXPExhaustion = function() return 300 end
IsResting = function() return false end
IsInInstance = function() return false end
GetGameTime = function() return 14, 5 end
GetBuildInfo = function() return "1", "2", "3", 16001 end
InCombatLockdown = function() return false end
IsShiftKeyDown = function() return false end IsControlKeyDown = IsShiftKeyDown IsAltKeyDown = IsShiftKeyDown
GetCVar = function() return "1" end
C_CVar = { GetCVar = function() return "1" end }
C_Container = { GetContainerNumSlots = function() return 16 end, GetContainerNumFreeSlots = function() return 4 end, GetContainerItemInfo = function() return nil end }
C_AddOns = { GetAddOnMetadata = function() return "test" end, GetNumAddOns = function() return 0 end,
    IsAddOnLoaded = function(name) return arg[3] == "broker" and name == "ChocolateBar" end }

-- WoW Forever APIs: skill list, Legacy renown track
C_SkillInfo = {
    GetNumSkillLines = function() return 4 end,
    GetSkillLineInfo = function(i)
        return ({ { name = "Weapon skills", isHeader = true },
                  { name = "Staves", rank = 50, maxRank = 65, skillLineCategoryID = 6, skillID = 136 },
                  { name = "Herbalism", rank = 21, maxRank = 75, isAbandonable = true, skillLineCategoryID = 11 },
                  { name = "Comprehension", rank = 12, maxRank = 65, skillLineCategoryID = 9, skillID = 3012 } })[i]
    end,
}
-- Legacy challenges (achievement categories), camp auras, honor currency
GetCategoryList = function() return { 15568, 15577, 15593, 15425 } end
GetCategoryInfo = function(id)
    return ({ [15568] = "Classes", [15577] = "Druid", [15593] = "Dungeons", [15425] = "Do Not Display" })[id],
        ({ [15577] = 15568 })[id] or -1
end
GetCategoryNumAchievements = function(id) return ({ [15577] = 3, [15593] = 3 })[id] or 0, id == 15577 and 1 or 0 end
C_UnitAuras = { GetPlayerAuraBySpellID = function(id)
    if id == 1229741 then return { name = "Camp Perks", spellId = id, expirationTime = 3000 } end
end }
C_CurrencyInfo = C_CurrencyInfo or {}
C_CurrencyInfo.GetCurrencyInfo = function(id)
    if id == 1792 then return { name = "Honor", quantity = 1250, maxQuantity = 25000 } end
end
C_MajorFactions = {
    GetMajorFactionData = function() return { renownLevel = 16, maxLevel = 90, name = "Legacy" } end,
    GetRenownLevels = function() return { { level = 15 }, { level = 25 }, { level = 40 } } end,
    GetRenownRewardsForLevel = function(_, level) return { { name = "Reward " .. level } } end,
}
ToggleLegacySystemUI = function() end

-- LibStub with a small LibDataBroker-1.1 (same API and callbacks as the real one)
do
    local libs, callbacks = {}, {}
    LibStub = setmetatable({}, { __call = function(_, name) return libs[name] end })
    local function FireCallback(event, ...)
        for _, fn in pairs(callbacks[event] or {}) do fn(event, ...) end
    end
    local ldb = { proxies = {} }
    ldb.RegisterCallback = function(owner, event, fn)
        callbacks[event] = callbacks[event] or {}
        callbacks[event][owner] = fn
    end
    function ldb:NewDataObject(name, data)
        if self.proxies[name] then return end
        local attrs, proxy = data or {}, nil
        proxy = setmetatable({}, { __index = attrs, __newindex = function(_, k, v)
            if attrs[k] == v then return end
            attrs[k] = v
            FireCallback("LibDataBroker_AttributeChanged", name, k, v, proxy)
        end })
        self.proxies[name] = proxy
        FireCallback("LibDataBroker_DataObjectCreated", name, proxy)
        return proxy
    end
    function ldb:DataObjectIterator() return pairs(self.proxies) end
    function ldb:GetDataObjectByName(name) return self.proxies[name] end
    libs["LibDataBroker-1.1"] = ldb
    -- objects of a pretend addon: a data source with each kind of tooltip, and a launcher
    ldb:NewDataObject("FakeFPS", { type = "data source", text = "60 fps", label = "Fake FPS", icon = 123,
        tocname = "FakeAddon", OnTooltipShow = function(tt) tt:AddLine("x") end, OnClick = function() end })
    ldb:NewDataObject("FakeValue", { type = "data source", value = 12, suffix = "ms", OnEnter = function() end,
        OnLeave = function() end })
    ldb:NewDataObject("FakeLauncher", { type = "launcher", icon = "Interface\\Icons\\X", label = "Fake Launcher",
        OnClick = function() end })
end
C_Map = { GetBestMapForUnit = function() return nil end }
C_FriendList = { GetNumOnlineFriends = function() return 0 end, GetNumFriends = function() return 0 end }
IsInGuild = function() return false end
GetInventoryItemDurability = function() return 50, 100 end
SlashCmdList = {}
StaticPopupDialogs = {}
UISpecialFrames = {}
STANDARD_TEXT_FONT = "x"
RAID_CLASS_COLORS = { MAGE = { r = 0.4, g = 0.8, b = 1 } }
date = os.date time = os.time
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
hooksecurefunc = noop
StaticPopup_Show = noop RegisterStateDriver = noop UnregisterStateDriver = noop
MinimalSliderWithSteppersMixin = { Label = { Right = 1, Left = 2 }, Event = { OnValueChanged = 1 } }
methods.IsMouseEnabled = function() return true end
-- any other global: a function returning nil
setmetatable(_G, { __index = function(_, k) if k:match("^[A-Z]") or k:match("^C_") then return nil end end })

local ns = {}
local toc = io.open(addonDir .. "/Tessera.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^#") and line:match("%.lua$") then
        local path = addonDir .. "/" .. line:gsub("\\", "/")
        local chunk = assert(loadfile(path))
        local ok, err = pcall(chunk, "Tessera", ns)
        if not ok then print("LOAD ERROR " .. line .. ": " .. tostring(err)) os.exit(1) end
    end
end
-- a test build's extra file (test and development commands, never released), if given:
-- TESSERA_DEV=/path/to/TesseraDev.lua lua5.1 tools/mock_run.lua . enUS
local devFile = os.getenv("TESSERA_DEV")
if devFile and devFile ~= "" then
    local ok, err = pcall(assert(loadfile(devFile)), "Tessera", ns)
    if not ok then print("LOAD ERROR " .. devFile .. ": " .. tostring(err)) os.exit(1) end
end
print("loaded files OK")
local function Fire(event, ...)
    for f in pairs(frames) do
        if f.__events[event] and f.__scripts.OnEvent then
            local ok, err = pcall(f.__scripts.OnEvent, f, event, ...)
            if not ok then print("EVENT ERROR " .. event .. ": " .. tostring(err)) end
        end
    end
end
Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD")
for round = 1, 3 do
    local timers = __timers; __timers = {}
    for _, fn in ipairs(timers) do local ok, err = pcall(fn) if not ok then print("TIMER ERROR: " .. tostring(err)) end end
    for _, fn in ipairs(__tickers) do local ok, err = pcall(fn) if not ok then print("TICKER ERROR: " .. tostring(err)) end end
end
-- open options, every page and sub-tab, select every block
local ok, err = xpcall(function() ns:ToggleOptions() end, debug.traceback)
if not ok then print("OPTIONS ERROR: " .. tostring(err)) end
for i = 1, 8 do local ok2, err2 = xpcall(function() ns.ShowOptionsPage(i) end, debug.traceback) if not ok2 then print("PAGE ERROR " .. i .. ": " .. tostring(err2)) end end
-- every options page must fit in the window (pages start 98 px below its top)
if -(ns.optionsLowestY or 0) > TesseraOptions:GetHeight() - 98 - 12 then
    print("STEP ERROR: options page too tall: " .. -ns.optionsLowestY .. " px for " .. (TesseraOptions:GetHeight() - 110))
end
for _, key in ipairs(ns:GetBlockKeys()) do
    local ok3, err3 = pcall(function() ns:OpenOptionsFor(key); ns:UpdateBlock(key) end)
    if not ok3 then print("BLOCK ERROR " .. key .. ": " .. tostring(err3)) end
end
-- tooltips of every block
for key, f in pairs(ns.frames) do
    local fn = f.__scripts.OnEnter
    if fn then local ok4, err4 = pcall(fn, f) if not ok4 then print("TOOLTIP ERROR " .. key .. ": " .. tostring(err4)) end end
end
-- In a dungeon, then in combat there (WoW Forever's beta closes before every case can be
-- tested in game): automatic dungeon profile, "hide in instances", frozen blocks, tooltips
-- and clicks in combat, then leaving combat and the dungeon.
do
    local function Step(label, fn)
        local ok, err = xpcall(fn, debug.traceback)
        if not ok then print("STEP ERROR (" .. label .. "): " .. tostring(err)) end
    end
    local usual = ns:GetActiveProfileName()
    Step("dungeon profile", function()
        ns:CreateProfile("Mock dungeon")
        if usual then ns:SetProfile(usual) end
        ns.sv.instanceProfile = "Mock dungeon"
        ns.db.blocks.gold.hideInInstance = true
    end)
    IsInInstance = function() return true, "party" end
    Step("enter dungeon", function()
        Fire("ZONE_CHANGED_NEW_AREA")
        assert(ns.profileOverride == "Mock dungeon", "dungeon profile not used")
    end)
    InCombatLockdown = function() return true end
    Step("combat in dungeon", function()
        Fire("PLAYER_REGEN_DISABLED")
        assert(ns:IsLocked(), "blocks not frozen in combat")
        ns:SetLocked(false) -- asking to unlock in combat must not break anything
        ns:UpdateLayout()
        for key, f in pairs(ns.frames) do
            if f:IsShown() then
                if f.__scripts.OnEnter then f.__scripts.OnEnter(f) end
                if f.__scripts.OnMouseUp then f.__scripts.OnMouseUp(f, "LeftButton") end
                if f.__scripts.OnLeave then f.__scripts.OnLeave(f) end
            end
        end
        ns:ToggleOptions(); ns:ToggleOptions()
        Fire("GROUP_ROSTER_UPDATE"); Fire("PARTY_LOOT_METHOD_CHANGED")
    end)
    InCombatLockdown = function() return false end
    Step("end of combat", function() Fire("PLAYER_REGEN_ENABLED"); ns:SetLocked(true) end)
    IsInInstance = function() return false end
    Step("leave dungeon", function()
        Fire("ZONE_CHANGED_NEW_AREA")
        assert(ns.profileOverride == nil, "dungeon profile still used outside")
        ns.sv.instanceProfile = nil
    end)
end

-- placement mode, undo, spacer, scale, lock
for _, step in ipairs({
    function() ns:SetLocked(false) end,
    function() ns:PushUndo(); ns:Undo() end,
    function() local k = ns:AddSpacer(); ns:PlaceNearOptions(k); ns:RemoveSpacer(k) end,
    function() ns:SetGlobalScale(1.5); ns:SetGlobalScale(1) end,
    function() ns:SetLocked(true) end,
    function() ns:UpdateLayout() end,
    function() ns:ResetProfile() end,
    function() ns:UpdateLayout() end,
    function()
        local text = ns:ExportProfile()
        local decoded = assert(ns:DecodeProfile(text), "export/import roundtrip failed")
        assert(type(decoded.blocks) == "table")
        assert(ns:ImportProfile(text, "Imported"))
        assert(ns:DuplicateProfile("Copy"))
        assert(not ns:DecodeProfile("garbage"))
    end,
    function()
        -- a malicious / damaged profile must be cleaned on import, never break the addon
        local saved = ns.db
        ns.db = { scale = "big", blocks = {
            gold = "x", ["spacer:1"] = 5, ["launcher:x"] = { launcher = { kind = "frame", source = "UIParent" } },
            bags = { width = "wide", point = "zz", dock = { to = "fps", side = "RIGHT" } },
            fps = { dock = { to = "bags", side = "LEFT" }, height = 0 },
            latency = { anchor = { below = "time" } }, time = { anchor = { above = "latency" } },
            unknownKey = { width = 10 },
        } }
        local text = ns:ExportProfile()
        ns.db = saved
        assert(ns:ImportProfile(text, "Evil"), "import of a damaged profile was refused")
        ns:UpdateLayout()
        local p = ns.sv.profiles.Evil
        assert(type(p.blocks.gold) == "table" and p.blocks.unknownKey == nil and p.blocks["launcher:x"] ~= nil)
        assert(not (p.blocks.bags.dock and p.blocks.fps.dock), "dock loop not broken")
        ns:SetProfile("Default")
    end,
    function() for _, p in ipairs(ns.PRESETS) do ns:ResetProfile(p); ns:UpdateLayout() end end,
    function() ns:SetPreview(true); ns:UpdateAll(); ns:SetPreview(false) end,
    function() ns.sv.instanceProfile = "Copy"; ns:CheckSituationProfile() end,
    function() for _, key in ipairs(ns:GetBlockKeys()) do ns:RunClickAction(key, "chat") end end,
    function() SlashCmdList.TESSERA("help") end,
    function() SlashCmdList.TESSERA("bug") end,
    -- development and test commands: only with a test build's extra file (TESSERA_DEV)
    function()
        if not ns.DevCommand then return end
        for _, cmd in ipairs({ "debug", "debug", "debug legacy", "debug skills", "atelier", "atelier",
            "test", "test blocs", "test compacte", "test colonne", "test infobulles", "test infobulles",
            "test flare", "test fin" }) do
            SlashCmdList.TESSERA(cmd)
            local queued = __timers; __timers = {}
            for _, fn in ipairs(queued) do pcall(fn) end
        end
        assert(not ns.sv.profiles.Test, "test profile not deleted")
    end,
    -- icon frames: round, square, black and white, fixed size, then back to normal
    function()
        local cfg = ns.db.blocks.gold
        for _, shape in ipairs({ "round", "square", "none" }) do
            cfg.iconShape, cfg.iconDesaturate, cfg.iconSize = shape, shape ~= "none", shape == "none" and 0 or 18
            ns:ApplyStyle("gold")
            ns:UpdateBlock("gold")
        end
    end,
    -- the Legacy and weapon skill blocks read the WoW Forever APIs
    function()
        for _, key in ipairs({ "legacy", "weaponSkills" }) do
            local mod = ns.modules[key]
            assert(mod, key .. " not registered")
            local value = mod.update(ns.db.blocks[key])
            assert(value and value ~= ns.L.NA and value ~= ns.L.NONE, key .. " has no value")
            mod.tooltip(GameTooltip, ns.db.blocks[key])
            assert(mod.progress(ns.db.blocks[key]), key .. " progress")
        end
    end,
    function() local k = ns:AddSpacer(); ns:OpenOptionsFor(k); ns:RemoveSpacer(k) end,
    function() ns:UpdateVehicleState() end,
    -- DataBroker: add every source, update, tooltip, click, then remove one
    function()
        for _, source in ipairs(ns:GetBrokerSources()) do
            local key = ns:AddBroker(source)
            ns:UpdateBlock(key)
            local f = ns.frames[key]
            ns.brokerModule.customTooltip(f, ns.db.blocks[key])
            ns.brokerModule.onLeave(f, ns.db.blocks[key])
            ns.brokerModule.onClick(f, "RightButton", ns.db.blocks[key])
            ns:OpenOptionsFor(key)
        end
        LibStub("LibDataBroker-1.1"):GetDataObjectByName("FakeFPS").text = "30 fps"
        assert(#ns:GetBrokerSources() == 0, "sources still offered after being added")
        local decoded = ns:DecodeProfile(ns:ExportProfile())
        assert(decoded and decoded.blocks["broker:FakeFPS"] and decoded.blocks["broker:FakeFPS"].broker,
            "broker blocks lost by export / import")
        ns:RemoveBroker("broker:FakeValue")
    end,
    -- sharing, then DataBroker mode on and off
    function()
        ns.sv.brokerShare = true
        ns:UpdatePublishing()
        local obj = LibStub("LibDataBroker-1.1"):GetDataObjectByName("Tessera_gold")
        assert(obj, "gold not published")
        for _, fn in ipairs(__tickers) do pcall(fn) end
        assert(obj.text and obj.text ~= "", "published gold has no text")
        obj.OnTooltipShow(GameTooltip)
        obj.OnClick(nil, "RightButton")
        ns:SetBrokerMode(true)
        assert(ns.brokerModeActive, "broker mode not on")
        for i = 1, 8 do ns.ShowOptionsPage(i) end
        ns:OpenOptionsFor("gold")
        ns:SetBrokerMode(false)
        assert(not ns.brokerModeActive, "broker mode not off")
    end,
    function() for _, t in ipairs(ns:GetAvailableThemes()) do ns:ApplyTheme(t.key); ns:UpdateLayout() end end,
    -- demo mode: every block with sample values, styles switched from the banner;
    -- the player's profile comes back, also after a /reload during the demo
    function()
        ns:ResetProfile("left")
        ns.db.blocks.time.width = 123
        ns:StartDemo()
        assert(ns:IsDemoActive() and ns.previewMode, "demo started")
        assert(ns.db.blocks.legacy.enabled and ns.db.blocks.gold.showLabel, "demo shows the blocks with labels")
        ns:SetLocked(false)
        assert(ns:IsLocked(), "no unlocking during the demo")
        local b = TesseraDemoBanner
        b.nextStyle:GetScript("OnClick")(b.nextStyle)
        b.prev:GetScript("OnClick")(b.prev)
        b.hideUI:SetChecked(true)
        b.hideUI:GetScript("OnClick")(b.hideUI)
        ns:UpdateLayout()
        b.quit:GetScript("OnClick")(b.quit)
        assert(not ns:IsDemoActive() and not ns.previewMode, "demo ended")
        assert(ns.db.blocks.time.width == 123, "the player's layout is back")
        -- a demo left open at logout
        ns:StartDemo()
        ns:RestoreDemoBackup()
        ns:LoadProfile()
        assert(ns.db.blocks.time.width == 123, "the player's layout is back after a reload")
        ns.previewMode = nil
        ns:ResetProfile("top")
    end,
    -- display options of the blocks (gold, bags, XP, durability, FPS, latency, time,
    -- coordinates, friends, guild, reputation): every value gives a text
    function()
        local b = ns.db.blocks
        local function Try(key, field, values)
            for _, v in ipairs(values) do
                b[key][field] = v
                ns:UpdateBlock(key)
            end
        end
        for _, f in ipairs({ "full", "goldSilver", "gold", "short" }) do
            b.gold.goldFormat = f
            for _, icons in ipairs({ true, false }) do
                b.gold.goldIcons = icons
                Try("gold", "goldRound", { true, false })
                Try("gold", "goldSeparator", { false, true })
            end
        end
        Try("bags", "bagsFormat", { "free", "usedTotal", "freeTotal" })
        Try("xp", "xpFormat", { "values", "remaining", "percent" })
        Try("xp", "xpRested", { false, true })
        Try("durability", "durabilityMode", { "average", "lowest" })
        Try("fps", "showUnit", { false, true })
        Try("latency", "latencySource", { "home", "both", "world" })
        Try("latency", "showUnit", { false, true })
        Try("time", "showSeconds", { true, false })
        Try("serverTime", "showSeconds", { true, false })
        Try("coords", "coordDecimals", { 0, 2, 1 })
        Try("friends", "countFormat", { "onlineTotal", "online" })
        Try("guild", "countFormat", { "online", "onlineTotal" })
        Try("reputation", "repFormat", { "namePercent", "percent", "standing", "standingPercent" })
        -- gold: the formats themselves
        local gold = ns.modules.gold
        b.gold.goldIcons, b.gold.goldFormat, b.gold.goldRound, b.gold.goldSeparator = false, "gold", true, false
        local text = gold.update(b.gold)
        assert(text and text:find("|r", 1, true), "gold letters are colored")
        b.gold.goldIcons, b.gold.goldFormat, b.gold.goldRound, b.gold.goldSeparator = true, "full", false, true
    end,
    -- Runestone: text only, black and white; another style gives icons and colors back;
    -- the styles of interfaces that are not installed can be picked, with a note
    function()
        assert(ns:ApplyTheme("runestone"), "runestone refused")
        local cfg, f = ns.db.blocks.durability, ns.frames.durability
        assert(cfg.hideIcons and cfg.monochrome, "runestone flags")
        ns:ApplyStyle("durability")
        ns:UpdateBlock("durability")
        assert(not f.icon:IsShown(), "runestone hides the icon")
        assert(not (f.lastText or ""):find("|c", 1, true), "runestone: no color in the text")
        assert(ns:ApplyTheme("grimoire") and not cfg.hideIcons and cfg.textTint.a == 1, "grimoire clears runestone")
        assert(ns:ApplyTheme("flat") and (cfg.textTint.a or 0) == 0, "flat clears the tint")
        assert(ns:ApplyTheme("elvui") and ns:GetThemeNote("elvui"), "elvui without ElvUI, with a note")
        assert(ns:GetTheme() == "elvui", "a style picked without its UI stays")
        ns:ApplyTheme("flat")
    end,
    function() for _, t in ipairs(ns.themes) do t.block({}); assert(t.window().title, t.key) end end,
    -- a profile styled with FlareUI 1.x keeps its look, and FlareUI 2.x is offered in a window
    function()
        local has = ns.HasFlareUIMedia
        ns.HasFlareUIMedia = function() return true end
        ns.db.theme, ns.db.flareStylesSplit, ns.db.autoTheme = "flareui", nil, nil
        ns:ApplyThemeToCfg(ns.db.blocks.gold, "flareui")
        ns.sv.uiOffered = nil
        ns:SyncAutoTheme()
        assert(ns.db.theme == "flareui", "current look not kept")
        local offer = ns:GetStylesToOffer()
        assert(offer[1] == "flareui2", "FlareUI 2 not offered")
        ns:ShowStyleOffer({ "flareui2", "elvui" })
        local frame = _G.TesseraStyleOffer
        frame:Hide()
        frame:GetScript("OnHide")(frame) -- the mock does not fire OnHide by itself
        assert(#ns:GetStylesToOffer() == 0, "offered twice")
        ns:ApplyTheme("flareui2")
        ns.HasFlareUIMedia = has
    end,
    -- an interface missing for one session gets its style back when it returns
    function()
        local has = ns.HasFlareUIMedia
        ns.db.theme, ns.db.autoTheme, ns.db.autoThemeMissing = nil, "flareui2", nil
        ns.HasFlareUIMedia = function() return false end
        ns:SyncAutoTheme()
        assert(ns.db.autoThemeMissing == "flareui2" and ns.db.theme == nil, "missing style not remembered")
        ns.HasFlareUIMedia = function() return true end
        ns:SyncAutoTheme()
        assert(ns.db.autoThemeMissing == nil and ns:GetTheme() == "flareui2", "style not given back")
        assert(math.abs(ns.db.blocks.gold.borderColor.r - 0.80) < 0.01, "blocks not restyled back")
        ns.HasFlareUIMedia = has
    end,
    -- DataBroker mode choices are remembered per display addon
    function()
        local was = ns.brokerDisplay
        ns.brokerDisplay = "Bazooka"
        ns.sv.brokerMode = false -- 1.0.0-rc1 setting: migrated
        ns:RefreshBrokerMode()
        assert(ns.sv.brokerRefused.Bazooka and not ns.brokerModeActive, "rc1 refusal not migrated")
        ns.brokerDisplay = "Titan Panel"
        ns:RefreshBrokerMode()
        assert(ns.brokerModeActive, "another display addon should offer the mode again")
        assert(ns:GetBrokerStatus():find("Titan"), "status line")
        ns:SetBrokerMode(false)
        assert(ns.sv.brokerRefused["Titan Panel"] and not ns.brokerModeActive, "refusal for Titan")
        ns:ResetBrokerChoices()
        assert(not ns:HasBrokerChoices() and ns.brokerModeActive, "reset")
        ns.brokerDisplay = was
        ns:ResetBrokerChoices()
        ns:SetBrokerMode(false)
    end,
    -- help topics: every help text splits into titled sections, nothing lost
    function()
        -- every key of the help layouts exists (one key per line, see Locales/enUS.lua)
        for _, layout in ipairs({ ns.HELP_LAYOUT, ns.HELP_LAYOUT_BROKER }) do
            for _, topic in ipairs(layout) do
                assert(ns.L[topic.title], "missing help title " .. topic.title)
                for _, key in ipairs(topic.lines) do
                    assert(key == "" or ns.L[key], "missing help line " .. key)
                end
            end
        end
        for _, t in ipairs({ ns.HelpText(ns.HELP_LAYOUT), ns.HelpText(ns.HELP_LAYOUT_BROKER) }) do
            local sections = ns.SplitHelp(t)
            assert(#sections >= 4, "help has too few topics")
            local total = 0
            for _, sec in ipairs(sections) do
                assert(sec.title ~= "" and sec.body ~= "", "empty help topic")
                total = total + #sec.body
            end
            assert(total > #t * 0.8, "help text lost while splitting")
        end
    end,
    -- what's new popup opens the About tab on the Changelog topic
    function()
        StaticPopupDialogs.TESSERA_WHATS_NEW.OnAccept()
        assert(ns.L.ABOUT_AI and ns.L.TAB_ABOUT, "About strings missing")
    end,
    -- shape test: every shape, then back to the original layout
    function()
        if not ns.ShapeTest then return end -- test builds only
        local before = ns.DeepCopy(ns.db.blocks.gold.dock)
        for _ = 1, #ns.SHAPES do ns:ShapeTest("") end
        ns:ShapeTest("croix")
        ns:ShapeTest("fin")
        assert(not ns.sv.shapeTestBackup, "shape test backup not cleared")
        local after = ns.db.blocks.gold.dock
        assert((before == nil) == (after == nil), "layout not restored after the shape test")
    end,
    -- WoW Forever screenshot preview: every arrangement, then back to normal
    function()
        local goldEnabled = ns.db.blocks.gold.enabled
        for _ = 1, 4 do ns:PreviewForever("") end
        assert(not ns.sv.foreverPreviewBackup, "forever preview not finished after the last arrangement")
        ns:PreviewForever("")
        ns:PreviewForever("fin")
        assert(ns.db.blocks.gold.enabled == goldEnabled, "blocks not restored after the forever preview")
        assert(not ns.previewMode, "preview mode left on")
    end,
    -- "around the gryphons" layout: one group in each bottom corner of the screen
    function()
        ns:ResetProfile("gryphons")
        ns:UpdateLayout()
        local b = ns.db.blocks
        assert(b.legacy.point and b.legacy.point[1] == "BOTTOMLEFT" and not b.legacy.dock, "legacy heads the left group")
        assert(b.honor.point and b.honor.point[1] == "BOTTOMRIGHT" and not b.honor.dock, "honor heads the right group")
        assert(b.comprehension.dock and b.comprehension.dock.to == "legacy" and b.comprehension.dock.side == "RIGHT", "row 1")
        assert(b.durability.dock and b.durability.dock.to == "legacy" and b.durability.dock.side == "TOP", "row 2 head")
        assert(b.camping.dock and b.camping.dock.to == "durability", "camping dock")
        assert(b.gold.dock and b.gold.dock.to == "durability" and b.bags.dock.to == "gold", "row 3")
        assert(b.weaponSkills.dock and b.weaponSkills.dock.side == "LEFT", "right group grows inward")
        assert(b.mail.anchor and b.mail.anchor.above == "gold" and b.mail.anchor.align == "LEFT", "left hidden row")
        assert(b.friends.anchor and b.friends.anchor.above == "time" and b.friends.anchor.align == "RIGHT", "right hidden row")
        assert(b.coords and not b.coords.enabled, "other blocks hidden")
        local exported = ns:SanitizeProfile(ns:DecodeProfile(ns:ExportProfile()))
        assert(exported and exported.blocks.mail.anchor.align == "LEFT", "align lost by export")
        ns:ResetProfile("top")
    end,
    -- replace a block in place, then swap two shown blocks
    function()
        ns:ResetProfile("top")
        local b = ns.db.blocks
        local goldDock, goldAnchor = ns.DeepCopy(b.gold.dock), ns.DeepCopy(b.gold.anchor)
        local bagsTo = b.bags.dock and b.bags.dock.to
        assert(not b.zone.enabled, "zone starts hidden")
        assert(ns:ReplaceBlock("gold", "zone"), "replace refused")
        assert(b.zone.enabled and not b.gold.enabled, "zone shown, gold hidden")
        assert((b.zone.anchor ~= nil) == (goldAnchor ~= nil) and (b.zone.dock ~= nil) == (goldDock ~= nil), "zone took gold's place")
        if bagsTo == "gold" then assert(b.bags.dock.to == "zone", "neighbour follows the new block") end
        for k, c in pairs(b) do
            assert(not (c.dock and c.dock.to == "gold"), k .. " still docked to the hidden block")
        end
        -- swap two shown blocks: bags and time
        local bagsDock, timeDock = ns.DeepCopy(b.bags.dock), ns.DeepCopy(b.time.dock)
        assert(ns:ReplaceBlock("bags", "time"), "swap refused")
        assert(b.bags.enabled and b.time.enabled, "both stay shown in a swap")
        assert(b.time.dock and bagsDock and (b.time.dock.side == bagsDock.side), "time took bags' side")
        assert(b.bags.dock and timeDock and (b.bags.dock.side == timeDock.side), "bags took time's side")
        for k, c in pairs(b) do
            assert(not (c.dock and c.dock.to == k), k .. " docked to itself")
        end
        ns:GetReplacementChoices("time")
        ns:AskReplaceBlock("time", "fps")
        ns:OpenReplaceMenu("time")
        -- a spacer replaced by a hidden block is deleted; Ctrl + Z brings it back
        ns:ResetProfile("top")
        b = ns.db.blocks
        local had = {}
        for k in pairs(b) do had[k] = true end
        assert(ns:InsertSpacer("bags", "RIGHT") ~= false, "spacer refused")
        local spacer
        for k in pairs(b) do
            if not had[k] and ns.IsSpacerKey(k) then spacer = k end
        end
        assert(spacer and b[spacer].dock, "no new docked spacer")
        local spacerDock = ns.DeepCopy(b[spacer].dock)
        local hidden
        for _, other in ipairs(ns:GetReplacementChoices(spacer)) do
            if not other.shown then hidden = other.key break end
        end
        assert(hidden, "no hidden block to put in the spacer's place")
        assert(ns:ReplaceBlock(spacer, hidden), "spacer replacement refused")
        assert(b[spacer] == nil, "the replaced spacer is deleted")
        assert(b[hidden].enabled and b[hidden].dock and b[hidden].dock.to == spacerDock.to, "the block took the spacer's place")
        ns:Undo()
        assert(b[spacer] and b[spacer].dock and b[spacer].dock.to == spacerDock.to, "undo brings the spacer back")
        assert(not b[hidden].enabled, "undo hides the block again")
        -- placement mode: the cross and the arrow on a block
        ns:SetLocked(false)
        local f = ns.frames.fps
        assert(f.closeBtn and f.replaceBtn, "no buttons on the block")
        ns:ShowBlockControls(f)
        f:GetScript("OnEnter")(f)
        assert(ns.banner and ns.banner.info and ns.banner.info:IsShown(), "no hint panel under the banner")
        f.replaceBtn:GetScript("OnEnter")(f.replaceBtn)
        f.replaceBtn:GetScript("OnLeave")(f.replaceBtn)
        f:GetScript("OnLeave")(f)
        f.closeBtn:GetScript("OnClick")(f.closeBtn)
        f.replaceBtn:GetScript("OnClick")(f.replaceBtn)
        f:GetScript("OnMouseUp")(f, "RightButton")
        ns:SetLocked(true)
        ns:ResetProfile("top")
    end,
    -- screen edges: stick and stretch a bar, undo it; OS-like layouts
    function()
        ns:ResetProfile("top")
        local b = ns.db.blocks
        local function Spacers()
            local n = 0
            for k in pairs(b) do if ns.IsSpacerKey(k) then n = n + 1 end end
            return n
        end
        local root = ns:GetRoot("bags")
        local before = Spacers()
        ns:StickToEdges(root, { TOP = true }, "center")
        ns:UpdateLayout()
        assert(b[root].stretch == "TOP" and b[root].edges.LEFT and b[root].edges.RIGHT, "stretched bar")
        assert(Spacers() >= before + 2, "centered bar gets spacers on both sides")
        for k, c in pairs(b) do
            assert(not (c.dock and c.dock.to == k), k .. " docked to itself")
        end
        ns:Undo()
        assert(not b[root].stretch and Spacers() == before, "undo removes the stretch and its spacers")
        ns:StickToEdges(root, { LEFT = true })
        assert(b[root].edges.LEFT and not b[root].stretch, "left edge: stuck, not stretched")
        -- a column stuck to the bottom: its head (at the top) stays above the column's height
        ns:ResetProfile("left")
        b = ns.db.blocks
        local col = ns:GetRoot("bags")
        ns:StickToEdges(col, { BOTTOM = true })
        assert(b[col].point[1]:find("BOTTOM") and b[col].point[4] > 0, "column stuck to the bottom keeps its height")
        ns:ResetProfile("top")
        b = ns.db.blocks
        root = ns:GetRoot("bags")
        ns:StickToEdges(root, { LEFT = true })
        local exported = ns:SanitizeProfile(ns:DecodeProfile(ns:ExportProfile()))
        assert(exported.blocks[root].edges and exported.blocks[root].edges.LEFT, "edges lost by export")
        for _, preset in ipairs({ "stormwind", "cathedral", "tirisfal", "gnomeregan" }) do
            ns:ResetProfile(preset)
            ns:UpdateLayout()
            b = ns.db.blocks
            local stretched, spacers = 0, 0
            for k, c in pairs(b) do
                if c.stretch then stretched = stretched + 1 end
                if ns.IsSpacerKey(k) and c.enabled then spacers = spacers + 1 end
            end
            assert(stretched == 1 and spacers >= 4, preset .. ": one stretched bar with several spacers")
        end
        assert(b.time.enabled and b.time.dock, "clock in the bar")
        ns:ResetProfile("top")
    end,
    -- insert an empty spacer next to a block, in between if needed
    function()
        ns:ResetProfile("top")
        local b = ns.db.blocks
        -- find a block docked RIGHT of another one
        local left, right
        for k, c in pairs(b) do
            if c.dock and c.dock.side == "RIGHT" and c.enabled then left, right = c.dock.to, k break end
        end
        assert(left, "a merged pair in the top bar")
        assert(ns:InsertSpacer(left, "RIGHT"), "insert refused")
        local sp = b[right].dock.to
        assert(ns.IsSpacerKey(sp) and b[sp].dock.to == left and b[sp].dock.side == "RIGHT", "spacer slipped in between")
        -- on the side the block is docked from: between it and its target
        assert(ns:InsertSpacer(right, "LEFT"))
        local sp2 = b[right].dock.to
        assert(ns.IsSpacerKey(sp2) and sp2 ~= sp and b[sp2].dock.to == sp, "second spacer in between")
        assert(ns:InsertSpacer(left, "TOP") and true, "free side")
        for k, c in pairs(b) do
            assert(not (c.dock and c.dock.to == k), k .. " docked to itself")
        end
        -- stretched bar: no second row
        ns:ResetProfile("gnomeregan")
        b = ns.db.blocks
        assert(not ns:CanInsertSpacer("time", "TOP"), "no row above in a stretched bar")
        assert(ns:InsertSpacer("time", "LEFT"), "left is fine in a stretched bar")
        ns:ResetProfile("top")
    end,
    -- a new spacer takes the layer chosen for all blocks
    function()
        ns.db.groupDefaults = ns.db.groupDefaults or {}
        ns.db.groupDefaults.strata = "HIGH"
        local k = ns:AddSpacer()
        assert(ns.db.blocks[k].strata == "HIGH", "new spacer on the blocks' layer")
        ns:RemoveSpacer(k)
        ns.db.groupDefaults.strata = nil
    end,
    -- "Square" styles and separators
    function()
        for _, key in ipairs({ "flareSquare", "modernSquare", "classicSquare" }) do
            ns:ApplyTheme(key)
            ns:UpdateLayout()
            assert(ns.db.blocks.gold.separators == true, key .. ": separators on")
        end
        ns:ApplyTheme("flat")
        assert(ns.db.blocks.gold.separators == false, "other styles: no separators")
        ns:ResetProfile("gnomeregan")
        assert(ns.db.blocks.time.separators == true, "Forever layouts: separators on")
        ns:UpdateLayout()
        ns:ResetProfile("top")
    end,
    -- a single group's own look, from the quick menu
    function()
        ns:ResetProfile("top")
        local a, b = "gold", "fps"
        ns.db.blocks[b].dock = { to = a, side = "RIGHT" }
        ns.db.blocks[b].enabled, ns.db.blocks[a].enabled = true, true
        assert(ns:IsInGroup(a) and ns:IsInGroup(b), "two docked blocks form a group")
        ns:SetGroupOwnLook(b, "tiles")
        assert(ns:GetGroupLook(a) == "tiles" and ns:JointGap(a) >= 2, "the group has its own look")
        assert(ns:GetGroupLook() ~= "tiles" or ns.db.groupLook == "tiles", "the general look is untouched")
        ns:OpenQuickMenu(a)
        ns:UpdateLayout()
        ns:SetGroupOwnLook(a, nil)
        assert(ns.db.blocks[a].look == nil, "back to the Look tab's choice")
        ns:ResetProfile("top")
    end,
    -- sharing a style or a layout: export, missing parts, import
    function()
        ns:ResetProfile("top")
        ns.db.blocks.gold.font = "lsm:SomeMissingFont"
        ns.db.blocks.gold.fontSize = 17
        local style = ns:ExportStyle()
        assert(ns:GetExportKind(style) == "style", "style text recognized")
        local missing = ns:FindMissing(style)
        local listed = false
        for _, line in ipairs(missing) do listed = listed or line:find("SomeMissingFont") ~= nil end
        assert(listed, "missing font listed")
        -- a fake layout with a launcher and a DataBroker block nobody has here
        ns.db.blocks.fps.point = { "CENTER", "CENTER", 10, 20 }
        local layoutText = ns:ExportLayout()
        assert(ns:GetExportKind(layoutText) == "layout", "layout text recognized")
        assert(ns:GetExportKind(ns:ExportProfile()) == "profile", "profile text recognized")
        assert(ns:GetExportKind("nonsense") == nil, "invalid text")
        -- change things, then import both back
        ns.db.blocks.gold.fontSize = 9
        ns.db.blocks.fps.point = { "CENTER", "CENTER", 0, 0 }
        assert(ns:ImportStyle(style) and ns.db.blocks.gold.fontSize == 17, "style imported")
        assert(ns:ImportLayout(layoutText) and ns.db.blocks.fps.point[3] == 10, "layout imported")
        assert(ns.db.blocks.gold.fontSize == 17, "layout import keeps the look")
        assert(not ns:ImportStyle(layoutText) and not ns:ImportLayout(style), "kinds are not mixed up")
        ns:UpdateLayout()
        ns:Undo()
        -- the import window routes each kind (popups are mocked)
        ns:OpenImportWindow(style)
        ns:FinishImport(layoutText, "layout")
        ns:FinishImport(style, "style")
        ns:ResetProfile("top")
    end,
    -- round minimap button: shown, dragged, hidden, shown again
    function()
        ns.sv.hideMinimapButton = nil
        ns:UpdateMinimapButton()
        local b = _G.TesseraMinimapButton
        assert(b, "round minimap button created")
        GetCursorPosition = function() return 10, 10 end
        b:GetScript("OnDragStart")(b)
        b:GetScript("OnUpdate")(b)
        b:GetScript("OnDragStop")(b)
        assert(type(ns.sv.minimapAngle) == "number", "angle saved")
        b:GetScript("OnEnter")(b)
        b:GetScript("OnClick")(b, "RightButton")
        b:GetScript("OnClick")(b, "RightButton")
        ns:SetMinimapButtonShown(false)
        ns:SetMinimapButtonShown(true)
    end,
    -- Edit Mode: a copy of the layout with room for a bar stuck to the bottom
    function()
        assert(ns.EditModeCopyName("Modern++", {}) == "Modern++ (Tessera 1)", "copy name")
        assert(ns.EditModeCopyName("Modern++", { ["Modern++ (Tessera 1)"] = true }) == "Modern++ (Tessera 2)", "next number")
        local long = ns.EditModeCopyName(("é"):rep(40), {})
        local _, chars = long:gsub("[^\128-\191]", "")
        assert(chars == 30, "name cut to 30 characters: " .. chars)
        ns:ResetProfile("stormwind")
        local rect = ns.GroupRectUI
        ns.GroupRectUI = function() return 0, 0, 1366, 24 end -- the bar along the bottom edge
        local moves = ns:PlanEditModeRoom(EditModePresetLayoutManager:GetCopyOfPresetLayouts()[1])
        assert(#moves == 1 and moves[1].sys.system == 13 and moves[1].dy == 24,
            "only the micro menu moves, by what the main bar needs: " .. tostring(moves[1] and moves[1].dy))
        assert(ns:OfferEditModeRoom() == true, "offer shown")
        assert(ns:ApplyEditModeRoom() == true, "copy made")
        local copy = EM.layouts.layouts[1]
        assert(copy.layoutName == "Moderne (Tessera 1)" and copy.layoutType == 1, "copy of the preset, account type")
        assert(EM.layouts.activeLayout == 4, "copy active (after the 3 presets)")
        assert(copy.systems[1].anchorInfo.offsetY == 30 and copy.systems[1].isInDefaultPosition == false,
            "micro menu moved up from its real place: " .. tostring(copy.systems[1].anchorInfo.offsetY))
        assert(copy.systems[3].anchorInfo.offsetY == 153, "chat untouched")
        assert(ns:GetEditModeStatus():find("Tessera copy"), "bug report knows the copy")
        -- again from the copy: the same copy is updated, no new layout
        ns:OfferEditModeRoom()
        ns:ApplyEditModeRoom()
        assert(#EM.layouts.layouts == 1, "copy reused")
        -- back to the original, then cleaning up: a layout of the player with a
        -- Tessera-like name is never deleted
        assert(ns:RevertEditModeLayout() and EM.layouts.activeLayout == 1, "back to Moderne")
        table.insert(EM.layouts.layouts, { layoutName = "Moderne (Tessera 2)", layoutType = 1, systems = EMSystems() })
        local list = ns:GetEditModeCopies()
        assert(#list == 1 and list[1] == "Moderne (Tessera 1)", "only Tessera's own copy is listed")
        ns:OfferEditModeCleanup()
        ns:DeleteEditModeCopies()
        assert(#EM.layouts.layouts == 1 and EM.layouts.layouts[1].layoutName == "Moderne (Tessera 2)",
            "the player's layout is kept")
        -- full: nothing is made
        for i = 1, 4 do table.insert(EM.layouts.layouts, { layoutName = "L" .. i, layoutType = 1, systems = EMSystems() }) end
        ns:OfferEditModeRoom()
        assert(ns:ApplyEditModeRoom() == false and #EM.layouts.layouts == 5, "limit respected")
        ns:CheckEditModeRoom()
        ns:CheckEditModeForProfile()
        ns.GroupRectUI = rect
        EM.layouts = { activeLayout = 1, layouts = {} }
        ns:ResetProfile("top")
    end,
    -- quick tour
    function()
        ns:StartTutorial()
        for _ = 1, 9 do TesseraTutorial.next:GetScript("OnClick")() end
        -- the layouts step: try some, leave without keeping -> the player's layout comes back
        ns:ResetProfile("left")
        ns.db.blocks.time.width = 123
        ns:StartTutorial()
        TesseraTutorial.next:GetScript("OnClick")() -- step 2: layouts
        TesseraTutorial.layouts.name:GetText()
        TesseraTutorial.action:GetScript("OnClick")() -- nothing tried yet: no change
        ns:KeepTourLayout()
        for _ = 1, #ns.PRESETS + 1 do TesseraTutorial.layouts.nextLayout:GetScript("OnClick")() end
        TesseraTutorial.layouts.prev:GetScript("OnClick")()
        TesseraTutorial.next:GetScript("OnClick")() -- leaves the step
        assert(ns.db.blocks.time.width == 123, "the player's layout comes back after the tour")
        -- keep one
        ns:StartTutorial()
        TesseraTutorial.next:GetScript("OnClick")()
        TesseraTutorial.layouts.nextLayout:GetScript("OnClick")()
        TesseraTutorial.layouts.nextLayout:GetScript("OnClick")()
        ns:KeepTourLayout()
        TesseraTutorial:Hide()
        assert(ns.db.blocks.time.width ~= 123, "a kept layout stays")
        ns:ResetProfile("top")
    end,
    -- group looks: fused, tiles (joint between blocks), separate; old profiles keep their choice
    function()
        ns.db.groupLook = nil
        ns.db.merge = false
        assert(ns:GetGroupLook() == "separate", "old profile without merge reads as separate")
        ns.db.merge = true
        assert(ns:GetGroupLook() == "fused", "old profile with merge reads as fused")
        ns:SetGroupLook("tiles")
        assert(ns.db.merge == true and ns:JointGap() >= 2, "tiles keep the groups, with a joint")
        ns.db.jointGap = 6
        ns:UpdateLayout()
        ns:ResetProfile("stormwind")
        ns:UpdateLayout()
        ns:SetGroupLook("separate")
        assert(ns.db.merge == false and ns:JointGap() == 0, "separate: no joint")
        ns:UpdateLayout()
        ns:SetGroupLook("fused")
        ns.db.jointGap = nil
        ns:ResetProfile("top")
    end,
    -- recover off-screen blocks, Edit Mode hook, what's new, combat toggle
    function()
        ns:RecoverBlocksCommand()
        ns:HookEditMode()
        ns.sv.welcomed, ns.sv.lastVersion = true, "old"
        ns:ShowWelcomeIfNeeded()
        Tessera_ToggleBlocks(); Tessera_ToggleBlocks()
    end,
}) do
    local ok5, err5 = pcall(step) if not ok5 then print("STEP ERROR: " .. tostring(err5)) end
end
-- last: reset everything empties the saved variables and asks for a reload
do
    local reloaded = false
    ReloadUI = function() reloaded = true end
    local ok, err = pcall(function() ns:ResetEverything() end)
    if not ok then print("STEP ERROR: " .. tostring(err)) end
    if TesseraDB ~= nil or not reloaded then print("STEP ERROR: reset everything did not empty TesseraDB / reload") end
end
-- tools/fuzz_blocks.lua reuses the loaded addon
if os.getenv("TESSERA_EXPORT_NS") then TESSERA_NS = ns end
-- tools/check_docs.lua asks for the list of blocks (key and locale key of the name)
if os.getenv("TESSERA_LIST_MODULES") then
    for _, key in ipairs(ns.order) do
        print("MODULE " .. key .. " " .. tostring(ns.modules[key].label))
    end
end
print("mock run finished")
