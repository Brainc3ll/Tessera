local _, ns = ...

-- Language of Tessera's texts (1.8). Each language file hands its texts to
-- ns.RegisterLocale as a function. The language of the game is applied at once, as before.
-- The saved choice (Language list, General tab) is read later, when the saved variables exist
-- (ns:ApplySavedLanguage, called from InitDB): English goes back into ns.L, then the chosen
-- language. A change takes effect after a reload of the interface. Texts that are read while
-- the files load are read again through ns.OnLanguage.
local L = ns.L

-- Languages with texts, in the order of the files (the list in the General tab). A language file
-- adds itself with ns.RegisterLocale: a file with no texts is not offered, a new file with texts is.
ns.LANGUAGES = { { key = "enUS", name = "English" } }

local clientCode = GetLocale()
local active = "enUS"
local loaders = {}
local callbacks = {}

-- code: the game's language code ("deDE"), name: the language written in itself ("Deutsch"),
-- fill(L): puts the texts in L
function ns.RegisterLocale(code, name, fill)
    loaders[code] = fill
    ns.LANGUAGES[#ns.LANGUAGES + 1] = { key = code, name = name }
    if code == clientCode then
        fill(L)
        active = code
    end
end

-- Code of the language in use (the client's, or the saved choice)
function ns.GetLanguage() return active end

-- "fr" or "en": the changelog and the long guides exist in these two languages only
function ns.TextLanguage() return active == "frFR" and "fr" or "en" end

local function IsLanguage(code)
    for _, entry in ipairs(ns.LANGUAGES) do
        if entry.key == code then return true end
    end
    return false
end

-- The saved choice, or nil ("As the game")
function ns.GetLanguageChoice()
    local code = ns.sv and ns.sv.language
    return IsLanguage(code) and code or nil
end

-- Runs fill() once the language is final (a text read while the files load would stay in
-- the language of the game): at once when the language is already applied
local applied = false
function ns.OnLanguage(fill)
    if applied then fill() else callbacks[#callbacks + 1] = fill end
end

-- Entries of a list that name their text by key (`nameKey = "THEME_EMBER"`) get the text in
-- the field (`name`), now and again once the language is final.
function ns.LocalizeList(list, field)
    local keyField = field .. "Key"
    local function fill()
        for _, entry in pairs(list) do
            local key = type(entry) == "table" and entry[keyField]
            if key then entry[field] = L[key] end
        end
    end
    fill()
    ns.OnLanguage(fill)
end

-- Called once the saved variables exist. Puts the saved language in ns.L, then lets go of
-- the other languages (their code is freed at the next garbage collection).
function ns:ApplySavedLanguage()
    if applied then return end
    local want = ns.GetLanguageChoice() or clientCode
    if not IsLanguage(want) or (want ~= "enUS" and not loaders[want]) then want = "enUS" end
    if want ~= active and ns.BuildEnglish then
        for key in pairs(L) do L[key] = nil end
        for key, text in pairs(ns.BuildEnglish()) do L[key] = text end
        if want ~= "enUS" then loaders[want](L) end
        active = want
    end
    applied = true
    loaders = {}
    ns.BuildEnglish = nil
    for _, fill in ipairs(callbacks) do fill() end
    callbacks = {}
end

-- A change in the list: saved now, applied after a reload of the interface (a window offers it)
function ns:SetLanguageChoice(code)
    ns.sv.language = IsLanguage(code) and code or nil
    local target = ns.sv.language or clientCode
    if not IsLanguage(target) then target = "enUS" end
    if target ~= active then StaticPopup_Show("TESSERA_LANGUAGE_RELOAD") end
end
