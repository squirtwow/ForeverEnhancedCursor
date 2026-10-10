-- The marker on the pointer (Engine.lua, Style.lua, MarkerPage.lua, the
-- preview): off by default; each shape its own art, tinted; the class icon is
-- the game's own (UI-Classes-Circles cut by CLASS_ICON_TCOORDS for your
-- class), untinted, and the Dot without the game's table or with a secret
-- class; size, colour and opacity; on the cursor's point; only in combat;
-- nothing made as it runs; profiles, imports and repairs carry it; and the
-- Marker page, every control with a note saying Needs testing, no em dash.
-- Run with fengari: Tools/TestMarker.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, Near, True = H.S, H.Equal, H.Near, H.True

local ns, E
local MEDIA = "Interface\\AddOns\\ForeverEnhancedCursor\\Media\\"
local ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"
local DRUID = H.CLASS_COLOURS.DRUID
local MINE = "Zriel (Druid) - Zephras"

-- A fresh login with these profile settings (nil: a first install).
local function Login(settings, before)
    H.Environment()
    if before then before() end
    local saved = nil
    if settings then
        saved = { profiles = { Mine = settings }, chars = { [H.character.guid] = "Mine" } }
    end
    ns = H.Load(saved)
    E = ns.Engine
end

local function Step(x, y)
    H.cursor.x, H.cursor.y = x, y
    H.Frame(1 / 60)
end

local function Running()
    return E.driver ~= nil and S[E.driver].scripts.OnUpdate ~= nil and S[E.driver].shown
end

-- Numbers as text, the same in any Lua.
local function G(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = ("%g"):format(v) end
    return table.concat(out, " ")
end

local function Tint(marker) return S[marker.texture].tint end

-- Off by default ------------------------------------------------------------------------------

Login(nil)
Equal(ns.Get("marker"), false, "the marker is off on a first install")
Equal(ns.Get("markerCombat"), false, "and Only in combat off")
Equal(ns.Get("markerShape") .. " " .. ns.Get("markerSize") .. " " .. ns.Get("markerAlpha") .. " " .. ns.Get("markerColour")
    .. " " .. ns.Get("markerCustom"), "bullseye 32 100 class FFFFFF", "a bullseye 32 across, solid, in your class's colour")
Equal(E.driver, nil, "nothing made for it while it's off")
Equal(ForeverEnhancedCursorAPI.IsShown("marker"), false, "the API says it's off")
Equal(H.Problems(), "", "nothing wrong at load")

-- On: on the cursor's point, never taking the mouse ---------------------------------------------

Login(nil)
ns.Set("marker", true)
Equal(Running(), true, "on: the frame runs")
Equal(S[E.marker].shown, true, "and the marker shows")
Equal(ForeverEnhancedCursorAPI.IsShown("marker"), true, "the API says it's on")
local centre = H.Point(E.marker, "CENTER")
Equal(centre[2] == E.anchor and centre[3], "CENTER", "centred on the anchor that follows the cursor")
Equal(S[E.marker].mouse, false, "never taking the mouse")
Equal(S[E.marker].level, 99, "under the ring, the cast ring and the highlight")
True(H.Under(E.marker, E.driver), "on the effects' one frame")
H.scale = .5
Step(300, 200)
local anchor = H.Point(E.anchor, "CENTER")
Equal(G({ anchor[4], anchor[5] }), "600 400", "the anchor at the cursor, in the interface's units")
ns.Set("marker", false)
Equal(S[E.marker].shown, false, "off: it hides")
Equal(Running(), false, "and the frame stops")

-- Each shape its own art, tinted ----------------------------------------------------------------

Login({ marker = true })
local FILES = { bullseye = "MarkerBullseye.tga", crosshair = "MarkerCrosshair.tga", dot = "MarkerDot.tga",
    diamond = "MarkerDiamond.tga", star = "MarkerStar.tga" }
for _, shape in ipairs(ns.MARKER_SHAPES) do
    if shape ~= "class" then
        ns.Set("markerShape", shape)
        local texture = S[E.marker.texture]
        Equal(texture.texture, MEDIA .. FILES[shape], shape .. ": its own art")
        Equal(G(texture.texCoord), "0 1 0 1", shape .. ": the whole of it")
        Equal(G(texture.tint), G({ DRUID.r, DRUID.g, DRUID.b, 1 }), shape .. ": in your class's colour")
        Equal(E.marker.tinted, true, shape .. ": tinted")
    end
end
Equal(#ns.MARKER_SHAPES, 6, "six shapes")
Equal(table.concat(ns.MARKER_SHAPES, " "), "bullseye crosshair dot diamond star class", "in the window's order")

-- Size, colour and opacity ------------------------------------------------------------------------

ns.Set("markerShape", "star")
ns.Set("markerSize", 64)
Equal(S[E.marker].width .. " " .. S[E.marker].height, "64 64", "64 across")
ns.Set("markerAlpha", 50)
Equal(Tint(E.marker)[4], .5, "half solid")
ns.Set("markerColour", "custom")
ns.Set("markerCustom", "FF0000")
Equal(G(Tint(E.marker)), "1 0 0 0.5", "its own colour, still half solid")
for _, wrong in ipairs({ 11, 97, 32.5, "big" }) do
    ns.Set("markerSize", wrong)
    Equal(ns.Get("markerSize"), 64, "a size of " .. tostring(wrong) .. " isn't taken")
end
ns.Set("markerSize", 12)
Equal(S[E.marker].width, 12, "as small as 12")
ns.Set("markerSize", 96)
Equal(S[E.marker].width, 96, "as big as 96")
ns.Set("markerColour", "none")
Equal(ns.Get("markerColour"), "custom", "only Class, Custom or the trail's")
ns.Set("markerShape", "heart")
Equal(ns.Get("markerShape"), "star", "only a shape it has")

-- The trail's colour, flowing: tinted each frame, nothing made.
ns.Set("colourMode", "rainbow")
ns.Set("colourSpeed", 50)
ns.Set("markerColour", "trail")
Step(10, 10)
local before = G(Tint(E.marker))
local textures = H.textures
for i = 1, 30 do Step(10 + i, 10) end
True(G(Tint(E.marker)) ~= before, "the trail's colour flows over it")
Equal(Tint(E.marker)[4], .5, "at its own opacity")
Equal(H.textures, textures, "no texture made as it runs")

-- The class icon: the game's own, untinted ------------------------------------------------------

ns.Set("markerShape", "class")
do
    local texture = S[E.marker.texture]
    Equal(texture.texture, ICONS, "the class icon is the game's round class icons")
    Equal(G(texture.texCoord), G(H.CLASS_ICONS.DRUID), "cut to a Druid's by CLASS_ICON_TCOORDS")
    Equal(G(texture.tint), "1 1 1 0.5", "untinted, at its opacity")
    Equal(E.marker.tinted, false, "and says so")
    for i = 1, 10 do Step(50 + i, 10) end
    Equal(G(texture.tint), "1 1 1 0.5", "the trail's flowing colour never tints it")
    ns.Set("markerColour", "class")
    ns.Set("markerColour", "custom")
    Equal(G(texture.tint), "1 1 1 0.5", "nor does any colour picked")
    ns.Set("markerSize", 40)
    Equal(S[E.marker].width, 40, "sized like any shape")
    -- Another class, as the game says it.
    H.character.class, H.character.classFile = "Mage", "MAGE"
    ns.Set("markerSize", 41)
    Equal(G(texture.texCoord), G(H.CLASS_ICONS.MAGE), "a Mage gets a Mage's icon")
    -- A secret class: the Dot in its colour, nothing compared.
    H.character.classFile = H.SECRET
    ns.Set("markerSize", 42)
    Equal(texture.texture, MEDIA .. "MarkerDot.tga", "a secret class: the Dot")
    Equal(E.marker.tinted, true, "tinted then")
    Equal(H.Problems(), "", "and the secret is never compared or indexed")
    H.character.class, H.character.classFile = "Druid", "DRUID"
end

-- Without the game's icon table: the Dot.
Login({ marker = true, markerShape = "class" }, function() _G.CLASS_ICON_TCOORDS = nil end)
Equal(S[E.marker.texture].texture, MEDIA .. "MarkerDot.tga", "no CLASS_ICON_TCOORDS: the Dot")
Equal(G(S[E.marker.texture].tint), G({ DRUID.r, DRUID.g, DRUID.b, 1 }), "in your class's colour")
Equal(H.Problems(), "", "nothing wrong")
-- Nor one for your class.
Login({ marker = true, markerShape = "class" }, function() _G.CLASS_ICON_TCOORDS = { MAGE = { 0, 1, 0, 1 } } end)
Equal(S[E.marker.texture].texture, MEDIA .. "MarkerDot.tga", "no entry for your class: the Dot")

-- Only in combat ------------------------------------------------------------------------------------

Login({ marker = true, markerCombat = true })
Equal(S[E.marker].shown, false, "only in combat: hidden out of a fight")
Equal(Running(), false, "and nothing runs for it")
H.Combat(true)
Equal(S[E.marker].shown, true, "a fight starts: it shows")
Equal(Running(), true, "and the frame runs")
Step(100, 100)
local placed = H.Point(E.anchor, "CENTER")
Equal(G({ placed[4], placed[5] }), "100 100", "following the cursor")
H.Combat(false)
Equal(S[E.marker].shown, false, "the fight ends: it hides")
Equal(Running(), false, "and the frame stops")
ns.Set("markerCombat", false)
Equal(S[E.marker].shown, true, "Only in combat off: it shows out of a fight")
-- After a reload in a fight, it shows at once.
Login({ marker = true, markerCombat = true }, function() H.affecting = true end)
Equal(S[E.marker].shown, true, "a reload in a fight: it shows")

-- Profiles carry it --------------------------------------------------------------------------------

Login(nil)
ns.Set("marker", true)
ns.Set("markerShape", "diamond")
ns.Set("markerSize", 50)
ns.Set("markerColour", "custom")
ns.Set("markerCustom", "00FF00")
ns.Set("markerCombat", true)
local mine = ns.ProfileName()
Equal(mine, MINE, "on my own profile")
True(ns.CopyProfile("Copied"), "a copy made")
Equal(ns.Get("markerShape") .. " " .. ns.Get("markerSize") .. " " .. ns.Get("markerCustom") .. " " .. tostring(ns.Get("markerCombat")),
    "diamond 50 00FF00 true", "a copy keeps every marker setting")
True(ns.NewProfile("Fresh"), "a new profile made")
Equal(ns.Get("marker") or S[E.marker].shown, false, "a new profile: the marker off, and hidden")
Equal(ns.Get("markerShape"), "bullseye", "at its defaults")
True(ns.UseProfile(mine), "back to my own")
Equal(S[E.marker].shown, false, "Only in combat comes back with it: hidden out of a fight")
H.Combat(true)
Equal(S[E.marker].shown, true, "and shown in one")
Equal(S[E.marker.texture].texture .. " " .. S[E.marker].width, MEDIA .. "MarkerDiamond.tga 50", "a diamond, 50 across")
Equal(G(Tint(E.marker)), "0 1 0 1", "in its own green")
H.Combat(false)
Equal(ns.ProfileSetting("Copied", "markerShape"), "diamond", "read from another profile")
for _, key in ipairs({ "marker", "markerCombat", "markerShape", "markerSize", "markerAlpha", "markerColour", "markerCustom" }) do
    True(ns.PROFILE_KEYS[key] and ns.Shareable(key), key .. ": a profile's own, and shared with it")
end
-- An import puts it on the profile showing; left out, back to the default.
True(ns.ReplaceSettings({ marker = true, markerShape = "class", markerAlpha = 40 }), "an import")
Equal(ns.Get("markerShape") .. " " .. ns.Get("markerAlpha") .. " " .. ns.Get("markerSize"), "class 40 32",
    "the import's shape and opacity, the size it leaves out at its default")
Equal(S[E.marker.texture].texture, ICONS, "drawn as the class icon at once")
do
    local changes = ns.ProfileTools.Changes({ marker = true, markerShape = "star", markerAlpha = 40 })
    local lines = {}
    for _, change in ipairs(changes) do lines[#lines + 1] = ns.ProfileTools.Describe(change) end
    Equal(table.concat(lines, " | "), "Marker: shape: Class icon to Star", "an import lists the marker's changes in words")
    Equal(ns.ProfileTools.Describe({ key = "markerAlpha", from = 40, to = 100 }), "Marker: opacity: 40% to 100%", "in percent")
end
-- Saved settings that don't make sense are repaired at load.
Login({ marker = true, markerShape = "heart", markerSize = 500, markerColour = "none", markerCustom = "red", markerAlpha = 5 })
Equal(ns.Get("markerShape") .. " " .. ns.Get("markerSize") .. " " .. ns.Get("markerColour") .. " " .. ns.Get("markerCustom")
    .. " " .. ns.Get("markerAlpha"), "bullseye 32 class FFFFFF 100", "every wrong setting back to its default")
Equal(S[E.marker].shown, true, "and the marker drawn")

-- The Marker page ------------------------------------------------------------------------------------

Login(nil)
SlashCmdList.FECURSOR("")
local w = FECursorFrame
local page = w.pages.marker
True(page ~= nil, "a Marker page")
Equal(S[w.nav.marker.label].text, "Marker", "listed down the left")
w:Select("marker")
Equal(S[page].shown, true, "it shows")
Equal(S[w.preview].shown, true, "with the preview at the top")
Equal(w.preview.focus, "marker", "about the marker")
Equal(S[w.preview.caption].text, "Off: tick Show a marker on the pointer to use it.", "off: the preview says how to turn it on")
Equal(S[w.preview.marker].shown, true, "and shows it dimmed meanwhile")
Near(S[w.preview.marker.texture].tint[4], .35, "dimmed")
Equal(page.main.nudged, true, "its tick lit in the accent while it's off")
Equal(S[page.main.text].text, "Show a marker on the pointer", "the tick's words, as the preview's line names them")
-- Every control has a note, none saying Needs testing (seen working in game
-- 2026-10-10), and none an em dash.
do
    local found, missing, untested, dashed = 0, {}, {}, {}
    for _, obj in ipairs(H.objects) do
        local s = S[obj]
        if H.Under(obj, page) and (s.kind == "Button" or s.kind == "EditBox" or rawget(obj, "track") ~= nil or s.mouse == true) then
            found = found + 1
            local hint = rawget(obj, "hint")
            if type(hint) == "function" then hint = hint(obj) end
            local name = s.kind .. ":" .. tostring(rawget(obj, "setting") or rawget(obj, "key") or "?")
            if type(hint) ~= "string" or hint == "" then
                missing[#missing + 1] = name
            elseif hint:lower():find("needs testing", 1, true) then
                untested[#untested + 1] = name .. " " .. hint
            end
            if type(hint) == "string" and hint:find("\226\128\148", 1, true) then dashed[#dashed + 1] = hint end
        end
        if H.Under(obj, page) and type(s.text) == "string" and s.text:find("\226\128\148", 1, true) then dashed[#dashed + 1] = s.text end
    end
    True(found >= 14, "its controls found (" .. found .. ")")
    Equal(table.concat(missing, " "), "", "every control has a note")
    Equal(table.concat(untested, " | "), "", "no note says Needs testing")
    Equal(table.concat(dashed, " | "), "", "no em dash on the page")
    Equal(w.nav.marker.hint:lower():find("needs testing", 1, true), nil, "nor the list's note")
end
-- Hovering shows each note in the footer.
do
    local shape
    for _, obj in ipairs(H.objects) do
        if rawget(obj, "setting") == "markerShape" then shape = obj end
    end
    local star = shape.buttons[5]
    S[star].scripts.OnEnter(star)
    Equal(S[w.note].text, "A filled five-point star.", "a shape's note in the footer")
    S[star].scripts.OnLeave(star)
    -- Clicking: the tick, a shape, a size.
    page.main:Click()
    Equal(ns.Get("marker"), true, "the tick turns it on")
    Equal(S[E.marker].shown, true, "on screen")
    Equal(S[w.preview.caption].text, "", "the preview's line goes")
    Equal(page.main.nudged, false, "and the tick is no longer lit")
    star:Click()
    Equal(ns.Get("markerShape"), "star", "a shape clicked")
    Equal(S[w.preview.marker.texture].texture, MEDIA .. "MarkerStar.tga", "the preview draws it")
    Equal(S[E.marker.texture].texture, MEDIA .. "MarkerStar.tga", "and so does the real one")
    -- The class icon: its colour doesn't apply, and the controls say so.
    shape.buttons[6]:Click()
    Equal(ns.Get("markerShape"), "class", "Class icon clicked")
    Equal(S[shape.buttons[6].label].text, "Class icon", "labelled Class icon")
    Equal(S[page.colour].alpha, .35, "the colour choice greyed out")
    True(page.colour.buttons[1].hint():find("keeps its own colours", 1, true) ~= nil, "saying why")
    Equal(S[page.field.swatch].enabled, false, "and the custom colour too")
    True(page.field.swatch.hint():find("keeps its own colours", 1, true) ~= nil, "saying why")
    Equal(S[w.preview.marker.texture].texture, ICONS, "the preview shows the class icon")
    Equal(G(S[w.preview.marker.texture].tint), "1 1 1 1", "untinted")
    shape.buttons[1]:Click()
    Equal(S[page.colour].alpha, 1, "another shape: the colour choice back")
    Equal(S[page.field.swatch].enabled, false, "Custom not picked: the custom colour greyed")
    page.colour.buttons[2]:Click()
    Equal(ns.Get("markerColour"), "custom", "Custom picked")
    Equal(S[page.field.swatch].enabled, true, "the custom colour usable")
    page.field.swatch:Click()
    True(ns.ColourPicker:IsOpen() and ns.ColourPicker:Setting() == "markerCustom", "the colour picker opens for it")
    ns.ColourPicker:Close(true)
end
Equal(H.Problems(), "", "nothing wrong on the page")
-- A reset puts it back off.
ns.ResetProfile()
Equal(ns.Get("marker") or S[E.marker].shown, false, "a reset turns it off")

io.stdout:write("TestMarker: " .. H.checks .. " checks passed\n")
