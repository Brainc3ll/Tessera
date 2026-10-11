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
function ns:GetEffectiveDock(key)
    local target, side = self:GetDockTarget(key)
    local seen = { [key] = true }
    while target and not seen[target] do
        local t = self.frames[target]
        if not t or t:IsShown() then break end
        seen[target] = true
        local nextTarget, nextSide = self:GetDockTarget(target)
        if not nextTarget or nextSide ~= side then break end
        target = nextTarget
    end
    return target, side
end

-- Head block of the group (the one that is docked to nothing)
function ns:GetRoot(key)
    local seen = {}
    while not seen[key] do
        seen[key] = true
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
        local seen, cur = {}, k
        while cur and not seen[cur] do
            if cur == key then
                set[k] = true
                break
            end
            seen[cur] = true
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
    local root, seen = self:GetRoot(key), {}
    while not seen[root] do
        seen[root] = true
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
-- Anchors a docked block to its effective target. Vertical docks are
-- left-aligned, horizontal docks are top-aligned. Returns false if the block
-- is not docked (or its dock was dropped because it would form a loop).
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
    if side == "LEFT" then
        f:SetPoint("TOPRIGHT", t, "TOPLEFT", 0, 0)
    elseif side == "RIGHT" then
        f:SetPoint("TOPLEFT", t, "TOPRIGHT", 0, 0)
    elseif side == "TOP" then
        f:SetPoint("BOTTOMLEFT", t, "TOPLEFT", 0, 0)
    else
        f:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, 0)
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
function ns:FindDock(left, top, w, h, exclude)
    -- all coordinates in UIParent units (blocks can have different scales)
    local right, bottom = left + w, top - h
    local best, bestDist = nil, DOCK_DISTANCE + 1
    for key, other in pairs(self.frames) do
        if not exclude[key] and self.db.blocks[key] and other:IsShown() and other:GetLeft()
            and not self:IsFrozen(key) then -- a frozen group accepts no new block
            local ol, ob, or_, ot = self:GetRectUI(other)
            local vOverlap = math.min(top, ot) - math.max(bottom, ob)
            local hOverlap = math.min(right, or_) - math.max(left, ol)
            local candidates = {}
            -- a row hanging below (above) another group: its top (bottom) side faces that
            -- group, and the row moves when its blocks hide, so nothing may dock there
            local hang = self.db.blocks[self:GetRoot(key)].anchor
            local blockedSide = hang and (hang.below and "TOP" or (hang.above and "BOTTOM"))
            if vOverlap > math.min(h, ot - ob) / 3 then
                candidates.RIGHT = math.abs(left - or_)
                candidates.LEFT = math.abs(right - ol)
            end
            if hOverlap > math.min(w, or_ - ol) / 3 then
                candidates.TOP = math.abs(bottom - ot)
                candidates.BOTTOM = math.abs(top - ob)
            end
            if blockedSide then candidates[blockedSide] = nil end
            for side, dist in pairs(candidates) do
                if dist < bestDist and not SideOccupied(self, key, side, exclude) then
                    best, bestDist = { to = key, side = side }, dist
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
        if f and cfg and f:IsShown() then need[key] = { NeededSize(f, cfg) } end
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

    -- Hidden blocks that others depend on (a hidden group head, or a head hidden
    -- because empty) shrink to no width, so their visible neighbours close the gap
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
    local function Fill(rootKey, total, spacersOnly)
        local members, horizontal = GroupMembers(rootKey)
        if not horizontal or #members == 0 then return end
        local sum = 0
        for _, k in ipairs(members) do sum = sum + need[k][1] end
        local extra = math.floor(total - sum)
        if extra <= 0 then return end
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
                if pass == "frame" and a.frame and _G[a.frame] and _G[a.frame].GetWidth then
                    -- the frame's width, converted to this block's own units
                    local frame = _G[a.frame]
                    Fill(key, frame:GetWidth() * frame:GetEffectiveScale() / f:GetEffectiveScale())
                elseif pass == "below" and ns.HangTarget(a) and self.db.blocks[ns.HangTarget(a)] then
                    local baseMembers = GroupMembers(self:GetRoot(ns.HangTarget(a)))
                    local total = 0
                    for _, k in ipairs(baseMembers) do total = total + need[k][1] end
                    Fill(key, total)
                end
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
            for other, o in pairs(rects) do
                if other ~= key and o.root == me.root then
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
        end
    end
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

-- rectangle (left, bottom, right, top) the tag would occupy at this position
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

-- would the tag cover another displayed block? (1 px tolerance)
function ns:TagCovers(f, p)
    local w, h = f.tag:GetStringWidth() or 0, f.tag:GetStringHeight() or 0
    local l, b, r, t = TagRect(f, p, w, h)
    if not l then return false end
    for _, other in pairs(self.frames) do
        if other ~= f and other:IsShown() then
            local ol, ob, orr, ot = self:GetRectUI(other)
            if ol and l < orr - 1 and r > ol + 1 and b < ot - 1 and t > ob + 1 then return true end
        end
    end
    return false
end

-- Places the name tag on the first side that is neither shared (s[side])
-- nor would cover another block; otherwise parks it on top and flags it hidden.
function ns:PlaceTag(f, s)
    if not f.tag then return end
    f.tag:ClearAllPoints()
    f.tagHidden = true
    for _, p in ipairs(TAG_POINTS) do
        if not s[p[1]] and not self:TagCovers(f, p) then
            f.tag:SetPoint(p[2], f, p[3], p[4], p[5])
            f.tagHidden = nil
            break
        end
    end
    if f.tagHidden then f.tag:SetPoint("BOTTOM", f, "TOP", 0, 2) end
    self:ApplyLock(f)
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
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetAtlas(atlas)
        if src.GetHorizTile then
            tex:SetHorizTile(src:GetHorizTile())
            tex:SetVertTile(src:GetVertTile())
        end
    elseif name and e and e > 0 then
        -- border tile at the right length (repeated if longer than one tile)
        tex:SetTexture(src:GetTexture(), "REPEAT", "REPEAT")
        tex:SetTexCoord(EdgeCoords(name, along / e))
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
    local full, any, partial = {}, {}, false
    for _, side in ipairs(SIDES) do
        local list = cov[side]
        any[side] = #list > 0
        full[side] = #list == 1 and list[1][1] <= 0 and list[1][2] >= LEN[side]
        if any[side] and not full[side] then partial = true end
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
    if partial then table.insert(parts, string.format("%.1fx%.1f", W, H)) end
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
    local changed = true
    while changed do
        changed = false
        for key in pairs(width) do
            if x[key] == nil then
                local target, side = self:GetEffectiveDock(key)
                if target and x[target] ~= nil and width[target] then
                    if side == "RIGHT" then
                        x[key] = x[target] + width[target]
                    elseif side == "LEFT" then
                        x[key] = x[target] - width[key]
                    else
                        x[key] = x[target]
                    end
                    changed = true
                end
            end
        end
    end
    local minX, maxX = 0, 0
    for key, left in pairs(x) do
        minX = math.min(minX, left)
        maxX = math.max(maxX, left + width[key])
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
    for key in pairs(width) do
        local cfg, f = self.db.blocks[key], self.frames[key]
        -- a row aligned on one edge (cfg.anchor.align) is not centered
        if cfg.anchor and not cfg.anchor.align and not self:GetDockTarget(key) then
            local groupWidth, headX = GroupExtent(self, key, width)
            local offset
            if ns.HangTarget(cfg.anchor) then
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
