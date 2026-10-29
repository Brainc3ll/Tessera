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
function MockTextWidth(text)
    local n = #((text or ""):gsub("|T.-|t", "##"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    return n > 40 and 6 * n or 40
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
    -- positions: fixed by default; with MOCK_GEOMETRY (tools/geometry_check.lua) they come
    -- from the anchor points, like the game (see MockRect below)
    GetLeft = function(self) if MOCK_GEOMETRY then return (MockRect(self)) end return 100 end,
    GetRight = function(self) if MOCK_GEOMETRY then local l, _, w = MockRect(self) return l + w end return 100 + self.__w end,
    GetTop = function(self) if MOCK_GEOMETRY then local _, b, _, h = MockRect(self) return b + h end return 500 end,
    GetBottom = function(self) if MOCK_GEOMETRY then local _, b = MockRect(self) return b end return 500 - self.__h end,
    GetCenter = function(self)
        if MOCK_GEOMETRY then local l, b, w, h = MockRect(self) return l + w / 2, b + h / 2 end
        return 100 + self.__w / 2, 500 - self.__h / 2
    end,
    GetNumPoints = function(self) return #(self.__points or {}) end,
    GetPoint = function(self, i)
        local p = (self.__points or {})[i or 1]
        if p then return p[1], p[2], p[3], p[4], p[5] end
    end,
    GetEffectiveScale = function() return 1 end, GetScale = function() return 1 end,
    GetName = function(self) return self.__name end,
    CreateTexture = function() return NewObject("Texture") end,
    CreateMaskTexture = function() return NewObject("MaskTexture") end,
    CreateFontString = function() return NewObject("FontString") end,
    CreateAnimationGroup = function() return NewObject("AnimGroup") end,
    CreateAnimation = function() return NewObject("Anim") end,
    -- text width: 40, except very long texts (over 40 letters, icons and colour codes
    -- left out: 6 per letter)
    GetStringWidth = function(self) return MockTextWidth(self.__text) end,
    GetUnboundedStringWidth = function(self) return MockTextWidth(self.__text) end,
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
    ClearAllPoints = function(self) self.__anchors = nil; self.__points = nil end,
    SetAllPoints = function(self, rel) self.__points = nil; self:SetPoint("TOPLEFT", rel or UIParent, "TOPLEFT", 0, 0); self:SetPoint("BOTTOMRIGHT", rel or UIParent, "BOTTOMRIGHT", 0, 0) end,
    SetPoint = function(self, point, rel, relPoint, x, y)
        -- recorded for the geometry mode: SetPoint(point, rel, relPoint, x, y), (point, x, y), (point)
        local r, rp, ox, oy = rel, relPoint, x, y
        if type(rel) == "number" then r, rp, ox, oy = nil, point, rel, relPoint end
        if type(r) == "string" then r = _G[r] end
        if r == nil then r = UIParent end
        rp = rp or point
        self.__points = self.__points or {}
        for i = #self.__points, 1, -1 do if self.__points[i][1] == point then table.remove(self.__points, i) end end
        table.insert(self.__points, { point, r, rp, ox or 0, oy or 0 })
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
-- Geometry mode: rectangle of a frame (left, bottom, width, height) from its anchor
-- points, as the game resolves them (one point: placed by its size; two points on an
-- axis: they set both edges). Scales are 1 in the mock.
local FRACTION = { LEFT = 0, CENTER = 0.5, RIGHT = 1, TOP = 1, BOTTOM = 0 }
local function PointFractions(point)
    point = point or "CENTER"
    local v = point:match("^TOP") and 1 or (point:match("^BOTTOM") and 0 or 0.5)
    local h = point:match("LEFT$") and 0 or (point:match("RIGHT$") and 1 or 0.5)
    return h, v
end
local resolving = {}
function MockRect(f)
    if f == UIParent then return 0, 0, UIParent.__w, UIParent.__h end
    local pts = f.__points
    if not pts or #pts == 0 or resolving[f] then return 100, 500 - (f.__h or 0), f.__w or 0, f.__h or 0 end
    resolving[f] = true
    local hx, vy = {}, {}
    for _, p in ipairs(pts) do
        local rl, rb, rw, rh = MockRect(p[2] or UIParent)
        local rfx, rfy = PointFractions(p[3])
        local fx, fy = PointFractions(p[1])
        local ax, ay = rl + rfx * rw + p[4], rb + rfy * rh + p[5]
        local hsame, vsame = false, false
        for _, c in ipairs(hx) do if c[1] == fx then hsame = true end end
        for _, c in ipairs(vy) do if c[1] == fy then vsame = true end end
        if not hsame then hx[#hx + 1] = { fx, ax } end
        if not vsame then vy[#vy + 1] = { fy, ay } end
    end
    resolving[f] = nil
    local w, h = f.__w or 0, f.__h or 0
    local l, b
    if #hx >= 2 and hx[1][1] ~= hx[2][1] then
        local a, c = hx[1], hx[2]
        w = (c[2] - a[2]) / (c[1] - a[1]); l = a[2] - a[1] * w
    else l = hx[1][2] - hx[1][1] * w end
    if #vy >= 2 and vy[1][1] ~= vy[2][1] then
        local a, c = vy[1], vy[2]
        h = (c[2] - a[2]) / (c[1] - a[1]); b = a[2] - a[1] * h
    else b = vy[1][2] - vy[1][1] * h end
    return l, b, w, h
end
_G.MockRect = MockRect
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
-- Blizzard's Edit Mode (Layers.lua): two frames at the bottom of the screen and
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
GetCursorInfo = function() return "item", 2592 end
ClearCursor = function() end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
hooksecurefunc = noop
StaticPopup_Show = noop RegisterStateDriver = noop UnregisterStateDriver = noop
MinimalSliderWithSteppersMixin = { Label = { Right = 1, Left = 2 }, Event = { OnValueChanged = 1 } }
methods.IsMouseEnabled = function() return true end
-- any other global: a function returning nil
setmetatable(_G, { __index = function(_, k) if k:match("^[A-Z]") or k:match("^C_") then return nil end end })

-- Start from a player's saved variables (old-data test), as WoW Forever would:
--   TESSERA_SV=tools/fixtures/sv-rc9-forever.lua TESSERA_FULLNAME="Nora Quill" TESSERA_REALM="Classic PvE"
--   lua5.1 tools/mock_run.lua . enUS
local svFile = os.getenv("TESSERA_SV")
if svFile and svFile ~= "" then assert(loadfile(svFile))() end
local fullName = os.getenv("TESSERA_FULLNAME")
if fullName and fullName ~= "" then
    local first, last = fullName:match("^(%S+)%s+(%S+)$")
    RegionalUniqueNamesEnabled = function() return true end
    UnitNameUnmodified = function() return first, last end
    UnitName = function() return first, last end
end
local realmLabel = os.getenv("TESSERA_REALM")
if realmLabel and realmLabel ~= "" then GetRealmName = function() return realmLabel end end

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
if svFile and svFile ~= "" then
    -- the character keys after the login conversion, for the old-data test
    for _, field in ipairs({ "chars", "charProfiles", "goldHistory" }) do
        local keys = {}
        for k in pairs(TesseraDB[field] or {}) do table.insert(keys, k) end
        table.sort(keys)
        print("SV " .. field .. ": " .. table.concat(keys, " | "))
    end
end
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
    -- export texts: the compact format (TESSERA2) gives back exactly the same profile, and
    -- texts exported by earlier versions (TESSERA1, tools/fixtures/rc9-*.txt, made by the
    -- released 1.0.0-rc9) must always import
    function()
        local function Same(a, b, path)
            if type(a) ~= type(b) then error("export: " .. path .. " differs (" .. tostring(a) .. " / " .. tostring(b) .. ")") end
            if type(a) ~= "table" then
                if a ~= b then error("export: " .. path .. " differs (" .. tostring(a) .. " / " .. tostring(b) .. ")") end
                return
            end
            for k, v in pairs(a) do Same(v, b[k], path .. "." .. tostring(k)) end
            for k, v in pairs(b) do if a[k] == nil then Same(nil, v, path .. "." .. tostring(k)) end end
        end
        for _, preset in ipairs(ns.PRESETS) do
            ns:ResetProfile(preset)
            ns.db.blocks.gold.width, ns.db.blocks.fps.bgColor = 133, { r = 0.6, g = 0.35, b = 0.8, a = 0.45 }
            ns.db.blocks.stats.stat, ns.db.blocks.xp.barTexture = "haste", "lsm:FlareUI Forever"
            local text = ns:ExportProfile()
            assert(text:sub(1, 9) == "TESSERA2:", "new exports use the compact format")
            assert(#text < 20000, "export too long for " .. preset .. ": " .. #text)
            Same(ns:SanitizeProfile(ns.DeepCopy(ns.db)), ns:DecodeProfile(text), preset)
            -- a layout and a style go through the same format
            local layout, style = ns:ExportLayout(), ns:ExportStyle()
            assert(ns:GetExportKind(layout) == "layout" and ns:GetExportKind(style) == "style")
            assert(#style < 8000 and #layout < 8000, "style or layout export too long: " .. #style .. " / " .. #layout)
        end
        local function Fixture(name)
            local f = assert(io.open(addonDir .. "/tools/fixtures/" .. name), "missing fixture " .. name)
            local text = f:read("*a")
            f:close()
            assert(text:sub(1, 9) == "TESSERA1:", name .. " is an older text")
            return text
        end
        local old = ns:DecodeProfile(Fixture("rc9-profile.txt"))
        assert(old, "a profile exported by 1.0.0-rc9 no longer imports")
        assert(old.theme == "grimoire" and old.groupDefaults.fontSize == 13, "rc9 profile: settings lost")
        local b = old.blocks
        assert(b.gold.width == 133 and b.gold.goldFormat == "short" and b.fps.bgColor.r == 0.6, "rc9 profile: block settings lost")
        assert(b.time.frozen == true and b.time.scale == 1.25 and b.stats.point[3] == -40, "rc9 profile: placement lost")
        assert(b.stats.stat == "crit", "rc9 profile: the Stats block's choice lost")
        assert(b.gold.barTexture == false and b.xp.barTexture == false, "rc9 profile: bar texture")
        assert(ns:ImportProfile(Fixture("rc9-profile.txt"), "From rc9"), "rc9 profile import refused")
        ns:ResetProfile("top")
        assert(ns:ImportStyle(Fixture("rc9-style.txt")), "a style exported by 1.0.0-rc9 no longer imports")
        assert(ns.db.blocks.gold.font == "morpheus", "rc9 style not applied")
        -- a style keeps its bar texture
        ns.db.blocks.xp.barTexture = "lsm:FlareUI Forever"
        local withBar = ns:ExportStyle()
        ns.db.blocks.xp.barTexture = false
        assert(ns:ImportStyle(withBar) and ns.db.blocks.xp.barTexture == "lsm:FlareUI Forever", "style: bar texture lost")
        assert(ns:ImportLayout(Fixture("rc9-layout.txt")), "a layout exported by 1.0.0-rc9 no longer imports")
        assert(ns.db.blocks.stats.enabled and ns.db.blocks.gold.width == 133, "rc9 layout not applied")
        ns:SetProfile(ns.DEFAULT_PROFILE)
        ns:DeleteProfile("From rc9")
        ns:ResetProfile("top")
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
        for _, cmd in ipairs({ "debug", "debug", "debug forever", "debug dps", "debug dps live", "debug farm",
            "debug farm live", "debug farm live",
            "test", "test blocs", "test compacte", "test colonne", "test infobulles", "test infobulles",
            "test infobulles", "test fin" }) do
            SlashCmdList.TESSERA(cmd)
            local queued = __timers; __timers = {}
            for _, fn in ipairs(queued) do pcall(fn) end
        end
        -- the Farm test window: an item dropped on it, then a bag change
        local farm = ns.farmLive
        if farm and farm.GetScript and farm:GetScript("OnReceiveDrag") then
            farm:GetScript("OnReceiveDrag")(farm)
            farm:GetScript("OnEvent")(farm, "BAG_UPDATE_DELAYED")
        end
        assert(not ns.sv.profiles.Test, "test profile not deleted")
        assert(not ns.sv.devTooltips, "the player's tooltip settings given back")
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
    -- a spacer in line mode, Behaviour tab: its options stay above the buttons at the bottom
    function()
        local k = ns:AddSpacer()
        ns.db.blocks[k].spacerMode = "line"
        ns:OpenOptionsFor(k)
        ns.ShowBlockSub(4)
        ns.optionsLowestY = 0
        ns:RefreshOptions()
        local limit = TesseraOptions:GetHeight() - 98 - 12 - 40 -- the bottom buttons take 40 px
        assert(-ns.optionsLowestY <= limit, "spacer options overlap the buttons: " .. -ns.optionsLowestY .. " > " .. limit)
        ns:RemoveSpacer(k)
    end,
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
    -- FlareUI's XP bar turned on after the profile was made: the top bar follows it
    function()
        ns:ResetProfile("top")
        local root = ns:GetRoot("gold")
        assert(ns.db.blocks[root].anchor and ns.db.blocks[root].anchor.frame == "FlareUI_XPBar", "top bar follows FlareUI's XP bar")
        local xp = CreateFrame("Frame", "FlareUI_XPBar", UIParent)
        _G.FlareUI_XPBar = xp
        xp:SetSize(560, 14)
        xp:Show()
        ns.db.blocks[root].anchor = { top = -6 } -- a bar made by an older version
        ns:ReanchorAll()
        ns:UpdateLayout()
        _G.FlareUI_XPBar = nil
        ns:ResetProfile("top")
    end,
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
        -- mixed styles: after the styles, each column in its own style
        local styles = #ns:GetAvailableThemes()
        local before = b.style:GetText()
        local mixed
        for _ = 1, styles + 4 do
            b.nextStyle:GetScript("OnClick")(b.nextStyle)
            if b.style:GetText() == ns.L.DEMO_STYLE_MIXED:format(1, 4) then mixed = true break end
        end
        assert(mixed, "the switcher reaches the mixed styles")
        local function Look(cfg)
            return table.concat({ tostring(cfg.bg), tostring(cfg.border), tostring(cfg.font),
                tostring(cfg.bgColor and cfg.bgColor.r) }, "|")
        end
        assert(Look(ns.db.blocks.gold) ~= Look(ns.db.blocks.friends), "each column has its own style")
        local title = ns.db.blocks[ns.SPACER_PREFIX .. "demo2"].spacerText
        assert(title ~= ns.L.DEMO_CAT_SOCIAL and title:find(ns.L.DEMO_CAT_SOCIAL, 1, true), "the column title names its style")
        for _ = 1, styles + 4 do b.nextStyle:GetScript("OnClick")(b.nextStyle) end
        assert(b.style:GetText() == ns.L.DEMO_STYLE_MIXED:format(1, 4), "the switcher goes round every step")
        for _ = 1, 4 do b.nextStyle:GetScript("OnClick")(b.nextStyle) end
        assert(ns.db.blocks[ns.SPACER_PREFIX .. "demo2"].spacerText == ns.L.DEMO_CAT_SOCIAL,
            "one style again: plain column titles")
        assert(before, "banner text")
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
        ns:ApplyStyle("gold")
        ns:UpdateBlock("gold")
        assert(not (ns.frames.gold.lastText or ""):find("|T", 1, true), "runestone: no coin pictures")
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
    -- threshold colors: automatic = soft with the FlareUI style, bright otherwise; the old
    -- colorblind checkbox becomes the colorblind palette; the FlareUI style draws bronze
    -- lines and textures the progress bars when FlareUI's bar texture is there
    function()
        local has, lsm = ns.HasFlareUIMedia, ns.GetLSM
        ns.HasFlareUIMedia = function() return true end
        ns.GetLSM = function() return { Fetch = function(_, kind, name)
            if kind == "statusbar" and name == "FlareUI Forever" then return "flare-forever.tga" end
            if kind == "border" then return "flare-thin.tga" end
        end } end
        ns.sv.levelPalette, ns.sv.colorblind = nil, true
        assert(ns:GetLevelPalette() == "colorblind" and ns.sv.colorblind == nil, "colorblind not converted")
        ns.sv.levelPalette = nil
        ns:ApplyTheme("flareui2")
        assert(ns.LEVEL_COLORS[1] == "26d126", "FlareUI style: soft colors")
        local cfg, f = ns.db.blocks.xp, ns.frames.xp
        assert(cfg.separators and cfg.barTexture == "lsm:FlareUI Forever", "FlareUI style: lines and bar texture")
        cfg.progressBar = true
        local file
        local set = f.bar.SetTexture
        f.bar.SetTexture = function(self, t) file = t; if set then return set(self, t) end end
        ns:UpdateBar(f, cfg, { progress = function() return 0.5 end }, 1)
        assert(file == "flare-forever.tga" and f.barTextured, "progress bar not textured")
        ns.GetLSM = function() return nil end
        ns:UpdateBar(f, cfg, { progress = function() return 0.5 end }, 1)
        assert(not f.barTextured, "without FlareUI: plain color")
        f.bar.SetTexture = set
        ns.GetLSM = lsm
        ns:ApplyTheme("flat")
        assert(ns.LEVEL_COLORS[1] == "4dff4d" and not cfg.barTexture, "other style: bright, no texture")
        ns.sv.levelPalette = "soft"; ns:ApplyLevelPalette()
        assert(ns.LEVEL_COLORS[3] == "de4545", "soft chosen")
        ns.sv.levelPalette = nil; ns:ApplyLevelPalette()
        ns.HasFlareUIMedia = has
    end,
    -- class color everywhere a color is picked; soft colors tone it down, colorblind does not
    function()
        ns.sv.levelPalette = "bright"; ns:ApplyLevelPalette()
        assert(math.abs(ns:GetClassColor().b - 1) < 0.001, "bright: the game's class color")
        ns.sv.levelPalette = "soft"; ns:ApplyLevelPalette()
        assert(math.abs(ns:GetClassColor().b - 0.85) < 0.001, "soft: darker class color")
        ns.sv.levelPalette = "colorblind"; ns:ApplyLevelPalette()
        assert(math.abs(ns:GetClassColor().b - 1) < 0.001, "colorblind: class colors stay bright")
        ns.sv.levelPalette = nil; ns:ApplyLevelPalette()
        local cfg = ns.db.blocks.gold
        for _, k in ipairs({ "classColorBg", "classColorIcon", "classColorSeparator" }) do
            assert(cfg[k] == false, k .. " default")
            local found
            for _, f in ipairs(ns.STYLE_KEYS) do if f == k then found = true end end
            assert(found, k .. " is part of the style")
        end
        cfg.classColorBg, cfg.classColorIcon, cfg.classColorSeparator, cfg.iconShape = true, true, true, "square"
        ns:ApplyStyle("gold")
        ns:UpdateLayout()
        cfg.classColorBg, cfg.classColorIcon, cfg.classColorSeparator, cfg.iconShape = false, false, false, "none"
        ns:ApplyStyle("gold")
        -- a new skin rebuilds the border pieces of the joins (no piece of the old style left)
        ns.frames.gold.seamKey = "old"
        ns:ApplyStyle("gold")
        assert(ns.frames.gold.seamKey ~= "old", "border joins rebuilt after a new skin")
        -- a new style starts without the class color options; the list is alphabetical
        cfg.classColorText, cfg.classColorBg = true, true
        ns:ApplyTheme("flat")
        assert(not cfg.classColorText and not cfg.classColorBg, "a new style unchecks the class colors")
        local themes = ns:GetAvailableThemes()
        for i = 2, #themes do
            assert(ns.SortKey(themes[i - 1].name) <= ns.SortKey(themes[i].name), "styles in alphabetical order (accents ignored)")
        end
        local sp = ns:AddSpacer()
        ns.db.blocks[sp].spacerMode, ns.db.blocks[sp].spacerClassColor = "line", true
        ns:ApplyStyle(sp)
        ns:RemoveSpacer(sp)
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
    -- the screenshot helper of an older test version, left open: the layout comes back
    function()
        local goldEnabled = ns.db.blocks.gold.enabled
        local positions = {}
        for key, cfg in pairs(ns.db.blocks) do positions[key] = { enabled = cfg.enabled } end
        ns.sv.foreverPreviewBackup = { positions = positions, extra = {}, mode = 1 }
        ns.db.blocks.gold.enabled = not goldEnabled
        ns:RestoreForeverPreview()
        assert(not ns.sv.foreverPreviewBackup and ns.db.blocks.gold.enabled == goldEnabled, "layout given back")
    end,
    -- ready-made layouts: second rows placed once under the bar's left edge; bars stuck
    -- to an edge only hold blocks that are always shown (no hole in the bar)
    function()
        for _, preset in ipairs({ "top", "forever", "bottom" }) do
            ns:ResetProfile(preset)
            local found = false
            for _, cfg in pairs(ns.db.blocks) do
                local a = cfg.enabled and cfg.anchor
                if a and (a.below or a.above) then
                    found = true
                    assert(a.fixed and a.offset == 0, preset .. ": second row placed once at the bar's left edge")
                end
            end
            assert(found, preset .. " has a second row")
        end
        -- a hidden block keeps the width it had when shown, whatever its old text says
        -- (the demo mode's samples used to widen it and push its neighbours away)
        ns:ResetProfile("top")
        ns:UpdateLayout()
        local mail = ns.frames.mail
        mail:Hide()
        ns.db.blocks.mail.slotW = 60
        ns:UpdateLayout()
        local before = mail:GetWidth()
        mail.text:SetText("A very long sample text from the demo mode, much wider than the block")
        ns:UpdateLayout()
        assert(math.abs(mail:GetWidth() - before) < 1, "hidden block keeps its last shown width")
        mail.text:SetText("")
        ns:ResetProfile("rampart")
        for key, cfg in pairs(ns.db.blocks) do
            if cfg.enabled and not ns.IsSpacerKey(key) then assert(not cfg.hideEmpty, "rampart: " .. key .. " always shown") end
        end
        ns:ResetProfile("top")
    end,
    -- "around the gryphons" layout: one group in each bottom corner of the screen
    function()
        ns:ResetProfile("gryphons")
        ns:UpdateLayout()
        local b = ns.db.blocks
        assert(b.legacy.point and b.legacy.point[1] == "BOTTOMLEFT" and not b.legacy.dock, "legacy heads the left group")
        assert(b.time.point and b.time.point[1] == "BOTTOMRIGHT" and not b.time.dock, "time heads the right group")
        assert(b.comprehension.dock and b.comprehension.dock.to == "legacy" and b.comprehension.dock.side == "RIGHT", "row 1")
        assert(b.durability.dock and b.durability.dock.to == "legacy" and b.durability.dock.side == "TOP", "column 1")
        assert(b.camping.dock and b.camping.dock.to == "comprehension" and b.camping.dock.side == "TOP", "column 2")
        assert(b.gold.dock.to == "durability" and b.bags.dock.to == "camping", "row 3")
        assert(b.date.dock and b.date.dock.to == "time" and b.date.dock.side == "LEFT", "right group grows inward")
        assert(not b.camping.hideEmpty and not b.comprehension.hideEmpty, "no hole in the rectangles")
        assert(not b.mail.enabled and b.coords and not b.coords.enabled, "other blocks hidden")
        -- each column as wide as its widest block: straight edges
        local f = ns.frames
        for _, column in ipairs({ { "legacy", "durability", "gold" }, { "comprehension", "camping", "bags" },
                                  { "time", "latency", "honor" }, { "date", "fps", "weaponSkills" } }) do
            for _, key in ipairs(column) do
                assert(math.abs(f[key]:GetWidth() - f[column[1]]:GetWidth()) < 0.01, "column width " .. key)
            end
        end
        ns:ResetProfile("top")
    end,
    -- the second row of "Double bar" dropped back right against its bar: it keeps hanging
    -- there (full width, centered) instead of merging into the bar as a narrow column
    function()
        ns:ResetProfile("forever")
        ns:UpdateLayout()
        local rowKey, base
        for key, cfg in pairs(ns.db.blocks) do
            if cfg.enabled and cfg.anchor and cfg.anchor.below then rowKey, base = key, cfg.anchor.below end
        end
        assert(rowKey, "Double bar has a second row")
        local baseGroup = ns:GetSubtree(ns:GetRoot(base))
        local rowGroup = ns:GetSubtree(rowKey)
        -- the bar from y 100 to 80, the row dropped just under it (where it hangs)
        local realRect, realDock = ns.GetRectUI, ns.FindDock
        ns.GetRectUI = function(_, frame)
            if baseGroup[frame.key] then return 100, 80, 700, 100 end
            if rowGroup[frame.key] then return 150, 58, 650, 79 end
            return realRect(ns, frame)
        end
        ns.FindDock = function() return { to = base, side = "BOTTOM" }, 1 end
        ns:SnapAndSave(ns.frames[rowKey])
        ns.GetRectUI, ns.FindDock = realRect, realDock
        local cfg = ns.db.blocks[rowKey]
        assert(cfg.anchor and cfg.anchor.below == base and cfg.anchor.fill, "the row keeps hanging under its bar")
        assert(not cfg.dock, "the row is not merged into the bar")
        ns:ResetProfile("top")
    end,
    -- a second row: a lone block left in it keeps its own width (not the whole bar's);
    -- a column merged into the bar pushes the row down instead of being covered;
    -- a text that changes without changing size asks for no new layout
    function()
        ns:ResetProfile("top")
        ns:UpdateLayout()
        local rowKey, base
        for key, cfg in pairs(ns.db.blocks) do
            if cfg.enabled and cfg.anchor and cfg.anchor.below then rowKey, base = key, cfg.anchor.below end
        end
        assert(rowKey, "the top bar has a second row")
        local row = ns:GetSubtree(rowKey)
        for k in pairs(row) do if k ~= rowKey and ns.frames[k] then ns.frames[k]:Hide() end end
        ns.frames[rowKey]:Show()
        ns:UpdateLayout()
        local barWidth = 0
        for k in pairs(ns:GetSubtree(ns:GetRoot(base))) do
            local f = ns.frames[k]
            if f and f:IsShown() then barWidth = barWidth + f:GetWidth() end
        end
        assert(ns.frames[rowKey]:GetWidth() < barWidth / 2, "a lone block in the second row is not stretched")
        -- a block of the bar reaches 20 below the block the row hangs from
        local baseGroup = ns:GetSubtree(ns:GetRoot(base))
        local deep
        for k in pairs(baseGroup) do if k ~= base and ns.frames[k] and ns.frames[k]:IsShown() then deep = k end end
        local realRect = ns.GetRectUI
        ns.GetRectUI = function(_, frame)
            if frame.key == deep then return 300, 60, 340, 100 end
            if baseGroup[frame.key] then return 100, 80, 140, 100 end
            return realRect(ns, frame)
        end
        ns:UpdateLayout()
        ns.GetRectUI = realRect
        assert(ns.frames[rowKey].hangDrop == 20, "the row moves under the deepest block: " .. tostring(ns.frames[rowKey].hangDrop))
        ns:UpdateLayout()
        assert((ns.frames[rowKey].hangDrop or 0) == 0, "and back up when it is gone")
        -- same size, new text: no layout
        local f, calls = ns.frames.fps, 0
        local real = ns.RequestLayout
        ns.RequestLayout = function() calls = calls + 1 end
        f.lastText = "something else"
        ns:UpdateBlock("fps")
        ns.RequestLayout = real
        assert(calls == 0, "a text of the same size asks for no layout")
        ns:ResetProfile("top")
    end,
    -- never anchor a block to one that is (still) anchored to it: WoW would raise
    -- "Cannot anchor to a region dependent on it" (seen when the demo rebuilt the groups)
    function()
        local a, b = ns.frames.bags, ns.frames.durability
        local ca = ns.db.blocks.bags
        local oldDock = ca.dock
        ca.dock = { to = "durability", side = "RIGHT" }
        b.GetNumPoints = function() return 1 end
        b.GetPoint = function() return "TOPLEFT", a, "TOPRIGHT", 0, 0 end
        assert(ns:AnchorDocked(a, ca) == false, "a loop of anchors is refused")
        b.GetNumPoints, b.GetPoint = nil, nil
        ca.dock = oldDock
        ns:RefreshAllBlocks()
    end,
    -- Gold block: forget a character (deleted or renamed) from its tooltip
    function()
        ns:RecordMoney()
        local other = "Oldtoon-" .. GetRealmName()
        ns.sv.chars[other] = { money = 5000, class = "MAGE" }
        ns.sv.goldHistory = ns.sv.goldHistory or {}
        ns.sv.goldHistory[other] = { ["2026-10-15"] = 100 }
        local list = ns:GetOtherCharacters()
        assert(#list == 1 and list[1] == other, "other characters listed")
        assert(ns.ShortCharName(other) == "Oldtoon", "realm suffix removed")
        ns.db.blocks.gold.enabled = true
        ns:RefreshAllBlocks()
        GameTooltip:ClearLines()
        ns.modules.gold.tooltip(GameTooltip, ns.db.blocks.gold)
        ns:OpenQuickMenu("gold")
        ns:AskForgetCharacter(other)
        assert(not ns:ForgetCharacter(ns.charKey), "the current character cannot be forgotten")
        assert(ns:ForgetCharacter(other), "character forgotten")
        assert(not ns.sv.chars[other] and not ns.sv.goldHistory[other], "gold and history removed")
        assert(ns.sv.chars[ns.charKey], "current character kept")
    end,
    -- after a loading screen (boat, portal...), blocks are looked at again a moment later:
    -- data not ready right away (durability...) does not stay "N/A"
    function()
        local real, n = ns.UpdateAll, 0
        ns.UpdateAll = function() n = n + 1 end
        Fire("PLAYER_ENTERING_WORLD")
        local queued = __timers; __timers = {}
        for _, fn in ipairs(queued) do fn() end
        ns.UpdateAll = real
        assert(n >= 3, "blocks updated again after the loading screen: " .. n)
    end,
    -- WoW Forever names characters "First name Surname", unique across all rulesets: the full
    -- name alone is the character's key (GetRealmName() is a label that may change), and
    -- data saved under the earlier keys moves to it, once
    function()
        local realRegional, realUnmod = _G.RegionalUniqueNamesEnabled, _G.UnitNameUnmodified
        _G.RegionalUniqueNamesEnabled = function() return true end
        _G.UnitNameUnmodified = function() return "Ellen", "Kemp" end
        local key = "Ellen Kemp"
        assert(ns.CharacterKey() == key, "full name alone as key: " .. ns.CharacterKey())
        local before = ns.charKey
        local legacy = ns.LegacyCharacterKey() -- "Ellen-Realm"
        local rc = ns.RealmCharacterKey()      -- "Ellen Kemp-Realm"
        assert(rc == "Ellen Kemp-" .. GetRealmName(), "1.0.0-rc key")
        ns.sv.goldHistory = ns.sv.goldHistory or {}
        -- saved by the rc versions, under the current label and under an older label
        ns.sv.charProfiles[rc] = "Mine"
        ns.sv.chars[rc] = { money = 42, class = "MAGE" }
        ns.sv.goldHistory["Ellen Kemp-Classic Beta PvP"] = { ["2026-10-20"] = 5 }
        -- saved before the rc versions (first name only): older, must not win
        ns.sv.charProfiles[legacy] = "Old"
        ns.sv.chars[legacy] = { money = 1, class = "MAGE" }
        -- other characters, saved by the rc versions under the beta label: converted too
        ns.sv.chars["Ellen Kempton-Classic Beta PvE"] = { money = 7, class = "ROGUE" }
        ns.sv.goldHistory["Tobin Harrow-Classic Beta PvE"] = { ["2026-10-22"] = 2 }
        -- a first-name-only key of another character (first test versions): left as it is
        ns.sv.chars["Bob-Classic Beta PvE"] = { money = 3, class = "WARRIOR" }
        ns.charKey = ns.CharacterKey()
        local function Convert()
            ns:MigrateCharacterKey(ns.RealmCharacterKey())
            ns:MigrateCharacterKey(ns.LegacyCharacterKey())
            ns:MigrateFullNameKeys()
        end
        Convert()
        assert(ns.sv.charProfiles[key] == "Mine", "the rc profile wins: " .. tostring(ns.sv.charProfiles[key]))
        assert(ns.sv.chars[key].money == 42, "the rc gold wins")
        assert(ns.sv.goldHistory[key] and ns.sv.goldHistory[key]["2026-10-20"] == 5, "history under an older label moved")
        for _, old in ipairs({ rc, legacy, "Ellen Kemp-Classic Beta PvP" }) do
            assert(ns.sv.charProfiles[old] == nil and ns.sv.chars[old] == nil and ns.sv.goldHistory[old] == nil,
                "old key removed: " .. old)
        end
        assert(ns.sv.chars["Ellen Kempton"].money == 7 and not ns.sv.chars["Ellen Kempton-Classic Beta PvE"],
            "another character's key converted")
        assert(ns.sv.goldHistory["Tobin Harrow"] and not ns.sv.goldHistory["Tobin Harrow-Classic Beta PvE"], "other history converted")
        assert(ns.sv.chars["Bob-Classic Beta PvE"], "a first-name-only key stays")
        assert(ns.ShortCharName("Bob-Classic Beta PvE") == "Bob", "no ruleset label shown")
        -- a second run changes nothing
        local snapshot = ns.sv.charProfiles[key] .. ns.sv.chars[key].money
        Convert()
        assert(ns.sv.charProfiles[key] .. ns.sv.chars[key].money == snapshot, "converting twice changes nothing")
        assert(ns.ShortCharName(key) == "Ellen Kemp", "full name shown as is")
        -- FlareUI's font, read from its AceDB profile under AceDB's key (the full name alone)
        _G.FlareUI2_DB = { profileKeys = { ["Ellen Kemp"] = "Perso" },
            profiles = { Perso = { actionbars = { hotkeyFont = { face = "Friz Quadrata TT", flags = "NONE" } } } } }
        local theme = ns:GetThemeInfo("flareui2")
        assert(theme, "FlareUI style")
        _G.FlareUI2_DB = nil
        ns.sv.charProfiles[key], ns.sv.chars[key], ns.sv.goldHistory[key] = nil, nil, nil
        ns.sv.chars["Ellen Kempton"], ns.sv.chars["Bob-Classic Beta PvE"], ns.sv.goldHistory["Tobin Harrow"] = nil, nil, nil
        ns.charKey = before
        _G.RegionalUniqueNamesEnabled, _G.UnitNameUnmodified = realRegional, realUnmod
    end,
    -- Look tab shortcuts: the Blocks tab on "All blocks", Frame or Text
    function()
        ns:OpenAllBlocks(3)
        ns:OpenAllBlocks(2)
        ns:ToggleOptions()
    end,
    -- changelog sorted by kind since 1.0.0 (older entries: a plain list)
    function()
        local rc6
        for _, e in ipairs(ns.CHANGELOG) do if e.version == "1.0.0-rc6" then rc6 = e end end
        local sections = ns.ChangelogSections(rc6, "fr")
        assert(not sections[1].title and sections[2].title == "Nouveautés", "changelog sections")
        local old = ns.ChangelogSections(ns.CHANGELOG[#ns.CHANGELOG], "en")
        assert(#old == 1 and not old[1].title and #old[1].lines > 0, "old entries: one plain list")
    end,
    -- date block: formats, names from the game's texts, local or server date
    function()
        local t = { year = 2026, month = 10, day = 15, wday = 5 }
        assert(ns.FormatDate(t, "dmy") == "15/10/2026" and ns.FormatDate(t, "dm") == "15/10", "numeric dates")
        assert(ns.FormatDate(t, "mdy") == "10/15/2026" and ns.FormatDate(t, "iso") == "2026-10-15", "other orders")
        local short = ns.FormatDate(t, "short")
        assert(short:find("15", 1, true) and not short:find("{", 1, true), "short date: " .. short)
        _G.WEEKDAY_THURSDAY, _G.FULLDATE_MONTH_OCTOBER = "Thursday", "October"
        assert(ns.FormatDate(t, "long") == "Thursday 15 October", "long date with the game's names")
        _G.WEEKDAY_THURSDAY, _G.FULLDATE_MONTH_OCTOBER = nil, nil
        local cfg = ns.db.blocks.date
        assert(cfg and not cfg.enabled, "new block hidden by default")
        cfg.enabled = true
        for _, fmt in ipairs({ "short", "long", "dmy", "dm", "mdy", "iso" }) do
            cfg.dateFormat = fmt
            for _, source in ipairs({ "local", "server" }) do
                cfg.dateSource = source
                ns:UpdateBlock("date")
            end
        end
        GameTooltip:ClearLines()
        ns.modules.date.tooltip(GameTooltip, cfg)
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
        for _, preset in ipairs({ "rampart" }) do
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
        assert(b.date.enabled and b.date.dock and b.date.dock.to == "time", "date next to the clock")
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
        ns:ResetProfile("rampart")
        b = ns.db.blocks
        -- the mock measures short texts wide (40 px at least, see MockTextWidth): with the
        -- gold amount and its coin icons, the mock screen's bar has no room left
        b.gold.goldFormat, b.gold.goldIcons = "gold", false
        ns:RefreshAllBlocks(); ns:UpdateLayout()
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
        ns:ResetProfile("rampart")
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
    -- in front of or behind Blizzard's frames: the question when blocks cover them,
    -- the temporary switch of placement mode, the Look tab buttons
    function()
        local function RunTimers()
            local queued = __timers; __timers = {}
            for _, fn in ipairs(queued) do fn() end
        end
        -- a ready-made layout keeps the player's style
        ns.db.theme = "grimoire"
        ns:ResetProfile("rampart")
        assert(ns.db.theme == "grimoire", "the style stays when a layout is applied")
        ns.db.theme = nil
        local shown = {}
        local realShow = StaticPopup_Show
        StaticPopup_Show = function(which, a, b, data) table.insert(shown, { which = which, text = a, data = data }) end
        ns:ResetProfile("rampart")
        RunTimers()
        -- the blocks laid along the bottom edge (Blizzard's frames keep their own rectangles)
        local rect = ns.GetRectUI
        ns.GetRectUI = function(self, frame)
            if frame and frame.key and ns.frames[frame.key] == frame then return 0, 0, 1366, 24 end
            return rect(self, frame)
        end
        local labels, covering = ns:GetCoveredFrames()
        assert(#labels >= 1 and next(covering), "the bar covers the action bars and the menu")
        ns.db.layerAsked = nil
        ns:AskLayer()
        local ask = shown[#shown]
        assert(ask and ask.which == "TESSERA_LAYER", "question asked")
        StaticPopupDialogs.TESSERA_LAYER.OnCancel(nil, ask.data, "clicked")
        local root = next(ask.data)
        assert(ns.db.blocks[root].strata == "BACKGROUND", "blocks behind")
        local count = #shown
        ns:AskLayer()
        assert(#shown == count, "asked once for the same situation")
        -- locking without touching the switch: no question
        count = #shown
        ns:SetLocked(false, true)
        ns:SetLocked(true, true)
        RunTimers()
        assert(#shown == count, "no question without the switch")
        -- placement mode: a temporary switch, nothing saved; locking ends it
        ns:SetLocked(false, true)
        ns:ToggleTempLayer()
        assert(ns.tempStrata == "HIGH" and ns.db.blocks[root].strata == "BACKGROUND", "temporary, not saved")
        -- locking after the switch: the player is asked which layer to keep (even for the
        -- same situation), the switch stays on screen until the answer
        count = #shown
        ns:SetLocked(true, true)
        RunTimers()
        assert(#shown == count + 1 and shown[#shown].which == "TESSERA_LAYER", "asked after the switch")
        assert(ns.tempStrata, "the switch stays until the answer")
        StaticPopupDialogs.TESSERA_LAYER.OnAccept(nil, shown[#shown].data)
        assert(not ns.tempStrata and ns.db.blocks[root].strata == "HIGH", "kept in front")
        -- nothing covered: the question is about every block
        local covered = ns.GetCoveredFrames
        ns.GetCoveredFrames = function() return {}, {}, "" end
        ns:ToggleTempLayer()
        ns:OnBlocksLocked()
        RunTimers()
        assert(shown[#shown].which == "TESSERA_LAYER_ALL", "asked for every block")
        StaticPopupDialogs.TESSERA_LAYER_ALL.OnCancel(nil, nil, "clicked")
        assert(not ns.tempStrata and ns.db.blocks.gold.strata == "BACKGROUND", "every block behind")
        ns.GetCoveredFrames = covered
        -- the button under Blizzard's Edit Mode window: same switch, the question on closing
        ns:ShowEditModeLayerButton(true)
        TesseraEditModeLayerButton:GetScript("OnEnter")(TesseraEditModeLayerButton)
        TesseraEditModeLayerButton:GetScript("OnClick")(TesseraEditModeLayerButton)
        assert(ns.tempStrata, "switched from Edit Mode")
        ns:OnBlocksLocked()
        RunTimers()
        assert(shown[#shown].which:find("TESSERA_LAYER"), "asked when Edit Mode closes")
        StaticPopupDialogs.TESSERA_LAYER.OnAccept(nil, shown[#shown].data)
        ns:ShowEditModeLayerButton(false)
        -- Look tab: every block in front
        ns:SetLayer("front")
        assert(ns.db.blocks[root].strata == "HIGH" and ns.db.groupDefaults.strata == "HIGH", "all blocks in front")
        StaticPopupDialogs.TESSERA_LAYER.OnAccept(nil, ask.data)
        ns.GetRectUI = rect
        -- an Edit Mode copy left by an older test version, active: back to the player's layout
        local copy = { layoutName = "Moderne (Tessera 1)", layoutType = 1, systems = EMSystems() }
        EM.layouts = { activeLayout = 4, layouts = { copy } }
        ns.sv.editModeCopies = { [copy.layoutName] = { layoutType = 1, fingerprint = ns.EditModeFingerprint(copy) } }
        ns.sv.editModeOriginal = { name = "Moderne", layoutType = 0 }
        assert(ns:GetEditModeStatus():find("Tessera copy"), "bug report knows the copy")
        ns:CheckEditModeCopies()
        assert(shown[#shown].which == "TESSERA_EDITMODE_LEGACY", "offered to go back")
        ns:LeaveEditModeCopy()
        RunTimers()
        assert(EM.layouts.activeLayout == 1 and #EM.layouts.layouts == 0, "back to Moderne, copy deleted")
        assert(not ns.sv.editModeCopies and not ns.sv.editModeOriginal, "nothing left to ask")
        -- a copy not in use, and a layout of the player: only the copy goes, silently
        local mine = { layoutName = "Mine", layoutType = 1, systems = EMSystems() }
        copy = { layoutName = "Classique (Tessera 1)", layoutType = 1, systems = EMSystems() }
        EM.layouts = { activeLayout = 4, layouts = { mine, copy } }
        ns.sv.editModeCopies = { [copy.layoutName] = { layoutType = 1, fingerprint = ns.EditModeFingerprint(copy) } }
        ns:CheckEditModeCopies()
        assert(#EM.layouts.layouts == 1 and EM.layouts.layouts[1].layoutName == "Mine", "the player's layout is kept")
        assert(not ns.sv.editModeCopies, "copies forgotten")
        EM.layouts = { activeLayout = 1, layouts = {} }
        StaticPopup_Show = realShow
        ns:ResetProfile("top")
        RunTimers()
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
        -- a layout being tried is saved aside: a /reload or a crash gives the player's back at login
        ns:ResetProfile("left")
        ns.db.blocks.time.width = 124
        local mine = ns.profileName
        ns:StartTutorial()
        TesseraTutorial.next:GetScript("OnClick")()
        TesseraTutorial.layouts.nextLayout:GetScript("OnClick")()
        assert(type(ns.sv.tourBackup) == "table" and ns.sv.tourBackup.profile == mine, "tried layout: backup saved")
        ns:RestoreTourBackup() -- what the next login does
        assert(ns.sv.profiles[mine].blocks.time.width == 124 and not ns.sv.tourBackup, "backup given back at login")
        TesseraTutorial:Hide()
        -- the profile changes during the step (a dungeon's profile): the backup goes back to its own profile
        ns:CreateProfile("Mock tour other")
        ns:SetProfile(mine)
        ns:StartTutorial()
        TesseraTutorial.next:GetScript("OnClick")()
        TesseraTutorial.layouts.nextLayout:GetScript("OnClick")()
        ns:SetProfile("Mock tour other")
        TesseraTutorial:Hide()
        TesseraTutorial:GetScript("OnHide")(TesseraTutorial) -- (the mock's Hide runs no script)
        assert(ns.sv.profiles[mine].blocks.time.width == 124, "the player's layout goes back to its own profile")
        assert(ns.sv.profiles["Mock tour other"].blocks.time.width ~= 124, "another profile is not overwritten")
        ns:SetProfile(mine)
        ns:DeleteProfile("Mock tour other")
        ns:ResetProfile("top")
    end,
    -- Ctrl + Z gives back a group's scale and frozen state (replace, merge)
    function()
        ns:ResetProfile("top")
        local root = ns:GetRoot("bags")
        ns.db.blocks[root].frozen, ns.db.blocks[root].scale = true, 1.4
        ns:ReplaceBlock(root, "zone")
        ns:Undo()
        assert(ns.db.blocks[root].frozen == true, "undo: frozen state back")
        assert(ns.db.blocks[root].scale == 1.4, "undo: group scale back")
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
        ns:ResetProfile("rampart")
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
    -- Blizzard modern (silver) and Blizzard Forever (gold): the same color on both games, and a
    -- WoW Forever profile that had Blizzard modern (gold there) keeps its look, once
    function()
        local realRegional = _G.RegionalUniqueNamesEnabled
        _G.RegionalUniqueNamesEnabled = function() return true end
        local cfg = {}
        ns:ApplyThemeToCfg(cfg, "blizzardModern")
        assert(cfg.border == "modernTooltipGrey", "Forever: Blizzard modern uses the grey frame")
        ns:ApplyThemeToCfg(cfg, "blizzardForever")
        assert(cfg.border == "modernTooltip", "Forever: Blizzard Forever uses the game's gold frame")
        local p = { theme = "blizzardModern" }
        ns:SplitBlizzardModernTheme(p)
        assert(p.theme == "blizzardForever", "Forever: a Blizzard modern profile keeps its gold look")
        p.theme = "blizzardModern"
        ns:SplitBlizzardModernTheme(p)
        assert(p.theme == "blizzardModern", "a later choice of Blizzard modern stays")
        local sq = { theme = "modernSquare" }
        ns:SplitBlizzardModernTheme(sq)
        assert(sq.theme == "foreverSquare", "Blizzard modern square keeps its gold look")
        _G.RegionalUniqueNamesEnabled = realRegional
        local q = { theme = "blizzardModern" }
        ns:SplitBlizzardModernTheme(q)
        assert(q.theme == "blizzardModern", "Retail: Blizzard modern stays")
        ns:ApplyThemeToCfg(cfg, "blizzardModern")
        assert(cfg.border == "modernTooltip", "Retail: Blizzard modern uses the game's silver frame")
        ns:ApplyThemeToCfg(cfg, "blizzardForever")
        assert(cfg.borderColor.b < 0.5, "Retail: Blizzard Forever tints the frame gold")
    end,
    -- block width: the horizontal offset of inline icons (coin icons) is counted
    function()
        local fs = { GetStringWidth = function() return 40 end }
        assert(ns.TextWidth(fs, "plain") == 40, "plain text width")
        local w = ns.TextWidth(fs, "5|Ta:12:12:2:0|t 54|Tb:12:12:2:0|t 27|Tc:12:12:2:0|t")
        assert(w >= 42, "three 12 px coin icons with a 2 px offset count 42 px: " .. w)
        assert(ns.modules.bags.defaults.bagsFormat == "usedTotal", "bags: used / total by default")
    end,
    -- streamer mode: the gold block and its tooltip hide the amounts, the block shows the state
    function()
        local gold = ns.modules.gold
        assert(gold.update({}) ~= ns.HIDDEN, "gold shown before streamer mode")
        Tessera_ToggleStreamer()
        assert(ns:IsStreamer(), "the key binding turns streamer mode on")
        assert(gold.update({}) == ns.HIDDEN, "streamer mode hides the gold")
        assert(gold.chatText() == ns.HIDDEN, "streamer mode hides the gold copied to chat")
        assert(ns.modules.streamer.update() == ns.L.STREAMER_ON, "the streamer block shows the mode")
        assert(not ns.modules.streamer.isEmpty(), "the streamer block is not empty while on")
        ns.modules.streamer.onClick(nil, "LeftButton")
        assert(not ns:IsStreamer(), "a click on the streamer block turns the mode off")
        assert(ns.modules.streamer.isEmpty(), "the streamer block is empty while off")
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
