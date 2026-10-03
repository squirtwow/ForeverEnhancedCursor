-- The tour: the basics a page at a time. Each step opens the page (and the
-- tab) it's about, outlines the part it means in the accent and explains it
-- in a box beside it, with Back, Next and Skip tour. The tour only opens the
-- addon's own pages and points: it never changes a setting, never touches
-- Blizzard's frames or the game's settings, works in a fight too, and the
-- outline takes no clicks. While a pick list is open (a profile for a rule,
-- say), or the colour picker, it steps aside, so nothing of it covers them.
-- A first install's first look at the window offers it; after that it's on
-- the General page and /fec tour. Escape (out of a fight), Skip tour or closing the window
-- ends it.
-- Each step has the version it arrived in, so What's new can offer a shorter
-- tour of just the steps an update added (Tour:StartNews). Until an update
-- adds steps (NEWS), What's new has no button for it.
local _, ns = ...
local T = ns.Theme

local Tour = {}
ns.Tour = Tour

local FLAT = "Interface\\Buttons\\WHITE8X8"
local BOX_WIDTH, PAD = 290, 10
local GAP = 14 -- between the part outlined and the box
local OUTLINE = 4 -- how far outside that part the outline sits
local TOUR_NOTE = "Take the tour any time from the General page, or with " .. ns.SLASH .. " tour."
local NEWS_NOTE = "See it again any time from What's new, or with " .. ns.SLASH .. " new."

local window, box, outline, spot
local steps, index, welcome
local news -- the tour showing is What's new's
local offer = true -- a first install's welcome, until the window first opens

local function Value(value, ...)
    if type(value) == "function" then return value(...) end
    return value
end

-- The minimap button, while there's one to point at (EraUI can fade it).
local function MinimapButton()
    local button = ns.MinimapButton and ns.MinimapButton:Button()
    if button and button:IsVisible() and button:GetAlpha() > .5 then return button end
end

-- Whether the profile menu in the header is open.
local function ProfilesOpen(w)
    return w.profilePanel ~= nil and w.profilePanel:IsShown()
end

-- Whether a pick list (a profile for a rule or a mount, a mount to list, or
-- the Profiles page's) is open. While you pick, the tour steps aside: its
-- box, outline and arrow hide, so nothing of it sits over the list or takes
-- its clicks, and they come back as the list closes.
local function Picking()
    return ns.PageParts.Picking(window)
end

-- Escape is the window's only out of a fight (Core.lua hands it back to the
-- game as one starts), so the notes only offer it then (Core.lua's
-- ns.EscapeWords, which the colour picker's notes use too).
local function Escape(words)
    return ns.EscapeWords(words)
end

-- The steps of the full tour, the basics. version: the version the step
-- arrived in (ns.UNRELEASED until the release gives it its number). page:
-- the page it opens (none keeps the one showing), and tab: that page's tab.
-- when: whether it can show, if it can't always. target: the part it
-- outlines, or the first and last of a group of them (top left to bottom
-- right). side: where the box goes, "right", "left", "below" or "above";
-- align "end" lines the box up with the far end; shift moves it that much
-- further right. Each box sits clear of what its step asks you to click.
-- try: a line asking you to try it yourself (the tour never does it for
-- you).
local STEPS = {
    {
        version = "1.0.0",
        title = "The menu",
        text = "Every page is in this list: Trail, Colours and Rings for the effects, then Profiles, Auto-switch and General."
            .. " Hover anything and the line at the foot of the window says what it does.",
        target = function(w) return w.navFrame end,
        side = "right",
    },
    {
        version = "1.0.0",
        page = "trail",
        title = "The trail",
        text = "Every effect starts off. The preview at the top shows each change at once, even for an effect that's off,"
            .. " so you can try a look before you turn it on.",
        try = function()
            if ns.Get("trail") then return "Try it: move a slider and watch the preview." end
            return "Try it: tick Show the cursor trail, under the preview."
        end,
        target = function(w) return w.preview end,
        -- Over the right column, so the tick and the sliders on the left stay free.
        side = "below",
        align = "end",
    },
    {
        version = "1.0.0",
        page = "colours",
        title = "Colours",
        text = "Your class's colour, one colour, a rainbow, or a gradient of up to ten of your own. Phases repeats them along"
            .. " the trail and Colour speed makes them flow.",
        target = function(w) return w.colourMode end,
        -- Clear of the ten swatches on the left.
        side = "below",
        align = "end",
    },
    {
        version = "1.0.0",
        page = "rings",
        tab = "ring",
        title = "Rings",
        text = "A ring round the cursor, cast progress round it, and a see-through pointer where the cursor comes back while"
            .. " you turn or look around. Each tab says whether its effect is on: the tick at the top of the tab turns it on.",
        target = function(w) return w.pages.rings and w.pages.rings.tabs end,
        -- In the right column, clear of each tab's tick on the left.
        side = "below",
        shift = ns.PageParts.RIGHT - ns.PageParts.LEFT,
    },
    {
        version = "1.0.0",
        page = "profiles",
        title = "Profiles",
        text = "Each character starts with its own profile. This menu and the Profiles page switch, copy and share them, and"
            .. " mark one account-wide for every character.",
        -- Once the menu is open the box moves beside it, so it never covers it.
        target = function(w) return ProfilesOpen(w) and w.profilePanel or w.profileButton end,
        side = function(w) return ProfilesOpen(w) and "left" or "below" end,
        align = "end",
    },
    {
        version = "1.0.0",
        page = "autoswitch",
        tab = "rules",
        title = "Auto-switch",
        text = "Tick it, then pick a profile for any rule: in combat, mounted, in a dungeon and more. The first rule that"
            .. " matches decides, in the order shown. Off until you tick it.",
        target = function(w)
            if w.autoSwitchTick and w.autoStatus then return w.autoSwitchTick, w.autoStatus end
        end,
        -- At the far end, so each rule's name and the start of its pick stay free.
        side = "below",
        align = "end",
    },
    {
        version = "1.0.0",
        title = "That's the basics",
        text = function()
            return (MinimapButton() and "Open these settings any time with this button or " .. ns.SLASH .. "."
                or "Open these settings any time with " .. ns.SLASH .. ".")
                .. " What's new shows after each update, and this tour is on the General page."
        end,
        target = function(w) return MinimapButton() or w.versionText end,
        side = function() return MinimapButton() and "below" or "above" end,
        align = function() return MinimapButton() and "end" or nil end,
    },
}

-- Steps only What's new tours, for what an update added after the basics.
-- The same fields as above; the next update's wait as ns.UNRELEASED until
-- the release gives them its number.
local NEWS = {
}

-- Where the box goes against what it points at, and its arrow on the box's
-- edge: the box's point, the part's point, the offset, the arrow's point on
-- the box and its offset, and which way the arrow faces.
local PLACES = {
    right = { "TOPLEFT", "TOPRIGHT", GAP, 0, "RIGHT", "TOPLEFT", 0, -20, "left" },
    left = { "TOPRIGHT", "TOPLEFT", -GAP, 0, "LEFT", "TOPRIGHT", 0, -20, "right" },
    below = { "TOPLEFT", "BOTTOMLEFT", 0, -GAP, "BOTTOM", "TOPLEFT", 24, 0, "up" },
    above = { "BOTTOMLEFT", "TOPLEFT", 0, GAP, "TOP", "BOTTOMLEFT", 24, 0, "down" },
    belowEnd = { "TOPRIGHT", "BOTTOMRIGHT", 0, -GAP, "BOTTOM", "TOPRIGHT", -24, 0, "up" },
    aboveEnd = { "BOTTOMRIGHT", "TOPRIGHT", 0, GAP, "TOP", "BOTTOMRIGHT", -24, 0, "down" },
}

local function Strip(frame, layer)
    local strip = frame:CreateTexture(nil, layer)
    strip:SetTexture(FLAT)
    return strip
end

-- A ring of four strips, `width` thick, `out` pixels outside the frame's edge.
local function Ring(frame, width, out, layer)
    local top, bottom, left, right = Strip(frame, layer), Strip(frame, layer), Strip(frame, layer), Strip(frame, layer)
    top:SetPoint("TOPLEFT", -out, out)
    top:SetPoint("TOPRIGHT", out, out)
    top:SetHeight(width)
    bottom:SetPoint("BOTTOMLEFT", -out, -out)
    bottom:SetPoint("BOTTOMRIGHT", out, -out)
    bottom:SetHeight(width)
    left:SetPoint("TOPLEFT", -out, out)
    left:SetPoint("BOTTOMLEFT", -out, -out)
    left:SetWidth(width)
    right:SetPoint("TOPRIGHT", out, out)
    right:SetPoint("BOTTOMRIGHT", out, -out)
    right:SetWidth(width)
    return { top, bottom, left, right }
end

local function Build()
    window = ns.window
    -- The part a step means as one frame, from its first piece's top left to
    -- its last's bottom right; the outline and the box are placed round it.
    -- Nothing drawn, and it takes no mouse.
    spot = CreateFrame("Frame", nil, window)
    -- The outline: the accent, with a soft edge, gently pulsing while it
    -- shows (no timer while it's hidden). It takes no mouse either, so
    -- what it outlines can still be clicked.
    outline = CreateFrame("Frame", nil, window)
    outline:SetFrameStrata("FULLSCREEN_DIALOG")
    outline:SetFrameLevel(window:GetFrameLevel() + 70)
    local line = Ring(outline, 2, 0, "OVERLAY")
    local soft = Ring(outline, 3, 3, "ARTWORK")
    T:Paint(function(accent)
        for _, strip in ipairs(line) do strip:SetVertexColor(accent[1], accent[2], accent[3], 1) end
        for _, strip in ipairs(soft) do strip:SetVertexColor(accent[1], accent[2], accent[3], .3) end
    end)
    local pulse = 0
    local function Pulse(self, elapsed)
        pulse = pulse + elapsed
        self:SetAlpha(.55 + .45 * (1 + math.sin(pulse * 4)) / 2)
    end
    outline:SetScript("OnShow", function(self) self:SetScript("OnUpdate", Pulse) end)
    outline:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    outline:Hide()

    box = CreateFrame("Frame", "FECursorTour", window, "BackdropTemplate")
    box.outline, box.spot = outline, spot
    box:SetWidth(BOX_WIDTH)
    box:SetFrameStrata("FULLSCREEN_DIALOG")
    box:SetFrameLevel(window:GetFrameLevel() + 80)
    box:SetClampedToScreen(true)
    box:EnableMouse(true) -- clicks on the box stay on it
    T:Flat(box, T.BG, T.CONTROL_BORDER)
    -- The box's own note: the welcome has no Back, just Take the tour and Skip.
    window:Hint(box, function()
        if welcome then
            return "Take the tour for a short look round this window, or Skip it." .. Escape("Escape skips it too.")
        end
        return "The tour: Next and Back step through it, Skip tour ends it." .. Escape("Escape ends it too.")
    end)
    box.title = T:Heading(box, "")
    box.title:SetPoint("TOPLEFT", PAD, -PAD)
    box.count = T:Text(box, "GameFontHighlightSmall", T.MUTED)
    box.count:SetPoint("TOPRIGHT", -PAD, -PAD)
    box.count:SetJustifyH("RIGHT")
    box.text = T:Text(box, "GameFontHighlightSmall")
    box.text:SetPoint("TOPLEFT", PAD, -(PAD + 16))
    box.text:SetWidth(BOX_WIDTH - 2 * PAD)
    box.arrow = box:CreateTexture(nil, "ARTWORK")
    box.arrow:SetTexture(ns.MEDIA .. "TourArrow.tga")
    local nextButton = T:Button(box, "Next", 64, 20)
    nextButton:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    window:Hint(nextButton, function()
        if welcome then return "Start the tour: a page at a time, about a minute." end
        if steps and index == #steps then return "End the tour, with the window left open." end
        return "The next step. It opens the page it's about."
    end)
    local back = T:Button(box, "Back", 64, 20)
    back:SetPoint("RIGHT", nextButton, "LEFT", -6, 0)
    window:Hint(back, "The step before.")
    local skip = T:Button(box, "Skip tour", 76, 20)
    skip:SetPoint("BOTTOMLEFT", PAD, PAD)
    window:Hint(skip, function()
        if welcome then return "No tour for now. " .. TOUR_NOTE end
        return "End the tour here." .. Escape("Escape ends it too.")
    end)
    T:Paint(function(accent)
        box:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        box.arrow:SetVertexColor(accent[1], accent[2], accent[3], 1)
        nextButton:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
    end)
    nextButton:SetScript("OnClick", function()
        if welcome then Tour:Start() else Tour:Next() end
    end)
    back:SetScript("OnClick", function() Tour:Back() end)
    skip:SetScript("OnClick", function()
        local note = news and NEWS_NOTE or TOUR_NOTE
        Tour:Stop()
        window:Say(note)
        window:Refresh()
    end)
    box.next, box.back, box.skip = nextButton, back, skip
    box:Hide()
    -- Closing the window ends the tour.
    window:HookScript("OnHide", function() Tour:Stop() end)
    -- Opening or closing the profile menu moves the box beside it, or back;
    -- a pick list or the colour picker opening or closing steps the tour
    -- aside, or brings it back.
    local function Follow(frame)
        if not frame then return end
        frame:HookScript("OnShow", function() Tour:Repoint() end)
        frame:HookScript("OnHide", function() Tour:Repoint() end)
    end
    Follow(window.profilePanel)
    for _, list in ipairs(window.pickLists or {}) do Follow(list) end
    if ns.ColourPicker then Follow(ns.ColourPicker.frame) end
end

-- The window, open, with the tour's box made. A pick list or the colour
-- picker left open closes (the colour kept), so the tour starts in sight
-- rather than stepped aside, and so does the Reset question (unanswered:
-- nothing changes), which would sit over the tour.
local function Ready()
    if not ns.ShowWindow then return false end
    ns.ShowWindow()
    if not ns.window then return false end
    if not box then Build() end
    if window.CloseReset then window:CloseReset() end
    for _, list in ipairs(window.pickLists or {}) do list:Hide() end
    if ns.ColourPicker then ns.ColourPicker:Close(true) end
    return true
end

-- Whether a step's page is there to open: in the window once it's made, in
-- its list of pages before.
local function HasPage(key)
    if ns.window then return ns.window.pages[key] ~= nil end
    for _, known in ipairs(ns.PAGE_KEYS or {}) do
        if known == key then return true end
    end
    return false
end

-- Whether a step can show: its page there, and its own test if it has one.
local function Can(step)
    if step.page and not HasPage(step.page) then return false end
    return not step.when or step.when(ns.window) == true
end

-- Sizes the box round its text: the title row, the text, then the buttons.
local function Fit()
    box:SetHeight(PAD + 16 + math.ceil(box.text:GetStringHeight() or 0) + 12 + 20 + PAD)
end

-- The step's part: its first and last pieces, while they're showing.
local function Part(step)
    local first, last = Value(step.target, window)
    return first, last or first
end

-- The outline and the arrow only while the part shows: on another page or
-- tab the box stays, and Next or Back opens it again. None of it while a
-- pick list is open.
local function Mark(step)
    local first, last = Part(step)
    local here = first ~= nil and first:IsVisible() and last:IsVisible() and not Picking()
    outline:SetShown(here)
    box.arrow:SetShown(here)
end

local function Point(step)
    local first, last = Part(step)
    spot:ClearAllPoints()
    if not first then
        -- Nothing to point at (a part that isn't there): the box in the
        -- middle of the window, no outline.
        outline:Hide()
        box.arrow:Hide()
        box:ClearAllPoints()
        box:SetPoint("CENTER", window, "CENTER", 90, 30)
        return
    end
    spot:SetPoint("TOPLEFT", first, "TOPLEFT")
    spot:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT")
    outline:ClearAllPoints()
    outline:SetPoint("TOPLEFT", spot, "TOPLEFT", -OUTLINE, OUTLINE)
    outline:SetPoint("BOTTOMRIGHT", spot, "BOTTOMRIGHT", OUTLINE, -OUTLINE)
    local side = Value(step.side, window) or "below"
    local align = Value(step.align, window) == "end" and "End" or ""
    local place = PLACES[side .. align] or PLACES[side] or PLACES.below
    box:ClearAllPoints()
    box:SetPoint(place[1], spot, place[2], place[3] + (Value(step.shift, window) or 0), place[4])
    local arrow = box.arrow
    arrow:ClearAllPoints()
    arrow:SetPoint(place[5], box, place[6], place[7], place[8])
    if place[9] == "left" then
        arrow:SetSize(9, 16)
        arrow:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
    elseif place[9] == "right" then
        arrow:SetSize(9, 16)
        arrow:SetTexCoord(1, 1, 0, 1, 1, 0, 0, 0)
    else
        arrow:SetSize(16, 9)
        if place[9] == "up" then arrow:SetTexCoord(0, 1, 0, 1) else arrow:SetTexCoord(0, 1, 1, 0) end
    end
    Mark(step)
end

-- Opens a step's page, on its tab. Only which page and tab show: nothing
-- saved changes.
local function Open(step)
    local page = step.page and window.pages[step.page]
    if not page then return end
    if step.tab and page.tab ~= nil then page.tab = step.tab end
    window:Select(step.page)
end

local function Show(i)
    index, welcome = i, nil
    local step = steps[i]
    Open(step)
    local text = Value(step.text)
    local try = Value(step.try)
    if try then text = text .. "\n\n|cff" .. T:Hex(T:Accent()) .. try .. "|r" end
    box.title:SetText(step.title:upper())
    box.count:SetText(i .. " of " .. #steps)
    box.count:Show()
    box.text:SetText(text)
    box.back:SetShown(i > 1)
    box.next:SetWidth(64)
    box.next:SetLabel(i == #steps and "Done" or "Next")
    box.skip:SetLabel("Skip tour")
    Fit()
    Point(step)
    box:Show()
    box:Raise()
end

-- The tour from the start, over the window.
function Tour:Start()
    offer = false
    if not Ready() then return end
    local list = {}
    for _, step in ipairs(STEPS) do
        if Can(step) then list[#list + 1] = step end
    end
    if #list == 0 then return end
    steps, news = list, nil
    Show(1)
end

-- The newest version a step arrived in, no newer than the one running (for a
-- copy straight from the source, the newest there is).
local function Latest(now)
    local compare, latest = ns.CompareVersions, nil
    for _, list in ipairs({ STEPS, NEWS }) do
        for _, step in ipairs(list) do
            if (compare(step.version, now) or 1) < 1 and (not latest or compare(step.version, latest) == 1) then
                latest = step.version
            end
        end
    end
    return latest
end

-- The steps an update added, the full tour's then What's new's: newer than
-- the version seen before it and no newer than the one running, so versions
-- skipped come together. With no version seen (What's new opened by hand, or
-- none noted), the latest update's: the steps of the newest version that
-- added any. Only steps that can show.
function Tour:News(seen)
    local now, compare = ns.Version(), ns.CompareVersions
    local byHand = not compare(seen, now)
    local latest = byHand and Latest(now)
    local list = {}
    if byHand and not latest then return list end
    for _, group in ipairs({ STEPS, NEWS }) do
        for _, step in ipairs(group) do
            local new
            if latest then
                new = compare(step.version, latest) == 0
            else
                new = compare(step.version, seen) == 1 and (compare(step.version, now) or 1) < 1
            end
            if new and Can(step) then list[#list + 1] = step end
        end
    end
    return list
end

-- What's new's tour: just those steps, over the window.
function Tour:StartNews(seen)
    offer = false
    local list = self:News(seen)
    if #list == 0 or not Ready() then return end
    steps, news = list, true
    Show(1)
end

-- A first install: the window, and an offer of the tour.
function Tour:Welcome()
    offer = false
    if not Ready() then return end
    steps, index, welcome, news = nil, nil, true, nil
    box.title:SetText("WELCOME")
    box.count:Hide()
    box.text:SetText("New to " .. ns.TITLE .. "? A quick tour shows you the basics, a page at a time. It takes about a"
        .. " minute.")
    box.back:Hide()
    box.next:SetWidth(100)
    box.next:SetLabel("Take the tour")
    box.skip:SetLabel("Skip")
    Fit()
    Point({})
    box:Show()
    box:Raise()
end

-- The window opening (Window.lua). The first time after a first install, a
-- moment after login or sooner if you open it yourself, it offers the tour.
-- Once only: a settings file that isn't empty is no first install.
function Tour:Shown()
    if offer and ns.firstInstall then self:Welcome() end
end

function Tour:Next()
    if not (steps and index) then return end
    if index < #steps then return Show(index + 1) end
    local done = news and "That's what's new. " .. NEWS_NOTE or "That's the tour. " .. TOUR_NOTE
    self:Stop()
    window:Say(done)
    window:Refresh()
end

function Tour:Back()
    if steps and index and index > 1 then Show(index - 1) end
end

function Tour:Stop()
    steps, index, welcome, news = nil, nil, nil, nil
    if box then
        box:Hide()
        outline:Hide()
    end
end

function Tour:Active()
    return box ~= nil and box:IsShown()
end

-- Called whenever the window refreshes (a page or a tab chosen): the
-- outline only shows while the part the step means does (and no pick list
-- is open).
function Tour:Sync()
    local step = steps and index and steps[index]
    if not step or not box then return end
    Mark(step)
end

-- Points the step showing at its part again, for a part that moved or
-- changed (the Profiles step, once the profile menu opens or closes), and
-- steps aside or comes back as a pick list opens or closes (the tour only
-- starts with none open: Ready closes it).
function Tour:Repoint()
    if not box or not (steps or welcome) then return end
    local step = steps and index and steps[index]
    if step then Point(step) end
    box:SetShown(not Picking())
end
