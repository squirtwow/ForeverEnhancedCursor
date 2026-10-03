-- The trail: dots dropped every set distance along the cursor's path, each
-- fading out over the same lifetime. Used by the effects (Engine.lua) and by
-- the window's preview, each with a trail of its own.
--
-- How it stays smooth and cheap:
-- - The dots are a ring of textures made once, only when the settings change
--   (Apply); each frame reuses them, oldest first. All last as long, so they
--   die in the order they were born: the oldest are dropped from one end and
--   only the live ones are drawn.
-- - Between two frames the path is a curve from the last cursor sample to
--   the newest, cut into short straight pieces: no corners at low frame
--   rates, and it ends at the cursor every frame, so the trail never lags
--   behind it. It leaves the last sample the way the curve before it
--   arrived, and arrives the way the cursor is heading now (worked out from
--   the last three samples, never looking ahead), so the joins are smooth.
--   Neither way is let reach further than the step itself, so a sudden stop
--   or turn can't swing the curve past where the cursor went.
--   A dot goes every spacing along it, the distance left over carried to the
--   next frame, each born at the time the cursor passed that spot, so the
--   fade is smooth inside one frame's dots too.
-- - A pause (no frames for much longer than they've been taking, and at
--   least GAP: a loading screen, Alt+Z, a hitch), a jump across the screen
--   or a look round starts a new line rather than drawing a streak; the old
--   dots fade as normal. A low frame rate is no pause: it still draws.
-- - The colours along the trail blend between the entries worked out for
--   it (Style.TrailColours), so they flow rather than step.
-- - Nothing made in the parts run every frame (between the "per frame"
--   marks, which Tools/TestRules.mjs checks): no tables, functions or text.
local _, ns = ...

local Trail = {}
Trail.__index = Trail
ns.Trail = Trail

local sqrt, floor = math.sqrt, math.floor
local atan2 = math.atan2 or math.atan
local PIECES = 12 -- straight pieces each frame's curve is cut into
local GAP = .2 -- the shortest wait without a sample that starts a new line
local PAUSE = 4 -- a wait this many times the frames' own starts a new line
local LUT = ns.Style.LUT -- colours along the trail (Style.TrailColours)
Trail.PIECES, Trail.GAP, Trail.PAUSE = PIECES, GAP, PAUSE

-- A trail drawing its dots in parent, placed from relative's bottom left.
function Trail.New(parent, relative)
    local t = setmetatable({}, Trail)
    t.parent, t.relative = parent, relative or parent
    t.tex, t.x, t.y, t.born, t.shown, t.angle = {}, {}, {}, {}, {}, {}
    t.lutR, t.lutG, t.lutB = {}, {}, {}
    for i = 1, LUT do t.lutR[i], t.lutG[i], t.lutB[i] = 1, 1, 1 end
    t.made, t.cap, t.first, t.count = 0, 0, 1, 0
    t.has, t.carry = false, 0
    t.t0, t.x1, t.y1, t.t1 = 0, 0, 0, 0
    -- The pace the curve arrived at the newest sample with, and the last
    -- step's own (units a second), while it's known.
    t.vx, t.vy, t.ux, t.uy, t.paced = 0, 0, 0, 0, false
    t.frame = 1 / 60 -- how long the frames have been taking, about
    t.qx, t.qy = {}, {} -- the curve's pieces, worked out each frame
    for k = 1, PIECES do t.qx[k], t.qy[k] = 0, 0 end
    t.spacing, t.life, t.width, t.height, t.alpha = 4, .25, 10, 10, .55
    t.k1, t.k2 = 1, 0
    t.jump2 = math.huge
    t.shrink, t.align, t.glow = false, false, false
    return t
end

-- Settings ---------------------------------------------------------------------------------

-- Moves the live dots, newest last, into the first slots of a ring cap long;
-- the oldest go if there are too many.
function Trail:Resize(cap)
    local keep = math.min(self.count, cap)
    local old = self.cap
    local xs, ys, born, angles = {}, {}, {}, {}
    for k = 1, keep do
        local i = (self.first + self.count - keep + k - 2) % old + 1
        xs[k], ys[k], born[k], angles[k] = self.x[i], self.y[i], self.born[i], self.angle[i]
    end
    for i = 1, self.made do
        if self.shown[i] then
            self.tex[i]:Hide()
            self.shown[i] = false
        end
    end
    for k = 1, keep do
        self.x[k], self.y[k], self.born[k], self.angle[k] = xs[k], ys[k], born[k], angles[k]
        local tex = self.tex[k]
        tex:SetPoint("CENTER", self.relative, "BOTTOMLEFT", xs[k], ys[k])
        if self.align then tex:SetRotation(angles[k]) end
        tex:Show()
        self.shown[k] = true
    end
    self.cap, self.first, self.count = cap, 1, keep
end

-- Textures made, hidden, up to count, so a profile switched to later (by the
-- Auto-switch rules, maybe in a fight) makes none. Never fewer.
function Trail:Reserve(count)
    count = math.max(0, math.floor(count or 0))
    while self.made < count do
        local i = self.made + 1
        local tex = self.parent:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(ns.Style.DOT)
        ns.Style.Crisp(tex)
        tex:SetSize(self.width, self.height)
        tex:SetBlendMode(self.glow and "ADD" or "BLEND")
        tex:Hide()
        self.tex[i], self.x[i], self.y[i], self.born[i], self.shown[i], self.angle[i] = tex, 0, 0, 0, false, 0
        self.made = i
    end
end

-- The settings (Style.TrailConfig): textures made up to the most dots asked
-- for, the live dots kept and restyled. A cap of 0 makes none and clears it.
function Trail:Apply(cfg)
    local cap = math.max(0, math.floor(cfg.cap or 0))
    self:Reserve(cap)
    local wasAligned = self.align
    self.spacing, self.life = math.max(.5, cfg.spacing), math.max(.01, cfg.life)
    -- What's left over from a wider spacing would put the next dot behind
    -- where the last frame ended: at most one new spacing is carried.
    if self.carry > self.spacing then self.carry = self.spacing end
    self.width, self.height, self.alpha = cfg.width, cfg.height, cfg.alpha
    self.glow, self.shrink, self.align = cfg.glow == true, cfg.shrink == true, cfg.align == true
    self.jump2 = cfg.jump and cfg.jump * cfg.jump or math.huge
    self.k1, self.k2 = cfg.k1 or 1, cfg.k2 or 0
    for i = 1, LUT do self.lutR[i], self.lutG[i], self.lutB[i] = cfg.lutR[i], cfg.lutG[i], cfg.lutB[i] end
    if cap ~= self.cap then self:Resize(cap) end
    local blend = self.glow and "ADD" or "BLEND"
    for i = 1, self.made do
        local tex = self.tex[i]
        tex:SetSize(self.width, self.height)
        tex:SetBlendMode(blend)
        if wasAligned and not self.align then tex:SetRotation(0) end
    end
    if self.count == 0 then self:Break() end
end

-- The next sample starts a new line; the dots already there fade as normal.
function Trail:Break()
    self.has = false
    self.carry = 0
end

-- Every dot gone at once.
function Trail:Clear()
    for i = 1, self.made do
        if self.shown[i] then
            self.tex[i]:Hide()
            self.shown[i] = false
        end
    end
    self.first, self.count = 1, 0
    self:Break()
end

function Trail:Count()
    return self.count
end

-- Placing dots ---------------------------------------------------------------------------------

-- One dot, in the next slot, or over the oldest when they're all in use.
function Trail:Put(x, y, born, angle)
    -- per frame: start
    local cap = self.cap
    local i
    if self.count == cap then
        i = self.first
        self.first = i % cap + 1
    else
        i = (self.first + self.count - 1) % cap + 1
        self.count = self.count + 1
    end
    self.x[i], self.y[i], self.born[i] = x, y, born
    local tex = self.tex[i]
    tex:SetPoint("CENTER", self.relative, "BOTTOMLEFT", x, y)
    if self.align then
        self.angle[i] = angle
        tex:SetRotation(angle)
    end
    if not self.shown[i] then
        tex:Show()
        self.shown[i] = true
    end
    -- per frame: end
end

-- A straight piece from a (at time ta) to b (at time tb): a dot every
-- spacing along it, the distance since the last dot carried over. A carry
-- below 0 is a stretch still to skip.
function Trail:Walk(ax, ay, ta, bx, by, tb)
    -- per frame: start
    local dx, dy = bx - ax, by - ay
    local length = sqrt(dx * dx + dy * dy)
    if length <= 0 then return end
    local spacing = self.spacing
    local angle = 0
    if self.align then angle = atan2(dy, dx) end
    local s = spacing - self.carry -- how far along this piece the next dot goes
    while s <= length do
        local f = s / length
        self:Put(ax + dx * f, ay + dy * f, ta + (tb - ta) * f, angle)
        s = s + spacing
    end
    self.carry = length - (s - spacing)
    -- per frame: end
end

-- The cursor's place this frame (in relative's units) at time now.
function Trail:Move(x, y, now)
    -- per frame: start
    if self.cap <= 0 then return end
    if self.has then
        -- A pause: much longer than the frames have been taking, and at
        -- least GAP. The frames' own time is followed as they come.
        local gap = now - self.t1
        local limit = self.frame * PAUSE
        if limit < GAP then limit = GAP end
        if gap > 0 then
            local step = gap
            if step > 1 then step = 1 end
            self.frame = self.frame + (step - self.frame) * .25
        end
        if gap > limit then self.has = false end
    end
    if not self.has then
        self.has = true
        self.t0, self.x1, self.y1, self.t1 = now, x, y, now
        self.vx, self.vy, self.paced = 0, 0, false
        self.carry = 0
        return
    end
    local dx, dy = x - self.x1, y - self.y1
    local moved = dx * dx + dy * dy
    if moved > self.jump2 then
        self:Break()
        return self:Move(x, y, now)
    end
    if moved < 1e-6 then
        -- Still: the trail already ends where the cursor rests.
        self.vx, self.vy, self.paced = 0, 0, false
        self.t0, self.t1 = now, now
        return
    end
    local x1, y1, t1 = self.x1, self.y1, self.t1
    local dt = now - t1
    if dt < 1e-4 then dt = 1e-4 end
    local length = sqrt(moved)
    -- Leaving the last sample the way the curve arrived there. Each way is
    -- kept to the step's own length, shortened the further it points from
    -- the step, and dropped if it points back: a sharp turn draws a point,
    -- not a loop.
    local ax, ay = self.vx * dt, self.vy * dt
    local ahead = ax * dx + ay * dy -- how far it points along the step
    local reach = ax * ax + ay * ay
    if ahead <= 0 or reach <= 0 then
        ax, ay = 0, 0
    else
        reach = sqrt(reach)
        local keep = ahead / (reach * length) -- how closely it follows the step
        if reach > length then keep = keep * length / reach end
        ax, ay = ax * keep, ay * keep
    end
    -- Arriving the way the cursor is heading now: this step, bent by how it
    -- differs from the step before (a curve through the last three samples).
    local ux, uy = dx / dt, dy / dt
    local bx, by = dx, dy
    if self.paced then
        local bend = dt / (t1 - self.t0 + dt)
        bx, by = (ux + (ux - self.ux) * bend) * dt, (uy + (uy - self.uy) * bend) * dt
        ahead = bx * dx + by * dy
        reach = bx * bx + by * by
        if ahead <= 0 or reach <= 0 then
            bx, by = dx, dy
        else
            reach = sqrt(reach)
            local keep = ahead / (reach * length)
            if reach > length then keep = keep * length / reach end
            bx, by = bx * keep, by * keep
        end
    end
    self.vx, self.vy, self.ux, self.uy, self.paced = bx / dt, by / dt, ux, uy, true
    -- The curve's pieces, measured.
    local qx, qy = self.qx, self.qy
    local px, py, total = x1, y1, 0
    for k = 1, PIECES do
        local u = k / PIECES
        local u2 = u * u
        local u3 = u2 * u
        local along, leave, arrive = 3 * u2 - 2 * u3, u3 - 2 * u2 + u, u3 - u2
        local ex = x1 + dx * along + ax * leave + bx * arrive
        local ey = y1 + dy * along + ay * leave + by * arrive
        qx[k], qy[k] = ex, ey
        local sx, sy = ex - px, ey - py
        total = total + sqrt(sx * sx + sy * sy)
        px, py = ex, ey
    end
    -- More dots this frame than the trail holds: the start of the curve,
    -- which would be dropped at once, is skipped.
    local over = total - self.cap * self.spacing
    if over > 0 then self.carry = self.carry - over end
    px, py = x1, y1
    local pt = t1
    for k = 1, PIECES do
        local qt = t1 + (now - t1) * k / PIECES
        self:Walk(px, py, pt, qx[k], qy[k], qt)
        px, py, pt = qx[k], qy[k], qt
    end
    if self.carry < 0 then self.carry = 0 end
    self.t0, self.x1, self.y1, self.t1 = t1, x, y, now
    -- per frame: end
end

-- Drawing --------------------------------------------------------------------------------------

-- The colour at the cursor now (Style.TrailColours), blended between entries.
function Trail:HeadColour(now)
    -- per frame: start
    local q = -now * self.k2
    q = (q - floor(q)) * LUT
    local c = floor(q)
    local f = q - c
    if c >= LUT then c, f = 0, 0 end
    local a = c + 1
    local b = a % LUT + 1
    local lutR, lutG, lutB = self.lutR, self.lutG, self.lutB
    return lutR[a] + (lutR[b] - lutR[a]) * f, lutG[a] + (lutG[b] - lutG[a]) * f, lutB[a] + (lutB[b] - lutB[a]) * f
    -- per frame: end
end

-- Drops the dots that have faded out and draws the rest; gives how many live.
function Trail:Tick(now)
    -- per frame: start
    local born, tex, shown = self.born, self.tex, self.shown
    local cap, life = self.cap, self.life
    while self.count > 0 and now - born[self.first] >= life do
        local i = self.first
        tex[i]:Hide()
        shown[i] = false
        self.first = i % cap + 1
        self.count = self.count - 1
    end
    local count = self.count
    if count == 0 then return 0 end
    local alpha, k1, k2 = self.alpha, self.k1, self.k2
    local lutR, lutG, lutB = self.lutR, self.lutG, self.lutB
    local shrink, width, height = self.shrink, self.width, self.height
    local i = self.first
    for _ = 1, count do
        local age = (now - born[i]) / life
        if age < 0 then age = 0 end
        local fade = 1 - age
        local q = age * k1 - now * k2
        q = (q - floor(q)) * LUT
        local c = floor(q)
        local f = q - c
        if c >= LUT then c, f = 0, 0 end
        local a = c + 1
        local b = a % LUT + 1
        local dot = tex[i]
        dot:SetVertexColor(lutR[a] + (lutR[b] - lutR[a]) * f, lutG[a] + (lutG[b] - lutG[a]) * f,
            lutB[a] + (lutB[b] - lutB[a]) * f, alpha * fade * fade)
        if shrink then dot:SetSize(width * fade, height * fade) end
        i = i % cap + 1
    end
    return count
    -- per frame: end
end
