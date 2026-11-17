local _, ns = ...
local L = ns.L

-- The history of the Whispers block, shown under the mouse in place of its tooltip (setting
-- "On hover"): one row for each of the last whispers (the pinned ones first), with the start of the
-- message. A click on a row replies, a right click pins it or unpins it. It stays while the mouse is on the block or on the list and
-- closes a moment after it leaves both. Same idea as GuildList.lua, smaller: at most 20 rows.
local Tools = ns.BlockTools
local MAX_ROWS = 40 -- 20 whispers and the pinned ones
local AWAY = 0.3 -- seconds the mouse may stay away before the list closes

local list, owner, cfgNow
local away = 0

-- Sizes follow the font height, so a bigger text makes bigger rows
local function Metrics()
    local font = _G["GameFontHighlight"]
    local _, height
    if font then _, height = font:GetFont() end
    local k = math.max(1, (height or 12) / 12)
    return { line = math.max(14, math.floor((height or 12) * 1.3)), name = math.floor(170 * k), count = math.floor(90 * k),
             time = math.floor(120 * k) }
end

local function Draw()
    if not list then return end
    local history = ns.WhisperHistory(cfgNow)
    local m = Metrics()
    local rowH = m.line * 2 + 6
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
            row:Show()
        else
            row:Hide()
        end
    end
    list.empty:SetShown(#history == 0)
    list:SetHeight(8 + math.max(1, #history) * rowH + 8 + m.line + 4)
end

local function Click(row, button)
    if not row.entry then return end
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
    list:SetSize(width, 8 + rowH + 8 + m.line + 4)
    list.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetSize(width - 16, rowH)
        row:SetPoint("TOPLEFT", 8, -(8 + (i - 1) * rowH))
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", Click)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.12)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("TOPLEFT", 4, -2)
        row.name:SetWidth(m.name)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.count:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
        row.count:SetWidth(m.count)
        row.count:SetJustifyH("LEFT")
        row.count:SetTextColor(1, 0.82, 0)
        row.time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.time:SetPoint("TOPRIGHT", -4, -2)
        row.time:SetJustifyH("RIGHT")
        row.time:SetTextColor(0.7, 0.7, 0.7)
        -- the start of the message, cut with "..." when it is too long for the line
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row.text:SetTextColor(0.6, 0.6, 0.6)
        list.rows[i] = row
    end
    -- what the clicks do
    list.hint = list:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    list.hint:SetPoint("BOTTOMLEFT", 12, 8)
    list.hint:SetTextColor(0.5, 0.8, 1)
    list.hint:SetText(L.WHISPERLIST_HINT)
    list.empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    list.empty:SetPoint("TOP", list, "TOP", 0, -14)
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
    if list.SetBackdrop then
        -- the look of a tooltip: the game's own background and border
        list:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        list:SetBackdropColor(0.07, 0.07, 0.1, 0.96)
        list:SetBackdropBorderColor(1, 1, 1, 1)
    end
    list:SetScale((ns.db and ns.db.tooltipScale) or 1)
    list:ClearAllPoints()
    local _, y = owner:GetCenter()
    -- touching the block, so the mouse crosses no gap on its way to the list
    if y and y < UIParent:GetHeight() / 2 then
        list:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 0)
    else
        list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 0)
    end
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
