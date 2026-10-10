-- What's new: this version's notes, shown once after the addon updates, then
-- any time from What's new in /fec or /fec new. The releases before it
-- follow underneath. A first install has nothing new to show: the window
-- opens instead, with a welcome. Drawn in the window's flat style.
local _, ns = ...
local T = ns.Theme

-- Newest first, word for word as in CHANGELOG.txt (Tools/TestNotes.mjs checks).
-- Notes waiting for their version number are "Unreleased".
ns.NOTES = {
    {
        version = "1.0.1",
        sections = {
            { "Cursor effects", {
                "New: Cursor marker: a bullseye, crosshair, dot, diamond, star or your class icon on your pointer, sized and coloured as you like.",
            } },
            { "Look", {
                "A new purple logo, same design.",
            } },
        },
    },
    {
        version = "1.0.0",
        sections = {
            { "Cursor effects", {
                "New addon: cursor effects for WoW Forever, each off until you turn it on in /fec.",
                "Cursor trail: smooth, evenly spaced dots that fade behind the cursor, with spacing, lifetime, most dots, size, opacity and offsets.",
                "Only in combat, for the trail.",
                "Trail extras: glow, shrink as it fades, and dots turned along the path.",
                "Trail colours: your class, one colour, a rainbow, or a gradient of up to ten colours, with colours in use, phases and colour speed.",
                "Cursor ring, with opacity and class, custom or the trail's colour.",
                "Cast progress ring round the cursor, with the same choices.",
                "Cursor highlight while looking: a see-through pointer marks where the cursor comes back while you turn or move the camera.",
                "A live preview at the top of the Trail, Colours and Rings pages, with the game's own pointer.",
            } },
            { "Profiles", {
                "Profiles: new, copy, rename, delete and switch, in combat too.",
                "Account-wide: one profile for every character, new ones too.",
                "Share a profile as text, and import one as a new profile or over yours.",
                "With EraUI loaded: copy its cursor settings into a profile, offered once.",
                "Auto-switch (off at first): a profile for combat, out of combat, mounted, a mount you list (Needs testing), open world, dungeon or raid, battleground or arena, and each talent group.",
            } },
            { "Settings", {
                "/fec opens the settings, also under Options > AddOns. Hover anything and the footer says what it does.",
                "A colour picker of its own: each colour shows at once, and Cancel puts the old one back.",
                "A tour of the window, offered on a first install and on the General page.",
                "A minimap button: click for the settings, right-click for What's new.",
                "Found a bug or have an idea? The Discord button on the General page, or /fec discord.",
                "Reset on the General page, or /fec reset: this profile or everything back to the defaults, asked first.",
                "More from Squirt on the General page: Forever Enhanced Cooldown Manager, with screenshots, and Forever Enhanced Raid Frames coming soon.",
            } },
        },
    },
}

local WIDTH, HEADER = 520, 42
local TOP, FOOT = 82, 52 -- above and below the notes
local TEXT = WIDTH - 48 -- the notes' width, clear of the scroll thumb
local BULLET = 16 -- bullet text indent
local MAX_HEIGHT = 620
local HISTORY = 3 -- this version's notes and the two before

local N = {}
ns.Notes = N

-- This version's notes and the ones before, or the newest if this version has
-- none (a copy straight from the source).
local function Entries()
    local version, start = ns.Version(), 1
    for i, entry in ipairs(ns.NOTES) do
        if entry.version == version then
            start = i
            break
        end
    end
    local list = {}
    for i = start, math.min(#ns.NOTES, start + HISTORY - 1) do list[#list + 1] = ns.NOTES[i] end
    return list
end

local function Label(version)
    return version:match("^%d") and "Version " .. version or version
end

local window

local function Build()
    window = CreateFrame("Frame", "FECursorNotes", UIParent, "BackdropTemplate")
    window:SetSize(WIDTH, 400)
    window:SetPoint("CENTER", 0, 40)
    window:SetFrameStrata("FULLSCREEN_DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    T:Flat(window, T.BG, T.CONTROL_BORDER)
    T:Paint(function(accent) window:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1) end)
    window:Hide()
    -- Set before anything hooks them: setting a script later drops hooks.
    window:SetScript("OnShow", function() ns.EscUpdate() end)
    window:SetScript("OnHide", function(self)
        self:StopMovingOrSizing() -- closed mid-drag, it never hears the mouse let go
        ns.EscUpdate()
    end)
    ns.notes = window

    local header = T:TitleBar(window, HEADER)
    window.close = header.close
    local fade = T:Fade(window, T.FADE.page)
    fade:SetPoint("TOPLEFT", 1, -(HEADER + 1))
    fade:SetPoint("BOTTOMRIGHT", -1, 1)

    local entries = Entries()
    local heading = T:Heading(window, "What's new")
    heading:SetPoint("TOPLEFT", 20, -(HEADER + 18))
    window.version = T:Text(window, "GameFontHighlightSmall", T.MUTED)
    window.version:SetPoint("LEFT", heading, "RIGHT", 10, 0)
    window.version:SetText(Label(entries[1].version))

    -- The notes scroll between the heading and the footer, pinned by two
    -- corners, again once shown: a scroll frame placed any other way can
    -- draw nothing.
    local scroll = T:Scroll(window, TEXT)
    local function Pin()
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 20, -TOP)
        scroll:SetPoint("BOTTOMRIGHT", -28, FOOT)
        scroll:ScrollTo(scroll:GetVerticalScroll() or 0)
    end
    Pin()
    window:HookScript("OnShow", function() C_Timer.After(0, Pin) end)
    window.scroll = scroll
    local content = scroll.content

    -- Each row with the space above it; placed by Layout once the text has
    -- its width.
    local flow = {}
    window.flow = flow
    for index, entry in ipairs(entries) do
        local gap = 0
        if index > 1 then
            local rule = content:CreateTexture(nil, "ARTWORK")
            rule:SetHeight(1)
            T:Fill(rule, T.BORDER)
            flow[#flow + 1] = { rule = rule, gap = 22 }
            local older = T:Text(content, "GameFontHighlight", T.MUTED)
            older:SetWidth(TEXT)
            older:SetText(Label(entry.version))
            flow[#flow + 1] = { text = older, gap = 14 }
            gap = 12
        end
        for s, section in ipairs(entry.sections) do
            local title = T:Heading(content, section[1])
            title:SetWidth(TEXT)
            flow[#flow + 1] = { text = title, gap = s > 1 and 18 or gap }
            for i, item in ipairs(section[2]) do
                local text = T:Text(content, "GameFontHighlight")
                text:SetWidth(TEXT - BULLET)
                text:SetText(item)
                -- A small accent square level with the first line.
                local _, size = text:GetFont()
                local dot = content:CreateTexture(nil, "ARTWORK")
                dot:SetSize(4, 4)
                T:Paint(function(accent) T:Fill(dot, accent) end)
                flow[#flow + 1] = { text = text, indent = BULLET, dot = dot, gap = i == 1 and 8 or 6,
                    dotY = math.max(2, math.floor((size or 12) / 2) - 1) }
            end
        end
    end

    -- Rows top to bottom; the window grows to fit, up to the screen.
    function window:Layout()
        local y = 0
        for _, row in ipairs(flow) do
            y = y + row.gap
            local region = row.rule or row.text
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", row.indent or 0, -y)
            if row.dot then
                row.dot:ClearAllPoints()
                row.dot:SetPoint("TOPLEFT", 4, -(y + row.dotY))
            end
            if row.rule then
                region:SetPoint("TOPRIGHT", 0, -y)
                y = y + 1
            else
                y = y + math.max(1, row.text:GetStringHeight() or 12)
            end
        end
        content:SetHeight(math.max(1, y))
        local room = math.max(200, math.min(MAX_HEIGHT, (UIParent:GetHeight() or MAX_HEIGHT) - 40))
        self:SetHeight(math.max(200, math.min(room, TOP + y + FOOT + 12)))
        scroll:ScrollTo(scroll:GetVerticalScroll() or 0)
    end
    window:RegisterEvent("UI_SCALE_CHANGED")
    window:RegisterEvent("DISPLAY_SIZE_CHANGED")
    window:SetScript("OnEvent", function(self) if self:IsShown() then self:Layout() end end)

    -- Two short lines on the left: where to take a bug or an idea, and how to
    -- see this again. On the right Got it, then the Discord button.
    local ask = T:Text(window, "GameFontHighlightSmall")
    ask:SetPoint("BOTTOMLEFT", 20, 27)
    ask:SetText("Found a bug or have an idea?")
    local hint = T:Text(window, "GameFontHighlightSmall", T.MUTED)
    hint:SetPoint("BOTTOMLEFT", 20, 13)
    hint:SetText(ns.SLASH .. " new shows this again.")
    window.hint = hint
    local done = T:Button(window, "Got it", 100, 24)
    done:SetPoint("BOTTOMRIGHT", -16, 14)
    T:Paint(function(accent) done:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1) end)
    done:SetScript("OnClick", function() window:Hide() end)
    window.done = done
    local discord = T:Button(window, "Discord", 80, 24)
    discord:SetPoint("RIGHT", done, "LEFT", -8, 0)
    discord:SetScript("OnClick", function() if ns.ShowDiscord then ns.ShowDiscord() end end)
    window.discord, window.ask = discord, ask
end

function ns.ShowNotes()
    if #ns.NOTES == 0 then return end
    if not window then Build() end
    window:Show()
    window:Raise()
    window:Layout()
    window.scroll:ScrollTo(0)
end

-- Once per version: a moment after the first login with it, and never in
-- combat. A first install has nothing new to show: the window opens instead,
-- with a welcome in its footer.
function N:Start()
    local version, seen = ns.Version(), ns.NotesSeen()
    if seen == version then return end
    ns.SetNotesSeen(version)
    local welcome = ns.firstInstall
    if not welcome and #ns.NOTES == 0 then return end
    local events = CreateFrame("Frame")
    local due, waiting = false, false
    local function ShowWhenFree()
        if not due or InCombatLockdown() then return end
        due = false
        events:UnregisterAllEvents()
        if not welcome then return ns.ShowNotes() end
        ns.ShowWindow()
        ns.window:Say("Welcome! Hover anything here and this line says what it does.")
        ns.window:Refresh()
    end
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
        if event ~= "PLAYER_ENTERING_WORLD" then return ShowWhenFree() end
        if waiting then return end
        waiting = true
        C_Timer.After(2, function()
            due = true
            ShowWhenFree()
        end)
    end)
end
