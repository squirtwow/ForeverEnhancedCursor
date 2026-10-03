-- A mock of the game for the addon's tests, loaded with loadfile. The addon's
-- real files run in it.
--
-- Blizzard's frames here are sealed, as the addon must leave them: writing
-- any key on one is a violation, and so is calling any method but a read
-- (Get..., Is...) or HookScript. Only Blizzard's own code, run by the test as
-- the game would, may do more. Violations are recorded even when the addon
-- catches the error, and each test checks none were.
--
-- For the cursor effects: the cursor's place (H.cursor, in screen pixels) and
-- the screen's scale (H.scale) can be set; H.Frame(elapsed) moves the clock on
-- and runs every visible frame's OnUpdate, as a frame of the game does; every
-- texture made is counted (H.textures), and the calls the effects make each
-- frame are counted by method (H.counts). Cooldowns, the game's colour
-- picker (there, never to be touched), IsMouselooking (there or not), the
-- player's casts, EraUI (loaded or not) and its saved settings are stood in
-- for.
local H = {}

H.checks = 0
function H.Equal(actual, expected, label)
    H.checks = H.checks + 1
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

function H.Near(actual, expected, label, within)
    H.checks = H.checks + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > (within or 1e-6) then
        error(label .. ": expected about " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

function H.True(value, label)
    H.checks = H.checks + 1
    if not value then error(label .. ": expected true, got " .. tostring(value), 2) end
end

-- The addon's files, in the TOC's order (Tools/TestRules.mjs checks they match).
H.FILES = { "Core.lua", "Style.lua", "FromEraUI.lua", "State.lua", "Trail.lua", "Engine.lua", "Cast.lua",
    "AutoSwitch.lua", "API.lua", "Theme.lua", "PageParts.lua", "ColourPicker.lua", "Preview.lua", "TrailPage.lua",
    "ColoursPage.lua", "RingsPage.lua", "ProfileTools.lua", "ProfilesPage.lua", "AutoSwitchPage.lua", "ProfileMenu.lua",
    "Window.lua", "Tour.lua", "MinimapButton.lua", "Notes.lua" }
H.ADDON = "ForeverEnhancedCursor"

-- Secret values -------------------------------------------------------------------------

H.violations = {}
local function Violation(text)
    H.violations[#H.violations + 1] = text
end
H.Violation = Violation

local function Boom(what)
    return function()
        Violation("a secret value was " .. what)
        error("secret value " .. what, 2)
    end
end
H.SECRET = setmetatable({}, { __index = Boom("indexed"), __newindex = Boom("written into"), __eq = Boom("compared"),
    __lt = Boom("compared"), __le = Boom("compared"), __add = Boom("used in arithmetic"), __sub = Boom("used in arithmetic"),
    __mul = Boom("used in arithmetic"), __div = Boom("used in arithmetic"), __mod = Boom("used in arithmetic"),
    __pow = Boom("used in arithmetic"), __unm = Boom("used in arithmetic"), __concat = Boom("concatenated"),
    __len = Boom("measured"), __call = Boom("called"), __tostring = Boom("turned into text") })
local SECRET = H.SECRET
local function IsSecret(v) return rawequal(v, SECRET) end

-- Mock objects -----------------------------------------------------------------------------

local S = setmetatable({}, { __mode = "k" }) -- each object's state, never on the object
H.S = S
H.objects = {} -- everything made, oldest first
H.frames = {} -- frames made with CreateFrame
local Proto = {}
H.Proto = Proto
local blizzardCalling = false -- Blizzard's own code is running (not a hook of the addon's)

-- Whether the addon may call this on one of Blizzard's objects: reads and hooks only.
local function Allowed(_, key)
    if type(key) ~= "string" or not key:match("^[A-Z]") then return true end
    return key:match("^Get") ~= nil or key:match("^Is") ~= nil or key == "HookScript"
end
H.Allowed = Allowed

local function Name(obj)
    local s = S[obj]
    return s and (s.name or s.key or s.kind) or "?"
end

-- Calls counted by method, over everything (H.counts), and each object's
-- last arguments and count.
H.counts = {}
local function Record(obj, key, ...)
    local s = S[obj]
    s.last[key] = table.pack(...)
    s.calls[key] = (s.calls[key] or 0) + 1
    H.counts[key] = (H.counts[key] or 0) + 1
end

local New
New = function(kind, parent)
    local obj = {}
    S[obj] = { kind = kind, parent = parent, shown = true, last = {}, calls = {}, scripts = {}, events = {}, points = {},
        width = 0, height = 0, alpha = 1, children = {} }
    H.objects[#H.objects + 1] = obj
    if parent and S[parent] then table.insert(S[parent].children, obj) end
    setmetatable(obj, {
        __index = function(_, key)
            local s = S[obj]
            -- A frame the addon must never touch at all counts every look.
            if s.untouchable and not blizzardCalling then
                s.touched = (s.touched or 0) + 1
                Violation("looked up " .. tostring(key) .. " on Blizzard's " .. Name(obj))
            end
            if s.blizzard and not blizzardCalling and not Allowed(obj, key) then
                return function()
                    Violation("called " .. key .. " on Blizzard's " .. Name(obj))
                    error("called " .. key .. " on a Blizzard frame", 2)
                end
            end
            local method = Proto[key]
            if method then return method end
            if type(key) == "string" and key:match("^[A-Z]") then
                -- Anything else: recorded, the last call's arguments kept.
                return function(self, ...) Record(self, key, ...) end
            end
        end,
        __newindex = function(t, key, value)
            if S[t].sealed and not blizzardCalling then
                Violation("wrote key '" .. tostring(key) .. "' on Blizzard's " .. Name(t))
                error("wrote key '" .. tostring(key) .. "' on a Blizzard frame", 2)
            end
            rawset(t, key, value)
        end,
    })
    return obj
end
H.New = New

function H.Last(obj, method, i)
    local call = S[obj].last[method]
    return call and call[i or 1]
end

function H.Calls(obj, method)
    return S[obj].calls[method] or 0
end

-- Like the game: showing or hiding runs the frame's OnShow or OnHide.
local function Toggled(self, v)
    local s = S[self]
    local changed = s.shown ~= v
    s.shown = v
    H.counts[v and "Show" or "Hide"] = (H.counts[v and "Show" or "Hide"] or 0) + 1
    if changed then
        local script = s.scripts[v and "OnShow" or "OnHide"]
        if script then script(self) end
    end
end
function Proto:Show() Toggled(self, true) end
function Proto:Hide() Toggled(self, false) end
function Proto:SetShown(v) Toggled(self, v and true or false) end
function Proto:IsShown() return S[self].shown end
-- Like the game: shown, and so is everything it sits in.
function Proto:IsVisible()
    local s = S[self]
    if not s.shown then return false end
    local parent = s.parent
    return parent == nil or S[parent] == nil or parent:IsVisible()
end
function Proto:SetScript(k, fn) S[self].scripts[k] = fn end
function Proto:GetScript(k) return S[self].scripts[k] end
-- Like the game: a hook runs after the script; setting a script drops hooks.
function Proto:HookScript(k, fn)
    local old = S[self].scripts[k]
    S[self].scripts[k] = function(...)
        if old then old(...) end
        local was = blizzardCalling
        blizzardCalling = false
        fn(...)
        blizzardCalling = was
    end
end
function Proto:RegisterEvent(e)
    if H.unknownEvents and H.unknownEvents[e] then error("unknown event " .. e) end
    S[self].events[e] = true
end
function Proto:RegisterUnitEvent(e, unit)
    if H.unknownEvents and H.unknownEvents[e] then error("unknown event " .. e) end
    S[self].events[e] = unit or true
end
function Proto:UnregisterEvent(e) S[self].events[e] = nil end
function Proto:UnregisterAllEvents() S[self].events = {} end
function Proto:GetObjectType() return S[self].kind end
function Proto:GetParent() return S[self].parent end
function Proto:GetName() return S[self].name end
function Proto:IsForbidden() return false end
-- Every texture made is counted: the effects make theirs only as settings change.
H.textures = 0
function Proto:CreateTexture(_, layer)
    local t = New("Texture", self)
    S[t].layer = layer
    H.textures = H.textures + 1
    return t
end
function Proto:CreateFontString(_, layer, template)
    local text = New("FontString", self)
    S[text].template, S[text].layer = template, layer
    return text
end
-- The game refuses text on a string made with no template and given no font.
local function NeedsFont(obj, method)
    local s = S[obj]
    if s.kind == "FontString" and not s.template and not s.fontFile then
        error("FontString:" .. method .. "(): Font not set", 3)
    end
end
function Proto:SetText(t) NeedsFont(self, "SetText"); S[self].text = t end
function Proto:GetText() return S[self].text end
-- Like the game: a second point of the same name replaces the first.
function Proto:SetPoint(point, ...)
    local s = S[self]
    local entry = table.pack(point, ...)
    local replaced = false
    for i, old in ipairs(s.points) do
        if old[1] == point then
            s.points[i] = entry
            replaced = true
        end
    end
    if not replaced then s.points[#s.points + 1] = entry end
    s.calls.SetPoint = (s.calls.SetPoint or 0) + 1
    H.counts.SetPoint = (H.counts.SetPoint or 0) + 1
end
function Proto:ClearAllPoints() S[self].points = {} end
function Proto:SetAllPoints(rel) S[self].points = { table.pack("ALL", rel) } end
function Proto:SetSize(w, h)
    S[self].width, S[self].height = w, h
    Record(self, "SetSize", w, h)
end
function Proto:SetWidth(w) S[self].width = w end
function Proto:SetHeight(h) S[self].height = h end
function Proto:GetWidth() return S[self].width end
function Proto:GetHeight() return S[self].height end
function Proto:GetSize() return S[self].width, S[self].height end
function Proto:GetVerticalScroll() return S[self].scroll or 0 end
function Proto:SetVerticalScroll(v) S[self].scroll = v end
function Proto:GetEffectiveScale() return S[self].scale or 1 end
-- Where a frame's left, bottom and top edges are on the screen, once a test
-- says (S[frame].left, .bottom, .top).
function Proto:GetLeft() return S[self].left end
function Proto:GetBottom() return S[self].bottom end
function Proto:GetTop() return S[self].top end
function Proto:SetBackdropBorderColor(r, g, b, a) S[self].border = { r, g, b, a } end
function Proto:SetBackdropColor(r, g, b, a) S[self].backdrop = { r, g, b, a } end
function Proto:SetTextColor(r, g, b) S[self].colour = { r, g, b } end
function Proto:SetShadowColor(_, _, _, a) S[self].shadow = a end
function Proto:SetAlpha(a) S[self].alpha = a end
function Proto:GetAlpha() return S[self].alpha end
function Proto:GetCenter() return S[self].cx, S[self].cy end
function Proto:GetFrameLevel() return S[self].level or 1 end
function Proto:SetFrameLevel(level) S[self].level = level end
function Proto:SetFrameStrata(strata) S[self].strata = strata end
function Proto:GetFrameStrata() return S[self].strata or "MEDIUM" end
-- One line of text: about six units a letter, as H.Rect reckons it.
function Proto:GetStringWidth()
    local text = S[self].text
    return type(text) == "string" and #text * 6 or 0
end
-- Wrapped text: about six units a letter, twelve a line.
function Proto:GetStringHeight()
    local s = S[self]
    local text = type(s.text) == "string" and s.text or ""
    return math.max(1, math.ceil(#text * 6 / math.max(1, s.width))) * 12
end
function Proto:Click(button) S[self].scripts.OnClick(self, button or "LeftButton") end
-- The file, and how it's smoothed when drawn smaller (a filter mode the
-- game has, or none for its usual).
function Proto:SetTexture(t, _, _, filter)
    assert(filter == nil or filter == "LINEAR" or filter == "TRILINEAR" or filter == "NEAREST", "a filter mode the game has")
    S[self].texture, S[self].filter = t, filter
end
function Proto:GetTexture() return S[self].texture end
function Proto:SetTexCoord(...)
    local n = select("#", ...)
    assert(n == 4 or n == 8, "SetTexCoord takes 4 or 8 numbers")
    for i = 1, n do assert(type((select(i, ...))) == "number", "SetTexCoord takes numbers") end
    S[self].texCoord = { ... }
end
function Proto:SetColorTexture(r, g, b, a) S[self].color = { r, g, b, a } end
function Proto:SetVertexColor(r, g, b, a)
    for _, v in ipairs({ r, g, b }) do assert(type(v) == "number", "SetVertexColor takes numbers") end
    S[self].tint = { r, g, b, a }
    S[self].calls.SetVertexColor = (S[self].calls.SetVertexColor or 0) + 1
    H.counts.SetVertexColor = (H.counts.SetVertexColor or 0) + 1
end
function Proto:GetVertexColor()
    local t = S[self].tint
    if not t then return 1, 1, 1, 1 end
    return t[1], t[2], t[3], t[4] or 1
end
function Proto:SetRotation(angle)
    assert(type(angle) == "number", "SetRotation takes a number")
    S[self].rotation = angle
    Record(self, "SetRotation", angle)
end
function Proto:SetBlendMode(mode)
    assert(mode == "BLEND" or mode == "ADD" or mode == "DISABLE" or mode == "ALPHAKEY" or mode == "MOD", "a blend mode the game has")
    S[self].blend = mode
    Record(self, "SetBlendMode", mode)
end
function Proto:IsMouseOver() return S[self].mouseOver == true end
function Proto:EnableMouse(v) S[self].last.EnableMouse = table.pack(v); S[self].mouse = v end
function Proto:IsMouseEnabled() return S[self].mouse == true end
function Proto:SetEnabled(v) S[self].enabled = v and true or false end
function Proto:IsEnabled() return S[self].enabled ~= false end
function Proto:SetClipsChildren(v) S[self].clips = v end
function Proto:DoesClipChildren() return S[self].clips == true end
-- Text boxes.
function Proto:SetFocus() S[self].focus = true end
function Proto:ClearFocus()
    local s = S[self]
    if s.focus and s.scripts.OnEditFocusLost then s.focus = false; s.scripts.OnEditFocusLost(self) end
    s.focus = false
end
function Proto:HasFocus() return S[self].focus == true end
-- Cooldowns, as the cast ring uses one: Clear runs its done script, as the game's does.
function Proto:SetCooldown(start, duration)
    assert(type(start) == "number" and type(duration) == "number", "SetCooldown takes numbers")
    S[self].cooldown = { start, duration }
    S[self].durationObject = nil
    Record(self, "SetCooldown", start, duration)
end
function Proto:SetCooldownFromDurationObject(duration)
    if H.refuseDuration then error("the game refused the duration") end
    S[self].durationObject = duration
    S[self].cooldown = nil
end
function Proto:Clear()
    local s = S[self]
    s.cooldown, s.durationObject = nil, nil
    s.clears = (s.clears or 0) + 1
    if s.clears > 50 then error("Clear ran over and over: its done script calls it back") end
    if s.scripts.OnCooldownDone then s.scripts.OnCooldownDone(self) end
    s.clears = s.clears - 1
end
function Proto:SetReverse(v) S[self].reverse = v end
function Proto:SetSwipeColor(r, g, b, a)
    S[self].swipe = { r, g, b, a }
    Record(self, "SetSwipeColor", r, g, b, a)
end

-- Seals an object and everything in it as Blizzard's.
local function Seal(obj)
    S[obj].sealed, S[obj].blizzard = true, true
    for _, child in ipairs(S[obj].children) do Seal(child) end
end
H.Seal = Seal

-- Events -------------------------------------------------------------------------------------

function H.Fire(event, ...)
    for _, frame in ipairs(H.frames) do
        if S[frame].events[event] and S[frame].scripts.OnEvent then S[frame].scripts.OnEvent(frame, event, ...) end
    end
end

-- Timers waiting (H.timers), each with the delay it asked for (H.delays)
-- and the clock time it's due (H.dues): run all at once, as if that long
-- had passed.
function H.RunTimers()
    local due = H.timers
    H.timers, H.delays, H.dues = {}, {}, {}
    for _, timer in ipairs(due) do timer() end
end

-- The clock moved on by seconds, running each timer as it falls due, in
-- order (one a timer starts runs too, if it falls due in time).
function H.Advance(seconds)
    local target = H.clock + seconds
    while true do
        local best
        for i, due in ipairs(H.dues) do
            if due <= target + 1e-9 and (not best or due < H.dues[best]) then best = i end
        end
        if not best then break end
        local timer, due = table.remove(H.timers, best), table.remove(H.dues, best)
        table.remove(H.delays, best)
        if due > H.clock then H.clock = due end
        timer()
    end
    H.clock = target
end

-- One frame of the game: the clock moves on, then every visible frame's
-- OnUpdate runs.
function H.Frame(elapsed)
    elapsed = elapsed or 1 / 60
    H.clock = H.clock + elapsed
    local list = H.frames
    for i = 1, #list do
        local frame = list[i]
        local script = S[frame].scripts.OnUpdate
        if script and frame:IsVisible() then script(frame, elapsed) end
    end
end

-- Blizzard's own code, run by the test as the game would.
function H.Blizzard(fn, ...)
    local was = blizzardCalling
    blizzardCalling = true
    local results = table.pack(pcall(fn, ...))
    blizzardCalling = was
    if not results[1] then error(results[2], 2) end
    return table.unpack(results, 2, results.n)
end

-- The game -------------------------------------------------------------------------------------

-- Who is logged in: a GUID tells characters apart, even with the same name.
H.character = { guid = "Player-1-0001", name = "Zriel", realm = "Zephras", class = "Druid", classFile = "DRUID" }
H.CLASS_COLOURS = {
    DRUID = { r = 1, g = .49, b = .04 }, WARRIOR = { r = .78, g = .61, b = .43 }, MAGE = { r = .25, g = .78, b = .92 },
    PRIEST = { r = 1, g = 1, b = 1 }, ROGUE = { r = 1, g = .96, b = .41 }, PALADIN = { r = .96, g = .55, b = .73 },
}

-- EraUI's saved settings (a table), or nil for EraUI not installed. EraUI is
-- loaded while it has settings, unless loaded says otherwise (its settings
-- left behind, say, while the game says it isn't loaded).
function H.Era(saved, loaded)
    _G.EraUIDB = saved
    if loaded == nil then loaded = saved ~= nil end
    H.eraLoaded = loaded
end

-- Blizzard's frames: UIParent, the minimap and the colour picker, sealed.
local function BuildBlizzardFrames()
    _G.UIParent = New("Frame")
    S[UIParent].name, S[UIParent].width, S[UIParent].height, S[UIParent].cx, S[UIParent].cy = "UIParent", 1024, 768, 512, 384
    _G.Minimap = New("Frame", UIParent)
    S[Minimap].name, S[Minimap].width, S[Minimap].height, S[Minimap].cx, S[Minimap].cy = "Minimap", 140, 140, 900, 700
    S[Minimap].level = 2
    _G.GameTooltip = New("Frame", UIParent)
    S[GameTooltip].name, S[GameTooltip].shown = "GameTooltip", false
    -- The game's colour picker (Blizzard_ColorPickerFrame), there as in the
    -- game but never used: the addon has its own. Any look at it at all is a
    -- violation, a read included.
    _G.ColorPickerFrame = New("Frame", UIParent)
    S[ColorPickerFrame].name, S[ColorPickerFrame].shown, S[ColorPickerFrame].strata = "ColorPickerFrame", false, "DIALOG"
    S[ColorPickerFrame].untouchable = true
    for _, frame in ipairs({ UIParent, Minimap, GameTooltip, ColorPickerFrame }) do Seal(frame) end
    H.blizzardFrames = { UIParent, Minimap, GameTooltip, ColorPickerFrame }
end

local ADDON_GLOBALS = { "^FECursor", "^SLASH_FECURSOR", "^ForeverEnhancedCursorDB$", "^ForeverEnhancedCursorAPI$" }
local function Ours(key)
    if type(key) ~= "string" then return false end
    for _, pattern in ipairs(ADDON_GLOBALS) do
        if key:find(pattern) then return true end
    end
    return false
end
H.Ours = Ours

function H.Environment()
    -- Anything the addon made last time goes, as after a restart.
    for key in pairs(_G) do
        if Ours(key) then _G[key] = nil end
    end
    H.objects, H.frames, H.violations, H.hooks, H.hookErrors, H.timers, H.printed = {}, {}, {}, {}, {}, {}, {}
    H.counts, H.textures = {}, 0
    H.lockdown, H.clock, H.bindings = false, 100, {}
    H.unknownEvents = nil
    blizzardCalling = false
    H.delays, H.dues = {}, {}
    _G.C_Timer = { After = function(delay, fn)
        H.timers[#H.timers + 1] = fn
        H.delays[#H.timers] = delay
        H.dues[#H.timers] = H.clock + delay
    end }
    -- The cursor, in screen pixels, and the screen's scale.
    H.cursor, H.scale = { x = 0, y = 0 }, 1
    _G.GetCursorPosition = function() return H.cursor.x, H.cursor.y end
    _G.GetTime = function() return H.clock end
    _G.InCombatLockdown = function() return H.lockdown end
    H.affecting = false
    _G.UnitAffectingCombat = function(unit) return unit == "player" and H.affecting end
    -- The game's mouselook: there unless a test takes it away.
    H.mouselook = false
    _G.IsMouselooking = function() return H.mouselook end
    _G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end
    _G.RAID_CLASS_COLORS = H.CLASS_COLOURS
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.print = function(msg) H.printed[#H.printed + 1] = msg end
    _G.issecretvalue = IsSecret
    _G.ReloadUI = function() error("the addon never reloads the interface") end
    _G.C_CVar = {
        GetCVar = function() return nil end,
        SetCVar = function(name) Violation("changed the game setting " .. tostring(name)) end,
    }
    _G.SetCVar = C_CVar.SetCVar
    _G.GetCVar = C_CVar.GetCVar
    -- The character (H.character, read as it is at each call).
    _G.UnitGUID = function(unit) if unit == "player" then return H.character.guid end end
    _G.UnitName = function(unit) if unit == "player" then return H.character.name, H.character.surname end end
    _G.UnitClass = function(unit) if unit == "player" then return H.character.class, H.character.classFile end end
    _G.GetRealmName = function() return H.character.realm end
    -- The player's cast and channel: a list of UnitCastingInfo's or
    -- UnitChannelInfo's answers, or "error" for one that fails; and the
    -- game's duration for either (H.duration).
    H.castInfo, H.channelInfo, H.duration, H.refuseDuration = nil, nil, nil, false
    local function Info(info)
        if info == "error" then error("unavailable") end
        if info then return table.unpack(info) end
    end
    _G.UnitCastingInfo = function(unit) assert(unit == "player", "only the player's casts"); return Info(H.castInfo) end
    _G.UnitChannelInfo = function(unit) assert(unit == "player", "only the player's casts"); return Info(H.channelInfo) end
    _G.UnitCastingDuration = function() return H.duration end
    _G.UnitChannelDuration = function() return H.duration end
    -- Where the player is and what they ride (H.game), for the Auto-switch
    -- rules: mounted, on a flight path, the instance, the talent group, the
    -- game's mount list (each mount: name, spell, icon, active, collected)
    -- and the auras the player has, by spell.
    H.game = { mounted = false, taxi = false, inside = false, kind = "none", group = 1, groups = 2, mounts = {}, auras = {},
        fromSpell = {} }
    H.gameCalls = {}
    local function Called(name) H.gameCalls[name] = (H.gameCalls[name] or 0) + 1 end
    _G.IsMounted = function() Called("IsMounted"); return H.game.mounted end
    _G.UnitOnTaxi = function(unit) return unit == "player" and H.game.taxi end
    _G.IsInInstance = function() Called("IsInInstance"); return H.game.inside, H.game.kind end
    _G.C_SpecializationInfo = { GetActiveSpecGroup = function() return H.game.group end }
    _G.GetNumSpecGroups = function() return H.game.groups end
    _G.C_MountJournal = {
        GetMountIDs = function()
            Called("GetMountIDs")
            local ids = {}
            for id in pairs(H.game.mounts) do ids[#ids + 1] = id end
            table.sort(ids)
            return ids
        end,
        GetMountInfoByID = function(id)
            Called("GetMountInfoByID")
            local m = H.game.mounts[id]
            if not m then return nil end
            return m.name, m.spell, m.icon, m.active == true, true, 0, false, false, nil, false, m.collected ~= false, id, false
        end,
        GetMountFromSpell = function(spell) Called("GetMountFromSpell"); return H.game.fromSpell[spell] end,
    }
    _G.C_UnitAuras = { GetPlayerAuraBySpellID = function(spell)
        Called("GetPlayerAuraBySpellID")
        if H.lockdown then Violation("read a mount aura in combat") end
        if H.game.auras[spell] then return { spellId = spell } end
    end }
    _G.C_EncodingUtil = nil
    _G.CreateFrame = function(kind, name, parent, template)
        local f = New(kind, parent)
        S[f].name, S[f].template = name, template
        H.frames[#H.frames + 1] = f
        if name then _G[name] = f end
        return f
    end
    -- Post-hooks, as the game makes them.
    _G.hooksecurefunc = function(a, b, c)
        local t, key, hook = a, b, c
        if type(a) == "string" then t, key, hook = _G, a, b end
        local original = t[key]
        assert(type(original) == "function", "hooked " .. tostring(key) .. ", which isn't a function")
        local function hooked(...)
            local results = table.pack(original(...))
            local ok, err = pcall(hook, ...)
            if not ok then H.hookErrors[#H.hookErrors + 1] = tostring(err) end
            return table.unpack(results, 1, results.n)
        end
        if t == _G then _G[key] = hooked else rawset(t, key, hooked) end
        H.hooks[#H.hooks + 1] = { t = t, key = key }
    end
    _G.GameFontHighlight = { GetFont = function() return "font", 12, "" end }
    _G.SlashCmdList = {}
    -- Which addons are loaded: EraUI while H.Era says so, any other while
    -- H.addOns[name] is true (both answers, as the game gives them: loaded
    -- or loading, and loaded).
    H.eraLoaded, H.addOns = false, {}
    _G.C_AddOns = { IsAddOnLoaded = function(name)
        local on = (name == "EraUI" and H.eraLoaded == true) or (name ~= "EraUI" and H.addOns[name] == true)
        return on, on
    end }
    _G.IsAddOnLoaded = nil
    _G.ClearOverrideBindings = function(owner)
        if H.lockdown then Violation("changed a binding in combat") end
        H.bindings[owner] = nil
    end
    _G.SetOverrideBindingClick = function(owner, _, key, button)
        if H.lockdown then Violation("changed a binding in combat") end
        H.bindings[owner] = key .. ":" .. button
    end
    _G.Settings = {
        RegisterCanvasLayoutCategory = function(canvas, title) return { canvas = canvas, title = title } end,
        RegisterAddOnCategory = function(category) H.category = category end,
    }
    H.category = nil
    local function Never(what)
        return function() Violation(what); error(what, 2) end
    end
    _G.ShowUIPanel, _G.HideUIPanel = Never("opened one of Blizzard's windows"), Never("closed one of Blizzard's windows")
    _G.EraUIDB = nil
    BuildBlizzardFrames()
    -- UIParent's scale is the screen's, read as it is at each call.
    S[UIParent].scale = nil
    rawset(UIParent, "GetEffectiveScale", function() return H.scale end)
    _G.ForeverEnhancedCursorDB = nil
    _G.ForeverEnhancedCursorAPI = nil
    -- What was there before the addon loads, to find what it adds.
    H.before = {}
    for key in pairs(_G) do H.before[key] = true end
end

-- Loads the addon's files as the game does, then logs in (unless told not to).
function H.Load(saved, beforeLogin)
    local ns = {}
    _G.ForeverEnhancedCursorDB = saved
    for _, file in ipairs(H.FILES) do assert(loadfile(file))(H.ADDON, ns) end
    H.Fire("ADDON_LOADED", H.ADDON)
    if not beforeLogin then
        H.Fire("PLAYER_LOGIN")
        H.Fire("PLAYER_ENTERING_WORLD")
    end
    return ns
end

-- The global names the addon has added since the environment was set up.
function H.NewGlobals()
    local added = {}
    for key in pairs(_G) do
        if not H.before[key] then added[#added + 1] = tostring(key) end
    end
    table.sort(added)
    return added
end

-- Fights begin and end as the game says.
function H.Combat(on)
    if on then
        H.Fire("PLAYER_REGEN_DISABLED")
        H.lockdown = true
    else
        H.lockdown = false
        H.Fire("PLAYER_REGEN_ENABLED")
    end
end

-- Whether a region sits somewhere inside root.
function H.Under(region, root)
    local parent = S[region] and S[region].parent
    while parent do
        if parent == root then return true end
        parent = S[parent] and S[parent].parent
    end
    return false
end

-- Shown, and everything it sits in too.
function H.Visible(region)
    return region ~= nil and region:IsVisible()
end

-- The newest region showing this text, if any (part of its text, with part).
function H.Find(text, part)
    for i = #H.objects, 1, -1 do
        local s = S[H.objects[i]]
        if s and (rawequal(s.text, text) or (part and type(s.text) == "string" and s.text:find(text, 1, true))) then
            return H.objects[i]
        end
    end
end

-- Where a region sits against root (left, right, top, bottom; root's top
-- left is 0, 0), worked out from its points and size as the game lays it
-- out. A text with no width of its own is one line, about six units a letter.
local function At(rect, point)
    local x, y = (rect.l + rect.r) / 2, (rect.t + rect.b) / 2
    if point:find("LEFT") then x = rect.l elseif point:find("RIGHT") then x = rect.r end
    if point:find("TOP") then y = rect.t elseif point:find("BOTTOM") then y = rect.b end
    return x, y
end
function H.Rect(region, root)
    if region == root then return { l = 0, r = root:GetWidth(), t = 0, b = -root:GetHeight() } end
    local s = S[region]
    local l, r, t, b, cx, cy
    for _, p in ipairs(s.points) do
        local point, to, toPoint, x, y = p[1], p[2], p[3], p[4], p[5]
        if point == "ALL" then return H.Rect(p[2] or s.parent, root) end
        if type(to) == "number" then to, toPoint, x, y = nil, point, p[2], p[3] end
        if type(toPoint) ~= "string" then toPoint, x, y = point, p[3], p[4] end
        local ax, ay = At(H.Rect(to or s.parent, root), toPoint)
        ax, ay = ax + (x or 0), ay + (y or 0)
        if point:find("LEFT") then l = ax elseif point:find("RIGHT") then r = ax else cx = ax end
        if point:find("TOP") then t = ay elseif point:find("BOTTOM") then b = ay else cy = ay end
    end
    local width, height = s.width or 0, s.height or 0
    if s.kind == "FontString" and width == 0 then
        width, height = #tostring(s.text or "") * 6, 12
    elseif s.kind == "FontString" and height == 0 then
        height = region:GetStringHeight()
    end
    if not l and not r then l = (cx or 0) - width / 2; r = l + width end
    l, r = l or r - width, r or l + width
    if not t and not b then t = (cy or 0) + height / 2; b = t - height end
    t, b = t or b + height, b or t - height
    return { l = l, r = r, t = t, b = b }
end

-- Whether two regions overlap, against root.
function H.Overlap(a, c, root)
    local x, y = H.Rect(a, root), H.Rect(c, root)
    return x.l < y.r and y.l < x.r and x.b < y.t and y.b < x.t
end

-- A point of a region's: the anchor's name, then what SetPoint was given.
function H.Point(region, point)
    for _, entry in ipairs(S[region].points) do
        if entry[1] == point then return entry end
    end
end

-- Everything that went wrong, as one line: rule violations, hook errors and
-- anything printed.
function H.Problems()
    local list = {}
    for _, v in ipairs(H.violations) do list[#list + 1] = v end
    for _, e in ipairs(H.hookErrors) do list[#list + 1] = "hook error: " .. e end
    for _, p in ipairs(H.printed) do list[#list + 1] = "printed: " .. tostring(p) end
    return table.concat(list, " | ")
end

return H
