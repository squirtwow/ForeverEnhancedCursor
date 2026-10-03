-- The preview across the top of the Trail, Colours and Rings pages: the
-- game's own pointer loops a figure eight and the profile's effects follow it,
-- drawn with the same pieces as the real ones (Trail.lua, Style.lua), so
-- every change shows here at once. A six second loop: moving; then looking
-- round (the cursor hides and the highlight, a see-through copy of it, marks
-- where it'll come back); then moving on with a one second cast. The effect
-- a page is about shows even while it's off, dimmed, with a line saying how
-- to turn it on. It runs only while it shows, and ignores the real mouse.
local _, ns = ...
local T = ns.Theme
local Style = ns.Style

ns.PREVIEW_WIDTH, ns.PREVIEW_HEIGHT = 606, 120
local LOOP = 6 -- seconds
local LOOK_FROM, LOOK_TO = 3.5, 5 -- looking round, in the loop
local CAST_FROM = 5 -- a one second cast, to the loop's end
local SPEED = 2.6 -- the figure eight's pace, in radians a second
local DIM = .35 -- how much of an effect that's off shows
-- The game's own pointer, the gauntlet (Style.POINTER), about as big as it
-- shows in the game at the usual sizes; its fingertip is its top left corner.
local POINTER = 24

-- What each page or tab is about: the setting that turns it on, and what
-- the line says while it's off.
local FOCUS = {
    trail = { key = "trail", off = "Off: tick Show the cursor trail to use it." },
    ring = { key = "ring", off = "Off: tick Show a ring round the cursor to use it." },
    cast = { key = "cast", off = "Off: tick Show cast progress round the cursor to use it." },
    look = { key = "look", off = "Off: tick Cursor highlight while looking to use it." },
}

function ns.BuildPreview(window, x, y)
    local get = ns.Get
    local strip = CreateFrame("Frame", nil, window, "BackdropTemplate")
    strip:SetPoint("TOPLEFT", x, y)
    strip:SetSize(ns.PREVIEW_WIDTH, ns.PREVIEW_HEIGHT)
    strip:SetFrameLevel(window:GetFrameLevel() + 20)
    T:Flat(strip, T.PANEL, T.BORDER)
    strip:SetClipsChildren(true)
    strip:EnableMouse(false)
    strip:Hide()

    -- The dots on a frame of their own inside the strip, so they're clipped
    -- with everything else in it.
    local canvas = CreateFrame("Frame", nil, strip)
    canvas:SetAllPoints()
    local trail = ns.Trail.New(canvas, strip)
    local ring = Style.NewRing(strip)
    local cast = Style.NewCast(strip)
    -- The highlight over the other effects, as on screen.
    local look = Style.NewLook(strip, strip:GetFrameLevel() + 5)
    -- The pointer, its fingertip on the point.
    local top = CreateFrame("Frame", nil, strip)
    top:SetAllPoints()
    top:SetFrameLevel(strip:GetFrameLevel() + 6)
    local pointer = top:CreateTexture(nil, "OVERLAY")
    pointer:SetTexture(Style.POINTER)
    pointer:SetSize(POINTER, POINTER)
    local caption = T:Text(top, "GameFontHighlightSmall", T.MUTED)
    caption:SetPoint("BOTTOMLEFT", 8, 6)
    local cfg = {}
    strip.trail, strip.ring, strip.cast, strip.look, strip.pointer, strip.caption = trail, ring, cast, look, pointer, caption
    strip.focus = "trail"

    -- Shown as the profile has it; dimmed while off if it's the one in focus.
    local showRing, showCast, showLook, showTrail = false, false, false, false
    local trailOn, offsetX, offsetY, lookPulse, lookAlpha, ringAlpha = false, 0, 0, false, 1, 1
    -- Effects coloured as the trail, while its colours flow (as on screen).
    local tintRing, tintLook, tintCast = false, false, false
    -- Where the loop is: looking round, or casting (since castStart).
    local looking, casting, castStart = false, false, 0
    local function Apply()
        local focus = strip.focus
        trailOn = get("trail")
        showTrail = trailOn or focus == "trail"
        Style.TrailConfig(cfg, get, trailOn and 1 or DIM)
        if not showTrail then cfg.cap = 0 end
        trail:Apply(cfg)
        offsetX, offsetY = get("trailX"), get("trailY")
        local now = GetTime()
        showRing = get("ring") or focus == "ring"
        local r, g, b = Style.EffectColour(get, "ring", trail, now)
        ringAlpha = get("ringAlpha") / 100 * (get("ring") and 1 or DIM)
        Style.PaintRing(ring, get("ringSize"), get("ringThickness"), r, g, b, ringAlpha)
        ring:SetShown(showRing)
        local flowing = trail.k2 ~= 0
        tintRing = flowing and get("ringColour") == "trail"
        tintCast = flowing and get("castColour") == "trail"
        tintLook = flowing and get("lookColour") == "trail"
        showCast = get("cast") or focus == "cast"
        r, g, b = Style.EffectColour(get, "cast", trail, now)
        Style.PaintCast(cast, Style.CastSize(get), r, g, b, get("castAlpha") / 100 * (get("cast") and 1 or DIM))
        -- Mid-cast, another tab or the tick shows or hides it now, not at
        -- the loop's next turn.
        if casting and showCast ~= cast:IsShown() then
            if showCast then
                cast.cooldown:SetReverse(true)
                cast.cooldown:SetCooldown(castStart, LOOP - CAST_FROM)
            end
            cast:SetShown(showCast)
        end
        showLook = get("look") or focus == "look"
        lookAlpha = get("lookAlpha") / 100 * (get("look") and 1 or DIM)
        lookPulse = get("lookPulse")
        r, g, b = Style.LookColour(get, trail, now)
        Style.PaintLook(look, get("lookSize"), r, g, b, lookAlpha)
        -- Looking round, likewise for the highlight.
        if looking then look:SetShown(showLook) end
        local spec = FOCUS[focus]
        caption:SetText(spec and not get(spec.key) and spec.off or "")
    end
    strip.Apply = Apply

    -- The loop: where the pointer is, in the strip.
    local cx, cy = ns.PREVIEW_WIDTH / 2, ns.PREVIEW_HEIGHT / 2
    local A, B = ns.PREVIEW_WIDTH / 2 - 70, ns.PREVIEW_HEIGHT - 50
    local sin = math.sin
    local started, path = 0, 0
    local function Update(_, elapsed)
        -- per frame: start
        local now = GetTime()
        local t = (now - started) % LOOP
        local lookNow = t >= LOOK_FROM and t < LOOK_TO
        if not lookNow then path = path + (elapsed or 0) end
        local px = cx + A * sin(path * SPEED)
        local py = cy + B * sin(path * SPEED * 2) / 2
        if lookNow ~= looking then
            looking = lookNow
            trail:Break()
            if looking then
                -- Where the pointer's fingertip just was.
                Style.PlaceLook(look, strip, "BOTTOMLEFT", px, py)
                look:SetShown(showLook)
                pointer:Hide()
            else
                look:Hide()
                pointer:Show()
            end
        end
        if not looking then
            pointer:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", px, py)
            ring:SetPoint("CENTER", strip, "BOTTOMLEFT", px, py)
            cast:SetPoint("CENTER", strip, "BOTTOMLEFT", px, py)
            if showTrail then trail:Move(px + offsetX, py + offsetY, now) end
        end
        local castNow = t >= CAST_FROM
        if castNow ~= casting then
            casting, castStart = castNow, now
            if casting and showCast then
                cast.cooldown:SetReverse(true)
                cast.cooldown:SetCooldown(now, LOOP - CAST_FROM)
                cast:Show()
            else
                cast:Hide()
            end
        end
        if looking and lookPulse then look:SetAlpha(lookAlpha * (.75 + .25 * sin(now * 4))) end
        if tintRing or tintCast or tintLook then
            local r, g, b = trail:HeadColour(now)
            if tintRing then ring.texture:SetVertexColor(r, g, b, ringAlpha) end
            if tintCast then cast.cooldown:SetSwipeColor(r, g, b, 1) end
            if tintLook then Style.TintLook(look, r, g, b) end
        end
        trail:Tick(now)
        -- per frame: end
    end

    -- Runs only while it shows.
    function strip:Run(on)
        if on then
            if not self:GetScript("OnUpdate") then
                started, path = GetTime(), 0
                looking, casting = false, false
                look:Hide()
                cast:Hide()
                pointer:Show()
                Apply()
                self:SetScript("OnUpdate", Update)
                Update(self, 0)
            end
        elseif self:GetScript("OnUpdate") then
            self:SetScript("OnUpdate", nil)
            trail:Clear()
            cast:Hide()
            look:Hide()
        end
    end

    -- Which effect the page in view is about ("trail", "ring", "cast" or "look").
    function strip:Focus(focus)
        if focus == self.focus then return end
        self.focus = focus
        if self:GetScript("OnUpdate") then Apply() end
    end

    strip:SetScript("OnHide", function(self) self:Run(false) end)
    ns.Listen(function(key)
        if strip:GetScript("OnUpdate") and (key == nil or ns.PROFILE_KEYS[key]) then Apply() end
    end)
    window.preview = strip
    return strip
end
