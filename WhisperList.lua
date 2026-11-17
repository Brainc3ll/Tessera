local _, ns = ...
local L = ns.L

-- The history of the Whispers block, shown under the mouse in place of its tooltip (setting
-- "On hover"): one row for each of the last whispers (the pinned ones first), with the start of the
-- message. A click on a row replies, a right click pins it or unpins it, Ctrl + click deletes it
-- (not a pinned one); the "Clear" button at the top removes all the whispers that are not pinned. It stays while the mouse is on the block or on the list and
-- closes a moment after it leaves both. Same idea as GuildList.lua, smaller: at most 20 rows.
local Tools = ns.BlockTools
local MAX_ROWS = 40 -- 20 whispers and the pinned ones
local AWAY = 0.3 -- seconds the mouse may stay away before the list closes

local list, owner, cfgNow
local away = 0

-- Sizes follow the font height, so a bigger text makes bigger rows
local function Metrics()
    local font = _G["GameTooltipText"] or _G["GameFontHighlight"]
    local _, height
    if font then _, height = font:GetFont() end
    local k = math.max(1, (height or 12) / 12)
    return { line = math.max(14, math.floor((height or 12) * 1.3)), name = math.floor(170 * k), count = math.floor(90 * k),
             time = math.floor(120 * k) }
end

-- A small tooltip for a button inside the list: set beside the list, not over it (the list sits in
-- the TOOLTIP strata too and would cover it)
local function SideTip(button)
    GameTooltip:SetOwner(button, "ANCHOR_NONE")
    local gap = 8
    local listRight, right = list:GetRight(), button:GetRight()
    if listRight and right then
        gap = (listRight - right) * list:GetEffectiveScale() / GameTooltip:GetEffectiveScale() + 6
    end
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("LEFT", button, "RIGHT", gap, 0)
end

local function Draw()
    if not list then return end
    local history = ns.WhisperHistory(cfgNow)
    local m = Metrics()
    local rowH = m.line * 2 + 6
    local headH = m.line + 12 -- the title line with the Clear button
    local loose = 0
    for _, w in ipairs(history) do if not w.pinned then loose = loose + 1 end end
    list.clear:SetShown(loose > 0)
    if loose == 0 then list.clear.sure = nil list.clear:SetText(L.WHISPERLIST_CLEAR) end
    for i = 1, MAX_ROWS do
        local row = list.rows[i]
        local w = history[i]
        row.entry = w
        if w then
            local unread = not w.read
            row.name:SetText(Tools.Masked(w.name))
            row.name:SetTextColor(unread and 1 or 0.75, unread and 0.82 or 0.75, unread and 0 or 0.75)
            -- words as well as colors: what is new, what is pinned
            local tag = ""
            if w.pinned then tag = L.WHISPER_TAG_PINNED end
            if unread then tag = (tag ~= "" and tag .. ", " or "") .. L.WHISPER_TAG_NEW end
            row.count:SetText(tag)
            row.time:SetText(("%s (%s)"):format(date("%H:%M", w.when or 0), L.TT_AGO:format(Tools.ShortDuration(GetTime() - w.at))))
            row.text:SetText(Tools.Masked(w.text or ""))
            -- the two small buttons: the pin (filled when pinned, an outline when not: a shape, not only a
            -- color) and the cross (not on a pinned whisper: unpin it first)
            row.pin:SetAtlas(w.pinned and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off")
            row.del:SetShown(not w.pinned)
            if row.del.sure and row.del.sure ~= w then row.del.sure = nil end
            if row.del.sure then row.time:SetText("|cffff5050" .. L.WHISPERLIST_SURE .. "|r") end
            row:Show()
        else
            row:Hide()
        end
    end
    list.empty:SetShown(#history == 0)
    -- what a click on a row does, then the block's own clicks (as its tooltip shows them)
    local hint = ns:ListHintText({ L.WHISPERLIST_HINT, L.WHISPERLIST_DELETE_HINT, L.GUILDLIST_ROW_MENU },
        owner and owner.key, cfgNow)
    list.hint:SetWidth(list:GetWidth() - 24)
    list.hint:SetText(hint)
    local hintH = hint ~= "" and math.max(m.line, list.hint:GetStringHeight() or m.line) or 0
    list:SetHeight(headH + math.max(1, #history) * rowH + 8 + hintH + 4)
end

-- Shift + click: the full menu (reply, invite, pin, delete, and the menu of the other lists)
local function RowMenu(row)
    local w = row.entry
    if not w or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    -- the menu opens in a lower strata than the list: the list steps back so the menu stays visible
    list:SetFrameStrata("DIALOG")
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(Tools.Masked(w.name))
        root:CreateButton(L.GUILDLIST_WHISPER, function() ns.WhisperReply(w) list:Hide() end)
        if not w.bnet then
            root:CreateButton(L.GUILDLIST_INVITE, function()
                local party = C_PartyInfo
                local invite = (party and party.InviteUnit) or _G["InviteUnit"]
                if invite then pcall(invite, w.name) end
            end)
        end
        root:CreateButton(w.pinned and L.WHISPER_MENU_UNPIN or L.WHISPER_MENU_PIN, function() ns.WhisperTogglePin(w) end)
        if not w.pinned then root:CreateButton(L.WHISPER_MENU_DELETE, function() ns.WhisperDelete(w) end) end
        -- a Battle.net whisper comes from an account: no character name to add, look up or ignore
        ns.AddPlayerMenuEntries(root, not w.bnet and w.name or nil, w.name, false)
    end)
end

local function Click(row, button)
    if not row.entry then return end
    if IsShiftKeyDown() then RowMenu(row) return end
    if IsControlKeyDown() then
        ns.WhisperDelete(row.entry) -- a pinned whisper stays: unpin it first
        return
    end
    if button == "RightButton" then
        ns.WhisperTogglePin(row.entry) -- the list stays open
    else
        ns.WhisperReply(row.entry)
        list:Hide()
    end
end

local function Build()
    if list then return list end
    local m = Metrics()
    local rowH = m.line * 2 + 6
    local width = 16 + m.name + m.count + m.time + 10
    list = CreateFrame("Frame", "TesseraWhisperList", UIParent, "BackdropTemplate")
    list:SetFrameStrata("TOOLTIP") -- the highest strata, over every window and bar
    list:SetClampedToScreen(true)
    list:EnableMouse(true)
    local headH = m.line + 12
    list:SetSize(width, headH + rowH + 8 + m.line + 4)
    list.rows = {}
    list.title = list:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
    list.title:SetPoint("TOPLEFT", 12, -8)
    list.title:SetText(ns:GetBlockName("whispers"))
    -- "Clear": removes the whispers that are not pinned; a second click within 3 seconds confirms
    local clear = CreateFrame("Button", nil, list, "UIPanelButtonTemplate")
    clear:SetSize(math.floor(90 * (m.name / 170)), m.line + 6)
    clear:SetPoint("TOPRIGHT", -8, -5)
    clear:SetText(L.WHISPERLIST_CLEAR)
    clear:SetScript("OnClick", function(self)
        if self.sure then
            self.sure = nil
            self:SetText(L.WHISPERLIST_CLEAR)
            ns.WhisperClear()
        else
            self.sure = true
            self:SetText(L.WHISPERLIST_SURE)
            C_Timer.After(3, function()
                if self.sure then
                    self.sure = nil
                    self:SetText(L.WHISPERLIST_CLEAR)
                end
            end)
        end
    end)
    clear:SetScript("OnEnter", function(self)
        SideTip(self)
        GameTooltip:AddLine(L.TIP_WHISPERLIST_CLEAR, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    clear:SetScript("OnLeave", function() GameTooltip:Hide() end)
    list.clear = clear
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetSize(width - 16, rowH)
        row:SetPoint("TOPLEFT", 8, -(headH + (i - 1) * rowH))
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", Click)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.12)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        row.name:SetPoint("TOPLEFT", 4, -2)
        row.name:SetWidth(m.name)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.count = row:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        row.count:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
        row.count:SetWidth(m.count)
        row.count:SetJustifyH("LEFT")
        row.count:SetTextColor(1, 0.82, 0)
        row.time = row:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        row.time:SetPoint("TOPRIGHT", -4, -2)
        row.time:SetJustifyH("RIGHT")
        row.time:SetTextColor(0.7, 0.7, 0.7)
        -- the start of the message, cut with "..." when it is too long for the line
        row.text = row:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        row.text:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        -- small buttons at the end of the message line: pin, then delete (a second click within 3 seconds
        -- confirms; the time then reads "Sure?")
        local size = math.max(16, m.line)
        local del = CreateFrame("Button", nil, row)
        del:SetSize(size, size)
        del:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 2)
        del:SetNormalAtlas("communities-icon-redx")
        del:SetHighlightAtlas("communities-icon-redx", "ADD")
        del:SetScript("OnClick", function(self)
            local entry = row.entry
            if not entry then return end
            if self.sure == entry then
                self.sure = nil
                ns.WhisperDelete(entry)
            else
                self.sure = entry
                Draw()
                C_Timer.After(3, function()
                    if self.sure == entry then
                        self.sure = nil
                        if list:IsShown() then Draw() end
                    end
                end)
            end
        end)
        del:SetScript("OnEnter", function(self)
            SideTip(self)
            GameTooltip:AddLine(L.WHISPER_MENU_DELETE, 1, 1, 1)
            GameTooltip:AddLine(L.TIP_WHISPER_DELETE_BUTTON, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        del:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.del = del
        local pinButton = CreateFrame("Button", nil, row)
        pinButton:SetSize(size, size)
        pinButton:SetPoint("RIGHT", del, "LEFT", -4, 0)
        row.pin = pinButton:CreateTexture(nil, "ARTWORK")
        row.pin:SetAllPoints()
        local glow = pinButton:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.2)
        pinButton:SetScript("OnClick", function() if row.entry then ns.WhisperTogglePin(row.entry) end end)
        pinButton:SetScript("OnEnter", function(self)
            SideTip(self)
            GameTooltip:AddLine(row.entry and row.entry.pinned and L.WHISPER_MENU_UNPIN or L.WHISPER_MENU_PIN, 1, 1, 1)
            GameTooltip:Show()
        end)
        pinButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.pinButton = pinButton
        row.text:SetPoint("RIGHT", pinButton, "LEFT", -6, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row.text:SetTextColor(0.6, 0.6, 0.6)
        list.rows[i] = row
    end
    -- what the clicks do
    list.hint = list:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    list.hint:SetPoint("BOTTOMLEFT", 12, 8)
    list.hint:SetJustifyH("LEFT")
    list.hint:SetTextColor(0.5, 0.8, 1)
    list.hint:SetText(L.WHISPERLIST_HINT)
    list.empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    list.empty:SetPoint("TOP", list, "TOP", 0, -(headH + 6))
    list.empty:SetText(L.NONE)
    list:SetScript("OnShow", function() away = 0 end)
    list:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() or (owner and owner:IsMouseOver()) or ns.dragging then
            away = 0
        else
            away = away + elapsed
            if away >= AWAY then self:Hide() end
        end
    end)
    list:Hide()
    table.insert(UISpecialFrames, "TesseraWhisperList") -- closes with Escape
    return list
end

function ns:ShowWhisperList(block, cfg)
    Build()
    owner = block or UIParent
    cfgNow = cfg
    if list:IsShown() then away = 0 return end
    list:SetFrameStrata("TOOLTIP") -- back on top after a menu
    ns.ApplyListLook(list, false) -- the game's own tooltip look (or the look another addon gives it)
    list:SetScale((ns.db and ns.db.tooltipScale) or 1)
    ns.PlaceHoverList(list, owner) -- the tooltip's own side and alignment settings
    Draw()
    list:Show()
end

-- A whisper came in while the list is open
function ns:RefreshWhisperList()
    if list and list:IsShown() then Draw() end
end

-- the options window opens: the list closes (no window over another)
function ns:HideWhisperList()
    if list and list:IsShown() then list:Hide() end
end

-- another block is hovered: this list closes, unless it belongs to that block
table.insert(ns.hoverListHiders, function(except)
    if list and list:IsShown() and owner ~= except then list:Hide() end
end)
