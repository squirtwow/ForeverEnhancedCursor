-- Auto-switch: rules that show another profile for a while,
-- in a set order, the first that matches and has a profile picked deciding:
--
--   1 In combat
--   2 A mount you list (Needs testing)
--   3 Mounted (not on a flight path)
--   4 Battleground or arena
--   5 Dungeon or raid
--   6 Open world
--   7 Not in combat
--   8 Primary or Secondary talents (each character's own picks)
--     Otherwise: your own profile
--
-- What the rules pick is shown in place of your own profile (Core.lua's
-- override): your pick, and every character's, stay as they are. How it
-- stays calm:
-- - Only a change counts: a switch happens only when what the rules pick
--   (and why) is new.
-- - A profile picked by hand holds until what the rules pick changes.
-- - While the /fec window is open, switches wait until it closes, so a
--   profile never changes under you while you edit it.
-- - Each event asks for one look a moment later (combat starting at once,
--   combat ending after a second so a chain pull changes nothing, a new zone,
--   mount or talent group after a moment, a login a second after the loading
--   screen); a burst of events looks once, after the last one's moment.
--   The waits after a fight and after the login hold however the look comes
--   (another event, the window closing), and which mount you're on is only
--   asked once the game has had its moment to say.
-- - The effects are the addon's own textures, so switching in a fight is
--   safe; the dots a rule's profile needs are made ahead.
-- Every game call is asked carefully: an error, a secret or a call this game
-- doesn't have answers nothing.
local _, ns = ...
local State = ns.State

local A = {}
ns.AutoSwitch = A

A.PRIORITY = { "combat", "mount", "mounted", "pvp", "dungeon", "world", "peace", "talent1", "talent2" }
A.NAMES = {
    combat = "In combat", mount = "A mount you list", mounted = "Mounted", pvp = "Battleground or arena",
    dungeon = "Dungeon or raid", world = "Open world", peace = "Not in combat", talent1 = "Primary talents",
    talent2 = "Secondary talents",
}
-- Why, in a sentence: "Mounted, so now on profile X."
local REASONS = {
    combat = "In combat", mounted = "Mounted", pvp = "In a battleground or arena", dungeon = "In a dungeon or raid",
    world = "In the open world", peace = "Out of combat", talent1 = "Primary talents", talent2 = "Secondary talents",
}
A.DELAYS = { combatStart = 0, combatEnd = 1, change = .3, login = 1 }
A.SPELL_WINDOW = 10 -- seconds: the spell cast to mount, if it came this soon before

local function Secret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- One of the game's answers: true and the answer; false when it won't say
-- (an error, or a secret, which is never compared, indexed or kept). A call
-- this game doesn't have answers nothing (true, nil).
local function Ask(fn, ...)
    if type(fn) ~= "function" then return true, nil end
    local ok, value = pcall(fn, ...)
    if not ok or Secret(value) then return false end
    return true, value
end
A.Ask = Ask

-- Reading the game --------------------------------------------------------------------------

-- On a mount (a flight path doesn't count).
function A.Mounted()
    local ok, mounted = Ask(_G.IsMounted)
    if not ok or mounted ~= true then return false end
    local _, taxi = Ask(_G.UnitOnTaxi, "player")
    return taxi ~= true
end

-- Where you are: "world", "dungeon" (a dungeon or raid), "pvp" (a
-- battleground or arena), "other" (another kind of instance), or nil while
-- the game won't say.
function A.Place()
    local fn = _G.IsInInstance
    if type(fn) ~= "function" then return nil end
    local ok, inside, kind = pcall(fn)
    if not ok or Secret(inside) or Secret(kind) then return nil end
    if inside ~= true or kind == "none" then return "world" end
    if kind == "pvp" or kind == "arena" then return "pvp" end
    if kind == "party" or kind == "raid" then return "dungeon" end
    return "other"
end

-- The talent group you're in, 1 or 2, or nil while the game won't say.
function A.ActiveGroup()
    local info = _G.C_SpecializationInfo
    local get = type(info) == "table" and info.GetActiveSpecGroup or _G.GetActiveTalentGroup
    if type(get) ~= "function" then return nil end
    local ok, group = pcall(get)
    if not ok or Secret(group) or (group ~= 1 and group ~= 2) then return nil end
    return group
end

-- Whether dual spec is learned, or nil while the game won't say.
function A.DualSpec()
    local ok, groups = Ask(_G.GetNumSpecGroups)
    if not ok or type(groups) ~= "number" then return nil end
    return groups > 1
end

-- Mounts (Needs testing) ----------------------------------------------------------------------

local function Journal()
    local J = _G.C_MountJournal
    if type(J) == "table" then return J end
end

local function Plain(value, kind)
    if Secret(value) or type(value) ~= kind then return nil end
    return value
end

-- A mount's name, spell, icon, whether you're on it and whether you have
-- it, from the game's mount list; nil for anything it won't say.
function A.MountInfo(id)
    local J = Journal()
    if not J or type(J.GetMountInfoByID) ~= "function" or type(id) ~= "number" then return nil end
    local ok, name, spellID, icon, active, _, _, _, _, _, _, collected = pcall(J.GetMountInfoByID, id)
    if not ok then return nil end
    return Plain(name, "string"), Plain(spellID, "number"), Plain(icon, "number") or Plain(icon, "string"),
        Plain(active, "boolean"), Plain(collected, "boolean")
end

local collected = {} -- the mounts you have, by ID: read at login and as one is learned
local mounted = false
local mountID -- the mount you're on, worked out as you mount and kept till you get off
local mountStale = true -- worked out again at the next look
local mountedAt -- when you last mounted, got off or came out of a loading screen
local lastSpell, lastSpellAt -- your last spell cast, and when

local function ReadJournal()
    collected = {}
    local J = Journal()
    if not J then return end
    local ok, ids = Ask(J.GetMountIDs)
    if not ok or type(ids) ~= "table" then return end
    for _, id in ipairs(ids) do
        if type(id) == "number" and not Secret(id) then
            local _, _, _, _, have = A.MountInfo(id)
            if have == true then collected[#collected + 1] = id end
        end
    end
end

-- The mounts you have, for the Mounts tab: { id, name, icon }, by name. If
-- the game's list was still empty at login, it's read again now.
function A.Collected()
    if #collected == 0 then ReadJournal() end
    local list = {}
    for _, id in ipairs(collected) do
        local name, _, icon = A.MountInfo(id)
        if name then list[#list + 1] = { id = id, name = name, icon = icon } end
    end
    table.sort(list, function(a, b)
        if a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end
        return a.id < b.id
    end)
    return list
end

-- The mount you're on: the one the game's mount list says is active; else
-- the one the spell you just cast summons; else, out of a fight, a listed
-- mount whose aura you have.
local function FindMount()
    local J = Journal()
    if not J then return nil end
    if #collected == 0 then ReadJournal() end
    for _, id in ipairs(collected) do
        local _, _, _, active = A.MountInfo(id)
        if active == true then return id end
    end
    if lastSpell and lastSpellAt and GetTime() - lastSpellAt <= A.SPELL_WINDOW then
        local ok, id = Ask(J.GetMountFromSpell, lastSpell)
        if ok and type(id) == "number" then return id end
    end
    if State.combat then return nil end
    local auras = _G.C_UnitAuras
    local get = type(auras) == "table" and auras.GetPlayerAuraBySpellID or nil
    if type(get) ~= "function" then return nil end
    for _, id in ipairs(ns.MountIDs()) do
        local _, spellID = A.MountInfo(id)
        if spellID then
            local ok, aura = Ask(get, spellID)
            if ok and aura ~= nil then return id end
        end
    end
    return nil
end

-- Whether you're mounted, and on which mount, worked out only as you mount
-- or dismount (or after a loading screen): never each frame. Which mount
-- waits a moment after mounting, for the game to say: a look sooner (for
-- another event) gets how long is left, and waits that out, while any mount
-- is listed (with none, which mount never matters). 0 once it's known.
local function ReadMount()
    mounted = A.Mounted()
    if not mounted then
        mountID, mountStale = nil, false
    elseif mountStale then
        local left = mountedAt and math.min(A.DELAYS.change, mountedAt + A.DELAYS.change - GetTime()) or 0
        if left > .01 and #ns.MountIDs() > 0 then
            mountID = nil
            return left
        end
        mountID, mountStale = FindMount(), false
    end
    return 0
end

-- The mount you're on, while it's known; and whether you're mounted.
function A.Mount()
    if not mounted then return nil, false end
    return mountID, true
end

-- Deciding -----------------------------------------------------------------------------------

-- Where things stand now: combat, mounted and mount, place and talent group.
function A.Now()
    local state = {}
    state.combat = State.combat == true
    state.mounted = A.Mounted()
    state.mount = state.mounted and mountID or nil
    state.place = A.Place()
    state.group = A.ActiveGroup()
    return state
end

local MATCH = {
    combat = function(s) return s.combat end,
    mount = function(s) return s.mounted and s.mount ~= nil and ns.MountListed(s.mount) end,
    mounted = function(s) return s.mounted end,
    pvp = function(s) return s.place == "pvp" end,
    dungeon = function(s) return s.place == "dungeon" end,
    world = function(s) return s.place == "world" end,
    peace = function(s) return not s.combat end,
    talent1 = function(s) return s.group == 1 end,
    talent2 = function(s) return s.group == 2 end,
}

local PICK = {
    mount = function(s) return ns.MountPick(s.mount) end,
    talent1 = function() return ns.TalentPick(1) end,
    talent2 = function() return ns.TalentPick(2) end,
}

-- Whether a rule matches where things stand (picked or not).
function A.Matches(rule, state)
    local match = MATCH[rule]
    return match ~= nil and match(state) == true
end

-- A rule's pick (for "mount", the mount you're on's).
function A.Pick(rule, state)
    local pick = PICK[rule]
    if pick then return pick(state) end
    return ns.RulePick(rule)
end

-- What the rules pick where things stand, and why (the rule); nil when
-- switching is off or no rule that matches has a profile.
function A.Decide(state)
    if not ns.Get("autoSwitch") then return nil end
    for _, rule in ipairs(A.PRIORITY) do
        if A.Matches(rule, state) then
            local name = A.Pick(rule, state)
            if name then return name, rule end
        end
    end
    return nil
end

function A.Reason(why)
    if why == "mount" then
        local name = mountID and A.MountInfo(mountID)
        return name and ("On " .. name) or "On a mount you listed"
    end
    return REASONS[why] or "A rule"
end

-- Switching ------------------------------------------------------------------------------------

local last = { set = false } -- what the rules picked last time it counted: name, why
local held = false -- a profile picked by hand holds until they pick something new (kept over a reload)
local waiting = false -- a switch waits for the window to close
local started = false
local loginAt, foughtAt -- when the login's loading screen and the last fight ended

-- How long the waits still running have left: a second after the login's
-- loading screen, and out of a fight a second after it ended. 0 once over.
local function Settling()
    local now, left = GetTime(), 0
    local function Wait(since, delay)
        if since then left = math.max(left, math.min(delay, since + delay - now)) end
    end
    Wait(loginAt, A.DELAYS.login)
    if not State.combat then Wait(foughtAt, A.DELAYS.combatEnd) end
    return left
end

local function Paused()
    return ns.window ~= nil and ns.window:IsShown()
end

local function RefreshWindow()
    if ns.window and ns.window:IsShown() then ns.window:Refresh() end
end

local function Say(name, why)
    if not ns.Get("autoSay") then return end
    if name then
        print(("|cffffd100%s:|r %s, so now on profile %s."):format(ns.TITLE, A.Reason(why), name))
    else
        print(("|cffffd100%s:|r No rule picks a profile now, so back on your own, %s."):format(ns.TITLE,
            tostring(ns.OwnProfile())))
    end
end

-- Looks at where things stand and shows what the rules pick, if that's
-- new: "switched", "waiting" (the window's open, or the wait after a fight
-- or the login, or a mount's moment, still runs: it looks again then) or
-- nil (nothing new).
function A:Evaluate()
    if not ns.OwnProfile() then return nil end
    local left = Settling()
    if left <= .01 then left = ReadMount() end
    if left > .01 then
        self:Schedule(left)
        return "waiting"
    end
    local name, why = A.Decide(A.Now())
    if last.set and name == last.name and why == last.why then
        if waiting then
            waiting = false
            RefreshWindow()
        end
        return nil
    end
    if Paused() then
        if not waiting then
            waiting = true
            RefreshWindow()
        end
        return "waiting"
    end
    last.set, last.name, last.why = true, name, why
    held, waiting = false, false
    ns.SetSavedHold(nil)
    if ns.SetOverride(name) then Say(name, why) end
    RefreshWindow()
    return "switched"
end

-- One look a moment from now (delay in seconds; 0: now). A look asked for
-- later than the one waiting moves it later, so each event gets its moment
-- and a burst looks once; one asked for sooner is covered by it. A look now
-- leaves the one waiting in place.
local generation, dueAt = 0, nil
function A:Schedule(delay)
    if not started then return end
    delay = delay or 0
    if delay <= 0 then
        self:Evaluate()
        return
    end
    local due = GetTime() + delay
    if dueAt and dueAt >= due then return end
    generation = generation + 1
    local mine = generation
    dueAt = due
    C_Timer.After(delay, function()
        if mine ~= generation then return end
        dueAt = nil
        A:Evaluate()
    end)
end

-- A profile picked by hand (Core.lua): it holds until the rules pick
-- something new, measured from what they pick now, over a reload too.
function A:Held()
    local name, why = A.Decide(A.Now())
    last.set, last.name, last.why = true, name, why
    held = name ~= nil and name ~= ns.OwnProfile()
    waiting = false
    if held then ns.SetSavedHold(name, why) else ns.SetSavedHold(nil) end
end

-- A profile renamed (to) or deleted (to is nil). One the rules last picked,
-- deleted, means they decide again.
function A:ProfileMoved(from, to)
    if not last.set or last.name ~= from then return end
    if to then
        last.name = to
        return
    end
    last.set, held = false, false
    self:Evaluate()
end

-- Everything reset (Core.lua): every rule and hold gone, and the master
-- switch off, so the rules pick nothing and nothing waits or holds.
function A:Forget()
    last.set, last.name, last.why = true, nil, nil
    held, waiting = false, false
end

-- The window closed: a switch that waited goes now.
function A:WindowClosed()
    if waiting then self:Evaluate() end
end

-- The rules changed (a pick, the master switch): the dots made ahead, and
-- a look at once (which waits while the window is open).
function A:RulesChanged()
    if mounted and mountID == nil then mountStale = true end
    self:Reserve()
    if started then self:Evaluate() end
end

-- Made ahead, at login and as the rules change, for every profile a rule
-- can show: the effects' frames, the dots for the biggest trail, and the
-- cast ring, so a switch in a fight makes none of them then.
function A:Reserve()
    if not ns.Get("autoSwitch") or not ns.Engine then return end
    local get = ns.ProfileSetting
    local most, any, cast = 0, false, false
    for _, name in ipairs(ns.RuleProfiles()) do
        if get(name, "trail") then most = math.max(most, get(name, "trailMax")) end
        any = any or get(name, "trail") or get(name, "ring") or get(name, "look") or get(name, "cast") or get(name, "marker")
        cast = cast or get(name, "cast")
    end
    if any then ns.Engine:Build() end
    if most > 0 then ns.Engine:Reserve(most) end
    if cast and ns.Cast then ns.Cast:Build() end
end

-- For the Auto-switch page: what the rules pick now and why, whether a
-- switch waits for the window, and whether a pick by hand holds.
function A.Status()
    local name, why = A.Decide(A.Now())
    local pending
    if last.set then pending = name ~= last.name or why ~= last.why else pending = name ~= nil end
    return { on = ns.Get("autoSwitch") == true, name = name, why = why, waiting = pending and Paused(), held = held and not pending }
end

-- Events ---------------------------------------------------------------------------------------

local loggedIn = false
local HANDLERS = {
    PLAYER_ENTERING_WORLD = function()
        mountStale, mountedAt = true, GetTime()
        if not loggedIn then
            loggedIn = true
            loginAt = GetTime()
            ReadJournal()
            A:Reserve()
            -- A pick by hand that held when you logged out still holds, if
            -- the rules would pick the same as then.
            local name, why = ns.SavedHold()
            if name then last.set, last.name, last.why, held = true, name, why, true end
            A:Schedule(A.DELAYS.login)
        else
            A:Schedule(A.DELAYS.change)
        end
    end,
    ZONE_CHANGED_NEW_AREA = function() A:Schedule(A.DELAYS.change) end,
    PLAYER_MOUNT_DISPLAY_CHANGED = function()
        mountStale, mountedAt = true, GetTime()
        A:Schedule(A.DELAYS.change)
    end,
    NEW_MOUNT_ADDED = function() ReadJournal() end,
    ACTIVE_TALENT_GROUP_CHANGED = function() A:Schedule(A.DELAYS.change) end,
    PLAYER_TALENT_UPDATE = function() A:Schedule(A.DELAYS.change) end,
    -- Only the spell's number is kept, to ask the mount list which mount it
    -- summons once you're mounted.
    UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
        if unit ~= "player" or Secret(spellID) or type(spellID) ~= "number" then return end
        lastSpell, lastSpellAt = spellID, GetTime()
    end,
}

function A:Start()
    if started then return end
    started = true
    local frame = CreateFrame("Frame")
    self.frame = frame
    -- Each asked for on its own, so one the game doesn't have can't stop the rest.
    for event in pairs(HANDLERS) do
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            pcall(frame.RegisterUnitEvent, frame, event, "player")
        else
            pcall(frame.RegisterEvent, frame, event)
        end
    end
    frame:SetScript("OnEvent", function(_, event, ...)
        local handler = HANDLERS[event]
        if handler then handler(...) end
    end)
    -- Combat from State.lua, which has already noted it: starting shows the
    -- combat profile at once; ending waits a second, so a chain pull
    -- changes nothing.
    State:Listen(function(what)
        if what ~= "combat" then return end
        if State.combat then
            A:Schedule(A.DELAYS.combatStart)
        else
            foughtAt = GetTime()
            A:Schedule(A.DELAYS.combatEnd)
        end
    end)
end
