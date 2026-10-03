-- The Rings page, in three tabs under the preview: a ring round the cursor,
-- cast progress round the cursor, and the highlight that marks where the
-- cursor is while the game hides it to turn or look around (a see-through
-- copy of the game's pointer). Each has its size, opacity and colour (your
-- class's, one of your own, or the trail's); the highlight's colour is a
-- gentle tint, none at first.
-- A tab only shows its effect's settings: each says whether its effect is
-- on, and while it's off the tick that turns it on is lit in the accent.
local _, ns = ...
local T = ns.Theme
local P = ns.PageParts

local TABS = {
    { key = "ring", label = "Cursor ring", colour = "Ring colour", note = "A ring round the cursor, so it's easy to find." },
    { key = "cast", label = "Cast ring", colour = "Cast ring colour",
        note = "Cast progress round the cursor: it fills as you cast and drains as you channel." },
    { key = "look", label = "While looking", colour = "Highlight tint",
        note = "A see-through pointer where the cursor comes back while the game hides it to turn or look around." },
}
local TAB_WIDTH = 422 -- three tabs of 140
local COLOUR_NAMES = { class = "Class", custom = "Custom", trail = "Trail's" }
local COLOUR_NOTES = {
    class = "Your class's colour.",
    custom = "A colour of your own: pick it on the right.",
    trail = "The trail's colour at the cursor (the Colours page), flowing with it when its colours move.",
}
-- The highlight is the game's pointer: untinted, or a gentle wash of a colour.
local TINT_NAMES = { none = "None", class = "Class", custom = "Custom", trail = "Trail's" }
local TINT_NOTES = {
    none = "The game's own pointer as it is, only see-through.",
    class = "A gentle wash of your class's colour over the pointer.",
    custom = "A gentle wash of a colour of your own over the pointer: pick it on the right.",
    trail = "A gentle wash of the trail's colour at the cursor (the Colours page), flowing with it when its colours move.",
}
local NOTES = {
    ring = "A ring round the cursor, so it's easy to find.",
    ringSize = "How wide the ring is across, in pixels.",
    ringThickness = "How thick the ring's line is, in pixels.",
    ringAlpha = "How solid the ring is, in percent.",
    ringCustom = "The ring's own colour, for Custom: click to pick it in the colour picker.",
    cast = "Cast progress round the cursor: the ring fills as you cast and drains as you channel. An interrupted cast hides it at once.",
    castSize = "How wide the cast ring is across, in pixels. With the cursor ring on, it grows to sit just outside it.",
    castAlpha = "How solid the cast ring is, in percent.",
    castCustom = "The cast ring's own colour, for Custom: click to pick it in the colour picker.",
    look = "A see-through copy of the game's pointer where the cursor comes back while the game hides it to turn or look "
        .. "around, its fingertip on the spot. On its own, apart from the other effects.",
    lookSize = "How big the see-through pointer is, in pixels. The game's own is about 24 to 32 at the usual interface sizes.",
    lookAlpha = "How solid the see-through pointer is, in percent: lower is fainter.",
    lookCustom = "The tint's own colour, for Custom: click to pick it in the colour picker.",
    lookRight = "Show it while you turn your character with the right mouse button.",
    lookLeft = "Show it while you move the camera with the left mouse button.",
    lookPulse = "The see-through pointer brightens and dims gently, so it catches the eye.",
}
local TOP = -186 -- each tab's first row, under the tabs

function ns.BuildRingsPage(window, page, width)
    local L, R = P.LEFT, P.RIGHT
    page.tab = "ring"
    local tabs = T:Segmented(page, TABS, TAB_WIDTH, function(key)
        page.tab = key
        window:Refresh()
    end)
    tabs:SetPoint("TOPLEFT", L, P.TOP)
    -- A tab is only the settings' page: the tick on it turns the effect on.
    for i, button in ipairs(tabs.buttons) do
        local item = TABS[i]
        window:Hint(button, function()
            if ns.Get(item.key) then return item.note .. " It's on." end
            return item.note .. " It's off: tick the box at the top of this tab to turn it on."
        end)
    end
    page.tabs = tabs
    local panes, controls, fields, mains = {}, {}, {}, {}
    for _, item in ipairs(TABS) do
        local pane = CreateFrame("Frame", nil, page)
        pane:SetPoint("TOPLEFT")
        pane:SetSize(width, page:GetHeight() or 489)
        panes[item.key] = pane
    end
    page.panes = panes
    local function Add(control) controls[#controls + 1] = control; return control end
    local function Tick(pane, label, key, x, y) return Add(P.Tick(window, pane, label, key, x, y, NOTES[key])) end
    local function Slider(pane, label, key, x, y) return Add(P.Slider(window, pane, label, key, x, y, NOTES[key])) end
    -- Colour: Class, Custom or the trail's (the highlight's: a tint, or
    -- none), and the custom colour beside it.
    local function Colour(pane, prefix, y)
        local tint = prefix == "look"
        local names, notes = tint and TINT_NAMES or COLOUR_NAMES, tint and TINT_NOTES or COLOUR_NOTES
        P.Label(pane, tint and "Tint" or "Colour", L, y)
        Add(P.Choice(window, pane, 110, y, 240, prefix .. "Colour", names, function(key) return notes[key] end))
        local title
        for _, item in ipairs(TABS) do if item.key == prefix then title = item.colour end end
        local field = Add(P.ColourField(window, pane, 370, y + 1, prefix .. "Custom", NOTES[prefix .. "Custom"], title))
        fields[prefix] = field
    end

    -- Cursor ring.
    local p = panes.ring
    mains.ring = Tick(p, "Show a ring round the cursor", "ring", L, TOP)
    Slider(p, "Size", "ringSize", L, TOP - 36)
    Slider(p, "Thickness", "ringThickness", R, TOP - 36)
    Slider(p, "Opacity", "ringAlpha", L, TOP - 76)
    Colour(p, "ring", TOP - 116)
    Add(P.Notice(p, "ring", L, TOP - 152))

    -- Cast ring.
    p = panes.cast
    mains.cast = Tick(p, "Show cast progress round the cursor", "cast", L, TOP)
    Slider(p, "Size", "castSize", L, TOP - 36)
    Slider(p, "Opacity", "castAlpha", R, TOP - 36)
    Colour(p, "cast", TOP - 76)
    P.Detail(p, "Fills as you cast and drains as you channel. Grows to sit outside the cursor ring while that's on.",
        L, TOP - 112, 600)
    Add(P.Notice(p, "cast", L, TOP - 136))

    -- While looking.
    p = panes.look
    mains.look = Tick(p, "Cursor highlight while looking", "look", L, TOP)
    Slider(p, "Size", "lookSize", L, TOP - 36)
    Slider(p, "Opacity", "lookAlpha", R, TOP - 36)
    Colour(p, "look", TOP - 76)
    Tick(p, "While turning with the right mouse button", "lookRight", L, TOP - 114)
    Tick(p, "While moving the camera with the left mouse button", "lookLeft", L, TOP - 138)
    Tick(p, "Pulse gently", "lookPulse", L, TOP - 162)
    P.Detail(p, "The game hides the cursor while you turn or look around; a see-through pointer marks where it will come back.",
        L, TOP - 190, 600)

    -- A custom colour waits for Custom.
    for prefix, field in pairs(fields) do
        local key = prefix .. "Custom"
        field.swatch.hint = function()
            if ns.Get(prefix .. "Colour") ~= "custom" then return "Pick Custom to use a colour of your own." end
            return NOTES[key]
        end
    end

    page.controls, page.mains = controls, mains
    function page:Refresh()
        tabs:SetSelected(self.tab)
        for i, button in ipairs(tabs.buttons) do
            local item = TABS[i]
            button.label:SetText(item.label .. (ns.Get(item.key) and ": On" or ": Off"))
            mains[item.key]:SetNudged(not ns.Get(item.key))
        end
        for key, pane in pairs(panes) do pane:SetShown(key == self.tab) end
        self.focus = self.tab
        P.SyncAll(controls)
        for prefix, field in pairs(fields) do field:SetUsable(ns.Get(prefix .. "Colour") == "custom") end
    end
    page.focus = "ring"
end
