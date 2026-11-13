local _, ns = ...
local L = ns.L

-- Placement part of the options window: the banner shown while blocks are unlocked and the nudge pad (move by the pixel).
-- Shared with the other Options*.lua files through ns.OptionsTools (see Options.lua).
local Tools = ns.OptionsTools
local S = Tools.S
local AttachTip, ListenForUndo = Tools.AttachTip, Tools.ListenForUndo


---------------------------------------------------------------------------
-- "Placement mode" banner: visible while blocks are unlocked
---------------------------------------------------------------------------
-- Creates one button of the placement banner
local function BannerButton(b, text, tip, onClick)
    local btn = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
    btn:SetSize(104, 22)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    AttachTip(btn, text, tip)
    return btn
end

local BANNER_W, BANNER_H = 530, 130

-- "Empty blocks: shown / hidden": one button in each placement banner (V on the keyboard)
local emptyButtons = {}
local function EmptyBlocksButton(parent)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(176, 22)
    btn:SetScript("OnClick", function() ns:SetPlaceHideEmpty(not ns.placeHideEmpty) end)
    AttachTip(btn, L.EMPTY_BLOCKS, L.TIP_EMPTY_BLOCKS)
    table.insert(emptyButtons, btn)
    btn:SetText(ns.placeHideEmpty and L.EMPTY_BLOCKS_HIDDEN or L.EMPTY_BLOCKS_SHOWN)
    return btn
end
function ns:RefreshPlaceEmptyButtons()
    local text = self.placeHideEmpty and L.EMPTY_BLOCKS_HIDDEN or L.EMPTY_BLOCKS_SHOWN
    for _, btn in ipairs(emptyButtons) do btn:SetText(text) end
end

-- Grid sizes, the same as the General tab's list
local GRID_STEPS = { 0, 8, 16, 32 }
local function GridText(v)
    return v == 0 and L.GRID_OFF or (v .. " px")
end
-- Next (dir 1) or previous (dir -1) grid size, in a loop
function ns:StepGrid(dir)
    local cur, at = self.db.grid or 0, 1
    for i, v in ipairs(GRID_STEPS) do if v == cur then at = i end end
    at = (at - 1 + dir) % #GRID_STEPS + 1
    self.db.grid = GRID_STEPS[at]
    self:UpdateGrid()
    if self.banner and self.banner.gridValue then self.banner.gridValue:SetText(GridText(self.db.grid)) end
    if self.RefreshOptions then self:RefreshOptions() end
end

-- Where the player last dragged the banner (account-wide), else near the top of the screen
local function PlaceBanner(b)
    b:ClearAllPoints()
    local pos = ns.sv.bannerPoint
    if type(pos) == "table" and type(pos[1]) == "string" then
        b:SetPoint(pos[1], UIParent, pos[1], tonumber(pos[2]) or 0, tonumber(pos[3]) or 0)
    else
        b:SetPoint("TOP", UIParent, "TOP", 0, -140)
    end
end

-- Shows or hides the placement banner depending on the lock state (created on first use)
function ns:UpdatePlacementBanner()
    -- (never in DataBroker mode: Tessera shows no block of its own; nor while Blizzard's
    -- Edit Mode unlocked the blocks: its own window is open at the same place)
    local placing = self.db and not self:IsLocked() and not self.brokerModeActive
        and not self.db.unlockedByEditMode and true or false

    -- the options window is tucked away during placement and comes back on lock
    -- (placing to the pixel folds it to its bar instead: StartNudge)
    if placing and not self.placementActive then
        if S.panel and S.panel:IsShown() and not self.nudge then
            S.panel:Hide()
            self.optionsTucked = true
        end
    elseif not placing and self.placementActive then
        if self.optionsTucked and self.db and self.db.locked then
            self.optionsTucked = nil
            if S.panel then
                ns:SkinOptions()
                ns:RefreshOptions()
                S.panel.keepPlace = true
                S.panel:Show()
                S.panel.keepPlace = nil
            end
        end
    end
    self.placementActive = placing
    -- locked while placing to the pixel (the folded window's lock button): the move stays
    if self.nudge and self.db and self.db.locked then
        self.nudge.wasLocked = true
        self:FinishNudge(true)
        return
    end

    -- while the options window is open (it has its own lock button), the banner steps
    -- aside, except while placing to the pixel (the window is folded to its bar)
    local show = placing and (self.nudge or not (S.panel and S.panel:IsShown()))
    if not show then
        if self.banner then self.banner:Hide() end
        return
    end
    local b = self.banner
    if not b then
        b = CreateFrame("Frame", "TesseraPlacementBanner", UIParent, "BackdropTemplate")
        b:SetSize(BANNER_W, BANNER_H)
        -- where the player last dragged it (account-wide), else near the top of the screen
        PlaceBanner(b)
        b:SetFrameStrata("DIALOG")
        b:SetClampedToScreen(true)
        b:EnableMouse(true)
        b:SetMovable(true)
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", b.StartMoving)
        b:SetScript("OnDragStop", function(frame)
            frame:StopMovingOrSizing()
            -- remembered as an offset from the screen center
            local x, y = frame:GetCenter()
            local cx, cy = UIParent:GetCenter()
            local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            ns.sv.bannerPoint = { "CENTER", math.floor(x * k - cx + 0.5), math.floor(y * k - cy + 0.5) }
        end)

        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.text:SetPoint("TOPLEFT", 14, -11)
        b.text:SetText(L.PLACEMENT_TITLE)

        -- every block in front of or behind Blizzard's frames for a while (Layers.lua)
        b.layer = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
        b.layer:SetSize(150, 20)
        b.layer:SetPoint("TOPRIGHT", -12, -8)
        b.layer:SetScript("OnClick", function() ns:ToggleTempLayer() end)
        AttachTip(b.layer, L.LAYER_TOGGLE, L.TIP_LAYER_TOGGLE)

        b.hint = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.hint:SetPoint("TOPLEFT", 14, -30)
        b.hint:SetWidth(BANNER_W - 28)
        b.hint:SetJustifyH("LEFT")
        b.hint:SetText(L.PLACEMENT_HINT)

        -- five buttons in a row: Options, Place, Undo, Reload, Lock
        local buttons = {
            BannerButton(b, L.BANNER_OPTIONS, L.TIP_BANNER_OPTIONS, function()
                ns.optionsTucked = nil
                ns:ToggleOptions()
            end),
            -- the block chosen in the Blocks tab, else the player clicks the block to place
            BannerButton(b, L.PLACE_BLOCK, L.TIP_BANNER_PLACE, function()
                ns:StartNudge(ns:GetOptionsSelection(), true)
            end),
            BannerButton(b, L.UNDO_SHORT, L.TIP_UNDO, function() ns:Undo() end),
            BannerButton(b, L.RELOAD_SHORT, L.TIP_RELOAD, function() ReloadUI() end),
            BannerButton(b, L.LOCK_SHORT, L.TIP_LOCKED, function() ns:SetLocked(true) end),
        }
        local x = 12
        for i, btn in ipairs(buttons) do
            local w = i == 2 and 128 or 88 -- "Place by pixel" is the longest label
            btn:SetWidth(w)
            btn:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", x, 12)
            x = x + w + 6
        end
        buttons[2]:SetNormalFontObject("GameFontNormal")
        b.undo = buttons[3]
        b.buttons = buttons

        -- grid size in two clicks (same setting as the General tab), or G on the keyboard
        b.gridLabel = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.gridLabel:SetPoint("TOPLEFT", 14, -68)
        b.gridLabel:SetText(L.GRID)
        local function GridArrow(texture, dir)
            local btn = CreateFrame("Button", nil, b)
            btn:SetSize(24, 24)
            btn:SetNormalTexture(texture .. "-Up")
            btn:SetPushedTexture(texture .. "-Down")
            btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            btn:SetScript("OnClick", function() ns:StepGrid(dir) end)
            AttachTip(btn, L.GRID, L.TIP_BANNER_GRID)
            return btn
        end
        b.gridPrev = GridArrow("Interface\\Buttons\\UI-SpellbookIcon-PrevPage", -1)
        b.gridPrev:SetPoint("LEFT", b.gridLabel, "RIGHT", 10, 0)
        b.gridValue = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.gridValue:SetWidth(90)
        b.gridValue:SetPoint("LEFT", b.gridPrev, "RIGHT", 4, 0)
        b.gridNext = GridArrow("Interface\\Buttons\\UI-SpellbookIcon-NextPage", 1)
        b.gridNext:SetPoint("LEFT", b.gridValue, "RIGHT", 4, 0)
        -- empty blocks (those set to hide when empty): shown while placing, or hidden as in game
        b.emptyBtn = EmptyBlocksButton(b)
        b.emptyBtn:SetPoint("TOPRIGHT", b, "TOPRIGHT", -12, -66)
        b.gridRow = { b.gridLabel, b.gridPrev, b.gridValue, b.gridNext, b.emptyBtn }
        -- G: next grid size, V: empty blocks (only while the banner shows its own buttons)
        b.OnOwnKey = function(_, key)
            if ns.nudge or IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then return false end
            if key == "G" then
                ns:StepGrid(1)
                return true
            elseif key == "V" then
                ns:SetPlaceHideEmpty(not ns.placeHideEmpty)
                return true
            end
            return false
        end

        -- Ctrl + Z undoes while the banner is shown (see ListenForUndo)
        ListenForUndo(b)
        self.banner = b
    end
    self:SkinWindow(b, b.text)
    b.layer:SetText(self:LayerShown() == "behind" and L.LAYER_BEHIND_STATE or L.LAYER_FRONT_STATE)
    b.gridValue:SetText(GridText(self.db.grid or 0))
    self:ShowNudgePad(b)
    b:Show()
    self:ClearPlacementInfo()
    self:UpdateUndoButton()
end

-- Placing to the pixel ("Place" in the Blocks tab): the banner shows a pad instead of
-- its usual buttons. Arrows (keyboard or pad): 1 pixel, Shift: 10 pixels; held for
-- 0.5 s, the group keeps moving 10 steps a second. Enter or the check button keeps the
-- place, Escape or Cancel puts the group back (ns:FinishNudge). X and Y can be typed.
-- Without a mouse: everything has a key. In combat the game stops frames from reading
-- the keyboard and the blocks' click buttons cannot follow them: placing waits, and the
-- banner says so.
local NUDGE_DELAY, NUDGE_RATE = 0.5, 10
local NUDGE_KEYS = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
local PAD_BUTTON = 30
local NUDGE_NAMES = { UP = L.NUDGE_UP, DOWN = L.NUDGE_DOWN, LEFT = L.NUDGE_LEFT, RIGHT = L.NUDGE_RIGHT }

local function NudgeOnce(dir, big)
    local n = ns.nudge
    if not (n and n.key) then return end
    local step = big and 10 or 1
    ns:NudgeBy(n.key, dir[1] * step, dir[2] * step)
end

local function StopHold(pad, name)
    if pad.hold and (not name or pad.hold.name == name) then
        if pad.arrows[pad.hold.name] then pad.arrows[pad.hold.name]:UnlockHighlight() end
        pad.hold = nil
    end
end

-- Holding an arrow (key or pad button): one step at once, then steps after NUDGE_DELAY
local function StartHold(pad, name, big, fromKey)
    local dir = NUDGE_KEYS[name]
    if not dir then return end
    if pad.hold and pad.hold.name == name then return end -- a key repeat of the same arrow
    StopHold(pad) -- another arrow was held: only the last one moves
    NudgeOnce(dir, big)
    pad.hold = { name = name, dir = dir, big = big, key = fromKey, wait = NUDGE_DELAY, acc = 0 }
    if pad.arrows[name] then pad.arrows[name]:LockHighlight() end
end

local function PadArrow(pad, name, texture, rotation)
    local btn = CreateFrame("Button", nil, pad, "BackdropTemplate")
    btn:SetSize(PAD_BUTTON, PAD_BUTTON)
    btn:SetNormalTexture(texture .. "-Up")
    btn:SetPushedTexture(texture .. "-Down")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    if rotation then
        for _, t in ipairs({ btn:GetNormalTexture(), btn:GetPushedTexture() }) do
            if t and t.SetRotation then t:SetRotation(rotation) end
        end
    end
    -- a pressed button keeps moving, like a held key
    btn:SetScript("OnMouseDown", function() StartHold(pad, name, IsShiftKeyDown()) end)
    btn:SetScript("OnMouseUp", function() StopHold(pad, name) end)
    btn:SetScript("OnHide", function() StopHold(pad, name) end)
    AttachTip(btn, NUDGE_NAMES[name], L.TIP_NUDGE_ARROW)
    pad.arrows[name] = btn
    return btn
end

local function NudgeBox(pad, label)
    local fs = pad:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(label)
    local box = CreateFrame("EditBox", nil, pad, "InputBoxTemplate")
    box:SetSize(64, 22)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(5)
    box:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    local function Apply(self)
        local n = ns.nudge
        local x, y = tonumber(pad.x:GetText()), tonumber(pad.y:GetText())
        if n and n.key and x and y then ns:SetNudgePosition(n.key, x, y) end
        self:ClearFocus()
    end
    box:SetScript("OnEnterPressed", Apply)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function() StopHold(pad) end)
    box:SetScript("OnEditFocusLost", function() pad:Refresh() end)
    box:SetScript("OnTabPressed", function(self)
        Apply(self)
        local other = self == pad.x and pad.y or pad.x
        other:SetFocus()
        other:HighlightText()
    end)
    AttachTip(box, label, L.TIP_NUDGE_XY)
    return fs, box
end

local function BuildNudgePad(b)
    -- (the pad covers the whole banner: a frame without a height draws nothing, test102)
    local pad = CreateFrame("Frame", nil, b)
    pad:SetAllPoints(b)
    pad.arrows = {}
    local W = b:GetWidth() - 28

    pad.title = pad:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pad.title:SetPoint("TOPLEFT", 14, -11)
    pad.title:SetWidth(W)
    pad.title:SetJustifyH("LEFT")

    -- first time only: why the options window folded, and how to open it again
    pad.notice = pad:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pad.notice:SetWidth(W - 96)
    pad.notice:SetJustifyH("LEFT")
    pad.notice:SetText(L.NUDGE_NOTICE)
    pad.gotIt = CreateFrame("Button", nil, pad, "UIPanelButtonTemplate")
    pad.gotIt:SetSize(88, 22)
    pad.gotIt:SetText(L.NUDGE_GOT_IT)
    pad.gotIt:SetPoint("TOPLEFT", pad.notice, "TOPRIGHT", 8, 0)
    pad.gotIt:SetScript("OnClick", function()
        ns.sv.placeNoticeSeen = true
        pad:Refresh()
    end)
    AttachTip(pad.gotIt, L.NUDGE_GOT_IT, L.TIP_NUDGE_GOT_IT)

    pad.groupNote = pad:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pad.groupNote:SetWidth(W)
    pad.groupNote:SetJustifyH("LEFT")
    pad.groupNote:SetText(L.NUDGE_GROUP_NOTE)

    -- the pad: four arrows around the check button
    pad.cross = CreateFrame("Frame", nil, pad)
    pad.cross:SetSize(PAD_BUTTON * 3 + 4, PAD_BUTTON * 3 + 4)
    local up = PadArrow(pad, "UP", "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp")
    local down = PadArrow(pad, "DOWN", "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown")
    local left = PadArrow(pad, "LEFT", "Interface\\Buttons\\UI-SpellbookIcon-PrevPage")
    local right = PadArrow(pad, "RIGHT", "Interface\\Buttons\\UI-SpellbookIcon-NextPage")
    pad.done = CreateFrame("Button", nil, pad, "UIPanelButtonTemplate")
    pad.done:SetSize(PAD_BUTTON, PAD_BUTTON)
    pad.done.check = pad.done:CreateTexture(nil, "OVERLAY")
    pad.done.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    pad.done.check:SetPoint("CENTER")
    pad.done.check:SetSize(PAD_BUTTON - 4, PAD_BUTTON - 4)
    pad.done:SetScript("OnClick", function() ns:FinishNudge(true) end)
    AttachTip(pad.done, L.NUDGE_DONE, L.TIP_NUDGE_DONE)
    pad.done:SetPoint("CENTER", pad.cross, "CENTER")
    up:SetPoint("BOTTOM", pad.done, "TOP", 0, 2)
    down:SetPoint("TOP", pad.done, "BOTTOM", 0, -2)
    left:SetPoint("RIGHT", pad.done, "LEFT", -2, 0)
    right:SetPoint("LEFT", pad.done, "RIGHT", 2, 0)

    -- X and Y, then Cancel, right of the pad
    pad.xLabel, pad.x = NudgeBox(pad, L.NUDGE_X)
    pad.yLabel, pad.y = NudgeBox(pad, L.NUDGE_Y)
    pad.xLabel:SetPoint("TOPLEFT", pad.cross, "TOPRIGHT", 20, -10)
    pad.yLabel:SetPoint("TOPLEFT", pad.xLabel, "BOTTOMLEFT", 0, -16)
    pad.cancel = CreateFrame("Button", nil, pad, "UIPanelButtonTemplate")
    pad.cancel:SetSize(120, 22)
    pad.cancel:SetText(L.NUDGE_CANCEL)
    -- "Keep" in words too, beside "Cancel" (the check of the pad says the same)
    pad.keep = CreateFrame("Button", nil, pad, "UIPanelButtonTemplate")
    pad.keep:SetSize(120, 22)
    pad.keep:SetText(L.NUDGE_DONE)
    pad.keep:SetNormalFontObject("GameFontNormal")
    pad.keep:SetPoint("TOPLEFT", pad.yLabel, "BOTTOMLEFT", 0, -14)
    pad.keep:SetScript("OnClick", function() ns:FinishNudge(true) end)
    AttachTip(pad.keep, L.NUDGE_DONE, L.TIP_NUDGE_DONE)
    -- the same "Empty blocks" button as the banner's, right of the X box
    pad.empty = EmptyBlocksButton(pad)
    pad.empty:SetPoint("LEFT", pad.x, "RIGHT", 24, 0)
    pad.cancel:SetPoint("LEFT", pad.keep, "RIGHT", 6, 0)
    pad.cancel:SetScript("OnClick", function() ns:FinishNudge(false) end)
    AttachTip(pad.cancel, L.NUDGE_CANCEL, L.TIP_NUDGE_CANCEL)

    pad.hint = pad:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pad.hint:SetWidth(W)
    pad.hint:SetJustifyH("LEFT")
    pad.hint:SetText(L.NUDGE_HINT)
    pad.combat = pad:CreateFontString(nil, "OVERLAY", "GameFontRed")
    pad.combat:SetWidth(W)
    pad.combat:SetJustifyH("LEFT")
    pad.combat:SetText(L.NUDGE_COMBAT)

    -- texts above and below the pad: each one takes the height of its text
    -- (bigger text, Shift + mouse wheel), and the banner grows with them
    pad.Refresh = function(self)
        local n = ns.nudge
        if not n then return end
        local key = n.key
        local alone = true
        if key then
            local group = ns:GetSubtree(ns:GetRoot(key))
            alone = next(group, next(group)) == nil
            self.title:SetFormattedText(alone and L.NUDGE_TITLE or L.NUDGE_TITLE_GROUP, ns:GetBlockName(key))
        else
            self.title:SetText(L.NUDGE_PICK) -- started from the banner with no block chosen
        end
        local y = -11 - self.title:GetStringHeight() - 8
        local noticeOn = not ns.sv.placeNoticeSeen and n.fromWindow -- (about the folded window)
        self.notice:SetShown(noticeOn)
        self.gotIt:SetShown(noticeOn)
        if noticeOn then
            self.notice:ClearAllPoints()
            self.notice:SetPoint("TOPLEFT", 14, y)
            y = y - math.max(self.notice:GetStringHeight(), 22) - 8
        end
        self.groupNote:SetShown(not alone)
        if not alone then
            self.groupNote:ClearAllPoints()
            self.groupNote:SetPoint("TOPLEFT", 14, y)
            y = y - self.groupNote:GetStringHeight() - 6
        end
        self.cross:ClearAllPoints()
        self.cross:SetPoint("TOPLEFT", 14, y)
        y = y - self.cross:GetHeight() - 6
        self.hint:ClearAllPoints()
        self.hint:SetPoint("TOPLEFT", 14, y)
        y = y - self.hint:GetStringHeight() - 4
        local fight = InCombatLockdown()
        self.combat:SetShown(fight)
        for _, btn in pairs(self.arrows) do btn:SetEnabled(not fight) end
        if fight then StopHold(self) end
        if fight then
            self.combat:ClearAllPoints()
            self.combat:SetPoint("TOPLEFT", 14, y)
            y = y - self.combat:GetStringHeight() - 4
        end
        b:SetHeight(math.floor(-y + 10))
        -- X and Y follow the group (a mouse drag too), except a box being typed in
        local px, py
        if key then px, py = ns:GetNudgePosition(key) end
        if not self.x:HasFocus() then self.x:SetText(px and tostring(px) or "") end
        if not self.y:HasFocus() then self.y:SetText(py and tostring(py) or "") end
    end

    -- held arrow, and X / Y kept up to date (10 times a second)
    local tick = 0
    pad:SetScript("OnUpdate", function(self, elapsed)
        local h = self.hold
        -- a key let go where the banner cannot hear it (a text box, another window)
        if h and h.key and IsKeyDown and not IsKeyDown(h.name) then
            StopHold(self)
            h = nil
        end
        if h then
            if h.wait > 0 then
                h.wait = h.wait - elapsed
            else
                h.acc = h.acc + elapsed
                while h.acc >= 1 / NUDGE_RATE do
                    h.acc = h.acc - 1 / NUDGE_RATE
                    NudgeOnce(h.dir, h.big)
                end
            end
        end
        tick = tick + elapsed
        if tick >= 0.1 then
            tick = 0
            self:Refresh()
        end
    end)
    pad:SetScript("OnHide", function(self) StopHold(self) end)

    -- keys of the banner while placing (ListenForUndo calls these); otherwise the
    -- banner's own keys (G: grid)
    local ownKey = b.OnOwnKey
    b.OnOwnKey = function(self, key)
        if not ns.nudge then return ownKey and ownKey(self, key) or false end
        if NUDGE_KEYS[key] then
            StartHold(pad, key, IsShiftKeyDown(), true)
            return true
        elseif key == "V" and not IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown() then
            ns:SetPlaceHideEmpty(not ns.placeHideEmpty)
            return true
        elseif key == "ENTER" then
            ns:FinishNudge(true)
            return true
        elseif key == "ESCAPE" then
            ns:FinishNudge(false)
            return true
        end
        return false
    end
    b.OnOwnKeyUp = function(_, key)
        if NUDGE_KEYS[key] then StopHold(pad, key) end
    end
    -- the folded options window may hear the keys first: it passes them on the same way
    if S.panel then
        S.panel.OnOwnKey = function(_, key) return ns.nudge and b:OnOwnKey(key) or false end
        S.panel.OnOwnKeyUp = b.OnOwnKeyUp
    end
    b.pad = pad
    return pad
end

-- Banner content: the usual buttons, or the pad while placing to the pixel
function ns:ShowNudgePad(b)
    local on = self.nudge ~= nil
    if on and not b.pad then BuildNudgePad(b) end
    b.text:SetShown(not on)
    b.layer:SetShown(not on)
    b.hint:SetShown(not on)
    for _, btn in ipairs(b.buttons) do btn:SetShown(not on) end
    if b.pad then
        b.pad:SetShown(on)
        if on then
            b.pad:Refresh()
            self:SkinWindow(b, b.pad.title)
        end
    end
    -- while placing, the banner sits right under the folded options window (it was behind
    -- its bar, test102); back to its own place afterwards
    local panelShown = S.panel and S.panel:IsShown()
    if on and panelShown and not b.underPanel then
        b:ClearAllPoints()
        b:SetPoint("TOP", S.panel, "BOTTOM", 0, -8)
        b.underPanel = true
    elseif not on and b.underPanel then
        PlaceBanner(b)
        b.underPanel = nil
    end
    for _, w in ipairs(b.gridRow) do w:SetShown(not on) end
    if not on then b:SetHeight(BANNER_H) end
end

-- Placement mode: what can be done with the hovered block, in a panel stuck to the
-- banner (above it when the banner is low on the screen) rather than in a tooltip
-- next to the block, where it covered the block's cross and arrows. Dragging the
-- panel moves the banner with it. When nothing is hovered, it says so in one line.
-- Returns false when the banner is not shown (the caller then uses a tooltip).
local function HintLine(text)
    -- "Drag: move the block" -> the gesture in gold, then what it does
    local gesture, rest = text:match("^(.-)%s?:%s(.*)$")
    if not gesture then return text end
    return "|cffffd100" .. gesture .. "|r   " .. rest
end

function ns:ShowPlacementInfo(lines, title)
    local b = self.banner
    if not (b and b:IsShown()) then return false end
    local info = b.info
    if not info then
        info = CreateFrame("Frame", nil, b, "BackdropTemplate")
        info:SetWidth(b:GetWidth())
        info:EnableMouse(true)
        info:RegisterForDrag("LeftButton")
        info:SetScript("OnDragStart", function() b:StartMoving() end)
        info:SetScript("OnDragStop", function() b:GetScript("OnDragStop")(b) end)
        info.title = info:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        info.title:SetPoint("TOPLEFT", 14, -10)
        info.title:SetWidth(b:GetWidth() - 28)
        info.title:SetJustifyH("LEFT")
        info.text = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        info.text:SetWidth(b:GetWidth() - 28)
        info.text:SetJustifyH("LEFT")
        info.text:SetSpacing(3)
        b.info = info
    end
    self:SkinWindow(info, info.title)
    info.title:SetText(title or "")
    info.title:SetShown(title ~= nil)
    info.text:ClearAllPoints()
    if title then
        info.text:SetPoint("TOPLEFT", info.title, "BOTTOMLEFT", 0, -6)
    else
        info.text:SetPoint("TOPLEFT", 14, -10)
    end
    local out = {}
    for i, line in ipairs(lines) do out[i] = HintLine(line) end
    info.text:SetText(table.concat(out, "\n"))
    info:SetHeight(20 + (title and (info.title:GetStringHeight() + 6) or 0) + info.text:GetStringHeight())
    -- below the banner, or above it when the banner is in the lower half of the screen
    info:ClearAllPoints()
    local _, y = b:GetCenter()
    if y and y < UIParent:GetHeight() / 2 then
        info:SetPoint("BOTTOM", b, "TOP", 0, 4)
    else
        info:SetPoint("TOP", b, "BOTTOM", 0, -4)
    end
    info:Show()
    return true
end

-- Back to "hover a block" when the mouse leaves the block
function ns:ClearPlacementInfo()
    if self.banner and self.banner:IsShown() then
        self:ShowPlacementInfo({ L.PLACEMENT_INFO_IDLE })
    end
end

-- The banner's Undo button is only clickable when there is something to undo
function ns:UpdateUndoButton()
    if self.banner and self.banner.undo then
        self.banner.undo:SetEnabled(self:CanUndo())
    end
end
