-- The tour (Tour.lua), run against the mock game (Tools/Harness.lua): a first
-- install's welcome (once only, never over a fight, never for a tester who
-- already has settings), /fec tour and the General page's Take the tour,
-- every step's page, tab and part (shown while it's outlined), the box beside
-- it (sized round its words, clear of its part), Back, Next, Skip tour,
-- Escape and closing the window, the outline taking no clicks and running no
-- timer while hidden, the tour stepping aside while a pick list is open, the
-- whole tour in a fight, What's new's shorter tour (no steps of its own yet),
-- the released copy's number in What's new and the footer, and that no way
-- into the tour changes a setting or touches anything of Blizzard's.
-- Run with fengari: Tools/TestTour.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, Fire = H.S, H.Equal, H.Fire
local ns, w, box

local TOUR_NOTE = "Take the tour any time from the General page, or with /fec tour."
local WELCOME = "New to Forever Enhanced Cursor? A quick tour shows you the basics, a page at a time. It takes about a minute."
local BASICS = "THE MENU, THE TRAIL, COLOURS, RINGS, PROFILES, AUTO-SWITCH, THAT'S THE BASICS"
-- The box round its words: its edge, the title row, the text, a gap, the
-- buttons and its edge (Tour.lua's Fit).
local FRAME = 10 + 16 + 12 + 20 + 10

local function Hover(region, script) if S[region].scripts[script] then S[region].scripts[script](region) end end
local function Title() return S[box.title].text end
local function Count() return S[box.count].text end
local function Text() return S[box.text].text end
local function Footer() return S[w.note].text end
local function First() local p = S[box.spot].points[1]; return p and p[2] end
local function Last() local p = S[box.spot].points[2]; return p and p[2] end
local function Anchor() local p = S[box].points[1]; return p[1] .. " " .. p[3] end
local function Shown(region) return S[region].shown == true end
local function Clean(label)
    Equal(H.Problems(), "", label .. ": nothing of Blizzard's touched, no error")
end
local function NoteOf(control)
    Hover(control, "OnEnter")
    local text = Footer()
    Hover(control, "OnLeave")
    return text
end

-- Where a region sits in the window (Tools/Harness.lua's H.Rect), and
-- whether two overlap.
local function Rect(region) return H.Rect(region, w) end
local function Overlap(a, c) return H.Overlap(a, c, w) end

-- Saved settings, copied whole, and the first difference between two copies.
local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = Copy(item) end
    return out
end
local function Differ(a, b, path)
    path = path or "saved"
    if type(a) ~= "table" or type(b) ~= "table" then
        if a ~= b then return path .. ": " .. tostring(a) .. " became " .. tostring(b) end
        return nil
    end
    for key, item in pairs(a) do
        local found = Differ(item, b[key], path .. "." .. tostring(key))
        if found then return found end
    end
    for key, item in pairs(b) do
        if a[key] == nil then return path .. "." .. tostring(key) .. ": added " .. tostring(item) end
    end
    return nil
end

-- Runs part of a test, then checks it changed no setting: everything saved,
-- copied whole before, exactly as after, and none of the addon's setters
-- called at all (each one counted while it runs).
local SETTERS = { "Set", "SetRulePick", "SetMountPick", "AddMount", "RemoveMount", "SetTalentPick", "SetNotesSeen", "SetEraOffered",
    "ReplaceSettings", "UseProfile", "SetAccountWide", "NewProfile", "NewProfileFrom", "CopyProfile", "RenameProfile",
    "DeleteProfile" }
local function Unchanged(label, run)
    local addon = ns
    local before = Copy(ForeverEnhancedCursorDB)
    local called, kept = {}, {}
    for _, name in ipairs(SETTERS) do
        local setter = addon[name]
        Equal(type(setter), "function", label .. ": ns." .. name .. " is there to count")
        kept[name] = setter
        addon[name] = function(...)
            called[#called + 1] = name
            return setter(...)
        end
    end
    run()
    for name, setter in pairs(kept) do addon[name] = setter end
    Equal(table.concat(called, " "), "", label .. ": no setting set")
    Equal(Differ(before, ForeverEnhancedCursorDB), nil, label .. ": everything saved exactly as before")
end

-- The counting itself: a setting set, or a saved value changed, is caught.
do
    H.Environment()
    ns = H.Load({ notesSeen = "dev" })
    local ok = pcall(Unchanged, "a setter", function() ns.Set("accent", "blue") end)
    Equal(ok, false, "Unchanged catches a setting set")
    ok = pcall(Unchanged, "a saved value", function() ForeverEnhancedCursorDB.accent = "teal" end)
    Equal(ok, false, "and a saved value changed by any means")
end

-- A first install: the window and the welcome -------------------------------------------------

do
    H.Environment()
    ns = H.Load(nil)
    Equal(ns.firstInstall, true, "an empty settings file is a first install")
    Unchanged("the first install's welcome", function()
        Equal(FECursorFrame == nil and FECursorTour == nil, true, "a first install waits a moment to open the window")
        H.lockdown = true
        H.RunTimers()
        Equal(FECursorFrame == nil and FECursorTour == nil, true, "not in a fight")
        H.lockdown = false
        Fire("PLAYER_REGEN_ENABLED")
        w, box = FECursorFrame, FECursorTour
        Equal(w ~= nil and Shown(w) and box ~= nil and Shown(box), true, "then the window opens, the welcome over it")
        Equal(Title() .. " | " .. Text(), "WELCOME | " .. WELCOME, "saying what the tour is")
        Equal(S[box.next.label].text .. "|" .. S[box.skip.label].text .. "|" .. tostring(Shown(box.back)) .. "|"
            .. tostring(Shown(box.count)), "Take the tour|Skip|false|false", "offering the tour, or Skip; no Back, no count")
        Equal(S[box].height, FRAME + math.ceil(box.text:GetStringHeight()), "the welcome sized round its words")
        Equal(tostring(Shown(box.outline)) .. " " .. tostring(Shown(box.arrow)), "false false", "nothing outlined or pointed at")
        Equal(Footer(), "Welcome! Hover anything here and this line says what it does.", "the footer welcomes too")
        Equal(FECursorNotes == nil or not Shown(FECursorNotes), true, "and no What's new")
        box.skip:Click()
        Equal(Shown(box), false, "Skip closes the welcome")
        Equal(Shown(w) and Footer(), TOUR_NOTE, "leaving the window open, and saying where the tour is")
        Clean("the welcome")
    end)
    -- Once only: the settings aren't empty any more.
    local saved = ForeverEnhancedCursorDB
    H.Environment()
    ns = H.Load(saved)
    Unchanged("the next login", function()
        H.RunTimers()
        Equal(FECursorFrame == nil and FECursorTour == nil, true, "the welcome only comes once")
        SlashCmdList.FECURSOR("")
        Equal(Shown(FECursorFrame) and FECursorTour == nil, true, "opening the window later: no welcome")
    end)
end

-- Testers who already have settings are never ambushed.
do
    H.Environment()
    ns = H.Load({ notesSeen = "dev", accent = "teal" })
    Unchanged("a tester's login", function()
        H.RunTimers()
        Equal(FECursorFrame == nil and FECursorTour == nil, true, "nothing opens by itself")
        SlashCmdList.FECURSOR("")
        Equal(Shown(FECursorFrame) and FECursorTour == nil, true, "and the window opens with no welcome")
    end)
end

-- The tour, a step at a time -------------------------------------------------------------------

-- Each step: its title, the page and tab it opens, the part it outlines (the
-- first and last pieces) and where its box sits against that part.
-- A tick or slider by its setting.
local function TickFor(setting)
    for _, obj in ipairs(H.objects) do
        if rawget(obj, "setting") == setting and (rawget(obj, "track") or (S[obj].kind == "Button" and rawget(obj, "text"))) then
            return obj
        end
    end
end

-- Each step: its title, the page and tab it opens, the part it outlines (the
-- first and last pieces), where its box sits against that part, and what
-- the box must leave free to click (free), or leave a start of free (start).
local function Steps()
    local rows = {}
    for _, row in ipairs(w.autoRows) do rows[#rows + 1] = row end
    return {
        { title = "THE MENU", parts = { w.navFrame }, at = "TOPLEFT TOPRIGHT" },
        { title = "THE TRAIL", page = "trail", parts = { w.preview }, at = "TOPRIGHT BOTTOMRIGHT",
            free = { w.trailTick, TickFor("trailSpacing"), TickFor("trailMax"), TickFor("trailWidth"), TickFor("trailX") } },
        { title = "COLOURS", page = "colours", parts = { w.colourMode }, at = "TOPRIGHT BOTTOMRIGHT", free = w.pages.colours.swatches },
        { title = "RINGS", page = "rings", tab = "ring", bar = w.pages.rings.tabs, parts = { w.pages.rings.tabs }, at = "TOPLEFT BOTTOMLEFT",
            free = { TickFor("ring"), TickFor("ringSize"), TickFor("ringAlpha") },
            says = "a see-through pointer where the cursor comes back while you turn or look around. Each tab says" },
        { title = "PROFILES", page = "profiles", parts = { w.profileButton }, at = "TOPRIGHT BOTTOMRIGHT" },
        { title = "AUTO-SWITCH", page = "autoswitch", tab = "rules", bar = w.pages.autoswitch.tabs,
            parts = { w.autoSwitchTick, w.autoStatus }, at = "TOPRIGHT BOTTOMRIGHT", free = { w.autoSwitchTick }, start = rows },
        { title = "THAT'S THE BASICS", parts = { FECursorMinimapButton }, at = "TOPRIGHT BOTTOMRIGHT" },
    }
end

local EM_DASH = "\226\128\148"
local function Check(i, step, total, label)
    label = label or step.title
    Equal(Count() .. " " .. Title(), i .. " of " .. total .. " " .. step.title, label .. ": step " .. i .. " of " .. total)
    if step.page then Equal(w.selected, step.page, label .. ": its page opened") end
    if step.tab then
        Equal(w.pages[step.page].tab .. " " .. tostring(step.bar.selected), step.tab .. " " .. step.tab, label .. ": on its tab")
    end
    local first, last = step.parts[1], step.parts[2] or step.parts[1]
    Equal(first ~= nil and First() == first and Last() == last, true, label .. ": the spot pinned round its part")
    Equal(first:IsVisible() and last:IsVisible(), true, label .. ": the part showing as it's outlined")
    Equal(Shown(box.outline) and Shown(box.arrow) and Shown(box), true, label .. ": outlined, with the arrow pointing at it")
    Equal(Anchor() .. " " .. tostring(S[box].points[1][2] == box.spot), step.at .. " true", label .. ": the box beside it")
    Equal(tostring(Shown(box.back)) .. " " .. S[box.next.label].text .. " " .. S[box.skip.label].text,
        tostring(i > 1) .. " " .. (i == total and "Done" or "Next") .. " Skip tour", label .. ": Back from the second, Done on the last")
    local text = Text()
    Equal(type(text) == "string" and #text > 60 and not text:find(EM_DASH, 1, true), true, label .. ": says what it's for, no em dash")
    if step.says then Equal(type(text) == "string" and text:find(step.says, 1, true) ~= nil, true, label .. ": says \"" .. step.says .. "\"") end
    -- Each step's effect has been seen working in game: none says Needs testing (only a mount you list does, not in the tour).
    Equal(type(text) == "string" and text:lower():find("testing", 1, true), nil, label .. ": no Needs testing")
    Equal(S[box].height .. " " .. S[box].width, FRAME + math.ceil(box.text:GetStringHeight()) .. " 290",
        label .. ": the box sized round its words")
    if H.Under(first, w) then Equal(Overlap(box, box.spot), false, label .. ": the box clear of the part it outlines") end
    -- Clear of what the step asks you to click, or of the start of each.
    for _, control in ipairs(step.free or {}) do
        Equal(control ~= nil and control:IsVisible() and not Overlap(box, control), true,
            label .. ": the box clear of " .. tostring(control and (S[control.text or control.label or control] or {}).text or "a control"))
    end
    for _, control in ipairs(step.start or {}) do
        Equal(Rect(box).l - Rect(control).l >= 60, true, label .. ": the start of each rule's pick left free")
    end
end

;(function()
    H.Environment()
    ns = H.Load({ notesSeen = "dev" })
    Unchanged("the tour", function()
        SlashCmdList.FECURSOR("")
        w = FECursorFrame
        w:Select("general") -- the first step keeps whatever page is showing
        SlashCmdList.FECURSOR("tour")
        box = FECursorTour
        Equal(Shown(w) and Shown(box), true, "/fec tour opens the window with the tour")
        Equal(S[box].parent == w and S[box.outline].parent == w and S[box.spot].parent == w, true, "the tour's frames are the window's own")
        Equal(tostring(S[box].mouse) .. " " .. tostring(S[box.outline].mouse) .. " " .. tostring(S[box.spot].mouse), "true nil nil",
            "the box keeps its clicks; the outline takes none, so what it outlines can still be clicked")
        local outline = box.outline
        Equal(type(S[outline].scripts.OnUpdate), "function", "the outline pulses while it shows")
        Equal(S[box.arrow].texture, "Interface\\AddOns\\ForeverEnhancedCursor\\Media\\TourArrow.tga", "with the tour's arrow")

        local steps = Steps()
        Equal(w.selected, "general", "the first step leaves the page as it was")
        Check(1, steps[1], 7)
        box.next:Click()
        Check(2, steps[2], 7)
        Equal(Text():find("|cffe07829Try it: tick Show the cursor trail, under the preview.|r", 1, true) ~= nil, true,
            "asking you to try it, in the accent")
        local tick = S[w.trailTick.text].text
        Equal(Text():find("tick " .. tick .. ",", 1, true) ~= nil, true, "naming the tick by the words it shows: " .. tick)
        Equal(ns.Get("trail"), false, "the tour ticks nothing")
        -- Another page: the outline and arrow go, the box stays; back, they return.
        w:Select("general")
        Equal(tostring(Shown(box)) .. " " .. tostring(Shown(box.outline)) .. " " .. tostring(Shown(box.arrow)), "true false false",
            "on another page the outline hides, the box stays")
        Equal(S[outline].scripts.OnUpdate, nil, "no pulse while it's hidden")
        w:Select("trail")
        Equal(Shown(box.outline), true, "back on the page, outlined again")
        box.next:Click()
        Check(3, steps[3], 7)
        box.back:Click()
        Check(2, steps[2], 7, "Back")
        box.next:Click()
        -- Rings, on the Cursor ring tab whichever was showing.
        w.pages.rings.tab = "look"
        box.next:Click()
        Check(4, steps[4], 7)
        -- The colour picker open: the tour steps aside; Escape closes the
        -- picker first, and the tour comes back.
        local field
        for _, obj in ipairs(H.objects) do
            if rawget(obj, "setting") == "ringCustom" and rawget(obj, "input") then field = obj end
        end
        field.swatch:Click()
        Equal(tostring(ns.ColourPicker:IsOpen()) .. " " .. tostring(Shown(box)) .. " " .. tostring(H.Visible(box.outline)),
            "true false false", "the colour picker open: the tour steps aside")
        FECursorEscButton:Click()
        Equal(tostring(ns.ColourPicker:IsOpen()) .. " " .. tostring(Shown(box)) .. " " .. tostring(ns.Tour:Active()),
            "false true true", "Escape closes the picker first, and the tour comes back")
        Check(4, steps[4], 7, "Rings, after the picker")
        box.next:Click()
        Check(5, steps[5], 7)
        -- The profile menu opened: the box moves beside it.
        w.profileButton:Click()
        Equal(tostring(Shown(w.profilePanel)) .. " " .. Anchor() .. " " .. tostring(First() == w.profilePanel),
            "true TOPRIGHT TOPLEFT true", "the menu open: the box beside it, outlining it")
        Equal(Overlap(box, w.profilePanel), false, "and clear of it")
        w.profileButton:Click()
        Equal(Anchor() .. " " .. tostring(First() == w.profileButton), "TOPRIGHT BOTTOMRIGHT true", "closed, back under the button")
        w.pages.autoswitch.tab = "mounts"
        box.next:Click()
        Check(6, steps[6], 7)
        Equal(ns.Get("autoSwitch"), false, "the tour ticks nothing here either")
        -- A pick list open: the tour steps aside, and comes back as it closes.
        w.autoRows[1]:Click()
        local list = w.pages.autoswitch.pickList
        Equal(Shown(list), true, "a rule's pick list open")
        Equal(tostring(Shown(box)) .. " " .. tostring(H.Visible(box.outline)), "false false", "the tour steps aside")
        w.autoRows[1]:Click()
        Equal(Shown(list), false, "the list closed")
        Equal(Shown(box) and Shown(box.outline), true, "the tour back")
        box.next:Click()
        Check(7, steps[7], 7)
        Equal(Text(), "Open these settings any time with this button or /fec. What's new shows after each update, and this tour is "
            .. "on the General page.", "where to find the settings and the tour")
        box.next:Click()
        Equal(Shown(box) or Shown(box.outline), false, "Done ends the tour")
        Equal(Shown(w) and Footer(), "That's the tour. " .. TOUR_NOTE, "leaving the window open, and saying where the tour is")
        Equal(S[outline].scripts.OnUpdate, nil, "and nothing left running")

        -- Take the tour on the General page; Escape ends the tour first, then
        -- closes the window.
        w:Select("general")
        Equal(w.tour:IsVisible() and S[w.tour.label].text, "Take the tour", "Take the tour on the General page")
        Equal(NoteOf(w.tour), "A short tour of this window, a page at a time. /fec tour starts it too.", "with its note")
        w.tour:Click()
        Equal(Shown(box) and Count() .. " " .. Title(), "1 of 7 THE MENU", "starts it from the first step")
        FECursorEscButton:Click()
        Equal(tostring(Shown(box)) .. " " .. tostring(Shown(w)), "false true", "Escape ends the tour, the window stays")
        FECursorEscButton:Click()
        Equal(Shown(w), false, "then Escape closes the window")
        -- Closing the window ends it too.
        SlashCmdList.FECURSOR("tour")
        box.next:Click()
        w.close:Click()
        Equal(Shown(box), false, "closing the window ends the tour")
        SlashCmdList.FECURSOR("")
        Equal(Shown(box), false, "and it doesn't come back by itself")
        -- The whole tour in a fight.
        H.Combat(true)
        SlashCmdList.FECURSOR("tour")
        local titles = {}
        for i = 1, 7 do
            titles[#titles + 1] = Title()
            if i < 7 then box.next:Click() end
        end
        Equal(table.concat(titles, ", "), BASICS, "every step works in a fight too")
        Equal(NoteOf(box), "The tour: Next and Back step through it, Skip tour ends it.", "and no Escape offered then")
        box.skip:Click()
        H.Combat(false)
        -- What's new's own tour: no steps of its own yet, and the basics all came with 1.0.0.
        Equal(#ns.Tour:News(ns.Version()), 0, "nothing new since this version")
        Equal(#ns.Tour:News("1.0.0"), 0, "nor since 1.0.0: the basics came with it")
        Equal(#ns.Tour:News("0.9.0"), 7, "since an older version: the basics, all new")
        Clean("the tour")
    end)
end)()

-- The released copy (1.0.0, uploaded by hand, with no packager): the game
-- reads the TOC's own number (Tools/TestRules.mjs checks the TOC says 1.0.0,
-- the newest in CHANGELOG.txt), and What's new, the footer and What's new's
-- tour go by it. A tester's copy from before had no number ("dev").
do
    H.Environment()
    local number = "1.0.0"
    _G.C_AddOns.GetAddOnMetadata = function(name, field)
        if name == H.ADDON and field == "Version" then return number end
    end
    ns = H.Load({ notesSeen = "dev" })
    Equal(ns.Version() .. " " .. ns.NOTES[1].version, "1.0.0 1.0.0", "read as the game reads it, the newest notes its own")
    H.Advance(2)
    local notes = FECursorNotes
    Equal(notes ~= nil and Shown(notes), true, "What's new shows once, a moment after the login")
    Equal(S[notes.version].text .. " | " .. tostring(ns.NotesSeen()), "Version 1.0.0 | 1.0.0", "headed 1.0.0, and noted as seen")
    notes.done:Click()
    SlashCmdList.FECURSOR("")
    w = FECursorFrame
    Equal(S[w.versionText].text, "v1.0.0   /fec to open", "the footer's version")
    Equal(#ns.Tour:News(ns.Version()) .. " " .. #ns.Tour:News("dev") .. " " .. #ns.Tour:News("0.9.0"), "0 0 7",
        "What's new's tour: nothing new for 1.0.0 or a tester's copy, the basics since an older version")
    Clean("the released copy")
end

io.stdout:write("TestTour: " .. H.checks .. " checks passed\n")
