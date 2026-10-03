-- Forever Enhanced Cursor: saved settings and profiles, the /fec command,
-- Escape for the window and the entry in Options > AddOns. Each effect lives
-- in its own file and starts from here once the saved settings are loaded.
local ADDON, ns = ...

ns.TITLE = "Forever Enhanced Cursor"
ns.SLASH = "/fec"
ns.SLASH_SPARE = "/fecursor" -- in case another addon takes /fec
ns.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
ns.ICON = ns.MEDIA .. "FECIcon.tga"

-- The addon's version, from the TOC, which CurseForge's packager fills in from
-- each version tag; "dev" for a copy whose TOC has no number (none, or the
-- packager's placeholder, as in the source itself).
function ns.Version()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = get and get(ADDON, "Version")
    if type(version) ~= "string" or version == "" or version:find("@", 1, true) then return "dev" end
    return version
end

-- The version of notes still waiting for the next update's number (Notes.lua).
ns.UNRELEASED = "Unreleased"

-- A version as numbers to compare part by part ("1.10.2" is 1, 10, 2), or nil
-- if it isn't one. What's unreleased comes after every release, and a copy
-- straight from the source ("dev") after that.
local function VersionParts(version)
    if version == ns.UNRELEASED then return { math.huge } end
    if version == "dev" then return { math.huge, math.huge } end
    local digits = type(version) == "string" and version:match("^v?(%d+[%d%.]*)")
    if not digits then return nil end
    local parts = {}
    for part in digits:gmatch("%d+") do parts[#parts + 1] = tonumber(part) end
    return parts
end

-- -1, 0 or 1 as version a is older than, the same as or newer than b; nil if
-- either isn't a version.
function ns.CompareVersions(a, b)
    a, b = VersionParts(a), VersionParts(b)
    if not (a and b) then return nil end
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

-- Settings -------------------------------------------------------------------------
-- Every effect starts off. Most settings live in profiles, so each character
-- can have its own look; the window's accent, the minimap button and the
-- Auto-switch rules are the same for every character. Numbers are kept in
-- the unit their slider shows, and colours as six hex digits ("FF8000").
ns.DEFAULTS = {
    accent = "orange", -- the /fec window's accent colour
    minimap = true, -- the minimap button
    minimapAngle = 255, -- where it sits round the minimap: degrees anticlockwise from the right
    autoSwitch = false, -- the Auto-switch page's rules (AutoSwitch.lua), for every character
    autoSay = false, -- a line in chat for each automatic switch
    -- The trail.
    trail = false,
    trailCombat = false, -- only in combat
    trailSpacing = 4, -- between dots along the path, in pixels
    trailLife = .25, -- how long each dot lasts, in seconds
    trailMax = 160, -- the most dots at once
    trailWidth = 10,
    trailHeight = 10,
    trailAlpha = 55, -- percent
    trailX = 0, -- moves the trail from the cursor's point, in pixels
    trailY = 0,
    trailGlow = false, -- additive blend
    trailShrink = false, -- dots shrink as they fade
    trailAlign = false, -- dots turn along the path
    -- Its colours: your class colour, one colour, a rainbow, or a gradient
    -- of up to ten colours.
    colourMode = "class",
    colour1 = "FFFFFF", colour2 = "FF4D4D", colour3 = "FFB84D", colour4 = "FFF04D", colour5 = "5CFF6B",
    colour6 = "4DD2FF", colour7 = "6B5CFF", colour8 = "D35CFF", colour9 = "FF5CC8", colour10 = "8C8C8C",
    colourCount = 2, -- how many of the ten the gradient uses
    colourPhases = 1, -- how often the colours repeat along the trail
    colourSpeed = 0, -- how fast they flow out from the cursor, in percent; 0 stays put
    -- A ring round the cursor.
    ring = false,
    ringSize = 48,
    ringThickness = 2,
    ringAlpha = 100,
    ringColour = "custom", -- class, custom or the trail's
    ringCustom = "FFFFFF",
    -- Cast progress round the cursor.
    cast = false,
    castSize = 60,
    castAlpha = 90,
    castColour = "class",
    castCustom = "FFFFFF",
    -- A marker where the cursor is while the game hides it to look around:
    -- a see-through copy of the game's pointer, its fingertip on the spot.
    look = false,
    lookSize = 32, -- how big the pointer is across (the game's own is about 24 to 32)
    lookAlpha = 60, -- see-through
    lookColour = "none", -- untinted (the game's pointer as it is), or a gentle tint
    lookCustom = "FFFFFF",
    lookRight = true, -- while turning with the right mouse button
    lookLeft = true, -- while moving the camera with the left mouse button
    lookPulse = false,
}
-- The settings a profile holds; the rest are shared.
ns.PROFILE_KEYS = {
    trail = true, trailCombat = true, trailSpacing = true, trailLife = true, trailMax = true, trailWidth = true,
    trailHeight = true, trailAlpha = true, trailX = true, trailY = true, trailGlow = true, trailShrink = true, trailAlign = true,
    colourMode = true, colourCount = true, colourPhases = true, colourSpeed = true,
    ring = true, ringSize = true, ringThickness = true, ringAlpha = true, ringColour = true, ringCustom = true,
    cast = true, castSize = true, castAlpha = true, castColour = true, castCustom = true,
    look = true, lookSize = true, lookAlpha = true, lookColour = true, lookCustom = true, lookRight = true, lookLeft = true,
    lookPulse = true,
}
ns.COLOUR_COUNT = 10
for i = 1, ns.COLOUR_COUNT do ns.PROFILE_KEYS["colour" .. i] = true end

-- Number settings, each within its limits: min, max, default (the slider's
-- step is the window's, ns.STEPS).
ns.NUMBERS = {
    minimapAngle = { 0, 359, 255 },
    trailSpacing = { 1, 40, 4 },
    trailLife = { .1, 2, .25 },
    trailMax = { 10, 500, 160 },
    trailWidth = { 2, 64, 10 },
    trailHeight = { 2, 64, 10 },
    trailAlpha = { 5, 100, 55 },
    trailX = { -100, 100, 0 },
    trailY = { -100, 100, 0 },
    colourCount = { 1, 10, 2 },
    colourPhases = { 1, 10, 1 },
    colourSpeed = { 0, 100, 0 },
    ringSize = { 24, 160, 48 },
    ringThickness = { 1, 10, 2 },
    ringAlpha = { 10, 100, 100 },
    castSize = { 24, 200, 60 },
    castAlpha = { 10, 100, 90 },
    lookSize = { 16, 128, 32 }, -- as the ring's was, so every size saved before still loads
    lookAlpha = { 10, 100, 60 },
}
-- Steps for the sliders: 1 unless listed.
ns.STEPS = { trailLife = .05, trailMax = 10 }
-- Whole numbers only: every number but the lifetime.
local WHOLE = {}
for key in pairs(ns.NUMBERS) do WHOLE[key] = key ~= "trailLife" end
-- Colours: six hex digits.
local HEX = { ringCustom = true, castCustom = true, lookCustom = true }
for i = 1, ns.COLOUR_COUNT do HEX["colour" .. i] = true end
ns.HEX_KEYS = HEX
-- Choices a text setting may hold, in the order the window offers them.
ns.ACCENT_KEYS = { "orange", "blue", "teal", "purple", "green" }
ns.EFFECT_COLOURS = { "class", "custom", "trail" }
-- The highlight's tint: none first (the game's pointer as it is).
ns.LOOK_TINTS = { "none", "class", "custom", "trail" }
ns.CHOICE_KEYS = {
    accent = ns.ACCENT_KEYS,
    colourMode = { "class", "single", "rainbow", "gradient" },
    ringColour = ns.EFFECT_COLOURS,
    castColour = ns.EFFECT_COLOURS,
    lookColour = ns.LOOK_TINTS,
}

-- Settings taken out before release, dropped from the saved settings at load.
local RETIRED = {}

local CHOICES = {}
for key, list in pairs(ns.CHOICE_KEYS) do
    CHOICES[key] = {}
    for _, value in ipairs(list) do CHOICES[key][value] = true end
end

function ns.Valid(key, value)
    local default = ns.DEFAULTS[key]
    if default == nil then return false end
    if type(default) == "boolean" then return type(value) == "boolean" end
    if CHOICES[key] then return CHOICES[key][value] == true end
    if HEX[key] then return type(value) == "string" and value:match("^%x%x%x%x%x%x$") ~= nil end
    local limits = ns.NUMBERS[key]
    if limits then
        return type(value) == "number" and value == value and value >= limits[1] and value <= limits[2]
            and (not WHOLE[key] or value == math.floor(value))
    end
    return type(value) == type(default)
end

local db
ns.loaded = {}

-- Profiles -----------------------------------------------------------------------------
-- Each character, told apart by its GUID since two can share a name, uses
-- one profile, at first its own "Name (Class) - Realm". Several characters can
-- share one, and one can be account-wide: every character uses it, new ones
-- too. The effects are the addon's own textures, so profiles can change in
-- combat too.
--
-- Your own profile is the one you picked. The Auto-switch rules
-- (AutoSwitch.lua) can show another for a while (in combat, mounted, in a
-- dungeon...) without changing your pick: the profile showing. The window
-- edits, copies, renames and shares the profile showing; picking a profile
-- by hand makes it your own and drops the rules' for now.
ns.PROFILE_MAX = 48 -- longest profile name

local active -- this character's own profile, once the character is known
local override -- the profile the rules show instead, while they do; never saved
local scratch = {} -- settings used before then; never saved

local function Profiles()
    if type(db.profiles) ~= "table" then db.profiles = {} end
    return db.profiles
end

local function Chars()
    if type(db.chars) ~= "table" then db.chars = {} end
    return db.chars
end

local function Exists(name)
    return type(name) == "string" and type(Profiles()[name]) == "table"
end

-- The Auto-switch rules' picks (AutoSwitch.lua does the switching):
--   rules       = { [rule] = profile name }, for every character
--   mountRules  = { [mount ID] = profile name, or false for None }, for every
--                 character, at most ns.MOUNT_MAX
--   talentRules = { [character GUID] = { [1] = name, [2] = name } }, each
--                 character's own, as their talents differ
--   held        = { [character GUID] = { name = profile, why = rule } }: what
--                 the rules picked when that character picked a profile by
--                 hand instead, so the pick still holds after a reload
ns.RULES = { "combat", "mounted", "pvp", "dungeon", "world", "peace" }
local HOLD_RULES = { mount = true, talent1 = true, talent2 = true }
for _, rule in ipairs(ns.RULES) do HOLD_RULES[rule] = true end
ns.MOUNT_MAX = 20
local RULE_SLOTS = {}
for _, rule in ipairs(ns.RULES) do RULE_SLOTS[rule] = true end

local function Table(key)
    if type(db[key]) ~= "table" then db[key] = {} end
    return db[key]
end

local function MountID(id)
    return type(id) == "number" and id == id and id > 0 and id < 2 ^ 31 and id == math.floor(id)
end

local function RepairPicks()
    local rules = Table("rules")
    for rule, name in pairs(rules) do
        if not RULE_SLOTS[rule] or not Exists(name) then rules[rule] = nil end
    end
    local mounts, kept = Table("mountRules"), {}
    for id, name in pairs(mounts) do
        if MountID(id) and (name == false or type(name) == "string") then
            kept[#kept + 1] = id
            if name ~= false and not Exists(name) then mounts[id] = false end
        else
            mounts[id] = nil
        end
    end
    table.sort(kept)
    for i = ns.MOUNT_MAX + 1, #kept do mounts[kept[i]] = nil end
    local talents = Table("talentRules")
    for guid, picks in pairs(talents) do
        if type(guid) ~= "string" or type(picks) ~= "table" then
            talents[guid] = nil
        else
            for group, name in pairs(picks) do
                if (group ~= 1 and group ~= 2) or not Exists(name) then picks[group] = nil end
            end
            if next(picks) == nil then talents[guid] = nil end
        end
    end
    local holds = Table("held")
    for guid, hold in pairs(holds) do
        if type(guid) ~= "string" or type(hold) ~= "table" or not Exists(hold.name) or not HOLD_RULES[hold.why] then
            holds[guid] = nil
        end
    end
    if db.eraOffered ~= true then db.eraOffered = nil end
end

-- Every rule's pick of one profile moved to a new name, or dropped (to nil;
-- a listed mount stays listed, with None).
local function MovePicks(from, to)
    local rules = Table("rules")
    for rule, name in pairs(rules) do
        if name == from then rules[rule] = to end
    end
    local mounts = Table("mountRules")
    for id, name in pairs(mounts) do
        if name == from then mounts[id] = to or false end
    end
    local talents = Table("talentRules")
    for guid, picks in pairs(talents) do
        for group, name in pairs(picks) do
            if name == from then picks[group] = to end
        end
        if next(picks) == nil then talents[guid] = nil end
    end
    local holds = Table("held")
    for guid, hold in pairs(holds) do
        if hold.name == from then
            if to then hold.name = to else holds[guid] = nil end
        end
    end
end

-- A profile's settings, repaired in place: anything it shouldn't hold, or
-- that isn't valid, goes, so the default shows instead.
local function Repair(profile)
    for key, value in pairs(profile) do
        if not ns.PROFILE_KEYS[key] or not ns.Valid(key, value) then profile[key] = nil end
    end
    return profile
end

-- The profile chosen for every character, new ones included, if there is one.
local function Everyone()
    local name = db and db.everyone
    if type(name) == "string" and type(Profiles()[name]) == "table" then return name end
end

local function RepairProfiles()
    local profiles = Profiles()
    for name, profile in pairs(profiles) do
        if type(name) ~= "string" or type(profile) ~= "table" then profiles[name] = nil else Repair(profile) end
    end
    local chars = Chars()
    for guid, name in pairs(chars) do
        if type(guid) ~= "string" or type(name) ~= "string" then chars[guid] = nil end
    end
    db.everyone = Everyone()
    RepairPicks()
end

-- The profile showing: the rules' while they show one, else this
-- character's own; nil until the character is known.
local function ShownName()
    if override and db and type(Profiles()[override]) == "table" then return override end
    return active
end

-- The profile showing's settings, or a stand-in until the character is known.
local function Current()
    local name = ShownName()
    local profile = name and db and Profiles()[name]
    return type(profile) == "table" and profile or scratch
end

local function PlayerGUID()
    local guid = UnitGUID and UnitGUID("player")
    return type(guid) == "string" and guid ~= "" and guid or nil
end

local UNKNOWN = UNKNOWNOBJECT or "Unknown"

-- Text cut to at most max bytes, never through the middle of a letter, and
-- without a space left at the end.
local function Cut(text, max)
    if #text <= max then return text end
    local cut = max
    -- A byte from 128 to 191 carries on the letter before it.
    while cut > 0 and (text:byte(cut + 1) or 0) >= 128 and (text:byte(cut + 1) or 0) < 192 do cut = cut - 1 end
    return (text:sub(1, cut):gsub("%s+$", ""))
end

-- "Name (Class) - Realm", cut to fit a profile name. On a character's very
-- first login the game may not know its name yet: nil then, unless a name is
-- needed now anyway.
local function OwnName(anyway)
    local name = UnitName and UnitName("player")
    if type(name) ~= "string" or name == "" or name == UNKNOWN then
        if not anyway then return nil end
        name = UNKNOWN
    end
    local class = UnitClass and UnitClass("player") or UNKNOWN
    if type(class) ~= "string" then class = UNKNOWN end
    local realm = GetRealmName and GetRealmName() or ""
    if type(realm) ~= "string" or realm == "" then return Cut(("%s (%s)"):format(name, class), ns.PROFILE_MAX) end
    return Cut(("%s (%s) - %s"):format(name, class, realm), ns.PROFILE_MAX)
end

-- The name itself if it's free, otherwise with a number after it, cut
-- shorter where needed so it still fits.
local function FreeName(name)
    local profiles, candidate, n = Profiles(), name, 1
    while profiles[candidate] do
        n = n + 1
        local suffix = " " .. n
        candidate = Cut(name, ns.PROFILE_MAX - #suffix) .. suffix
    end
    return candidate
end

-- Settings changed by a switch or by the window: the parts that draw them
-- listen, and hear the key that changed (nil for everything, after a
-- profile switch).
local listeners = {}

function ns.Listen(listener)
    listeners[#listeners + 1] = listener
end

local function Changed(key)
    for _, listener in ipairs(listeners) do listener(key) end
end

-- Works out this character's profile, making its own on its first login (or
-- using the one chosen for every character). A new profile waits until the
-- game knows the character's name, at login at the latest ("final").
function ns.ResolveProfile(final)
    if active then return true end
    local guid = db and PlayerGUID()
    if not guid then return false end
    local profiles, chars = Profiles(), Chars()
    local name = chars[guid]
    if not profiles[name] and Everyone() then
        name = Everyone()
        chars[guid] = name
    elseif not profiles[name] then
        local own = OwnName(final)
        if not own then return false end
        name = FreeName(own)
        profiles[name] = {}
        chars[guid] = name
    end
    active = name
    return true
end

-- The profile showing: the rules' while they show one, else your own.
function ns.ProfileName()
    return ShownName()
end

-- This character's own profile: the one picked by hand (or made for it).
function ns.OwnProfile()
    return active
end

-- The profile the Auto-switch rules show instead of your own, while they do.
function ns.Override()
    local name = ShownName()
    if name ~= nil and name ~= active then return name end
    return nil
end

function ns.ProfileNames()
    local names = {}
    if not db then return names end
    for name in pairs(Profiles()) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        if a:lower() ~= b:lower() then return a:lower() < b:lower() end
        return a < b
    end)
    return names
end

function ns.ProfileExists(name)
    return db ~= nil and Exists(name)
end

-- How many characters use a profile as their own.
function ns.ProfileUsers(name)
    local count = 0
    for _, used in pairs(db and Chars() or {}) do
        if used == name then count = count + 1 end
    end
    return count
end

-- One of a profile's settings, as it would show: its own, or the default.
function ns.ProfileSetting(name, key)
    local profile = db and type(name) == "string" and Profiles()[name]
    local value
    if type(profile) == "table" then value = profile[key] end
    if value == nil or not ns.Valid(key, value) then value = ns.DEFAULTS[key] end
    return value
end

-- Profiles change in combat too: the effects are the addon's own textures.
local function Blocked()
    if not active then return "Your profile hasn't loaded yet." end
end

-- How many characters a text has, as the name boxes count them
-- (SetMaxLetters): bytes from 128 to 191 carry on the one before them.
local function Letters(text)
    local _, more = text:gsub("[\128-\191]", "")
    return #text - more
end

local function CleanName(text)
    local name = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
    if name == "" then return nil, "Type a profile name first." end
    if Letters(name) > ns.PROFILE_MAX then return nil, "Profile names can be up to " .. ns.PROFILE_MAX .. " characters." end
    if name:find("[%c|]") then return nil, "Profile names can't use the | character." end
    return name
end

-- A profile picked by hand: it's this character's own now, the rules'
-- profile goes, and the rules hold off until what they'd pick changes.
local function Switch(name)
    Chars()[PlayerGUID()] = name
    active, override = name, nil
    if ns.AutoSwitch then ns.AutoSwitch:Held() end
    Changed(nil)
end

function ns.UseProfile(name)
    local why = Blocked()
    if why then return false, why end
    if not Profiles()[name] then return false, ('No profile is called "%s".'):format(tostring(name)) end
    if name == active and ns.Override() == nil then return true, "You're already using " .. name .. "." end
    Switch(name)
    return true, "Now using " .. name .. "."
end

-- The rules' profile shown instead of your own (nil: your own again). Only
-- AutoSwitch.lua calls this: your own pick, and every character's, stay as
-- they are. true if the profile showing changed.
function ns.SetOverride(name)
    if not db or not active then return false end
    if name ~= nil and not Exists(name) then name = nil end
    if name == active then name = nil end
    if name == override then return false end
    local before = ShownName()
    override = name
    if ShownName() == before then return false end
    Changed(nil)
    return true
end

-- Only what a profile keeps: each setting it can hold that's valid and not
-- the default.
local function Kept(settings)
    local profile = {}
    if type(settings) ~= "table" then return profile end
    for key in pairs(ns.PROFILE_KEYS) do
        local value = settings[key]
        if value ~= nil then
            local ok, valid = pcall(ns.Valid, key, value)
            if ok and valid and value ~= ns.DEFAULTS[key] then profile[key] = value end
        end
    end
    return profile
end

local function Create(text, copy)
    local why = Blocked()
    if why then return false, why end
    local name, problem = CleanName(text)
    if not name then return false, problem end
    if Profiles()[name] then return false, name .. " already exists." end
    Profiles()[name] = copy and Kept(Current()) or {}
    Switch(name)
    return true, (copy and "Copied your settings to " or "Made ") .. name .. ", and switched to it."
end

-- A new profile with every setting at its default.
function ns.NewProfile(text)
    return Create(text, false)
end

-- A new profile starting with the settings of the profile showing.
function ns.CopyProfile(text)
    return Create(text, true)
end

-- A new profile holding these settings (a shared profile, or EraUI's),
-- each checked again, under the name given or, if that's taken, the name
-- with a number after it; switched to. true, the message and the name.
function ns.NewProfileFrom(text, settings)
    local why = Blocked()
    if why then return false, why end
    local name, problem = CleanName(text)
    if not name then return false, problem end
    name = FreeName(name)
    Profiles()[name] = Kept(settings)
    Switch(name)
    return true, "Made " .. name .. ", and switched to it.", name
end

-- The account-wide profile: every character uses it, and new ones load it.
function ns.EveryoneProfile()
    return db and Everyone()
end

function ns.IsAccountWide(name)
    return name ~= nil and name == ns.EveryoneProfile()
end

-- Marks this character's own profile as account-wide (on) or takes the
-- mark off (off). On, every character known uses it now, and new ones load
-- it; only one profile has the mark. A profile the Auto-switch rules show
-- meanwhile is left showing, and this character's own pick stays as it is.
-- Off, every character keeps what it uses now, and new ones get their own
-- again.
function ns.SetAccountWide(on)
    local why = Blocked()
    if why then return false, why end
    if not on then
        local was = Everyone()
        if not was then return true, "No profile is account-wide." end
        db.everyone = nil
        return true, was .. " isn't account-wide now. Characters keep what they use; new ones get their own."
    end
    local name = active
    local chars = Chars()
    for guid in pairs(chars) do chars[guid] = name end
    chars[PlayerGUID()] = name
    db.everyone = name
    return true, name .. " is account-wide: all your characters use it now, and new ones will too."
end

-- A profile's new name, for every character using it, the account-wide mark
-- and every rule's pick.
local function Rename(from, to)
    local profiles, chars = Profiles(), Chars()
    profiles[to], profiles[from] = profiles[from], nil
    for guid, used in pairs(chars) do
        if used == from then chars[guid] = to end
    end
    if db.everyone == from then db.everyone = to end
    MovePicks(from, to)
    if active == from then active = to end
    if override == from then override = to end
    if ns.AutoSwitch then ns.AutoSwitch:ProfileMoved(from, to) end
end

-- Gives the profile showing a new name.
function ns.RenameProfile(text)
    local why = Blocked()
    if why then return false, why end
    local name, problem = CleanName(text)
    if not name then return false, problem end
    local current = ShownName()
    if name == current then return true, "That's already its name." end
    if Profiles()[name] then return false, name .. " already exists." end
    Rename(current, name)
    return true, "Renamed to " .. name .. "."
end

-- A profile made before the game knew the character's name ("Unknown
-- (Paladin)") takes the name, while it's still that character's alone.
function ns.NameUnknownProfile()
    local own = OwnName()
    if not (active and own) or active == own or Profiles()[own] then return false end
    local prefix = UNKNOWN .. " ("
    if active:sub(1, #prefix) ~= prefix or ns.ProfileUsers(active) ~= 1 then return false end
    Rename(active, own)
    return true
end

-- Whether a profile can be deleted now: true, its name and how many other
-- characters use it, or false and why. The exact name is looked up first.
function ns.CanDeleteProfile(text)
    local why = Blocked()
    if why then return false, why end
    local name = type(text) == "string" and Profiles()[text] and text
    if not name then
        local problem
        name, problem = CleanName(text)
        if not name then return false, problem end
        if not Profiles()[name] then return false, ('No profile is called "%s".'):format(name) end
    end
    local me, others = PlayerGUID(), 0
    for guid, used in pairs(Chars()) do
        if used == name and guid ~= me then others = others + 1 end
    end
    return true, name, others
end

-- Deletes the named profile. Other characters that used it are let go of:
-- at their next login they get a profile as a new character would. Rules
-- that picked it pick None. Deleting your own leaves you on a new profile of
-- your own, with every setting at its default; deleting the one the rules
-- show puts your own back until they decide again.
function ns.DeleteProfile(text)
    local ok, name = ns.CanDeleteProfile(text)
    if not ok then return false, name end
    local profiles, chars = Profiles(), Chars()
    local showing = ShownName()
    profiles[name] = nil
    for guid, used in pairs(chars) do
        if used == name then chars[guid] = nil end
    end
    if db.everyone == name then db.everyone = nil end
    MovePicks(name, nil)
    if override == name then override = nil end
    local message = "Deleted " .. name .. "."
    if name == active then
        local fresh = FreeName(OwnName(true))
        profiles[fresh] = {}
        Switch(fresh)
        message = "Deleted " .. name .. ". You're now on " .. fresh .. "."
    elseif showing == name then
        Changed(nil)
        message = "Deleted " .. name .. ". Your own profile, " .. active .. ", shows for now."
    end
    if ns.AutoSwitch then ns.AutoSwitch:ProfileMoved(name, nil) end
    return true, message
end

-- The Auto-switch rules' picks ------------------------------------------------------------
-- Only the picks: AutoSwitch.lua does the switching. A pick of a profile
-- that's gone reads as None.

local function PickError(name)
    if name ~= nil and not Exists(name) then return ('No profile is called "%s".'):format(tostring(name)) end
end

-- A rule's pick ("combat", "mounted", "pvp", "dungeon", "world" or "peace"),
-- the same for every character.
function ns.RulePick(rule)
    local name = db and RULE_SLOTS[rule] and Table("rules")[rule]
    if Exists(name) then return name end
    return nil
end

function ns.SetRulePick(rule, name)
    if not RULE_SLOTS[rule] then return false, "That isn't a rule." end
    if not db then return false, "Your profile hasn't loaded yet." end
    local problem = PickError(name)
    if problem then return false, problem end
    Table("rules")[rule] = name
    return true
end

-- The mounts listed, by ID, in order.
function ns.MountIDs()
    local ids = {}
    if not db then return ids end
    for id in pairs(Table("mountRules")) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

function ns.MountListed(id)
    return db ~= nil and MountID(id) and Table("mountRules")[id] ~= nil
end

-- A listed mount's pick, while that profile is there.
function ns.MountPick(id)
    local name = db and MountID(id) and Table("mountRules")[id]
    if Exists(name) then return name end
    return nil
end

-- Lists a mount (with None until a profile is picked), up to ns.MOUNT_MAX.
function ns.AddMount(id)
    if not db then return false, "Your profile hasn't loaded yet." end
    if not MountID(id) then return false, "That isn't a mount." end
    local mounts = Table("mountRules")
    if mounts[id] ~= nil then return true, "That mount is listed already." end
    if #ns.MountIDs() >= ns.MOUNT_MAX then return false, "Up to " .. ns.MOUNT_MAX .. " mounts can be listed." end
    mounts[id] = false
    return true
end

function ns.SetMountPick(id, name)
    if not ns.MountListed(id) then return false, "Add the mount first." end
    local problem = PickError(name)
    if problem then return false, problem end
    Table("mountRules")[id] = name or false
    return true
end

function ns.RemoveMount(id)
    if not ns.MountListed(id) then return false, "That mount isn't listed." end
    Table("mountRules")[id] = nil
    return true
end

-- This character's pick for a talent group (1 Primary, 2 Secondary).
function ns.TalentPick(group)
    local guid = db and PlayerGUID()
    local picks = guid and Table("talentRules")[guid]
    local name = type(picks) == "table" and (group == 1 or group == 2) and picks[group]
    if Exists(name) then return name end
    return nil
end

function ns.SetTalentPick(group, name)
    if group ~= 1 and group ~= 2 then return false, "There are two talent groups." end
    local guid = db and PlayerGUID()
    if not guid then return false, "Your profile hasn't loaded yet." end
    local problem = PickError(name)
    if problem then return false, problem end
    local all = Table("talentRules")
    if type(all[guid]) ~= "table" then all[guid] = {} end
    all[guid][group] = name
    if next(all[guid]) == nil then all[guid] = nil end
    return true
end

-- This character's pick by hand that the rules hold off for: what they
-- picked then and why (AutoSwitch.lua), while that profile is there.
function ns.SavedHold()
    local guid = db and PlayerGUID()
    local hold = guid and Table("held")[guid]
    if type(hold) == "table" and Exists(hold.name) and HOLD_RULES[hold.why] then return hold.name, hold.why end
    return nil
end

-- Kept (name and why), or let go of (nil).
function ns.SetSavedHold(name, why)
    local guid = db and PlayerGUID()
    if not guid then return end
    if Exists(name) and HOLD_RULES[why] then
        Table("held")[guid] = { name = name, why = why }
    else
        Table("held")[guid] = nil
    end
end

-- Every profile a rule can show (this character's talent picks among them).
function ns.RuleProfiles()
    local names, seen = {}, {}
    local function Add(name)
        if Exists(name) and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    if not db then return names end
    for _, rule in ipairs(ns.RULES) do Add(ns.RulePick(rule)) end
    for _, id in ipairs(ns.MountIDs()) do Add(ns.MountPick(id)) end
    Add(ns.TalentPick(1))
    Add(ns.TalentPick(2))
    return names
end

-- Sharing (ProfileTools.lua) ---------------------------------------------------------------

-- Whether a profile setting goes in a share string: all of them (each is a
-- tick, a number, a choice or a colour). Never the shared settings.
function ns.Shareable(key)
    return ns.PROFILE_KEYS[key] == true
end

-- A shared profile put on the profile showing, for every character using
-- it, in place of its own: each setting takes the shared one, or its default
-- where it has none. Each is checked again here.
function ns.ReplaceSettings(settings)
    local why = Blocked()
    if why then return false, why end
    if type(settings) ~= "table" then return false, "Nothing to import." end
    local profile, kept = Current(), Kept(settings)
    for key in pairs(ns.PROFILE_KEYS) do profile[key] = kept[key] end
    Changed(nil)
    return true
end

-- Reset ------------------------------------------------------------------------------------
-- Two ways back to the defaults; the window asks which first (Window.lua).

-- The profile showing: every setting it holds goes, so each shows its
-- default and every effect is off. Its name, the characters using it, the
-- account-wide mark and the rules' picks of it stay, and so do the other
-- profiles. true, the message and its name.
function ns.ResetProfile()
    local why = Blocked()
    if why then return false, why end
    local name = ShownName()
    local profile = Profiles()[name]
    for key in pairs(profile) do profile[key] = nil end
    Changed(nil)
    return true, name .. " is back to the defaults, with every effect off.", name
end

-- What Everything keeps: not settings, but what the addon has noted (the
-- notes seen, so What's new doesn't show again; EraUI's settings offered,
-- which the Profiles page still has).
local KEEP = { notesSeen = true, eraOffered = true }

-- Everything, as a first install: every profile, character, account-wide
-- mark, Auto-switch rule and hold goes, and the shared settings (the
-- window's accent, the minimap button, Auto-switch's ticks) go back to their
-- defaults. This character starts on one new profile of its own, every
-- effect off; other characters get their own at their next login. true, the
-- message and the new profile's name.
function ns.ResetEverything()
    local why = Blocked()
    if why then return false, why end
    for key in pairs(db) do
        if not KEEP[key] then db[key] = nil end
    end
    local name = FreeName(OwnName(true))
    Profiles()[name] = {}
    local guid = PlayerGUID()
    if guid then Chars()[guid] = name end
    active, override = name, nil
    if ns.AutoSwitch then ns.AutoSwitch:Forget() end
    Changed(nil)
    if ns.Theme then ns.Theme:Repaint() end
    if ns.MinimapButton then ns.MinimapButton:Apply() end
    return true, "Everything is back to the defaults: one profile, " .. name .. ", with every effect off.", name
end

-- EraUI's settings were offered as a profile once (ProfileTools.lua).
function ns.EraOffered()
    return db ~= nil and db.eraOffered == true
end

function ns.SetEraOffered()
    if db then db.eraOffered = true end
end

-- Reading and changing settings --------------------------------------------------------

function ns.Get(key)
    local value
    if ns.PROFILE_KEYS[key] then
        value = Current()[key]
    else
        value = db and db[key]
    end
    if value == nil or not ns.Valid(key, value) then value = ns.DEFAULTS[key] end
    return value
end

-- Everything lives in the saved settings, which the game writes at logout and
-- on a reload; a change is heard by the parts that draw it, and the window
-- redraws. A profile keeps only what differs from the default.
function ns.Set(key, value)
    if not db or not ns.Valid(key, value) then return end
    if ns.PROFILE_KEYS[key] then
        if value == ns.DEFAULTS[key] then value = nil end
        Current()[key] = value
    else
        db[key] = value
    end
    Changed(key)
    if ns.window and ns.window:IsShown() then ns.window:Refresh() end
end

-- What's new: the version whose notes were last shown, or passed over on a
-- first install.
function ns.NotesSeen()
    return db and type(db.notesSeen) == "string" and db.notesSeen or nil
end

function ns.SetNotesSeen(version)
    if not db then return end
    db.notesSeen = version
end

-- Escape closes the /fec window. The key is borrowed only while it's up and
-- handed back as a fight begins, since bindings cannot change in combat; this
-- keeps the addon out of the game's own Escape handling.
local escButton

-- On screen: a window left open while the interface is hidden (Alt+Z)
-- doesn't count, so Escape goes back to the game and brings the interface
-- back.
local function Shown(frame)
    return frame ~= nil and frame:IsVisible()
end

function ns.EscUpdate()
    if not escButton or InCombatLockdown() then return end
    ClearOverrideBindings(escButton)
    if Shown(ns.window) or Shown(ns.notes) then
        SetOverrideBindingClick(escButton, true, "ESCAPE", escButton:GetName())
    end
end

-- Words about Escape for a note, after a space, only out of a fight: in one
-- the key is the game's again (the tour's notes and the colour picker's).
function ns.EscapeWords(words)
    if InCombatLockdown() then return "" end
    return " " .. words
end

local function BuildEscape()
    escButton = CreateFrame("Button", "FECursorEscButton", UIParent)
    escButton:SetScript("OnClick", function()
        if Shown(ns.notes) then
            ns.notes:Hide()
        elseif ns.window and ns.window.ResetShown and ns.window:ResetShown() then
            -- The Reset question first: Escape answers Cancel.
            ns.window:CloseReset()
        elseif ns.ColourPicker and ns.ColourPicker:IsOpen() then
            -- The colour picker first: Escape puts its colour back.
            ns.ColourPicker:Cancel()
        elseif ns.Tour and ns.Tour:Active() then
            ns.Tour:Stop()
        elseif ns.window then
            ns.window:Hide()
        end
        -- Checked again here too: hiding a frame that's already off screen
        -- runs no OnHide, so the key would otherwise stay borrowed.
        ns.EscUpdate()
    end)
    escButton:RegisterEvent("PLAYER_REGEN_DISABLED")
    escButton:RegisterEvent("PLAYER_REGEN_ENABLED")
    escButton:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            ClearOverrideBindings(self)
        else
            ns.EscUpdate()
        end
    end)
end

-- Options > AddOns -------------------------------------------------------------------------

local function BuildOptionsEntry()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local canvas = CreateFrame("Frame")
    canvas:SetSize(600, 200)
    local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ns.TITLE)
    local about = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    about:SetWidth(560)
    about:SetJustifyH("LEFT")
    about:SetText("A smooth cursor trail, a ring round the cursor, cast progress round the cursor and a see-through pointer "
        .. "where the cursor comes back while you look around. Type " .. ns.SLASH .. ", click the minimap button, or click below, for the settings.")
    local open = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    open:SetSize(160, 24)
    open:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -14)
    open:SetText("Open settings")
    open:SetScript("OnClick", function() if ns.ShowWindow then ns.ShowWindow() end end)
    local category = Settings.RegisterCanvasLayoutCategory(canvas, ns.TITLE)
    Settings.RegisterAddOnCategory(category)
end

-- Startup ------------------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")

local function Load()
    ForeverEnhancedCursorDB = type(ForeverEnhancedCursorDB) == "table" and ForeverEnhancedCursorDB or {}
    db = ForeverEnhancedCursorDB
    -- An empty settings file: the addon's first login on this account.
    ns.firstInstall = next(db) == nil
    -- Everything saved is checked and repaired now, before anything uses it.
    for key, value in pairs(db) do
        if RETIRED[key] or (ns.DEFAULTS[key] ~= nil and (ns.PROFILE_KEYS[key] or not ns.Valid(key, value))) then db[key] = nil end
    end
    RepairProfiles()
    ns.ResolveProfile()

    SLASH_FECURSOR1 = ns.SLASH
    SLASH_FECURSOR2 = ns.SLASH_SPARE
    SlashCmdList.FECURSOR = function(msg)
        msg = type(msg) == "string" and msg:lower() or ""
        if msg:match("^%s*new%s*$") and ns.ShowNotes then
            ns.ShowNotes()
        elseif msg:match("^%s*reset%s*$") and ns.AskReset then
            ns.AskReset()
        elseif msg:match("^%s*tour%s*$") and ns.Tour then
            ns.Tour:Start()
        elseif msg:match("^%s*discord%s*$") and ns.ShowDiscord then
            ns.ShowDiscord()
        elseif ns.Toggle then
            ns.Toggle()
        end
    end
    BuildEscape()
    BuildOptionsEntry()

    if ns.State then ns.State:Start() end
    if ns.Engine then ns.Engine:Start() end
    if ns.Cast then ns.Cast:Start() end
    if ns.AutoSwitch then ns.AutoSwitch:Start() end
    if ns.MinimapButton then ns.MinimapButton:Start() end
    if ns.Notes then ns.Notes:Start() end
end

loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        Load()
    elseif event == "PLAYER_LOGIN" and db then
        self:UnregisterEvent("PLAYER_LOGIN")
        -- In case the character, or its name, wasn't known yet when the
        -- settings loaded: what was drawn from the stand-in is drawn again.
        if not active and ns.ResolveProfile(true) then Changed(nil) end
        if ns.NameUnknownProfile() and ns.window and ns.window:IsShown() then ns.window:Refresh() end
    end
end)
