-- Run the addon's real files against a mock game (Tools/Harness.lua): the
-- /fec window and its pages, every setting's control and note (the
-- question's buttons too), each page laid out with nothing on anything else,
-- Needs testing only where it still applies, no em dash anywhere shown, the preview
-- and its pointer, the addon's own colour picker (the game's never touched)
-- and hex boxes, the Rings tabs saying what's on, EraUI's notices (only while
-- EraUI is loaded), profiles and the header's
-- profile menu, the minimap button, the Discord, Escape, Options > AddOns,
-- the saved settings, the public API, and that every global the addon makes
-- is its own.
-- Run with fengari: Tools/TestWindow.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, Near, True, Fire = H.S, H.Equal, H.Near, H.True, H.Fire
local ns, w

local function Hover(region, script) if S[region].scripts[script] then S[region].scripts[script](region) end end
local function Text() return S[w.note].text end
local CREDIT = "Made with |TInterface\\AddOns\\ForeverEnhancedCursor\\Media\\Heart.tga:0:0:0:0:32:32:0:32:0:32:%d:%d:%d|t"
    .. " by |cff%sSquirt|r"
local ORANGE = CREDIT:format(224, 120, 41, "e07829")
local MINE = "Zriel (Druid) - Zephras"
-- Types into a text box and presses Enter.
local function Type(box, text)
    box:SetText(text)
    S[box].scripts.OnEnterPressed(box)
end

-- Loading, the commands and Options > AddOns ------------------------------------------------

H.Environment()
ns = H.Load(nil)
Equal(SLASH_FECURSOR1, "/fec", "/fec opens the settings")
Equal(SLASH_FECURSOR2, "/fecursor", "and /fecursor, in case another addon takes /fec")
Equal(type(SlashCmdList.FECURSOR), "function", "through its own command")
Equal(H.category and H.category.title, "Forever Enhanced Cursor", "listed under Options > AddOns")
Equal(tostring(ns.firstInstall) .. " " .. ns.ProfileName(), "true " .. MINE, "a first install: a profile of your own")
Equal(FECursorFrame, nil, "no window until it's asked for")
Equal(H.Problems(), "", "nothing wrong at load")

-- Every effect and extra starts off.
for key, value in pairs(ns.DEFAULTS) do
    if type(value) == "boolean" and key ~= "minimap" and key ~= "lookRight" and key ~= "lookLeft" then
        Equal(value, false, key .. " starts off")
    end
end
Equal(ns.Get("colourMode") .. " " .. ns.Get("ringColour") .. " " .. ns.Get("castColour") .. " " .. ns.Get("lookColour"),
    "class custom class none", "class colours for the trail and cast, white for the ring (as EraUI's), no tint on the highlight")
Equal(ns.Get("ringSize") .. " " .. ns.Get("ringThickness") .. " " .. ns.Get("castSize") .. " " .. ns.Get("castAlpha"), "48 2 60 90",
    "the ring and cast ring as EraUI's")

-- The window --------------------------------------------------------------------------------------

SlashCmdList.FECURSOR("")
w = FECursorFrame
Equal(S[w].shown, true, "/fec opens the window")
local ORDER = { "trail", "colours", "rings", "profiles", "autoswitch", "general" }
Equal(table.concat(ns.PAGE_KEYS, " "), table.concat(ORDER, " "), "six pages")
do
    local labels, tops = {}, {}
    for _, key in ipairs(ORDER) do
        labels[#labels + 1] = S[w.nav[key].label].text
        tops[#tops + 1] = S[w.nav[key]].points[1][3]
    end
    Equal(table.concat(labels, "|"), "Trail|Colours|Rings|Profiles|Auto-switch|General", "listed down the left")
    Equal(table.concat(tops, " "), "-12 -44 -76 -120 -152 -184", "the effects' pages, a rule, then Profiles, Auto-switch and General")
end
Equal(w.selected, "trail", "opening on Trail")
Equal(S[w].strata, "FULLSCREEN_DIALOG", "over the game's own windows")
Equal(H.bindings[FECursorEscButton], "ESCAPE:FECursorEscButton", "Escape closes the window")
Equal(S[w.header.title].text, "Forever |cffe07829Enhanced|r Cursor", "the title with Enhanced in the accent")
Equal(S[w.header.icon].texture, "Interface\\AddOns\\ForeverEnhancedCursor\\Media\\FECIcon.tga", "and the addon's icon")
Equal(Text(), ORANGE, "the footer's credit: the heart and Squirt in the accent")
Equal(S[w.versionText].text, "dev   /fec to open", "the footer shows the version")
for _, key in ipairs(ORDER) do
    w:Select(key)
    local shown = {}
    for other, page in pairs(w.pages) do if S[page].shown then shown[#shown + 1] = other end end
    Equal(table.concat(shown, ","), key, key .. " page shown alone")
    Equal(S[w.nav[key].glow].shown, true, key .. " lit in the list")
    Equal(S[w.pages[key]].width .. " " .. S[w.pages[key]].height, "638 489", key .. " page sized as it's made")
end
w:Select("nope")
Equal(w.selected, "general", "an unknown page is ignored")

-- The accent, on General: set colours, kept for every character.
local heading = H.Find("WINDOW ACCENT")
True(heading ~= nil and H.Under(heading, w.pages.general), "General starts with the window's accent")
Equal(#w.swatches, 5, "five accents")
w.swatches[3]:Click()
Equal(ns.Get("accent"), "teal", "a set colour chosen")
Equal(S[heading].colour[1], .17, "the whole window repaints")
Equal(S[w.accentChosen].text, "Teal", "and names it")
Equal(ForeverEnhancedCursorDB.accent, "teal", "kept for every character, outside the profiles")
w.swatches[1]:Click()
Equal(Text(), ORANGE, "back to orange")

-- Closing: the X, Escape and /fec again; Escape is given back in combat.
w.close:Click()
Equal(S[w].shown, false, "the X closes it")
Equal(H.bindings[FECursorEscButton], nil, "and hands Escape back")
SlashCmdList.FECURSOR("")
H.Combat(true)
Equal(H.bindings[FECursorEscButton], nil, "in combat Escape goes back to the game")
H.Combat(false)
FECursorEscButton:Click()
Equal(S[w].shown, false, "Escape closes the window")
SlashCmdList.FECURSOR("")
SlashCmdList.FECURSOR("")
Equal(S[w].shown, false, "/fec toggles it")
for _, obj in ipairs(H.objects) do
    if S[obj].template == "UIPanelButtonTemplate" then obj:Click() end
end
Equal(S[w].shown, true, "Open settings under Options > AddOns opens it")
Equal(H.Problems(), "", "nothing wrong in the window")

-- Every setting has a control with a note -----------------------------------------------------------

do
    local controls, bySetting = {}, {}
    for _, obj in ipairs(H.objects) do
        local setting = rawget(obj, "setting")
        if setting and rawget(obj, "Sync") or (setting and S[obj].kind == "Button") then
            controls[#controls + 1] = obj
            bySetting[setting] = obj
        end
    end
    local missing = {}
    for key in pairs(ns.PROFILE_KEYS) do
        if not bySetting[key] then missing[#missing + 1] = key end
    end
    table.sort(missing)
    Equal(table.concat(missing, " "), "", "every profile setting has a control on a page")
    -- Each slider within the setting's own limits, and its step.
    local sliders = 0
    for _, control in ipairs(controls) do
        local key = rawget(control, "setting")
        if rawget(control, "track") then
            sliders = sliders + 1
            local limits = ns.NUMBERS[key]
            control:Choose(-1e9)
            Equal(ns.Get(key), limits[1], key .. " stops at its least")
            control:Choose(1e9)
            Equal(ns.Get(key), limits[2], key .. " stops at its most")
            control:Choose(limits[3])
            Equal(ns.Get(key), limits[3], key .. " back to its default")
        end
    end
    local numbers = 0
    for key in pairs(ns.NUMBERS) do if ns.PROFILE_KEYS[key] then numbers = numbers + 1 end end
    Equal(sliders .. " " .. numbers, "18 18", "every number in a profile has a slider (the minimap's angle is dragged)")
    local life = bySetting.trailLife
    life:Choose(.33)
    Equal(ns.Get("trailLife"), .35, "Lifetime in steps of .05 seconds, saved as it shows")
    life:Choose(.25)
    local profile = ForeverEnhancedCursorDB.profiles[MINE]
    Equal(profile.trailLife, nil, "back at its default, the profile keeps nothing for it")
end

-- Every control has a note, and shows it in the footer -----------------------------------------------

do
    local ground = { [w.profilePanel] = true, [w.confirm.shade] = true }
    local function Control(region)
        local s = S[region]
        if not s or ground[region] then return false end
        return s.kind == "Button" or s.kind == "EditBox" or rawget(region, "track") ~= nil or s.mouse == true
    end
    w.profileButton:Click()
    w.profileButton:Click()
    local controls, missing = {}, {}
    for _, region in ipairs(H.objects) do
        if H.Under(region, w) and Control(region) then
            controls[#controls + 1] = region
            if rawget(region, "hint") == nil then
                missing[#missing + 1] = S[region].kind .. ":" .. tostring(S[region].text or (rawget(region, "label") and S[region.label].text)) .. " "
            end
        end
    end
    Equal(table.concat(missing), "", "every button, box, slider and anything else taking the mouse has a note")
    True(#controls >= 60, "all of them checked (" .. #controls .. ")")
    local quiet, tried = {}, {}
    local views = { { "trail" }, { "colours" }, { "rings", "ring" }, { "rings", "cast" }, { "rings", "look" }, { "profiles" },
        { "autoswitch", "rules" }, { "autoswitch", "mounts" }, { "general" } }
    for _, view in ipairs(views) do
        w:Select(view[1])
        if view[2] then w.pages[view[1]].tab = view[2]; w:Refresh() end
        for _, control in ipairs(controls) do
            Hover(control, "OnEnter")
            if control:IsVisible() then
                tried[control] = true
                local text = Text()
                if type(text) ~= "string" or text == "" or text:find("^Made with") then
                    quiet[#quiet + 1] = view[1] .. ":" .. S[control].kind .. ":" .. tostring(text) .. " "
                end
            end
            Hover(control, "OnLeave")
            if Text() ~= ORANGE then quiet[#quiet + 1] = view[1] .. " left on: " .. tostring(Text()) .. " " end
        end
    end
    local count = 0
    for _ in pairs(tried) do count = count + 1 end
    Equal(table.concat(quiet), "", "on every page and tab, each control showing has its note on hover and gives the footer back")
    True(count >= 60, "most of them showing somewhere (" .. count .. ")")

    -- The question's own buttons, while it's up.
    w:Select("profiles")
    w.accountWide:Click()
    Equal(S[w.confirm.shade].shown, true, "a question up")
    for _, pair in ipairs({ { w.confirm.yes, "Account-wide: go ahead, as the question says." },
        { w.confirm.no, "Close the question. Nothing changes." } }) do
        Hover(pair[1], "OnEnter")
        Equal(Text(), pair[2], "the question's buttons have notes too")
        Hover(pair[1], "OnLeave")
    end
    w.confirm.no:Click()

    -- No em dash in anything shown, however it was written.
    local dashed = {}
    for _, region in ipairs(H.objects) do
        local text = S[region].text
        if type(text) == "string" and text:find("\226\128\148", 1, true) then dashed[#dashed + 1] = text end
        local hint = rawget(region, "hint")
        if type(hint) == "function" then hint = hint(region) end
        if type(hint) == "string" and hint:find("\226\128\148", 1, true) then dashed[#dashed + 1] = hint end
    end
    Equal(table.concat(dashed, " | "), "", "no em dash in any text or note shown")
end

-- Laid out: every control on its page, clear of the preview, none on another ---------------------------

do
    -- What takes the mouse: buttons, boxes, slider tracks, anything else with
    -- the mouse on. A control inside another (a slider's track) is part of it.
    local function Takes(region)
        local s = S[region]
        return s.kind == "Button" or s.kind == "EditBox" or s.mouse == true
    end
    local views = { { "trail" }, { "colours" }, { "rings", "ring" }, { "rings", "cast" }, { "rings", "look" }, { "profiles" },
        { "autoswitch", "rules" }, { "autoswitch", "mounts" }, { "general" } }
    local PREVIEWED = { trail = true, colours = true, rings = true }
    local problems = {}
    local function Name(region)
        local s = S[region]
        local label = rawget(region, "text") or rawget(region, "label")
        return s.kind .. ":" .. tostring(s.text or (label and S[label].text) or rawget(region, "setting") or "?")
    end
    for _, view in ipairs(views) do
        local key = view[1]
        w:Select(key)
        if view[2] then w.pages[key].tab = view[2]; w:Refresh() end
        local page = w.pages[key]
        local area = H.Rect(page, w)
        local preview = H.Rect(w.preview, w)
        local list = {}
        for _, region in ipairs(H.objects) do
            if H.Under(region, page) and Takes(region) and region:IsVisible() then list[#list + 1] = region end
        end
        for i, a in ipairs(list) do
            local r = H.Rect(a, w)
            local where = table.concat(view, "/") .. " " .. Name(a)
            if r.l < area.l or r.r > area.r or r.t > area.t or r.b < area.b then problems[#problems + 1] = where .. " outside its page" end
            if PREVIEWED[key] and r.t > preview.b then problems[#problems + 1] = where .. " under the preview" end
            for j = i + 1, #list do
                local c = list[j]
                if not H.Under(a, c) and not H.Under(c, a) and H.Overlap(a, c, w) then
                    problems[#problems + 1] = where .. " on " .. Name(c)
                end
            end
        end
        True(#list >= 3, table.concat(view, "/") .. ": its controls found (" .. #list .. ")")
    end
    Equal(table.concat(problems, "; "), "", "on every page and tab, the controls fit, clear of the preview and of each other")
end

-- Needs testing, said only where it's still true ------------------------------------------------------

-- Seen working in game (2026-10-03): the trail and its extras, the cast ring,
-- the highlight while looking with each button, Share and Auto-switch. Not
-- yet: a mount you list, which keeps its Needs testing.
do
    -- The ticks for what's been seen working say just what they do, and so do their notes.
    for _, spec in ipairs({ { "trail", "Show the cursor trail" }, { "trailGlow", "Glow" }, { "trailShrink", "Shrink as it fades" },
        { "trailAlign", "Turn dots along the path" }, { "cast", "Show cast progress round the cursor" },
        { "look", "Cursor highlight while looking" }, { "lookRight", "While turning with the right mouse button" },
        { "lookLeft", "While moving the camera with the left mouse button" } }) do
        local tick
        for _, obj in ipairs(H.objects) do
            if rawget(obj, "setting") == spec[1] and S[obj].kind == "Button" and rawget(obj, "text") then tick = obj end
        end
        Equal(tick and S[tick.text].text, spec[2], spec[1] .. ": its tick, with no Needs testing")
        True(tick ~= nil and type(tick.hint) == "string" and #tick.hint > 20 and not tick.hint:find("testing", 1, true),
            spec[1] .. ": nor its note")
    end
    Equal(S[w.autoSwitchTick.text].text, "Switch profiles automatically", "Auto-switch's tick, with no Needs testing")
    True(not w.autoSwitchTick.hint:find("testing", 1, true), "nor its note")
    True(not w.shareExport.hint:find("testing", 1, true) and not w.shareImport.hint:find("testing", 1, true),
        "Share's Export and Import notes, with no Needs testing")
    True(H.Find("EXTRAS") ~= nil and H.Find("SHARE") ~= nil, "the trail's extras and Share, headed with no Needs testing")
    -- A mount you list keeps it: the rule's words and note, the Mounts tab and its heading.
    local mountRow, mountTab = w.autoRows[2], w.pages.autoswitch.tabs.buttons[2]
    Equal(mountRow.rule .. " " .. S[mountTab.label].text, "mount Mounts", "the mount rule's row and the Mounts tab")
    True(H.Find("A mount you list (Needs testing)") ~= nil, "the rule for a mount you list: Needs testing")
    True(mountRow.hint:find("Needs testing", 1, true) ~= nil, "and its note")
    True(mountTab.hint:find("Needs testing", 1, true) ~= nil, "the Mounts tab's note: Needs testing")
    True(H.Find("YOUR MOUNTS (NEEDS TESTING)") ~= nil, "the Mounts tab's heading: Needs testing")
    -- And nothing else, on any page or tab, shown or in a note.
    local keep = { ["A mount you list (Needs testing)"] = true, ["YOUR MOUNTS (NEEDS TESTING)"] = true }
    local stray = {}
    for _, obj in ipairs(H.objects) do
        local text = S[obj] and S[obj].text
        if type(text) == "string" and text:lower():find("needs testing", 1, true) and not keep[text] and obj ~= w.note then
            stray[#stray + 1] = text
        end
        local hint = type(obj) == "table" and rawget(obj, "hint")
        if type(hint) == "function" then
            local ok, said = pcall(hint, obj)
            hint = ok and said or nil
        end
        if type(hint) == "string" and hint:lower():find("needs testing", 1, true) and obj ~= mountRow and obj ~= mountTab then
            stray[#stray + 1] = hint
        end
    end
    Equal(table.concat(stray, " | "), "", "Needs testing nowhere else, shown or in a note")
end

-- The preview ------------------------------------------------------------------------------------------

do
    local preview = w.preview
    w:Select("trail")
    Equal(S[preview].shown, true, "the preview across the top of Trail")
    Equal(S[preview].clips, true, "drawing inside its box only")
    Equal(S[preview].width .. " " .. S[preview].height, "606 120", "606 by 120")
    True(S[preview].scripts.OnUpdate ~= nil, "running while it shows")
    Equal(S[preview].mouse, false, "ignoring the real mouse")
    Equal(S[preview.pointer].texture, "Interface\\Cursor\\Point", "the game's own pointer, the gauntlet, not a stand-in")
    Equal(S[preview.pointer].width .. " " .. S[preview.pointer].height, "24 24", "about as big as the game draws it")
    Equal(S[preview.caption].text, "Off: tick Show the cursor trail to use it.", "the trail off: it still shows, dimmed, saying so")
    -- Each effect's line names its tick by the words the tick shows.
    for _, view in ipairs({ { "trail", nil, "trail" }, { "rings", "ring", "ring" }, { "rings", "cast", "cast" }, { "rings", "look", "look" } }) do
        w:Select(view[1])
        if view[2] then w.pages.rings.tab = view[2]; w:Refresh() end
        local tick
        for _, obj in ipairs(H.objects) do
            if rawget(obj, "setting") == view[3] and S[obj].kind == "Button" and rawget(obj, "text") then tick = obj end
        end
        Equal(S[preview.caption].text, "Off: tick " .. S[tick.text].text .. " to use it.", view[3] .. ": the preview names its tick as it shows")
    end
    w:Select("trail")
    local made = H.textures
    for _ = 1, 90 do H.Frame() end
    True(preview.trail:Count() > 10, "the pointer's trail")
    do
        local tip, centre = H.Point(preview.pointer, "TOPLEFT"), H.Point(preview.ring, "CENTER")
        Equal(tip[4] .. " " .. tip[5], centre[4] .. " " .. centre[5], "its fingertip on the point the effects follow")
    end
    Equal(H.textures, made, "no textures made as it runs")
    Near(preview.trail.alpha, .55 * .35, "dimmed while off")
    ns.Set("trail", true)
    Equal(S[preview.caption].text, "", "on: no line")
    Near(preview.trail.alpha, .55, "at its own opacity")
    ns.Set("trailWidth", 30)
    local dot = preview.trail.tex[1]
    Equal(S[dot].width, 30, "every change shows at once")
    -- The ring in the trail's flowing colours, as on screen.
    ns.Set("ringColour", "trail")
    ns.Set("colourMode", "rainbow")
    ns.Set("colourSpeed", 50)
    H.Frame(.1)
    local before = table.concat(S[preview.ring.texture].tint, ",")
    H.Frame(.1)
    True(table.concat(S[preview.ring.texture].tint, ",") ~= before, "the preview's ring flows with the trail's colours")
    -- The highlight's tint likewise, but only Trail's: Class and Custom stay their own wash.
    ns.Set("lookColour", "trail")
    H.Frame(.1)
    before = table.concat(S[preview.look.texture].tint, ",")
    H.Frame(.1)
    True(table.concat(S[preview.look.texture].tint, ",") ~= before, "the preview's highlight: Trail's tint flows too")
    for _, choice in ipairs({ { "class", "1.000 0.694 0.424" }, { "custom", "1.000 0.400 0.400" } }) do
        ns.Set("lookCustom", "FF0000")
        ns.Set("lookColour", choice[1])
        local calls = H.Calls(preview.look.texture, "SetVertexColor")
        for _ = 1, 10 do H.Frame(.05) end
        local tint = S[preview.look.texture].tint
        Equal(("%.3f %.3f %.3f"):format(tint[1], tint[2], tint[3]) .. " " .. H.Calls(preview.look.texture, "SetVertexColor"),
            choice[2] .. " " .. calls, "the preview's highlight, " .. choice[1] .. ": its own wash, still while the trail's colours flow")
    end
    ns.Set("lookColour", "none")
    ns.Set("lookCustom", "FFFFFF")
    ns.Set("ringColour", "custom")
    ns.Set("colourMode", "class")
    ns.Set("colourSpeed", 0)
    -- The loop: the pointer looks round, then casts.
    w:Select("rings")
    w.pages.rings.tab = "look"
    w:Refresh()
    Equal(S[preview.caption].text, "Off: tick Cursor highlight while looking to use it.", "the While looking tab: about the highlight")
    w.preview:Run(false)
    w.preview:Run(true)
    for _ = 1, 216 do H.Frame() end -- 3.6 seconds in: looking round
    Equal(S[preview.pointer].shown, false, "looking: the pointer hides")
    Equal(S[preview.look].shown, true, "and the highlight marks where it'll come back")
    -- The same ghost gauntlet as on screen: the game's pointer, see-through,
    -- its fingertip where the pointer's just was. No ring and no dot.
    do
        local look = preview.look
        local textures, art = {}, {}
        for _, obj in ipairs(H.objects) do
            if S[obj].kind == "Texture" and H.Under(obj, look) then
                textures[#textures + 1] = obj
                if tostring(S[obj].texture):find("Media", 1, true) then art[#art + 1] = S[obj].texture end
            end
        end
        Equal(#textures .. " " .. tostring(textures[1] == look.texture) .. " " .. #art, "1 true 0",
            "the preview's highlight: one texture, no ring or dot art")
        Equal(S[look.texture].texture, S[preview.pointer].texture, "the same pointer the preview moves round")
        local tip, was = H.Point(look, "TOPLEFT"), H.Point(preview.pointer, "TOPLEFT")
        Equal(#S[look].points .. " " .. tostring(tip[2] == preview and was[2] == preview) .. " " .. tip[3] .. " " .. tip[4] .. " " .. tip[5],
            "1 true BOTTOMLEFT " .. was[4] .. " " .. was[5], "its fingertip exactly where the pointer's was")
        Equal(S[look].width .. " " .. S[look].height, "32 32", "at the highlight's size")
        Near(S[look].alpha, .6 * .35, "see-through, and dimmed while it's off")
        Equal(table.concat(S[look.texture].tint, " "), "1 1 1 1", "untinted")
        -- The ring, cast ring and dots take the game's level for a new frame
        -- (the strip's, one up); the pointer and caption are on top.
        Equal(tostring(S[preview.ring].level) .. " " .. tostring(S[preview.cast].level), "nil nil", "the other effects' own level")
        True(S[look].level > S[preview].level + 1 and S[look].level < S[preview.pointer:GetParent()].level,
            "the highlight over the other effects, as on screen")
        -- On, and changed: the preview's matches the real one's at once.
        ns.Set("look", true)
        ns.Set("lookSize", 48)
        ns.Set("lookAlpha", 75)
        ns.Set("lookColour", "custom")
        ns.Set("lookCustom", "3366FF")
        local real = ns.Engine.look
        Equal(S[look].width .. " " .. S[look].height .. " " .. S[look].alpha .. " " .. table.concat(S[look.texture].tint, " "),
            S[real].width .. " " .. S[real].height .. " " .. S[real].alpha .. " " .. table.concat(S[real.texture].tint, " "),
            "the preview's and the real one's: the same size, opacity and tint")
        Equal(S[look].width .. " " .. S[look].alpha, "48 0.75", "and as set")
        ns.Set("look", false)
        ns.Set("lookSize", 32)
        ns.Set("lookAlpha", 60)
        ns.Set("lookColour", "none")
        ns.Set("lookCustom", "FFFFFF")
    end
    -- Another tab mid-look: the dimmed highlight goes at once, not at the
    -- loop's next turn, and comes back with its tab.
    w.pages.rings.tab = "ring"
    w:Refresh()
    Equal(S[preview.look].shown, false, "another tab while looking: the dimmed highlight goes at once")
    w.pages.rings.tab = "look"
    w:Refresh()
    Equal(S[preview.look].shown, true, "and back with its tab")
    local count = preview.trail:Count()
    for _ = 1, 10 do H.Frame() end
    True(preview.trail:Count() <= count, "no new dots while looking")
    for _ = 1, 90 do H.Frame() end -- 5.1 seconds in: moving on, casting
    Equal(S[preview.pointer].shown and not S[preview.look].shown, true, "moving again")
    Equal(S[preview.cast].shown, false, "no cast ring: it's off, and this tab isn't about it")
    w.pages.rings.tab = "cast"
    w:Refresh()
    w.preview:Run(false)
    w.preview:Run(true)
    for _ = 1, 306 do H.Frame() end
    Equal(S[preview.cast].shown, true, "the Cast ring tab: a one second cast at the loop's end")
    Equal(S[preview.cast.cooldown].cooldown[2], 1, "a second long")
    -- Likewise mid-cast: another tab hides it at once; back on its tab, the
    -- same cast shows again.
    local castFrom = S[preview.cast.cooldown].cooldown[1]
    w.pages.rings.tab = "look"
    w:Refresh()
    Equal(S[preview.cast].shown, false, "another tab mid-cast: the dimmed cast ring goes at once")
    S[preview.cast.cooldown].cooldown = nil
    w.pages.rings.tab = "cast"
    w:Refresh()
    Equal(S[preview.cast].shown, true, "and back with its tab")
    Equal(tostring(S[preview.cast.cooldown].cooldown and S[preview.cast.cooldown].cooldown[1]) .. " "
        .. tostring(S[preview.cast.cooldown].cooldown and S[preview.cast.cooldown].cooldown[2]), castFrom .. " 1",
        "the same cast, from where it started")
    w:Select("general")
    Equal(S[preview].shown, false, "not on General")
    Equal(S[preview].scripts.OnUpdate, nil, "and not running")
    w:Select("trail")
    True(S[preview].scripts.OnUpdate ~= nil, "back on Trail, running again")
    w:Hide()
    Equal(S[preview].scripts.OnUpdate, nil, "the window closed: stopped")
    ns.Set("trail", false)
    ns.Set("trailWidth", 10)
    w:Show()
end

-- Colours: the addon's own colour picker, and hex digits typed in ---------------------------------------

-- The colour a swatch shows, as six hex digits.
local function Shown(swatch)
    local fill = S[swatch].backdrop
    return ns.Style.HexOf(fill[1], fill[2], fill[3])
end

-- Drags on the picker's square or bar: pressed at (x, y) on it, from its
-- bottom left, then moved to each further point, a frame each, and let go.
local function Drag(frame, points)
    S[frame].left, S[frame].bottom = 400, 200
    H.scale = 1
    H.cursor.x, H.cursor.y = 400 + points[1][1], 200 + points[1][2]
    S[frame].scripts.OnMouseDown(frame, "LeftButton")
    for i = 2, #points do
        H.cursor.x, H.cursor.y = 400 + points[i][1], 200 + points[i][2]
        H.Frame()
    end
    S[frame].scripts.OnMouseUp(frame, "LeftButton")
end

do
    w:Select("colours")
    local page = w.pages.colours
    local C = ns.ColourPicker
    local picker = C.frame
    ns.Set("colourMode", "gradient")
    ns.Set("colourCount", 3)
    Equal(S[page.swatches[2]].shown and S[page.swatches[10]].shown, true, "Gradient: all ten swatches")
    Equal(S[page.swatches[4]].alpha < 1 and S[page.swatches[3]].alpha == 1, true, "those past Colours in use dimmed")
    Equal(S[page.swatches[2].mark].text, "2", "each numbered")
    Equal(S[picker].shown, false, "the colour picker waits for a click")
    page.swatches[2]:Click()
    Equal(page.selected, 2, "a click picks the swatch")
    Equal(S[page.chosen].text, "Colour 2", "named")
    Equal(tostring(S[picker].shown) .. " " .. tostring(C:Setting()), "true colour2", "and opens the addon's own colour picker for it")
    Equal(S[picker.title].text, "COLOUR 2", "titled with what it's for")
    Equal(S[picker.hex].text .. " " .. Shown(picker.before) .. " " .. Shown(picker.now), "FF4D4D FF4D4D FF4D4D",
        "on its colour now: its hex digits, before and now")
    Equal(S[page.hex].shown or S[page.help].shown, false, "the page's own hex box steps aside meanwhile")
    Equal(S[w].strata, "FULLSCREEN_DIALOG", "part of the window: nothing steps down a layer")
    True(ns.PageParts.Picking(w), "the tour steps aside while it's open, as for a pick list")
    -- In the window's look, over the right of the page and under the preview.
    do
        local area, preview, rect = H.Rect(page, w), H.Rect(w.preview, w), H.Rect(picker, w)
        True(rect.l >= area.l and rect.r <= area.r and rect.b >= area.b and rect.t <= preview.b,
            ("inside the page, under the preview (%d %d %d %d)"):format(rect.l, rect.r, rect.t, rect.b))
        Equal(table.concat(S[picker].backdrop, ","), table.concat(ns.Theme.PANEL, ","), "on the window's own panel colour")
        True(picker:GetFrameLevel() > page:GetFrameLevel() + 40, "above the page and its lists")
    end
    -- Each colour moved through shows at once: the setting, the swatches,
    -- the preview.
    local lut = table.concat(w.preview.trail.lutG, ",")
    C:PickHue(1 / 3)
    C:PickSquare(1, 1)
    Equal(ns.Get("colour2"), "00FF00", "each colour moved through shows at once")
    Equal(S[picker.hex].text .. " " .. Shown(picker.now) .. " " .. Shown(page.swatches[2]), "00FF00 00FF00 00FF00",
        "in the picker and on the page's swatch")
    True(table.concat(w.preview.trail.lutG, ",") ~= lut, "and in the preview")
    Equal(Shown(picker.before), "FF4D4D", "the colour before stays beside it")
    -- Dragging on the square: across for how rich, up for how bright,
    -- following the cursor until the button lets go.
    Drag(picker.square, { { 70, 140 } })
    Equal(ns.Get("colour2"), "80FF80", "half way across: half as rich")
    Drag(picker.square, { { 0, 0 }, { 140, 70 }, { 140, 140 } })
    Equal(ns.Get("colour2"), "00FF00", "followed to the top right: the full colour")
    Equal(S[picker.square].scripts.OnUpdate, nil, "let go: it stops following")
    -- The bar: red at the top, round the rainbow.
    Drag(picker.bar, { { 7, 140 } })
    Equal(ns.Get("colour2"), "FF0000", "the bar's top: red")
    Drag(picker.bar, { { 7, 140 * 2 / 3 }, { 7, 70 } })
    Equal(ns.Get("colour2"), "00FFFF", "half way down: cyan")
    Drag(picker.bar, { { 7, 140 * 5 / 6 } })
    Equal(ns.Get("colour2"), "FFFF00", "a sixth of the way down: yellow")
    Drag(picker.bar, { { 7, -50 } })
    Equal(ns.Get("colour2"), "FF0000", "past the bar's foot: kept to it, red again")
    Drag(picker.bar, { { 7, 70 }, { 7, 190 } })
    Equal(ns.Get("colour2"), "FF0000", "past its top: red")
    Equal(H.Point(picker.notch, "CENTER")[5], 0, "its mark at the top")
    Drag(picker.bar, { { 7, 140 * 7 / 8 } })
    Equal(ns.Get("colour2"), "FFBF00", "an eighth of the way down: amber")
    Drag(picker.square, { { 400, 400 } })
    Equal(ns.Get("colour2"), "FFBF00", "past the square's top right: kept to it, the full colour")
    Drag(picker.square, { { 400, -400 } })
    Equal(ns.Get("colour2"), "000000", "past its foot: black")
    Drag(picker.square, { { 140, 140 } })
    Equal(ns.Get("colour2"), "FFBF00", "black, then bright again: the colour it was on")
    picker.cancel:Click()
    Equal(ns.Get("colour2"), "FF4D4D", "Cancel puts it back")
    Equal(S[picker].shown or C:IsOpen(), false, "and closes it")
    Equal(S[page.hex].shown and S[page.help].shown, true, "the page's own hex box back")
    -- OK keeps it.
    page.swatches[3]:Click()
    C:PickHue(2 / 3)
    C:PickSquare(1, 1)
    picker.ok:Click()
    Equal(ns.Get("colour3") .. " " .. tostring(C:IsOpen()), "0000FF false", "OK keeps it")
    -- Escape cancels, and leaves the window open.
    page.swatches[3]:Click()
    C:PickHue(0)
    Equal(ns.Get("colour3"), "FF0000", "red for now")
    FECursorEscButton:Click()
    Equal(ns.Get("colour3") .. " " .. tostring(C:IsOpen()) .. " " .. tostring(S[w].shown), "0000FF false true",
        "Escape puts it back and closes the picker only")
    -- Hex digits typed in the picker; Escape in its box cancels too.
    page.swatches[3]:Click()
    Type(picker.hex, "#ff8000")
    Equal(ns.Get("colour3") .. " " .. Shown(picker.now), "FF8000 FF8000", "six hex digits typed, a # and small letters allowed")
    Type(picker.hex, "orange")
    Equal(ns.Get("colour3") .. " " .. S[picker.hex].text, "FF8000 FF8000", "anything else ignored, the box put right")
    Equal(Text(), "Type six hex digits, like FF8000.", "and the footer says what it takes")
    picker.hex:SetFocus()
    S[picker.hex].scripts.OnEscapePressed(picker.hex)
    Equal(ns.Get("colour3") .. " " .. tostring(C:IsOpen()), "0000FF false", "Escape in its box: the colour from before")
    -- Colours to start from, and the one before.
    page.swatches[3]:Click()
    Equal(#picker.quick, 8, "eight colours to start from")
    picker.quick[2]:Click()
    Equal(ns.Get("colour3"), ns.Style.HexOf(ns.Style.ClassColour()), "your class's colour")
    picker.quick[1]:Click()
    Equal(ns.Get("colour3"), "FFFFFF", "white")
    C:PickHue(1 / 3)
    C:PickSquare(1, 1)
    Equal(ns.Get("colour3"), "00FF00", "from white, the bar still picks the colour")
    Type(picker.hex, "808080")
    Equal(ns.Get("colour3"), "808080", "a grey typed")
    C:PickSquare(1, 1)
    Equal(ns.Get("colour3"), "00FF00", "keeps the colour it was on: rich and bright again, green")
    picker.before:Click()
    Equal(ns.Get("colour3") .. " " .. tostring(C:IsOpen()), "0000FF true", "Before goes back to it, still picking")
    -- A second click on its swatch closes it, keeping the colour.
    C:PickHue(0)
    page.swatches[3]:Click()
    Equal(ns.Get("colour3") .. " " .. tostring(C:IsOpen()), "FF0000 false", "its swatch again: closed, the colour kept")
    -- Another swatch: the first keeps its colour, the picker moves on.
    page.swatches[3]:Click()
    C:PickHue(2 / 3)
    page.swatches[1]:Click()
    Equal(ns.Get("colour3") .. " " .. tostring(C:Setting()) .. " " .. S[picker.title].text, "0000FF colour1 COLOUR 1",
        "another swatch: the first keeps its colour, the picker moves to the next")
    -- A mode that doesn't use the swatches, another page, or the window
    -- closing: it closes, keeping the colour.
    C:PickHue(1 / 3)
    C:PickSquare(1, 1)
    ns.Set("colourMode", "class")
    Equal(ns.Get("colour1") .. " " .. tostring(C:IsOpen()) .. " " .. tostring(S[picker].shown), "00FF00 false false",
        "Class, its swatch greyed out: closed, the colour kept")
    ns.Set("colourMode", "gradient")
    page.swatches[1]:Click()
    w:Select("trail")
    Equal(tostring(C:IsOpen()) .. " " .. tostring(S[picker].shown), "false false", "another page: closed")
    Equal(ns.PageParts.Picking(w), false, "and the tour back")
    w:Select("colours")
    page.swatches[1]:Click()
    C:PickHue(0)
    w:Hide()
    Equal(ns.Get("colour1") .. " " .. tostring(C:IsOpen()), "FF0000 false", "the window closed: closed, the colour kept")
    w:Show()
    Equal(S[picker].shown, false, "and not back with the window")
    -- Another profile shown while it's open: closed, and the old colour
    -- never put on the other profile.
    page.swatches[1]:Click()
    C:PickHue(2 / 3)
    ns.NewProfile("Picked")
    Equal(tostring(C:IsOpen()) .. " " .. ns.Get("colour1"), "false FFFFFF", "a new profile: closed, its own colour left alone")
    ns.UseProfile(MINE)
    Equal(ns.Get("colour1"), "0000FF", "the colour kept where it was picked")
    ns.DeleteProfile("Picked")
    -- Renamed while it's open (no other profile, a new name): closed as the
    -- window redraws, the colour kept.
    page.swatches[1]:Click()
    C:PickHue(1 / 3)
    ns.RenameProfile("Renamed")
    w:Refresh()
    Equal(tostring(C:IsOpen()) .. " " .. ns.Get("colour1"), "false 00FF00", "the profile renamed: closed, the colour kept")
    ns.RenameProfile(MINE)
    ns.Set("colour1", "FFFFFF")
    ns.Set("colour3", "0000FF")
    -- The profile menu and the picker would cover each other, so only one
    -- shows: the menu opening closes the picker (the colour kept), and the
    -- picker opening closes the menu.
    page.swatches[1]:Click()
    C:PickHue(2 / 3)
    C:PickSquare(1, 1)
    w.profileButton:Click()
    Equal(tostring(S[w.profilePanel].shown) .. " " .. tostring(C:IsOpen()) .. " " .. tostring(S[picker].shown) .. " "
        .. ns.Get("colour1"), "true false false 0000FF", "the profile menu opened: the picker closed, the colour kept")
    page.swatches[1]:Click()
    Equal(tostring(C:IsOpen()) .. " " .. tostring(S[w.profilePanel].shown), "true false", "the picker opened: the menu closed")
    w.profileButton:Click()
    w.profileButton:Click()
    Equal(tostring(S[w.profilePanel].shown) .. " " .. tostring(C:IsOpen()), "false false", "the menu closed again: neither shows")
    -- Escape is the game's again in a fight, so the notes only offer it out
    -- of one.
    page.swatches[1]:Click()
    Hover(picker.cancel, "OnEnter")
    Equal(Text(), "Put back the colour from before and close the picker. Escape does this too.", "Cancel's note: Escape too")
    Hover(picker.cancel, "OnLeave")
    H.Combat(true)
    Hover(picker.cancel, "OnEnter")
    Equal(Text(), "Put back the colour from before and close the picker.", "in a fight, Cancel only")
    Hover(picker.cancel, "OnLeave")
    Hover(picker, "OnEnter")
    Equal(Text(), "Pick a colour: it shows at once. OK keeps it; Cancel puts back the one before.", "and the picker's own note too")
    Hover(picker, "OnLeave")
    H.Combat(false)
    Hover(picker, "OnEnter")
    Equal(Text(), "Pick a colour: it shows at once. OK keeps it; Cancel puts back the one before. Escape does too.",
        "out of the fight, Escape again")
    Hover(picker, "OnLeave")
    picker.ok:Click()
    ns.Set("colour1", "FFFFFF")
    -- Hex digits typed in the page's own box.
    page.selected = 3
    w:Refresh()
    Type(page.hex, "#ff8000")
    Equal(ns.Get("colour3"), "FF8000", "the page's box: six hex digits, a # and small letters allowed")
    Type(page.hex, "orange")
    Equal(ns.Get("colour3"), "FF8000", "anything else ignored")
    Equal(Text(), "Type six hex digits, like FF8000.", "and the footer says what it takes")
    ns.Set("colour3", "0000FF")
    -- One colour: Colour 1 only. Class and Rainbow use none.
    ns.Set("colourMode", "single")
    Equal(S[page.swatches[1]].shown and not S[page.swatches[2]].shown, true, "One colour: only Colour 1")
    Equal(page.selected, 1, "and the box edits it")
    ns.Set("colourMode", "class")
    Equal(S[page.swatches[1]].enabled, false, "Class: the swatches greyed out")
    Hover(page.swatches[1], "OnEnter")
    True(Text():find("Class uses your class's colour", 1, true) ~= nil, "saying why")
    Hover(page.swatches[1], "OnLeave")
    Equal(page.count.usable, false, "Colours in use only for Gradient")
    Equal(page.speed.usable, false, "speed only for Rainbow and Gradient")
    ns.Set("colourMode", "rainbow")
    Equal(page.speed.usable and page.phases.usable, true, "Rainbow: speed and phases")
    ns.Set("colourMode", "class")
    ns.Set("colourCount", 2)
    -- The game's own colour picker: never touched.
    Equal(S[ColorPickerFrame].touched, nil, "the game's colour picker never touched")
    Equal(H.Problems(), "", "nothing wrong while picking")
end

-- Rings: the custom colours ----------------------------------------------------------------------------------

do
    w:Select("rings")
    local page = w.pages.rings
    local C = ns.ColourPicker
    local picker = C.frame
    page.tab = "ring"
    w:Refresh()
    local field
    for _, obj in ipairs(H.objects) do
        if rawget(obj, "setting") == "ringCustom" and rawget(obj, "input") then field = obj end
    end
    Equal(S[field.swatch].enabled ~= false, true, "the ring: Custom (white) at first, as EraUI's")
    ns.Set("ringColour", "class")
    Equal(S[field.swatch].enabled, false, "its custom colour waits for Custom")
    ns.Set("ringColour", "custom")
    Equal(S[field.swatch].enabled ~= false, true, "Custom: ready")
    Type(field.input, "3366ff")
    Equal(ns.Get("ringCustom"), "3366FF", "typed in")
    field.swatch:Click()
    Equal(tostring(C:Setting()) .. " " .. S[picker.title].text, "ringCustom RING COLOUR", "or picked, in the same picker")
    do
        local area, preview, rect = H.Rect(page, w), H.Rect(w.preview, w), H.Rect(picker, w)
        True(rect.l >= area.l and rect.r <= area.r and rect.b >= area.b and rect.t <= preview.b, "inside the page, under the preview")
    end
    C:PickHue(0)
    C:PickSquare(1, 1)
    Equal(ns.Get("ringCustom"), "FF0000", "showing at once")
    picker.ok:Click()
    Equal(ns.Get("ringCustom"), "FF0000", "OK keeps it")
    Equal(S[field.input].text, "FF0000", "the box shows it")
    field.swatch:Click()
    ns.Set("ringColour", "class")
    Equal(tostring(C:IsOpen()) .. " " .. ns.Get("ringCustom"), "false FF0000", "Class picked meanwhile: closed")
    ns.Set("ringColour", "custom")
    field.swatch:Click()
    page.tab = "look"
    w:Refresh()
    Equal(C:IsOpen(), false, "another tab: closed")
    -- The highlight's own colour, on its tab.
    ns.Set("lookColour", "custom")
    for _, obj in ipairs(H.objects) do
        if rawget(obj, "setting") == "lookCustom" and rawget(obj, "input") then field = obj end
    end
    field.swatch:Click()
    Equal(S[picker.title].text, "HIGHLIGHT TINT", "the highlight's tint, titled so")
    picker.cancel:Click()
    ns.Set("lookColour", "none")
    -- The highlight's Tint row: None first (the game's pointer as it is), then
    -- a gentle wash of a colour; the custom colour waits for Custom.
    do
        local bar
        for _, obj in ipairs(H.objects) do
            if rawget(obj, "setting") == "lookColour" and rawget(obj, "buttons") then bar = obj end
        end
        local labels, notes = {}, {}
        for _, button in ipairs(bar.buttons) do
            labels[#labels + 1] = S[button.label].text
            Hover(button, "OnEnter")
            notes[#notes + 1] = Text()
            Hover(button, "OnLeave")
        end
        Equal(table.concat(labels, "|"), "None|Class|Custom|Trail's", "Tint: None first, then the colours")
        Equal(notes[1], "The game's own pointer as it is, only see-through.", "None's note")
        for i = 2, 4 do True(notes[i]:find("^A gentle wash of ") ~= nil, labels[i] .. ": a gentle wash, its note says") end
        Equal(bar.selected, "none", "None picked at first")
        True(H.Find("Tint") ~= nil and H.Under(H.Find("Tint"), page.panes.look), "its row says Tint")
        Equal(tostring(field.swatch:IsEnabled()) .. " " .. tostring(field.input:IsEnabled()), "false false", "the custom colour waits for Custom")
        bar.buttons[3]:Click()
        Equal(ns.Get("lookColour"), "custom", "Custom picked from the row")
        Equal(tostring(field.swatch:IsEnabled()) .. " " .. tostring(field.input:IsEnabled()), "true true", "then the custom colour is usable")
        bar.buttons[1]:Click()
        Equal(ns.Get("lookColour"), "none", "and None again")
    end
    -- Its parts, laid out: inside it, none on another.
    page.tab = "ring"
    w:Refresh()
    field = nil
    for _, obj in ipairs(H.objects) do
        if rawget(obj, "setting") == "ringCustom" and rawget(obj, "input") then field = obj end
    end
    field.swatch:Click()
    local box, parts, problems = H.Rect(picker, w), {}, {}
    for _, region in ipairs(H.objects) do
        local s = S[region]
        if H.Under(region, picker) and region:IsVisible() and (s.kind == "Button" or s.kind == "EditBox" or s.mouse == true) then
            parts[#parts + 1] = region
        end
    end
    for i, a in ipairs(parts) do
        local r = H.Rect(a, w)
        if r.l < box.l or r.r > box.r or r.t > box.t or r.b < box.b then problems[#problems + 1] = S[a].kind .. " outside" end
        for j = i + 1, #parts do
            if H.Overlap(a, parts[j], w) then problems[#problems + 1] = S[a].kind .. " on " .. S[parts[j]].kind end
        end
    end
    True(#parts >= 14, "its parts found (" .. #parts .. ")")
    Equal(table.concat(problems, "; "), "", "every part inside the picker, none on another")
    for _, part in ipairs(parts) do
        Hover(part, "OnEnter")
        local text = Text()
        True(type(text) == "string" and text ~= ORANGE and text ~= "", "each part has its note: " .. tostring(text))
        Hover(part, "OnLeave")
    end
    picker.cancel:Click()
    Equal(S[ColorPickerFrame].touched, nil, "the game's colour picker never touched")
end

-- Rings: each tab says whether its effect is on; while it's off, the tick
-- that turns it on is lit (opening a tab only shows its settings) ----------------------------------------------

do
    w:Select("rings")
    local page = w.pages.rings
    local function Labels()
        local labels = {}
        for _, button in ipairs(page.tabs.buttons) do labels[#labels + 1] = S[button.label].text end
        return table.concat(labels, "|")
    end
    local function Edge(tick) return table.concat(S[tick.box].border, ",") end
    local accent = ns.Theme:Accent()
    local LIT = table.concat({ accent[1], accent[2], accent[3], 1 }, ",")
    Equal(Labels(), "Cursor ring: Off|Cast ring: Off|While looking: Off", "each tab says its effect is off")
    local tab = page.tabs.buttons[3]
    tab:Click()
    Equal(page.tab .. " " .. tostring(ns.Get("look")), "look false", "opening the While looking tab turns nothing on")
    Equal(S[tab.label].text, "While looking: Off", "and the tab still says it's off")
    local tick = page.mains.look
    Equal(tostring(tick.nudged) .. " " .. Edge(tick), "true " .. LIT, "its tick lit in the accent while it's off")
    Equal(S[tick.box].backdrop[4], .25, "washed in it too")
    Hover(tab, "OnEnter")
    True(Text():find("It's off: tick the box at the top of this tab to turn it on.", 1, true) ~= nil, "the tab's note says how")
    Hover(tab, "OnLeave")
    Hover(tick, "OnEnter")
    Hover(tick, "OnLeave")
    Equal(Edge(tick), LIT, "the mouse passing over leaves it lit")
    tick:Click()
    Equal(ns.Get("look"), true, "the tick turns it on")
    Equal(Labels(), "Cursor ring: Off|Cast ring: Off|While looking: On", "and the tab says so")
    Equal(tostring(tick.nudged) .. " " .. Edge(tick), "false 0.33,0.33,0.33,1", "the tick's light goes")
    Hover(tab, "OnEnter")
    True(Text():find("It's on.", 1, true) ~= nil, "the tab's note: on")
    Hover(tab, "OnLeave")
    tick:Click()
    Equal(tostring(ns.Get("look")) .. " " .. tostring(tick.nudged), "false true", "off again: lit again")
    for _, key in ipairs({ "ring", "cast" }) do
        Equal(page.mains[key].nudged, true, key .. ": its tick lit too while it's off")
    end
    -- The trail's own tick, on its page.
    w:Select("trail")
    Equal(w.trailTick.nudged, true, "the trail's tick lit while it's off")
    ns.Set("trail", true)
    Equal(w.trailTick.nudged, false, "and not once it's on")
    ns.Set("trail", false)
    -- A new accent relights it.
    w:Select("general")
    w.swatches[3]:Click()
    Equal(S[w.trailTick.box].border[1], .17, "a new accent: the lit tick in it")
    w.swatches[1]:Click()
    Equal(H.Problems(), "", "nothing wrong")
end

-- EraUI's own effects: a notice while they're on, read only -------------------------------------------------

do
    local era = { enabled = true, cursorTrail = false, cursorRing = true, cursorCastRing = false, darkMode = true }
    local before = {}
    for key, value in pairs(era) do before[key] = value end
    H.Era(era)
    w:Select("trail")
    local trailNotice = H.Find("EraUI's own cursor trail is on too", true)
    Equal(S[trailNotice].shown, false, "EraUI's trail off: no notice")
    era.cursorTrail = true
    w:Refresh()
    Equal(S[trailNotice].shown, true, "EraUI's trail on: a notice on Trail")
    True(S[trailNotice].text:find("Turn it off in /era", 1, true) ~= nil, "saying where to turn it off")
    w:Select("rings")
    w.pages.rings.tab = "ring"
    w:Refresh()
    Equal(S[H.Find("EraUI's own cursor ring is on too", true)].shown, true, "EraUI's ring on: a notice on Cursor ring")
    Equal(S[H.Find("EraUI's own cast progress ring is on too", true)].shown, false, "its cast ring off: none there")
    era.enabled = false
    w:Refresh()
    Equal(S[H.Find("EraUI's own cursor ring is on too", true)].shown, false, "EraUI turned off: no notices")
    era.enabled = true
    H.Era(era, false)
    w:Refresh()
    Equal(S[H.Find("EraUI's own cursor ring is on too", true)].shown, false,
        "EraUI's settings still there but the game says EraUI isn't loaded: no notices")
    H.Era(era)
    w:Refresh()
    Equal(S[H.Find("EraUI's own cursor ring is on too", true)].shown, true, "loaded again: the notice again")
    H.Era(nil)
    w:Refresh()
    Equal(S[H.Find("EraUI's own cursor ring is on too", true)].shown, false, "no EraUI: no notices")
    local same = true
    era.cursorTrail, era.enabled = false, true
    for key, value in pairs(era) do if before[key] ~= value then same = false end end
    for key in pairs(before) do if era[key] == nil then same = false end end
    True(same, "EraUI's settings never written")
    Equal(ns.FromEraUI.Drawing("look"), false, "EraUI has no highlight of its own")
end

-- Profiles -----------------------------------------------------------------------------------------------

H.character = { guid = "Player-1-0001", name = "Zriel", realm = "Zephras", class = "Druid", classFile = "DRUID" }
H.Environment()
ns = H.Load(nil)
local saved = ForeverEnhancedCursorDB
Equal(ns.ProfileName(), MINE, "first login makes a profile named Name (Class) - Realm")
Equal(saved.chars["Player-1-0001"], MINE, "kept for this character's GUID")
local heard = {}
ns.Listen(function(key) heard[#heard + 1] = tostring(key) end)
ns.Set("trail", true)
Equal(tostring(saved.profiles[MINE].trail) .. " " .. tostring(saved.trail), "true nil", "a profile setting goes into the profile")
Equal(table.concat(heard, ","), "trail", "and whatever draws it hears which")
ns.Set("trail", "yes")
Equal(ns.Get("trail"), true, "a bad value is ignored")
ns.Set("ringCustom", "12345G")
Equal(ns.Get("ringCustom"), "FFFFFF", "not a colour")
ns.Set("accent", "pink")
Equal(ns.Get("accent"), "orange", "not an accent on offer")

-- New, Copy, Rename and Delete, in combat too.
H.Combat(true)
local ok, message = ns.NewProfile("  Raiding  ")
Equal(ok and ns.ProfileName(), "Raiding", "New makes a profile, trimmed, and switches to it, in combat too")
Equal(message, "Made Raiding, and switched to it.", "and says so")
Equal(ns.Get("trail"), false, "with the default settings")
Equal(select(2, ns.NewProfile("Raiding")), "Raiding already exists.", "names are unique")
Equal(select(2, ns.NewProfile("   ")), "Type a profile name first.", "a name is needed")
Equal(select(2, ns.NewProfile("a|b")), "Profile names can't use the | character.", "no escape characters")
Equal(select(2, ns.NewProfile(string.rep("x", 49))), "Profile names can be up to 48 characters.", "names kept short")
Equal((ns.NewProfile(string.rep("\195\169", 48))), true, "48 accented letters fit, as the name boxes allow (96 bytes)")
Equal(select(2, ns.NewProfile(string.rep("\195\169", 49))), "Profile names can be up to 48 characters.", "49 don't")
ok = ns.UseProfile(MINE)
Equal(ok and ns.Get("trail"), true, "switching in combat brings that profile's settings")
ok, message = ns.CopyProfile("Copy")
Equal(tostring(ok) .. " " .. tostring(ns.Get("trail")) .. " " .. message, "true true Copied your settings to Copy, and switched to it.",
    "Copy starts with your settings")
ok = ns.RenameProfile("Solo")
Equal(ok and saved.chars["Player-1-0001"], "Solo", "renaming updates the characters using it")
ok, message = ns.DeleteProfile("Solo")
Equal(ok and ns.ProfileName(), MINE .. " 2", "deleting your own leaves you on a fresh one named after you")
Equal(message, "Deleted Solo. You're now on " .. MINE .. " 2.", "and says so")
H.Combat(false)
Equal(H.Problems(), "", "nothing wrong with profiles in combat")

-- Kept over a reload; anything broken put right.
H.Environment()
ns = H.Load(saved)
Equal(ns.ProfileName(), MINE .. " 2", "each character's profile kept over a reload")
Equal(tostring(ns.firstInstall), "false", "a normal reload")
H.Environment()
ns = H.Load({ accent = "pink", minimap = "yes", minimapAngle = 999, trail = true,
    profiles = { Good = { trail = true, junk = 1, accent = "teal", trailLife = 7, colour3 = "nothex", ringColour = "trail" },
        [5] = {}, Bad = "no" },
    chars = { ["Player-1-0001"] = "Good", ["Player-1-0003"] = 7 }, everyone = "Missing" })
do
    local db = ForeverEnhancedCursorDB
    Equal(tostring(db.accent) .. " " .. tostring(db.minimap) .. " " .. tostring(db.minimapAngle) .. " " .. tostring(db.trail),
        "nil nil nil nil", "bad shared settings, and profile settings left outside a profile, dropped")
    Equal(ns.Get("accent") .. " " .. tostring(ns.Get("minimap")) .. " " .. ns.Get("minimapAngle"), "orange true 255", "so the defaults show")
    local good = db.profiles.Good
    Equal(tostring(good.junk) .. " " .. tostring(good.accent) .. " " .. tostring(good.trailLife) .. " " .. tostring(good.colour3)
        .. " " .. tostring(good.trail) .. " " .. good.ringColour, "nil nil nil nil true trail", "a profile keeps only its own good settings")
    Equal(tostring(db.profiles[5]) .. " " .. tostring(db.profiles.Bad) .. " " .. tostring(db.chars["Player-1-0003"]) .. " "
        .. tostring(db.everyone), "nil nil nil nil", "broken profiles and characters gone")
    Equal(ns.ProfileName(), "Good", "this character's profile kept")
end

-- The profile menu.
SlashCmdList.FECURSOR("")
w = FECursorFrame
ns.NewProfile("Other")
w:Refresh()
Equal(S[w.profileButton.label].text, "|cff8b8d92Profile|r   Other", "the header names the profile in use")
w.profileButton:Click()
Equal(S[w.profilePanel].shown, true, "a click opens the profile list")
local rows = {}
for _, obj in ipairs(H.objects) do
    if rawget(obj, "profile") and rawget(obj, "remove") and S[obj].shown then rows[rawget(obj, "profile")] = obj end
end
True(rows.Good ~= nil and rows.Other ~= nil, "every profile listed")
rows.Good:Click()
Equal(ns.ProfileName(), "Good", "a click on one switches to it")
Equal(S[w.profilePanel].shown, false, "and closes the list")
w.profileButton:Click()
rows.Other.remove:Click()
Equal(S[w.confirm.shade].shown, true, "deleting asks first")
w.confirm.yes:Click()
Equal(ForeverEnhancedCursorDB.profiles.Other, nil, "then deletes")
w.profileButton:Click()
w.profileEveryone:Click()
w.confirm.yes:Click()
Equal(ns.EveryoneProfile(), "Good", "Use on all characters")
Equal(H.Problems(), "", "nothing wrong in the profile menu")

-- The minimap button -------------------------------------------------------------------------------------

do
    local button = FECursorMinimapButton
    True(button ~= nil and S[button].shown, "a minimap button")
    local point = H.Point(button, "CENTER")
    Near(point[4], math.cos(math.rad(255)) * 74, "round the minimap at its own angle (x)", .001)
    Near(point[5], math.sin(math.rad(255)) * 74, "and (y)", .001)
    w:Hide()
    S[button].scripts.OnClick(button, "LeftButton")
    Equal(S[w].shown, true, "a click opens the settings")
    S[button].scripts.OnClick(button, "RightButton")
    Equal(S[FECursorNotes].shown, true, "a right-click shows What's new")
    FECursorNotes.done:Click()
    Equal(H.Problems(), "", "nothing wrong")
    S[button].scripts.OnEnter(button)
    local tip = FECursorMinimapTip
    Equal(#tip.lines .. " " .. S[tip.lines[1]].text .. " | " .. S[tip.lines[2]].text .. " | " .. S[tip.lines[3]].text,
        "3 Click: settings | Right-click: What's new | Drag: move it round the minimap", "its tooltip says what the mouse does")
    S[button].scripts.OnLeave(button)
    H.clock = H.clock + 1
    S[button].scripts.OnDragStart(button)
    H.cursor.x, H.cursor.y = 900, 800 -- straight above the minimap's centre
    S[button].scripts.OnUpdate(button)
    S[button].scripts.OnDragStop(button)
    Equal(ns.Get("minimapAngle"), 90, "dragged round to the top")
    w:Select("general")
    w.minimap:Click()
    Equal(S[button].shown, false, "General turns it off")
    w.minimap:Click()
    Equal(S[button].shown, true, "and on")
end

-- The Discord ---------------------------------------------------------------------------------------------------

w.discord:Click()
local box = FECursorCopyLink
Equal(S[box].shown and S[box.input].text, "https://discord.gg/FVfcDWJncr", "the Discord invite, ready to copy")
box.close:Click()
SlashCmdList.FECURSOR("discord")
Equal(S[box].shown, true, "/fec discord shows it too")
box.close:Click()

-- The public API -----------------------------------------------------------------------------------------------

do
    local api = ForeverEnhancedCursorAPI
    Equal(api.version, 1, "the API's version")
    Equal(api.OwnsCursorEffects(), true, "this addon draws the cursor effects while it's loaded")
    ns.Set("ring", false)
    Equal(api.IsShown("ring"), false, "whether an effect is on")
    ns.Set("ring", true)
    Equal(api.IsShown("ring"), true, "in the profile showing")
    Equal(api.IsShown("nope") or api.IsShown(5) or api.IsShown(nil), false, "anything else: false")
    local wrote = pcall(function() api.version = 2 end)
    Equal(wrote, false, "read-only")
    Equal(getmetatable(api), false, "and sealed")
    ns.Set("ring", false)
end

-- Names: only the addon's own -------------------------------------------------------------------------------------

do
    H.Environment()
    ns = H.Load(nil)
    SlashCmdList.FECURSOR("")
    for _, key in ipairs(ns.PAGE_KEYS) do FECursorFrame:Select(key) end
    FECursorFrame.profileButton:Click()
    SlashCmdList.FECURSOR("discord")
    S[FECursorMinimapButton].scripts.OnEnter(FECursorMinimapButton)
    ns.Set("trail", true)
    ns.Set("ring", true)
    ns.Set("cast", true)
    ns.Set("look", true)
    H.Frame()
    local strangers = {}
    for _, name in ipairs(H.NewGlobals()) do
        if not H.Ours(name) then strangers[#strangers + 1] = name end
    end
    Equal(table.concat(strangers, " "), "", "every global name the addon makes starts with FECursor (or is its saved settings or API)")
    SlashCmdList.FECURSOR("new")
    Equal(table.concat(H.NewGlobals(), " "), "FECursorCopyLink FECursorEscButton FECursorFrame FECursorMinimapButton FECursorMinimapTip "
        .. "FECursorNotes FECursorTour ForeverEnhancedCursorAPI ForeverEnhancedCursorDB SLASH_FECURSOR1 SLASH_FECURSOR2",
        "its frames, commands, settings and API")
    Equal(H.Problems(), "", "nothing wrong anywhere")
end

io.stdout:write("TestWindow: " .. H.checks .. " checks passed\n")
