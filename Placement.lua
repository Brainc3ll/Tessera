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
    for _, f in pairs(self.frames) do f:ClearAllPoints() end
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
local POSITION_FIELDS = { "point", "dock", "anchor", "enabled" }

-- Remembers the position of every block, before a move / merge / detach / hide
function ns:PushUndo()
    self.undoStack = self.undoStack or {}
    local snap = {}
    for key, cfg in pairs(self.db.blocks) do
        local s = {}
        for _, field in ipairs(POSITION_FIELDS) do s[field] = self.DeepCopy(cfg[field]) end
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
    for key, s in pairs(snap) do
        local cfg = self.db.blocks[key]
        if cfg then
            for _, field in ipairs(POSITION_FIELDS) do cfg[field] = self.DeepCopy(s[field]) end
        end
    end
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
    "PlayerFrame", "TargetFrame", "FlareUI_XPBar",
}

-- Rectangles (UIParent units) a moved group can snap to; `exclude` = the moved group
-- Rectangles (UIParent units) of the visible Blizzard frames of BLIZZARD_FRAMES
-- (action bars, minimap, chat...), whatever the snapping option
function ns:GetBlizzardRects()
    local rects = {}
    for _, name in ipairs(BLIZZARD_FRAMES) do
        local frame = _G[name]
        if frame and frame.IsVisible and frame:IsVisible() and frame.GetLeft then
            local l, b, r, t = self:GetRectUI(frame)
            if l and r - l > 1 and t - b > 1 then table.insert(rects, { l, b, r, t }) end
        end
    end
    return rects
end

function ns:GetSnapRects(exclude)
    local rects = {}
    for key, other in pairs(self.frames) do
        if not exclude[key] and self.db.blocks[key] and other:IsShown() then
            local l, b, r, t = self:GetRectUI(other)
            if l then table.insert(rects, { l, b, r, t }) end
        end
    end
    if self.db.snapBlizzard then
        for _, name in ipairs(BLIZZARD_FRAMES) do
            local frame = _G[name]
            if frame and frame.IsVisible and frame:IsVisible() and frame.GetLeft then
                local l, b, r, t = self:GetRectUI(frame)
                if l and r - l > 1 and t - b > 1 then table.insert(rects, { l, b, r, t, blizzard = true }) end
            end
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
        for _, o in ipairs(guide.rects) do
            for _, x in ipairs({ o[1], o[3] }) do
                for _, edge in ipairs({ l, r }) do
                    local d = math.abs(edge - x)
                    if d < bestX then bestX, gx = d, x end
                end
            end
            for _, y in ipairs({ o[2], o[4] }) do
                for _, edge in ipairs({ b, t }) do
                    local d = math.abs(edge - y)
                    if d < bestY then bestY, gy = d, y end
                end
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

-- Alt + right-click: small menu without opening the options window
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
        root:CreateCheckbox(L.MENU_FREEZE,
            function() return self:IsFrozen(key) end,
            function() self:SetFrozen(key, not self:IsFrozen(key)) end)
        root:CreateButton(self:IsLocked() and L.UNLOCK_BUTTON or L.LOCK_BUTTON,
            function() self:SetLocked(not self.db.locked) end)
        root:CreateButton(L.MENU_COPY_CHAT, function() InsertInChat(self:GetChatText(key)) end)
    end)
end

---------------------------------------------------------------------------
-- Key bindings (see Bindings.xml)
---------------------------------------------------------------------------
BINDING_HEADER_TESSERA = "Tessera"
BINDING_NAME_TESSERA_TOGGLE = L.BINDING_TOGGLE
BINDING_NAME_TESSERA_LOCK = L.BINDING_LOCK
BINDING_NAME_TESSERA_OPTIONS = L.BINDING_OPTIONS

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
-- Development probes: one value (or a table's plain fields) as text
local function Describe(v)
    if type(v) ~= "table" then return tostring(v) end
    local parts = {}
    for k, x in pairs(v) do
        if type(x) ~= "table" and type(x) ~= "function" then table.insert(parts, tostring(k) .. "=" .. tostring(x)) end
    end
    table.sort(parts)
    return "{ " .. table.concat(parts, ", ") .. " }"
end

-- Development probe (/tessera debug legacy): WoW Forever's Legacy points have no
-- documented API yet. Lists the game's C_ namespaces that may hold them, the functions
-- of the Legacy panel, and every text shown in that panel with its frame path, in a
-- window that can be read (or screenshotted).
function ns:LegacyProbe()
    local lines = {}
    local function Add(s) table.insert(lines, s) end
    Add("== C_ namespaces (legacy / progress / challenge / account / heritage) ==")
    local names = {}
    for k in pairs(_G) do
        if type(k) == "string" and k:find("^C_") then
            local low = k:lower()
            for _, word in ipairs({ "legacy", "progress", "challenge", "account", "heritage", "season" }) do
                if low:find(word, 1, true) then table.insert(names, k) break end
            end
        end
    end
    table.sort(names)
    for _, k in ipairs(names) do
        local funcs = {}
        if type(_G[k]) == "table" then
            for fk, fv in pairs(_G[k]) do if type(fv) == "function" then table.insert(funcs, fk) end end
        end
        table.sort(funcs)
        Add(k .. ": " .. table.concat(funcs, ", "))
    end
    -- functions anywhere in C_ namespaces whose name mentions the Legacy system
    Add("")
    Add("== C_ functions named legacy / rewardtrack / heritage ==")
    for k, t in pairs(_G) do
        if type(k) == "string" and k:find("^C_") and type(t) == "table" then
            for fk, fv in pairs(t) do
                if type(fk) == "string" and type(fv) == "function" then
                    local low = fk:lower()
                    if low:find("legacy", 1, true) or low:find("rewardtrack", 1, true) or low:find("heritage", 1, true) then
                        Add(k .. "." .. fk)
                    end
                end
            end
        end
    end
    -- global functions and Blizzard addons with "legacy" in their name
    Add("")
    Add("== Global functions named legacy ==")
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "function" and k:lower():find("legacy", 1, true) then Add(k) end
    end
    Add("")
    Add("== Blizzard addons named legacy ==")
    local getInfo = C_AddOns and C_AddOns.GetAddOnInfo
    local count = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or 0
    for i = 1, count do
        local ok, name = pcall(getInfo, i)
        if ok and type(name) == "string" and name:lower():find("legacy", 1, true) then
            local loaded = C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(i)
            Add(name .. (loaded and " (loaded)" or " (not loaded)"))
        end
    end
    local frame = _G.LegacySystemFrame
    Add("")
    Add("== LegacySystemFrame functions ==")
    if not frame then
        Add("(not loaded: open the Legacy panel once, then type the command again)")
    else
        local funcs = {}
        for k, v in pairs(frame) do if type(v) == "function" then table.insert(funcs, k) end end
        table.sort(funcs)
        Add(table.concat(funcs, ", "))
        -- the reward track looks built on the renown (major factions) system
        local track = frame.RewardTrackPage
        if type(track) == "table" then
            Add("")
            Add("== RewardTrackPage data ==")
            Add("majorFactionData = " .. Describe(track.majorFactionData))
            Add("actualLevel = " .. tostring(track.actualLevel) .. ", displayLevel = " .. tostring(track.displayLevel)
                .. ", maxLevel = " .. tostring(track.maxLevel))
            if type(track.renownLevelsInfo) == "table" then
                for i, info in ipairs(track.renownLevelsInfo) do
                    if i > 6 then break end
                    Add("renownLevelsInfo[" .. i .. "] = " .. Describe(info))
                end
            end
            local id = type(track.majorFactionData) == "table" and track.majorFactionData.factionID
            if id and C_MajorFactions then
                if C_MajorFactions.GetMajorFactionData then
                    local ok, data = pcall(C_MajorFactions.GetMajorFactionData, id)
                    Add("C_MajorFactions.GetMajorFactionData(" .. id .. ") = " .. (ok and Describe(data) or "error"))
                end
                if C_MajorFactions.GetRenownLevels then
                    local ok, levels = pcall(C_MajorFactions.GetRenownLevels, id)
                    if ok and type(levels) == "table" then
                        Add("C_MajorFactions.GetRenownLevels: " .. #levels .. " levels, first = " .. Describe(levels[1]))
                    end
                end
                if C_MajorFactions.GetRenownRewardsForLevel then
                    for _, level in ipairs({ 15, 25, 40, 55 }) do
                        local ok, rewards = pcall(C_MajorFactions.GetRenownRewardsForLevel, id, level)
                        if ok and type(rewards) == "table" then
                            Add("GetRenownRewardsForLevel(" .. level .. "): " .. #rewards .. " reward(s), first = "
                                .. Describe(rewards[1]))
                        end
                    end
                end
            end
        end
        if C_MajorFactions and C_MajorFactions.GetMajorFactionIDs then
            local ok, ids = pcall(C_MajorFactions.GetMajorFactionIDs)
            if ok and type(ids) == "table" then
                Add("C_MajorFactions.GetMajorFactionIDs = " .. table.concat(ids, ", "))
            end
        end
        if C_MajorFactions then
            local mfFuncs = {}
            for k, v in pairs(C_MajorFactions) do if type(v) == "function" then table.insert(mfFuncs, k) end end
            table.sort(mfFuncs)
            Add("C_MajorFactions: " .. table.concat(mfFuncs, ", "))
        end
        Add("")
        for _, sub in ipairs({ "RewardTrackPage", "ChallengesPage", "TreePage" }) do
            local page = frame[sub]
            if type(page) == "table" then
                local keys = {}
                for k, v in pairs(page) do
                    if type(k) == "string" then table.insert(keys, k .. (type(v) == "function" and "()" or "")) end
                end
                table.sort(keys)
                Add(sub .. ": " .. table.concat(keys, ", "))
            end
        end
        Add("")
        Add("== Texts in the panel ==")
        local function Walk(f, path, depth)
            if depth > 8 then return end
            for _, region in ipairs({ f:GetRegions() }) do
                if region.GetText and region:GetObjectType() == "FontString" then
                    local ok, text = pcall(region.GetText, region)
                    if ok and type(text) == "string" and text ~= "" then
                        local name = region.GetDebugName and region:GetDebugName() or "?"
                        Add(path .. " > " .. name .. " = " .. text)
                    end
                end
            end
            for _, child in ipairs({ f:GetChildren() }) do
                local name = child.GetDebugName and child:GetDebugName() or "?"
                Walk(child, name, depth + 1)
            end
        end
        Walk(frame, "LegacySystemFrame", 0)
    end
    self:ShowTextWindow("Legacy probe", table.concat(lines, "\n"))
end

-- Development probe (/tessera debug skills): does this client have weapon skills?
-- Lists the skill functions that exist, the skill list they return, the C_ namespaces
-- and frames whose name mentions skills or weapons.
function ns:SkillsProbe()
    local lines = {}
    local function Add(s) table.insert(lines, s) end
    Add("== Classic skill functions ==")
    for _, name in ipairs({ "GetNumSkillLines", "GetSkillLineInfo", "ExpandSkillHeader", "GetProfessions",
        "GetProfessionInfo", "GetWeaponSkill", "UnitCharacterPoints" }) do
        Add(name .. ": " .. (type(_G[name]) == "function" and "yes" or "no"))
    end
    -- WoW Forever: the skill list is in C_SkillInfo
    local S = C_SkillInfo
    if S and S.GetNumSkillLines and S.GetSkillLineInfo then
        local ok, count = pcall(S.GetNumSkillLines)
        Add("")
        Add("== C_SkillInfo skill list (" .. tostring(ok and count) .. " lines) ==")
        for i = 1, math.min(ok and tonumber(count) or 0, 60) do
            local res = { pcall(S.GetSkillLineInfo, i) }
            if res[1] then
                local parts = {}
                for j = 2, #res do table.insert(parts, Describe(res[j])) end
                Add(i .. ". " .. table.concat(parts, " | "))
            end
        end
    end
    if type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
        local ok, count = pcall(GetNumSkillLines)
        Add("")
        Add("== Skill list (" .. tostring(ok and count) .. " lines) ==")
        for i = 1, (ok and tonumber(count) or 0) do
            local okLine, name, header, _, rank, _, _, max, abandonable = pcall(GetSkillLineInfo, i)
            if okLine then
                Add(("%d. %s%s %s/%s%s"):format(i, tostring(name), header and " [header]" or "",
                    tostring(rank), tostring(max), abandonable and " (can be unlearned)" or ""))
            end
        end
    end
    Add("")
    Add("== C_ namespaces (skill / weapon / profession / tradeskill) ==")
    local found = {}
    for k in pairs(_G) do
        if type(k) == "string" then
            local low = k:lower()
            local isC = k:find("^C_")
            for _, word in ipairs({ "skill", "weapon", "profession" }) do
                if low:find(word, 1, true) and (isC or (type(_G[k]) == "table" and _G[k].GetObjectType)) then
                    table.insert(found, k)
                    break
                end
            end
        end
    end
    table.sort(found)
    for _, k in ipairs(found) do
        local funcs = {}
        if k:find("^C_") and type(_G[k]) == "table" then
            for fk, fv in pairs(_G[k]) do if type(fv) == "function" then table.insert(funcs, fk) end end
            table.sort(funcs)
        end
        Add(k .. (#funcs > 0 and (": " .. table.concat(funcs, ", ")) or ""))
    end
    self:ShowTextWindow("Skills probe", table.concat(lines, "\n"))
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
                if l then
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
    end)
    frame:HookScript("OnHide", function()
        if ns.db and ns.db.unlockedByEditMode then
            ns.db.unlockedByEditMode = nil
            if not ns.db.locked then ns:SetLocked(true, true) end
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
-- Development: shape test (/tessera debug formes)
---------------------------------------------------------------------------
-- Arranges a few visible blocks into "exotic" shapes (L, T, tetris S / Z,
-- square, cross, U, stairs, ring...) to check merging, shared widths and
-- heights, and hidden borders between touching blocks. Each call shows the
-- next shape in the middle of the screen; "fin" puts every block back.
-- The layout before the test is kept in the saved variables, so a /reload in
-- the middle of a test can still be undone. Not mentioned in the UI or help.
--
-- A shape is a list of links: links[i] = { parent index, side } means block i
-- is docked to block "parent" on that side (block 1 is the root). The side is
-- where block i sits relative to its parent (see Merge.lua).
local SHAPES = {
    { name = "L",          links = { {}, { 1, "BOTTOM" }, { 2, "BOTTOM" }, { 3, "RIGHT" } } },
    { name = "J",          links = { {}, { 1, "BOTTOM" }, { 2, "BOTTOM" }, { 3, "LEFT" } } },
    { name = "T",          links = { {}, { 1, "RIGHT" }, { 2, "RIGHT" }, { 2, "BOTTOM" } } },
    { name = "S",          links = { {}, { 1, "RIGHT" }, { 1, "BOTTOM" }, { 3, "LEFT" } } },
    { name = "Z",          links = { {}, { 1, "RIGHT" }, { 2, "BOTTOM" }, { 3, "RIGHT" } } },
    -- 4 touches 2 from below without being docked to it
    { name = "carré",      links = { {}, { 1, "RIGHT" }, { 1, "BOTTOM" }, { 3, "RIGHT" } } },
    { name = "croix",      links = { {}, { 1, "TOP" }, { 1, "RIGHT" }, { 1, "BOTTOM" }, { 1, "LEFT" } } },
    { name = "U",          links = { {}, { 1, "BOTTOM" }, { 2, "RIGHT" }, { 3, "RIGHT" }, { 4, "TOP" } } },
    { name = "escalier",   links = { {}, { 1, "RIGHT" }, { 2, "BOTTOM" }, { 3, "RIGHT" }, { 4, "BOTTOM" } } },
    { name = "peigne",     links = { {}, { 1, "BOTTOM" }, { 2, "BOTTOM" }, { 1, "RIGHT" }, { 3, "RIGHT" } } },
    -- a closed loop: 8 touches 1 without being docked to it
    { name = "anneau",     links = { {}, { 1, "RIGHT" }, { 2, "RIGHT" }, { 3, "BOTTOM" }, { 4, "BOTTOM" },
                                     { 5, "LEFT" }, { 6, "LEFT" }, { 7, "TOP" } } },
    { name = "colonne",    links = { {}, { 1, "BOTTOM" }, { 2, "BOTTOM" }, { 3, "BOTTOM" }, { 4, "BOTTOM" } } },
}
ns.SHAPES = SHAPES -- used by tools/mock_run.lua

local function SnapshotPositions(self)
    local snap = {}
    for key, cfg in pairs(self.db.blocks) do
        local s = {}
        for _, field in ipairs(POSITION_FIELDS) do s[field] = self.DeepCopy(cfg[field]) end
        snap[key] = s
    end
    return snap
end

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

-- Information blocks currently shown (no spacers, launchers or DataBroker
-- blocks, which may have very different sizes), in display order
local function ShapeCandidates(self)
    local keys = {}
    for _, key in ipairs(self:GetBlockKeys()) do
        local f = self.frames[key]
        if f and f:IsShown() and not self.IsSpacerKey(key) and not self.IsForwardingKey(key) then
            table.insert(keys, key)
        end
    end
    return keys
end

function ns:ShapeTest(arg)
    local backup = self.sv.shapeTestBackup
    if arg == "fin" or arg == "stop" then
        if not backup then
            self.Print("[test] aucun test de formes en cours.")
            return
        end
        RestorePositions(self, backup)
        self.sv.shapeTestBackup, self.sv.shapeTestIndex = nil, nil
        self:ClearUndo()
        self.Print("[test] disposition d'origine remise.")
        return
    end
    if InCombatLockdown() then
        self.Print("[test] pas pendant un combat.")
        return
    end

    local candidates = ShapeCandidates(self)
    -- chosen shape: by name, or the next one
    local index
    for i, shape in ipairs(SHAPES) do
        if arg and arg ~= "" and shape.name == arg then index = i end
    end
    index = index or ((self.sv.shapeTestIndex or 0) % #SHAPES) + 1
    -- skip shapes that need more blocks than shown
    for _ = 1, #SHAPES do
        if #SHAPES[index].links <= #candidates then break end
        index = (index % #SHAPES) + 1
    end
    local shape = SHAPES[index]
    if #shape.links > #candidates then
        self.Print(("[test] pas assez de blocs affichés (%d) pour une forme."):format(#candidates))
        return
    end

    -- first shape: keep the current layout, and start from it for every shape
    if not backup then
        self.sv.shapeTestBackup = SnapshotPositions(self)
    else
        RestorePositions(self, backup)
    end
    self.sv.shapeTestIndex = index
    self:ClearUndo()

    local used, usedSet = {}, {}
    for i = 1, #shape.links do
        used[i] = candidates[i]
        usedSet[candidates[i]] = true
    end
    -- other blocks docked to the used ones stay where they are, on their own
    for key, cfg in pairs(self.db.blocks) do
        if not usedSet[key] and cfg.dock and usedSet[cfg.dock.to] then self:Detach(key) end
    end
    for i, key in ipairs(used) do
        local cfg = self.db.blocks[key]
        local link = shape.links[i]
        cfg.anchor = nil
        if link[1] then
            cfg.dock = { to = used[link[1]], side = link[2] }
        else
            cfg.dock = nil
            cfg.point = { "CENTER", "CENTER", 0, 120 }
        end
    end
    self:ReanchorAll()
    self:RequestLayout()
    self.Print(("[test] forme %d/%d : %s (%d blocs). /tes debug formes : la suivante ; "
        .. "/tes debug formes fin : tout remettre."):format(index, #SHAPES, shape.name, #shape.links))
end

---------------------------------------------------------------------------
-- Screenshot helper: WoW Forever blocks only (/tessera preview forever)
---------------------------------------------------------------------------
-- Shows only the blocks made for WoW Forever, with sample values, in the middle
-- of the screen. Each call shows the next arrangement: merged in a row, apart,
-- merged in a column; "fin" (or the call after the last arrangement) puts every
-- block back. The layout before is kept in the saved variables (like the shape
-- test), so a /reload in between can still be undone.
local FOREVER_KEYS = { "legacy", "comprehension", "camping", "honor", "weaponSkills" }
local FOREVER_MODES = { "row", "apart", "column" }
local EXTRA_FIELDS = { "showIcon", "showLabel" }

function ns:PreviewForever(arg)
    local backup = self.sv.foreverPreviewBackup
    local function Stop()
        if not backup then return end
        RestorePositions(self, backup.positions)
        for key, s in pairs(backup.extra) do
            local cfg = self.db.blocks[key]
            if cfg then for _, field in ipairs(EXTRA_FIELDS) do cfg[field] = s[field] end end
        end
        self.sv.foreverPreviewBackup = nil
        self:RefreshAllBlocks()
        self:ReanchorAll()
        self:ClearUndo()
        self:SetPreview(false)
    end
    if arg == "fin" or arg == "stop" or arg == "off" then
        Stop()
        return
    end
    if InCombatLockdown() then
        self.Print("[preview] pas pendant un combat.")
        return
    end
    local keys = {}
    for _, key in ipairs(FOREVER_KEYS) do
        if self.modules[key] and self.db.blocks[key] then table.insert(keys, key) end
    end
    if #keys == 0 then
        self.Print("[preview] aucun bloc WoW Forever sur ce client.")
        return
    end
    local mode = backup and (backup.mode % #FOREVER_MODES) + 1 or 1
    if backup and backup.mode == #FOREVER_MODES then
        Stop() -- after the last arrangement: back to normal
        return
    end
    if not backup then
        backup = { positions = SnapshotPositions(self), extra = {} }
        for key, cfg in pairs(self.db.blocks) do
            local s = {}
            for _, field in ipairs(EXTRA_FIELDS) do s[field] = cfg[field] end
            backup.extra[key] = s
        end
        self.sv.foreverPreviewBackup = backup
    else
        RestorePositions(self, backup.positions)
    end
    backup.mode = mode

    -- only the WoW Forever blocks, with icon and label
    local wanted = {}
    for _, key in ipairs(keys) do wanted[key] = true end
    for key, cfg in pairs(self.db.blocks) do
        if wanted[key] then
            cfg.enabled, cfg.showIcon, cfg.showLabel = true, true, true
            cfg.anchor, cfg.dock = nil, nil
        else
            cfg.enabled = false
        end
    end
    local name = FOREVER_MODES[mode]
    for i, key in ipairs(keys) do
        local cfg = self.db.blocks[key]
        if name == "apart" then
            cfg.point = { "CENTER", "CENTER", math.floor((i - (#keys + 1) / 2) * 190), 120 }
        elseif i == 1 then
            cfg.point = { "CENTER", "CENTER", 0, 120 }
        else
            cfg.dock = { to = keys[i - 1], side = name == "column" and "BOTTOM" or "RIGHT" }
        end
    end
    self:RefreshAllBlocks()
    self:ReanchorAll()
    self:RequestLayout()
    self:ClearUndo()
    if not self.previewMode then self:SetPreview(true) else self:UpdateAll() end
    local labels = { row = "fusionnés en ligne", apart = "séparés", column = "fusionnés en colonne" }
    self.Print(("[preview] blocs WoW Forever %s (%d/%d). /tes preview forever : la suite ; "
        .. "/tes preview forever fin : tout remettre."):format(labels[name], mode, #FOREVER_MODES))
    if self.brokerModeActive then
        self.Print("[preview] le mode DataBroker est actif : désactive-le (/tes broker) pour voir les blocs.")
    end
end
