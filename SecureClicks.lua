local ADDON, ns = ...

-- Secure clicks
-- Lets a block open a Blizzard window (character sheet, bags, map...) without tainting it.
--
-- Why: when addon code opens a Blizzard window directly, WoW marks that window as
-- "tainted" (touched by insecure code). With the secret values introduced in
-- Midnight/Forever, a tainted window errors out as soon as it reads protected data,
-- such as the player's health.
--
-- Fix (same approach as FlareUI): a transparent secure button sits on top of the block
-- and runs a macro (/click CharacterMicroButton, /run ToggleAllBags()...). The game
-- itself executes the macro, so nothing gets tainted.
--
-- These buttons are protected: they cannot be created, moved or hidden during combat.
-- So they are positioned in screen coordinates (not anchored to the block, otherwise
-- the block would become protected too) and re-synced once combat ends.

-- Secure overlay buttons, keyed by block key
local overlays = {}
local syncPending = false

-- Returns a handler that runs the block's own script (e.g. OnEnter) from the overlay
local function ForwardScript(key, script)
    return function()
        local f = ns.frames[key]
        local handler = f and f:GetScript(script)
        if handler then handler(f) end
    end
end

-- Returns the secure overlay button for a block, creating it if needed.
-- Returns nil in combat, since secure frames cannot be created then.
-- Macro text of a block: a fixed text, or a function (e.g. a profession block casts
-- the character's own profession)
local function MacroText(key)
    local macro = ns.modules[key].secureMacro
    if type(macro) == "function" then
        local ok, text = pcall(macro, ns.db and ns.db.blocks[key])
        return ok and text or "/stopmacro"
    end
    return macro
end

local function GetOverlay(key)
    if overlays[key] then return overlays[key] end
    if InCombatLockdown() then return nil end
    local o = CreateFrame("Button", "TesseraClick_" .. key, UIParent, "SecureActionButtonTemplate")
    o:RegisterForClicks("LeftButtonUp")
    o:SetAttribute("useOnKeyDown", false)
    o:SetAttribute("pressAndHoldAction", false)
    o:SetAttribute("type", "macro")
    o:SetAttribute("macrotext", MacroText(key))
    -- Shift + left click does nothing securely ("/stopmacro" is a no-op macro): it runs
    -- the block's configurable Shift action instead (see ns:HandleLockedClick)
    o:SetAttribute("shift-type1", "macro")
    o:SetAttribute("shift-macrotext1", "/stopmacro")
    -- Middle click runs the same macro, but only when the block's middle-click action
    -- is "open" (the button is registered for middle clicks in SyncClickOverlays)
    o:SetAttribute("type3", "macro")
    o:SetAttribute("macrotext3", MacroText(key))
    -- Keep showing the block's own tooltip
    o:SetScript("OnEnter", ForwardScript(key, "OnEnter"))
    o:SetScript("OnLeave", ForwardScript(key, "OnLeave"))
    -- Right / Alt + right / Shift / middle clicks are handled in Lua (Placement.lua)
    o:HookScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or IsShiftKeyDown() then
            ns:HandleLockedClick(key, button, ns.frames[key])
        end
    end)
    o:Hide()
    overlays[key] = o
    return o
end

-- Places, resizes, shows or hides every overlay to match its block.
-- Overlays only exist while blocks are locked. In combat, the sync is postponed.
function ns:SyncClickOverlays()
    if InCombatLockdown() then
        syncPending = true
        return
    end
    syncPending = false
    if not self.db then return end

    local locked = self:IsLocked()
    for key, mod in pairs(self.modules) do
        if mod.secureMacro then
            local f, cfg = self.frames[key], self.db.blocks[key]
            local wanted = locked and f and cfg and f:IsShown() and f:GetLeft() ~= nil
            local o = overlays[key] or (wanted and GetOverlay(key))
            if o then
                UnregisterStateDriver(o, "visibility")
                if wanted then
                    -- macro rebuilt if it depends on the character (out of combat only)
                    local macro = MacroText(key)
                    if o:GetAttribute("macrotext") ~= macro then
                        o:SetAttribute("macrotext", macro)
                        o:SetAttribute("macrotext3", macro)
                    end
                    -- the block may have its own scale: place the button in UIParent units
                    local l, b, r, t = ns:GetRectUI(f)
                    o:ClearAllPoints()
                    o:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
                    o:SetSize(r - l, t - b)
                    if cfg.middleClick == "open" then
                        o:RegisterForClicks("LeftButtonUp", "MiddleButtonUp")
                    else
                        o:RegisterForClicks("LeftButtonUp")
                    end
                    o:SetFrameStrata(f:GetFrameStrata())
                    o:SetFrameLevel(f:GetFrameLevel() + 10)
                    o:Show()
                    -- If the block hides in combat, hide the button too (the game handles it during combat)
                    if cfg.hideInCombat then
                        RegisterStateDriver(o, "visibility", "[combat] hide; show")
                    end
                else
                    o:Hide()
                end
            end
        end
    end
end

-- Batches sync requests; positions are read after the layout has been applied
function ns:RequestOverlaySync()
    if self.overlaySyncQueued then return end
    self.overlaySyncQueued = true
    C_Timer.After(0.05, function()
        ns.overlaySyncQueued = false
        ns:SyncClickOverlays()
    end)
end

-- Run any postponed sync when combat ends
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if syncPending and ns.built then ns:RequestOverlaySync() end
end)
