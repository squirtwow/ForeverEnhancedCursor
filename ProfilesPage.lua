-- The Profiles page: the profile this character uses and the account-wide
-- mark; making, copying, renaming and deleting profiles; sharing them as
-- text; and, while EraUI is loaded, EraUI's cursor settings brought over as a
-- profile. The same rules as the header's profile menu (Core.lua); the
-- sharing is ProfileTools.lua's. Each part is a frame of its own, stacked
-- top to bottom on every refresh, so a part that's hidden leaves no gap.
local _, ns = ...
local T = ns.Theme
local P = ns.PageParts

local L = 16
local PICK_X, PICK_WIDTH = 150, 260
local TOP, GAP = -16, 16 -- the first part's top, and the room between parts

-- A note for the footer after a pick by hand, while the rules would show
-- something else: it holds until they change.
function ns.PickNote(message)
    local status = ns.AutoSwitch and ns.AutoSwitch.Status()
    if status and status.on and status.held then
        return message .. " The Auto-switch rules wait until what they'd pick changes."
    end
    return message
end

function ns.BuildProfilesPage(window, page, width)
    local list = P.PickList(window, page, PICK_WIDTH)
    page.pickList = list

    -- The parts, each sized as it's made; Stack places the ones showing.
    local sections = {}
    local function Section(height)
        local section = CreateFrame("Frame", nil, page)
        section:SetSize(width, height)
        section:SetPoint("TOPLEFT", 0, TOP)
        sections[#sections + 1] = section
        return section
    end
    local function Stack()
        local y = TOP
        for _, section in ipairs(sections) do
            if section:IsShown() then
                section:ClearAllPoints()
                section:SetPoint("TOPLEFT", 0, y)
                y = y - section:GetHeight() - GAP
            end
        end
    end
    page.sections = sections

    -- This character: always first, so its picker's top on the page is fixed.
    local character = Section(92)
    T:Heading(character, "This character"):SetPoint("TOPLEFT", L, 0)
    P.Label(character, "Uses", L, -20)
    local picker = T:Button(character, "", PICK_WIDTH, 22)
    picker:SetPoint("TOPLEFT", PICK_X, -20)
    picker.label:SetWidth(PICK_WIDTH - 16)
    picker.label:SetWordWrap(false)
    picker:SetScript("OnClick", function(self)
        if list:IsShown() and list.owner == self then return list:Hide() end
        local items = {}
        for _, name in ipairs(ns.ProfileNames()) do
            items[#items + 1] = { key = name, label = ns.IsAccountWide(name) and (name .. "  |cff8b8d92account-wide|r") or name }
        end
        list:Open(self, TOP - 20, items, ns.OwnProfile(), function(item)
            local ok, message = ns.UseProfile(item.key)
            window:Say(ok and ns.PickNote(message) or message)
            window:Refresh()
        end, "Pick the profile this character uses.", function(item)
            if item.key == ns.OwnProfile() then return "The profile this character uses now." end
            return "Use " .. item.key .. " on this character."
        end)
    end)
    window:Hint(picker, "The profile this character uses: its cursor effects. Click to pick another. The header's menu does this too.")
    window.profilesPicker = picker
    local state = T:Text(character, "GameFontHighlightSmall", T.MUTED)
    state:SetPoint("LEFT", picker, "RIGHT", 10, 0)
    state:SetWidth(width - PICK_X - PICK_WIDTH - 26)
    state:SetWordWrap(false)
    page.state = state

    -- The mark is for this character's own profile, the one above, even
    -- while the Auto-switch rules show another.
    local wide = T:Check(character, "Account-wide: every character uses it", function(self)
        local on = self:GetChecked()
        self:SetChecked(not on) -- until it's done
        local name = ns.OwnProfile()
        if not on then
            local _, message = ns.SetAccountWide(false)
            window:Say(message)
            return window:Refresh()
        end
        window:Ask(('Make "%s" account-wide?'):format(tostring(name)),
            "Every character uses it now, and any you make later loads it. Their own profiles stay in the list.",
            "Account-wide", function()
                local _, message = ns.SetAccountWide(true)
                window:Say(message)
                window:Refresh()
            end)
    end)
    wide:SetPoint("TOPLEFT", L, -52)
    window:Hint(wide, function()
        local everyone, name = ns.EveryoneProfile(), ns.OwnProfile()
        if everyone and everyone == name then
            return name .. " is account-wide. Untick to stop: characters keep what they use, new ones get their own."
        end
        if everyone then return "The account-wide profile is " .. everyone .. ". Tick to make " .. tostring(name) .. " it instead." end
        return "Tick to make " .. tostring(name) .. " account-wide: every character uses it, and new ones load it. It asks first."
    end)
    window.accountWide = wide
    local wideAbout = P.Detail(character, "", L + 18, -72, width - 50)
    page.wideAbout = wideAbout

    -- Manage: a name, then New, Copy, Rename and Delete.
    local manage = Section(98)
    T:Heading(manage, "Manage"):SetPoint("TOPLEFT", L, 0)
    local input = T:Input(manage, "Profile name", 260)
    input:SetPoint("TOPLEFT", L, -20)
    input:SetMaxLetters(ns.PROFILE_MAX)
    window:Hint(input, "A name for New, Copy or Rename.")
    window.profilesInput = input
    local function Act(action)
        return function()
            local ok, message = action(input:GetText())
            window:Say(ok and ns.PickNote(message) or message)
            if ok then
                P.SetBoxText(input, "")
                input:ClearFocus()
            end
            window:Refresh()
        end
    end
    local actions = {}
    local specs = {
        { "New", ns.NewProfile, "Make a new profile with the default settings and the name typed, and switch to it." },
        { "Copy", ns.CopyProfile, "Copy the settings showing into a new profile with the name typed, and switch to it." },
        { "Rename", ns.RenameProfile, "Give the profile showing the name typed, for every character using it." },
    }
    for i, spec in ipairs(specs) do
        local button = T:Button(manage, spec[1], 90, 22)
        button:SetPoint("TOPLEFT", L + (i - 1) * 96, -48)
        button:SetScript("OnClick", Act(spec[2]))
        window:Hint(button, spec[3])
        actions[spec[1]:lower()] = button
    end
    local delete = T:Button(manage, "Delete", 90, 22)
    delete:SetPoint("TOPLEFT", L + 3 * 96, -48)
    delete.label:SetTextColor(T.WARN[1], T.WARN[2], T.WARN[3])
    delete:SetScript("OnClick", function()
        local ok, name, others = ns.CanDeleteProfile(ns.ProfileName())
        if not ok then
            window:Say(name)
            return window:Refresh()
        end
        local mine = name == ns.OwnProfile()
        local detail = mine and "You're using it, so you'll move to a new profile of your own, with the default settings. "
            or "The Auto-switch rules show it now: your own profile shows instead, and rules that pick it pick None. "
        if others > 0 then
            local everyone = ns.EveryoneProfile()
            local fate = everyone and everyone ~= name and ("loads " .. everyone) or "gets a new profile of its own"
            detail = detail .. (others == 1 and "Another character uses it, and " or (others .. " other characters use it, and each "))
                .. fate .. " at its next login. "
        end
        window:Ask(('Delete "%s"?'):format(name), detail .. "This can't be undone.", "Delete", function()
            local _, message = ns.DeleteProfile(name)
            window:Say(message)
            window:Refresh()
        end)
    end)
    window:Hint(delete, function() return "Delete " .. tostring(ns.ProfileName()) .. ", the profile showing. It asks first." end)
    actions.delete = delete
    window.profilesActions = actions
    local manageAbout = P.Detail(manage, "", L, -78, width - 32)
    page.manageAbout = manageAbout

    -- Share: Export and Import, in a box over the window.
    local share = Section(66)
    local shareHeading = T:Heading(share, "Share")
    shareHeading:SetPoint("TOPLEFT", L, 0)
    local box = ns.ProfileTools.BuildBox(window)
    local export = T:Button(share, "Export", 110, 22)
    export:SetPoint("TOPLEFT", L, -18)
    export:SetScript("OnClick", function()
        local text, why = ns.ProfileTools.Export()
        if not text then
            window:Say(why)
            return window:Refresh()
        end
        box:Open("export", text)
    end)
    window:Hint(export, "The profile showing as text, to copy and share or keep.")
    window.shareExport = export
    local import = T:Button(share, "Import", 110, 22)
    import:SetPoint("TOPLEFT", L + 120, -18)
    import:SetScript("OnClick", function() box:Open("import") end)
    window:Hint(import, "Paste a profile, see what it changes, then make it a new profile or put it on this one.")
    window.shareImport = import
    P.Detail(share, "Everything on the Trail, Colours and Rings pages. Not the window's accent, the minimap button or the "
        .. "Auto-switch rules.", L, -48, width - 32)

    -- From EraUI: only while EraUI is loaded and its settings can be read.
    local era = Section(90)
    T:Heading(era, "From EraUI"):SetPoint("TOPLEFT", L, 0)
    local copyEra = T:Button(era, "Copy EraUI's cursor settings", 210, 22)
    copyEra:SetPoint("TOPLEFT", L, -18)
    copyEra:SetScript("OnClick", function()
        local _, message = ns.ProfileTools.CopyFromEraUI()
        window:Say(message)
        window:Refresh()
    end)
    window:Hint(copyEra, "Makes a profile named " .. ns.ProfileTools.ERA_NAME .. " from EraUI's cursor trail, ring and cast "
        .. "ring settings, and switches to it. EraUI's settings are only read.")
    window.copyEra = copyEra
    P.Detail(era, "EraUI's own effects stay on until you turn them off in /era: until then both draw.", L, -48, width - 32)
    page.era = era
    Stack()

    function page:Refresh()
        local own, shown, everyone = ns.OwnProfile(), ns.ProfileName(), ns.EveryoneProfile()
        picker:SetLabel(own or "loading...")
        if shown and shown ~= own then
            state:SetText("Auto-switch shows " .. shown .. " for now")
        elseif own and own == everyone then
            state:SetText("Account-wide")
        else
            local users = own and ns.ProfileUsers(own) or 0
            state:SetText(users > 1 and ("Shared with " .. (users - 1) .. (users == 2 and " other character" or " other characters")) or "")
        end
        wide:SetChecked(everyone ~= nil and everyone == own)
        if everyone and everyone ~= own then
            wideAbout:SetText("The account-wide profile is " .. everyone .. ". New characters load it.")
        elseif everyone then
            wideAbout:SetText("New characters load it too. Only one profile is account-wide at a time.")
        else
            wideAbout:SetText("No profile is account-wide: each new character gets its own.")
        end
        manageAbout:SetText("New starts from the defaults; Copy from the settings showing. Rename and Delete act on the profile "
            .. "showing: " .. tostring(shown) .. ".")
        era:SetShown(ns.FromEraUI.Readable())
        Stack()
    end
end
