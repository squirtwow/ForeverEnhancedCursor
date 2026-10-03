-- The profile menu in the /fec window's header: the profile showing (with
-- "(auto)" while the Auto-switch rules show one), and a panel under it
-- listing every profile (click one to switch, or its x to delete it after
-- asking) with a box to type a name for New, Copy or Rename, and the
-- account-wide tick. Profiles hold the settings for the cursor effects; the
-- window's accent, the minimap button and the rules are shared. The rules
-- for profiles live in Core.lua; the Profiles page has all of this too.
local _, ns = ...
local T = ns.Theme

local WIDTH, ROW = 300, 22
local LIST_ROWS = 8 -- profiles listed at once; more scroll
local LIST_WIDTH = WIDTH - 28 -- the list, clear of its scroll thumb

local function Users(name)
    if ns.IsAccountWide(name) then return "account-wide" end
    local count = ns.ProfileUsers(name)
    local mine = name == ns.OwnProfile()
    if mine and count > 1 then return "you + " .. (count - 1) end
    if mine then return "you" end
    if count == 0 then return "unused" end
    return count == 1 and "1 character" or (count .. " characters")
end

function ns.BuildProfileMenu(window, header, anchor)
    local button = T:Button(header, "", 280, 24)
    button:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
    button.label:SetWidth(264)
    button.label:SetWordWrap(false)
    window:Hint(button, function()
        local auto = ns.Override()
        if auto then
            return auto .. " shows for now, picked by the Auto-switch rules; your own is " .. tostring(ns.OwnProfile())
                .. ". Click for every profile: picking one by hand makes it yours."
        end
        return "The profile this character uses: its cursor effects. Click for every profile, to switch or make one."
    end)
    window.profileButton = button

    local panel = CreateFrame("Frame", nil, window, "BackdropTemplate")
    panel:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -4)
    panel:SetSize(WIDTH, 200) -- sized again on every refresh
    panel:SetFrameLevel(window:GetFrameLevel() + 60)
    panel:SetClampedToScreen(true)
    T:Flat(panel, T.PANEL, T.CONTROL_BORDER)
    panel:EnableMouse(true)
    panel:Hide()
    window.profilePanel = panel
    T:Heading(panel, "Profiles"):SetPoint("TOPLEFT", 10, -10)

    -- The profiles scroll in a list of up to LIST_ROWS, so however many there
    -- are, the name box and buttons under it stay in reach. Pinned by two
    -- corners, again a moment after the menu opens, as What's new's list is
    -- (Notes.lua): a scroll frame placed any other way can draw nothing.
    local list = T:Scroll(panel, LIST_WIDTH)
    local tall = 1 -- rows the list is tall enough for
    local function Pin()
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -28)
        list:SetPoint("BOTTOMRIGHT", panel, "TOPLEFT", 10 + LIST_WIDTH, -(28 + tall * ROW))
        list:ScrollTo(list:GetVerticalScroll() or 0)
    end
    Pin()
    panel:HookScript("OnShow", function() C_Timer.After(0, Pin) end)
    window:Hint(list.thumb, ns.SCROLL_NOTE)
    window.profileList = list

    -- Deleting asks first, in the window's own dialog, saying what happens to
    -- any other character using it: at its next login it gets a profile as a
    -- new character would, even one since deleted that only left its name.
    local function Ask(name)
        local ok, why, others = ns.CanDeleteProfile(name)
        if not ok then
            window:Say(why)
            return window:Refresh()
        end
        local mine = name == ns.OwnProfile()
        local detail = mine and "You're using it, so you'll move to a new profile of your own, with the default settings. " or ""
        if not mine and name == ns.Override() then
            detail = "The Auto-switch rules show it now: your own profile shows instead, and rules that pick it pick None. "
        end
        if others > 0 then
            local everyone = ns.EveryoneProfile()
            local fate = everyone and everyone ~= name and ("loads " .. everyone)
                or "gets a new profile of its own"
            detail = detail .. (others == 1 and "Another character uses it, and " or (others .. " other characters use it, and each "))
                .. fate .. " at its next login. "
        end
        window:Ask(('Delete "%s"?'):format(name), detail .. "This can't be undone.", "Delete", function()
            local done, message = ns.DeleteProfile(name)
            window:Say(message)
            -- Deleting your own profile moves you, so the menu closes as for any switch.
            if done and mine then panel:Hide() end
            window:Refresh()
        end)
    end

    local rows = {}
    local function Row(i)
        if rows[i] then return rows[i] end
        local row = CreateFrame("Button", nil, list.content)
        row:SetSize(LIST_WIDTH, ROW - 2)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
        row.fill = row:CreateTexture(nil, "BACKGROUND")
        row.fill:SetAllPoints()
        T:Fill(row.fill, T.SELECTED)
        row.mark = row:CreateTexture(nil, "ARTWORK")
        row.mark:SetPoint("TOPLEFT")
        row.mark:SetPoint("BOTTOMLEFT")
        row.mark:SetWidth(3)
        T:Paint(function(accent) T:Fill(row.mark, accent) end)
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, .05)
        row.name = T:Text(row, "GameFontHighlight")
        row.name:SetPoint("LEFT", 10, 0)
        row.name:SetWidth(160)
        row.name:SetWordWrap(false)
        row.remove = T:Square(row, "x")
        row.remove:SetSize(16, 16)
        row.remove:SetPoint("RIGHT", -2, 0)
        row.remove:SetScript("OnClick", function() Ask(row.profile) end)
        row.users = T:Text(row, "GameFontHighlightSmall", T.MUTED)
        row.users:SetPoint("RIGHT", row.remove, "LEFT", -8, 0)
        row.users:SetJustifyH("RIGHT")
        row:SetScript("OnClick", function(self)
            local ok, message = ns.UseProfile(self.profile)
            window:Say(ok and ns.PickNote and ns.PickNote(message) or message)
            if ok then panel:Hide() end
            window:Refresh()
        end)
        window:Hint(row, function()
            if row.profile == ns.Override() then return "The Auto-switch rules show this now. Click to make it your own." end
            return row.profile == ns.ProfileName() and "The profile you're on." or ("Switch to " .. row.profile .. ".")
        end)
        window:Hint(row.remove, function() return "Delete " .. row.profile .. ". It asks first." end)
        rows[i] = row
        return row
    end

    -- Placed now as for one profile, then moved under the list on refresh, so
    -- nothing is ever laid out without a place.
    local input = T:Input(panel, "Profile name", WIDTH - 20)
    input:SetPoint("TOPLEFT", 10, -54)
    window:Hint(input, "A name for New, Copy or Rename.")
    window.profileInput = input
    local hint = T:Text(panel, "GameFontHighlightSmall", T.MUTED)
    hint:SetPoint("TOPLEFT", 10, -136)
    hint:SetWidth(WIDTH - 20)
    hint:SetText("Click a profile to use it, or x to delete it. Type a name to make, copy or rename the profile showing. "
        .. "Any character can share a profile. The window's accent, the minimap button and the rules are the same for all.")

    -- Your own profile (the one with the accent mark), account-wide: every
    -- character uses it, and any made later loads it, even while the
    -- Auto-switch rules show another. Ticking asks first; unticking doesn't.
    local everyone = T:Check(panel, "Account-wide", function(self)
        local on = self:GetChecked()
        self:SetChecked(not on) -- until it's done
        local name = ns.OwnProfile()
        if not name then return end
        if not on then
            local _, message = ns.SetAccountWide(false)
            window:Say(message)
            return window:Refresh()
        end
        window:Ask(('Make "%s" account-wide?'):format(name),
            "Every character uses it now, and any you make later loads it. Their own profiles stay in this list.",
            "Account-wide", function()
                local _, message = ns.SetAccountWide(true)
                window:Say(message)
                panel:Hide()
                window:Refresh()
            end)
    end)
    everyone:SetPoint("TOPLEFT", 10, -106)
    window:Hint(everyone, function()
        local name, wide = ns.OwnProfile(), ns.EveryoneProfile()
        if wide and wide == name then return name .. " is account-wide. Untick to stop: characters keep what they use." end
        if wide then return "The account-wide profile is " .. wide .. ". Tick to make your own, " .. tostring(name) .. ", it instead." end
        return "Tick to make your own profile, " .. tostring(name) .. ", account-wide: every character uses it, and new ones load it. "
            .. "It asks first."
    end)
    window.profileEveryone = everyone

    -- Each button acts on the typed name. Every one of them leaves you on a
    -- different profile or name, so the menu closes once it has worked.
    local function Act(action)
        return function()
            local ok, message = action(input:GetText())
            window:Say(message)
            if ok then
                input:SetText("")
                input:ClearFocus()
                input.placeholder:Show()
                panel:Hide()
            end
            window:Refresh()
        end
    end
    local buttons = {}
    local x = 10
    for _, spec in ipairs({ { "New", ns.NewProfile, "Make a new profile with the default settings and the name typed above, and switch to it." },
        { "Copy", ns.CopyProfile, "Copy your settings into a new profile with the name typed above, and switch to it." },
        { "Rename", ns.RenameProfile, "Give the profile you're on the name typed above, for every character using it." } }) do
        local action = T:Button(panel, spec[1], 90, 22)
        action:SetPoint("TOPLEFT", x, -80)
        action.x = x
        action:SetScript("OnClick", Act(spec[2]))
        window:Hint(action, spec[3])
        buttons[spec[1]:lower()] = action
        x = x + 94
    end
    window.profileActions = buttons

    button:SetScript("OnClick", function()
        local open = not panel:IsShown()
        -- The colour picker would sit under it: it closes, keeping its colour
        -- (opening it closes this in turn).
        if open and ns.ColourPicker then ns.ColourPicker:Close(true, true) end
        panel:SetShown(open)
        window:Refresh()
    end)
    window:HookScript("OnHide", function() panel:Hide() end)

    function window:RefreshProfiles()
        local current = ns.ProfileName()
        button:SetLabel("|cff8b8d92Profile|r   " .. (current or "loading...") .. (ns.Override() and "  |cff8b8d92(auto)|r" or ""))
        if not panel:IsShown() then return end
        local names = ns.ProfileNames()
        for i, name in ipairs(names) do
            local row = Row(i)
            row.profile = name
            row.name:SetText(name)
            row.users:SetText(Users(name))
            row.fill:SetShown(name == current)
            row.mark:SetShown(name == ns.OwnProfile())
            row:Show()
        end
        for i = #names + 1, #rows do rows[i]:Hide() end
        -- The list is as tall as its profiles, up to LIST_ROWS; the box,
        -- buttons and hint follow it.
        tall = math.max(1, math.min(#names, LIST_ROWS))
        list.content:SetHeight(math.max(1, #names * ROW))
        Pin()
        local y = 32 + tall * ROW
        input:ClearAllPoints()
        input:SetPoint("TOPLEFT", 10, -y)
        for _, action in pairs(buttons) do
            action:ClearAllPoints()
            action:SetPoint("TOPLEFT", action.x, -(y + 26))
        end
        everyone:ClearAllPoints()
        everyone:SetPoint("TOPLEFT", 10, -(y + 55))
        everyone:SetChecked(ns.IsAccountWide(ns.OwnProfile()))
        hint:ClearAllPoints()
        hint:SetPoint("TOPLEFT", 10, -(y + 82))
        panel:SetHeight(y + 92 + math.max(28, math.ceil(hint:GetStringHeight() or 28)))
    end
end
