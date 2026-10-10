-- Sharing profiles as text, the box that shows or takes the text, and
-- EraUI's cursor settings brought over as a profile (offered once).
--
-- A share string is "FEC1:" (the format's version) and the profile's own
-- settings (every one on the Trail, Colours, Rings and Marker pages, ns.Shareable),
-- with its name and the addon's version, packed by the game's own encoder
-- (C_EncodingUtil: CBOR, then Deflate, then Base64). Never the shared
-- settings (the window's accent, the minimap button), the Auto-switch rules
-- or anything of EraUI's. Reading one only unpacks data and checks each
-- setting by Core.lua's rules: nothing in a string is ever run.
local _, ns = ...
local T = ns.Theme

local P = {}
ns.ProfileTools = P

P.PREFIX, P.FORMAT = "FEC", 1
P.MAX_TEXT = 12000 -- the longest string read; a whole profile is far shorter
local MAX_DATA = 65536 -- the most a string may unpack to
local MAX_WORD = 64 -- the longest text read
local MAX_DEPTH, MAX_ITEMS = 4, 400 -- a list's deepest nesting, and the most it may hold in all
local DAMAGED = "That string is damaged or cut short. Copy the whole of it again."
P.IMPORTED = "Imported" -- a shared profile's name when it came without one

-- The game's encoder, if it has all six calls used here (named one by one,
-- never looked up by a name made of text: Tools/TestRules.mjs checks).
local function Encoder()
    local E = _G.C_EncodingUtil
    if type(E) ~= "table" then return nil end
    local calls = { E.SerializeCBOR, E.DeserializeCBOR, E.CompressString, E.DecompressString, E.EncodeBase64, E.DecodeBase64 }
    for i = 1, 6 do
        if type(calls[i]) ~= "function" then return nil end
    end
    return E
end

-- The settings a profile shares, in a set order.
local function Shared()
    local keys = {}
    for key in pairs(ns.PROFILE_KEYS) do
        if ns.Shareable(key) then keys[#keys + 1] = key end
    end
    table.sort(keys)
    return keys
end

-- A tick, a short word or a real number.
local function Plain(value)
    local kind = type(value)
    if kind == "boolean" then return true end
    if kind == "string" then return #value <= MAX_WORD end
    if kind == "number" then return value == value and value > -math.huge and value < math.huge end
    return false
end

-- A value read from a string, copied: a plain one, or a list of them (keys
-- words or numbers) a few deep and not too long. nil for anything else.
local function Copy(value, depth, count)
    if type(value) ~= "table" then
        if Plain(value) then return value end
        return nil
    end
    if depth >= MAX_DEPTH then return nil end
    local copy = {}
    for key, item in pairs(value) do
        count[1] = count[1] + 1
        if count[1] > MAX_ITEMS or not (type(key) == "string" or type(key) == "number") or not Plain(key) then return nil end
        local kept = Copy(item, depth + 1, count)
        if kept == nil then return nil end
        copy[key] = kept
    end
    return copy
end

-- The profile showing, as a share string; or nil and why not.
function P.Export()
    local E = Encoder()
    if not E then return nil, "This game can't make share strings." end
    local settings = {}
    for _, key in ipairs(Shared()) do settings[key] = ns.Get(key) end
    local data = { s = settings, a = ns.Version(), n = ns.ProfileName() }
    local ok, text = pcall(function()
        return E.EncodeBase64(E.CompressString(E.SerializeCBOR(data)))
    end)
    if not ok or type(text) ~= "string" or text == "" then return nil, "Couldn't make the string. Please report this." end
    return P.PREFIX .. P.FORMAT .. ":" .. text
end

-- A profile name from a string: plain text, cut to fit, or nil.
local function SharedName(value)
    if type(value) ~= "string" then return nil end
    local name = value:gsub("[%c|]", ""):match("^%s*(.-)%s*$")
    if name == "" then return nil end
    if #name > ns.PROFILE_MAX then name = name:sub(1, ns.PROFILE_MAX):gsub("[\128-\191]*$", ""):gsub("[\192-\255]$", "") end
    return name ~= "" and name or nil
end

-- A pasted string's profile: { settings, skipped (how many it held that this
-- version doesn't know or can't use), name (or nil) }; or nil and why not
-- (nil too for an empty box).
function P.Read(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("%s+", "")
    if text == "" then return nil end
    if #text > P.MAX_TEXT then return nil, "That's too long to be a profile from this addon." end
    local format, body = text:match("^" .. P.PREFIX .. "(%d+):(.*)$")
    format = tonumber(format)
    if not format then return nil, "That isn't a profile from this addon: those start with FEC1:" end
    if format > P.FORMAT then return nil, "That profile is from a newer version of the addon. Update it, then paste it again." end
    if format < 1 or body == "" or body:find("[^%w%+/=]") then return nil, DAMAGED end
    local E = Encoder()
    if not E then return nil, "This game can't read share strings." end
    local ok, data = pcall(function()
        local packed = E.DecodeBase64(body)
        if type(packed) ~= "string" or packed == "" then return nil end
        local raw = E.DecompressString(packed)
        if type(raw) ~= "string" or raw == "" or #raw > MAX_DATA then return nil end
        return E.DeserializeCBOR(raw)
    end)
    if not ok or type(data) ~= "table" or type(data.s) ~= "table" then return nil, DAMAGED end
    local shared = {}
    for _, key in ipairs(Shared()) do shared[key] = true end
    local settings, known, skipped = {}, 0, 0
    for key, value in pairs(data.s) do
        local kept, valid = nil, false
        if shared[key] then kept = Copy(value, 0, { 0 }) end
        if kept ~= nil then
            local good, result = pcall(ns.Valid, key, kept)
            valid = good and result == true
        end
        if valid then
            settings[key] = kept
            known = known + 1
        else
            skipped = skipped + 1
        end
    end
    if known == 0 then return nil, "That string holds no settings this addon knows." end
    return { settings = settings, skipped = skipped, name = SharedName(data.n) }
end

-- What a shared profile would change on the profile showing: { key, from,
-- to } in the window's order. A setting it leaves out goes to its default.
local ORDER = {
    -- Trail
    { "trail", "Show the cursor trail" }, { "trailCombat", "Only in combat" }, { "trailSpacing", "Dot spacing" },
    { "trailLife", "Lifetime" }, { "trailMax", "Max dots" }, { "trailAlpha", "Opacity" }, { "trailWidth", "Width" },
    { "trailHeight", "Height" }, { "trailX", "X offset" }, { "trailY", "Y offset" }, { "trailGlow", "Glow" },
    { "trailShrink", "Shrink as it fades" }, { "trailAlign", "Turn dots along the path" },
    -- Colours
    { "colourMode", "Colours" }, { "colourCount", "Colours in use" }, { "colourPhases", "Phases" },
    { "colourSpeed", "Colour speed" },
    -- Rings
    { "ring", "Cursor ring" }, { "ringSize", "Cursor ring: size" }, { "ringThickness", "Cursor ring: thickness" },
    { "ringAlpha", "Cursor ring: opacity" }, { "ringColour", "Cursor ring: colour" }, { "ringCustom", "Cursor ring: custom colour" },
    { "cast", "Cast ring" }, { "castSize", "Cast ring: size" }, { "castAlpha", "Cast ring: opacity" },
    { "castColour", "Cast ring: colour" }, { "castCustom", "Cast ring: custom colour" },
    { "look", "Highlight while looking" }, { "lookSize", "Highlight: size" }, { "lookAlpha", "Highlight: opacity" },
    { "lookColour", "Highlight: tint" }, { "lookCustom", "Highlight: custom tint" },
    { "lookRight", "Highlight: right mouse button" }, { "lookLeft", "Highlight: left mouse button" },
    { "lookPulse", "Highlight: pulse gently" },
    -- Marker
    { "marker", "Marker" }, { "markerCombat", "Marker: only in combat" }, { "markerShape", "Marker: shape" },
    { "markerSize", "Marker: size" }, { "markerAlpha", "Marker: opacity" }, { "markerColour", "Marker: colour" },
    { "markerCustom", "Marker: custom colour" },
}
-- The ten colours after Colours.
for i = ns.COLOUR_COUNT, 1, -1 do table.insert(ORDER, 15, { "colour" .. i, "Colour " .. i }) end
local LABELS, RANK = {}, {}
for i, item in ipairs(ORDER) do LABELS[item[1]], RANK[item[1]] = item[2], i end
P.ORDER = ORDER

local VALUES = {
    class = "Class", single = "One colour", rainbow = "Rainbow", gradient = "Gradient", custom = "Custom", trail = "Trail's",
}
local PERCENT = { trailAlpha = true, colourSpeed = true, ringAlpha = true, castAlpha = true, lookAlpha = true, markerAlpha = true }
local SECONDS = { trailLife = true }

-- A setting with no name here yet: its key in words ("dotSize": "Dot size").
local function Words(key)
    local words = key:gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2"):lower()
    return (words:gsub("^%l", string.upper))
end

function P.Label(key)
    return LABELS[key] or Words(key)
end

function P.Value(key, value)
    if type(value) == "boolean" then return value and "On" or "Off" end
    if type(value) == "number" then
        local text = value == math.floor(value) and ("%d"):format(value) or ("%.2f"):format(value):gsub("0$", "")
        if PERCENT[key] then return text .. "%" end
        if SECONDS[key] then return text .. " s" end
        return text
    end
    value = tostring(value)
    if ns.HEX_KEYS[key] then return "#" .. value end
    if key == "markerShape" and value == "class" then return "Class icon" end
    return VALUES[value] or Words(value)
end

function P.Changes(settings)
    local list = {}
    for _, key in ipairs(Shared()) do
        local now, new = ns.Get(key), settings[key]
        if new == nil then new = ns.DEFAULTS[key] end
        if new ~= now then list[#list + 1] = { key = key, from = now, to = new } end
    end
    table.sort(list, function(a, b)
        local x, y = RANK[a.key] or math.huge, RANK[b.key] or math.huge
        if x ~= y then return x < y end
        return a.key < b.key
    end)
    return list
end

-- One line of the list: "Colours: Class to Rainbow".
function P.Describe(change)
    return ("%s: %s to %s"):format(P.Label(change.key), P.Value(change.key, change.from), P.Value(change.key, change.to))
end

-- The share box -----------------------------------------------------------------------------
-- Over the whole window, as the "Are you sure?" dialog is. Export shows the
-- string to copy; Import takes one pasted in, lists what it would change on
-- the profile showing before anything does, then makes it a new profile
-- (named as it came, or as typed) or replaces the profile showing.

local BOX_WIDTH, BOX_HEIGHT, EXPORT_HEIGHT = 480, 360, 150
local LIST_WIDTH = BOX_WIDTH - 40 -- the changes, clear of their scroll thumb
local LIST_TOP, LIST_FOOT = 156, 48

function P.BuildBox(window)
    local shade = CreateFrame("Frame", nil, window)
    shade:SetAllPoints()
    shade:SetFrameLevel(window:GetFrameLevel() + 70)
    shade:EnableMouse(true) -- nothing behind it can be clicked meanwhile
    local dim = shade:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, .45)
    shade:Hide()
    window:Hint(shade, "Close the box first: Close, Cancel or Escape.")

    local box = CreateFrame("Frame", nil, shade, "BackdropTemplate")
    box:SetSize(BOX_WIDTH, BOX_HEIGHT)
    box:SetPoint("CENTER")
    T:Flat(box, T.PANEL, T.CONTROL_BORDER)
    box:EnableMouse(true)
    window:Hint(box, function()
        return box.mode == "export" and "Copy the text with Ctrl+C, then Close."
            or "Paste a profile, check what it changes, then make it a new profile or put it on this one."
    end)
    box.shade = shade
    box.title = T:Heading(box, "")
    box.title:SetPoint("TOPLEFT", 14, -14)
    box.detail = T:Text(box, "GameFontHighlightSmall", T.MUTED)
    box.detail:SetPoint("TOPLEFT", 14, -34)
    box.detail:SetWidth(BOX_WIDTH - 28)

    local function Close()
        box.shared, box.count, box.profile = nil, nil, nil
        shade:Hide()
    end
    box.Close = Close

    -- The string to copy: it stays as it is, selected.
    local copy = T:Input(box, "", BOX_WIDTH - 28)
    copy:SetPoint("TOPLEFT", 14, -72)
    copy:SetScript("OnTextChanged", function(self)
        if box.mode == "export" and self:GetText() ~= box.text then
            self:SetText(box.text or "")
            self:HighlightText()
        end
    end)
    copy:SetScript("OnEscapePressed", Close)
    copy:SetScript("OnEnterPressed", Close)
    window:Hint(copy, "The profile as text. Press Ctrl+C to copy it.")
    box.copy = copy

    -- The string pasted in, read as it changes.
    local paste = T:Input(box, "Paste a profile here: Ctrl+V", BOX_WIDTH - 28)
    paste:SetPoint("TOPLEFT", 14, -72)
    paste:SetMaxLetters(P.MAX_TEXT + 1)
    paste:SetScript("OnEscapePressed", Close)
    window:Hint(paste, "Paste a profile here with Ctrl+V. Nothing changes until you pick what to do with it.")
    box.paste = paste

    -- The new profile's name: the one it came with, or one typed.
    local nameLabel = T:Text(box, "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", 14, -104)
    nameLabel:SetText("New profile's name")
    local name = T:Input(box, P.IMPORTED, 240)
    name:SetPoint("TOPLEFT", 130, -100)
    name:SetMaxLetters(ns.PROFILE_MAX)
    name:SetScript("OnEscapePressed", Close)
    window:Hint(name, "The name for Make a new profile. A name already taken gets a number after it.")
    box.name, box.nameLabel = name, nameLabel

    box.status = T:Text(box, "GameFontHighlight")
    box.status:SetPoint("TOPLEFT", 14, -132)
    box.status:SetWidth(BOX_WIDTH - 28)
    box.status:SetWordWrap(false)

    -- The changes, scrolling when there are many. Pinned by two corners,
    -- again a moment after the box opens.
    local list = T:Scroll(box, LIST_WIDTH)
    local lines = T:Text(list.content, "GameFontHighlightSmall")
    lines:SetPoint("TOPLEFT", 0, 0)
    lines:SetWidth(LIST_WIDTH)
    local function Pin()
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -LIST_TOP)
        list:SetPoint("BOTTOMRIGHT", box, "TOPLEFT", 14 + LIST_WIDTH, -(BOX_HEIGHT - LIST_FOOT))
        list:ScrollTo(list:GetVerticalScroll() or 0)
    end
    Pin()
    window:Hint(list.thumb, ns.SCROLL_NOTE)
    box.list, box.lines = list, lines

    local make = T:Button(box, "Make a new profile", 130, 22)
    make:SetPoint("BOTTOMRIGHT", -14, 14)
    window:Hint(make, function()
        if not box.shared then return "Paste a profile first." end
        return "Make it a new profile and switch to it. The profile you're on stays as it is."
    end)
    local replace = T:Button(box, "Replace this profile", 130, 22)
    replace:SetPoint("RIGHT", make, "LEFT", -6, 0)
    window:Hint(replace, function()
        if not box.shared then return "Paste a profile first." end
        return "Put it on " .. (ns.ProfileName() or "your profile") .. " in place of its own settings. It asks first."
    end)
    local no = T:Button(box, "Cancel", 90, 22)
    no:SetPoint("BOTTOMLEFT", 14, 14)
    no:SetScript("OnClick", Close)
    window:Hint(no, function() return box.mode == "export" and "Close the box." or "Close the box. Nothing changes." end)
    box.make, box.replace, box.no = make, replace, no

    local function Status(text, colour)
        box.status:SetText(text)
        box.status:SetTextColor(colour[1], colour[2], colour[3])
    end
    local function List(text)
        lines:SetText(text)
        list.content:SetHeight(math.max(1, math.ceil((lines:GetStringHeight() or 0) + 4)))
        list:SetVerticalScroll(0)
        Pin()
    end
    local function Usable(button, usable)
        button.usable = usable
        button:SetEnabled(usable)
        if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
        button:SetAlpha(usable and 1 or .35)
    end

    -- Reads what's in the box, and shows what it would change on the profile
    -- showing (box.profile).
    function box:Check()
        local shared, why = P.Read(paste:GetText() or "")
        box.shared, box.count, box.profile = nil, nil, ns.ProfileName()
        local shown = {}
        local typed = name:GetText() or ""
        local auto = box.autoName ~= nil and typed == box.autoName
        if not shared then
            Status(why or "Paste a profile to see what it changes.", why and T.WARN or T.MUTED)
            -- The paste box emptied: a name a string put there goes with it.
            if auto and (paste:GetText() or "") == "" then
                ns.PageParts.SetBoxText(name, "")
                box.autoName = nil
            end
        else
            local changes = P.Changes(shared.settings)
            local profile = ns.ProfileName() or "your profile"
            if #changes == 0 then
                Status("The same as " .. profile .. ": nothing would change on it.", T.MUTED)
            else
                Status(("Against %s: %d %s."):format(profile, #changes, #changes == 1 and "difference" or "differences"), T.TEXT)
                for _, change in ipairs(changes) do shown[#shown + 1] = P.Describe(change) end
            end
            box.shared, box.count = shared.settings, #changes
            -- The string's own name, in place of one an earlier string put
            -- there; never over a name you typed.
            if not name:HasFocus() and (typed == "" or auto) then
                ns.PageParts.SetBoxText(name, shared.name or "")
                box.autoName = shared.name
            end
            if shared.skipped > 0 then
                shown[#shown + 1] = ("|cff8b8d92Left out: %d %s this version doesn't know.|r"):format(shared.skipped,
                    shared.skipped == 1 and "setting" or "settings")
            end
        end
        List(table.concat(shown, "\n"))
        Usable(make, box.shared ~= nil)
        Usable(replace, box.shared ~= nil and (box.count or 0) > 0)
    end
    paste:SetScript("OnTextChanged", function() box:Check() end)
    -- A switch while the box is open (a rule, say) changes what it would do:
    -- read again for the profile showing now.
    ns.Listen(function()
        if shade:IsShown() and box.mode == "import" then box:Check() end
    end)

    make:SetScript("OnClick", function()
        if box.mode ~= "import" or not box.shared then return end
        local typed = name:GetText() or ""
        if typed:match("^%s*$") then typed = P.IMPORTED end
        local ok, message = ns.NewProfileFrom(typed, box.shared)
        if not ok then return Status(message, T.WARN) end
        Close()
        window:Say(message)
        window:Refresh()
    end)
    replace:SetScript("OnClick", function()
        if box.mode ~= "import" or not box.shared then return end
        if box.profile ~= ns.ProfileName() then
            box:Check()
            return Status("The profile showing changed: check the list again.", T.WARN)
        end
        local settings, count, profile = box.shared, box.count, box.profile
        local users = ns.ProfileUsers(profile)
        local detail = ("%d %s to %s"):format(count, count == 1 and "setting changes" or "settings change", profile)
        if users > 1 then detail = detail .. (", for all %d characters using it"):format(users) end
        Close()
        window:Ask(('Replace "%s"?'):format(profile), detail .. ". This can't be undone.", "Replace", function()
            local ok, why = ns.ReplaceSettings(settings)
            window:Say(ok and ("Imported into %s: %d %s."):format(profile, count, count == 1 and "change" or "changes") or why)
            window:Refresh()
        end)
    end)

    function box:Open(mode, text)
        box.mode, box.text, box.shared, box.count = mode, text, nil, nil
        if window.profilePanel then window.profilePanel:Hide() end
        local export = mode == "export"
        local profile = ns.ProfileName() or "your profile"
        box.title:SetText((export and "Export a profile" or "Import a profile"):upper())
        box.detail:SetText(export and (profile .. ", as text. Press Ctrl+C to copy it, then share it or keep it.")
            or "Paste a profile someone shared. The list shows how it differs from " .. profile .. " before anything changes.")
        copy:SetShown(export)
        paste:SetShown(not export)
        name:SetShown(not export)
        nameLabel:SetShown(not export)
        box.status:SetShown(not export)
        list:SetShown(not export)
        if export then list.thumb:Hide() end
        make:SetShown(not export)
        replace:SetShown(not export)
        no:ClearAllPoints()
        if export then no:SetPoint("BOTTOMRIGHT", -14, 14) else no:SetPoint("BOTTOMLEFT", 14, 14) end
        no:SetLabel(export and "Close" or "Cancel")
        box:SetHeight(export and EXPORT_HEIGHT or BOX_HEIGHT)
        shade:Show()
        if export then
            copy:SetText(text)
            copy:HighlightText()
            copy:SetFocus()
        else
            paste:SetText("")
            paste.placeholder:Show()
            ns.PageParts.SetBoxText(name, "")
            box.autoName = nil
            box:Check()
            paste:SetFocus()
            C_Timer.After(0, Pin)
        end
    end
    window:HookScript("OnHide", Close)
    window.shareBox = box
    return box
end

-- EraUI's cursor settings ---------------------------------------------------------------------
-- Read from EraUI's saved settings (FromEraUI.lua, never changed) into a new
-- profile "From EraUI", switched to.
P.ERA_NAME = "From EraUI"

function P.CopyFromEraUI()
    local settings = ns.FromEraUI.Settings()
    if not settings then return false, "EraUI's settings can't be read: is EraUI on?" end
    local ok, message, name = ns.NewProfileFrom(P.ERA_NAME, settings)
    if not ok then return false, message end
    return true, "Copied EraUI's cursor settings into " .. name .. ", and switched to it.", name
end

-- Once per account, the first time the window opens with EraUI drawing a
-- cursor effect: an offer to bring its settings over. then runs once the
-- question is answered. true if it asked.
function P.Offer(window, after)
    if ns.EraOffered() or not ns.OwnProfile() or not ns.FromEraUI.Offerable() then return false end
    ns.SetEraOffered()
    window:Ask("Bring over your EraUI cursor settings?",
        "Makes a profile named " .. P.ERA_NAME .. " from EraUI's cursor trail, ring and cast ring, and switches to it. "
            .. "EraUI's own stay on until you turn them off in /era. The Profiles page has this too.",
        "Bring them over", function()
            local _, message = P.CopyFromEraUI()
            window:Say(message)
            window:Refresh()
        end, after, "Not now")
    return true
end
