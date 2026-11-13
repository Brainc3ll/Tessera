local _, ns = ...
local L = ns.L

-- Blocks about other players: friends, guild, group, whispers, mail, loot.
-- Shared tools come from Modules.lua (ns.BlockTools); see its header for how to add a block.
local Tools = ns.BlockTools
local ClassColor, GOOD, MAX_LINES, Masked = Tools.ClassColor, Tools.GOOD, Tools.MAX_LINES, Tools.Masked
local ShortDuration, Try = Tools.ShortDuration, Tools.Try
local WARN, WHITE = Tools.WARN, Tools.WHITE

-- Friends and guild: members online only, or online / total
local COUNT_OPTION = { kind = "dropdown", field = "countFormat", tab = "text", label = "COUNT_SHOWN", tip = "TIP_COUNT_SHOWN",
    values = { { key = "online", label = "COUNT_ONLINE" }, { key = "onlineTotal", label = "COUNT_ONLINE_TOTAL" } } }

-- Your own Battle.net status, as the game's friends window shows it: online, away, busy, or
-- "appear offline". (BNGetInfo: ..., isAFK, isBusy, isRealIDEnabled, isAppearOffline)
local STATUS_COLORS = { online = "ff4ce64c", away = "ffff9933", busy = "ffff4040", offline = "ff9a9a9a" }
local function MyStatus()
    if not BNGetInfo then return "online" end
    local _, _, _, _, afk, busy, _, appearOffline = BNGetInfo()
    if appearOffline == true then return "offline" end
    if busy == true then return "busy" end
    if afk == true or (UnitIsAFK and UnitIsAFK("player")) then return "away" end
    if UnitIsDND and UnitIsDND("player") then return "busy" end
    return "online"
end
local STATUS_TEXT = { online = "STATUS_ONLINE", away = "STATUS_AWAY", busy = "STATUS_BUSY", offline = "STATUS_APPEAR_OFFLINE" }

-- " <Away>" / " <Busy>" after a friend's name
local function StatusTag(afk, dnd)
    if dnd then return " " .. L.TT_DND_TAG end
    if afk then return " " .. L.TT_AFK_TAG end
    return ""
end

-- The Battle.net friends online: playing WoW (character, level, zone) or elsewhere (the game or app)
local function BNetFriendsOnline()
    local list = {}
    local getInfo = C_BattleNet and C_BattleNet.GetFriendAccountInfo
    if not (BNGetNumFriends and getInfo) then return list end
    local total = BNGetNumFriends() or 0
    for i = 1, total do
        local ok, account = pcall(getInfo, i)
        local game = ok and type(account) == "table" and account.gameAccountInfo
        if game and game.isOnline then table.insert(list, { account = account, game = game }) end
    end
    return list
end

ns:RegisterModule("friends", {
    label = "FRIENDS",
    icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
    events = { "FRIENDLIST_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "BN_CONNECTED",
               "BN_INFO_CHANGED", "BN_FRIEND_INFO_CHANGED", "PLAYER_FLAGS_CHANGED" },
    defaultEnabled = false,
    -- nobody online: block hidden ("Hide when empty" option)
    isEmpty = function(cfg)
        local online = C_FriendList.GetNumOnlineFriends() or 0
        if BNGetNumFriends and not (cfg and cfg.noBNetFriends) then
            local _, bnOnline = BNGetNumFriends()
            online = online + (bnOnline or 0)
        end
        return online == 0
    end,
    -- the count, in the color of your own status (option "statusColor")
    update = function(cfg)
        local online = C_FriendList.GetNumOnlineFriends() or 0
        local total = C_FriendList.GetNumFriends() or 0
        if BNGetNumFriends and not (cfg and cfg.noBNetFriends) then
            local bnTotal, bnOnline = BNGetNumFriends()
            online = online + (bnOnline or 0)
            total = total + (bnTotal or 0)
        end
        local text = tostring(online)
        if cfg and cfg.countFormat == "onlineTotal" then text = ("%d / %d"):format(online, total) end
        if not (cfg and cfg.statusColor == false) then
            text = ("|c%s%s|r"):format(STATUS_COLORS[MyStatus()], text)
        end
        return text
    end,
    defaults = { countFormat = "online", statusColor = true },
    options = { COUNT_OPTION, { kind = "check", field = "noBNetFriends", tab = "text", label = "NO_BNET_FRIENDS",
                                tip = "TIP_NO_BNET_FRIENDS" },
                { kind = "check", field = "statusColor", tab = "text", label = "STATUS_COLOR", tip = "TIP_STATUS_COLOR" } },
    tooltip = function(tt, cfg)
        -- your status, in words as well as in color
        local status = MyStatus()
        local c = STATUS_COLORS[status]
        tt:AddDoubleLine(L.TT_MY_STATUS, ("|c%s%s|r"):format(c, L[STATUS_TEXT[status]]), 0.8, 0.8, 0.8, 1, 1, 1)
        local shown = 0
        local function Line(left, right, r, g, b)
            shown = shown + 1
            if shown <= MAX_LINES then tt:AddDoubleLine(left, right, r, g, b, 0.8, 0.8, 0.8) end
        end
        -- friends of this game (your WoW friends list)
        local count = C_FriendList.GetNumFriends() or 0
        for i = 1, count do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected then
                local r, g, b = ClassColor(info.className and info.className:upper())
                Line(("%s (%d)%s"):format(Masked(info.name or "?"), info.level or 0, StatusTag(info.afk, info.dnd)),
                    Masked(info.area or ""), r, g, b)
            end
        end
        -- Battle.net friends: in WoW, their character, level and zone; elsewhere, where they are
        if not (cfg and cfg.noBNetFriends) then
            local bnet = BNetFriendsOnline()
            if #bnet > 0 then tt:AddLine(L.TT_BNET_ONLINE, 0.3, 0.75, 1) end
            for _, f in ipairs(bnet) do
                local account, game = f.account, f.game
                local name = Masked(account.accountName or account.battleTag or "?")
                local tag = StatusTag(account.isAFK or game.isGameAFK, account.isDND or game.isGameBusy)
                if game.clientProgram == BNET_CLIENT_WOW and game.characterName then
                    Line(("%s : %s (%d)%s"):format(name, Masked(game.characterName), game.characterLevel or 0, tag),
                        Masked(game.areaName or ""), 0.3, 0.75, 1)
                else
                    Line(name .. tag, game.richPresence or game.clientProgram or "", 0.3, 0.75, 1)
                end
            end
        end
        if shown > MAX_LINES then tt:AddLine(L.TT_MORE:format(shown - MAX_LINES), 0.8, 0.8, 0.8) end
        if shown == 0 then tt:AddLine(L.TT_NO_FRIEND, 0.8, 0.8, 0.8) end
    end,
    secureMacro = "/run ToggleFriendsFrame(1)",
    clickHint = L.HINT_FRIENDS,
})

ns:RegisterModule("guild", {
    label = "GUILD",
    icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
    events = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" },
    defaultEnabled = false,
    -- ask the server for the guild roster every minute (answer: GUILD_ROSTER_UPDATE)
    request = function()
        if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
    end,
    requestInterval = 60,
    -- no guild: block hidden ("Hide when empty" option)
    isEmpty = function() return not IsInGuild() end,
    update = function(cfg)
        if not IsInGuild() then return L.NO_GUILD end
        local total, online = GetNumGuildMembers()
        if cfg and cfg.countFormat == "online" then return tostring(online or 0) end
        return ("%d / %d"):format(online or 0, total or 0)
    end,
    defaults = { countFormat = "onlineTotal" },
    options = { COUNT_OPTION },
    tooltip = function(tt)
        if not IsInGuild() then return end
        local guildName = GetGuildInfo("player")
        if guildName then tt:AddLine(Masked(guildName), 0.3, 1, 0.3) end
        local total = GetNumGuildMembers() or 0
        local shown = 0
        for i = 1, total do
            local name, _, _, level, _, zone, _, _, online, _, class = GetGuildRosterInfo(i)
            if online and name then
                shown = shown + 1
                if shown <= MAX_LINES then
                    local r, g, b = ClassColor(class)
                    local shownName = Masked(Ambiguate and Ambiguate(name, "guild") or name)
                    tt:AddDoubleLine(("%s (%d)"):format(shownName, level or 0), Masked(zone or ""), r, g, b, 0.8, 0.8, 0.8)
                end
            end
        end
        if shown > MAX_LINES then tt:AddLine(L.TT_MORE:format(shown - MAX_LINES), 0.8, 0.8, 0.8) end
    end,
    secureMacro = "/click GuildMicroButton",
    clickHint = L.HINT_GUILD,
})

---------------------------------------------------------------------------
-- Mail: with "Hide when empty", only shown when mail is waiting
---------------------------------------------------------------------------
ns:RegisterModule("mail", {
    label = "MAIL",
    icon = "Interface\\Icons\\INV_Letter_15",
    events = { "UPDATE_PENDING_MAIL", "MAIL_INBOX_UPDATE", "MAIL_CLOSED" },
    interval = 30,
    alertOnShow = true, -- flash when new mail arrives
    isEmpty = function() return not Try(HasNewMail) end,
    update = function()
        if Try(HasNewMail) then return L.MAIL_NEW, GOOD end
        return L.NONE
    end,
    tooltip = function(tt)
        local senders = { Try(GetLatestThreeSenders) }
        if #senders == 0 then
            tt:AddLine(Try(HasNewMail) and L.MAIL_NEW or L.TT_NO_MAIL, 0.8, 0.8, 0.8)
        end
        for _, name in ipairs(senders) do tt:AddLine(Masked(name), 1, 1, 1) end
    end,
})

---------------------------------------------------------------------------
-- Group loot: loot method and quality threshold; click = /roll
---------------------------------------------------------------------------
-- Modern clients give a number (Enum.LootMethod), older ones a string
local LOOT_METHODS = {
    [0] = "LOOT_FFA", [1] = "LOOT_RR", [2] = "LOOT_MASTER", [3] = "LOOT_GROUP",
    [4] = "LOOT_NBG", [5] = "LOOT_PERSONAL",
    freeforall = "LOOT_FFA", roundrobin = "LOOT_RR", master = "LOOT_MASTER",
    group = "LOOT_GROUP", needbeforegreed = "LOOT_NBG", personal = "LOOT_PERSONAL",
}

-- method, threshold (item quality), master looter's name; nil when not in a group
local function LootInfo()
    if not Try(IsInGroup) then return nil end
    local method, partyID, raidID
    if C_PartyInfo and C_PartyInfo.GetLootMethod then method, partyID, raidID = Try(C_PartyInfo.GetLootMethod) end
    local master
    if raidID then
        master = Try(GetRaidRosterInfo, raidID)
    elseif partyID == 0 then
        master = UnitName("player")
    elseif partyID then
        master = UnitName("party" .. partyID)
    end
    return method, Try(GetLootThreshold), master
end

-- The game's own names first (official in every language), Tessera's as a fallback.
-- The game writes them for the chat ("Loot: Group Loot", "Butin : Butin de groupe"):
-- only the part after the colon is kept, with a capital letter.
local GAME_LOOT_NAMES = {
    LOOT_FFA = "LOOT_FREE_FOR_ALL", LOOT_RR = "LOOT_ROUND_ROBIN", LOOT_MASTER = "LOOT_MASTER_LOOTER",
    LOOT_GROUP = "LOOT_GROUP_LOOT", LOOT_NBG = "LOOT_NEED_BEFORE_GREED", LOOT_PERSONAL = "LOOT_PERSONAL_LOOT",
}
local function GameText(name, fallback)
    local text = _G[name]
    if type(text) ~= "string" or text == "" then return fallback end
    text = text:match("^[^:]+:%s*(.+)$") or text
    return (text:gsub("^%l", string.upper))
end
local function LootMethodName(method)
    local key = method ~= nil and LOOT_METHODS[method]
    return key and GameText(GAME_LOOT_NAMES[key], L[key]) or L.NA
end

-- Name of an item quality in its own color ("Uncommon" in green)
local function QualityText(quality)
    local name = quality and _G["ITEM_QUALITY" .. quality .. "_DESC"]
    if not name then return nil end
    local r, g, b = Try(C_Item and C_Item.GetItemQualityColor, quality)
    if type(r) == "number" then
        return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, name)
    end
    return name
end

ns:RegisterModule("loot", {
    label = "LOOT",
    icon = "Interface\\Icons\\INV_Misc_Bag_10",
    events = { "PARTY_LOOT_METHOD_CHANGED", "GROUP_ROSTER_UPDATE" },
    defaultEnabled = false,
    isEmpty = function() return not Try(IsInGroup) end,
    update = function()
        if not Try(IsInGroup) then return L.LOOT_SOLO end
        return LootMethodName((LootInfo()))
    end,
    tooltip = function(tt)
        if not Try(IsInGroup) then
            tt:AddLine(L.TT_LOOT_SOLO, 1, 1, 1, true)
            return
        end
        local method, threshold, master = LootInfo()
        WHITE(tt, L.TT_LOOT_METHOD, LootMethodName(method))
        local quality = QualityText(threshold)
        if quality then WHITE(tt, L.TT_LOOT_THRESHOLD, quality) end
        if master then WHITE(tt, L.TT_LOOT_MASTER, Masked(master)) end
    end,
    clickHint = L.HINT_ROLL,
    onClick = function(_, button)
        if button ~= "LeftButton" then return end
        if RandomRoll then RandomRoll(1, 100) end
    end,
})

---------------------------------------------------------------------------
-- Group (shows only in a group or raid)
---------------------------------------------------------------------------
local function GroupUnits()
    local units, raid = {}, IsInRaid and IsInRaid()
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    if raid then
        for i = 1, count do table.insert(units, "raid" .. i) end
    elseif count > 0 then
        table.insert(units, "player")
        for i = 1, count - 1 do table.insert(units, "party" .. i) end
    end
    return units, raid
end

ns:RegisterModule("group", {
    label = "GROUP",
    icon = "Interface\\Icons\\INV_Misc_GroupLooking",
    events = { "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED" },
    defaultEnabled = false,
    isEmpty = function() return not (IsInGroup and IsInGroup()) end,
    update = function()
        local units, raid = GroupUnits()
        return ("%d / %d"):format(#units, raid and 40 or 5)
    end,
    tooltip = function(tt)
        local units = GroupUnits()
        for i = 1, math.min(#units, MAX_LINES) do
            local unit = units[i]
            local name = Try(UnitName, unit)
            if name then
                local _, class = Try(UnitClass, unit)
                local r, g, b = ClassColor(class)
                local leader = UnitIsGroupLeader and Try(UnitIsGroupLeader, unit) and " |cffffd100(" .. L.TT_LEADER .. ")|r" or ""
                tt:AddDoubleLine(Masked(name) .. leader, tostring(Try(UnitLevel, unit) or ""), r, g, b, 0.8, 0.8, 0.8)
            end
        end
        if #units > MAX_LINES then tt:AddLine(L.TT_MORE:format(#units - MAX_LINES), 0.8, 0.8, 0.8) end
    end,
})

---------------------------------------------------------------------------
-- Unread whispers: counts whispers received since you last answered each
-- sender; a click replies to the most recent one. Names are read through
-- pcall/tostring because chat data can be protected on Midnight-era clients.
---------------------------------------------------------------------------
local whispers = {} -- ordered list of { name, count, at, bnet }

local function FindWhisper(name)
    for i, w in ipairs(whispers) do
        if w.name == name then return i, w end
    end
end

local function OnWhisper(name, bnet)
    if issecretvalue and issecretvalue(name) then return end -- protected chat data: ignore
    local ok, text = pcall(tostring, name)
    if not ok or not text or text == "" then return end
    local i, w = FindWhisper(text)
    if w then table.remove(whispers, i) else w = { name = text, count = 0, bnet = bnet } end
    w.count, w.at = w.count + 1, GetTime()
    table.insert(whispers, w)
end

local function ClearWhisper(name)
    if issecretvalue and issecretvalue(name) then return end
    local ok, text = pcall(tostring, name)
    local i = ok and FindWhisper(text)
    if i then table.remove(whispers, i) end
end

local whisperFrame = CreateFrame("Frame")
for _, event in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER",
                         "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER_INFORM" }) do
    pcall(whisperFrame.RegisterEvent, whisperFrame, event)
end
whisperFrame:SetScript("OnEvent", function(_, event, _, sender)
    if event == "CHAT_MSG_WHISPER" then
        OnWhisper(sender, false)
    elseif event == "CHAT_MSG_BN_WHISPER" then
        OnWhisper(sender, true)
    else
        ClearWhisper(sender) -- you answered: that conversation is read
    end
    ns:UpdateBlock("whispers")
end)

local function UnreadCount()
    local n = 0
    for _, w in ipairs(whispers) do n = n + w.count end
    return n
end

ns:RegisterModule("whispers", {
    label = "WHISPERS",
    icon = "Interface\\Icons\\INV_Letter_02",
    alertOnShow = true,
    isEmpty = function() return #whispers == 0 end,
    update = function(cfg)
        local n = UnreadCount()
        local last = whispers[#whispers]
        if cfg and cfg.whispersShown == "name" and last then
            return ("%s (%d)"):format(Masked(last.name), n), n > 0 and WARN or GOOD
        end
        return tostring(n), n > 0 and WARN or GOOD
    end,
    defaults = { whispersShown = "count" },
    options = {
        { kind = "dropdown", field = "whispersShown", tab = "text", label = "WHISPERS_SHOWN", tip = "TIP_WHISPERS_SHOWN",
          values = { { key = "count", label = "WHISPERS_COUNT" }, { key = "name", label = "WHISPERS_NAME" } } },
    },
    tooltip = function(tt)
        if #whispers == 0 then tt:AddLine(L.NONE, 0.8, 0.8, 0.8) end
        for i = #whispers, 1, -1 do
            local w = whispers[i]
            tt:AddDoubleLine(("%s (%d)"):format(Masked(w.name), w.count),
                L.TT_AGO:format(ShortDuration(GetTime() - w.at)), 1, 1, 1, 0.7, 0.7, 0.7)
        end
    end,
    clickHint = L.HINT_WHISPER,
    -- left click: reply to the most recent sender, and mark it as read
    onClick = function(_, button)
        if button ~= "LeftButton" then return end
        local w = whispers[#whispers]
        if not w then return end
        -- ChatFrameUtil first: the ChatFrame_* names are Blizzard's old fallbacks, due to go
        local util = ChatFrameUtil
        local tell = w.bnet and ((util and util.SendBNetTell) or ChatFrame_SendBNetTell)
            or ((util and util.SendTell) or ChatFrame_SendTell)
        if tell then pcall(tell, w.name) end
        table.remove(whispers)
    end,
})

-- Sample values for the demo and the preview mode
local SAMPLES = {
    friends     = function() return "3" end,
    guild       = function() return "12 / 87" end,
    mail        = function() return L.MAIL_NEW, GOOD end,
    group       = function() return "4 / 5" end,
    whispers    = function() return "2", WARN end,
    loot        = function() return GameText("LOOT_GROUP_LOOT", L.LOOT_GROUP) end,
}
for key, sample in pairs(SAMPLES) do
    if ns.modules[key] then ns.modules[key].sample = sample end
end
