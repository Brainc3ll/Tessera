-- Options.lua (first of the OptionsXxx.lua files)
-- Tessera's options window and everything around it.
--
-- Main parts, in file order:
--   Selection        which block(s) the "Blocks" tab edits: all blocks, all launchers or one block;
--                    smart placement of newly shown blocks (PlaceNearOptions) and SetField,
--                    which writes a setting to every selected block and remembers it as a default.
--   Widgets          small widget factory (header, note, checkbox, slider, dropdown, action
--                    dropdown, color swatch, button). Every widget has a Refresh() method and a
--                    layoutHeight, and is registered so RefreshOptions() can update them all.
--   Column layout    NewLayout(): stacks widgets top-down in two columns.
--   Tab builders     BuildBlockPage (Display / Text / Frame sub-tabs), BuildGeneralPage,
--                    BuildLaunchersPage, BuildProfilesPage, BuildHelpPage.
--   Window           SkinWindow() themes a Tessera window (FlareUI or Blizzard look);
--                    BuildPanel() creates the main window and its tabs; Open/Toggle functions.
--   Blizzard page    a small page under Options > AddOns that opens the real options window.
--   Placement banner shown while blocks are unlocked; hides the options window meanwhile.
--   Welcome popup    shown once on first launch.
--   Debug report     /tessera debug: prints diagnostics and shows them in a copyable window.
--
-- The options window is split in files, loaded in this order (see Tessera.toc): Options.lua (this one:
-- constants, selection, state), OptionsWidgets, OptionsBlocks, OptionsPages, OptionsHelp, OptionsWindow,
-- OptionsPlacement, OptionsTour. A file takes what it needs from earlier ones through ns.OptionsTools.
-- (Lua refuses more than 200 local variables in a file: tools/check_locals.py keeps each under 160.)
--
-- Note: some debug messages below are intentionally left in French (they are string literals).

local ADDON, ns = ...
local L = ns.L

-- State shared by the Options*.lua files: panel (the main window), selected (what the Blocks tab
-- edits), currentPage and aboutContent. A table, because a local variable cannot be shared.
local S = {}

-- Options window tabs:
--   Blocks     selection (all blocks, all launchers or a single block) and its settings
--   Look       style, how groups look, ready-made layouts, screen edges
--   General    moving, tooltips, combat, chat, minimap
--   Accessibility  colors of levels, high contrast, fewer animations, text size (1.3)
--   Launchers  add and edit launcher blocks and DataBroker blocks
--   Broker     share Tessera's blocks with DataBroker addons, DataBroker mode
--   Profiles   profiles and reset
--   Help       help topics (list on the left, selected topic on the right)
--   About      author, translators, license, links, and the changelog (same layout as Help)
-- In DataBroker mode (Broker.lua) only the Broker, Help and About tabs are shown.


local widgets = {}
local PAGE_BLOCKS, PAGE_LOOK, PAGE_GENERAL, PAGE_LAUNCHERS, PAGE_BROKER, PAGE_PROFILES, PAGE_HELP, PAGE_ABOUT =
    1, 2, 3, 4, 5, 6, 7, 8
-- (1.3) a page added later gets the next number (its texts, PAGE_HINT_<n>, keep theirs);
-- NAV_ORDER is where each one sits in the list on the left
local PAGE_ACCESS = 9
local NEWS_VERSION = "1.3" -- the version with a "What's new" window (ns:ShowNews)
local PAGE_COUNT = 9
local NAV_ORDER = { PAGE_BLOCKS, PAGE_LOOK, PAGE_GENERAL, PAGE_ACCESS, PAGE_LAUNCHERS, PAGE_BROKER,
    PAGE_PROFILES, PAGE_HELP, PAGE_ABOUT }
ns.OPTIONS_PAGE_COUNT = PAGE_COUNT
local HIDDEN_IN_BROKER_MODE = { [PAGE_BLOCKS] = true, [PAGE_LOOK] = true, [PAGE_GENERAL] = true,
    [PAGE_LAUNCHERS] = true, [PAGE_PROFILES] = true }
local pages, tabs = {}, {}
S.currentPage = PAGE_BLOCKS

-- Layout: 720 px window, two 300 px columns, 40 px margins (scaled down on small
-- screens, see FitPanelToScreen)
-- The window: a navigation list on the left (like the game's own settings), the page on the
-- right. Pages keep their own coordinates (COL_X): only their frame moves.
local NAV_W = 176            -- navigation list, on the left
local PAGE_TOP = -64         -- top of the pages, under the title
ns.OPTIONS_PAGE_TOP = PAGE_TOP
local SEARCH_W = 200         -- search box, in the top bar
local TOPBAR_RIGHT = 134     -- top bar, right of the lock button: the size (%), fold, close
local HELP_W = 260           -- help panel, on the right (1.3): explains the setting under the mouse
local PANEL_W, PANEL_H = 720 + NAV_W + HELP_W, 780
local COL_W = 300
local COL_X = { 40, 380 }
local FULL_W = COL_X[2] + COL_W - COL_X[1]
local SPACING = 4 -- vertical space between two rows (each row has its own air, ROW_PAD)

local ALL = "*all"            -- selection value "All blocks"
local LAUNCHERS = "*launchers" -- selection value "All launchers"
local GROUP_PREFIX = "*group:" -- selection value of a group: the prefix, then its head block
S.selected = ALL

---------------------------------------------------------------------------
-- Selection
---------------------------------------------------------------------------
-- Keys of all launcher blocks, in display order
local function LauncherKeys()
    local keys = {}
    for _, key in ipairs(ns:GetBlockKeys()) do
        if ns.IsLauncherKey(key) then table.insert(keys, key) end
    end
    return keys
end

-- Head block of the selected group of blocks (a bar and its rows), nil otherwise
local function GroupHead()
    if type(S.selected) == "string" and S.selected:sub(1, #GROUP_PREFIX) == GROUP_PREFIX then
        return S.selected:sub(#GROUP_PREFIX + 1)
    end
end

-- Members of a group that "All blocks"-like settings change: spacers keep their own look
local function GroupStyleKeys(head)
    local keys = {}
    for _, key in ipairs(ns:GetStyleGroup(head)) do
        if not ns.IsSpacerKey(key) then table.insert(keys, key) end
    end
    return keys
end

-- True when the selection is several blocks (all blocks, all launchers, one group)
-- rather than one block
local function IsGroup() return S.selected == ALL or S.selected == LAUNCHERS or GroupHead() ~= nil end

-- Blocks affected by a setting change
local function Targets()
    if S.selected == ALL then
        -- spacers keep their own look: "All blocks" does not change them
        -- (except their layer and visibility, see SPACER_SHARED_FIELDS)
        local keys = {}
        for _, key in ipairs(ns:GetBlockKeys()) do
            if not ns.IsSpacerKey(key) then table.insert(keys, key) end
        end
        return keys
    end
    if S.selected == LAUNCHERS then return LauncherKeys() end
    local head = GroupHead()
    if head then return GroupStyleKeys(head) end
    return { S.selected }
end

-- Block whose values are displayed (the first one of the selection)
local function Cfg()
    local key = Targets()[1]
    return key and ns.db.blocks[key]
end

-- Falls back to "All blocks" if the selected block or group no longer exists
local function ValidateSelection()
    if S.selected == ALL then return end
    if S.selected == LAUNCHERS then
        if #LauncherKeys() == 0 then S.selected = ALL end
        return
    end
    local head = GroupHead()
    if head then
        -- the group keeps its entry when its head changes (a block merged on its left)
        if ns.db.blocks[head] then head = ns:GetVisualRoot(head) end
        S.selected = (ns.db.blocks[head] and #GroupStyleKeys(head) >= 2) and (GROUP_PREFIX .. head) or ALL
        return
    end
    if not ns.db.blocks[S.selected] then S.selected = ALL end
end

-- State used by PlaceNearOptions: a counter for the fallback position, and the areas
-- of blocks placed during the last second (cleared by a timer)
local placedCount = 0
local recentPlaced, recentTimer = {}, nil

-- Does a block's saved position overlap another visible block?
function ns:OverlapsOtherBlock(key)
    local cfg, f = ns.db.blocks[key], ns.frames[key]
    if not cfg or not cfg.point or not f then return false end
    local ratio = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local l, b, r, t = ns:PointToRect(cfg.point, f:GetWidth() > 1 and f:GetWidth() or cfg.width or 60,
        cfg.height or 24, ratio)
    for k, o in pairs(ns.frames) do
        if k ~= key and o:IsShown() then
            local ol, ob, or_, ot = ns:GetRectUI(o)
            if ol and l < or_ - 2 and r > ol + 2 and b < ot - 2 and t > ob + 2 then return true end
        end
    end
    return false
end

-- Places a block that appears (never placed, or its old spot is taken) in a free
-- spot next to the options window: columns alternate right / left of the window,
-- nearest first, each scanned top to bottom. All maths in UIParent units.
function ns:PlaceNearOptions(key)
    local cfg = ns.db.blocks[key]
    if not cfg then return end
    cfg.dock, cfg.anchor = nil, nil
    -- real block width (text included): shown off-screen for a moment to measure it
    cfg.point = { "TOPLEFT", "BOTTOMLEFT", -2000, -2000 }
    ns:ApplyStyle(key)
    ns:UpdateBlock(key)
    local f = ns.frames[key]
    if not f then return end
    local ratio = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local needed = 0
    if f.text then
        local tw = f.text.GetUnboundedStringWidth and f.text:GetUnboundedStringWidth() or f.text:GetStringWidth()
        needed = math.ceil(tw or 0) + 8 + 2 * (f.inset or 0) + (cfg.showIcon and ((f.iconSize or 0) + 4) or 0)
    end
    local width = math.max(cfg.width or 60, needed, 100) * ratio
    local height = (cfg.height or 24) * ratio
    local step = height + 22 -- room for the block name above it
    local screenW = UIParent:GetWidth()

    -- areas already taken: visible blocks, blocks placed in the same click (the game
    -- has not recomputed their position yet), the options window
    local taken = {}
    for k, o in pairs(ns.frames) do
        if k ~= key and o:IsShown() and not recentPlaced[k] then
            local l, b, r, t = ns:GetRectUI(o)
            if l then table.insert(taken, { l, b, r, t + 18 }) end
        end
    end
    for k, z in pairs(recentPlaced) do
        if k ~= key then table.insert(taken, z) end
    end
    local pl, pb, pr, pt
    if S.panel and S.panel:IsShown() then
        pl, pb, pr, pt = ns:GetRectUI(S.panel)
        if pl then table.insert(taken, { pl, pb, pr, pt }) end
    end
    -- Blizzard's action bars, minimap, chat...: a block placed on them could be hidden
    for _, z in ipairs(ns:GetBlizzardRects()) do table.insert(taken, z) end
    local function Free(x, y)
        local l, b, r, t = x - 4, y - height - 4, x + width + 4, y + 18
        for _, z in ipairs(taken) do
            if l < z[3] and r > z[1] and b < z[4] and t > z[2] then return false end
        end
        return true
    end

    -- candidate columns: right 1, left 1, right 2, left 2... (around the screen
    -- center when the options window is closed)
    local right0, left0, top
    if pl then
        right0, left0, top = pr + 20, pl - 20 - width, pt - 20
    else
        right0 = screenW / 2 + 10
        left0 = screenW / 2 - 10 - width
        top = UIParent:GetHeight() / 2 + 160
    end
    -- highest free slot of a column, above the bottom of the screen (action bars area)
    local BOTTOM = 140
    local function FirstFree(cx)
        if not cx then return nil end
        for row = 0, math.floor((top - height - BOTTOM) / step) do
            local cy = top - row * step
            if Free(cx, cy) then return cy end
        end
    end
    -- columns go in pairs (right n, left n): the side with the higher free slot wins, so
    -- both sides of the window fill up evenly instead of one long column on the right
    local x, y
    for i = 0, 12 do
        local rx, lx = right0 + i * (width + 16), left0 - i * (width + 16)
        local ry = (rx + width <= screenW) and FirstFree(rx) or nil
        local ly = (lx >= 0) and FirstFree(lx) or nil
        if ry and (not ly or ry >= ly) then
            x, y = rx, ry
        elseif ly then
            x, y = lx, ly
        end
        if x then break end
    end
    if not x then -- screen full: fallback position
        x, y = math.max(0, math.min(right0, screenW - width)), top - (placedCount % 10) * step
    end
    placedCount = placedCount + 1
    recentPlaced[key] = { x, y - height, x + width, y + 18 }
    if not recentTimer then
        recentTimer = true
        C_Timer.After(1, function()
            recentTimer = nil
            wipe(recentPlaced)
        end)
    end
    cfg.point = ns:MakeRelativePoint(x, y - height, x + width, y, ratio)
    ns:ApplyStyle(key)
end

function ns:RefreshOptions()
    if not S.panel then return end
    ValidateSelection()
    for _, w in ipairs(widgets) do
        if w.isShown then
            local shown = w.isShown() and true or false
            w:SetShown(shown)
            if w.check then w.check:SetShown(shown) end -- a check box follows its row
        end
        if w.Refresh then w:Refresh() end
    end
    if ns.RelayoutBlockOptions then ns.RelayoutBlockOptions() end
    if ns.ReflowOptionLayouts then ns.ReflowOptionLayouts() end -- folded sections, column 2
end

-- Per-block settings, never stored as defaults for other blocks
local PER_BLOCK_FIELDS = { enabled = true, width = true, height = true }

-- Writes a setting to every selected block. Newly shown blocks get a style and a
-- free position; group changes are also saved as defaults for future blocks.
-- Settings that "All blocks" also gives to spacers: a spacer keeps its own look
-- (colors, frame), but it must stay on the same layer as the blocks around it, and
-- show, hide and fade with them
local SPACER_SHARED_FIELDS = {
    strata = true, alpha = true, fadeOut = true, fadeAlpha = true, fadeShowCombat = true,
    hideInCombat = true, hideInInstance = true, hideInVehicle = true, hideWhenResting = true,
}

-- Puts blocks on the screen or takes them off it ("On screen" checkbox). Undoable.
--   * off: each block leaves its group (the blocks around it close the gap) and keeps
--     its look and settings;
--   * on: a block with no place appears next to the options window; one that was never
--     on screen takes the look of the reference block, one that comes back keeps its own.
function ns:SetBlocksOnScreen(keys, on)
    local refKey = on and self:GetReferenceBlock()
    self:PushUndo()
    local regroup = false
    for _, key in ipairs(keys) do
        local cfg = self.db.blocks[key]
        if cfg then
            if on and not cfg.enabled then
                cfg.enabled = true
                if not cfg.point and not cfg.dock and not cfg.anchor then
                    if not cfg.keepLook and refKey and refKey ~= key then self:AdoptReferenceStyle(key, refKey) end
                    self:PlaceNearOptions(key)
                elseif not cfg.dock and not cfg.anchor and self:OverlapsOtherBlock(key) then
                    self:PlaceNearOptions(key) -- its old spot is taken: find a free one
                end
            elseif not on and cfg.enabled then
                if ns.LeaveGroupData(self.db.blocks, key) then regroup = true end
                cfg.enabled = false
                cfg.keepLook = true
            end
            self:ApplyStyle(key)
        end
    end
    if regroup then
        self:RefreshAllBlocks()
        self:RequestLayout()
    end
end

-- Taking several blocks off the screen at once (a group, "All blocks") asks first
StaticPopupDialogs["TESSERA_REMOVE_BLOCKS"] = {
    text = L.REMOVE_BLOCKS_CONFIRM,
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, keys)
        ns:SetBlocksOnScreen(keys, false)
        if ns.RefreshOptions then ns:RefreshOptions() end
    end,
    OnCancel = function() if ns.RefreshOptions then ns:RefreshOptions() end end,
}

-- Everything the other Options*.lua files import (they are loaded after this one)
ns.OptionsTools = {
    S = S,
    ALL = ALL,
    COL_W = COL_W,
    COL_X = COL_X,
    Cfg = Cfg,
    FULL_W = FULL_W,
    GROUP_PREFIX = GROUP_PREFIX,
    GroupHead = GroupHead,
    HELP_W = HELP_W,
    HIDDEN_IN_BROKER_MODE = HIDDEN_IN_BROKER_MODE,
    IsGroup = IsGroup,
    LAUNCHERS = LAUNCHERS,
    LauncherKeys = LauncherKeys,
    NAV_ORDER = NAV_ORDER,
    NAV_W = NAV_W,
    NEWS_VERSION = NEWS_VERSION,
    PAGE_ABOUT = PAGE_ABOUT,
    PAGE_ACCESS = PAGE_ACCESS,
    PAGE_BLOCKS = PAGE_BLOCKS,
    PAGE_BROKER = PAGE_BROKER,
    PAGE_GENERAL = PAGE_GENERAL,
    PAGE_HELP = PAGE_HELP,
    PAGE_LAUNCHERS = PAGE_LAUNCHERS,
    PAGE_LOOK = PAGE_LOOK,
    PAGE_PROFILES = PAGE_PROFILES,
    PAGE_TOP = PAGE_TOP,
    PANEL_H = PANEL_H,
    PANEL_W = PANEL_W,
    PER_BLOCK_FIELDS = PER_BLOCK_FIELDS,
    SEARCH_W = SEARCH_W,
    SPACER_SHARED_FIELDS = SPACER_SHARED_FIELDS,
    SPACING = SPACING,
    TOPBAR_RIGHT = TOPBAR_RIGHT,
    Targets = Targets,
    ValidateSelection = ValidateSelection,
    pages = pages,
    tabs = tabs,
    widgets = widgets,
}

