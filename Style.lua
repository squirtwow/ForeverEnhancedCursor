-- How the effects look, worked out from the settings: colours (your class's,
-- one picked, a rainbow or a gradient), the ring art's cell for a size and
-- thickness, and the pieces the effects and the window's preview are both
-- drawn with (the highlight while looking is the game's own pointer,
-- see-through), so the preview always matches. Only TintLook runs every frame
-- (between the "per frame" marks, which Tools/TestRules.mjs checks).
local _, ns = ...

local S = {}
ns.Style = S

local floor, max, min = math.floor, math.max, math.min

S.DOT = ns.MEDIA .. "TrailDot.tga"
S.RINGS = ns.MEDIA .. "Rings.tga"
S.CAST = ns.MEDIA .. "CastRing.tga"
-- The game's own pointer, the gauntlet: the preview's pointer and the
-- highlight while looking. Its fingertip is its top left corner.
S.POINTER = "Interface\\Cursor\\Point"
S.LUT = 64 -- colours worked out along the trail, from the cursor out

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end
S.Public = Public

-- Colours -------------------------------------------------------------------------------

-- Your class's colour; Paladins get the softer pink they show in the game's
-- own raid frames. White if the game doesn't say.
function S.ClassColour()
    local _, class = UnitClass("player")
    if type(class) ~= "string" or not Public(class) then return 1, 1, 1 end
    if class == "PALADIN" then return .96, .55, .73 end
    local colour = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if type(colour) ~= "table" or type(colour.r) ~= "number" then return 1, 1, 1 end
    return colour.r, colour.g, colour.b
end

-- Six hex digits as three numbers from 0 to 1; white for anything else.
function S.HexRGB(hex)
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x$") then return 1, 1, 1 end
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- Three numbers from 0 to 1 as six hex digits, in capitals.
function S.HexOf(r, g, b)
    local function Byte(v) return floor(max(0, min(1, v)) * 255 + .5) end
    return ("%02X%02X%02X"):format(Byte(r), Byte(g), Byte(b))
end

-- A typed colour: six hex digits, a # in front allowed, any case; nil if not.
function S.ParseHex(text)
    local hex = type(text) == "string" and text:match("^%s*#?(%x%x%x%x%x%x)%s*$")
    return hex and hex:upper() or nil
end

-- A hue from 0 to 1 at full colour, as three numbers.
local function Hue(h)
    h = (h - floor(h)) * 6
    local i = floor(h)
    local f = h - i
    if i == 0 then return 1, f, 0 end
    if i == 1 then return 1 - f, 1, 0 end
    if i == 2 then return 0, 1, f end
    if i == 3 then return 0, 1 - f, 1 end
    if i == 4 then return f, 0, 1 end
    return 1, 0, 1 - f
end
S.Hue = Hue

-- A colour by its hue (0 to 1, round the rainbow from red), saturation (0
-- white, 1 the full colour) and brightness (0 black, 1 full), as three
-- numbers from 0 to 1; and back. Black and the greys have no hue: 0.
function S.FromHSV(h, s, v)
    local r, g, b = Hue(h)
    return v * (1 - s * (1 - r)), v * (1 - s * (1 - g)), v * (1 - s * (1 - b))
end

function S.ToHSV(r, g, b)
    local high, low = max(r, g, b), min(r, g, b)
    local range = high - low
    local h = 0
    if range > 0 then
        if high == r then
            h = ((g - b) / range) % 6
        elseif high == g then
            h = (b - r) / range + 2
        else
            h = (r - g) / range + 4
        end
        h = h / 6
    end
    return h, high > 0 and range / high or 0, high
end

-- The colours in use for the trail, as get(key) reads them: one for Class
-- and One colour, the first colourCount of the ten for Gradient (Rainbow
-- needs none).
local colours = {}
local function Colours(get, mode)
    if mode == "class" then
        colours[1] = { S.ClassColour() }
        return 1
    end
    local count = mode == "gradient" and get("colourCount") or 1
    for i = 1, count do colours[i] = { S.HexRGB(get("colour" .. i)) } end
    return count
end

-- Fills three arrays of S.LUT colours along the trail, from the cursor out,
-- and gives how the trail steps through them: k1 for a dot's age (0 at the
-- cursor, 1 as it fades out), k2 for time, so a dot's colour sits at
-- frac(age * k1 - now * k2) * S.LUT along them, blended between the entries
-- either side (Trail.lua), the last blending round to the first. Still
-- (speed 0), a gradient runs once from colour 1 at the cursor to its last
-- colour at the end; moving, or repeated, the colours blend round so the
-- joins are smooth.
function S.TrailColours(get, lutR, lutG, lutB)
    local mode = get("colourMode")
    local count = mode == "rainbow" and 0 or Colours(get, mode)
    local N = S.LUT
    for k = 1, N do
        local r, g, b
        if mode == "rainbow" then
            r, g, b = Hue((k - 1) / N)
        else
            local pos = (k - 1) / N * count
            local a = floor(pos) % count + 1
            local c = a % count + 1
            local f = pos - floor(pos)
            local from, to = colours[a], colours[c]
            r = from[1] + (to[1] - from[1]) * f
            g = from[2] + (to[2] - from[2]) * f
            b = from[3] + (to[3] - from[3]) * f
        end
        lutR[k], lutG[k], lutB[k] = r, g, b
    end
    local changing = mode == "rainbow" or (mode == "gradient" and count > 1)
    local speed = changing and get("colourSpeed") or 0
    local phases = changing and get("colourPhases") or 1
    local span = 1
    if changing and mode == "gradient" and speed == 0 and phases == 1 then span = (count - 1) / count end
    return phases * span, speed / 50
end

-- The trail's settings, as the Trail takes them (Trail.lua), into cfg (kept
-- and reused). dim: how much of its opacity shows (the preview dims what's off).
function S.TrailConfig(cfg, get, dim)
    cfg.spacing = get("trailSpacing")
    cfg.life = get("trailLife")
    cfg.cap = get("trailMax")
    cfg.width, cfg.height = get("trailWidth"), get("trailHeight")
    cfg.alpha = get("trailAlpha") / 100 * (dim or 1)
    cfg.glow, cfg.shrink, cfg.align = get("trailGlow"), get("trailShrink"), get("trailAlign")
    cfg.lutR, cfg.lutG, cfg.lutB = cfg.lutR or {}, cfg.lutG or {}, cfg.lutB or {}
    cfg.k1, cfg.k2 = S.TrailColours(get, cfg.lutR, cfg.lutG, cfg.lutB)
    return cfg
end

-- An effect's colour (prefix "ring", "cast" or "look"): your class's, its
-- own custom one, or the trail's at the cursor (trail: the Trail drawing it,
-- now: the time, as the trail's colours may flow).
function S.EffectColour(get, prefix, trail, now)
    local choice = get(prefix .. "Colour")
    if choice == "class" then return S.ClassColour() end
    if choice == "trail" and trail then
        return trail:HeadColour(now or 0)
    end
    return S.HexRGB(get(prefix .. "Custom"))
end

-- The ring art ----------------------------------------------------------------------------
-- Rings.tga is 8 by 8 cells of 128 pixels, each a ring 120 pixels across with
-- a clear edge round it; cell k (from 0, left to right then down) is
-- (k + 1) / 128 of the ring's width thick. The texture is drawn 128/120 of
-- the ring's size, so the ring itself is exactly the size asked for.

-- The cell for a ring this many pixels across and thick: its texture
-- coordinates (left, right, top, bottom) and the texture's size.
function S.RingCell(diameter, thickness)
    local index = max(1, min(64, floor(thickness / diameter * 128 + .5))) - 1
    local column, row = index % 8, floor(index / 8)
    return column / 8, (column + 1) / 8, row / 8, (row + 1) / 8, diameter * 128 / 120
end

local function Crisp(texture)
    texture:SetSnapToPixelGrid(false)
    texture:SetTexelSnappingBias(0)
end
S.Crisp = Crisp

-- A ring: a frame the size of the ring, its art centred in it. Never takes
-- the mouse.
function S.NewRing(parent, level)
    local frame = CreateFrame("Frame", nil, parent)
    frame:EnableMouse(false)
    if level then frame:SetFrameLevel(level) end
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetTexture(S.RINGS)
    texture:SetPoint("CENTER")
    Crisp(texture)
    frame.texture = texture
    return frame
end

function S.PaintRing(frame, diameter, thickness, r, g, b, a)
    local left, right, top, bottom, size = S.RingCell(diameter, thickness)
    frame:SetSize(diameter, diameter)
    frame.texture:SetTexCoord(left, right, top, bottom)
    frame.texture:SetSize(size, size)
    frame.texture:SetVertexColor(r, g, b, a)
end

-- Cast progress: a dark ring behind, and the game's cooldown swipe drawing
-- the ring in the cast's colour as the cast goes. Never takes the mouse.
S.CAST_BACK = { .08, .08, .08, .45 }
function S.NewCast(parent, level)
    local frame = CreateFrame("Frame", nil, parent)
    frame:EnableMouse(false)
    if level then frame:SetFrameLevel(level) end
    local back = frame:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetTexture(S.CAST)
    back:SetVertexColor(S.CAST_BACK[1], S.CAST_BACK[2], S.CAST_BACK[3], S.CAST_BACK[4])
    Crisp(back)
    local cooldown = CreateFrame("Cooldown", nil, frame)
    cooldown:SetAllPoints()
    cooldown:EnableMouse(false)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetSwipeTexture(S.CAST, 1, 1, 1, 1)
    frame.back, frame.cooldown = back, cooldown
    frame:Hide()
    return frame
end

-- Its size: bigger than asked when the cursor ring is on, so it sits just
-- outside it.
function S.CastSize(get)
    local size = get("castSize")
    if get("ring") then size = max(size, (get("ringSize") + 6) / .88) end
    return size
end

function S.PaintCast(frame, size, r, g, b, a)
    frame:SetSize(size, size)
    frame:SetAlpha(a)
    frame.cooldown:SetSwipeColor(r, g, b, 1)
end

-- The highlight while looking: a see-through copy of the game's own pointer
-- (the gauntlet) where the cursor comes back, its fingertip on the spot, so
-- it reads as "your cursor is here". No ring and no dot. Its size is how big
-- it is across (the game's own shows about 24 to 32 at the usual interface
-- sizes). It's the pointer as the game draws it unless a tint is picked:
-- then a gentle wash, LOOK_TINT of the way from white to the tint's colour
-- (the texture's own colours are multiplied by that). Never takes the mouse.
S.LOOK_TINT = .6
local TINT = S.LOOK_TINT

local function Wash(r, g, b)
    return 1 - TINT * (1 - r), 1 - TINT * (1 - g), 1 - TINT * (1 - b)
end

function S.NewLook(parent, level)
    local frame = CreateFrame("Frame", nil, parent)
    frame:EnableMouse(false)
    if level then frame:SetFrameLevel(level) end
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetTexture(S.POINTER)
    texture:SetAllPoints()
    frame.texture = texture
    frame:Hide()
    return frame
end

-- Puts its fingertip on a point of another frame's, x and y from it.
function S.PlaceLook(frame, relative, relativePoint, x, y)
    frame:SetPoint("TOPLEFT", relative, relativePoint, x, y)
end

-- Its colour: white (untinted) for None, else the wash of your class's
-- colour, its own custom one or the trail's at the cursor.
function S.LookColour(get, trail, now)
    if get("lookColour") == "none" then return 1, 1, 1 end
    return Wash(S.EffectColour(get, "look", trail, now))
end

-- r, g, b: as LookColour gives them.
function S.PaintLook(frame, size, r, g, b, a)
    frame:SetSize(size, size)
    frame.texture:SetVertexColor(r, g, b, 1)
    frame:SetAlpha(a)
end

-- Its tint on its own, as the trail's colours flow (r, g, b: the trail's
-- colour at the cursor, washed here): every frame then.
function S.TintLook(frame, r, g, b)
    -- per frame: start
    r, g, b = Wash(r, g, b)
    frame.texture:SetVertexColor(r, g, b, 1)
    -- per frame: end
end

-- The marker on the pointer --------------------------------------------------------------
-- A shape of the addon's own (Tools/GenerateArt.mjs draws them white, to be
-- tinted), centred on the cursor's point, or your class's icon as the game
-- draws it, in its own colours. Size is how big it is across. Never takes
-- the mouse.
S.MARKERS = {
    bullseye = ns.MEDIA .. "MarkerBullseye.tga",
    crosshair = ns.MEDIA .. "MarkerCrosshair.tga",
    dot = ns.MEDIA .. "MarkerDot.tga",
    diamond = ns.MEDIA .. "MarkerDiamond.tga",
    star = ns.MEDIA .. "MarkerStar.tga",
}
-- The game's round class icons, one sheet, cut by CLASS_ICON_TCOORDS.
S.CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"

-- Your class's icon on the game's sheet (left, right, top, bottom), or nil
-- if the game doesn't say (no class known yet, a secret, or no table).
function S.ClassIconCoords()
    local _, class = UnitClass("player")
    if type(class) ~= "string" or not Public(class) then return nil end
    local all = CLASS_ICON_TCOORDS
    local coords = type(all) == "table" and all[class]
    if type(coords) ~= "table" then return nil end
    local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
    if type(left) ~= "number" or type(right) ~= "number" or type(top) ~= "number" or type(bottom) ~= "number" then return nil end
    return left, right, top, bottom
end

function S.NewMarker(parent, level)
    local frame = CreateFrame("Frame", nil, parent)
    frame:EnableMouse(false)
    if level then frame:SetFrameLevel(level) end
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    Crisp(texture)
    frame.texture = texture
    frame:Hide()
    return frame
end

-- Draws it: shape, size across, the tint r, g, b and opacity a. The class
-- icon keeps its own colours; without the game's icon table it's the Dot.
-- true if the tint shows (any shape but the class icon).
function S.PaintMarker(frame, shape, size, r, g, b, a)
    frame:SetSize(size, size)
    local texture = frame.texture
    if shape == "class" then
        local left, right, top, bottom = S.ClassIconCoords()
        if left then
            texture:SetTexture(S.CLASS_ICONS)
            texture:SetTexCoord(left, right, top, bottom)
            texture:SetVertexColor(1, 1, 1, a)
            frame.tinted = false
            return false
        end
        shape = "dot"
    end
    texture:SetTexture(S.MARKERS[shape] or S.MARKERS.dot)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetVertexColor(r, g, b, a)
    frame.tinted = true
    return true
end
