-- The trail on its own (Trail.lua, with Style.lua's colours): dots placed
-- every set distance along a smooth path, born as the cursor passed, kept to
-- the most allowed, dying oldest first; no streaks across pauses or jumps;
-- the colours along it; and nothing made once it's set up.
-- Run with fengari: Tools/TestTrail.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, Near, True = H.S, H.Equal, H.Near, H.True

H.Environment()
local ns = {}
for _, file in ipairs({ "Core.lua", "Style.lua", "Trail.lua" }) do assert(loadfile(file))(H.ADDON, ns) end
local Style, Trail = ns.Style, ns.Trail
local atan2 = math.atan2 or math.atan

-- Settings as get(key) reads them: these, else the defaults.
local function Getter(settings)
    return function(key)
        local value = settings[key]
        if value == nil then value = ns.DEFAULTS[key] end
        return value
    end
end

-- A trail with these settings, on a frame of its own, from UIParent's corner.
local parent = CreateFrame("Frame", nil, UIParent)
local function New(settings, extra)
    local t = Trail.New(parent, UIParent)
    local cfg = Style.TrailConfig({}, Getter(settings or {}))
    for key, value in pairs(extra or {}) do cfg[key] = value end
    t:Apply(cfg)
    return t, cfg
end

-- The live dots, oldest first: their slots.
local function Live(t)
    local list = {}
    for n = 0, t.count - 1 do list[#list + 1] = (t.first + n - 1) % t.cap + 1 end
    return list
end

-- Placed: along a straight line, evenly, born in order ------------------------------------

do
    local t = New({ trailSpacing = 4, trailMax = 500, trailLife = 2 })
    local now, x = 0, 0
    for i = 1, 60 do
        now = now + (i % 3 == 0 and 1 / 30 or 1 / 144) -- uneven frames
        x = x + (i % 2 == 0 and 23 or 3) -- uneven moves
        t:Move(x, 100, now)
    end
    local live = Live(t)
    True(#live > 100, "a line of dots")
    local even, rising, onLine = true, true, true
    for k = 2, #live do
        local a, b = live[k - 1], live[k]
        if math.abs((t.x[b] - t.x[a]) - 4) > 1e-6 then even = false end
        if t.born[b] < t.born[a] then rising = false end
        if t.y[b] ~= 100 then onLine = false end
    end
    True(even, "a dot every 4 pixels, however uneven the frames")
    True(rising, "each dot born after the one before it, as the cursor passed")
    True(onLine, "on the cursor's path")
    -- Each dot's texture is where the dot is, from UIParent's bottom left.
    local last = live[#live]
    local point = H.Point(t.tex[last], "CENTER")
    Equal(point[2] == UIParent and point[3], "BOTTOMLEFT", "placed from UIParent's bottom left")
    Near(point[4], t.x[last], "at the dot's x")
    Equal(S[t.tex[last]].shown, true, "shown")
end

-- Smooth: at a low frame rate the path curves rather than turning corners --------------------

do
    -- A circle at 20 frames a second, 30 degrees a frame: joined by straight
    -- lines, each sample would be a 30 degree corner.
    local t = New({ trailSpacing = 2, trailMax = 500, trailLife = 2 })
    local R = 150
    for f = 0, 24 do
        local a = f * math.pi / 6
        t:Move(500 + R * math.cos(a), 400 + R * math.sin(a), f / 20)
    end
    local live, worst, off = Live(t), 0, 0
    for k = 3, #live do
        local i0, i1, i2 = live[k - 2], live[k - 1], live[k]
        local a1 = atan2(t.y[i1] - t.y[i0], t.x[i1] - t.x[i0])
        local a2 = atan2(t.y[i2] - t.y[i1], t.x[i2] - t.x[i1])
        local turn = math.abs((a2 - a1 + math.pi) % (2 * math.pi) - math.pi) * 180 / math.pi
        if turn > worst then worst = turn end
    end
    for _, i in ipairs(live) do
        off = math.max(off, math.abs(math.sqrt((t.x[i] - 500) ^ 2 + (t.y[i] - 400) ^ 2) - R))
    end
    True(worst < 30 / 4, ("no corners: worst turn between dots %.1f degrees, under a quarter of 30"):format(worst))
    True(off < 12, ("close to the true circle: %.1f pixels at most"):format(off))
end

-- The trail reaches the cursor every frame, and ends there once it stops --------------------------

do
    -- A quick flick at low and high frame rates: no gap between the cursor
    -- and the newest dot, however few the frames.
    for _, fps in ipairs({ 20, 30, 60, 144 }) do
        for _, speed in ipairs({ 800, 2000, 4000 }) do
            local t = New({ trailSpacing = 4, trailMax = 500, trailLife = 2 })
            local x = 0
            for f = 0, 12 do
                x = f * speed / fps
                t:Move(x, 0, f / fps)
            end
            local live = Live(t)
            local gap = x - t.x[live[#live]]
            True(gap >= 0 and gap < 4, ("%d fps at %d a second: the newest dot %.2f behind the cursor, under one spacing"):format(fps, speed, gap))
        end
    end
    local t = New({ trailSpacing = 1, trailMax = 500, trailLife = 2 })
    for f = 0, 30 do t:Move(f * 25, 0, f / 60) end -- 1500 pixels a second
    local live = Live(t)
    True(750 - t.x[live[#live]] < 1, "while moving, the trail reaches the cursor")
    Equal(t.born[live[#live]] <= 30 / 60 + 1e-9, true, "each dot born as the cursor got there, not later")
    for f = 31, 33 do t:Move(750, 0, f / 60) end -- the cursor stops
    live = Live(t)
    local head = live[#live]
    True(750 - t.x[head] < 1, ("stopped, the trail ends at the cursor: %.2f pixels short"):format(750 - t.x[head]))
    local count = t.count
    t:Move(750, 0, 34 / 60)
    Equal(t.count, count, "and resting adds no more")
end

-- A sudden stop or turn: never swung past where the cursor went ---------------------------------

do
    local function Furthest(points)
        local t = New({ trailSpacing = 1, trailMax = 500, trailLife = 2 })
        for f, p in ipairs(points) do t:Move(p[1], p[2], f / 30) end
        local most = -math.huge
        for _, i in ipairs(Live(t)) do most = math.max(most, t.x[i]) end
        return most
    end
    local stop = Furthest({ { 0, 0 }, { 100, 0 }, { 200, 0 }, { 300, 0 }, { 400, 0 }, { 500, 0 }, { 502, 0 }, { 502, 0 } })
    True(stop <= 502 + 1e-6, ("fast, then stopped at 502: no dot past it (%.2f)"):format(stop))
    local back = Furthest({ { 0, 0 }, { 100, 0 }, { 200, 0 }, { 300, 0 }, { 400, 0 }, { 500, 0 }, { 495, 0 }, { 490, 0 } })
    True(back <= 500 + 1e-6, ("turned back at 500: no dot past it (%.2f)"):format(back))
    local corner = Furthest({ { 0, 0 }, { 100, 0 }, { 200, 0 }, { 300, 0 }, { 300, 100 }, { 300, 200 }, { 300, 300 } })
    True(corner < 300 + 10, ("a right angle at 300, 100 a frame: only a slight round past it (%.2f)"):format(corner))
end

-- Low frame rates still draw; a real pause still starts a new line ------------------------------

do
    local t = New({ trailSpacing = 2, trailMax = 500, trailLife = 2 })
    for f = 0, 19 do t:Move(f * 50, 0, f / 4.5) end -- 4.5 frames a second
    True(t.count > 300, ("4.5 frames a second draws (%d dots)"):format(t.count))
    local before = t.count
    t:Move(1200, 0, 19 / 4.5 + 2) -- two seconds with no frame
    Equal(t.count, before, "a pause of two seconds at that rate starts a new line")
    t = New({ trailSpacing = 2, trailMax = 500, trailLife = 9 })
    for f = 0, 30 do t:Move(f * 5, 0, f / 60) end
    before = t.count
    t:Move(250, 0, 30 / 60 + .3) -- a hitch of .3 seconds at 60 frames a second
    Equal(t.count, before, "at 60 frames a second, a hitch of .3 seconds starts a new line")
end

-- A hairpin with few dots allowed: the next frame still draws ----------------------------------

do
    local t = New({ trailSpacing = 1, trailMax = 10, trailLife = 2 })
    t:Move(0, 0, 0)
    t:Move(10, 0, 1 / 60)
    t:Move(70, 0, 2 / 60)
    t:Move(10, 0, 3 / 60)
    True(t.carry >= 0, ("the distance carried over is never below 0 (%.2f)"):format(t.carry))
    local placed = H.counts.SetPoint or 0
    t:Move(40, 0, 4 / 60)
    True((H.counts.SetPoint or 0) - placed >= 10, "the frame after a hairpin draws its dots")
end

-- Dot spacing lowered while dots are out: the next dot goes where the last
-- frame ended, never behind it ----------------------------------------------------------------

do
    local t = New({ trailSpacing = 40, trailMax = 500, trailLife = 2 })
    t:Move(0, 100, 0)
    t:Move(70, 100, 1 / 60)
    True(t.carry > 4, ("a long way since the last dot at the wide spacing (%.1f)"):format(t.carry))
    local before = t.count
    t:Apply(Style.TrailConfig({}, Getter({ trailSpacing = 4, trailMax = 500, trailLife = 2 })))
    Equal(t.carry, 4, "Apply carries no more than the new spacing")
    t:Move(78, 100, 2 / 60)
    local live, behind = Live(t), 0
    for k = before + 1, #live do
        if t.x[live[k]] < 70 - 1e-6 then behind = behind + 1 end
    end
    True(#live > before, "new dots at the new spacing")
    Equal(behind, 0, "none behind where the cursor was a frame ago")
    local carried = t.carry
    t:Apply(Style.TrailConfig({}, Getter({ trailSpacing = 30, trailMax = 500, trailLife = 2 })))
    Equal(t.carry, carried, "a wider spacing keeps what's carried")
end

-- The same with what's carried between the new spacing and twice it (40 to
-- 20 with about 30 carried): cut too, so the next dot goes exactly where the
-- last frame ended.
do
    local t = New({ trailSpacing = 40, trailMax = 500, trailLife = 2 })
    t:Move(0, 100, 0)
    t:Move(70, 100, 1 / 60)
    local carried = t.carry
    True(carried > 20 and carried < 40, ("between the new spacing and twice it (%.1f)"):format(carried))
    local before = t.count
    t:Apply(Style.TrailConfig({}, Getter({ trailSpacing = 20, trailMax = 500, trailLife = 2 })))
    Equal(t.carry, 20, "cut to the new spacing")
    t:Move(110, 100, 2 / 60)
    local live, behind, first = Live(t), 0, math.huge
    for k = before + 1, #live do
        local x = t.x[live[k]]
        if x < 70 - 1e-6 then behind = behind + 1 end
        if x < first then first = x end
    end
    Equal(#live - before, 3, "three new dots, 20 apart")
    Equal(behind, 0, "none behind where the cursor was a frame ago")
    Near(first, 70, "the first where the last frame ended")
end

-- The most dots: never more, the oldest reused first -------------------------------------------

do
    local t = New({ trailSpacing = 4, trailMax = 50, trailLife = 9 })
    local made = H.textures
    for i = 1, 400 do t:Move(i * 7, 0, i / 60) end
    Equal(t.count, 50, "never more than the most dots")
    Equal(H.textures, made, "the same 50 textures, reused")
    local live = Live(t)
    True(t.x[live[#live]] > t.x[live[1]], "the newest kept")
    True(t.x[live[1]] > 2500, "the oldest let go")
    local shown = 0
    for i = 1, t.made do if S[t.tex[i]].shown then shown = shown + 1 end end
    Equal(shown, 50, "each live dot shown once")

    -- Dying, oldest first: all last as long.
    local dying = t.born[live[1]]
    t:Tick(dying + 9 + 1e-9)
    True(t.count < 50, "the oldest fade out first")
    Equal(S[t.tex[live[1]]].shown, false, "and their textures hide")
    Equal(S[t.tex[live[#live]]].shown, true, "the newest still show")
    t:Tick(1000)
    Equal(t.count, 0, "all gone in time")
    shown = 0
    for i = 1, t.made do if S[t.tex[i]].shown then shown = shown + 1 end end
    Equal(shown, 0, "every texture hidden")
end

-- No streaks: across a pause, or a jump across the screen ------------------------------------

do
    local t = New({ trailSpacing = 2, trailMax = 500, trailLife = 9 }, { jump = 384 })
    t:Move(0, 0, 0)
    t:Move(10, 0, .016)
    t:Move(20, 0, .032)
    local before = t.count
    t:Move(300, 0, 1.0) -- a second later, far off: OnUpdate paused, or Alt+Z
    Equal(t.count, before, "a pause starts a new line, with nothing drawn across it")
    t:Move(310, 0, 1.016)
    local live = Live(t)
    local gap = false
    for _, i in ipairs(live) do if t.x[i] > 25 and t.x[i] < 299 then gap = true end end
    Equal(gap, false, "no dots between the old line and the new")
    local kept = t.count
    t:Move(1200, 0, 1.032) -- 890 pixels in one frame, more than half of 768
    Equal(t.count, kept, "a jump across the screen breaks the line")
    t:Move(1210, 0, 1.048)
    live = Live(t)
    gap = false
    for _, i in ipairs(live) do if t.x[i] > 320 and t.x[i] < 1199 then gap = true end end
    Equal(gap, false, "with no streak to the new spot")
    True(t.count > kept, "and the old dots kept, to fade as normal")
    local before = t.count
    t:Break()
    t:Move(1220, 0, 1.064)
    Equal(t.count, before, "a break (looking round) starts afresh too, with nothing drawn yet")
end

-- A huge move in one frame places no more dots than the trail holds -------------------------

do
    local t = New({ trailSpacing = 4, trailMax = 50, trailLife = 9 })
    t:Move(0, 0, 0)
    local placed = H.counts.SetPoint or 0
    t:Move(3000, 0, 1 / 60)
    local calls = (H.counts.SetPoint or 0) - placed
    True(calls <= 52, ("a flick of 3000 pixels placed %d dots, not 375"):format(calls))
    local live = Live(t)
    True(#live > 40, "the trail full")
    True(t.x[live[#live]] > 1490, "the dots nearest the cursor kept")
end

-- Settings change: fewer dots, a new size, the dots restyled where they are ------------------

do
    local t, cfg = New({ trailSpacing = 2, trailMax = 100, trailLife = 9 })
    for i = 1, 100 do t:Move(i * 5, 0, i / 60) end
    Equal(t.count, 100, "full")
    local newest = t.x[Live(t)[100]]
    cfg.cap, cfg.width, cfg.height = 30, 20, 6
    t:Apply(cfg)
    Equal(t.count, 30, "fewer dots: the oldest go")
    Equal(t.x[Live(t)[30]], newest, "the newest kept")
    local shown, sized = 0, true
    for i = 1, t.made do
        if S[t.tex[i]].shown then shown = shown + 1 end
        if S[t.tex[i]].width ~= 20 or S[t.tex[i]].height ~= 6 then sized = false end
    end
    Equal(shown, 30, "the rest hidden")
    True(sized, "every dot resized")
    local made = t.made
    cfg.cap = 60
    t:Apply(cfg)
    Equal(t.count .. " " .. t.made, "30 " .. made, "more allowed: the live dots stay, no new textures needed")
    cfg.cap = 0
    t:Apply(cfg)
    Equal(t.count, 0, "none allowed (the trail off): all cleared")
end

-- Opacity and fading: solid at the cursor, gone at the end of its life ------------------------

do
    local t = New({ trailSpacing = 4, trailMax = 100, trailLife = 1, trailAlpha = 80 })
    t:Move(0, 0, 0)
    t:Move(40, 0, .1)
    t:Move(40, 0, .2)
    local live = Live(t)
    t:Tick(t.born[live[#live]])
    Near(S[t.tex[live[#live]]].tint[4], .8, "the newest dot at the trail's opacity")
    t:Tick(t.born[live[1]] + .5)
    Near(S[t.tex[live[1]]].tint[4], .8 * .25, "half way through its life, a quarter of it ((1 - age) squared)")
end

-- Colours along the trail -------------------------------------------------------------------------

local function Colour(t, i) local tint = S[t.tex[i]].tint; return tint[1], tint[2], tint[3] end
-- Three numbers each near the three expected.
local function RGB(label, r, g, b, er, eg, eb)
    Near(r, er, label .. " (red)", .002)
    Near(g, eg, label .. " (green)", .002)
    Near(b, eb, label .. " (blue)", .002)
end

do
    -- Class: Druids' orange, all along.
    local t = New({ trailMax = 100, trailLife = 1 })
    t:Move(0, 0, 0); t:Move(30, 0, .1); t:Move(60, 0, .2)
    t:Tick(.2)
    local live = Live(t)
    local r, g, b = Colour(t, live[1])
    RGB("Class: your class's colour", r, g, b, 1, .49, .04)
    r, g, b = Colour(t, live[#live])
    RGB("all along the trail", r, g, b, 1, .49, .04)
    -- Paladins: the softer pink.
    H.character.classFile = "PALADIN"
    r, g, b = Style.ClassColour()
    RGB("Paladins in their pink", r, g, b, .96, .55, .73)
    H.character.classFile = H.SECRET
    r, g, b = Style.ClassColour()
    RGB("a class the game won't say: white", r, g, b, 1, 1, 1)
    H.character.classFile = "DRUID"
end

do
    -- One colour: Colour 1.
    local lutR, lutG, lutB = {}, {}, {}
    local k1, k2 = Style.TrailColours(Getter({ colourMode = "single", colour1 = "FF8000", colourCount = 5 }), lutR, lutG, lutB)
    RGB("One colour: Colour 1", lutR[1], lutG[1], lutB[1], 1, 128 / 255, 0)
    RGB("all along, whatever Colours in use says", lutR[64], lutG[64], lutB[64], 1, 128 / 255, 0)
    Near(k1, 1, "and still: once along")
    Near(k2, 0, "not moving")

    -- Gradient: Colour 1 at the cursor, the last in use at the end, when still.
    local get = Getter({ colourMode = "gradient", colour1 = "FF0000", colour2 = "00FF00", colour3 = "0000FF", colourCount = 3 })
    k1, k2 = Style.TrailColours(get, lutR, lutG, lutB)
    RGB("Gradient: Colour 1 at the cursor", lutR[1], lutG[1], lutB[1], 1, 0, 0)
    Near(k1, 2 / 3, "running once, not round to the start")
    local tail = math.floor(.9999 * k1 * 64) + 1
    True(lutB[tail] > .9 and lutR[tail] < .05, "the end of the trail in the last colour in use")
    Near(lutG[22], 1 - (lutR[22]), "blending from one to the next", .02)
    -- Repeated, or moving, the colours blend back round so the joins are smooth.
    k1, k2 = Style.TrailColours(Getter({ colourMode = "gradient", colourCount = 3, colourPhases = 2 }), lutR, lutG, lutB)
    Near(k1, 2, "Phases 2: twice along the trail, all the way round each time")
    Near(k2, 0, "still")
    k1, k2 = Style.TrailColours(Getter({ colourMode = "gradient", colourCount = 3, colourSpeed = 50 }), lutR, lutG, lutB)
    Near(k1, 1, "moving: all the way round along the trail")
    Near(k2, 1, "Colour speed 50: a turn of the colours a second")
    -- One colour in use: no movement to see.
    k1, k2 = Style.TrailColours(Getter({ colourMode = "gradient", colourCount = 1, colourSpeed = 50, colourPhases = 4 }), lutR, lutG, lutB)
    Near(k1, 1, "a gradient of one colour: once along")
    Near(k2, 0, "and still")

    -- Rainbow: red at the cursor.
    k1, k2 = Style.TrailColours(Getter({ colourMode = "rainbow" }), lutR, lutG, lutB)
    RGB("Rainbow: red at the cursor", lutR[1], lutG[1], lutB[1], 1, 0, 0)
    Near(k1, 1, "once round along the trail")
    local hue = { Style.Hue(1 / 3) }
    Near(hue[2], 1, "a third of the way round: green")
end

do
    -- Each dot's colour by its age and the time, blended between the
    -- entries either side: moving colours flow out.
    local N = Style.LUT
    local function Blend(t, q)
        q = (q - math.floor(q)) * N
        local c = math.floor(q)
        local f = q - c
        local a, b = c + 1, (c + 1) % N + 1
        return t.lutR[a] + (t.lutR[b] - t.lutR[a]) * f, t.lutG[a] + (t.lutG[b] - t.lutG[a]) * f,
            t.lutB[a] + (t.lutB[b] - t.lutB[a]) * f
    end
    local t = New({ colourMode = "rainbow", colourSpeed = 50, trailMax = 200, trailLife = 1, trailSpacing = 2 })
    for f = 0, 20 do t:Move(f * 10, 0, f / 60) end
    local now = 20 / 60
    t:Tick(now)
    local right = true
    for _, i in ipairs(Live(t)) do
        local age = (now - t.born[i]) / t.life
        local er, eg, eb = Blend(t, age * t.k1 - now * t.k2)
        local r, g, b = Colour(t, i)
        if math.abs(r - er) > 1e-9 or math.abs(g - eg) > 1e-9 or math.abs(b - eb) > 1e-9 then right = false end
    end
    True(right, "each dot's colour from its age and the time, blended")
    local r1, g1, b1 = t:HeadColour(0)
    local r2, g2, b2 = t:HeadColour(.25)
    True(r1 ~= r2 or g1 ~= g2 or b1 ~= b2, "moving: the colour at the cursor changes")
    -- The colour at the cursor now is a quarter second later a quarter of the
    -- way out (k2 / k1 = 1): q = age * k1 - now * k2 stays the same.
    local er, eg, eb = Blend(t, .25 * t.k1 - .25 * t.k2)
    Near(r1 + g1 + b1, er + eg + eb, "and flows out along the trail")
    local still = New({ colourMode = "gradient", colourCount = 3, colour1 = "FF0000" })
    local a = { still:HeadColour(0) }
    local b = { still:HeadColour(7.3) }
    Equal(("%g %g %g | %g %g %g"):format(a[1], a[2], a[3], b[1], b[2], b[3]), "1 0 0 | 1 0 0", "still colours stay put, Colour 1 at the cursor")

    -- Flowing slowly, the colour at the cursor (the ring's, in the trail's
    -- colour) changes a little every moment, never in steps.
    local slow = New({ colourMode = "rainbow", colourSpeed = 2 })
    local pr, pg, pb = slow:HeadColour(0)
    local changed, jump = 0, 0
    for i = 1, 100 do
        local r, g, b = slow:HeadColour(i / 10)
        if r ~= pr or g ~= pg or b ~= pb then changed = changed + 1 end
        jump = math.max(jump, math.abs(r - pr), math.abs(g - pg), math.abs(b - pb))
        pr, pg, pb = r, g, b
    end
    Equal(changed, 100, "Rainbow at speed 2: a new colour every tenth of a second, not every few")
    True(jump < .03, ("and never a step: at most %.3f a tenth of a second"):format(jump))
    -- Along the trail too: two dots close together differ only a little.
    local busy = New({ colourMode = "gradient", colourCount = 10, colourPhases = 1, trailMax = 500, trailLife = 2, trailSpacing = 1 })
    for f = 0, 60 do busy:Move(f * 8, 0, f / 60) end
    busy:Tick(1)
    local live, worst = Live(busy), 0
    for k = 2, #live do
        local ar, ag, ab = Colour(busy, live[k - 1])
        local br, bg, bb = Colour(busy, live[k])
        worst = math.max(worst, math.abs(ar - br), math.abs(ag - bg), math.abs(ab - bb))
    end
    True(worst < .05, ("a gradient of ten colours flows dot to dot (at most %.3f apart)"):format(worst))
end

-- Extras: glow, shrinking, turning along the path ---------------------------------------------

do
    local t, cfg = New({ trailGlow = true, trailShrink = true, trailWidth = 20, trailHeight = 10, trailLife = 1 })
    Equal(S[t.tex[1]].blend, "ADD", "Glow: the dots add their light")
    t:Move(0, 0, 0); t:Move(40, 0, .1); t:Move(40, 0, .2)
    local live = Live(t)
    t:Tick(t.born[live[1]] + .5)
    Near(S[t.tex[live[1]]].width, 10, "Shrink: half way, half the width")
    Near(S[t.tex[live[1]]].height, 5, "and half the height")
    cfg.glow, cfg.shrink = false, false
    t:Apply(cfg)
    Equal(S[t.tex[1]].blend .. " " .. S[t.tex[live[1]]].width, "BLEND 20", "off again: blended, full size")
end

do
    local t, cfg = New({ trailAlign = true, trailWidth = 20, trailHeight = 4, trailLife = 9, trailSpacing = 4 })
    local before = H.counts.SetRotation or 0
    t:Move(0, 0, 0); t:Move(0, 40, .1); t:Move(0, 80, .2)
    local turned = (H.counts.SetRotation or 0) - before
    local live = Live(t)
    Equal(turned, #live, "Turn dots along the path: each dot turned once, as it's placed")
    Near(S[t.tex[live[#live]]].rotation, math.pi / 2, "along the path (straight up)")
    local after = H.counts.SetRotation or 0
    for f = 1, 30 do t:Tick(.2 + f / 60) end
    Equal(H.counts.SetRotation or 0, after, "never again each frame")
    cfg.align = false
    t:Apply(cfg)
    Equal(S[t.tex[live[1]]].rotation, 0, "off again: straight")
end

-- Nothing made once it's set up ----------------------------------------------------------------

do
    local t = New({ trailMax = 300, trailSpacing = 1, trailLife = .5, colourMode = "rainbow", colourSpeed = 80,
        trailShrink = true, trailAlign = true })
    local made = H.textures
    local now = 0
    for f = 1, 2000 do
        now = now + 1 / 60
        local a = f * .07
        t:Move(500 + 300 * math.cos(a), 400 + 200 * math.sin(2 * a), now)
        t:Tick(now)
    end
    Equal(H.textures, made, "2000 frames of a fast, busy trail make no textures")
    True(t.count > 100, "while drawing plenty")
end

Equal(H.Problems(), "", "nothing wrong")
-- Colours by hue, saturation and brightness (the colour picker's) ------------------------------

do
    local HexOf, HexRGB = Style.HexOf, Style.HexRGB
    local function G(...)
        local list = {}
        for i = 1, select("#", ...) do list[i] = ("%g"):format((select(i, ...))) end
        return table.concat(list, " ")
    end
    Equal(HexOf(Style.FromHSV(0, 1, 1)) .. " " .. HexOf(Style.FromHSV(1 / 3, 1, 1)) .. " " .. HexOf(Style.FromHSV(2 / 3, 1, 1)),
        "FF0000 00FF00 0000FF", "red, green and blue round the rainbow")
    Equal(HexOf(Style.FromHSV(.5, .5, 1)) .. " " .. HexOf(Style.FromHSV(.25, 1, .5)) .. " " .. HexOf(Style.FromHSV(.9, 0, .5)),
        "80FFFF 408000 808080", "paler, darker, and grey with no saturation")
    local h, s, v = Style.ToHSV(0, 0, 0)
    Equal(G(h, s, v), "0 0 0", "black: no hue, no saturation")
    h, s, v = Style.ToHSV(1, 1, 1)
    Equal(G(h, s, v), "0 0 1", "white: bright, no saturation")
    h, s, v = Style.ToHSV(0, 1, 1)
    Equal(G(h, s, v), G(.5, 1, 1), "cyan: half way round")
    local same = 0
    for _, hex in ipairs({ "FF4D4D", "FFB84D", "FFF04D", "5CFF6B", "4DD2FF", "6B5CFF", "D35CFF", "FF5CC8", "8C8C8C", "123456",
        "FEDCBA", "000001", "7F0080" }) do
        if HexOf(Style.FromHSV(Style.ToHSV(HexRGB(hex)))) == hex then same = same + 1 end
    end
    Equal(same, 13, "every colour there and back again, the same")
end

io.stdout:write("TestTrail: " .. H.checks .. " checks passed\n")
