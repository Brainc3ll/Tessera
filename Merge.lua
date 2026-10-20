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
    if not self:GetDockTarget(f.key) then return false end
    -- every block of a group is placed relative to the group's head (rows, see
    -- Rows.lua); UpdateLayout computes the offsets
    local head = ns.RawRoot(self.db.blocks, f.key)
    local t = self.frames[head]
    f:ClearAllPoints() -- (the callers do it too: a safety, never an old point left)
    if not t or t == f or DependsOn(t, f) then
        f.anchoredTo = nil
        return false
    end
    if f.anchoredTo ~= head then f.rowX, f.rowY = nil, nil end
    f.anchoredTo = head
    f:SetPoint("TOPLEFT", t, "TOPLEFT", f.rowX or 0, f.rowY or 0)
    self:RequestLayout()
    return true
end

-- Takes a block out of its group while keeping its on-screen position
function ns:Detach(key)
    local f, cfg = self.frames[key], self.db.blocks[key]
    if not cfg or not (cfg.dock or self:HasDependents(key)) then return end
    self:RemoveFromGroup(key)
    self:ReanchorAll()
    if f and cfg.point then
        f:ClearAllPoints()
        f:SetPoint(cfg.point[1], UIParent, cfg.point[2], cfg.point[3], cfg.point[4])
    end
    self:RequestLayout()
end

-- A block about to be deleted: taken out of its group, the others stay together
function ns:DetachChildren(key)
    if self.db.blocks[key] then self:RemoveFromGroup(key) end
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
-- With rows, every side is open: LEFT / RIGHT inserts into the target's row at that
-- place (the next blocks move along), TOP / BOTTOM makes a new row (Rows.lua).
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
            if vOverlap > math.min(h, ot - ob) / 3 then
                local d = math.abs(left - or_)
                if d < bestDist then best, bestDist = { to = key, side = "RIGHT" }, d end
                d = math.abs(right - ol)
                if d < bestDist then best, bestDist = { to = key, side = "LEFT" }, d end
            end
            if hOverlap > math.min(w, or_ - ol) / 3 then
                local d = math.abs(bottom - ot)
                if d < bestDist then best, bestDist = { to = key, side = "TOP" }, d end
                d = math.abs(top - ob)
                if d < bestDist then best, bestDist = { to = key, side = "BOTTOM" }, d end
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

local LOOSE_GAP = 2 -- space around a short row of a fused group

-- Full layout pass, group by group: each group is a stack of rows (Rows.lua).
--   * hidden blocks leave their row (nothing to skip), an empty row disappears;
--   * every block of a row takes the row's height (the tallest block; a spacer
--     never makes a row taller);
--   * the group is as wide as its widest row (or the screen for a stretched bar,
--     or the reference frame for a bar that fills it). The other rows share that
--     width when their blocks at most double their width; otherwise they keep
--     their sizes and use their alignment ("fused": such a short row stands apart,
--     LOOSE_GAP off the others, so no border is ever partly shared);
--   * rows that all have the same number of blocks form a grid: columns line up;
--     a column (one block per row) always shares one width;
--   * positions are computed from the group's top-left corner and every block is
--     anchored to the head at its offset (no chain, no loop).
-- Results per head in ns.groupLayout: W, H (group size), hx, hy (head's offset from
-- the group's top-left corner, hy downward).
function ns:UpdateLayout()
    if not self.db then return end
    -- an older or edited layout is put back into canonical rows first
    if self:NormalizeLayout() then self:ReanchorAll() end
    local blocks = self.db.blocks
    local need = {}
    for _, key in ipairs(self:GetBlockKeys()) do
        local f, cfg = self.frames[key], blocks[key]
        if f and cfg and f:IsShown() then need[key] = { NeededSize(f, cfg) } end
    end

    -- hidden heads shrink to nothing (they keep the group's position)
    for key, cfg in pairs(blocks) do
        local f = self.frames[key]
        if f and not need[key] and (cfg.anchor or self:HasDependents(key)) then
            if f:GetWidth() > 0.02 or f:GetHeight() > 0.02 then f:SetSize(0.01, 0.01) end
        end
    end

    local heads = {}
    for key in pairs(need) do heads[ns.RawRoot(blocks, key)] = true end
    local layouts = {}
    for head in pairs(heads) do
        layouts[head] = self:LayoutGroup(head, need)
    end
    self.groupLayout = layouts

    self:CenterAnchoredGroups(layouts)
    self:PlaceStretchedGroups(layouts)
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

-- Lays out one group (see UpdateLayout). need: minimum size of each visible block.
function ns:LayoutGroup(head, need)
    local blocks = self.db.blocks
    local hf, hcfg = self.frames[head], blocks[head]
    if not hf or not hcfg then return nil end
    local rows, aligns, _, hr = self:GetRows(head)
    local look = self:GetGroupLook(head)
    local g = self:JointGap(head)
    local fused = look == "fused"

    local w, h = {}, {}
    local vis, rowH, nat = {}, {}, {}
    for r, row in ipairs(rows) do
        local list = {}
        for _, k in ipairs(row) do
            if need[k] then
                local f = self.frames[k]
                w[k], h[k] = self:PixelSize(need[k][1], f), self:PixelSize(need[k][2], f)
                table.insert(list, k)
            end
        end
        vis[r] = list
        local real, any = 0, 0
        for _, k in ipairs(list) do
            any = math.max(any, h[k])
            if not ns.IsSpacerKey(k) then real = math.max(real, h[k]) end
        end
        rowH[r] = real > 0 and real or any
    end

    -- grid: every shown row has the same number of blocks (2 rows or more)
    local count, shownRows = nil, 0
    local grid = true
    for r = 1, #rows do
        local n = #vis[r]
        if n > 0 then
            shownRows = shownRows + 1
            if count and n ~= count then grid = false end
            count = count or n
        end
    end
    local column = grid and shownRows >= 2 and count == 1
    if grid and shownRows >= 2 and count >= 2 then
        for c = 1, count do
            local cw = 0
            for r = 1, #rows do
                local k = vis[r][c]
                if k then cw = math.max(cw, w[k]) end
            end
            for r = 1, #rows do
                local k = vis[r][c]
                if k then w[k] = cw end
            end
        end
    end

    local maxNat = 0
    for r = 1, #rows do
        local sum = 0
        for _, k in ipairs(vis[r]) do sum = sum + w[k] end
        nat[r] = sum + g * math.max(0, #vis[r] - 1)
        maxNat = math.max(maxNat, nat[r])
    end

    -- width of the group
    local W, spacersOnly, fillRow = maxNat, false, nil
    if hcfg.stretch then
        W = math.max(maxNat, UIParent:GetWidth() * UIParent:GetEffectiveScale() / hf:GetEffectiveScale())
        spacersOnly = true
    elseif hcfg.anchor and hcfg.anchor.fill then
        local name = ns.AnchorFrameName(hcfg.anchor)
        local frame = name and _G[name]
        if frame and frame.GetWidth and frame:GetWidth() > 0 then
            W = math.max(maxNat, frame:GetWidth() * frame:GetEffectiveScale() / hf:GetEffectiveScale())
            fillRow = hr
        end
    end
    W = self:PixelSize(W, hf)

    -- x of each block in its row, y of each row
    local x, y = {}, {}
    local hx, hy
    local top, prevLoose = 0, false
    for r, row in ipairs(rows) do
        local list = vis[r]
        local extra = W - nat[r]
        local offset = 0
        local loose = false
        if #list > 0 and extra > 0.01 then
            -- a column (every row holds one block) always shares one width
            local justify = column or hcfg.stretch or r == fillRow or extra <= nat[r]
            -- fused: a row less than half as wide stands apart, just off the others,
            -- with its own frame (no partly shared border)
            loose = fused and not justify
            if justify then
                local takers = list
                if spacersOnly then
                    local spacers = {}
                    for _, k in ipairs(list) do
                        if ns.IsSpacerKey(k) then table.insert(spacers, k) end
                    end
                    if #spacers > 0 then takers = spacers end
                end
                local each = self:PixelSize(extra / #takers, hf)
                for n, k in ipairs(takers) do
                    if n < #takers then
                        w[k] = w[k] + each
                        extra = extra - each
                    else
                        w[k] = w[k] + extra
                    end
                end
            else
                local a = aligns[r]
                if a == "CENTER" then offset = self:PixelSize(extra / 2, hf)
                elseif a == "RIGHT" then offset = extra end
            end
        end
        if #list > 0 then
            if top > 0 and g == 0 and (loose or prevLoose) then top = top + LOOSE_GAP end
            prevLoose = loose
        end
        local cx = offset
        for _, k in ipairs(row) do
            if need[k] then
                x[k], y[k] = cx, top
                cx = cx + w[k] + g
            end
        end
        if #list > 0 then top = top + rowH[r] + g end
    end
    local H = math.max(0, top - g)
    if need[head] then
        hx, hy = x[head], y[head]
    else
        -- a hidden head (no width, no height) stays on the side of the group its
        -- saved point uses: a group in a right corner keeps its right edge there
        local p = (hcfg.anchor and (hcfg.anchor.bottom and "BOTTOMLEFT" or "TOPLEFT"))
            or (hcfg.stretch and (hcfg.stretch == "BOTTOM" and "BOTTOMLEFT" or "TOPLEFT"))
            or (type(hcfg.point) == "table" and hcfg.point[1]) or "TOPLEFT"
        hx = p:find("RIGHT") and W or (p:find("LEFT") and 0 or self:PixelSize(W / 2, hf))
        hy = p:find("BOTTOM") and H or (p:find("TOP") and 0 or self:PixelSize(H / 2, hf))
    end

    -- sizes and positions
    for r, row in ipairs(rows) do
        for _, k in ipairs(row) do
            local f = self.frames[k]
            if need[k] and f then
                local ph = rowH[r]
                if math.abs(f:GetWidth() - w[k]) > 0.01 or math.abs(f:GetHeight() - ph) > 0.01 then
                    f:SetSize(w[k], ph)
                    self:ResizeBar(f)
                end
                if k ~= head then
                    local s = hf:GetEffectiveScale() / f:GetEffectiveScale()
                    local ox, oy = (x[k] - hx) * s, -(y[k] - hy) * s
                    if f.anchoredTo ~= head or f.rowX ~= ox or f.rowY ~= oy or f:GetNumPoints() ~= 1 then
                        f:ClearAllPoints()
                        if hf ~= f and not DependsOn(hf, f) then
                            f:SetPoint("TOPLEFT", hf, "TOPLEFT", ox, oy)
                            f.anchoredTo, f.rowX, f.rowY = head, ox, oy
                        end
                    end
                end
            end
        end
    end
    return { W = W, H = H, hx = hx, hy = hy, rows = #rows }
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
-- Bars stretched over the screen width: the group's left edge on the screen's
-- left edge, on the top or bottom edge (the head may not be the leftmost block)
function ns:PlaceStretchedGroups(layouts)
    for key, lay in pairs(layouts) do
        local cfg, f = self.db.blocks[key], self.frames[key]
        if cfg and cfg.stretch and f and not self:GetDockTarget(key) then
            local point = (cfg.stretch == "BOTTOM" and "BOTTOM" or "TOP") .. "LEFT"
            local p, rel, _, x, y = f:GetPoint(1)
            if p ~= point or rel ~= UIParent or math.abs((x or 0) - lay.hx) > 0.5 or (y or 0) ~= 0 then
                f:ClearAllPoints()
                f:SetPoint(point, UIParent, point, lay.hx, 0)
            end
        end
    end
end

-- Re-anchors each anchored group head so the whole group is centered on its
-- reference (offset from GetCenterOffset in Core.lua); only when the offset changed.
function ns:CenterAnchoredGroups(layouts)
    for key, lay in pairs(layouts) do
        local cfg, f = self.db.blocks[key], self.frames[key]
        -- a row aligned on one edge (cfg.anchor.align) is not centered
        if cfg and f and cfg.anchor and not cfg.anchor.align and not ns.HangTarget(cfg.anchor)
            and not self:GetDockTarget(key) then
            local offset = math.floor(self:GetCenterOffset(cfg, lay.W, lay.hx, f) + 0.5)
            if f.centerOffset ~= offset then
                f.centerOffset = offset
                f:ClearAllPoints()
                self:AnchorToFrame(f, cfg)
            end
        end
    end
end
