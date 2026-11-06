local ADDON, ns = ...

-- Pinned tooltips: a block's tooltip kept open next to the block and refreshed every
-- second (gold this session, FPS, a goal...). Pin or unpin it from the quick menu
-- (Alt + right-click) or with a Shift / middle click set to "Pin the tooltip".
-- The choice is saved per block (cfg.pinned). A pinned tooltip follows the block:
-- hidden when the block is hidden, and in combat unless tooltips are allowed in combat.

local panels, ticker = {}, nil

local function CanPin(key)
    local mod = ns:GetModule(key)
    return mod and mod.tooltip and not mod.customTooltip and not ns.IsSpacerKey(key)
end
ns.CanPinTooltip = CanPin

local function Panel(key)
    if panels[key] then return panels[key] end
    local ok, p = pcall(CreateFrame, "GameTooltip", "TesseraPin_" .. key, UIParent, "GameTooltipTemplate")
    if not ok or not p then return nil end
    p:SetFrameStrata("MEDIUM")
    panels[key] = p
    return p
end

local function Fill(key)
    local p, f, cfg, mod = panels[key], ns.frames[key], ns.db.blocks[key], ns:GetModule(key)
    if not p then return end
    local show = cfg and cfg.pinned and f and f:IsShown() and mod
        and not (ns.state.inCombat and not ns.db.tooltipInCombat)
    if not show then p:Hide() return end
    p:SetOwner(f, "ANCHOR_NONE")
    p:ClearAllPoints()
    -- below the block in the top half of the screen, above it in the bottom half
    local _, y = f:GetCenter()
    if y and y < UIParent:GetHeight() / 2 then
        p:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
    else
        p:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)
    end
    p:AddLine(ns:GetBlockName(key), 1, 0.82, 0)
    pcall(mod.tooltip, p, cfg)
    p:Show()
end

-- Shows, refreshes or hides every pinned tooltip; one shared timer runs while any is pinned
function ns:RefreshPins()
    if not self.db then return end
    local any = false
    for key, cfg in pairs(self.db.blocks) do
        if cfg.pinned and CanPin(key) then
            any = true
            if Panel(key) then Fill(key) end
        elseif panels[key] then
            panels[key]:Hide()
        end
    end
    if any and not ticker then
        ticker = C_Timer.NewTicker(1, function() ns:RefreshPins() end)
    elseif not any and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

function ns:IsPinned(key)
    local cfg = self.db and self.db.blocks[key]
    return cfg and cfg.pinned and true or false
end

function ns:TogglePin(key)
    local cfg = self.db.blocks[key]
    if not (cfg and CanPin(key)) then return end
    cfg.pinned = not cfg.pinned or nil
    GameTooltip:Hide()
    self:RefreshPins()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
    C_Timer.After(2, function() ns:RefreshPins() end)
end)
