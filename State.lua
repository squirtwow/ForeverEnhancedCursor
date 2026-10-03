-- What the effects need to know about the game, from its events: whether
-- you're in a fight, whether the game has hidden the cursor to turn or look
-- around, and when the screen's scale changes. The effects listen.
local _, ns = ...

local State = { combat = false, turning = false, looking = false }
ns.State = State
-- Where the cursor was as the game hid it to turn or look around (screen
-- pixels, as GetCursorPosition gives them), until it shows again: the spot
-- it comes back to, for an effect that starts meanwhile.
State.spotX, State.spotY = nil, nil

local listeners = {}

-- listener(what): "combat", "look", "scale" or "world" (a loading screen).
function State:Listen(listener)
    listeners[#listeners + 1] = listener
end

local function Tell(what)
    for i = 1, #listeners do listeners[i](what) end
end

-- A plain answer from the game, or nil for an error or a secret.
local function Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or (issecretvalue and issecretvalue(value)) then return nil end
    return value
end

-- In a fight: the game's own events say so (the lockdown can still read
-- false while the fight's first event runs), and after a loading screen or a
-- reload, which a fight can outlast, the game is asked.
local function InFight()
    return Ask(InCombatLockdown) == true or Ask(UnitAffectingCombat, "player") == true
end

-- The cursor's spot as the first of the two starts, kept until both stop.
local function Started()
    if State.turning or State.looking then return end
    local ok, x, y = false, nil, nil
    if type(GetCursorPosition) == "function" then ok, x, y = pcall(GetCursorPosition) end
    local secret = issecretvalue and (issecretvalue(x) or issecretvalue(y))
    if ok and not secret and type(x) == "number" and type(y) == "number" then
        State.spotX, State.spotY = x, y
    else
        State.spotX, State.spotY = nil, nil
    end
end

local function Stopped()
    if not (State.turning or State.looking) then State.spotX, State.spotY = nil, nil end
end

local HANDLERS = {
    PLAYER_REGEN_DISABLED = function() State.combat = true; return "combat" end,
    PLAYER_REGEN_ENABLED = function() State.combat = false; return "combat" end,
    -- Turning with the right mouse button, and moving the camera with the
    -- left (seen working in game; Engine also polls IsMouselooking).
    PLAYER_STARTED_TURNING = function() Started(); State.turning = true; return "look" end,
    PLAYER_STOPPED_TURNING = function() State.turning = false; Stopped(); return "look" end,
    PLAYER_STARTED_LOOKING = function() Started(); State.looking = true; return "look" end,
    PLAYER_STOPPED_LOOKING = function() State.looking = false; Stopped(); return "look" end,
    UI_SCALE_CHANGED = function() return "scale" end,
    DISPLAY_SIZE_CHANGED = function() return "scale" end,
    -- A stop missed during a loading screen never sticks.
    PLAYER_ENTERING_WORLD = function()
        State.combat = InFight()
        State.turning, State.looking = false, false
        State.spotX, State.spotY = nil, nil
        return "world"
    end,
}

function State:Start()
    if self.frame then return end
    local frame = CreateFrame("Frame")
    self.frame = frame
    -- Each asked for on its own, so one the game doesn't have can't stop the rest.
    for event in pairs(HANDLERS) do pcall(frame.RegisterEvent, frame, event) end
    frame:SetScript("OnEvent", function(_, event)
        local handler = HANDLERS[event]
        if handler then Tell(handler()) end
    end)
    State.combat = InFight()
end
