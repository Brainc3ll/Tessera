local _, ns = ...
local L = ns.L

-- ========================================================================
-- Profiles.lua: sharing and switching profiles
-- ========================================================================
-- (The basic profile functions — load, create, delete, reset — are in Core.lua.)
--   * Export / import: a profile becomes a single line of text the player can
--     copy and paste (to share a layout, or move it to another account). The
--     text is "TESSERA2:" followed by the profile serialized and Base64-encoded,
--     so it only contains safe characters. Importing never runs code: the text
--     is parsed by the small decoder below.
--     TESSERA2 (1.0.0) writes every setting shared by most blocks once, then for each
--     block only what differs (see Compact): a profile went from about 70 KB to a few
--     KB. TESSERA1 texts (earlier versions: every block in full) are still read.
--   * Duplicate a profile.
--   * Automatic profile: a chosen profile is used inside dungeons and raids,
--     and the usual profile comes back outside.

local EXPORT_PREFIX = "TESSERA2:"
local LEGACY_PREFIX = "TESSERA1:" -- texts exported before 1.0.0, still imported

---------------------------------------------------------------------------
-- Serializer: tables, strings, numbers and booleans
--   table   "t" key value key value ... "e"
--   string  "s" <length> ":" <bytes>
--   number  "n" <digits> ";"
--   boolean "T" / "F"
---------------------------------------------------------------------------
-- Shortest text that reads back as exactly the same number ("0.6", not
-- "0.59999999999999998"); non-finite numbers are not exported
local function NumberText(value)
    if value ~= value or value == math.huge or value == -math.huge then return "0" end
    for digits = 1, 17 do
        local text = string.format("%." .. digits .. "g", value)
        if tonumber(text) == value then return text end
    end
    return string.format("%.17g", value)
end

-- Keys in a fixed order (numbers first, then names), so the same table always gives
-- the same text (Compact compares tables through it)
local function SortedKeys(t)
    local keys = {}
    for k in pairs(t) do
        local kk = type(k)
        if kk == "string" or kk == "number" then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) == "number" end
        return a < b
    end)
    return keys
end

local function Serialize(value, out)
    local kind = type(value)
    if kind == "table" then
        table.insert(out, "t")
        for _, k in ipairs(SortedKeys(value)) do
            local vk = type(value[k])
            if vk == "string" or vk == "number" or vk == "boolean" or vk == "table" then
                Serialize(k, out)
                Serialize(value[k], out)
            end
        end
        table.insert(out, "e")
    elseif kind == "string" then
        table.insert(out, "s" .. #value .. ":" .. value)
    elseif kind == "number" then
        table.insert(out, "n" .. NumberText(value) .. ";")
    elseif kind == "boolean" then
        table.insert(out, value and "T" or "F")
    end
end

-- A value as text, to compare two values (tables included)
local function ValueKey(value)
    local out = {}
    Serialize(value, out)
    return table.concat(out)
end

-- Reads one value at position pos; returns value, next position (nil on error)
local function Deserialize(text, pos, depth)
    if depth > 50 then return nil end
    local c = text:sub(pos, pos)
    if c == "t" then
        local t = {}
        pos = pos + 1
        while text:sub(pos, pos) ~= "e" do
            if pos > #text then return nil end
            local k, v
            k, pos = Deserialize(text, pos, depth + 1)
            if k == nil or pos == nil then return nil end
            v, pos = Deserialize(text, pos, depth + 1)
            if v == nil or pos == nil then return nil end
            t[k] = v
        end
        return t, pos + 1
    elseif c == "s" then
        local len, after = text:match("^(%d+):()", pos + 1)
        len = tonumber(len)
        if not len then return nil end
        return text:sub(after, after + len - 1), after + len
    elseif c == "n" then
        local digits, after = text:match("^([^;]+);()", pos + 1)
        local n = tonumber(digits)
        -- only finite numbers (tonumber also accepts "nan", "inf" and hexadecimal)
        if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
        return n, after
    elseif c == "T" then
        return true, pos + 1
    elseif c == "F" then
        return false, pos + 1
    end
    return nil
end

---------------------------------------------------------------------------
-- Base64 (without bit operations, so it runs anywhere)
---------------------------------------------------------------------------
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DECODE = {}
for i = 1, #ALPHABET do DECODE[ALPHABET:sub(i, i)] = i - 1 end

local function Encode64(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        table.insert(out, ALPHABET:sub(c1 + 1, c1 + 1) .. ALPHABET:sub(c2 + 1, c2 + 1)
            .. (b and ALPHABET:sub(c3 + 1, c3 + 1) or "=") .. (c and ALPHABET:sub(c4 + 1, c4 + 1) or "="))
    end
    return table.concat(out)
end

local function Decode64(text)
    text = text:gsub("[^%w%+/=]", "")
    local out = {}
    for i = 1, #text, 4 do
        local chunk = text:sub(i, i + 3)
        local n, pad = 0, 0
        for j = 1, 4 do
            local ch = chunk:sub(j, j)
            if ch == "=" or ch == "" then
                pad = pad + 1
                n = n * 64
            else
                local v = DECODE[ch]
                if not v then return nil end
                n = n * 64 + v
            end
        end
        local bytes = string.char(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
        table.insert(out, bytes:sub(1, 3 - pad))
    end
    return table.concat(out)
end

---------------------------------------------------------------------------
-- Compact block list (TESSERA2). Blocks of the same family (data blocks, spacers,
-- launchers, DataBroker blocks) share most of their settings (the style, the defaults):
-- data.blockBase[family] holds, for each setting, the value most blocks of that family
-- have, and each block keeps only what differs from it, plus the list "~" of the base
-- settings it does not have. Expand gives back exactly the same blocks: nothing depends
-- on the defaults of the Tessera version or the addons installed on either side.
---------------------------------------------------------------------------
local ABSENT = "~"

-- "spacer" for "spacer:3", "launcher", "broker"; "block" for the data blocks
local function Family(key)
    return type(key) == "string" and key:match("^(%a+):") or "block"
end

-- The base of one family: for each setting, its most common value, when it saves more
-- than it costs (blocks without that setting must then list it as absent)
local function FamilyBase(list)
    local counts, values = {}, {}
    for _, cfg in ipairs(list) do
        for field, value in pairs(cfg) do
            if type(field) == "string" then
                local key = ValueKey(value)
                counts[field] = counts[field] or {}
                counts[field][key] = (counts[field][key] or 0) + 1
                values[key] = value
            end
        end
    end
    local base, baseKey = {}, {}
    for field, byValue in pairs(counts) do
        local bestKey, best, holders = nil, 0, 0
        for key, n in pairs(byValue) do
            holders = holders + n
            if n > best or (n == best and key < bestKey) then bestKey, best = key, n end
        end
        if best >= 2 and best > #list - holders then
            base[field], baseKey[field] = values[bestKey], bestKey
        end
    end
    return base, baseKey
end

local function Compact(blocks)
    local families = {}
    for key, cfg in pairs(blocks) do
        if type(cfg) == "table" then
            local f = Family(key)
            families[f] = families[f] or {}
            table.insert(families[f], cfg)
        end
    end
    local bases, keys = {}, {}
    for f, list in pairs(families) do bases[f], keys[f] = FamilyBase(list) end
    local out = {}
    for key, cfg in pairs(blocks) do
        if type(cfg) == "table" then
            local f = Family(key)
            local base, baseKey = bases[f], keys[f]
            local diff, absent = {}, {}
            for field, value in pairs(cfg) do
                if type(field) ~= "string" or baseKey[field] ~= ValueKey(value) then diff[field] = value end
            end
            for field in pairs(base) do
                if cfg[field] == nil then absent[#absent + 1] = field end
            end
            if #absent > 0 then
                table.sort(absent)
                diff[ABSENT] = absent
            end
            out[key] = diff
        end
    end
    return out, bases
end

local function Expand(blocks, bases)
    if type(blocks) ~= "table" or type(bases) ~= "table" then return blocks end
    local out = {}
    for key, diff in pairs(blocks) do
        if type(diff) == "table" then
            local base = bases[Family(key)]
            local cfg = type(base) == "table" and ns.DeepCopy(base) or {}
            for field, value in pairs(diff) do
                if field ~= ABSENT then cfg[field] = ns.DeepCopy(value) end
            end
            for _, field in ipairs(type(diff[ABSENT]) == "table" and diff[ABSENT] or {}) do
                if type(field) == "string" then cfg[field] = nil end
            end
            out[key] = cfg
        end
    end
    return out
end

-- Any exported data (profile, style, layout) as a line of text
local function Encode(data)
    local copy = {}
    for k, v in pairs(data) do copy[k] = v end
    if type(data.blocks) == "table" then copy.blocks, copy.blockBase = Compact(data.blocks) end
    local out = {}
    Serialize(copy, out)
    return EXPORT_PREFIX .. Encode64(table.concat(out))
end

-- Reads any exported text, new or older format, without cleaning it: the raw table
-- (blocks in full), or nil if the text is not valid
local function DecodeRaw(text)
    if type(text) ~= "string" then return nil end
    text = strtrim(text)
    local prefix = text:sub(1, #EXPORT_PREFIX)
    if prefix ~= EXPORT_PREFIX and prefix ~= LEGACY_PREFIX then return nil end
    local raw = Decode64(text:sub(#EXPORT_PREFIX + 1))
    if not raw then return nil end
    local ok, data = pcall(Deserialize, raw, 1, 0)
    if not ok or type(data) ~= "table" or type(data.blocks) ~= "table" then return nil end
    if prefix == EXPORT_PREFIX then
        local okExpand, blocks = pcall(Expand, data.blocks, data.blockBase)
        if not okExpand or type(blocks) ~= "table" then return nil end
        data.blocks, data.blockBase = blocks, nil
    end
    return data
end

---------------------------------------------------------------------------
-- Validation of an imported profile: an import must never break the addon,
-- so everything that does not have the expected shape is dropped. Missing
-- settings are filled in later from the defaults (Core.lua, PrepareProfile).
---------------------------------------------------------------------------
local MAX_NUMBER = 100000
local SIDES = { LEFT = true, RIGHT = true, TOP = true, BOTTOM = true }
local LAUNCHER_KINDS = { libdbicon = true, frame = true, compartment = true }

local function IsNumber(v)
    return type(v) == "number" and v == v and v > -MAX_NUMBER and v < MAX_NUMBER
end

-- Value of the same simple type as the default (colors: { r, g, b, a } numbers)
local function SameShape(value, default)
    if type(default) == "number" then return IsNumber(value) end
    if type(default) == "table" then
        if type(value) ~= "table" then return false end
        for k, v in pairs(default) do
            if type(v) == "number" and not IsNumber(value[k]) then return false end
        end
        return true
    end
    return type(value) == type(default)
end

local function CleanPoint(p)
    if type(p) ~= "table" or type(p[1]) ~= "string" or type(p[2]) ~= "string"
        or not IsNumber(p[3]) or not IsNumber(p[4]) then return nil end
    return { p[1], p[2], p[3], p[4] }
end

-- Block settings: known fields with the right type, plus position / docking data
local function CleanBlock(self, key, block, keys)
    local defaults = self:GetBlockDefaults(key)
    local clean = {}
    for field, value in pairs(block) do
        if defaults[field] ~= nil then
            if SameShape(value, defaults[field]) then clean[field] = value end
        elseif field == "point" then
            clean.point = CleanPoint(value)
        elseif field == "dock" and type(value) == "table" and type(value.to) == "string"
            and keys[value.to] and value.to ~= key and SIDES[value.side] then
            clean.dock = { to = value.to, side = value.side }
        elseif field == "anchor" and type(value) == "table" then
            local a = {}
            for _, k in ipairs({ "top", "bottom", "gap" }) do
                if IsNumber(value[k]) then a[k] = value[k] end
            end
            if type(value.frame) == "string" then a.frame = value.frame end
            if type(value.fill) == "boolean" then a.fill = value.fill end
            if value.align == "LEFT" or value.align == "RIGHT" then a.align = value.align end
            if value.fixed == true and IsNumber(value.offset) then a.fixed, a.offset = true, value.offset end
            for _, k in ipairs({ "below", "above" }) do
                if type(value[k]) == "string" and keys[value[k]] and value[k] ~= key then a[k] = value[k] end
            end
            clean.anchor = a
        elseif field == "launcher" and type(value) == "table" and LAUNCHER_KINDS[value.kind]
            and type(value.source) == "string" then
            clean.launcher = { kind = value.kind, source = value.source,
                label = type(value.label) == "string" and value.label or value.source }
        elseif field == "broker" and type(value) == "table" and type(value.name) == "string"
            and key == self.BROKER_PREFIX .. value.name then
            clean.broker = { name = value.name,
                label = type(value.label) == "string" and value.label or value.name,
                kind = value.kind == "launcher" and "launcher" or "data source",
                addon = type(value.addon) == "string" and value.addon or nil }
        elseif (field == "scale") and IsNumber(value) and value >= 0.5 and value <= 3 then
            clean.scale = value
        elseif (field == "warnAt" or field == "badAt") and IsNumber(value) then
            clean[field] = value
        elseif field == "frozen" and type(value) == "boolean" then
            clean.frozen = value
        elseif field == "edges" and type(value) == "table" then
            local e = {}
            for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
                if value[side] == true then e[side] = true end
            end
            if next(e) then clean.edges = e end
        elseif field == "look" and (value == "fused" or value == "tiles" or value == "separate") then
            clean.look = value
        elseif field == "stretch" and (value == "TOP" or value == "BOTTOM") then
            clean.stretch = value
        end
    end
    -- sizes that could hide the block or break the layout
    if clean.width and (clean.width < 1 or clean.width > 2000) then clean.width = nil end
    if clean.height and (clean.height < 1 or clean.height > 500) then clean.height = nil end
    return clean
end

-- Drops docks / hangs that would form a loop (A docked to B docked to A...)
local function BreakLoops(blocks)
    local function Parent(cfg)
        return (cfg.dock and cfg.dock.to) or (cfg.anchor and (cfg.anchor.below or cfg.anchor.above))
    end
    for key, cfg in pairs(blocks) do
        local seen, cur = { [key] = true }, Parent(cfg)
        while cur and blocks[cur] do
            if seen[cur] then
                cfg.dock = nil
                if cfg.anchor then cfg.anchor.below, cfg.anchor.above = nil, nil end
                break
            end
            seen[cur] = true
            cur = Parent(blocks[cur])
        end
    end
end

-- Returns a safe copy of a decoded profile
function ns:SanitizeProfile(profile)
    local clean = { blocks = {} }
    for field, default in pairs(self.PROFILE_DEFAULTS) do
        local value = profile[field]
        if field ~= "blocks" and value ~= nil and type(value) == type(default) then
            if type(value) == "number" then
                if IsNumber(value) then clean[field] = value end
            elseif type(value) == "table" then
                -- shared defaults ("All blocks" / "All launchers"): simple values only
                local t = {}
                for k, v in pairs(value) do
                    if type(k) == "string" and (type(v) ~= "table" or SameShape(v, { r = 0, g = 0, b = 0 })) then
                        t[k] = v
                    end
                end
                clean[field] = t
            else
                clean[field] = value
            end
        end
    end
    if clean.scale and (clean.scale < 0.5 or clean.scale > 3) then clean.scale = nil end
    if clean.tooltipScale and (clean.tooltipScale < 0.5 or clean.tooltipScale > 2) then clean.tooltipScale = nil end
    if type(profile.theme) == "string" then clean.theme = profile.theme end
    -- group look (Look tab), absent from profiles made before it
    local look = profile.groupLook
    if look == "fused" or look == "tiles" or look == "separate" then clean.groupLook = look end
    if IsNumber(profile.jointGap) and profile.jointGap >= 2 and profile.jointGap <= 12 then
        clean.jointGap = profile.jointGap
    end

    -- which block keys can exist: game modules, launchers, spacers
    local keys = {}
    for key, block in pairs(type(profile.blocks) == "table" and profile.blocks or {}) do
        if type(key) == "string" and type(block) == "table"
            and (self.modules[key] or self.IsLauncherKey(key) or self.IsBrokerKey(key) or self.IsSpacerKey(key)) then
            keys[key] = true
        end
    end
    for key in pairs(keys) do
        local block = CleanBlock(self, key, profile.blocks[key], keys)
        -- a launcher or DataBroker block without its source description is useless
        if (not self.IsLauncherKey(key) or block.launcher) and (not self.IsBrokerKey(key) or block.broker) then
            clean.blocks[key] = block
        end
    end
    BreakLoops(clean.blocks)
    clean.initialized = true
    return clean
end

---------------------------------------------------------------------------
-- Export / import
---------------------------------------------------------------------------
-- The active profile as a line of text
function ns:ExportProfile()
    return Encode(self.db)
end

-- Reads an exported text; returns the profile table, or nil if the text is not valid
function ns:DecodeProfile(text)
    local profile = DecodeRaw(text)
    if not profile then return nil end
    local okClean, clean = pcall(self.SanitizeProfile, self, profile)
    return okClean and clean or nil
end

-- Imports a text as a new profile named `name` and switches to it
function ns:ImportProfile(text, name)
    local profile = self:DecodeProfile(text)
    if not profile then return false, L.IMPORT_INVALID end
    name = name and strtrim(name) or ""
    if name == "" or self.sv.profiles[name] then return false, L.PROFILE_EXISTS end
    self.sv.profiles[name] = profile
    self:SetProfile(name)
    return true
end

---------------------------------------------------------------------------
-- Sharing only a style or only a layout
---------------------------------------------------------------------------
-- Same text format as a profile, with a "kind" field: "style" (the look only:
-- fonts, colors, frames, icons, group look) or "layout" (the placement only:
-- which blocks, where, how they are grouped, stuck to edges, stretched). One
-- import window reads all three kinds. Before anything is applied, the import
-- lists what the text needs and this computer lacks (see FindMissing).
local LAYOUT_FIELDS = { "point", "dock", "anchor", "enabled", "edges", "stretch", "look",
    "width", "autoWidth", "height", "frozen" }

local function Pick(src, fields)
    local t = {}
    for _, field in ipairs(fields) do
        if src[field] ~= nil then t[field] = ns.DeepCopy(src[field]) end
    end
    return t
end

-- "profile", "style" or "layout", or nil if the text is not valid
function ns:GetExportKind(text)
    local data = DecodeRaw(text)
    if not data then return nil end
    if data.kind == "style" or data.kind == "layout" then return data.kind end
    return "profile"
end

-- The look of all blocks. Blocks the other player does not have take the look
-- of a reference block ("base": the first shown data block).
function ns:ExportStyle()
    local data = { kind = "style", theme = self.db.theme, groupLook = self.db.groupLook,
        jointGap = self.db.jointGap, blocks = {} }
    local keys = {}
    for key, cfg in pairs(self.db.blocks) do
        data.blocks[key] = Pick(cfg, self.STYLE_KEYS)
        table.insert(keys, key)
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local cfg = self.db.blocks[key]
        if self.modules[key] and cfg.enabled ~= false then
            data.base = key
            break
        end
    end
    return Encode(data)
end

-- The placement of all blocks (launchers, DataBroker blocks and spacers carry
-- what is needed to create them on the other side)
function ns:ExportLayout()
    local data = { kind = "layout", blocks = {} }
    for key, cfg in pairs(self.db.blocks) do
        local b = self.IsSpacerKey(key) and self.DeepCopy(cfg) or Pick(cfg, LAYOUT_FIELDS)
        b.enabled = cfg.enabled ~= false
        if cfg.launcher then b.launcher = self.DeepCopy(cfg.launcher) end
        if cfg.broker then b.broker = self.DeepCopy(cfg.broker) end
        data.blocks[key] = b
    end
    return Encode(data)
end

-- What a text needs and this computer lacks, as lines of text (empty list: nothing
-- missing): other addons' DataBroker blocks and minimap buttons, media from
-- LibSharedMedia, the UI a style matches, WoW Forever blocks.
function ns:FindMissing(text)
    local data = DecodeRaw(text)
    local lines = {}
    if not data then return lines end
    local brokers, launchers, media, forever = {}, {}, {}, 0
    local isForever = {}
    for _, key in ipairs(self.FOREVER_KEYS or {}) do isForever[key] = true end
    local LSM, prefix = self:GetLSM(), self.LSM_PREFIX
    for key, cfg in pairs(data.blocks) do
        if type(key) == "string" and type(cfg) == "table" and cfg.enabled ~= false then
            if self.IsBrokerKey(key) then
                if not self:IsBrokerAvailable(cfg) then
                    local b = type(cfg.broker) == "table" and cfg.broker or {}
                    local who = tostring(b.addon or b.name or key)
                    brokers[who] = (brokers[who] or 0) + 1
                end
            elseif self.IsLauncherKey(key) then
                if not self:IsLauncherAvailable(cfg) then
                    local l = type(cfg.launcher) == "table" and cfg.launcher or {}
                    launchers[tostring(l.label or l.source or key)] = true
                end
            elseif isForever[key] and not self.modules[key] then
                forever = forever + 1
            end
            for kind, field in pairs({ font = "font", background = "bg", border = "border" }) do
                local v = cfg[field]
                if type(v) == "string" and v:sub(1, #prefix) == prefix then
                    local name = v:sub(#prefix + 1)
                    if not (LSM and LSM:Fetch(kind, name, true)) then media[name] = true end
                end
            end
        end
    end
    local function Sorted(t)
        local list = {}
        for k in pairs(t) do table.insert(list, k) end
        table.sort(list)
        return list
    end
    for _, who in ipairs(Sorted(brokers)) do table.insert(lines, L.MISSING_BROKER:format(who, brokers[who])) end
    for _, who in ipairs(Sorted(launchers)) do table.insert(lines, L.MISSING_LAUNCHER:format(who)) end
    for _, name in ipairs(Sorted(media)) do table.insert(lines, L.MISSING_MEDIA:format(name)) end
    if type(data.theme) == "string" then
        local t = self:GetThemeInfo(data.theme)
        if t and not self:IsThemeInstalled(data.theme) then table.insert(lines, L.MISSING_UI:format(t.name)) end
    end
    if forever > 0 then table.insert(lines, L.MISSING_FOREVER:format(forever)) end
    return lines
end

-- Applies a style text to the blocks of the active profile; placement is untouched
function ns:ImportStyle(text)
    local data = DecodeRaw(text)
    if not data or data.kind ~= "style" then return false end
    local clean = self:SanitizeProfile({ blocks = data.blocks, groupLook = data.groupLook, jointGap = data.jointGap })
    local base = type(data.base) == "string" and clean.blocks[data.base] or nil
    for key, cfg in pairs(self.db.blocks) do
        local src = clean.blocks[key] or base
        if src then
            for _, field in ipairs(self.STYLE_KEYS) do
                if src[field] ~= nil then cfg[field] = self.DeepCopy(src[field]) end
            end
        end
    end
    if type(data.theme) == "string" and self:GetThemeInfo(data.theme) then self.db.theme = data.theme end
    if clean.groupLook then self:SetGroupLook(clean.groupLook) end
    self.db.jointGap = clean.jointGap
    self:RefreshAllBlocks()
    return true
end

-- Applies a layout text: blocks of the layout take its placement (missing
-- launchers and DataBroker blocks are skipped), the others are hidden. The look
-- is untouched. Ctrl + Z undoes it.
function ns:ImportLayout(text)
    local data = DecodeRaw(text)
    if not data or data.kind ~= "layout" then return false end
    -- leave out what cannot be shown here, so nothing stays docked to it
    local usable = {}
    for key, cfg in pairs(data.blocks) do
        if type(key) == "string" and type(cfg) == "table" then
            local ok = true
            if self.IsBrokerKey(key) then ok = self:IsBrokerAvailable(cfg)
            elseif self.IsLauncherKey(key) then ok = self:IsLauncherAvailable(cfg) end
            if ok then usable[key] = cfg end
        end
    end
    local clean = self:SanitizeProfile({ blocks = usable })
    if self.PushUndo then self:PushUndo() end
    for key, cfg in pairs(self.db.blocks) do
        if not clean.blocks[key] then
            cfg.enabled = false
            cfg.point, cfg.dock, cfg.anchor, cfg.edges, cfg.stretch, cfg.look = nil, nil, nil, nil, nil, nil
        end
    end
    for key, src in pairs(clean.blocks) do
        local cfg = self.db.blocks[key]
        if not cfg then
            cfg = self:GetBlockDefaults(key)
            if self.IsSpacerKey(key) then
                for field, value in pairs(src) do cfg[field] = self.DeepCopy(value) end
            end
            cfg.launcher, cfg.broker = self.DeepCopy(src.launcher), self.DeepCopy(src.broker)
            self.db.blocks[key] = cfg
        end
        -- position fields follow the layout (absent = not set); sizes only if given
        for _, field in ipairs({ "point", "dock", "anchor", "edges", "stretch", "look" }) do
            cfg[field] = self.DeepCopy(src[field])
        end
        for _, field in ipairs({ "enabled", "width", "autoWidth", "height", "frozen" }) do
            if src[field] ~= nil then cfg[field] = src[field] end
        end
    end
    self:RefreshAllBlocks()
    return true
end

-- Copies the active profile under a new name and switches to it
function ns:DuplicateProfile(name)
    name = name and strtrim(name) or ""
    if name == "" or self.sv.profiles[name] then return false end
    self.sv.profiles[name] = self.DeepCopy(self.db)
    self:SetProfile(name)
    return true
end

---------------------------------------------------------------------------
-- Automatic profile in dungeons and raids
---------------------------------------------------------------------------
-- Profile wanted for the current situation, or nil for the usual one
function ns:GetSituationProfile()
    local name = self.sv and self.sv.instanceProfile
    if not name or not self.sv.profiles[name] then return nil end
    local inInstance, kind = IsInInstance()
    if inInstance and (kind == "party" or kind == "raid") then return name end
    return nil
end

-- Called when the zone changes: switches profile if the situation asks for it
function ns:CheckSituationProfile()
    if not self.built then return end
    local wanted = self:GetSituationProfile()
    if wanted ~= self.profileOverride then
        self.profileOverride = wanted
        self:LoadProfile()
    end
end
