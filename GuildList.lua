local _, ns = ...
local L = ns.L

-- ========================================================================
-- GuildList.lua: the clickable guild list of the Guild block
-- ========================================================================
-- Shown under the mouse, in place of the tooltip, when the Guild block's "Member list" setting is on.
-- It stays while the mouse is on the block or on the list, and closes a moment after it leaves both.
-- Online members only, in the order of the block's own settings (sort, leaders on top). A click on a
-- name whispers, a right click invites, Shift + click opens a small menu (the same two choices, for
-- players without a right button). Big guilds: a search field, the mouse wheel and a scroll bar; only
-- the visible rows exist (reused), so memory does not depend on the guild's size.

local Tools = ns.BlockTools
local ROWS_DEFAULT, ROWS_MIN, ROWS_MAX = 14, 5, 100 -- rows on screen: the block's "List rows" setting
local visible = ROWS_DEFAULT
local cfgNow -- the Guild block's settings, read when the list opens

-- the tooltip's own checkboxes (count, message, rank, note) also drive the list
local function On(field)
    return not cfgNow or cfgNow[field] ~= false
end
local WHEEL_STEP = 3
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local list -- the window, built on the first opening
local members = {} -- the sorted online members
local shownList = {} -- members that match the search
local offset = 0 -- index of the first row on screen, minus one
local filter = ""
local owner -- the block the list belongs to
local AWAY = 0.3 -- seconds the mouse may stay off the block and the list before the list closes
local away = 0

-- Sizes follow the font height, so a bigger text makes bigger rows
local function Metrics()
    local font = _G["GameFontHighlight"]
    local _, height
    if font then _, height = font:GetFont() end
    local k = math.max(1, (height or 12) / 12)
    return {
        row = math.max(22, math.floor((height or 12) * 1.7)),
        icon = math.floor(16 * k), level = math.floor(26 * k), name = math.floor(130 * k),
        rank = math.floor(90 * k), zone = math.floor(150 * k),
    }
end

local function Tell(name)
    -- ChatFrameUtil first: the ChatFrame_* names are Blizzard's old fallbacks, due to go
    local util = ChatFrameUtil
    local send = (util and util.SendTell) or ChatFrame_SendTell
    if send then pcall(send, name) end
end

local function Invite(name)
    local party = C_PartyInfo
    local invite = (party and party.InviteUnit) or _G["InviteUnit"]
    if invite then pcall(invite, name) end
end

local function Short(name, context)
    return Ambiguate and Ambiguate(name, context) or name
end

local function IsMe(name)
    return Short(name, "none") == UnitName("player")
end

local function Plain(name)
    return Tools.Masked(Short(name, "guild"))
end

-- The rows that match the search (name, zone, rank or note)
local function Filter()
    wipe(shownList)
    local needle = filter:lower()
    for _, m in ipairs(members) do
        if needle == "" then
            shownList[#shownList + 1] = m
        else
            local hay = ((m.name or "") .. "\n" .. (m.zone or "") .. "\n" .. (m.rank or "") .. "\n" .. (m.note or "")):lower()
            if hay:find(needle, 1, true) then shownList[#shownList + 1] = m end
        end
    end
end

local function RowMenu(row)
    local m = row.member
    if not m or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    -- the menu opens in a lower strata than the list: the list steps back so the menu stays visible
    list:SetFrameStrata("DIALOG")
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(Plain(m.name))
        root:CreateButton(L.GUILDLIST_WHISPER, function() Tell(m.name) list:Hide() end)
        if not IsMe(m.name) then root:CreateButton(L.GUILDLIST_INVITE, function() Invite(m.name) end) end
    end)
end

local function RowClick(row, button)
    local m = row.member
    if not m then return end
    if IsShiftKeyDown() then RowMenu(row) return end
    if IsMe(m.name) then return end
    if button == "RightButton" then
        Invite(m.name)
    else
        Tell(m.name)
        list:Hide()
    end
end

local function RowTooltip(row)
    local m = row.member
    if not m then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local r, g, b = Tools.ClassColor(m.class)
    GameTooltip:AddLine(("%d %s"):format(m.level, Plain(m.name)), r, g, b)
    if On("guildTipRank") and type(m.rank) == "string" and m.rank ~= "" then GameTooltip:AddLine(m.rank, 1, 0.82, 0) end
    if m.zone ~= "" then GameTooltip:AddLine(Tools.Masked(m.zone), 0.8, 0.8, 0.8) end
    if On("guildTipNote") and type(m.note) == "string" and m.note ~= "" then GameTooltip:AddLine(Tools.Masked(m.note), 1, 1, 1, true) end
    if not IsMe(m.name) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.GUILDLIST_ROW_WHISPER, 0.5, 0.8, 1)
        GameTooltip:AddLine(L.GUILDLIST_ROW_INVITE, 0.5, 0.8, 1)
        GameTooltip:AddLine(L.GUILDLIST_ROW_MENU, 0.5, 0.8, 1)
    end
    GameTooltip:Show()
end

local function FillRow(row, m)
    row.member = m
    if not m then row:Hide() return end
    local coords = _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[m.class]
    if coords then
        row.icon:SetTexture(CLASS_ICONS)
        row.icon:SetTexCoord(unpack(coords))
    else
        row.icon:SetTexture(nil)
    end
    row.level:SetText(m.level)
    local r, g, b = Tools.ClassColor(m.class)
    local tag = ""
    -- a text marker too, not only a color (status: 1 away, 2 busy)
    if m.status == 1 then tag = " " .. (_G.CHAT_FLAG_AFK or "AFK")
    elseif m.status == 2 then tag = " " .. (_G.CHAT_FLAG_DND or "DND") end
    row.name:SetText(("|cff%02x%02x%02x%s|r%s"):format(r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5, Plain(m.name), tag))
    row.rank:SetText(Tools.Masked(m.rank or ""))
    row.zone:SetText(Tools.Masked(m.zone or ""))
    row:Show()
end

-- Draws what is on screen: the header, the rows from `offset`, the scroll bar
local function Draw()
    if not list then return end
    local total = #shownList
    local maxOffset = math.max(0, total - visible)
    offset = math.min(math.max(0, offset), maxOffset)
    for i, row in ipairs(list.rows) do FillRow(row, i <= visible and shownList[offset + i] or nil) end
    local guild = GetGuildInfo("player")
    local count, online = GetNumGuildMembers()
    if On("guildTipCount") then
        list.title:SetText(("%s  |cffcccccc%s|r"):format(Tools.Masked(guild or ""),
            L.GUILDLIST_ONLINE:format(online or #members, count or 0)))
    else
        list.title:SetText(Tools.Masked(guild or ""))
    end
    list.empty:SetShown(total == 0)
    if total == 0 then list.empty:SetText(#members == 0 and L.GUILDLIST_EMPTY or L.GUILDLIST_NO_MATCH) end
    list.bar:SetShown(maxOffset > 0)
    list.bar:SetMinMaxValues(0, math.max(1, maxOffset))
    list.syncing = true
    list.bar:SetValue(offset)
    list.syncing = nil
end

local function Reload()
    local cfg = cfgNow or (ns.db and ns.db.blocks and ns.db.blocks.guild)
    members = ns.GuildMembers(cfg)
    -- "Members shown" of the tooltip is also the most the list holds
    local cap = tonumber(cfg and cfg.guildMax)
    if cap then for i = #members, cap + 1, -1 do members[i] = nil end end
    Filter()
    Draw()
end

-- The roster events come in bursts: one reload every half second at most
local reloadQueued = false
local function QueueReload()
    if reloadQueued then return end
    reloadQueued = true
    C_Timer.After(0.5, function()
        reloadQueued = false
        if list and list:IsShown() then Reload() end
    end)
end

local function Scroll(delta)
    offset = offset - delta * WHEEL_STEP
    Draw()
end

-- One row of the list (made once, then reused); Layout() sizes and places it
local function MakeRow(i, m)
    local row = CreateFrame("Button", nil, list)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
    row:SetScript("OnClick", RowClick)
    row:SetScript("OnEnter", RowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.12)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(m.icon, m.icon)
    row.icon:SetPoint("LEFT", 2, 0)
    row.level = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.level:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.level:SetWidth(m.level)
    row.level:SetJustifyH("LEFT")
    row.level:SetTextColor(0.8, 0.8, 0.8)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.level, "RIGHT", 4, 0)
    row.name:SetWidth(m.name)
    row.name:SetJustifyH("LEFT")
    row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.rank:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.rank:SetWidth(m.rank)
    row.rank:SetJustifyH("LEFT")
    row.rank:SetTextColor(1, 0.82, 0)
    row.zone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.zone:SetPoint("LEFT", row.rank, "RIGHT", 4, 0)
    row.zone:SetPoint("RIGHT", -2, 0)
    row.zone:SetJustifyH("RIGHT")
    row.zone:SetTextColor(0.8, 0.8, 0.8)
    list.rows[i] = row
    return row
end

-- Sizes the list for `rows` visible rows at `scale` percent; makes the rows it lacks
local function Layout(rows, scale)
    local m = Metrics()
    local showRank = On("guildTipRank")
    local motd = On("guildTipMotd") and C_GuildInfo and C_GuildInfo.GetMOTD and C_GuildInfo.GetMOTD()
    local hasMotd = type(motd) == "string" and motd ~= ""
    local width = 16 + m.icon + m.level + m.name + (showRank and m.rank or 0) + m.zone + 16 + 10
    local head = 8 + m.row + (hasMotd and m.row or 0) + 4 -- title and message of the day
    local top = head + m.row + 4 -- and the search field
    rows = math.min(ROWS_MAX, math.max(ROWS_MIN, tonumber(rows) or ROWS_DEFAULT))
    visible = rows
    -- the tooltip size setting (General tab) also sizes the list when it looks like a tooltip
    local k = (cfgNow and cfgNow.guildListLook == "window") and 1 or ((ns.db and ns.db.tooltipScale) or 1)
    list:SetScale(math.min(150, math.max(80, tonumber(scale) or 100)) / 100 * k)
    list:SetSize(width, top + rows * m.row + 8)
    list.motd:SetShown(hasMotd)
    if hasMotd then
        list.motd:SetWidth(width - 20)
        list.motd:SetText(Tools.Masked(motd))
    end
    list.box:ClearAllPoints()
    list.box:SetPoint("TOPLEFT", 14, -head)
    list.box:SetSize(width - 36, m.row)
    list.empty:ClearAllPoints()
    list.empty:SetPoint("TOP", list, "TOP", 0, -(top + 8))
    list.bar:ClearAllPoints()
    list.bar:SetPoint("TOPRIGHT", -6, -top)
    list.bar:SetSize(12, rows * m.row)
    for i = 1, rows do
        local row = list.rows[i] or MakeRow(i, m)
        row:SetSize(width - 32, m.row)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 8, -(top + (i - 1) * m.row))
        row.rank:SetShown(showRank)
        row.rank:SetWidth(showRank and m.rank or 1)
    end
    for i = rows + 1, #list.rows do list.rows[i]:Hide() end
end

local function Build()
    if list then return list end
    list = CreateFrame("Frame", "TesseraGuildList", UIParent, "BackdropTemplate")
    list:SetFrameStrata("TOOLTIP") -- the highest strata, over every window and bar
    list:SetClampedToScreen(true)
    list:EnableMouse(true)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)

    list.title = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    list.title:SetPoint("TOPLEFT", 10, -8 - 2)
    list.title:SetPoint("RIGHT", -10, 0)
    list.title:SetJustifyH("LEFT")
    list.motd = list:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    list.motd:SetPoint("TOPLEFT", list.title, "BOTTOMLEFT", 0, -4)
    list.motd:SetJustifyH("LEFT")
    list.motd:SetWordWrap(false)
    list.motd:SetTextColor(0.9, 0.9, 0.55)

    local box = CreateFrame("EditBox", nil, list, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    box.hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    box.hint:SetPoint("LEFT", 2, 0)
    box.hint:SetText(L.GUILDLIST_SEARCH)
    box:SetScript("OnTextChanged", function(self)
        filter = self:GetText() or ""
        self.hint:SetShown(filter == "" and not self:HasFocus())
        offset = 0
        Filter()
        Draw()
    end)
    box:SetScript("OnEditFocusGained", function(self) self.hint:Hide() end)
    box:SetScript("OnEditFocusLost", function(self) self.hint:SetShown((self:GetText() or "") == "") end)
    box:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then self:SetText("") end
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    list.box = box

    list.rows = {}

    list.empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")

    local bar = CreateFrame("Slider", nil, list)
    bar:SetOrientation("VERTICAL")
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetMinMaxValues(0, 1)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.08)
    bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    local thumb = bar:GetThumbTexture()
    if thumb then thumb:SetSize(12, 18) end
    bar:SetScript("OnValueChanged", function(self, value)
        if list.syncing then return end
        offset = math.floor(value + 0.5)
        Draw()
    end)
    list.bar = bar

    list:SetScript("OnShow", function(self)
        self:RegisterEvent("GUILD_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_GUILD_UPDATE")
        away = 0
    end)
    -- closes a moment after the mouse leaves the block and the list (it stays while you type a search)
    list:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() or (owner and owner:IsMouseOver()) or self.box:HasFocus() or ns.dragging then
            away = 0
        else
            away = away + elapsed
            if away >= AWAY then self:Hide() end
        end
    end)
    list:SetScript("OnHide", function(self)
        self:UnregisterAllEvents()
        self.box:ClearFocus()
        GameTooltip:Hide()
    end)
    list:SetScript("OnEvent", QueueReload)
    list:Hide()
    -- closes with Escape, like Blizzard's menus
    table.insert(UISpecialFrames, "TesseraGuildList")
    return list
end

function ns:ShowGuildList(block, cfg)
    if not IsInGuild() then return end
    Build()
    owner = block or UIParent
    if list:IsShown() then away = 0 return end
    list:SetFrameStrata("TOOLTIP")
    cfgNow = cfg
    if cfg and cfg.guildListLook == "window" then
        if ns.SkinWindow then ns:SkinWindow(list) end
    elseif list.SetBackdrop then
        -- the look of a tooltip: the game's own background and border
        list:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        list:SetBackdropColor(0.07, 0.07, 0.1, 0.96)
        list:SetBackdropBorderColor(1, 1, 1, 1)
    end
    -- after the skin, which sets the windows' own scale: the block's "List size" wins
    Layout(cfg and cfg.guildListRows, cfg and cfg.guildListScale)
    list:ClearAllPoints()
    local _, y = owner:GetCenter()
    -- touching the block, so the mouse crosses no gap on its way to the list
    if y and y < UIParent:GetHeight() / 2 then
        list:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 0)
    else
        list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 0)
    end
    offset = 0
    list.box:SetText("")
    -- the roster is read again, and refreshed when the server answers
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
    Reload()
    list:Show()
end

-- the options window opens: the list closes (no window over another)
function ns:HideGuildList()
    if list and list:IsShown() then list:Hide() end
end
