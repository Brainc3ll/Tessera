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

-- A tooltip part is on unless its checkbox was cleared (a profile from before the checkbox keeps it on)
local function On(cfg, field)
    return not cfg or cfg[field] ~= false
end

-- Friends tooltip order: as the game gives it (default), or by name, level (highest first) or zone
local FRIENDS_SORT = { name = "name", level = "level", zone = "zone" }
local function SortFriends(list, mode)
    if not FRIENDS_SORT[mode] then return end
    table.sort(list, function(a, b)
        if mode == "level" then
            if a.level ~= b.level then return a.level > b.level end
        elseif mode == "zone" then
            if a.zone ~= b.zone then return a.zone < b.zone end
        end
        return a.name < b.name
    end)
end

-- Guild tooltip order: "leaders" top ranks (0 = off, 1 = guild master, 2 = two ranks...) come first,
-- by rank; then the chosen order. "game" keeps the roster's own order.
local GUILD_LIMITS = { [5] = true, [10] = true, [20] = true, [30] = true, [50] = true, [100] = true } -- "Members shown"
local GUILD_SORT = { game = true, name = true, level = true, zone = true, rank = true }
local function SortGuild(list, mode, leaders)
    if not GUILD_SORT[mode] then mode = "game" end
    if mode == "game" and leaders < 1 then return end
    table.sort(list, function(a, b)
        local la, lb = leaders > 0 and a.rankIndex < leaders, leaders > 0 and b.rankIndex < leaders
        if la ~= lb then return la end
        if la and a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end
        if mode == "level" and a.level ~= b.level then return a.level > b.level end
        if mode == "zone" and a.zone ~= b.zone then return a.zone < b.zone end
        if mode == "rank" and a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end
        if mode == "game" then return a.order < b.order end
        if a.name ~= b.name then return a.name < b.name end
        return a.order < b.order
    end)
end

-- The online guild members, in the order the player chose (leaders first, then the sort), with the
-- number of leaders on top: shared by the tooltip and the clickable list (GuildList.lua)
function ns.GuildMembers(cfg)
    local members = {}
    local total = GetNumGuildMembers() or 0
    for i = 1, total do
        -- name, rank, rank index, level, class, zone, public note, officer note, online, status, class file
        local name, rank, rankIndex, level, _, zone, note, _, online, status, class = GetGuildRosterInfo(i)
        if online and name then
            members[#members + 1] = { name = name, rank = rank, rankIndex = rankIndex or 99, level = level or 0,
                zone = zone or "", note = note, class = class, status = status, order = i }
        end
    end
    local leaders = tonumber(cfg and cfg.guildLeaders) or 0
    SortGuild(members, cfg and cfg.guildSort, leaders)
    local nLeaders = 0
    while leaders > 0 and members[nLeaders + 1] and members[nLeaders + 1].rankIndex < leaders do nLeaders = nLeaders + 1 end
    return members, nLeaders
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
    defaults = { countFormat = "online", statusColor = true, friendsSort = "game", friendsNotes = false, friendsWoWOnly = false,
                 friendsTipStatus = true, friendsTipWoW = true, friendsTipBNet = true },
    options = { COUNT_OPTION, { kind = "check", field = "noBNetFriends", tab = "text", label = "NO_BNET_FRIENDS",
                                tip = "TIP_NO_BNET_FRIENDS" },
                { kind = "check", field = "statusColor", tab = "text", label = "STATUS_COLOR", tip = "TIP_STATUS_COLOR" },
                { kind = "dropdown", field = "friendsSort", section = "tooltip", tab = "text", label = "FRIENDS_SORT", tip = "TIP_FRIENDS_SORT",
                  values = { { key = "game", label = "FRIENDS_SORT_GAME" }, { key = "name", label = "FRIENDS_SORT_NAME" },
                             { key = "level", label = "FRIENDS_SORT_LEVEL" }, { key = "zone", label = "FRIENDS_SORT_ZONE" } } },
                { kind = "check", field = "friendsNotes", section = "tooltip", tab = "text", label = "FRIENDS_NOTES", tip = "TIP_FRIENDS_NOTES" },
                { kind = "check", field = "friendsWoWOnly", section = "tooltip", tab = "text", label = "FRIENDS_WOW_ONLY", tip = "TIP_FRIENDS_WOW_ONLY",
                  shown = function(cfg) return not cfg.noBNetFriends end },
                { kind = "check", field = "friendsTipStatus", section = "tooltip", tab = "text", label = "FRIENDS_TIP_STATUS", tip = "TIP_FRIENDS_TIP_STATUS" },
                { kind = "check", field = "friendsTipWoW", section = "tooltip", tab = "text", label = "FRIENDS_TIP_WOW", tip = "TIP_FRIENDS_TIP_WOW" },
                { kind = "check", field = "friendsTipBNet", section = "tooltip", tab = "text", label = "FRIENDS_TIP_BNET", tip = "TIP_FRIENDS_TIP_BNET",
                  shown = function(cfg) return not cfg.noBNetFriends end } },
    tooltip = function(tt, cfg)
        -- your status, in words as well as in color
        if On(cfg, "friendsTipStatus") then
            local status = MyStatus()
            local c = STATUS_COLORS[status]
            tt:AddDoubleLine(L.TT_MY_STATUS, ("|c%s%s|r"):format(c, L[STATUS_TEXT[status]]), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        local shown = 0
        local started = On(cfg, "friendsTipStatus") -- something is already in the tooltip: a blank line goes before the next part
        -- right column: the friend's note (if asked), then the zone
        local function Right(note, zone)
            zone = Masked(zone or "")
            if cfg and cfg.friendsNotes and type(note) == "string" and note ~= "" then
                return Masked(note) .. (zone ~= "" and " - " .. zone or "")
            end
            return zone
        end
        local function Lines(list, r, g, b)
            SortFriends(list, cfg and cfg.friendsSort)
            for _, e in ipairs(list) do
                shown = shown + 1
                if shown <= MAX_LINES then
                    tt:AddDoubleLine(e.left, e.right, e.r or r, e.g or g, e.b or b, 0.8, 0.8, 0.8)
                end
            end
        end
        -- friends of this game (your WoW friends list)
        if On(cfg, "friendsTipWoW") then
            local list = {}
            for i = 1, C_FriendList.GetNumFriends() or 0 do
                local info = C_FriendList.GetFriendInfoByIndex(i)
                if info and info.connected then
                    local r, g, b = ClassColor(info.className and info.className:upper())
                    table.insert(list, { r = r, g = g, b = b, name = info.name or "?", level = info.level or 0, zone = info.area or "",
                        left = ("%s (%d)%s"):format(Masked(info.name or "?"), info.level or 0, StatusTag(info.afk, info.dnd)),
                        right = Right(info.notes, info.area) })
                end
            end
            if #list > 0 and started then ns.TooltipGap(tt) end
            if #list > 0 then started = true end
            Lines(list, 1, 1, 1)
        end
        -- Battle.net friends: in WoW, their character, level and zone; elsewhere, where they are
        if not (cfg and cfg.noBNetFriends) and On(cfg, "friendsTipBNet") then
            local list = {}
            for _, f in ipairs(BNetFriendsOnline()) do
                local account, game = f.account, f.game
                local name = Masked(account.accountName or account.battleTag or "?")
                local tag = StatusTag(account.isAFK or game.isGameAFK, account.isDND or game.isGameBusy)
                local inWoW = game.clientProgram == BNET_CLIENT_WOW and game.characterName
                if inWoW then
                    table.insert(list, { name = account.accountName or account.battleTag or "?", level = game.characterLevel or 0,
                        zone = game.areaName or "",
                        left = ("%s : %s (%d)%s"):format(name, Masked(game.characterName), game.characterLevel or 0, tag),
                        right = Right(account.note, game.areaName) })
                elseif not (cfg and cfg.friendsWoWOnly) then
                    table.insert(list, { name = account.accountName or account.battleTag or "?", level = 0,
                        zone = game.richPresence or game.clientProgram or "",
                        left = name .. tag,
                        right = Right(account.note, game.richPresence or game.clientProgram) })
                end
            end
            if #list > 0 then
                if started then ns.TooltipGap(tt) end
                tt:AddLine(L.TT_BNET_ONLINE, 0.3, 0.75, 1)
            end
            Lines(list, 0.3, 0.75, 1)
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
    defaults = { countFormat = "onlineTotal", guildTipMotd = true, guildTipCount = true, guildTipRank = true, guildTipNote = true,
                 guildSort = "game", guildLeaders = "0", guildMax = "20", guildShow = "list", guildListRows = 14,
                 guildListScale = 100, guildListLook = "tooltip" },
    options = { COUNT_OPTION,
                { kind = "dropdown", field = "guildShow", tab = "text", label = "GUILD_SHOW", tip = "TIP_GUILD_SHOW",
                  values = { { key = "tooltip", label = "GUILD_SHOW_TOOLTIP" }, { key = "list", label = "GUILD_SHOW_LIST" } } },
                { kind = "slider", field = "guildListRows", tab = "text", label = "GUILD_LIST_ROWS", tip = "TIP_GUILD_LIST_ROWS",
                  min = 5, max = 100, step = 1, default = 14, shown = function(cfg) return cfg.guildShow == "list" end },
                { kind = "slider", field = "guildListScale", tab = "text", label = "GUILD_LIST_SCALE", tip = "TIP_GUILD_LIST_SCALE",
                  min = 80, max = 150, step = 5, default = 100, shown = function(cfg) return cfg.guildShow == "list" end },
                { kind = "dropdown", field = "guildListLook", tab = "text", label = "GUILD_LIST_LOOK", tip = "TIP_GUILD_LIST_LOOK",
                  shown = function(cfg) return cfg.guildShow == "list" end,
                  values = { { key = "tooltip", label = "GUILD_LOOK_TOOLTIP" }, { key = "window", label = "GUILD_LOOK_WINDOW" } } },
                { kind = "dropdown", field = "guildSort", section = "tooltip", tab = "text", label = "GUILD_SORT", tip = "TIP_GUILD_SORT",
                  values = { { key = "game", label = "FRIENDS_SORT_GAME" }, { key = "name", label = "FRIENDS_SORT_NAME" },
                             { key = "level", label = "FRIENDS_SORT_LEVEL" }, { key = "zone", label = "FRIENDS_SORT_ZONE" },
                             { key = "rank", label = "GUILD_SORT_RANK" } } },
                { kind = "dropdown", field = "guildLeaders", section = "tooltip", tab = "text", label = "GUILD_LEADERS", tip = "TIP_GUILD_LEADERS",
                  values = { { key = "0", label = "GUILD_LEADERS_0" }, { key = "1", label = "GUILD_LEADERS_1" },
                             { key = "2", label = "GUILD_LEADERS_2" }, { key = "3", label = "GUILD_LEADERS_3" },
                             { key = "4", label = "GUILD_LEADERS_4" } } },
                { kind = "dropdown", field = "guildMax", section = "tooltip", tab = "text", label = "GUILD_MAX", tip = "TIP_GUILD_MAX",
                  values = { { key = "5", label = "5" }, { key = "10", label = "10" }, { key = "20", label = "20" },
                             { key = "30", label = "30" }, { key = "50", label = "50" }, { key = "100", label = "100" },
                             { key = "200", label = "200" }, { key = "500", label = "500" } } },
                { kind = "check", field = "guildTipMotd", section = "tooltip", tab = "text", label = "GUILD_TIP_MOTD", tip = "TIP_GUILD_TIP_MOTD" },
                { kind = "check", field = "guildTipCount", section = "tooltip", tab = "text", label = "GUILD_TIP_COUNT", tip = "TIP_GUILD_TIP_COUNT" },
                { kind = "check", field = "guildTipRank", section = "tooltip", tab = "text", label = "GUILD_TIP_RANK", tip = "TIP_GUILD_TIP_RANK" },
                { kind = "check", field = "guildTipNote", section = "tooltip", tab = "text", label = "GUILD_TIP_NOTE", tip = "TIP_GUILD_TIP_NOTE" } },
    tooltip = function(tt, cfg)
        if not IsInGuild() then return end
        local guildName = GetGuildInfo("player")
        local total, onlineCount = GetNumGuildMembers()
        total = total or 0
        -- header: the guild's name and, on the right, members online out of the total
        if guildName then
            if On(cfg, "guildTipCount") then
                tt:AddDoubleLine(Masked(guildName), ("%d/%d"):format(onlineCount or 0, total), 0.3, 1, 0.3, 0.8, 0.8, 0.8)
            else
                tt:AddLine(Masked(guildName), 0.3, 1, 0.3)
            end
        end
        -- message of the day
        local motd = On(cfg, "guildTipMotd") and C_GuildInfo and C_GuildInfo.GetMOTD and Try(C_GuildInfo.GetMOTD)
        if type(motd) == "string" and motd ~= "" then
            ns.TooltipGap(tt)
            tt:AddLine(Masked(motd), 0.9, 0.9, 0.55, true)
        end
        -- online members first, then the order the player chose
        local members, nLeaders = ns.GuildMembers(cfg)
        -- one line: level (grey), name (class color), rank (gold), note (white); the zone on the right
        local function Line(m)
            local r, g, b = ClassColor(m.class)
            local text = ("|cffcccccc%d|r |cff%02x%02x%02x%s|r"):format(m.level, r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5,
                Masked(Ambiguate and Ambiguate(m.name, "guild") or m.name))
            if On(cfg, "guildTipRank") and type(m.rank) == "string" and m.rank ~= "" then
                text = text .. " |cffffd100" .. Masked(m.rank) .. "|r"
            end
            if On(cfg, "guildTipNote") and type(m.note) == "string" and m.note ~= "" then
                text = text .. " |cffffffff" .. Masked(m.note) .. "|r"
            end
            tt:AddDoubleLine(text, Masked(m.zone), 1, 1, 1, 0.8, 0.8, 0.8)
        end
        if nLeaders > 0 then
            ns.TooltipGap(tt)
            for i = 1, nLeaders do Line(members[i]) end
        end
        local limit = GUILD_LIMITS[tonumber(cfg and cfg.guildMax)] and tonumber(cfg.guildMax) or MAX_LINES
        local others = #members - nLeaders
        if others > 0 then
            ns.TooltipGap(tt)
            for i = nLeaders + 1, math.min(#members, nLeaders + limit) do Line(members[i]) end
            if others > limit then tt:AddLine(L.TT_MORE:format(others - limit), 0.8, 0.8, 0.8) end
        end
    end,
    secureMacro = "/click GuildMicroButton",
    clickHint = L.HINT_GUILD,
    -- "Member list": a clickable list under the mouse in place of the tooltip (GuildList.lua)
    hoverList = function(frame, cfg)
        if cfg and cfg.guildShow == "list" and IsInGuild() and ns.ShowGuildList then
            ns:ShowGuildList(frame, cfg)
            return true
        end
    end,
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
    defaults = { groupTipRole = true, groupTipState = true, groupTipLevel = true },
    options = {
        { kind = "check", field = "groupTipRole", section = "tooltip", tab = "text", label = "GROUP_TIP_ROLE", tip = "TIP_GROUP_TIP_ROLE" },
        { kind = "check", field = "groupTipState", section = "tooltip", tab = "text", label = "GROUP_TIP_STATE", tip = "TIP_GROUP_TIP_STATE" },
        { kind = "check", field = "groupTipLevel", section = "tooltip", tab = "text", label = "GROUP_TIP_LEVEL", tip = "TIP_GROUP_TIP_LEVEL" },
    },
    tooltip = function(tt, cfg)
        local units = GroupUnits()
        local _, _, master = LootInfo()
        local showRole, showState = cfg == nil or cfg.groupTipRole ~= false, cfg == nil or cfg.groupTipState ~= false
        local showLevel = cfg == nil or cfg.groupTipLevel ~= false
        for i = 1, math.min(#units, MAX_LINES) do
            local unit = units[i]
            local name = Try(UnitName, unit)
            if name then
                local _, class = Try(UnitClass, unit)
                local r, g, b = ClassColor(class)
                local tags = ""
                if showRole then
                    -- only what the game says: leader, assistant (raid), master looter
                    if UnitIsGroupLeader and Try(UnitIsGroupLeader, unit) then tags = tags .. " |cffffd100(" .. L.TT_LEADER .. ")|r" end
                    if UnitIsGroupAssistant and Try(UnitIsGroupAssistant, unit) then
                        tags = tags .. " |cffffd100(" .. L.TT_ASSISTANT .. ")|r"
                    end
                    if master and master == name then tags = tags .. " |cffffd100(" .. L.TT_LOOTER .. ")|r" end
                end
                -- state in words and color: offline, away, dead
                local state
                if showState then
                    if UnitIsConnected and Try(UnitIsConnected, unit) == false then
                        state = _G.PLAYER_OFFLINE
                    elseif UnitIsDeadOrGhost and Try(UnitIsDeadOrGhost, unit) then
                        state = _G.DEAD
                    elseif UnitIsAFK and Try(UnitIsAFK, unit) then
                        state = _G.CHAT_FLAG_AFK
                    end
                end
                local right = showLevel and tostring(Try(UnitLevel, unit) or "") or ""
                if state then right = "|cffff6060" .. state .. "|r" .. (right ~= "" and "  " .. right or "") end
                tt:AddDoubleLine(Masked(name) .. tags, right, r, g, b, 0.8, 0.8, 0.8)
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
