local _, ns = ...
local L = ns.L

-- ========================================================================
-- Profiles.lua: sharing and switching profiles
-- ========================================================================
-- (The basic profile functions — load, create, delete, reset — are in Core.lua.)
--   * Export / import: a profile becomes a single line of text the player can
--     copy and paste (to share a layout, or move it to another account). The
--     text is "TESSERA1:" followed by the profile serialized and Base64-encoded,
--     so it only contains safe characters. Importing never runs code: the text
--     is parsed by the small decoder below.
--   * Duplicate a profile.
--   * Automatic profile: a chosen profile is used inside dungeons and raids,
--     and the usual profile comes back outside.

local EXPORT_PREFIX = "TESSERA1:"

---------------------------------------------------------------------------
-- Serializer: tables, strings, numbers and booleans
--   table   "t" key value key value ... "e"
--   string  "s" <length> ":" <bytes>
--   number  "n" <digits> ";"
--   boolean "T" / "F"
---------------------------------------------------------------------------
local function Serialize(value, out)
    local kind = type(value)
    if kind == "table" then
        table.insert(out, "t")
        for k, v in pairs(value) do
            local kk = type(k)
            local vk = type(v)
            if (kk == "string" or kk == "number")
                and (vk == "string" or vk == "number" or vk == "boolean" or vk == "table") then
                Serialize(k, out)
                Serialize(v, out)
            end
        end
        table.insert(out, "e")
    elseif kind == "string" then
        table.insert(out, "s" .. #value .. ":" .. value)
    elseif kind == "number" then
        -- full precision; non-finite numbers are not exported
        if value == value and value ~= math.huge and value ~= -math.huge then
            table.insert(out, "n" .. string.format("%.17g", value) .. ";")
        else
            table.insert(out, "n0;")
        end
    elseif kind == "boolean" then
        table.insert(out, value and "T" or "F")
    end
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
    if type(profile.theme) == "string" then clean.theme = profile.theme end

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
    local out = {}
    Serialize(self.db, out)
    return EXPORT_PREFIX .. Encode64(table.concat(out))
end

-- Reads an exported text; returns the profile table, or nil if the text is not valid
function ns:DecodeProfile(text)
    if type(text) ~= "string" then return nil end
    text = strtrim(text)
    if text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then return nil end
    local raw = Decode64(text:sub(#EXPORT_PREFIX + 1))
    if not raw then return nil end
    local ok, profile = pcall(Deserialize, raw, 1, 0)
    if not ok or type(profile) ~= "table" or type(profile.blocks) ~= "table" then return nil end
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
