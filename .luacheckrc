-- luacheck configuration (https://github.com/lunarmodules/luacheck)
-- Run from the addon folder:  luacheck .
std = "lua51"
max_line_length = 160
exclude_files = { "Libs/", "tools/", "docs/" }
ignore = {
    "113", -- accessing an undefined global: the WoW API is made of globals
    "212", -- unused argument (often `self` in ns:Method definitions)
    "211/ADDON", -- the addon name from `...` is not used in every file
}
globals = {
    "TesseraDB",                        -- saved variables
    "SlashCmdList", "SLASH_TESSERA1", "SLASH_TESSERA2",
    "StaticPopupDialogs", "UISpecialFrames",
    "Tessera_OnAddonCompartmentClick",
    "Tessera_ToggleBlocks", "Tessera_ToggleLock", "Tessera_ToggleOptions", "Tessera_ToggleStreamer", -- Bindings.xml
    "BINDING_HEADER_TESSERA", "BINDING_NAME_TESSERA_TOGGLE", "BINDING_NAME_TESSERA_LOCK",
    "BINDING_NAME_TESSERA_OPTIONS", "BINDING_NAME_TESSERA_STREAMER",
}
-- Locale files hold long translated sentences
files["Locales/"] = { max_line_length = false }
