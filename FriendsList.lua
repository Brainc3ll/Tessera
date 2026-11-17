local _, ns = ...
local L = ns.L

-- ========================================================================
-- FriendsList.lua: the clickable friends list of the Friends block
-- ========================================================================
-- Shown under the mouse, in place of the tooltip, when the Friends block's "On hover" setting is on
-- "Friends list" (the default). It stays while the mouse is on the block or on the list, and closes
-- a moment after it leaves both. The friends online (your WoW friends and your Battle.net friends,
-- as the block's settings say), in the block's own order. A click on a name whispers, a right click
-- invites, Shift + click opens a small menu (the same two choices, for players without a right
-- button). A search field, the mouse wheel and a scroll bar for a long list; only the visible rows
-- exist (reused). Same idea as GuildList.lua.

local Tools = ns.BlockTools
local ROWS_DEFAULT, ROWS_MIN, ROWS_MAX = 14, 5, 100 -- rows on screen: the block's "List rows" setting
local visible = ROWS_DEFAULT
local cfgNow -- the Friends block's settings, read when the list opens
local WHEEL_STEP = 3
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local BNET_BLUE = { 0.3, 0.75, 1 }

local list -- the window, built on the first opening
local friends = {} -- the friends online, sorted
local shownList = {} -- the ones that match the search
local onlineCount, totalCount = 0, 0
local myStatus -- your own status, as the tooltip shows it (nil when that part is off)
local offset = 0 -- index of the first row on screen, minus one
local filter = ""
local owner -- the block the list belongs to
local AWAY = 0.3 -- seconds the mouse may stay off the block and the list before the list closes
local away = 0

-- Sizes follow the font height, so a bigger text makes bigger rows
local function Metrics()
    local font = _G["GameTooltipText"] or _G["GameFontHighlight"]
    local _, height
    if font then _, height = font:GetFont() end
    local k = math.max(1, (height or 12) / 12)
    return {
        row = math.max(22, math.floor((height or 12) * 1.7)),
        icon = math.floor(16 * k), level = math.floor(26 * k), name = math.floor(210 * k), zone = math.floor(190 * k),
    }
end

local function Tell(f)
    -- ChatFrameUtil first: the ChatFrame_* names are Blizzard's old fallbacks, due to go
    local util = ChatFrameUtil
    local send
    if f.kind == "bnet" then
        send = (util and util.SendBNetTell) or ChatFrame_SendBNetTell
    else
        send = (util and util.SendTell) or ChatFrame_SendTell
    end
    if send then pcall(send, f.name) end
end

local function Invite(f)
    if not f.inviteName then return end
    local party = C_PartyInfo
    local invite = (party and party.InviteUnit) or _G["InviteUnit"]
    if invite then pcall(invite, f.inviteName) end
end

-- you cannot invite or whisper yourself
local function IsMe(f)
    return f.kind == "wow" and Ambiguate and Ambiguate(f.name, "none") == UnitName("player")
end

local function Plain(f)
    return Tools.Masked(f.label or f.name)
end

-- The rows that match the search (name, zone or note)
local function Filter()
    wipe(shownList)
    local needle = filter:lower()
    for _, f in ipairs(friends) do
        if needle == "" then
            shownList[#shownList + 1] = f
        else
            local hay = ((f.label or "") .. "\n" .. (f.zone or "") .. "\n" .. (f.note or "")):lower()
            if hay:find(needle, 1, true) then shownList[#shownList + 1] = f end
        end
    end
end

local function RowMenu(row)
    local f = row.friend
    if not f or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    -- the menu opens in a lower strata than the list: the list steps back so the menu stays visible
    list:SetFrameStrata("DIALOG")
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(Plain(f))
        root:CreateButton(L.GUILDLIST_WHISPER, function() Tell(f) list:Hide() end)
        if f.inviteName and not IsMe(f) then root:CreateButton(L.GUILDLIST_INVITE, function() Invite(f) end) end
        -- a WoW friend: the name; a Battle.net friend in WoW: the character; elsewhere: the account name to copy
        ns.AddPlayerMenuEntries(root, f.inviteName, f.name, IsMe(f))
    end)
end

local function RowClick(row, button)
    local f = row.friend
    if not f then return end
    if IsShiftKeyDown() then RowMenu(row) return end
    if IsMe(f) then return end
    if button == "RightButton" then
        Invite(f)
    else
        Tell(f)
        list:Hide()
    end
end

local function RowTooltip(row)
    local f = row.friend
    if not f then return end
    -- beside the list, not over its scroll bar: the row stops a few pixels before the list's edge
    GameTooltip:SetOwner(row, "ANCHOR_NONE")
    local listRight, rowRight = list:GetRight(), row:GetRight()
    local gap = 26
    if listRight and rowRight then
        gap = (listRight - rowRight) * list:GetEffectiveScale() / GameTooltip:GetEffectiveScale() + 2
    end
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPLEFT", row, "TOPRIGHT", gap, 0)
    local r, g, b = BNET_BLUE[1], BNET_BLUE[2], BNET_BLUE[3]
    if f.class then r, g, b = Tools.ClassColor(f.class) end
    GameTooltip:AddLine(f.level > 0 and ("%d %s"):format(f.level, Plain(f)) or Plain(f), r, g, b)
    if f.zone ~= "" then GameTooltip:AddLine(Tools.Masked(f.zone), 0.8, 0.8, 0.8) end
    if cfgNow and cfgNow.friendsNotes and type(f.note) == "string" and f.note ~= "" then
        GameTooltip:AddLine(Tools.Masked(f.note), 1, 1, 1, true)
    end
    if not IsMe(f) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.GUILDLIST_ROW_WHISPER, 0.5, 0.8, 1)
        if f.inviteName then GameTooltip:AddLine(L.GUILDLIST_ROW_INVITE, 0.5, 0.8, 1) end
        GameTooltip:AddLine(L.GUILDLIST_ROW_MENU, 0.5, 0.8, 1)
    end
    GameTooltip:Show()
end

local function FillRow(row, f)
    row.friend = f
    if not f then row:Hide() return end
    local coords = f.class and _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[f.class]
    if coords then
        row.icon:SetTexture(CLASS_ICONS)
        row.icon:SetTexCoord(unpack(coords))
    else
        row.icon:SetTexture(nil)
    end
    row.level:SetText(f.level > 0 and f.level or "")
    local r, g, b = BNET_BLUE[1], BNET_BLUE[2], BNET_BLUE[3]
    if f.class then r, g, b = Tools.ClassColor(f.class) end
    local tag = ""
    -- a text marker too, not only a color
    if f.dnd then tag = " " .. L.TT_DND_TAG
    elseif f.afk then tag = " " .. L.TT_AFK_TAG end
    row.name:SetText(("|cff%02x%02x%02x%s|r%s"):format(r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5, Plain(f), tag))
    row.zone:SetText(Tools.Masked(f.right or f.zone or ""))
    row:Show()
end

-- Draws what is on screen: the header, the rows from `offset`, the scroll bar
local function Draw()
    if not list then return end
    local total = #shownList
    local maxOffset = math.max(0, total - visible)
    offset = math.min(math.max(0, offset), maxOffset)
    for i, row in ipairs(list.rows) do FillRow(row, i <= visible and shownList[offset + i] or nil) end
    list.title:SetText(("%s  |cffcccccc%s|r"):format(ns:GetBlockName("friends"),
        L.GUILDLIST_ONLINE:format(onlineCount, totalCount)))
    list.status:SetText(myStatus or "")
    list.empty:SetShown(total == 0)
    if total == 0 then list.empty:SetText(#friends == 0 and L.FRIENDSLIST_EMPTY or L.GUILDLIST_NO_MATCH) end
    list.bar:SetShown(maxOffset > 0)
    list.bar:SetMinMaxValues(0, math.max(1, maxOffset))
    list.syncing = true
    list.bar:SetValue(offset)
    list.syncing = nil
end

local function Reload()
    local cfg = cfgNow or (ns.db and ns.db.blocks and ns.db.blocks.friends)
    friends, onlineCount, totalCount, myStatus = ns.FriendsOnline(cfg)
    Filter()
    Draw()
end

-- The friends events come in bursts: one reload every half second at most
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
    row.level = row:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    row.level:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.level:SetWidth(m.level)
    row.level:SetJustifyH("LEFT")
    row.level:SetTextColor(0.8, 0.8, 0.8)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    row.name:SetPoint("LEFT", row.level, "RIGHT", 4, 0)
    row.name:SetWidth(m.name)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.zone = row:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    row.zone:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.zone:SetPoint("RIGHT", -2, 0)
    row.zone:SetJustifyH("RIGHT")
    row.zone:SetWordWrap(false)
    row.zone:SetTextColor(0.8, 0.8, 0.8)
    list.rows[i] = row
    return row
end

-- The blue click hints of the block's tooltip, kept under the list (they go with the tooltip it replaces)
local function HintText()
    return ns:ListHintText({ L.GUILDLIST_ROW_WHISPER, L.GUILDLIST_ROW_INVITE, L.GUILDLIST_ROW_MENU }, owner and owner.key, cfgNow)
end

-- Sizes the list for `rows` visible rows at `scale` percent; makes the rows it lacks
local function Layout(rows, scale)
    local m = Metrics()
    local width = 16 + m.icon + m.level + m.name + m.zone + 16 + 10
    local head = 8 + m.row + 4 -- title
    local top = head + m.row + 4 -- and the search field
    rows = math.min(ROWS_MAX, math.max(ROWS_MIN, tonumber(rows) or ROWS_DEFAULT))
    visible = rows
    -- the tooltip size setting (General tab) also sizes the list when it looks like a tooltip
    local k = (cfgNow and cfgNow.friendsListLook == "window") and 1 or ((ns.db and ns.db.tooltipScale) or 1)
    list:SetScale(math.min(150, math.max(80, tonumber(scale) or 100)) / 100 * k)
    local hintText = HintText()
    list.hint:SetWidth(width - 20)
    list.hint:SetText(hintText)
    local hintH = hintText ~= "" and ((list.hint:GetStringHeight() or 0) + 8) or 0
    list:SetSize(width, top + rows * m.row + 8 + hintH)
    list.hint:ClearAllPoints()
    list.hint:SetPoint("BOTTOMLEFT", 10, 6)
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
    end
    for i = rows + 1, #list.rows do list.rows[i]:Hide() end
end

local function Build()
    if list then return list end
    list = CreateFrame("Frame", "TesseraFriendsList", UIParent, "BackdropTemplate")
    list:SetFrameStrata("TOOLTIP") -- the highest strata, over every window and bar
    list:SetClampedToScreen(true)
    list:EnableMouse(true)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)

    list.title = list:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
    list.title:SetPoint("TOPLEFT", 10, -8 - 2)
    list.title:SetPoint("RIGHT", -10, 0)
    list.title:SetJustifyH("LEFT")
    -- your own status, on the title line, right side (the tooltip's first line)
    list.status = list:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    list.status:SetPoint("TOPRIGHT", -26, -8 - 2)
    list.status:SetJustifyH("RIGHT")

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

    list.hint = list:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    list.hint:SetJustifyH("LEFT")
    list.hint:SetTextColor(0.5, 0.8, 1)
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
    bar:SetScript("OnValueChanged", function(_, value)
        if list.syncing then return end
        offset = math.floor(value + 0.5)
        Draw()
    end)
    list.bar = bar

    list:SetScript("OnShow", function(self)
        for _, event in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
                                 "BN_FRIEND_INFO_CHANGED", "BN_INFO_CHANGED" }) do
            pcall(self.RegisterEvent, self, event)
        end
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
    table.insert(UISpecialFrames, "TesseraFriendsList")
    return list
end

function ns:ShowFriendsList(block, cfg)
    Build()
    owner = block or UIParent
    if list:IsShown() then away = 0 return end
    list:SetFrameStrata("TOOLTIP")
    cfgNow = cfg
    if cfg and cfg.friendsListLook == "window" then
        if ns.SkinWindow then ns:SkinWindow(list) end
    else
        ns.ApplyTooltipLook(list) -- the game's own tooltip look (or the look another addon gives it)
    end
    -- after the skin, which sets the windows' own scale: the block's "List size" wins
    Layout(cfg and cfg.friendsListRows, cfg and cfg.friendsListScale)
    ns.PlaceHoverList(list, owner) -- the tooltip's own side and alignment settings
    offset = 0
    list.box:SetText("")
    filter = "" -- (the search field empties itself; the filter follows even if no event comes)
    -- the friends are read again, and refreshed when the game answers
    if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
    Reload()
    list:Show()
end

-- the options window opens: the list closes (no window over another)
function ns:HideFriendsList()
    if list and list:IsShown() then list:Hide() end
end

-- another block is hovered: this list closes, unless it belongs to that block
table.insert(ns.hoverListHiders, function(except)
    if list and list:IsShown() and owner ~= except then list:Hide() end
end)
