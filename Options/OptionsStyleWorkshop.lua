local _, ns = ...
local L = ns.L

-- The style gallery's workshop (27/11, Braincell1980): a column on the right of the gallery
-- with the rows of the Style box (ns.LOOK_ROWS: font, text size, corners, icons, effects).
-- Each change shows at once on every thumbnail; nothing is saved before a button at the bottom
-- of the gallery. The column shows what the marked style offers (its font, its effects), except
-- what the player changed here; the style the gallery opened on shows the blocks' own
-- settings. A field no style sets (text size, corners, icons) shows the blocks' value.
-- Keyboard and gamepad: Up / Down pick a row, Enter or A takes it, then Left / Right change the
-- value and Enter, A or B let it go; a check box flips at once. Left, or Down past the last
-- row, leaves the column. High contrast: plain black, white edge (Skin.Box); a text twice as
-- big makes the column scroll.
local Tools = ns.OptionsTools
local Skin = ns.Skin
local AttachTip = Tools.AttachTip

local W = {}
ns.StyleWorkshop = W

local MEDIA = Skin.MEDIA
local KEEP = {} -- the style does not set this field: the blocks keep their value
local side, scroll, content, title, hint
local rows, visible = {}, {}
local touched, proposals, ctx = {}, {}, {}
local focusRow, taken = 1, false

-- A white drawing of Media/Skin stretched by its edges (the focus ring)
local function Sliced(f, layer, file, margin)
    local t = f:CreateTexture(nil, layer)
    t:SetTexture(MEDIA .. file)
    if t.SetTextureSliceMargins then
        t:SetTextureSliceMargins(margin, margin, margin, margin)
        if t.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
            t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        end
    end
    t:SetAllPoints(f)
    return t
end

-- What a style writes into the look fields (KEEP where it writes nothing), once per style
local function Proposal(style)
    local p = style and proposals[style]
    if p then return p end
    p = {}
    local cfg = ns:GetBlockDefaults("gold")
    for _, spec in ipairs(ns.LOOK_ROWS) do cfg[spec.field] = KEEP end
    if style and pcall(ns.ApplyThemeToCfg, ns, cfg, style) then
        for _, spec in ipairs(ns.LOOK_ROWS) do p[spec.field] = cfg[spec.field] end
    end
    if style then proposals[style] = p end
    return p
end

-- The blocks' own value (nil: they differ; first = the first block's value then)
local function Current(field, first)
    if not ctx.lookNow then return nil end
    return ctx.lookNow(field, first)
end

-- The value a thumbnail shows before the player changes it
local function Base(field, cardKey, style, first)
    if cardKey ~= ctx.openKey then
        local v = Proposal(style)[field]
        if v ~= KEEP and v ~= nil then return v end
    end
    return Current(field, first)
end

-- The value of a field for a thumbnail (cardKey: its key, "auto" included; style: what it draws)
function W.Value(field, cardKey, style, first)
    local v = touched[field]
    if v ~= nil then return v end
    return Base(field, cardKey, style, first)
end

-- Writes the workshop's values into the settings of a thumbnail
function W.ApplyToCfg(cfg, cardKey, style)
    if not W.active then return end
    for _, spec in ipairs(ns.LOOK_ROWS) do
        local v = W.Value(spec.field, cardKey, style, true)
        if v ~= nil then cfg[spec.field] = v end
    end
end

local function Chosen()
    if ctx.chosen then return ctx.chosen() end
end
local function Display(field, first)
    local key, style = Chosen()
    return W.Value(field, key, style, first)
end

-- The settings of the marked thumbnail (Corners only shows with a rounded border)
local function ChosenCfg()
    local key, style = Chosen()
    local cfg = ns:GetBlockDefaults("gold")
    if style then pcall(ns.ApplyThemeToCfg, ns, cfg, style) end
    W.ApplyToCfg(cfg, key, style)
    return cfg
end
local function RowShown(spec, cfg)
    return not spec.shownOne or spec.shownOne(cfg) and true or false
end

-- What the buttons write: a list of { field, value, look, spacers }, or nil when nothing changed
-- (a hidden row is left out: the player cannot see it)
function W.Changes()
    if not W.active then return nil end
    local key, style = Chosen()
    local cfg = ChosenCfg()
    local list
    for _, spec in ipairs(ns.LOOK_ROWS) do
        local v = touched[spec.field]
        if v ~= nil and RowShown(spec, cfg) and v ~= Base(spec.field, key, style) then
            list = list or {}
            list[#list + 1] = { field = spec.field, value = v, look = spec.look, spacers = spec.look == true }
        end
    end
    return list
end
function W.OpenKey() return ctx.openKey end

-- Once a button wrote everything: the column starts again from the blocks
function W.Applied(key)
    touched, proposals = {}, {}
    ctx.openKey = key
    taken = false
end

local function Set(field, v)
    if v == "mixed" then v = nil end
    touched[field] = v
    if ctx.redraw then ctx.redraw() end
end

-- The choices of a list row; "Mixed" first while the blocks differ and nothing is picked
local function Choices(spec)
    local list = {}
    if Display(spec.field) == nil then list[1] = { key = "mixed", name = L.FONT_MIXED } end
    for _, item in ipairs(spec.choices()) do list[#list + 1] = item end
    return list
end

local function EnsureRowVisible(r)
    if not (r and scroll) then return end
    local view = scroll:GetHeight() or 300
    local cur = scroll:GetVerticalScroll() or 0
    local maxScroll = scroll:GetVerticalScrollRange() or 0
    local top, bottom = r.y or 0, (r.y or 0) + (r:GetHeight() or 40) + 8
    if top < cur then
        scroll:SetVerticalScroll(math.max(0, top - 8))
    elseif bottom > cur + view then
        scroll:SetVerticalScroll(math.min(maxScroll, bottom - view))
    end
end

local function NewRow(spec)
    local r = CreateFrame("Frame", nil, content)
    r.spec, r.kind = spec, spec.kind
    local label, tip = L[spec.label], L[spec.tip]
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.label:SetJustifyH("LEFT")
    r.label:SetWordWrap(true)
    r.label:SetText(label)
    local field = spec.field
    if spec.kind == "list" then
        local dd = Skin.Dropdown(CreateFrame("DropdownButton", nil, r, "WowStyle1DropdownTemplate"))
        dd:SetupMenu(function(_, root)
            if root.SetScrollMode then root:SetScrollMode(400) end
            for _, opt in ipairs(Choices(spec)) do
                root:CreateRadio(ns:MediaLabel(opt),
                    function(value) return (Display(field) or "mixed") == value end,
                    function(value) Set(field, value) end, opt.key)
            end
        end)
        r.control = dd
        r.Refresh = function() dd:GenerateMenu() end
        r.Step = function(dir)
            local list = spec.choices()
            local now, at = Display(field), 0
            for i, item in ipairs(list) do if item.key == now then at = i end end
            local nextAt = math.max(1, math.min(#list, at + dir))
            if at == 0 then nextAt = dir > 0 and 1 or #list end
            if list[nextAt] then Set(field, list[nextAt].key) end
        end
        AttachTip(dd, label, tip)
    elseif spec.kind == "slider" then
        local sl = Skin.Slider(CreateFrame("Frame", nil, r, "MinimalSliderWithSteppersTemplate"))
        sl:Init(Display(field, true) or spec.min, spec.min, spec.max, spec.max - spec.min, {
            [MinimalSliderWithSteppersMixin.Label.Right] = function(v) return tostring(math.floor(v + 0.5)) end,
        })
        sl:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
            if r.updating then return end
            Set(field, math.floor(value + 0.5))
        end, r)
        r.control = sl
        r.Refresh = function()
            r.updating = true
            sl:SetValue(Display(field, true) or spec.min)
            r.updating = false
        end
        r.Step = function(dir)
            local v = (Display(field, true) or spec.min) + dir
            Set(field, math.max(spec.min, math.min(spec.max, v)))
        end
        if sl.Slider then AttachTip(sl.Slider, label, tip) end
    else
        local ok, cb = pcall(CreateFrame, "CheckButton", nil, r, "SettingsCheckboxTemplate")
        if not ok or not cb then
            cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
        end
        cb:SetSize(24, 24)
        cb:SetScript("OnEnter", nil)
        cb:SetScript("OnLeave", nil)
        cb:SetScript("OnClick", function(self) Set(field, self:GetChecked() and true or false) end)
        r:EnableMouse(true)
        r:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and cb:IsEnabled() then cb:Click() end
        end)
        r.control = cb
        r.Refresh = function() cb:SetChecked(Display(field, true) and true or false) end
        r.Step = function() Set(field, not Display(field, true)) end
        AttachTip(cb, label, tip)
    end
    AttachTip(r, label, tip)
    -- keyboard / gamepad focus: a ring around the row; a taken row also shows two arrows
    -- (a shape, not only a color)
    r.ring = CreateFrame("Frame", nil, r)
    r.ring:SetPoint("TOPLEFT", -5, 5)
    r.ring:SetPoint("BOTTOMRIGHT", 5, -5)
    r.ringTex = Sliced(r.ring, "OVERLAY", "frame8", 10)
    r.left = Skin.Image(r.ring, "left", 14, function(p) return p.title end, "OVERLAY")
    r.right = Skin.Image(r.ring, "right", 14, function(p) return p.title end, "OVERLAY")
    r.right:SetPoint("TOPRIGHT", r.ring, "TOPRIGHT", -6, -6)
    r.left:SetPoint("RIGHT", r.right, "LEFT", -2, 0)
    Skin.Paint(function(p)
        Skin.Tint(r.ringTex, p.contrast and p.edge or p.bar, 1)
        Skin.TextColor(r.label, p.ink)
    end)
    r.ring:Hide()
    return r
end

-- Builds the column in the gallery window f (once)
function W.Build(f, colW, pad, barH)
    side = CreateFrame("Frame", nil, f, "BackdropTemplate")
    side:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -44)
    side:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad + barH)
    side:SetWidth(colW)
    Skin.Box(side, 8)
    local ok, sc = pcall(CreateFrame, "ScrollFrame", nil, side, "ScrollFrameTemplate")
    if not ok then sc = CreateFrame("ScrollFrame", nil, side, "UIPanelScrollFrameTemplate") end
    scroll = sc
    scroll:SetPoint("TOPLEFT", 12, -12)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(colW - 12 - 28 - 6, 10)
    scroll:SetScrollChild(content)
    title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    hint = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    Skin.Paint(function(p)
        Skin.TextColor(title, p.title)
        Skin.TextColor(hint, p.soft)
    end)
    for i, spec in ipairs(ns.LOOK_ROWS) do rows[i] = NewRow(spec) end
    W.side, W.scroll, W.content, W.rows = side, scroll, content, rows -- (tools/mock_run.lua)
end

-- Opens the column for one opening of the gallery. o.lookNow(field, first) gives the blocks'
-- values (none: no column); chosen() gives the marked key and the style it draws; redraw()
-- draws the thumbnails again.
function W.Open(o, openKey, chosen, redraw)
    W.active = o.lookNow ~= nil
    ctx = { lookNow = o.lookNow, openKey = openKey, chosen = chosen, redraw = redraw }
    touched, proposals = {}, {}
    focusRow, taken = 1, false
    if side then side:SetShown(W.active) end
    if scroll then scroll:SetVerticalScroll(0) end
end

-- Places the rows (a text twice as big: taller rows, the column scrolls)
local function Layout()
    local w = content:GetWidth()
    local y = 0
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    title:SetWidth(w)
    title:SetText(L.STYLE_WORKSHOP_TITLE)
    y = y + math.ceil(title:GetStringHeight() or 16) + 6
    hint:ClearAllPoints()
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    hint:SetWidth(w)
    hint:SetText(L.STYLE_WORKSHOP_HINT)
    y = y + math.ceil(hint:GetStringHeight() or 12) + 14
    for _, r in ipairs(rows) do
        if r.shown then
            r:Show()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            r:SetWidth(w)
            local h
            r.label:ClearAllPoints()
            r.control:ClearAllPoints()
            if r.kind == "check" then
                r.control:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
                r.label:SetPoint("TOPLEFT", r, "TOPLEFT", 30, -4)
                r.label:SetWidth(w - 30 - 36)
                h = math.max(26, math.ceil(r.label:GetStringHeight() or 14) + 8)
            else
                r.label:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
                r.label:SetWidth(w - 36) -- room for the two arrows of a taken row
                local labelH = math.ceil(r.label:GetStringHeight() or 14)
                r.control:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -labelH - 4)
                local ch = r.kind == "list" and 26 or 24
                if r.kind == "list" then r.control:SetWidth(w) else r.control:SetWidth(w - 40) end
                h = labelH + 4 + ch
            end
            r:SetHeight(h)
            r.y = y
            y = y + h + 14
        else
            r:Hide()
        end
    end
    content:SetHeight(math.max(y, 1))
end

-- Shows the values of the marked style, the rows that matter for it, and lays them out
function W.Sync()
    if not (side and W.active) then return end
    local cfg = ChosenCfg()
    visible = {}
    for _, r in ipairs(rows) do
        r.shown = RowShown(r.spec, cfg)
        if r.shown then
            visible[#visible + 1] = r
            r.Refresh()
        end
    end
    focusRow = math.max(1, math.min(#visible, focusRow))
    Layout()
end

-- The focus ring (on = the keyboard or gamepad is in the column)
function W.ShowMarks(on)
    if not side then return end
    for i, r in ipairs(visible) do
        local here = on and i == focusRow
        r.ring:SetShown(here and true or false)
        r.left:SetShown(here and taken)
        r.right:SetShown(here and taken)
    end
    for _, r in ipairs(rows) do
        if not r.shown then r.ring:Hide() end
    end
end

function W.HasRows() return W.active and #visible > 0 end
function W.Taken() return taken end
function W.Release() taken = false end
function W.Enter()
    taken = false
    focusRow = math.max(1, math.min(#visible, focusRow))
    EnsureRowVisible(visible[focusRow])
end
function W.FocusedRow() return visible[focusRow] end -- (tools/mock_run.lua)

-- One key in the column: "used", or where the focus goes: "left" (back to the thumbnails),
-- "down" (the buttons), "tab" (the buttons)
function W.Key(what)
    local r = visible[focusRow]
    if not r then return "left" end
    if taken then
        if what == "left" or what == "right" then
            r.Step(what == "right" and 1 or -1)
            return "used"
        end
        taken = false
        if what == "confirm" or what == "back" then return "used" end
        if what == "tab" then return "tab" end
    end
    if what == "confirm" then
        if r.kind == "check" then r.Step(1) else taken = true end
        return "used"
    elseif what == "left" or what == "tab" then
        return what
    elseif what == "up" then
        focusRow = math.max(1, focusRow - 1)
    elseif what == "down" then
        if focusRow >= #visible then return "down" end
        focusRow = focusRow + 1
    end
    EnsureRowVisible(visible[focusRow])
    return "used"
end
