local _, ns = ...
local L = ns.L

-- Blocks about the world: zone, coordinates, clocks, instances, resets.
-- Shared tools come from Modules.lua (ns.BlockTools); see its header for how to add a block.
local Tools = ns.BlockTools
local FormatDuration, GOOD, ShortDuration, ShortTime = Tools.FormatDuration, Tools.GOOD, Tools.ShortDuration, Tools.ShortTime
local Try, WARN = Tools.Try, Tools.WARN
local WHITE, session = Tools.WHITE, Tools.session

---------------------------------------------------------------------------
-- Local time and server time
---------------------------------------------------------------------------
-- "HH:MM" (24 h) or "H:MM AM/PM" (12 h), per the block's "24-hour clock" option,
-- with ":SS" when the block shows the seconds
local function FormatClock(h, m, cfg, sec)
    h, m = h or 0, m or 0
    local seconds = (cfg and cfg.showSeconds and sec) and (":%02d"):format(sec) or ""
    if cfg and cfg.clock24 == false then
        local suffix = h >= 12 and "PM" or "AM"
        h = h % 12
        if h == 0 then h = 12 end
        return ("%d:%02d%s %s"):format(h, m, seconds, suffix)
    end
    return ("%02d:%02d%s"):format(h, m, seconds)
end

-- Local time of the computer
local function LocalTime(cfg)
    local t = date("*t")
    return FormatClock(t.hour, t.min, cfg, t.sec)
end

-- Server (realm) time; the game gives hours and minutes only: the seconds come from
-- the server's clock (time zones are whole minutes, so its seconds are the realm's)
local function ServerTime(cfg)
    local h, m = GetGameTime()
    local now = GetServerTime and GetServerTime() or time()
    return FormatClock(h, m, cfg, now % 60)
end

local CLOCK_OPTION = { kind = "check", field = "clock24", tab = "text", label = "CLOCK_24", tip = "TIP_CLOCK_24" }
local SECONDS_OPTION = { kind = "check", field = "showSeconds", tab = "text", label = "SHOW_SECONDS", tip = "TIP_SHOW_SECONDS" }

-- Tooltip shared by both time blocks
local function TimeTooltip(tt, cfg)
    tt:AddDoubleLine(L.TT_LOCAL_TIME, LocalTime(cfg), 1, 1, 1, 1, 1, 1)
    tt:AddDoubleLine(L.TT_SERVER_TIME, ServerTime(cfg), 1, 1, 1, 1, 1, 1)
    tt:AddDoubleLine(L.TT_SESSION_TIME, FormatDuration(GetTime() - session.start), 1, 1, 1, 1, 1, 1)
    tt:AddLine(date("%d/%m/%Y"), 0.8, 0.8, 0.8)
end

-- Does WoW's own clock show local time? (otherwise it shows server time)
-- Modern C_CVar API first, classic GetCVar global as fallback
local function WowClockIsLocal()
    local v = (C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("timeMgrUseLocalTime"))
        or (GetCVar and GetCVar("timeMgrUseLocalTime"))
    return v == "1"
end

-- Which time the "time" block shows: "server", "local", or "auto" = the one
-- WoW's clock does not already show
local function ShowsServerTime(cfg)
    local source = cfg and cfg.timeSource or "auto"
    if source == "server" then return true end
    if source == "local" then return false end
    return WowClockIsLocal()
end
ns.ShowsServerTime = ShowsServerTime

ns:RegisterModule("time", {
    label = "TIME",
    icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    interval = 1,
    update = function(cfg)
        if ShowsServerTime(cfg) then return ServerTime(cfg) end
        return LocalTime(cfg)
    end,
    options = {
        { kind = "dropdown", field = "timeSource", tab = "text", label = "TIME_SOURCE", tip = "TIP_TIME_SOURCE",
          values = { { key = "auto", label = "TIME_AUTO" }, { key = "local", label = "TT_LOCAL_TIME" },
                     { key = "server", label = "TT_SERVER_TIME" } } },
        CLOCK_OPTION,
        SECONDS_OPTION,
    },
    defaults = { showSeconds = false },
    tooltip = TimeTooltip,
    secureMacro = "/run if ToggleCalendar then ToggleCalendar() end",
    clickHint = L.HINT_CALENDAR,
})

ns:RegisterModule("serverTime", {
    label = "SERVER_TIME",
    icon = "Interface\\Icons\\INV_Misc_PocketWatch_02",
    interval = 1,
    defaultEnabled = false,
    update = ServerTime,
    options = { CLOCK_OPTION, SECONDS_OPTION },
    defaults = { showSeconds = false },
    tooltip = TimeTooltip,
    secureMacro = "/run if ToggleCalendar then ToggleCalendar() end",
    clickHint = L.HINT_CALENDAR,
})

---------------------------------------------------------------------------
-- Date
---------------------------------------------------------------------------
-- Full day and month names come from the game's own texts (translated in every
-- language); short names from Tessera's (a list per language, e.g. "Jan,Feb,..."),
-- since cutting a name gives wrong abbreviations in some languages.
local WEEKDAYS = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" }
local MONTHS = { "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER",
    "OCTOBER", "NOVEMBER", "DECEMBER" }

local function ShortNames(list)
    local names = {}
    for name in (list or ""):gmatch("[^,]+") do table.insert(names, name) end
    return names
end
local SHORT_DAYS, SHORT_MONTHS = ShortNames(L.DATE_DAYS_SHORT), ShortNames(L.DATE_MONTHS_SHORT)

local function TitleCase(s)
    return (s:gsub("^%l", string.upper))
end

-- Today's date, local or server ("realm") one: { year, month, day, wday } (wday 1 = Sunday)
local function Today(server)
    if server then
        local get = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime
        local ok, t = pcall(function() return get and get() end)
        if ok and type(t) == "table" and t.monthDay then
            return { year = t.year, month = t.month, day = t.monthDay, wday = t.weekday }
        end
    end
    local t = date("*t")
    return { year = t.year, month = t.month, day = t.day, wday = t.wday }
end

-- Formats a date: short "Thu 15 Oct", long "Thursday 15 October", dmy "15/10/2026", dm
-- "15/10", mdy "10/15/2026", iso "2026-10-15" (the order of the named formats is a text
-- of each language: {wd} day name, {d} day, {mon} month name, {y} year)
local function FormatDate(t, format)
    if format == "dmy" then return ("%02d/%02d/%d"):format(t.day, t.month, t.year) end
    if format == "dm" then return ("%02d/%02d"):format(t.day, t.month) end
    if format == "mdy" then return ("%02d/%02d/%d"):format(t.month, t.day, t.year) end
    if format == "iso" then return ("%d-%02d-%02d"):format(t.year, t.month, t.day) end
    local wd, mon, pattern
    if format == "long" then
        wd = _G["WEEKDAY_" .. (WEEKDAYS[t.wday] or "")] or WEEKDAYS[t.wday] or "?"
        mon = _G["FULLDATE_MONTH_" .. (MONTHS[t.month] or "")] or MONTHS[t.month] or "?"
        pattern = L.DATE_PATTERN_LONG
    else
        wd, mon, pattern = SHORT_DAYS[t.wday] or "?", SHORT_MONTHS[t.month] or "?", L.DATE_PATTERN_SHORT
    end
    local text = pattern:gsub("{(%a+)}", { wd = wd, d = tostring(t.day), mon = mon, y = tostring(t.year) })
    return TitleCase(text)
end
ns.FormatDate = FormatDate

local function SameDay(a, b)
    return a.year == b.year and a.month == b.month and a.day == b.day
end

ns:RegisterModule("date", {
    label = "DATE",
    icon = "Interface\\Icons\\INV_Scroll_05",
    interval = 30,
    defaultEnabled = false,
    defaults = { dateFormat = "short", dateSource = "local" },
    update = function(cfg)
        return FormatDate(Today(cfg.dateSource == "server"), cfg.dateFormat)
    end,
    options = {
        { kind = "dropdown", field = "dateFormat", tab = "text", label = "DATE_FORMAT", tip = "TIP_DATE_FORMAT",
          values = { { key = "short", label = "DATE_FMT_SHORT" }, { key = "long", label = "DATE_FMT_LONG" },
                     { key = "dmy", label = "DATE_FMT_DMY" }, { key = "dm", label = "DATE_FMT_DM" },
                     { key = "mdy", label = "DATE_FMT_MDY" }, { key = "iso", label = "DATE_FMT_ISO" } } },
        { kind = "dropdown", field = "dateSource", tab = "text", label = "DATE_SOURCE", tip = "TIP_DATE_SOURCE",
          values = { { key = "local", label = "TT_LOCAL_DATE" }, { key = "server", label = "TT_SERVER_DATE" } } },
    },
    tooltip = function(tt)
        local here, realm = Today(false), Today(true)
        tt:AddDoubleLine(L.TT_LOCAL_DATE, FormatDate(here, "long"), 1, 1, 1, 1, 1, 1)
        if not SameDay(here, realm) then
            tt:AddDoubleLine(L.TT_SERVER_DATE, FormatDate(realm, "long"), 1, 1, 1, 1, 1, 1)
        end
    end,
    secureMacro = "/run if ToggleCalendar then ToggleCalendar() end",
    clickHint = L.HINT_CALENDAR,
})

---------------------------------------------------------------------------
-- Coordinates and zone
---------------------------------------------------------------------------
ns:RegisterModule("coords", {
    label = "COORDS",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
    interval = 0.25,
    defaultEnabled = false,
    update = function(cfg)
        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return nil end
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if not pos then return nil end
        local x, y = pos:GetXY()
        if not x or (x == 0 and y == 0) then return nil end
        local d = math.max(0, math.min(2, math.floor(tonumber(cfg and cfg.coordDecimals) or 1)))
        local f = "%." .. d .. "f"
        return (f .. ", " .. f):format(x * 100, y * 100)
    end,
    options = {
        { kind = "slider", field = "coordDecimals", tab = "text", label = "COORD_DECIMALS", tip = "TIP_COORD_DECIMALS",
          min = 0, max = 2, step = 1, default = 1 },
    },
    tooltip = function(tt)
        local mapID = C_Map.GetBestMapForUnit("player")
        local info = mapID and C_Map.GetMapInfo(mapID)
        if info then tt:AddLine(info.name, 1, 1, 1) end
        local sub = GetSubZoneText()
        if sub and sub ~= "" then tt:AddDoubleLine(L.TT_SUBZONE, sub, 0.8, 0.8, 0.8, 1, 1, 1) end
    end,
    secureMacro = "/run ToggleWorldMap()",
    clickHint = L.HINT_MAP,
    -- "Zone (x, y)" for Shift + click "copy to chat"
    chatText = function()
        local mapID = C_Map.GetBestMapForUnit("player")
        local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        if not pos then return nil end
        local x, y = pos:GetXY()
        local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
        return ("%s (%.1f, %.1f)"):format(zone or "", x * 100, y * 100)
    end,
    -- extra click action: place a map pin on the player's position (middle click by default)
    extraAction = {
        key = "waypoint", label = "ACTION_WAYPOINT",
        run = function()
            local mapID = C_Map.GetBestMapForUnit("player")
            local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
            if not (pos and C_Map.SetUserWaypoint and UiMapPoint) then return end
            local x, y = pos:GetXY()
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
        end,
    },
    defaults = { middleClick = "waypoint", coordDecimals = 1 },
})

-- Tooltip shared by the zone and subzone blocks
local function ZoneTooltip(tt)
    tt:AddDoubleLine(L.ZONE, GetRealZoneText() or "", 0.8, 0.8, 0.8, 1, 1, 1)
    local sub = GetSubZoneText()
    if sub and sub ~= "" then tt:AddDoubleLine(L.TT_SUBZONE, sub, 0.8, 0.8, 0.8, 1, 1, 1) end
end

ns:RegisterModule("zone", {
    label = "ZONE",
    icon = "Interface\\Icons\\Ability_Hunter_Pathfinding",
    events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" },
    defaultEnabled = false,
    -- main zone (e.g. Stormwind), without the subzone; or "Zone - Subzone"
    update = function(cfg)
        local text = GetRealZoneText and GetRealZoneText() or GetZoneText()
        if text == "" then return nil end
        local sub = cfg and cfg.zoneShown == "both" and GetSubZoneText()
        if sub and sub ~= "" and sub ~= text then return ("%s - %s"):format(text, sub) end
        return text
    end,
    defaults = { zoneShown = "zone" },
    options = {
        { kind = "dropdown", field = "zoneShown", tab = "text", label = "ZONE_SHOWN", tip = "TIP_ZONE_SHOWN",
          values = { { key = "zone", label = "ZONE_ONLY" }, { key = "both", label = "ZONE_AND_SUBZONE" } } },
    },
    tooltip = ZoneTooltip,
    secureMacro = "/run ToggleWorldMap()",
    clickHint = L.HINT_MAP,
})

ns:RegisterModule("subzone", {
    label = "SUBZONE",
    icon = "Interface\\Icons\\INV_Misc_Map02",
    events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" },
    defaultEnabled = false,
    -- subzone (e.g. Trade District); the zone when there is no subzone
    update = function()
        local sub = GetSubZoneText()
        if sub and sub ~= "" then return sub end
        local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
        return zone ~= "" and zone or nil
    end,
    tooltip = ZoneTooltip,
    secureMacro = "/run ToggleWorldMap()",
    clickHint = L.HINT_MAP,
})

---------------------------------------------------------------------------
-- Hearthstone: bound location and cooldown; click = use it
---------------------------------------------------------------------------
-- Hearthstone item id
local HEARTHSTONE = 6948

-- Seconds left on the Hearthstone cooldown (0 = ready). Modern C_Container API first,
-- classic global as fallback. The math runs in pcall because on Midnight-era clients
-- the values can be "secret" and comparing them throws an error
local function HearthCooldown()
    local start, duration
    if C_Container and C_Container.GetItemCooldown then
        start, duration = Try(C_Container.GetItemCooldown, HEARTHSTONE)
    end
    local ok, remaining = pcall(function()
        if start and duration and start > 0 and duration > 1.5 then
            return math.max(0, start + duration - GetTime())
        end
        return 0
    end)
    return ok and remaining or 0
end

ns:RegisterModule("hearthstone", {
    label = "HEARTHSTONE",
    icon = "Interface\\Icons\\INV_Misc_Rune_01",
    interval = 1,
    defaultEnabled = false,
    update = function()
        local location = Try(GetBindLocation) or "?"
        local cd = HearthCooldown()
        if cd > 0 then return ("%s · %s"):format(location, ShortTime(cd)), WARN end
        return location, GOOD
    end,
    tooltip = function(tt)
        WHITE(tt, L.TT_BIND_LOCATION, Try(GetBindLocation) or "?")
        local cd = HearthCooldown()
        if cd > 0 then
            tt:AddDoubleLine(L.TT_COOLDOWN, ShortTime(cd), 1, 1, 1, 1, 0.6, 0.2)
        else
            tt:AddDoubleLine(L.TT_COOLDOWN, L.TT_READY, 1, 1, 1, 0.3, 1, 0.3)
        end
    end,
    secureMacro = "/use item:" .. HEARTHSTONE,
    clickHint = L.HINT_HEARTH,
})

---------------------------------------------------------------------------
-- Instances: the current one, and the instances you are saved to
---------------------------------------------------------------------------
-- Instance lockouts as { name, reset (seconds), difficulty, total, done }
local function SavedInstances()
    local list = {}
    local n = Try(GetNumSavedInstances) or 0
    for i = 1, n do
        local name, _, reset, _, locked, extended, _, _, _, difficultyName, numEncounters, progress = Try(GetSavedInstanceInfo, i)
        if name and (locked or extended) then
            table.insert(list, { name = name, reset = reset, difficulty = difficultyName,
                total = numEncounters, done = progress })
        end
    end
    return list
end

-- name, difficulty of the instance you are in, or nil outside instances
local function CurrentInstance()
    if not IsInInstance() then return nil end
    local name, _, _, difficultyName = Try(GetInstanceInfo)
    return name, difficultyName
end

ns:RegisterModule("instances", {
    label = "INSTANCES",
    icon = "Interface\\Icons\\INV_Misc_Key_03",
    events = { "UPDATE_INSTANCE_INFO", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" },
    request = function() if RequestRaidInfo then RequestRaidInfo() end end,
    requestInterval = 60,
    isEmpty = function() return CurrentInstance() == nil and #SavedInstances() == 0 end,
    update = function()
        local name, difficulty = CurrentInstance()
        if name then
            return (difficulty and difficulty ~= "") and ("%s (%s)"):format(name, difficulty) or name
        end
        local count = #SavedInstances()
        if count == 0 then return L.NONE end
        return L.INSTANCES_SAVED:format(count)
    end,
    tooltip = function(tt)
        local name, difficulty = CurrentInstance()
        if name then
            tt:AddLine(name, 1, 1, 1)
            if difficulty and difficulty ~= "" then tt:AddLine(difficulty, 0.8, 0.8, 0.8) end
            tt:AddLine(" ")
        end
        local list = SavedInstances()
        if #list == 0 then tt:AddLine(L.TT_NO_SAVES, 0.8, 0.8, 0.8) end
        for _, s in ipairs(list) do
            local left = s.difficulty and ("%s (%s)"):format(s.name, s.difficulty) or s.name
            local right = (s.total and s.total > 0) and ("%d / %d"):format(s.done or 0, s.total) or ""
            WHITE(tt, left, right)
            if s.reset then tt:AddLine(L.TT_RESET:format(FormatDuration(s.reset)), 0.6, 0.6, 0.6) end
        end
    end,
})

---------------------------------------------------------------------------
-- Daily / weekly reset timers (only if the client provides them)
---------------------------------------------------------------------------
if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
    ns:RegisterModule("reset", {
        label = "RESET",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_02",
        interval = 30,
        defaultEnabled = false,
        update = function(cfg)
            local daily = Try(C_DateAndTime.GetSecondsUntilDailyReset)
            local weekly = C_DateAndTime.GetSecondsUntilWeeklyReset and Try(C_DateAndTime.GetSecondsUntilWeeklyReset)
            local mode = cfg and cfg.resetShown or "daily"
            if mode == "weekly" and weekly then return ShortDuration(weekly) end
            if mode == "both" and daily and weekly then
                return ("%s · %s"):format(ShortDuration(daily), ShortDuration(weekly))
            end
            return daily and ShortDuration(daily) or nil
        end,
        defaults = { resetShown = "daily" },
        options = {
            { kind = "dropdown", field = "resetShown", tab = "text", label = "RESET_SHOWN", tip = "TIP_RESET_SHOWN",
              values = { { key = "daily", label = "RESET_DAILY" }, { key = "weekly", label = "RESET_WEEKLY" },
                         { key = "both", label = "RESET_BOTH" } } },
        },
        tooltip = function(tt)
            local daily = Try(C_DateAndTime.GetSecondsUntilDailyReset)
            local weekly = C_DateAndTime.GetSecondsUntilWeeklyReset and Try(C_DateAndTime.GetSecondsUntilWeeklyReset)
            if daily then WHITE(tt, L.TT_RESET_DAILY, FormatDuration(daily)) end
            if weekly then WHITE(tt, L.TT_RESET_WEEKLY, FormatDuration(weekly)) end
        end,
    })
end

-- Sample values for the demo and the preview mode
local SAMPLES = {
    time        = function(cfg) return FormatClock(20, 45, cfg) end,
    serverTime  = function(cfg) return FormatClock(14, 45, cfg) end,
    coords      = function() return "48.2, 61.7" end,
    instances   = function() return L.INSTANCES_SAVED:format(2) end,
    reset       = function() return ShortDuration(5 * 3600 + 12 * 60) end,
    hearthstone  = function() return (Try(GetBindLocation) or "Goldshire"), GOOD end,
}
for key, sample in pairs(SAMPLES) do
    if ns.modules[key] then ns.modules[key].sample = sample end
end
