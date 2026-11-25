local _, ns = ...
local L = ns.L

-- ========================================================================
-- VolumeList.lua: the clickable volume list of the Volume block, and its presets
-- ========================================================================
-- Shown under the mouse, in place of the tooltip, when the Volume block's "Hover shows" setting is
-- "List". It sets the game's own sound settings (nothing is recoded): every channel can be set with
-- a click on its bar or the mouse wheel, one row mutes or restores all sound, and up to four presets
-- (named by the player) store the five volumes and the muted state.
-- Presets live in the account-wide saved variables (TesseraDB.volumePresets), not in the profiles:
-- the sound settings are the game's, the same for every character.
-- Everything here can also be done from the block's options (no mouse over the block needed).

local CHANNELS = {
    { cvar = "Sound_MasterVolume", key = "TT_MASTER" },
    { cvar = "Sound_MusicVolume", key = "TT_MUSIC" },
    { cvar = "Sound_SFXVolume", key = "TT_EFFECTS" },
    { cvar = "Sound_AmbienceVolume", key = "TT_AMBIENCE" },
    { cvar = "Sound_DialogVolume", key = "TT_DIALOG" },
}
local MAX_PRESETS, NAME_MAX = 4, 14
local AWAY = 0.3 -- seconds the mouse may stay off the block and the list before the list closes

---------------------------------------------------------------------------
-- Presets (saved variables: TesseraDB.volumePresets[1..4] = { name, vol = {5 numbers}, muted })
---------------------------------------------------------------------------
local P = {}
ns.VolumePresets = P
P.MAX, P.NAME_MAX = MAX_PRESETS, NAME_MAX

local function CVarNumber(name)
    local ok, v = pcall(GetCVar, name)
    return ok and tonumber(v) or 0
end

-- volumes move in steps of 5 %, like the block's mouse wheel
local function Snap(v)
    return math.max(0, math.min(1, math.floor(v * 20 + 0.5) / 20))
end

-- The sound output devices, as the game's own sound options list them (indexes 0 to count - 1, chosen
-- through the Sound_OutputDriverIndex setting). WoW Forever's functions are read through _G.
local function Devices()
    local out = {}
    local count, nameAt = _G["Sound_GameSystem_GetNumOutputDrivers"], _G["Sound_GameSystem_GetOutputDriverNameByIndex"]
    if type(count) ~= "function" or type(nameAt) ~= "function" then return out end
    local ok, n = pcall(count)
    if not ok or type(n) ~= "number" then return out end
    for i = 0, n - 1 do
        local okName, name = pcall(nameAt, i)
        if okName and type(name) == "string" then out[#out + 1] = { index = i, name = name } end
    end
    return out
end

local function DeviceName(list, index)
    for _, d in ipairs(list) do
        if d.index == index then return d.name end
    end
    return nil
end

-- the output device in use: its index and name (nil when the game lists none)
local function CurrentDevice()
    local list = Devices()
    local ok, v = pcall(GetCVar, "Sound_OutputDriverIndex")
    local index = ok and tonumber(v) or nil
    return index, index and DeviceName(list, index) or nil
end

local function SetDevice(index)
    SetCVar("Sound_OutputDriverIndex", tostring(index))
end

local function IsMuted()
    local ok, v = pcall(GetCVar, "Sound_EnableAllSound")
    return ok and v == "0"
end

-- A name the player typed: trimmed and cut to NAME_MAX characters (not bytes: accents stay whole)
local function Clip(name)
    name = strtrim(tostring(name or ""))
    local out, n = {}, 0
    for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        n = n + 1
        if n > NAME_MAX then break end
        out[n] = ch
    end
    return table.concat(out)
end

-- Shown names keep a "|" from being read as a color or texture code
local function Plain(name)
    return (tostring(name or ""):gsub("|", "||"))
end

function P.DefaultName(i)
    return L.VOLUME_PRESET_DEFAULT:format(i)
end

function P.Get(i)
    local store = ns.sv and ns.sv.volumePresets
    local p = store and store[i]
    if type(p) == "table" and type(p.vol) == "table" then return p end
    return nil
end

function P.Count()
    local n = 0
    for i = 1, MAX_PRESETS do
        if P.Get(i) then n = n + 1 end
    end
    return n
end

function P.FreeSlot()
    for i = 1, MAX_PRESETS do
        if not P.Get(i) then return i end
    end
    return nil
end

-- Stores the five volumes and the muted state in slot i; `name` is optional (the old name stays,
-- or "Preset i" for a new slot)
function P.Save(i, name)
    if not ns.sv or type(i) ~= "number" or i < 1 or i > MAX_PRESETS then return end
    local old = P.Get(i)
    local vol = {}
    for k, c in ipairs(CHANNELS) do vol[k] = Snap(CVarNumber(c.cvar)) end
    local clipped = name and Clip(name) or ""
    if clipped == "" then clipped = old and old.name or P.DefaultName(i) end
    ns.sv.volumePresets = ns.sv.volumePresets or {}
    local _, device = CurrentDevice()
    ns.sv.volumePresets[i] = { name = clipped, vol = vol, muted = IsMuted(), device = device }
end

function P.Rename(i, name)
    local p = P.Get(i)
    if not p then return end
    local clipped = Clip(name)
    p.name = clipped ~= "" and clipped or P.DefaultName(i)
end

function P.Delete(i)
    local store = ns.sv and ns.sv.volumePresets
    if not store then return end
    store[i] = nil
    if next(store) == nil then ns.sv.volumePresets = nil end
end

-- Puts the preset's volumes and muted state into the game's sound settings
function P.Apply(i)
    local p = P.Get(i)
    if not p then return end
    for k, c in ipairs(CHANNELS) do
        local v = tonumber(p.vol[k])
        if v then SetCVar(c.cvar, tostring(Snap(v))) end
    end
    SetCVar("Sound_EnableAllSound", p.muted and "0" or "1")
    -- the output device too, when the preset kept one that is still there and is not the one in use
    if type(p.device) == "string" then
        local _, now = CurrentDevice()
        if now ~= p.device then
            for _, d in ipairs(Devices()) do
                if d.name == p.device then SetDevice(d.index) break end
            end
        end
    end
    if ns.UpdateBlock then ns:UpdateBlock("volume") end
end

-- Applies the next preset after the one in use (the first when none matches); returns its slot,
-- or nil when no preset is saved
function P.Next()
    local current = 0
    for i = 1, MAX_PRESETS do
        if P.Matches(i) then current = i break end
    end
    for step = 1, MAX_PRESETS do
        local i = ((current - 1 + step) % MAX_PRESETS) + 1
        if P.Get(i) then
            P.Apply(i)
            return i
        end
    end
    return nil
end

-- true when the game's sound settings are exactly this preset's
function P.Matches(i)
    local p = P.Get(i)
    if not p then return false end
    if (p.muted and true or false) ~= IsMuted() then return false end
    if type(p.device) == "string" then
        local _, now = CurrentDevice()
        if now ~= nil and now ~= p.device and DeviceName(Devices(), 0) ~= nil then
            -- a device that is gone does not stop a preset from matching
            for _, dv in ipairs(Devices()) do
                if dv.name == p.device then return false end
            end
        end
    end
    for k, c in ipairs(CHANNELS) do
        if math.abs((tonumber(p.vol[k]) or 0) - CVarNumber(c.cvar)) > 0.01 then return false end
    end
    return true
end

---------------------------------------------------------------------------
-- The list under the mouse
---------------------------------------------------------------------------
local list, owner, cfgNow
local away = 0
local rows, btns = {}, {} -- channel rows and buttons (made once, then reused)

local function Metrics()
    local font = _G["GameTooltipText"] or _G["GameFontHighlight"]
    local _, height
    if font then _, height = font:GetFont() end
    local k = math.max(1, (height or 12) / 12)
    return { row = math.max(22, math.floor((height or 12) * 1.7)), k = k, check = math.floor(16 * k) }
end

local function SetChannel(cvar, v)
    SetCVar(cvar, tostring(Snap(v)))
end

-- where the mouse is along a bar, 0 to 1
local function CursorFraction(bar)
    local x = GetCursorPosition()
    local scale = bar:GetEffectiveScale()
    local left, width = bar:GetLeft(), bar:GetWidth()
    if not (x and scale and scale > 0 and left and width and width > 0) then return nil end
    return math.max(0, math.min(1, (x / scale - left) / width))
end

local Refresh

-- Puts the name box over a preset's button; the button's own text steps aside (the box has no background)
local function StartRename(slot)
    local p = P.Get(slot)
    if not (p and list) then return end
    for _, b in ipairs(btns) do
        if b:IsShown() and b.item and b.item.kind == "preset" and b.item.slot == slot then
            local box = list.rename
            box.slot = slot
            b:SetText("")
            b.check:Hide()
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -1)
            box:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 1)
            box:SetText(p.name)
            box:Show()
            box:SetFocus()
            box:HighlightText()
            return
        end
    end
end

local function PresetMenu(button)
    local item = button.item
    if not item or item.kind ~= "preset" or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    local slot = item.slot
    -- the menu opens in a lower strata than the list: the list steps back so the menu stays visible
    list:SetFrameStrata("DIALOG")
    MenuUtil.CreateContextMenu(button, function(_, root)
        root:CreateTitle(Plain(item.name))
        root:CreateButton(L.VOLUMELIST_RENAME, function() StartRename(slot) end)
        root:CreateButton(L.VOLUMELIST_OVERWRITE, function()
            P.Save(slot)
            Refresh()
        end)
        root:CreateButton(L.VOLUMELIST_DELETE, function()
            P.Delete(slot)
            Refresh()
        end)
    end)
end

-- the choice of output device: a menu with the devices the game lists, the one in use ticked
local function DeviceMenu(button)
    if not MenuUtil or not MenuUtil.CreateContextMenu then return end
    list:SetFrameStrata("DIALOG")
    MenuUtil.CreateContextMenu(button, function(_, root)
        root:CreateTitle(L.VOLUMELIST_DEVICE)
        for _, d in ipairs(Devices()) do
            local index = d.index
            root:CreateRadio(Plain(d.name), function() return (CurrentDevice()) == index end,
                function()
                    SetDevice(index)
                    Refresh()
                end)
        end
    end)
end

local function ButtonClick(button, mouse)
    local item = button.item
    if not item then return end
    if item.kind == "preset" then
        if mouse == "RightButton" or IsShiftKeyDown() then
            PresetMenu(button)
        else
            P.Apply(item.slot)
            Refresh()
        end
    elseif item.kind == "save" then
        local slot = P.FreeSlot()
        if not slot then return end
        P.Save(slot)
        Refresh()
        StartRename(slot) -- the new preset's name is asked right away
    elseif item.kind == "mute" then
        SetCVar("Sound_EnableAllSound", IsMuted() and "1" or "0")
        Refresh()
    elseif item.kind == "device" then
        DeviceMenu(button)
    end
end

local function RowClick(row)
    local item = row.item
    if not item or item.kind ~= "channel" then return end
    local f = CursorFraction(row.track)
    if f then
        SetChannel(item.cvar, f)
        Refresh()
    end
end

local function RowWheel(row, delta)
    local item = row.item
    if not item or item.kind ~= "channel" then return end
    SetChannel(item.cvar, CVarNumber(item.cvar) + (delta > 0 and 0.05 or -0.05))
    Refresh()
end

-- A button of the list (preset, save, mute, device): the game's own button look
local function MakeButton(i)
    local b = CreateFrame("Button", nil, list, "UIPanelButtonTemplate")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", ButtonClick)
    -- the check mark: the preset or state in use (a shape, not only a color)
    b.check = b:CreateTexture(nil, "OVERLAY")
    b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    b.check:SetPoint("LEFT", 4, 0)
    btns[i] = b
    return b
end

-- One channel: its name, a bar (click to set) and its value
local function MakeRow(i)
    local row = CreateFrame("Button", nil, list)
    row:RegisterForClicks("LeftButtonUp")
    row:EnableMouseWheel(true)
    row:SetScript("OnClick", RowClick)
    row:SetScript("OnMouseWheel", RowWheel)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.12)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.track = row:CreateTexture(nil, "BACKGROUND")
    row.track:SetColorTexture(1, 1, 1, 0.12)
    row.fill = row:CreateTexture(nil, "ARTWORK")
    row.fill:SetColorTexture(0.35, 0.65, 1, 0.9)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    row.value:SetJustifyH("RIGHT")
    rows[i] = row
    return row
end

local function HintText()
    return ns:ListHintText({ L.VOLUMELIST_ROW_APPLY, L.VOLUMELIST_ROW_BAR, L.VOLUMELIST_ROW_MENU },
        owner and owner.key, cfgNow)
end

-- Places a button at (x, y) with a width, and says what it shows
local function PlaceButton(n, item, x, y, w, h, text, checked)
    local b = btns[n] or MakeButton(n)
    b.item = item
    b:SetSize(w, h)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", x, -y)
    b:SetText(text)
    if ns.FitButtonText then ns.FitButtonText(b) end
    b.check:SetSize(math.max(12, h - 8), math.max(12, h - 8))
    b.check:SetShown(checked and true or false)
    if checked then b:LockHighlight() else b:UnlockHighlight() end
    b:Show()
end

-- Draws the list: the buttons and channels it needs, their texts, bars and size
function Refresh()
    if not list then return end
    local m = Metrics()
    local width = math.floor(300 * m.k)
    local inner = width - 16
    local gap = 6
    local labelW = math.floor(96 * m.k)
    local valueW = math.floor(44 * m.k)
    local muted = IsMuted()
    local btnH = m.row + 2
    for _, b in ipairs(btns) do
        b.item = nil
        b:Hide()
    end
    for _, r in ipairs(rows) do
        r.item = nil
        r:Hide()
    end
    local y = 8 + m.row + 4 -- the title
    local nb = 0
    -- the presets, two to a line
    local half = math.floor((inner - gap) / 2)
    local shownPresets = 0
    for i = 1, MAX_PRESETS do
        local p = P.Get(i)
        if p then
            nb = nb + 1
            local col = shownPresets % 2
            PlaceButton(nb, { kind = "preset", slot = i, name = p.name }, 8 + col * (half + gap), y, half, btnH,
                Plain(p.name), P.Matches(i))
            shownPresets = shownPresets + 1
            if col == 1 then y = y + btnH + gap end
        end
    end
    if shownPresets % 2 == 1 then y = y + btnH + gap end
    if P.FreeSlot() then
        nb = nb + 1
        PlaceButton(nb, { kind = "save" }, 8, y, inner, btnH, L.VOLUMELIST_SAVE, false)
        y = y + btnH + gap
    end
    nb = nb + 1
    PlaceButton(nb, { kind = "mute" }, 8, y, inner, btnH, muted and L.VOLUMELIST_UNMUTE or L.VOLUMELIST_MUTE, muted)
    y = y + btnH + gap
    -- the output device: only when the game lists more than one
    local devices = Devices()
    if #devices > 1 then
        local _, name = CurrentDevice()
        nb = nb + 1
        PlaceButton(nb, { kind = "device" }, 8, y, inner, btnH, L.VOLUMELIST_DEVICE_NOW:format(Plain(name or "?")), false)
        y = y + btnH + gap
    end
    y = y + 2
    for k, c in ipairs(CHANNELS) do
        local row = rows[k] or MakeRow(k)
        local v = CVarNumber(c.cvar)
        row.item = { kind = "channel", index = k, cvar = c.cvar }
        row:SetSize(inner, m.row)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 8, -y)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", 4, 0)
        row.label:SetWidth(labelW)
        row.label:SetText(L[c.key])
        row.label:SetTextColor(muted and 0.6 or 1, muted and 0.6 or 1, muted and 0.6 or 1)
        row.value:ClearAllPoints()
        row.value:SetPoint("RIGHT", -4, 0)
        row.value:SetWidth(valueW)
        row.value:SetText(("%d%%"):format(math.floor(v * 100 + 0.5)))
        row.track:ClearAllPoints()
        row.track:SetPoint("LEFT", row.label, "RIGHT", 4, 0)
        row.track:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
        row.track:SetHeight(math.max(6, math.floor(m.row / 3)))
        row.fill:ClearAllPoints()
        row.fill:SetPoint("TOPLEFT", row.track, "TOPLEFT")
        row.fill:SetPoint("BOTTOMLEFT", row.track, "BOTTOMLEFT")
        local trackW = row.track:GetWidth() or 0
        row.fill:SetWidth(math.max(1, trackW * math.max(0, math.min(1, v))))
        row.fill:SetShown(v > 0)
        row:Show()
        y = y + m.row
    end
    local hintText = HintText()
    list.hint:SetWidth(width - 20)
    list.hint:SetText(hintText)
    local hintH = hintText ~= "" and ((list.hint:GetStringHeight() or 0) + 8) or 0
    list.hint:ClearAllPoints()
    list.hint:SetPoint("BOTTOMLEFT", 10, 6)
    list:SetSize(width, y + 8 + hintH)
    list.title:SetText(L.VOLUME)
end

local function Build()
    if list then return list end
    list = CreateFrame("Frame", "TesseraVolumeList", UIParent, "BackdropTemplate")
    list:SetFrameStrata("TOOLTIP") -- the highest strata, over every window and bar
    list:SetClampedToScreen(true)
    list:EnableMouse(true)
    list.title = list:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
    list.title:SetPoint("TOPLEFT", 10, -10)
    list.title:SetPoint("RIGHT", -10, 0)
    list.title:SetJustifyH("LEFT")
    list.hint = list:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    list.hint:SetJustifyH("LEFT")
    list.hint:SetTextColor(0.5, 0.8, 1)

    -- the name of a preset, typed in place of its row (Enter keeps it, Escape leaves it as it was)
    local box = CreateFrame("EditBox", nil, list, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetMaxLetters(NAME_MAX)
    box:Hide()
    box:SetScript("OnEnterPressed", function(self)
        if self.slot then P.Rename(self.slot, self:GetText()) end
        self.slot = nil
        self:ClearFocus()
        self:Hide()
        Refresh()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self.slot = nil
        self:ClearFocus()
        self:Hide()
        Refresh()
    end)
    list.rename = box

    list:SetScript("OnShow", function(self)
        self:RegisterEvent("CVAR_UPDATE")
        away = 0
    end)
    -- closes a moment after the mouse leaves the block and the list (it stays while a name is typed)
    list:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() or (owner and owner:IsMouseOver()) or self.rename:HasFocus() or ns.dragging then
            away = 0
        else
            away = away + elapsed
            if away >= AWAY then self:Hide() end
        end
    end)
    list:SetScript("OnHide", function(self)
        self:UnregisterAllEvents()
        self.rename.slot = nil
        self.rename:ClearFocus()
        self.rename:Hide()
    end)
    -- the game's sound settings changed (the wheel on the block, the game's own window): redraw
    list:SetScript("OnEvent", function() Refresh() end)
    list:Hide()
    -- closes with Escape, like Blizzard's menus
    table.insert(UISpecialFrames, "TesseraVolumeList")
    return list
end

function ns:ShowVolumeList(block, cfg)
    Build()
    owner = block or UIParent
    if list:IsShown() then away = 0 return end
    list:SetFrameStrata("TOOLTIP")
    cfgNow = cfg
    -- the game's own tooltip look (or the look another addon gives it)
    ns.ApplyListLook(list, false)
    -- after the look, which can set the scale: the tooltip size setting (General tab) sizes the list
    list:SetScale((ns.db and ns.db.tooltipScale) or 1)
    Refresh()
    ns.PlaceHoverList(list, owner) -- the tooltip's own side and alignment settings
    list:Show()
end

-- the options window opens: the list closes (no window over another)
function ns:HideVolumeList()
    if list and list:IsShown() then list:Hide() end
end

-- another block is hovered: this list closes, unless it belongs to that block
table.insert(ns.hoverListHiders, function(except)
    if list and list:IsShown() and owner ~= except then list:Hide() end
end)
