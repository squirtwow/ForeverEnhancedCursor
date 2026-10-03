-- The Colours page: the trail's colours. Your class's colour, one colour, a
-- rainbow, or a gradient of up to ten colours of your own; how many of the
-- ten the gradient uses, how often the colours repeat along the trail and
-- how fast they flow out from the cursor. The ring, cast progress and the
-- highlight can take the trail's colours too (the Rings page).
local _, ns = ...
local T = ns.Theme
local P = ns.PageParts
local Style = ns.Style

local SWATCH, GAP = 28, 6
local MODE_NAMES = { class = "Class", single = "One colour", rainbow = "Rainbow", gradient = "Gradient" }
local MODE_NOTES = {
    class = "Your class's colour, all along the trail.",
    single = "One colour of your own, all along the trail: Colour 1.",
    rainbow = "Every colour of the rainbow along the trail. Phases repeats it; Colour speed makes it flow.",
    gradient = "Your own colours blending one into the next, from Colour 1 at the cursor. Colours in use says how many.",
}
local NOTES = {
    colourCount = "How many of your ten colours the gradient uses, from Colour 1 on.",
    colourPhases = "How many times the colours repeat along the trail.",
    colourSpeed = "How fast the colours flow out from the cursor, in percent. 0 keeps them still.",
}
local WHY = {
    class = "Class uses your class's colour: pick One colour or Gradient to use your own colours.",
    rainbow = "Rainbow uses every colour: pick One colour or Gradient to use your own colours.",
}

function ns.BuildColoursPage(window, page)
    local L, R, Y = P.LEFT, P.RIGHT, P.Y
    local controls = {}
    local function Add(control) controls[#controls + 1] = control; return control end
    page.selected = 1 -- the colour the hex box edits

    P.Label(page, "Colours", L, Y(0))
    local mode = Add(P.Choice(window, page, 110, Y(0), 400, "colourMode", MODE_NAMES, function(key) return MODE_NOTES[key] end))
    window.colourMode = mode

    -- Ten swatches, two rows of five, each numbered.
    local swatches = {}
    for i = 1, ns.COLOUR_COUNT do
        local swatch
        swatch = P.Swatch(page, SWATCH, function()
            page.selected = i
            window:Refresh()
            if not P.OpenPicker("colour" .. i, swatch, "Colour " .. i) then page.hex:SetFocus() end
        end)
        local column, row = (i - 1) % 5, math.floor((i - 1) / 5)
        swatch:SetPoint("TOPLEFT", L + column * (SWATCH + GAP), Y(1) - row * (SWATCH + GAP))
        swatch.index, swatch.setting = i, "colour" .. i
        P.Mark(swatch, tostring(i))
        window:Hint(swatch, function()
            local why = WHY[ns.Get("colourMode")]
            if why then return why end
            return ("Colour %d: click to pick it in the colour picker, or type its hex digits on the right."):format(i)
        end)
        swatches[i] = swatch
    end
    page.swatches = swatches

    -- The chosen colour's hex digits.
    local x = L + 5 * (SWATCH + GAP) + 18
    local chosen = T:Text(page, "GameFontHighlight")
    chosen:SetPoint("TOPLEFT", x, Y(1) - 3)
    local hex = T:Input(page, "Hex", 90)
    hex:SetPoint("TOPLEFT", x + 74, Y(1))
    hex:SetMaxLetters(7)
    hex:SetScript("OnEnterPressed", function(self)
        local value = Style.ParseHex(self:GetText())
        self:ClearFocus()
        if value then
            ns.Set("colour" .. page.selected, value)
        else
            window:Say("Type six hex digits, like FF8000.")
            window:Refresh()
        end
    end)
    hex:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        P.SetBoxText(self, ns.Get("colour" .. page.selected))
    end)
    window:Hint(hex, "The chosen colour as six hex digits: type new ones and press Enter.")
    page.hex, page.chosen = hex, chosen
    local help = P.Detail(page, "Click a swatch to pick its colour; every colour you move through shows at once. Swatches past "
        .. "Colours in use are kept for later.", x, Y(1) - 30, 400)
    page.help = help

    local count = Add(P.Slider(window, page, "Colours in use", "colourCount", L, Y(3), NOTES.colourCount))
    local phases = Add(P.Slider(window, page, "Phases", "colourPhases", R, Y(3), NOTES.colourPhases))
    local speed = Add(P.Slider(window, page, "Colour speed", "colourSpeed", L, Y(4), NOTES.colourSpeed))
    page.count, page.phases, page.speed = count, phases, speed
    local about = P.Detail(page, "", L, Y(5) + 4, 600)
    page.about = about

    -- What doesn't apply to a mode is greyed out, and its note says why.
    local function Why(key)
        local current = ns.Get("colourMode")
        if key == "colourCount" and current ~= "gradient" then return "Colours in use is for Gradient." end
        if (key == "colourPhases" or key == "colourSpeed") and (current == "class" or current == "single") then
            return "Phases and Colour speed are for Rainbow and Gradient."
        end
        if (key == "colourPhases" or key == "colourSpeed") and current == "gradient" and ns.Get("colourCount") < 2 then
            return "Phases and Colour speed need two or more Colours in use."
        end
    end
    for _, slider in ipairs({ count, phases, speed }) do
        local key = slider.setting
        slider.hint = function() return Why(key) or NOTES[key] end
        slider.track.hint = slider.hint
    end

    page.focus = "trail"
    function page:Refresh()
        P.SyncAll(controls)
        local current = ns.Get("colourMode")
        local own = current == "single" or current == "gradient"
        if current == "single" then self.selected = 1 end
        local used = current == "gradient" and ns.Get("colourCount") or 1
        for i, swatch in ipairs(swatches) do
            local colour = { Style.HexRGB(ns.Get("colour" .. i)) }
            P.PaintSwatch(swatch, colour, own and i == self.selected)
            swatch:MarkOn(colour)
            swatch:SetShown(current ~= "single" or i == 1)
            P.Usable(swatch, own)
            if own and i > used then swatch:SetAlpha(.45) end
        end
        chosen:SetText(own and ("Colour " .. self.selected) or "")
        -- The colour picker, while it's open, has a hex box of its own.
        local picking = ns.ColourPicker ~= nil and ns.ColourPicker:IsOpen()
        hex:SetShown(own and not picking)
        help:SetShown(own and not picking)
        if own and not hex:HasFocus() then P.SetBoxText(hex, ns.Get("colour" .. self.selected)) end
        P.Usable(count, Why("colourCount") == nil)
        P.Usable(phases, Why("colourPhases") == nil)
        P.Usable(speed, Why("colourSpeed") == nil)
        about:SetText(MODE_NOTES[current] or "")
    end
end
