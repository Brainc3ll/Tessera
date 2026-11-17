local _, ns = ...
local L = ns.L

-- ========================================================================
-- GroupList.lua: the clickable member list of the Group block
-- ========================================================================
-- Shown under the mouse, in place of the tooltip, when the Group block's "On hover" setting is on
-- "Group list" (the default). It stays while the mouse is on the block or on the list, and closes
-- a moment after it leaves both. The members of your party or raid in the game's order, with their
-- role tags and state (offline, dead, away). A click on a name whispers; Shift + click opens a small
-- menu. A search field, the mouse wheel and a scroll bar for a raid; only the visible rows exist
-- (reused). Same idea as FriendsList.lua.

local Tools = ns.BlockTools
local ROWS_DEFAULT, ROWS_MIN, ROWS_MAX = 14, 5, 100 -- rows on screen: the block's "List rows" setting
local visible = ROWS_DEFAULT
local cfgNow -- the Group block's settings, read when the list opens
local WHEEL_STEP = 3
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local BNET_BLUE = { 0.3, 0.75, 1 }

local list -- the window, built on the first opening
local friends = {} -- the members, in the game's order
local shownList = {} -- the ones that match the search
local totalCount = 0
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
        icon = math.floor(16 * k), level = math.floor(26 * k), name = math.floor(210 * k), zone = math.floor(150 * k),
    }
end

local function Tell(f)
    -- ChatFrameUtil first: ChatFrame_SendTell is Blizzard's old fallback, due to go
    local util = ChatFrameUtil
    local send = (util and util.SendTell) or ChatFrame_SendTell
    if send then pcall(send, f.name) end
end

-- you cannot whisper yourself
local function IsMe(f)
    return f.isMe == true
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
    end)
end

local function RowClick(row)
    local f = row.friend
    if not f then return end
    if IsShiftKeyDown() then RowMenu(row) return end
    if IsMe(f) then return end
    Tell(f)
    list:Hide()
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
    if not IsMe(f) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.GUILDLIST_ROW_WHISPER, 0.5, 0.8, 1)
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
    if f.dnd then tag = " " .. (_G.CHAT_FLAG_DND or "DND")
    elseif f.afk then tag = " " .. (_G.CHAT_FLAG_AFK or "AFK") end
    row.name:SetText(("|cff%02x%02x%02x%s|r%s"):format(r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5, Plain(f), tag))
    row.zone:SetText(Tools.Masked(f.zone or ""))
    row:Show()
end

-- Draws what is on screen: the header, the rows from `offset`, the scroll bar
local function Draw()
    if not list then return end
    local total = #shownList
    local maxOffset = math.max(0, total - visible)
    offset = math.min(math.max(0, offset), maxOffset)
    for i, row in ipairs(list.rows) do FillRow(row, i <= visible and shownList[offset + i] or nil) end
    list.title:SetText(("%s  |cffcccccc%s|r"):format(ns:GetBlockName("group"),
        totalCount))
    list.empty:SetShown(total == 0)
    if total == 0 then list.empty:SetText(L.GUILDLIST_NO_MATCH) end
    list.bar:SetShown(maxOffset > 0)
    list.bar:SetMinMaxValues(0, math.max(1, maxOffset))
    list.syncing = true
    list.bar:SetValue(offset)
    list.syncing = nil
end

local function Reload()
    local cfg = cfgNow or (ns.db and ns.db.blocks and ns.db.blocks.group)
    friends = ns.GroupMembers(cfg)
    totalCount = #friends
    Filter()
    Draw()
end

-- The group events come in bursts: one reload every half second at most
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
    row.name:SetWordWrap(false)
    row.zone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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
    local lines = owner and owner.key and ns:BlockHints(owner.key, cfgNow or {}) or {}
    return table.concat(lines, "\n")
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
    local k = (cfgNow and cfgNow.groupListLook == "window") and 1 or ((ns.db and ns.db.tooltipScale) or 1)
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
    list = CreateFrame("Frame", "TesseraGroupList", UIParent, "BackdropTemplate")
    list:SetFrameStrata("TOOLTIP") -- the highest strata, over every window and bar
    list:SetClampedToScreen(true)
    list:EnableMouse(true)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)

    list.title = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    list.title:SetPoint("TOPLEFT", 10, -8 - 2)
    list.title:SetPoint("RIGHT", -10, 0)
    list.title:SetJustifyH("LEFT")

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

    list.hint = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
        for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "UNIT_CONNECTION",
                                 "PLAYER_FLAGS_CHANGED" }) do
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
    table.insert(UISpecialFrames, "TesseraGroupList")
    return list
end

function ns:ShowGroupList(block, cfg)
    Build()
    owner = block or UIParent
    if list:IsShown() then away = 0 return end
    list:SetFrameStrata("TOOLTIP")
    cfgNow = cfg
    if cfg and cfg.groupListLook == "window" then
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
    Layout(cfg and cfg.groupListRows, cfg and cfg.groupListScale)
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
    filter = "" -- (the search field empties itself; the filter follows even if no event comes)
    Reload()
    list:Show()
end

-- the options window opens: the list closes (no window over another)
function ns:HideGroupList()
    if list and list:IsShown() then list:Hide() end
end
