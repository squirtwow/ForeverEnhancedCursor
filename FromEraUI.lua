-- EraUI (Squirt's own addon) has cursor effects of its own. This file only
-- reads its saved settings, never writes them and never calls EraUI: whether
-- one of its effects is on, so the pages can say both are drawing until it's
-- turned off there, and its cursor settings as a profile of this addon's,
-- offered once (ProfileTools.lua). The only file that names EraUI's saved
-- settings.
local _, ns = ...

local F = {}
ns.FromEraUI = F

-- EraUI's switch for each of this addon's effects.
local KEYS = { trail = "cursorTrail", ring = "cursorRing", cast = "cursorCastRing" }
F.KEYS = KEYS

-- EraUI's own defaults, for any setting it hasn't saved.
local DEFAULTS = {
    cursorTrail = false, cursorTrailClassColour = true, cursorTrailColour = "FFFFFF", cursorTrailSize = 10,
    cursorTrailOpacity = 55, cursorTrailLength = 25,
    cursorRing = false, cursorRingClassColour = false, cursorRingSize = 48, cursorRingThickness = 2,
    cursorCastRing = false, cursorCastClassColour = true, cursorCastColour = "FFFFFF", cursorCastSize = 60,
    cursorCastOpacity = 90,
}

-- Whether EraUI is loaded, as the game says. Nothing of EraUI's shows in
-- the window without it: no From EraUI block, no notices, no offer.
function F.Loaded()
    local check = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if type(check) ~= "function" then return false end
    local ok, loaded = pcall(check, "EraUI")
    return ok and loaded and true or false
end

-- EraUI's saved settings, while EraUI is loaded and they're readable.
local function Saved()
    if not F.Loaded() then return nil end
    local saved = _G.EraUIDB
    if type(saved) ~= "table" then return nil end
    if saved.enabled == false then return nil end
    return saved
end

-- Whether EraUI draws its own copy of an effect ("trail", "ring" or "cast").
function F.Drawing(kind)
    local key = KEYS[kind]
    local saved = key and Saved()
    return saved ~= nil and saved[key] == true
end

-- Whether EraUI is loaded and its settings can be read.
function F.Readable()
    return Saved() ~= nil
end

-- Whether EraUI draws any of the three: worth offering its settings.
function F.Offerable()
    return F.Drawing("trail") or F.Drawing("ring") or F.Drawing("cast")
end

-- One of EraUI's settings, of the kind it should be, else EraUI's default.
local function Read(saved, key)
    local value = saved[key]
    local default = DEFAULTS[key]
    if (issecretvalue and issecretvalue(value)) or type(value) ~= type(default) then return default end
    if type(value) == "number" and value ~= value then return default end
    return value
end

local function Round(value)
    return math.floor(value + .5)
end

-- EraUI's cursor settings as this addon's profile settings (each checked
-- again as the profile is made), or nil while they can't be read. EraUI's
-- one trail size sets the width and height, and the dot spacing to suit.
function F.Settings()
    local saved = Saved()
    if not saved then return nil end
    local out = {}
    local function Put(key, value)
        if value ~= nil and ns.Valid(key, value) then out[key] = value end
    end
    local function Hex(key)
        return ns.Style.ParseHex(Read(saved, key))
    end
    Put("trail", Read(saved, "cursorTrail"))
    if Read(saved, "cursorTrailClassColour") then
        Put("colourMode", "class")
    else
        Put("colourMode", "single")
        Put("colour1", Hex("cursorTrailColour"))
    end
    local size = Round(Read(saved, "cursorTrailSize"))
    Put("trailWidth", size)
    Put("trailHeight", size)
    Put("trailSpacing", Round(math.max(2, size * .4)))
    Put("trailAlpha", Round(Read(saved, "cursorTrailOpacity")))
    Put("trailLife", Round(Read(saved, "cursorTrailLength")) / 100)
    Put("ring", Read(saved, "cursorRing"))
    Put("ringSize", Round(Read(saved, "cursorRingSize")))
    Put("ringThickness", Round(Read(saved, "cursorRingThickness")))
    if Read(saved, "cursorRingClassColour") then
        Put("ringColour", "class")
    else
        Put("ringColour", "custom")
        Put("ringCustom", "FFFFFF")
    end
    Put("cast", Read(saved, "cursorCastRing"))
    Put("castSize", Round(Read(saved, "cursorCastSize")))
    Put("castAlpha", Round(Read(saved, "cursorCastOpacity")))
    if Read(saved, "cursorCastClassColour") then
        Put("castColour", "class")
    else
        Put("castColour", "custom")
        Put("castCustom", Hex("cursorCastColour"))
    end
    return out
end
