-- Exports the English and French strings for CurseForge's localization tool:
-- writes docs/localization/<locale>.lua as L["KEY"] = "text" lines (the format the
-- release workflow sends to CurseForge, see .github/workflows/release.yml).
-- Keys keep the order of the existing export; new keys are added at the end, sorted.
-- Usage, from the addon folder:  lua5.1 tools/export_locales.lua . enUS docs/localization/enUS.lua
local dir, loc, out = arg[1], arg[2], arg[3]
GetLocale = function() return loc end
local order = {}
for line in io.lines(dir .. "/docs/localization/enUS.lua") do
    local k = line:match('^L%["(.-)"%]') if k then order[#order + 1] = k end
end
local ns = {}
assert(loadfile(dir .. "/Locales/enUS.lua"))("Tessera", ns)
local en = {} for k, v in pairs(ns.L) do en[k] = v end
-- record which keys the locale file sets
local set = {}
setmetatable(ns.L, nil)
local proxy = setmetatable({}, { __index = ns.L, __newindex = function(t, k, v) set[k] = v end })
if loc ~= "enUS" then ns.L = proxy; assert(loadfile(dir .. "/Locales/" .. loc .. ".lua"))("Tessera", ns) else set = en end
local seen = {}
for _, k in ipairs(order) do seen[k] = true end
local extra = {} for k in pairs(en) do if not seen[k] then extra[#extra + 1] = k end end
table.sort(extra) for _, k in ipairs(extra) do order[#order + 1] = k end
local f = io.open(out, "w")
local n = 0
for _, k in ipairs(order) do
    local v = set[k]
    if type(v) == "string" then
        v = v:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
        f:write(('L["%s"] = "%s"\n'):format(k, v)) n = n + 1
    end
end
f:close() print(loc, n)
