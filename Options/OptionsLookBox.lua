local _, ns = ...
local L = ns.L

-- The look settings, gathered (27/11, Braincell1980): under the style come the font, the text
-- size, the corners, the icons and the effects, always in this order, in two places: the Style
-- box of the Style and layouts tab (every block) and the Style box at the top of a block's
-- Appearance tab (this block, its group or every block). The style row itself is built by each
-- page (its own list and buttons); the rows below it come from ns.LOOK_ROWS, so both places
-- keep the same rows in the same order. Nothing here is saved in a new way: each row writes the
-- block field it always wrote.
local Tools = ns.OptionsTools
local CreateCheck, CreateDropdown, CreateSlider = Tools.CreateCheck, Tools.CreateDropdown, Tools.CreateSlider

local function FontChoices() return ns:GetMediaList("font") end
local function EdgeChoices()
    return { { key = "round", name = L.EDGE_SHAPE_ROUND }, { key = "pixel", name = L.EDGE_SHAPE_PIXEL } }
end
local function IconChoices()
    return {
        { key = "classic", name = L.ICON_SET_CLASSIC },
        { key = "hd", name = L.ICON_SET_HD },
        { key = "hdTint", name = L.ICON_SET_HD_TINT },
    }
end
-- separators (27/11): the line, or an ornament in its place, for any style
function ns.SeparatorChoices()
    return {
        { key = "line", name = L.SEPARATOR_LINE },
        { key = "diamond", name = L.SEPARATOR_DIAMOND },
        { key = "rune", name = L.SEPARATOR_RUNES },
        { key = "dot", name = L.SEPARATOR_DOT },
    }
end

-- Corners only matter with the rounded borders of Gilded, Blue rune, Silver and Brazen
local function HDBorder(cfg) return cfg ~= nil and ns:FindMedia("border", cfg.border).hd and true or false end
local function AnyHDBorder()
    for _, cfg in pairs(ns.db.blocks) do
        if HDBorder(cfg) then return true end
    end
    return false
end
local function HDIcons() return ns.HD_ICONS_ON end

-- The rows under the style, in order. look: which blocks "every block" counts (Core.lua,
-- ns:AllBlocksField): true = spacers too (they take the style's frame), "blocks" or "icons" =
-- without the spacers. Locked blocks are never counted nor changed. shownOne / shownAll: when
-- the row is useful for the selection / for every block. (The style gallery's workshop reads
-- this list too.)
ns.LOOK_ROWS = {
    { field = "font", label = "FONT", kind = "list", choices = FontChoices, look = "blocks",
      tip = "TIP_FONT", tipAll = "TIP_FONT_ALL" },
    { field = "fontSize", label = "FONT_SIZE", kind = "slider", min = 6, max = 32, look = "blocks",
      tip = "TIP_FONT_SIZE", tipAll = "TIP_FONT_SIZE_ALL" },
    { field = "edgeShape", label = "EDGE_SHAPE", kind = "list", choices = EdgeChoices, look = true,
      tip = "TIP_EDGE_SHAPE", tipAll = "TIP_EDGE_SHAPE_ALL", shownOne = HDBorder, shownAll = AnyHDBorder },
    { field = "iconSet", label = "ICON_SET", kind = "list", choices = IconChoices, look = "icons",
      tip = "TIP_ICON_SET", tipAll = "TIP_ICON_SET_ALL", shownOne = HDIcons, shownAll = HDIcons },
    { field = "hoverGlow", label = "HOVER_GLOW", kind = "check", half = true, look = "blocks",
      tip = "TIP_HOVER_GLOW", tipAll = "TIP_HOVER_GLOW_ALL" },
    { field = "valueGlide", label = "VALUE_GLIDE", kind = "check", half = true, look = "blocks",
      tip = "TIP_VALUE_GLIDE", tipAll = "TIP_VALUE_GLIDE_ALL" },
}

-- A list for every block: "Mixed" first when the blocks differ
local function WithMixed(choices, mixed)
    return function()
        local list = {}
        if mixed() then list[1] = { key = "mixed", name = L.FONT_MIXED } end
        for _, item in ipairs(choices()) do list[#list + 1] = item end
        list.mayGrow = true
        return list
    end
end

-- Adds the rows of ns.LOOK_ROWS to box. all = true: every block (Style and layouts tab); otherwise
-- the selection of the Blocks tab (Cfg: its first block), through the usual block fields, so
-- Reset, Ctrl + Z and the pages with several blocks work as for any other setting.
function Tools.AddLookRows(box, parent, all, Cfg)
    for _, spec in ipairs(ns.LOOK_ROWS) do
        local w
        local label, look = L[spec.label], spec.look
        if all then
            local field = spec.field
            local function get() return ns:AllBlocksField(field, look) end
            local function getFirst() return ns:AllBlocksField(field, look, true) end
            local function set(v)
                if v == "mixed" then return end
                ns:SetAllBlocksField(field, v, look)
                if spec.kind ~= "slider" then ns:RefreshOptions() end -- (a slider: not at each step)
            end
            local tip, shown = L[spec.tipAll], spec.shownAll
            if spec.kind == "list" then
                w = CreateDropdown(parent, label, WithMixed(spec.choices, function() return get() == nil end),
                    function() return get() or "mixed" end, set, shown, nil, tip)
            elseif spec.kind == "slider" then
                w = CreateSlider(parent, label, spec.min, spec.max, 1, getFirst, set, shown, tip)
            else
                w = CreateCheck(parent, label, function() return getFirst() and true or false end, set, shown, tip)
            end
        else
            local get, set = Tools.Field(spec.field)
            local tip = L[spec.tip]
            local shown = spec.shownOne and function() return spec.shownOne(Cfg()) end
            if spec.kind == "list" then
                w = CreateDropdown(parent, label, spec.choices, get, set, shown, nil, tip)
            elseif spec.kind == "slider" then
                w = CreateSlider(parent, label, spec.min, spec.max, 1, get, set, shown, tip)
            else
                w = CreateCheck(parent, label, get, set, shown, tip)
            end
            w.field = spec.field
        end
        w.lookField = spec.field -- (tools/mock_run.lua: the same rows, in the same order, in both places)
        box.Add(w, { half = spec.half })
    end
end
