local ADDON, ns = ...
local L = ns.L

-- Micro-menu blocks: one block per button of Blizzard's micro menu (character, spellbook,
-- talents, quest log, guild...). A click runs "/click <button>" through a secure overlay
-- (SecureClicks.lua), so the window opens exactly as with Blizzard's own button.
-- A menu not unlocked yet (its button is disabled until a given level) shows a grey icon
-- and says so in its tooltip; with "Hide when empty" the block only appears once unlocked.
-- Blocks are offered only for the buttons this client has (WoW Forever or Retail).
-- The shop button is left out (no in-game advertising).

local ENTRIES = {
    { key = "microCharacter", button = "CharacterMicroButton", label = "MICRO_CHARACTER",
      icon = "Interface\\Icons\\INV_Misc_Head_Human_01" },
    { key = "microSpellbook", button = "SpellbookMicroButton", label = "MICRO_SPELLBOOK",
      icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { key = "microTalents", button = "TalentMicroButton", label = "MICRO_TALENTS",
      icon = "Interface\\Icons\\Ability_Marksmanship" },
    { key = "microTalents", button = "PlayerSpellsMicroButton", label = "MICRO_TALENTS",
      icon = "Interface\\Icons\\Ability_Marksmanship" },
    { key = "microProfessions", button = "ProfessionMicroButton", label = "MICRO_PROFESSIONS",
      icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { key = "microQuests", button = "QuestLogMicroButton", label = "MICRO_QUESTS",
      icon = "Interface\\Icons\\INV_Misc_Book_08" },
    { key = "microGuild", button = "GuildMicroButton", label = "MICRO_GUILD",
      icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01" },
    { key = "microGroupFinder", button = "LFDMicroButton", label = "MICRO_GROUP_FINDER",
      icon = "Interface\\Icons\\INV_Misc_GroupLooking" },
    { key = "microJournal", button = "EJMicroButton", label = "MICRO_JOURNAL",
      icon = "Interface\\Icons\\INV_Misc_Book_11" },
    { key = "microCollections", button = "CollectionsMicroButton", label = "MICRO_COLLECTIONS",
      icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
    { key = "microLegacy", button = "LegacyMicroButton", label = "MICRO_LEGACY", icon = 4279397 },
    { key = "microGameMenu", button = "MainMenuMicroButton", label = "MICRO_GAME_MENU",
      icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}
ns.MICRO_KEYS = {}

local function Unlocked(button)
    local b = _G[button]
    if not b then return false end
    local ok, enabled = pcall(b.IsEnabled, b)
    return ok and enabled ~= false
end

-- The button's own icon when it uses an atlas, else a fixed icon; grey while locked
local function Icon(entry)
    local b = _G[entry.button]
    local normal = b and b.GetNormalTexture and b:GetNormalTexture()
    local atlas = normal and normal.GetAtlas and normal:GetAtlas()
    local icon = atlas and { atlas = atlas } or { file = entry.icon }
    if not Unlocked(entry.button) then icon.color = { 0.45, 0.45, 0.45 } end
    return icon
end

local registered = {}
for _, entry in ipairs(ENTRIES) do
    if not registered[entry.key] and _G[entry.button] then
        registered[entry.key] = true
        table.insert(ns.MICRO_KEYS, entry.key)
        ns:RegisterModule(entry.key, {
            label = entry.label,
            icon = entry.icon,
            getIcon = function() return Icon(entry) end,
            events = { "PLAYER_LEVEL_UP" },
            interval = 5, -- a menu unlocks with a quest or a level: checked now and then
            defaultEnabled = false,
            defaults = { showLabel = false },
            isEmpty = function() return not Unlocked(entry.button) end,
            update = function() return "" end,
            tooltip = function(tt)
                if Unlocked(entry.button) then return end
                local b = _G[entry.button]
                local why = b and type(b.disabledTooltip) == "string" and b.disabledTooltip
                tt:AddLine(why or L.MICRO_LOCKED, 1, 0.6, 0.2, true)
            end,
            secureMacro = "/click " .. entry.button,
            clickHint = L.HINT_MICRO,
        })
    end
end
