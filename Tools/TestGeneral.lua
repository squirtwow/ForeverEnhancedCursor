-- Run the addon's real files against a mock game (Tools/Harness.lua): the
-- General page's Reset and More from Squirt.
-- Reset: its question (the addon's own, in the window, never the game's
-- popups or the keyboard) from the button and /fec reset; its notes; Cancel,
-- its X, Escape and the window closing change nothing; This profile puts the
-- profile showing back to the defaults and leaves everything else; Everything
-- leaves one profile at the defaults and the window's settings at theirs, as
-- a first install; both at once with no reload; the saved settings after
-- each; in a fight too; EraUI's settings untouched.
-- More from Squirt: Squirt's two other Forever Enhanced addons, each with
-- its icon, a line about it and where it stands; Open (installed) runs its
-- own command and closes this window; the links (not installed) copy the
-- right address; Forever Enhanced Raid Frames is always Coming soon; laid out
-- with nothing on anything else; no EraUI. The cooldown manager's two
-- pictures: thumbnails in its panel, full size over the window while the
-- mouse is on one, installed or not.
-- No em dash anywhere in either.
-- Run with fengari: Tools/TestGeneral.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, Near, True = H.S, H.Equal, H.Near, H.True
local ns, w
local MINE = "Zriel (Druid) - Zephras"
local ME, OTHER = "Player-1-0001", "Player-1-0002"
local ZRIEL = { guid = ME, name = "Zriel", realm = "Zephras", class = "Druid", classFile = "DRUID" }

local function Text() return S[w.note].text end
-- A control's note in the footer, the mouse over it and away again.
local function Note(region)
    if S[region].scripts.OnEnter then S[region].scripts.OnEnter(region) end
    local text = Text()
    if S[region].scripts.OnLeave then S[region].scripts.OnLeave(region) end
    return text
end

-- A value as one line of text, keys sorted, to compare whole.
local function Dump(value)
    if type(value) ~= "table" then return type(value) == "string" and ("%q"):format(value) or tostring(value) end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = "[" .. Dump(key) .. "]=" .. Dump(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- A table's keys, sorted, between bars.
local function Keys(t)
    local keys = {}
    for key in pairs(t) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    return table.concat(keys, " | ")
end

-- The game's own popups are never used for the question.
local function NoPopups()
    _G.StaticPopup_Show = function() H.Violation("showed one of the game's popups") end
    _G.StaticPopupDialogs = setmetatable({}, { __newindex = function() H.Violation("added one of the game's popups") end })
end

-- A character with two profiles, every rule picked, a hold, and every
-- shared setting changed from its default.
local function Setup()
    H.character = ZRIEL
    H.Environment()
    NoPopups()
    ns = H.Load(nil)
    local db = ForeverEnhancedCursorDB
    for _, pair in ipairs({ { "trail", true }, { "trailWidth", 30 }, { "colourMode", "rainbow" }, { "colour3", "123456" },
        { "ring", true }, { "ringCustom", "FF0000" }, { "cast", true }, { "look", true }, { "lookSize", 60 } }) do
        ns.Set(pair[1], pair[2])
    end
    ns.NewProfile("Raid")
    ns.Set("trail", true)
    ns.Set("ring", true)
    ns.UseProfile(MINE)
    ns.SetAccountWide(true)
    db.chars[OTHER] = "Raid"
    ns.SetRulePick("combat", MINE)
    ns.SetRulePick("dungeon", "Raid")
    ns.AddMount(101)
    ns.SetMountPick(101, "Raid")
    ns.SetTalentPick(1, "Raid")
    ns.SetSavedHold("Raid", "dungeon")
    for _, pair in ipairs({ { "accent", "teal" }, { "minimap", false }, { "minimapAngle", 90 }, { "autoSwitch", true },
        { "autoSay", true } }) do
        ns.Set(pair[1], pair[2])
    end
    ns.Theme:Repaint()
    ns.MinimapButton:Apply()
    ns.SetEraOffered()
    SlashCmdList.FECURSOR("")
    w = FECursorFrame
    return db
end

-- Every em dash in a text or note under root, notes worked out as they show.
local function Dashes(root)
    local found = {}
    for _, region in ipairs(H.objects) do
        if region == root or H.Under(region, root) then
            local text = S[region].text
            if type(text) == "string" and text:find("\226\128\148", 1, true) then found[#found + 1] = text end
            local hint = rawget(region, "hint")
            if type(hint) == "function" then hint = hint(region) end
            if type(hint) == "string" and hint:find("\226\128\148", 1, true) then found[#found + 1] = hint end
        end
    end
    return table.concat(found, " | ")
end

-- Reset: the part on General ---------------------------------------------------------------------

local db = Setup()
local R = w.reset
SlashCmdList.FECURSOR("")
Equal(S[w].shown, false, "the window toggles shut")
SlashCmdList.FECURSOR("")
w:Select("general")
local page = w.pages.general
local heading = H.Find("RESET")
True(heading ~= nil and H.Under(heading, page), "General has a Reset part")
Equal(H.Rect(heading, w).t, H.Rect(H.Find("WINDOW ACCENT"), w).t, "at the top, beside the window's accent")
Equal(S[w.resetButton.label].text, "Reset to defaults", "its button")
True(H.Visible(w.resetButton), "showing")
Equal(Note(w.resetButton), "Back to the defaults: the profile showing, or everything. It asks which first. /fec reset asks too.",
    "its note says what it does, and that it asks")
True(H.Visible(H.Find("Puts this profile, or everything, back to the defaults. It asks first.")), "a line under it says so too")
Equal(S[R.shade].shown, false, "no question until one is asked")

-- The question --------------------------------------------------------------------------------------

local before, shape = Dump(db), Keys(db)
w.resetButton:Click()
Equal(S[R.shade].shown, true, "the button asks first")
Equal(Dump(db), before, "asking changes nothing")
Equal(R.shade:GetParent(), w, "the addon's own question, in the window (not a game popup)")
Equal(table.concat(S[R.dialog].backdrop, ","), table.concat(ns.Theme.PANEL, ","), "in the window's own look")
Equal(S[R.shade].mouse, true, "nothing behind it can be clicked meanwhile")
True(R.shade:GetFrameLevel() > w.confirm.shade:GetFrameLevel() and R.shade:GetFrameLevel() > w.shareBox.shade:GetFrameLevel()
    and R.shade:GetFrameLevel() > w.profilePanel:GetFrameLevel(), "over the window's other questions, boxes and menus")
local keys = 0
for _, region in ipairs(H.objects) do
    if region == R.shade or H.Under(region, R.shade) then keys = keys + H.Calls(region, "EnableKeyboard") end
end
Equal(keys, 0, "never taking the keyboard")
Equal(S[R.dialog.title].text, "Reset to the defaults?", "a short question")
Equal(S[R.dialog.detail].text, "This profile puts " .. MINE .. " back to the defaults. Everything starts again from one new"
    .. " profile, as on a first install. Neither can be undone.", "naming the profile showing")
Equal(S[R.profile.label].text .. " | " .. S[R.everything.label].text .. " | " .. S[R.cancel.label].text .. " | "
    .. S[R.close.label].text, "This profile | Everything | Cancel | X", "three answers and an X")
-- Laid out: inside the question, nothing on anything else, the X clear of the title.
local function QuestionFits(label)
    local box, parts, problems = H.Rect(R.dialog, w), { R.dialog.title, R.dialog.detail, R.close, R.profile, R.everything, R.cancel }, {}
    for i, a in ipairs(parts) do
        local r = H.Rect(a, w)
        if r.l < box.l or r.r > box.r or r.t > box.t or r.b < box.b then problems[#problems + 1] = i .. " outside" end
        for j = i + 1, #parts do
            if H.Overlap(a, parts[j], w) then problems[#problems + 1] = i .. " on " .. j end
        end
    end
    Equal(table.concat(problems, "; "), "", label)
end
QuestionFits("every part inside the question, none on another")
-- Each answer's note says exactly what it does.
Equal(Note(R.profile), "Every setting of " .. MINE .. " back to its default, every effect off. Its name, account-wide mark and"
    .. " Auto-switch picks stay, and so do your other profiles.", "This profile's note")
Equal(Note(R.everything), "Every profile and Auto-switch rule deleted, and you start on one new profile, every effect off. The"
    .. " window's accent and minimap button go back too, as on a first install.", "Everything's note")
Equal(Note(R.cancel), "Close the question. Nothing changes.", "Cancel's note")
Equal(Note(R.close), "Close the question. Nothing changes. Escape closes it too.", "the X's: Escape too, out of a fight")
H.Combat(true)
Equal(Note(R.close), "Close the question. Nothing changes.", "in a fight Escape is the game's, so not offered")
H.Combat(false)
Equal(Note(R.shade), "Answer the question first: This profile, Everything, or Cancel to change nothing.", "the shade's note")
Equal(Dashes(R.shade), "", "no em dash in the question or its notes")

-- Cancel, the X, Escape and the window closing change nothing.
R.cancel:Click()
Equal(tostring(S[R.shade].shown) .. " " .. tostring(S[w].shown) .. " " .. tostring(Dump(db) == before), "false true true",
    "Cancel closes it, the window stays, nothing changes")
w.resetButton:Click()
R.close:Click()
Equal(tostring(S[R.shade].shown) .. " " .. tostring(Dump(db) == before), "false true", "the X too")
w.resetButton:Click()
Equal(H.bindings[FECursorEscButton], "ESCAPE:FECursorEscButton", "Escape is the window's while it's open")
FECursorEscButton:Click()
Equal(tostring(S[R.shade].shown) .. " " .. tostring(S[w].shown) .. " " .. tostring(Dump(db) == before), "false true true",
    "Escape closes the question only, nothing changed")
FECursorEscButton:Click()
Equal(S[w].shown, false, "Escape again closes the window")
SlashCmdList.FECURSOR("")
w.resetButton:Click()
w:Hide()
Equal(tostring(S[R.shade].shown) .. " " .. tostring(Dump(db) == before), "false true", "the window closing under it: gone, nothing changed")
SlashCmdList.FECURSOR("")
Equal(S[R.shade].shown, false, "and not back with the window")

-- /fec reset: the window on General, asking.
w:Select("trail")
SlashCmdList.FECURSOR("reset")
Equal(tostring(S[w].shown) .. " " .. w.selected .. " " .. tostring(S[R.shade].shown), "true general true",
    "/fec reset: General, and the question")
R.cancel:Click()
w:Hide()
SlashCmdList.FECURSOR("  RESET ")
Equal(tostring(S[w].shown) .. " " .. w.selected .. " " .. tostring(S[R.shade].shown), "true general true",
    "from a closed window too, in any case")
R.cancel:Click()
Equal(Dump(db), before, "nothing changed")

-- Whatever else sits over the window closes as it asks, so it's the only
-- thing asking: another question (unanswered: neither of its answers runs),
-- the share box, the profile menu, the colour picker (its colour kept) and
-- the tour.
do
    local ran = {}
    w:Ask("A question", "Its detail", "Yes", function() ran[#ran + 1] = "yes" end, function() ran[#ran + 1] = "after" end)
    SlashCmdList.FECURSOR("reset")
    Equal(tostring(S[w.confirm.shade].shown) .. " " .. #ran .. " " .. tostring(S[R.shade].shown), "false 0 true",
        "another question closes unanswered")
    R.cancel:Click()
    w.shareBox:Open("export", "FEC1:text")
    SlashCmdList.FECURSOR("reset")
    Equal(tostring(S[w.shareBox.shade].shown) .. " " .. tostring(S[R.shade].shown), "false true", "the share box closes")
    R.cancel:Click()
    w:Select("general")
    w.profileButton:Click()
    Equal(S[w.profilePanel].shown, true, "the profile menu open")
    w.resetButton:Click()
    Equal(tostring(S[w.profilePanel].shown) .. " " .. tostring(S[R.shade].shown), "false true", "the profile menu closes")
    R.cancel:Click()
    ns.Tour:Start()
    Equal(ns.Tour:Active(), true, "the tour going")
    w:Select("general")
    w.resetButton:Click()
    Equal(tostring(ns.Tour:Active()) .. " " .. tostring(S[R.shade].shown), "false true", "the tour ends")
    R.cancel:Click()
    w:Select("rings")
    w.pages.rings.tab = "ring"
    w:Refresh()
    local field
    for _, obj in ipairs(H.objects) do
        if rawget(obj, "setting") == "ringCustom" and rawget(obj, "input") then field = obj end
    end
    field.swatch:Click()
    ns.ColourPicker:PickHue(1 / 3)
    ns.ColourPicker:PickSquare(1, 1)
    SlashCmdList.FECURSOR("reset")
    Equal(tostring(ns.ColourPicker:IsOpen()) .. " " .. ns.Get("ringCustom") .. " " .. tostring(S[R.shade].shown), "false 00FF00 true",
        "the colour picker closes, its colour kept")
    R.cancel:Click()
    ns.Set("ringCustom", "FF0000")
    Equal(Dump(db), before, "and nothing else changed")
    Equal(H.Problems(), "", "nothing wrong asking")
end

-- And the other way round: the tour starting (/fec tour, or What's new's)
-- closes the question unanswered, so it never sits over the tour.
do
    SlashCmdList.FECURSOR("reset")
    SlashCmdList.FECURSOR("tour")
    Equal(tostring(S[R.shade].shown) .. " " .. tostring(ns.Tour:Active()), "false true", "/fec tour: the question closes, the tour going")
    ns.Tour:Stop()
    SlashCmdList.FECURSOR("reset")
    Equal(S[R.shade].shown, true, "asked again")
    ns.Tour:StartNews("0.9.0")
    Equal(tostring(S[R.shade].shown) .. " " .. tostring(ns.Tour:Active()), "false true", "What's new's tour too")
    ns.Tour:Stop()
    Equal(Dump(db), before, "nothing changed")
end

-- This profile ----------------------------------------------------------------------------------------

do
    True(ns.Engine.ring:IsShown() and ns.Engine.driver:IsShown(), "the ring showing before")
    local heard = {}
    ns.Listen(function(key) heard[#heard + 1] = tostring(key) end)
    w.resetButton:Click()
    R.profile:Click()
    Equal(S[R.shade].shown, false, "the answer closes the question")
    Equal(Dump(db.profiles[MINE]), "{}", "every setting of the profile showing gone, so each shows its default")
    Equal(table.concat(heard, ","), "nil", "everything that draws hears it, once, at once")
    for key, value in pairs(ns.DEFAULTS) do
        if ns.PROFILE_KEYS[key] then Equal(ns.Get(key), value, key .. " at its default") end
    end
    Equal(tostring(ns.Engine.ring:IsShown()) .. " " .. tostring(ns.Engine.driver:IsShown()), "false false",
        "the effects go at once, with no reload")
    Equal(ForeverEnhancedCursorAPI.IsShown("trail") or ForeverEnhancedCursorAPI.IsShown("ring"), false, "the API says so too")
    Equal(Text(), MINE .. " is back to the defaults, with every effect off.", "the footer says so")
    -- Everything else stays.
    Equal(Keys(db), shape, "the saved settings keep their shape")
    Equal(Dump(db.profiles.Raid), Dump({ trail = true, ring = true }), "the other profile untouched")
    Equal(Keys(db.profiles), "Raid | " .. MINE, "both profiles still there")
    Equal(db.everyone, MINE, "the account-wide mark stays")
    Equal(Dump(db.chars), Dump({ [ME] = MINE, [OTHER] = "Raid" }), "every character keeps its profile")
    Equal(Dump(db.rules), Dump({ combat = MINE, dungeon = "Raid" }), "the rules' picks stay")
    Equal(Dump(db.mountRules) .. " " .. Dump(db.talentRules), Dump({ [101] = "Raid" }) .. " " .. Dump({ [ME] = { "Raid" } }),
        "the mounts' and talents' too")
    Equal(Dump(db.held), Dump({ [ME] = { name = "Raid", why = "dungeon" } }), "and the hold")
    Equal(db.accent .. " " .. tostring(db.minimap) .. " " .. db.minimapAngle .. " " .. tostring(db.autoSwitch) .. " "
        .. tostring(db.autoSay) .. " " .. tostring(db.eraOffered), "teal false 90 true true true", "the window's settings stay")
    Equal(ns.ProfileName(), MINE, "still on it")
    Equal(H.Problems(), "", "nothing wrong")
end

-- With a rule's profile showing, This profile is that one, as everywhere in
-- the window; your own is left alone.
do
    ns.Set("trailWidth", 22)
    w:Hide()
    ns.SetOverride("Raid")
    SlashCmdList.FECURSOR("reset")
    True(S[R.dialog.detail].text:find("This profile puts Raid back to the defaults.", 1, true) ~= nil, "the question names it")
    True(Note(R.profile):find("Every setting of Raid back to its default", 1, true) ~= nil, "and so does the note")
    R.profile:Click()
    Equal(Dump(db.profiles.Raid) .. " " .. ns.ProfileName(), "{} Raid", "the rules' profile is reset, and still shows")
    Equal(Dump(db.profiles[MINE]), Dump({ trailWidth = 22 }), "your own left as it was")
    w:Hide()
    ns.SetOverride(nil)
end

-- A profile more than one character uses: the question and its note say
-- they all get the defaults; one only you use says nothing of it.
do
    db.chars[OTHER] = MINE
    SlashCmdList.FECURSOR("reset")
    Equal(S[R.dialog.detail].text, "This profile puts " .. MINE .. " back to the defaults, for all 2 characters using it."
        .. " Everything starts again from one new profile, as on a first install. Neither can be undone.", "the question says how many use it")
    Equal(Note(R.profile), "Every setting of " .. MINE .. " back to its default, every effect off, for all 2 characters using it."
        .. " Its name, account-wide mark and Auto-switch picks stay, and so do your other profiles.", "and so does its note")
    QuestionFits("the question grows to fit, nothing on anything else")
    R.cancel:Click()
    -- A rule's profile showing: its own users count, not your profile's.
    w:Hide()
    ns.SetOverride("Raid")
    SlashCmdList.FECURSOR("reset")
    True(S[R.dialog.detail].text:find("This profile puts Raid back to the defaults. Everything", 1, true) ~= nil,
        "a rule's profile no one else uses: not said")
    R.cancel:Click()
    w:Hide()
    ns.SetOverride(nil)
    db.chars[OTHER] = "Raid"
    SlashCmdList.FECURSOR("reset")
    Equal(Note(R.profile):find("characters using it", 1, true), nil, "used by you alone: not said")
    R.cancel:Click()
    w:Hide()
end

-- Everything --------------------------------------------------------------------------------------

do
    -- Auto-switch itself showing Raid (the Primary talents rule, once the
    -- login's moment is over), the window closed.
    H.Advance(2)
    Equal(H.printed[1], "|cffffd100Forever Enhanced Cursor:|r Primary talents, so now on profile Raid.", "Auto-switch shows Raid")
    H.printed = {}
    ns.Set("ring", true)
    SlashCmdList.FECURSOR("reset")
    True(S[FECursorMinimapButton].shown == false and ns.Override() == "Raid", "the minimap button hidden, a rule's profile showing")
    True(ns.Engine.ring:IsShown() and S[heading].colour[1] == ns.Theme.ACCENTS.teal.colour[1], "its ring showing, the window teal")
    local heard = {}
    ns.Listen(function(key) heard[#heard + 1] = tostring(key) end)
    R.everything:Click()
    Equal(S[R.shade].shown, false, "the answer closes the question")
    Equal(Keys(db), "chars | eraOffered | notesSeen | profiles",
        "saved: the profiles and characters, and what the addon noted, nothing else")
    Equal(Keys(db.profiles), MINE, "exactly one profile, named as a first install names it")
    Equal(Dump(db.profiles[MINE]), "{}", "at the defaults")
    Equal(Dump(db.chars), Dump({ [ME] = MINE }), "this character on it; the others let go, to get their own at their next login")
    Equal(tostring(db.notesSeen) .. " " .. tostring(db.eraOffered), "dev true",
        "What's new seen and EraUI's offer made stay noted (neither shows again)")
    Equal(ns.ProfileName() .. " | " .. tostring(ns.Override()) .. " | " .. tostring(ns.OwnProfile()), MINE .. " | nil | " .. MINE,
        "your own profile showing, no rule's")
    for key, value in pairs(ns.DEFAULTS) do Equal(ns.Get(key), value, key .. " at its default") end
    Equal(ns.EveryoneProfile(), nil, "nothing account-wide")
    Equal(#ns.RuleProfiles() .. " " .. #ns.MountIDs() .. " " .. tostring(ns.TalentPick(1)) .. " " .. tostring(ns.SavedHold()),
        "0 0 nil nil", "no rules, mounts, talent picks or hold")
    local status = ns.AutoSwitch.Status()
    Equal(tostring(status.on) .. " " .. tostring(status.name) .. " " .. tostring(status.waiting) .. " " .. tostring(status.held),
        "false nil false false", "Auto-switch off: picking nothing, nothing waiting, nothing held")
    Equal(table.concat(heard, ","), "nil", "everything that draws hears it, once, at once")
    -- At once: the accent, the minimap button, the effects and the window.
    Equal(S[heading].colour[1], ns.Theme.ACCENTS.orange.colour[1], "the window repainted in orange")
    Equal(S[FECursorMinimapButton].shown, true, "the minimap button back")
    local point = H.Point(FECursorMinimapButton, "CENTER")
    Near(point[4], math.cos(math.rad(255)) * 74, "at its first place again", .001)
    Equal(tostring(ns.Engine.ring:IsShown()) .. " " .. tostring(ns.Engine.driver:IsShown()), "false false", "no effects")
    Equal(Text(), "Everything is back to the defaults: one profile, " .. MINE .. ", with every effect off.", "the footer says so")
    Equal(S[w.profileButton.label].text, "|cff8b8d92Profile|r   " .. MINE, "the header names it")
    Equal(S[w].shown, true, "the window stays open")
    -- Every page and tab draws from the fresh start.
    for _, view in ipairs({ { "trail" }, { "colours" }, { "rings", "ring" }, { "rings", "cast" }, { "rings", "look" },
        { "profiles" }, { "autoswitch", "rules" }, { "autoswitch", "mounts" }, { "general" } }) do
        w:Select(view[1])
        if view[2] then w.pages[view[1]].tab = view[2]; w:Refresh() end
    end
    Equal(H.Problems(), "", "nothing wrong, on any page")
    -- The window closing switches nothing: the rules are gone.
    w:Hide()
    Equal(ns.ProfileName(), MINE, "nothing switches as the window closes")
end

-- Over a reload: one profile, and no first install, so no welcome, tour or
-- What's new. Another character, at its next login, gets its own.
do
    local saved = db
    H.Environment()
    ns = H.Load(saved)
    H.Advance(5)
    Equal(tostring(ns.firstInstall) .. " | " .. ns.ProfileName(), "false | " .. MINE, "a normal login, on it")
    Equal(tostring(FECursorFrame) .. " " .. tostring(FECursorNotes) .. " " .. tostring(FECursorTour), "nil nil nil",
        "no welcome, What's new or tour")
    H.character = { guid = OTHER, name = "Mira", realm = "Zephras", class = "Mage", classFile = "MAGE" }
    H.Environment()
    ns = H.Load(saved)
    Equal(ns.ProfileName(), "Mira (Mage) - Zephras", "another character: its own profile at its next login")
    Equal(Keys(saved.profiles), "Mira (Mage) - Zephras | " .. MINE, "as a new character gets")
    H.character = ZRIEL
end

-- In a fight too: profiles are the addon's own textures.
do
    db = Setup()
    R = w.reset
    SlashCmdList.FECURSOR("reset")
    H.Combat(true)
    R.everything:Click()
    Equal(Keys(db.profiles) .. " " .. tostring(ns.Get("ring")), MINE .. " false", "in a fight too")
    H.Combat(false)
    SlashCmdList.FECURSOR("reset")
    H.Combat(true)
    ns.Set("ring", true)
    R.profile:Click()
    Equal(tostring(ns.Get("ring")) .. " " .. Dump(db.profiles[MINE]), "false {}", "This profile in a fight too")
    H.Combat(false)
    Equal(H.Problems(), "", "nothing wrong in a fight")
end

-- Before the profile is known, there's nothing to reset.
do
    H.character = { guid = nil, name = "Zriel", realm = "Zephras", class = "Druid", classFile = "DRUID" }
    H.Environment()
    ns = H.Load(nil, true)
    local saved = Dump(ForeverEnhancedCursorDB)
    local ok, why = ns.ResetEverything()
    Equal(tostring(ok) .. " " .. tostring(why), "false Your profile hasn't loaded yet.", "Everything waits for the profile")
    ok, why = ns.ResetProfile()
    Equal(tostring(ok) .. " " .. tostring(why), "false Your profile hasn't loaded yet.", "and so does This profile")
    -- Asked meanwhile, the question names no profile it can't know.
    SlashCmdList.FECURSOR("reset")
    w = FECursorFrame
    local early = w.reset
    Equal(S[early.dialog.detail].text, "This profile puts your profile back to the defaults. Everything starts again from one new"
        .. " profile, as on a first install. Neither can be undone.", "the question, before the profile loads")
    True(Note(early.profile):find("^Every setting of your profile back to its default") ~= nil, "and its note")
    early.profile:Click()
    Equal(Text(), "Your profile hasn't loaded yet.", "answered: the footer says why nothing happened")
    Equal(Dump(ForeverEnhancedCursorDB), saved, "nothing changed meanwhile")
    H.character = ZRIEL
end

-- EraUI's settings are never touched (the addon only ever reads them).
do
    db = Setup()
    R = w.reset
    w:Hide()
    local era = { enabled = true, cursorTrail = true, cursorRing = true, cursorCastRing = false, cursorTrailSize = 12 }
    local eraBefore = Dump(era)
    H.Era(era)
    SlashCmdList.FECURSOR("reset")
    R.profile:Click()
    SlashCmdList.FECURSOR("reset")
    R.everything:Click()
    Equal(tostring(rawequal(_G.EraUIDB, era)) .. " " .. tostring(Dump(era) == eraBefore), "true true", "EraUI's settings untouched")
    w:Hide()
    SlashCmdList.FECURSOR("")
    Equal(S[w.confirm.shade].shown, false, "and its offer, made before, isn't made again")
    Equal(H.Problems(), "", "nothing wrong")
end

-- /fec reset opening the window: its question first. The window's first-look
-- offers (EraUI's settings, a first install's tour), which the question would
-- close unseen, wait for the next opening instead.
do
    H.Environment()
    H.Era({ enabled = true, cursorTrail = true, cursorRing = true, cursorCastRing = false, cursorTrailSize = 12 })
    ns = H.Load({ notesSeen = "dev" })
    SlashCmdList.FECURSOR("reset")
    w = FECursorFrame
    Equal(tostring(S[w.reset.shade].shown) .. " " .. tostring(S[w.confirm.shade].shown) .. " " .. tostring(ns.EraOffered()),
        "true false false", "EraUI's offer: not made under the question, and not noted as made")
    w.reset.cancel:Click()
    -- Asked again with the window open, by /fec reset or the button: nothing
    -- waiting is put off again.
    SlashCmdList.FECURSOR("reset")
    w.reset.cancel:Click()
    w.resetButton:Click()
    w.reset.cancel:Click()
    w:Hide()
    SlashCmdList.FECURSOR("")
    Equal(tostring(S[w.confirm.shade].shown) .. " " .. tostring(ns.EraOffered()), "true true", "the next opening makes it")
    w.confirm.no:Click()
    Equal(H.Problems(), "", "nothing wrong")

    -- A first install: no welcome under the question, even as the login's
    -- moment passes; the next opening offers the tour.
    H.Environment()
    ns = H.Load(nil)
    SlashCmdList.FECURSOR("reset")
    w = FECursorFrame
    H.Advance(5)
    Equal(tostring(S[w.reset.shade].shown) .. " " .. tostring(FECursorTour ~= nil and H.Visible(FECursorTour)), "true false",
        "a first install: the question, and no welcome under it")
    w.reset.cancel:Click()
    SlashCmdList.FECURSOR("reset")
    w.reset.cancel:Click()
    w:Hide()
    SlashCmdList.FECURSOR("")
    Equal(tostring(FECursorTour ~= nil and H.Visible(FECursorTour)) .. " " .. tostring(FECursorTour and S[FECursorTour.title].text),
        "true WELCOME", "the next opening offers the tour")
    ns.Tour:Stop()
    Equal(H.Problems(), "", "nothing wrong")
end

-- More from Squirt ---------------------------------------------------------------------------------------

H.character = ZRIEL
H.Environment()
NoPopups()
ns = H.Load(nil)
SlashCmdList.FECURSOR("")
w = FECursorFrame
w:Select("general")
page = w.pages.general
local fecm, ferf = w.more.fecm, w.more.ferf
local FECM_NAME, FERF_NAME = "Forever Enhanced Cooldown Manager", "Forever Enhanced Raid Frames"
local CURSEFORGE = "https://www.curseforge.com/wow/addons/forever-enhanced-cooldown-manager"
local GITHUB = "https://github.com/squirtwow/ForeverEnhancedCooldownManager"

do
    local more = H.Find("MORE FROM SQUIRT")
    True(more ~= nil and H.Under(more, page), "General has More from Squirt")
    Equal(Keys(w.more), "fecm | ferf", "two addons, no more")
    True(H.Rect(more, w).b >= H.Rect(fecm, w).t and H.Rect(fecm, w).b > H.Rect(ferf, w).t,
        "under its heading, the cooldown manager first")
    True(H.Rect(H.Find("Bugs, ideas and help on the Discord.", true), w).b > H.Rect(more, w).t, "under Help")
    Equal(S[fecm.title].text .. " | " .. S[ferf.title].text, FECM_NAME .. " | " .. FERF_NAME, "each by its name")
    Equal(S[fecm.icon].texture .. " | " .. S[ferf.icon].texture, "Interface\\AddOns\\ForeverEnhancedCursor\\Media\\FECMIcon.tga"
        .. " | Interface\\AddOns\\ForeverEnhancedCursor\\Media\\FERFIcon.tga", "each with this addon's own copy of its icon")
    Equal(S[fecm.about].text, "A cleaner Cooldown Manager and resource display, with cooldown, buff and cast bars of your own.",
        "a line about the cooldown manager")
    Equal(S[ferf.about].text, "A cleaner look for Blizzard's raid frames, with health text and icons for HoTs, shields and debuffs.",
        "and the raid frames")
end

-- Every part showing on General: texts, what takes the mouse, the icons and
-- the Coming soon mark.
local function Parts()
    local list = {}
    for _, region in ipairs(H.objects) do
        local s = S[region]
        if H.Under(region, page) and region:IsVisible() then
            local text = s.kind == "FontString" and type(s.text) == "string" and s.text ~= ""
            local takes = s.kind == "Button" or s.kind == "EditBox" or s.mouse == true
            local icon = s.kind == "Texture" and type(s.texture) == "string" and s.texture:find("Icon%.tga$") ~= nil
            if text or takes or icon or region == ferf.soon then list[#list + 1] = region end
        end
    end
    return list
end

-- Laid out: everything inside the page, each addon's parts inside its
-- panel, nothing on anything else (but what sits inside it).
local function Layout(state)
    local problems = {}
    local area = H.Rect(page, w)
    local list = Parts()
    local function Name(region)
        local label = rawget(region, "label")
        return S[region].kind .. ":" .. tostring(S[region].text or (label and S[label].text) or S[region].texture or "?")
    end
    for i, a in ipairs(list) do
        local r = H.Rect(a, w)
        if r.l < area.l or r.r > area.r or r.t > area.t or r.b < area.b then problems[#problems + 1] = Name(a) .. " outside the page" end
        for _, panel in ipairs({ fecm, ferf }) do
            local box = H.Rect(panel, w)
            if H.Under(a, panel) and (r.l < box.l or r.r > box.r or r.t > box.t or r.b < box.b) then
                problems[#problems + 1] = Name(a) .. " outside its panel"
            end
        end
        for j = i + 1, #list do
            local c = list[j]
            if not H.Under(a, c) and not H.Under(c, a) and H.Overlap(a, c, w) then problems[#problems + 1] = Name(a) .. " on " .. Name(c) end
        end
    end
    True(#list >= 25, state .. ": the parts found (" .. #list .. ")")
    Equal(table.concat(problems, "; "), "", state .. ": the General page fits, nothing on anything else")
end

-- Not installed: its links, no Open.
do
    Equal(tostring(H.Visible(fecm.open)) .. " " .. tostring(H.Visible(fecm.links[1])) .. " " .. tostring(H.Visible(fecm.links[2])),
        "false true true", "not installed: links, no Open")
    Equal(S[fecm.links[1].label].text .. " " .. S[fecm.links[2].label].text, "CurseForge GitHub", "CurseForge and GitHub")
    Equal(S[fecm.state].text, "Get it on CurseForge or GitHub: click one for its link.", "saying so")
    Equal(Note(fecm), FECM_NAME .. ": not installed. Get it on CurseForge or GitHub.", "its panel's note")
    Equal(Note(fecm.links[1]), FECM_NAME .. " on CurseForge, as a link to copy.", "each link's note")
    Equal(Note(fecm.links[2]), FECM_NAME .. " on GitHub, as a link to copy.", "and the other's")
    Layout("not installed")
    fecm.links[1]:Click()
    local box = FECursorCopyLink
    Equal(tostring(S[box].shown) .. " " .. S[box.input].text, "true " .. CURSEFORGE, "CurseForge's address, ready to copy")
    Equal(S[box.title].text, "FOREVER ENHANCED COOLDOWN MANAGER ON CURSEFORGE", "titled with what it is")
    Equal(S[box.note].text, "Press Ctrl+C to copy, then paste it into your browser. On CurseForge, Install opens the CurseForge app.",
        "and how to use it")
    Equal(tostring(S[box.input].focus), "true", "selected, to copy")
    box.close:Click()
    fecm.links[2]:Click()
    Equal(tostring(S[box].shown) .. " " .. S[box.input].text .. " | " .. S[box.title].text,
        "true " .. GITHUB .. " | FOREVER ENHANCED COOLDOWN MANAGER ON GITHUB", "GitHub's")
    Equal(S[box.note].text, "Press Ctrl+C to copy, then paste it into your browser.", "with the usual note")
    box.close:Click()
    Equal(S[w].shown, true, "the window stays open for the links")
end

-- Installed: Open, no links. Open runs its own command, as /fecm does, and
-- closes this window.
do
    H.addOns.ForeverEnhancedCooldownManager = true
    w:Refresh()
    Equal(tostring(H.Visible(fecm.open)) .. " " .. tostring(H.Visible(fecm.links[1])) .. " " .. tostring(H.Visible(fecm.links[2])),
        "true false false", "installed: Open, no links")
    Equal(S[fecm.open.label].text, "Open", "its button")
    Equal(S[fecm.state].text, "Installed. Type /fecm, or click Open.", "saying so")
    Equal(Note(fecm.open), "Open " .. FECM_NAME .. "'s settings, as /fecm does. This window closes.", "Open's note")
    Equal(Note(fecm), FECM_NAME .. ": installed. Open shows its settings.", "its panel's note")
    Layout("installed")
    local ran = {}
    SlashCmdList.FECM = function(msg) ran[#ran + 1] = msg end
    fecm.open:Click()
    Equal(Dump(ran) .. " " .. tostring(S[w].shown), '{[1]=""} false', "Open runs its own command, as /fecm, and closes this window")
    -- Its window already open: left open (its command would close it again).
    SlashCmdList.FECURSOR("")
    local theirs = CreateFrame("Frame", "FECMFrame", UIParent)
    fecm.open:Click()
    Equal(#ran .. " " .. tostring(S[w].shown) .. " " .. tostring(S[theirs].shown), "1 false true",
        "its window already open: left open, this one closes")
    theirs:Hide()
    SlashCmdList.FECURSOR("")
    fecm.open:Click()
    Equal(#ran .. " " .. tostring(S[w].shown), "2 false", "its window shut: opened")
    _G.FECMFrame = nil
    -- Its command not there: this window stays, saying what to type.
    SlashCmdList.FECM = nil
    SlashCmdList.FECURSOR("")
    fecm.open:Click()
    Equal(tostring(S[w].shown) .. " " .. Text(), "true Type /fecm to open it.", "no command: the window stays, saying what to type")
    -- Asked the game's older way, where it has no C_AddOns; no answer is no.
    local addOns = _G.C_AddOns
    _G.C_AddOns = nil
    _G.IsAddOnLoaded = function(name) return name == "ForeverEnhancedCooldownManager" end
    w:Refresh()
    Equal(H.Visible(fecm.open), true, "the older IsAddOnLoaded: installed")
    _G.IsAddOnLoaded = function() error("not now") end
    w:Refresh()
    Equal(tostring(H.Visible(fecm.open)) .. " " .. tostring(H.Visible(fecm.links[1])), "false true", "an error: not installed")
    _G.IsAddOnLoaded = nil
    w:Refresh()
    Equal(H.Visible(fecm.links[1]), true, "no way to ask: not installed")
    _G.C_AddOns = addOns
    H.addOns.ForeverEnhancedCooldownManager = false
    w:Refresh()
    Equal(H.Problems(), "", "nothing wrong")
end

-- Forever Enhanced Raid Frames: Coming soon, with nothing to get or open,
-- installed or not.
do
    SlashCmdList.FERF = function() error("never opened from here") end
    for _, installed in ipairs({ false, true }) do
        H.addOns.ForeverEnhancedRaidFrames = installed
        w:Refresh()
        local state = installed and "installed" or "not installed"
        local buttons, links = 0, {}
        for _, obj in ipairs(H.objects) do
            if H.Under(obj, ferf) then
                if S[obj].kind == "Button" or S[obj].kind == "EditBox" then buttons = buttons + 1 end
                local text = S[obj].text
                if type(text) == "string" and text:find("http", 1, true) then links[#links + 1] = text end
            end
        end
        Equal(buttons .. " " .. #links, "0 0", state .. ": nothing to click, no links")
        Equal(tostring(H.Visible(ferf.soon)) .. " " .. S[ferf.soon.label].text, "true COMING SOON", state .. ": marked Coming soon")
        Equal(S[ferf.state].text, "Not out yet: nothing to get for now.", state .. ": saying so")
        Equal(Note(ferf), FERF_NAME .. ": coming soon. It isn't out yet, so there's nothing to get or open for now.", state .. ": its note")
    end
    H.addOns.ForeverEnhancedRaidFrames = nil
    SlashCmdList.FERF = nil
end

-- The cooldown manager's pictures -------------------------------------------------------------------
-- Two thumbnails at the top right of its panel (its Layout page and its bars
-- in game, this addon's own copies), the same height, each its picture's own
-- shape, in a thin border; the buttons under them. The mouse on one shows it
-- full size over the window with its caption, inside the window, clear of
-- the thumbnails; leaving it hides it. Installed or not.
local MEDIA = "Interface\\AddOns\\ForeverEnhancedCursor\\Media\\"
local SHOTS = {
    { file = MEDIA .. "FECMShotLayout.tga", height = 349, caption = "The Layout page",
        note = FECM_NAME .. ": its Layout page, shown full size while the mouse is on it." },
    { file = MEDIA .. "FECMShotInGame.tga", height = 392, caption = "In game: bars, resource display and cast bar",
        note = FECM_NAME .. ": its bars, resource display and cast bar in game, shown full size while the mouse is on it." },
}
local function Hover(region) S[region].scripts.OnEnter(region) end
local function Leave(region) S[region].scripts.OnLeave(region) end
local function Colour(list) return table.concat({ list[1], list[2], list[3] }, ",") end
local function Edge(region) return Colour(S[region].border) end

do
    w:Select("general")
    local view, shots = w.shotView, fecm.shots
    Equal(#shots .. " " .. tostring(ferf.shots), "2 nil", "two pictures for the cooldown manager, none for the raid frames")
    for i, thumb in ipairs(shots) do
        local shot = SHOTS[i]
        Equal(thumb:GetParent(), fecm, i .. ": in the cooldown manager's panel")
        Equal(S[thumb.picture].texture, shot.file, i .. ": this addon's own copy")
        Equal(S[thumb.picture].filter, "TRILINEAR", i .. ": smoothed, as it's drawn small")
        Equal(table.concat(S[thumb.picture].texCoord, ","), "0,1,0," .. shot.height / 512, i .. ": the picture, not the rows under it")
        local r, p = H.Rect(thumb, w), H.Rect(thumb.picture, w)
        Equal(p.t - p.b, 62, i .. ": 62 high")
        Near((p.r - p.l) / (p.t - p.b), 512 / shot.height, i .. ": its own shape", .01)
        Equal((p.l - r.l) .. " " .. (r.r - p.r) .. " " .. (r.t - p.t) .. " " .. (p.b - r.b), "1 1 1 1", i .. ": a border all round")
        Equal(H.Last(thumb, "SetBackdrop").edgeSize, 1, i .. ": a thin one")
        Equal(Edge(thumb), Colour(ns.Theme.CONTROL_BORDER), i .. ": in the window's look")
        Equal(tostring(S[thumb].mouse) .. " " .. tostring(H.Visible(thumb)), "true true", i .. ": showing, and it feels the mouse")
    end
    local a, b, box = H.Rect(shots[1], w), H.Rect(shots[2], w), H.Rect(fecm, w)
    Equal(a.t .. " " .. a.b, b.t .. " " .. b.b, "side by side, the same height")
    Equal(b.l - a.r, 8, "a gap between them")
    Equal((box.r - b.r) .. " " .. (box.t - a.t), "12 12", "at the panel's top right")
    True(a.l - H.Rect(fecm.about, w).r >= 12, "clear of the line about it")
    local raid, area = H.Rect(ferf, w), H.Rect(page, w)
    Equal((box.b - raid.t) .. " " .. (raid.t - raid.b), "8 80", "the raid frames under it as before, the same gap between")
    True(raid.b - area.b >= 8, "room to spare under them (" .. (raid.b - area.b) .. ")")
    Equal(S[view].shown, false, "nothing full size until the mouse is on one")
    Equal(view:IsMouseEnabled(), false, "the full size takes no mouse, so the thumbnail keeps it")
    Equal(H.Last(view, "SetClampedToScreen"), true, "and never leaves the screen")

    for _, installed in ipairs({ false, true }) do
        H.addOns.ForeverEnhancedCooldownManager = installed
        w:Refresh()
        local state = installed and "installed" or "not installed"
        -- The buttons in a row under the pictures, lined up with them on
        -- the right, the line saying where it stands level with them.
        local buttons = installed and { fecm.open } or fecm.links
        local line = H.Rect(fecm.state, w)
        for _, button in ipairs(buttons) do
            local r = H.Rect(button, w)
            True(H.Visible(button) and r.t < a.b, state .. ": " .. S[button.label].text .. " under the pictures")
            Equal((r.t + r.b) / 2, (line.t + line.b) / 2, state .. ": the line beside " .. S[button.label].text .. ", level")
        end
        Equal(H.Rect(buttons[#buttons], w).r, b.r, state .. ": lined up with the pictures on the right")
        Layout(state .. ", with the pictures")
        for i, thumb in ipairs(shots) do
            local shot = SHOTS[i]
            local label = state .. ", " .. shot.caption
            True(H.Visible(thumb), label .. ": showing")
            Hover(thumb)
            True(H.Visible(view), label .. ": the mouse on it shows it full size")
            Equal(Text(), shot.note, label .. ": the footer says what it is")
            Equal(Edge(thumb), Colour(ns.Theme:Accent()), label .. ": its border lit")
            Equal(S[view.picture].texture .. " " .. table.concat(S[view.picture].texCoord, ","), shot.file .. " 0,1,0," .. shot.height / 512,
                label .. ": the same picture")
            Equal(S[view.picture].width .. "x" .. S[view.picture].height, "512x" .. shot.height, label .. ": full size, its own shape")
            Equal(S[view.caption].text, shot.caption, label .. ": its caption")
            -- Inside the window (so on the screen, as the window is), above
            -- the footer saying what it is, clear of both thumbnails, over
            -- the page and the "Are you sure?" question, under the Reset
            -- question.
            local v, win = H.Rect(view, w), H.Rect(w, w)
            True(v.l >= win.l and v.r <= win.r and v.t <= win.t and v.b >= win.b, label .. ": inside the window")
            True(v.b >= H.Rect(page, w).b, label .. ": above the footer")
            local s = H.Rect(view, UIParent)
            True(s.l >= 0 and s.r <= 1024 and s.t <= 0 and s.b >= -768, label .. ": on the screen")
            True(not H.Overlap(view, shots[1], w) and not H.Overlap(view, shots[2], w), label .. ": clear of the thumbnails")
            local pic, cap = H.Rect(view.picture, w), H.Rect(view.caption, w)
            True(pic.l > v.l and pic.r < v.r and pic.t < v.t and cap.b > v.b and cap.r < v.r, label .. ": picture and caption inside it")
            True(cap.t < pic.b, label .. ": the caption under the picture")
            True(view:GetFrameLevel() > page:GetFrameLevel() + 10 and view:GetFrameLevel() > shots[i]:GetFrameLevel()
                and view:GetFrameLevel() > w.confirm.shade:GetFrameLevel()
                and view:GetFrameLevel() < w.reset.shade:GetFrameLevel(),
                label .. ": over the page and the \"Are you sure?\" question, under the Reset question")
            Leave(thumb)
            Equal(tostring(S[view].shown) .. " " .. Edge(thumb), "false " .. Colour(ns.Theme.CONTROL_BORDER), label .. ": leaving it hides it")
            True(Text() ~= shot.note, label .. ": and its note")
        end
    end
    H.addOns.ForeverEnhancedCooldownManager = false
    w:Refresh()

    -- From one straight onto the other, whichever order the game sends the
    -- leave and the enter: the second shows, and only its leaving hides it.
    Hover(shots[1])
    Hover(shots[2])
    Equal(S[view.caption].text .. " | " .. Edge(shots[1]) .. " | " .. Edge(shots[2]), SHOTS[2].caption .. " | "
        .. Colour(ns.Theme.CONTROL_BORDER) .. " | " .. Colour(ns.Theme:Accent()), "onto the second before leaving the first")
    Leave(shots[1])
    Equal(tostring(H.Visible(view)) .. " " .. S[view.caption].text, "true " .. SHOTS[2].caption, "the first's leave leaves it")
    Leave(shots[2])
    Equal(S[view].shown, false, "the second's leave hides it")
    Hover(shots[1])
    Leave(shots[2])
    Equal(H.Visible(view), true, "nor does the other's, late")
    Leave(shots[1])

    -- The accent: its border, and the thumbnail's while lit.
    ns.Set("accent", "blue")
    ns.Theme:Repaint()
    Hover(shots[2])
    Equal(Colour(S[view].border) .. " | " .. Edge(shots[2]), Colour(ns.Theme.ACCENTS.blue.colour) .. " | "
        .. Colour(ns.Theme.ACCENTS.blue.colour), "in the window's accent")
    Leave(shots[2])
    ns.Set("accent", "orange")
    ns.Theme:Repaint()

    -- Never left showing: another page, the window closing, Escape (the
    -- window's, as before: nothing new in its order) all take it away, and
    -- it doesn't come back with the page.
    Hover(shots[1])
    w:Select("trail")
    Equal(S[view].shown, false, "another page: gone")
    w:Select("general")
    Equal(S[view].shown, false, "and not back with General")
    Hover(shots[1])
    w:Hide()
    SlashCmdList.FECURSOR("")
    Equal(tostring(S[view].shown) .. " " .. Edge(shots[1]), "false " .. Colour(ns.Theme.CONTROL_BORDER), "the window closing: gone")
    w:Select("general")
    Hover(shots[2])
    FECursorEscButton:Click()
    Equal(tostring(S[w].shown) .. " " .. tostring(S[view].shown), "false false", "Escape closes the window, as before, and it goes")
    SlashCmdList.FECURSOR("")
    w:Select("general")

    -- The tour from General: its first step stays on General, its box clear
    -- of the pictures, and a picture shown full size meanwhile sits over its
    -- box and outline.
    w.tour:Click()
    True(ns.Tour:Active() and w.selected == "general", "the tour's first step, on General")
    for _, thumb in ipairs(shots) do True(not H.Overlap(FECursorTour, thumb, w), "its box clear of the pictures") end
    Hover(shots[1])
    True(H.Visible(view) and view:GetFrameLevel() > FECursorTour:GetFrameLevel()
        and view:GetFrameLevel() > FECursorTour.outline:GetFrameLevel(), "shown full size over the tour's box and outline")
    Leave(shots[1])
    ns.Tour:Stop()
    Equal(Dashes(view), "", "no em dash in the pictures' captions")
    Equal(H.Problems(), "", "nothing wrong")
end

-- Only Squirt's Forever Enhanced addons: no EraUI, and no em dash, in any
-- text, note or link, installed or not.
do
    local said = {}
    local function Gather()
        for _, panel in ipairs({ fecm, ferf }) do
            for _, region in ipairs(H.objects) do
                if region == panel or H.Under(region, panel) then
                    said[#said + 1] = tostring(S[region].text or "")
                    local hint = rawget(region, "hint")
                    if type(hint) == "function" then hint = hint(region) end
                    said[#said + 1] = tostring(hint or "")
                end
            end
        end
    end
    for _, installed in ipairs({ false, true }) do
        H.addOns.ForeverEnhancedCooldownManager = installed
        w:Refresh()
        Gather()
    end
    H.addOns.ForeverEnhancedCooldownManager = false
    w:Refresh()
    for _, link in ipairs(fecm.links) do
        link:Click()
        said[#said + 1] = S[FECursorCopyLink.input].text .. " " .. S[FECursorCopyLink.title].text .. " " .. S[FECursorCopyLink.note].text
        FECursorCopyLink.close:Click()
    end
    local all = table.concat(said, " | ")
    Equal(all:lower():find("era%s*ui") , nil, "no EraUI anywhere in More from Squirt")
    Equal(all:find("\226\128\148", 1, true), nil, "no em dash")
    Equal(Dashes(page), "", "nor anywhere on General")
end

-- The window's names stay its own: nothing named for these.
do
    local strangers = {}
    for _, name in ipairs(H.NewGlobals()) do
        if not H.Ours(name) and name ~= "StaticPopup_Show" and name ~= "StaticPopupDialogs" then strangers[#strangers + 1] = name end
    end
    Equal(table.concat(strangers, " "), "", "every global name the addon makes is its own")
    Equal(H.Problems(), "", "nothing wrong anywhere")
end

io.stdout:write("TestGeneral: " .. H.checks .. " checks passed\n")
