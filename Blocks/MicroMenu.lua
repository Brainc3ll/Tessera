local ADDON, ns = ...
local L = ns.L

-- Micro-menu block: one block for Blizzard's micro menu. Its tooltip lists the menus
-- (grey: not unlocked yet); a click opens a small list next to the block, and a click on
-- a menu there opens it exactly as Blizzard's button does ("/click <button>" run by a
-- secure button, so nothing gets tainted). Secure buttons cannot be shown or hidden in
-- combat: the list opens out of combat only. The shop button is left out (no in-game
-- advertising). Only the buttons this client has are listed (WoW Forever or Retail).

local ENTRIES = {
    { button = "CharacterMicroButton", label = "MICRO_CHARACTER", icon = "Interface\\Icons\\INV_Misc_Head_Human_01" },
    { button = "SpellbookMicroButton", label = "MICRO_SPELLBOOK", icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { button = "TalentMicroButton", label = "MICRO_TALENTS", icon = "Interface\\Icons\\Ability_Marksmanship" },
    { button = "PlayerSpellsMicroButton", label = "MICRO_TALENTS", icon = "Interface\\Icons\\Ability_Marksmanship" },
    { button = "ProfessionMicroButton", label = "MICRO_PROFESSIONS", icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { button = "QuestLogMicroButton", label = "MICRO_QUESTS", icon = "Interface\\Icons\\INV_Misc_Book_08" },
    { button = "GuildMicroButton", label = "MICRO_GUILD", icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01" },
    { button = "LFDMicroButton", label = "MICRO_GROUP_FINDER", icon = "Interface\\Icons\\INV_Misc_GroupLooking" },
    { button = "EJMicroButton", label = "MICRO_JOURNAL", icon = "Interface\\Icons\\INV_Misc_Book_11" },
    { button = "CollectionsMicroButton", label = "MICRO_COLLECTIONS", icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
    { button = "LegacyMicroButton", label = "MICRO_LEGACY", icon = 4279397 },
    { button = "MainMenuMicroButton", label = "MICRO_GAME_MENU", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}

-- The menus this client has (one entry per label: Retail and Forever name the talent button differently)
local function Entries()
    local list, seen = {}, {}
    for _, e in ipairs(ENTRIES) do
        if _G[e.button] and not seen[e.label] then
            seen[e.label] = true
            table.insert(list, e)
        end
    end
    return list
end
ns.MicroMenuEntries = Entries

local function Unlocked(button)
    local b = _G[button]
    if not b then return false end
    local ok, enabled = pcall(b.IsEnabled, b)
    return ok and enabled ~= false
end
ns.MicroMenuUnlocked = Unlocked

local function Icon(e)
    local b = _G[e.button]
    local normal = b and b.GetNormalTexture and b:GetNormalTexture()
    local atlas = normal and normal.GetAtlas and normal:GetAtlas()
    return atlas and { atlas = atlas } or { file = e.icon }
end

---------------------------------------------------------------------------
-- The list opened by a click: one secure row per menu
---------------------------------------------------------------------------
local ROW_H, LIST_W = 24, 210
local list

local function BuildList()
    if list then return list end
    if InCombatLockdown() then return nil end
    list = CreateFrame("Frame", "TesseraMicroMenuList", UIParent, "BackdropTemplate")
    list:SetFrameStrata("DIALOG")
    list:SetClampedToScreen(true)
    list:EnableMouse(true)
    list.rows = {}
    for i, e in ipairs(Entries()) do
        local row = CreateFrame("Button", "TesseraMicroMenuRow" .. i, list, "SecureActionButtonTemplate")
        row:SetSize(LIST_W - 16, ROW_H)
        row:SetPoint("TOPLEFT", 8, -8 - (i - 1) * ROW_H)
        row:RegisterForClicks("LeftButtonUp")
        row:SetAttribute("useOnKeyDown", false)
        row:SetAttribute("type", "macro")
        row:SetAttribute("macrotext", "/click " .. e.button)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ROW_H - 4, ROW_H - 4)
        row.icon:SetPoint("LEFT", 2, 0)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.text:SetPoint("RIGHT", -2, 0)
        row.text:SetJustifyH("LEFT")
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.12)
        row:HookScript("OnClick", function() list:Hide() end)
        row.entry = e
        list.rows[i] = row
    end
    list:SetSize(LIST_W, 16 + #list.rows * ROW_H)
    list:Hide()
    -- closes with Escape, like Blizzard's menus
    table.insert(UISpecialFrames, "TesseraMicroMenuList")
    return list
end

-- Updates each row (a locked menu is grey and cannot be clicked), skins and places the list
local function RefreshList(owner)
    for _, row in ipairs(list.rows) do
        local e, unlocked = row.entry, Unlocked(row.entry.button)
        ns:SetIcon(row.icon, Icon(e))
        row.icon:SetDesaturated(not unlocked)
        local name = L[e.label]
        row.text:SetText(unlocked and name or ("|cff808080" .. name .. "|r"))
        row:SetAttribute("type", unlocked and "macro" or nil)
    end
    if ns.SkinWindow then ns:SkinWindow(list) end
    list:ClearAllPoints()
    local _, y = owner:GetCenter()
    if y and y < UIParent:GetHeight() / 2 then
        list:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 2)
    else
        list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    end
end

function ns:ToggleMicroMenuList(owner)
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(L.MICRO_IN_COMBAT, 1, 0.3, 0.3)
        return
    end
    if not BuildList() then return end
    if list:IsShown() then list:Hide() return end
    RefreshList(owner or ns.frames.microMenu or UIParent)
    list:Show()
end

-- the options window opens: the list closes (no window over another)
function ns:HideMicroMenuList()
    if list and list:IsShown() and not InCombatLockdown() then list:Hide() end
end

local listCloser = CreateFrame("Frame")
listCloser:RegisterEvent("PLAYER_REGEN_DISABLED")
listCloser:SetScript("OnEvent", function()
    if list and list:IsShown() then list:Hide() end -- secure frames: hidden before combat locks them
end)

---------------------------------------------------------------------------
-- The block
---------------------------------------------------------------------------
if #Entries() > 0 then
ns:RegisterModule("microMenu", {
    label = "MICRO_MENU",
    icon = "Interface\\Icons\\INV_Misc_Book_07",
    events = { "PLAYER_LEVEL_UP" },
    defaultEnabled = false,
    defaults = { microCount = "locked" },
    options = {
        { kind = "dropdown", field = "microCount", label = "MICRO_COUNT", tip = "TIP_MICRO_COUNT",
          values = { { key = "locked", label = "MICRO_COUNT_LOCKED" }, { key = "always", label = "MICRO_COUNT_ALWAYS" } } },
    },
    update = function(cfg)
        local open, total = 0, 0
        for _, e in ipairs(Entries()) do
            total = total + 1
            if Unlocked(e.button) then open = open + 1 end
        end
        if open < total or (cfg and cfg.microCount == "always") then return ("%d / %d"):format(open, total) end
        return ""
    end,
    tooltip = function(tt)
        for _, e in ipairs(Entries()) do
            local icon = type(e.icon) == "number" and e.icon or e.icon
            local mark = ("|T%s:16:16:0:0:64:64:5:59:5:59|t "):format(icon)
            if Unlocked(e.button) then
                tt:AddLine(mark .. L[e.label], 1, 1, 1)
            else
                local b = _G[e.button]
                local why = b and type(b.disabledTooltip) == "string" and b.disabledTooltip or L.MICRO_LOCKED
                tt:AddDoubleLine(mark .. L[e.label], why, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6)
            end
        end
    end,
    onClick = function(self, button)
        if button ~= "LeftButton" then return end
        ns:ToggleMicroMenuList(self)
    end,
    clickHint = L.HINT_MICRO,
})
end
