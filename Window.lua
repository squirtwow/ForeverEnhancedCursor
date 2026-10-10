-- The /fec window: the pages listed down the left (Trail, Colours, Rings and Marker,
-- then Profiles, Auto-switch and General), the chosen page filling the rest,
-- the preview across the top of the effects' pages, the profile menu in the
-- header and a footer that explains whatever the mouse is over. Drawn in the
-- flat charcoal Theme style.
local _, ns = ...
local T = ns.Theme
local P = ns.PageParts

local WIDTH, HEIGHT = 820, 560
local HEADER, FOOTER, NAV = 42, 28, 180
local HEART = "Heart.tga" -- white on clear, tinted to the accent in the footer's credit
local SWATCH, SWATCH_GAP = 20, 6
-- A list's scroll thumb, wherever there's one: the profiles.
ns.SCROLL_NOTE = "Drag to scroll the list, or turn the mouse wheel over it."

local function Version()
    local version = ns.Version()
    return version == "dev" and version or "v" .. version
end

-- A link to copy, in the window's own look: an addon can't open a web page
-- itself. The link stays as it is, selected.
local COPY = "Press Ctrl+C to copy, then paste it into your browser."
local copyBox
local function CopyLink(title, url, note)
    if not copyBox then
        local box = CreateFrame("Frame", "FECursorCopyLink", UIParent, "BackdropTemplate")
        box:SetSize(420, 136)
        box:SetPoint("CENTER", 0, 120)
        box:SetFrameStrata("FULLSCREEN_DIALOG")
        box:SetToplevel(true)
        box:EnableMouse(true)
        T:Flat(box, T.BG, T.CONTROL_BORDER)
        T:Paint(function(accent) box:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1) end)
        box.title = T:Heading(box, "")
        box.title:SetPoint("TOPLEFT", 16, -16)
        box.note = T:Text(box, "GameFontHighlightSmall", T.MUTED)
        box.note:SetPoint("TOPLEFT", 16, -36)
        box.note:SetWidth(388)
        box.input = T:Input(box, "", 388)
        box.input:SetPoint("TOPLEFT", 16, -72)
        box.input:SetScript("OnTextChanged", function(self)
            if self:GetText() ~= box.url then
                self:SetText(box.url or "")
                self:HighlightText()
            end
        end)
        box.input:SetScript("OnEscapePressed", function() box:Hide() end)
        box.input:SetScript("OnEnterPressed", function() box:Hide() end)
        local close = T:Button(box, "Close", 90, 22)
        close:SetPoint("BOTTOMRIGHT", -16, 12)
        close:SetScript("OnClick", function() box:Hide() end)
        box.close = close
        copyBox = box
    end
    copyBox.url = url
    copyBox.title:SetText(title:upper())
    copyBox.note:SetText(note or COPY)
    copyBox:Show()
    copyBox:Raise()
    copyBox.input:SetText(url)
    copyBox.input:HighlightText()
    copyBox.input:SetFocus()
end
ns.DISCORD_URL = "https://discord.gg/FVfcDWJncr"

-- The Discord invite, ready to copy: from the General page and /fec discord.
function ns.ShowDiscord()
    CopyLink("Join the Discord", ns.DISCORD_URL, "Found a bug or have an idea? " .. COPY)
end

-- More from Squirt -----------------------------------------------------------------------------
-- Squirt's other Forever Enhanced addons, at the foot of the General page:
-- each with its icon (this addon's own copy, so it shows without that addon
-- too), a line about it and where it stands. One you have opens from here,
-- as its own command does; one you don't has its links to copy; one still
-- being made says Coming soon, with nothing to get or open yet. shots: two
-- pictures from its own page, small at the top right of its panel, installed
-- or not (Tools/GenerateShots.mjs makes them: each texture is SHOT_SIZE
-- square, the picture across its top, height tall).
local MORE = {
    {
        key = "fecm", addon = "ForeverEnhancedCooldownManager", name = "Forever Enhanced Cooldown Manager",
        icon = "FECMIcon.tga", slash = "FECM", command = "/fecm", frame = "FECMFrame",
        about = "A cleaner Cooldown Manager and resource display, with cooldown, buff and cast bars of your own.",
        links = {
            { label = "CurseForge", url = "https://www.curseforge.com/wow/addons/forever-enhanced-cooldown-manager",
                note = COPY .. " On CurseForge, Install opens the CurseForge app." },
            { label = "GitHub", url = "https://github.com/squirtwow/ForeverEnhancedCooldownManager" },
        },
        shots = {
            { file = "FECMShotLayout.tga", height = 349, caption = "The Layout page", note = "its Layout page" },
            { file = "FECMShotInGame.tga", height = 392, caption = "In game: bars, resource display and cast bar",
                note = "its bars, resource display and cast bar in game" },
        },
    },
    {
        key = "ferf", name = "Forever Enhanced Raid Frames", icon = "FERFIcon.tga", soon = true,
        about = "A cleaner look for Blizzard's raid frames, with health text and icons for HoTs, shields and debuffs.",
    },
}
local MORE_HEIGHT, MORE_GAP = 80, 8 -- each addon's panel, and between them
local MORE_ABOUT = 334 -- the line about it, clear of the buttons (or pictures) on the right
local MORE_BUTTONS = 10 -- under the pictures, the buttons' row this far up from the foot
local SHOT_SIZE = 512 -- each picture's texture, square, the picture across its top
local SHOT_THUMB, SHOT_GAP = 62, 8 -- a thumbnail's height (as wide as its shape says), and between them
local SHOT_PAD = 8 -- round the full-size picture
-- A panel with pictures: them at the top, the buttons' row under them.
local MORE_TALL = 12 + SHOT_THUMB + 2 + 8 + 22 + MORE_BUTTONS

-- Whether the game says an addon is loaded (its older way too, where it
-- has no C_AddOns); no answer is no.
local function Loaded(addon)
    local check = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if type(check) ~= "function" then return false end
    local ok, loaded = pcall(check, addon)
    return ok and loaded and true or false
end

-- Opens an addon's settings by its own command (closing this window), or
-- says to type it if the command isn't there. Its window already open stays
-- open: the command would close it again.
local function OpenOther(window, info)
    local run = SlashCmdList and SlashCmdList[info.slash]
    if type(run) ~= "function" then
        window:Say("Type " .. info.command .. " to open it.")
        return window:Refresh()
    end
    window:Hide()
    local theirs = info.frame and _G[info.frame]
    if type(theirs) == "table" and type(theirs.IsShown) == "function" and theirs:IsShown() then return end
    run("")
end

-- The full-size picture, one for every thumbnail: over the window, to the
-- left of the thumbnails (left: their left edge on the page) and halfway
-- down the page, so it stays inside the window and never covers them. It
-- takes no mouse, so the thumbnail under the mouse keeps it.
local function BuildShotView(window, page, left)
    local view = CreateFrame("Frame", nil, window, "BackdropTemplate")
    view:SetFrameLevel(window:GetFrameLevel() + 85) -- over the page and the tour, under the Reset question
    view:SetClampedToScreen(true)
    T:Flat(view, T.BG, T.CONTROL_BORDER)
    T:Paint(function(accent) view:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1) end)
    view:SetPoint("RIGHT", page, "TOPLEFT", left - SHOT_GAP, -page:GetHeight() / 2)
    view.picture = view:CreateTexture(nil, "ARTWORK")
    view.picture:SetPoint("TOPLEFT", SHOT_PAD, -SHOT_PAD)
    view.caption = T:Text(view, "GameFontHighlightSmall")
    view:Hide()
    local function Edge(thumb, colour)
        thumb:SetBackdropBorderColor(colour[1], colour[2], colour[3], 1)
    end
    -- Shows a thumbnail's picture, full size, with its caption under it,
    -- the thumbnail's border lit.
    function view:Open(thumb)
        local shot = thumb.shot
        if self.owner and self.owner ~= thumb then Edge(self.owner, T.CONTROL_BORDER) end
        self.owner = thumb
        Edge(thumb, T:Accent())
        self.picture:SetTexture(ns.MEDIA .. shot.file)
        self.picture:SetTexCoord(0, 1, 0, shot.height / SHOT_SIZE)
        self.picture:SetSize(SHOT_SIZE, shot.height)
        self.caption:ClearAllPoints()
        self.caption:SetPoint("TOPLEFT", SHOT_PAD, -(SHOT_PAD + shot.height + 6))
        self.caption:SetText(shot.caption)
        self:SetSize(SHOT_SIZE + 2 * SHOT_PAD, shot.height + 2 * SHOT_PAD + 6 + 12)
        self:Show()
    end
    -- Only the thumbnail it shows can close it, whichever order the game
    -- sends one's leave and the next one's enter; nil closes it whatever.
    function view:Close(thumb)
        if thumb and self.owner ~= thumb then return end
        if self.owner then Edge(self.owner, T.CONTROL_BORDER) end
        self.owner = nil
        self:Hide()
    end
    -- Gone with the page or the window, so it never shows unasked.
    page:HookScript("OnHide", function() view:Close() end)
    window:HookScript("OnHide", function() view:Close() end)
    window.shotView = view
    return view
end

-- An addon's pictures at the top right of its panel (panelLeft: its left
-- edge on the page), the same height side by side, each in a thin border
-- that lights in the accent while the mouse is on it and its picture shows
-- full size. Drawn from the full-size texture, smoothed (the game's smaller
-- copies of it) so they don't sparkle.
local function BuildShots(window, page, panel, info, panelLeft)
    panel.shots = {}
    local right = -12 -- the next one's right edge, from the panel's
    for i = #info.shots, 1, -1 do
        local shot = info.shots[i]
        local wide = math.floor(SHOT_THUMB * SHOT_SIZE / shot.height + .5)
        local thumb = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        thumb:SetSize(wide + 2, SHOT_THUMB + 2)
        thumb:SetPoint("TOPRIGHT", right, -12)
        T:Flat(thumb, T.FIELD, T.CONTROL_BORDER)
        thumb:EnableMouse(true)
        thumb.shot = shot
        thumb.picture = thumb:CreateTexture(nil, "ARTWORK")
        thumb.picture:SetPoint("TOPLEFT", 1, -1)
        thumb.picture:SetPoint("BOTTOMRIGHT", -1, 1)
        thumb.picture:SetTexture(ns.MEDIA .. shot.file, nil, nil, "TRILINEAR")
        thumb.picture:SetTexCoord(0, 1, 0, shot.height / SHOT_SIZE)
        panel.shots[i] = thumb
        right = right - wide - 2 - SHOT_GAP
    end
    local left = panelLeft + panel:GetWidth() + right + SHOT_GAP -- the first one's left edge on the page
    local view = window.shotView or BuildShotView(window, page, left)
    for _, thumb in ipairs(panel.shots) do
        thumb:SetScript("OnEnter", function(self) view:Open(self) end)
        thumb:SetScript("OnLeave", function(self) view:Close(self) end)
        thumb:SetScript("OnHide", function(self) view:Close(self) end)
        window:Hint(thumb, info.name .. ": " .. thumb.shot.note .. ", shown full size while the mouse is on it.")
    end
end

local function BuildMore(window, page, top, width)
    T:Heading(page, "More from Squirt"):SetPoint("TOPLEFT", 16, top)
    window.more = {}
    local y = top - 18
    for _, info in ipairs(MORE) do
        local height = info.shots and MORE_TALL or MORE_HEIGHT
        local panel = CreateFrame("Frame", nil, page, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", 16, y)
        panel:SetSize(width - 32, height)
        y = y - height - MORE_GAP
        T:Flat(panel, T.PANEL, T.BORDER)
        panel:EnableMouse(true)
        panel.info = info
        panel.icon = panel:CreateTexture(nil, "ARTWORK")
        panel.icon:SetSize(36, 36)
        panel.icon:SetPoint("TOPLEFT", 12, -12)
        panel.icon:SetTexture(ns.MEDIA .. info.icon)
        panel.title = T:Text(panel, "GameFontHighlight")
        panel.title:SetPoint("TOPLEFT", 60, -12)
        panel.title:SetText(info.name)
        panel.about = T:Text(panel, "GameFontHighlightSmall", T.MUTED)
        panel.about:SetPoint("TOPLEFT", 60, -30)
        panel.about:SetWidth(MORE_ABOUT)
        panel.about:SetText(info.about)
        -- The buttons' row: on the right halfway down, or under the pictures
        -- with the line saying where it stands beside it.
        local row, rowY = "RIGHT", 0
        panel.state = T:Text(panel, "GameFontHighlightSmall", T.MUTED)
        if info.shots then
            row, rowY = "BOTTOMRIGHT", MORE_BUTTONS
            panel.state:SetPoint("LEFT", panel, "BOTTOMLEFT", 60, MORE_BUTTONS + 11)
            BuildShots(window, page, panel, info, 16)
        else
            panel.state:SetPoint("BOTTOMLEFT", 60, 10)
        end
        panel.links = {}
        if info.soon then
            -- Coming soon: a mark where the buttons would be, and nothing to click.
            local soon = CreateFrame("Frame", nil, panel, "BackdropTemplate")
            soon:SetSize(100, 22)
            soon:SetPoint("RIGHT", -12, 0)
            T:Flat(soon, T.FIELD, T.CONTROL_BORDER)
            T:Paint(function(accent) soon:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1) end)
            soon.label = T:Heading(soon, "Coming soon")
            soon.label:SetPoint("CENTER")
            soon.label:SetJustifyH("CENTER")
            panel.soon = soon
            panel.state:SetText("Not out yet: nothing to get for now.")
            window:Hint(panel, info.name .. ": coming soon. It isn't out yet, so there's nothing to get or open for now.")
        else
            local open = T:Button(panel, "Open", 80, 22)
            open:SetPoint(row, -12, rowY)
            open:SetScript("OnClick", function() OpenOther(window, info) end)
            window:Hint(open, "Open " .. info.name .. "'s settings, as " .. info.command .. " does. This window closes.")
            panel.open = open
            for j, link in ipairs(info.links) do
                local button = T:Button(panel, link.label, 90, 22)
                button:SetPoint(row, -12 - (#info.links - j) * 98, rowY)
                button:SetScript("OnClick", function() CopyLink(info.name .. " on " .. link.label, link.url, link.note) end)
                window:Hint(button, info.name .. " on " .. link.label .. ", as a link to copy.")
                panel.links[j] = button
            end
            window:Hint(panel, function()
                if Loaded(info.addon) then return info.name .. ": installed. Open shows its settings." end
                return info.name .. ": not installed. Get it on CurseForge or GitHub."
            end)
        end
        -- Where it stands, as the page shows again.
        function panel:Sync()
            if info.soon then return end
            local installed = Loaded(info.addon)
            self.open:SetShown(installed)
            for _, button in ipairs(self.links) do button:SetShown(not installed) end
            self.state:SetText(installed and ("Installed. Type " .. info.command .. ", or click Open.")
                or "Get it on CurseForge or GitHub: click one for its link.")
        end
        window.more[info.key] = panel
    end
end

-- General: the window's accent, Reset, the minimap button, help and Squirt's
-- other addons.
local function BuildGeneral(window, page, width)
    local top = -16
    T:Heading(page, "Window accent"):SetPoint("TOPLEFT", 16, top)
    local swatches = {}
    for i, key in ipairs(ns.ACCENT_KEYS) do
        local swatch = P.Swatch(page, SWATCH, function()
            ns.Set("accent", key)
            T:Repaint()
            window:Refresh()
        end)
        swatch:SetPoint("TOPLEFT", 16 + (i - 1) * (SWATCH + SWATCH_GAP), top - 20)
        swatch.key = key
        window:Hint(swatch, T.ACCENTS[key].name .. " for this window's headings, ticks, sliders and highlights.")
        swatches[i] = swatch
    end
    window.swatches = swatches
    local chosen = T:Text(page, "GameFontHighlightSmall", T.MUTED)
    chosen:SetPoint("TOPLEFT", 16 + #ns.ACCENT_KEYS * (SWATCH + SWATCH_GAP) + 4, top - 24)
    window.accentChosen = chosen

    -- Reset, in the right column: back to the defaults, this profile or
    -- everything, asked first (the question is BuildReset's).
    T:Heading(page, "Reset"):SetPoint("TOPLEFT", P.RIGHT, top)
    local reset = T:Button(page, "Reset to defaults", 130, 22)
    reset:SetPoint("TOPLEFT", P.RIGHT, top - 18)
    reset:SetScript("OnClick", function() window:AskReset() end)
    window:Hint(reset, "Back to the defaults: the profile showing, or everything. It asks which first. " .. ns.SLASH
        .. " reset asks too.")
    window.resetButton = reset
    P.Detail(page, "Puts this profile, or everything, back to the defaults. It asks first.", P.RIGHT, top - 46, 280)

    top = top - 64
    T:Heading(page, "Minimap button"):SetPoint("TOPLEFT", 16, top)
    local minimap = T:Check(page, "Show the minimap button", function(self)
        ns.Set("minimap", self:GetChecked())
        if ns.MinimapButton then ns.MinimapButton:Apply() end
    end)
    minimap:SetPoint("TOPLEFT", 16, top - 20)
    window:Hint(minimap, "A button on the minimap for these settings. Off, " .. ns.SLASH .. " still opens them.")
    window.minimap = minimap
    P.Detail(page, "Click it for these settings, and drag it round the minimap.", 34, top - 40, 420)

    -- Help: the tour of the basics (Tour.lua), What's new (Notes.lua) and
    -- the Discord for bugs and ideas.
    top = top - 80
    T:Heading(page, "Help"):SetPoint("TOPLEFT", 16, top)
    local tour = T:Button(page, "Take the tour", 110, 22)
    tour:SetPoint("TOPLEFT", 16, top - 18)
    tour:SetScript("OnClick", function() if ns.Tour then ns.Tour:Start() end end)
    window:Hint(tour, "A short tour of this window, a page at a time. " .. ns.SLASH .. " tour starts it too.")
    window.tour = tour
    local news = T:Button(page, "What's new", 110, 22)
    news:SetPoint("TOPLEFT", 132, top - 18)
    news:SetScript("OnClick", function() if ns.ShowNotes then ns.ShowNotes() end end)
    window:Hint(news, "What changed in this version. " .. ns.SLASH .. " new shows it too.")
    window.generalNews = news
    local discord = T:Button(page, "Discord", 80, 22)
    discord:SetPoint("TOPLEFT", 248, top - 18)
    discord:SetScript("OnClick", function() ns.ShowDiscord() end)
    window:Hint(discord, "The Discord invite, ready to copy: bugs, ideas and help. " .. ns.SLASH .. " discord shows it too.")
    window.discord = discord
    P.Detail(page, "Bugs, ideas and help on the Discord. " .. ns.SLASH .. " opens this window, and " .. ns.SLASH_SPARE
        .. " does too.", 16, top - 50, 600)

    BuildMore(window, page, top - 80, width)

    function page:Refresh()
        for _, panel in pairs(window.more) do panel:Sync() end
        local accent = ns.Get("accent")
        for _, swatch in ipairs(swatches) do
            P.PaintSwatch(swatch, T.ACCENTS[swatch.key].colour, swatch.key == accent)
        end
        chosen:SetText(T.ACCENTS[accent].name)
        minimap:SetChecked(ns.Get("minimap"))
        -- A new file only loads after a full restart: until then, no tour.
        tour:SetShown(ns.Tour ~= nil)
        news:SetShown(ns.ShowNotes ~= nil)
    end
end

-- The page list ----------------------------------------------------------------------------

-- Down the left, top to bottom: the effects' pages, a rule, then the rest.
local PAGES = {
    { key = "trail", label = "Trail", preview = true, build = function(...) ns.BuildTrailPage(...) end,
        note = "The cursor trail: on or off, only in combat, and its dots' spacing, lifetime, size and opacity." },
    { key = "colours", label = "Colours", preview = true, build = function(...) ns.BuildColoursPage(...) end,
        note = "The trail's colours: your class's, one colour, a rainbow, or a gradient of up to ten of your own." },
    { key = "rings", label = "Rings", preview = true, build = function(...) ns.BuildRingsPage(...) end,
        note = "A ring round the cursor, cast progress round the cursor, and a highlight where it is while you look around." },
    { key = "marker", label = "Marker", preview = true, needs = "BuildMarkerPage", build = function(...) ns.BuildMarkerPage(...) end,
        note = "A marker on the pointer: a bullseye, crosshair, dot, diamond, star or your class icon." },
    { rule = true },
    { key = "profiles", label = "Profiles", build = function(...) ns.BuildProfilesPage(...) end,
        note = "Your profile, the account-wide one, and making, copying, sharing and importing profiles." },
    { key = "autoswitch", label = "Auto-switch", build = function(...) ns.BuildAutoSwitchPage(...) end,
        note = "Rules that show another profile for a while: in combat, mounted, in a dungeon and more." },
    { key = "general", label = "General", build = BuildGeneral,
        note = "The window's accent, Reset, the minimap button, the tour, What's new, the Discord and more from Squirt." },
}
-- A page from a file added since the game started only shows after a full
-- restart (a /reload doesn't load new files): until then it's left out.
for i = #PAGES, 1, -1 do
    if PAGES[i].needs and not ns[PAGES[i].needs] then table.remove(PAGES, i) end
end
ns.PAGE_KEYS = {}
local PREVIEWED = {}
for _, spec in ipairs(PAGES) do
    if spec.key then ns.PAGE_KEYS[#ns.PAGE_KEYS + 1] = spec.key end
    if spec.preview then PREVIEWED[spec.key] = true end
end

local function NavItem(window, nav, spec, y)
    local item = CreateFrame("Button", nil, nav)
    item:SetPoint("TOPLEFT", 0, -y)
    item:SetPoint("RIGHT")
    item:SetHeight(30)
    item.fill = item:CreateTexture(nil, "BACKGROUND")
    item.fill:SetAllPoints()
    T:Fill(item.fill, T.SELECTED)
    item.glow = T:Fade(item, T.FADE.selected)
    item.glow:SetAllPoints()
    item.mark = item:CreateTexture(nil, "ARTWORK")
    item.mark:SetPoint("TOPLEFT")
    item.mark:SetPoint("BOTTOMLEFT")
    item.mark:SetWidth(3)
    T:Paint(function(accent) T:Fill(item.mark, accent) end)
    local hover = item:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, .04)
    item.label = T:Text(item, "GameFontHighlight")
    item.label:SetPoint("TOPLEFT", 14, -9)
    item.label:SetText(spec.label)
    item.key = spec.key
    item:SetScript("OnClick", function() window:Select(spec.key) end)
    window:Hint(item, spec.note)
    return item
end

-- Setup ------------------------------------------------------------------------------------

-- "Are you sure?": a small dialog over the whole window, for anything that
-- can't simply be clicked back. window:Ask(title, detail, button, action,
-- after, cancel): after runs once it closes by either button (not when the
-- window closes under it); cancel labels the other button.
local function BuildConfirm(window)
    local shade = CreateFrame("Frame", nil, window)
    shade:SetAllPoints()
    shade:SetFrameLevel(window:GetFrameLevel() + 80)
    shade:EnableMouse(true) -- nothing behind it can be clicked meanwhile
    local dim = shade:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, .45)
    shade:Hide()
    local dialog = CreateFrame("Frame", nil, shade, "BackdropTemplate")
    dialog:SetSize(320, 112)
    dialog:SetPoint("CENTER")
    T:Flat(dialog, T.PANEL, T.CONTROL_BORDER)
    dialog.title = T:Text(dialog, "GameFontHighlight")
    dialog.title:SetPoint("TOPLEFT", 14, -14)
    dialog.title:SetWidth(292)
    dialog.detail = T:Text(dialog, "GameFontHighlightSmall", T.MUTED)
    dialog.detail:SetPoint("TOPLEFT", dialog.title, "BOTTOMLEFT", 0, -8)
    dialog.detail:SetWidth(292)
    local yes = T:Button(dialog, "", 90, 22)
    yes:SetPoint("BOTTOMRIGHT", -14, 14)
    yes.label:SetTextColor(T.WARN[1], T.WARN[2], T.WARN[3])
    local no = T:Button(dialog, "Cancel", 90, 22)
    no:SetPoint("RIGHT", yes, "LEFT", -6, 0)
    window.confirm = { shade = shade, dialog = dialog, yes = yes, no = no }
    window:Hint(shade, "Answer the question first.")
    window:Hint(yes, function() return (yes.word or "Yes") .. ": go ahead, as the question says." end)
    window:Hint(no, "Close the question. Nothing changes.")
    local pending, after
    local function Close()
        pending, after = nil, nil
        shade:Hide()
    end
    window.confirm.close = Close -- unanswered: the Reset question takes its place
    no:SetScript("OnClick", function()
        local next = after
        Close()
        if next then next() end
    end)
    yes:SetScript("OnClick", function()
        local action, next = pending, after
        Close()
        if action then action() end
        if next then next() end
    end)
    window:HookScript("OnHide", Close)
    function window:Ask(title, detail, label, action, afterwards, cancel)
        pending, after = action, afterwards
        no:SetLabel(cancel or "Cancel")
        dialog.title:SetText(title)
        dialog.detail:SetText(detail)
        yes:SetLabel(label)
        yes.word = label
        -- A long profile name wraps, and the dialog grows to fit it all.
        local text = (dialog.title:GetStringHeight() or 14) + 8 + (dialog.detail:GetStringHeight() or 14)
        dialog:SetHeight(math.max(112, math.ceil(14 + text + 16 + 22 + 14)))
        shade:Show()
    end
end

-- Reset: a question of its own over the whole window, above everything else
-- in it, with three answers. This profile puts the profile showing back to
-- the defaults; Everything starts again from one new profile, as a first
-- install does (Core.lua does both, at once: no reload). Cancel, its X and
-- Escape (out of a fight; in one the key is the game's) close it with
-- nothing changed. It never takes the keyboard. Opening it closes whatever
-- else sits over the window (another question unanswered, the share box,
-- the profile menu, the tour), so it's the only thing asking.
local RESET_WIDTH = 380
-- The profile showing, by name (before it loads, just "your profile"), and
-- for how many characters, when it's more than you: they all use it.
local function ResetName()
    return ns.ProfileName() or "your profile"
end
local function ResetUsers()
    local users = ns.ProfileUsers(ns.ProfileName())
    return users > 1 and (", for all %d characters using it"):format(users) or ""
end
local RESET_NOTES = {
    profile = function()
        return "Every setting of " .. ResetName() .. " back to its default, every effect off" .. ResetUsers() .. "."
            .. " Its name, account-wide mark and Auto-switch picks stay, and so do your other profiles."
    end,
    everything = "Every profile and Auto-switch rule deleted, and you start on one new profile, every effect off. The"
        .. " window's accent and minimap button go back too, as on a first install.",
    cancel = "Close the question. Nothing changes.",
}

local function BuildReset(window)
    local shade = CreateFrame("Frame", nil, window)
    shade:SetAllPoints()
    shade:SetFrameLevel(window:GetFrameLevel() + 90)
    shade:EnableMouse(true) -- nothing behind it can be clicked meanwhile
    local dim = shade:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, .45)
    shade:Hide()
    local dialog = CreateFrame("Frame", nil, shade, "BackdropTemplate")
    dialog:SetSize(RESET_WIDTH, 132)
    dialog:SetPoint("CENTER")
    T:Flat(dialog, T.PANEL, T.CONTROL_BORDER)
    dialog.title = T:Text(dialog, "GameFontHighlight")
    dialog.title:SetPoint("TOPLEFT", 14, -14)
    dialog.title:SetWidth(RESET_WIDTH - 28 - 24) -- clear of the X
    dialog.title:SetText("Reset to the defaults?")
    dialog.detail = T:Text(dialog, "GameFontHighlightSmall", T.MUTED)
    dialog.detail:SetPoint("TOPLEFT", dialog.title, "BOTTOMLEFT", 0, -8)
    dialog.detail:SetWidth(RESET_WIDTH - 28)
    local close = T:Square(dialog, "X")
    close:SetPoint("TOPRIGHT", -10, -10)
    local everything = T:Button(dialog, "Everything", 96, 22)
    everything:SetPoint("BOTTOMRIGHT", -14, 14)
    local profile = T:Button(dialog, "This profile", 96, 22)
    profile:SetPoint("RIGHT", everything, "LEFT", -6, 0)
    for _, button in ipairs({ everything, profile }) do button.label:SetTextColor(T.WARN[1], T.WARN[2], T.WARN[3]) end
    local cancel = T:Button(dialog, "Cancel", 80, 22)
    cancel:SetPoint("RIGHT", profile, "LEFT", -6, 0)
    window.reset = { shade = shade, dialog = dialog, profile = profile, everything = everything, cancel = cancel, close = close }
    window:Hint(shade, "Answer the question first: This profile, Everything, or Cancel to change nothing.")
    window:Hint(profile, RESET_NOTES.profile)
    window:Hint(everything, RESET_NOTES.everything)
    window:Hint(cancel, RESET_NOTES.cancel)
    window:Hint(close, function() return RESET_NOTES.cancel .. ns.EscapeWords("Escape closes it too.") end)

    local function Close()
        shade:Hide()
    end
    -- An answer: done at once, said in the footer, the window drawn again.
    local function Answer(reset)
        Close()
        local _, message = reset()
        window:Say(message)
        window:Refresh()
    end
    cancel:SetScript("OnClick", Close)
    close:SetScript("OnClick", Close)
    profile:SetScript("OnClick", function() Answer(ns.ResetProfile) end)
    everything:SetScript("OnClick", function() Answer(ns.ResetEverything) end)
    window:HookScript("OnHide", Close)

    -- From the General page (/fec reset opens it first, which closes a pick
    -- list or the colour picker on another page, keeping its colour).
    function window:AskReset()
        if self.confirm.close then self.confirm.close() end
        if self.shareBox then self.shareBox.Close() end
        self.profilePanel:Hide()
        if ns.Tour then ns.Tour:Stop() end
        dialog.detail:SetText("This profile puts " .. ResetName() .. " back to the defaults" .. ResetUsers() .. "."
            .. " Everything starts again from one new profile, as on a first install. Neither can be undone.")
        local text = (dialog.title:GetStringHeight() or 14) + 8 + (dialog.detail:GetStringHeight() or 14)
        dialog:SetHeight(math.max(132, math.ceil(14 + text + 16 + 22 + 14)))
        shade:Show()
    end
    function window:CloseReset()
        Close()
    end
    function window:ResetShown()
        return shade:IsShown()
    end
end

-- "Made with <heart> by Squirt", the heart and name in the accent. The font
-- has no heart, so it's a small white texture inline in the text, tinted by
-- the escape's own colour.
local function Credit()
    local accent = T:Accent()
    local function Byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + .5) end
    return ("Made with |T%s:0:0:0:0:32:32:0:32:0:32:%d:%d:%d|t by |cff%sSquirt|r"):format(ns.MEDIA .. HEART,
        Byte(accent[1]), Byte(accent[2]), Byte(accent[3]), T:Hex(accent))
end

-- The footer: the version on the left; on the right a note for the control
-- under the mouse, or else the last message, or else who made the addon.
-- Built before the pages, which give their controls notes as they're made.
local function BuildFooter(window)
    local version = T:Text(window, "GameFontHighlightSmall", T.MUTED)
    version:SetPoint("BOTTOMLEFT", 12, 9)
    version:SetText(Version() .. "   " .. ns.SLASH .. " to open")
    window.versionText = version
    local note = T:Text(window, "GameFontHighlightSmall", T.MUTED)
    note:SetPoint("BOTTOMRIGHT", -12, 9)
    note:SetJustifyH("RIGHT")
    note:SetWidth(560)
    window.note = note
    -- Shown at the next refresh, and until the one after.
    function window:Say(text)
        self.message = text
    end
    -- The hovered control's note, worked out afresh (some change as you
    -- click), or what the footer rests on: the last message, or the credit.
    function window:ShowNote()
        local hovered = self.hovered
        if hovered and not hovered:IsVisible() then hovered, self.hovered = nil, nil end
        local text = hovered and not self.saying and hovered.hint
        if type(text) == "function" then text = text(hovered) end
        self.lastNote = self.said or Credit()
        note:SetText(text or self.lastNote)
    end
    function window:Note(control)
        self.hovered, self.saying = control, nil
        self:ShowNote()
    end
    -- Only the control whose note is up can take it down, whichever order
    -- the game sends enter and leave.
    function window:Unnote(control)
        if self.hovered ~= control then return end
        self.hovered = nil
        self:ShowNote()
    end
    -- Every control's note, set up the same way. text: its note, or a
    -- function for one that changes. A slider has it all over, its label and
    -- value too, and on its track, which takes the mouse over the rest.
    function window:Hint(control, text)
        if control.track then
            control:EnableMouse(true)
            self:Hint(control.track, text)
        end
        control.hint = text
        control:HookScript("OnEnter", function() window:Note(control) end)
        control:HookScript("OnLeave", function() window:Unnote(control) end)
    end
    window:HookScript("OnHide", function() window.hovered = nil end)
    -- A new accent recolours the heart and name at once.
    T:Paint(function() window:ShowNote() end)
end

local function BuildWindow()
    local window = CreateFrame("Frame", "FECursorFrame", UIParent, "BackdropTemplate")
    window:SetSize(WIDTH, HEIGHT)
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
    window:Hide()
    -- Set before anything hooks these: setting a script later would drop the
    -- hooks the pages and the profile menu add.
    window:SetScript("OnShow", function(self)
        self:Refresh()
        ns.EscUpdate()
        -- Opened by /fec reset: its question comes first and would close
        -- these offers unseen, so they wait for the next opening.
        if self.resetFirst then
            self.resetFirst = nil
            return
        end
        -- EraUI's cursor settings are offered once (ProfileTools.lua); a
        -- first install's first look then offers the tour (Tour.lua).
        local offered = ns.ProfileTools and ns.ProfileTools.Offer(self, function()
            if ns.Tour then ns.Tour:Shown() end
        end)
        if not offered and ns.Tour then ns.Tour:Shown() end
    end)
    window:SetScript("OnHide", function(self)
        -- Closed mid-drag, it never hears the mouse let go: stop moving now.
        self:StopMovingOrSizing()
        if self.preview then self.preview:Run(false) end
        ns.EscUpdate()
        -- A profile switch the Auto-switch rules held back while it was open.
        if ns.AutoSwitch then ns.AutoSwitch:WindowClosed() end
    end)

    -- Header: the addon's icon, and "Enhanced" in the accent.
    local header = T:TitleBar(window, HEADER)
    window.fades = { header = header.fade, page = T:Fade(window, T.FADE.page) }
    window.fades.page:SetPoint("TOPLEFT", NAV + 1, -(HEADER + 1))
    window.fades.page:SetPoint("BOTTOMRIGHT", -1, FOOTER)
    window.close = header.close
    window.header = header
    BuildFooter(window)
    window:Hint(header.close, "Close the window. Escape closes it too, and " .. ns.SLASH .. " opens it again.")
    BuildConfirm(window)
    BuildReset(window)
    ns.BuildProfileMenu(window, header, header.close)

    -- The page list down the left.
    local nav = CreateFrame("Frame", nil, window, "BackdropTemplate")
    nav:SetPoint("TOPLEFT", 1, -(HEADER + 1))
    nav:SetPoint("BOTTOMLEFT", 1, FOOTER)
    nav:SetWidth(NAV)
    window.navFrame = nav
    T:Flat(nav, T.NAV, T.NAV)
    local edge = nav:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")
    edge:SetWidth(1)
    T:Fill(edge, T.BORDER)
    window.nav = {}
    local y = 12
    for _, spec in ipairs(PAGES) do
        if spec.rule then
            local rule = nav:CreateTexture(nil, "BORDER")
            rule:SetPoint("TOPLEFT", 12, -(y + 4))
            rule:SetPoint("RIGHT", -12, 0)
            rule:SetHeight(1)
            T:Fill(rule, T.BORDER)
            y = y + 12
        else
            window.nav[spec.key] = NavItem(window, nav, spec, y)
            y = y + 32
        end
    end
    -- What's new in this version, at the foot of the list, once there are notes.
    if ns.ShowNotes then
        local news = T:Button(nav, "What's new", NAV - 24, 22)
        news:SetPoint("BOTTOMLEFT", 12, 12)
        news:SetScript("OnClick", function() ns.ShowNotes() end)
        window:Hint(news, "What changed in this version. " .. ns.SLASH .. " new shows it too.")
        window.news = news
    end

    -- Pages fill the rest, each sized now so everything on it has a place.
    window.pages = {}
    for _, spec in ipairs(PAGES) do
        if spec.key then
            local page = CreateFrame("Frame", nil, window)
            page:SetPoint("TOPLEFT", NAV + 1, -(HEADER + 1))
            page:SetPoint("BOTTOMRIGHT", -1, FOOTER)
            page:SetSize(WIDTH - NAV - 2, HEIGHT - HEADER - FOOTER - 1)
            page:Hide()
            window.pages[spec.key] = page
            spec.build(window, page, WIDTH - NAV - 2)
        end
    end
    -- The preview across the top of the effects' pages, and the colour
    -- picker over the right of a page, under it.
    ns.BuildPreview(window, NAV + 1 + 16, -(HEADER + 1 + 16))
    if ns.ColourPicker then ns.ColourPicker:Build(window) end

    window.selected = "trail"
    function window:Select(key)
        if not self.pages[key] then return end
        self.selected = key
        self.profilePanel:Hide()
        for _, list in ipairs(self.pickLists or {}) do list:Hide() end
        self:Refresh()
    end

    function window:Refresh()
        self:RefreshProfiles()
        local selected = self.selected
        for key, item in pairs(self.nav) do
            local chosen = key == selected
            item.fill:SetShown(chosen)
            item.glow:SetShown(chosen)
            item.mark:SetShown(chosen)
        end
        for key, page in pairs(self.pages) do page:SetShown(key == selected) end
        local page = self.pages[selected]
        page:Refresh()
        -- The colour picker closes once its swatch has gone or can't be
        -- used; the page then shows without it.
        if ns.ColourPicker and ns.ColourPicker:Sync() then page:Refresh() end
        -- The preview, about the page's own effect, only on the effects' pages.
        local previewed = PREVIEWED[selected] == true
        self.preview:SetShown(previewed)
        self.preview:Focus(page.focus or "trail")
        self.preview:Run(previewed and self:IsShown())
        -- A message takes the footer, even from the control just clicked,
        -- for now: the next refresh without one, or the mouse onto another
        -- control, brings a hovered control's note back, updated.
        self.said, self.message = self.message, nil
        self.saying = self.said ~= nil
        self:ShowNote()
        if ns.Tour then ns.Tour:Sync() end
    end

    ns.window = window
    return window
end

function ns.ShowWindow()
    local window = ns.window or BuildWindow()
    window:Show()
    window:Raise()
end

function ns.Toggle()
    local window = ns.window or BuildWindow()
    window:SetShown(not window:IsShown())
end

-- /fec reset: the window on the General page, and the Reset question, as
-- its Reset button asks. Opened by this, the window makes no first-look
-- offers (EraUI's settings, a first install's tour): the next opening does.
function ns.AskReset()
    local window = ns.window or BuildWindow()
    if not window:IsShown() then window.resetFirst = true end
    ns.ShowWindow()
    window:Select("general")
    window:AskReset()
end
