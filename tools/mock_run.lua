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
-- (MOCK_TEXT_SCALE = 2: every text twice as big, as the options window must allow)
function MockTextWidth(text)
    local n = #((text or ""):gsub("|T.-|t", "##"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    return (n > 40 and 6 * n or 40) * (MOCK_TEXT_SCALE or 1)
end
local methods = {
    SetScript = function(self, name, fn) self.__scripts[name] = fn end,
    GetScript = function(self, name) return self.__scripts[name] end,
    HookScript = function(self, name, fn) local old = self.__scripts[name]; self.__scripts[name] = function(...) if old then old(...) end fn(...) end end,
    RegisterEvent = function(self, e) self.__events[e] = true; frames[self] = true end,
    RegisterUnitEvent = function(self, e) self.__events[e] = true; frames[self] = true end,
    UnregisterEvent = function(self, e) self.__events[e] = nil end,
    IsEventRegistered = function(self, e) return self.__events[e] end,
    Show = function(self) local was = self.__shown; self.__shown = true; if not was and self.__scripts and self.__scripts.OnShow then self.__scripts.OnShow(self) end end, Hide = function(self) local was = self.__shown; self.__shown = false; if was and self.__scripts and self.__scripts.OnHide then self.__scripts.OnHide(self) end end,
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
    CreateFontString = function(self)
        local fs = NewObject("FontString")
        self.__fontStrings = self.__fontStrings or {}
        table.insert(self.__fontStrings, fs)
        return fs
    end,
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
            lines = lines + math.max(1, math.ceil(#para * 5.6 * (MOCK_TEXT_SCALE or 1) / math.max(40, self.__w or 250)))
        end
        return 13 * lines * (MOCK_TEXT_SCALE or 1)
    end,
    SetFont = function() return true end,
    GetText = function(self) return self.__text or "" end, SetText = function(self, t) self.__text = t end,
    NumLines = function() return 3 end,
    SetAttribute = function(self, k, v) self.__attrs[k] = v end,
    GetAttribute = function(self, k) return self.__attrs[k] end,
    IsMouseOver = function() return false end,
    GetChecked = function() return false end,
    HasFocus = function() return false end,
    GetAtlas = function() return nil end, GetTexture = function(self) return self.__texture or "x" end,
    SetTexture = function(self, file) self.__texture = file end,
    SetClampedToScreen = function(self, on) self.__clamped = on end,
    SetAlpha = function(self, a) self.__alpha = a end, GetAlpha = function(self) return self.__alpha or 1 end,
    SetClampRectInsets = function(self, l, r, t, b) self.__insets = { l, r, t, b } end,
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
-- a font object (the 2.0 skin makes its button fonts with it)
CreateFont = function(name)
    local f = NewObject("Font"); if name then _G[name] = f end
    return f
end
-- MOCK_FRAMES: every frame made, so a test can find an options widget by its text
MOCK_FRAMES = {}
CreateFrame = function(kind, name, _, template)
    local f = NewObject(kind); f.__name = name; if name then _G[name] = f end
    table.insert(MOCK_FRAMES, f)
    -- the game's list with ◄ ► arrows (options rows, 1.3): its pieces
    if template == "SettingsDropdownWithButtonsTemplate" then
        f.Dropdown = CreateFrame("DropdownButton")
        f.IncrementButton, f.DecrementButton = CreateFrame("Button"), CreateFrame("Button")
        f.Label = f:CreateFontString()
        f.__arrows = true
    end
    return f
end
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
GetGuildInfo = GetGuildInfo or function() return nil end
GetNumGuildMembers = GetNumGuildMembers or function() return 0, 0 end
GetGuildRosterInfo = GetGuildRosterInfo or function() end
GetRealmName = function() return "Realm" end
UnitFactionGroup = function() return "Alliance", "Alliance" end
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

-- Blizzard's micro menu buttons (Legacy still locked)
local function MicroButton(enabled)
    return { IsEnabled = function() return enabled end, disabledTooltip = not enabled and "Available at level 10" or nil,
             GetNormalTexture = function() return { GetAtlas = function() return nil end } end }
end
for _, name in ipairs({ "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "ProfessionMicroButton",
                        "QuestLogMicroButton", "GuildMicroButton", "LFDMicroButton", "EJMicroButton",
                        "CollectionsMicroButton", "MainMenuMicroButton" }) do _G[name] = MicroButton(true) end
LegacyMicroButton = MicroButton(false)
-- blocks registered only when the client has their functions (so the doc check sees them)
GetAverageItemLevel = function() return 52.4, 50.1 end
C_DateAndTime = setmetatable({ GetSecondsUntilDailyReset = function() return 3600 end,
    GetSecondsUntilWeeklyReset = function() return 90000 end }, { __index = C_DateAndTime or {} })
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
-- long buffs: Well Fed (30 min, 20 left) and a short buff that is not counted
C_UnitAuras.GetBuffDataByIndex = function(_, i)
    return ({ { name = "Well Fed", icon = 136000, duration = 1800, expirationTime = 2200 },
              { name = "Sprint", icon = 132307, duration = 15, expirationTime = 1010 } })[i]
end
-- minimap tracking (Find Herbs on), hunter pet (happy), a poison on the main hand
C_Minimap = { GetNumTrackingTypes = function() return 3 end, GetTrackingInfo = function(i)
    return ({ { name = "Flight Master", texture = 1, active = true, type = "other", subType = 2 },
              { name = "Find Herbs", texture = 133939, active = true, type = "spell", subType = 0 },
              { name = "Find Minerals", texture = 136025, active = false, type = "spell", subType = 0 } })[i]
end }
HasPetUI = function() return true, true end
-- 1.1.0: damage meter (last fight: 1200 damage in 60 s), realm rules, weather, a ghost
C_DamageMeter = { GetCombatSessionSourceFromType = function() return { totalAmount = 1200, maxAmount = 300 } end,
                  GetSessionDurationSeconds = function() return 60 end }
C_GameRules = { IsHardcoreActive = function() return false end, IsSelfFoundAllowed = function() return false end }
UnitIsGhost = function() return false end
C_Container.GetContainerItemDurability = function(bag, slot) if bag == 0 and slot == 1 then return 30, 60 end end
C_PetInfo = { GetPetHappiness = function() return 3, 125, 20 end, GetPetLoyalty = function() return "Loyalty level 3" end }
C_Item = C_Item or {}
C_Item.GetWeaponEnchantInfo = function(slot)
    if slot == 0 then return { { hasEnchant = true, enchantType = 0, timeLeft = 1500000, charges = 40 } } end
    return {}
end
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
        -- TESSERA_EARLY=1: lists every text read while the files load (before the saved language is
        -- applied, Locales/Language.lua); such a text would stay in the language of the game
        if line:match("Language%.lua$") and os.getenv("TESSERA_EARLY") then
            local real = ns.L
            ns.L = setmetatable({}, {
                __index = function(_, key)
                    if ns.__loading ~= false then
                        local info = debug.getinfo(2, "Sl")
                        print(("EARLY READ %s:%d %s"):format(info.short_src:gsub("^.*/", ""), info.currentline, tostring(key)))
                    end
                    return real[key]
                end,
                __newindex = function(_, key, value) real[key] = value end,
            })
        end
    end
end
ns.__loading = false
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
for i = 1, ns.OPTIONS_PAGE_COUNT do local ok2, err2 = xpcall(function() ns.ShowOptionsPage(i) end, debug.traceback) if not ok2 then print("PAGE ERROR " .. i .. ": " .. tostring(err2)) end end
-- every options page must fit in the window (pages start 98 px below its top)
-- (every page keeps the 40 px of the bottom buttons free: nothing may ever cover them)
for slot, n in pairs(ns.optionStacks or {}) do
    if n > 1 then print("STEP ERROR: " .. n .. " option stacks share one column (" .. slot .. "): they overlap") end
end
for title in pairs(ns.optionsWithoutTip or {}) do print("STEP ERROR: option without a tooltip: " .. title) end
local pageRoom = TesseraOptions:GetHeight() + ns.OPTIONS_PAGE_TOP - 12 - 40
if -(ns.optionsLowestY or 0) > pageRoom then
    print("STEP ERROR: options page too tall: " .. -ns.optionsLowestY .. " px for " .. pageRoom)
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
    -- a closed options window is not refreshed (1.5.1): it brings itself up to date when it opens
    function()
        ns:OpenOptions()
        local panel = _G["TesseraOptions"]
        local widgets = ns.OptionsTools.widgets
        assert(#widgets > 0, "the options window has widgets")
        local refreshed = 0
        local probe = { Refresh = function() refreshed = refreshed + 1 end }
        widgets[#widgets + 1] = probe
        ns:RefreshOptions()
        assert(refreshed == 1, "an open window is refreshed")
        panel:Hide()
        refreshed = 0
        ns:RefreshOptions()
        ns:RefreshOptions()
        assert(refreshed == 0, "a closed window is not refreshed")
        ns:OpenOptions()
        assert(refreshed >= 1, "the window is brought up to date when it opens")
        local after = refreshed
        panel:Hide(); panel:Show()
        assert(refreshed == after, "nothing changed while it was closed: no extra refresh")
        table.remove(widgets)
        panel:Hide()
    end,
    -- GetEffectiveDock keeps its answers (1.5.1: no table in the usual case)
    function()
        local function Reference(key) -- the version before 1.5.1
            local target, side = ns:GetDockTarget(key)
            local seen = { [key] = true }
            while target and not seen[target] do
                local t = ns.frames[target]
                if not t or t:IsShown() or ns:HasPlace(target) then break end
                seen[target] = true
                local nextTarget, nextSide = ns:GetDockTarget(target)
                if not nextTarget or nextSide ~= side then break end
                target = nextTarget
            end
            return target, side
        end
        local docked, hiddenCase = 0, 0
        for _, key in ipairs(ns:GetBlockKeys()) do
            local t1, s1 = ns:GetEffectiveDock(key)
            local t2, s2 = Reference(key)
            assert(t1 == t2 and s1 == s2, "GetEffectiveDock differs from the old answer for " .. key)
            if ns:GetDockTarget(key) then docked = docked + 1 end
        end
        -- a hidden target that no longer keeps its place: the walk goes on to the block before it
        for _, key in ipairs(ns:GetBlockKeys()) do
            local target = ns:GetDockTarget(key)
            local f = target and ns.frames[target]
            if f and ns.db.blocks[target] then
                local wasShown, wasEnabled = f:IsShown(), ns.db.blocks[target].enabled
                f:Hide(); ns.db.blocks[target].enabled = false
                local t1, s1 = ns:GetEffectiveDock(key)
                local t2, s2 = Reference(key)
                assert(t1 == t2 and s1 == s2, "GetEffectiveDock differs for a hidden target of " .. key)
                hiddenCase = hiddenCase + 1
                f:SetShown(wasShown); ns.db.blocks[target].enabled = wasEnabled
            end
        end
        assert(docked == 0 or hiddenCase > 0, "the hidden-target case was not exercised")
    end,
    -- undo steps share what did not change (1.5.1): same behaviour, far less memory
    function()
        local keys = ns:GetBlockKeys()
        local k1, k2 = keys[1], keys[2]
        local c1, c2 = ns.db.blocks[k1], ns.db.blocks[k2]
        c1.point = { "TOPLEFT", "TOPLEFT", 10, -10 }
        ns.undoStack = {}
        ns:PushUndo(true)
        ns:PushUndo(true)
        local a, b = ns.undoStack[1], ns.undoStack[2]
        assert(a ~= b, "undo steps are distinct tables")
        assert(rawequal(a[k1], b[k1]), "unchanged block: the step shares its entry")
        local oldSize, oldPoint = c1.fontSize, c1.point
        c1.fontSize = (oldSize or 12) + 3
        c1.point = { "TOPLEFT", "TOPLEFT", 99, -99 }
        ns:PushUndo(true)
        local c = ns.undoStack[3]
        assert(not rawequal(b[k1], c[k1]), "changed block: a new entry")
        assert(rawequal(b[k2], c[k2]), "other block still shared")
        assert(c[k1].style.fontSize == oldSize + 3 or c[k1].style.fontSize == (oldSize or 12) + 3, "new style value kept")
        assert(b[k1].style.fontSize == oldSize, "the older step still has the old value")
        assert(rawequal(b[k1].point, a[k1].point), "unchanged position table shared")
        -- Undo puts the values of the step back (and copies them: the steps are never changed)
        c1.fontSize = 40
        ns:Undo()
        assert(c1.fontSize == oldSize + 3 and c1.point[3] == 99, "undo restores the state of the last step")
        ns:Undo()
        assert(c1.fontSize == oldSize, "undo restores the old style value")
        assert(c1.point[3] == 10, "undo restores the old position")
        assert(not rawequal(c1.point, b[k1].point), "the live settings are a copy, not the step's table")
        c1.point[3] = 777
        assert(b[k1].point[3] == 10, "changing live settings leaves the kept step alone")
        -- 30 full steps stay small
        ns.undoStack = {}
        collectgarbage("collect"); local before = collectgarbage("count")
        for i = 1, 30 do ns:PushUndo(true) end
        collectgarbage("collect")
        local kb = collectgarbage("count") - before
        assert(kb < 400, ("30 undo steps of an unchanged profile take %d KB (expected under 400)"):format(kb))
        ns.undoStack = {}
        ns:PushUndo()
        ns:Undo()
        c1.point, c1.fontSize = oldPoint, oldSize
    end,
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
    -- 1.3, "Remove" instead of "Hide": a block that is turned off leaves its group in the
    -- saved data; profiles and texts made before 1.3 are tidied, once
    function()
        local function Blocks(spec)
            local t = {}
            for k, v in pairs(spec) do t[k] = v end
            return t
        end
        local function R(to) return { to = to, side = "RIGHT" } end
        -- middle of a row: what followed it follows what it followed
        local b = Blocks({ a = { enabled = true, point = { "CENTER", "CENTER", 0, 0 }, scale = 1.2 },
            b = { enabled = true, dock = R("a") }, c = { enabled = true, dock = R("b") } })
        assert(ns.LeaveGroupData(b, "b") and b.c.dock.to == "a" and not b.b.dock, "middle block: row not closed")
        assert(not ns.LeaveGroupData(b, "b"), "leaving twice changes nothing")
        -- head of a group: the first block docked to it takes the place and the group settings
        assert(ns.LeaveGroupData(b, "a"))
        assert(not b.c.dock and b.c.point[1] == "CENTER" and b.c.scale == 1.2, "head: heir did not take the place")
        assert(b.a.point == nil and b.a.scale == nil, "head: the removed block kept a place")
        -- elbow: c hangs under b; b leaves, c takes b's seat (the group keeps its shape)
        b = Blocks({ a = { enabled = true, point = { "CENTER", "CENTER", 0, 0 } }, b = { enabled = true, dock = R("a") },
            c = { enabled = true, dock = { to = "b", side = "BOTTOM" } }, d = { enabled = true, dock = { to = "a", side = "BOTTOM" } } })
        ns.LeaveGroupData(b, "b")
        assert(b.c.dock.to == "a" and b.c.dock.side == "RIGHT" and b.d.dock.to == "a", "elbow: heir did not take the seat")
        -- 2 x 2 square (p, a under p, b right of a, c above b): b leaves, c must not land on p
        b = Blocks({ p = { enabled = true, point = { "CENTER", "CENTER", 0, 0 } }, a = { enabled = true, dock = { to = "p", side = "BOTTOM" } },
            b = { enabled = true, dock = R("a") }, c = { enabled = true, dock = { to = "b", side = "TOP" } } })
        ns.LeaveGroupData(b, "b")
        assert(b.c.dock.to == "a" and b.c.dock.side == "RIGHT", "square: a block landed on another one")
        -- the block that carried on the row is the heir; the other one follows it
        b = Blocks({ a = { enabled = true, point = { "CENTER", "CENTER", 0, 0 } }, b = { enabled = true, dock = R("a") },
            c = { enabled = true, dock = { to = "b", side = "BOTTOM" } }, d = { enabled = true, dock = R("b") } })
        ns.LeaveGroupData(b, "b")
        assert(b.d.dock.to == "a" and b.d.dock.side == "RIGHT" and b.c.dock.to == "d" and b.c.dock.side == "BOTTOM", "row heir")
        -- damaged data, a loop through hidden blocks: no block hangs on itself, and a
        -- second pass changes nothing
        b = Blocks({ a = { enabled = true, dock = { to = "b", side = "BOTTOM" } }, b = { enabled = false, dock = { to = "c", side = "BOTTOM" } },
            c = { enabled = false, anchor = { below = "b" }, point = { "TOP", "TOP", 0, 0 } } })
        ns.TidyRemovedBlocks(b)
        assert(b.a.point or b.a.dock or b.a.anchor, "loop: the visible block lost its place")
        assert(not (b.a.anchor and b.a.anchor.below == "a"), "loop: a block hangs on itself")
        local snap = ns.DeepCopy(b.a)
        assert(not ns.TidyRemovedBlocks(b), "loop: the second pass changed something")
        assert((snap.point and b.a.point and snap.point[1] == b.a.point[1]) or (snap.dock and b.a.dock) or (snap.anchor and b.a.anchor),
            "loop: the visible block lost its place the second time")
        -- a lone bar block with a second row hanging on it: the row takes its place
        b = Blocks({ a = { enabled = true, anchor = { top = true, fill = true } },
            r = { enabled = true, anchor = { below = "a", fill = true, gap = 0 } }, s = { enabled = true, dock = R("r") } })
        ns.LeaveGroupData(b, "a")
        assert(b.r.anchor and b.r.anchor.top and not b.r.anchor.below and b.s.dock.to == "r", "hanging row lost")
        -- old profile: hidden blocks inside a row and at its head, damaged entries
        b = Blocks({ h = { enabled = false, point = { "TOP", "TOP", 0, -5 }, frozen = true },
            x = { enabled = true, dock = R("h") }, y = { enabled = false, dock = R("x") }, z = { enabled = true, dock = R("y") },
            lone = { enabled = false, point = { "CENTER", "CENTER", 9, 9 } }, odd = { enabled = false, dock = "bad", anchor = 3 },
            self = { enabled = false, dock = R("self") }, far = { enabled = true, dock = R("nowhere") }, junk = 7 })
        assert(ns.TidyRemovedBlocks(b), "old profile not tidied")
        assert(not b.x.dock and b.x.point[1] == "TOP" and b.x.frozen == true, "old profile: head not replaced")
        assert(b.z.dock.to == "x", "old profile: hidden block still in the row")
        for _, k in ipairs({ "h", "y", "lone", "odd", "self" }) do
            assert(b[k].point == nil and b[k].dock == nil and b[k].anchor == nil, k .. " kept a place")
            assert(b[k].enabled == false, k .. " changed state")
        end
        assert(b.far.dock.to == "nowhere" and b.junk == 7, "tidy touched something else")
        assert(not ns.TidyRemovedBlocks(b), "tidy must do nothing the second time")
        assert(not ns.TidyRemovedBlocks(nil) and not ns.TidyRemovedBlocks({}), "tidy on nothing")

        -- in the game: remove a block in the middle of a bar, then put it back
        ns:ResetProfile("top")
        b = ns.db.blocks
        for _, k in ipairs({ "gold", "bags", "durability", "fps" }) do
            b[k].enabled, b[k].anchor, b[k].point = true, nil, nil
        end
        b.gold.dock, b.gold.point = nil, { "CENTER", "CENTER", 0, 0 }
        b.bags.dock, b.durability.dock, b.fps.dock = R("gold"), R("bags"), R("durability")
        b.bags.fontSize = 17
        ns:RefreshAllBlocks()
        ns:PushUndo()
        ns:HideBlock("bags")
        assert(b.bags.enabled == false and not b.bags.dock and b.bags.fontSize == 17, "removed block: place kept or look lost")
        assert(b.durability.dock.to == "gold" and b.fps.dock.to == "durability", "bar not closed after a removal")
        assert(not ns.frames.bags:IsShown(), "removed block still on screen")
        ns:Undo()
        assert(b.bags.enabled == true and b.bags.dock.to == "gold" and b.durability.dock.to == "bags", "Ctrl + Z after a removal")
        -- the head of the bar: the next block heads it, at the same spot
        ns:PushUndo()
        ns:HideBlock("gold")
        assert(not b.bags.dock and b.bags.point and b.bags.point[1] == "CENTER", "head removed: bar lost its place")
        ns:Undo()
        -- a block that comes back from the options keeps its own look, and appears with no dock
        ns:HideBlock("bags")
        ns:SetBlocksOnScreen({ "bags" }, true)
        assert(b.bags.enabled == true and b.bags.fontSize == 17 and not b.bags.dock and b.bags.point, "block back: look or place wrong")
        -- a block that was never on screen takes the look of the blocks already there
        b.zone.enabled, b.zone.point, b.zone.dock, b.zone.anchor, b.zone.keepLook = false, nil, nil, nil, false
        b.gold.fontSize = 19
        ns:SetBlocksOnScreen({ "zone" }, true)
        assert(b.zone.fontSize == b[ns:GetReferenceBlock("zone")].fontSize, "new block: reference look not taken")
        ns:SetBlocksOnScreen({ "zone", "bags" }, false)
        assert(not b.zone.enabled and not b.bags.enabled and b.zone.keepLook and b.bags.keepLook, "several blocks removed")
        ns:Undo()
        assert(b.bags.enabled == true, "Ctrl + Z after removing several blocks")
        b.bags.point, b.bags.dock = nil, R("gold")
        b.durability.dock = R("bags")
        ns:RefreshAllBlocks()
        -- the "hide" click action can be undone too
        ns:RunClickAction("bags", "hide")
        assert(b.bags.enabled == false and b.durability.dock.to == "gold", "click action: block not removed")
        ns:Undo()
        assert(b.bags.enabled == true and b.bags.dock and b.bags.dock.to == "gold", "click action: Ctrl + Z")
        -- the Gryphons layout keeps its shape when an inner block leaves
        ns:ResetProfile("gryphons")
        b = ns.db.blocks
        local shape = {}
        for k, c in pairs(b) do
            if c.dock and c.dock.to == "comprehension" then shape[k] = true end
        end
        local seat = ns.DeepCopy(b.comprehension.dock)
        if seat and next(shape) then
            ns:PushUndo()
            ns:HideBlock("comprehension")
            local heirs = 0
            for k in pairs(shape) do
                if b[k].dock.to == seat.to and b[k].dock.side == seat.side then heirs = heirs + 1 end
            end
            assert(heirs == 1, "gryphons: no block took the seat of the one that left")
            ns:Undo()
        end
        ns:ResetProfile("top")
        b = ns.db.blocks
        for _, k in ipairs({ "gold", "bags", "durability", "fps" }) do
            b[k].enabled, b[k].anchor, b[k].point = true, nil, nil
        end
        b.gold.dock, b.gold.point = nil, { "CENTER", "CENTER", 0, 0 }
        b.bags.dock, b.durability.dock, b.fps.dock = R("gold"), R("bags"), R("durability")
        ns:RefreshAllBlocks()
        -- prepared again (login, profile change): hidden blocks of an old profile leave their rows
        b.bags.enabled = false
        ns:PrepareProfile(ns.db)
        assert(not b.bags.dock and b.durability.dock.to == "gold", "old profile not tidied when it loads")
        local before = ns:ExportProfile()
        ns:PrepareProfile(ns.db)
        assert(before == ns:ExportProfile(), "a profile changes when it is prepared twice")
        -- a text exported before 1.3 with a hidden block in a row
        local old = ns.DeepCopy(ns.db)
        old.blocks.bags.dock, old.blocks.durability.dock = R("gold"), R("bags")
        local clean = ns:SanitizeProfile(old)
        assert(not clean.blocks.bags.dock and clean.blocks.durability.dock.to == "gold", "old text not tidied on import")
        -- every ready-made layout leaves no hidden block with a place
        for _, preset in ipairs(ns.PRESETS) do
            ns:ResetProfile(preset)
            assert(not ns.TidyRemovedBlocks(ns.DeepCopy(ns.db.blocks)), "layout " .. preset .. " leaves a hidden block with a place")
        end
        ns:ResetProfile("top")
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
        ns.ShowBlockSub(5)
        ns.optionsLowestY = 0
        ns:RefreshOptions()
        local limit = TesseraOptions:GetHeight() + ns.OPTIONS_PAGE_TOP - 12 - 40 -- the bottom buttons take 40 px
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
        for i = 1, ns.OPTIONS_PAGE_COUNT do ns.ShowOptionsPage(i) end
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
        -- "Keep this style": the layout comes back, with the style the demo showed
        local themeBefore = ns.db.theme
        ns:StartDemo()
        b.nextStyle:GetScript("OnClick")(b.nextStyle)
        local shownTheme = ns.demoTheme
        ns:StopDemo(true)
        assert(ns.db.theme == shownTheme and ns.db.blocks.time.width == 123, "demo style kept, layout back")
        ns.db.theme = themeBefore
        ns:ApplyTheme(themeBefore)
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
    -- 2.0 styles (2.0.0): rounded frame in 9 pieces, fill squared at joins, ornate separators,
    -- "1 pixel" corners, their fonts, and an old block without the new fields
    function()
        for _, key in ipairs({ "hdGold", "hdRune", "hdSilver", "hdBronze" }) do
            assert(ns:ApplyTheme(key), key .. " refused")
            local cfg, f = ns.db.blocks.gold, ns.frames.gold
            assert(ns:FindMedia("border", cfg.border).hd, key .. ": 2.0 border")
            assert(cfg.separatorStyle ~= "line" and cfg.edgeShape == "round", key .. ": ornament, round corners")
            ns:ApplyStyle("gold")
            assert(f.tesseraHD and f.tesseraHDFill and f.TopLeftCorner and f.nineSliceInfo, key .. ": hd pieces")
            assert(ns:FindMedia("font", cfg.font).key == cfg.font, key .. ": its font exists")
        end
        -- "1 pixel": a plain line, no rounded pieces left
        ns:SetAllBlocksField("edgeShape", "pixel")
        assert(ns:AllBlocksField("edgeShape") == "pixel", "corners for all blocks")
        local f = ns.frames.gold
        assert(not f.tesseraHD and f.skinKind == "backdrop" and not f.nineSliceInfo, "1 pixel corners use the plain line")
        ns:SetAllBlocksField("edgeShape", "round")
        assert(ns.frames.gold.tesseraHD, "rounded again")
        -- the style export carries the new fields; an unknown corner value draws rounded
        -- a client whose names the style's font cannot draw gets the game's font
        local locale = GetLocale
        GetLocale = function() return "ruRU" end
        assert(ns:ApplyTheme("hdRune") and ns.db.blocks.gold.font == "friz", "Cinzel has no Cyrillic")
        assert(ns:ApplyTheme("hdSilver") and ns.db.blocks.gold.font == "inter", "Inter draws Cyrillic")
        GetLocale = function() return "koKR" end
        assert(ns:ApplyTheme("hdSilver") and ns.db.blocks.gold.font == "friz", "Inter has no Hangul")
        GetLocale = locale
        assert(ns:ApplyTheme("hdBronze"))
        local styleKeys = {}
        for _, k in ipairs(ns.STYLE_KEYS) do styleKeys[k] = true end
        assert(styleKeys.edgeShape and styleKeys.separatorStyle, "style keys")
        -- a locked block keeps its corners when the Look tab changes them for all
        ns.db.blocks.bags.styleLocked = true
        ns:SetAllBlocksField("edgeShape", "pixel", true)
        assert(ns.db.blocks.bags.edgeShape == "round" and ns.db.blocks.gold.edgeShape == "pixel", "locked corners")
        ns.db.blocks.bags.styleLocked = nil
        ns:SetAllBlocksField("edgeShape", "round", true)
        -- a narrow block: corners never larger than half its width (the fill bands would overlap)
        ns.db.blocks.gold.width, ns.db.blocks.gold.autoWidth = 12, false
        ns:ApplyStyle("gold")
        assert(ns.frames.gold.nineSliceInfo.edge <= 6, "corner fits the width")
        ns.db.blocks.gold.width, ns.db.blocks.gold.autoWidth = 60, true
        ns:ApplyStyle("gold")
        ns.db.blocks.gold.edgeShape = "zigzag"
        ns:ApplyStyle("gold")
        assert(ns.frames.gold.tesseraHD, "unknown corners: rounded")
        ns.db.blocks.gold.edgeShape = "round"
        -- a 2.0 style export comes back whole; a style from 1.0.0-rc9 brings lines back
        local text = ns:ExportStyle()
        assert(ns:ApplyTheme("flat"))
        assert(ns:ImportStyle(text) and ns.db.blocks.gold.border == "hdDouble"
            and ns.db.blocks.gold.separatorStyle ~= "line", "2.0 style export round trip")
        local fx = assert(io.open(addonDir .. "/tools/fixtures/rc9-style.txt"), "missing fixture")
        local old = fx:read("*a")
        fx:close()
        ns.db.blocks.gold.iconSet = "hd"
        assert(ns:ImportStyle(old), "rc9 style over a 2.0 style")
        assert(ns.db.blocks.gold.iconSet == "classic", "rc9 style: usual icons")
        for key, cfg in pairs(ns.db.blocks) do
            assert(cfg.separatorStyle == "line", "rc9 style keeps no 2.0 ornament: " .. key)
        end
        assert(ns:ApplyTheme("hdBronze"))
        -- another style takes the frame back and puts the line separators back
        assert(ns:ApplyTheme("flat"))
        ns:ApplyStyle("gold")
        assert(not ns.frames.gold.tesseraHD and ns.db.blocks.gold.separatorStyle == "line", "flat after a 2.0 style")
        for _, tex in pairs(ns.frames.gold.tesseraHDFill) do assert(not tex:IsShown(), "2.0 fill hidden") end
        local fonts = {}
        for _, item in ipairs(ns:GetMediaList("font")) do fonts[item.key] = true end
        assert(fonts.cinzel and fonts.inter, "Cinzel and Inter in the font list")
    end,
    -- another interface's setup guide or tour: Tessera's popups wait for it, then follow
    function()
        local function Flush()
            local queued = __timers; __timers = {}
            for _, fn in ipairs(queued) do fn() end
        end
        local function Fake(name, shown)
            local f = { shown = shown, IsShown = function(self) return self.shown end }
            _G[name] = f
            return f
        end
        local ran = 0
        -- nothing open: runs at once
        assert(not ns:OtherUIBusy(), "no first-run window yet")
        ns:WhenOtherUIFree(function() ran = ran + 1 end)
        assert(ran == 1, "nothing open: at once")
        -- a window open: waits, however often it checks
        local guide = Fake("ElvUIInstallFrame", true)
        assert(ns:OtherUIBusy(), "ElvUI's installer is seen")
        ns:WhenOtherUIFree(function() ran = ran + 1 end)
        assert(ran == 1, "waits while the installer is open")
        Flush(); Flush()
        assert(ran == 1, "still waiting")
        -- it closes, and a tour opens during the pause: still waits
        guide.shown = false
        Flush()                                   -- sees it closed, starts the pause
        local tour = Fake("DaylightUITour", true)
        Flush()                                   -- the pause ends: a tour is open
        assert(ran == 1, "a tour that follows the guide is waited for too")
        tour.shown = false
        Flush(); Flush(); Flush()
        assert(ran == 2, "runs after everything closed, once")
        Flush(); Flush()
        assert(ran == 2, "never twice")
        -- a window that never closes: gives up after 30 minutes
        local stuck = Fake("GwWelcomePage", true)
        ns:WhenOtherUIFree(function() ran = ran + 1 end)
        for _ = 1, 905 do Flush() end
        assert(ran == 3, "gives up after the longest wait")
        stuck.shown = false
        for _, name in ipairs(ns.FIRST_RUN_WINDOWS) do _G[name] = nil end
        assert(not ns:OtherUIBusy(), "back to none")
        -- the style offer holds back while a window is open
        local offerShown = false
        local showOffer = ns.ShowStyleOffer
        ns.ShowStyleOffer = function() offerShown = true end
        local getList = ns.GetStylesToOffer
        ns.GetStylesToOffer = function() return { "elvui" } end
        Fake("FlareUI_Tour", true)
        ns:OfferStylesIfNeeded()
        assert(not offerShown, "no style offer on top of another interface's tour")
        _G["FlareUI_Tour"].shown = false
        ns:OfferStylesIfNeeded()
        assert(offerShown, "style offer once it is closed")
        _G["FlareUI_Tour"] = nil
        ns.ShowStyleOffer, ns.GetStylesToOffer = showOffer, getList
    end,
    -- Aurore (DaylightUI): without the addon an imitation with a note; with a fake API (the calls
    -- of its API.md: Skin, Font, Accent) the frame is drawn by DaylightUI, and its shell hides
    -- again when the block changes style
    function()
        local theme = ns.db.theme
        assert(not ns:IsThemeInstalled("aurore") and ns:GetDaylightAPI() == nil, "no DaylightUI yet")
        local cfg0 = {}
        ns:ApplyThemeToCfg(cfg0, "aurore")
        assert(cfg0.border == "solid" and cfg0.borderSize == 1 and not cfg0.separators, "Aurore imitation")
        assert(ns:ApplyTheme("aurore") and ns:GetThemeNote("aurore"), "Aurore without DaylightUI has a note")
        for _, t in ipairs(ns:GetAvailableThemes()) do
            if t.key == "aurore" then assert(t.name:find("DaylightUI", 1, true), "Aurore imitation names its addon") end
        end
        local made, last = 0, nil
        _G.DaylightUI = { API = { major = 1, minor = 3,
            Skin = function(frame, opts)
                made = made + 1
                local shell = frame.__daylight or CreateFrame("Frame", nil, frame)
                frame.__daylight, last = shell, opts
                return shell
            end,
            Font = function() return "Fonts\\ARIALN.TTF" end,
            Accent = function() return 0.4, 0.5, 0.9 end } }
        assert(ns:IsThemeInstalled("aurore") and not ns:GetThemeNote("aurore"), "Aurore with DaylightUI")
        assert(ns:FindMedia("border", "daylight").daylight and ns:FindMedia("font", "daylight").file, "daylight media")
        assert(ns:GetAutoTheme() == "aurore", "auto style with DaylightUI: " .. tostring(ns:GetAutoTheme()))
        local cfg = {}
        ns:ApplyThemeToCfg(cfg, "aurore")
        assert(cfg.border == "daylight" and cfg.font == "daylight" and cfg.separators, "Aurore block style")
        assert(math.abs(cfg.separatorColor.b - 0.9) < 0.01, "separators take DaylightUI's accent")
        ns:ApplyTheme("aurore")
        local f = ns.frames.gold
        ns:ApplyStyle("gold")
        assert(made > 0 and f.__daylight and f.__daylight:IsShown(), "DaylightUI draws the block")
        assert(last.borderPx == 2 and f.skinKind == "daylight", "border size passed on")
        assert(f.tesseraDaylightShell == f.__daylight, "shell kept for later")
        ns:ApplyTheme("flat")
        ns:ApplyStyle("gold")
        assert(not f.__daylight:IsShown() and f.skinKind ~= "daylight", "shell hidden after a style change")
        ns:ApplyTheme("aurore")
        ns:ApplyStyle("gold")
        assert(f.__daylight:IsShown(), "shell back with Aurore")
        -- a DaylightUI too old or of another major: the plain imitation
        _G.DaylightUI.API.major = 2
        assert(ns:GetDaylightAPI() == nil and ns:FindMedia("border", "daylight").file, "other major: plain border")
        _G.DaylightUI = nil
        ns:ApplyStyle("gold")
        assert(f.skinKind ~= "daylight", "DaylightUI gone: no shell")
        ns.db.theme = theme
        ns:ApplyTheme(theme or "flat")
    end,
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
        -- a block whose style is locked keeps its own settings through the fallback and back (1.7.1)
        local bags = ns.db.blocks.bags
        local bagsIcon, bagsBg = bags.iconSize, bags.bg
        bags.styleLocked, bags.iconSize, bags.bg = true, 27, false
        ns.pendingStyleNotice = nil
        ns:SyncAutoTheme()
        assert(ns.db.autoThemeMissing == "flareui2" and ns.db.theme == nil, "missing style not remembered")
        local notice = ns.pendingStyleNotice
        assert(notice and notice.text:find("FlareUI", 1, true) and #notice.locked == 1 and notice.locked[1] == "bags",
            "the fallback window: interface and locked blocks")
        ns:ShowStyleNotice(notice)
        local nw = _G["TesseraStyleNotice"]
        assert(nw and nw:IsShown() and nw.names:GetText():find(ns:GetBlockName("bags"), 1, true), "the window names the locked block")
        nw:Hide()
        assert(bags.iconSize == 27 and bags.bg == false, "a locked block was restyled by the fallback")
        ns.pendingStyleNotice = nil
        ns:SyncAutoTheme()
        assert(ns.pendingStyleNotice == nil, "the fallback window comes back at every sync")
        ns.HasFlareUIMedia = function() return true end
        ns:SyncAutoTheme()
        assert(ns.db.autoThemeMissing == nil and ns:GetTheme() == "flareui2", "style not given back")
        assert(math.abs(ns.db.blocks.gold.borderColor.r - 0.80) < 0.01, "blocks not restyled back")
        assert(bags.iconSize == 27 and bags.bg == false, "a locked block was restyled when the interface came back")
        assert(ns.pendingStyleNotice and ns.pendingStyleNotice.text:find("FlareUI", 1, true), "no window when the interface comes back")
        ns.pendingStyleNotice = nil
        -- the Look tab leaves it too; "Apply this style to" changes it
        ns:ApplyTheme("blizzard")
        assert(bags.iconSize == 27, "the Look tab restyled a locked block")
        ns:ApplyThemeToBlocks({ "bags" }, "blizzard")
        assert(bags.iconSize ~= 27 and bags.styleLocked, "Apply this style to: not applied, or the lock was lost")
        ns:ApplyTheme("flareui2")
        ns.db.theme = nil
        bags.styleLocked, bags.iconSize, bags.bg = nil, bagsIcon, bagsBg
        ns.HasFlareUIMedia = has
    end,
    -- a block whose style is locked is left alone by the pages with several blocks (All blocks, a group) (1.7.2)
    function()
        local Tools = ns.OptionsTools
        local bags, gold = ns.db.blocks.bags, ns.db.blocks.gold
        local sLock, sFont, sEnabled, sIcon, gFont, gIcon = bags.styleLocked, bags.fontSize, bags.enabled, bags.iconSize, gold.fontSize, gold.iconSize
        bags.styleLocked, bags.fontSize, bags.iconSize = true, 13, 31
        gold.fontSize, gold.iconSize = 13, 16
        local selected = Tools.S.selected
        Tools.S.selected = Tools.ALL
        Tools.SetField("fontSize", 21)
        assert(gold.fontSize == 21, "All blocks: an unlocked block takes the setting")
        assert(bags.fontSize == 13, "All blocks: a locked block was changed by a setting")
        bags.enabled = false
        Tools.SetField("enabled", true)
        assert(bags.enabled == false, "All blocks: the On screen switch reached a locked block")
        -- the page of the block itself stays editable; the lock setting still reaches a locked block of a page
        Tools.S.selected = "bags"
        Tools.SetField("fontSize", 17)
        assert(bags.fontSize == 17, "a locked block is no longer editable on its own page")
        Tools.S.selected = Tools.ALL
        Tools.SetField("styleLocked", nil)
        assert(bags.styleLocked == nil, "All blocks: the lock cannot be removed")
        bags.styleLocked, bags.fontSize = true, 13
        -- copy style: it asks first, then copies and the block stays locked
        local asked = {}
        local realShow = StaticPopup_Show
        StaticPopup_Show = function(which, a, b, data) table.insert(asked, { which = which, n = a, data = data }) end
        gold.iconSize = 44
        ns:CopyStyleToAll("gold")
        assert(#asked == 1 and asked[1].which == "TESSERA_STYLE_LOCKED_COPY" and asked[1].n >= 1, "Copy style to all: no question about the locked block")
        assert(bags.iconSize == 31, "Copy style to all: a locked block changed before the answer")
        -- the first button (default): every block but the locked one
        local other = ns.db.blocks.time
        other.iconSize = 30
        StaticPopupDialogs.TESSERA_STYLE_LOCKED_COPY.OnAccept(nil, asked[1].data)
        assert(bags.iconSize == 31 and other.iconSize == 44, "Copy style to all, Not the locked ones: wrong blocks changed")
        StaticPopupDialogs.TESSERA_STYLE_LOCKED_COPY.OnButton3(nil, asked[1].data)
        assert(bags.iconSize == 44 and bags.styleLocked, "Copy style to all: not copied after Them too, or the lock was lost")
        bags.iconSize = 31
        local members = ns:GetStyleGroup("bags")
        local src
        for _, k in ipairs(members) do if k ~= "bags" and not ns.IsSpacerKey(k) then src = k break end end
        assert(src, "the test needs a group with the Bags block")
        local before = ns.db.blocks[src].iconSize
        ns.db.blocks[src].iconSize = 45
        asked = {}
        ns:CopyStyleToGroup(src)
        assert(#asked == 1 and asked[1].data.group and bags.iconSize == 31, "Copy style to the group: no question, or changed before the answer")
        StaticPopupDialogs.TESSERA_STYLE_LOCKED_COPY.OnAccept(nil, asked[1].data)
        assert(bags.iconSize == 31, "Copy style to the group, Not the locked ones: the locked block changed")
        StaticPopupDialogs.TESSERA_STYLE_LOCKED_COPY.OnButton3(nil, asked[1].data)
        assert(bags.iconSize == 45 and bags.styleLocked, "Copy style to the group: not copied after Them too, or the lock was lost")
        ns.db.blocks[src].iconSize = before
        StaticPopup_Show = realShow
        -- no locked block: no question
        bags.styleLocked, bags.iconSize = nil, 31
        asked = {}
        StaticPopup_Show = function(which, a, b, data) table.insert(asked, { which = which }) end
        ns:CopyStyleToAll("gold")
        StaticPopup_Show = realShow
        assert(#asked == 0 and bags.iconSize == 44, "Copy style to all: asked with no locked block")
        Tools.S.selected = selected
        bags.styleLocked, bags.fontSize, bags.enabled, bags.iconSize, gold.fontSize, gold.iconSize = sLock, sFont, sEnabled, sIcon, gFont, gIcon
        ns:ApplyStyle("bags") ns:ApplyStyle("gold")
    end,
    -- placing: empty blocks ("Hide when empty") stay shown unless the player hides them (V)
    function()
        local key = "whispers"
        local cfg = ns.db.blocks[key]
        local mod = ns.modules[key]
        local was, empty, locked = cfg.hideEmpty, mod.isEmpty, ns.db.locked
        cfg.enabled, cfg.hideEmpty = true, true
        mod.isEmpty = function() return true end
        ns.db.locked = true
        assert(not ns:ShouldShow(key), "locked: an empty block hides")
        ns.db.locked = false
        ns.placeHideEmpty = nil
        assert(ns:ShouldShow(key), "placing: an empty block is shown")
        ns:SetPlaceHideEmpty(true)
        assert(not ns:ShouldShow(key), "placing, empty blocks hidden: the block hides")
        assert(ns.frames[key] and not ns.frames[key]:IsShown(), "placing, empty blocks hidden: its frame hides")
        ns:SetPlaceHideEmpty(false)
        assert(ns:ShouldShow(key) and ns.frames[key]:IsShown(), "placing, empty blocks shown again")
        ns:SetPlaceHideEmpty(true)
        ns:SetLocked(true, true)
        assert(ns.placeHideEmpty == nil, "locking resets the empty blocks button")
        ns:SetLocked(false, true)
        assert(ns:ShouldShow(key), "unlocked again: shown")
        ns.db.locked = locked
        cfg.hideEmpty, mod.isEmpty = was, empty
        ns:UpdateAllVisibility()
    end,
    -- FlareUI 6: Bronze and gold for new profiles; a profile on Bronze keeps it and is offered the new one
    function()
        local has, meta = ns.HasFlareUIMedia, C_AddOns.GetAddOnMetadata
        local theme, auto, missing = ns.db.theme, ns.db.autoTheme, ns.db.autoThemeMissing
        ns.HasFlareUIMedia = function() return true end
        C_AddOns.GetAddOnMetadata = function(name, field)
            if name == "FlareUI" and field == "Version" then return "6.0.1" end
            return meta(name, field)
        end
        ns.db.theme, ns.db.autoTheme, ns.db.autoThemeMissing = nil, "flareui2", nil
        ns:SyncAutoTheme()
        assert(ns.db.theme == "flareui2", "Bronze profile lost its style under FlareUI 6")
        local offered = false
        for _, key in ipairs(ns:GetDetectedUIStyles()) do offered = offered or key == "flareui6" end
        assert(offered, "Bronze and gold not offered with FlareUI 6")
        ns.db.theme = nil
        assert(ns:GetTheme() == "flareui6", "FlareUI 6: new profiles not on Bronze and gold")
        assert(ns:GetUIName("flareui6") == "FlareUI 6.0.1", "UI name of Bronze and gold")
        -- 2.0: the window accents come from the stone and metal palette of the style
        assert(ns:WindowAccents().lit == ns.Skin.Palette().bar, "Bronze and gold window accents")
        ns.db.theme = "flareui2"
        assert(ns:WindowAccents().text == ns.Skin.Palette().title, "window accents follow the style")
        assert(ns:GetUIName("elvui") == "ElvUI" and ns:GetUIName("ellesmere") == "EllesmereUI", "UI names after renaming")
        for _, t in ipairs(ns:GetAvailableThemes()) do
            if t.key == "elvui" then assert(t.name:find("ElvUI", 1, true), "imitation does not name its addon: " .. t.name) end
        end
        local cfg = {}
        ns:ApplyThemeToCfg(cfg, "flareui6")
        assert(math.abs(cfg.borderColor.r - 0.65) < 0.01 and cfg.textTint, "Bronze and gold block style")
        C_AddOns.GetAddOnMetadata, ns.HasFlareUIMedia = meta, has
        ns.db.theme, ns.db.autoTheme, ns.db.autoThemeMissing = theme, auto, missing
    end,
    -- "Automatic" in the style list: back to the installed interface's style, from a fixed one
    function()
        local has, meta = ns.HasFlareUIMedia, C_AddOns.GetAddOnMetadata
        local theme, auto, missing = ns.db.theme, ns.db.autoTheme, ns.db.autoThemeMissing
        ns.HasFlareUIMedia = function() return true end
        C_AddOns.GetAddOnMetadata = function(name, field)
            if name == "FlareUI" and field == "Version" then return "6.0.1" end
            return meta(name, field)
        end
        ns:ApplyTheme("flareui2")
        assert(ns.db.theme == "flareui2" and ns:GetStyleChoice() == "flareui2", "a fixed style shows as itself")
        local list = ns:GetStyleChoices()
        assert(list[1].key == "auto" and list[1].name:find(ns.L.THEME_BRONZE_GOLD, 1, true), "Automatic first, naming its style")
        ns:PickStyleChoice("auto")
        assert(ns.db.theme == nil and ns:GetStyleChoice() == "auto", "Automatic leaves no style fixed")
        assert(ns:GetTheme() == "flareui6" and ns.db.autoTheme == "flareui6", "Automatic gives FlareUI 6's style")
        assert(math.abs(ns.db.blocks.gold.borderColor.r - 0.65) < 0.01, "blocks restyled by Automatic")
        local said, print0 = {}, ns.Print
        ns.Print = function(msg) table.insert(said, msg) end
        ns.HasFlareUIMedia = function() return false end
        ns:SyncAutoTheme()
        assert(ns.db.autoThemeMissing == "flareui6" and ns.pendingStyleNotice, "Automatic follows the interface when it goes missing")
        ns.pendingStyleNotice = nil
        ns.Print = print0
        -- a fixed style stays as it is when its interface is missing (no fallback by hand)
        ns.HasFlareUIMedia = function() return true end
        ns:ApplyTheme("flareui2")
        ns.db.autoThemeMissing = nil
        ns.HasFlareUIMedia = function() return false end
        said = {}
        ns.Print = function(msg) table.insert(said, msg) end
        ns:SyncAutoTheme()
        ns.Print = print0
        assert(ns.db.theme == "flareui2" and ns.db.autoThemeMissing == nil and #said == 0, "a style picked by hand must stay")
        C_AddOns.GetAddOnMetadata, ns.HasFlareUIMedia = meta, has
        ns.db.theme, ns.db.autoTheme, ns.db.autoThemeMissing = theme, auto, missing
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
        -- the news counted: only versions newer than the one the player had; a test build is its version
        -- (1.6.2 and 1.6.3 only fix bugs and have no news: the 1.6.1 entry is found by its version)
        local e161
        for _, e in ipairs(ns.CHANGELOG) do if e.version == "1.6.1" then e161 = e break end end
        local e170
        for _, e in ipairs(ns.CHANGELOG) do if e.version == "1.7.0" then e170 = e break end end
        local e171
        for _, e in ipairs(ns.CHANGELOG) do if e.version == "1.7.1" then e171 = e break end end
        local e180
        for _, e in ipairs(ns.CHANGELOG) do if e.version == "1.8.0" then e180 = e break end end
        local e190
        for _, e in ipairs(ns.CHANGELOG) do if e.version == "1.9.0" then e190 = e break end end
        local e200
        for _, e in ipairs(ns.CHANGELOG) do if e.version == "2.0.0" then e200 = e break end end
        local n161 = #ns.ChangelogHighlights(e161, "en")
        local n170 = #ns.ChangelogHighlights(e170, "en") + (e171 and #ns.ChangelogHighlights(e171, "en") or 0)
            + (e180 and #ns.ChangelogHighlights(e180, "en") or 0) + (e190 and #ns.ChangelogHighlights(e190, "en") or 0)
            + (e200 and #ns.ChangelogHighlights(e200, "en") or 0)
        assert(#ns.WhatsNewItems("1.6.0") == n161 + n170, "1.6.0 -> now: the 1.6.1, 1.7.0, 1.7.1, 1.8.0, 1.9.0 and 2.0.0 news")
        assert(#ns.WhatsNewItems("1.6.1-test184") > 0 and #ns.WhatsNewItems("1.6.1-test184") <= n161 + n170 + 7, "a test build counts as its version")
        assert(#ns.WhatsNewItems("1.5.1") > n161 + n170, "1.5.1 -> 1.6.1: the 1.6.0 news too")
        assert(ns.WhatsNewIsNewer("1.10.0", "1.9.2") and not ns.WhatsNewIsNewer("1.6.0", "1.6.0"), "versions compare as numbers")
        ns:ShowWhatsNewWindow("9.9.9", "1.0.0")
        local w = _G["TesseraWhatsNew"]
        assert(w and w:IsShown() and w.more:IsShown(), "the update window shows, with more news than it lists")
        w.all:GetScript("OnClick")(w.all)
        assert(not w:IsShown(), "See what's new closes it")
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
        -- its text shadow follows FlareUI's (4.0: enableShadow, on by default); other styles: none
        local cfg = {}
        ns:ApplyThemeToCfg(cfg, "flareui2")
        assert(cfg.textShadow == true, "FlareUI style: shadow by default")
        _G.FlareUI2_DB.profiles.Perso.actionbars.hotkeyFont.enableShadow = false
        ns:ApplyThemeToCfg(cfg, "flareui2")
        assert(cfg.textShadow == false, "FlareUI style: shadow turned off in FlareUI")
        cfg.textShadow = true
        ns:ApplyThemeToCfg(cfg, "blizzard")
        assert(cfg.textShadow == false, "another style starts without shadow")
        -- a change in FlareUI reaches the blocks at the next load, without applying the style again;
        -- a font the player set on one block stays
        _G.FlareUI2_DB.profiles.Perso.actionbars.hotkeyFont.enableShadow = true
        local themeBefore = ns.db.theme
        if ns:ApplyTheme("flareui2") then
            ns.db.blocks.bags.font = "arial"
            _G.FlareUI2_DB.profiles.Perso.actionbars.hotkeyFont.enableShadow = false
            _G.FlareUI2_DB.profiles.Perso.actionbars.hotkeyFont.flags = "THICKOUTLINE"
            ns:FollowFlareFont()
            assert(ns.db.blocks.gold.textShadow == false and ns.db.blocks.gold.outline == "THICKOUTLINE", "followed at load")
            assert(ns.db.blocks.bags.font == "arial", "the player's own font stays")
            ns:FollowFlareFont()
            assert(ns.db.blocks.gold.outline == "THICKOUTLINE", "a second load changes nothing")
            if themeBefore then ns:ApplyTheme(themeBefore) end
        end
        -- FlareUI 6.x: the XP bar has its own font (xpFont); once FlareUI made its copy, the keybind font no longer counts
        local bars = _G.FlareUI2_DB.profiles.Perso.actionbars
        bars.hotkeyFont = { face = "Friz Quadrata TT", flags = "THICKOUTLINE", enableShadow = false }
        bars.xpFont = { flags = "NONE" }
        bars.xpFontSeeded = true
        local xpCfg = {}
        ns:ApplyThemeToCfg(xpCfg, "flareui2")
        assert(xpCfg.outline == "NONE" and xpCfg.textShadow == true, "FlareUI 6: follows the XP bar font, not the keybind font")
        bars.xpFontSeeded, bars.xpFont = nil, nil
        ns:ApplyThemeToCfg(xpCfg, "flareui2")
        assert(xpCfg.outline == "THICKOUTLINE" and xpCfg.textShadow == false, "before FlareUI's copy: the keybind font")
        -- FlareUI's "Global" font choice (a font set to Global, or "Use Global Font Everywhere"):
        -- the XP bar's face is the word "__global"; the font is the profile's Global Font
        -- (Friz Quadrata TT until the player picks another), never Arial
        do
            local realLSM = ns.GetLSM
            ns.GetLSM = function() return { Fetch = function(_, _, name) return name end } end
            bars.xpFontSeeded, bars.xpFont = true, { face = "__global" }
            local fontCfg = {}
            ns:ApplyThemeToCfg(fontCfg, "flareui2")
            assert(fontCfg.font == "lsm:Friz Quadrata TT", "Global font, default: Friz Quadrata TT (got " .. tostring(fontCfg.font) .. ")")
            _G.FlareUI2_DB.profiles.Perso.fonts = { global = { face = "Expressway" } }
            ns:ApplyThemeToCfg(fontCfg, "flareui2")
            assert(fontCfg.font == "lsm:Expressway", "Global font: the one picked in FlareUI (got " .. tostring(fontCfg.font) .. ")")
            -- a font Tessera lends to FlareUI (Lexend): found before Tessera has shared it
            ns.GetLSM = function() return { Fetch = function() return nil end } end
            _G.FlareUI2_DB.profiles.Perso.fonts = { global = { face = "Lexend" } }
            ns:ApplyThemeToCfg(fontCfg, "flareui2")
            assert(fontCfg.font == "lexend", "Global font = Tessera's Lexend, before it is shared (got " .. tostring(fontCfg.font) .. ")")
            _G.FlareUI2_DB.profiles.Perso.fonts = nil
            ns.GetLSM = realLSM
        end
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
        local long = ns.FormatDate(t, "long") -- (the order is the language's: German puts a dot)
        assert(long:find("Thursday", 1, true) and long:find("October", 1, true) and long:find("15", 1, true),
            "long date with the game's names: " .. long)
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
    -- a hidden block still in a chain takes another block's place: the bar must not come
    -- apart (a player's bar broke: the old chain looped back on the hidden block)
    function()
        ns:ResetProfile("top")
        local b = ns.db.blocks
        local function Chain(keys)
            for i = 2, #keys do b[keys[i]].dock = { to = keys[i - 1], side = "RIGHT" } end
        end
        -- gold > bags > friends (hidden) > durability > fps > time
        for _, k in ipairs({ "gold", "bags", "friends", "durability", "fps", "time" }) do b[k].enabled = true end
        Chain({ "gold", "bags", "friends", "durability", "fps", "time" })
        b.friends.enabled = false
        ns:RefreshAllBlocks()
        assert(ns:ReplaceBlock("fps", "friends"), "replace refused")
        for k, c in pairs(b) do
            assert(not (c.dock and c.dock.to == k), k .. " docked to itself")
        end
        assert(b.durability.dock and b.durability.dock.to == "bags", "durability follows what friends followed")
        assert(b.friends.dock and b.friends.dock.to == "durability", "friends takes fps' place")
        assert(b.time.dock and b.time.dock.to == "friends", "time follows friends")
        -- the block replaced sits right after the hidden one: no self-dock
        ns:ResetProfile("top")
        b = ns.db.blocks
        for _, k in ipairs({ "gold", "bags", "friends", "durability" }) do b[k].enabled = true end
        Chain({ "gold", "bags", "friends", "durability" })
        b.friends.enabled = false
        ns:RefreshAllBlocks()
        assert(ns:ReplaceBlock("durability", "friends"), "replace refused")
        assert(b.friends.dock and b.friends.dock.to == "bags", "friends after bags: " .. tostring(b.friends.dock and b.friends.dock.to))
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
    -- a free group in the middle of the screen keeps its center when a block grows,
    -- a group on the left keeps its left edge
    function()
        MOCK_GEOMETRY = true
        ns:ResetProfile("top")
        ns:UpdateLayout()
        ns:FreezeAnchoredGroups()
        ns:UpdateLayout()
        local b = ns.db.blocks
        local root = ns:GetRoot("bags")
        assert(not b[root].anchor and b[root].point, "top bar: a free position after the first layout")
        local function Center()
            local l, _, r = ns:GroupRectUI(root)
            return l, l
        end
        local c0 = Center()
        b.time.autoWidth, b.time.width = false, (ns.frames.time:GetWidth() + 100)
        ns:UpdateLayout()
        local c1 = Center()
        b.time.width = 20
        ns:UpdateLayout()
        local c2 = Center()
        -- moved to the left third: no centering, the left edge stays
        local l = ns:GroupRectUI(root)
        local f = ns.frames[root]
        local hl, hb, hr, ht = ns:GetRectUI(f)
        b[root].point = ns:MakeRelativePoint(hl - l + 10, hb, hr - l + 10, ht, 1)
        ns:ApplyStyle(root)
        ns:UpdateLayout()
        local _, left0 = Center()
        b.time.width = 300
        ns:UpdateLayout()
        local _, left1 = Center()
        MOCK_GEOMETRY = false
        -- (1.3: a free group keeps its place, it is no longer re-centered when a block grows)
        assert(math.abs(c1 - c0) <= 1 and math.abs(c2 - c0) <= 1,
            string.format("free bar moved when a block changed: %.1f, %.1f, %.1f", c0, c1, c2))
        assert(math.abs(left1 - left0) <= 1, string.format("bar on the left moved: %.1f, %.1f", left0, left1))
        ns:ResetProfile("top")
    end,
    -- a block that shows up at the end of a free bar (a whisper arrives) and goes away again:
    -- the bar keeps its place (its left edge), in placement mode as well
    function()
        MOCK_GEOMETRY = true
        ns:ResetProfile("top")
        ns:SetLocked(true)
        ns:UpdateLayout()
        ns:FreezeAnchoredGroups()
        ns:UpdateLayout()
        local b = ns.db.blocks
        local root = ns:GetRoot("bags")
        b.whispers.enabled, b.whispers.hideEmpty = true, true
        b.whispers.dock = { to = "time", side = "RIGHT" }
        ns:UpdateAll()
        ns:UpdateLayout()
        local function Left()
            local l
            for k, f in pairs(ns.frames) do
                if f:IsShown() and ns:GetRoot(k) == root then
                    local fl = ns:GetRectUI(f)
                    l = l and math.min(l, fl) or fl
                end
            end
            return l
        end
        local l0 = Left()
        local mod = ns.modules.whispers
        local originalEmpty = mod.isEmpty
        mod.isEmpty = function() return false end
        ns:UpdateVisibility("whispers", true)
        ns:UpdateLayout()
        local l1 = Left()
        mod.isEmpty = originalEmpty
        ns:UpdateVisibility("whispers", true)
        ns:UpdateLayout()
        local l2 = Left()
        ns:SetLocked(false, true)
        ns:UpdateAllVisibility()
        ns:UpdateLayout()
        local l3 = Left()
        MOCK_GEOMETRY = false
        ns:ResetProfile("top")
        assert(math.abs(l1 - l0) <= 1 and math.abs(l2 - l0) <= 1 and math.abs(l3 - l0) <= 1,
            string.format("bar moved when a block came and went: %.1f, %.1f, %.1f, %.1f", l0, l1, l2, l3))
    end,
    -- hover fade: the alpha moves a little every drawn frame, not in four jumps
    function()
        ns:ResetProfile("top")
        ns:SetLocked(true)
        local cfg, f = ns.db.blocks.gold, ns.frames.gold
        cfg.fadeOut, cfg.fadeAlpha = true, 0
        f.fade = 1
        ns:UpdateFades()
        local drive = ns.fadeDriver and ns.fadeDriver:GetScript("OnUpdate")
        assert(drive, "fade: no per-frame driver")
        drive(ns.fadeDriver, 1 / 60)
        assert(f.fade > 0.9 and f.fade < 1, "fade: small first step, got " .. f.fade)
        for _ = 1, 60 do
            drive = ns.fadeDriver:GetScript("OnUpdate")
            if not drive then break end
            drive(ns.fadeDriver, 1 / 60)
        end
        assert(f.fade == 0 and not ns.fadeDriver:GetScript("OnUpdate"), "fade: reaches its target and stops")
        cfg.fadeOut = false
        ns:ResetProfile("top")
    end,
    -- two columns stuck to the bottom-right corner: a wider text in the right column makes the
    -- group grow to the left (it stays on the screen edge), nothing overlaps
    function()
        MOCK_GEOMETRY = true
        ns:ResetProfile("left")
        ns:UpdateLayout()
        local b = ns.db.blocks
        local root = ns:GetRoot("bags")
        local col = {}
        for k in pairs(ns:GetSubtree(root)) do
            if b[k].enabled and ns.frames[k] and ns.frames[k]:IsShown() and not ns.IsSpacerKey(k) then col[#col + 1] = k end
        end
        table.sort(col, function(x, y) return select(2, ns:GetRectUI(ns.frames[x])) > select(2, ns:GetRectUI(ns.frames[y])) end)
        assert(#col >= 3, "left layout: a column of blocks")
        local used = {}
        for _, k in ipairs(col) do used[k] = true end
        local right = {}
        for _, k in ipairs({ "fps", "latency", "memory", "zone", "coords" }) do
            if not used[k] and #right < 2 and b[k] then right[#right + 1] = k end
        end
        for i, k in ipairs(right) do
            b[k].enabled, b[k].anchor, b[k].point = true, nil, nil
            b[k].dock = { to = col[i], side = "RIGHT" }
        end
        ns:RefreshAllBlocks()
        ns:UpdateLayout()
        ns:StickToEdges(ns:GetRoot(col[1]), { RIGHT = true, BOTTOM = true })
        ns:UpdateLayout()
        local function Overlaps()
            local n = 0
            local keys = {}
            for _, k in ipairs(col) do keys[#keys + 1] = k end
            for _, k in ipairs(right) do keys[#keys + 1] = k end
            for i = 1, #keys do
                for j = i + 1, #keys do
                    local l1, b1, r1, t1 = ns:GetRectUI(ns.frames[keys[i]])
                    local l2, b2, r2, t2 = ns:GetRectUI(ns.frames[keys[j]])
                    if math.min(r1, r2) - math.max(l1, l2) > 1 and math.min(t1, t2) - math.max(b1, b2) > 1 then n = n + 1 end
                end
            end
            return n
        end
        assert(#right == 2, "two blocks for the right column")
        assert(Overlaps() == 0, "columns overlap before the wider text")
        ns:SetPreview(true)
        ns:UpdateLayout()
        for _, k in ipairs(right) do ns.frames[k].text:SetText(string.rep("W", 60)); ns.frames[k].lastText = nil end
        ns:UpdateLayout()
        local _, _, rr = ns:GetRectUI(ns.frames[right[1]])
        local n = Overlaps()
        ns:SetPreview(false)
        MOCK_GEOMETRY = false
        assert(n == 0, n .. " overlapping block pair(s) after a wider text")
        assert(rr <= UIParent.__w + 1, "the group goes off the right edge")
        ns:ResetProfile("top")
    end,
    -- a spacer in a column of blocks draws the line under it (not between two spacers)
    function()
        MOCK_GEOMETRY = true
        ns:ResetProfile("left")
        ns:UpdateLayout()
        local b = ns.db.blocks
        local root = ns:GetRoot("bags")
        local col = {}
        for k in pairs(ns:GetSubtree(root)) do
            if b[k].enabled and ns.frames[k] and ns.frames[k]:IsShown() and not ns.IsSpacerKey(k) then col[#col + 1] = k end
        end
        table.sort(col, function(x, y) return select(2, ns:GetRectUI(ns.frames[x])) > select(2, ns:GetRectUI(ns.frames[y])) end)
        for _, k in ipairs(col) do b[k].separators = true end
        local sp = ns:InsertSpacer(col[1], "RIGHT")
        assert(sp, "a spacer right of the first block")
        sp = b[col[1]] and (function() for k, c in pairs(b) do if ns.IsSpacerKey(k) and c.dock and c.dock.to == col[1] then return k end end end)()
        assert(sp, "spacer docked to the first block")
        local below = "memory"
        b[below].enabled, b[below].anchor, b[below].point = true, nil, nil
        b[below].dock = { to = sp, side = "BOTTOM" }
        ns:RefreshAllBlocks()
        ns:UpdateLayout()
        local shown = 0
        for _, tex in ipairs(ns.frames[sp].separatorPool or {}) do if tex:IsShown() then shown = shown + 1 end end
        MOCK_GEOMETRY = false
        assert(shown == 1, "the spacer draws one line, under it (" .. shown .. ")")
        ns:ResetProfile("top")
    end,
    -- separators: drawn between blocks only, never along a stuck screen edge
    function()
        MOCK_GEOMETRY = true
        ns:ResetProfile("top")
        local b = ns.db.blocks
        for _, c in pairs(b) do c.separators = true end
        ns:UpdateLayout()
        local root = ns:GetRoot("bags")
        b[root].anchor = nil   -- dragged by the player: a free position
        ns:StickToEdges(root, { RIGHT = true, TOP = true })
        ns:UpdateLayout()
        local inner, onEdge = 0, 0
        for key, f in pairs(ns.frames) do
            if ns:GetRoot(key) == root and f:IsShown() then
                for _, tex in ipairs(f.separatorPool or {}) do
                    if tex:IsShown() then
                        local l, b2, w, h = MockRect(tex)
                        if l + w >= UIParent.__w - 1 or b2 + h >= UIParent.__h - 1 and w > h then
                            onEdge = onEdge + 1
                        else
                            inner = inner + 1
                        end
                    end
                end
            end
        end
        MOCK_GEOMETRY = false
        assert(inner > 0, "separators between the blocks of the bar")
        assert(onEdge == 0, onEdge .. " separator(s) drawn along the screen edge")
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
    -- the weapon skill block takes the skill of the weapon held, by item subclass, not by
    -- name ("Épées à deux mains" also contains "Épées")
    function()
        local oldS, oldLink, oldItem = C_SkillInfo, GetInventoryItemLink, C_Item
        C_SkillInfo = {
            GetNumSkillLines = function() return 2 end,
            GetSkillLineInfo = function(i)
                return ({ { name = "Épées", rank = 12, maxRank = 60, skillLineCategoryID = 6, skillID = 43 },
                          { name = "Épées à deux mains", rank = 60, maxRank = 60, skillLineCategoryID = 6,
                            skillID = 55 } })[i]
            end,
        }
        GetInventoryItemLink = function() return "item:2h-sword" end
        C_Item = setmetatable({ GetItemInfoInstant = function() return 1, "", "", "", "", 2, 8 end },
            { __index = oldItem })
        local value = ns.modules.weaponSkills.update(ns.db.blocks.weaponSkills)
        assert(value:find("deux mains"), "two-handed sword skill: " .. tostring(value))
        -- "Follows the fight": the ranged weapon's skill while shooting (wand: subclass 19, skill 228)
        C_SkillInfo.GetNumSkillLines = function() return 3 end
        local lines = C_SkillInfo.GetSkillLineInfo
        C_SkillInfo.GetSkillLineInfo = function(i)
            if i == 3 then return { name = "Baguettes", rank = 30, maxRank = 60, skillLineCategoryID = 6, skillID = 228 } end
            return lines(i)
        end
        GetInventoryItemLink = function(_, slot) return slot == 18 and "item:wand" or "item:2h-sword" end
        C_Item = setmetatable({ GetItemInfoInstant = function(link)
            if link == "item:wand" then return 1, "", "", "", "", 2, 19 end
            return 1, "", "", "", "", 2, 8 end }, { __index = oldItem })
        local cfg = { skillShown = "combat" }
        assert(ns.modules.weaponSkills.update(cfg):find("deux mains"), "not shooting: weapon in hand")
        ns.state.autoRepeat = true
        assert(ns.modules.weaponSkills.update(cfg):find("Baguettes"), "shooting: wand skill")
        ns.state.autoRepeat = nil
        -- "Picked": always the chosen skill, offered in the option's list
        cfg = { skillShown = "chosen", skillChosen = 43 }
        assert(ns.modules.weaponSkills.update(cfg):find("^Épées 12"), "picked skill: " .. ns.modules.weaponSkills.update(cfg))
        local picks = ns.modules.weaponSkills.options[2].values()
        assert(#picks == 3 and picks[3].key == 228, "skill list for the picker")
        C_SkillInfo, GetInventoryItemLink, C_Item = oldS, oldLink, oldItem
    end,
    -- unspent talent points on WoW Forever: modern talent trees, no UnitCharacterPoints
    function()
        local oldU, oldCT, oldT = UnitCharacterPoints, C_ClassTalents, C_Traits
        UnitCharacterPoints = nil
        C_ClassTalents = { GetActiveConfigID = function() return 7 end, HasUnspentTalentPoints = function() return true end }
        C_Traits = { GetConfigInfo = function() return { treeIDs = { 42 } } end,
                     GetTreeCurrencyInfo = function() return { { quantity = 2 }, { quantity = 1 } } end }
        local t = ns.modules.talents
        assert(not t.isEmpty(), "talent points left are seen")
        assert(t.update() == "3", "talent points: " .. tostring(t.update()))
        C_Traits.GetTreeCurrencyInfo = function() return { { quantity = 0 } } end
        C_ClassTalents.HasUnspentTalentPoints = function() return false end
        assert(t.isEmpty(), "no point left: the block hides")
        UnitCharacterPoints, C_ClassTalents, C_Traits = oldU, oldCT, oldT
    end,
    -- talents 1.7.0: points per tree (by column, then by the game's groups), main tree, milestone, legacy points
    function()
        local oldU, oldCT, oldT = UnitCharacterPoints, C_ClassTalents, C_Traits
        UnitCharacterPoints = nil
        C_ClassTalents = { GetActiveConfigID = function() return 7 end, HasUnspentTalentPoints = function() return false end }
        local nodes = { [1] = { 1020, 5 }, [2] = { 1620, 11 }, [3] = { 5020, 0 }, [4] = { 9080, 0 } }
        C_Traits = {
            GetConfigInfo = function() return { treeIDs = { 42 } } end,
            GetTreeCurrencyInfo = function() return { { traitCurrencyID = 3820, quantity = 2, spent = 16 } } end,
            GetTreeNodes = function() return { 1, 2, 3, 4 } end,
            GetNodeInfo = function(_, id) return { posX = nodes[id][1], currentRank = nodes[id][2], maxRanks = 5, groupIDs = {} } end,
        }
        local data = ns.Traits.Talents()
        assert(data.free == 2 and data.spent == 16 and data.total == 18, "talent currency")
        assert(#data.trees == 3 and data.trees[1].points == 16 and data.trees[2].points == 0, "trees by column")
        local cfg = { talentsShown = "split" }
        assert(ns.modules.talents.update(cfg) == "16/0/0", "split text: " .. tostring(ns.modules.talents.update(cfg)))
        cfg.talentsShown = "main"
        assert(ns.modules.talents.update(cfg):find("16"), "main tree text")
        assert(ns.Traits.NextMilestone(18).at == 21 and ns.Traits.NextMilestone(18).left == 3, "next milestone")
        assert(ns.Traits.NextMilestone(60) == nil, "no milestone left")
        -- the game's groups, when it gives them
        C_Traits.GetGroupDisplayInfoByTreeID = function()
            return { { groupID = 11, displayName = "Arcane", orderIndex = 0 }, { groupID = 12, displayName = "Fire", orderIndex = 1 },
                     { groupID = 13, displayName = "Frost", orderIndex = 2 } }
        end
        C_Traits.GetNodeInfo = function(_, id)
            return { posX = nodes[id][1], currentRank = nodes[id][2], maxRanks = 5, groupIDs = { id == 4 and 13 or (id == 3 and 12 or 11) } }
        end
        local named = ns.Traits.Talents()
        assert(named.trees[1].name == "Arcane" and named.trees[1].points == 16, "trees by group")
        -- the tooltip runs with every line on, and with every line off
        local lines = {}
        local tt = setmetatable({}, { __index = function() return function() lines[#lines + 1] = true end end })
        ns.modules.talents.tooltip(tt, {})
        ns.modules.talents.tooltip(tt, { talentsTipTrees = false, talentsTipSpecs = false, talentsTipNext = false })
        assert(#lines >= 4, "talents tooltip")
        -- legacy points: one config of type Generic, three trees, one shared currency, an empty tree
        local legacy = { [1187] = { 3, 9 }, [1188] = { 0, 9 }, [1189] = { 1, 9 }, [1118] = { 0, 0 } }
        C_Traits = {
            GetConfigsByType = function() return { 99 } end,
            GetConfigInfo = function() return { treeIDs = { 1187, 1188, 1189, 1118 } } end,
            GetTreeCurrencyInfo = function() return { { traitCurrencyID = 4225, quantity = 1, spent = 4 } } end,
            GetTreeNodes = function(treeID) return { treeID } end,
            GetNodeInfo = function(_, id) return { posX = 0, currentRank = legacy[id][1], maxRanks = legacy[id][2], groupIDs = {} } end,
        }
        local points = ns.Traits.Legacy()
        assert(points and points.free == 1 and points.spent == 4, "legacy currency counted once")
        assert(#points.trees == 3 and points.trees[1].ranks == 3 and points.trees[1].max == 9, "legacy trees")
        C_Traits = nil
        assert(ns.Traits.Legacy() == nil and ns.Traits.Talents() == nil, "no trait API: nothing, no error")
        assert(ns.Traits.SpecMacro():find("^/"), "spec macro")
        UnitCharacterPoints, C_ClassTalents, C_Traits = oldU, oldCT, oldT
    end,
    -- 1.7.0: an old profile with no middle click on the Talents block gets the spec change once
    function()
        local p = { blocks = { talents = { middleClick = "none" } } }
        ns:PrepareProfile(p)
        assert(p.blocks.talents.middleClick == "switchSpec", "old profile: middle click changes spec")
        p.blocks.talents.middleClick = "none"
        ns:PrepareProfile(p)
        assert(p.blocks.talents.middleClick == "none", "a later choice stays")
    end,
    -- every value of every block's display choices gives a value without error, and the
    -- default of each choice is the block's former display
    function()
        for _, key in ipairs(ns.order) do
            local mod, cfg = ns.modules[key], ns.db.blocks[key]
            for _, o in ipairs(mod.options or {}) do
                if o.kind == "dropdown" and o.field then
                    local saved = cfg[o.field]
                    -- (a list made at the time, like the player's skills: its labels are game names)
                    local listed = type(o.values) == "function"
                    for _, v in ipairs(listed and o.values() or o.values) do
                        assert(listed or ns.L[v.label] or tostring(v.label):match("^%d+$"), key .. ": no text for " .. tostring(v.label))
                        cfg[o.field] = v.key
                        local ok, err = pcall(mod.update, cfg)
                        assert(ok, key .. " " .. o.field .. "=" .. tostring(v.key) .. ": " .. tostring(err))
                    end
                    cfg[o.field] = saved
                    assert(ns.L[o.label] and ns.L[o.tip], key .. ": label or tooltip text missing")
                end
            end
        end
    end,
    -- Gold, Bags, Durability and XP settings (1.5): every checkbox on and off draws the block and its
    -- tooltip; the account total counts only characters of the same faction and realm; the history
    -- length follows its setting; "reset session" restarts the gains
    function()
        for _, key in ipairs({ "gold", "bags", "durability", "xp" }) do
            local mod, cfg = ns.modules[key], ns.db.blocks[key]
            for _, o in ipairs(mod.options) do
                assert(ns.L[o.label] and ns.L[o.tip], key .. ": text missing for " .. o.field)
                if o.kind == "check" then
                    local saved = cfg[o.field]
                    for _, v in ipairs({ true, false }) do
                        cfg[o.field] = v
                        local ok, err = pcall(mod.update, cfg)
                        assert(ok, key .. " " .. o.field .. "=" .. tostring(v) .. ": " .. tostring(err))
                        ok, err = pcall(mod.tooltip, GameTooltip, cfg)
                        assert(ok, key .. " tooltip " .. o.field .. "=" .. tostring(v) .. ": " .. tostring(err))
                    end
                    cfg[o.field] = saved
                end
            end
        end
        local gold, tools = ns.modules.gold, ns.BlockTools
        local cfg, saved = ns.db.blocks.gold, ns.sv.chars
        ns:RecordMoney()
        assert(ns.sv.chars[ns.charKey].faction == "Alliance" and ns.sv.chars[ns.charKey].realm == GetRealmName(),
            "faction and realm are recorded")
        ns.sv.chars = {
            [ns.charKey] = { money = 1, class = "MAGE", faction = "Alliance", realm = GetRealmName() },
            ["Ally-Same"] = { money = 100, class = "MAGE", faction = "Alliance", realm = GetRealmName() },
            ["Horde-Same"] = { money = 1000, class = "MAGE", faction = "Horde", realm = GetRealmName() },
            ["Ally-Other"] = { money = 10000, class = "MAGE", faction = "Alliance", realm = "Elsewhere" },
            ["Old-Entry"] = { money = 100000, class = "MAGE" },
        }
        cfg.goldScope = "total"
        assert(gold.update(cfg) == tools.FormatGold((GetMoney() or 0) + 100, cfg), "total: same faction and realm only")
        cfg.goldScope = "character"
        assert(gold.update(cfg) == tools.FormatGold(GetMoney() or 0, cfg), "this character by default")
        ns.sv.chars = saved
        -- history length
        local old = date("%Y-%m-%d", time() - 10 * 86400)
        ns.sv.goldHistory = ns.sv.goldHistory or {}
        ns.sv.goldHistory[ns.charKey] = { [old] = 5 }
        cfg.goldHistoryDays = "14"
        ns.lastMoney = (GetMoney() or 0) - 1
        ns:RecordMoney()
        assert(ns.sv.goldHistory[ns.charKey][old], "14 days keep a 10 day old entry")
        cfg.goldHistoryDays = "7"
        ns.lastMoney = (GetMoney() or 0) - 1
        ns:RecordMoney()
        assert(not ns.sv.goldHistory[ns.charKey][old], "7 days drop it")
        -- reset session
        tools.session.xpGained = 5000
        ns.sessionMoney = 0
        tools.ResetSession()
        assert(tools.session.xpGained == 0 and ns.sessionMoney == (GetMoney() or 0), "reset session")
        assert(ns.modules.gold.extraAction.key == "resetSession" and ns.modules.xp.extraAction.key == "resetSession")
    end,
    -- Durability repair cost (1.6.3): the cost counts the worn items (796) and the damaged item in the bags (33),
    -- like the vendor's Repair all (829); the checkbox leaves the bags out
    function()
        local mod, cfg = ns.modules.durability, ns.db.blocks.durability
        local savedInfo, saved = C_TooltipInfo, {}
        for k, v in pairs(cfg) do saved[k] = v end
        C_TooltipInfo = {
            GetInventoryItem = function(_, slot) return slot == 1 and { repairCost = 796 } or nil end,
            GetBagItem = function(bag, slot) return bag == 0 and slot == 1 and { repairCost = 33 } or nil end,
        }
        local lines = {}
        local tt = setmetatable({ AddLine = function() end,
            AddDoubleLine = function(_, a, b) table.insert(lines, tostring(a) .. " | " .. tostring(b)) end },
            { __index = GameTooltip })
        cfg.durabilityTipCost = true
        mod.tooltip(tt, cfg)
        assert(table.concat(lines, "\n"):find(ns.FormatMoney(829), 1, true), "tooltip cost: " .. table.concat(lines, "\n"))
        cfg.durabilityCost = true
        assert(mod.update(cfg):find(ns.FormatMoney(829), 1, true), "block cost with the bags: " .. tostring(mod.update(cfg)))
        cfg.durabilityCostBags = false
        local noBags = mod.update(cfg)
        assert(noBags:find(ns.FormatMoney(796), 1, true) and not noBags:find(ns.FormatMoney(829), 1, true),
            "items in bags left out of the cost when the checkbox is cleared")
        C_TooltipInfo = savedInfo
        for k in pairs(cfg) do cfg[k] = nil end
        for k, v in pairs(saved) do cfg[k] = v end
    end,
    -- micro-menu block: one block; its tooltip lists the menus (Legacy locked); a click opens
    -- the list of secure rows, out of combat only
    function()
        assert(#ns.MicroMenuEntries() == 11, "menus listed: " .. #ns.MicroMenuEntries())
        local m = ns.modules.microMenu
        assert(m.update() == "10 / 11", "unlocked menus: " .. tostring(m.update()))
        m.tooltip(GameTooltip)
        ns:ToggleMicroMenuList(UIParent)
        assert(_G["TesseraMicroMenuRow1"]:GetAttribute("macrotext") == "/click CharacterMicroButton", "row opens Blizzard's button")
        ns:ToggleMicroMenuList(UIParent)
        LegacyMicroButton = MicroButton(true)
        assert(m.update() == "", "all unlocked: no count")
        LegacyMicroButton = MicroButton(false)
    end,
    -- the new blocks of 1.0.5: tracking, hunter pet, weapon enchant, long buffs, session XP and gold
    function()
        local m = ns.modules
        assert(m.pet.update() == (PET_HAPPINESS3 or "3"), "pet happiness")
        local text, level = m.weaponEnchant.update()
        assert(text == "25:00" and level == 1, "poison time left: " .. tostring(text))
        -- the poison is on the main hand: "off hand only" sees nothing, "main hand" sees it
        assert(m.weaponEnchant.update({ weaponSlots = "main" }) == "25:00", "main hand option")
        assert(m.weaponEnchant.isEmpty({ weaponSlots = "off" }), "off hand option: empty")
        assert(m.longBuffs.update() == "20:00", "long buffs: only Well Fed, 20 minutes left: " .. tostring(m.longBuffs.update()))
        for _, key in ipairs({ "pet", "weaponEnchant", "longBuffs", "xpRate", "goldSession" }) do
            m[key].tooltip(GameTooltip, ns.db.blocks[key])
            assert(m[key].sample, key .. " has a demo sample")
        end
        -- session gold: +1 gold 50 silver since login; hidden in streamer mode
        local oldMoney = GetMoney
        m.goldSession.update(ns.db.blocks.goldSession)
        GetMoney = function() return oldMoney() + 15000 end
        assert(m.goldSession.update(ns.db.blocks.goldSession):sub(1, 1) == "+", "gold earned")
        ns:SetStreamerMode(true)
        assert(m.goldSession.update(ns.db.blocks.goldSession) == ns.HIDDEN, "gold hidden in streamer mode")
        ns:SetStreamerMode(false)
        GetMoney = oldMoney
        -- XP per hour comes from the shared session: 1000 XP gained in half an hour = 2000 XP/h
        local oldXP, oldTime = UnitXP, GetTime
        local shared = ns.BlockTools.session
        local savedGained, savedStart = shared.xpGained, shared.gainStart
        shared.xpGained, shared.gainStart = 1000, oldTime() - 1800
        UnitXP = function() return 2000 - 500 end
        local rate = m.xpRate.update({ xpRateShown = "rate" })
        assert(rate:find("2[ ,.\194\160]?000"), "xp rate: " .. rate)
        assert(m.xpRate.update({ xpRateShown = "time" }) == "15m", "500 XP left at 2000/h: 15 minutes")
        local both = m.xpRate.update({ xpRateShown = "both" })
        assert(both:find("15m") and both:find("2[ ,.\194\160]?000"), "rate and time together: " .. both)
        -- the tooltip parts follow their checkboxes
        local count = 0
        local counter = setmetatable({ AddLine = function() count = count + 1 end,
            AddDoubleLine = function() count = count + 1 end }, { __index = function() return function() end end })
        m.xpRate.tooltip(counter, { xpTipTime = false, xpTipGained = false, xpTipRate = false, xpTipRecent = false })
        local fewer = count
        count = 0
        m.xpRate.tooltip(counter, {})
        assert(count >= fewer + 3, "the checkboxes drop lines")
        -- "Reset session" starts the rate again
        shared.xpGained, shared.gainStart = 0, oldTime()
        assert(m.xpRate.update({ xpRateShown = "rate" }):find("^0 "), "rate after a reset")
        shared.xpGained, shared.gainStart = savedGained, savedStart
        UnitXP, GetTime = oldXP, oldTime
    end,
    -- 1.5.0 (test141): Goal (currency, reached, estimate), Reagents, Group, Memory, Instances
    function()
        local m = ns.modules
        local function FakeTip()
            local lines = {}
            local tt = setmetatable({ AddLine = function(_, t) table.insert(lines, tostring(t)) end,
                AddDoubleLine = function(_, a, b) table.insert(lines, tostring(a) .. " | " .. tostring(b)) end },
                { __index = function() return function() end end })
            return tt, function() return table.concat(lines, "\n") end
        end
        local L = ns.L
        -- Goal: reached shows the word, the estimate needs a pace, a currency goal counts the currency
        local oldMoney, shared = GetMoney, ns.BlockTools.session
        local savedStart, savedMoney = shared.gainStart, ns.sessionMoney
        GetMoney = function() return 20000000 end
        local text = m.goal.update({ goalType = "gold", goalValue = 1000 })
        assert(text:find(L.GOAL_REACHED, 1, true), "goal reached in words: " .. text)
        GetMoney = function() return 9000000 end -- 900 gold of 1000
        shared.gainStart, ns.sessionMoney = GetTime() - 3600, 8000000 -- 100 gold in an hour
        local tt, got = FakeTip()
        m.goal.tooltip(tt, { goalType = "gold", goalValue = 1000 })
        assert(got():find(L.TT_GOAL_ETA, 1, true) and got():find("1h", 1, true), "estimated time: " .. got())
        GetMoney, shared.gainStart, ns.sessionMoney = oldMoney, savedStart, savedMoney
        local oldCI = C_CurrencyInfo.GetCurrencyInfo
        C_CurrencyInfo.GetCurrencyInfo = function() return { quantity = 50, name = "Honor", iconFileID = 1 } end
        assert(m.goal.update({ goalType = "currency", goalCurrency = 1901, goalValue = 100 }) == "50%", "currency goal")
        assert(m.goal.getIcon({ goalType = "currency", goalCurrency = 1901 }) == 1, "currency goal icon")
        C_CurrencyInfo.GetCurrencyInfo = oldCI
        -- Reagents: nothing at zero unless asked, gray when shown, a turned-off reagent never
        local oldClass = UnitClass
        UnitClass = function() return "Mage", "MAGE" end
        assert(m.reagents.update({}) == L.NONE, "no reagent carried")
        assert(m.reagents.update({ reagentsZero = true }):find("|cff808080", 1, true), "zero grayed out")
        local all = m.reagents.update({ reagentsZero = true })
        local fewer = m.reagents.update({ reagentsZero = true, reagent17031 = false })
        assert(#fewer < #all, "a reagent turned off is dropped")
        UnitClass = oldClass
        -- Group: roles, state and level follow their checkboxes
        local saved = { IsInGroup = IsInGroup, IsInRaid = IsInRaid, GetNumGroupMembers = GetNumGroupMembers,
            UnitName = UnitName, UnitIsGroupLeader = UnitIsGroupLeader, UnitIsConnected = UnitIsConnected,
            UnitLevel = UnitLevel }
        IsInGroup, IsInRaid, GetNumGroupMembers = function() return true end, function() return false end, function() return 2 end
        UnitName = function(unit) return unit == "player" and "Me" or "Pal" end
        UnitIsGroupLeader = function(unit) return unit == "player" end
        UnitIsConnected = function(unit) return unit == "player" end
        UnitLevel = function() return 42 end
        tt, got = FakeTip()
        m.group.tooltip(tt, {})
        assert(got():find("(" .. L.TT_LEADER .. ")", 1, true), "leader tag: " .. got())
        assert(got():find(PLAYER_OFFLINE or "Offline", 1, true) or not PLAYER_OFFLINE, "offline in words: " .. got())
        assert(got():find("42", 1, true), "level shown")
        tt, got = FakeTip()
        m.group.tooltip(tt, { groupTipRole = false, groupTipState = false, groupTipLevel = false })
        assert(not got():find(L.TT_LEADER, 1, true) and not got():find("42", 1, true), "parts off: " .. got())
        -- (1.6) the clickable group list: members, status, whisper, search, not in a group
        local members = ns.GroupMembers({})
        assert(#members == 2 and members[1].isMe and members[1].label == "Me" and members[2].label == "Pal", "group members")
        assert(members[1].zone:find(L.TT_LEADER, 1, true), "the leader tag is in the status column")
        assert(ns.modules.group.defaults.groupShow == "list", "the group list is the default")
        local gblock = CreateFrame("Frame", nil, UIParent)
        assert(not ns.modules.group.hoverList(gblock, { groupShow = "tooltip" }), "tooltip setting: the normal tooltip")
        assert(ns.modules.group.hoverList(gblock, { groupShow = "list" }), "list setting: the list takes its place")
        -- a real raid (not the preview): sorted by the raid's groups
        local oldRaid, oldRoster, oldNum, oldName2 = IsInRaid, GetRaidRosterInfo, GetNumGroupMembers, UnitName
        IsInRaid = function() return true end
        GetNumGroupMembers = function() return 3 end
        UnitName = function(unit) return unit end
        GetRaidRosterInfo = function(i) return "raid" .. i, 0, ({ 3, 1, 2 })[i] end
        local raidReal = ns.GroupMembers({})
        assert(raidReal[1].name == "raid2" and raidReal[2].name == "raid3" and raidReal[3].name == "raid1", "raid: sorted by group")
        IsInRaid, GetRaidRosterInfo, GetNumGroupMembers, UnitName = oldRaid, oldRoster, oldNum, oldName2
        local glist = _G["TesseraGroupList"]
        assert(glist and glist:IsShown() and glist.rows[2]:IsShown() and not glist.rows[3]:IsShown(), "2 rows for 2 members")
        local gTold
        local oldUtil = ChatFrameUtil
        ChatFrameUtil = { SendTell = function(n) gTold = n end }
        glist.rows[1]:GetScript("OnClick")(glist.rows[1], "LeftButton")
        assert(gTold == nil and glist:IsShown(), "you cannot whisper yourself")
        glist.rows[2]:GetScript("OnClick")(glist.rows[2], "LeftButton")
        assert(gTold == "Pal" and not glist:IsShown(), "a click whispers a member")
        ChatFrameUtil = oldUtil
        -- the list opens on the tooltip's side, with the block's alignment setting
        local pts = {}
        local fakeList = { ClearAllPoints = function() pts = {} end, SetPoint = function(_, ...) pts[#pts + 1] = { ... } end }
        local realRect2 = ns.GetRectUI
        ns.GetRectUI = function() return 100, 700, 200, 720 end -- a block in the top left of a 1000 x 800 screen
        local gcfg = ns.db.blocks.group
        gcfg.tooltipAlign, gcfg.tooltipAnchor = nil, nil
        local fakeOwner = { key = "group" }
        ns.PlaceHoverList(fakeList, fakeOwner)
        assert(pts[1][1] == "TOPLEFT" and pts[1][3] == "BOTTOMLEFT", "automatic: under the block, left edge: " .. tostring(pts[1][1]))
        gcfg.tooltipAlign, gcfg.tooltipAnchor = "right", "top"
        ns.PlaceHoverList(fakeList, fakeOwner)
        assert(pts[1][1] == "BOTTOMRIGHT" and pts[1][3] == "TOPRIGHT", "forced: above the block, right edge: " .. tostring(pts[1][1]))
        gcfg.tooltipAlign, gcfg.tooltipAnchor = nil, nil
        ns.GetRectUI = realRect2
        -- hovering another block closes a list, the block's own stays (no overlap)
        ns.modules.group.hoverList(gblock, { groupShow = "list" })
        ns:HideHoverLists(gblock)
        assert(glist:IsShown(), "a list stays while its own block is hovered")
        ns:HideHoverLists(CreateFrame("Frame", nil, UIParent))
        assert(not glist:IsShown(), "hovering another block closes the list")
        IsInGroup = function() return false end
        assert(not ns.modules.group.hoverList(gblock, { groupShow = "list" }), "no list outside a group")
        IsInGroup = function() return true end
        for name, fn in pairs(saved) do _G[name] = fn end
        -- Memory: the total line and the shares come with their checkboxes
        pcall(m.memory.update, {})
        tt, got = FakeTip()
        m.memory.tooltip(tt, {})
        assert(not got():find(L.TT_MEMORY_TOTAL, 1, true), "no total line by default")
        tt, got = FakeTip()
        m.memory.tooltip(tt, { memoryTotal = true, memoryShare = true, memoryCount = "5" })
        assert(got():find(L.TT_MEMORY_TOTAL, 1, true), "total line: " .. got())
        -- Instances: nearest reset first, red when a reset is under the threshold
        local oldN, oldInfo = GetNumSavedInstances, GetSavedInstanceInfo
        GetNumSavedInstances = function() return 2 end
        GetSavedInstanceInfo = function(i)
            if i == 1 then return "Far Keep", 1, 400000, 0, true, false, false, false, 10, "Normal", 3, 1 end
            return "Near Keep", 2, 3000, 0, true, false, false, false, 10, "Normal", 3, 1
        end
        tt, got = FakeTip()
        m.instances.tooltip(tt, { instancesSortReset = true })
        local first, second = got():find("Near Keep", 1, true), got():find("Far Keep", 1, true)
        assert(first and second and first < second, "nearest reset first")
        tt, got = FakeTip()
        m.instances.tooltip(tt, { instancesTipSaved = false })
        assert(not got():find("Keep", 1, true), "saves hidden")
        local _, level = m.instances.update({})
        assert(level == 3, "red when a reset is under an hour: " .. tostring(level))
        GetNumSavedInstances, GetSavedInstanceInfo = oldN, oldInfo
    end,
    -- 1.1.0: pinned tooltips, custom names, item goal, DPS, corpse, game mode, weather,
    -- worn items in the bags, profession bags apart in the bags tooltip
    function()
        local m = ns.modules
        -- custom name: used everywhere the block is named, empty = the usual name
        ns.db.blocks.gold.customName = "Mes sous"
        assert(ns:GetBlockName("gold") == "Mes sous", "custom name")
        ns.db.blocks.gold.customName = nil
        assert(ns:GetBlockName("gold") == ns.L.GOLD, "usual name back")
        -- pinned tooltip: toggled, saved, refreshed without error
        ns:TogglePin("fps")
        assert(ns:IsPinned("fps"), "pinned")
        ns:RefreshPins()
        ns:TogglePin("fps")
        assert(not ns:IsPinned("fps"), "unpinned")
        ns:RunClickAction("fps", "pin")
        assert(ns:IsPinned("fps"), "pin from a click action")
        ns:TogglePin("fps")
        -- item goal: the single item of the first test builds becomes the list's first item
        local oldCount = C_Item.GetItemCount
        C_Item.GetItemCount = function(id) return (id == 2592 and 7) or (id == 2589 and 30) or 0 end
        local cfg = { goalType = "item", goalItem = 2592, goalValue = 20 }
        assert(m.goal.update(cfg) == "7 / 20", "item goal: " .. tostring(m.goal.update(cfg)))
        assert(cfg.goalItem == nil and #cfg.goalItems == 1, "old item converted")
        ns.GoalItems(cfg)
        assert(#cfg.goalItems == 1 and cfg.goalItems[1].count == 20, "conversion runs once")
        m.goal.tooltip(GameTooltip, cfg)
        -- the list on the real block: add, newest shown, all shown, full at 3, change, remove
        local g = ns.db.blocks.goal
        g.goalItems, g.goalType = {}, "gold"
        assert(ns:AddGoalItem("goal", 2592, 20) and g.goalType == "item", "add an item")
        assert(ns:AddGoalItem("goal", 2589, 25), "add a second item")
        assert(m.goal.update(g) == "30 / 25", "newest item shown: " .. tostring(m.goal.update(g)))
        g.goalItemsShown = "all"
        assert(select(2, m.goal.update(g):gsub("/", "")) == 2, "every item shown: " .. m.goal.update(g))
        g.goalItemsShown = "last"
        assert(ns:AddGoalItem("goal", 4306, 10), "third item")
        assert(not ns:AddGoalItem("goal", 4338, 10) and #g.goalItems == 3, "no fourth item")
        assert(ns:AddGoalItem("goal", 2592, 5) and #g.goalItems == 3 and g.goalItems[3].id == 2592, "change moves it last")
        ns:RemoveGoalItem("goal", 4306)
        assert(#g.goalItems == 2, "removed")
        m.goal.tooltip(GameTooltip, g)
        ns:FillGoalMenu(setmetatable({}, { __index = function() return function(self) return self end end }), "goal")
        -- the list survives an export and an import; a broken list is cleaned
        local text = ns:ExportProfile()
        local data = ns:DecodeProfile(text)
        assert(data and #data.blocks.goal.goalItems == 2, "goal items exported and read back")
        g.goalItems[3] = { id = "x", count = -1 }
        g.goalItems[4], g.goalItems[5] = { id = 1, count = 1 }, { id = 2, count = 2 }
        data = ns:DecodeProfile(ns:ExportProfile())
        assert(#data.blocks.goal.goalItems == 3, "broken entry dropped, at most 3 kept")
        g.goalItems[5], g.goalItems[4], g.goalItems[3] = nil, nil, nil
        C_Item.GetItemCount = oldCount
        -- corpse: hidden while alive
        assert(m.corpse.isEmpty(), "corpse hidden while alive")
        -- corpse: no arrow character in the text (the game's fonts lack them), a turned icon instead
        local oldGhost, oldFacing = UnitIsGhost, GetPlayerFacing
        UnitIsGhost, GetPlayerFacing = function() return true end, function() return 0 end
        local oldMap, oldDeath = C_Map, C_DeathInfo
        C_Map = setmetatable({ GetBestMapForUnit = function() return 1 end,
            GetPlayerMapPosition = function() return { x = 0.5, y = 0.5 } end,
            GetWorldPosFromMapPos = function(_, p) return 1, { x = p.x * 1000, y = p.y * 1000 } end }, { __index = oldMap })
        C_DeathInfo = { GetCorpseMapPosition = function() return { x = 0.6, y = 0.5 } end }
        local ctext = m.corpse.update()
        assert(not ctext:find("[\128-\255]") and ctext:find("%d"), "corpse text: " .. ctext)
        local cicon = m.corpse.getIcon()
        assert(type(cicon) == "table" and cicon.rotation, "corpse arrow icon")
        UnitIsGhost, GetPlayerFacing, C_Map, C_DeathInfo = oldGhost, oldFacing, oldMap, oldDeath
        -- "Show the value" unchecked: the icon alone; the name when the icon is hidden too
        local fcfg = ns.db.blocks.fps
        fcfg.showValue = false
        ns:ApplyStyle("fps"); ns:UpdateBlock("fps")
        assert(ns.frames.fps.iconOnly or not fcfg.showIcon, "icon alone")
        fcfg.showIcon = false
        ns:ApplyStyle("fps"); ns:UpdateBlock("fps")
        assert(tostring(ns.frames.fps.lastText):find(ns:GetBlockName("fps"), 1, true), "name when no icon: " .. tostring(ns.frames.fps.lastText))
        fcfg.showValue, fcfg.showIcon = true, true
        fcfg.textShadow = true; ns:UpdateBlock("fps"); fcfg.textShadow = false; ns:UpdateBlock("fps") -- text shadow on, off
        ns:ApplyStyle("fps"); ns:UpdateBlock("fps")
        -- micro-menu count: hidden when every menu is open, unless "always"
        if m.microMenu then
            local mt = m.microMenu.update({ microCount = "always" })
            assert(mt:find("/"), "micro count always: " .. mt)
        end
        m.durability.tooltip(GameTooltip, ns.db.blocks.durability)
        -- bags tooltip with a herb bag listed apart
        local oldC = C_Container
        C_Container = setmetatable({
            GetContainerNumSlots = function(bag) return bag <= 1 and 16 or 0 end,
            GetContainerNumFreeSlots = function(bag) if bag == 1 then return 12, 32 end return 0, 0 end,
            GetContainerItemInfo = function() return nil end,
            GetBagName = function(bag) return bag == 1 and "Herb Pouch" or "Backpack" end,
        }, { __index = oldC })
        local lines = {}
        local tt = setmetatable({ AddLine = function(_, t) lines[#lines + 1] = t end,
            AddDoubleLine = function(_, l) lines[#lines + 1] = l end }, { __index = GameTooltip })
        m.bags.tooltip(tt)
        local title, after = nil, false
        for i, t in ipairs(lines) do
            if t == ns.L.TT_PROFESSION_BAGS then title = i end
            if title and t == "Herb Pouch" then after = true end
        end
        assert(title and after, "herb bag listed under its own title")
        C_Container = oldC
    end,
    -- a little life (2.0.0): glow on hover, gliding values, thin progress bar; the four new
    -- styles turn them on, any other style off; Fewer animations stops the motion
    function()
        assert(ns:ApplyTheme("hdGold"))
        local cfg, f = ns.db.blocks.durability, ns.frames.durability
        assert(cfg.hoverGlow and cfg.valueGlide and cfg.progressLook == "thin", "the new styles' effects")
        assert(cfg.progressBar and cfg.progressByStyle, "thin bar turned on by the style")
        ns:ApplyStyle("durability")
        assert(f.barThin and f.barTrack and f.hoverGlowPieces, "thin bar and glow pieces")
        -- gliding: colors and pictures stay whole, only the digits move
        f.glide, f.glideLast = nil, "|cff00ff0050|r / 100 |TInterface\\Icons\\x:0|t"
        ns.SetBlockText(f, cfg, "|cff00ff0080|r / 100 |TInterface\\Icons\\x:0|t")
        assert(f.glide and #f.glide.to == 2 and f.glide.to[1].value == 80, "a number glides")
        local parts = 0
        for _, part in ipairs(f.glide.parts) do if type(part) == "string" and part:find("|cff00ff00", 1, true) then parts = parts + 1 end end
        assert(parts == 1, "the color code stays whole")
        -- a decimal counts as one number and keeps its decimals; a time never glides
        f.glide, f.glideLast = nil, "62.9%"
        ns.SetBlockText(f, cfg, "63.0%")
        assert(f.glide and #f.glide.to == 1 and f.glide.to[1].decimals == 1, "decimal number")
        f.glide, f.glideLast = nil, "1:05"
        ns.SetBlockText(f, cfg, "1:04")
        assert(not f.glide and f.text:GetText() == "1:04", "a time is written at once")
        -- a bar the block has anyway (XP) is not the style's
        assert(ns:GetBlockDefaults("xp").progressByStyle == false, "XP's own bar")
        -- another shape (a word changed): at once
        ns.SetBlockText(f, cfg, "N/A")
        assert(not f.glide, "a text that changes shape is written at once")
        -- Fewer animations: no glide, no glow
        ns.sv.reduceMotion = true
        f.glideLast = "10 / 100"
        ns.SetBlockText(f, cfg, "20 / 100")
        assert(not f.glide, "fewer animations: no glide")
        ns.GlowTo(f, 1)
        assert(not f.glowTarget, "fewer animations: no glow")
        ns.sv.reduceMotion = false
        ns.GlowTo(f, 1)
        assert(f.glowTarget == 1, "glow on hover")
        -- a player's own bar stays when the style changes; the style's own goes away
        ns.db.blocks.bags.progressBar, ns.db.blocks.bags.progressByStyle = true, false
        assert(ns:ApplyTheme("flat"))
        assert(not cfg.hoverGlow and not cfg.valueGlide and cfg.progressLook == "fill", "other style: effects off")
        assert(cfg.progressBar == false and not cfg.progressByStyle, "the style's bar goes away")
        assert(ns.db.blocks.bags.progressBar == true, "the player's bar stays")
        ns:ApplyStyle("durability")
        assert(not f.barThin and not f.barTrack:IsShown(), "band again")
        ns.db.blocks.bags.progressBar = false
    end,
    -- HD icons (2.0.0): the game's drawing in a ring over the block's icon, which stays in
    -- place; a block without a drawing, or a client without the atlas, keeps its usual icon
    function()
        local oldTex = C_Texture
        C_Texture = setmetatable({ GetAtlasInfo = function(a)
            return (a:find("^gamepad%-radial%-icon%-") or a:find("^Cursor_.*_128$")) and { width = 91, height = 128 } or nil
        end }, { __index = oldTex or {} })
        local cfg = ns.db.blocks.gold
        -- off for now (27/11): a block saved with HD icons by a test build draws its usual icon
        assert(ns.HD_ICONS_ON == false, "HD icons are off")
        cfg.iconSet, cfg.enabled, cfg.showIcon = "hd", true, true
        ns:ApplyStyle("gold")
        assert(not (ns.frames.gold.hdIcon and ns.frames.gold.hdIcon:IsShown()), "HD off: usual icon")
        cfg.iconSet = "classic"
        ns.HD_ICONS_ON = true
        cfg.enabled, cfg.showIcon = true, true
        ns:ApplyStyle("gold")
        local f = ns.frames.gold
        assert(not (f.hdIcon and f.hdIcon:IsShown()), "usual icons by default")
        local shape = cfg.iconShape
        cfg.iconShape = "round"
        for _, set in ipairs({ "hd", "hdTint" }) do
            cfg.iconSet = set
            ns:ApplyStyle("gold")
            ns:UpdateBlock("gold")
            assert(f.hdIcon and f.hdIcon:IsShown() and f.hdIconRing:IsShown(), set .. ": HD icon in its ring")
        end
        -- the drawing keeps its proportions inside the ring
        local w, h = f.hdIcon.__w, f.hdIcon.__h
        assert(w and h and h > 0 and math.abs(w / h - 91 / 128) < 0.01, "HD icon not stretched")
        assert(f.icon:GetAlpha() == 0, "usual icon hidden under the HD one")
        -- HD icons take the block's height but 2 px on each side (27/11: they looked tiny)
        assert(f.iconSize >= cfg.height - 4, "HD icon size follows the whole height")
        -- the icon frame shapes the HD icon (27/11): square frame, round ring, or the drawing alone
        cfg.iconShape = "square"
        ns:ApplyStyle("gold")
        assert(f.hdIconRing:GetTexture():find("hd_box", 1, true) and f.hdIconRing:IsShown(), "square frame")
        cfg.iconShape = "round"
        ns:ApplyStyle("gold")
        assert(f.hdIconRing:GetTexture():find("hd_ring", 1, true), "round ring")
        cfg.iconShape = "none"
        ns:ApplyStyle("gold")
        assert(f.hdIcon:IsShown() and not f.hdIconRing:IsShown() and not f.hdIconDisc:IsShown(), "no frame: the drawing alone")
        cfg.iconShape = "round"
        ns:ApplyStyle("gold")
        assert(f.hdIconRing:IsShown(), "ring for the next checks")
        -- tinted: the class color of the text; a dark tint gets a light disc
        cfg.classColorText = true
        ns:ApplyStyle("gold")
        cfg.classColorText = false
        local oldTint = cfg.textTint
        cfg.textTint = { r = 0.1, g = 0.06, b = 0.025, a = 1 }
        ns:ApplyStyle("gold")
        cfg.textTint = oldTint
        cfg.iconSet = "classic"
        ns:ApplyStyle("gold")
        assert(f.icon:GetAlpha() == 1 and not f.hdIcon:IsShown(), "back to the usual icon")
        cfg.iconSet = "hd"
        ns:ApplyStyle("gold")
        -- no drawing for this block: its usual icon
        local fps = ns.db.blocks.fps
        fps.iconSet, fps.enabled, fps.showIcon = "hd", true, true
        ns:ApplyStyle("fps")
        assert(not (ns.frames.fps.hdIcon and ns.frames.fps.hdIcon:IsShown()), "fps keeps its icon")
        -- an older client without the atlas: usual icon
        C_Texture = oldTex
        ns:ApplyStyle("gold")
        assert(not f.hdIcon:IsShown(), "no atlas: usual icon")
        -- icon turned off: no ring left behind
        C_Texture = setmetatable({ GetAtlasInfo = function() return { width = 128, height = 128 } end }, { __index = oldTex or {} })
        cfg.showIcon = false
        ns:ApplyStyle("gold")
        assert(not f.hdIcon:IsShown() and not f.hdIconRing:IsShown() and f.icon:GetAlpha() == 1, "icon hidden: no ring")
        cfg.showIcon, cfg.iconSet, fps.iconSet, cfg.iconShape = true, "classic", "classic", shape
        ns.HD_ICONS_ON = false
        ns:ApplyStyle("gold")
        ns:ApplyStyle("fps")
        C_Texture = oldTex
    end,
    -- expansion styles: their art frame on a large window only; a small window (the placement
    -- banner) takes the plain frame; under the art, a solid base hides what is behind
    function()
        local oldTex, oldTheme = C_Texture, ns.db.theme
        C_Texture = setmetatable({ GetAtlasInfo = function(a) return a:find("^ui%-frame%-") and { width = 64 } or nil end },
            { __index = oldTex or {} })
        ns.db.theme = "warWithin"
        local big = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        big:SetSize(800, 600)
        big.keepThemeSkin = true -- (a list under the mouse: the style's own window)
        ns:SkinWindow(big)
        assert(big.skinKind == "atlas" and big.tesseraArtBase, "large window: art frame with a solid base")
        local small = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        small:SetSize(500, 110)
        small.keepThemeSkin = true
        ns:SkinWindow(small)
        assert(small.skinKind ~= "atlas", "small window: plain frame (" .. tostring(small.skinKind) .. ")")
        -- ...in the style's dark color, not the art's white tint (the banner came out white)
        local bg = ns:GetThemeInfo("warWithin").window().bg
        assert(bg and (bg[1] or bg.r) < 0.5, "small window: dark background")
        C_Texture, ns.db.theme = oldTex, oldTheme
    end,
    -- the bags block counts only bags that hold anything, not a herb bag's free slots
    function()
        local old = C_Container
        C_Container = {
            GetContainerNumSlots = function(bag) return bag <= 1 and 16 or 0 end,
            GetContainerNumFreeSlots = function(bag) if bag == 1 then return 12, 32 end return 0, 0 end,
            GetContainerItemInfo = function() return nil end,
        }
        local bags = ns.modules.bags
        assert(bags.update({ bagsFormat = "free" }) == "0", "no free slot left: " .. bags.update({ bagsFormat = "free" }))
        assert(bags.update({ bagsFormat = "usedTotal" }) == ns.L.BAGS_FORMAT:format(16, 16), "full backpack only")
        assert(bags.progress() == 1, "bar full")
        C_Container = old
    end,
    -- a hidden block docked under another (empty mail under Legacy) does not keep it wide
    function()
        ns:ResetProfile("top")
        local top, below = "fps", "mail"
        ns.db.blocks[below].enabled, ns.db.blocks[top].enabled = true, true
        ns.db.blocks[below].dock = { to = top, side = "BOTTOM" }
        ns.db.blocks[below].slotW = 300 -- the width it had while showing "New mail"
        ns:UpdateLayout()
        ns.frames[below]:Hide()
        ns:UpdateLayout()
        assert(ns.frames[top]:GetWidth() < 300, "the visible block keeps its own width: "
            .. ns.frames[top]:GetWidth())
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
    -- one group's style at once (1.2): group entries in "Blocks to set up",
    -- "Copy style to group" (options and quick menu), undo
    function()
        ns:ResetProfile("top")
        local L = ns.L
        -- a shown option widget: a button by its text, or a check box by its label
        local function Widget(kind, text)
            for _, f in ipairs(MOCK_FRAMES) do
                if f.__kind == kind and f.__shown and f.__text == text then return f end
            end
        end
        -- (a check box's label is a font string it made: the mock keeps them)
        local function Check(label)
            for _, f in ipairs(MOCK_FRAMES) do
                if f.__kind == "CheckButton" and f.__shown then
                    for _, fs in ipairs(f.__fontStrings or {}) do
                        if fs.__text == label then return f end
                    end
                end
            end
        end
        local groups = ns:ListStyleGroups()
        assert(#groups >= 1, "the ready-made bar is a group")
        local g = groups[1]
        assert(g.keys[1] == g.head and ns:GetVisualRoot(g.keys[2]) == g.head, "head block first")
        local members, inGroup = {}, {}
        for _, k in ipairs(g.keys) do
            inGroup[k] = true
            if not ns.IsSpacerKey(k) then table.insert(members, k) end
        end
        local outside
        for _, k in ipairs(ns:GetBlockKeys()) do
            if not inGroup[k] and not ns.IsSpacerKey(k) then outside = k break end
        end
        assert(outside, "a block outside the group")
        for _, k in ipairs(ns:GetBlockKeys()) do ns.db.blocks[k].showIcon = true end
        -- the group selected in the options: a setting changes its blocks only
        ns:OpenOptionsFor("*group:" .. g.head)
        ns:RefreshOptions()
        local icon = Check(L.SHOW_ICON)
        assert(icon, "the Display settings are offered for a group")
        icon:GetScript("OnClick")(icon) -- the mock's check box reads unchecked
        for _, k in ipairs(members) do assert(ns.db.blocks[k].showIcon == false, "group member changed: " .. k) end
        assert(ns.db.blocks[outside].showIcon == true, "a block outside the group keeps its setting")
        assert(L.GROUP_ENTRY:format("x") ~= "" and L.GROUPS_TITLE, "group texts exist")
        -- "Copy style to group" next to "Copy style to all", for a block in a group
        local src = members[2]
        local before = {}
        for i, k in ipairs(g.keys) do
            ns.db.blocks[k].fontSize = 8 + i
            before[k] = ns.db.blocks[k].fontSize
        end
        ns.db.blocks[src].fontSize, ns.db.blocks[outside].fontSize = 19, 11
        before[src] = 19
        ns:OpenOptionsFor(src)
        ns:RefreshOptions()
        local copyGroup = Widget("Button", L.COPY_STYLE_GROUP)
        assert(copyGroup, "Copy style to group shown for a block in a group")
        copyGroup:GetScript("OnClick")(copyGroup)
        for _, k in ipairs(g.keys) do assert(ns.db.blocks[k].fontSize == 19, "style copied to " .. k) end
        assert(ns.db.blocks[outside].fontSize == 11, "a block outside the group keeps its look")
        ns:Undo()
        for _, k in ipairs(g.keys) do
            assert(ns.db.blocks[k].fontSize == before[k], "undo gives the old look back: " .. k)
        end
        -- a block on its own: no button, nothing copied
        ns:Detach(outside)
        ns.db.blocks[outside].anchor = nil
        assert(#ns:GetStyleGroup(outside) == 0, "a detached block is alone")
        do
            assert(ns:CopyStyleToGroup(outside) == false, "nothing to copy to")
            ns:OpenOptionsFor(outside)
            ns:RefreshOptions()
            assert(not Widget("Button", L.COPY_STYLE_GROUP), "no group button for a lone block")
        end
        -- the quick menu offers the same action
        local oldMenu, items = MenuUtil, {}
        local function Node()
            local n = {}
            local function Add(text, fn) items[text] = fn or true return Node() end
            n.CreateTitle, n.CreateDivider = function() end, function() end
            n.CreateButton = function(_, text, fn) return Add(text, fn) end
            n.CreateRadio = function(_, text) return Add(text) end
            n.CreateCheckbox = function(_, text) return Add(text) end
            n.SetScrollMode = function() end
            return n
        end
        MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, Node()) end }
        ns:OpenQuickMenu(src)
        MenuUtil = oldMenu
        assert(type(items[L.MENU_COPY_STYLE_GROUP]) == "function", "quick menu: copy this style to the group")
        -- the group entry follows its group, and goes when the group does
        ns:OpenOptionsFor("*group:" .. g.head)
        for _, k in ipairs(g.keys) do if k ~= g.head then ns:Detach(k) end end
        ns:RefreshOptions() -- falls back to "All blocks" without an error
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
    -- friends: the count in the color of your status; WoW and Battle.net friends in the tooltip
    function()
        local oldFL, oldBN, oldInfo, oldC = C_FriendList, BNGetNumFriends, BNGetInfo, C_BattleNet
        C_FriendList = { GetNumOnlineFriends = function() return 1 end, GetNumFriends = function() return 2 end,
            GetFriendInfoByIndex = function(i)
                return i == 1 and { connected = true, name = "Tilda", level = 30, className = "Mage", area = "Orgrimmar", afk = true, notes = "my cousin" }
                    or { connected = false, name = "Away" }
            end }
        BNGetNumFriends = function() return 2, 2 end
        _G.BNET_CLIENT_WOW = "WoW"
        C_BattleNet = { GetFriendAccountInfo = function(i)
            if i == 1 then
                return { accountName = "Kaz", isAFK = false, isDND = true, gameAccountInfo = { isOnline = true,
                    clientProgram = "WoW", characterName = "Zug", characterLevel = 42, areaName = "Tanaris" }, note = "raid lead" }
            end
            return { accountName = "Mo", gameAccountInfo = { isOnline = true, clientProgram = "App", richPresence = "In the app" } }
        end }
        local m = ns.modules.friends
        BNGetInfo = function() return 1, "Me#1", 1, "", false, false, true, false end
        assert(m.update({}):find("^|cff4ce64c3|r$"), "available: green 3 -> " .. m.update({}))
        BNGetInfo = function() return 1, "Me#1", 1, "", true, false, true, false end
        assert(m.update({}):find("ffff9933"), "away: orange")
        BNGetInfo = function() return 1, "Me#1", 1, "", false, true, true, false end
        assert(m.update({}):find("ffff4040"), "busy: red")
        BNGetInfo = function() return 1, "Me#1", 1, "", false, false, true, true end
        assert(m.update({}):find("ff9a9a9a"), "appear offline: gray")
        assert(m.update({ statusColor = false }) == "3", "status color off")
        local lines = {}
        local tt = setmetatable({ AddLine = function(_, t) table.insert(lines, tostring(t)) end,
            AddDoubleLine = function(_, a, b) table.insert(lines, tostring(a) .. " | " .. tostring(b)) end },
            { __index = function() return function() end end })
        m.tooltip(tt, {})
        local all = table.concat(lines, "\n")
        assert(all:find(ns.L.TT_MY_STATUS, 1, true), "status in words")
        assert(all:find("Tilda (30) " .. ns.L.TT_AFK_TAG, 1, true), "WoW friend with away tag")
        assert(all:find("Kaz : Zug (42) " .. ns.L.TT_DND_TAG, 1, true) and all:find("Tanaris", 1, true), "BNet friend in WoW")
        assert(all:find("Mo", 1, true) and all:find("In the app", 1, true), "BNet friend elsewhere")
        lines = {}
        m.tooltip(tt, { noBNetFriends = true })
        assert(not table.concat(lines, "\n"):find("Kaz", 1, true), "no Battle.net friends when left out")
        -- (1.5) notes, Battle.net friends in WoW only, tooltip parts, sort
        local function Tip(cfg)
            lines = {}
            m.tooltip(tt, cfg)
            return table.concat(lines, "\n")
        end
        all = Tip({})
        assert(not all:find("my cousin", 1, true) and not all:find("raid lead", 1, true), "notes are off by default")
        all = Tip({ friendsNotes = true })
        assert(all:find("my cousin - Orgrimmar", 1, true) and all:find("raid lead - Tanaris", 1, true), "friend notes before the zone")
        assert(not Tip({ friendsWoWOnly = true }):find("In the app", 1, true), "WoW only hides the other games")
        assert(not Tip({ friendsTipWoW = false }):find("Tilda", 1, true), "WoW friends part off")
        assert(not Tip({ friendsTipBNet = false }):find("Kaz", 1, true), "Battle.net part off")
        assert(not Tip({ friendsTipStatus = false }):find(ns.L.TT_MY_STATUS, 1, true), "status part off")
        all = Tip({ friendsSort = "level" })
        assert(all:find("Kaz", 1, true) < all:find("Mo", 1, true), "level sort: highest first")
        all = Tip({ friendsSort = "zone" })
        assert(all:find("Mo", 1, true) < all:find("Kaz", 1, true), "zone sort")
        -- (1.6) the clickable friends list: the same friends, whisper, invite, search
        local fl, online, total = ns.FriendsOnline({})
        assert(#fl == 3 and online == 3 and total == 4, "friends online: WoW and Battle.net")
        assert(#ns.FriendsOnline({ noBNetFriends = true }) == 1 and #ns.FriendsOnline({ friendsWoWOnly = true }) == 2, "the block's settings choose the friends")
        assert(m.defaults.friendsShow == "list", "the list is the default")
        local block = CreateFrame("Frame", nil, UIParent)
        assert(not m.hoverList(block, { friendsShow = "tooltip" }), "tooltip setting: the normal tooltip")
        assert(m.hoverList(block, { friendsShow = "list", friendsNotes = true }), "list setting: the list takes its place")
        local flist = _G["TesseraFriendsList"]
        assert(flist and flist:IsShown() and flist.rows[3]:IsShown() and not flist.rows[4]:IsShown(), "3 rows for 3 friends")
        local savedUtil, savedParty = ChatFrameUtil, C_PartyInfo
        local told, bnTold, invited
        ChatFrameUtil = { SendTell = function(n) told = n end, SendBNetTell = function(n) bnTold = n end }
        C_PartyInfo = { InviteUnit = function(n) invited = n end }
        flist.rows[1]:GetScript("OnClick")(flist.rows[1], "RightButton")
        assert(invited == "Tilda", "a right click invites the WoW friend: " .. tostring(invited))
        flist.rows[2]:GetScript("OnClick")(flist.rows[2], "LeftButton")
        assert(bnTold == "Kaz" and not flist:IsShown(), "a click whispers a Battle.net friend by account name")
        m.hoverList(block, { friendsShow = "list" })
        flist.rows[1]:GetScript("OnClick")(flist.rows[1], "LeftButton")
        assert(told == "Tilda", "a click whispers a WoW friend")
        m.hoverList(block, { friendsShow = "list" })
        flist.box:SetText("Zug")
        flist.box:GetScript("OnTextChanged")(flist.box)
        assert(flist.rows[1]:IsShown() and flist.rows[1].friend.name == "Kaz" and not flist.rows[2]:IsShown(), "the search finds a character name")
        flist:GetScript("OnUpdate")(flist, 0.2)
        flist:GetScript("OnUpdate")(flist, 0.2)
        assert(not flist:IsShown(), "the list closes once the mouse stayed away")
        ChatFrameUtil, C_PartyInfo = savedUtil, savedParty
        -- (1.6) the list shows what the tooltip shows: your status, notes in the right column, the
        -- tooltip's tags, the game's friends first then Battle.net's
        local fl2, _, _, status2 = ns.FriendsOnline({ friendsNotes = true })
        assert(status2 and status2:find(ns.L.TT_MY_STATUS, 1, true), "your status comes with the list")
        assert(not select(4, ns.FriendsOnline({ friendsTipStatus = false })), "status part off: no status")
        assert(fl2[1].kind == "wow" and fl2[2].kind == "bnet", "the game's friends come before Battle.net's")
        assert(fl2[1].right == "my cousin - Orgrimmar" and fl2[2].right == "raid lead - Tanaris", "the note comes before the zone")
        assert(ns.FriendsOnline({})[1].right == "Orgrimmar", "no note unless asked")
        m.hoverList(block, { friendsShow = "list", friendsNotes = true })
        assert(flist.rows[1].zone:GetText():find("my cousin - Orgrimmar", 1, true), "the list row shows note and zone: " .. tostring(flist.rows[1].zone:GetText()) .. " / " .. tostring(flist.rows[1].friend and flist.rows[1].friend.right))
        assert(flist.rows[1].name:GetText():find(ns.L.TT_AFK_TAG, 1, true), "the tooltip's away tag in the list")
        flist:Hide()
        -- (1.6) the Shift + click menu: copy, add friend, /who, ignore (not for yourself)
        local entries = {}
        local root = { CreateButton = function(_, label, fn) entries[#entries + 1] = label entries[label] = fn end }
        local oldFL2, oldUtil2 = C_FriendList, ChatFrameUtil
        local added, ignored, opened
        C_FriendList = { AddFriend = function(n) added = n end, IsFriend = function() return false end,
            SendWho = function() end, AddIgnore = function(n) ignored = n end, IsIgnored = function() return false end }
        ChatFrameUtil = { OpenChat = function(t) opened = t end }
        ns.AddPlayerMenuEntries(root, "Zug", "Kaz", false)
        assert(#entries == 4, "four extra menu entries: " .. #entries)
        entries[ns.L.MENU_COPY_NAME]() entries[ns.L.MENU_ADD_FRIEND]() entries[ns.L.MENU_IGNORE]()
        assert(opened == "Zug" and added == "Zug" and ignored == "Zug", "copy, add friend and ignore use the character name")
        entries = {}
        ns.AddPlayerMenuEntries(root, nil, "Mo", false)
        assert(#entries == 1, "a Battle.net friend outside WoW: copy only")
        entries = {}
        ns.AddPlayerMenuEntries(root, "Me", "Me", true)
        assert(#entries == 1, "yourself: copy only")
        C_FriendList, ChatFrameUtil = oldFL2, oldUtil2
        -- (1.6.1) a list keeps the tooltip's neutral colors, not the tint of the last unit shown
        local oldTip = GameTooltip
        local function Piece(r, g, b) local p = { c = { r, g, b, 1 } }
            function p.GetVertexColor(self) return unpack(self.c) end
            function p.SetVertexColor(self, ...) self.c = { ... } end
            return p end
        local nine = {}
        for _, n in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge",
                             "BottomEdge", "LeftEdge", "RightEdge", "Center" }) do nine[n] = Piece(1, 0.96, 0.41) end
        local unit
        GameTooltip = setmetatable({ NineSlice = nine, GetUnit = function() return unit end }, { __index = oldTip })
        ns.CaptureTooltipLook()
        unit = "npc"
        for _, p in pairs(nine) do p.c = { 0, 1, 0, 1 } end -- the game tints it green for a friendly unit
        ns.CaptureTooltipLook()
        assert(nine.TopEdge.c[2] == 1, "the tooltip itself is green now")
        local list = { tesseraTipNine = true }
        for n in pairs(nine) do list[n] = Piece(0, 0, 0) end
        local oldNSU = NineSliceUtil
        NineSliceUtil = { ApplyLayoutByName = function() return true end }
        ns.ApplyTooltipLook(list)
        NineSliceUtil = oldNSU
        GameTooltip = oldTip
        local r, g = unpack(list.TopEdge.c)
        assert(r == 1 and g == 0.96, "the list keeps the neutral gold border, not the green tint: " .. tostring(r) .. "," .. tostring(g))
        -- (1.6) the blue click hints of the tooltip go under the lists too (unless the player turned them off)
        local hints = ns:BlockHints("friends", ns.db.blocks.friends)
        assert(hints[1] == ns.L.HINT_FRIENDS and hints[#hints] == ns.L.HINT_QUICK_MENU, "block hints: its click, then the quick menu")
        local two = ns:ListHintText({ "row" }, "friends", ns.db.blocks.friends)
        assert(two:find(ns.L.HINTS_IN_LIST, 1, true) and two:find(ns.L.HINTS_ON_BLOCK, 1, true)
            and two:find(ns.L.HINTS_IN_LIST, 1, true) < two:find(ns.L.HINTS_ON_BLOCK, 1, true), "list hints: in the list, then on the block")
        ns.db.tooltipHints = false
        assert(#ns:BlockHints("friends", ns.db.blocks.friends) == 0, "hints off: no hint lines")
        assert(ns:ListHintText({ "row" }, "friends", ns.db.blocks.friends) == "", "hints off: no list help")
        ns.db.tooltipHints = nil
        -- (1.6) preview mode: made-up players in every list
        ns.previewMode = true
        local pf, pOnline, pTotal = ns.FriendsOnline({})
        assert(#pf == 7 and pOnline == 7 and pTotal > pOnline, "preview: made-up friends")
        assert(#ns.FriendsOnline({ friendsWoWOnly = true }) == 6, "preview: the settings still apply")
        assert(#ns.GuildMembers({}) == 24, "preview: made-up guild members")
        local raidList = ns.GroupMembers({})
        assert(#raidList == 20, "preview: a made-up raid")
        local sortedByGroup = true
        for i = 2, #raidList do if raidList[i].group < raidList[i - 1].group then sortedByGroup = false end end
        assert(sortedByGroup and raidList[1].zone:find(ns.L.GROUPLIST_GROUP:format(1), 1, true), "a raid is sorted by group, the group shown")
        assert(m.hoverList(block, { friendsShow = "list" }), "preview: the friends list opens")
        flist:Hide()
        assert(ns.modules.guild.hoverList(block, { guildShow = "list" }), "preview: the guild list opens without a guild")
        assert(_G["TesseraGuildList"]:IsShown(), "preview: the guild list is shown")
        _G["TesseraGuildList"]:Hide()
        assert(ns.modules.group.hoverList(block, { groupShow = "list" }), "preview: the group list opens without a group")
        _G["TesseraGroupList"]:Hide()
        -- (1.9) Volume list and presets: four named slots, kept for the whole account
        do
            local cvars = { Sound_MasterVolume = "0.7", Sound_MusicVolume = "0.4", Sound_SFXVolume = "0.8",
                Sound_AmbienceVolume = "0.5", Sound_DialogVolume = "1", Sound_EnableAllSound = "1" }
            local oldGet, oldSet = GetCVar, SetCVar
            GetCVar = function(n) return cvars[n] end
            SetCVar = function(n, v) cvars[n] = tostring(v) end
            -- two output devices, numbered from 0 like the game's own sound options do
            local oldNum, oldName = Sound_GameSystem_GetNumOutputDrivers, Sound_GameSystem_GetOutputDriverNameByIndex
            local drivers = { [0] = "Primary Sound Driver", [1] = "Headset" }
            -- a device named in Latin-1 (one byte per accent) is converted to UTF-8
            assert(ns.VolumePresets.Utf8Fix("St\233r\233o num\233rique") == "St\195\169r\195\169o num\195\169rique", "volume: Latin-1 names are converted")
            assert(ns.VolumePresets.Utf8Fix("St\195\169r\195\169o") == "St\195\169r\195\169o", "volume: UTF-8 names stay as they are")
            Sound_GameSystem_GetNumOutputDrivers = function() return 2 end
            Sound_GameSystem_GetOutputDriverNameByIndex = function(i) return drivers[i] end
            cvars.Sound_OutputDriverIndex = "0"
            local P = ns.VolumePresets
            ns.sv.volumePresets = nil
            assert(P and P.Count() == 0 and P.FreeSlot() == 1, "volume presets: none at first")
            P.Save(1, "  Solo  ")
            assert(P.Get(1).name == "Solo" and P.Get(1).vol[1] == 0.7 and P.Get(1).vol[5] == 1, "volume presets: a name and the five volumes")
            assert(P.Matches(1), "volume presets: the saved state matches")
            cvars.Sound_MusicVolume, cvars.Sound_MasterVolume = "0", "0.25"
            assert(not P.Matches(1), "volume presets: a changed volume no longer matches")
            P.Apply(1)
            assert(cvars.Sound_MusicVolume == "0.4" and cvars.Sound_MasterVolume == "0.7" and cvars.Sound_EnableAllSound == "1", "volume presets: apply restores the volumes")
            assert(P.Get(1).device == "Primary Sound Driver", "volume presets: the output device is kept")
            cvars.Sound_OutputDriverIndex = "1"
            assert(not P.Matches(1), "volume presets: another output device no longer matches")
            P.Apply(1)
            assert(cvars.Sound_OutputDriverIndex == "0", "volume presets: apply switches the output device back")
            cvars.Sound_MasterVolume = "0.35"
            P.Save(2, "Éééééééééééééééé") -- 16 accented letters: cut to 14 letters, not bytes
            local letters = 0
            for _ in P.Get(2).name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do letters = letters + 1 end
            assert(letters == 14, "volume presets: a name is cut to 14 characters, accents whole")
            cvars.Sound_EnableAllSound = "0"
            P.Save(3, "Quiet")
            assert(P.Get(3).muted == true, "volume presets: the muted state is kept")
            cvars.Sound_EnableAllSound = "1"
            P.Apply(3)
            assert(cvars.Sound_EnableAllSound == "0", "volume presets: apply mutes again")
            P.Save(4, "")
            assert(P.Get(4).name == ns.L.VOLUME_PRESET_DEFAULT:format(4) and P.FreeSlot() == nil and P.Count() == 4, "volume presets: four at most, a default name")
            P.Save(5, "x")
            assert(P.Count() == 4 and P.Get(5) == nil, "volume presets: no fifth slot")
            P.Rename(1, "   ")
            assert(P.Get(1).name == ns.L.VOLUME_PRESET_DEFAULT:format(1), "volume presets: an empty name gets the default")
            -- the block: the tooltip is kept unless the list is chosen, the options reach the presets
            local vol = ns.modules.volume
            assert(not vol.hoverList(block, { volumeShow = "tooltip" }), "volume: the tooltip is still a choice")
            assert(vol.defaults.volumeShow == "list", "volume: the default is the list")
            -- "Click on the block": the next preset, or mute (also when no preset exists)
            P.Apply(1)
            vol.onClick(nil, "LeftButton", { volumeClick = "next" })
            assert(cvars.Sound_MasterVolume == "0.35", "volume click: the next preset is applied")
            vol.onClick(nil, "LeftButton", { volumeClick = "next" })
            assert(cvars.Sound_EnableAllSound == "0", "volume click: then the next one (muted)")
            cvars.Sound_EnableAllSound = "1"
            vol.onClick(nil, "LeftButton", { volumeClick = "mute" })
            assert(cvars.Sound_EnableAllSound == "0", "volume click: the default mutes")
            cvars.Sound_EnableAllSound = "1"
            assert(vol.clickHintFor({ volumeClick = "next" }) == ns.L.HINT_VOLUME_NEXT and vol.clickHintFor({}) == nil,
                "volume click: the hint follows the setting")
            -- "Block text": the preset name when the sound matches one exactly
            local active = P.Get(2).name
            assert(vol.update({ volumeText = "volume" }) == "35%" and vol.update({}) == "35%", "volume text: the volume alone by default")
            assert(vol.update({ volumeText = "both" }) == active .. " 35%", "volume text: name and volume")
            assert(vol.update({ volumeText = "name" }) == active, "volume text: the name alone")
            cvars.Sound_MusicVolume = "0.9"
            assert(vol.update({ volumeText = "both" }) == "35%" and vol.update({ volumeText = "name" }) == "35%", "volume text: no preset matches, only the volume")
            cvars.Sound_MusicVolume = "0.4"
            assert(P.ActiveName() == active, "volume text: the active name returns")
            cvars.Sound_EnableAllSound = "0"
            assert(vol.update({ volumeText = "both" }) == ns.L.MUTED, "volume text: muted stays first")
            cvars.Sound_EnableAllSound = "1"
            assert(vol.hoverList(block, { volumeShow = "list" }), "volume: the list opens")
            local vlist = _G["TesseraVolumeList"]
            assert(vlist and vlist:IsShown(), "volume: the list is shown")
            ns:HideVolumeList()
            assert(not vlist:IsShown(), "volume: the list closes with the options window")
            local names, buttons = 0, 0
            for _, opt in ipairs(vol.options) do
                if opt.kind == "text" and opt.get then names = names + 1 end
                if opt.kind == "button" then buttons = buttons + 1 end
            end
            assert(names == 4 and buttons == 8, "volume: four names, four save and four delete buttons in the options")
            local nameOpt
            for _, opt in ipairs(vol.options) do if opt.field == "volumePreset1Name" then nameOpt = opt end end
            nameOpt.set("Stream")
            assert(P.Get(1).name == "Stream" and nameOpt.get() == "Stream", "volume options: a name renames the preset")
            P.Delete(1) P.Delete(2) P.Delete(3) P.Delete(4)
            assert(P.Count() == 0 and ns.sv.volumePresets == nil, "volume presets: deleting them all leaves nothing saved")
            vol.onClick(nil, "LeftButton", { volumeClick = "next" })
            assert(cvars.Sound_EnableAllSound == "0", "volume click: no preset, a click still mutes")
            cvars.Sound_EnableAllSound = "1"
            assert(vol.clickHintFor({ volumeClick = "next" }) == nil, "volume click: no preset, the mute hint stays")
            nameOpt.set("Fresh")
            assert(P.Get(1) and P.Get(1).name == "Fresh", "volume options: a name on an empty slot saves the current volumes")
            -- damaged saved data does not break the list
            ns.sv.volumePresets = { "oops", { name = "x" }, { name = "y", vol = {} } }
            assert(P.Count() == 1 and not P.Get(1) and not P.Get(2), "volume presets: damaged data is ignored")
            assert(vol.hoverList(block, { volumeShow = "list" }), "volume: the list opens with damaged data")
            ns:HideVolumeList()
            ns.sv.volumePresets = nil
            GetCVar, SetCVar = oldGet, oldSet
            Sound_GameSystem_GetNumOutputDrivers, Sound_GameSystem_GetOutputDriverNameByIndex = oldNum, oldName
        end
        ns.previewMode = nil
        C_FriendList, BNGetNumFriends, BNGetInfo, C_BattleNet = oldFL, oldBN, oldInfo, oldC
    end,
    -- whispers history: the last whispers stay after you answered, a clickable list replies and pins
    function()
        local mod = ns.modules.whispers
        local savedUtil = ChatFrameUtil
        local told
        ChatFrameUtil = { SendTell = function(n) told = n end }
        Fire("CHAT_MSG_WHISPER", "hello there, how are you doing today, I wanted to ask you something quite long", "Anna-Realm")
        Fire("CHAT_MSG_WHISPER_INFORM", "hi", "Anna-Realm")
        local history = ns.WhisperHistory({ whispersHistory = "10" })
        assert(#history == 1 and history[1].name == "Anna-Realm" and history[1].read, "answered, but still in the history")
        assert(history[1].text and history[1].text:find("hello"), "the start of the message is kept")
        Fire("CHAT_MSG_WHISPER", "one more", "Anna-Realm")
        Fire("CHAT_MSG_WHISPER", "and another", "Anna-Realm")
        assert(#ns.WhisperHistory({ whispersHistory = "10" }) == 3, "three whispers from one player are three entries")
        for i = 1, 25 do Fire("CHAT_MSG_WHISPER", "msg " .. i, "Player" .. i .. "-Realm") end
        assert(#ns.WhisperHistory({ whispersHistory = "20" }) == 20, "20 whispers at most")
        assert(#ns.WhisperHistory({ whispersHistory = "10" }) == 10, "the History setting gives 10")
        assert(#ns.WhisperHistory({ whispersHistory = "5" }) == 5, "the History setting gives 5")
        assert(ns.WhisperHistory({})[1].name == "Player25-Realm", "newest first")
        local saved = ns.sv.whisperHistory and next(ns.sv.whisperHistory) and ns.sv.whisperHistory[next(ns.sv.whisperHistory)]
        assert(saved and #saved == 20 and saved[#saved].name == "Player25-Realm", "the history is saved for a reload")
        assert(mod.isEmpty() == false, "unread whispers: the block is not empty")
        -- pin the oldest one shown: it stays, whatever comes after
        local oldest = ns.WhisperHistory({ whispersHistory = "20" })[20]
        ns.WhisperTogglePin(oldest)
        for i = 1, 25 do Fire("CHAT_MSG_WHISPER", "later " .. i, "Late" .. i .. "-Realm") end
        local pinnedFirst = ns.WhisperHistory({ whispersHistory = "5" })
        assert(#pinnedFirst == 6 and pinnedFirst[1] == oldest and oldest.pinned, "a pinned whisper stays, listed first")
        local block = CreateFrame("Frame", nil, UIParent)
        assert(not mod.hoverList(block, { whispersHover = "tooltip" }), "tooltip setting: the normal tooltip")
        assert(mod.hoverList(block, { whispersHover = "list", whispersHistory = "5" }), "list setting: the list takes its place")
        local list = _G["TesseraWhisperList"]
        assert(list and list:IsShown() and list.rows[6]:IsShown() and not list.rows[7]:IsShown(), "5 whispers and the pinned one")
        list.rows[2]:GetScript("OnClick")(list.rows[2], "LeftButton")
        assert(told == "Late25-Realm" and not list:IsShown(), "a click replies and closes the list")
        mod.hoverList(block, { whispersHover = "list", whispersHistory = "5" })
        list.rows[1]:GetScript("OnClick")(list.rows[1], "RightButton")
        assert(not oldest.pinned and list:IsShown(), "a right click unpins, the list stays open")
        -- (1.6) the row's small buttons: the star pins, the cross deletes on a second click
        local starRow = list.rows[3]
        local starEntry = starRow.entry
        starRow.pinButton:GetScript("OnClick")(starRow.pinButton)
        assert(starEntry.pinned, "the star pins the whisper")
        -- pinned, it moves to the top of the list: its star is on the first row now
        assert(list.rows[1].entry == starEntry, "a pinned whisper comes first")
        list.rows[1].pinButton:GetScript("OnClick")(list.rows[1].pinButton)
        assert(not starEntry.pinned, "the star unpins it")
        local beforeDel = #ns.WhisperHistory({ whispersHistory = "20" })
        local delRow = list.rows[3]
        delRow.del:GetScript("OnClick")(delRow.del)
        assert(#ns.WhisperHistory({ whispersHistory = "20" }) == beforeDel, "the first click on the cross only asks")
        delRow.del:GetScript("OnClick")(delRow.del)
        assert(#ns.WhisperHistory({ whispersHistory = "20" }) == beforeDel - 1, "the second click deletes")
        -- (1.6.1) the whispers list has the window look too
        list:Hide()
        ns:ShowWhisperList(CreateFrame("Frame", nil, UIParent), { whispersListLook = "window" })
        assert(list.skinKind ~= "tooltip", "whispers list: window look")
        list:Hide()
        ns:ShowWhisperList(CreateFrame("Frame", nil, UIParent), { whispersListLook = "tooltip" })
        assert(list.skinKind == "tooltip", "whispers list: back to the tooltip look")
        -- (1.6) Shift + click: the full menu (reply, invite, pin, delete, copy, friend, /who, ignore)
        local oldMenu, labels = MenuUtil, {}
        local node = { CreateTitle = function() end, CreateButton = function(_, label) labels[#labels + 1] = label end }
        MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, node) end }
        local shiftDown, oldFL3 = IsShiftKeyDown, C_FriendList
        IsShiftKeyDown = function() return true end
        C_FriendList = { AddFriend = function() end, SendWho = function() end, AddIgnore = function() end }
        list.rows[2]:GetScript("OnClick")(list.rows[2], "LeftButton")
        IsShiftKeyDown, MenuUtil, C_FriendList = shiftDown, oldMenu, oldFL3
        local menuText = table.concat(labels, "|")
        assert(menuText:find(ns.L.WHISPER_MENU_PIN, 1, true) and menuText:find(ns.L.WHISPER_MENU_DELETE, 1, true)
            and menuText:find(ns.L.MENU_WHO, 1, true) and menuText:find(ns.L.GUILDLIST_INVITE, 1, true), "whisper menu: " .. menuText)
        assert(list:IsShown(), "the menu keeps the list open")
        -- (1.6) Ctrl + click deletes one whisper (not a pinned one); Clear removes the loose ones
        local before = #ns.WhisperHistory({ whispersHistory = "20" })
        local ctrlDown = IsControlKeyDown
        IsControlKeyDown = function() return true end
        local victim = list.rows[3].entry
        list.rows[3]:GetScript("OnClick")(list.rows[3], "LeftButton")
        assert(#ns.WhisperHistory({ whispersHistory = "20" }) == before - 1 and not victim.pinned, "Ctrl + click deletes a whisper")
        local keep = ns.WhisperHistory({ whispersHistory = "20" })[1]
        ns.WhisperTogglePin(keep)
        list.rows[1]:GetScript("OnClick")(list.rows[1], "LeftButton")
        assert(keep.pinned and ns.WhisperHistory({ whispersHistory = "20" })[1] == keep, "Ctrl + click leaves a pinned whisper")
        IsControlKeyDown = ctrlDown
        list.clear:GetScript("OnClick")(list.clear)
        assert(#ns.WhisperHistory({ whispersHistory = "20" }) > 1, "the first click on Clear only asks")
        list.clear:GetScript("OnClick")(list.clear)
        local left = ns.WhisperHistory({ whispersHistory = "20" })
        assert(#left == 1 and left[1] == keep, "Clear removes everything except the pinned whispers")
        ns.WhisperTogglePin(keep)
        local tt = { lines = 0 }
        tt.AddLine = function() tt.lines = tt.lines + 1 end
        tt.AddDoubleLine = tt.AddLine
        Fire("CHAT_MSG_WHISPER", "one", "Aa-Realm") Fire("CHAT_MSG_WHISPER", "two", "Bb-Realm") Fire("CHAT_MSG_WHISPER", "three", "Cc-Realm")
        Fire("CHAT_MSG_WHISPER", "four", "Dd-Realm") Fire("CHAT_MSG_WHISPER", "five", "Ee-Realm")
        mod.tooltip(tt, { whispersHistory = "5" })
        assert(tt.lines >= 5, "the tooltip lists the history")
        list:GetScript("OnUpdate")(list, 0.2)
        list:GetScript("OnUpdate")(list, 0.2)
        assert(not list:IsShown(), "the list closes once the mouse stayed away")
        ChatFrameUtil = savedUtil
    end,
    -- clickable guild list (1.5.2): the click setting, the list, whisper, invite, search and scrolling
    function()
        local saved = { IsInGuild, GetNumGuildMembers, GetGuildRosterInfo, GetGuildInfo, C_GuildInfo, C_PartyInfo, ChatFrameUtil }
        IsInGuild = function() return true end
        GetNumGuildMembers = function() return 30, 30 end
        GetGuildInfo = function() return "The Mosaic" end
        local asked = 0
        C_GuildInfo = { GuildRoster = function() asked = asked + 1 end }
        GetGuildRosterInfo = function(i)
            return ("Member%02d-Realm"):format(i), "Member", 2, 10 + i, "Mage", i % 2 == 0 and "Orgrimmar" or "Tanaris", "",
                "", true, i == 3 and 1 or 0, "MAGE"
        end
        local told, invited
        ChatFrameUtil = { SendTell = function(n) told = n end }
        C_PartyInfo = { InviteUnit = function(n) invited = n end }
        local mod = ns.modules.guild
        assert(mod.defaults.guildShow == "list", "the member list is the default")
        assert(mod.secureMacro == "/click GuildMicroButton", "a click on the block still opens the guild window")
        local block = CreateFrame("Frame", nil, UIParent)
        assert(not mod.hoverList(block, { guildShow = "tooltip" }), "setting off: the normal tooltip")
        assert(mod.hoverList(block, { guildShow = "list" }), "setting on: the list takes the tooltip's place")
        local list = _G["TesseraGuildList"]
        assert(list and list:IsShown(), "the list opens")
        assert(asked == 1, "the roster is asked for when the list opens")
        mod.hoverList(block, { guildShow = "list" })
        assert(asked == 1, "hovering again does not ask the roster again")
        assert(#list.rows == 14 and list.rows[1]:IsShown() and list.rows[14]:IsShown(), "14 rows on screen for 30 members")
        assert(list.rows[1].member.name == "Member01-Realm", "first row: the first member")
        -- size settings: fewer rows and a bigger scale
        list:Hide()
        local scaled
        list.SetScale = function(_, v) scaled = v end
        mod.hoverList(block, { guildShow = "list", guildListRows = 9, guildListScale = 120 })
        assert(list.rows[9]:IsShown() and not list.rows[10]:IsShown(), "9 rows on screen")
        assert(math.abs((scaled or -1) - 1.2) < 0.001, "scale 120 percent, got " .. tostring(scaled))
        list:Hide()
        mod.hoverList(block, { guildShow = "list", guildListRows = 999, guildListScale = 500 })
        assert(#list.rows == 100 and scaled == 1.5, "rows and scale stay inside their limits")
        list:Hide()
        -- the tooltip's settings also drive the list: members shown, rank, count
        mod.hoverList(block, { guildShow = "list", guildMax = "5", guildTipRank = false, guildTipCount = false })
        assert(list.rows[14]:IsShown(), "the list ignores Members shown: it scrolls through everyone")
        -- the emblem of a guild that plays with Tessera: only with its addon loaded and its image found
        local oldGI2, oldAddOns = GetGuildInfo, C_AddOns
        GetGuildInfo = function() return "Forts Rêveurs" end
        C_AddOns = setmetatable({ IsAddOnLoaded = function(name) return name == "GuildSelfForever" end }, { __index = oldAddOns })
        assert(ns.GuildEmblem() and ns.GuildEmblem():find("GuildSelfForeverIcon", 1, true), "emblem with the guild and its addon")
        C_AddOns = setmetatable({ IsAddOnLoaded = function() return false end }, { __index = oldAddOns })
        assert(not ns.GuildEmblem(), "no emblem without the guild's addon")
        C_AddOns = setmetatable({ IsAddOnLoaded = function(name) return name == "GuildSelfForever" end }, { __index = oldAddOns })
        ns.sv.streamerMode = true
        assert(not ns.GuildEmblem(), "streamer mode: no emblem (it would show the guild)")
        -- (1.6.1) the four kinds: the guild name unchecked shows the guild and its emblem, players stay hidden
        ns.db.blocks.streamer.streamerGuild = false
        assert(ns.GuildEmblem(), "guild name not hidden: the emblem shows")
        assert(ns.BlockTools.Masked("The Mosaic", "guild") == "The Mosaic", "guild name shown")
        assert(ns.BlockTools.Masked("Ana") == ns.HIDDEN, "other players still hidden")
        assert(ns:IsStreamer("gold") and ns:IsStreamer("alts"), "gold and characters still hidden")
        ns.db.blocks.streamer.streamerGuild = true
        ns.sv.streamerMode = nil
        assert(ns.BlockTools.Masked("Ana") == "Ana", "streamer mode off: nothing hidden")
        -- (1.6.1) a first install starts with Essentials: one bar, every block always shown
        assert(ns.PRESETS[1] == "essentials", "Essentials is the first layout")
        ns:ResetProfile("essentials")
        local w, gl = ns.db.blocks.whispers, ns.db.blocks.guild
        assert(w.enabled and w.hideEmpty == false and gl.enabled and gl.hideEmpty == false, "Essentials: whispers and guild always shown")
        assert(not ns.db.blocks.mail.enabled, "Essentials: no second row")
        ns:ResetProfile("top")
        GetGuildInfo = function() return "The Mosaic" end
        assert(not ns.GuildEmblem(), "no emblem for another guild")
        GetGuildInfo, C_AddOns = oldGI2, oldAddOns
        assert(not mod.update({}):find("The Mosaic", 1, true), "no guild name in the block by default")
        assert(mod.update({ guildShowName = true }):find("The Mosaic", 1, true), "Show the guild name")
        ns.sv.streamerMode = true
        assert(not mod.update({ guildShowName = true }):find("The Mosaic", 1, true), "streamer mode hides the name in the block too")
        ns.sv.streamerMode = nil
        assert(list.rows[1].icon:IsShown(), "class icons on by default")
        -- (1.6.1) window look then tooltip look: the window skin is cleared first
        list:Hide()
        mod.hoverList(block, { guildShow = "list", guildListLook = "window" })
        assert(list.skinKind ~= "tooltip", "window look applied")
        list:Hide()
        mod.hoverList(block, { guildShow = "list", guildListLook = "tooltip" })
        assert(list.skinKind == "tooltip", "back to the tooltip look")
        list:Hide()
        mod.hoverList(block, { guildShow = "list" })
        list:Hide()
        mod.hoverList(block, { guildShow = "list", guildListIcons = false })
        assert(not list.rows[1].icon:IsShown(), "Class icons unchecked: no icon")
        list:Hide()
        mod.hoverList(block, { guildShow = "list", guildMax = "5", guildTipRank = false, guildTipCount = false })
        local opt
        for _, o in ipairs(ns.modules.guild.options) do if o.field == "guildMax" then opt = o end end
        assert(opt.shown({ guildShow = "list" }) == false and opt.shown({ guildShow = "tooltip" }), "Members shown only in tooltip mode")
        list.box:SetText("Member2")
        list.box:GetScript("OnTextChanged")(list.box)
        assert(list.rows[1]:IsShown() and list.rows[1].member.name:find("Member2"), "a search finds a member")
        list.box:SetText("")
        list.box:GetScript("OnTextChanged")(list.box)
        assert(not list.rows[1].rank:IsShown(), "no rank column when the tooltip hides ranks")
        assert(list.rows[1].note:IsShown(), "the note column follows the tooltip's note setting (on)")
        list:Hide()
        mod.hoverList(block, { guildShow = "list", guildTipNote = false })
        assert(not list.rows[1].note:IsShown(), "no note column when the tooltip hides notes")
        list:Hide()
        mod.hoverList(block, { guildShow = "list", guildMax = "5", guildTipRank = false, guildTipCount = false })
        assert(not tostring(list.title:GetText()):find("%d"), "no count in the title when the tooltip hides it")
        list:Hide()
        mod.hoverList(block, { guildShow = "list" })
        local click = list.rows[1]:GetScript("OnClick")
        click(list.rows[2], "LeftButton")
        assert(told == "Member02-Realm", "a click whispers the member: " .. tostring(told))
        assert(not list:IsShown(), "the list closes after a whisper")
        mod.hoverList(block, { guildShow = "list" })
        click(list.rows[4], "RightButton")
        assert(invited == "Member04-Realm" and list:IsShown(), "a right click invites and keeps the list open: " .. tostring(invited))
        -- search: name, zone, rank or note; the number of rows follows
        list.box:SetText("member2")
        list.box:GetScript("OnTextChanged")(list.box)
        assert(list.rows[1].member.name == "Member20-Realm" and list.rows[10].member and not list.rows[11].member,
            "search by name: 10 matches (Member20 to Member29)")
        list.box:SetText("zzz")
        list.box:GetScript("OnTextChanged")(list.box)
        assert(not list.rows[1].member and list.empty:IsShown(), "search without a match: no rows, a message")
        list.box:SetText("")
        list.box:GetScript("OnTextChanged")(list.box)
        -- scrolling: the wheel moves by 3, the first row follows
        list:GetScript("OnMouseWheel")(list, -1)
        assert(list.rows[1].member.name == "Member04-Realm", "the wheel scrolls three rows: " .. tostring(list.rows[1].member and list.rows[1].member.name))
        for _ = 1, 20 do list:GetScript("OnMouseWheel")(list, -1) end
        assert(list.rows[14].member.name == "Member30-Realm", "scrolling stops at the end of the list")
        -- a member who is not online does not show, and the list follows the block's sort
        GetGuildRosterInfo = function(i)
            return ("Member%02d-Realm"):format(i), "Member", 2, 10 + i, "Mage", "A", "", "", i ~= 1, 0, "MAGE"
        end
        ns.db.blocks.guild = ns.db.blocks.guild or {}
        local members = ns.GuildMembers({ guildSort = "level" })
        assert(#members == 29 and members[1].name == "Member30-Realm", "online members only, highest level first")
        -- the mouse is on neither the block nor the list: the list closes after a short moment
        mod.hoverList(block, { guildShow = "list" })
        assert(list:IsShown(), "the list is open again")
        list:GetScript("OnUpdate")(list, 0.2)
        assert(list:IsShown(), "a short moment off the list: it stays")
        list:GetScript("OnUpdate")(list, 0.2)
        assert(list:IsShown() == false, "the list closes once the mouse stayed away")
        IsInGuild = saved[1]; GetNumGuildMembers = saved[2]; GetGuildRosterInfo = saved[3]; GetGuildInfo = saved[4]
        C_GuildInfo = saved[5]; C_PartyInfo = saved[6]; ChatFrameUtil = saved[7]
    end,
    -- guild tooltip parts, item level and stats choices, time-left thresholds (1.5)
    function()
        local oldIn, oldNum, oldRoster, oldGI, oldInfo = IsInGuild, GetNumGuildMembers, GetGuildRosterInfo, C_GuildInfo, GetGuildInfo
        IsInGuild = function() return true end
        GetNumGuildMembers = function() return 3, 2 end
        GetGuildInfo = function() return "The Mosaic" end
        C_GuildInfo = { GetMOTD = function() return "Raid on Friday" end }
        GetGuildRosterInfo = function(i)
            if i == 1 then return "Ana-Realm", "Officer", 1, 60, "Mage", "Orgrimmar", "Alchemist", "", true, 0, "MAGE" end
            if i == 2 then return "Bob-Realm", "Member", 2, 50, "Priest", "Tanaris", "", "", false, 0, "PRIEST" end
            return "Cy-Realm", "Member", 2, 40, "Rogue", "Ungoro", "", "", true, 0, "ROGUE"
        end
        local lines = {}
        local tt = setmetatable({ AddLine = function(_, t) table.insert(lines, tostring(t)) end,
            AddDoubleLine = function(_, a, b) table.insert(lines, tostring(a) .. " | " .. tostring(b)) end },
            { __index = function() return function() end end })
        local function Tip(cfg)
            lines = {}
            ns.modules.guild.tooltip(tt, cfg)
            return table.concat(lines, "\n")
        end
        local all = Tip({})
        assert(all:find("The Mosaic | 2/3", 1, true), "guild header counter: " .. all)
        assert(all:find("Raid on Friday", 1, true), "message of the day")
        assert(all:find("Ana-Realm|r |cffffd100Officer|r |cffffffffAlchemist|r | Orgrimmar", 1, true), "level, name, rank, note, then the zone: " .. all)
        assert(all:find("|cffcccccc60|r ", 1, true), "the level comes first")
        assert(all:find("Cy-Realm|r |cffffd100Member|r | Ungoro", 1, true), "member without note")
        all = Tip({ guildTipMotd = false, guildTipCount = false, guildTipRank = false, guildTipNote = false })
        assert(not all:find("Raid", 1, true) and not all:find("2/3", 1, true) and not all:find("Officer", 1, true)
            and not all:find("Alchemist", 1, true) and all:find("Ana-Realm|r | Orgrimmar", 1, true), "every part off: " .. all)
        all = Tip({ guildSort = "level" })
        assert(all:find("Ana%-Realm.*Cy%-Realm"), "guild sort by level: " .. all)
        all = Tip({ guildSort = "name", guildLeaders = "2" })
        assert(all:find("Ana%-Realm.*Cy%-Realm"), "leaders first, then by name: " .. all)
        GetGuildRosterInfo = function(i)
            if i == 1 then return "Zed-Realm", "Member", 2, 70, "Mage", "A", "", "", true, 0, "MAGE" end
            if i == 2 then return "Ana-Realm", "Guild Master", 0, 10, "Priest", "B", "", "", true, 0, "PRIEST" end
            return "Cy-Realm", "Officer", 1, 40, "Rogue", "C", "", "", true, 0, "ROGUE"
        end
        all = Tip({ guildLeaders = "2", guildSort = "level" })
        assert(all:find("Ana%-Realm.*Cy%-Realm.*Zed%-Realm"), "guild master, officer, then the rest: " .. all:gsub("\n", " / "))
        all = Tip({ guildLeaders = "1", guildSort = "name" })
        assert(all:find("Ana%-Realm.*Cy%-Realm.*Zed%-Realm"), "top rank only: " .. all)
        all = Tip({ guildSort = "rank" })
        assert(all:find("Ana%-Realm.*Cy%-Realm.*Zed%-Realm"), "by rank: " .. all)
        -- "Members shown": the leaders on top do not count; the rest is cut and counted
        GetNumGuildMembers = function() return 8, 8 end
        GetGuildRosterInfo = function(i)
            if i == 1 then return "Gm-Realm", "Guild Master", 0, 60, "Mage", "A", "", "", true, 0, "MAGE" end
            if i == 2 then return "Off-Realm", "Officer", 1, 60, "Mage", "A", "", "", true, 0, "MAGE" end
            return "M" .. i .. "-Realm", "Member", 2, 10 + i, "Rogue", "B", "", "", true, 0, "ROGUE"
        end
        all = Tip({ guildLeaders = "2", guildMax = "5" })
        assert(all:find("Gm%-Realm") and all:find("Off%-Realm") and all:find("M3%-Realm") and all:find("M7%-Realm")
            and not all:find("M8%-Realm"), "5 members shown, both leaders on top and not counted: " .. all)
        assert(all:find(ns.L.TT_MORE:format(1), 1, true), "the rest is counted: " .. all)
        all = Tip({ guildMax = "5" })
        assert(all:find("M5%-Realm") and not all:find("M6%-Realm") and all:find(ns.L.TT_MORE:format(3), 1, true),
            "without leaders on top, 5 lines in all: " .. all)
        all = Tip({ guildMax = "999" })
        assert(all:find("M8%-Realm"), "an unknown value falls back to the default of 20")
        -- blank lines between the parts (the general setting turns them off)
        ns.db.tooltipSpacing = true
        local blanks = select(2, Tip({ guildLeaders = "2" }):gsub("\n \n", ""))
        assert(blanks == 3, "blank lines: message of the day, leaders, members (" .. blanks .. ")")
        ns.db.tooltipSpacing = false
        assert(select(2, Tip({ guildLeaders = "2" }):gsub("\n \n", "")) == 0, "no blank line when spacing is off")
        ns.db.tooltipSpacing = true
        all = Tip({ guildMax = "100" })
        assert(all:find("M8%-Realm"), "100 is an allowed number of members")
        -- tooltip alignment: left edge, centered, right edge; automatic follows the screen's middle
        local oldRect = ns.GetRectUI
        local points
        local fakeTip = { ClearAllPoints = function() end, SetPoint = function(_, ...) points = { ... } end }
        ns.GetRectUI = function() return 10, 700, 110, 724 end
        local gcfg = ns.db.blocks.gold
        local function Place(align)
            gcfg.tooltipAlign = align
            ns.MoveTooltip({ key = "gold" }, fakeTip)
            return points[1] .. "/" .. points[3]
        end
        assert(Place("auto") == "TOPLEFT/BOTTOMLEFT", "automatic, block on the left half: " .. Place("auto"))
        assert(Place("right") == "TOPRIGHT/BOTTOMRIGHT", "right edge: " .. Place("right"))
        assert(Place("center") == "TOP/BOTTOM", "centered: " .. Place("center"))
        assert(Place("left") == "TOPLEFT/BOTTOMLEFT", "left edge: " .. Place("left"))
        gcfg.tooltipAlign = "auto"
        ns.GetRectUI = oldRect
        IsInGuild, GetNumGuildMembers, GetGuildRosterInfo, C_GuildInfo, GetGuildInfo = oldIn, oldNum, oldRoster, oldGI, oldInfo
        -- item level
        local il = ns.modules.itemLevel
        assert(il.update({}) == "50.1" and il.update({ itemLevelShown = "overall" }) == "52.4"
            and il.update({ itemLevelShown = "both" }) == "50.1 / 52.4", "item level choices")
        assert(pcall(il.tooltip, tt, { itemLevelWeakFirst = true }), "item level tooltip, weakest first")
        -- second stat
        local st = ns.modules.stats
        local oldD, oldP = GetDodgeChance, GetParryChance
        GetDodgeChance, GetParryChance = function() return 5.5 end, function() return 6.25 end
        local one = st.update({ stat = "dodge" })
        local two = st.update({ stat = "dodge", stat2 = "parry" })
        assert(one and two and two:find(one, 1, true) and two:find(" | ", 1, true), "second stat: " .. tostring(two))
        assert(st.update({ stat = "dodge", stat2 = "dodge" }) == one and st.update({ stat = "dodge", stat2 = "none" }) == one,
            "no second stat, or the same one twice")
        GetDodgeChance, GetParryChance = oldD, oldP
        -- time-left thresholds: orange under 5 minutes, red under 1 (settings in seconds)
        assert(ns.modules.weaponEnchant.thresholds and ns.modules.longBuffs.thresholds, "thresholds are settings")
        local T = ns.BlockTools
        assert(T.Threshold({}, 200, ns.modules.longBuffs.thresholds) == T.WARN, "orange under 5 minutes")
        assert(T.Threshold({}, 30, ns.modules.longBuffs.thresholds) == T.BAD, "red under 1 minute")
        assert(T.Threshold({}, 900, ns.modules.longBuffs.thresholds) == T.GOOD, "good above")
    end,
    -- currencies (1.5): chosen currency, cap, weekly limit, session gain, alert, tooltip parts
    function()
        local CI = C_CurrencyInfo
        local old = { CI.GetBackpackCurrencyInfo, CI.GetCurrencyListSize, CI.GetCurrencyListInfo, CI.GetCurrencyListLink,
            CI.GetCurrencyIDFromLink, CI.GetCurrencyInfo }
        local counts = { [111] = 90, [222] = 5 }
        CI.GetBackpackCurrencyInfo = function(i)
            if i == 1 then return { name = "Badge", quantity = counts[111], iconFileID = 1, currencyTypesID = 111 } end
            if i == 2 then return { name = "Mark", quantity = counts[222], iconFileID = 2, currencyTypesID = 222 } end
        end
        CI.GetCurrencyListSize = function() return 4 end
        CI.GetCurrencyListInfo = function(i)
            if i == 1 then return { name = "Dungeon", isHeader = true } end
            if i == 2 then return { name = "Badge", quantity = counts[111] } end
            if i == 3 then return { name = "Mark", quantity = counts[222] } end
            return { name = "Dust", quantity = 40 }
        end
        CI.GetCurrencyListLink = function(i) return "link" .. i end
        CI.GetCurrencyIDFromLink = function(link) return ({ link2 = 111, link3 = 222, link4 = 333 })[link] end
        CI.GetCurrencyInfo = function(id)
            if id == 111 then return { name = "Badge", quantity = counts[111], maxQuantity = 100, maxWeeklyQuantity = 50,
                quantityEarnedThisWeek = 20, iconFileID = 1 } end
            if id == 222 then return { name = "Mark", quantity = counts[222], maxQuantity = 0, iconFileID = 2 } end
            if id == 333 then return { name = "Dust", quantity = 40, iconFileID = 3 } end
        end
        local mod = ns.modules.currency
        local lines = {}
        local tt = setmetatable({ AddLine = function(_, t) table.insert(lines, tostring(t)) end,
            AddDoubleLine = function(_, a, b) table.insert(lines, tostring(a) .. " | " .. tostring(b)) end },
            { __index = function() return function() end end })
        local function Tip(cfg)
            lines = {}
            mod.tooltip(tt, cfg)
            return table.concat(lines, "\n")
        end
        local T = ns.BlockTools
        T.session.curBase = {}
        ns.CurrencySnapshot()
        -- the old choices keep their meaning; the cap colors the block and adds a word at the cap
        local text, level = mod.update({ currencyShown = "all", fontSize = 12 })
        assert(text:find("90", 1, true) and text:find("5", 1, true) and level == T.WARN, "90 % of the cap is orange: " .. tostring(level))
        text = mod.update({ currencyShown = "2", fontSize = 12 })
        assert(text:find("5", 1, true) and not text:find("90", 1, true), "2nd tracked")
        counts[111] = 100
        text, level = mod.update({ currencyShown = "1", fontSize = 12 })
        assert(level == T.BAD and text:find(ns.L.CURRENCY_CAPPED, 1, true), "at the cap: red and the word: " .. text)
        assert(select(2, mod.update({ currencyShown = "2", fontSize = 12 })) == nil, "no cap, no color")
        -- one chosen currency, even one that is not tracked
        text = mod.update({ currencyShown = "c333", fontSize = 12 })
        assert(text:find("40", 1, true) and not text:find("90", 1, true), "a chosen currency: " .. text)
        assert(mod.update({ currencyShown = "c999", fontSize = 12 }) == ns.L.NONE, "an unknown currency shows nothing")
        local found = false
        for _, v in ipairs(mod.options[1].values()) do if v.key == "c333" and v.label == "Dust" then found = true end end
        assert(found, "the choice list holds every currency you own")
        -- tooltip parts
        local all = Tip({})
        assert(all:find("Badge | 100", 1, true) and all:find("Mark | 5", 1, true) and not all:find("Dust", 1, true), "tracked only by default: " .. all)
        assert(not all:find(" / ", 1, true), "no cap line by default")
        assert(Tip({ currencyTipTracked = false }) == "", "tracked part off")
        all = Tip({ currencyTipCap = true })
        assert(all:find("Badge | 100 / 100", 1, true) and all:find(ns.L.TT_CURRENCY_WEEK .. " | 20 / 50", 1, true), "cap and week: " .. all)
        assert(not all:find("Mark | 5 /", 1, true), "no cap for a currency without one")
        all = Tip({ currencyTipOthers = true })
        assert(all:find("Dungeon", 1, true) and all:find("Dust | 40", 1, true), "other currencies under their category: " .. all)
        -- gain of the session
        all = Tip({ currencyTipSession = true })
        assert(all:find(ns.L.TT_XP_SESSION .. " | +10", 1, true), "gain since the first count: " .. all)
        T.ResetSession()
        all = Tip({ currencyTipSession = true })
        assert(not all:find("+10", 1, true), "Reset session starts the gain again")
        counts[222] = 9
        assert(Tip({ currencyTipSession = true }):find(ns.L.TT_XP_SESSION .. " | +4", 1, true), "gain after the reset")
        assert(mod.extraAction and mod.extraAction.key == "resetSession", "reset action offered")
        CI.GetBackpackCurrencyInfo, CI.GetCurrencyListSize, CI.GetCurrencyListInfo, CI.GetCurrencyListLink,
            CI.GetCurrencyIDFromLink, CI.GetCurrencyInfo = unpack(old, 1, 6)
    end,
    -- launchers: a pool of numbered map pins on the minimap is not offered (QuestieFrame10...)
    function()
        local function Btn(name)
            return { GetName = function() return name end, IsObjectType = function(_, t) return t == "Button" end,
                IsForbidden = function() return false end, IsProtected = function() return false end,
                GetSize = function() return 24, 24 end }
        end
        local old = Minimap.GetChildren
        Minimap.GetChildren = function()
            return Btn("QuestieFrame10"), Btn("QuestieFrame11"), Btn("QuestieFrame12"), Btn("MyAddonMinimapButton"),
                Btn("OtherAddon2")
        end
        local labels = {}
        for _, src in ipairs(ns:GetLauncherSources()) do labels[src.label] = true end
        Minimap.GetChildren = old
        assert(labels.MyAddon and labels.OtherAddon2, "real minimap buttons offered")
        assert(not labels.QuestieFrame10 and not labels.QuestieFrame11, "map pins left out")
    end,
    -- no window over another: a side window closes the other one and docks beside the options
    function()
        ns:OpenOptions()
        ns:BugReport()
        assert(TesseraDebugCopy:IsShown(), "text window shown")
        ns:StartTutorial()
        assert(TesseraTutorial:IsShown() and not TesseraDebugCopy:IsShown(), "one side window at a time")
        TesseraTutorial:Hide()
        assert(TesseraDebugCopy:IsShown(), "the window that stepped aside comes back")
        TesseraDebugCopy:Hide()
        local a = { GetEffectiveScale = function() return 1 end, GetLeft = function() return 0 end,
            GetRight = function() return 100 end, GetTop = function() return 100 end, GetBottom = function() return 0 end }
        local b = setmetatable({ GetLeft = function() return 50 end, GetRight = function() return 150 end }, { __index = a })
        local c = setmetatable({ GetLeft = function() return 108 end, GetRight = function() return 200 end }, { __index = a })
        assert(ns.FramesOverlap(a, b) and not ns.FramesOverlap(a, c), "overlap test")
        TesseraOptions:Hide()
    end,
    -- the left list is as wide as its longest name; the window grows by the same amount
    function()
        local S = ns.OptionsTools.S
        if not (S.navW and S.navW >= 176 and S.navW <= 296) then print("STEP ERROR: nav width out of range: " .. tostring(S.navW)) end
        if TesseraOptions:GetWidth() ~= S.panelW then print("STEP ERROR: window width " .. tostring(TesseraOptions:GetWidth()) .. " is not panelW " .. tostring(S.panelW)) end
    end,
    -- quick tour
    function()
        ns:StartTutorial()
        for _ = 1, 10 do
            -- "Show me" steps (block options, Place by pixel, Accessibility) run without error
            local i = TesseraTutorial.index
            if i == 3 or i == 4 or i == 10 then
                local ok, err = pcall(TesseraTutorial.action:GetScript("OnClick"))
                if not ok then print("STEP ERROR: tour step " .. i .. " button: " .. tostring(err)) end
                ns:ShowSideWindow(TesseraTutorial)
            end
            TesseraTutorial.next:GetScript("OnClick")()
        end -- 11 steps: the last one
        if TesseraTutorial.index ~= 11 then print("STEP ERROR: tour: expected 11 steps, at the last one the index is " .. tostring(TesseraTutorial.index)) end
        -- "Show me" finds its settings: they must be registered rows
        for _, label in ipairs({ ns.L.APPLY_STYLE_TO, ns.L.HIGH_CONTRAST }) do
            local found = false
            for _, r in ipairs(ns.optionRows) do if r.label == label then found = true end end
            if not found then print("STEP ERROR: tour: no setting row for \"" .. label .. "\"") end
        end
        -- "All blocks" page: the style choice is greyed, one button opens the Look tab
        local function Row(label)
            for _, r in ipairs(ns.optionRows) do if r.label == label then return r.frame end end
        end
        local styleRow, applyRow = Row(ns.L.BLOCK_STYLE), Row(ns.L.APPLY_STYLE_TO)
        if not (styleRow and applyRow and applyRow.goLook) then
            print("STEP ERROR: style rows not registered")
        else
            local enabled
            styleRow.dropdown.SetEnabled = function(_, v) enabled = v and true or false end
            ns:SetOptionsSelection("*all")
            ns:RefreshOptions()
            if enabled ~= false then print("STEP ERROR: All blocks: the style list is not greyed out") end
            if not applyRow.goLook:IsShown() then print("STEP ERROR: All blocks: no button to the Look tab") end
            for _, b in ipairs(applyRow.buttons) do
                if b:IsShown() then print("STEP ERROR: All blocks: a style button is still shown") end
            end
            if applyRow.label:GetText() ~= ns.L.STYLE_ALL_HERE then print("STEP ERROR: All blocks: the apply row keeps its label") end
            local page, showPage = nil, ns.ShowOptionsPage
            ns.ShowOptionsPage = function(i) page = i end
            applyRow.goLook:GetScript("OnClick")(applyRow.goLook)
            ns.ShowOptionsPage = showPage
            if page ~= 2 then print("STEP ERROR: All blocks: the button did not open the Look tab (page " .. tostring(page) .. ")") end
            -- a single block: back to the three buttons and the list
            ns:SetOptionsSelection("gold")
            ns:RefreshOptions()
            if enabled ~= true then print("STEP ERROR: one block: the style list stays greyed out") end
            if applyRow.goLook:IsShown() or not applyRow.buttons[1]:IsShown() then print("STEP ERROR: one block: the three buttons did not come back") end
            if applyRow.label:GetText() ~= ns.L.APPLY_STYLE_TO then print("STEP ERROR: one block: the apply row label did not come back") end
        end
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
    -- keeping a block alone: the "Merge blocks dropped together" setting and "Freeze this group"
    function()
        assert(ns.PROFILE_DEFAULTS.dropMerge == true, "blocks merge when dropped together by default")
        assert(ns.PROFILE_DEFAULTS.gridSnap == true, "blocks snap to the grid by default")
        local key = ns:GetBlockKeys()[1]
        ns:SetFrozen(key, true)
        assert(ns:IsFrozen(key), "the group is frozen")
        ns:SetFrozen(key, false)
        assert(not ns:IsFrozen(key), "and free again")
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
    -- a font the game has not loaded yet can measure 0 wide for a moment (14/11, seen with a
    -- SharedMedia font): the block must measure again soon, never keep a 0 width (it stayed
    -- empty until its text changed)
    function()
        local key, f
        for _, k in ipairs(ns:GetBlockKeys()) do
            local c, fr = ns.db.blocks[k], ns.frames[k]
            if c and c.enabled and fr and not ns.IsSpacerKey(k) and ns:GetModule(k) then
                fr.lastText = nil
                ns:UpdateBlock(k)
                if fr.lastText and fr.lastText ~= "" and not fr.lastText:find("|T", 1, true) then key, f = k, fr break end
            end
        end
        if not key then print("STEP ERROR: font not loaded: no block with a plain text to test") return end
        local text, calls = f.text, 0
        local oldW, oldU = text.GetStringWidth, text.GetUnboundedStringWidth
        local function Width(self)
            calls = calls + 1
            if calls <= 2 then return 0 end -- the first measures, before the font is loaded
            return 40
        end
        text.GetStringWidth, text.GetUnboundedStringWidth = Width, Width
        f.lastText, f.textW, f.measureTries = nil, nil, nil
        ns:UpdateBlock(key)
        for _ = 1, 6 do
            local queued = __timers; __timers = {}
            for _, fn in ipairs(queued) do pcall(fn) end
        end
        text.GetStringWidth, text.GetUnboundedStringWidth = oldW, oldU
        if not (f.textW and f.textW > 0) then
            print("STEP ERROR: font not loaded: block " .. key .. " keeps a 0 width (" .. tostring(f.textW) .. ")")
        end
        ns:UpdateBlock(key)
    end,
    -- after a font change the game can still measure with the previous font for a moment:
    -- every block is measured again later (14/11, blocks stayed too narrow, so looked empty)
    function()
        local ready = false
        local keys = {}
        for _, k in ipairs(ns:GetBlockKeys()) do
            local fr = ns.frames[k]
            if fr and fr.text and ns.db.blocks[k].enabled and not ns.IsSpacerKey(k) then
                table.insert(keys, k)
                local function Width() return ready and 40 or 10 end -- 10: the old font's width
                fr.text.GetStringWidth, fr.text.GetUnboundedStringWidth = Width, Width
            end
        end
        for _, k in ipairs(keys) do
            ns.db.blocks[k].font = "arial"
            ns:ApplyStyle(k)
        end
        ready = true
        for _ = 1, 4 do
            local queued = __timers; __timers = {}
            for _, fn in ipairs(queued) do pcall(fn) end
        end
        local wrong
        for _, k in ipairs(keys) do
            local f = ns.frames[k]
            if f.lastText and f.lastText ~= "" and not f.lastText:find("|T", 1, true) and f.textW ~= 40 then wrong = wrong or k end
        end
        if wrong then print("STEP ERROR: font change: block " .. wrong .. " is not measured again (" .. tostring(ns.frames[wrong].textW) .. ")") end
        for _, k in ipairs(keys) do
            local t = ns.frames[k].text
            t.GetStringWidth, t.GetUnboundedStringWidth = nil, nil
            ns.db.blocks[k].font = "friz"
            ns:ApplyStyle(k)
        end
    end,
    -- the Accessibility tab's font is the one of "All blocks": each follows the other
    function()
        local keys = {}
        for _, k in ipairs(ns:GetBlockKeys()) do
            if not ns.IsSpacerKey(k) then table.insert(keys, k) end
        end
        ns:SetAllBlocksFont("arial")
        if ns:AllBlocksFont() ~= "arial" then print("STEP ERROR: accessibility font: AllBlocksFont does not follow SetAllBlocksFont") end
        for _, k in ipairs(keys) do
            if ns.db.blocks[k].font ~= "arial" then print("STEP ERROR: accessibility font: block " .. k .. " did not change") break end
        end
        if ns.db.groupDefaults.font ~= "arial" then print("STEP ERROR: accessibility font: new blocks would not get it") end
        ns.db.blocks[keys[1]].font = "skurri" -- changed one by one in the Blocks tab
        if ns:AllBlocksFont() ~= nil then print("STEP ERROR: accessibility font: different fonts must read as mixed") end
        ns:SetAllBlocksFont("friz")
        if ns:AllBlocksFont() ~= "friz" then print("STEP ERROR: accessibility font: could not go back to one font") end
    end,
    -- professions are recognized by skill line, not by name: on WoW Forever, GetProfessions
    -- returns prof1, prof2, first aid, fishing, cooking, and the First Aid spell name differs
    function()
        local oldP, oldI = GetProfessions, GetProfessionInfo
        GetProfessions = function() return 1, nil, 2, nil, 3 end
        local data = {
            { "Tailoring", "tex-tailoring", 40, 75, 0, 0, 197 },
            { "Secourisme", "tex-firstaid", 2, 75, 0, 0, 129 },
            { "Cuisine", "tex-cooking", 10, 75, 0, 0, 185 },
        }
        GetProfessionInfo = function(i) return unpack(data[i]) end
        local fa, p1, p2 = ns.modules.firstAid, ns.modules.profession1, ns.modules.profession2
        assert(not fa.isEmpty(), "first aid recognized by its skill line")
        assert(fa.update() == "2 / 75", "first aid rank: " .. tostring(fa.update()))
        assert(fa.getIcon() == "tex-firstaid", "first aid icon from the game")
        assert(p1.update():find("Tailoring"), "tailoring stays the first primary profession")
        assert(p2.isEmpty(), "first aid is not taken for a second primary profession")
        assert(ns.modules.cooking.update() == "10 / 75", "cooking recognized by its skill line")
        -- a gathering profession opens its own page, not the last profession opened
        data[2] = { "Herboristerie", "tex-herb", 30, 75, 0, 0, 182 }
        GetProfessions = function() return 1, 2 end
        local oldTS = C_TradeSkillUI
        local opened, hidden, shownId = nil, false, nil
        C_TradeSkillUI = { OpenTradeSkill = function(id) opened = id shownId = id return true end,
            GetBaseProfessionInfo = function() return { professionID = shownId } end }
        local oldF, oldHide = ProfessionsFrame, HideUIPanel
        ProfessionsFrame = { IsShown = function() return shownId ~= nil end }
        HideUIPanel = function() hidden = true shownId = nil end
        local macro = p2.secureMacro()
        assert(#macro <= 255, "macro too long: " .. #macro)
        local run = assert(loadstring(macro:gsub("^/run ", "")))
        shownId = 171 -- Alchemy is open: a click on Herbalism shows Herbalism
        run()
        assert(opened == 182 and not hidden, "herbalism click opens herbalism: " .. tostring(opened))
        run() -- second click on Herbalism: closes it
        assert(hidden, "a second click closes the herbalism page")
        ProfessionsFrame, HideUIPanel = oldF, oldHide
        assert(p1.secureMacro() == "/cast Tailoring", "a crafting profession still casts its spell")
        C_TradeSkillUI = oldTS
        GetProfessions, GetProfessionInfo = oldP, oldI
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
        local fields = {}
        for _, o in ipairs(ns.modules[key].options or {}) do fields[#fields + 1] = tostring(o.field) end
        print("MODULE " .. key .. " " .. tostring(ns.modules[key].label) .. " " .. table.concat(fields, ","))
    end
end
-- Boxes (1.5, as FlareUI's settings panel): in each page and tab, the shown rows never
-- overlap, sit inside their box and the page's scroll area, start at the box's left edge (or
-- at the right half of a shared line); every row is listed with its page and has a tooltip;
-- the keyboard order follows the screen; a text twice as big still fits. Checked with the
-- anchor geometry, for every block and every tab.
do
    MOCK_GEOMETRY = true
    local L = ns.L
    local function Rect(f) local l, b, w, h = MockRect(f) return l, b, l + w, b + h end
    local function CheckRows(what)
        local groups = {}
        for _, r in ipairs(ns.optionWidgets) do
            if r.frame.__shown then
                local id = tostring(r.content)
                groups[id] = groups[id] or { content = r.content, rows = {} }
                table.insert(groups[id].rows, r)
            end
        end
        for _, g in pairs(groups) do
            local cl, cb, _, ct = Rect(g.content)
            for i, a in ipairs(g.rows) do
                local al, ab, ar, at = Rect(a.frame)
                local box = a.box
                if box and box.framed then
                    if not box.frame.__shown then
                        print("STEP ERROR: a row shows in a hidden box (" .. what .. "): " .. tostring(a.label))
                    else
                        local fl, fb, fr, ft = Rect(box.frame)
                        if al < fl - 0.5 or ar > fr + 0.5 or ab < fb - 0.5 or at > ft + 0.5 then
                            print("STEP ERROR: row outside its box (" .. what .. "): " .. tostring(a.label)
                                .. " in " .. tostring(box.title))
                        end
                    end
                    local x = al - cl
                    if math.abs(x - 40) > 0.5 and not (a.frame.halfRight and math.abs(x - 365) < 0.5) then
                        print("STEP ERROR: row out of its column (" .. what .. "): " .. tostring(a.label) .. " at " .. x)
                    end
                end
                if g.content.scroll and (ab < cb - 0.5 or at > ct + 0.5) then
                    print("STEP ERROR: row outside its scroll area (" .. what .. "): " .. tostring(a.label))
                end
                for j = i + 1, #g.rows do
                    local b2 = g.rows[j]
                    local bl, bb, br, bt = Rect(b2.frame)
                    if math.min(at, bt) - math.max(ab, bb) > 0.5 and math.min(ar, br) - math.max(al, bl) > 0.5 then
                        print("STEP ERROR: rows overlap (" .. what .. "): " .. tostring(a.label) .. " / " .. tostring(b2.label))
                    end
                end
            end
            -- keyboard and gamepad order: left to right, then the next line
            local order = ns.OptionsFocusOrder(g.content)
            for k = 2, #order do
                local _, _, _, t1 = Rect(order[k - 1])
                local l1 = Rect(order[k - 1])
                local _, _, _, t2 = Rect(order[k])
                local l2 = Rect(order[k])
                if t2 > t1 + 0.5 or (math.abs(t2 - t1) <= 0.5 and l2 < l1) then
                    print("STEP ERROR: focus order does not follow the screen (" .. what .. "): "
                        .. tostring(order[k - 1].optionLabel) .. " / " .. tostring(order[k].optionLabel))
                end
            end
        end
    end
    for _, r in ipairs(ns.optionRows) do
        if not r.page then print("STEP ERROR: row without a page: " .. tostring(r.label)) end
        if not r.tip then print("STEP ERROR: row without a tooltip: " .. tostring(r.label)) end
    end
    ns:ResetProfile("top")
    local keys = { "*all" }
    for _, key in ipairs(ns:GetBlockKeys()) do keys[#keys + 1] = key end
    for _, key in ipairs(keys) do
        if key == "*all" or ns.db.blocks[key] then
            pcall(function() ns:OpenOptionsFor(key) end)
            for sub = 1, 6 do -- (1.5: 1, 5, 6 Content, 2 and 3 Appearance, 4 Behaviour)
                ns.ShowBlockSub(sub)
                ns:RefreshOptions()
                CheckRows(key .. ", sub-tab " .. sub)
            end
        end
    end
    for page = 1, ns.OPTIONS_PAGE_COUNT do
        ns.ShowOptionsPage(page)
        CheckRows("page " .. page)
    end
    local spacer = ns:AddSpacer()
    ns.db.blocks[spacer].spacerMode = "line"
    ns:OpenOptionsFor(spacer)
    ns:RefreshOptions()
    CheckRows("spacer")
    -- a spacer has no clicks: the Clicks box disappears
    for _, box in ipairs(ns.blockTabs.flows[3].boxes) do
        if box.title == L.SECTION_CLICKS and box.frame.__shown then print("STEP ERROR: an empty box still shows") end
    end
    ns:RemoveSpacer(spacer)
    -- three tabs; the old sub-tabs open the right one
    if #ns.blockTabs.bar.buttons ~= 3 then print("STEP ERROR: the Blocks tab has " .. #ns.blockTabs.bar.buttons .. " tabs") end
    for sub, tab in pairs({ [1] = 1, [2] = 2, [3] = 2, [4] = 3, [5] = 1, [6] = 1, [7] = 2 }) do
        ns.ShowBlockSub(sub)
        if ns.blockTabs.bar.selected ~= tab then print("STEP ERROR: sub-tab " .. sub .. " does not open tab " .. tab) end
    end
    -- text twice as big: half rows whose label no longer fits take the whole line, nothing overlaps
    MOCK_TEXT_SCALE = 2
    ns:OpenOptionsFor("guild")
    for sub = 1, 4 do
        ns.ShowBlockSub(sub)
        ns:RefreshOptions()
        CheckRows("guild, text x2, sub-tab " .. sub)
    end
    ns.ShowOptionsPage(3)
    CheckRows("General, text x2")
    MOCK_TEXT_SCALE = nil
    ns:OpenOptionsFor("guild")
    ns:RefreshOptions()
    local function Find(label)
        for _, r in ipairs(ns.optionWidgets) do
            if r.frame.__shown and (r.frame.headerText or r.label) == label then return r.frame, r end
        end
    end
    -- (1.5) a block's tooltip settings: in the "Only for this block" box of Content, the checkboxes two by two
    do
        ns:OpenOptionsFor("gold")
        ns.ShowBlockSub(1)
        ns:RefreshOptions()
        local tipTitle = Find(L.SECTION_TOOLTIP)
        local a, ra = Find(L.GOLD_TIP_SESSION)
        local b = Find(L.GOLD_TIP_HOUR)
        if not (tipTitle and a and b and ra.box and ra.box.title == L.BOX_OWN) then
            print("STEP ERROR: gold: the Tooltip box and its checkboxes are shown")
        else
            local al, _, _, at = Rect(a)
            local bl, _, _, bt = Rect(b)
            if math.abs(at - bt) > 0.5 or math.abs((bl - al) - 325) > 0.5 then
                print("STEP ERROR: two tooltip checkboxes share a line: " .. al .. "," .. at .. " / " .. bl .. "," .. bt)
            end
        end
        -- a setting that depends on another: greyed while that one is off
        ns.db.blocks.gold.fadeOut = false
        ns.ShowBlockSub(4)
        ns:RefreshOptions()
        local fade = Find(L.FADE_ALPHA)
        if not (fade and fade.enabledByParent == false and fade.indented) then
            print("STEP ERROR: \"" .. L.FADE_ALPHA .. "\" is not indented and greyed under \"" .. L.FADE_OUT .. "\"")
        end
        ns.db.blocks.gold.fadeOut = true
        ns:RefreshOptions()
        if fade and fade.enabledByParent ~= true then print("STEP ERROR: a child setting does not come back") end
        ns.db.blocks.gold.fadeOut = nil
        -- Reset of a box: its settings go back to their defaults, Ctrl + Z brings them back
        local _, rf = Find(L.FONT_SIZE)
        ns.ShowBlockSub(2)
        ns:RefreshOptions()
        _, rf = Find(L.FONT_SIZE)
        local cfg = ns.db.blocks.gold
        local before = cfg.fontSize
        cfg.fontSize = (before or 12) + 7
        ns:RefreshOptions()
        if not (rf and ns.CanResetOptionsBox(rf.box)) then print("STEP ERROR: the Text box cannot be reset") end
        ns.ResetOptionsBox(rf.box)
        if cfg.fontSize ~= ns:GetBlockDefaults("gold").fontSize then print("STEP ERROR: Reset does not bring the text size back") end
        if rf and ns.CanResetOptionsBox(rf.box) then print("STEP ERROR: Reset stays usable after a reset") end
        ns:Undo()
        if cfg.fontSize ~= before + 7 then print("STEP ERROR: Ctrl + Z does not undo a box reset") end
        -- on All blocks, Reset leaves a block whose style is locked as it is (1.7.2)
        do
            local Tools = ns.OptionsTools
            local sel, bags = Tools.S.selected, ns.db.blocks.bags
            local bagsFont, bagsLock, goldFont = bags.fontSize, bags.styleLocked, cfg.fontSize
            Tools.S.selected = Tools.ALL
            ns:RefreshOptions()
            local _, rfAll = Find(L.FONT_SIZE)
            bags.styleLocked, bags.fontSize, cfg.fontSize = true, 29, 31
            ns:RefreshOptions()
            if not rfAll then print("STEP ERROR: no Text box on the All blocks page") else
                ns.ResetOptionsBox(rfAll.box)
                if bags.fontSize ~= 29 then print("STEP ERROR: Reset on All blocks changed a locked block") end
                if cfg.fontSize == 31 then print("STEP ERROR: Reset on All blocks left an unlocked block") end
            end
            Tools.S.selected, bags.styleLocked, bags.fontSize, cfg.fontSize = sel, bagsLock, bagsFont, goldFont
            ns:RefreshOptions()
        end
        cfg.fontSize = before
    end
    MOCK_GEOMETRY = nil
end
-- Window frame (1.3): search (old names too), going to a result, folding, size
do
    local L = ns.L
    local found = ns.SearchOptions((L.SEARCH_OLD_ENABLED or "Show"):match("^[^,]+"))
    local hasOnScreen = false
    for _, r in ipairs(found) do if r.label == L.ENABLED then hasOnScreen = true end end
    if not hasOnScreen then print("STEP ERROR: search: an old name does not find \"" .. L.ENABLED .. "\"") end
    if #ns.SearchOptions("e") ~= 0 then print("STEP ERROR: search starts at two letters") end
    local fmt = ns.SearchOptions(ns.L.HIDE_EMPTY)
    if #fmt < 2 then print("STEP ERROR: search: a setting of several blocks is listed once per block") end
    for _, r in ipairs(found) do
        local ok, err = pcall(ns.GoToOption, r, ns.ShowOptionsPage)
        if not ok then print("STEP ERROR: going to a search result: " .. tostring(err)) end
    end
    for _, fn in ipairs(__timers) do pcall(fn) end
    if not TesseraOptions:IsShown() then ns:ToggleOptions() end
    ns:SetOptionsFolded(true)
    if TesseraOptions:GetHeight() > 100 or TesseraOptions.nav:IsShown() then print("STEP ERROR: a folded window keeps only its top bar") end
    TesseraOptions:Hide(); TesseraOptions:Show()
    if TesseraOptions:GetHeight() < 500 or not TesseraOptions.nav:IsShown() then print("STEP ERROR: the window opens unfolded") end
    local wheel = TesseraOptions:GetScript("OnMouseWheel")
    local shift = IsShiftKeyDown
    IsShiftKeyDown = function() return true end
    for _ = 1, 30 do wheel(TesseraOptions, 1) end
    if ns.sv.optionsZoom ~= 1.3 then print("STEP ERROR: window size stops at 130 %: " .. tostring(ns.sv.optionsZoom)) end
    for _ = 1, 30 do wheel(TesseraOptions, -1) end
    if ns.sv.optionsZoom ~= 0.7 then print("STEP ERROR: window size stops at 70 %: " .. tostring(ns.sv.optionsZoom)) end
    for _ = 1, 9 do wheel(TesseraOptions, 1) end
    if ns.sv.optionsZoom ~= nil then print("STEP ERROR: back to 115 % saves nothing") end
    IsShiftKeyDown = shift
    -- help tooltips of Tessera's windows: 125 % of the game's size, given back on hide
    local set = {}
    GameTooltip.SetScale = function(_, v) set[#set + 1] = v end
    GameTooltip.GetOwner = function() return TesseraOptions end
    GameTooltip.__scripts.OnShow(GameTooltip)
    if not set[1] or math.abs(set[1] - 1.25 * 1.15) > 0.001 then print("STEP ERROR: window tooltips are 125 % of the game's size: " .. tostring(set[1])) end
    GameTooltip.__scripts.OnHide(GameTooltip)
    if not set[2] or math.abs(set[2] - 1) > 0.001 then print("STEP ERROR: the game's tooltip scale is given back") end
    GameTooltip.SetScale, GameTooltip.GetOwner = nil, nil
end
-- Blocks tab (1.3, lot 4): the "On screen" switch, the list in two parts, the style of
-- one block, sections that fold and open from the search; Accessibility tab
do
    local L = ns.L
    ns:ResetProfile("top")
    if not TesseraOptions:IsShown() then ns:ToggleOptions() end
    local key
    for _, k in ipairs(ns:GetBlockKeys()) do
        if ns.db.blocks[k].enabled and not ns.IsSpacerKey(k) then key = k break end
    end
    ns:OpenOptionsFor(key)
    -- the list: "On screen" first, then "Available"
    local switch = ns.blockSwitch
    if not switch then print("STEP ERROR: no \"On screen\" switch on the Blocks tab") end
    switch:Activate()
    if ns.db.blocks[key].enabled then print("STEP ERROR: the switch does not take the block off the screen") end
    switch:Activate()
    if not ns.db.blocks[key].enabled then print("STEP ERROR: the switch does not put the block back") end
    -- (1.6) "What's new": every line's "Show me" finds its setting, the popup lists the version's lines
    for _, entry in ipairs(ns.CHANGELOG) do
        for _, line in ipairs(ns.ChangelogHighlights(entry, "fr")) do
            if not line.text or #line.text > 120 then print("STEP ERROR: what's new line too long or empty in " .. entry.version) end
            local spec = line.show
            if spec then
                if spec.label and not ns.L[spec.label] then print("STEP ERROR: what's new: unknown label " .. spec.label) end
                if spec.page and not ns.OptionsTools[spec.page] then print("STEP ERROR: what's new: unknown page " .. spec.page) end
                if spec.widget and not ns[spec.widget] then print("STEP ERROR: what's new: no widget " .. spec.widget) end
                if not spec.label and not spec.widget then print("STEP ERROR: what's new: nothing to blink in " .. entry.version) end
                local found = not spec.label
                for _, r in ipairs(ns.optionRows) do
                    if spec.label and r.label == ns.L[spec.label] then found = true end
                end
                if not found then print("STEP ERROR: what's new: no setting row for " .. tostring(spec.label)) end
                local ok, err = pcall(ns.ShowWhatsNewTarget, ns, spec)
                if not ok then print("STEP ERROR: what's new target " .. tostring(spec.label) .. ": " .. tostring(err)) end
            end
        end
    end
    -- after a "Show me", a button brings you back to What's new
    ns:ShowWhatsNewTarget({ page = "PAGE_LOOK" })
    local timers = _G.__timers
    _G.__timers = {}
    for _, fn in ipairs(timers) do pcall(fn) end
    local back = ns.WhatsNewBackButton()
    if not back then print("STEP ERROR: no Back to What's new button after Show me")
    else
        if not back:IsShown() then print("STEP ERROR: no Back to What's new button after Show me") end
        ns.WhatsNewGoBack()
        if back:IsShown() then print("STEP ERROR: the back button stays after use") end
    end
    -- the popup lists the news since the version the player had; a fixes-only version shows the latest news
    local withNews
    for _, e in ipairs(ns.CHANGELOG) do if e.highlights then withNews = e break end end
    local first = ns.ChangelogHighlights(withNews, "en")[1].text
    local firstFr = ns.ChangelogHighlights(withNews, "fr")[1].text
    local popup = ns.WhatsNewPopupText(ns.CHANGELOG[1].version, ns.CHANGELOG[1].version)
    if not (popup:find(first, 1, true) or popup:find(firstFr, 1, true)) then
        print("STEP ERROR: the update popup lists no news")
    end
    ns:OpenOptionsFor(key)
    -- (1.6) "Hide when empty" beside it: the same setting as the Behaviour tab's check
    local hs = ns.hideEmptySwitch
    if not hs then print("STEP ERROR: no \"Hide when empty\" switch beside \"Enabled\"")
    else
        local fkey = "friends"
        ns:OpenOptionsFor(fkey)
        TesseraOptions:GetScript("OnShow")(TesseraOptions)
        if not hs:IsShown() then print("STEP ERROR: the hide-when-empty switch is hidden for the Friends block") end
        local before = ns.db.blocks[fkey].hideEmpty and true or false
        hs:Activate()
        if (ns.db.blocks[fkey].hideEmpty and true or false) == before then print("STEP ERROR: the hide-when-empty switch changes nothing") end
        hs:Activate()
        if (ns.db.blocks[fkey].hideEmpty and true or false) ~= before then print("STEP ERROR: the hide-when-empty switch does not flip back") end
        ns:OpenOptionsFor(key)
    end
    -- every block off at once, then Ctrl + Z in the options window brings them back
    local onBefore = 0
    for _, k in ipairs(ns:GetBlockKeys()) do if ns.db.blocks[k].enabled then onBefore = onBefore + 1 end end
    ns:SetBlocksOnScreen(ns:GetBlockKeys(), false)
    local ctrl = IsControlKeyDown
    IsControlKeyDown = function() return true end
    TesseraOptions:GetScript("OnKeyDown")(TesseraOptions, "Z")
    IsControlKeyDown = ctrl
    local onAfter = 0
    for _, k in ipairs(ns:GetBlockKeys()) do if ns.db.blocks[k].enabled then onAfter = onAfter + 1 end end
    if onAfter ~= onBefore then print("STEP ERROR: Ctrl + Z in the options window: " .. onAfter .. " blocks back of " .. onBefore) end
    -- style of one block: the others keep theirs, Ctrl + Z brings it back
    local themes = ns:GetAvailableThemes()
    local other
    for _, k in ipairs(ns:GetBlockKeys()) do if k ~= key and not ns.IsSpacerKey(k) then other = k break end end
    local before, otherBefore = ns.db.blocks[key].border, ns.db.blocks[other].border
    local target
    for _, t in ipairs(themes) do
        local probe = {}
        ns:ApplyThemeToCfg(probe, t.key)
        if probe.border ~= before then target = t.key break end
    end
    if target then
        ns:ApplyThemeToBlocks({ key }, target)
        if ns.db.blocks[key].border == before then print("STEP ERROR: the style did not reach the block") end
        if ns.db.blocks[other].border ~= otherBefore then print("STEP ERROR: the style of one block changed another one") end
        ns:Undo()
        if ns.db.blocks[key].border ~= before then print("STEP ERROR: Ctrl + Z does not bring the block's look back") end
    end
    -- the search names the tab and the box, and opens the tab
    local found = ns.SearchOptions(L.FADE_OUT)
    local r = found[1]
    if not (r and r.tabName == L.BLOCK_TAB_BEHAVIOUR and r.section == L.SECTION_FADE) then
        print("STEP ERROR: a setting does not know its tab and its box")
    else
        ns.ShowBlockSub(1)
        ns.GoToOption(r, ns.ShowOptionsPage)
        if ns.blockTabs.bar.selected ~= 3 then print("STEP ERROR: the search does not open the tab") end
    end
    local guildNote = ns.SearchOptions(L.GUILD_TIP_NOTE)[1]
    local where = guildNote and ns.OptionPlaceName(guildNote) or ""
    local want = table.concat({ L.TAB_BLOCK, ns:GetBlockName("guild"), L.BLOCK_TAB_CONTENT, L.BOX_OWN }, " › ")
    if where ~= want then print("STEP ERROR: search place \"" .. where .. "\" instead of \"" .. want .. "\"") end
    for _, fn in ipairs(__timers) do pcall(fn) end
    -- Accessibility tab: its settings are found, fewer animations runs
    local access = ns.SearchOptions(L.REDUCE_MOTION)
    if not (access[1] and access[1].page == ns.OPTIONS_PAGE_COUNT) then print("STEP ERROR: \"Fewer animations\" not on the Accessibility tab") end
    ns.sv.reduceMotion = true
    local f = ns.frames[key]
    local ok, err = pcall(function() ns:Flash(f); ns:UpdateFades() end)
    if not ok then print("STEP ERROR: fewer animations: " .. tostring(err)) end
    ns.sv.reduceMotion = nil
    for _, fn in ipairs(__timers) do pcall(fn) end
end
-- "See all" window of the Blocks tab (1.8): counter, every block in one window, search, a click selects
do
    local tools = ns.OptionsTools
    local shown, total = tools.CountBlocks()
    if not (total >= 50 and shown >= 0 and shown <= total) then print("STEP ERROR: block count " .. shown .. " / " .. total) end
    ns.seeAllButton:Refresh()
    ns:ShowBlockPicker()
    local picker = ns.BlockPicker()
    if not picker:IsShown() then print("STEP ERROR: the See all window does not open") end
    local visible = 0
    for _, b in ipairs(picker.buttons) do if b:IsShown() then visible = visible + 1 end end
    if visible < total then print("STEP ERROR: See all shows " .. visible .. " buttons for " .. total .. " blocks") end
    -- search: only the blocks whose name holds the text
    local name = ns:GetBlockName("gold")
    picker.search:SetText(name:sub(1, 3))
    picker.search.__scripts.OnTextChanged(picker.search)
    local found = 0
    for _, b in ipairs(picker.buttons) do if b:IsShown() then found = found + 1 end end
    if found < 1 or found >= visible then print("STEP ERROR: See all search found " .. found .. " of " .. visible) end
    -- a click selects the block and closes the window
    local key
    for _, b in ipairs(picker.buttons) do if b:IsShown() and b.entryKey then key = b.entryKey b.__scripts.OnClick(b) break end end
    if picker:IsShown() or ns.OptionsTools.S.selected ~= key then print("STEP ERROR: a click in See all does not select the block") end
    ns:ShowBlockPicker()
    picker.search:SetText("zzzzzz")
    picker.search.__scripts.OnTextChanged(picker.search)
    if not picker.empty:IsShown() then print("STEP ERROR: See all shows no message when nothing matches") end
    picker:Hide()
end
-- Style gallery: every style once, by family, "Automatic" first from the Look tab; marking a
-- thumbnail changes nothing, Apply does; keyboard; locked blocks keep their style; text x2;
-- from a block's page, "This block" styles that block only
do
    local L = ns.L
    local themeBefore = ns.db.theme
    local available = ns:GetAvailableThemes()
    local seen, nCards = {}, 0
    for _, row in ipairs(ns.StyleGalleryRows(true)) do
        if row.key then
            nCards = nCards + 1
            if seen[row.key] then print("STEP ERROR: gallery: " .. row.key .. " twice") end
            seen[row.key] = true
        end
    end
    for _, t in ipairs(available) do
        if not seen[t.key] then print("STEP ERROR: gallery: style " .. t.key .. " missing") end
    end
    if ns.StyleGalleryRows(true)[2].key ~= "auto" then print("STEP ERROR: gallery: Automatic is not first") end
    for _, fam in ipairs(ns.STYLE_FAMILIES) do
        if not L[fam.title] or L[fam.title] == fam.title then print("STEP ERROR: gallery: no text for " .. fam.title) end
        for _, key in ipairs(fam.keys) do
            if not ns:GetThemeInfo(key) then print("STEP ERROR: gallery: family key " .. key .. " is not a style") end
        end
    end
    -- open from the Look tab
    ns:PickStyleChoice("auto")
    local lockKey = "fps"
    ns.db.blocks[lockKey].styleLocked = true
    local lockedBorder = ns.db.blocks[lockKey].border
    -- a click on the style list opens the gallery, not the list's menu
    local b = ns.lookStyleList
    local function OpenLook() b.dropdown:SetMenuOpen(true) end
    if not b then print("STEP ERROR: gallery: the Look tab's style list does not open it") else OpenLook() end
    if b and b.dropdown:IsMenuOpen() then print("STEP ERROR: gallery: the style list opened its menu") end
    local g = ns.StyleGallery()
    if not (g and g:IsShown()) then
        print("STEP ERROR: gallery: the window does not open")
    else
        if g.nCards ~= nCards then print("STEP ERROR: gallery shows " .. tostring(g.nCards) .. " cards for " .. nCards) end
        if g.chosen ~= "auto" then print("STEP ERROR: gallery: the current choice is not marked") end
        local apply = g.buttons[1]
        if apply.usable then print("STEP ERROR: gallery: Apply is usable on the current style") end
        -- keyboard: the first key shows the focus, the next ones move it; Enter marks
        ns.StyleGalleryKey("RIGHT")
        if g.focus ~= 1 then print("STEP ERROR: gallery: the first key moved the focus") end
        ns.StyleGalleryKey("DOWN")
        ns.StyleGalleryKey("ENTER")
        local marked = g.chosen
        if marked == "auto" or not seen[marked] then print("STEP ERROR: gallery: Enter marked " .. tostring(marked)) end
        if ns:GetStyleChoice() ~= "auto" then print("STEP ERROR: gallery: marking a style applied it") end
        if not apply.usable then print("STEP ERROR: gallery: Apply stays greyed") end
        -- Tab goes to the workshop's column, then to the buttons; Enter presses Apply
        ns.StyleGalleryKey("TAB")
        if g.zone ~= "side" then print("STEP ERROR: gallery: Tab does not reach the workshop") end
        ns.StyleGalleryKey("TAB")
        if g.focus ~= g.nCards + 1 then print("STEP ERROR: gallery: Tab does not reach Apply") end
        ns.StyleGalleryKey("ENTER")
        if ns:GetStyleChoice() ~= marked then print("STEP ERROR: gallery: Apply did not apply " .. tostring(marked)) end
        if ns.db.blocks[lockKey].border ~= lockedBorder then print("STEP ERROR: gallery: a locked block lost its style") end
        if apply.usable then print("STEP ERROR: gallery: Apply stays usable after applying") end
        local tagged = 0
        for i = 1, g.nCards do
            local c = g.cards[i]
            if c.tag:GetText() ~= "" then
                tagged = tagged + 1
                if c.key ~= marked then print("STEP ERROR: gallery: the current tag is on " .. c.key) end
            end
        end
        if tagged ~= 1 then print("STEP ERROR: gallery: " .. tagged .. " cards tagged current") end
        -- cards never overlap and hold their sample, also with a text twice as big
        local function CheckCards(what)
            for i = 1, g.nCards do
                local c = g.cards[i]
                if c.sample:GetWidth() > c:GetWidth() then print("STEP ERROR: gallery " .. what .. ": sample wider than its card " .. c.key) end
                if g.columns * c:GetWidth() > g.content:GetWidth() + 1 then print("STEP ERROR: gallery " .. what .. ": cards wider than the window") end
            end
        end
        CheckCards("x1")
        -- a "text only" style (Runestone) shows no icon on its card, as on a real block
        for i = 1, g.nCards do
            local c = g.cards[i]
            if c.key == "runestone" and c.sample.icon:IsShown() then print("STEP ERROR: gallery: Runestone shows an icon") end
            if c.key == "grimoire" and not c.sample.icon:IsShown() then print("STEP ERROR: gallery: Grimoire lost its icon") end
        end
        local columns = g.columns
        MOCK_TEXT_SCALE = 2
        OpenLook()
        CheckCards("x2")
        if g.columns > columns then print("STEP ERROR: gallery: more columns with a text twice as big") end
        MOCK_TEXT_SCALE = nil
        -- Escape closes, and the game gets its keys back
        if not ns.StyleGalleryKey("ESCAPE") or g:IsShown() then print("STEP ERROR: gallery: Escape does not close it") end
        if ns.StyleGalleryKey("LEFT") then print("STEP ERROR: gallery: a closed gallery keeps the keys") end
        -- from a block's page: the three buttons of "Apply this style to"
        ns.db.blocks[lockKey].styleLocked = nil
        ns:SetOptionsSelection("gold")
        ns:RefreshOptions()
        local bb = ns.blockStyleList
        if not bb then
            print("STEP ERROR: gallery: the block page's style list does not open it")
        else
            local before = ns.db.blocks.time.border
            bb.Activate()
            if #g.buttons < 4 or not g.buttons[4]:IsShown() then print("STEP ERROR: gallery: the block page buttons are missing") end
            local target = ns:GetTheme() == "hdGold" and "hdSilver" or "hdGold"
            for i = 1, g.nCards do if g.cards[i].key == target then g.cards[i]:GetScript("OnClick")(g.cards[i]) end end
            if g.chosen ~= target then print("STEP ERROR: gallery: a click does not mark the style") end
            g.buttons[1]:GetScript("OnClick")(g.buttons[1]) -- This block
            local want = ns:GetBlockDefaults("gold")
            ns:ApplyThemeToCfg(want, target)
            if ns.db.blocks.gold.border ~= want.border then print("STEP ERROR: gallery: This block did not style the block") end
            if ns.db.blocks.time.border ~= before then print("STEP ERROR: gallery: This block styled another block") end
            if ns:GetStyleChoice() ~= marked then print("STEP ERROR: gallery: This block changed the profile's style") end
            for i = 1, g.nCards do if g.cards[i].key == "auto" then print("STEP ERROR: gallery: Automatic offered on a block page") end end
            g:Hide()
            ns:SetOptionsSelection("*all")
            ns:RefreshOptions()
            bb.Activate()
            if not bb.galleryOff or g:IsShown() then print("STEP ERROR: gallery: the block page list opens it on All blocks") end
            ns:SetOptionsSelection("gold")
        end
    end
    if themeBefore then ns:ApplyTheme(themeBefore) else ns:PickStyleChoice("auto") end
end
-- The gallery's workshop (27/11): a column with the Style box's rows; the marked style's offer,
-- what the player changed kept; shown on the thumbnails, saved only by a button; Apply with the
-- same style writes only what changed; locked blocks kept; keyboard; text x2; high contrast
do
    local W = ns.StyleWorkshop
    local themeBefore = ns.db.theme
    ns:PickStyleChoice("auto")
    local g
    local function OpenLook() ns.lookStyleList.dropdown:SetMenuOpen(true) g = ns.StyleGallery() end
    local function Mark(key)
        for i = 1, g.nCards do if g.cards[i].key == key then g.cards[i]:GetScript("OnClick")(g.cards[i]) end end
    end
    local function Row(field)
        for _, r in ipairs(W.rows) do if r.spec.field == field then return r end end
    end
    local function CardOf(key)
        for i = 1, g.nCards do if g.cards[i].key == key then return g.cards[i] end end
    end
    local lockKey = "fps"
    ns.db.blocks[lockKey].styleLocked = true
    local lockedSize, lockedBorder = ns.db.blocks[lockKey].fontSize, ns.db.blocks[lockKey].border
    local size0 = ns:AllBlocksField("fontSize", "blocks", true)
    OpenLook()
    if not (W.active and W.side:IsShown()) then print("STEP ERROR: workshop: no column in the gallery") end
    if g:GetWidth() <= 900 then print("STEP ERROR: workshop: the gallery is not wider") end
    if g:GetWidth() > UIParent:GetWidth() then print("STEP ERROR: workshop: the gallery is wider than the screen") end
    if g.content:GetWidth() + W.side:GetWidth() + 18 * 2 + 34 > g:GetWidth() then print("STEP ERROR: workshop: thumbnails under the column") end
    if g.columns < 3 then print("STEP ERROR: workshop: only " .. g.columns .. " thumbnails per row") end
    -- the column starts from the blocks; the marked style brings its font and effects
    if W.Value("fontSize", g.chosen, "x", true) ~= size0 then print("STEP ERROR: workshop: the size is not the blocks' one") end
    Mark("hdRune")
    local want = ns:GetBlockDefaults("gold")
    ns:ApplyThemeToCfg(want, "hdRune")
    if W.Value("font", "hdRune", "hdRune") ~= want.font then print("STEP ERROR: workshop: the column does not show Blue rune's font") end
    if W.Value("hoverGlow", "hdRune", "hdRune") ~= true then print("STEP ERROR: workshop: Blue rune's effects are not offered") end
    if not Row("edgeShape").shown then print("STEP ERROR: workshop: no Corners for a rounded border") end
    if Row("iconSet").shown ~= (ns.HD_ICONS_ON and true or false) then print("STEP ERROR: workshop: Icons row shown while HD icons are off") end
    Mark("blizzard")
    if Row("edgeShape").shown then print("STEP ERROR: workshop: Corners shown without a rounded border") end
    Mark("hdRune")
    -- keyboard: Tab into the column, Down to the size, Enter takes it, Right raises it
    g.keyboardOn = true
    ns.StyleGalleryKey("TAB")
    if g.zone ~= "side" then print("STEP ERROR: workshop: Tab does not reach the column") end
    while W.FocusedRow() and W.FocusedRow().spec.field ~= "fontSize" do ns.StyleGalleryKey("DOWN") end
    ns.StyleGalleryKey("ENTER")
    if not W.Taken() then print("STEP ERROR: workshop: Enter does not take the row") end
    ns.StyleGalleryKey("RIGHT")
    ns.StyleGalleryKey("RIGHT")
    local size1 = size0 + 2
    if W.Value("fontSize", g.chosen, "hdRune") ~= size1 then print("STEP ERROR: workshop: Right does not raise the size") end
    if ns:AllBlocksField("fontSize", "blocks", true) ~= size0 then print("STEP ERROR: workshop: a change was saved before Apply") end
    if ns:GetStyleChoice() ~= "auto" then print("STEP ERROR: workshop: the style changed before Apply") end
    local card = CardOf("hdSilver")
    if not (card and card.sample.lifeCfg and card.sample.lifeCfg.fontSize == size1) then print("STEP ERROR: workshop: the thumbnails do not show the new size") end
    -- Escape lets the row go first, Left goes back to the thumbnails
    ns.StyleGalleryKey("ESCAPE")
    if W.Taken() or not g:IsShown() then print("STEP ERROR: workshop: Escape on a taken row closed the gallery") end
    ns.StyleGalleryKey("LEFT")
    if g.zone == "side" then print("STEP ERROR: workshop: Left does not leave the column") end
    -- another style: its font, the size the player chose stays
    Mark("hdSilver")
    local silver = ns:GetBlockDefaults("gold")
    ns:ApplyThemeToCfg(silver, "hdSilver")
    if W.Value("font", "hdSilver", "hdSilver") ~= silver.font then print("STEP ERROR: workshop: Silver's font not shown") end
    if W.Value("fontSize", "hdSilver", "hdSilver") ~= size1 then print("STEP ERROR: workshop: the player's size was lost") end
    -- Right at the end of a row of thumbnails goes into the column
    local first = g.cards[1]
    local last = 1
    for i = 1, g.nCards do if g.cards[i].row == first.row then last = i end end
    g.focus = last
    ns.StyleGalleryKey("RIGHT")
    if g.zone ~= "side" then print("STEP ERROR: workshop: Right at the end of a row does not reach the column") end
    ns.StyleGalleryKey("LEFT")
    -- Apply: the style, then the size; the locked block keeps both
    g.buttons[1]:GetScript("OnClick")(g.buttons[1])
    if ns:GetStyleChoice() ~= "hdSilver" then print("STEP ERROR: workshop: Apply did not give the style") end
    if ns.db.blocks.gold.fontSize ~= size1 or ns.db.blocks.gold.font ~= silver.font then print("STEP ERROR: workshop: Apply did not write the settings") end
    if ns.db.blocks[lockKey].fontSize ~= lockedSize or ns.db.blocks[lockKey].border ~= lockedBorder then print("STEP ERROR: workshop: a locked block changed") end
    if W.Changes() ~= nil then print("STEP ERROR: workshop: changes left after Apply") end
    if g.buttons[1].usable then print("STEP ERROR: workshop: Apply usable with nothing to apply") end
    -- same style, only the font: Apply writes the font and keeps the player's colors
    ns.db.blocks.gold.bgColor = { r = 0.2, g = 0.4, b = 0.6, a = 1 }
    W.Release()
    local fonts = ns:GetMediaList("font")
    local other
    for _, f in ipairs(fonts) do if f.key ~= silver.font then other = f.key break end end
    g.zone = "side"
    W.Enter()
    while W.FocusedRow() and W.FocusedRow().spec.field ~= "font" do ns.StyleGalleryKey("UP") end
    Row("font").Step(1)
    if W.Value("font", g.chosen, "hdSilver") == silver.font then Row("font").Step(-1) end -- (the last font of the list)
    local picked = W.Value("font", g.chosen, "hdSilver")
    if picked == silver.font then print("STEP ERROR: workshop: the font did not change") end
    if not g.buttons[1].usable then print("STEP ERROR: workshop: Apply greyed after changing only the font") end
    g.buttons[1]:GetScript("OnClick")(g.buttons[1])
    if ns.db.blocks.gold.font ~= picked then print("STEP ERROR: workshop: Apply did not write the font") end
    if ns.db.blocks.gold.bgColor.b ~= 0.6 then print("STEP ERROR: workshop: Apply with the same style reset the colors") end
    if other == nil then print("STEP ERROR: workshop: only one font in the list") end
    -- text twice as big: rows never overlap and stay in the column
    MOCK_TEXT_SCALE = 2
    OpenLook()
    local prev
    for _, r in ipairs(W.rows) do
        if r.shown then
            if r:GetWidth() > W.content:GetWidth() + 1 or r.label:GetWidth() > r:GetWidth() then print("STEP ERROR: workshop x2: row wider than the column " .. r.spec.field) end
            if prev and prev.y + prev:GetHeight() > r.y then print("STEP ERROR: workshop x2: rows overlap at " .. r.spec.field) end
            prev = r
        end
    end
    MOCK_TEXT_SCALE = nil
    -- high contrast: the column turns plain black with a white edge
    ns.sv.highContrast = true
    ns.Skin.Repaint()
    if W.side.skinMode ~= "contrast" then print("STEP ERROR: workshop: high contrast does not reach the column") end
    ns.sv.highContrast = nil
    ns.Skin.Repaint()
    g:Hide()
    -- a block's page, same style, only the size: This block writes the size and nothing else
    ns.db.blocks[lockKey].styleLocked = nil
    ns:SetOptionsSelection("gold")
    ns:RefreshOptions()
    local borderBefore = ns.db.blocks.gold.border
    ns.db.blocks.gold.border = "none"
    ns.blockStyleList.Activate()
    g = ns.StyleGallery()
    Row("fontSize").Step(1)
    local timeSize = ns.db.blocks.time.fontSize
    g.buttons[1]:GetScript("OnClick")(g.buttons[1]) -- This block
    if ns.db.blocks.gold.fontSize ~= size1 + 1 then print("STEP ERROR: workshop: This block did not write the size") end
    if ns.db.blocks.gold.border ~= "none" then print("STEP ERROR: workshop: This block gave the style again") end
    if ns.db.blocks.time.fontSize ~= timeSize then print("STEP ERROR: workshop: This block changed another block") end
    -- with a locked block in the lot, the warning comes first; Cancel keeps the workshop
    ns.db.blocks.time.styleLocked = true
    Row("fontSize").Step(1)
    local asked = {}
    local realShow = StaticPopup_Show
    StaticPopup_Show = function(which, n, _, data) table.insert(asked, { which = which, n = n, data = data }) end
    g.buttons[3]:GetScript("OnClick")(g.buttons[3]) -- All blocks
    StaticPopup_Show = realShow
    if not (asked[1] and asked[1].which == "TESSERA_STYLE_LOCKED_LOOK") then print("STEP ERROR: workshop: no warning for the locked block") end
    if W.Changes() == nil then print("STEP ERROR: workshop: the warning emptied the workshop before an answer") end
    -- "Skip locked": the others get the size, the locked one keeps its own
    if asked[1] then
        StaticPopupDialogs.TESSERA_STYLE_LOCKED_LOOK.OnAccept(nil, asked[1].data)
        if ns.db.blocks.time.fontSize ~= timeSize then print("STEP ERROR: workshop: Skip locked changed a locked block") end
        if ns.db.blocks.gold.fontSize ~= size1 + 2 then print("STEP ERROR: workshop: Skip locked left the others") end
        if W.Changes() ~= nil then print("STEP ERROR: workshop: changes left after the warning") end
    end
    ns.db.blocks.time.styleLocked = nil
    ns.db.blocks.gold.border = borderBefore
    g:Hide()
    if themeBefore then ns:ApplyTheme(themeBefore) else ns:PickStyleChoice("auto") end
end
-- The gallery, second round (27/11): two merged blocks per thumbnail with the separator between
-- them; separators and glow rows in the column; the animation and its box; Jade and Amethyst;
-- the glow shapes and color (new saved fields: old profiles and old style texts keep the halo)
do
    local W = ns.StyleWorkshop
    local themeBefore = ns.db.theme
    ns:PickStyleChoice("auto")
    ns.lookStyleList.dropdown:SetMenuOpen(true)
    local g = ns.StyleGallery()
    local function CardOf(key)
        for i = 1, g.nCards do if g.cards[i].key == key then return g.cards[i] end end
    end
    local function Row(field)
        for _, r in ipairs(W.rows) do if r.spec.field == field then return r end end
    end
    -- six rounded styles, Jade and Amethyst among them, two rows of three
    local fam = {}
    for i = 1, g.nCards do
        local k = g.cards[i].key
        if k:sub(1, 2) == "hd" then fam[#fam + 1] = g.cards[i] end
    end
    if #fam ~= 6 then print("STEP ERROR: gallery: " .. #fam .. " rounded styles, not 6") end
    if not (CardOf("hdJade") and CardOf("hdAmethyst")) then print("STEP ERROR: gallery: Jade or Amethyst missing") end
    if fam[1] and fam[4] and (fam[1].row == fam[4].row or fam[4].row ~= fam[6].row) then
        print("STEP ERROR: gallery: the rounded styles are not two rows of three")
    end
    for _, key in ipairs({ "hdJade", "hdAmethyst" }) do
        local cfg = ns:GetBlockDefaults("gold")
        ns:ApplyThemeToCfg(cfg, key)
        if not (cfg.hoverGlow and cfg.separators and ns:FindMedia("border", cfg.border).hd) then
            print("STEP ERROR: style " .. key .. " is not a rounded style")
        end
    end
    -- two blocks side by side, the second against the first, the separator between them
    local card = CardOf("hdGold")
    local a, b = card.sample, card.sample2
    if not (b and b:IsShown()) then print("STEP ERROR: gallery: no second block on the thumbnail") end
    if math.abs((card.pairW or 0) - (a:GetWidth() + b:GetWidth())) > 0.5 then print("STEP ERROR: gallery: the pair width is wrong") end
    if not card.joinLayer.ornate:IsShown() then print("STEP ERROR: gallery: Gilded's diamond is not drawn between the blocks") end
    if a.text:GetText() == b.text:GetText() then print("STEP ERROR: gallery: both blocks show the same value") end
    -- the column: separators off hides their shape and the thumbnails' separator
    g.chosen = "hdGold"
    W.Sync()
    if not (Row("separators").shown and Row("separatorStyle").shown) then print("STEP ERROR: workshop: separator rows missing") end
    Row("separators").Step(1)
    if Row("separatorStyle").shown then print("STEP ERROR: workshop: separator shape shown with separators off") end
    if card.joinLayer.ornate:IsShown() or card.joinLayer.line:IsShown() then print("STEP ERROR: gallery: separator drawn while off") end
    Row("separators").Step(1)
    -- the glow rows follow Glow on hover; Pulse and the class color reach the thumbnails
    if not (Row("glowShape").shown and Row("glowColorMode").shown) then print("STEP ERROR: workshop: glow rows missing") end
    while W.Value("glowShape", "hdGold", "hdGold") ~= "pulse" do Row("glowShape").Step(1) end
    Row("glowColorMode").Step(1)
    if a.lifeCfg.glowShape ~= "pulse" or a.lifeCfg.glowColorMode ~= "class" then print("STEP ERROR: workshop: glow shape or color not on the thumbnail") end
    if a.pulse == nil then print("STEP ERROR: glow: Pulse does not breathe") end
    Row("hoverGlow").Step(1)
    if Row("glowShape").shown or Row("glowColorMode").shown then print("STEP ERROR: workshop: glow rows shown with the glow off") end
    -- the animation: the first block lights up, then the second; the numbers change
    if not W.Animating() then print("STEP ERROR: workshop: the thumbnails do not animate at opening") end
    Row("hoverGlow").Step(1)
    local anim = g:GetScript("OnUpdate")
    local before = a.glideLast
    anim(g, 0.1)
    if a.glowTarget ~= 1 or b.glowTarget ~= 0 then print("STEP ERROR: animation: the first block does not light up first") end
    anim(g, 1.3)
    if b.glowTarget ~= 1 or a.glowTarget ~= 0 then print("STEP ERROR: animation: the second block does not light up next") end
    anim(g, 1.2)
    if a.glideLast == before then print("STEP ERROR: animation: the numbers do not change") end
    -- the box stops it; Fewer animations greys it and keeps everything still
    Row("animate").Step(1)
    if W.Animating() or a.glowTarget == 1 or b.glowTarget == 1 then print("STEP ERROR: animation: the box does not stop it") end
    Row("animate").Step(1)
    ns.sv.reduceMotion = true
    Row("animate").Refresh()
    if W.Animating() or Row("animate").control:IsEnabled() then print("STEP ERROR: animation: Fewer animations does not keep it still") end
    ns.sv.reduceMotion = nil
    -- closing the gallery while a thumbnail pulses: everything goes out, the animator stops
    while W.Value("glowShape", "hdGold", "hdGold") ~= "pulse" do Row("glowShape").Step(1) end
    anim(g, 2.4)
    g:Hide()
    local driver = ns.GlowAnimator and ns.GlowAnimator()
    for _ = 1, 30 do -- (real blocks may still be gliding: a few seconds of ticks)
        if driver and driver:GetScript("OnUpdate") then driver:GetScript("OnUpdate")(driver, 0.1) end
    end
    if driver and driver:GetScript("OnUpdate") then print("STEP ERROR: animation: the animator runs after the gallery closed") end
    if a.glowTarget or b.glowTarget then print("STEP ERROR: animation: a thumbnail still glows after closing") end
    -- the Style box holds the new rows too, in the same order
    local seen = {}
    for _, spec in ipairs(ns.LOOK_ROWS) do seen[spec.field] = true end
    for _, field in ipairs({ "separators", "separatorStyle", "glowShape", "glowColorMode" }) do
        if not seen[field] then print("STEP ERROR: Style box: no row " .. field) end
    end
    -- saved data (T2): a block from an old profile gets the halo in the style's color; a style
    -- text from before the glow shapes resets them; an unknown shape draws the halo
    local fresh = ns:GetBlockDefaults("gold")
    if fresh.glowShape ~= "halo" or fresh.glowColorMode ~= "style" then print("STEP ERROR: glow: wrong defaults") end
    for _, key in ipairs({ "gold", "time" }) do
        ns.db.blocks[key].glowShape, ns.db.blocks[key].glowColorMode = "pulse", "class"
    end
    local fx = assert(io.open(addonDir .. "/tools/fixtures/rc9-style.txt"), "missing fixture")
    local old = fx:read("*a")
    fx:close()
    if not ns:ImportStyle(old) then print("STEP ERROR: glow: the rc9 style text does not import") end
    for _, key in ipairs({ "gold", "time" }) do
        local cfg = ns.db.blocks[key]
        if cfg.glowShape ~= "halo" or cfg.glowColorMode ~= "style" then print("STEP ERROR: glow: an old style text left " .. key .. "'s glow shape") end
    end
    -- a new style text carries them, and imports twice to the same result
    ns.db.blocks.gold.glowShape, ns.db.blocks.gold.glowColorMode = "edge", "class"
    local text = ns:ExportStyle()
    ns.db.blocks.gold.glowShape, ns.db.blocks.gold.glowColorMode = "halo", "style"
    ns:ImportStyle(text)
    ns:ImportStyle(text)
    if ns.db.blocks.gold.glowShape ~= "edge" or ns.db.blocks.gold.glowColorMode ~= "class" then print("STEP ERROR: glow: a style text loses the glow shape") end
    local f = ns.frames and ns.frames.gold
    if f then
        local cfg = ns.db.blocks.gold
        cfg.hoverGlow, cfg.glowShape = true, "from a later version"
        ns.PrepareLife(f, cfg, 6)
        if f.glowFile ~= "hd_glow" then print("STEP ERROR: glow: an unknown shape does not draw the halo") end
        cfg.glowShape = "inner"
        ns.PrepareLife(f, cfg, 6)
        if f.glowFile ~= "hd_glow_inner" then print("STEP ERROR: glow: Inner does not draw its texture") end
    end
    for _, key in ipairs({ "gold", "time" }) do
        ns.db.blocks[key].glowShape, ns.db.blocks[key].glowColorMode = "halo", "style"
    end
    if themeBefore then ns:ApplyTheme(themeBefore) else ns:PickStyleChoice("auto") end
end
-- Look settings gathered (27/11): the Style box of the Style and layouts tab and the one at the top of
-- a block's Appearance tab hold the same rows in the same order; locked blocks keep theirs; Reset of
-- the box does not unlock; the separator shape reaches every block and draws its ornament
do
    local L = ns.L
    local function Fields(box)
        local list = {}
        for _, w in ipairs(box.rows) do if w.lookField then list[#list + 1] = w.lookField end end
        return table.concat(list, " ")
    end
    local function RowOf(label)
        for _, r in ipairs(ns.optionRows) do if r.label == label then return r end end
    end
    local want = {}
    for _, spec in ipairs(ns.LOOK_ROWS) do want[#want + 1] = spec.field end
    want = table.concat(want, " ")
    local lookRow, blockRow = RowOf(L.THEME), RowOf(L.BLOCK_STYLE)
    if not (lookRow and blockRow) then
        print("STEP ERROR: look box: style rows not found")
    else
        if Fields(lookRow.box) ~= want then print("STEP ERROR: look box: Style and layouts rows: " .. Fields(lookRow.box)) end
        if Fields(blockRow.box) ~= want then print("STEP ERROR: look box: block page rows: " .. Fields(blockRow.box)) end
        if blockRow.tabName ~= L.BLOCK_TAB_LOOK then print("STEP ERROR: look box: the block's style is not in the Appearance tab") end
        -- the style comes first in both boxes, and the block's box is the first of Appearance
        if lookRow.box.rows[2] ~= lookRow.frame then print("STEP ERROR: look box: the style is not first (Style and layouts)") end
        if blockRow.box.rows[1] ~= blockRow.frame then print("STEP ERROR: look box: the style is not first (block page)") end
        if ns.blockTabs.flows[2].boxes[1] ~= blockRow.box then print("STEP ERROR: look box: the Style box is not first in Appearance") end
        local lock = RowOf(L.STYLE_LOCK)
        if not (lock and lock.box == blockRow.box) then print("STEP ERROR: look box: the style lock is not in the Style box") end
        -- nothing taken away: each moved setting is found once in the block page (search, Show me)
        for _, label in ipairs({ L.FONT, L.FONT_SIZE, L.HOVER_GLOW, L.VALUE_GLIDE, L.EDGE_SHAPE, L.APPLY_STYLE_TO }) do
            local n = 0
            for _, r in ipairs(ns.optionRows) do if r.label == label and r.box == blockRow.box then n = n + 1 end end
            if n ~= 1 then print("STEP ERROR: look box: \"" .. label .. "\" found " .. n .. " times in the block's Style box") end
        end
        -- every block from Style and layouts: a locked block keeps its font and its glow
        local locked = "fps"
        ns.db.blocks[locked].styleLocked = true
        local keepFont, keepGlow = ns.db.blocks[locked].font, ns.db.blocks[locked].hoverGlow
        local font, glow
        for _, w in ipairs(lookRow.box.rows) do
            if w.lookField == "font" then font = w elseif w.lookField == "hoverGlow" then glow = w end
        end
        font.setter("inter")
        glow.setter(not keepGlow)
        if ns.db.blocks.gold.font ~= "inter" then print("STEP ERROR: look box: Font did not reach every block") end
        if ns.db.blocks.gold.hoverGlow ~= (not keepGlow) then print("STEP ERROR: look box: Glow did not reach every block") end
        if ns.db.blocks[locked].font ~= keepFont or ns.db.blocks[locked].hoverGlow ~= keepGlow then
            print("STEP ERROR: look box: a locked block lost its look")
        end
        if ns:AllBlocksField("font", "blocks") ~= "inter" then print("STEP ERROR: look box: a locked block makes Font look mixed") end
        -- the Accessibility tab's Font still reaches every block, locked ones too
        ns:SetAllBlocksFont("friz")
        if ns.db.blocks[locked].font ~= "friz" then print("STEP ERROR: look box: Accessibility Font left a locked block") end
        -- Reset of the block's Style box puts the look back but keeps the lock
        ns:SetOptionsSelection(locked)
        ns:RefreshOptions()
        StaticPopupDialogs["TESSERA_RESET_BOX"].OnAccept(nil, blockRow.box)
        if not ns.db.blocks[locked].styleLocked then print("STEP ERROR: look box: Reset unlocked the block") end
        ns.db.blocks[locked].styleLocked = nil
        ns:SetOptionsSelection("gold")
        ns:RefreshOptions()
    end
    -- separator shape: in the Separators box and for every block (Groups of blocks)
    local sepRow = RowOf(L.SEPARATOR_SHAPE)
    if not sepRow then print("STEP ERROR: separators: no shape setting") end
    local allSep
    for _, r in ipairs(ns.optionRows) do
        if r.label == L.SEPARATOR_SHAPE and r.section == L.SECTION_GROUP_LOOK then allSep = r.frame end
    end
    if not allSep then
        print("STEP ERROR: separators: no shape setting in Groups of blocks")
    else
        for _, key in ipairs({ "line", "drawn", "dash", "diamond", "rune", "smallDot", "dot" }) do
            local found = false
            for _, opt in ipairs(ns.SeparatorChoices()) do if opt.key == key and L[opt.name] ~= opt.name then found = true end end
            if not found or (key ~= "line" and not ns.SEPARATOR_FILES[key]) then print("STEP ERROR: separators: shape " .. key) end
        end
        ns.db.blocks.time.styleLocked = true
        local keep = ns.db.blocks.time.separatorStyle
        allSep.setter("dot")
        if ns.db.blocks.gold.separatorStyle ~= "dot" then print("STEP ERROR: separators: Dot did not reach every block") end
        if ns.db.blocks.time.separatorStyle ~= keep then print("STEP ERROR: separators: a locked block lost its shape") end
        ns.db.blocks.time.styleLocked = nil
        allSep.setter("line")
    end
end
-- Language list (1.8): the choice is saved, a change offers the reload, "as the game" does not
do
    local asked = {}
    local realShow = StaticPopup_Show
    StaticPopup_Show = function(which) asked[#asked + 1] = which end
    -- the list holds the languages that have texts (a file registers itself), not the empty ones
    local listed = {}
    for _, entry in ipairs(ns.LANGUAGES) do listed[#listed + 1] = entry.key end
    if table.concat(listed, " ") ~= "enUS frFR deDE esES esMX ptBR" then print("STEP ERROR: languages listed: " .. table.concat(listed, " ")) end
    local other = ns.GetLanguage() == "deDE" and "ptBR" or "deDE"
    ns:SetLanguageChoice(other)
    if ns.sv.language ~= other or ns.GetLanguageChoice() ~= other then print("STEP ERROR: the language choice is not saved") end
    if asked[1] ~= "TESSERA_LANGUAGE_RELOAD" then print("STEP ERROR: a language change does not offer the reload") end
    local popup = StaticPopupDialogs["TESSERA_LANGUAGE_RELOAD"]
    if not (popup and popup.text == ns.L.LANGUAGE_RELOAD) then print("STEP ERROR: the language reload window has no text") end
    asked = {}
    ns:SetLanguageChoice(nil)
    if ns.sv.language ~= nil or #asked > 0 then print("STEP ERROR: \"As the game\" must save nothing and ask nothing") end
    if ns.TextLanguage() ~= (GetLocale() == "frFR" and "fr" or "en") then print("STEP ERROR: text language of the changelog") end
    StaticPopup_Show = realShow
end
-- Options that must never get lost (rule: a rework takes nothing away). Dump with
-- MOCK_WRITE_OPTIONS=1 on a version known good; then every run (enUS only) checks that each
-- recorded option still exists, or that tools/options_renames.txt says what it became.
if os.getenv("MOCK_WRITE_OPTIONS") then
    local list = {}
    for title in pairs(ns.optionsSeen or {}) do list[#list + 1] = title end
    table.sort(list)
    local out = assert(io.open("tools/options_baseline.txt", "w"))
    for _, title in ipairs(list) do out:write(title, "\n") end
    out:close()
    print("options baseline written: " .. #list)
elseif GetLocale() == "enUS" then
    local function readLines(path)
        local fh = io.open(path, "r")
        if not fh then return nil end
        local lines = {}
        for line in fh:lines() do
            if line ~= "" and line:sub(1, 1) ~= "#" then lines[#lines + 1] = line end
        end
        fh:close()
        return lines
    end
    local baseline, renameLines = readLines("tools/options_baseline.txt"), readLines("tools/options_renames.txt") or {}
    local renames = {}
    for _, line in ipairs(renameLines) do
        local old, new = line:match("^(.-)\t(.+)$")
        if old then renames[old] = new else print("STEP ERROR: tools/options_renames.txt needs 'old<TAB>new': " .. line) end
    end
    if not baseline then
        print("STEP ERROR: tools/options_baseline.txt is missing")
    else
        local lost = 0
        for _, title in ipairs(baseline) do
            if not ns.optionsSeen[title] and not (renames[title] and ns.optionsSeen[renames[title]]) then
                lost = lost + 1
                print("STEP ERROR: option lost: " .. title)
            end
        end
        print("options checked: " .. #baseline .. ", lost: " .. lost)
    end
end
-- Placing to the pixel (1.3, lot 5): "Place" folds the window, the arrows move the
-- whole group by real pixels, Escape puts it back, Enter keeps it (one undo step)
do
    MOCK_GEOMETRY = true
    local physical = GetPhysicalScreenSize
    GetPhysicalScreenSize = function() return 1920, 1080 end
    ns:ResetProfile("top")
    ns:UpdateLayout()
    local key
    for _, k in ipairs(ns:GetBlockKeys()) do
        local c = ns.db.blocks[k]
        if c.enabled and c.dock and not ns.IsSpacerKey(k) then key = k break end
    end
    if not key then print("STEP ERROR: placing: no block inside a group") end
    ns:SetLocked(true, true)
    if not TesseraOptions:IsShown() then ns:ToggleOptions() end
    ns:OpenOptionsFor(key)
    ns:RefreshOptions()
    if not (ns.placeButton and ns:CanNudge(key)) then print("STEP ERROR: placing: no \"Place\" button for a block on screen") end
    ns.sv.placeNoticeSeen = nil
    ns.placeButton:GetScript("OnClick")(ns.placeButton)
    local b = ns.banner
    if not ns.nudge then print("STEP ERROR: placing: \"Place\" did not start") end
    if ns.db.locked then print("STEP ERROR: placing: blocks still locked") end
    if not (TesseraOptions:IsShown() and TesseraOptions.folded) then print("STEP ERROR: placing: the options window is not folded to its bar") end
    if not (b and b:IsShown() and b.pad and b.pad:IsShown()) then print("STEP ERROR: placing: no pad on the banner") end
    if not b.pad.notice:IsShown() then print("STEP ERROR: placing: no first-time message") end
    -- a frame without a height draws nothing in the game (test102: empty banner)
    local top, bottom = false, false
    for _, pt in ipairs(b.pad.__points or {}) do
        if pt[1]:find("TOP") then top = true end
        if pt[1]:find("BOTTOM") then bottom = true end
    end
    if not (top and bottom) and (b.pad.__h or 0) <= 0 then print("STEP ERROR: placing: the pad has no height") end
    b.pad.gotIt:GetScript("OnClick")(b.pad.gotIt)
    if not ns.sv.placeNoticeSeen or b.pad.notice:IsShown() then print("STEP ERROR: placing: \"Got it\" does not hide the message") end
    local root = ns:GetRoot(key)
    local x0, y0 = ns:GetNudgePosition(key)
    local before = ns.DeepCopy(ns.db.blocks[root].point)
    ns:NudgeBy(key, 1, 0)
    local x1, y1 = ns:GetNudgePosition(key)
    if x1 ~= x0 + 1 or y1 ~= y0 then print("STEP ERROR: placing: one step is not one pixel: " .. tostring(x1 - x0) .. ", " .. tostring(y1 - y0)) end
    -- keyboard: Shift + down arrow = 10 pixels (the bar is at the top of the screen)
    local shift = IsShiftKeyDown
    IsShiftKeyDown = function() return true end
    b:GetScript("OnKeyDown")(b, "DOWN")
    b:GetScript("OnKeyUp")(b, "DOWN")
    IsShiftKeyDown = shift
    local x2, y2 = ns:GetNudgePosition(key)
    if x2 ~= x1 or y2 ~= y1 - 10 then print("STEP ERROR: placing: Shift + arrow is not 10 pixels") end
    ns:SetNudgePosition(key, 300, 200)
    local x3, y3 = ns:GetNudgePosition(key)
    if x3 ~= 300 or y3 ~= 200 then print("STEP ERROR: placing: typed X and Y not reached: " .. tostring(x3) .. ", " .. tostring(y3)) end
    -- the group stays on the screen
    ns:SetNudgePosition(key, 99999, 99999)
    local al, ab, ar, at
    for k in pairs(ns:GetDragSet(root)) do
        local f = ns.frames[k]
        if f and f:IsShown() then
            local l, bb, r, t = ns:GetRectUI(f)
            al, ab = math.min(al or l, l), math.min(ab or bb, bb)
            ar, at = math.max(ar or r, r), math.max(at or t, t)
        end
    end
    if ar > UIParent:GetWidth() + 0.01 or at > UIParent:GetHeight() + 0.01 then print("STEP ERROR: placing: the group left the screen") end
    -- in combat: nothing moves
    InCombatLockdown = function() return true end
    if ns:NudgeBy(key, 1, 0) then print("STEP ERROR: placing: moved in combat") end
    InCombatLockdown = function() return false end
    -- Escape: back to the start, locked again, window unfolded
    b:GetScript("OnKeyDown")(b, "ESCAPE")
    ns:UpdateLayout()
    local x4, y4 = ns:GetNudgePosition(key)
    if ns.nudge then print("STEP ERROR: placing: Escape did not stop") end
    if x4 ~= x0 or y4 ~= y0 then print("STEP ERROR: placing: Escape did not put the group back") end
    local p = ns.db.blocks[root].point
    if not (p and before and p[3] == before[3] and p[4] == before[4]) then print("STEP ERROR: placing: Escape left another saved point") end
    if not ns.db.locked then print("STEP ERROR: placing: blocks not locked again") end
    if TesseraOptions.folded or not TesseraOptions:IsShown() then print("STEP ERROR: placing: options window not opened again") end
    -- Enter keeps the place; Ctrl + Z then undoes the whole placement
    ns:StartNudge(key)
    if b.snapCheck and b.snapCheck:IsShown() then print("STEP ERROR: placing by pixel: the banner checks overlap the arrows") end
    for _ = 1, 3 do ns:NudgeBy(key, 1, 0) end
    b:GetScript("OnKeyDown")(b, "ENTER")
    local x5 = ns:GetNudgePosition(key)
    if ns.nudge or x5 ~= x0 + 3 then print("STEP ERROR: placing: Enter did not keep the place") end
    ns:Undo()
    ns:UpdateLayout()
    if (ns:GetNudgePosition(key)) ~= x0 then print("STEP ERROR: placing: Ctrl + Z after Enter does not undo the placement") end
    -- the "Empty blocks" button: in the banner and in the pad, V toggles, locking resets
    ns:StartNudge(key)
    if not (b.emptyBtn and b.pad and b.pad.empty) then print("STEP ERROR: placing: no Empty blocks button") end
    b:GetScript("OnKeyDown")(b, "V")
    if not ns.placeHideEmpty or b.pad.empty:GetText() ~= ns.L.EMPTY_BLOCKS_HIDDEN or b.emptyBtn:GetText() ~= ns.L.EMPTY_BLOCKS_HIDDEN then
        print("STEP ERROR: placing: V did not hide the empty blocks on both buttons")
    end
    b.pad.empty:GetScript("OnClick")(b.pad.empty)
    if ns.placeHideEmpty or b.emptyBtn:GetText() ~= ns.L.EMPTY_BLOCKS_SHOWN then print("STEP ERROR: placing: the pad button did not show them again") end
    ns:FinishNudge(false)
    -- the saved point still exports and imports (decimals in the offsets)
    ns:StartNudge(key)
    ns:NudgeBy(key, 1, 1)
    ns:FinishNudge(true)
    local text = ns:ExportProfile()
    if text and ns.ImportProfile then
        local ok = ns:ImportProfile(text, "nudge-check")
        if not ok then print("STEP ERROR: placing: a profile with a placed group does not import") end
    end
    -- nothing moved: no empty undo step
    local depth = #(ns.undoStack or {})
    ns:StartNudge(key)
    ns:FinishNudge(true)
    if #(ns.undoStack or {}) ~= depth then print("STEP ERROR: placing: an empty undo step was left") end
    -- a click on a block of another group while placing: that group is placed from now on
    local other
    for _, k in ipairs(ns:GetBlockKeys()) do
        local c = ns.db.blocks[k]
        if c.enabled and c.dock and k ~= key and not ns.IsSpacerKey(k) then
            ns:Detach(k) -- a second group
            ns:UpdateLayout()
            if ns:CanNudge(k) and ns:GetRoot(k) ~= ns:GetRoot(key) then other = k break end
        end
    end
    ns:StartNudge(key)
    if not other then print("STEP ERROR: placing: no second group to click") end
    if other then
        local f = ns.frames[other]
        f.dragMoved = false
        f:GetScript("OnMouseUp")(f, "LeftButton")
        if ns.nudge.key ~= other then print("STEP ERROR: placing: a click on another block does not switch to it") end
    end
    ns:FinishNudge(false)
    -- from the banner, with no block chosen: the player picks one; the window stays closed
    TesseraOptions:Hide()
    ns:SetLocked(false, true)
    ns:StartNudge(nil, true)
    if not (ns.nudge and ns.nudge.key == nil) then print("STEP ERROR: placing: the banner's \"Place\" does not ask for a block") end
    ns:SetNudgeTarget(key)
    if ns.nudge.key ~= key then print("STEP ERROR: placing: picking a block does not start placing it") end
    ns:FinishNudge(true)
    if TesseraOptions:IsShown() then print("STEP ERROR: placing: the options window opened though placing started from the banner") end
    -- a block shown while the banner is up never lands under it: it appears above it
    do
        local nk = "zone"
        local nc = ns.db.blocks[nk]
        nc.enabled, nc.point, nc.dock, nc.anchor = false, nil, nil, nil
        ns:SetBlocksOnScreen({ nk }, true)
        local bl, bb, br, bt = ns:GetRectUI(ns.banner)
        local fl, fb, fr, ft = ns:GetRectUI(ns.frames[nk])
        if not (bl and fl) then print("STEP ERROR: banner: no rectangle to compare")
        elseif fl < br and fr > bl and fb < bt and ft > bb then
            print("STEP ERROR: banner: a new block was placed under the placement banner")
        elseif fb < bt then print("STEP ERROR: banner: a new block is not above the placement banner") end
    end
    -- the same with the options window open: the new block still lands above the banner, over its width (test139)
    do
        ns:OpenOptions()
        for _, nk in ipairs({ "speed", "regen" }) do
            local nc = ns.db.blocks[nk]
            nc.enabled, nc.point, nc.dock, nc.anchor = false, nil, nil, nil
            ns:SetBlocksOnScreen({ nk }, true)
            local bl, bb, br, bt = ns:GetRectUI(ns.banner)
            local fl, fb, fr = ns:GetRectUI(ns.frames[nk])
            if not (bl and fl) then print("STEP ERROR: banner: no rectangle to compare (options open)")
            elseif fb < bt then print("STEP ERROR: banner: with the options window open, " .. nk .. " is not above the banner")
            elseif fr < bl or fl > br then print("STEP ERROR: banner: with the options window open, " .. nk .. " lands beside the banner, not over it") end
        end
        -- the options window over the row above the banner (test141, in game): the block still goes right
        -- above the banner, not to the far side of the screen
        local bl, bb, br, bt = ns:GetRectUI(ns.banner)
        TesseraOptions:ClearAllPoints()
        TesseraOptions:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", bl - 40, bb - 50)
        TesseraOptions:SetSize(br - bl + 80, bt - bb + 250)
        local nk = "subzone"
        local nc = ns.db.blocks[nk]
        nc.enabled, nc.point, nc.dock, nc.anchor = false, nil, nil, nil
        ns:SetBlocksOnScreen({ nk }, true)
        local fl, fb, fr = ns:GetRectUI(ns.frames[nk])
        if not fl then print("STEP ERROR: banner: no rectangle (options over the banner)")
        elseif fb < bt or fr < bl or fl > br then
            print(("STEP ERROR: banner: options over the banner, %s lands at %d,%d instead of over the banner (%d-%d)"):format(nk, fl, fb, bl, br))
        end
        TesseraOptions:Hide()
    end
    -- the banner's grid: G gives the next size, the arrows too
    ns.db.grid = 0
    b:GetScript("OnKeyDown")(b, "G")
    if ns.db.grid ~= 8 then print("STEP ERROR: banner: G does not change the grid") end
    b.gridPrev:GetScript("OnClick")(b.gridPrev)
    if ns.db.grid ~= 0 then print("STEP ERROR: banner: the grid arrow does not go back") end
    ns:SetLocked(true, true)
    GetPhysicalScreenSize = physical
    MOCK_GEOMETRY = false
    ns:ResetProfile("top")
end
-- 2.0 styles in a fused bar (2.0.0): an ornament at each join instead of a line, rounded
-- corners only where no block touches (the fill is squared under the hidden corners)
do
    MOCK_GEOMETRY = true
    ns:ResetProfile("top")
    ns:ApplyTheme("hdGold")
    ns:UpdateLayout()
    local ornate, lines, squared = 0, 0, 0
    for _, f in pairs(ns.frames) do
        for _, tex in ipairs(f.ornatePool or {}) do if tex:IsShown() then ornate = ornate + 1 end end
        for _, tex in ipairs(f.separatorPool or {}) do if tex:IsShown() then lines = lines + 1 end end
        if f.tesseraHD and f.TopRightCorner and not f.TopRightCorner:IsShown() then
            squared = squared + 1
            assert(f.tesseraHDFill.TopRightCorner:GetTexture() == "Interface\\Buttons\\WHITE8X8", "square fill at a join")
        end
        if f.tesseraHD and f.TopLeftCorner and f.TopLeftCorner:IsShown() then
            assert(f.tesseraHDFill.TopLeftCorner:GetTexture():find("hd_fill", 1, true), "rounded fill at a free corner")
        end
    end
    assert(ornate > 0 and lines == 0, "2.0 bar: ornaments, no lines (" .. ornate .. ", " .. lines .. ")")
    assert(squared > 0, "2.0 bar: corners hidden at the joins")
    -- the separator shape (27/11): Dot for every block draws the dot's drawing at each join
    ns:SetAllBlocksField("separatorStyle", "dot", "blocks")
    ns:UpdateLayout()
    local drawn, dot = 0, 0
    for _, f in pairs(ns.frames) do
        for _, tex in ipairs(f.ornatePool or {}) do
            if tex:IsShown() then
                drawn = drawn + 1
                if tostring(tex:GetTexture()):find("hd_sep_dot", 1, true) then dot = dot + 1 end
            end
        end
    end
    assert(drawn > 0 and dot == drawn, "Dot separators: " .. dot .. " of " .. drawn)
    ns:ApplyTheme("hdGold")
    ns:UpdateLayout()
    -- the whole group stays on the screen as one piece: only group heads are clamped, their
    -- clamp rectangle covers the group (27/11: a wider font opened a gap at the screen edge)
    local heads, docked = 0, 0
    for key, f in pairs(ns.frames) do
        if f:IsShown() and ns.db.blocks[key] then
            if ns:GetEffectiveDock(key) then
                docked = docked + 1
                assert(f.__clamped == false, "docked block not clamped alone: " .. key)
            elseif ns:GetSubtree(key) and next(ns:GetSubtree(key)) then
                heads = heads + 1
                assert(f.__clamped == true and f.__insets, "group head clamped: " .. key)
                local ins = f.__insets
                assert(ins[1] <= 0 and ins[2] >= 0 and ins[3] >= 0 and ins[4] <= 0, "clamp covers the group: " .. key)
            end
        end
    end
    assert(heads > 0 and docked > 0, "a bar with a head and docked blocks")
    ns:ApplyTheme("flat")
    MOCK_GEOMETRY = false
    ns:ResetProfile("top")
end
-- Separator lines follow their check box at once (1.6.1 drew them again only at the next layout:
-- ticking or unticking "Line between merged blocks" showed nothing until a reload or a style change)
do
    local L = ns.L
    MOCK_GEOMETRY = true
    ns:ResetProfile("top")
    ns:ApplyTheme("flareui6") -- a style with lines between the blocks
    ns:UpdateLayout()
    local function Lines(k)
        local n = 0
        for _, t in ipairs(ns.frames[k].separatorPool or {}) do if t:IsShown() then n = n + 1 end end
        return n
    end
    local key
    for _, k in ipairs(ns:GetBlockKeys()) do
        local c, f = ns.db.blocks[k], ns.frames[k]
        if c.enabled and c.dock and f and f:IsShown() and not ns.IsSpacerKey(k) and Lines(k) > 0 then key = k break end
    end
    if not key then
        print("STEP ERROR: separators: no block draws a line with the FlareUI style")
    else
        local function Find(label)
            for _, r in ipairs(ns.optionWidgets) do
                if r.frame.__shown and (r.frame.headerText or r.label) == label then return r.frame end
            end
        end
        ns:OpenOptionsFor(key)
        local row
        for sub = 1, 5 do
            ns.ShowBlockSub(sub)
            ns:RefreshOptions()
            row = Find(L.SEPARATORS)
            if row then break end
        end
        if not (row and row.check) then
            print("STEP ERROR: separators: the check box is not on the block's page")
        else
            -- (the mock's check box always reports "not checked": the row's own setter is what a click calls)
            row.setter(false)
            if ns.db.blocks[key].separators ~= false or Lines(key) ~= 0 then
                print("STEP ERROR: separators: unticking the box did not remove the lines of " .. key .. " (" .. Lines(key) .. " left)")
            end
            row.setter(true)
            if ns.db.blocks[key].separators ~= true or Lines(key) == 0 then
                print("STEP ERROR: separators: ticking the box did not bring the lines of " .. key .. " back (sep=" .. tostring(ns.db.blocks[key].separators) .. ", lines=" .. Lines(key) .. ")")
            end
        end
    end
    -- the lines sit on whole screen pixels (1080 pixels high: one pixel is 0.711 units, so
    -- block edges fall between pixels) and stay inside their block
    if key then
        local physical = GetPhysicalScreenSize
        GetPhysicalScreenSize = function() return 1920, 1080 end
        local unit = 768 / 1080
        local function OnPixel(v) return math.abs(v / unit - math.floor(v / unit + 0.5)) < 1e-4 end
        ns:UpdateLayout()
        local checked, fractional = 0, false
        for _, k in ipairs(ns:GetBlockKeys()) do
            local f = ns.frames[k]
            if f and f:IsShown() and not OnPixel(f:GetRight()) then fractional = true end
            for _, t in ipairs(f and f.separatorPool or {}) do
                if t:IsShown() then
                    checked = checked + 1
                    local vertical = t:GetWidth() < t:GetHeight()
                    local edge = vertical and t:GetRight() or t:GetBottom()
                    if not OnPixel(edge) or not OnPixel(t:GetLeft()) or not OnPixel(t:GetTop()) then
                        print("STEP ERROR: separators: a line of " .. k .. " is not on whole pixels (" .. edge .. ")")
                        break
                    end
                    if (vertical and t:GetRight() > f:GetRight() + 1e-6) or (not vertical and t:GetBottom() < f:GetBottom() - 1e-6) then
                        print("STEP ERROR: separators: a line of " .. k .. " goes past its block")
                        break
                    end
                end
            end
        end
        if checked == 0 or not fractional then
            print("STEP ERROR: separators: pixel test found no line (" .. checked .. ") or no block between two pixels")
        end
        GetPhysicalScreenSize = physical
        ns:UpdateLayout()
    end
    MOCK_GEOMETRY = false
    ns:ResetProfile("top")
end
print("mock run finished")
