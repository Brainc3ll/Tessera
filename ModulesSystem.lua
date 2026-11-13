local _, ns = ...
local L = ns.L

-- Blocks about the computer and the game: FPS, latency, memory, volume, time played, streamer mode.
-- Shared tools come from Modules.lua (ns.BlockTools); see its header for how to add a block.
local Tools = ns.BlockTools
local BAD, FormatDuration, GOOD, LevelColor = Tools.BAD, Tools.FormatDuration, Tools.GOOD, Tools.LevelColor
local ShortDuration, THRESHOLDS = Tools.ShortDuration, Tools.THRESHOLDS
local Threshold, Try, WARN, WHITE = Tools.Threshold, Tools.Try, Tools.WARN, Tools.WHITE
local session = Tools.session

local ignoreFPSUntil = GetTime() + 10 -- loading screens skew the FPS numbers

-- Records XP gained this session (handles level-ups, where the XP bar resets)
local tracker = CreateFrame("Frame")
tracker:RegisterEvent("PLAYER_ENTERING_WORLD")
tracker:RegisterEvent("PLAYER_XP_UPDATE")
tracker:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        ignoreFPSUntil = GetTime() + 5
        session.lastXP, session.lastXPMax = UnitXP("player"), UnitXPMax("player")
    else
        local cur, max = UnitXP("player"), UnitXPMax("player")
        local last, lastMax = session.lastXP, session.lastXPMax
        if last then
            -- level gained: rest of the previous level + start of the new one
            local gained = cur >= last and (cur - last) or ((lastMax or last) - last + cur)
            session.xpGained = session.xpGained + gained
        end
        session.lastXP, session.lastXPMax = cur, max
    end
end)

-- History for the tooltip graphs: one point every 5 seconds, last 5 minutes
local GRAPH_POINTS, GRAPH_STEP = 60, 5
local history = { fps = {}, latency = {} }
local fpsBucket = { sum = 0, count = 0 }

local function PushHistory(list, value)
    table.insert(list, value)
    if #list > GRAPH_POINTS then table.remove(list, 1) end
end

-- Samples FPS once per second for the session average / min / max (and the graph)
C_Timer.NewTicker(1, function()
    if GetTime() < ignoreFPSUntil then return end
    local fps = GetFramerate()
    if not fps or fps <= 0 then return end
    local f = session.fps
    f.sum, f.count = f.sum + fps, f.count + 1
    f.min = f.min and math.min(f.min, fps) or fps
    f.max = f.max and math.max(f.max, fps) or fps
    fpsBucket.sum, fpsBucket.count = fpsBucket.sum + fps, fpsBucket.count + 1
    if fpsBucket.count >= GRAPH_STEP then
        PushHistory(history.fps, fpsBucket.sum / fpsBucket.count)
        fpsBucket.sum, fpsBucket.count = 0, 0
    end
end)

-- Samples the world latency every 5 seconds for its graph
C_Timer.NewTicker(GRAPH_STEP, function()
    local _, _, _, world = GetNetStats()
    if world and world > 0 then PushHistory(history.latency, world) end
end)

-- Small bar graph drawn inside the tooltip, under a title line. Space is reserved
-- with blank lines, then a frame with one bar per point is laid over them.
local GRAPH_W, GRAPH_H = 200, 34
local graph

local function AddGraph(tt, title, values, levelOf)
    if #values < 2 or not tt.GetName or not tt:GetName() then return end
    tt:AddLine(" ")
    tt:AddLine(title, 0.8, 0.8, 0.8)
    local first = tt:NumLines() + 1
    for _ = 1, 3 do tt:AddLine(" ") end
    local line = _G[tt:GetName() .. "TextLeft" .. first]
    if not line then return end
    if not graph then
        graph = CreateFrame("Frame", nil, tt)
        graph.bars = {}
        -- the graph belongs to one tooltip display only
        tt:HookScript("OnHide", function() graph:Hide() end)
        tt:HookScript("OnTooltipCleared", function(self)
            graph:Hide()
            if graph.widened and self.SetMinimumWidth then
                self:SetMinimumWidth(0)
                graph.widened = nil
            end
        end)
    end
    graph:SetParent(tt)
    graph:ClearAllPoints()
    graph:SetPoint("TOPLEFT", line, "TOPLEFT", 0, -2)
    graph:SetSize(GRAPH_W, GRAPH_H)
    if tt.SetMinimumWidth then
        tt:SetMinimumWidth(GRAPH_W + 24)
        graph.widened = true
    end
    local maxV = 1
    for _, v in ipairs(values) do maxV = math.max(maxV, v) end
    local barW = GRAPH_W / GRAPH_POINTS
    for i = 1, GRAPH_POINTS do
        local bar = graph.bars[i]
        if not bar then
            bar = graph:CreateTexture(nil, "ARTWORK")
            graph.bars[i] = bar
        end
        local v = values[#values - GRAPH_POINTS + i]
        if v then
            local hex = ns.LEVEL_COLORS[levelOf(v)] or "ffffff"
            bar:SetColorTexture(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
                tonumber(hex:sub(5, 6), 16) / 255, 0.85)
            bar:ClearAllPoints()
            bar:SetSize(math.max(1, barW - 1), math.max(1, v / maxV * GRAPH_H))
            bar:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", (i - 1) * barW, 0)
            bar:Show()
        else
            bar:Hide()
        end
    end
    graph:Show()
end

-- Game frame rate cap (0 or disabled = unlimited). pcall: the CVar may not exist on every client
local function FPSCap(useVar, valueVar)
    local ok, use = pcall(GetCVar, useVar)
    local ok2, value = pcall(GetCVar, valueVar)
    value = ok2 and tonumber(value)
    if (ok and use == "0") or not value or value <= 0 then return L.TT_UNLIMITED end
    return L.FPS_FORMAT:format(value)
end

---------------------------------------------------------------------------
-- FPS and latency
---------------------------------------------------------------------------
ns:RegisterModule("fps", {
    label = "FPS",
    icon = "Interface\\Icons\\Ability_Rogue_Sprint",
    interval = 1,
    update = function(cfg)
        local fps = GetFramerate() or 0
        local text = (cfg and cfg.showUnit == false) and ("%.0f"):format(fps) or L.FPS_FORMAT:format(fps)
        return text, Threshold(cfg, fps, THRESHOLDS.fps)
    end,
    defaults = { showUnit = true },
    options = { { kind = "check", field = "showUnit", tab = "text", label = "SHOW_UNIT", tip = "TIP_SHOW_UNIT" } },
    thresholds = THRESHOLDS.fps,
    tooltip = function(tt, cfg)
        local f = session.fps
        tt:AddDoubleLine(L.TT_FPS_NOW, L.FPS_FORMAT:format(GetFramerate() or 0), 1, 1, 1, 1, 1, 1)
        if f.count > 0 then
            tt:AddDoubleLine(L.TT_FPS_AVG, L.FPS_FORMAT:format(f.sum / f.count), 1, 1, 1, 1, 1, 1)
            tt:AddDoubleLine(L.TT_FPS_MIN, L.FPS_FORMAT:format(f.min), 1, 1, 1, 1, 0.3, 0.3)
            tt:AddDoubleLine(L.TT_FPS_MAX, L.FPS_FORMAT:format(f.max), 1, 1, 1, 0.3, 1, 0.3)
        end
        tt:AddLine(" ")
        tt:AddDoubleLine(L.TT_FPS_CAP, FPSCap("useMaxFPS", "maxFPS"), 1, 1, 1, 1, 1, 1)
        tt:AddDoubleLine(L.TT_FPS_CAP_BG, FPSCap("useMaxFPSBk", "maxFPSBk"), 1, 1, 1, 1, 1, 1)
        if GetPhysicalScreenSize then
            local w, h = GetPhysicalScreenSize()
            if w and h then tt:AddDoubleLine(L.TT_RESOLUTION, ("%d x %d"):format(w, h), 1, 1, 1, 1, 1, 1) end
        end
        AddGraph(tt, L.TT_GRAPH_FPS, history.fps, function(v) return Threshold(cfg, v, THRESHOLDS.fps) end)
    end,
})

-- GOOD under 100 ms, WARN under 250 ms, BAD above
local function LatencyLevel(ms, cfg)
    return Threshold(cfg, ms, THRESHOLDS.latency)
end

ns:RegisterModule("latency", {
    label = "LATENCY",
    icon = "Interface\\Icons\\Spell_Nature_Lightning",
    interval = 5,
    update = function(cfg)
        local _, _, home, world = GetNetStats()
        home, world = home or 0, world or 0
        local function Ms(v)
            if cfg and cfg.showUnit == false then return tostring(v) end
            return L.LATENCY_FORMAT:format(v)
        end
        local source = cfg and cfg.latencySource or "world"
        if source == "home" then return Ms(home), LatencyLevel(home, cfg) end
        if source == "both" then
            return Ms(home) .. " / " .. Ms(world), LatencyLevel(math.max(home, world), cfg)
        end
        return Ms(world), LatencyLevel(world, cfg)
    end,
    defaults = { showUnit = true, latencySource = "world" },
    options = {
        { kind = "dropdown", field = "latencySource", tab = "text", label = "LATENCY_SHOWN", tip = "TIP_LATENCY_SHOWN",
          values = { { key = "world", label = "TT_WORLD" }, { key = "home", label = "TT_HOME" },
                     { key = "both", label = "LATENCY_BOTH" } } },
        { kind = "check", field = "showUnit", tab = "text", label = "SHOW_UNIT", tip = "TIP_SHOW_UNIT" },
    },
    thresholds = THRESHOLDS.latency,
    tooltip = function(tt, cfg)
        local bwIn, bwOut, home, world = GetNetStats()
        tt:AddDoubleLine(L.TT_HOME, LevelColor(LatencyLevel(home or 0, cfg)) .. L.LATENCY_FORMAT:format(home or 0) .. "|r",
            1, 1, 1)
        tt:AddDoubleLine(L.TT_WORLD, LevelColor(LatencyLevel(world or 0, cfg)) .. L.LATENCY_FORMAT:format(world or 0)
            .. "|r", 1, 1, 1)
        tt:AddDoubleLine(L.TT_BANDWIDTH_IN, L.BANDWIDTH_FORMAT:format(bwIn or 0), 1, 1, 1, 1, 1, 1)
        tt:AddDoubleLine(L.TT_BANDWIDTH_OUT, L.BANDWIDTH_FORMAT:format(bwOut or 0), 1, 1, 1, 1, 1, 1)
        AddGraph(tt, L.TT_GRAPH_LATENCY, history.latency, function(v) return LatencyLevel(v, cfg) end)
    end,
})

---------------------------------------------------------------------------
-- Addon memory
---------------------------------------------------------------------------
-- Modern clients moved these functions into C_AddOns; classic clients keep the globals
local GetNumAddOnsFn = (C_AddOns and C_AddOns.GetNumAddOns) or function() return 0 end
local GetAddOnInfoFn = (C_AddOns and C_AddOns.GetAddOnInfo) or function() end
local GetMemoryFn = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage

-- Last measurement, reused by the tooltip (measuring is expensive)
local memoryCache = { total = 0, list = {} }

local function RefreshMemory()
    if InCombatLockdown() then return end -- avoid a stutter during combat
    UpdateAddOnMemoryUsage()
    local total, list = 0, {}
    for i = 1, GetNumAddOnsFn() do
        local kb = GetMemoryFn(i) or 0
        if kb > 0 then
            local name, title = GetAddOnInfoFn(i)
            total = total + kb
            table.insert(list, { name = title or name, folder = name, kb = kb })
        end
    end
    table.sort(list, function(a, b) return a.kb > b.kb end)
    memoryCache.total, memoryCache.list = total, list
end

-- "512 KB" or "1.5 MB"
local function FormatMemory(kb)
    if kb >= 1024 then return L.MEMORY_MB:format(kb / 1024) end
    return L.MEMORY_KB:format(kb)
end

ns:RegisterModule("memory", {
    label = "MEMORY",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    interval = 30,
    defaultEnabled = false,
    update = function(cfg)
        pcall(RefreshMemory) -- on failure, keep showing the last known total
        if cfg and cfg.memoryShown == "tessera" then
            for _, e in ipairs(memoryCache.list) do
                if e.name == "Tessera" or e.folder == "Tessera" then return FormatMemory(e.kb) end
            end
            return FormatMemory(0)
        end
        return FormatMemory(memoryCache.total)
    end,
    defaults = { memoryShown = "total" },
    options = {
        { kind = "dropdown", field = "memoryShown", tab = "text", label = "MEMORY_SHOWN", tip = "TIP_MEMORY_SHOWN",
          values = { { key = "total", label = "MEMORY_ALL_ADDONS" }, { key = "tessera", label = "MEMORY_TESSERA" } } },
    },
    tooltip = function(tt)
        -- Tessera's own footprint first, then the heaviest addons
        local own = 0
        for _, e in ipairs(memoryCache.list) do
            if e.name == "Tessera" or e.folder == "Tessera" then own = e.kb end
        end
        tt:AddDoubleLine(L.TT_TESSERA_MEMORY, FormatMemory(own), 0.4, 0.75, 1, 1, 1, 1)
        tt:AddLine(" ")
        tt:AddLine(L.TT_TOP_ADDONS, 1, 0.82, 0)
        for i = 1, math.min(10, #memoryCache.list) do
            local e = memoryCache.list[i]
            tt:AddDoubleLine(e.name, FormatMemory(e.kb), 1, 1, 1, 1, 1, 1)
        end
    end,
})

---------------------------------------------------------------------------
-- Volume: wheel = master volume, click = mute / unmute
---------------------------------------------------------------------------
-- A CVar read as a number (0 if missing)
local function CVarNumber(name)
    return tonumber(Try(GetCVar, name)) or 0
end

-- Volume CVars listed in the tooltip, with their Locale key
local VOLUMES = {
    { "Sound_MasterVolume", "TT_MASTER" },
    { "Sound_MusicVolume", "TT_MUSIC" },
    { "Sound_SFXVolume", "TT_EFFECTS" },
    { "Sound_AmbienceVolume", "TT_AMBIENCE" },
    { "Sound_DialogVolume", "TT_DIALOG" },
}

ns:RegisterModule("volume", {
    label = "VOLUME",
    icon = "Interface\\Icons\\INV_Misc_Drum_01",
    events = { "CVAR_UPDATE" },
    interval = 5,
    defaultEnabled = false,
    update = function(cfg)
        if Try(GetCVar, "Sound_EnableAllSound") == "0" then return L.MUTED, BAD end
        return ("%d%%"):format(math.floor(CVarNumber(cfg and cfg.volumeChannel or "Sound_MasterVolume") * 100 + 0.5))
    end,
    defaults = { volumeChannel = "Sound_MasterVolume" },
    options = {
        { kind = "dropdown", field = "volumeChannel", tab = "text", label = "VOLUME_SHOWN", tip = "TIP_VOLUME_SHOWN",
          values = { { key = "Sound_MasterVolume", label = "TT_MASTER" }, { key = "Sound_MusicVolume", label = "TT_MUSIC" },
                     { key = "Sound_SFXVolume", label = "TT_EFFECTS" }, { key = "Sound_AmbienceVolume", label = "TT_AMBIENCE" },
                     { key = "Sound_DialogVolume", label = "TT_DIALOG" } } },
    },
    tooltip = function(tt)
        for _, v in ipairs(VOLUMES) do
            WHITE(tt, L[v[2]], ("%d%%"):format(math.floor(CVarNumber(v[1]) * 100 + 0.5)))
        end
    end,
    clickHint = L.HINT_VOLUME,
    onClick = function(_, button)
        if button ~= "LeftButton" then return end
        local enabled = Try(GetCVar, "Sound_EnableAllSound") ~= "0"
        SetCVar("Sound_EnableAllSound", enabled and "0" or "1")
    end,
    onWheel = function(delta, cfg)
        local cvar = cfg and cfg.volumeChannel or "Sound_MasterVolume"
        local v = CVarNumber(cvar) + (delta > 0 and 0.05 or -0.05)
        v = math.max(0, math.min(1, math.floor(v * 20 + 0.5) / 20))
        SetCVar(cvar, tostring(v))
    end,
})

---------------------------------------------------------------------------
-- Played time. The game only answers RequestTimePlayed() with an event that
-- the chat frames also print; that printing is muted for Tessera's own request.
---------------------------------------------------------------------------
local played = { total = nil, level = nil, at = 0, requested = false }
local mutedChatFrames = {}

local playedFrame = CreateFrame("Frame")
playedFrame:RegisterEvent("TIME_PLAYED_MSG")
playedFrame:SetScript("OnEvent", function(_, _, total, level)
    played.total, played.level, played.at = total, level, GetTime()
    played.requested = false
    -- give the chat frames their event back, after this event has been delivered
    C_Timer.After(0, function()
        for _, chat in ipairs(mutedChatFrames) do chat:RegisterEvent("TIME_PLAYED_MSG") end
        wipe(mutedChatFrames)
    end)
    ns:UpdateBlock("played")
end)

local function RequestPlayed()
    if played.requested or not RequestTimePlayed then return end
    played.requested = true
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local chat = _G["ChatFrame" .. i]
        if chat and chat.IsEventRegistered and chat:IsEventRegistered("TIME_PLAYED_MSG") then
            chat:UnregisterEvent("TIME_PLAYED_MSG")
            table.insert(mutedChatFrames, chat)
        end
    end
    RequestTimePlayed()
end

local function PlayedNow(base)
    return base and (base + GetTime() - played.at) or nil
end

ns:RegisterModule("played", {
    label = "PLAYED",
    icon = "Interface\\Icons\\INV_Misc_PocketWatch_03",
    interval = 30,
    defaultEnabled = false,
    request = RequestPlayed,
    requestInterval = 3600,
    update = function(cfg)
        local mode = cfg and cfg.playedShown or "level"
        local sessionTime = ShortDuration(GetTime() - session.start)
        if mode == "session" then return sessionTime end
        local value = PlayedNow(mode == "total" and played.total or played.level)
        return value and ShortDuration(value) or sessionTime
    end,
    defaults = { playedShown = "level" },
    options = {
        { kind = "dropdown", field = "playedShown", tab = "text", label = "PLAYED_SHOWN", tip = "TIP_PLAYED_SHOWN",
          values = { { key = "level", label = "TT_PLAYED_LEVEL" }, { key = "total", label = "TT_PLAYED_TOTAL" },
                     { key = "session", label = "PLAYED_SESSION" } } },
    },
    tooltip = function(tt)
        WHITE(tt, L.TT_SESSION_TIME, FormatDuration(GetTime() - session.start))
        if played.level then WHITE(tt, L.TT_PLAYED_LEVEL, FormatDuration(PlayedNow(played.level))) end
        if played.total then WHITE(tt, L.TT_PLAYED_TOTAL, FormatDuration(PlayedNow(played.total))) end
    end,
})

---------------------------------------------------------------------------
-- Streamer mode: shows whether it is on, a click turns it on or off
---------------------------------------------------------------------------
ns:RegisterModule("streamer", {
    label = "STREAMER",
    icon = "Interface\\Icons\\Ability_Stealth",
    defaultEnabled = false,
    -- "Hide when empty" (off by default, 1.3: the block stays on screen to switch the mode
    -- on with a click): when ticked, the block only shows while the mode is on
    defaults = { hideEmpty = false }, -- new profiles; saved profiles keep their choice
    isEmpty = function() return not ns:IsStreamer() end,
    update = function()
        if ns:IsStreamer() then return L.STREAMER_ON, WARN end
        return L.STREAMER_OFF
    end,
    tooltip = function(tt)
        tt:AddLine(ns:IsStreamer() and L.TT_STREAMER_ON or L.TT_STREAMER_OFF, 1, 1, 1, true)
    end,
    clickHint = L.HINT_STREAMER,
    onClick = function(_, button)
        if button ~= "LeftButton" then return end
        ns:SetStreamerMode(not ns:IsStreamer())
    end,
})

-- Sample values for the demo and the preview mode
local SAMPLES = {
    fps         = function() return L.FPS_FORMAT:format(144), GOOD end,
    latency     = function() return L.LATENCY_FORMAT:format(42), GOOD end,
    memory      = function() return FormatMemory(24576) end,
    volume      = function() return "80%" end,
    played      = function() return ShortDuration(2 * 86400 + 4 * 3600) end,
    streamer     = function() return L.STREAMER_ON, WARN end,
}
for key, sample in pairs(SAMPLES) do
    if ns.modules[key] then ns.modules[key].sample = sample end
end
