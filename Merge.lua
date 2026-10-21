local ADDON, ns = ...

-- ========================================================================
-- Merge.lua: docking ("merging") blocks into groups, group layout, borders
-- ========================================================================
--
-- DOCKING MODEL
-- -------------
-- Each block's saved config may contain:
--   cfg.dock = { to = key of the target block, side = where THIS block sits relative to its target }
--     LEFT   : the block is glued to the left of its target   (same height)
--     RIGHT  : the block is glued to the right of its target  (same height)
--     TOP    : the block is glued above its target            (same width)
--     BOTTOM : the block is glued below its target            (same width)
--
-- Docks form a tree: every block points to at most one target. The block that
-- points to nothing is the ROOT (or "head") of the group; only the root has a
-- free position on screen (cfg.point / cfg.anchor). Every other block is
-- anchored to its target with SetPoint, so anchors are CHAINED:
--
--     [A root] <- [B dock={to=A, side=RIGHT}] <- [C dock={to=B, side=RIGHT}]
--         |
--         ^-- [D dock={to=A, side=BOTTOM}]
--
-- Chaining means moving the root moves the whole group for free (WoW resolves
-- the anchors), and a block resizing pushes its neighbours along.
-- Dragging any block of a group drags the root (i.e. the whole group);
-- Shift + drag detaches the grabbed block (together with the blocks docked to it).
--
-- If a target is hidden (empty block, disabled module...), the block docks to
-- whatever precedes the target in the same direction, so no gap is left
-- (see GetEffectiveDock). "Re-rooting" (Reroot) reverses the dock links along
-- a path so another block becomes the head without changing the group's shape.
--
-- LAYOUT PASS (UpdateLayout, coalesced to once per frame by RequestLayout)
-- -----------
--   1. Sizes: each visible block's minimum size from its text/icon (NeededSize).
--   2. Re-anchor blocks whose effective dock target changed (a target was hidden/shown).
--   3. Fill width: a root anchored with "fill" to an external frame (the FlareUI
--      XP bar) shares that frame's width among the blocks of its group, if the
--      group is purely horizontal.
--   4. Union-find: blocks merged horizontally share one height, blocks merged
--      vertically share one width (each set takes its largest member).
--   5. Centering of anchored groups on their reference frame.
--   6. Seams: borders are rebuilt (UpdateSeams), then once more 0.2 s later when
--      all positions have settled.
-- (Step 3 runs before step 4, so the extra width it adds also counts when
-- widths are equalized.)
--
-- SEAM MODEL (UpdateSeams + ApplySeams)
-- ----------
-- Where two blocks of the same group touch, the border between them is hidden
-- so the group looks like one frame.
--
-- Coordinates: WoW's GetLeft/GetBottom/GetRight/GetTop use a bottom-left origin
-- (y grows upward). For coverage, positions along TOP/BOTTOM are measured from
-- the block's LEFT edge (0..W), and positions along LEFT/RIGHT are measured from
-- the block's TOP edge downward (0..H).
--
-- * Coverage intervals: for each side, the list of [a, b] portions touched by
--   another block of the group (merged, snapped to the ends within SEAM_TOL).
--   A side is "full" if one interval covers it entirely, "partial" otherwise.
-- * Convex corners: a block's corner piece is hidden when either side meeting
--   at that corner is covered at that end; edge pieces then run to the corner.
-- * Partial sides: the edge texture is hidden and redrawn only on the free
--   portions ("segments"); the background is extended to the edge over the
--   covered portions ("patches").
-- * Concave corners ("notches"): where the group's outline turns inward, the
--   two borders arriving at that point would leave a gap. A notch is a small
--   L of two border pieces (one horizontal, one vertical) drawn inside the
--   block, anchored on the concave point, that joins them at a right angle.
--   Notches occur in two places:
--
--     a) at a block corner: both sides of the corner are covered but the
--        diagonal neighbour spot is empty
--
--              +-----+
--              |  T  |
--        +-----X-----+        X = concave point at "me"'s TopLeft corner
--        |  L  | me  |            -> notch "TopLeft" at offset (0, 0)
--        +-----+-----+
--
--     b) mid-edge, where a coverage interval starts or ends inside a side
--
--        +------------------+
--        |        me        |
--        +----X-------X-----+  me's BOTTOM is covered on [a, b]
--             |   B   |        -> notch "BottomLeft" at x = a,
--             +-------+           notch "BottomRight" at x = b
--
--   Notch corner naming: the name is the corner of the notch rectangle that
--   sits on the concave point (it is also the SetPoint anchor used to place it).
-- * Reach: how far each notch arm extends, as a fraction of the border
--   thickness e. It is a per-border tuning value (f.lineReach, from
--   GetBorderReach in Core.lua; default 0.5), because border textures differ
--   in how much of their tile is visible line versus padding.
-- ========================================================================

local OPPOSITE = { LEFT = "RIGHT", RIGHT = "LEFT", TOP = "BOTTOM", BOTTOM = "TOP" }
local HORIZONTAL = { LEFT = true, RIGHT = true }
local DOCK_DISTANCE = 10

-- Corners of a block: { horizontal side, vertical side }
local CORNERS = {
    BottomLeft = { "LEFT", "BOTTOM" }, BottomRight = { "RIGHT", "BOTTOM" },
    TopLeft = { "LEFT", "TOP" }, TopRight = { "RIGHT", "TOP" },
}
-- Border piece (frame texture key) used for each side
local EDGE_OF = { LEFT = "LeftEdge", RIGHT = "RightEdge", TOP = "TopEdge", BOTTOM = "BottomEdge" }

-- Texture coordinates of a single border tile (classic border file: 8 tiles
-- side by side), taken from Blizzard's Backdrop.lua; len = length / thickness,
-- i.e. how many times the tile repeats along the piece. Returns the 8-value
-- form of SetTexCoord (UL, LL, UR, LR); top/bottom tiles are stored rotated
-- in the file, hence the swapped coordinates for TopEdge/BottomEdge.
local UV_START = 0.0625
local function EdgeCoords(edge, len)
    local r = UV_START + len
    if edge == "LeftEdge" then return 0.0078125, UV_START, 0.0078125, r, 0.1171875, UV_START, 0.1171875, r end
    if edge == "RightEdge" then return 0.1328125, UV_START, 0.1328125, r, 0.2421875, UV_START, 0.2421875, r end
    if edge == "TopEdge" then return 0.2578125, r, 0.3671875, r, 0.2578125, UV_START, 0.3671875, UV_START end
    return 0.3828125, r, 0.4921875, r, 0.3828125, UV_START, 0.4921875, UV_START -- BottomEdge
end

---------------------------------------------------------------------------
-- Relations between blocks
---------------------------------------------------------------------------
-- Configured dock target of a block, or nil if its cfg.dock is missing or
-- invalid (self-dock, unknown target, target frame not built, bad side).
-- Returns: targetKey, side
function ns:GetDockTarget(key)
    local cfg = self.db.blocks[key]
    local dock = cfg and cfg.dock
    if dock and dock.to ~= key and self.db.blocks[dock.to] and self.frames[dock.to] and OPPOSITE[dock.side] then
        return dock.to, dock.side
    end
end

-- Actual target of a docked block: if its target is hidden (empty block, disabled...),
-- it docks to whatever precedes that target in the same direction, leaving no gap.
-- Stops walking when the chain changes direction or ends.
-- A block that is turned on keeps its place even while hidden (empty, in combat...):
-- the blocks around it do not move (only a block turned off leaves the group's shape)
function ns:HasPlace(key)
    local cfg = self.db.blocks[key]
    return cfg ~= nil and cfg.enabled == true and self.frames[key] ~= nil
end

function ns:GetEffectiveDock(key)
    local target, side = self:GetDockTarget(key)
    local seen = { [key] = true }
    while target and not seen[target] do
        local t = self.frames[target]
        if not t or t:IsShown() or self:HasPlace(target) then break end
        seen[target] = true
        local nextTarget, nextSide = self:GetDockTarget(target)
        if not nextTarget or nextSide ~= side then break end
        target = nextTarget
    end
    return target, side
end

-- Head block of the group (the one that is docked to nothing)
-- (no table per call: it runs for every block several times a second; a dock loop,
-- which AnchorDocked refuses anyway, simply stops after MAX_CHAIN steps)
local MAX_CHAIN = 500
function ns:GetRoot(key)
    for _ = 1, MAX_CHAIN do
        local target = self:GetDockTarget(key)
        if not target then return key end
        key = target
    end
    return key
end

-- The block and every block docked to it, directly or indirectly (as a set)
function ns:GetSubtree(key)
    local set = { [key] = true }
    for k in pairs(self.db.blocks) do
        local cur = k
        for _ = 1, MAX_CHAIN do
            if not cur then break end
            if cur == key then
                set[k] = true
                break
            end
            cur = self:GetDockTarget(cur)
        end
    end
    return set
end

-- Does any block hang from this one (docked to it, or second row anchored below it)?
function ns:HasDependents(key)
    for _, cfg in pairs(self.db.blocks) do
        if (cfg.dock and cfg.dock.to == key) or ns.HangTarget(cfg.anchor) == key then return true end
    end
    return false
end

-- Head of the "visual" group: a second row anchored below a group counts as part
-- of it, so the borders between the two rows are joined like a single frame
function ns:GetVisualRoot(key)
    local root = self:GetRoot(key)
    for _ = 1, MAX_CHAIN do
        local cfg = self.db.blocks[root]
        local below = cfg and ns.HangTarget(cfg.anchor)
        if not below or not self.db.blocks[below] then break end
        root = self:GetRoot(below)
    end
    return root
end

-- Everything that moves when a group is dragged: the group itself, plus any
-- second row hanging below it (recursively). Used to exclude those blocks from
-- snapping and merging during the drag.
function ns:GetDragSet(key)
    local set = self:GetSubtree(self:GetRoot(key))
    local added = true
    while added do
        added = false
        for k, cfg in pairs(self.db.blocks) do
            local hang = ns.HangTarget(cfg.anchor)
            if not set[k] and hang and set[hang] then
                for m in pairs(self:GetSubtree(k)) do set[m] = true end
                added = true
            end
        end
    end
    return set
end

-- Is side "side" of the target already taken by another block? This is true
-- either if a block is docked there, or if the target itself is docked through
-- that side. Blocks in "ignore" do not count.
local function SideOccupied(self, targetKey, side, ignore)
    for k, cfg in pairs(self.db.blocks) do
        if not ignore[k] and cfg.dock and cfg.dock.to == targetKey and cfg.dock.side == side then
            return true
        end
    end
    local to, toSide = self:GetDockTarget(targetKey)
    return to ~= nil and not ignore[to] and OPPOSITE[toSide] == side
end

---------------------------------------------------------------------------
-- Anchoring, detaching
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- How groups look (Look tab): "fused" (one frame, borders between blocks
-- hidden), "tiles" (mosaic with joints: each block keeps its frame, a small gap
-- between them, the group still moves as one) or "separate" (no merging at all,
-- the old "Merge blocks" option turned off). Saved in db.groupLook; profiles from
-- before it only have db.merge, read as "fused" or "separate".
-- A group can override it (quick menu): cfg.look on the group's head block. The
-- override only changes the drawing; merging new blocks follows the global look.
---------------------------------------------------------------------------
local LOOKS = { fused = true, tiles = true, separate = true }
ns.GROUP_LOOKS = { "fused", "tiles", "separate" }

-- key: optional, any block of a group, to read that group's own look
function ns:GetGroupLook(key)
    if key and self.db then
        local cfg = self.db.blocks[self:GetRoot(key)]
        if cfg and LOOKS[cfg.look] then return cfg.look end
    end
    local look = self.db and self.db.groupLook
    if LOOKS[look] then return look end
    return (self.db and self.db.merge == false) and "separate" or "fused"
end

-- Sets (or clears, look = nil) the look of the group containing key
function ns:SetGroupOwnLook(key, look)
    local cfg = self.db.blocks[self:GetRoot(key)]
    if not cfg then return end
    cfg.look = LOOKS[look] and look or nil
    self:ReanchorAll()
    self:RequestLayout()
end

-- True if another block is docked to this block's group
function ns:IsInGroup(key)
    local root = self:GetRoot(key)
    for other in pairs(self.db.blocks) do
        if other ~= root and self:GetRoot(other) == root and self:GetDockTarget(other) then return true end
    end
    return false
end

function ns:SetGroupLook(look)
    self.db.groupLook = look
    self.db.merge = look ~= "separate"
    self:ReanchorAll()
    self:RequestLayout()
end

-- Gap between docked blocks: the joint width in "tiles" mode, else none. At least
-- 2 pixels, more than the tolerance that hides borders between touching blocks.
function ns:JointGap(key)
    if self:GetGroupLook(key) ~= "tiles" then return 0 end
    return math.max(2, self.db.jointGap or 3)
end

-- Anchors a docked block to its effective target. Vertical docks are
-- left-aligned, horizontal docks are top-aligned. Returns false if the block
-- is not docked (or its dock was dropped because it would form a loop).
-- Is frame a anchored, directly or through other frames, to frame b? (WoW refuses
-- an anchor from b to a then: "Cannot anchor to a region dependent on it")
local function DependsOn(a, b)
    local seen, queue = {}, { a }
    while #queue > 0 do
        local cur = table.remove(queue)
        if cur == b then return true end
        if not seen[cur] and cur ~= UIParent and cur.GetNumPoints then
            seen[cur] = true
            for i = 1, cur:GetNumPoints() or 0 do
                local _, rel = cur:GetPoint(i)
                if type(rel) == "string" then rel = _G[rel] end
                if rel then queue[#queue + 1] = rel end
            end
        end
    end
    return false
end

function ns:AnchorDocked(f, cfg)
    local target, side = self:GetDockTarget(f.key)
    if not target then return false end

    -- safety: never create an anchor loop
    local seen, cur = {}, target
    while cur and not seen[cur] do
        if cur == f.key then
            cfg.dock = nil
            return false
        end
        seen[cur] = true
        cur = self:GetDockTarget(cur)
    end

    target = self:GetEffectiveDock(f.key)
    f.anchoredTo = target
    local t = self.frames[target]
    local g = self:JointGap(f.key)
    f:ClearAllPoints() -- (the callers do it too: a safety, never an old point left)
    -- the block it would hang from is (still) anchored to it: that happened while the
    -- demo or a profile rebuilt every group, when a hidden block made two blocks point
    -- at each other. The caller then uses the saved free position; the next layout
    -- pass anchors it properly.
    if not t or t == f or DependsOn(t, f) then
        f.anchoredTo = nil
        return false
    end
    if side == "LEFT" then
        f:SetPoint("TOPRIGHT", t, "TOPLEFT", -g, 0)
    elseif side == "RIGHT" then
        f:SetPoint("TOPLEFT", t, "TOPRIGHT", g, 0)
    elseif side == "TOP" then
        f:SetPoint("BOTTOMLEFT", t, "TOPLEFT", 0, g)
    else
        f:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -g)
    end
    return true
end

-- Detaches a block while keeping its on-screen position
-- (saved as TOPLEFT relative to UIParent's BOTTOMLEFT)
function ns:Detach(key)
    local f, cfg = self.frames[key], self.db.blocks[key]
    if not cfg or not cfg.dock then return end
    local l, b, r, t
    if f then l, b, r, t = self:GetRectUI(f) end
    -- the block keeps the scale of the group it leaves (scale is stored on roots)
    local groupScale = self.db.blocks[self:GetRoot(key)].scale
    cfg.dock = nil
    cfg.scale = groupScale
    if l then
        cfg.point = self:MakeRelativePoint(l, b, r, t, f:GetEffectiveScale() / UIParent:GetEffectiveScale())
    end
    if f and cfg.point then
        f:ClearAllPoints()
        f:SetPoint(cfg.point[1], UIParent, cfg.point[2], cfg.point[3], cfg.point[4])
    end
    self:RequestLayout()
end

-- Detaches every block docked directly to this one
function ns:DetachChildren(key)
    for k, cfg in pairs(self.db.blocks) do
        if cfg.dock and cfg.dock.to == key then self:Detach(k) end
    end
end

---------------------------------------------------------------------------
-- Moving
---------------------------------------------------------------------------
-- Starts a drag: Shift detaches the grabbed block and moves it alone (with its
-- subtree, which stays anchored to it); otherwise the group's root is moved.
function ns:BeginDrag(f)
    if self:IsLocked() or self:IsFrozen(f.key) then return end
    self:PushUndo()
    local mover = f
    if IsShiftKeyDown() then
        self:Detach(f.key)
        if self.db.blocks[f.key] then self.db.blocks[f.key].anchor = nil end
    else
        mover = self.frames[self:GetRoot(f.key)] or f
    end
    f.dragMoved = true -- a drag is not a Ctrl+click
    self.dragging = mover
    mover:StartMoving()
    self:StartGuides(mover)
end

-- Ends a drag and lets SnapAndSave snap/dock and save the moved frame
function ns:EndDrag(f)
    -- no drag started (locked, or frozen group refused in BeginDrag): nothing to save
    if not self.dragging then return end
    local mover = self.dragging
    self.dragging = nil
    mover:StopMovingOrSizing()
    self:StopGuides()
    if not self:IsLocked() then self:SnapAndSave(mover) end
end

-- Looks for a block the dropped block is touching (within DOCK_DISTANCE).
-- left, top, w, h: position of the dropped block after snapping; exclude: its group.
-- A side is a candidate only if the blocks overlap by more than a third of the
-- smaller one along that side. Returns the closest { to, side } and its distance.
-- The block docked on that side of targetKey (a block of its own group), or nil
local function DockedOn(self, targetKey, side, ignore)
    for k, cfg in pairs(self.db.blocks) do
        if not ignore[k] and cfg.dock and cfg.dock.to == targetKey and cfg.dock.side == side then return k end
    end
end

-- allowInsert: the moved block is alone (no group): it may be slipped between two merged
-- blocks (dropped against a side already taken, it takes that place and the block that was
-- there docks to it). Returns { to, side, insert = key of the block pushed along } or nil.
function ns:FindDock(left, top, w, h, exclude, allowInsert)
    -- all coordinates in UIParent units (blocks can have different scales)
    local right, bottom = left + w, top - h
    local best, bestDist = nil, DOCK_DISTANCE + 1
    -- a group with a second row hanging below (above) it: that row lives along its bottom
    -- (top) side, so nothing may dock there (it would sit on the row and mix both groups)
    local hangSide = {}
    for k, cfg in pairs(self.db.blocks) do
        local target = not exclude[k] and cfg.anchor and ns.HangTarget(cfg.anchor)
        if target and self.db.blocks[target] then
            hangSide[self:GetRoot(target)] = cfg.anchor.below and "BOTTOM" or "TOP"
        end
    end
    for key, other in pairs(self.frames) do
        if not exclude[key] and self.db.blocks[key] and other:IsShown() and other:GetLeft()
            and not self:IsFrozen(key) then -- a frozen group accepts no new block
            local ol, ob, or_, ot = self:GetRectUI(other)
            local vOverlap = math.min(top, ot) - math.max(bottom, ob)
            local hOverlap = math.min(right, or_) - math.max(left, ol)
            local candidates = {}
            -- a row hanging below (above) another group: its top (bottom) side faces that
            -- group, and the row moves when its blocks hide, so nothing may dock there.
            -- A row placed once (anchor.fixed) no longer moves: blocks may dock on it.
            local hang = self.db.blocks[self:GetRoot(key)].anchor
            local blockedSide = hang and not hang.fixed and (hang.below and "TOP" or (hang.above and "BOTTOM"))
            if vOverlap > math.min(h, ot - ob) / 3 then
                candidates.RIGHT = math.abs(left - or_)
                candidates.LEFT = math.abs(right - ol)
            end
            if hOverlap > math.min(w, or_ - ol) / 3 then
                candidates.TOP = math.abs(bottom - ot)
                candidates.BOTTOM = math.abs(top - ob)
            end
            if blockedSide then candidates[blockedSide] = nil end
            local hung = hangSide[self:GetRoot(key)]
            if hung then candidates[hung] = nil end
            for side, dist in pairs(candidates) do
                if dist < bestDist then
                    if not SideOccupied(self, key, side, exclude) then
                        best, bestDist = { to = key, side = side }, dist
                    elseif allowInsert then
                        local pushed = DockedOn(self, key, side, exclude)
                        if pushed then best, bestDist = { to = key, side = side, insert = pushed }, dist end
                    end
                end
            end
        end
    end
    return best, bestDist
end

-- Reverses the dock links between newRoot and the group's current head:
-- newRoot becomes the head (the group keeps its shape).
-- Example: A <-RIGHT- B <-RIGHT- C, Reroot(C) gives C <-LEFT- B <-LEFT- A.
function ns:Reroot(newRoot)
    local path, cur, seen = { newRoot }, newRoot, {}
    while not seen[cur] do
        seen[cur] = true
        local target = self:GetDockTarget(cur)
        if not target then break end
        table.insert(path, target)
        cur = target
    end
    local sides = {}
    for i = 1, #path - 1 do sides[i] = self.db.blocks[path[i]].dock.side end
    self.db.blocks[newRoot].dock = nil
    for i = 1, #path - 1 do
        local cfg = self.db.blocks[path[i + 1]]
        cfg.dock = { to = path[i], side = OPPOSITE[sides[i]] }
        cfg.anchor = nil
    end
end

---------------------------------------------------------------------------
-- Sizes: minimum = text, then equal heights / widths inside a group
---------------------------------------------------------------------------
local pending = false

-- Schedules one UpdateLayout on the next frame (repeated calls are coalesced)
function ns:RequestLayout()
    if pending or not self.built then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        ns:UpdateLayout()
    end)
end

-- Minimum size of a block: text (or icon) plus padding and border inset,
-- never smaller than the configured width/height. Returns w, h.
local function NeededSize(f, cfg)
    local inset, iconSize = f.inset or 0, f.iconSize or 0
    local w
    if f.iconOnly then
        w = iconSize + 8 + 2 * inset
    else
        local text = f.text
        local tw = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or text:GetStringWidth()
        w = math.ceil(tw or 0) + 8 + 2 * inset + (cfg.showIcon and (iconSize + 4) or 0)
    end
    local th = f.text:GetStringHeight() or 0
    local h = math.ceil(math.max(th, cfg.showIcon and iconSize or 0)) + 4 + 2 * inset
    -- "Fit width to text" unchecked: fixed width (text that is too long is clipped)
    if cfg.autoWidth == false then return cfg.width, math.max(cfg.height, h) end
    return math.max(cfg.width, w), math.max(cfg.height, h)
end

-- Union-find lookup: representative of k's set (no path compression)
local function Find(parent, k)
    while parent[k] ~= k do k = parent[k] end
    return k
end

-- Full layout pass (see the header for the step order)
function ns:UpdateLayout()
    if not self.db then return end
    local need = {}
    for _, key in ipairs(self:GetBlockKeys()) do
        local f, cfg = self.frames[key], self.db.blocks[key]
        -- hidden but turned on: it keeps its place, at the size it had when shown
        -- (cfg.slotW, saved: the same place after a reload)
        if f and cfg and (f:IsShown() or self:HasPlace(key)) then
            local w, h = NeededSize(f, cfg)
            if f:IsShown() then
                if not cfg.slotW or math.abs(cfg.slotW - w) > 0.5 then cfg.slotW = w end
            else
                w = math.max(w, cfg.slotW or 0)
            end
            need[key] = { w, h }
        end
    end

    -- a block whose target was hidden or shown again re-docks in the right place
    for key in pairs(need) do
        local f = self.frames[key]
        if self:GetDockTarget(key) and f.anchoredTo ~= self:GetEffectiveDock(key) then
            f:ClearAllPoints()
            local cfg = self.db.blocks[key]
            -- AnchorDocked refuses (and clears the dock) if it would create an anchor loop:
            -- fall back to the saved free position so the block is never left unanchored
            if not self:AnchorDocked(f, cfg) and cfg.point then
                f:SetPoint(cfg.point[1], UIParent, cfg.point[2], cfg.point[3], cfg.point[4])
            end
        end
    end

    -- Blocks turned off that others still depend on shrink to no width, so their
    -- neighbours close the gap (a hidden block that is turned on keeps its place)
    for key, cfg in pairs(self.db.blocks) do
        local f = self.frames[key]
        if f and not need[key] and (cfg.anchor or self:HasDependents(key)) then
            -- width only: a second row hangs below this block, so its height must stay
            if f:GetWidth() > 0.02 then f:SetWidth(0.01) end
        end
    end

    -- Groups that share a width ("fill"): the base bar shares the width of
    -- FlareUI's XP bar, the second row shares the base bar's width. Extra width is
    -- spread over the visible blocks (rounding remainder to the first one). Done in
    -- two passes because the second row needs the base bar's final widths.
    local function GroupMembers(rootKey)
        local members, horizontal = {}, true
        for k in pairs(need) do
            if self:GetRoot(k) == rootKey then
                local _, side = self:GetDockTarget(k)
                if side and not HORIZONTAL[side] then horizontal = false end
                table.insert(members, k)
            end
        end
        table.sort(members)
        return members, horizontal
    end
    -- spacersOnly: in a bar stretched over the screen width, only its spacers take
    -- the extra room (the blocks keep their size); without spacers, all share it
    -- atMostDouble: a second row only shares the base bar's width when its blocks at
    -- most double their width; otherwise (one or two blocks left, the others hidden
    -- because empty) it keeps their own sizes, centered under the bar
    local function Fill(rootKey, total, spacersOnly, atMostDouble)
        local members, horizontal = GroupMembers(rootKey)
        if not horizontal or #members == 0 then return end
        local sum = 0
        for _, k in ipairs(members) do sum = sum + need[k][1] end
        sum = sum + self:JointGap(rootKey) * (#members - 1) -- the joints between tiles take their share
        local extra = math.floor(total - sum)
        if extra <= 0 then return end
        if atMostDouble and extra > sum then return end
        local takers = members
        if spacersOnly then
            local spacers = {}
            for _, k in ipairs(members) do
                if ns.IsSpacerKey(k) then table.insert(spacers, k) end
            end
            if #spacers > 0 then takers = spacers end
        end
        local each = math.floor(extra / #takers)
        for _, k in ipairs(takers) do need[k][1] = need[k][1] + each end
        local first = (need[rootKey] and not spacersOnly) and rootKey or takers[1]
        need[first][1] = need[first][1] + extra - each * #takers
    end
    -- bars stuck to the top or bottom edge and stretched over the screen width
    for key, cfg in pairs(self.db.blocks) do
        local f = self.frames[key]
        if cfg.stretch and f and not self:GetDockTarget(key) then
            Fill(key, UIParent:GetWidth() * UIParent:GetEffectiveScale() / f:GetEffectiveScale(), true)
        end
    end
    for _, pass in ipairs({ "frame", "below" }) do
        for key, cfg in pairs(self.db.blocks) do
            local a, f = cfg.anchor, self.frames[key]
            if a and a.fill and f and not self:GetDockTarget(key) then
                local name = ns.AnchorFrameName(a)
                if pass == "frame" and name and _G[name] and _G[name].GetWidth then
                    -- the frame's width, converted to this block's own units
                    local frame = _G[name]
                    Fill(key, frame:GetWidth() * frame:GetEffectiveScale() / f:GetEffectiveScale())
                elseif pass == "below" and ns.HangTarget(a) and self.db.blocks[ns.HangTarget(a)] then
                    local baseMembers = GroupMembers(self:GetRoot(ns.HangTarget(a)))
                    local total = 0
                    for _, k in ipairs(baseMembers) do total = total + need[k][1] end
                    -- the joints between the bar's tiles are part of its width
                    total = total + self:JointGap(self:GetRoot(ns.HangTarget(a))) * math.max(0, #baseMembers - 1)
                    Fill(key, total, false, true)
                end
            end
        end
    end
    -- A second row placed once (anchor.fixed) that lines up with its bar at both ends
    -- stays flush with it: when a text changes width by a few pixels, the narrower of
    -- the two widens to the other's width. A row that does not line up keeps its size.
    local FLUSH = 8
    local function RowSpan(rootKey)
        local members, horizontal = GroupMembers(rootKey)
        if not horizontal or #members == 0 then return nil end
        local total, left = self:JointGap(rootKey) * (#members - 1), nil
        for _, k in ipairs(members) do
            total = total + need[k][1]
            local l = self:GetRectUI(self.frames[k])
            if l and (not left or l < left) then left = l end
        end
        return total, left
    end
    for key, cfg in pairs(self.db.blocks) do
        local a, f = cfg.anchor, self.frames[key]
        local base = a and a.fixed and ns.HangTarget(a)
        if base and f and need[key] and self.db.blocks[base] and not self:GetDockTarget(key) then
            local baseRoot = self:GetRoot(base)
            local rowW, rowL = RowSpan(key)
            local barW, barL = RowSpan(baseRoot)
            if rowW and barW and rowL and barL and math.abs(rowL - barL) <= 3
                and math.abs(rowW - barW) <= FLUSH then
                if rowW < barW then Fill(key, barW) elseif barW < rowW then Fill(baseRoot, rowW) end
            end
        end
    end

    -- sets of equal height (horizontal merge) and equal width (vertical merge),
    -- built with union-find over the effective dock links between visible blocks
    local parentW, parentH = {}, {}
    for key in pairs(need) do parentW[key], parentH[key] = key, key end
    for key in pairs(need) do
        local target, side = self:GetEffectiveDock(key)
        if target and need[target] then
            local parent = HORIZONTAL[side] and parentH or parentW
            local a, b = Find(parent, key), Find(parent, target)
            if a ~= b then parent[a] = b end
        end
    end

    -- each set takes the size of its largest member
    -- A spacer adapts to the blocks it is merged with but never stretches them:
    -- e.g. a long separator line docked under a block takes that block's width
    -- instead of widening it. (A set made only of spacers keeps their own sizes.)
    local realW, realH = {}, {}
    for key in pairs(need) do
        if not ns.IsSpacerKey(key) then
            realW[Find(parentW, key)] = true
            realH[Find(parentH, key)] = true
        end
    end
    local maxW, maxH = {}, {}
    for key, n in pairs(need) do
        local rw, rh = Find(parentW, key), Find(parentH, key)
        local spacer = ns.IsSpacerKey(key)
        maxW[rw] = math.max(maxW[rw] or 0, (spacer and realW[rw]) and 0 or n[1])
        maxH[rh] = math.max(maxH[rh] or 0, (spacer and realH[rh]) and 0 or n[2])
    end
    local width = {}
    for key in pairs(need) do
        local f = self.frames[key]
        local w, h = maxW[Find(parentW, key)], maxH[Find(parentH, key)]
        -- sizes rounded to whole screen pixels, so thin borders stay sharp
        local pw, ph = self:PixelSize(w, f), self:PixelSize(h, f)
        width[key] = pw
        if math.abs(f:GetWidth() - pw) > 0.01 or math.abs(f:GetHeight() - ph) > 0.01 then
            f:SetSize(pw, ph)
            self:ResizeBar(f)
        end
    end

    -- hidden group heads count as zero-width blocks when centering their group
    for key, cfg in pairs(self.db.blocks) do
        if cfg.anchor and not width[key] and self.frames[key] then width[key] = 0 end
    end
    self:CenterAnchoredGroups(width)
    self:PlaceStretchedGroups(width)
    self:UpdateSeams(need)
    -- second pass a little later, once all positions have settled
    -- (avoids a border that is not redrawn in an unusual arrangement)
    self.seamSet = need
    if not self.seamRedrawQueued then
        self.seamRedrawQueued = true
        C_Timer.After(0.2, function()
            ns.seamRedrawQueued = false
            -- the border cache takes positions into account: only blocks that
            -- actually moved in the meantime are redrawn
            if ns.seamSet then ns:UpdateSeams(ns.seamSet) end
        end)
    end
    self:RequestOverlaySync()
end

---------------------------------------------------------------------------
-- Shared borders: hidden between two merged blocks
---------------------------------------------------------------------------
local SEAM_TOL = 1.5

-- Merges portions [a, b] of a side of length len: clamps them to [0, len],
-- snaps ends within SEAM_TOL of the side's extremities, sorts, joins portions
-- that touch or overlap, and drops slivers shorter than SEAM_TOL.
local function MergeIntervals(list, len)
    for _, iv in ipairs(list) do
        iv[1] = math.max(0, iv[1])
        iv[2] = math.min(len, iv[2])
        if iv[1] <= SEAM_TOL then iv[1] = 0 end
        if iv[2] >= len - SEAM_TOL then iv[2] = len end
    end
    table.sort(list, function(x, y) return x[1] < y[1] end)
    local out = {}
    for _, iv in ipairs(list) do
        local last = out[#out]
        if last and iv[1] <= last[2] + SEAM_TOL then
            last[2] = math.max(last[2], iv[2])
        elseif iv[2] - iv[1] > SEAM_TOL then
            table.insert(out, { iv[1], iv[2] })
        end
    end
    return out
end

-- Is position pos along a side touched (within SEAM_TOL)?
local function Covered(list, pos)
    for _, iv in ipairs(list) do
        if pos >= iv[1] - SEAM_TOL and pos <= iv[2] + SEAM_TOL then return true end
    end
    return false
end

-- Computes, for every active block, its coverage intervals per side and its
-- concave corner notches, then hands them to ApplySeams.
-- active: set of block keys (the visible blocks from UpdateLayout).
function ns:UpdateSeams(active)
    -- rectangles of the displayed blocks, with their group (root)
    -- (screen coordinates, bottom-left origin: b < t, l < r)
    local rects = {}
    for key in pairs(active) do
        local f = self.frames[key]
        local l, b, r, t = f:GetLeft(), f:GetBottom(), f:GetRight(), f:GetTop()
        if f:IsShown() and l then rects[key] = { l = l, b = b, r = r, t = t, root = self:GetVisualRoot(key) } end
    end

    -- groups stuck to screen edges (cfg.edges on their root): the screen counts as
    -- a neighbour along those edges, so the border there disappears
    local edgesOf = {}
    for key, me in pairs(rects) do
        local rootCfg = self.db.blocks[self:GetRoot(key)]
        if rootCfg and rootCfg.edges then edgesOf[me.root] = rootCfg.edges end
    end

    -- is a point (just outside a corner) inside a block of the group? Off screen
    -- along a stuck edge counts as occupied (no notch drawn at the screen's corner)
    local function Occupied(root, x, y, sw, sh)
        local edges = edgesOf[root]
        if edges and ((edges.LEFT and x < 0) or (edges.RIGHT and x > sw)
            or (edges.BOTTOM and y < 0) or (edges.TOP and y > sh)) then return true end
        for _, o in pairs(rects) do
            if o.root == root and x > o.l and x < o.r and y > o.b and y < o.t then return true end
        end
        return false
    end

    for key in pairs(active) do
        local f, me = self.frames[key], rects[key]
        if me then
            local W, H = me.r - me.l, me.t - me.b
            local cov = { W = W, H = H, TOP = {}, BOTTOM = {}, LEFT = {}, RIGHT = {} }
            -- portions of each side touched by another block of the same group.
            -- hA..hB: horizontal overlap, measured from my left edge;
            -- vA..vB: vertical overlap, measured downward from my top edge.
            -- "separate" look: every block keeps its whole frame
            local fused = self:GetGroupLook(key) ~= "separate"
            for other, o in pairs(rects) do
                if fused and other ~= key and o.root == me.root then
                    local hA, hB = math.max(o.l, me.l) - me.l, math.min(o.r, me.r) - me.l
                    local vA, vB = me.t - math.min(o.t, me.t), me.t - math.max(o.b, me.b)
                    if hB - hA > SEAM_TOL then
                        if math.abs(o.b - me.t) <= SEAM_TOL then table.insert(cov.TOP, { hA, hB }) end
                        if math.abs(o.t - me.b) <= SEAM_TOL then table.insert(cov.BOTTOM, { hA, hB }) end
                    end
                    if vB - vA > SEAM_TOL then
                        if math.abs(o.r - me.l) <= SEAM_TOL then table.insert(cov.LEFT, { vA, vB }) end
                        if math.abs(o.l - me.r) <= SEAM_TOL then table.insert(cov.RIGHT, { vA, vB }) end
                    end
                end
            end
            -- screen size in this block's units, for the stuck edges
            local k = UIParent:GetEffectiveScale() / f:GetEffectiveScale()
            local sw, sh = UIParent:GetWidth() * k, UIParent:GetHeight() * k
            local edges = edgesOf[me.root]
            if edges then
                if edges.TOP and math.abs(me.t - sh) <= SEAM_TOL then table.insert(cov.TOP, { 0, W }) end
                if edges.BOTTOM and math.abs(me.b) <= SEAM_TOL then table.insert(cov.BOTTOM, { 0, W }) end
                if edges.LEFT and math.abs(me.l) <= SEAM_TOL then table.insert(cov.LEFT, { 0, H }) end
                if edges.RIGHT and math.abs(me.r - sw) <= SEAM_TOL then table.insert(cov.RIGHT, { 0, H }) end
            end
            for side, len in pairs({ TOP = W, BOTTOM = W, LEFT = H, RIGHT = H }) do
                cov[side] = MergeIntervals(cov[side], len)
            end
            -- concave corners at the block's own corners: both sides meeting at the
            -- corner are covered there, but nothing occupies the diagonal spot
            -- (tested 1 px outside the corner)
            cov.cornerNotch = {}
            local CX = { Left = me.l - 1, Right = me.r + 1 }
            local CY = { Top = me.t + 1, Bottom = me.b - 1 }
            for corner, sides in pairs(CORNERS) do
                local hEnd = sides[1] == "LEFT" and 0 or W     -- corner position along the top/bottom side
                local vEnd = sides[2] == "TOP" and 0 or H      -- corner position along the left/right side
                if Covered(cov[sides[2]], hEnd) and Covered(cov[sides[1]], vEnd) then
                    local cx = CX[sides[1] == "LEFT" and "Left" or "Right"]
                    local cy = CY[sides[2] == "TOP" and "Top" or "Bottom"]
                    if not Occupied(me.root, cx, cy, sw, sh) then cov.cornerNotch[corner] = true end
                end
            end
            self:ApplySeams(f, cov)
            self:DrawSeparators(f, cov)
        end
    end
    -- name tags of the unlock mode: no overlap between them, none off screen
    self:PlaceAllTags()
end

-- Block name tag (unlock mode): placed on a free side so it does not cover
-- a merged block; hidden if every side is taken (hovering shows the name).
-- Each entry: { side tested, tag anchor point, block anchor point, x, y },
-- tried in this order.
local TAG_POINTS = {
    { "TOP",    "BOTTOM", "TOP",    0, 2 },
    { "BOTTOM", "TOP",    "BOTTOM", 0, -2 },
    { "LEFT",   "RIGHT",  "LEFT",  -4, 0 },
    { "RIGHT",  "LEFT",   "RIGHT",  4, 0 },
}

-- rectangle (left, bottom, right, top) the tag would occupy at this position;
-- w, h: size of the tag in the block's own units
local function TagRect(f, p, w, h)
    local l, b, r, t = ns:GetRectUI(f) -- UIParent units: blocks may have different scales
    if not l then return end
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    w, h = w * k, h * k
    local cx, cy = (l + r) / 2, (b + t) / 2
    if p[1] == "TOP" then return cx - w / 2, t + 2, cx + w / 2, t + 2 + h end
    if p[1] == "BOTTOM" then return cx - w / 2, b - 2 - h, cx + w / 2, b - 2 end
    if p[1] == "LEFT" then return l - 4 - w, cy - h / 2, l - 4, cy + h / 2 end
    return r + 4, cy - h / 2, r + 4 + w, cy + h / 2
end

local function Overlap(l, b, r, t, ol, ob, orr, ot)
    return l < orr - 1 and r > ol + 1 and b < ot - 1 and t > ob + 1
end

-- Rectangle of the tag at position p, or nil if it cannot go there: it would leave the
-- screen, cover another displayed block, or cover a tag already placed (taken).
-- width: forced tag width (a shortened tag), else the full text width.
function ns:TagFits(f, p, width, taken)
    local w = width or f.tag:GetStringWidth() or 0
    local h = f.tag:GetStringHeight() or 0
    local l, b, r, t = TagRect(f, p, w, h)
    if not l then return nil end
    if l < 0 or b < 0 or r > UIParent:GetWidth() or t > UIParent:GetHeight() then return nil end
    for _, other in pairs(self.frames) do
        if other ~= f and other:IsShown() then
            local ol, ob, orr, ot = self:GetRectUI(other)
            if ol and Overlap(l, b, r, t, ol, ob, orr, ot) then return nil end
        end
    end
    for _, rect in ipairs(taken or {}) do
        if Overlap(l, b, r, t, rect[1], rect[2], rect[3], rect[4]) then return nil end
    end
    return { l, b, r, t }
end

-- older name, kept for callers outside this file
function ns:TagCovers(f, p) return self:TagFits(f, p) == nil end

-- Places the name tag on the first side that is not shared with a merged block (s[side])
-- and where it fits (see TagFits). If no side has room for the whole name, the name is
-- shortened to the block's width ("Composants de...") above or below it. Otherwise it is
-- hidden (hovering the block shows the name). taken: tags already placed in this pass.
function ns:PlaceTag(f, s, taken)
    if not f.tag then return end
    f.tag:ClearAllPoints()
    f.tag:SetWordWrap(false)
    f.tag:SetWidth(0) -- whole name
    f.tagHidden = true
    local rect
    for _, p in ipairs(TAG_POINTS) do
        if not s[p[1]] then
            rect = self:TagFits(f, p, nil, taken)
            if rect then
                f.tag:SetPoint(p[2], f, p[3], p[4], p[5])
                break
            end
        end
    end
    -- no room for the whole name: shortened to the block's width, above or below
    local short = math.floor((f:GetWidth() or 0) - 4)
    if not rect and short >= 24 and (f.tag:GetStringWidth() or 0) > short then
        for i = 1, 2 do
            local p = TAG_POINTS[i]
            if not s[p[1]] then
                rect = self:TagFits(f, p, short, taken)
                if rect then
                    f.tag:SetWidth(short)
                    f.tag:SetPoint(p[2], f, p[3], p[4], p[5])
                    break
                end
            end
        end
    end
    if rect then
        f.tagHidden = nil
        if taken then table.insert(taken, rect) end
    else
        f.tag:SetPoint("BOTTOM", f, "TOP", 0, 2)
    end
    self:ApplyLock(f)
end

-- Places every name tag again, top to bottom and left to right, so that no two tags
-- overlap and none leaves the screen (unlock mode). Called after each layout pass.
function ns:PlaceAllTags()
    local list = {}
    for _, f in pairs(self.frames) do
        if f.tag and f:IsShown() and self:GetRectUI(f) then table.insert(list, f) end
    end
    table.sort(list, function(a, b)
        local al, _, _, at = self:GetRectUI(a)
        local bl, _, _, bt = self:GetRectUI(b)
        if math.abs(at - bt) > 1 then return at > bt end
        return al < bl
    end)
    local taken = {}
    for _, f in ipairs(list) do self:PlaceTag(f, f.sharedSet or {}, taken) end
end

local SIDES = { "TOP", "BOTTOM", "LEFT", "RIGHT" }

-- Copies a border piece (or the background) into a texture pool on the frame.
-- pool: f[pool] table name; id: slot in the pool (textures are reused);
-- src: texture to copy; name/e/along (optional): edge name, border thickness
-- and piece length, used to tile a classic border edge to the right length.
-- Returns the texture, shown and with its points cleared.
local function CopyPiece(f, pool, id, src, name, e, along)
    f[pool] = f[pool] or {}
    local tex = f[pool][id]
    if not tex then
        tex = f:CreateTexture()
        f[pool][id] = tex
    end
    tex:SetDrawLayer(src:GetDrawLayer())
    local atlas = src.GetAtlas and src:GetAtlas()
    if atlas then
        -- as Blizzard's NineSlice does it: the mirroring (texture coordinates) and the
        -- tiling first, then the atlas. A bottom edge is often the top edge mirrored, and
        -- tiling set after the atlas repeated the wrong part of the sheet (thin vertical
        -- marks along the bottom of a block over a short second row)
        local ulx, uly, _, lly, urx = src:GetTexCoord()
        local flipH = ulx and urx and ulx > urx
        local flipV = uly and lly and uly > lly
        tex:SetTexCoord(flipH and 1 or 0, flipH and 0 or 1, flipV and 1 or 0, flipV and 0 or 1)
        if src.GetHorizTile then
            tex:SetHorizTile(src:GetHorizTile())
            tex:SetVertTile(src:GetVertTile())
        end
        tex:SetAtlas(atlas, true)
    elseif name and e and e > 0 then
        -- border tile at the right length (repeated if longer than one tile); the tile
        -- count is in screen pixels, as in Blizzard's Backdrop.lua
        tex:SetTexture(src:GetTexture(), "REPEAT", "REPEAT")
        tex:SetTexCoord(EdgeCoords(name, along * f:GetEffectiveScale() / e))
    else
        tex:SetTexture(src:GetTexture())
        tex:SetTexCoord(0, 1, 0, 1)
    end
    tex:SetVertexColor(src:GetVertexColor())
    tex:ClearAllPoints()
    tex:Show()
    return tex
end

-- Hides every texture of a pool
-- Separators: a thin line where two merged blocks touch (cfg.separators). Drawn
-- by the block on its right and bottom sides only, so each line is drawn once,
-- a little shorter than the side so it does not touch the group's border.
-- Spacers draw none (a stretched bar stays clean).
function ns:DrawSeparators(f, cov)
    local cfg = self.db.blocks[f.key]
    f.separatorPool = f.separatorPool or {}
    local used = 0
    if cfg and cfg.separators and not ns.IsSpacerKey(f.key) then
        local c = cfg.separatorColor or { r = 1, g = 1, b = 1, a = 0.4 }
        if cfg.classColorSeparator then c = self:GetClassColor(c.a) or c end
        local thick = self:PixelSize(1, f)
        local function Line(side, a, b)
            local len = b - a
            local inset = math.min(6, len / 4)
            if len - 2 * inset < 2 then return end
            used = used + 1
            local tex = f.separatorPool[used]
            if not tex then
                tex = f:CreateTexture(nil, "OVERLAY", nil, 2)
                tex:SetTexture("Interface\\Buttons\\WHITE8X8")
                f.separatorPool[used] = tex
            end
            tex:SetVertexColor(c.r, c.g, c.b, c.a)
            tex:ClearAllPoints()
            if side == "RIGHT" then
                tex:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -(a + inset))
                tex:SetSize(thick, len - 2 * inset)
            else
                tex:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", a + inset, 0)
                tex:SetSize(len - 2 * inset, thick)
            end
            tex:Show()
        end
        for _, iv in ipairs(cov.RIGHT or {}) do Line("RIGHT", iv[1], iv[2]) end
        for _, iv in ipairs(cov.BOTTOM or {}) do Line("BOTTOM", iv[1], iv[2]) end
    end
    for i = used + 1, #f.separatorPool do f.separatorPool[i]:Hide() end
end

local function HidePool(f, pool)
    for _, tex in pairs(f[pool] or {}) do tex:Hide() end
end

-- Repositions the frame's border pieces (corners, edges, center).
-- cov: portions of each side touched by a block of the same group (see UpdateSeams);
-- nil means a standalone block (no shared sides).
-- Rebuilds only when the computed state differs from the cached one (f.seamKey).
function ns:ApplySeams(f, cov)
    cov = cov or { W = f:GetWidth(), H = f:GetHeight(), TOP = {}, BOTTOM = {}, LEFT = {}, RIGHT = {}, cornerNotch = {} }
    local W, H = cov.W, cov.H
    local LEN = { TOP = W, BOTTOM = W, LEFT = H, RIGHT = H }
    local full, any = {}, {}
    for _, side in ipairs(SIDES) do
        local list = cov[side]
        any[side] = #list > 0
        full[side] = #list == 1 and list[1][1] <= 0 and list[1][2] >= LEN[side]
    end
    f.sharedSet = any
    self:PlaceTag(f, any)

    local info = f.backdropInfo or f.nineSliceInfo
    if not info then
        HidePool(f, "notches"); HidePool(f, "segments"); HidePool(f, "patches")
        return
    end

    -- is the side touched at one of its ends?
    -- (TOP/BOTTOM: 0 = left end, W = right end; LEFT/RIGHT: 0 = top end, H = bottom end)
    local topL, topR = Covered(cov.TOP, 0), Covered(cov.TOP, W)
    local botL, botR = Covered(cov.BOTTOM, 0), Covered(cov.BOTTOM, W)
    local leftT, leftB = Covered(cov.LEFT, 0), Covered(cov.LEFT, H)
    local rightT, rightB = Covered(cov.RIGHT, 0), Covered(cov.RIGHT, H)

    -- concave corner joins: { notch corner, x offset, y offset }
    -- The corner name is both the notch rectangle's corner sitting on the concave
    -- point and the frame point it is anchored to; the offsets move it from the
    -- frame's matching corner to that point (WoW offsets: +x right, +y up).
    -- First the block-corner notches (offset 0, 0), then one notch at each end of
    -- a coverage interval that lies strictly inside its side (mid-edge transitions).
    local notches = {}
    for corner in pairs(cov.cornerNotch or {}) do table.insert(notches, { corner, 0, 0 }) end
    for _, side in ipairs(SIDES) do
        local len = LEN[side]
        for _, iv in ipairs(cov[side]) do
            local a, b = iv[1], iv[2]
            if side == "BOTTOM" or side == "TOP" then
                local s = side == "BOTTOM" and "Bottom" or "Top"
                if a > 0 then table.insert(notches, { s .. "Left", a, 0 }) end
                if b < len then table.insert(notches, { s .. "Right", b - W, 0 }) end
            else
                local s = side == "LEFT" and "Left" or "Right"
                if a > 0 then table.insert(notches, { "Top" .. s, 0, -a }) end
                if b < len then table.insert(notches, { "Bottom" .. s, 0, H - b }) end
            end
        end
    end

    -- no need to redo everything if nothing changed: cache key built from the
    -- reach, the intervals, the notches and (if any side is partial) the size
    local parts = { tostring(f.lineReach) }
    for _, side in ipairs(SIDES) do
        local s = side:sub(1, 1)
        for _, iv in ipairs(cov[side]) do s = s .. string.format("%.1f-%.1f,", iv[1], iv[2]) end
        table.insert(parts, s)
    end
    for _, n in ipairs(notches) do table.insert(parts, string.format("%s%.1f/%.1f", n[1], n[2], n[3])) end
    -- (the size always counts: pieces anchored to a corner drift when the block resizes)
    table.insert(parts, string.format("%.1fx%.1f", W, H))
    local seamKey = table.concat(parts, "|")

    -- information for /tessera debug ("~" marks a partially shared side)
    local shared = {}
    for _, side in ipairs(SIDES) do
        if any[side] then table.insert(shared, side:sub(1, 1) .. (full[side] and "" or "~")) end
    end
    f.sharedSides = table.concat(shared, "")
    local nl = {}
    for _, n in ipairs(notches) do table.insert(nl, n[1]) end
    f.notchList = table.concat(nl, ", ")

    if f.seamKey == seamKey and f.seamInfo == info then return end
    f.seamKey, f.seamInfo = seamKey, info
    HidePool(f, "notches"); HidePool(f, "segments"); HidePool(f, "patches")

    -- e = border thickness (edge size); 0 means the style has no border to fix
    local e
    if f.nineSliceInfo then
        e = f.nineSliceInfo.edge or 0
    else
        e = info.edgeFile and (info.edgeSize or 0) or 0
    end
    local inset = f.inset or 0

    if e > 0 then
        -- convex corners: hide a corner piece when either side meeting there is
        -- covered at that end
        if f.TopLeftCorner then f.TopLeftCorner:SetShown(not (topL or leftT)) end
        if f.TopRightCorner then f.TopRightCorner:SetShown(not (topR or rightT)) end
        if f.BottomLeftCorner then f.BottomLeftCorner:SetShown(not (botL or leftB)) end
        if f.BottomRightCorner then f.BottomRightCorner:SetShown(not (botR or rightB)) end

        -- ends of each side: run all the way to the corner if the neighbouring
        -- side is touched there (its corner piece is hidden), otherwise stop e
        -- short to leave room for the corner piece
        local ends = {
            TOP = { leftT, rightT }, BOTTOM = { leftB, rightB },
            LEFT = { topL, botL }, RIGHT = { topR, botR },
        }
        for _, side in ipairs(SIDES) do
            local name = EDGE_OF[side]
            local src = f[name]
            if src then
                local startIn, endIn = ends[side][1] and 0 or e, ends[side][2] and 0 or e
                src:ClearAllPoints()
                if side == "TOP" or side == "BOTTOM" then
                    src:SetPoint(side .. "LEFT", f, side .. "LEFT", startIn, 0)
                    src:SetPoint(side .. "RIGHT", f, side .. "RIGHT", -endIn, 0)
                else
                    src:SetPoint("TOP" .. side, f, "TOP" .. side, 0, -startIn)
                    src:SetPoint("BOTTOM" .. side, f, "BOTTOM" .. side, 0, endIn)
                end
                src:SetShown(not any[side])

                -- partially touched side: the original edge is hidden and border
                -- "segments" are drawn only on the free portions
                if any[side] and not full[side] then
                    local len, pos = LEN[side], 0
                    local free = {}
                    for _, iv in ipairs(cov[side]) do
                        if iv[1] > pos then table.insert(free, { pos, iv[1] }) end
                        pos = math.max(pos, iv[2])
                    end
                    if pos < len then table.insert(free, { pos, len }) end
                    for i, seg in ipairs(free) do
                        local a, b = seg[1], seg[2]
                        if a <= 0 then a = startIn end
                        if b >= len then b = len - endIn end
                        if b - a > 0.5 then
                            local tex = CopyPiece(f, "segments", side .. i, src, name, e, b - a)
                            if side == "TOP" or side == "BOTTOM" then
                                tex:SetSize(b - a, e)
                                tex:SetPoint(side .. "LEFT", f, side .. "LEFT", a, 0)
                            else
                                tex:SetSize(e, b - a)
                                tex:SetPoint("TOP" .. side, f, "TOP" .. side, 0, -a)
                            end
                        end
                    end
                end
            end
        end

        -- concave corner joins: extend the two borders arriving at the corner
        -- (a piece of horizontal border and a piece of vertical border) so they
        -- meet at a right angle like the rest of the frame.
        -- len = reach in pixels (f.lineReach x thickness, at least 1). Each notch
        -- draws a len x e horizontal piece and an e x len vertical piece, both
        -- anchored at the notch corner, forming an L inside this block.
        local len = math.max(1, math.floor(e * (f.lineReach or 0.5) + 0.5))
        for i, n in ipairs(notches) do
            local corner, ox, oy = n[1], n[2], n[3]
            local sides = CORNERS[corner]
            local point = corner:upper()
            local hName, vName = EDGE_OF[sides[2]], EDGE_OF[sides[1]]
            for j, spec in ipairs({ { hName, len, e }, { vName, e, len } }) do
                local name, w, h = spec[1], spec[2], spec[3]
                local src = f[name]
                if src then
                    local tex = CopyPiece(f, "notches", i .. ":" .. j, src, name, e, len)
                    tex:SetSize(w, h)
                    tex:SetPoint(point, f, point, ox, oy)
                end
            end
        end
    end

    -- background: reaches the frame edge on fully shared sides, otherwise stays
    -- inset inside the border
    if f.Center then
        f.Center:ClearAllPoints()
        f.Center:SetPoint("TOPLEFT", f, "TOPLEFT", full.LEFT and 0 or inset, full.TOP and 0 or -inset)
        f.Center:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", full.RIGHT and 0 or -inset, full.BOTTOM and 0 or inset)
        -- partially touched side: background "patches" extend it to the edge
        -- over the touched portions
        if inset > 0 then
            for _, side in ipairs(SIDES) do
                if any[side] and not full[side] then
                    for i, iv in ipairs(cov[side]) do
                        local a, b = iv[1], iv[2]
                        local tex = CopyPiece(f, "patches", side .. i, f.Center)
                        if side == "TOP" or side == "BOTTOM" then
                            tex:SetSize(b - a, inset)
                            tex:SetPoint(side .. "LEFT", f, side .. "LEFT", a, 0)
                        else
                            tex:SetSize(inset, b - a)
                            tex:SetPoint("TOP" .. side, f, "TOP" .. side, 0, -a)
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Centering anchored groups (base bar) on their reference frame
---------------------------------------------------------------------------
-- Horizontal position of each block of a group, with the head at x = 0
-- (propagated along effective dock links until nothing changes; vertical docks
-- share their target's x because they are left-aligned).
-- Returns the group's total width and the head's x offset from the group's left edge.
local function GroupExtent(self, head, width)
    local x = { [head] = 0 }
    local g = self:JointGap(head)
    -- a hidden block that others still hang from (e.g. a hidden block under the bar
    -- with a block on its right) is a zero-width link: its dependents must be placed
    -- too. Only for this computation: the width table itself is not changed.
    local function W(key)
        if width[key] then return width[key] end
        local f = self.frames[key]
        if f and not f:IsShown() then return 0 end
    end
    local changed = true
    while changed do
        changed = false
        for key in pairs(self.db.blocks) do
            if x[key] == nil and W(key) then
                local target, side = self:GetEffectiveDock(key)
                local tw = target and W(target)
                if tw and x[target] ~= nil then
                    if side == "RIGHT" then
                        x[key] = x[target] + tw + g
                    elseif side == "LEFT" then
                        x[key] = x[target] - W(key) - g
                    else
                        x[key] = x[target]
                    end
                    changed = true
                end
            end
        end
    end
    -- the extent counts the visible blocks only
    local minX, maxX = 0, 0
    for key, left in pairs(x) do
        if width[key] then
            minX = math.min(minX, left)
            maxX = math.max(maxX, left + width[key])
        end
    end
    -- total width, head's offset from the group's left edge, and every block's x
    -- relative to the head
    return maxX - minX, -minX, x
end

-- Bars stretched over the screen width: the group's left edge on the screen's
-- left edge, on the top or bottom edge (the head may not be the leftmost block)
function ns:PlaceStretchedGroups(width)
    for key in pairs(width) do
        local cfg, f = self.db.blocks[key], self.frames[key]
        if cfg.stretch and f and not self:GetDockTarget(key) then
            local _, headX = GroupExtent(self, key, width)
            local point = (cfg.stretch == "BOTTOM" and "BOTTOM" or "TOP") .. "LEFT"
            local p, rel, _, x, y = f:GetPoint(1)
            if p ~= point or rel ~= UIParent or math.abs((x or 0) - headX) > 0.5 or (y or 0) ~= 0 then
                f:ClearAllPoints()
                f:SetPoint(point, UIParent, point, headX, 0)
            end
        end
    end
end

-- Re-anchors each anchored group root so the whole group is centered on its
-- reference (offset from GetCenterOffset in Core.lua); only when the offset changed.
-- width: final width of each visible block, from UpdateLayout.
function ns:CenterAnchoredGroups(width)
    -- a second row hangs below (above) its whole base group: when a block of that group
    -- reaches lower (higher) than the block the row hangs from (a column merged into the
    -- bar), the row moves down (up) by that much instead of covering it
    for key in pairs(width) do
        local cfg, f = self.db.blocks[key], self.frames[key]
        local below = cfg and cfg.anchor and ns.HangTarget(cfg.anchor)
        local base = below and self.frames[below]
        if base and not self:GetDockTarget(key) then
            local _, bb, _, bt = self:GetRectUI(base)
            local baseRoot, depth = self:GetRoot(below), 0
            if bb then
                for k in pairs(width) do
                    local o = self.frames[k]
                    if k ~= below and o and self:GetRoot(k) == baseRoot then
                        local _, ob, _, ot = self:GetRectUI(o)
                        if ob and cfg.anchor.below then depth = math.max(depth, bb - ob)
                        elseif ot then depth = math.max(depth, ot - bt) end
                    end
                end
            end
            -- UIParent units to this block's own units
            local drop = math.floor(depth * UIParent:GetEffectiveScale() / f:GetEffectiveScale() + 0.5)
            if drop < 1 then drop = 0 end
            if (f.hangDrop or 0) ~= drop then
                f.hangDrop = drop
                f:ClearAllPoints()
                self:AnchorToFrame(f, cfg)
            end
        end
    end
    for key in pairs(width) do
        local cfg, f = self.db.blocks[key], self.frames[key]
        -- a row aligned on one edge (cfg.anchor.align) is not centered
        if cfg.anchor and not cfg.anchor.align and not self:GetDockTarget(key) then
            local groupWidth, headX = GroupExtent(self, key, width)
            local offset
            if ns.HangTarget(cfg.anchor) and cfg.anchor.fixed then
                -- placed once (FreezeAnchoredGroups): it stays where it is, to the pixel
                offset = cfg.anchor.offset or 0
            elseif ns.HangTarget(cfg.anchor) then
                -- second row: centered under the group of the block it hangs from.
                -- The offset is relative to that block's left edge.
                local below = ns.HangTarget(cfg.anchor)
                local baseRoot = self:GetRoot(below)
                if width[baseRoot] then
                    local baseWidth, baseHeadX, xs = GroupExtent(self, baseRoot, width)
                    local belowLeft = baseHeadX + (xs[below] or 0)
                    offset = math.floor((baseWidth - groupWidth) / 2 + headX - belowLeft + 0.5)
                end
            else
                offset = math.floor(self:GetCenterOffset(cfg, groupWidth, headX, f) + 0.5)
            end
            if offset and f.centerOffset ~= offset then
                f.centerOffset = offset
                f:ClearAllPoints()
                self:AnchorToFrame(f, cfg)
            end
        end
    end
end
