-- Geometry check: loads the addon in the mock (tools/mock_run.lua) with real positions
-- (MOCK_GEOMETRY: every frame is placed from its anchor points, like the game), then lays
-- out every ready-made layout, in every group look, with blocks hidden and shown, and
-- reports any two visible blocks that overlap and any block outside the screen.
-- Run from the addon folder:   lua5.1 tools/geometry_check.lua .
local dir = arg[1] or "."
arg = { [0] = "tools/mock_run.lua", dir, "enUS" }
local realPrint = print
print = function() end
os.getenv = (function(get) return function(k) if k == "TESSERA_EXPORT_NS" then return "1" end return get(k) end end)(os.getenv)
dofile(dir .. "/tools/mock_run.lua")
local ns = assert(TESSERA_NS, "the mock did not export the addon")
TesseraDB = TesseraDB or {}
MOCK_GEOMETRY = true

local problems, checks = 0, 0
local function Visible()
    local list = {}
    for key, f in pairs(ns.frames) do
        local cfg = ns.db.blocks[key]
        if cfg and cfg.enabled and f:IsShown() and f:GetWidth() > 1 then
            local l, b, r, t = f:GetLeft(), f:GetBottom(), f:GetRight(), f:GetTop()
            list[#list + 1] = { key = key, l = l, b = b, r = r, t = t }
        end
    end
    return list
end
local function Check(label)
    checks = checks + 1
    ns:UpdateLayout()
    ns:UpdateLayout() -- (some passes need the sizes of the first one)
    local list = Visible()
    local found = {}
    for i = 1, #list do
        local a = list[i]
        if a.l < -0.5 or a.b < -0.5 or a.r > UIParent.__w + 0.5 or a.t > UIParent.__h + 0.5 then
            found[#found + 1] = ("%s off screen (%.0f,%.0f %.0f,%.0f)"):format(a.key, a.l, a.b, a.r, a.t)
        end
        for j = i + 1, #list do
            local c = list[j]
            local ox = math.min(a.r, c.r) - math.max(a.l, c.l)
            local oy = math.min(a.t, c.t) - math.max(a.b, c.b)
            if ox > 1 and oy > 1 then
                found[#found + 1] = ("%s overlaps %s (%.0f x %.0f)"):format(a.key, c.key, ox, oy)
            end
        end
    end
    if #found > 0 then
        problems = problems + #found
        realPrint("[" .. label .. "]")
        for k = 1, math.min(#found, 6) do realPrint("  " .. found[k]) end
        if #found > 6 then realPrint(("  ... and %d more"):format(#found - 6)) end
    end
end

-- only blocks of the same group must never overlap (random moves leave groups anywhere)
local function CheckGroups(label)
    checks = checks + 1
    ns:UpdateLayout()
    ns:UpdateLayout()
    local list, found = Visible(), {}
    for i = 1, #list do
        for j = i + 1, #list do
            local x, y = list[i], list[j]
            if ns.RawRoot(ns.db.blocks, x.key) == ns.RawRoot(ns.db.blocks, y.key) then
                local ox = math.min(x.r, y.r) - math.max(x.l, y.l)
                local oy = math.min(x.t, y.t) - math.max(x.b, y.b)
                if ox > 1 and oy > 1 then
                    found[#found + 1] = ("%s overlaps %s (%.0f x %.0f)"):format(x.key, y.key, ox, oy)
                end
            end
        end
    end
    if #found > 0 then
        problems = problems + #found
        realPrint("[" .. label .. "]")
        for k = 1, math.min(#found, 6) do realPrint("  " .. found[k]) end
    end
end

local function HideSome(step)
    local i = 0
    for _, key in ipairs(ns:GetBlockKeys()) do
        local f = ns.frames[key]
        i = i + 1
        if f and (i + step) % 3 == 0 then f:Hide() end
    end
end

for _, preset in ipairs(ns.PRESETS) do
    for _, look in ipairs({ "fused", "tiles", "separate" }) do
        ns:ResetProfile(preset)
        ns:SetGroupLook(look)
        Check(preset .. " / " .. look)
        for step = 0, 2 do
            ns:ResetProfile(preset)
            ns:SetGroupLook(look)
            ns:UpdateLayout()
            HideSome(step)
            Check(("%s / %s / hidden %d"):format(preset, look, step))
        end
    end
end
-- Random moves, as a player would make them: take a block out of its group and drop
-- it against a random side of another block (rows), hide or show blocks, change the
-- look; also random old dock trees (layouts of older versions) converted to rows.
math.randomseed(1)
local SIDES = { "LEFT", "RIGHT", "TOP", "BOTTOM" }
for run = 1, 12 do
    ns:ResetProfile(ns.PRESETS[(run % #ns.PRESETS) + 1])
    ns:SetGroupLook(({ "fused", "tiles", "separate" })[(run % 3) + 1])
    ns:UpdateLayout()
    local keys = {}
    for _, key in ipairs(ns:GetBlockKeys()) do
        if ns.db.blocks[key].enabled and ns.frames[key] and ns.frames[key]:IsShown() then keys[#keys + 1] = key end
    end
    for step = 1, 25 do
        local a, b = keys[math.random(#keys)], keys[math.random(#keys)]
        if a ~= b and ns.RawRoot(ns.db.blocks, a) ~= ns.RawRoot(ns.db.blocks, b) or math.random() < 0.3 then
            ns:RemoveFromGroup(a)
            if ns.RawRoot(ns.db.blocks, b) ~= a then ns:JoinRows(a, b, SIDES[math.random(4)], "CENTER") end
        end
        if math.random() < 0.2 then
            local f = ns.frames[keys[math.random(#keys)]]
            if f:IsShown() then f:Hide() else f:Show() end
        end
        ns:ReanchorAll()
        CheckGroups(("random %d step %d"):format(run, step))
        local rows = ns:GetRows(a)
        if #rows > ns.MAX_ROWS then
            problems = problems + 1
            realPrint("more than MAX_ROWS rows after random moves")
        end
    end
end
-- old dock trees: random trees over the shown blocks, every side, hanging rows
for run = 1, 20 do
    ns:ResetProfile("top")
    ns:UpdateLayout()
    local keys = {}
    for _, key in ipairs(ns:GetBlockKeys()) do
        if ns.db.blocks[key].enabled then keys[#keys + 1] = key end
    end
    for i = 2, #keys do
        local cfg = ns.db.blocks[keys[i]]
        cfg.anchor = nil
        if math.random() < 0.85 then
            cfg.dock = { to = keys[math.random(i - 1)], side = SIDES[math.random(4)] }
        else
            cfg.dock = nil
            cfg.point = { "CENTER", "CENTER", math.random(-400, 400), math.random(-250, 250) }
            if math.random() < 0.4 then cfg.anchor = { below = keys[math.random(i - 1)], fill = true, gap = 0 } end
        end
    end
    ns:ReanchorAll()
    ns:UpdateLayout()
    for _, key in ipairs(keys) do
        local cfg = ns.db.blocks[key]
        if cfg.anchor and ns.HangTarget(cfg.anchor) then
            problems = problems + 1
            realPrint("old tree " .. run .. ": a row still hangs: " .. key)
        end
    end
    -- nothing overlaps inside a group (groups placed at random may overlap each other)
    local list = Visible()
    for i = 1, #list do
        for j = i + 1, #list do
            local x, y = list[i], list[j]
            if ns.RawRoot(ns.db.blocks, x.key) == ns.RawRoot(ns.db.blocks, y.key) then
                local ox = math.min(x.r, y.r) - math.max(x.l, y.l)
                local oy = math.min(x.t, y.t) - math.max(x.b, y.b)
                if ox > 1 and oy > 1 then
                    problems = problems + 1
                    realPrint(("old tree %d: %s overlaps %s"):format(run, x.key, y.key))
                end
            end
        end
    end
    checks = checks + 1
end
realPrint(("Geometry check: %d layouts, %d problem(s)"):format(checks, problems))
os.exit(problems > 0 and 1 or 0)
