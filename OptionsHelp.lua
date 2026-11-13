local ADDON, ns = ...
local L = ns.L

-- Help part of the options window: themed windows (SkinWindow), the help text and the Help and About tabs.
-- Shared with the other Options*.lua files through ns.OptionsTools (see Options.lua).
local Tools = ns.OptionsTools
local S = Tools.S
local AttachTip, COL_X, CreateButton, FULL_W = Tools.AttachTip, Tools.COL_X, Tools.CreateButton, Tools.FULL_W
local HELP_W, NAV_W, NEWS_VERSION, PANEL_W = Tools.HELP_W, Tools.NAV_W, Tools.NEWS_VERSION, Tools.PANEL_W
local Register = Tools.Register


---------------------------------------------------------------------------
-- Window, skinned according to the theme (FlareUI or Blizzard)
---------------------------------------------------------------------------
-- The window's background reaches under the border's line: the textures' own insets (made
-- for tooltips and dialogs) leave a see-through line a few pixels wide on a large window
local WINDOW_FILL = 3
local ATLAS_MIN_HEIGHT = 220 -- smallest window that gets an expansion's art frame
local function WindowInset(t)
    local inset = t.inset or 0
    if t.edgeFile and inset >= 4 then return inset - 2 end
    return inset
end

-- Skins a Tessera window with the chosen theme (options window, placement banner, ...)
function ns:SkinWindow(frame, title)
    self:FollowWindowSize(frame) -- Shift + mouse wheel: the size of Tessera's windows
    local t = self:GetThemeInfo(self:GetTheme()).window()
    if title then title:SetTextColor(unpack(t.title)) end
    -- the expansion frames (The War Within, Midnight) are drawn for large windows: on a small
    -- one (placement banner, its info panel) their thick border crowds the text, so a small
    -- window takes the style's plain frame in the same colors
    local small = (frame:GetHeight() or 0) < ATLAS_MIN_HEIGHT
    if t.borderAtlas and not small and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(t.borderAtlas) then
        self:ApplySkin(frame, { kind = "atlas", borderAtlas = t.borderAtlas, bgAtlas = t.bgAtlas, bg = t.atlasBg or t.bg, bgInset = t.bgInset })
    elseif t.nineSlice and NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
        self:ApplySkin(frame, { kind = "modern", layout = t.nineSlice, border = t.border, bg = t.bg, desaturate = t.desaturate })
        -- the tooltip layout keeps its center a few pixels inside the border (made for small
        -- tooltips): on a large window that leaves a see-through line, so the center fills up to it
        if frame.Center then
            frame.Center:ClearAllPoints()
            frame.Center:SetPoint("TOPLEFT", WINDOW_FILL, -WINDOW_FILL)
            frame.Center:SetPoint("BOTTOMRIGHT", -WINDOW_FILL, WINDOW_FILL)
        end
    else
        self:ApplySkin(frame, {
            kind = "backdrop",
            info = {
                bgFile = t.bgFile,
                edgeFile = t.edgeFile,
                edgeSize = t.edgeSize,
                tile = t.tile or false,
                tileSize = t.tileSize,
                insets = { left = WindowInset(t), right = WindowInset(t), top = WindowInset(t), bottom = WindowInset(t) },
            },
            border = t.border, bg = t.bg,
        })
    end
end

-- Re-skins the open Tessera windows after a theme change
function ns:SkinOptions()
    if S.panel then self:SkinWindow(S.panel, S.panel.title) end
    self:RepaintAccents() -- section lines in the new style's colors
    if self.banner then self:SkinWindow(self.banner, self.banner.text) end
end

---------------------------------------------------------------------------
-- "Help" tab
---------------------------------------------------------------------------
-- Builds the "Help" tab: scrollable help text
-- Splits a help text into sections. A section starts with a header line
-- written in the help title color (|cffffd100Title|r). Returns a list of
-- { title = "...", body = "..." }; text before the first header, if any,
-- becomes an untitled first section.
local HEADER_PATTERN = "|cffffd100(.-)|r\n"
local function SplitHelp(fullText)
    local sections = {}
    local pos = 1
    local headerStart, headerEnd, title = fullText:find(HEADER_PATTERN, pos)
    if headerStart and headerStart > 1 then
        local intro = strtrim(fullText:sub(1, headerStart - 1))
        if intro ~= "" then table.insert(sections, { title = "", body = intro }) end
    end
    if not headerStart then
        return { { title = "", body = fullText } }
    end
    while headerStart do
        local nextStart, nextEnd, nextTitle = fullText:find(HEADER_PATTERN, headerEnd + 1)
        local body = fullText:sub(headerEnd + 1, (nextStart or #fullText + 1) - 1)
        table.insert(sections, { title = title, body = strtrim(body) })
        headerStart, headerEnd, title = nextStart, nextEnd, nextTitle
    end
    return sections
end
ns.SplitHelp = SplitHelp -- used by tools/mock_run.lua

-- Joins the help from its translation keys: each topic of the layout (ns.HELP_LAYOUT,
-- written at the end of Locales/enUS.lua) is a title key and a list of line keys, "" being
-- an empty line. One key per line, so changing a line only asks translators to redo that line.
function ns.HelpText(layout)
    local parts = {}
    for _, topic in ipairs(layout or {}) do
        parts[#parts + 1] = "|cffffd100" .. (L[topic.title] or "") .. "|r"
        for _, key in ipairs(topic.lines) do
            parts[#parts + 1] = key == "" and "" or (L[key] or "")
        end
        parts[#parts + 1] = ""
    end
    return table.concat(parts, "\n")
end

-- The help topics with their chapters: a topic's lines are cut at each "" of the layout, and
-- each chapter is drawn apart, with a thin line between (BuildTopicPage). Topics that end a
-- group of the list (the list shows a line under them) are named here.
-- Groups: getting started (in short, using blocks, WoW Forever) / placing (place, replace,
-- Blizzard's frames) / the settings tabs (Blocks, Look, General, Accessibility, Profiles) /
-- other addons (Launchers, DataBroker) / Help, About and commands
local HELP_GROUP_END = { HELP_T_FOREVER = true, HELP_T_EDITMODE = true, HELP_T_PROFILES = true,
    HELP_T_BROKER = true }
local function HelpSections(layout)
    local sections = {}
    for _, topic in ipairs(layout or {}) do
        local chunks, current = {}, {}
        for _, key in ipairs(topic.lines) do
            if key == "" then
                if #current > 0 then chunks[#chunks + 1] = table.concat(current, "\n"); current = {} end
            else
                current[#current + 1] = L[key] or ""
            end
        end
        if #current > 0 then chunks[#chunks + 1] = table.concat(current, "\n") end
        sections[#sections + 1] = { title = L[topic.title] or "", body = strtrim(table.concat(chunks, "\n")),
            chunks = chunks, groupEnd = HELP_GROUP_END[topic.title] }
    end
    return sections
end

-- Topic page (Help and About tabs): a list of topics on the left, the selected
-- topic on the right. This keeps each screen short instead of one long wall of text.
-- getSections() returns a key and the list of { title, body, raw } sections; the
-- topics are rebuilt only when the key changes. Unless "raw" is set, an empty line
-- is added between the paragraphs of a topic. Returns the content frame, with
-- Refresh() and ShowTopic(index).
local TOPIC_W, TOPIC_H = 165, 22
local function BuildTopicPage(page, getSections, bottomRoom)
    bottomRoom = bottomRoom or 0 -- room kept free at the bottom (About: the links)
    local topicList = CreateFrame("Frame", nil, page)
    topicList:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[1] - 12, -6)
    topicList:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1] - 12, 70 + bottomRoom)
    topicList:SetWidth(TOPIC_W)

    -- thin vertical line between the topics and the text
    local divider = page:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 0.82, 0, 0.25)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", topicList, "TOPRIGHT", 6, 0)
    divider:SetPoint("BOTTOMLEFT", topicList, "BOTTOMRIGHT", 6, 0)

    local textX = COL_X[1] - 12 + TOPIC_W + 18
    local textW = PANEL_W - NAV_W - HELP_W - textX - 48
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, page, "ScrollFrameTemplate")
    if not ok then scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate") end
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", textX, -6)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -40, 24 + bottomRoom)
    if ns.OptionsZoomOnShiftWheel then ns.OptionsZoomOnShiftWheel(scroll) end

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(textW, 10)
    scroll:SetScrollChild(content)

    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetWidth(textW)
    title:SetJustifyH("LEFT")

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetWidth(textW)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)

    local buttons, sections, chapters, groupLines = {}, {}, {}, {}

    local function ShowSection(index)
        local section = sections[index]
        if not section then return end
        title:SetText(section.title)
        -- an empty line between paragraphs (each line of the text), for more air
        local function Paragraphs(body)
            return section.raw and body or (body:gsub("\n+", "\n\n"))
        end
        local chunks = section.chunks
        text:SetText(Paragraphs(chunks and chunks[1] or section.body))
        -- the other chapters: a thin line, then the chapter
        local height = title:GetStringHeight() + 10 + text:GetStringHeight()
        local above = text
        local extra = chunks and #chunks - 1 or 0
        for n = 1, math.max(extra, #chapters) do
            local c = chapters[n]
            if n <= extra then
                if not c then
                    c = { line = content:CreateTexture(nil, "ARTWORK"), text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight") }
                    c.line:SetColorTexture(1, 0.82, 0, 0.25)
                    c.line:SetHeight(1)
                    c.text:SetWidth(textW)
                    c.text:SetJustifyH("LEFT")
                    c.text:SetSpacing(3)
                    chapters[n] = c
                end
                c.line:ClearAllPoints()
                c.line:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -12)
                c.line:SetWidth(textW)
                c.line:Show()
                c.text:ClearAllPoints()
                c.text:SetPoint("TOPLEFT", c.line, "BOTTOMLEFT", 0, -12)
                c.text:SetText(Paragraphs(chunks[n + 1]))
                c.text:Show()
                height = height + 25 + c.text:GetStringHeight()
                above = c.text
            elseif c then
                c.line:Hide()
                c.text:Hide()
            end
        end
        content:SetHeight(height + 20)
        if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
        for i, b in ipairs(buttons) do
            local selectedTopic = (i == index)
            b.mark:SetShown(selectedTopic)
            if selectedTopic then
                b.label:SetTextColor(1, 0.82, 0)
            else
                b.label:SetTextColor(0.9, 0.9, 0.9)
            end
        end
    end

    local function TopicButton(i)
        if buttons[i] then return buttons[i] end
        local b = CreateFrame("Button", nil, topicList)
        b:SetSize(TOPIC_W, TOPIC_H)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        b.mark = b:CreateTexture(nil, "ARTWORK")
        b.mark:SetColorTexture(1, 0.82, 0, 0.9)
        b.mark:SetSize(3, TOPIC_H - 6)
        b.mark:SetPoint("LEFT", b, "LEFT", 0, 0)
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.label:SetPoint("LEFT", b, "LEFT", 10, 0)
        b.label:SetPoint("RIGHT", b, "RIGHT", -4, 0)
        b.label:SetJustifyH("LEFT")
        b.label:SetWordWrap(true) -- long titles wrap on two lines
        b:SetScript("OnClick", function() ShowSection(i) end)
        buttons[i] = b
        return b
    end

    local shownKey
    content.Refresh = function()
        local key, wanted = getSections()
        if key == shownKey then return end
        shownKey = key
        sections = wanted
        local y = 0
        for i, section in ipairs(sections) do
            local b = TopicButton(i)
            b.label:SetText(section.title ~= "" and section.title or "...")
            b:SetHeight(math.max(TOPIC_H, (b.label:GetStringHeight() or 0) + 8))
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", topicList, "TOPLEFT", 0, -y)
            y = y + b:GetHeight() + 2
            b:Show()
            -- a thin line under the last topic of a group
            local line = groupLines[i]
            if not line then
                line = topicList:CreateTexture(nil, "ARTWORK")
                line:SetColorTexture(1, 0.82, 0, 0.25)
                line:SetHeight(1)
                groupLines[i] = line
            end
            if section.groupEnd and i < #sections then
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", topicList, "TOPLEFT", 8, -(y + 4))
                line:SetWidth(TOPIC_W - 16)
                line:Show()
                y = y + 10
            else
                line:Hide()
            end
        end
        for i = #sections + 1, #buttons do buttons[i]:Hide() end
        for i = #sections + 1, #groupLines do groupLines[i]:Hide() end
        ShowSection(1)
    end
    content.ShowTopic = function(_, index) ShowSection(index) end
    content:Refresh()
    Register(content)
    return content
end

-- Help tab. In DataBroker mode, only the help of that mode (how to leave it comes first).
local function BuildHelpPage(page)
    local cache = {}
    BuildTopicPage(page, function()
        local wanted = ns.brokerModeActive and "broker" or "normal"
        cache[wanted] = cache[wanted]
            or HelpSections(ns.brokerModeActive and ns.HELP_LAYOUT_BROKER or ns.HELP_LAYOUT)
        return wanted, cache[wanted]
    end, 26) -- room for the three buttons below the topics
    -- the quick tour can be started again from here (not in DataBroker mode: no blocks)
    local tour = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    tour:SetSize(TOPIC_W, 22)
    tour:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1] - 12, 14)
    tour:SetText(L.TUTORIAL_START)
    tour:SetScript("OnClick", function() ns:StartTutorial() end)
    AttachTip(tour, L.TUTORIAL_START, L.TIP_TUTORIAL_START)
    tour.Refresh = function() end
    Register(tour, function() return not ns.brokerModeActive end)
    -- demo mode: every block, by category, with sample values (Demo.lua)
    local demo = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    demo:SetSize(TOPIC_W, 22)
    demo:SetPoint("BOTTOMLEFT", tour, "TOPLEFT", 0, 4)
    demo:SetText(L.DEMO_BUTTON)
    demo:SetScript("OnClick", function()
        if S.panel and S.panel:IsShown() then ns:ToggleOptions() end -- the blocks must be visible
        ns:StartDemo()
    end)
    AttachTip(demo, L.DEMO_BUTTON, L.TIP_DEMO_BUTTON)
    demo.Refresh = function() end
    Register(demo, function() return not ns.brokerModeActive end)
    -- what changed in 1.3, with buttons that open the right places
    local whatsNew = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    whatsNew:SetSize(TOPIC_W, 22)
    whatsNew:SetPoint("BOTTOMLEFT", demo, "TOPLEFT", 0, 4)
    whatsNew:SetText(L.NEWS_BUTTON:format(NEWS_VERSION))
    whatsNew:SetScript("OnClick", function() ns:ShowNews() end)
    AttachTip(whatsNew, L.NEWS_BUTTON:format(NEWS_VERSION), L.TIP_NEWS_BUTTON)
    whatsNew.Refresh = function() end
    Register(whatsNew, function() return not ns.brokerModeActive end)
end

---------------------------------------------------------------------------
-- "About" tab: author, translators, license, links (topic "About") and the
-- changelog from Changelog.lua (topic "Changelog")
---------------------------------------------------------------------------
local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or function() end
local SOURCE_URL = "https://github.com/Brainc3ll/Tessera"
local CHANGELOG_TOPIC = 2 -- second topic of the About tab
-- S.aboutContent: content frame of the About tab, to open the changelog topic

local function ChangelogText()
    local lang = GetLocale() == "frFR" and "fr" or "en"
    local lines = {}
    for _, entry in ipairs(ns.CHANGELOG or {}) do
        -- an empty line after the version title and between changes, for more air
        table.insert(lines, ("|cffffd100%s|r  |cff999999%s|r"):format(entry.version, entry.date or ""))
        -- changes sorted by kind (new, improvements, fixes) since 1.0.0
        for _, section in ipairs(ns.ChangelogSections(entry, lang)) do
            if section.title then
                table.insert(lines, "")
                table.insert(lines, ("|cff8fc7ff%s|r"):format(section.title))
            end
            for _, change in ipairs(section.lines) do
                table.insert(lines, "")
                table.insert(lines, "- " .. change)
            end
        end
        table.insert(lines, "")
        table.insert(lines, "")
    end
    return table.concat(lines, "\n")
end

local function AboutText()
    local function InfoLine(label, value)
        return ("|cffffd100%s|r  %s"):format(label, value)
    end
    local version = GetMetadata and GetMetadata(ADDON, "Version") or "?"
    local author = GetMetadata and GetMetadata(ADDON, "Author") or "Braincell1980"
    local lines = {
        InfoLine(L.ABOUT_VERSION, version),
        InfoLine(L.ABOUT_AUTHOR, author),
    }
    -- translators of the current language (empty in English: the line is hidden)
    if L.ABOUT_TRANSLATORS and L.ABOUT_TRANSLATORS ~= "" then
        table.insert(lines, InfoLine(L.ABOUT_TRANSLATION, L.ABOUT_TRANSLATORS))
    end
    -- a translation made by Claude and not reviewed by a player yet says so (empty in English
    -- and French; the translator who reviews a language empties it)
    if L.ABOUT_TRANSLATION_NOTE and L.ABOUT_TRANSLATION_NOTE ~= "" then
        table.insert(lines, "|cffffb040" .. L.ABOUT_TRANSLATION_NOTE .. "|r")
    end
    table.insert(lines, InfoLine(L.ABOUT_GAME, "WoW Forever"))
    table.insert(lines, InfoLine(L.ABOUT_LICENSE, "MIT"))
    table.insert(lines, InfoLine(L.ABOUT_SOURCE, SOURCE_URL))
    table.insert(lines, "")
    table.insert(lines, L.ABOUT_AI)
    table.insert(lines, "")
    if L.ABOUT_THANKS and L.ABOUT_THANKS ~= "" then
        table.insert(lines, L.ABOUT_THANKS)
        table.insert(lines, "")
    end
    if L.ABOUT_THANKS_2 and L.ABOUT_THANKS_2 ~= "" then
        table.insert(lines, L.ABOUT_THANKS_2)
        table.insert(lines, "")
    end
    table.insert(lines, L.ABOUT_BUGS)
    table.insert(lines, "")
    table.insert(lines, L.ABOUT_TRANSLATE)
    return table.concat(lines, "\n")
end

-- Links of the About tab (1.3): the game opens no browser, so a button per link puts
-- it, selected, in one copy box of the page (inside the window: never behind it)
local ABOUT_LINKS = {
    { "GitHub", SOURCE_URL },
    { "ABOUT_LINK_ISSUES", SOURCE_URL .. "/issues" },
    { "CurseForge", "https://www.curseforge.com/wow/addons/tessera" },
    { "Wago", "https://addons.wago.io/addons/tessera" },
    -- the thanks to Malkkav: his addon's page (FlareUI is the addon's name, not translated)
    { "FlareUI", "https://www.curseforge.com/wow/addons/flareui" },
}

-- A copy box: shows a link, selected on focus; typing changes nothing
local function CopyBox(parent, width, getText)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(getText())
            self:HighlightText()
        end
    end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end
local function BuildAboutLinks(page)
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1], 88)
    title:SetText(L.ABOUT_LINKS)
    -- Tessera's links: a button puts its link in the shared box
    local current = ""
    local box = CopyBox(page, FULL_W - 150, function() return current end)
    box:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1] + 6, 26)
    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("LEFT", box, "RIGHT", 10, 0)
    hint:SetText(L.ABOUT_COPY_HINT)
    local w = math.floor((FULL_W - 3 * 6) / #ABOUT_LINKS)
    for i, link in ipairs(ABOUT_LINKS) do
        local name = L[link[1]] or link[1]
        local b = CreateButton(page, name, function()
            current = link[2]
            box:SetText(current)
            box:SetFocus()
            box:HighlightText()
        end, nil, w, L.TIP_ABOUT_COPY)
        b:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", COL_X[1] + (i - 1) * (w + 6), 54)
    end
    AttachTip(box, L.ABOUT_LINKS, L.TIP_ABOUT_COPY)
end

local function BuildAboutPage(page)
    local sections -- built once: the version and language do not change in a session
    S.aboutContent = BuildTopicPage(page, function()
        sections = sections or {
            { title = L.TAB_ABOUT, body = AboutText(), raw = true },
            { title = L.CHANGELOG_TITLE, body = ChangelogText(), raw = true },
        }
        return "about", sections
    end, 88)
    BuildAboutLinks(page)
    -- the tab always opens on "About" (the "what's new" popup then asks for the changelog)
    page:HookScript("OnShow", function() S.aboutContent:ShowTopic(1) end)
end

-- Small screens: the window shrinks so a column of blocks still fits on each side
-- of it (blocks shown from the options appear left and right of the window), and
-- it never gets taller than the screen. Full size on large screens.
---------------------------------------------------------------------------
-- No window over another: Tessera's other windows (quick tour, text / import window,
-- style offer) open one at a time, and beside the options window, never on it.
---------------------------------------------------------------------------
local sideWindows = {}

-- Shared with the files loaded after this one
Tools.BuildAboutPage = BuildAboutPage
Tools.BuildHelpPage = BuildHelpPage
Tools.CHANGELOG_TOPIC = CHANGELOG_TOPIC
Tools.GetMetadata = GetMetadata
Tools.sideWindows = sideWindows

