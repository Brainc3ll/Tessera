-- Robustness test: the blocks built on WoW Forever's own systems (and the newest blocks)
-- must survive a game that changes under them. WoW Forever is in beta, and its release may
-- remove or change functions. The older blocks use long-standing game functions and are
-- protected by Core.lua (an error there is caught and printed once). This loads the
-- addon in the mock (tools/mock_run.lua), then calls every block's update, tooltip,
-- isEmpty and progress while the game's C_* namespaces are (1) missing, (2) returning nil,
-- (3) returning empty tables, (4) raising errors, and while the Get* / Unit* / Is* / Has*
-- functions return nil. Any Lua error is reported; the exit code is 1 if there is one.
-- Run from the addon folder:   lua5.1 tools/fuzz_blocks.lua .
local dir = arg[1] or "."
arg = { [0] = "tools/mock_run.lua", dir, "enUS" }
local realPrint = print
print = function() end
os.getenv = (function(get) return function(k) if k == "TESSERA_EXPORT_NS" then return "1" end return get(k) end end)(os.getenv)
dofile(dir .. "/tools/mock_run.lua")
print = realPrint
local ns = assert(TESSERA_NS, "the mock did not export the addon")

local namespaces, functions = {}, {}
for k, v in pairs(_G) do
    if type(k) == "string" then
        if k:match("^C_") and type(v) == "table" then namespaces[#namespaces + 1] = k end
        if type(v) == "function" and k ~= "GetTime" and (k:match("^Get") or k:match("^Unit") or k:match("^Is") or k:match("^Has")) then
            functions[#functions + 1] = k
        end
    end
end
local saved = {}
for _, n in ipairs(namespaces) do saved[n] = _G[n] end
for _, n in ipairs(functions) do saved[n] = _G[n] end

local function each(t, make) local r = {} for f in pairs(t) do r[f] = make end return r end
local MODES = {
    ["namespaces missing"] = function() for _, n in ipairs(namespaces) do _G[n] = nil end end,
    ["namespaces return nil"] = function() for _, n in ipairs(namespaces) do _G[n] = each(saved[n], function() return nil end) end end,
    ["namespaces return {}"] = function() for _, n in ipairs(namespaces) do _G[n] = each(saved[n], function() return {} end) end end,
    ["namespaces raise errors"] = function() for _, n in ipairs(namespaces) do _G[n] = each(saved[n], function() error("changed API") end) end end,
    ["functions return nil"] = function() for _, n in ipairs(functions) do _G[n] = function() return nil end end end,
}
-- blocks that must never raise an error, whatever the game returns
local STRICT = { legacy = true, comprehension = true, camping = true, honor = true, weaponSkills = true,
    profession1 = true, profession2 = true, cooking = true, firstAid = true, fishing = true,
    talents = true, regen = true, stats = true, loot = true, durability = true }
local tooltip = setmetatable({}, { __index = function() return function() end end })
local problems = 0
for name, apply in pairs(MODES) do
    apply()
    for _, key in ipairs(ns.order) do
        local mod, cfg = ns.modules[key], ns.db.blocks[key] or {}
        if STRICT[key] then
            for _, fn in ipairs({ "update", "tooltip", "isEmpty", "progress" }) do
                if mod[fn] then
                    local ok, err = pcall(mod[fn], fn == "tooltip" and tooltip or cfg, cfg)
                    if not ok then
                        problems = problems + 1
                        realPrint(("%s: block %s, %s: %s"):format(name, key, fn, tostring(err)))
                    end
                end
            end
        end
    end
    for n, v in pairs(saved) do _G[n] = v end
end
local n = 0 for k in pairs(STRICT) do if ns.modules[k] then n = n + 1 end end
realPrint(("Block robustness: %d block(s) tested, %d problem(s)"):format(n, problems))
if problems > 0 then os.exit(1) end
