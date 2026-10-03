-- The addon's own colour picker, in the window's look: a square of how rich
-- (across) and how bright (up) the colour is, for the colour picked on the
-- bar beside it; the colour before and now; a few colours to start from; a
-- box for six hex digits; and OK and Cancel. Every colour moved through
-- shows at once: on the page, in the preview and on the real cursor. Cancel
-- (or Escape, out of a fight) puts the colour back as it was; OK keeps it,
-- and so does leaving its page or tab, opening the profile menu, or closing
-- the window. It sits over the right of the page, under the preview, so the
-- preview stays in view, and only one of it and the profile menu shows at a
-- time (they'd cover each other). The game's own colour picker is never used.
local _, ns = ...
local T = ns.Theme
local Style = ns.Style
local P = ns.PageParts

local C = {}
ns.ColourPicker = C

local WIDTH, HEIGHT = 300, 222
local PAD = 12
local SQUARE = 140 -- how rich across, how bright up
local BAR, BAR_GAP = 14, 8 -- the colour bar, right of the square
local RIGHT = PAD + SQUARE + BAR_GAP + BAR + 12 -- the column right of the bar
local COLUMN = WIDTH - RIGHT - PAD
local QUICK, QUICK_GAP = 18, 8
C.TOP, C.MARGIN = -186, 16 -- its top on the page, and from the page's right edge

-- Colours to start from: white, your class's, then the gradient's own six.
local QUICK_COLOURS = {
    { key = "FFFFFF", name = "White" },
    { key = "class", name = "Your class's colour" },
    { key = "FF4D4D", name = "Red" },
    { key = "FFB84D", name = "Orange" },
    { key = "FFF04D", name = "Yellow" },
    { key = "5CFF6B", name = "Green" },
    { key = "4DD2FF", name = "Blue" },
    { key = "D35CFF", name = "Purple" },
}

local function Clamp(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local window, picker
-- While it's open: the setting, its colour before, the control it was
-- opened from, the profile showing then, and the colour now (hue,
-- saturation, brightness, each 0 to 1).
local session
local hue, saturation, brightness = 0, 0, 1

local function QuickHex(item)
    if item.key == "class" then return Style.HexOf(Style.ClassColour()) end
    return item.key
end

-- The square's colour, the marks and the swatch for now, as the colour is.
local function Show()
    local r, g, b = Style.Hue(hue)
    picker.base:SetColorTexture(r, g, b, 1)
    picker.spot:ClearAllPoints()
    picker.spot:SetPoint("CENTER", picker.square, "BOTTOMLEFT", saturation * SQUARE, brightness * SQUARE)
    picker.notch:ClearAllPoints()
    picker.notch:SetPoint("CENTER", picker.bar, "TOPLEFT", BAR / 2, -hue * SQUARE)
    local hex = Style.HexOf(Style.FromHSV(hue, saturation, brightness))
    local nr, ng, nb = Style.HexRGB(hex)
    picker.now:SetBackdropColor(nr, ng, nb, 1) -- only its colour, as it follows a drag
    if not picker.hex:HasFocus() then P.SetBoxText(picker.hex, hex) end
    return hex
end

-- The colour as it is now: shown here, and on everything that draws it.
local function Use()
    local hex = Show()
    if session and ns.Get(session.setting) ~= hex then ns.Set(session.setting, hex) end
end

-- Six hex digits picked or typed: the colour they make, keeping the hue
-- when they're a grey (a grey has none of its own).
local function UseHex(hex)
    local h, s, v = Style.ToHSV(Style.HexRGB(hex))
    if s > 0 and v > 0 then hue = h end
    saturation, brightness = s, v
    Use()
end

function C:IsOpen()
    return session ~= nil
end

-- The setting it's open for, if it is.
function C:Setting()
    return session and session.setting
end

-- Opens it for a colour setting, from owner (the swatch clicked), titled
-- title. Open for another setting already, that one keeps its colour
-- first; open for this one, a second click closes it, keeping the colour.
function C:Open(setting, owner, title)
    if not picker then return false end
    if session then
        local same = session.setting == setting
        self:Close(true)
        if same then return true end
    end
    session = { setting = setting, before = ns.Get(setting), owner = owner, profile = ns.ProfileName() }
    picker.title:SetText((title or "Colour"):upper())
    P.PaintSwatch(picker.before, { Style.HexRGB(session.before) }, false)
    for _, swatch in ipairs(picker.quick) do P.PaintSwatch(swatch, { Style.HexRGB(QuickHex(swatch.item)) }, false) end
    hue, saturation, brightness = Style.ToHSV(Style.HexRGB(session.before))
    local page = window.pages[window.selected] or window
    picker:ClearAllPoints()
    picker:SetPoint("TOPRIGHT", page, "TOPRIGHT", -C.MARGIN, C.TOP)
    picker.hex:ClearFocus()
    -- The profile menu would sit over it: it closes (ProfileMenu.lua closes
    -- this in turn as it opens).
    if window.profilePanel then window.profilePanel:Hide() end
    Show()
    picker:Show()
    picker:Raise()
    window:Refresh()
    return true
end

-- Closes it. keep: the colour stays as it is now; else it goes back to
-- the colour before (another profile showing has closed it already,
-- keeping). The window then redraws, unless quiet (it's redrawing already).
function C:Close(keep, quiet)
    local was = session
    if not was then return end
    session = nil
    picker.square:Stop()
    picker.bar:Stop()
    picker:Hide()
    if not keep and ns.Get(was.setting) ~= was.before then
        ns.Set(was.setting, was.before) -- which redraws the window
    elseif not quiet and window:IsShown() then
        window:Refresh()
    end
end

function C:Cancel()
    self:Close(false)
end

-- As the window redraws, after the page: a picker whose swatch has gone
-- (another page or tab) or can't be used now (the mode doesn't use it), or
-- whose profile no longer shows by its name (renamed, say), closes, keeping
-- the colour. True if it closed, so the page can redraw without it.
function C:Sync()
    if not session then return false end
    local owner = session.owner
    local gone = owner ~= nil and (not owner:IsVisible() or (owner.IsEnabled and not owner:IsEnabled()))
    if not gone and ns.ProfileName() == session.profile then return false end
    self:Close(true, true)
    return true
end

-- Dragging on the square or the bar: the cursor's place on it, 0 to 1
-- across and up while it's over it (PickSquare and PickHue keep it there).
local function Where(frame)
    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    if type(x) ~= "number" or type(y) ~= "number" or type(scale) ~= "number" or scale <= 0 then return nil end
    local width, height = frame:GetWidth() or 0, frame:GetHeight() or 0
    if width <= 0 or height <= 0 then return nil end
    return (x / scale - (frame:GetLeft() or 0)) / width, (y / scale - (frame:GetBottom() or 0)) / height
end

-- The square: across for how rich, up for how bright.
function C:PickSquare(across, up)
    saturation, brightness = Clamp(across), Clamp(up)
    Use()
end

-- The bar: red at the top, round the rainbow to red again at the foot.
function C:PickHue(down)
    hue = Clamp(down)
    if hue >= 1 then hue = 0 end
    Use()
end

-- Pressed, it follows the cursor each frame until the mouse lets go.
local function Draggable(frame, pick)
    frame:EnableMouse(true)
    local function Follow()
        local across, up = Where(frame)
        if across then pick(across, up) end
    end
    function frame:Stop() self:SetScript("OnUpdate", nil) end
    frame:SetScript("OnMouseDown", function(self)
        Follow()
        self:SetScript("OnUpdate", Follow)
    end)
    frame:SetScript("OnMouseUp", frame.Stop)
    -- Hidden mid-drag, it never hears the mouse let go.
    frame:SetScript("OnHide", frame.Stop)
end

-- A small round mark: a dark ring round a white one, seen on any colour.
local function Mark(parent, size)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    frame:EnableMouse(false)
    local outer = Style.NewRing(frame)
    outer:SetPoint("CENTER")
    Style.PaintRing(outer, size, 2, 0, 0, 0, .85)
    local inner = Style.NewRing(frame)
    inner:SetPoint("CENTER")
    Style.PaintRing(inner, size - 3, 1.5, 1, 1, 1, 1)
    return frame
end

function C:Build(w)
    if picker then return picker end
    window = w
    picker = CreateFrame("Frame", nil, w, "BackdropTemplate")
    picker:SetSize(WIDTH, HEIGHT)
    picker:SetPoint("TOPRIGHT", w.pages.colours or w, "TOPRIGHT", -C.MARGIN, C.TOP)
    picker:SetFrameLevel(w:GetFrameLevel() + 60)
    picker:EnableMouse(true)
    T:Flat(picker, T.PANEL, T.CONTROL_BORDER)
    T:Paint(function(accent) picker:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1) end)
    picker:Hide()
    w:Hint(picker, function()
        return "Pick a colour: it shows at once. OK keeps it; Cancel puts back the one before." .. ns.EscapeWords("Escape does too.")
    end)
    picker.title = T:Heading(picker, "Colour")
    picker.title:SetPoint("TOPLEFT", PAD, -PAD)

    -- The square: the colour itself, washed to white on the left and to
    -- black at the foot.
    local square = CreateFrame("Frame", nil, picker)
    square:SetSize(SQUARE, SQUARE)
    square:SetPoint("TOPLEFT", PAD, -32)
    local base = square:CreateTexture(nil, "BACKGROUND")
    base:SetAllPoints()
    local white = square:CreateTexture(nil, "BORDER")
    white:SetAllPoints()
    T:Shade(white, "HORIZONTAL", { 1, 1, 1, 1 }, { 1, 1, 1, 0 })
    local black = square:CreateTexture(nil, "ARTWORK")
    black:SetAllPoints()
    T:Shade(black, "VERTICAL", { 0, 0, 0, 1 }, { 0, 0, 0, 0 })
    Draggable(square, function(across, up) C:PickSquare(across, up) end)
    w:Hint(square, "Drag right for a richer colour, up for a brighter one.")
    picker.square, picker.base = square, base
    picker.spot = Mark(square, 12)
    picker.spot:SetFrameLevel(square:GetFrameLevel() + 2)

    -- The bar: round the rainbow, red at the top and the foot.
    local bar = CreateFrame("Frame", nil, picker)
    bar:SetSize(BAR, SQUARE)
    bar:SetPoint("TOPLEFT", PAD + SQUARE + BAR_GAP, -32)
    local piece = SQUARE / 6
    for i = 0, 5 do
        local band = bar:CreateTexture(nil, "ARTWORK")
        band:SetPoint("TOPLEFT", 0, -i * piece)
        band:SetSize(BAR, piece)
        local top, foot = { Style.Hue(i / 6) }, { Style.Hue((i + 1) / 6) }
        T:Shade(band, "VERTICAL", { foot[1], foot[2], foot[3], 1 }, { top[1], top[2], top[3], 1 })
    end
    Draggable(bar, function(_, up) C:PickHue(1 - up) end)
    w:Hint(bar, "Drag up or down for the colour itself: red, yellow, green, blue, purple and round to red.")
    picker.bar = bar
    local notch = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    notch:SetSize(BAR + 6, 5)
    notch:SetFrameLevel(bar:GetFrameLevel() + 2)
    notch:EnableMouse(false)
    T:Flat(notch, { 0, 0, 0, 0 }, { 1, 1, 1, 1 })
    picker.notch = notch

    -- Before and now.
    local beforeLabel = T:Text(picker, "GameFontHighlightSmall", T.MUTED)
    beforeLabel:SetPoint("TOPLEFT", RIGHT, -30)
    beforeLabel:SetText("Before")
    local nowLabel = T:Text(picker, "GameFontHighlightSmall", T.MUTED)
    nowLabel:SetPoint("TOPLEFT", RIGHT + COLUMN / 2 + 3, -30)
    nowLabel:SetText("Now")
    local half = (COLUMN - 6) / 2
    local before = P.Swatch(picker, half, function()
        if session then UseHex(session.before) end
    end)
    before:SetSize(half, 24)
    before:SetPoint("TOPLEFT", RIGHT, -44)
    w:Hint(before, "The colour before you opened this: click to go back to it.")
    local now = CreateFrame("Frame", nil, picker, "BackdropTemplate")
    now:SetSize(half, 24)
    P.PaintSwatch(now, { 1, 1, 1 }, false)
    now:SetPoint("TOPLEFT", RIGHT + half + 6, -44)
    now:EnableMouse(true)
    w:Hint(now, "The colour now: it already shows on the page, in the preview and on the cursor.")
    picker.before, picker.now = before, now

    -- Six hex digits, typed.
    local hex = T:Input(picker, "Hex", COLUMN)
    hex:SetPoint("TOPLEFT", RIGHT, -78)
    hex:SetMaxLetters(7)
    hex:SetScript("OnEnterPressed", function(self)
        local typed = Style.ParseHex(self:GetText())
        self:ClearFocus()
        if typed then
            UseHex(typed)
        else
            Show()
            w:Say("Type six hex digits, like FF8000.")
            w:Refresh()
        end
    end)
    hex:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        C:Cancel()
    end)
    w:Hint(hex, "The colour as six hex digits: type new ones and press Enter. Escape cancels.")
    picker.hex = hex

    -- Colours to start from, two rows of four.
    picker.quick = {}
    for i, item in ipairs(QUICK_COLOURS) do
        local swatch = P.Swatch(picker, QUICK, function() UseHex(QuickHex(item)) end)
        local column, row = (i - 1) % 4, math.floor((i - 1) / 4)
        swatch:SetPoint("TOPLEFT", RIGHT + column * (QUICK + QUICK_GAP), -110 - row * (QUICK + QUICK_GAP))
        swatch.item = item
        w:Hint(swatch, item.name .. ": click to start from it.")
        picker.quick[i] = swatch
    end

    -- OK and Cancel.
    local ok = T:Button(picker, "OK", 80, 22)
    ok:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    ok:SetScript("OnClick", function() C:Close(true) end)
    T:Paint(function(accent) ok.label:SetTextColor(accent[1], accent[2], accent[3]) end)
    w:Hint(ok, "Keep this colour and close the picker.")
    local cancel = T:Button(picker, "Cancel", 80, 22)
    cancel:SetPoint("RIGHT", ok, "LEFT", -6, 0)
    cancel:SetScript("OnClick", function() C:Cancel() end)
    w:Hint(cancel, function()
        return "Put back the colour from before and close the picker." .. ns.EscapeWords("Escape does this too.")
    end)
    picker.ok, picker.cancel = ok, cancel

    -- The window closing keeps the colour showing; so does another profile
    -- showing (whose own colour is left alone).
    w:HookScript("OnHide", function() C:Close(true) end)
    ns.Listen(function(key)
        if key == nil and session and ns.ProfileName() ~= session.profile then C:Close(true) end
    end)
    C.frame = picker
    return picker
end
