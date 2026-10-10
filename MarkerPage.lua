-- The Marker page: a shape on the pointer, under the preview. A bullseye, a
-- crosshair, a dot, a diamond, a star or your class's icon (the game's own,
-- in its own colours), with its size, opacity and colour (your class's, one
-- of your own, or the trail's), and only in combat if you like.
local _, ns = ...
local P = ns.PageParts

local SHAPE_NAMES = {
    bullseye = "Bullseye", crosshair = "Crosshair", dot = "Dot", diamond = "Diamond", star = "Star", class = "Class icon",
}
local SHAPE_NOTES = {
    bullseye = "Two rings and a dot in the middle.",
    crosshair = "Four short lines round a small dot.",
    dot = "One round dot.",
    diamond = "A diamond outline.",
    star = "A filled five-point star.",
    class = "Your class's icon, as the game draws it, in its own colours.",
}
local COLOUR_NAMES = { class = "Class", custom = "Custom", trail = "Trail's" }
local COLOUR_NOTES = {
    class = "Your class's colour.",
    custom = "A colour of your own: pick it on the right.",
    trail = "The trail's colour at the cursor (the Colours page), flowing with it when its colours move.",
}
local NOTES = {
    marker = "A shape on the pointer, centred on its tip, so it's easy to find.",
    markerCombat = "Show the marker only in a fight. It goes as the fight ends.",
    markerSize = "How big the marker is across, in pixels.",
    markerAlpha = "How solid the marker is, in percent.",
    markerCustom = "The marker's own colour, for Custom: click to pick it in the colour picker.",
}
local ICON_KEEPS = "The class icon keeps its own colours: pick another shape to colour it."

function ns.BuildMarkerPage(window, page)
    local L, R, Y = P.LEFT, P.RIGHT, P.Y
    local controls = {}
    local function Add(control) controls[#controls + 1] = control; return control end
    local function Tick(label, key, x, y) return Add(P.Tick(window, page, label, key, x, y, NOTES[key])) end
    local function Slider(label, key, x, y) return Add(P.Slider(window, page, label, key, x, y, NOTES[key])) end

    local main = Tick("Show a marker on the pointer", "marker", L, Y(0))
    Tick("Only in combat", "markerCombat", R, Y(0))

    P.Label(page, "Shape", L, Y(1))
    Add(P.Choice(window, page, 110, Y(1), 488, "markerShape", SHAPE_NAMES, function(key) return SHAPE_NOTES[key] end))

    Slider("Size", "markerSize", L, Y(2))
    Slider("Opacity", "markerAlpha", R, Y(2))

    -- Colour: Class, Custom or the trail's, and the custom colour beside it.
    -- Neither applies to the class icon.
    local function Icon() return ns.Get("markerShape") == "class" end
    P.Label(page, "Colour", L, Y(3))
    local colour = Add(P.Choice(window, page, 110, Y(3), 240, "markerColour", COLOUR_NAMES, function(key)
        if Icon() then return ICON_KEEPS end
        return COLOUR_NOTES[key]
    end))
    local field = Add(P.ColourField(window, page, 370, Y(3) + 1, "markerCustom", NOTES.markerCustom, "Marker colour"))
    field.swatch.hint = function()
        if Icon() then return ICON_KEEPS end
        if ns.Get("markerColour") ~= "custom" then return "Pick Custom to use a colour of your own." end
        return NOTES.markerCustom
    end
    field.input.hint = "The colour as six hex digits: type new ones and press Enter."
    P.Detail(page, "Sits on the pointer's tip, under the rings. The class icon is the game's own, in its own colours.",
        L, Y(3) - 36, 600)

    page.controls, page.main, page.colour, page.field = controls, main, colour, field
    page.focus = "marker"
    function page:Refresh()
        P.SyncAll(controls)
        -- Off, its tick is lit in the accent: the one thing to click first.
        main:SetNudged(not ns.Get("marker"))
        colour:SetUsable(not Icon())
        field:SetUsable(not Icon() and ns.Get("markerColour") == "custom")
    end
end
