-- Run the addon's real files against a mock game (Tools/Harness.lua): the
-- Profiles page and its tools. A profile shared as text, read only as data
-- and checked setting by setting, listed before anything changes, then made
-- a new profile or put over the one showing; the account-wide mark, on and
-- off, and new characters; and EraUI's cursor settings brought over as a
-- profile, offered once, its saved settings only ever read. The game's
-- encoder is mocked here (its own packing, a stand-in "compression" and
-- real Base64); the real one is only proven in game.
-- Run with fengari: Tools/TestProfileTools.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local MINE = "Zriel (Druid) - Zephras"

-- The game's encoder, as a stand-in --------------------------------------------------------

local function Pack(value)
    local kind = type(value)
    if kind == "boolean" then return value and "T" or "F" end
    if kind == "number" then
        if value ~= value then return "Nnan;" end
        if value == math.huge then return "Ninf;" end
        return "N" .. string.format("%.17g", value) .. ";"
    end
    if kind == "string" then return "S" .. #value .. ":" .. value end
    if kind == "table" then
        local keys, parts = {}, { "{" }
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do parts[#parts + 1] = Pack(key) .. Pack(value[key]) end
        parts[#parts + 1] = "}"
        return table.concat(parts)
    end
    error("the encoder can't take a " .. kind)
end

local function Unpack(text)
    local at = 1
    local function Value()
        local c = text:sub(at, at)
        at = at + 1
        if c == "T" then return true end
        if c == "F" then return false end
        if c == "N" then
            local stop = assert(text:find(";", at, true), "bad number")
            local word = text:sub(at, stop - 1)
            at = stop + 1
            if word == "nan" then return 0 / 0 end
            if word == "inf" then return math.huge end
            return assert(tonumber(word), "bad number")
        end
        if c == "S" then
            local stop = assert(text:find(":", at, true), "bad text")
            local length = assert(tonumber(text:sub(at, stop - 1)), "bad text")
            local word = text:sub(stop + 1, stop + length)
            assert(#word == length, "text cut short")
            at = stop + 1 + length
            return word
        end
        if c == "{" then
            local t = {}
            while text:sub(at, at) ~= "}" do
                assert(at <= #text, "list cut short")
                local key = Value()
                t[key] = Value()
            end
            at = at + 1
            return t
        end
        error("bad data")
    end
    local value = Value()
    assert(at == #text + 1, "data after the end")
    return value
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function Encode64(text)
    local out = {}
    for i = 1, #text, 3 do
        local a, b, c = text:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local chars = {}
        for j = 3, 0, -1 do
            local index = math.floor(n / 64 ^ j) % 64
            chars[#chars + 1] = B64:sub(index + 1, index + 1)
        end
        if not b then chars[3], chars[4] = "=", "=" elseif not c then chars[4] = "=" end
        out[#out + 1] = table.concat(chars)
    end
    return table.concat(out)
end
local function Decode64(text)
    if #text % 4 ~= 0 or text:find("[^%w%+/=]") then return end
    local out = {}
    for i = 1, #text, 4 do
        local n, pad = 0, 0
        for j = 0, 3 do
            local ch = text:sub(i + j, i + j)
            local index = 0
            if ch == "=" then pad = pad + 1 else index = B64:find(ch, 1, true) - 1 end
            n = n * 64 + index
        end
        local bytes = string.char(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
        out[#out + 1] = bytes:sub(1, 3 - pad)
    end
    return table.concat(out)
end

local function Encoder()
    return {
        SerializeCBOR = Pack,
        DeserializeCBOR = Unpack,
        -- "Compressed": marked and turned round. "R<n>" unpacks to a good
        -- profile padded with n letters, for a string that unpacks to far more
        -- than it is.
        CompressString = function(text) return "Z" .. text:reverse() end,
        DecompressString = function(text)
            local count = text:match("^R(%d+)$")
            if count then return Pack({ s = { ring = true, padding = ("x"):rep(tonumber(count)) } }) end
            if text:sub(1, 1) == "Z" then return text:sub(2):reverse() end
        end,
        EncodeBase64 = Encode64,
        DecodeBase64 = Decode64,
    }
end
-- A string made by hand, packed the way the addon packs one.
local function Shared(data, prefix)
    return (prefix or "FEC1:") .. Encode64("Z" .. Pack(data):reverse())
end

-- Nothing in a string is ever run: these are never called.
local ran = 0
local function Never() ran = ran + 1 end

local ns, w, P
local function Start(saved, character)
    H.Environment()
    if character then H.character = character end
    _G.C_EncodingUtil = Encoder()
    _G.C_EncodingUtil.SerializeJSON, _G.C_EncodingUtil.DeserializeJSON = Never, Never
    _G.loadstring, _G.load, _G.RunScript, _G.RunMacroText, _G.RunMacro, _G.getglobal = Never, Never, Never, Never, Never, Never
    ns = H.Load(saved)
    P = ns.ProfileTools
    H.Advance(1)
end
local function Clean(label)
    Equal(H.Problems(), "", label .. ": nothing wrong")
end
local function Typed(input, text)
    input:SetText(text)
    S[input].scripts.OnTextChanged(input, true)
end
local function Greyed(button) return S[button].alpha == .35 and S[button].enabled == false end

-- A share string --------------------------------------------------------------------------------

Start({ notesSeen = "dev" })
do
    ns.Set("trail", true)
    ns.Set("colourMode", "rainbow")
    ns.Set("trailWidth", 20)
    ns.Set("ringCustom", "3366FF")
    ns.Set("accent", "teal")
    ns.Set("autoSwitch", true)
    ns.SetRulePick("combat", MINE)
    local text = P.Export()
    Equal(type(text) == "string" and text:sub(1, 5), "FEC1:", "a profile starts with FEC1:")
    Equal(text:sub(6):find("[^%w%+/=]"), nil, "then only Base64")
    local raw = Unpack(Decode64(text:sub(6)):sub(2):reverse())
    local keys, outside = 0, {}
    for key in pairs(raw.s) do
        keys = keys + 1
        if not ns.PROFILE_KEYS[key] then outside[#outside + 1] = key end
    end
    local count = 0
    for _ in pairs(ns.PROFILE_KEYS) do count = count + 1 end
    Equal(keys .. " " .. table.concat(outside, ","), count .. " ", "every profile setting, and nothing else")
    Equal(tostring(raw.s.accent) .. " " .. tostring(raw.s.autoSwitch) .. " " .. tostring(raw.rules) .. " " .. tostring(raw.s.rules)
        .. " " .. tostring(raw.mountRules), "nil nil nil nil nil", "never the accent, the rules, mounts or picks")
    Equal(raw.n .. " " .. raw.a, MINE .. " dev", "with its name and the addon's version")
    local shared = P.Read(text)
    local same = true
    for key, value in pairs(shared.settings) do if value ~= ns.Get(key) then same = false end end
    Equal(tostring(same) .. " " .. shared.skipped .. " " .. shared.name, "true 0 " .. MINE, "read back as it was")
    Equal(#P.Changes(shared.settings), 0, "and on the same profile it changes nothing")
    ns.Set("accent", "orange")
end
Clean("export")

-- Strings that aren't a profile, or can't be read, each say why; nothing runs.
do
    local text = P.Export()
    local function Why(value)
        local shared, why = P.Read(value)
        return shared and "read" or tostring(why)
    end
    local DAMAGED = "That string is damaged or cut short. Copy the whole of it again."
    local NOT_OURS = "That isn't a profile from this addon: those start with FEC1:"
    Equal(Why(""), "nil", "an empty box says nothing")
    Equal(Why("   \n "), "nil", "nor does one of spaces")
    Equal(Why("hello"), NOT_OURS, "a word")
    Equal(Why("FECM1:" .. text:sub(6)), NOT_OURS, "the cooldown addon's strings aren't these")
    Equal(Why("FERF1:" .. text:sub(6)), NOT_OURS, "nor the raid frames'")
    Equal(Why("FEC2:" .. text:sub(6)), "That profile is from a newer version of the addon. Update it, then paste it again.", "a newer format")
    Equal(Why("FEC1:"), DAMAGED, "the prefix alone")
    Equal(Why("FEC0:" .. text:sub(6)), DAMAGED, "format 0")
    Equal(Why("FEC1:@@@@"), DAMAGED, "not Base64")
    Equal(Why(text:sub(1, -9)), DAMAGED, "cut short")
    Equal(Why("FEC1:" .. Encode64("plain text")), DAMAGED, "Base64 of something else")
    Equal(Why(text:sub(1, 30) .. "\n  " .. text:sub(31)), "read", "spaces and line breaks from a chat are ignored")
    Equal(Why("FEC1:" .. ("A"):rep(P.MAX_TEXT)), "That's too long to be a profile from this addon.", "too long")
    Equal(Why("FEC1:" .. Encode64("R100")), "read", "a string that unpacks to a little more is read")
    Equal(Why("FEC1:" .. Encode64("R70000")), DAMAGED, "unpacking to far more than any profile")
    Equal(Why(Shared({ a = "dev" })), DAMAGED, "data without settings")
    Equal(Why(Shared("just a word")), DAMAGED, "data that isn't a list")
    Equal(Why(Shared({ s = {} })), "That string holds no settings this addon knows.", "settings, but none")
    Equal(Why(Shared({ s = { accent = "blue", minimap = false, autoSwitch = true } })),
        "That string holds no settings this addon knows.", "only shared settings, never taken")
    -- Each setting checked on its own: only the good ones are kept.
    local shared = P.Read(Shared({ s = { ring = true, colourMode = "neon", trailMax = 9999, trail = "yes", made = 1,
        accent = "blue", trailWidth = 0 / 0, castSize = math.huge, colour2 = "nothex", ringCustom = ("A"):rep(80),
        cast = { 1 }, look = "os.exit()", trailLife = .5, [5] = true }, n = 42 }))
    local kept = {}
    for key, value in pairs(shared.settings) do kept[#kept + 1] = key .. "=" .. tostring(value) end
    table.sort(kept)
    Equal(table.concat(kept, " ") .. " / " .. shared.skipped, "ring=true trailLife=0.5 / 12",
        "a bad value, an unknown or shared setting each left out, and counted")
    Equal(shared.name, nil, "a name that isn't text is no name")
    Equal(P.Read(Shared({ s = { ring = true }, n = "  Raid | night\n" })).name, "Raid  night", "a name kept to plain text")
    Equal(#P.Read(Shared({ s = { ring = true }, n = ("n"):rep(60) })).name, 48, "and cut to fit")
    Equal(ran, 0, "nothing in a string is ever run")
end
Clean("bad strings")

-- The list in the window's words.
do
    local function Line(key, from, to) return P.Describe({ key = key, from = from, to = to }) end
    Equal(Line("colourMode", "class", "rainbow"), "Colours: Class to Rainbow", "a choice, as its buttons say")
    Equal(Line("trail", false, true), "Show the cursor trail: Off to On", "a tick")
    Equal(Line("trailAlpha", 55, 80), "Opacity: 55% to 80%", "a percent")
    Equal(Line("trailLife", .25, .5), "Lifetime: 0.25 s to 0.5 s", "seconds")
    Equal(Line("colour3", "FFB84D", "00FF00"), "Colour 3: #FFB84D to #00FF00", "a colour")
    Equal(Line("ringColour", "custom", "trail"), "Cursor ring: colour: Custom to Trail's", "a ring's colour")
    Equal(Line("lookColour", "none", "class"), "Highlight: tint: None to Class", "the highlight's tint (the game's pointer, untinted or washed)")
    Equal(Line("lookCustom", "FFFFFF", "FF0000"), "Highlight: custom tint: #FFFFFF to #FF0000", "and its custom tint")
    -- A string shared before the ghost pointer, with the highlight's old colour: still read, as a tint.
    local old = P.Read(Shared({ s = { look = true, lookColour = "trail", lookSize = 40, lookAlpha = 90 } }))
    Equal(old and (old.settings.lookColour .. " " .. old.settings.lookSize .. " " .. old.settings.lookAlpha), "trail 40 90",
        "an older string's highlight settings are kept")
    ns.NewProfile("Fresh")
    local shared = P.Read(Shared({ s = { ring = true, colour1 = "00FF00", trail = true, colourCount = 3, lookPulse = true } }))
    local lines = {}
    for _, change in ipairs(P.Changes(shared.settings)) do lines[#lines + 1] = P.Label(change.key) end
    Equal(table.concat(lines, " | "), "Show the cursor trail | Colour 1 | Colours in use | Cursor ring | Highlight: pulse gently",
        "in the window's order: Trail, Colours, Rings")
end
Clean("words")

-- The share box: export, then import as a new profile or over the one showing ------------------

Start({ notesSeen = "dev" })
ns.ShowWindow()
w = FECursorFrame
w:Select("profiles")
local box = w.shareBox
ns.Set("trail", true)
ns.Set("trailWidth", 24)
w.shareExport:Click()
Equal(S[box.shade].shown and box.mode, "export", "Export opens the box with the string")
local text = S[box.copy].text
Equal(text:sub(1, 5), "FEC1:", "the profile as text, ready to copy")
Equal(S[box.copy].focus, true, "selected, for Ctrl+C")
box.no:Click()
Equal(S[box.shade].shown, false, "Close")

-- Import: the list first, then a new profile with the name it came with.
ns.NewProfile("Plain")
w.shareImport:Click()
Equal(S[box.shade].shown and box.mode, "import", "Import opens the box to paste into")
True(Greyed(box.make) and Greyed(box.replace), "nothing to import yet")
Typed(box.paste, text)
Equal(S[box.status].text, "Against Plain: 2 differences.", "how it differs from the profile showing")
Equal(S[box.lines].text, "Show the cursor trail: Off to On\nWidth: 10 to 24", "listed in the window's words")
Equal(S[box.name].text, MINE, "the name it came with, ready")
Equal(ns.Get("trail"), false, "nothing changed yet")
box.make:Click()
Equal(ns.ProfileName(), MINE .. " 2", "Make a new profile: a name already taken gets a number")
Equal(tostring(ns.Get("trail")) .. " " .. ns.Get("trailWidth"), "true 24", "with the shared settings")
Equal(ForeverEnhancedCursorDB.chars[H.character.guid], MINE .. " 2", "and it's this character's profile now")
Equal(S[box.shade].shown, false, "the box closes")
Equal(S[w.note].text, "Made " .. MINE .. " 2, and switched to it.", "and the footer says so")
-- A name typed in.
w.shareImport:Click()
Typed(box.paste, text)
box.name:SetText("Party trail")
box.make:Click()
Equal(ns.ProfileName(), "Party trail", "or the name typed")
-- Strings pasted one after another: each brings its own name; a name typed stays.
w.shareImport:Click()
Typed(box.paste, Shared({ s = { ring = true }, n = "First string" }))
Equal(S[box.name].text, "First string", "the first string's name")
Typed(box.paste, Shared({ s = { trail = true }, n = "Second string" }))
Equal(S[box.name].text, "Second string", "a second string brings its own name, over the first's")
Typed(box.paste, Shared({ s = { look = true } }))
Equal(S[box.name].text .. "|" .. tostring(S[box.name.placeholder].shown), "|true", "one with no name leaves it empty, for Imported")
Typed(box.paste, Shared({ s = { ring = true }, n = "First string" }))
Typed(box.paste, "")
Equal(S[box.name].text, "", "emptying the paste box takes the string's name with it")
Typed(box.paste, Shared({ s = { ring = true }, n = "First string" }))
box.name:SetText("Typed name")
Typed(box.paste, Shared({ s = { trail = true }, n = "Second string" }))
Equal(S[box.name].text, "Typed name", "a name typed is never replaced")
Typed(box.paste, "")
Equal(S[box.name].text, "Typed name", "not even as the paste box empties")
Typed(box.paste, Shared({ s = { ring = true }, n = "First string" }))
box.name:SetText("")
Typed(box.paste, Shared({ s = { trail = true, ring = false }, n = "Second string" }))
box.make:Click()
Equal(ns.ProfileName() .. " " .. tostring(ns.Get("trail")) .. " " .. tostring(ns.Get("ring")), "Second string true false",
    "Make a new profile: the second string's settings, under its own name")
w.shareImport:Click()
Equal(S[box.name].text, "", "opened again: the name box empty")
box.no:Click()
-- Replace: asks first, then the profile showing takes the settings.
ns.UseProfile("Plain")
w.shareImport:Click()
Typed(box.paste, Shared({ s = { ring = true, ringSize = 80 }, n = "Ring" }))
Equal(S[box.lines].text, "Cursor ring: Off to On\nCursor ring: size: 48 to 80", "what it changes on Plain")
box.replace:Click()
Equal(S[w.confirm.shade].shown, true, "Replace asks first")
Equal(ns.Get("ring"), false, "nothing changed yet")
w.confirm.yes:Click()
Equal(tostring(ns.Get("ring")) .. " " .. ns.Get("ringSize") .. " " .. ns.ProfileName(), "true 80 Plain", "Plain takes them")
local held = {}
for key in pairs(ForeverEnhancedCursorDB.profiles.Plain) do held[#held + 1] = key end
table.sort(held)
Equal(table.concat(held, " "), "ring ringSize", "only what isn't a default is kept")
-- Cancel changes nothing.
w.shareImport:Click()
Typed(box.paste, text)
box.no:Click()
Equal(ns.Get("trail"), false, "Cancel: nothing changes")
-- The same settings: nothing to replace.
w.shareImport:Click()
Typed(box.paste, Shared({ s = { ring = true, ringSize = 80 } }))
Equal(S[box.status].text, "The same as Plain: nothing would change on it.", "the same: it says so")
True(Greyed(box.replace) and not Greyed(box.make), "Replace greyed, but it can still be a new profile")
box.no:Click()
Clean("box")

-- The account-wide mark --------------------------------------------------------------------------

do
    local saved = ForeverEnhancedCursorDB
    saved.chars["Player-1-0009"] = "Plain"
    ns.UseProfile("Party trail")
    w:Select("profiles")
    Equal(w.accountWide:GetChecked(), false, "no profile account-wide at first")
    w.accountWide:Click()
    Equal(S[w.confirm.shade].shown, true, "ticking asks first")
    Equal(w.accountWide:GetChecked(), false, "and stays unticked meanwhile")
    w.confirm.yes:Click()
    Equal(ns.EveryoneProfile(), "Party trail", "account-wide")
    Equal(saved.chars["Player-1-0009"] .. " " .. saved.chars[H.character.guid], "Party trail Party trail", "every character uses it")
    Equal(w.accountWide:GetChecked(), true, "ticked")
    -- Another character picks its own: the mark stays.
    -- A new character loads it.
    Start(saved, { guid = "Player-1-0010", name = "Brann", realm = "Zephras", class = "Warrior", classFile = "WARRIOR" })
    Equal(ns.ProfileName(), "Party trail", "a new character loads the account-wide profile")
    ns.UseProfile("Plain")
    Equal(ns.EveryoneProfile(), "Party trail", "picking another on one character leaves the mark alone")
    -- Off: characters keep what they use, new ones get their own.
    ns.UseProfile("Party trail")
    ns.ShowWindow()
    w = FECursorFrame
    w:Select("profiles")
    w.accountWide:Click()
    Equal(S[w.confirm.shade].shown, false, "unticking doesn't ask")
    Equal(ns.EveryoneProfile(), nil, "the mark is off")
    Equal(ForeverEnhancedCursorDB.chars["Player-1-0009"], "Party trail", "characters keep what they use")
    Start(ForeverEnhancedCursorDB, { guid = "Player-1-0011", name = "Mira", realm = "Zephras", class = "Mage", classFile = "MAGE" })
    Equal(ns.ProfileName(), "Mira (Mage) - Zephras", "a new character gets its own again")
    -- The header menu shows the tag, and its tick does the same.
    ns.ShowWindow()
    w = FECursorFrame
    w.profileButton:Click()
    w.profileEveryone:Click()
    w.confirm.yes:Click()
    Equal(ns.EveryoneProfile(), "Mira (Mage) - Zephras", "the header menu's tick marks it too")
    w.profileButton:Click()
    local tag
    for _, obj in ipairs(H.objects) do
        if rawget(obj, "profile") == "Mira (Mage) - Zephras" and rawget(obj, "users") and S[obj].shown then tag = S[obj.users].text end
    end
    Equal(tag, "account-wide", "and its list says account-wide")
    H.character = { guid = "Player-1-0001", name = "Zriel", realm = "Zephras", class = "Druid", classFile = "DRUID" }
end
Clean("account-wide")

-- Page: Manage, from the Profiles page --------------------------------------------------------------

Start({ notesSeen = "dev" })
ns.ShowWindow()
w = FECursorFrame
w:Select("profiles")
w.profilesInput:SetText("Raiding")
w.profilesActions.new:Click()
Equal(ns.ProfileName(), "Raiding", "New, from the Profiles page")
Equal(S[w.profilesInput].text, "", "the box empties")
w.profilesInput:SetText("Raid night")
w.profilesActions.rename:Click()
Equal(ns.ProfileName(), "Raid night", "Rename")
w.profilesActions.delete:Click()
Equal(S[w.confirm.shade].shown, true, "Delete asks first")
w.confirm.yes:Click()
Equal(ForeverEnhancedCursorDB.profiles["Raid night"], nil, "then deletes")
w.profilesPicker:Click()
local list = w.pages.profiles.pickList
Equal(S[list].shown, true, "the picker lists the profiles")
w.profilesPicker:Click()
Equal(S[list].shown, false, "and closes again")
Clean("manage")

-- EraUI's cursor settings -----------------------------------------------------------------------------

local ERA = {
    enabled = true, darkMode = true, cursorTrail = true, cursorTrailClassColour = false, cursorTrailColour = "33cc99",
    cursorTrailSize = 20, cursorTrailOpacity = 70, cursorTrailLength = 40, cursorRing = true, cursorRingClassColour = true,
    cursorRingSize = 64, cursorRingThickness = 4, cursorCastRing = false, cursorCastClassColour = false,
    cursorCastColour = "FF0000", cursorCastSize = 90, cursorCastOpacity = 60,
}
local function Copy(t)
    local out = {}
    for key, value in pairs(t) do out[key] = value end
    return out
end
local function Same(a, b)
    for key, value in pairs(a) do if b[key] ~= value then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
-- Where each part of the Profiles page sits, top to bottom ("-" if hidden).
local function Tops(page)
    local tops = {}
    for _, section in ipairs(page.sections) do
        tops[#tops + 1] = S[section].shown and tostring(H.Point(section, "TOPLEFT")[3]) or "-"
    end
    return table.concat(tops, " ")
end

do
    local era = Copy(ERA)
    H.Environment()
    _G.C_EncodingUtil = Encoder()
    H.Era(era)
    ns = H.Load(nil)
    local settings = ns.FromEraUI.Settings()
    local list = {}
    for key, value in pairs(settings) do list[#list + 1] = key .. "=" .. tostring(value) end
    table.sort(list)
    Equal(table.concat(list, " "), "cast=false castAlpha=60 castColour=custom castCustom=FF0000 castSize=90 colour1=33CC99 "
        .. "colourMode=single ring=true ringColour=class ringSize=64 ringThickness=4 trail=true trailAlpha=70 trailHeight=20 "
        .. "trailLife=0.4 trailSpacing=8 trailWidth=20", "EraUI's settings in this addon's: the trail's size sets width, height and spacing")
    -- Offered once, as the window first opens.
    ns.ShowWindow()
    w = FECursorFrame
    Equal(S[w.confirm.shade].shown, true, "the window opens with the offer")
    Equal(S[w.confirm.dialog.title].text, "Bring over your EraUI cursor settings?", "asking")
    Equal(S[w.confirm.no.label].text, "Not now", "or not now")
    w.confirm.yes:Click()
    Equal(ns.ProfileName(), "From EraUI", "a profile From EraUI, switched to")
    Equal(tostring(ns.Get("trail")) .. " " .. ns.Get("colour1") .. " " .. ns.Get("ringSize") .. " " .. ns.Get("castCustom"),
        "true 33CC99 64 FF0000", "with EraUI's settings")
    True(Same(era, ERA), "EraUI's settings never changed")
    Equal(H.Visible(FECursorTour), true, "then a first install's welcome to the tour")
    FECursorTour.skip:Click()
    w:Hide()
    ns.ShowWindow()
    Equal(S[w.confirm.shade].shown, false, "offered once only")
    Equal(ForeverEnhancedCursorDB.eraOffered, true, "kept for the account")
    -- From the Profiles page too, any time.
    w:Select("profiles")
    Equal(H.Visible(w.copyEra), true, "the Profiles page has it while EraUI's settings can be read")
    Equal(Tops(w.pages.profiles), "-16 -124 -238 -320", "From EraUI last, under Share")
    -- A part hidden: the ones under it close up.
    w.pages.profiles.sections[3]:Hide()
    w:Refresh()
    Equal(Tops(w.pages.profiles), "-16 -124 - -238", "the page closes up round a hidden part")
    w.pages.profiles.sections[3]:Show()
    w:Refresh()
    Equal(Tops(w.pages.profiles), "-16 -124 -238 -320", "and opens again")
    w.copyEra:Click()
    Equal(ns.ProfileName(), "From EraUI 2", "a second copy gets a number")
    True(Same(era, ERA), "still never changed")
    -- Not now: nothing made.
    H.Environment()
    H.Era(Copy(ERA))
    ns = H.Load({ notesSeen = "dev" })
    ns.ShowWindow()
    FECursorFrame.confirm.no:Click()
    Equal(ns.ProfileName(), MINE, "Not now: nothing made")
    Equal(ForeverEnhancedCursorDB.eraOffered, true, "and not asked again")
    -- EraUI's effects all off: no offer. EraUI not there: no offer, no section.
    era = Copy(ERA)
    era.cursorTrail, era.cursorRing, era.cursorCastRing = false, false, false
    H.Environment()
    H.Era(era)
    ns = H.Load({ notesSeen = "dev" })
    ns.ShowWindow()
    Equal(S[FECursorFrame.confirm.shade].shown, false, "EraUI's effects off: nothing to offer")
    Equal(ForeverEnhancedCursorDB.eraOffered, nil, "so it can still offer later")
    H.Environment()
    ns = H.Load({ notesSeen = "dev" })
    ns.ShowWindow()
    Equal(S[FECursorFrame.confirm.shade].shown, false, "no EraUI: no offer")
    FECursorFrame:Select("profiles")
    Equal(H.Visible(FECursorFrame.copyEra), false, "and no From EraUI section")
    Equal(Tops(FECursorFrame.pages.profiles), "-16 -124 -238 -", "the rest where they always are, nothing left under them")
    Equal(select(2, ns.ProfileTools.CopyFromEraUI()), "EraUI's settings can't be read: is EraUI on?", "the copy says why")
    -- EraUI's settings there, but the game says EraUI isn't loaded: nothing
    -- of EraUI's shows.
    H.Environment()
    H.Era(Copy(ERA), false)
    ns = H.Load({ notesSeen = "dev" })
    ns.ShowWindow()
    Equal(S[FECursorFrame.confirm.shade].shown, false, "EraUI not loaded: no offer, whatever its settings say")
    FECursorFrame:Select("profiles")
    Equal(H.Visible(FECursorFrame.copyEra), false, "no From EraUI section")
    Equal(tostring(ns.FromEraUI.Drawing("trail")) .. " " .. tostring(ns.FromEraUI.Settings()), "false nil", "nothing read")
    -- Asked the game's older way, where it has no C_AddOns.
    _G.C_AddOns = nil
    _G.IsAddOnLoaded = function(name) return name == "EraUI" end
    FECursorFrame:Refresh()
    Equal(H.Visible(FECursorFrame.copyEra), true, "the older IsAddOnLoaded: loaded, so the section shows")
    _G.IsAddOnLoaded = function() error("not now") end
    Equal(ns.FromEraUI.Loaded(), false, "a question that fails counts as not loaded")
    _G.IsAddOnLoaded = nil
    Equal(ns.FromEraUI.Loaded(), false, "and no way to ask: not loaded")
    -- Junk in EraUI's settings: its defaults instead.
    H.Environment()
    H.Era({ cursorTrail = "yes", cursorTrailSize = "big", cursorRing = true, cursorTrailOpacity = 0 / 0, cursorRingSize = 999 })
    ns = H.Load({ notesSeen = "dev" })
    local junk = ns.FromEraUI.Settings()
    Equal(tostring(junk.trail) .. " " .. junk.trailWidth .. " " .. junk.trailAlpha .. " " .. tostring(junk.ringSize),
        "false 10 55 nil", "EraUI's own defaults for anything odd, and nothing out of range")
end
Clean("EraUI")

io.stdout:write("TestProfileTools: " .. H.checks .. " checks passed\n")
