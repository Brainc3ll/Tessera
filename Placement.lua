local _, ns = ...
local L = ns.L

-- ========================================================================
-- Placement.lua: helpers around moving blocks and interacting with them
-- ========================================================================
-- What lives here (everything else about positions is in Core.lua and Merge.lua):
--   * Coordinates: blocks can have their own scale, so rectangles are compared in
--     UIParent units (GetRectUI), and saved positions are relative to the nearest
--     screen anchor (a corner, an edge middle or the center), so a layout survives
--     another screen size or aspect ratio (MakeRelativePoint).
--   * Scale: global scale (profile) x group scale (root block), and pixel snapping.
--   * Undo: snapshots of every block's position before each placement action.
--   * Alignment guides drawn while dragging, and snapping to Blizzard frames.
--   * Frozen groups: a group whose blocks cannot be moved, hidden or merged into.
--   * Quick menu (Alt + right-click) and the configurable Shift / middle click actions.
--   * Key bindings (Bindings.xml calls the global functions at the end of this file).

---------------------------------------------------------------------------
-- Coordinates and scale
---------------------------------------------------------------------------

-- Rectangle of a frame in UIParent units (left, bottom, right, top), whatever its scale
function ns:GetRectUI(frame)
    local l, b, r, t = frame:GetLeft(), frame:GetBottom(), frame:GetRight(), frame:GetTop()
    if not (l and b and r and t) then return nil end
    local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return l * k, b * k, r * k, t * k
end

-- Ratio between a block's own units and UIParent units (1 = same scale)
local function UnitRatio(frame)
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

-- Saved position for a rectangle given in UIParent units: anchored to the nearest
-- screen anchor (thirds of the screen decide which one). `ratio` converts the
-- offsets to the block's own units, which is what SetPoint expects.
-- Returns { point, relativePoint, x, y } (point == relativePoint).
function ns:MakeRelativePoint(l, b, r, t, ratio)
    ratio = ratio or 1
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local cx, cy = (l + r) / 2, (b + t) / 2
    local h = cx < W / 3 and "LEFT" or (cx > W * 2 / 3 and "RIGHT" or "")
    local v = cy > H * 2 / 3 and "TOP" or (cy < H / 3 and "BOTTOM" or "")
    local x = (h == "LEFT" and l) or (h == "RIGHT" and r - W) or (cx - W / 2)
    local y = (v == "TOP" and t - H) or (v == "BOTTOM" and b) or (cy - H / 2)
    local point = (v .. h ~= "") and (v .. h) or "CENTER"
    return { point, point, math.floor(x / ratio + 0.5), math.floor(y / ratio + 0.5) }
end

-- Rectangle (UIParent units) that a saved point gives to a block of size w x h (own units)
function ns:PointToRect(point, w, h, ratio)
    ratio = ratio or 1
    w, h = w * ratio, h * ratio
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local p, rp, x, y = point[1], point[2], (point[3] or 0) * ratio, (point[4] or 0) * ratio
    -- position of the reference point on UIParent
    local function Ref(name)
        local rx = name:find("LEFT") and 0 or (name:find("RIGHT") and W or W / 2)
        local ry = name:find("TOP") and H or (name:find("BOTTOM") and 0 or H / 2)
        return rx, ry
    end
    local ax, ay = Ref(rp)
    ax, ay = ax + x, ay + y
    -- the block's own point sits at (ax, ay)
    local l = p:find("LEFT") and ax or (p:find("RIGHT") and ax - w or ax - w / 2)
    local t = p:find("TOP") and ay or (p:find("BOTTOM") and ay + h or ay + h / 2)
    return l, t - h, l + w, t
end

-- Effective scale of a block: global scale of the profile x scale of its group (root)
function ns:GetBlockScale(key)
    local root = self.db.blocks[self:GetRoot(key)] or self.db.blocks[key]
    return (self.db.scale or 1) * (root and root.scale or 1)
end

-- Rounds a size (in the frame's own units) to whole physical pixels, so thin
-- borders stay sharp at any resolution and UI scale
function ns:PixelSize(value, frame)
    if PixelUtil and PixelUtil.GetNearestPixelSize and frame then
        return PixelUtil.GetNearestPixelSize(value, frame:GetEffectiveScale(), value > 0 and 1 or 0)
    end
    return value
end

-- Changes the global scale (or one group's scale) while keeping every block where
-- it is on screen: saved offsets are in the block's own units, so they are
-- converted from the old scale to the new one
local function RescaleOffsets(cfg, old, new)
    if cfg.point and cfg.point[3] then
        cfg.point[3] = math.floor(cfg.point[3] * old / new + 0.5)
        cfg.point[4] = math.floor(cfg.point[4] * old / new + 0.5)
    end
end

function ns:SetGlobalScale(value)
    local old = self.db.scale or 1
    if math.abs(old - value) < 0.001 then return end
    self:ClearUndo() -- saved positions change units: older undo steps would be wrong
    for _, cfg in pairs(self.db.blocks) do
        if not cfg.dock then RescaleOffsets(cfg, old, value) end
    end
    self.db.scale = value
    self:RefreshAllBlocks()
end

function ns:SetGroupScale(key, value)
    local rootKey = self:GetRoot(key)
    local root = self.db.blocks[rootKey]
    if not root then return end
    local old = root.scale or 1
    if math.abs(old - value) < 0.001 then return end
    self:ClearUndo() -- saved positions change units: older undo steps would be wrong
    RescaleOffsets(root, old, value)
    root.scale = value
    for k in pairs(self:GetSubtree(rootKey)) do self:ApplyStyle(k) end
end

-- One-time conversion of positions saved by older versions (relative to the
-- bottom-left corner) to the nearest screen anchor
function ns:MigratePositions()
    for key, cfg in pairs(self.db.blocks) do
        local f = self.frames[key]
        if cfg.point and cfg.point[2] == "BOTTOMLEFT" and cfg.point[1] == "TOPLEFT"
            and not cfg.dock and not cfg.anchor and f and f:IsShown() then
            local l, b, r, t = self:GetRectUI(f)
            if l then cfg.point = self:MakeRelativePoint(l, b, r, t, UnitRatio(f)) end
        end
    end
end

-- Anchors every block again: roots first, then their docked blocks outward.
-- Clearing all anchors first avoids WoW's "anchor to a region dependent on it"
-- error when docking relations were changed (undo, profile change...).
function ns:ReanchorAll()
    for _, f in pairs(self.frames) do
        f:ClearAllPoints()
        f.seamKey = nil -- every border join is drawn again (no piece of an older shape left)
    end
    local done, queue = {}, {}
    for key in pairs(self.db.blocks) do
        if not self:GetDockTarget(key) then table.insert(queue, key) end
    end
    while #queue > 0 do
        local key = table.remove(queue, 1)
        if not done[key] then
            done[key] = true
            self:ApplyStyle(key)
            for k in pairs(self.db.blocks) do
                if not done[k] and self:GetDockTarget(k) == key then table.insert(queue, k) end
            end
        end
    end
    -- anything left (should not happen): anchored on its own
    for key in pairs(self.db.blocks) do
        if not done[key] then self:ApplyStyle(key) end
    end
end

---------------------------------------------------------------------------
-- Undo (placement mode)
---------------------------------------------------------------------------
local UNDO_LIMIT = 30
-- (scale and frozen live on a group's head block: merging, detaching or replacing it moves them)
local POSITION_FIELDS = { "point", "dock", "anchor", "enabled", "edges", "stretch", "look", "scale", "frozen" }

-- Remembers the position of every block, before a move / merge / detach / hide
function ns:PushUndo()
    self.undoStack = self.undoStack or {}
    local snap = {}
    for key, cfg in pairs(self.db.blocks) do
        local s = {}
        for _, field in ipairs(POSITION_FIELDS) do s[field] = self.DeepCopy(cfg[field]) end
        -- a spacer may be deleted (replaced by a block): keep all of it
        if ns.IsSpacerKey(key) then s.spacer = self.DeepCopy(cfg) end
        snap[key] = s
    end
    table.insert(self.undoStack, snap)
    if #self.undoStack > UNDO_LIMIT then table.remove(self.undoStack, 1) end
    if self.UpdateUndoButton then self:UpdateUndoButton() end
end

function ns:CanUndo()
    return self.undoStack ~= nil and #self.undoStack > 0
end

-- Puts every block back where it was before the last placement action
function ns:Undo()
    if not self:CanUndo() then return end
    local snap = table.remove(self.undoStack)
    local revived = false
    for key, s in pairs(snap) do
        local cfg = self.db.blocks[key]
        if not cfg and s.spacer then -- a spacer deleted since comes back
            self.db.blocks[key] = self.DeepCopy(s.spacer)
            revived = true
        elseif cfg then
            for _, field in ipairs(POSITION_FIELDS) do cfg[field] = self.DeepCopy(s[field]) end
        end
    end
    -- spacers added since (a bar stretched over the screen width) go away
    for key in pairs(self.db.blocks) do
        if not snap[key] and ns.IsSpacerKey(key) then
            self.db.blocks[key] = nil
            if self.frames[key] then self.frames[key]:Hide() end
        end
    end
    if revived then self:RefreshAllBlocks() end
    self:ReanchorAll()
    if self.UpdateUndoButton then self:UpdateUndoButton() end
    if self.RefreshOptions then self:RefreshOptions() end
end

function ns:ClearUndo()
    self.undoStack = {}
    if self.UpdateUndoButton then self:UpdateUndoButton() end
end

---------------------------------------------------------------------------
-- Snapping targets: other blocks, and optionally some Blizzard frames
---------------------------------------------------------------------------
local BLIZZARD_FRAMES = {
    "Minimap", "MinimapCluster", "ChatFrame1", "MainMenuBar", "MainActionBar",
    "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "PlayerFrame", "TargetFrame",
}

-- Visible frames blocks snap to: BLIZZARD_FRAMES plus the frames of known
-- interface addons marked snap (ns.KNOWN_UI_FRAMES)
function ns:SnapFrames()
    local list = {}
    local function Add(frame)
        if frame and frame.IsVisible and frame:IsVisible() and frame.GetLeft then table.insert(list, frame) end
    end
    for _, name in ipairs(BLIZZARD_FRAMES) do Add(_G[name]) end
    self:ForEachKnownUIFrame(function(f, info) if info.snap then Add(f) end end)
    return list
end

-- Rectangles (UIParent units) of the frames of SnapFrames (action bars, minimap,
-- chat...), whatever the snapping option
function ns:GetBlizzardRects()
    local rects = {}
    for _, frame in ipairs(self:SnapFrames()) do
        local l, b, r, t = self:GetRectUI(frame)
        if l and r - l > 1 and t - b > 1 then table.insert(rects, { l, b, r, t }) end
    end
    return rects
end

-- Rectangles (UIParent units) a moved group can snap to; `exclude` = the moved group
function ns:GetSnapRects(exclude)
    local rects = {}
    for key, other in pairs(self.frames) do
        if not exclude[key] and self.db.blocks[key] and other:IsShown() then
            local l, b, r, t = self:GetRectUI(other)
            if l then table.insert(rects, { l, b, r, t }) end
        end
    end
    if self.db.snapBlizzard then
        for _, frame in ipairs(self:SnapFrames()) do
            local l, b, r, t = self:GetRectUI(frame)
            if l and r - l > 1 and t - b > 1 then table.insert(rects, { l, b, r, t, blizzard = true }) end
        end
    end
    return rects
end

---------------------------------------------------------------------------
-- Alignment guides while dragging
---------------------------------------------------------------------------
local guide

local function GuideLine(parent)
    local line = parent:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(1, 0.82, 0, 0.7)
    line:Hide()
    return line
end

-- Called by BeginDrag: remembers the moved group's blocks relative to the moved
-- frame, and the rectangles it could align with
function ns:StartGuides(mover)
    if not (self.db.snap or self.db.merge) then return end
    if not guide then
        guide = CreateFrame("Frame", nil, UIParent)
        guide:SetAllPoints()
        guide:SetFrameStrata("TOOLTIP")
        guide.v = GuideLine(guide)
        guide.h = GuideLine(guide)
    end
    local exclude = self:GetDragSet(mover.key)
    local ml, _, _, mt = self:GetRectUI(mover)
    if not ml then return end
    local members = {}
    for key in pairs(exclude) do
        local f = self.frames[key]
        if f and f:IsShown() then
            local l, b, r, t = self:GetRectUI(f)
            if l then table.insert(members, { l - ml, b - mt, r - ml, t - mt }) end
        end
    end
    -- the group's outer rectangle: the only thing that lines up (as when dropping)
    local box
    for _, m in ipairs(members) do
        if not box then box = { m[1], m[2], m[3], m[4] } else
            box[1], box[2] = math.min(box[1], m[1]), math.min(box[2], m[2])
            box[3], box[4] = math.max(box[3], m[3]), math.max(box[4], m[4])
        end
    end
    members = box and { box } or {}
    guide.mover, guide.members, guide.rects = mover, members, self:GetSnapRects(exclude)
    guide:SetScript("OnUpdate", function() ns:UpdateGuides() end)
    guide:Show()
end

-- Shows one vertical and one horizontal line where an edge of the moved group
-- lines up (within snapping distance) with an edge of another block
function ns:UpdateGuides()
    if not guide or not self.dragging then return self:StopGuides() end
    local ml, _, _, mt = self:GetRectUI(guide.mover)
    if not ml then return end
    local SNAP = 10
    local bestX, bestY, gx, gy = SNAP + 1, SNAP + 1, nil, nil
    for _, m in ipairs(guide.members) do
        local l, b, r, t = ml + m[1], mt + m[2], ml + m[3], mt + m[4]
        -- (every frame while dragging: no table built here, only comparisons)
        for _, o in ipairs(guide.rects) do
            for xi = 1, 3, 2 do
                local x = o[xi]
                local d = math.abs(l - x)
                if d < bestX then bestX, gx = d, x end
                d = math.abs(r - x)
                if d < bestX then bestX, gx = d, x end
            end
            for yi = 2, 4, 2 do
                local y = o[yi]
                local d = math.abs(b - y)
                if d < bestY then bestY, gy = d, y end
                d = math.abs(t - y)
                if d < bestY then bestY, gy = d, y end
            end
        end
    end
    local s = UIParent:GetEffectiveScale() / guide:GetEffectiveScale()
    guide.v:SetShown(gx ~= nil)
    if gx then
        guide.v:ClearAllPoints()
        guide.v:SetPoint("TOPLEFT", UIParent, "TOPLEFT", gx * s, 0)
        guide.v:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", gx * s, 0)
        guide.v:SetWidth(1)
    end
    guide.h:SetShown(gy ~= nil)
    if gy then
        guide.h:ClearAllPoints()
        guide.h:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, gy * s)
        guide.h:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, gy * s)
        guide.h:SetHeight(1)
    end
end

function ns:StopGuides()
    if not guide then return end
    guide:SetScript("OnUpdate", nil)
    guide.v:Hide()
    guide.h:Hide()
    guide:Hide()
end

---------------------------------------------------------------------------
-- Frozen groups
---------------------------------------------------------------------------
-- The flag lives on the group's root block: frozen blocks cannot be dragged,
-- detached or hidden with Ctrl + click, and other blocks cannot merge into them.
function ns:IsFrozen(key)
    local root = self.db.blocks[self:GetRoot(key)]
    return root and root.frozen and true or false
end

function ns:SetFrozen(key, frozen)
    local root = self.db.blocks[self:GetRoot(key)]
    if not root then return end
    root.frozen = frozen or nil
    for k in pairs(self:GetSubtree(self:GetRoot(key))) do
        if self.frames[k] then self:ApplyLock(self.frames[k]) end
    end
end

---------------------------------------------------------------------------
-- Click actions (Shift + click, middle click) and the quick menu
---------------------------------------------------------------------------
-- Plain text of a block, for pasting in the chat. shownText (optional) replaces the
-- block's current text, e.g. the text published to a DataBroker addon (Broker.lua);
-- the block's name is then always put in front.
function ns:GetChatText(key, shownText)
    local mod, cfg, f = self:GetModule(key), self.db.blocks[key], self.frames[key]
    if mod and mod.chatText then
        local ok, text = pcall(mod.chatText, cfg)
        if ok and text then return text end
    end
    local text = shownText or (f and f.lastText) or ""
    -- strip textures, atlases, colors and links
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn.-:", "")
    text = text:gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
    text = strtrim(text)
    if shownText or not (cfg and cfg.showLabel) then text = self:GetBlockName(key) .. " : " .. text end
    return text
end

-- Puts text in the chat input box (opens it if needed)
local function InsertInChat(text)
    local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if active and ChatEdit_InsertLink then
        ChatEdit_InsertLink(text)
        return
    end
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    if open then pcall(open, text) end
end
ns.InsertInChat = InsertInChat

-- Readable name of a click action for the tooltip help lines (nil for "none")
local ACTION_LABELS = { chat = "ACTION_CHAT", options = "ACTION_OPTIONS", hide = "ACTION_HIDE", open = "ACTION_OPEN" }
function ns:GetActionName(key, action)
    if not action or action == "none" then return nil end
    local mod = self:GetModule(key)
    if mod and mod.extraAction and mod.extraAction.key == action then return L[mod.extraAction.label] end
    return ACTION_LABELS[action] and L[ACTION_LABELS[action]] or nil
end

-- Runs one of the configurable click actions on a block
--   "none", "open" (the block's normal click), "chat", "options", "hide"
function ns:RunClickAction(key, action, frame)
    if action == "chat" then
        InsertInChat(self:GetChatText(key))
    elseif action == "options" then
        if self.OpenOptionsFor then self:OpenOptionsFor(key) end
    elseif action == "hide" then
        self:HideBlock(key)
    elseif action == "open" then
        local mod = self:GetModule(key)
        if mod and mod.onClick then pcall(mod.onClick, frame or self.frames[key], "LeftButton", self.db.blocks[key]) end
    else
        -- the block's own extra action (e.g. coordinates: place a map pin)
        local mod = self:GetModule(key)
        if mod and mod.extraAction and mod.extraAction.key == action then
            pcall(mod.extraAction.run, self.db.blocks[key])
        end
    end
end

-- Mouse button released on a block while blocks are locked (shared by the block
-- frame and its secure overlay). Returns true when the click was handled here.
function ns:HandleLockedClick(key, button, frame)
    if button == "RightButton" and IsAltKeyDown() then
        GameTooltip:Hide()
        self:OpenQuickMenu(key)
        return true
    end
    if self.IsForwardingKey(key) then return false end -- launchers and DataBroker blocks forward their clicks
    local cfg = self.db.blocks[key]
    if button == "RightButton" then
        GameTooltip:Hide()
        if self.OpenOptionsFor then self:OpenOptionsFor(key) end
        return true
    end
    if button == "LeftButton" and IsShiftKeyDown() then
        GameTooltip:Hide()
        self:RunClickAction(key, cfg.shiftClick or "chat", frame)
        return true
    end
    if button == "MiddleButton" then
        -- "open" on a block with a secure overlay is run by the overlay itself
        local mod = self:GetModule(key)
        if cfg.middleClick == "open" and mod and mod.secureMacro then return true end
        GameTooltip:Hide()
        self:RunClickAction(key, cfg.middleClick or "none", frame)
        return true
    end
    return false
end

-- Right-click in placement mode, Alt + right-click when locked: small menu without
-- opening the options window
function ns:OpenQuickMenu(key)
    local frame = self.frames[key]
    if not (MenuUtil and MenuUtil.CreateContextMenu) or not frame then
        if self.OpenOptionsFor then self:OpenOptionsFor(key) end
        return
    end
    MenuUtil.CreateContextMenu(frame, function(_, root)
        root:CreateTitle(self:GetBlockName(key))
        root:CreateButton(L.MENU_SETTINGS, function() self:OpenOptionsFor(key) end)
        if not self:IsFrozen(key) then
            root:CreateButton(L.MENU_HIDE, function()
                self:PushUndo()
                self:HideBlock(key)
            end)
            if self:GetDockTarget(key) then
                root:CreateButton(L.MENU_DETACH, function()
                    self:PushUndo()
                    self:Detach(key)
                    self:ApplyStyle(key)
                end)
            end
        end
        -- an empty spacer on one side of this block (in between if a block is there)
        if not self:IsFrozen(key) then
            local sub = root:CreateButton(L.MENU_ADD_SPACER)
            for _, side in ipairs({ "LEFT", "RIGHT", "TOP", "BOTTOM" }) do
                if self:CanInsertSpacer(key, side) then
                    sub:CreateButton(L["SPACER_SIDE_" .. side], function() self:InsertSpacer(key, side) end)
                end
            end
        end
        -- put another block in this one's place (or swap with it if it is shown)
        if not self:IsFrozen(key) then
            local sub = root:CreateButton(L.MENU_REPLACE)
            if sub.SetScrollMode then sub:SetScrollMode(400) end
            self:FillReplaceMenu(sub, key)
        end
        -- this group's own look (fused, tiles, separate), or the one of the Look tab
        if self:IsInGroup(key) then
            local sub = root:CreateButton(L.MENU_GROUP_LOOK)
            local function Own() return self.db.blocks[self:GetRoot(key)].look end
            sub:CreateRadio(L.GROUP_LOOK_DEFAULT, function() return Own() == nil end,
                function() self:PushUndo(); self:SetGroupOwnLook(key, nil) end)
            for _, look in ipairs(ns.GROUP_LOOKS) do
                sub:CreateRadio(L["GROUP_LOOK_" .. look:upper()], function() return Own() == look end,
                    function() self:PushUndo(); self:SetGroupOwnLook(key, look) end)
            end
        end
        -- Gold block: forget a character (deleted or renamed) from its tooltip
        if key == "gold" then
            local others = self:GetOtherCharacters()
            if #others > 0 then
                local sub = root:CreateButton(L.GOLD_FORGET)
                if sub.SetScrollMode then sub:SetScrollMode(400) end
                for _, name in ipairs(others) do
                    sub:CreateButton(ns.ShortCharName(name), function() self:AskForgetCharacter(name) end)
                end
            end
        end
        root:CreateCheckbox(L.MENU_FREEZE,
            function() return self:IsFrozen(key) end,
            function() self:SetFrozen(key, not self:IsFrozen(key)) end)
        root:CreateButton(self:IsLocked() and L.UNLOCK_BUTTON or L.LOCK_BUTTON,
            function() self:SetLocked(not self.db.locked) end)
        root:CreateButton(L.MENU_COPY_CHAT, function() InsertInChat(self:GetChatText(key)) end)
    end)
end

-- Blocks that can take a block's place: every other block except spacers,
-- sorted by name; "shown" marks the blocks already shown (choosing one swaps them)
function ns:GetReplacementChoices(key)
    local list = {}
    for _, other in ipairs(self:GetBlockKeys()) do
        local cfg = self.db.blocks[other]
        if other ~= key and cfg and not ns.IsSpacerKey(other) then
            table.insert(list, { key = other, name = self:GetBlockName(other), shown = cfg.enabled and true or false })
        end
    end
    table.sort(list, function(a, b) return ns.SortKey(a.name) < ns.SortKey(b.name) end)
    return list
end

-- The "Replace with..." list: one alphabetical list, each block marked by a color
-- and an icon. Green "+": a hidden block, it takes this place (this block is hidden);
-- gold arrows: a shown block, the two swap places. The legend comes first.
local ICON_SHOW = "|TInterface\\Buttons\\UI-PlusButton-Up:14:14|t "
local ICON_SWAP = "|TInterface\\Buttons\\UI-RefreshButton:14:14|t "
local COLOR_SHOW, COLOR_SWAP = "|cff4dff4d", "|cffffd100"
function ns:FillReplaceMenu(root, key)
    local list = self:GetReplacementChoices(key)
    if #list == 0 then return end
    root:CreateTitle(ICON_SHOW .. COLOR_SHOW .. L.REPLACE_HIDDEN .. "|r")
    root:CreateTitle(ICON_SWAP .. COLOR_SWAP .. L.REPLACE_SHOWN .. "|r")
    if root.CreateDivider then root:CreateDivider() end
    for _, other in ipairs(list) do
        local label = other.shown and (ICON_SWAP .. COLOR_SWAP .. other.name .. "|r")
            or (ICON_SHOW .. COLOR_SHOW .. other.name .. "|r")
        root:CreateButton(label, function() self:AskReplaceBlock(key, other.key) end)
    end
end

-- The arrow button of a block in placement mode (and the Blocks tab): the list alone
function ns:OpenReplaceMenu(key, owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        if self.OpenOptionsFor then self:OpenOptionsFor(key) end
        return
    end
    MenuUtil.CreateContextMenu(owner or self.frames[key], function(_, root)
        if root.SetScrollMode then root:SetScrollMode(400) end
        root:CreateTitle(L.REPLACE_TITLE:format(self:GetBlockName(key)))
        self:FillReplaceMenu(root, key)
    end)
end

-- Asks before replacing (or swapping) a block
StaticPopupDialogs["TESSERA_REPLACE_BLOCK"] = {
    text = L.REPLACE_CONFIRM,
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, data)
        if data and ns:ReplaceBlock(data.old, data.new) and ns.RefreshOptions then ns:RefreshOptions() end
    end,
}

function ns:AskReplaceBlock(oldKey, newKey)
    if InCombatLockdown() then
        self.Print(L.REPLACE_IN_COMBAT)
        return
    end
    StaticPopup_Show("TESSERA_REPLACE_BLOCK", self:GetBlockName(newKey), self:GetBlockName(oldKey),
        { old = oldKey, new = newKey })
end

---------------------------------------------------------------------------
-- Key bindings (see Bindings.xml)
---------------------------------------------------------------------------
BINDING_HEADER_TESSERA = "Tessera"
BINDING_NAME_TESSERA_TOGGLE = L.BINDING_TOGGLE
BINDING_NAME_TESSERA_LOCK = L.BINDING_LOCK
BINDING_NAME_TESSERA_OPTIONS = L.BINDING_OPTIONS
BINDING_NAME_TESSERA_STREAMER = L.BINDING_STREAMER

-- Streamer mode on / off
function Tessera_ToggleStreamer()
    ns:SetStreamerMode(not ns:IsStreamer())
end

-- Shows or hides every block at once (for this session)
function Tessera_ToggleBlocks()
    if not ns.built then return end
    -- In combat the invisible secure click buttons on blocks cannot be hidden: hiding the
    -- blocks would leave clickable holes. Hiding is done when combat ends (pressing the key
    -- again cancels it); showing them works at once.
    if InCombatLockdown() and not ns.allHidden then
        ns.hideAfterCombat = not ns.hideAfterCombat or nil
        ns.Print(ns.hideAfterCombat and ns.L.TOGGLE_AFTER_COMBAT or ns.L.TOGGLE_CANCELLED)
        return
    end
    ns.hideAfterCombat = nil
    ns.allHidden = not ns.allHidden
    ns:UpdateAllVisibility()
    ns:RequestOverlaySync()
end

---------------------------------------------------------------------------
-- Blocks out of the screen, Blizzard's Edit Mode
---------------------------------------------------------------------------
-- Moves back inside the screen every free group (not attached to another frame) that
-- sticks out of it, e.g. after a resolution or scale change. Returns how many moved.
function ns:RecoverOffscreenBlocks()
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local moved = 0
    local pushed = false
    for key, cfg in pairs(self.db.blocks) do
        local f = self.frames[key]
        if f and f:IsShown() and self:GetRoot(key) == key and not cfg.anchor then
            -- the whole group's rectangle, second rows hanging from it included
            local group = self:GetSubtree(key)
            for k, c in pairs(self.db.blocks) do
                local hang = ns.HangTarget(c.anchor)
                if hang and group[hang] then
                    for sub in pairs(self:GetSubtree(k)) do group[sub] = true end
                end
            end
            local gl, gb, gr, gt
            for k in pairs(group) do
                local o = self.frames[k]
                local l, b, r, t
                if o and o:IsShown() then l, b, r, t = self:GetRectUI(o) end
                if l and b and r and t then
                    gl, gb = math.min(gl or l, l), math.min(gb or b, b)
                    gr, gt = math.max(gr or r, r), math.max(gt or t, t)
                end
            end
            if gl then
                local dx = (gl < 0 and -gl) or (gr > W and math.max(W - gr, -gl)) or 0
                local dy = (gb < 0 and -gb) or (gt > H and math.max(H - gt, -gb)) or 0
                if dx ~= 0 or dy ~= 0 then
                    if not pushed then
                        self:PushUndo()
                        pushed = true
                    end
                    local l, b, r, t = self:GetRectUI(f)
                    cfg.point = self:MakeRelativePoint(l + dx, b + dy, r + dx, t + dy, UnitRatio(f))
                    self:ApplyStyle(key)
                    moved = moved + 1
                end
            end
        end
    end
    if moved > 0 then self:RequestLayout() end
    return moved
end

-- Command and button: tells the result in the chat
function ns:RecoverBlocksCommand()
    if self.allHidden then
        ns.Print(ns.L.RECOVER_ALL_HIDDEN)
        return
    end
    local moved = self:RecoverOffscreenBlocks()
    ns.Print(moved > 0 and ns.L.RECOVER_DONE:format(moved) or ns.L.RECOVER_NONE)
end

-- Blizzard's Edit Mode: opening it also unlocks Tessera's blocks (option, on by default),
-- closing it locks them again if Edit Mode was what unlocked them. HookScript adds to
-- Blizzard's handlers without replacing them.
function ns:HookEditMode()
    local frame = EditModeManagerFrame
    if self.editModeHooked or not (frame and frame.HookScript) then return end
    self.editModeHooked = true
    -- (db.unlockedByEditMode is saved: a reload while Edit Mode is open locks again at login)
    frame:HookScript("OnShow", function()
        if ns.db and ns.db.editModeSync ~= false and ns.db.locked and not ns.brokerModeActive then
            ns.db.unlockedByEditMode = true
            ns:SetLocked(false, true)
        end
        -- the small "in front / behind" button under Edit Mode's window (Layers.lua)
        if ns.ShowEditModeLayerButton then ns:ShowEditModeLayerButton(true) end
    end)
    frame:HookScript("OnHide", function()
        if ns.ShowEditModeLayerButton then ns:ShowEditModeLayerButton(false) end
        if ns.db and ns.db.unlockedByEditMode then
            ns.db.unlockedByEditMode = nil
            if not ns.db.locked then ns:SetLocked(true, true) end
        elseif ns.tempStrata and ns.OnBlocksLocked then
            -- blocks switched while they stayed locked: the switch ends, then the question
            ns:OnBlocksLocked()
        end
    end)
end


-- Blocks hidden with the key binding during combat: hidden when combat ends
-- (also: Edit Mode may be loaded after Tessera on some clients)
local combatEnd = CreateFrame("Frame")
combatEnd:RegisterEvent("PLAYER_REGEN_ENABLED")
combatEnd:RegisterEvent("ADDON_LOADED")
combatEnd:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" then
        if ns.built then ns:HookEditMode() end
        return
    end
    if ns.hideAfterCombat and ns.built then
        ns.hideAfterCombat = nil
        ns.allHidden = true
        ns:UpdateAllVisibility()
        ns:RequestOverlaySync()
    end
end)

function Tessera_ToggleLock()
    if ns.built then ns:SetLocked(not ns.db.locked) end
end

function Tessera_ToggleOptions()
    if ns.built then ns:ToggleOptions() end
end

---------------------------------------------------------------------------
-- Positions of every block given back (an older test version saved them aside)
---------------------------------------------------------------------------
local function RestorePositions(self, snap)
    for key, s in pairs(snap) do
        local cfg = self.db.blocks[key]
        if cfg then
            for _, field in ipairs(POSITION_FIELDS) do cfg[field] = self.DeepCopy(s[field]) end
        end
    end
    self:ReanchorAll()
    self:RequestLayout()
end

-- The blocks made for WoW Forever (checked on import, Profiles.lua)
ns.FOREVER_KEYS = { "legacy", "comprehension", "camping", "honor", "weaponSkills" }

-- An older test version had a screenshot helper that put the player's layout aside
-- (sv.foreverPreviewBackup): left open at logout, the layout is given back at login
local EXTRA_FIELDS = { "showIcon", "showLabel" }
function ns:RestoreForeverPreview()
    local backup = self.sv and self.sv.foreverPreviewBackup
    if type(backup) ~= "table" then return end
    self.sv.foreverPreviewBackup = nil
    if type(backup.positions) == "table" then RestorePositions(self, backup.positions) end
    for key, saved in pairs(type(backup.extra) == "table" and backup.extra or {}) do
        local cfg = self.db.blocks[key]
        if cfg and type(saved) == "table" then
            for _, field in ipairs(EXTRA_FIELDS) do cfg[field] = saved[field] end
        end
    end
    self:RefreshAllBlocks()
    self:ReanchorAll()
end

---------------------------------------------------------------------------
-- Screen edges: sticking a group to an edge, stretching a bar over the width
---------------------------------------------------------------------------
-- A group dropped within EDGE_DISTANCE of a screen edge can be stuck to it
-- (db.edgeSnap: "ask" with a small menu, "always" or "never"). A stuck group
-- touches the edge exactly, stays there whatever the resolution (its position is
-- saved from that edge), and loses its border along the edge (cfg.edges on the
-- group's root, see UpdateSeams). Along the top or bottom edge, a single-row bar
-- can also be stretched over the whole width (cfg.stretch): spacer blocks are
-- added to align its blocks left, center, right or spread, and only those spacers
-- stretch, so the blocks keep their size. Moving the group again unsticks it.
local EDGE_DISTANCE = 10
local SPACER_SLOT = 200 -- about one spacer per this many pixels of room (1 to 4)
ns.STRETCH_ALIGNS = { "left", "center", "right", "spread" }

-- Rectangle of a whole group (UIParent units). It is rebuilt from the head's
-- position and the dock links, not read from each block: a block pushed off the
-- screen is held at the edge by the game (clamped), so reading it would give a
-- wrong rectangle (e.g. a tall column dragged to the bottom edge).
function ns:GroupRectUI(rootKey)
    local head = self.frames[rootKey]
    if not head then return nil end
    local hl, hb, hr, ht = self:GetRectUI(head)
    if not hl then return nil end
    local pos = { [rootKey] = { l = hl, t = ht, w = hr - hl, h = ht - hb } }
    local members = self:GetSubtree(rootKey)
    local changed = true
    while changed do
        changed = false
        for key in pairs(members) do
            local f = self.frames[key]
            if not pos[key] and f and f:IsShown() then
                local target, side = self:GetEffectiveDock(key)
                local tp = target and pos[target]
                if tp then
                    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
                    local w, h = f:GetWidth() * k, f:GetHeight() * k
                    local l, t = tp.l, tp.t
                    local g = self:JointGap(key) * k
                    if side == "RIGHT" then l = tp.l + tp.w + g
                    elseif side == "LEFT" then l = tp.l - w - g
                    elseif side == "BOTTOM" then t = tp.t - tp.h - g
                    else t = tp.t + h + g end
                    pos[key] = { l = l, t = t, w = w, h = h }
                    changed = true
                end
            end
        end
    end
    local l, b, r, t
    for _, p in pairs(pos) do
        l, b = math.min(l or p.l, p.l), math.min(b or (p.t - p.h), p.t - p.h)
        r, t = math.max(r or (p.l + p.w), p.l + p.w), math.max(t or p.t, p.t)
    end
    return l, b, r, t
end

-- Screen edges a rectangle touches (nil when none)
function ns:TouchedEdges(l, b, r, t)
    if not l then return nil end
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local e = {
        LEFT = l <= EDGE_DISTANCE or nil, RIGHT = r >= W - EDGE_DISTANCE or nil,
        BOTTOM = b <= EDGE_DISTANCE or nil, TOP = t >= H - EDGE_DISTANCE or nil,
    }
    if next(e) then return e end
end

-- True when the group is one row of blocks (only merged left / right)
function ns:IsSingleRow(rootKey)
    for key in pairs(self:GetSubtree(rootKey)) do
        local _, side = self:GetDockTarget(key)
        if side == "TOP" or side == "BOTTOM" then return false end
    end
    return true
end

-- Saved point of a stuck group's head: offsets measured from the stuck edges, so
-- the group stays against them on any screen
local function EdgePoint(self, l, b, r, t, ratio, edges)
    local pt = self:MakeRelativePoint(l, b, r, t, ratio)
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local h = (edges.LEFT and "LEFT") or (edges.RIGHT and "RIGHT") or (pt[1]:match("LEFT") or pt[1]:match("RIGHT") or "")
    local v = (edges.TOP and "TOP") or (edges.BOTTOM and "BOTTOM") or (pt[1]:match("TOP") or pt[1]:match("BOTTOM") or "")
    local cx, cy = (l + r) / 2, (b + t) / 2
    local x = (h == "LEFT" and l) or (h == "RIGHT" and r - W) or (cx - W / 2)
    local y = (v == "TOP" and t - H) or (v == "BOTTOM" and b) or (cy - H / 2)
    local point = (v .. h ~= "") and (v .. h) or "CENTER"
    return { point, point, math.floor(x / ratio + 0.5), math.floor(y / ratio + 0.5) }
end

-- Blocks of a one-row group, from left to right
local function RowOrder(self, rootKey)
    local list = {}
    for key in pairs(self:GetSubtree(rootKey)) do
        local f = self.frames[key]
        local l = f and self:GetRectUI(f)
        table.insert(list, { key = key, l = l or 0 })
    end
    table.sort(list, function(a, b) return a.l < b.l end)
    local keys = {}
    for _, e in ipairs(list) do table.insert(keys, e.key) end
    return keys
end

-- Adds spacers to a one-row group so its blocks are aligned once the bar is
-- stretched ("room": free width in UIParent units), then re-docks the row:
-- blocks left of the head docked LEFT, the others RIGHT (the head stays put)
local function AddStretchSpacers(self, rootKey, align, room)
    local row = RowOrder(self, rootKey)
    local gaps = {}  -- position (insert before row[i]; #row + 1 = at the end) -> room
    if align == "left" then
        gaps[#row + 1] = room
    elseif align == "right" then
        gaps[1] = room
    elseif align == "center" then
        gaps[1], gaps[#row + 1] = room / 2, room / 2
    else -- spread: between the blocks
        for i = 2, #row do gaps[i] = room / math.max(1, #row - 1) end
        if #row < 2 then gaps[#row + 1] = room end
    end
    local function NewSpacer()
        local n = 1
        while self.db.blocks[self.SPACER_PREFIX .. n] do n = n + 1 end
        local key = self.SPACER_PREFIX .. n
        self.db.blocks[key] = self:GetBlockDefaults(key)
        self:CopyBlockStyle(rootKey, key)
        self.db.blocks[key].width = 8
        return key
    end
    local ordered = {}
    for i = 1, #row + 1 do
        if gaps[i] then
            local count = math.max(1, math.min(4, math.floor(gaps[i] / SPACER_SLOT + 0.5)))
            for _ = 1, count do table.insert(ordered, NewSpacer()) end
        end
        if row[i] then table.insert(ordered, row[i]) end
    end
    local headIndex
    for i, key in ipairs(ordered) do
        if key == rootKey then headIndex = i end
    end
    for i, key in ipairs(ordered) do
        local cfg = self.db.blocks[key]
        cfg.anchor = nil
        if i < headIndex then
            cfg.dock = { to = ordered[i + 1], side = "LEFT" }
        elseif i > headIndex then
            cfg.dock = { to = ordered[i - 1], side = "RIGHT" }
        end
    end
end

-- Sticks a group to the given edges; align ("left", "center", "right", "spread")
-- also stretches a one-row bar along the top or bottom edge
function ns:StickToEdges(rootKey, edges, align)
    local f, cfg = self.frames[rootKey], self.db.blocks[rootKey]
    local l, b, r, t = self:GroupRectUI(rootKey)
    if not (f and cfg and l) or InCombatLockdown() then return end
    self:PushUndo()
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local dx = (edges.LEFT and -l) or (edges.RIGHT and W - r) or 0
    local dy = (edges.BOTTOM and -b) or (edges.TOP and H - t) or 0
    local rl, rb, rr, rt = self:GetRectUI(f)
    local stretch = align and (edges.TOP or edges.BOTTOM) and self:IsSingleRow(rootKey)
    if stretch then
        AddStretchSpacers(self, rootKey, align, W - (r - l))
        edges = { TOP = edges.TOP, BOTTOM = edges.BOTTOM, LEFT = true, RIGHT = true }
    end
    cfg.point = EdgePoint(self, rl + dx, rb + dy, rr + dx, rt + dy,
        f:GetEffectiveScale() / UIParent:GetEffectiveScale(), edges)
    cfg.edges = edges
    cfg.stretch = stretch and (edges.TOP and "TOP" or "BOTTOM") or nil
    self:RefreshAllBlocks()
    self:RequestLayout()
end

-- After a drop: is the group against a screen edge? Then stick it, or ask how
function ns:CheckScreenEdges(rootKey)
    if not self.db or self:GetDockTarget(rootKey) then return end
    local mode = self.db.edgeSnap or "ask"
    if mode == "never" then return end
    local edges = self:TouchedEdges(self:GroupRectUI(rootKey))
    if not edges then return end
    if mode == "always" or not (MenuUtil and MenuUtil.CreateContextMenu) then
        self:StickToEdges(rootKey, edges)
        return
    end
    MenuUtil.CreateContextMenu(UIParent, function(_, menu)
        menu:CreateTitle(L.EDGE_TITLE)
        menu:CreateButton(L.EDGE_STICK, function() self:StickToEdges(rootKey, edges) end)
        if (edges.TOP or edges.BOTTOM) and self:IsSingleRow(rootKey) then
            for _, align in ipairs(ns.STRETCH_ALIGNS) do
                menu:CreateButton(L["EDGE_STRETCH_" .. align:upper()],
                    function() self:StickToEdges(rootKey, edges, align) end)
            end
        end
        menu:CreateButton(L.EDGE_LEAVE, function() end)
    end)
end

---------------------------------------------------------------------------
-- Inserting an empty spacer next to a block
---------------------------------------------------------------------------
-- Adds an empty spacer on one side of a block, even inside a merged group:
--   * side free: the spacer is simply docked there;
--   * a block already docked on that side (or the block this one is docked to):
--     the spacer goes in between, and that block and everything after it move
--     one step further, nothing is detached.
-- In a bar stretched over the screen width, only left / right are allowed (a
-- second row would break the stretch), and the bar keeps its width: the new
-- spacer takes room from the other spacers. When there is no room left (the bar
-- would get wider than the screen), the insertion is undone with a message.
local OPPOSITE_SIDE = { LEFT = "RIGHT", RIGHT = "LEFT", TOP = "BOTTOM", BOTTOM = "TOP" }

function ns:CanInsertSpacer(key, side)
    local rootCfg = self.db.blocks[self:GetRoot(key)]
    if rootCfg and rootCfg.stretch and (side == "TOP" or side == "BOTTOM") then return false end
    return true
end

function ns:InsertSpacer(key, side)
    local blocks = self.db.blocks
    local cfg = blocks[key]
    if not cfg or InCombatLockdown() or not OPPOSITE_SIDE[side] then return false end
    local root = self:GetRoot(key)
    local stretched = blocks[root] and blocks[root].stretch
    if not self:CanInsertSpacer(key, side) then
        self.Print(L.SPACER_NO_ROW)
        return false
    end
    self:PushUndo()
    -- the new spacer, with the look of the block it sits next to
    local n = 1
    while blocks[self.SPACER_PREFIX .. n] do n = n + 1 end
    local spacer = self.SPACER_PREFIX .. n
    blocks[spacer] = self:GetBlockDefaults(spacer)
    self:CopyBlockStyle(key, spacer)
    local s = blocks[spacer]
    if side == "LEFT" or side == "RIGHT" then
        s.width = stretched and 8 or 16
    else
        s.height = 8
    end
    -- in between, or simply on that side
    local neighbour
    for k, c in pairs(blocks) do
        if c.dock and c.dock.to == key and c.dock.side == side then neighbour = k end
    end
    if neighbour then
        s.dock = { to = key, side = side }
        blocks[neighbour].dock.to = spacer
    elseif cfg.dock and OPPOSITE_SIDE[cfg.dock.side] == side then
        s.dock = { to = cfg.dock.to, side = cfg.dock.side }
        cfg.dock.to = spacer
    else
        s.dock = { to = key, side = side }
    end
    self:RefreshAllBlocks()
    self:UpdateLayout()
    -- a stretched bar must still fit on the screen
    if stretched then
        local l, _, r = self:GroupRectUI(root)
        if l and (r - l) > UIParent:GetWidth() + 1 then
            self:Undo()
            self:RefreshAllBlocks()
            self.Print(L.SPACER_NO_ROOM)
            return false
        end
    end
    return true
end
