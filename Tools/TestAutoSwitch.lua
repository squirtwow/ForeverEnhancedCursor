-- The Auto-switch rules (AutoSwitch.lua, Core.lua's picks), run against the
-- mock game (Tools/Harness.lua): each rule matches where it should; the
-- order they're tried in; None leaves a rule to the next; the master switch
-- off does nothing; the rules only show a profile, never change anyone's
-- pick; a pick by hand holds until what they pick changes, over a reload
-- too; the account-wide mark is for your own profile; the window holds
-- switches back until it closes; combat starts at once and ends after a
-- second, so a chain pull changes nothing, and that second and the login's
-- hold whatever else comes; a burst of events looks once, after the last;
-- which mount you're on, three ways, the aura way never in a fight; a flight
-- path isn't a mount; talent picks are each character's own; renaming or
-- deleting a profile moves or drops the rules' picks; no dots are made by a
-- switch in a fight; a line in chat only when asked; and the Auto-switch
-- page. The clock and the game's timers move with H.Advance.
-- Run with fengari: Tools/TestAutoSwitch.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True, Fire = H.S, H.Equal, H.True, H.Fire

local GUID = "Player-1-0001"
local ns, A, db
local switches -- profile switches heard since the last login (a whole-profile change)

-- Every look the rules can pick, and the character's own.
local function Saved(extra)
    local saved = {
        notesSeen = "dev", autoSwitch = true,
        profiles = {
            Mine = {}, Other = {}, ["Combat look"] = { trail = true, trailMax = 300, ring = true, cast = true, look = true }, ["Peace look"] = {}, ["Mounted look"] = {},
            ["Horse look"] = {}, ["Ram look"] = {}, ["PvP look"] = {}, ["Dungeon look"] = {}, ["World look"] = {},
            ["Primary look"] = {}, ["Secondary look"] = {},
        },
        chars = { [GUID] = "Mine" },
        rules = {},
        mountRules = {},
        talentRules = {},
    }
    for key, value in pairs(extra or {}) do saved[key] = value end
    return saved
end

-- Logs in with these saved settings, where things stand as game says (H.game),
-- then lets the login's look happen (a second after the loading screen).
local function Login(saved, game, wait)
    H.Environment()
    for key, value in pairs(game or {}) do H.game[key] = value end
    ns = H.Load(saved)
    A, db = ns.AutoSwitch, ForeverEnhancedCursorDB
    switches = 0
    ns.Listen(function(key) if key == nil then switches = switches + 1 end end)
    if wait ~= false then H.Advance(1) end
end

local function Showing() return ns.ProfileName() end
local function Clean(label) Equal(H.Problems(), "", label .. ": nothing wrong") end

-- Login: one look for every rule, a second after the loading screen ---------------------------

Login(Saved({ rules = { world = "World look" } }), nil, false)
Equal(Showing(), "Mine", "before the login's look, your own profile")
H.Advance(.9)
Equal(Showing(), "Mine", "not yet")
H.Advance(.2)
Equal(Showing(), "World look", "a second after the loading screen, the rules decide")
Equal(db.chars[GUID], "Mine", "your own pick unchanged: the rules only show theirs")
Equal(ns.OwnProfile(), "Mine", "and it's still your own")
Equal(ns.Override(), "World look", "the rules' profile showing")
Clean("login")

-- The master switch off: nothing switches.
Login(Saved({ autoSwitch = false, rules = { world = "World look", combat = "Combat look" } }))
Equal(Showing(), "Mine", "off: the rules decide nothing")
H.Combat(true)
Equal(Showing(), "Mine", "not even in a fight")
H.Combat(false)
H.Advance(2)
Equal(switches, 0, "no switch at all")
Clean("master off")

-- Each rule matches where it should ------------------------------------------------------------

-- In combat, at once; out of combat a second after the fight.
Login(Saved({ rules = { combat = "Combat look", peace = "Peace look" } }))
Equal(Showing(), "Peace look", "out of a fight: Not in combat")
H.Combat(true)
Equal(Showing(), "Combat look", "a fight starts: In combat at once")
H.Combat(false)
Equal(Showing(), "Combat look", "the fight ends: it stays a moment")
H.Advance(.5)
Equal(Showing(), "Combat look", "half a second on, still")
H.Advance(.6)
Equal(Showing(), "Peace look", "a second after the fight, Not in combat")
-- A chain pull: back in combat inside the second, so nothing switches.
local before = switches
H.Combat(true)
H.Combat(false)
H.Advance(.5)
H.Combat(true)
H.Advance(3)
Equal(Showing(), "Combat look", "a chain pull: still in combat")
Equal(switches, before + 1, "one switch into the fight, none for the gap between pulls")
H.Combat(false)
H.Advance(1.1)
Equal(Showing(), "Peace look", "then out")
Clean("combat")

-- A reload in a fight: the game says so at the loading screen.
H.Environment()
H.affecting = true
ns = H.Load(Saved({ rules = { combat = "Combat look" } }))
H.Advance(1)
Equal(ns.ProfileName(), "Combat look", "a reload in a fight: In combat")
H.affecting = false

-- Mounted, not on a flight path.
Login(Saved({ rules = { mounted = "Mounted look" } }))
H.game.mounted = true
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
Equal(Showing(), "Mine", "mounting: a moment first")
H.Advance(.3)
Equal(Showing(), "Mounted look", "Mounted")
H.game.mounted = false
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Advance(.3)
Equal(Showing(), "Mine", "off the mount: your own again")
H.game.mounted, H.game.taxi = true, true
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Advance(.3)
Equal(Showing(), "Mine", "a flight path isn't a mount")
Clean("mounted")

-- Where you are: a battleground or arena, a dungeon or raid, the open world.
Login(Saved({ rules = { pvp = "PvP look", dungeon = "Dungeon look", world = "World look" } }))
Equal(Showing(), "World look", "the open world")
for _, case in ipairs({ { "pvp", "PvP look" }, { "arena", "PvP look" }, { "party", "Dungeon look" }, { "raid", "Dungeon look" },
    { "scenario", "Mine" } }) do
    H.game.inside, H.game.kind = true, case[1]
    Fire("PLAYER_ENTERING_WORLD")
    H.Advance(.3)
    Equal(Showing(), case[2], "an instance of the kind " .. case[1])
end
H.game.inside, H.game.kind = false, "none"
Fire("ZONE_CHANGED_NEW_AREA")
H.Advance(.3)
Equal(Showing(), "World look", "out again: the open world")
Clean("place")

-- A burst of events (a loading screen and a new zone) looks once.
do
    H.game.inside, H.game.kind = true, "party"
    local looks, made = H.gameCalls.IsInInstance or 0, switches
    Fire("PLAYER_ENTERING_WORLD")
    H.Advance(.1)
    Fire("ZONE_CHANGED_NEW_AREA")
    Fire("ZONE_CHANGED_NEW_AREA")
    H.Advance(.5)
    Equal(Showing(), "Dungeon look", "the dungeon")
    Equal((H.gameCalls.IsInInstance or 0) - looks, 1, "one look for the burst")
    Equal(switches - made, 1, "one switch")
end

-- Talent groups: each character's own picks.
Login(Saved({ talentRules = { [GUID] = { "Primary look", "Secondary look" } } }), { group = 1 })
Equal(Showing(), "Primary look", "Primary talents")
H.game.group = 2
Fire("ACTIVE_TALENT_GROUP_CHANGED")
H.Advance(.3)
Equal(Showing(), "Secondary look", "Secondary talents after a swap")
do
    local saved = db
    H.character = { guid = "Player-1-0002", name = "Brann", realm = "Zephras", class = "Warrior", classFile = "WARRIOR" }
    Login(saved, { group = 2 })
    Equal(ns.TalentPick(2), nil, "another character has no talent picks of its own yet")
    Equal(Showing(), ns.OwnProfile(), "so its own profile shows")
    True(ns.SetTalentPick(1, "Peace look"), "it picks its own")
    Equal(db.talentRules[GUID][2], "Secondary look", "the first character's picks untouched")
    H.character = { guid = GUID, name = "Zriel", realm = "Zephras", class = "Druid", classFile = "DRUID" }
end
Clean("talents")

-- Which mount (Needs testing) ------------------------------------------------------------------

local MOUNTS = {
    [101] = { name = "Swift Horse", spell = 5001, icon = 132261 },
    [102] = { name = "Ram", spell = 5002, icon = 132248 },
    [103] = { name = "Kodo", spell = 5003, icon = 132243 },
    [104] = { name = "Not yours", spell = 5004, icon = 132243, collected = false },
}
local function Mounts()
    local copy = {}
    for id, m in pairs(MOUNTS) do copy[id] = { name = m.name, spell = m.spell, icon = m.icon, collected = m.collected } end
    return copy
end
local LISTED = { [101] = "Horse look", [102] = "Ram look", [103] = false }

-- The mount list says which is active.
Login(Saved({ rules = { mounted = "Mounted look" }, mountRules = LISTED }), { mounts = Mounts() })
H.game.mounted = true
H.game.mounts[101].active = true
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Advance(.3)
Equal(Showing(), "Horse look", "a mount you list comes before Mounted")
Equal(A.Mount(), 101, "worked out from the mount list")
H.game.mounts[101].active = false
H.game.mounted = false
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Advance(.3)
Equal(Showing(), "Mine", "dismounted")
Equal(A.Mount(), nil, "no mount known")
-- The spell cast to mount.
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 5002)
H.game.fromSpell[5002] = 102
H.game.mounted = true
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Advance(.3)
Equal(Showing(), "Ram look", "worked out from the spell you cast")
H.game.mounted = false
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Advance(.3)
-- A listed mount's aura, out of a fight.
H.clock = H.clock + 60 -- the last spell long ago
H.game.auras[5003] = true
H.game.mounted = true
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Advance(.3)
Equal(A.Mount(), 103, "worked out from a listed mount's aura")
Equal(Showing(), "Mounted look", "a mount with None leaves it to Mounted")
-- Mounted through a reload in a fight: the aura isn't read.
do
    local saved = db
    H.Environment()
    H.game.mounts, H.game.mounted, H.game.auras = Mounts(), true, { [5003] = true }
    H.affecting = true
    ns = H.Load(saved)
    H.lockdown = true
    local reads = H.gameCalls.GetPlayerAuraBySpellID or 0
    H.Advance(1)
    Equal((H.gameCalls.GetPlayerAuraBySpellID or 0) - reads, 0, "in a fight, no aura is read")
    Equal(ns.AutoSwitch.Mount(), nil, "so the mount isn't known")
    Equal(ns.ProfileName(), "Mounted look", "Mounted still decides")
    H.affecting, H.lockdown = false, false
end
-- The mounts you have, for the Mounts tab.
do
    local list = A.Collected()
    local names = {}
    for _, mount in ipairs(list) do names[#names + 1] = mount.name end
    Equal(table.concat(names, ", "), "Kodo, Ram, Swift Horse", "the mounts you have, by name, not ones you don't")
end
-- A mount list the game hadn't filled at login is read again when needed.
Login(Saved(), { mounts = {} })
H.game.mounts = Mounts()
Equal(#A.Collected(), 3, "an empty mount list at login is read again when it's needed")
Clean("mounts")

-- The order the rules are tried in, and None ----------------------------------------------------

local ALL = { combat = "Combat look", mounted = "Mounted look", pvp = "PvP look", dungeon = "Dungeon look", world = "World look",
    peace = "Peace look" }
Login(Saved({ rules = ALL, mountRules = { [101] = "Horse look" }, talentRules = { [GUID] = { "Primary look" } } }),
    { mounts = Mounts(), mounted = true, inside = true, kind = "party" })
H.game.mounts[101].active = true
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Combat(true)
H.Advance(.3)
local order = { Showing() }
H.Combat(false)
H.Advance(1)
order[#order + 1] = Showing()
for _, step in ipairs({ { "mount" }, { "mounted" }, { "dungeon" }, { "peace" } }) do
    if step[1] == "mount" then ns.SetMountPick(101, nil) else ns.SetRulePick(step[1], nil) end
    A:RulesChanged()
    order[#order + 1] = Showing()
end
ns.SetTalentPick(1, nil)
A:RulesChanged()
order[#order + 1] = Showing()
Equal(table.concat(order, " > "), "Combat look > Horse look > Mounted look > Dungeon look > Peace look > Primary look > Mine",
    "In combat, a listed mount, Mounted, the place, Not in combat, talents, then your own; None hands on to the next")
-- The place rules come in their own order too.
ns.SetRulePick("dungeon", "Dungeon look")
H.game.mounted = false
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Advance(.3)
Equal(Showing(), "Dungeon look", "Dungeon or raid before Not in combat")
H.game.kind = "pvp"
Fire("ZONE_CHANGED_NEW_AREA")
H.Advance(.3)
Equal(Showing(), "PvP look", "Battleground or arena")
Equal(A.PRIORITY[1] .. " " .. A.PRIORITY[2] .. " " .. A.PRIORITY[#A.PRIORITY], "combat mount talent2", "the order is one list")
Clean("order")

-- A pick by hand holds; the window holds switches back ----------------------------------------

Login(Saved({ rules = { combat = "Combat look", world = "World look" } }))
Equal(Showing(), "World look", "the open world")
local ok = ns.UseProfile("Other")
Equal(ok and Showing(), "Other", "a pick by hand shows at once")
Equal(db.chars[GUID] .. " " .. tostring(ns.Override()), "Other nil", "it's your own now, and the rules' goes")
True(A.Status().held, "the page says your pick holds")
Fire("ZONE_CHANGED_NEW_AREA")
H.Advance(.3)
Equal(Showing(), "Other", "the same place: your pick holds")
H.Combat(true)
Equal(Showing(), "Combat look", "what the rules pick changes: they decide again")
H.Combat(false)
H.Advance(1.1)
Equal(Showing(), "World look", "and after the fight, the open world's")

-- The window open: switches wait for it to close.
ns.ShowWindow()
H.Combat(true)
Equal(Showing(), "World look", "a fight starts with the window open: no switch under you")
do
    local status = A.Status()
    Equal(tostring(status.waiting) .. " " .. status.name, "true Combat look", "the page says what waits")
end
ns.window:Hide()
Equal(Showing(), "Combat look", "the window closes: the switch goes")
H.Combat(false)
H.Advance(1.1)
Equal(Showing(), "World look", "out of the fight")
-- A fight that starts and ends while it's open: nothing to switch as it closes.
ns.ShowWindow()
local made = switches
H.Combat(true)
H.Combat(false)
ns.window:Hide()
Equal(Showing(), "World look", "a fight over before the window closed: nothing switches")
H.Advance(1.1)
Equal(Showing() .. " " .. (switches - made), "World look 0", "nor a second later")
Clean("held")

-- The waits hold, whatever else comes meanwhile ------------------------------------------------------

-- The second after a fight: an event inside it doesn't cut it short, so a chain pull still keeps it.
Login(Saved({ rules = { combat = "Combat look", peace = "Peace look" } }))
H.Combat(true)
Equal(Showing(), "Combat look", "in a fight")
local made = switches
H.Combat(false)
H.Advance(.1)
Fire("PLAYER_TALENT_UPDATE")
H.Advance(.35)
Equal(Showing(), "Combat look", "an event a moment after the fight: still the fight's, the second not up")
H.Advance(.15)
H.Combat(true)
H.Advance(2)
Equal(switches - made, 0, "the next pull inside the second: no switch at all")
H.Combat(false)
-- Nor does the window closing inside it, with a switch waiting for it.
H.Combat(true)
ns.ShowWindow()
ns.SetRulePick("combat", "Other")
A:RulesChanged()
Equal(Showing() .. " " .. tostring(A.Status().waiting), "Combat look true", "a new pick for In combat waits for the window")
H.Combat(false)
H.Advance(.2)
made = switches
ns.window:Hide()
Equal(Showing(), "Combat look", "the window closing a moment after the fight: still the fight's, the second not up")
H.Advance(.3)
H.Combat(true)
Equal(Showing(), "Other", "the next pull: the new pick for In combat")
Equal(switches - made, 1, "one switch, none through Not in combat between")
H.Combat(false)
H.Advance(1.1)
Equal(Showing(), "Peace look", "then out, a second after the fight")
Clean("combat wait")

-- The login's second: a new zone straight after the loading screen doesn't cut it short.
Login(Saved({ rules = { world = "World look" } }), nil, false)
H.Advance(.05)
Fire("ZONE_CHANGED_NEW_AREA")
H.Advance(.5)
Equal(Showing(), "Mine", "half a second after login, with a new zone: not yet")
H.Advance(.5)
Equal(Showing(), "World look", "a second after login, the rules decide")
Clean("login wait")

-- A later event moves the look later: mounting just after a talent event still gets its moment.
Login(Saved({ rules = { mounted = "Mounted look" }, mountRules = { [101] = "Horse look" } }), { mounts = Mounts() })
Fire("PLAYER_TALENT_UPDATE")
H.Advance(.25)
H.game.mounted = true
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Advance(.1)
H.game.mounts[101].active = true -- the mount list says so a moment after mounting
H.Advance(.3)
Equal(A.Mount(), 101, "the mount worked out once the game has said")
Equal(Showing(), "Horse look", "so the listed mount's profile shows")
-- A look sooner than the mount's moment (a fight, say) leaves the mount to its own look.
H.game.mounts[101].active = false
H.game.mounted = false
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Advance(.3)
H.game.mounted = true
made = switches
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
A:RulesChanged()
Equal(tostring(A.Mount()) .. " " .. Showing(), "nil Mine", "straight after mounting, which mount isn't asked yet, and nothing switches")
H.game.mounts[101].active = true
H.Advance(.3)
Equal(A.Mount() .. " " .. Showing(), "101 Horse look", "a moment later it is, and its profile shows")
Equal(switches - made, 1, "one switch, not through Mounted first")
Clean("mount wait")

-- Two events a moment apart: the look waits for the later one's moment.
Login(Saved({ rules = { dungeon = "Dungeon look", world = "World look" } }))
Fire("PLAYER_TALENT_UPDATE")
H.Advance(.2)
Fire("ZONE_CHANGED_NEW_AREA")
H.Advance(.25)
H.game.inside, H.game.kind = true, "party" -- the game says where you are a moment after the new zone
H.Advance(.1)
Equal(Showing(), "Dungeon look", "the look waited for the new zone's moment, not the talent event's")
Clean("later moment")

-- A look now (a fight starting) leaves a look still waiting in place.
Login(Saved({ rules = { dungeon = "Dungeon look", world = "World look" } }))
Equal(Showing(), "World look", "the open world")
Fire("ZONE_CHANGED_NEW_AREA")
H.Advance(.1)
H.Combat(true)
H.game.inside, H.game.kind = true, "party" -- the game says where you are a moment later
H.Advance(.25)
Equal(Showing(), "Dungeon look", "the new zone's look still came, after the fight's")
H.Combat(false)
H.Advance(1.1)
Clean("look now")

-- A pick by hand holds over a reload; the account-wide mark is for your own ---------------------------

Login(Saved({ rules = { combat = "Combat look", world = "World look" } }))
Equal(Showing(), "World look", "the open world's")
ns.UseProfile("Mine")
Equal(tostring(Showing()) .. " " .. tostring(A.Status().held), "Mine true", "picked by hand: it holds")
do
    local saved = db
    Login(saved)
    Equal(tostring(Showing()) .. " " .. tostring(A.Status().held), "Mine true", "after a reload in the same place it still holds")
    Equal(switches, 0, "with no switch")
    Equal(db.held[GUID].name .. " " .. db.held[GUID].why, "World look world", "kept as what the rules picked then, and why")
    -- Another character's hold follows a rename of the rules' profile, and goes with a delete.
    db.held["Player-1-0002"] = { name = "World look", why = "world" }
    db.held["Player-1-0003"] = { name = "Peace look", why = "peace" }
    ns.UseProfile("World look")
    Equal(db.held[GUID], nil, "picking the rules' own pick by hand: nothing to hold")
    ns.RenameProfile("Wide look")
    Equal(db.held["Player-1-0002"].name, "Wide look", "another character's hold follows a rename")
    ns.DeleteProfile("Peace look")
    Equal(db.held["Player-1-0003"], nil, "and goes with a delete")
    ns.UseProfile("Mine")
    Equal(db.held[GUID].name, "Wide look", "held again, under the new name")
    Login(db)
    Equal(tostring(Showing()) .. " " .. tostring(A.Status().held), "Mine true", "and it still holds")
    H.Combat(true)
    Equal(Showing(), "Combat look", "what the rules pick changes: they decide again")
    Equal(db.held[GUID], nil, "and the hold is let go of")
    H.Combat(false)
    H.Advance(1.1)
    Login(db)
    Equal(Showing(), "Wide look", "so a reload shows the rules' pick")
end
Clean("hold over a reload")

do
    -- Another character uses Other; the rules show World look here.
    Login(Saved({ rules = { world = "World look" }, chars = { [GUID] = "Mine", ["Player-1-0002"] = "Other" } }))
    Equal(Showing() .. " " .. ns.OwnProfile(), "World look Mine", "the rules show theirs, your own is Mine")
    ns.ShowWindow()
    local w = FECursorFrame
    w:Select("profiles")
    Equal(w.accountWide:GetChecked(), false, "Mine isn't account-wide")
    w.accountWide:Click()
    True(S[w.confirm.dialog.title].text:find('"Mine"', 1, true) ~= nil, "the tick asks about your own profile, not the rules'")
    w.confirm.yes:Click()
    Equal(ns.EveryoneProfile() .. " " .. db.chars[GUID] .. " " .. db.chars["Player-1-0002"], "Mine Mine Mine",
        "your own made account-wide, for every character")
    Equal(ns.OwnProfile() .. " " .. tostring(ns.Override()), "Mine World look", "your own pick as it was, the rules' still showing")
    Equal(w.accountWide:GetChecked(), true, "ticked, under your own profile, while the rules' shows")
    w.profileButton:Click()
    Equal(w.profileEveryone:GetChecked(), true, "the header menu's tick too")
    w.profileButton:Click()
    w:Hide()
end
Clean("account-wide own")

-- A mount you're on but haven't listed: the mount rule doesn't match.
Login(Saved({ rules = { mounted = "Mounted look" } }), { mounts = Mounts() })
H.game.mounted = true
H.game.mounts[101].active = true
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Advance(.3)
Equal(A.Mount(), 101, "on a mount the game names")
Equal(A.Matches("mount", A.Now()), false, "not listed: A mount you list doesn't match")
ns.AddMount(101)
Equal(A.Matches("mount", A.Now()), true, "listed (with None): it matches, and hands on to Mounted")
Equal(Showing(), "Mounted look", "Mounted decides")
Clean("unlisted mount")

-- Renaming and deleting move or drop the rules' picks --------------------------------------------

Login(Saved({ rules = { combat = "Combat look", world = "Combat look" }, mountRules = { [101] = "Combat look" },
    talentRules = { [GUID] = { "Combat look" } } }))
Equal(Showing(), "Combat look", "the open world's pick")
ns.RenameProfile("Fight look")
Equal(db.rules.combat .. " " .. db.rules.world .. " " .. db.mountRules[101] .. " " .. db.talentRules[GUID][1],
    "Fight look Fight look Fight look Fight look", "renaming the profile showing moves every pick")
Equal(Showing(), "Fight look", "and it still shows")
local made = switches
ns.DeleteProfile("Fight look")
Equal(tostring(db.rules.combat) .. " " .. tostring(db.rules.world) .. " " .. tostring(db.mountRules[101]) .. " "
    .. tostring(db.talentRules[GUID]), "nil nil false nil", "deleting drops every pick; a listed mount stays, with None")
Equal(Showing(), "Mine", "your own shows again")
Equal(switches - made, 1, "one switch")
Clean("rename")

-- No dots made by a switch in a fight; a line in chat only when asked --------------------------------

Login(Saved({ rules = { combat = "Combat look" } }))
do
    local made = H.textures
    True(ns.Engine.trail ~= nil and ns.Engine.trail.made >= 300, "the combat profile's 300 dots made ahead, at login")
    True(ns.Cast.frame ~= nil and ns.Engine.ring ~= nil and ns.Engine.look ~= nil, "and its rings' frames")
    Equal(ns.Get("ring") or ns.Get("cast") or ns.Get("trail"), false, "while your own profile has them all off")
    H.Combat(true)
    Equal(Showing(), "Combat look", "in a fight, the combat profile")
    Equal(ns.Get("trail"), true, "with its trail")
    Equal(H.textures, made, "no texture made by the switch")
    H.Frame()
    Equal(H.textures, made, "nor as it draws")
    H.Combat(false)
    H.Advance(1.1)
end
Equal(#H.printed, 0, "no line in chat unless asked")
ns.Set("autoSay", true)
H.Combat(true)
Equal(H.printed[1], "|cffffd100Forever Enhanced Cursor:|r In combat, so now on profile Combat look.", "asked: a line for each switch")
H.Combat(false)
H.Advance(1.1)
Equal(H.printed[2], "|cffffd100Forever Enhanced Cursor:|r No rule picks a profile now, so back on your own, Mine.",
    "and back")
H.printed = {}
ns.Set("autoSay", false)
-- Turning the master switch off puts your own back; on, the rules decide.
H.Combat(true)
ns.Set("autoSwitch", false)
A:RulesChanged()
Equal(Showing(), "Mine", "off: your own")
ns.Set("autoSwitch", true)
A:RulesChanged()
Equal(Showing(), "Combat look", "on: the rules decide again")
H.Combat(false)
H.Advance(1.1)
Clean("dots and chat")

-- Junk in the saved rules is dropped ---------------------------------------------------------------

Login(Saved({ rules = { combat = "Missing", world = 5, nonsense = "Mine", peace = "Peace look" },
    mountRules = { [101] = "Missing", [-3] = "Mine", foo = "Mine", [102] = 7, [103] = "Ram look" },
    talentRules = { [GUID] = { "Missing", "Primary look", [3] = "Mine" }, [7] = {} },
    held = { [GUID] = { name = "Missing", why = "world" }, ["Player-1-0002"] = { name = "Mine", why = "nonsense" }, [5] = {},
        ["Player-1-0003"] = "World look", ["Player-1-0004"] = { name = "World look", why = "world" } } }))
do
    local kept = {}
    for guid, hold in pairs(db.held) do kept[#kept + 1] = guid .. "=" .. hold.name end
    Equal(table.concat(kept, " "), "Player-1-0004=World look", "holds: only real rules and real profiles")
end
Equal(tostring(db.rules.combat) .. " " .. tostring(db.rules.world) .. " " .. tostring(db.rules.nonsense) .. " " .. db.rules.peace,
    "nil nil nil Peace look", "rules: only real rules picking real profiles")
local ids = {}
for id, name in pairs(db.mountRules) do ids[#ids + 1] = id .. "=" .. tostring(name) end
table.sort(ids)
Equal(table.concat(ids, " "), "101=false 103=Ram look", "mounts: real IDs; a profile that's gone is None")
Equal(tostring(db.talentRules[GUID][1]) .. " " .. db.talentRules[GUID][2] .. " " .. tostring(db.talentRules[GUID][3]) .. " "
    .. tostring(db.talentRules[7]), "nil Primary look nil nil", "talent groups: only 1 and 2, real profiles")
-- At most twenty mounts.
for id = 200, 230 do ns.AddMount(id) end
Equal(#ns.MountIDs(), 20, "up to twenty mounts listed")
Equal(select(2, ns.AddMount(300)), "Up to 20 mounts can be listed.", "and it says so")
Clean("junk")

-- The Auto-switch page --------------------------------------------------------------------------

Login(Saved({ autoSwitch = false }), { mounts = Mounts() })
ns.ShowWindow()
local w = FECursorFrame
w:Select("autoswitch")
local page = w.pages.autoswitch
Equal(page.tab, "rules", "opening on Rules")
Equal(w.autoSwitchTick:GetChecked(), false, "off at first")
True(S[w.autoStatus].text:find("^Off") ~= nil, "the status line says it's off")
w.autoSwitchTick:Click()
Equal(ns.Get("autoSwitch"), true, "ticked on")
Equal(S[w.autoStatus].text, "No rule picks a profile now, so your own shows: Mine.", "nothing picked yet")
do
    local labels = {}
    for _, row in ipairs(w.autoRows) do labels[#labels + 1] = row.rule end
    Equal(table.concat(labels, " "), table.concat(A.PRIORITY, " "), "a row for each rule, in the order they're tried")
    local numbers = {}
    for _, obj in ipairs(H.objects) do
        local text = S[obj].text
        if S[obj].kind == "FontString" and H.Under(obj, page.panes.rules) and type(text) == "string" and text:match("^%d$") then
            numbers[#numbers + 1] = text
        end
    end
    Equal(table.concat(numbers, ""), "123456788", "numbered in order (both talent groups 8)")
end
-- Picking the open world's profile.
local world = w.autoRows[6]
Equal(world.rule, "world", "row 6: the open world")
world:Click()
local list = page.pickList
Equal(S[list].shown, true, "a click opens the list of profiles")
local rows = list.rows
Equal(S[rows[1].name].text, "None", "None first")
local target
for _, row in ipairs(rows) do if row.item and row.item.key == "World look" then target = row end end
target:Click()
Equal(ns.RulePick("world"), "World look", "picked")
Equal(S[list].shown, false, "the list closes")
Equal(S[world.label].text, "World look", "the row shows it")
Equal(S[world.state].text, "Now", "and says it decides now")
Equal(Showing(), "Mine", "but nothing switches while the window is open")
Equal(S[w.autoStatus].text, "The rules now pick World look (Open world): it switches when this window closes.", "the page says so")
w:Hide()
Equal(Showing(), "World look", "closing the window switches")
ns.ShowWindow()
Equal(S[w.autoStatus].text, "Now: In the open world, so World look.", "the status line")
True(S[w.autoRows[7].state].text == "Matches", "Not in combat matches too, after the open world")
-- The Mounts tab.
w.autoRows[2]:Click()
Equal(page.tab, "mounts", "row 2 opens the Mounts tab")
Equal(S[w.mountStatus].text, "Not mounted.", "not mounted")
Equal(w.addMount.usable == false or S[w.addMount].enabled == false, true, "nothing to add yet")
w.pickMount:Click()
local mountList = w.pickLists[#w.pickLists]
for _, list2 in ipairs(w.pickLists) do if list2.owner == w.pickMount then mountList = list2 end end
Equal(S[mountList].shown, true, "Pick a mount lists the mounts you have")
Equal(S[mountList.rows[1].name].text .. " " .. tostring(S[mountList.rows[1].icon].texture), "Kodo 132243", "by name, with icons")
Equal(w.mountList, mountList, "the page keeps it as window.mountList")
page.tabs.buttons[1]:Click()
Equal(page.tab .. " " .. tostring(S[mountList].shown), "rules false", "the Rules tab: the mount list closes with its tab")
page.tabs.buttons[2]:Click()
Equal(S[mountList].shown, false, "and stays closed back on Mounts")
w.pickMount:Click()
page:Hide() -- as the game hides it with the window, or for another page
Equal(S[mountList].shown, false, "the page going: the mount list too")
page:Show()
w.pickMount:Click()
Equal(S[mountList].shown, true, "open again")
mountList.rows[2]:Click()
Equal(ns.MountListed(102), true, "a mount picked is listed")
Equal(S[w.mountRows[1].name].text, "Ram", "and shown")
H.game.mounted = true
H.game.mounts[101].active = true
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
H.Advance(.3)
w:Refresh()
True(S[w.mountStatus].text:find("Swift Horse", 1, true) ~= nil, "mounted: the page names the mount")
w.addMount:Click()
Equal(ns.MountListed(101), true, "Add the mount you're on")
Equal(S[w.mountRows[1].name].text .. ", " .. S[w.mountRows[2].name].text, "Swift Horse, Ram", "listed in order")
w.mountRows[1].picker:Click()
for _, row in ipairs(list.rows) do if row.item and row.item.key == "Horse look" and S[row].shown then row:Click() end end
Equal(ns.MountPick(101), "Horse look", "its profile picked")
w.mountRows[2].remove:Click()
Equal(ns.MountListed(102), false, "x takes a mount off the list")
w:Hide()
Equal(Showing(), "Horse look", "on the horse, its profile")
-- Twenty mounts, the list scrolled: a row's profiles open from where the row shows now.
ns.ShowWindow()
w:Select("autoswitch")
page.tab = "mounts"
for id = 200, 218 do ns.AddMount(id) end
w:Refresh()
Equal(#ns.MountIDs(), 20, "twenty mounts listed")
do
    local row = w.mountRows[13]
    local scroll = S[S[row].parent].parent
    scroll:SetVerticalScroll(12 * 28)
    row.picker:Click()
    Equal(S[list].shown and S[list].points[1][1], "TOPLEFT", "scrolled so row 13 is at the top of the view: its list opens down")
    row.picker:Click()
    scroll:SetVerticalScroll(0)
    w.mountRows[8].picker:Click()
    Equal(S[list].shown and S[list].points[1][1], "BOTTOMLEFT", "unscrolled, row 8 at the foot of the view: its list opens up")
    w.mountRows[8].picker:Click()
end
w:Hide()
Clean("page")

io.stdout:write("TestAutoSwitch: " .. H.checks .. " checks passed\n")
