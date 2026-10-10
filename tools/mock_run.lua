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
    CreateFontString = function() return NewObject("FontString") end,
    CreateAnimationGroup = function() return NewObject("AnimGroup") end,
    CreateAnimation = function() return NewObject("Anim") end,
    GetStringWidth = function() return 40 end, GetUnboundedStringWidth = function() return 40 end,
    GetStringHeight = function() return 12 end,
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
Minimap = NewObject("Frame")
CreateFrame = function(kind, name) local f = NewObject(kind); f.__name = name; if name then _G[name] = f end return f end
C_Timer = { After = function(_, fn) table.insert(_G.__timers, fn) end, NewTicker = function(_, fn) table.insert(_G.__tickers, fn); return NewObject("Ticker") end }
__timers, __tickers = {}, {}
GetLocale = function() return arg[2] or "frFR" end
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
for i = 1, 7 do local ok2, err2 = xpcall(function() ns.ShowOptionsPage(i) end, debug.traceback) if not ok2 then print("PAGE ERROR " .. i .. ": " .. tostring(err2)) end end
for _, key in ipairs(ns:GetBlockKeys()) do
    local ok3, err3 = pcall(function() ns:OpenOptionsFor(key); ns:UpdateBlock(key) end)
    if not ok3 then print("BLOCK ERROR " .. key .. ": " .. tostring(err3)) end
end
-- tooltips of every block
for key, f in pairs(ns.frames) do
    local fn = f.__scripts.OnEnter
    if fn then local ok4, err4 = pcall(fn, f) if not ok4 then print("TOOLTIP ERROR " .. key .. ": " .. tostring(err4)) end end
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
    function() SlashCmdList.TESSERA("debug") end,
    function() SlashCmdList.TESSERA("help") end,
    function() SlashCmdList.TESSERA("bug") end,
    function() SlashCmdList.TESSERA("debug legacy") end,
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
        for i = 1, 7 do ns.ShowOptionsPage(i) end
        ns:OpenOptionsFor("gold")
        ns:SetBrokerMode(false)
        assert(not ns.brokerModeActive, "broker mode not off")
    end,
    function() for _, t in ipairs(ns:GetAvailableThemes()) do ns:ApplyTheme(t.key); ns:UpdateLayout() end end,
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
print("mock run finished")
