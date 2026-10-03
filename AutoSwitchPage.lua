-- The Auto-switch page, in two tabs. Rules: the master
-- switch, what the rules pick now, and a profile for each rule, numbered in
-- the order they're tried (the first that matches and has a profile
-- decides). Mounts: the mounts you list, each with its profile. The rules
-- are AutoSwitch.lua's; the picks are kept by Core.lua.
local _, ns = ...
local T = ns.Theme
local P = ns.PageParts
local A = ns.AutoSwitch

local L, R = 16, 326
local ROW_TOP, ROW = -120, 26
local PICK_X, PICK_WIDTH = 230, 220
local MOUNT_TOP, MOUNT_ROW, MOUNT_ROWS = -128, 28, 8
local MOUNT_WIDTH = 480

local TABS = {
    { key = "rules", label = "Rules", note = "The master switch and a profile for each rule, in the order they're tried." },
    { key = "mounts", label = "Mounts", note = "A profile for each mount you list, shown while you ride it. Needs testing." },
}

-- Each rule's row: its number in the order, its words and its note.
local RULES = {
    { rule = "combat", number = 1, label = "In combat",
        note = "Shows while you're in a fight, from its first moment. It goes a second after the fight ends, so a chain pull keeps it." },
    { rule = "mount", number = 2, label = "A mount you list" .. P.TESTING,
        note = "Each mount on the Mounts tab has its own profile, shown while you ride it, before Mounted's. Needs testing." },
    { rule = "mounted", number = 3, label = "Mounted",
        note = "Shows while you're on any mount (not on a flight path)." },
    { rule = "pvp", number = 4, label = "Battleground or arena",
        note = "Shows inside a battleground, or an arena if Forever adds them." },
    { rule = "dungeon", number = 5, label = "Dungeon or raid", note = "Shows inside a dungeon or a raid." },
    { rule = "world", number = 6, label = "Open world", note = "Shows anywhere that isn't an instance." },
    { rule = "peace", number = 7, label = "Not in combat", note = "Shows whenever you're not in a fight, if nothing above decides." },
    { rule = "talent1", number = 8, label = "Primary talents",
        note = "This character's own: shows while your Primary talents are active, if nothing above decides." },
    { rule = "talent2", number = 8, label = "Secondary talents",
        note = "This character's own: shows while your Secondary talents are active, if nothing above decides." },
}

-- The pick for a row, and setting it.
local function Get(rule)
    if rule == "talent1" then return ns.TalentPick(1) end
    if rule == "talent2" then return ns.TalentPick(2) end
    return ns.RulePick(rule)
end

local function Set(rule, name)
    if rule == "talent1" then return ns.SetTalentPick(1, name) end
    if rule == "talent2" then return ns.SetTalentPick(2, name) end
    return ns.SetRulePick(rule, name)
end

local function StatusText()
    local status = A.Status()
    local own = tostring(ns.OwnProfile())
    if not status.on then return "Off: tick it to let the rules below switch profiles. Picks can be made while it's off.", T.MUTED end
    local what = status.name and (status.name .. " (" .. A.NAMES[status.why] .. ")") or ("your own profile, " .. own)
    if status.waiting then return "The rules now pick " .. what .. ": it switches when this window closes.", T.WARN end
    if status.held then return "Holding your pick, " .. own .. ", until what the rules pick changes.", T.TEXT end
    if status.name then return "Now: " .. A.Reason(status.why) .. ", so " .. status.name .. ".", T.TEXT end
    return "No rule picks a profile now, so your own shows: " .. own .. ".", T.TEXT
end

-- The Rules tab.
local function BuildRules(window, page, pane, list, width)
    local master = T:Check(pane, "Switch profiles automatically", function(self)
        ns.Set("autoSwitch", self:GetChecked())
        A:RulesChanged()
        window:Refresh()
    end)
    master:SetPoint("TOPLEFT", L, -48)
    window:Hint(master, "For all your characters: the rules below show another profile for a while, the first that matches "
        .. "deciding. Your own pick stays yours. Off at first.")
    window.autoSwitchTick = master
    local say = T:Check(pane, "Say so in chat", function(self) ns.Set("autoSay", self:GetChecked()) end)
    say:SetPoint("TOPLEFT", R, -48)
    window:Hint(say, "A line in chat each time the rules switch profile.")
    window.autoSayTick = say
    local status = T:Text(pane, "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", L, -72)
    status:SetWidth(width - 32)
    window.autoStatus = status
    T:Heading(pane, "Rules, first match wins"):SetPoint("TOPLEFT", L, -100)

    local rows = {}
    for i, spec in ipairs(RULES) do
        local y = ROW_TOP - (i - 1) * ROW
        local number = T:Text(pane, "GameFontHighlight", T.MUTED)
        number:SetPoint("TOPLEFT", L, y - 3)
        number:SetText(tostring(spec.number))
        P.Label(pane, spec.label, L + 18, y)
        local control
        if spec.rule == "mount" then
            control = T:Button(pane, "On the Mounts tab", PICK_WIDTH, 22)
            control:SetPoint("TOPLEFT", PICK_X, y)
            control:SetScript("OnClick", function()
                page.tab = "mounts"
                window:Refresh()
            end)
            window:Hint(control, spec.note .. " Click for the Mounts tab.")
            control.Sync = function(self)
                local count = #ns.MountIDs()
                self:SetLabel(count == 0 and "Mounts tab: none listed" or ("Mounts tab: " .. count .. " listed"))
            end
        else
            control = P.ProfilePicker(window, pane, list, {
                x = PICK_X, y = y, width = PICK_WIDTH, forWhat = spec.label:lower(), with = "for " .. spec.label:lower(),
                none = "None: " .. spec.label .. " leaves it to the next rule.",
                hint = spec.note .. " Click to pick a profile, or None.",
                Get = function() return Get(spec.rule) end,
                Pick = function(name)
                    local ok, why = Set(spec.rule, name)
                    window:Say(ok and (name and (name .. " for " .. spec.label .. ".")
                        or ("None for " .. spec.label .. ": the next rule decides.")) or why)
                    A:RulesChanged()
                    window:Refresh()
                end,
            })
        end
        control.rule = spec.rule
        control.state = T:Text(pane, "GameFontHighlightSmall", T.MUTED)
        control.state:SetPoint("LEFT", control, "RIGHT", 10, 0)
        rows[i] = control
    end
    window.autoRows = rows
    local otherwise = T:Text(pane, "GameFontHighlight", T.MUTED)
    otherwise:SetPoint("TOPLEFT", L + 18, ROW_TOP - #RULES * ROW - 6)
    P.Detail(pane, "Rules are the same for all your characters; talent groups are each character's own. Arena counts if "
        .. "Forever adds arenas. A profile you pick by hand holds until what the rules pick changes, and nothing switches "
        .. "while this window is open.", L, ROW_TOP - #RULES * ROW - 30, width - 32)

    return function()
        local on = ns.Get("autoSwitch")
        master:SetChecked(on)
        say:SetChecked(ns.Get("autoSay"))
        local text, colour = StatusText()
        status:SetText(text)
        status:SetTextColor(colour[1], colour[2], colour[3])
        local now = A.Now()
        local _, deciding = A.Decide(now)
        local dual = A.DualSpec()
        for _, control in ipairs(rows) do
            control:Sync()
            local state = ""
            if control.rule == "talent2" and dual == false then
                state = "Dual spec not learned yet"
            elseif on and control.rule == deciding then
                state = "Now"
            elseif on and A.Matches(control.rule, now) then
                state = "Matches"
            end
            control.state:SetText(state)
        end
        otherwise:SetText("Otherwise: your own profile, " .. tostring(ns.OwnProfile()) .. ".")
    end
end

-- The Mounts tab.
local function BuildMounts(window, page, pane, list, width)
    local status = T:Text(pane, "GameFontHighlight")
    status:SetPoint("TOPLEFT", L, -48)
    status:SetWidth(width - 32)
    status:SetWordWrap(false)
    window.mountStatus = status
    local add = T:Button(pane, "Add the mount you're on", 190, 22)
    add:SetPoint("TOPLEFT", L, -72)
    window:Hint(add, function()
        local id, on = A.Mount()
        if not on then return "Get on a mount first, then click to list it." end
        if not id then return "The game hasn't said which mount you're on: pick it with Pick a mount instead." end
        if ns.MountListed(id) then return "This mount is listed already." end
        return "List the mount you're on, then pick its profile."
    end)
    window.addMount = add
    -- The page going closes it (PickList); so does its tab going.
    local mountList = P.PickList(window, page, 280)
    pane:HookScript("OnHide", function() mountList:Hide() end)
    window.mountList = mountList
    local choose = T:Button(pane, "Pick a mount", 130, 22)
    choose:SetPoint("TOPLEFT", L + 200, -72)
    window:Hint(choose, "Pick one of the mounts you have to list it.")
    window.pickMount = choose
    local count = T:Text(pane, "GameFontHighlightSmall", T.MUTED)
    count:SetPoint("LEFT", choose, "RIGHT", 10, 0)
    local heading = T:Heading(pane, "Your mounts" .. P.TESTING)
    heading:SetPoint("TOPLEFT", L, -108)

    local function Added(id)
        local ok, why = ns.AddMount(id)
        local name = A.MountInfo(id) or ("Mount " .. id)
        window:Say(ok and (name .. " is listed: pick its profile.") or why)
        A:RulesChanged()
        window:Refresh()
    end
    add:SetScript("OnClick", function()
        local id = A.Mount()
        if not id then
            window:Say("The game hasn't said which mount you're on: pick it with Pick a mount.")
            return window:Refresh()
        end
        Added(id)
    end)
    choose:SetScript("OnClick", function(self)
        if mountList:IsShown() and mountList.owner == self then return mountList:Hide() end
        local items = {}
        for _, mount in ipairs(A.Collected()) do
            items[#items + 1] = { key = mount.id, label = mount.name, icon = mount.icon }
        end
        if #items == 0 then
            window:Say("The game lists no mounts for you yet.")
            return window:Refresh()
        end
        mountList:Open(self, -72, items, nil, function(item) Added(item.key) end, "Pick a mount to list it.", function(item)
            if ns.MountListed(item.key) then return item.label .. " is listed already." end
            return "List " .. item.label .. "."
        end)
    end)

    -- The mounts listed, scrolling past MOUNT_ROWS. Pinned by two corners.
    local scroll = T:Scroll(pane, MOUNT_WIDTH)
    local function Pin()
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", L, MOUNT_TOP)
        scroll:SetPoint("BOTTOMRIGHT", pane, "TOPLEFT", L + MOUNT_WIDTH, MOUNT_TOP - MOUNT_ROWS * MOUNT_ROW)
        scroll:ScrollTo(scroll:GetVerticalScroll() or 0)
    end
    Pin()
    pane:HookScript("OnShow", function() C_Timer.After(0, Pin) end)
    window:Hint(scroll.thumb, ns.SCROLL_NOTE)
    local empty = T:Text(pane, "GameFontHighlightSmall", T.MUTED)
    empty:SetPoint("TOPLEFT", L, MOUNT_TOP - 4)
    empty:SetText("No mounts listed yet: add the one you're on, or pick one.")
    local rows = {}
    local function Row(i)
        if rows[i] then return rows[i] end
        local row = CreateFrame("Frame", nil, scroll.content)
        row:SetSize(MOUNT_WIDTH, MOUNT_ROW - 2)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * MOUNT_ROW)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", 0, 0)
        row.name = T:Text(row, "GameFontHighlight")
        row.name:SetPoint("LEFT", 28, 0)
        row.name:SetWidth(180)
        row.name:SetWordWrap(false)
        row.picker = P.ProfilePicker(window, row, list, {
            x = 214, y = -2, width = PICK_WIDTH, forWhat = "this mount", with = "while you ride it",
            none = "None: this mount leaves it to the next rule.",
            -- Where the row shows now, the list scrolled or not.
            listY = function() return MOUNT_TOP - (i - 1) * MOUNT_ROW + (scroll:GetVerticalScroll() or 0) end,
            hint = function() return "The profile shown while you ride " .. (row.label or "this mount") .. ". Click to pick one, or None." end,
            Get = function() return row.id and ns.MountPick(row.id) end,
            Pick = function(name)
                local ok, why = ns.SetMountPick(row.id, name)
                window:Say(ok and ((name or "None") .. " for " .. (row.label or "this mount") .. ".") or why)
                A:RulesChanged()
                window:Refresh()
            end,
        })
        row.remove = T:Square(row, "x")
        row.remove:SetSize(16, 16)
        row.remove:SetPoint("LEFT", 214 + PICK_WIDTH + 8, 0)
        row.remove:SetScript("OnClick", function()
            local ok, why = ns.RemoveMount(row.id)
            window:Say(ok and ((row.label or "The mount") .. " is off the list.") or why)
            A:RulesChanged()
            window:Refresh()
        end)
        window:Hint(row.remove, function() return "Take " .. (row.label or "this mount") .. " off the list." end)
        rows[i] = row
        return row
    end
    window.mountRows = rows

    return function()
        local id, on = A.Mount()
        if id then
            local name, _, icon = A.MountInfo(id)
            status:SetText("You're on: " .. (icon and ("|T" .. icon .. ":16|t ") or "") .. (name or ("mount " .. id)))
        elseif on then
            status:SetText("Mounted, but the game hasn't said which mount: pick it with Pick a mount.")
        else
            status:SetText("Not mounted.")
        end
        P.Usable(add, id ~= nil and not ns.MountListed(id) and #ns.MountIDs() < ns.MOUNT_MAX)
        local ids = ns.MountIDs()
        P.Usable(choose, #ids < ns.MOUNT_MAX)
        count:SetText(#ids .. " of " .. ns.MOUNT_MAX)
        for i, mountID in ipairs(ids) do
            local row = Row(i)
            local name, _, icon = A.MountInfo(mountID)
            row.id, row.label = mountID, name or ("Mount " .. mountID)
            row.name:SetText(row.label)
            row.icon:SetTexture(icon or 134400)
            row.picker:Sync()
            row:Show()
        end
        for i = #ids + 1, #rows do rows[i]:Hide() end
        empty:SetShown(#ids == 0)
        scroll.content:SetHeight(math.max(1, #ids * MOUNT_ROW))
        Pin()
    end
end

function ns.BuildAutoSwitchPage(window, page, width)
    page.tab = "rules"
    local tabs = T:Segmented(page, TABS, 240, function(key)
        page.tab = key
        window:Refresh()
    end)
    tabs:SetPoint("TOPLEFT", L, -16)
    for i, button in ipairs(tabs.buttons) do window:Hint(button, TABS[i].note) end
    page.tabs = tabs
    local list = P.PickList(window, page, PICK_WIDTH)
    page.pickList = list
    local panes, refresh = {}, {}
    for _, item in ipairs(TABS) do
        local pane = CreateFrame("Frame", nil, page)
        pane:SetPoint("TOPLEFT")
        pane:SetSize(width, page:GetHeight() or 489)
        pane:HookScript("OnHide", function() list:Hide() end)
        panes[item.key] = pane
    end
    page.panes = panes
    refresh.rules = BuildRules(window, page, panes.rules, list, width)
    refresh.mounts = BuildMounts(window, page, panes.mounts, list, width)

    function page:Refresh()
        tabs:SetSelected(self.tab)
        for key, pane in pairs(panes) do pane:SetShown(key == self.tab) end
        refresh[self.tab]()
    end
end
