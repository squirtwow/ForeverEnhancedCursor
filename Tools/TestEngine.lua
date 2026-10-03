-- The effects on screen (Engine.lua, State.lua): nothing runs while nothing
-- is on; each effect starts the frame and stops it; Only in combat; the
-- cursor's place at any scale; looking round freezes the ring and shows the
-- highlight where the cursor will come back, even for an effect that starts
-- meanwhile; the highlight is a see-through copy of the game's pointer, its
-- fingertip on the spot, at its size, opacity and tint, and profiles saved
-- before load as it; no streaks; no texture made as it runs; and nothing of it
-- ever takes the mouse.
-- Run with fengari: Tools/TestEngine.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, Near, True, Fire = H.S, H.Equal, H.Near, H.True, H.Fire

local ns, E

-- A fresh login with these profile settings (nil: a first install).
local function Login(settings)
    H.Environment()
    local saved = nil
    if settings then
        saved = { profiles = { Mine = settings }, chars = { [H.character.guid] = "Mine" } }
    end
    ns = H.Load(saved)
    E = ns.Engine
end

-- The cursor to (x, y) on screen, then a frame.
local function Step(x, y, elapsed)
    H.cursor.x, H.cursor.y = x, y
    H.Frame(elapsed or 1 / 60)
end

local function Running()
    return E.driver ~= nil and S[E.driver].scripts.OnUpdate ~= nil and S[E.driver].shown
end

-- Numbers as text, the same in any Lua ("600", not "600.0").
local function G(...)
    local list = {}
    for i = 1, select("#", ...) do list[i] = ("%g"):format((select(i, ...))) end
    return table.concat(list, " ")
end

local function Anchor()
    local point = H.Point(E.anchor, "CENTER")
    return point[4], point[5]
end

-- Nothing on: nothing made, nothing running ------------------------------------------------

Login(nil)
Equal(E.driver, nil, "a first install: every effect off, no frame made for them")
local updates = 0
for _, frame in ipairs(H.frames) do if S[frame].scripts.OnUpdate then updates = updates + 1 end end
Equal(updates, 0, "and nothing running each frame")
for _, key in ipairs({ "trail", "ring", "cast", "look" }) do Equal(ns.Get(key), false, key .. " off by default") end
Equal(ns.Get("trailCombat") or ns.Get("trailGlow") or ns.Get("trailShrink") or ns.Get("trailAlign") or ns.Get("lookPulse"), false,
    "every extra off too")
Equal(H.Problems(), "", "nothing wrong at load")

-- Each effect alone starts the frame, and turning it off stops it -----------------------------

for _, key in ipairs({ "trail", "ring", "look" }) do
    Login(nil)
    ns.Set(key, true)
    Equal(Running(), true, key .. " on: the frame runs")
    ns.Set(key, false)
    Equal(Running(), false, key .. " off: it stops")
end

Login(nil)
ns.Set("cast", true)
Equal(Running(), false, "cast progress alone waits for a cast, with nothing running")

-- The frames: above the game's windows, never taking the mouse --------------------------------

Login({ trail = true, ring = true, look = true, cast = true })
Equal(S[E.driver].strata .. " " .. S[E.driver].level, "TOOLTIP 98", "above the game's windows")
Equal(S[E.ring].level .. " " .. S[ns.Cast.frame].level .. " " .. S[E.look].level, "100 101 102",
    "the ring, cast progress over it, the highlight over both")
do
    local mouse, enter = {}, {}
    for _, frame in ipairs(H.frames) do
        if frame == E.driver or H.Under(frame, E.driver) then
            if S[frame].mouse ~= false then mouse[#mouse + 1] = S[frame].kind end
            if S[frame].scripts.OnEnter then enter[#enter + 1] = S[frame].kind end
        end
    end
    Equal(table.concat(mouse, ","), "", "every effect frame has the mouse turned off")
    Equal(table.concat(enter, ","), "", "and none reacts to it")
    True(#H.frames > 0 and H.Under(E.ring, E.driver) and H.Under(E.look, E.driver) and H.Under(ns.Cast.frame, E.driver),
        "all on the one frame")
end

-- The cursor's place, at any scale ------------------------------------------------------------

Login({ ring = true })
H.scale = .5
Step(300, 200)
local x, y = Anchor()
Equal(G(x, y), "600 400", "the ring at the cursor, in the interface's own units")
local point = H.Point(E.anchor, "CENTER")
Equal(point[2] == UIParent and point[3], "BOTTOMLEFT", "from the screen's bottom left")
local placed = H.Calls(E.anchor, "SetPoint")
for _ = 1, 30 do Step(300, 200) end
Equal(H.Calls(E.anchor, "SetPoint"), placed, "a still cursor moves nothing")
Step(301, 200)
Equal(H.Calls(E.anchor, "SetPoint"), placed + 1, "a moving one moves it once a frame")
Equal(H.Point(E.ring, "CENTER")[2], E.anchor, "the ring sits on the anchor")
-- The ring art: EraUI's proven cell for the size and thickness.
do
    local coords = S[E.ring.texture].texCoord
    Equal(G(table.unpack(coords)), "0.5 0.625 0 0.125", "a 48 pixel ring 2 thick: cell 4 of the atlas")
    Near(S[E.ring.texture].width, 48 * 128 / 120, "drawn 128/120 of its size, so the ring itself is 48 across")
    ns.Set("ringThickness", 10)
    ns.Set("ringSize", 24)
    coords = S[E.ring.texture].texCoord
    Equal(G(table.unpack(coords)), "0.5 0.625 0.75 0.875", "24 across and 10 thick: cell 52, for 53/128 of its width")
    Equal(S[E.ring].width, 24, "the ring 24 across")
    ns.Set("ringSize", 160)
    ns.Set("ringThickness", 1)
    Equal(G(table.unpack(S[E.ring.texture].texCoord)), "0 0.125 0 0.125", "a thin line keeps the thinnest cell")
end
-- Its colour: white unless picked; class; custom; opacity.
do
    local tint = S[E.ring.texture].tint
    Equal(tint[1] + tint[2] + tint[3] + tint[4], 4, "white and solid at first, as EraUI's")
    ns.Set("ringColour", "class")
    tint = S[E.ring.texture].tint
    Near(tint[2], .49, "Class: Druid orange")
    ns.Set("ringColour", "custom")
    ns.Set("ringCustom", "00FF80")
    tint = S[E.ring.texture].tint
    Near(tint[1] + tint[2], 1, "Custom: the colour picked")
    ns.Set("ringAlpha", 40)
    Near(S[E.ring.texture].tint[4], .4, "Opacity")
end

-- The trail on screen: offsets, and the pool reused --------------------------------------------

Login({ trail = true, trailX = 10, trailY = -5, trailSpacing = 2, trailLife = 1 })
H.scale = 1
Step(100, 100)
for i = 1, 20 do Step(100 + i * 6, 100) end
do
    local t = E.trail
    True(t:Count() > 20, "moving the cursor draws the trail")
    local newest = (t.first + t.count - 2) % t.cap + 1
    Equal(t.y[newest], 95, "the trail moved down by the Y offset")
    True(t.x[newest] > 200 and t.x[newest] <= 230, "and right by the X offset")
    Equal(H.Point(t.tex[newest], "CENTER")[2], UIParent, "the dots placed on the screen itself")
    local made = H.textures
    for i = 1, 600 do Step(220 + (i % 200) * 5, 100 + (i % 37) * 9) end
    Equal(H.textures, made, "600 frames of motion: the same textures, reused")
    Equal(H.Problems(), "", "nothing wrong")
end

-- A warp across the screen draws no streak -----------------------------------------------------

Login({ trail = true, trailSpacing = 2, trailLife = 2, trailMax = 500 })
Step(100, 100)
for i = 1, 10 do Step(100 + i * 5, 100) end
Step(900, 700)
Step(905, 700)
do
    local t, streak = E.trail, false
    for n = 0, t.count - 1 do
        local i = (t.first + n - 1) % t.cap + 1
        if t.x[i] > 160 and t.x[i] < 895 then streak = true end
    end
    Equal(streak, false, "a jump of over half the screen in a frame starts a new line")
end

-- Alt+Z, a loading screen: no streak when the interface comes back -------------------------------

Login({ trail = true, trailSpacing = 2, trailLife = 2, trailMax = 500 })
Step(100, 100)
Step(110, 100)
S[UIParent].shown = false -- Alt+Z: the game stops drawing (and updating) the interface
for _ = 1, 60 do Step(400, 300) end
S[UIParent].shown = true
local count = E.trail:Count()
Step(400, 300)
Step(406, 300)
do
    local t, streak = E.trail, false
    for n = 0, t.count - 1 do
        local i = (t.first + n - 1) % t.cap + 1
        if t.x[i] > 120 and t.x[i] < 399 then streak = true end
    end
    Equal(streak, false, "after a pause the trail starts afresh where the cursor is")
    True(t:Count() >= count, "the old dots fade as normal")
end

-- Only in combat -------------------------------------------------------------------------------

Login({ trail = true, trailCombat = true, trailLife = .5 })
Equal(Running(), false, "Only in combat: out of a fight, nothing runs")
Step(100, 100)
Step(150, 100)
Equal(E.trail:Count(), 0, "and no dots")
H.Combat(true)
Equal(Running(), true, "a fight starts it")
for i = 1, 10 do Step(150 + i * 8, 100) end
True(E.trail:Count() > 0, "dots in the fight")
H.Combat(false)
local left = E.trail:Count()
Step(300, 100)
Step(340, 100)
True(E.trail:Count() <= left, "the fight over: no new dots")
Equal(Running(), true, "while the last ones fade")
for _ = 1, 40 do Step(340, 100) end
Equal(E.trail:Count(), 0, "they fade out")
Equal(Running(), false, "then it stops")

-- A reload in a fight: the game is asked, as no event says so.
H.Environment()
H.affecting = true
ns = H.Load({ profiles = { Mine = { trail = true, trailCombat = true } }, chars = { [H.character.guid] = "Mine" } })
E = ns.Engine
Equal(ns.State.combat, true, "after a reload in a fight, still in it")
Equal(Running(), true, "so the trail draws")
H.affecting = false
-- A secret answer counts as no.
H.Environment()
_G.UnitAffectingCombat = function() return H.SECRET end
ns = H.Load(nil)
Equal(ns.State.combat, false, "a secret answer is no fight")
Equal(H.Problems(), "", "never compared")

-- Looking round: the cursor hides; the ring stays, the highlight marks the spot -----------------

Login({ trail = true, ring = true, look = true, trailSpacing = 2, trailLife = 2, trailMax = 500 })
Step(300, 200)
Step(310, 200)
Step(320, 200)
local before = E.trail:Count()
Equal(S[E.look].shown, false, "no highlight while the cursor shows")
Fire("PLAYER_STARTED_TURNING")
Step(512, 384) -- the game moves the hidden cursor
Step(600, 300)
x, y = Anchor()
Equal(G(x, y), "320 200", "turning: the ring stays where the cursor was")
Equal(S[E.look].shown, true, "and the highlight shows there")
do
    local tip = H.Point(E.look, "TOPLEFT")
    Equal(tip and tip[2] == E.anchor and G(#S[E.look].points, tip[4], tip[5]) .. " " .. tip[3], "1 0 0 CENTER",
        "on the same spot: the see-through pointer's fingertip (its top left corner) on the anchor, and nothing else placing it")
    local spot, ghost = H.Rect(E.anchor, UIParent), H.Rect(E.look, UIParent)
    Equal(G(ghost.l, ghost.t), G((spot.l + spot.r) / 2, (spot.t + spot.b) / 2), "exactly where the cursor was")
end
Equal(E.trail:Count(), before, "no dots while the cursor is hidden")
Fire("PLAYER_STOPPED_TURNING")
Step(320, 200)
Equal(S[E.look].shown, false, "the cursor back: the highlight goes")
Step(330, 200)
do
    local t, streak = E.trail, false
    for n = 0, t.count - 1 do
        local i = (t.first + n - 1) % t.cap + 1
        if t.x[i] > 340 then streak = true end
    end
    Equal(streak, false, "and the trail starts afresh, with nothing drawn to where the hidden cursor went")
end

-- Each button's own tick.
ns.Set("lookRight", false)
Fire("PLAYER_STARTED_TURNING")
Step(330, 200)
Equal(S[E.look].shown, false, "right-button turning ticked off: no highlight for it")
x, y = Anchor()
Equal(G(x, y), "330 200", "though the ring still waits where the cursor was")
Fire("PLAYER_STOPPED_TURNING")
Fire("PLAYER_STARTED_LOOKING")
Step(512, 384)
Equal(S[E.look].shown, true, "moving the camera with the left button: its own tick, on")
ns.Set("lookLeft", false)
Step(512, 384)
Equal(S[E.look].shown, false, "and off")
Fire("PLAYER_STOPPED_LOOKING")
ns.Set("lookRight", true)
ns.Set("lookLeft", true)

-- The game's own mouselook, asked each frame.
H.mouselook = true
Step(700, 500)
Equal(S[E.look].shown, true, "mouselook (asked of the game) shows it too")
H.mouselook = false
Step(330, 200)
Equal(S[E.look].shown, false, "and back")
_G.IsMouselooking = nil
Step(331, 200)
Equal(H.Problems(), "", "a game without IsMouselooking is fine")
-- A loading screen clears a stop the game never sent.
Fire("PLAYER_STARTED_TURNING")
Step(331, 200)
Equal(S[E.look].shown, true, "turning")
Fire("PLAYER_ENTERING_WORLD")
Step(331, 200)
Equal(S[E.look].shown, false, "a loading screen ends it, so a missed stop never sticks")

-- Pulse gently: the highlight brightens and dims.
ns.Set("lookPulse", true)
ns.Set("lookAlpha", 80)
Fire("PLAYER_STARTED_TURNING")
local alphas = {}
for i = 1, 30 do
    Step(331, 200, .05)
    alphas[S[E.look].alpha] = true
end
local low, high = 1, 0
for a in pairs(alphas) do low, high = math.min(low, a), math.max(high, a) end
True(high - low > .2 and high <= .8 + 1e-9 and low >= .8 * .5 - 1e-9, "Pulse gently: between half and all of its opacity")
Fire("PLAYER_STOPPED_TURNING")

-- The highlight is a see-through copy of the game's pointer --------------------------------------

-- Its texture regions (the frame's own), and whether any is ring or dot art.
local function Regions(frame)
    local list, art = {}, false
    for _, obj in ipairs(H.objects) do
        if S[obj].kind == "Texture" and H.Under(obj, frame) then
            list[#list + 1] = obj
            local file = tostring(S[obj].texture)
            if file:find("Rings", 1, true) or file:find("TrailDot", 1, true) or file:find("CastRing", 1, true) then art = true end
        end
    end
    return list, art
end

Login({ look = true })
do
    local look = E.look
    local regions, art = Regions(look)
    Equal(#regions .. " " .. tostring(regions[1] == look.texture) .. " " .. tostring(art), "1 true false",
        "one texture, the pointer: no ring and no dot")
    Equal(rawget(look, "dot"), nil, "no dot left over")
    Equal(S[look.texture].texture, "Interface\\Cursor\\Point", "the game's own pointer, the gauntlet")
    Equal(S[look.texture].points[1] and S[look.texture].points[1][1], "ALL", "filling its frame")
    Equal(G(S[look].width, S[look].height), "32 32", "32 across at first: about the game's own (24 to 32 at the usual sizes)")
    Near(S[look].alpha, .6, "see-through: 60% at first")
    Equal(G(table.unpack(S[look.texture].tint)), "1 1 1 1", "untinted at first: the pointer as the game draws it")
    Equal(ns.Get("lookSize") .. " " .. ns.Get("lookAlpha") .. " " .. ns.Get("lookColour"), "32 60 none", "the defaults")
    ns.Set("lookSize", 60)
    Equal(G(S[look].width, S[look].height), "60 60", "Size: how big the pointer is across, at once")
    ns.Set("lookSize", 128)
    Equal(G(S[look].width, S[look].height), "128 128", "up to 128, as the ring's sizes were")
    ns.Set("lookAlpha", 85)
    Near(S[look].alpha, .85, "Opacity, at once")
    -- A tint is a gentle wash: 60% of the way from white to its colour.
    ns.Set("lookColour", "custom")
    ns.Set("lookCustom", "FF0000")
    local tint = S[look.texture].tint
    Equal(("%.2f %.2f %.2f %g"):format(tint[1], tint[2], tint[3], tint[4]), "1.00 0.40 0.40 1", "Custom red: a gentle red wash")
    ns.Set("lookColour", "class")
    tint = S[look.texture].tint
    Equal(("%.3f %.3f %.3f"):format(tint[1], tint[2], tint[3]), "1.000 0.694 0.424", "Class: a wash of the druid's orange")
    ns.Set("lookColour", "none")
    Equal(G(table.unpack(S[look.texture].tint)), "1 1 1 1", "None: untinted again, whatever the custom colour")
    -- Shown and hidden as before, and nothing made while it shows.
    Step(200, 100)
    local made, tints = H.textures, H.Calls(look.texture, "SetVertexColor")
    Fire("PLAYER_STARTED_TURNING")
    for _ = 1, 30 do Step(512, 384) end
    Equal(S[look].shown, true, "shown while turning")
    Equal(H.textures .. " " .. H.Calls(look.texture, "SetVertexColor"), made .. " " .. tints,
        "nothing made and nothing recoloured each frame while it shows")
    Fire("PLAYER_STOPPED_TURNING")
    Step(200, 100)
    Equal(S[look].shown, false, "and hidden with the cursor back")
end

-- Profiles saved before: every old highlight setting still loads, as the ghost.
Login({ look = true, lookSize = 40, lookAlpha = 90, lookColour = "trail", lookCustom = "00FF00", lookPulse = true })
Equal(H.Problems(), "", "a profile saved with the old ring's settings loads")
Equal(G(S[E.look].width, S[E.look].height) .. " " .. G(S[E.look].alpha), "40 40 0.9", "its size and opacity kept, now the pointer's")
Equal(ns.Get("lookColour") .. " " .. ns.Get("lookCustom"), "trail 00FF00", "and its colour, now a tint")
do
    local tint = S[E.look.texture].tint
    Equal(("%.3f %.3f %.3f"):format(tint[1], tint[2], tint[3]), "1.000 0.694 0.424",
        "the trail's colour (the druid's, as the trail is in Class): washed gently")
end
Login({ look = true })
Equal(G(S[E.look].width, S[E.look].alpha) .. " " .. ns.Get("lookColour"), "32 0.6 none",
    "an old profile on the old defaults (nothing saved): the ghost's defaults")
Login({ look = true, lookSize = 300, lookAlpha = "solid", lookColour = "rainbow", lookCustom = "red" })
Equal(H.Problems(), "", "settings no highlight could hold: no error")
Equal(G(S[E.look].width, S[E.look].alpha) .. " " .. ns.Get("lookColour") .. " " .. ns.Get("lookCustom"), "32 0.6 none FFFFFF",
    "each falls back to its default")
-- The smallest and faintest the old ring could be saved at: kept as they were.
Login({ look = true, lookSize = 16, lookAlpha = 10 })
Equal(H.Problems(), "", "the old ring's smallest size and faintest opacity load")
Equal(G(S[E.look].width, S[E.look].height) .. " " .. G(S[E.look].alpha) .. " " .. ns.Get("lookSize") .. " " .. ns.Get("lookAlpha"),
    "16 16 0.1 16 10", "kept: 16 across and 10%, not the defaults")

-- The highlight on its own: off, it never shows; on alone it keeps the frame running.
Login({ look = true })
Equal(Running(), true, "the highlight alone keeps the frame running, to know the cursor's last place")
Step(200, 100)
Fire("PLAYER_STARTED_TURNING")
Step(512, 384)
x, y = Anchor()
Equal(S[E.look].shown and G(x, y), "200 100", "and marks where it'll come back")
Fire("PLAYER_STOPPED_TURNING")

-- Started while the cursor is hidden: placed where it hid, not where the anchor was left ----------

do
    local function Cast(start)
        H.castInfo = { "Heal", "Heal", 1, start * 1000, start * 1000 + 4000, false, 7, false, 123 }
        H.clock = start
        Fire("UNIT_SPELLCAST_START", "player")
    end
    local function Done()
        H.castInfo = nil
        Fire("UNIT_SPELLCAST_STOP", "player")
        Fire("PLAYER_STOPPED_TURNING")
    end
    -- Cast progress alone: nothing runs until a cast, so nothing knows the spot.
    Login({ cast = true })
    H.cursor.x, H.cursor.y = 700, 500
    Fire("PLAYER_STARTED_TURNING")
    H.cursor.x, H.cursor.y = 512, 384 -- the game moves the hidden cursor
    Cast(200)
    x, y = Anchor()
    Equal(S[ns.Cast.frame].shown and G(x, y), "700 500", "the first cast while turning: its ring where the cursor hid")
    Step(512, 384)
    x, y = Anchor()
    Equal(G(x, y), "700 500", "and it stays there while turning")
    Done()
    -- The last cast ended somewhere else; the mouse moved meanwhile.
    Step(100, 100)
    Cast(210)
    Step(100, 100)
    Done()
    Step(100, 100)
    Equal(Running(), false, "between casts nothing runs")
    H.cursor.x, H.cursor.y = 900, 650
    Fire("PLAYER_STARTED_TURNING")
    H.cursor.x, H.cursor.y = 512, 384
    Cast(220)
    x, y = Anchor()
    Equal(G(x, y), "900 650", "a later cast while turning: not where the last one ended")
    Done()
    -- The game's own mouselook with no event: where the game says the cursor is.
    Step(100, 100)
    H.mouselook = true
    H.cursor.x, H.cursor.y = 640, 480
    Cast(230)
    x, y = Anchor()
    Equal(G(x, y), "640 480", "mouselook with no event: the game's word for where it is")
    H.mouselook = false
    Done()
    -- A profile switched to while turning (Auto-switch, say): its ring and highlight at the spot.
    Login({})
    ns.NewProfile("Rings on")
    ns.Set("ring", true)
    ns.Set("look", true)
    ns.UseProfile("Mine")
    Equal(Running(), false, "your own profile draws nothing")
    H.cursor.x, H.cursor.y = 300, 250
    Fire("PLAYER_STARTED_TURNING")
    H.cursor.x, H.cursor.y = 512, 384
    ns.UseProfile("Rings on")
    x, y = Anchor()
    Equal(S[E.ring].shown and S[E.look].shown and G(x, y), "300 250", "a switch while turning: the ring and highlight where it hid")
    Fire("PLAYER_STOPPED_TURNING")
    Step(310, 250)
    x, y = Anchor()
    Equal(G(x, y), "310 250", "and back with the cursor once it shows")
    Equal(H.Problems(), "", "nothing wrong")
end

-- A new scale or screen size: the trail cleared, everything placed again ------------------------

Login({ trail = true, trailLife = 2 })
Step(100, 100)
for i = 1, 10 do Step(100 + i * 5, 100) end
True(E.trail:Count() > 0, "a trail")
Fire("UI_SCALE_CHANGED")
Equal(E.trail:Count(), 0, "a new interface scale clears it: the dots were placed for the old one")
for i = 1, 10 do Step(100 + i * 5, 100) end
Fire("DISPLAY_SIZE_CHANGED")
Equal(E.trail:Count(), 0, "so does a new screen size")

-- The trail's colours on the ring and highlight, flowing ----------------------------------------

Login({ ring = true, ringColour = "trail", look = true, lookColour = "trail", colourMode = "rainbow", colourSpeed = 50 })
Step(100, 100)
local first = S[E.ring.texture].tint[1] .. S[E.ring.texture].tint[2] .. S[E.ring.texture].tint[3]
local firstLook = table.concat(S[E.look.texture].tint, " ")
for _ = 1, 10 do Step(100, 100, .05) end
local later = S[E.ring.texture].tint[1] .. S[E.ring.texture].tint[2] .. S[E.ring.texture].tint[3]
True(first ~= later, "Trail's colour: the ring flows with the trail's colours")
True(firstLook ~= table.concat(S[E.look.texture].tint, " "), "and the highlight's tint with it")
do
    -- Still a gentle wash as it flows: each part at least 40% (white less 60% of the way).
    local r, g, b = E.trail:HeadColour(GetTime())
    local tint = S[E.look.texture].tint
    Equal(("%.4f %.4f %.4f"):format(tint[1], tint[2], tint[3]),
        ("%.4f %.4f %.4f"):format(1 - .6 * (1 - r), 1 - .6 * (1 - g), 1 - .6 * (1 - b)), "the trail's colour, washed")
    True(math.min(tint[1], tint[2], tint[3]) >= .4 - 1e-9, "never deeper than the wash")
end
-- Only Trail's tint flows: Class and Custom stay their own wash, nothing recoloured each frame.
for _, choice in ipairs({ { "class", "1.000 0.694 0.424" }, { "custom", "1.000 0.400 0.400" } }) do
    ns.Set("lookCustom", "FF0000")
    ns.Set("lookColour", choice[1])
    local calls = H.Calls(E.look.texture, "SetVertexColor")
    for _ = 1, 10 do Step(100, 100, .05) end
    local tint = S[E.look.texture].tint
    Equal(("%.3f %.3f %.3f"):format(tint[1], tint[2], tint[3]) .. " " .. H.Calls(E.look.texture, "SetVertexColor"),
        choice[2] .. " " .. calls, choice[1] .. " while the trail's colours flow: its own wash, still")
end
ns.Set("lookColour", "trail")
Equal(H.Problems(), "", "nothing wrong")
ns.Set("colourSpeed", 0)
local calls = H.Calls(E.ring.texture, "SetVertexColor")
for _ = 1, 10 do Step(100, 100) end
Equal(H.Calls(E.ring.texture, "SetVertexColor"), calls, "still colours: nothing recoloured each frame")

-- A profile switch restyles at once (in combat too) -----------------------------------------------

Login({ ring = true })
ns.CopyProfile("Two")
ns.Set("ring", false)
Equal(Running(), false, "the new profile's ring off")
H.Combat(true)
local ok = ns.UseProfile("Mine")
Equal(ok, true, "profiles switch in combat: the effects are the addon's own")
Equal(Running() and S[E.ring].shown, true, "and its ring is back at once")
H.Combat(false)
Equal(H.Problems(), "", "nothing wrong")

-- The dev probe came out before the first release: "/fec probe look" is any other
-- word now, so it only opens the window, and nothing is kept.

do
    Login({ look = true })
    SlashCmdList.FECURSOR("probe look")
    Equal(tostring(ns.Probe) .. " " .. tostring(ForeverEnhancedCursorDB.probeLook), "nil nil", "no probe, and nothing kept")
    Equal(ns.window ~= nil and ns.window:IsShown(), true, "the window opens, as for any other word")
end

Equal(H.Problems(), "", "nothing wrong")
io.stdout:write("TestEngine: " .. H.checks .. " checks passed\n")
