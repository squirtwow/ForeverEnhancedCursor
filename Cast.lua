-- Cast progress round the cursor: a ring that fills as you cast and drains as
-- you channel, on the effects' anchor (Engine.lua), so it follows the cursor.
-- Only your own casts, which the game keeps readable in combat; if it ever
-- hides their times, the game's own duration drives the ring instead. An
-- interrupted or failed cast hides it at once.
local _, ns = ...
local Style = ns.Style

local Cast = {}
ns.Cast = Cast

Cast.state = nil -- the cast showing, while one does
local frame -- the ring (Style.NewCast), made once it's turned on
local clearing = false -- clearing the swipe runs its done script: not again from there

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

-- A cast's times, in seconds, from the game's (in milliseconds), or nil if
-- any of them can't be read. A channel pushed back keeps its first length,
-- so the ring drains on at the same pace, as the game's own cast bar does.
function Cast.Snapshot(previous, channel, name, startMS, endMS, spellID, fresh)
    if not Public(name) or type(name) ~= "string" or not Public(startMS) or not Public(endMS) or not Public(spellID)
        or type(startMS) ~= "number" or type(endMS) ~= "number" or endMS <= startMS then return nil end
    local total = (endMS - startMS) / 1000
    local same = not fresh and previous ~= nil and previous.channel == channel and previous.name == name
        and previous.spellID == spellID
    if channel and same and type(previous.total) == "number" then total = math.max(previous.total, total) end
    return { name = name, spellID = spellID, channel = channel, start = startMS / 1000, finish = endMS / 1000, total = total }
end

-- Hidden, without a word to the engine (it's asking, or about to look).
local function Hide()
    Cast.state = nil
    if not frame then return end
    frame:Hide()
    if not clearing then
        clearing = true
        frame.cooldown:Clear()
        clearing = false
    end
end

function Cast:Stop()
    Hide()
    ns.Engine:Gate()
end

function Cast:Build()
    if frame then return frame end
    ns.Engine:Build()
    frame = Style.NewCast(ns.Engine.driver, 101)
    frame:SetPoint("CENTER", ns.Engine.anchor, "CENTER", 0, 0)
    frame.cooldown:SetScript("OnCooldownDone", function()
        if not clearing then Cast:Stop() end
    end)
    self.frame = frame
    return frame
end

-- Its size, colour and opacity; off, it hides. Turned on mid-cast (a tick,
-- or a profile switched to in a fight), the cast going now shows at once.
function Cast:Apply()
    local get = ns.Get
    if not get("cast") then
        Hide()
        return
    end
    self:Build()
    local r, g, b = Style.EffectColour(get, "cast", ns.Engine.trail, GetTime())
    Style.PaintCast(frame, Style.CastSize(get), r, g, b, get("castAlpha") / 100)
    if self.state == nil then self:Update() end
end

-- Its colour on its own, as the trail's colours flow.
function Cast:Tint(r, g, b)
    -- per frame: start
    frame.cooldown:SetSwipeColor(r, g, b, 1)
    -- per frame: end
end

-- Each frame while a cast shows: whether it still does (a cast whose time
-- is up hides at once, not waiting for the game's event).
function Cast:Tick(now)
    -- per frame: start
    local state = self.state
    if state == nil then return false end
    if state.finish and now >= state.finish then
        Hide()
        return false
    end
    return true
    -- per frame: end
end

-- The cast or channel going now, from the game; event is the one that asked.
function Cast:Update(event, retry)
    if not ns.Get("cast") then
        Hide()
        ns.Engine:Gate()
        return
    end
    self:Build()
    local ok, name, _, _, startMS, endMS, _, _, _, spellID = pcall(UnitCastingInfo, "player")
    local channel = false
    if ok and Public(name) and not name then
        ok, name, _, _, startMS, endMS, _, _, spellID = pcall(UnitChannelInfo, "player")
        channel = true
    end
    if not ok or (Public(name) and not name) then
        -- A channel's update can come a frame before its new times: once more, next frame.
        if self.state and event == "UNIT_SPELLCAST_CHANNEL_UPDATE" and not retry then
            local previous = self.state
            C_Timer.After(0, function()
                if Cast.state == previous then Cast:Update(event, true) end
            end)
            return
        end
        self:Stop()
        return
    end
    local fresh = event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
    local snapshot = Cast.Snapshot(self.state, channel, name, startMS, endMS, spellID, fresh)
    local cooldown = frame.cooldown
    cooldown:SetReverse(not channel)
    local driven = false
    if snapshot then
        local start = channel and snapshot.finish - snapshot.total or snapshot.start
        cooldown:SetCooldown(start, snapshot.total)
        driven = true
    else
        -- The times can't be read: the game's own duration drives the swipe.
        local getter = channel and UnitChannelDuration or UnitCastingDuration
        if getter and cooldown.SetCooldownFromDurationObject then
            local success, duration = pcall(getter, "player")
            if success and (not Public(duration) or duration) then
                driven = pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration)
            end
        end
    end
    if not driven then
        self:Stop()
        return
    end
    self.state = snapshot or { channel = channel }
    frame:Show()
    ns.Engine:Gate()
end

local EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }

function Cast:Start()
    if self.events then return end
    local events = CreateFrame("Frame")
    self.events = events
    for _, event in ipairs(EVENTS) do pcall(events.RegisterUnitEvent, events, event, "player") end
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("UI_SCALE_CHANGED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" or event == "UI_SCALE_CHANGED" then
            if ns.Get("cast") then self:Update() end
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
            self:Stop()
        else
            self:Update(event)
        end
    end)
end
