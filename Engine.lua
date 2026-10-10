-- The effects on screen: the trail, the ring round the cursor, the marker on
-- the pointer and the highlight while looking (cast progress is Cast.lua's,
-- on the same frames).
--
-- One frame of the addon's own drives them all, over the whole screen, above
-- the game's windows, never taking the mouse. It runs only while something
-- needs it: the ring, the highlight or cast progress showing, the trail able
-- to drop dots, or dots still fading. A 1 by 1 anchor follows the cursor and
-- the ring, the cast ring and the highlight sit on it; while the game hides
-- the cursor to turn or look around, the anchor stays where the cursor was,
-- which is where it comes back, so the highlight (a see-through copy of the
-- game's pointer, its fingertip on the anchor) marks that spot. Started
-- while it's hidden (a cast, or a profile switched to, while turning), the
-- frame places the anchor where the cursor hid (State.lua notes it), else
-- where the game says the cursor is: never where it was last left.
--
-- Nothing is made while it runs: the dots are made when the settings change
-- (Trail.lua), and the frame's own work, between the "per frame" marks, makes
-- no tables, functions or text (Tools/TestRules.mjs checks).
local _, ns = ...
local Style, State = ns.Style, ns.State

local Engine = {}
ns.Engine = Engine

local sin = math.sin
local Cast -- Cast.lua, once started
local driver, anchor, trail, ring, look, marker
local cfg = {} -- the trail's settings, reused
local running = false
-- Settings, read as they change.
local trailOn, trailCombat, trailAllowed = false, false, false
local offsetX, offsetY = 0, 0
local ringOn, ringAlpha = false, 1
local lookOn, lookRight, lookLeft, lookPulse, lookAlpha = false, true, true, false, .9
local markerOn, markerCombat, markerAllowed, markerAlpha = false, false, false, 1
-- Effects coloured as the trail, while its colours flow.
local tintRing, tintLook, tintCast, tintMarker, tinting = false, false, false, false, false
-- Each frame.
local lastX, lastY -- where the cursor last was, before any looking round
local wasLooking, marked = false, false

-- The frames, made once something is first turned on.
function Engine:Build()
    if driver then return end
    driver = CreateFrame("Frame", nil, UIParent)
    driver:SetAllPoints(UIParent)
    driver:SetFrameStrata("TOOLTIP")
    driver:SetFrameLevel(98)
    driver:EnableMouse(false)
    driver:Hide()
    anchor = CreateFrame("Frame", nil, driver)
    anchor:SetSize(1, 1)
    anchor:EnableMouse(false)
    anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 0, 0)
    trail = ns.Trail.New(driver, UIParent)
    ring = Style.NewRing(driver, 100)
    ring:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    ring:Hide()
    look = Style.NewLook(driver, 102)
    Style.PlaceLook(look, anchor, "CENTER", 0, 0)
    -- The marker under the rings, centred on the cursor's point.
    marker = Style.NewMarker(driver, 99)
    marker:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    self.driver, self.anchor, self.trail, self.ring, self.look, self.marker = driver, anchor, trail, ring, look, marker
end

local function Stop()
    running = false
    driver:SetScript("OnUpdate", nil)
    driver:Hide()
    trail:Clear()
    look:Hide()
    marked, wasLooking = false, false
    lastX, lastY = nil, nil
end

-- Every frame while running.
local function Update()
    -- per frame: start
    local now = GetTime()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local known = type(x) == "number" and type(y) == "number" and type(scale) == "number" and scale > 0
    if known then x, y = x / scale, y / scale end
    -- Turning (right button) or looking round (left): the game hides the cursor.
    local right, left = State.turning, State.looking
    local poll = IsMouselooking
    if poll and poll() then right = true end
    local looking = right or left
    if looking ~= wasLooking then
        wasLooking = looking
        trail:Break()
    end
    local mark = lookOn and ((lookRight and right) or (lookLeft and left)) or false
    if mark ~= marked then
        marked = mark
        if mark then look:Show() else look:Hide() end
    end
    -- Started while the cursor is hidden (a cast, or a profile switch, while
    -- turning): no spot known yet, so the one it hid at, else where the game
    -- says it is, rather than wherever the anchor was left.
    if looking and lastX == nil then
        local sx, sy = State.spotX, State.spotY
        if sx and sy and type(scale) == "number" and scale > 0 then
            x, y, known = sx / scale, sy / scale, true
        end
    end
    if known and (not looking or lastX == nil) then
        if x ~= lastX or y ~= lastY then
            lastX, lastY = x, y
            anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        end
        if trailAllowed and not looking then trail:Move(x + offsetX, y + offsetY, now) end
    end
    local live = trail:Tick(now)
    if tinting then
        local r, g, b = trail:HeadColour(now)
        if tintRing then ring.texture:SetVertexColor(r, g, b, ringAlpha) end
        if tintLook then Style.TintLook(look, r, g, b) end
        if tintCast and Cast.state then Cast:Tint(r, g, b) end
        if tintMarker then marker.texture:SetVertexColor(r, g, b, markerAlpha) end
    end
    if marked and lookPulse then look:SetAlpha(lookAlpha * (.75 + .25 * sin(now * 4))) end
    local casting = Cast.state ~= nil and Cast:Tick(now)
    if live == 0 and not (ringOn or lookOn or trailAllowed or markerAllowed or casting) then Stop() end
    -- per frame: end
end

-- Runs the frame while anything needs it, and stops it once nothing does.
function Engine:Gate()
    if not driver then return end
    trailAllowed = trailOn and (not trailCombat or State.combat == true)
    markerAllowed = markerOn and (not markerCombat or State.combat == true)
    marker:SetShown(markerAllowed)
    local need = ringOn or lookOn or trailAllowed or markerAllowed or (Cast ~= nil and Cast.state ~= nil) or trail:Count() > 0
    if need and not running then
        running = true
        driver:Show()
        driver:SetScript("OnUpdate", Update)
        Update()
    elseif not need and running then
        Stop()
    end
end

function Engine:Running()
    return running
end

-- Dots made ahead for the biggest trail a profile the Auto-switch rules can
-- show has, so switching to it (in a fight too) makes none then.
function Engine:Reserve(count)
    if type(count) ~= "number" or count <= 0 then return end
    self:Build()
    trail:Reserve(count)
end

-- The settings, read again: after a change, a profile switch or a new scale.
function Engine:Apply()
    local get = ns.Get
    trailOn, trailCombat = get("trail"), get("trailCombat")
    ringOn, lookOn = get("ring"), get("look")
    markerOn, markerCombat = get("marker"), get("markerCombat")
    if not driver then
        -- Nothing is made until something is turned on.
        if not (trailOn or ringOn or lookOn or markerOn or get("cast")) then return end
        self:Build()
    end
    offsetX, offsetY = get("trailX"), get("trailY")
    lookRight, lookLeft, lookPulse = get("lookRight"), get("lookLeft"), get("lookPulse")
    Style.TrailConfig(cfg, get, 1)
    -- A jump of half the screen in one frame is the cursor put somewhere
    -- else, not moved: a new line, not a streak.
    local height = UIParent:GetHeight()
    cfg.jump = (type(height) == "number" and height > 0 and height or 768) / 2
    if not trailOn then cfg.cap = 0 end
    trail:Apply(cfg)
    local now = GetTime()
    ringAlpha = get("ringAlpha") / 100
    local r, g, b = Style.EffectColour(get, "ring", trail, now)
    Style.PaintRing(ring, get("ringSize"), get("ringThickness"), r, g, b, ringAlpha)
    ring:SetShown(ringOn)
    lookAlpha = get("lookAlpha") / 100
    r, g, b = Style.LookColour(get, trail, now)
    Style.PaintLook(look, get("lookSize"), r, g, b, lookAlpha)
    if not lookOn and marked then
        marked = false
        look:Hide()
    end
    markerAlpha = get("markerAlpha") / 100
    r, g, b = Style.EffectColour(get, "marker", trail, now)
    local tinted = Style.PaintMarker(marker, get("markerShape"), get("markerSize"), r, g, b, markerAlpha)
    local flowing = trail.k2 ~= 0
    tintRing = flowing and ringOn and get("ringColour") == "trail"
    tintLook = flowing and lookOn and get("lookColour") == "trail"
    tintCast = flowing and get("cast") and get("castColour") == "trail"
    tintMarker = flowing and tinted and markerOn and get("markerColour") == "trail"
    tinting = tintRing or tintLook or tintCast or tintMarker
    if Cast then Cast:Apply() end
    self:Gate()
end

function Engine:Start()
    if self.started then return end
    self.started = true
    Cast = ns.Cast
    State:Listen(function(what)
        if what == "combat" then
            self:Gate()
        elseif what == "scale" or what == "world" then
            -- The dots were placed for the old scale.
            if trail then trail:Clear() end
            self:Apply()
        end
    end)
    ns.Listen(function(key)
        if key == nil or ns.PROFILE_KEYS[key] then self:Apply() end
    end)
    self:Apply()
end
