local _, ns = ...

-- ========================================================================
-- Spacers.lua: spacer blocks
-- ========================================================================
-- A spacer is a block without game data, used to lay out merged bars:
--   "empty"  an empty area (to air out a bar or separate groups of blocks)
--   "line"   a thin separator line, vertical or horizontal, in a chosen color
--   "text"   free text, e.g. a title such as "Social"
-- Spacers are created by the player (Blocks tab, "Add a spacer"), any number
-- of them, under keys "spacer:1", "spacer:2"... All share the module below.
-- The separator line itself is drawn by Core.lua (ApplyStyle).

ns.spacerModule = {
    label = "SPACER",
    -- a spacer never shows an icon, a label, a tooltip or threshold colors
    forced = { showIcon = false, showLabel = false, tooltip = false, colorize = false },
    defaults = {
        width = 56,
        spacerMode = "empty",
        spacerText = "",
        spacerOrientation = "vertical",
        spacerThickness = 2,
        spacerColor = { r = 1, g = 0.82, b = 0, a = 0.6 },
    },
    update = function(cfg)
        if cfg.spacerMode == "text" then return cfg.spacerText or "" end
        return ""
    end,
    options = {
        { kind = "dropdown", field = "spacerMode", label = "SPACER_MODE", tip = "TIP_SPACER_MODE",
          values = { { key = "empty", label = "SPACER_EMPTY" }, { key = "line", label = "SPACER_LINE" },
                     { key = "text", label = "SPACER_TEXT" } } },
        { kind = "text", field = "spacerText", label = "SPACER_TEXT_VALUE", tip = "TIP_SPACER_TEXT",
          shown = function(cfg) return cfg.spacerMode == "text" end },
        { kind = "dropdown", field = "spacerOrientation", label = "SPACER_ORIENTATION", tip = "TIP_SPACER_ORIENTATION",
          values = { { key = "vertical", label = "SPACER_VERTICAL" }, { key = "horizontal", label = "SPACER_HORIZONTAL" } },
          shown = function(cfg) return cfg.spacerMode == "line" end },
        { kind = "slider", field = "spacerThickness", label = "SPACER_THICKNESS", tip = "TIP_SPACER_THICKNESS",
          min = 1, max = 8, step = 1, default = 2, shown = function(cfg) return cfg.spacerMode == "line" end },
        { kind = "color", field = "spacerColor", label = "SPACER_COLOR", tip = "TIP_SPACER_COLOR",
          shown = function(cfg) return cfg.spacerMode == "line" end },
    },
}

-- Creates a new spacer block (next free number) and returns its key
function ns:AddSpacer()
    local n = 1
    while self.db.blocks[self.SPACER_PREFIX .. n] do n = n + 1 end
    local key = self.SPACER_PREFIX .. n
    self.db.blocks[key] = self:GetBlockDefaults(key)
    self:RefreshAllBlocks()
    return key
end

-- Deletes a spacer block; blocks docked to it are detached first
function ns:RemoveSpacer(key)
    if not self.IsSpacerKey(key) then return end
    self:DetachChildren(key)
    self.db.blocks[key] = nil
    if self.frames[key] then self.frames[key]:Hide() end
    self:RefreshAllBlocks()
end
