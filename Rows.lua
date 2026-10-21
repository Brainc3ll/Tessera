local ADDON, ns = ...

-- ========================================================================
-- Rows.lua: groups as stacks of rows
-- ========================================================================
--
-- A group is a list of ROWS, top to bottom; a row is a list of block keys, left
-- to right. Each row has an alignment (LEFT, CENTER, RIGHT) used when it is
-- narrower than the group.
--
-- Storage stays the one older versions read (exports and old versions keep
-- working): every block of a group has cfg.dock, written in a CANONICAL form
-- from the rows (WriteRows):
--   * in the head's row, blocks left of the head dock LEFT of their right
--     neighbour, blocks right of it dock RIGHT of their left neighbour;
--   * in another row, the first block docks BOTTOM (rows below the head) or
--     TOP (rows above) of the first block of the next row toward the head; the
--     other blocks dock RIGHT of their left neighbour.
-- The head (no dock) keeps the group's position and settings (point, anchor,
-- look, scale, frozen, edges, stretch) and cfg.rowAlign = { align of row 1, ... }.
--
-- Rows are read back by walking the dock tree on a grid (RIGHT = next column,
-- BOTTOM = next row...), which also turns any older layout into rows
-- (Normalize): blocks hanging anywhere become rows, a second row hanging under
-- a group (cfg.anchor.below / above) becomes that group's next (previous) row.
-- Every block is then placed relative to the head (Merge.lua, UpdateLayout):
-- no chain of anchors, no loop possible.
-- ========================================================================

ns.MAX_ROWS, ns.MAX_PER_ROW = 24, 24

local STEP = { RIGHT = { 0, 1 }, LEFT = { 0, -1 }, BOTTOM = { 1, 0 }, TOP = { -1, 0 } }
local ALIGNS = { LEFT = true, CENTER = true, RIGHT = true }
-- settings that belong to a group, saved on its head
local GROUP_FIELDS = { "point", "anchor", "edges", "stretch", "look", "scale", "frozen", "rowAlign", "rowAlignKeys" }

-- valid dock target of key in a blocks table (no frame needed)
local function Target(blocks, key)
    local c = blocks[key]
    local d = c and c.dock
    if type(d) == "table" and d.to ~= key and blocks[d.to] and STEP[d.side] then return d.to, d.side end
end

local function RawRoot(blocks, key)
    for _ = 1, 500 do
        local t = Target(blocks, key)
        if not t then return key end
        key = t
    end
    return key
end
ns.RawRoot = RawRoot

-- a dock loop (A on B, B on A) has no head: the loop is cut
local function BreakLoops(blocks)
    for key in pairs(blocks) do
        local seen, cur = {}, key
        while cur do
            if seen[cur] then
                blocks[cur].dock = nil
                break
            end
            seen[cur] = true
            cur = Target(blocks, cur)
        end
    end
end

local function Children(blocks)
    local children = {}
    for key in pairs(blocks) do
        local t, side = Target(blocks, key)
        if t then
            children[t] = children[t] or {}
            table.insert(children[t], { key = key, side = side })
        end
    end
    -- the same order on every run
    for _, list in pairs(children) do
        table.sort(list, function(a, b) return tostring(a.key) < tostring(b.key) end)
    end
    return children
end

-- Rows of the group of head: walks the dock tree on a grid. Returns rows (lists of
-- keys), aligns (one per row) and the head's row index.
local function ReadRows(blocks, head, children)
    children = children or Children(blocks)
    local pos, list, queue, seq = {}, {}, { head }, 0
    pos[head] = { 0, 0, 0 }
    while #queue > 0 do
        local k = table.remove(queue, 1)
        table.insert(list, k)
        for _, c in ipairs(children[k] or {}) do
            if not pos[c.key] then
                seq = seq + 1
                local s, p = STEP[c.side], pos[k]
                pos[c.key] = { p[1] + s[1], p[2] + s[2], seq }
                table.insert(queue, c.key)
            end
        end
    end
    table.sort(list, function(a, b)
        local pa, pb = pos[a], pos[b]
        if pa[1] ~= pb[1] then return pa[1] < pb[1] end
        if pa[2] ~= pb[2] then return pa[2] < pb[2] end
        return pa[3] < pb[3]
    end)
    local rows, rowOf, cols = {}, {}, {}
    local gmin, gmax
    for _, k in ipairs(list) do
        local r = pos[k][1]
        if not rowOf[r] then
            table.insert(rows, {})
            rowOf[r] = #rows
            cols[#rows] = { pos[k][2], pos[k][2] }
        end
        local i = rowOf[r]
        table.insert(rows[i], k)
        cols[i][2] = pos[k][2]
        gmin = math.min(gmin or pos[k][2], pos[k][2])
        gmax = math.max(gmax or pos[k][2], pos[k][2])
    end
    -- alignment: saved on the head, or guessed from the columns (older layouts)
    -- (an alignment is kept only for the row it was set on: rowAlignKeys holds the
    -- first block of each row; a layout changed by an older version is guessed again)
    local saved, savedKeys = blocks[head].rowAlign, blocks[head].rowAlignKeys
    local aligns = {}
    for i = 1, #rows do
        local a = type(saved) == "table" and type(savedKeys) == "table" and savedKeys[i] == rows[i][1] and saved[i]
        if not ALIGNS[a] then
            local c = cols[i]
            if c[1] == gmin then a = "LEFT"
            elseif c[2] == gmax then a = "RIGHT"
            else a = "CENTER" end
        end
        aligns[i] = a
    end
    return rows, aligns, rowOf[0]
end

-- Writes the canonical docks of a group from its rows (see the header)
local function WriteRows(blocks, head, rows, aligns)
    local hr, hi
    for r, row in ipairs(rows) do
        for i, k in ipairs(row) do
            if k == head then hr, hi = r, i end
        end
    end
    if not hr then return end
    for r, row in ipairs(rows) do
        for i, k in ipairs(row) do
            local c = blocks[k]
            if k ~= head then
                local to, side
                if r == hr then
                    if i < hi then to, side = row[i + 1], "LEFT" else to, side = row[i - 1], "RIGHT" end
                elseif i == 1 then
                    if r > hr then to, side = rows[r - 1][1], "BOTTOM" else to, side = rows[r + 1][1], "TOP" end
                else
                    to, side = row[i - 1], "RIGHT"
                end
                if not (c.dock and c.dock.to == to and c.dock.side == side) then
                    c.dock = { to = to, side = side }
                end
                c.rowAlign, c.rowAlignKeys, c.anchor = nil, nil, nil
            end
        end
    end
    local h = blocks[head]
    h.dock = nil
    if #rows > 1 then
        local list = {}
        local keys = {}
        for i = 1, #rows do
            list[i] = ALIGNS[aligns[i]] and aligns[i] or "LEFT"
            keys[i] = rows[i][1]
        end
        h.rowAlign, h.rowAlignKeys = list, keys
    else
        h.rowAlign, h.rowAlignKeys = nil, nil
    end
end

local function Snapshot(blocks)
    local parts = {}
    for key, c in pairs(blocks) do
        local d = c.dock
        local a = c.anchor
        table.insert(parts, tostring(key) .. ":" .. (d and (tostring(d.to) .. tostring(d.side)) or "")
            .. ":" .. (a and tostring(a.below or a.above or "") or "")
            .. ":" .. (type(c.rowAlign) == "table" and table.concat(c.rowAlign, ",") or "")
            .. ":" .. (type(c.rowAlignKeys) == "table" and table.concat(c.rowAlignKeys, ",") or ""))
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

-- Turns any layout (older dock trees, second rows hanging under a group) into
-- canonical rows. Works on a plain blocks table (a profile, an import, a preset).
-- Returns true if something changed.
function ns.NormalizeRows(blocks)
    if type(blocks) ~= "table" then return false end
    local before = Snapshot(blocks)
    BreakLoops(blocks)
    local children = Children(blocks)
    local groups = {} -- head -> { rows =, aligns = }
    for key in pairs(blocks) do
        if not Target(blocks, key) then
            local rows, aligns = ReadRows(blocks, key, children)
            groups[key] = { rows = rows, aligns = aligns }
        end
    end
    -- second rows hanging under (above) a group join it as its last (first) rows
    local into = {}
    local function Final(h)
        for _ = 1, 100 do
            if not into[h] then return h end
            h = into[h]
        end
        return h
    end
    for _ = 1, 50 do
        local done = true
        for head, g in pairs(groups) do
            local c = blocks[head]
            local a = c.anchor
            local base = type(a) == "table" and ns.HangTarget(a)
            if base and blocks[base] and not into[head] then
                local target = Final(RawRoot(blocks, base))
                if target ~= head and groups[target] then
                    local t = groups[target]
                    local align = (a.align == "LEFT" or a.align == "RIGHT") and a.align or "CENTER"
                    if a.above then
                        for i = #g.rows, 1, -1 do
                            table.insert(t.rows, 1, g.rows[i])
                            table.insert(t.aligns, 1, align)
                        end
                    else
                        for i = 1, #g.rows do
                            table.insert(t.rows, g.rows[i])
                            table.insert(t.aligns, align)
                        end
                    end
                    into[head] = target
                    for _, field in ipairs(GROUP_FIELDS) do
                        if field ~= "point" then c[field] = nil end
                    end
                    done = false
                else
                    a.below, a.above = nil, nil -- hangs under itself: plain position
                end
            end
        end
        if done then break end
    end
    for head, g in pairs(groups) do
        if not into[head] then WriteRows(blocks, head, g.rows, g.aligns) end
    end
    return Snapshot(blocks) ~= before
end

-- Same on any blocks table (a profile that is not the active one)
function ns.ReadRowsOf(blocks, key)
    local head = RawRoot(blocks, key)
    local rows, aligns, hr = ReadRows(blocks, head)
    return rows, aligns, head, hr
end
function ns.WriteRowsOf(blocks, head, rows, aligns) WriteRows(blocks, head, rows, aligns) end

---------------------------------------------------------------------------
-- Live helpers (the active profile)
---------------------------------------------------------------------------
-- Rows of the group containing key: rows, aligns, head, head's row index
function ns:GetRows(key)
    local blocks = self.db.blocks
    local head = RawRoot(blocks, key)
    local rows, aligns, hr = ReadRows(blocks, head)
    return rows, aligns, head, hr
end

function ns.FindInRows(rows, key)
    for r, row in ipairs(rows) do
        for i, k in ipairs(row) do
            if k == key then return r, i end
        end
    end
end

function ns:WriteRows(head, rows, aligns)
    WriteRows(self.db.blocks, head, rows, aligns)
end

-- Normalizes the active profile; true if it changed
-- The first time a profile is converted to rows (an older layout, not a fresh
-- one), a copy of it is kept as "<name> (1.0)" and the player is told.
function ns:NormalizeLayout()
    local db = self.db
    if not db or not db.blocks then return false end
    if db.rowsVersion then return ns.NormalizeRows(db.blocks) end
    local copy = db.initialized and not db.rowsBackupOf and self.DeepCopy(db)
    local changed = ns.NormalizeRows(db.blocks)
    db.rowsVersion = 1
    if changed and copy and self.sv and self.sv.profiles and self.profileName then
        local name = self.profileName .. " (1.0)"
        if not self.sv.profiles[name] then
            copy.rowsBackupOf = self.profileName
            self.sv.profiles[name] = copy
            self.Print(ns.L.ROWS_CONVERTED:format(name))
        end
    end
    return changed
end

-- Saved point of a block from where it is on the screen now (nil if not placed)
local function PointNow(self, key)
    local f = self.frames[key]
    if not f or not f:GetLeft() then return nil end
    local l, b, r, t = self:GetRectUI(f)
    return self:MakeRelativePoint(l, b, r, t, f:GetEffectiveScale() / UIParent:GetEffectiveScale())
end

-- Takes a block out of its group; the others close the gap. If it was the head,
-- the next block takes over the group's position and settings.
function ns:RemoveFromGroup(key)
    local blocks = self.db.blocks
    local cfg = blocks[key]
    if not cfg then return end
    local rows, aligns, head = self:GetRows(key)
    local alone = #rows == 1 and #rows[1] == 1
    if alone then return end
    local myPoint = PointNow(self, key)
    local r, i = ns.FindInRows(rows, key)
    table.remove(rows[r], i)
    if #rows[r] == 0 then
        table.remove(rows, r)
        table.remove(aligns, r)
    end
    if key == head then
        local newHead = (rows[r] and rows[r][1]) or rows[1][1]
        local n = blocks[newHead]
        for _, field in ipairs(GROUP_FIELDS) do n[field] = self.DeepCopy(cfg[field]) end
        n.point = PointNow(self, newHead) or n.point
        n.dock = nil
        head = newHead
        cfg.anchor, cfg.edges, cfg.stretch, cfg.look, cfg.frozen = nil, nil, nil, nil, nil
    else
        cfg.scale = blocks[head].scale -- keeps the scale of the group it leaves
    end
    WriteRows(blocks, head, rows, aligns)
    cfg.dock, cfg.rowAlign, cfg.rowAlignKeys = nil, nil, nil
    cfg.point = myPoint or cfg.point
end

-- Where a moved group (head movedHead) would go if dropped against side of target.
-- Returns the new rows, aligns and head of the target group, or nil and the key of
-- a message saying why it is refused.
-- align: alignment of a new row (TOP / BOTTOM)
function ns:PlanJoin(movedHead, target, side, align)
    local blocks = self.db.blocks
    local mrows, maligns = ReadRows(blocks, movedHead)
    local trows, taligns, thead = self:GetRows(target)
    local r, i = ns.FindInRows(trows, target)
    if not r then return nil, "ROWS_REFUSED" end
    if side == "LEFT" or side == "RIGHT" then
        local pos = side == "LEFT" and i or i + 1
        for j, row in ipairs(mrows) do
            local tr = r + j - 1
            if not trows[tr] then
                trows[tr] = {}
                taligns[tr] = maligns[j] or "CENTER"
            end
            local p = math.min(pos, #trows[tr] + 1)
            for n, k in ipairs(row) do table.insert(trows[tr], p + n - 1, k) end
        end
    else
        local at = side == "TOP" and r or r + 1
        for j, row in ipairs(mrows) do
            table.insert(trows, at + j - 1, row)
            table.insert(taligns, at + j - 1, (#mrows == 1 and align) or maligns[j] or "CENTER")
        end
    end
    if #trows > ns.MAX_ROWS then return nil, "ROWS_FULL_ROWS" end
    for _, row in ipairs(trows) do
        if #row > ns.MAX_PER_ROW then return nil, "ROWS_FULL_BLOCKS" end
    end
    -- a bar stretched over the screen width stays one row
    if blocks[thead].stretch and #trows > 1 then return nil, "ROWS_STRETCHED" end
    return trows, taligns, thead
end

-- Joins the moved group to the target group (see PlanJoin). Returns true, or false
-- and a message key.
function ns:JoinRows(movedHead, target, side, align)
    local rows, aligns, head = self:PlanJoin(movedHead, target, side, align)
    if not rows then return false, aligns end
    local m = self.db.blocks[movedHead]
    for _, field in ipairs(GROUP_FIELDS) do
        if field ~= "point" then m[field] = nil end
    end
    WriteRows(self.db.blocks, head, rows, aligns)
    return true
end

-- Sets the alignment of the row containing key
function ns:SetRowAlign(key, align)
    if not ALIGNS[align] then return end
    local rows, aligns, head = self:GetRows(key)
    local r = ns.FindInRows(rows, key)
    if not r or #rows < 2 then return end
    aligns[r] = align
    WriteRows(self.db.blocks, head, rows, aligns)
    self:RequestLayout()
end

function ns:GetRowAlign(key)
    local rows, aligns = self:GetRows(key)
    local r = ns.FindInRows(rows, key)
    return r and aligns[r], rows and #rows or 0
end

-- Text telling where a dropped block would go (placement mode)
-- plan: { target =, side = } from FindDock; refused: message key or nil
function ns:DescribeDrop(plan, refused)
    local L = ns.L
    if not plan then return L.ROWS_FREE end
    if refused then return "|cffff6060" .. (L[refused] or refused) .. "|r" end
    local rows, _, head = self:GetRows(plan.to)
    local r, i = ns.FindInRows(rows, plan.to)
    local function Shown(k)
        local f = self.frames[k]
        return f and f:IsShown() and not (self.dragSet and self.dragSet[k])
    end
    local name = function(k) return self:GetBlockName(k) end
    if plan.side == "LEFT" or plan.side == "RIGHT" then
        local row = rows[r]
        local before, after
        local pos = plan.side == "LEFT" and i or i + 1
        for n = pos - 1, 1, -1 do if Shown(row[n]) then before = row[n]; break end end
        for n = pos, #row do if Shown(row[n]) then after = row[n]; break end end
        local where = string.format(L.ROWS_ROW_N, r)
        if before and after then
            return where .. string.format(L.ROWS_BETWEEN, name(before), name(after))
        elseif before then
            return where .. string.format(L.ROWS_AFTER, name(before))
        elseif after then
            return where .. string.format(L.ROWS_BEFORE, name(after))
        end
        return where
    end
    local text = string.format(plan.side == "TOP" and L.ROWS_NEW_ABOVE or L.ROWS_NEW_BELOW, name(plan.to))
    if self:GetGroupLook(head) == "fused" then text = text .. "\n" .. L.ROWS_FUSED_NOTE end
    return text
end
