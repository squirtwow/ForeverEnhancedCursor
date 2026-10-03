-- Cast progress round the cursor (Cast.lua): fills as you cast, drains as you
-- channel, keeps a channel's pace after pushback, hides at once when a cast is
-- interrupted or fails, falls back to the game's own duration when the times
-- can't be read, never errors, and sits outside the cursor ring.
-- Run with fengari: Tools/TestCast.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, Near, True, Fire = H.S, H.Equal, H.Near, H.True, H.Fire

local ns, C, ring, cd

local function Login(settings)
    H.Environment()
    -- What's new already seen: nothing pops up a moment after login.
    ns = H.Load({ profiles = { Mine = settings }, chars = { [H.character.guid] = "Mine" }, notesSeen = "dev" })
    H.Advance(1) -- the login's own look done, before the clock is set for a test
    C = ns.Cast
    ring = C.frame
    cd = ring and ring.cooldown
end

local function Running()
    local driver = ns.Engine.driver
    return driver ~= nil and S[driver].scripts.OnUpdate ~= nil
end

Login({ cast = true })
True(ring ~= nil, "turned on, the cast ring is made")
Equal(S[ring].shown, false, "and waits, hidden")
Equal(Running(), false, "with nothing running until a cast")
Equal(S[cd].reverse == nil and S[ring].level, 101, "over the cursor ring")
Equal(H.Point(ring, "CENTER")[2], ns.Engine.anchor, "on the cursor's anchor")
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
    Equal(S[C.events].events[event], "player", event .. " heard for the player only")
end

-- A cast fills; a delay stretches it; an interrupt hides it at once.
H.clock = 10
H.cursor.x, H.cursor.y = 300, 200
H.castInfo = { "Heal", "Heal", 1, 10000, 14000, false, 7, false, 123 }
Fire("UNIT_SPELLCAST_START", "player")
Equal(S[ring].shown, true, "a cast shows the ring")
Equal(S[cd].reverse, true, "filling as you cast")
Equal(S[cd].cooldown[1], 10, "from the cast's start, on the game's clock")
Equal(S[cd].cooldown[2], 4, "over its length in seconds")
Equal(Running(), true, "the frame runs while it shows")
local point = H.Point(ns.Engine.anchor, "CENTER")
Equal(("%g %g"):format(point[4], point[5]), "300 200", "at the cursor")
H.clock = 11
H.castInfo[5] = 15000
Fire("UNIT_SPELLCAST_DELAYED", "player")
Equal(S[cd].cooldown[2], 5, "a delay stretches it")
Fire("UNIT_SPELLCAST_INTERRUPTED", "player")
Equal(S[ring].shown, false, "an interrupt hides it at once")
Near(S[cd].swipe[2], .49, "its colour left as it was (no red for an interrupt)")
H.Frame()
Equal(Running(), false, "and the frame stops")

-- A channel drains, and keeps its pace after pushback.
H.castInfo = nil
H.channelInfo = { "Channel", "Channel", 1, 11000, 16000, false, false, 456 }
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
Equal(S[ring].shown, true, "a channel shows it")
Equal(S[cd].reverse, false, "draining as you channel")
H.clock = 12
H.channelInfo[5] = 15000
Fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
Equal(S[cd].cooldown[2], 5, "pushed back, it keeps its first length")
Equal(S[cd].cooldown[1], 10, "ending at the new, earlier end")
-- An update a frame before the new times: once more, next frame.
H.channelInfo = nil
Fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
Equal(S[ring].shown, true, "a channel's update with no times yet keeps it a frame")
Equal(H.delays[#H.delays], 0, "asking again next frame")
H.RunTimers()
Equal(S[ring].shown, false, "still none: it hides")
Equal(#H.timers, 0, "only once")

-- A fresh channel of the same spell starts its pace afresh.
H.channelInfo = { "Channel", "Channel", 1, 20000, 22000, false, false, 456 }
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
Equal(S[cd].cooldown[2], 2, "a new channel, its own length")
Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
Equal(S[ring].shown, true, "stopping waits for the game to say the channel is gone")
H.channelInfo = nil
Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
Equal(S[ring].shown, false, "gone: hidden")

-- Times the game won't show: its own duration drives the swipe.
local SECRET = H.SECRET
H.castInfo = { SECRET, SECRET, SECRET, SECRET, SECRET, false, 7, false, SECRET }
H.duration = { made = "by the game" }
Fire("UNIT_SPELLCAST_START", "player")
Equal(S[cd].durationObject, H.duration, "secret times: the game's duration drives it")
Equal(S[ring].shown, true, "shown")
Equal(H.Problems(), "", "no secret compared, measured or used")
H.duration = nil
Fire("UNIT_SPELLCAST_START", "player")
Equal(S[ring].shown, false, "no duration either: hidden")
H.duration = { made = "by the game" }
H.refuseDuration = true
Fire("UNIT_SPELLCAST_START", "player")
Equal(S[ring].shown, false, "the game refusing it: hidden, no error")
H.refuseDuration = false
-- A name only kept secret.
H.castInfo = { SECRET, "Heal", 1, 10000, 14000, false, 7, false, 123 }
Fire("UNIT_SPELLCAST_START", "player")
Equal(S[cd].durationObject, H.duration, "a secret name: the game's duration too")
H.castInfo = "error"
Fire("UNIT_SPELLCAST_START", "player")
Equal(S[ring].shown, false, "the game erroring: hidden, no error of the addon's")
Equal(H.Problems(), "", "nothing wrong")

-- A cast whose time is up hides at once, without waiting for the event.
H.castInfo = { "Heal", "Heal", 1, 12000, 13000, false, 7, false, 123 }
H.clock = 12
Fire("UNIT_SPELLCAST_START", "player")
Equal(S[ring].shown, true, "shown")
H.Frame(1.01)
Equal(S[ring].shown, false, "its time up: hidden that frame")
H.Frame()
Equal(Running(), false, "and the frame stops")

-- The swipe done: hidden, without the clear running its done script again.
H.castInfo = { "Heal", "Heal", 1, 20000, 23000, false, 7, false, 123 }
H.clock = 20
Fire("UNIT_SPELLCAST_START", "player")
S[cd].scripts.OnCooldownDone(cd)
Equal(S[ring].shown, false, "the swipe done: hidden")
Equal(H.Problems(), "", "its clear doesn't run it round again")

-- Size, colour and opacity.
Login({ cast = true, castSize = 60, castAlpha = 70 })
Equal(S[ring].width, 60, "its size")
Near(S[ring].alpha, .7, "its opacity")
Near(S[cd].swipe[2], .49, "Class colour by default: Druid orange")
Equal(S[cd].swipe[4], 1, "the swipe itself solid")
ns.Set("castColour", "custom")
ns.Set("castCustom", "3366FF")
Near(S[cd].swipe[3], 1, "Custom: the colour picked")
ns.Set("ring", true)
ns.Set("ringSize", 160)
True(S[ring].width * .88 >= 166, "with the cursor ring on, it grows to sit outside it")
ns.Set("ringSize", 24)
Equal(S[ring].width, 60, "a small cursor ring leaves it its own size")
local back = S[ring.back]
Equal(back.tint[1] .. "," .. back.tint[4], "0.08,0.45", "a dark ring behind the progress")
Equal(H.Calls(cd, "SetDrawEdge") .. H.Calls(cd, "SetDrawBling") .. H.Calls(cd, "SetHideCountdownNumbers"), "111",
    "no edge, no flash at the end, no numbers")

-- Off: casts are ignored.
ns.Set("cast", false)
H.castInfo = { "Heal", "Heal", 1, 30000, 33000, false, 7, false, 123 }
H.clock = 30
Fire("UNIT_SPELLCAST_START", "player")
Equal(S[ring].shown, false, "off: no ring for a cast")
ns.Set("ring", false)
H.Frame()
Equal(Running(), false, "and nothing running")

-- The trail's colours on the cast ring, flowing.
Login({ cast = true, castColour = "trail", colourMode = "rainbow", colourSpeed = 50 })
H.castInfo = { "Heal", "Heal", 1, 100000, 110000, false, 7, false, 123 }
Fire("UNIT_SPELLCAST_START", "player")
local first = S[cd].swipe[1] .. S[cd].swipe[2] .. S[cd].swipe[3]
H.Frame(.2)
H.Frame(.2)
True(S[cd].swipe[1] .. S[cd].swipe[2] .. S[cd].swipe[3] ~= first, "Trail's colour: the cast ring flows with the trail")

-- Turned on mid-cast: the cast going now shows at once, not only the next one.
Login({})
H.clock = 40
H.castInfo = { "Heal", "Heal", 1, 40000, 44000, false, 7, false, 123 }
Fire("UNIT_SPELLCAST_START", "player")
Equal(C.frame, nil, "off: a cast shows nothing")
ns.Set("cast", true)
Equal(S[C.frame].shown, true, "ticked on mid-cast: the cast going now shows")
Equal(("%g %g"):format(S[C.frame.cooldown].cooldown[1], S[C.frame.cooldown].cooldown[2]), "40 4", "from its own start, over its length")
Equal(Running(), true, "and the frame runs for it")
ns.Set("cast", false)
Equal(S[C.frame].shown, false, "off again: hidden")
ns.Set("cast", true)
Equal(S[C.frame].shown, true, "and on again, still that cast")
-- A profile with it on, switched to mid-cast (a rule in a fight, say).
ns.Set("cast", false)
ns.NewProfile("Fight")
ns.Set("cast", true)
ns.UseProfile("Mine")
Equal(S[C.frame].shown, false, "your own profile: no cast ring")
ns.SetOverride("Fight")
Equal(S[C.frame].shown, true, "switched to one with it on: the cast going now shows")
ns.SetOverride(nil)
H.castInfo = nil
Fire("UNIT_SPELLCAST_STOP", "player")
-- With no cast going, turning it on shows nothing.
ns.Set("cast", true)
Equal(S[C.frame].shown, false, "no cast going: nothing to show")
Equal(H.Problems(), "", "nothing wrong")

-- Not turned on: nothing made for it.
Login({})
Equal(C.frame, nil, "off at login: no cast ring made")
Fire("UNIT_SPELLCAST_START", "player")
Equal(C.frame, nil, "nor for a cast")
Equal(H.Problems(), "", "nothing wrong")

io.stdout:write("TestCast: " .. H.checks .. " checks passed\n")
