-- Pieces the pages share: labels, ticks and sliders tied to a setting,
-- joined buttons, colour swatches (the addon's own colour picker for any
-- colour, ColourPicker.lua, or six hex digits typed in), and the notice
-- shown while EraUI draws its own copy of an effect. Every control has a
-- note for the window's footer.
local _, ns = ...
local T = ns.Theme
local Style = ns.Style

local P = {}
ns.PageParts = P

P.TESTING = " (Needs testing)"
P.LEFT, P.RIGHT = 16, 326 -- the two columns
P.TOP = -150 -- the first row, under the preview
P.ROW = 40 -- between rows
P.SLIDER = 280 -- a slider's width

function P.Y(row) return P.TOP - row * P.ROW end

function P.Label(parent, text, x, y)
    local label = T:Text(parent, "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y - 3)
    label:SetText(text)
    return label
end

function P.Detail(parent, text, x, y, width)
    local detail = T:Text(parent, "GameFontHighlightSmall", T.MUTED)
    detail:SetPoint("TOPLEFT", x, y)
    detail:SetWidth(width or 280)
    detail:SetText(text)
    return detail
end

-- Greyed out and left alone while it doesn't apply; still says why on hover.
function P.Usable(control, usable)
    local own = rawget(control, "SetUsable")
    if own then
        own(control, usable)
        return
    end
    control:SetEnabled(usable)
    if control.SetMotionScriptsWhileDisabled then control:SetMotionScriptsWhileDisabled(true) end
    control:SetAlpha(usable and 1 or .35)
end

function P.Swatch(parent, size, onClick)
    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetSize(size, size)
    swatch:SetScript("OnClick", onClick)
    return swatch
end

-- A swatch in its colour, outlined in white when it's the one chosen.
function P.PaintSwatch(swatch, colour, chosen)
    local border = chosen and { 1, 1, 1, 1 } or T.CONTROL_BORDER
    T:Flat(swatch, { colour[1], colour[2], colour[3], 1 }, border)
end

-- A number or letter on a swatch: dark on a light swatch, white on a dark one.
function P.Mark(swatch, text)
    local mark = swatch:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mark:SetPoint("CENTER", 0, 0)
    mark:SetText(text)
    mark:SetShadowOffset(0, 0)
    swatch.mark = mark
    function swatch:MarkOn(colour)
        local on = T:OnAccent(colour)
        mark:SetTextColor(on[1], on[2], on[3])
    end
    return mark
end

-- Controls tied to a setting --------------------------------------------------------------
-- Each knows its setting (control.setting) and shows its value again on
-- Sync; the pages sync them all on every refresh.

function P.Tick(window, parent, label, setting, x, y, hint)
    local check = T:Check(parent, label, function(self) ns.Set(setting, self:GetChecked()) end)
    check:SetPoint("TOPLEFT", x, y)
    check.setting = setting
    function check:Sync() self:SetChecked(ns.Get(setting)) end
    window:Hint(check, hint)
    return check
end

-- Fractions kept to two places, so a step of .05 is saved as it shows.
local function Tidy(value)
    if value == math.floor(value) then return value end
    return math.floor(value * 100 + .5) / 100
end

function P.Slider(window, parent, label, setting, x, y, hint, width)
    local limits = ns.NUMBERS[setting]
    local slider = T:Slider(parent, label, limits, ns.STEPS[setting] or 1, width or P.SLIDER, function(value)
        ns.Set(setting, Tidy(value))
    end)
    slider:SetPoint("TOPLEFT", x, y)
    slider.setting = setting
    function slider:Sync() self:Set(ns.Get(setting)) end
    window:Hint(slider, hint)
    return slider
end

-- Joined buttons for a choice; names[key] labels each, note(key) is its hint.
function P.Choice(window, parent, x, y, width, setting, names, note)
    local items = {}
    for _, key in ipairs(ns.CHOICE_KEYS[setting]) do items[#items + 1] = { key = key, label = names[key] or key } end
    local bar = T:Segmented(parent, items, width, function(key) ns.Set(setting, key) end)
    bar:SetPoint("TOPLEFT", x, y)
    for _, button in ipairs(bar.buttons) do
        window:Hint(button, function() return note(button.key) end)
    end
    bar.setting = setting
    function bar:Sync() self:SetSelected(ns.Get(setting)) end
    return bar
end

-- Text put in a box from the code: its grey placeholder only while it's empty.
function P.SetBoxText(input, text)
    input:SetText(text or "")
    input.placeholder:SetShown((text or "") == "")
end

-- Opens the colour picker for a colour setting from owner (the swatch
-- clicked), titled title (what the colour is for).
function P.OpenPicker(setting, owner, title)
    return ns.ColourPicker ~= nil and ns.ColourPicker:Open(setting, owner, title) == true
end

-- A swatch for one colour setting, with a box to type its hex digits:
-- clicking the swatch opens the colour picker. title: the picker's title.
function P.ColourField(window, parent, x, y, setting, hint, title)
    local field = CreateFrame("Frame", nil, parent)
    field:SetSize(110, 22)
    field:SetPoint("TOPLEFT", x, y)
    local input = T:Input(field, "Hex", 72)
    local swatch
    swatch = P.Swatch(field, 20, function()
        if not P.OpenPicker(setting, swatch, title) then input:SetFocus() end
    end)
    swatch:SetPoint("LEFT", 0, 0)
    input:SetPoint("LEFT", swatch, "RIGHT", 6, 0)
    input:SetMaxLetters(7)
    input:SetScript("OnEnterPressed", function(self)
        local hex = Style.ParseHex(self:GetText())
        self:ClearFocus()
        if hex then
            ns.Set(setting, hex)
        else
            window:Say("Type six hex digits, like FF8000.")
            window:Refresh()
        end
    end)
    input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        P.SetBoxText(self, ns.Get(setting))
    end)
    field.swatch, field.input, field.setting = swatch, input, setting
    swatch.setting = setting
    window:Hint(swatch, hint)
    window:Hint(input, "The colour as six hex digits: type new ones and press Enter.")
    function field:Sync()
        local colour = { Style.HexRGB(ns.Get(setting)) }
        P.PaintSwatch(swatch, colour, false)
        if not input:HasFocus() then P.SetBoxText(input, ns.Get(setting)) end
    end
    function field:SetUsable(usable)
        P.Usable(swatch, usable)
        input:SetEnabled(usable)
        input:SetAlpha(usable and 1 or .35)
    end
    return field
end

-- EraUI's own copy --------------------------------------------------------------------------

local NOTICES = {
    trail = "EraUI's own cursor trail is on too. Turn it off in /era to see only this one.",
    ring = "EraUI's own cursor ring is on too. Turn it off in /era to see only this one.",
    cast = "EraUI's own cast progress ring is on too. Turn it off in /era to see only this one.",
}

-- A line in the warning colour, shown only while EraUI draws its own copy
-- of the effect (read from EraUI's saved settings, never changed).
function P.Notice(parent, kind, x, y, width)
    local notice = T:Text(parent, "GameFontHighlightSmall", T.WARN)
    notice:SetPoint("TOPLEFT", x, y)
    notice:SetWidth(width or 600)
    notice:SetText(NOTICES[kind])
    notice.kind = kind
    function notice:Sync() self:SetShown(ns.FromEraUI.Drawing(kind)) end
    notice:Hide()
    return notice
end

-- Every control on a page with a Sync, shown again.
function P.SyncAll(list)
    for _, control in ipairs(list) do control:Sync() end
end

-- Pick lists --------------------------------------------------------------------------------
-- A list that opens under a picker button (or over it, near the foot of the
-- page): None and every profile, or the mounts you have, with an icon if
-- they have one. Past P.PICK_ROWS rows it scrolls. A click picks and closes
-- it; the page going closes it too. Pinned by two corners, again a moment
-- after it opens: a scroll frame placed any other way can draw nothing.
P.PICK_ROW, P.PICK_ROWS = 22, 8

function P.PickList(window, page, width)
    local list = CreateFrame("Frame", nil, page, "BackdropTemplate")
    list:SetSize(width, 100) -- sized again as it opens
    list:SetFrameLevel(page:GetFrameLevel() + 40)
    list:SetClampedToScreen(true)
    T:Flat(list, T.PANEL, T.CONTROL_BORDER)
    list:EnableMouse(true)
    list:Hide()
    window:Hint(list, function() return list.note or "Pick one, or click the button again to close the list." end)
    local scroll = T:Scroll(list, width - 20)
    local tall = 1 -- rows the list is tall enough for
    local function Pin()
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -6)
        scroll:SetPoint("BOTTOMRIGHT", list, "TOPLEFT", 6 + width - 20, -(6 + tall * P.PICK_ROW))
        scroll:ScrollTo(scroll:GetVerticalScroll() or 0)
    end
    Pin()
    list:HookScript("OnShow", function() C_Timer.After(0, Pin) end)
    window:Hint(scroll.thumb, ns.SCROLL_NOTE)
    list.scroll = scroll

    local rows = {}
    local function Row(i)
        if rows[i] then return rows[i] end
        local row = CreateFrame("Button", nil, scroll.content)
        row:SetSize(width - 20, P.PICK_ROW - 2)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * P.PICK_ROW)
        row.fill = row:CreateTexture(nil, "BACKGROUND")
        row.fill:SetAllPoints()
        T:Fill(row.fill, T.SELECTED)
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, .05)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 6, 0)
        row.name = T:Text(row, "GameFontHighlight")
        row.name:SetWordWrap(false)
        row:SetScript("OnClick", function(self)
            local pick = list.onPick
            list:Hide()
            if pick then pick(self.item) end
        end)
        window:Hint(row, function()
            if list.rowNote and row.item then return list.rowNote(row.item) end
            return "Pick this."
        end)
        rows[i] = row
        return row
    end
    list.rows = rows

    -- Opens under anchor (at y, its top on the page) with items, each
    -- { key, label, icon, muted }; chosen is the key picked now; onPick(item)
    -- runs on a click; note is the list's own hint, rowNote(item) each row's.
    function list:Open(anchor, y, items, chosen, onPick, note, rowNote)
        self.owner, self.onPick, self.note, self.rowNote = anchor, onPick, note, rowNote
        for i, item in ipairs(items) do
            local row = Row(i)
            row.item = item
            row.name:SetText(item.label)
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", item.icon and 28 or 8, 0)
            row.name:SetWidth(width - (item.icon and 56 or 36))
            local colour = item.muted and T.MUTED or T.TEXT
            row.name:SetTextColor(colour[1], colour[2], colour[3])
            row.icon:SetShown(item.icon ~= nil)
            if item.icon then row.icon:SetTexture(item.icon) end
            row.fill:SetShown(item.key == chosen)
            row:Show()
        end
        for i = #items + 1, #rows do rows[i]:Hide() end
        tall = math.max(1, math.min(#items, P.PICK_ROWS))
        scroll.content:SetHeight(math.max(1, #items * P.PICK_ROW))
        scroll:SetVerticalScroll(0)
        local height = 12 + tall * P.PICK_ROW
        self:SetHeight(height)
        Pin()
        self:ClearAllPoints()
        if -y + 24 + height > (page:GetHeight() or 489) then
            self:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
        else
            self:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
        end
        self:Show()
        self:Raise()
    end

    page:HookScript("OnHide", function() list:Hide() end)
    window.pickLists = window.pickLists or {}
    window.pickLists[#window.pickLists + 1] = list
    return list
end

-- Whether any pick list, or the colour picker, is open (the tour steps
-- aside meanwhile).
function P.Picking(window)
    if ns.ColourPicker and ns.ColourPicker:IsOpen() then return true end
    for _, list in ipairs(window and window.pickLists or {}) do
        if list:IsVisible() then return true end
    end
    return false
end

-- A button showing a profile picked (or None), opening the list of every
-- profile. spec: x, y, width, Get() (the name or nil), Pick(name) (nil for
-- None) and hint; listY (the button's top on the page, if not y); forWhat
-- (the list's note: "Pick the profile for ..."); none (None's note).
function P.ProfilePicker(window, parent, list, spec)
    local button = T:Button(parent, "", spec.width, 22)
    button:SetPoint("TOPLEFT", spec.x, spec.y)
    button.label:SetWidth(spec.width - 16)
    button.label:SetWordWrap(false)
    button.spec = spec
    button:SetScript("OnClick", function(self)
        if list:IsShown() and list.owner == self then return list:Hide() end
        local items = { { key = false, label = "None", muted = true } }
        for _, name in ipairs(ns.ProfileNames()) do items[#items + 1] = { key = name, label = name } end
        local y = type(spec.listY) == "function" and spec.listY() or spec.listY or spec.y
        list:Open(self, y, items, spec.Get() or false, function(item) spec.Pick(item.key or nil) end,
            "Pick the profile for " .. (spec.forWhat or "this") .. ".", function(item)
                if not item.key then return spec.none or "None: no profile for this." end
                return "Show " .. item.key .. " " .. (spec.with or "here") .. "."
            end)
    end)
    window:Hint(button, spec.hint)
    function button:Sync()
        local name = spec.Get()
        self:SetLabel(name or "None")
        local colour = name and T.TEXT or T.MUTED
        self.label:SetTextColor(colour[1], colour[2], colour[3])
    end
    return button
end
