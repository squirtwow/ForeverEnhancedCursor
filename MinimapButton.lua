-- The minimap button: click for the settings, drag it round the minimap
-- (and, once there are notes, right-click for What's new). A dark circle in
-- the minimap's gold ring, with this addon's cursor and trail, and a small
-- tooltip of its own in the window's style. The General page turns it off.
local _, ns = ...
local T = ns.Theme

local M = {}
ns.MinimapButton = M

local RING_GAP = 4 -- how far out from the minimap's edge it sits
local AFTER_DRAG = .2 -- a click this soon after a drag is the drag letting go
local atan2 = math.atan2 or math.atan

local button, tip, dragAngle
local dropped = -math.huge

-- What the mouse does, as the tooltip lists it.
local function TipLines()
    local lines = { "Click: settings" }
    if ns.ShowNotes then lines[#lines + 1] = "Right-click: What's new" end
    lines[#lines + 1] = "Drag: move it round the minimap"
    return lines
end

-- Round the minimap's edge at the saved angle: degrees anticlockwise from the
-- right, so 180 is the left. While dragging, where the cursor is.
function M:Place()
    if not button then return end
    local angle = math.rad(dragAngle or ns.Get("minimapAngle"))
    local radius = Minimap:GetWidth() / 2 + RING_GAP
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function Follow()
    local x, y = Minimap:GetCenter()
    if not x then return end
    local scale = Minimap:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    dragAngle = math.floor(math.deg(atan2(cursorY / scale - y, cursorX / scale - x)) + .5) % 360
    M:Place()
end

-- Saved once, where it was let go.
local function Drop(self)
    self:SetScript("OnUpdate", nil)
    self.isMoving = nil
    dropped = GetTime()
    local angle = dragAngle
    dragAngle = nil
    if angle then ns.Set("minimapAngle", angle) end
    M:Place()
end

-- The tooltip: the addon's name in the accent, then what the mouse does.
local function BuildTip()
    local lines = TipLines()
    tip = CreateFrame("Frame", "FECursorMinimapTip", UIParent, "BackdropTemplate")
    tip:SetSize(220, 24 + #lines * 14)
    tip:SetFrameStrata("TOOLTIP")
    tip:SetClampedToScreen(true)
    T:Flat(tip, T.BG, T.CONTROL_BORDER)
    tip:Hide()
    tip.title = T:Text(tip, "GameFontHighlight")
    tip.title:SetPoint("TOPLEFT", 10, -8)
    tip.title:SetText(ns.TITLE)
    T:Paint(function(accent) tip.title:SetTextColor(accent[1], accent[2], accent[3]) end)
    tip.lines = {}
    for i, line in ipairs(lines) do
        local text = T:Text(tip, "GameFontHighlightSmall", T.TEXT)
        text:SetPoint("TOPLEFT", 10, -12 - i * 14)
        text:SetText(line)
        tip.lines[i] = text
    end
end

function M:Apply()
    if not button then return end
    button:SetShown(ns.Get("minimap"))
    self:Place()
end

function M:Button()
    return button
end

function M:Start()
    if button or not Minimap then return end
    button = CreateFrame("Button", "FECursorMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    back:SetSize(20, 20)
    back:SetPoint("CENTER")
    back:SetVertexColor(.067, .071, .082)
    local glyph = button:CreateTexture(nil, "ARTWORK")
    glyph:SetTexture(ns.MEDIA .. "MinimapIcon.tga")
    glyph:SetSize(16, 16)
    glyph:SetPoint("CENTER")
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetSize(54, 54)
    ring:SetPoint("TOPLEFT")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function(_, click)
        if GetTime() - dropped < AFTER_DRAG then return end
        if click == "RightButton" then
            if ns.ShowNotes then ns.ShowNotes() end
        else
            ns.Toggle()
        end
    end)
    -- isMoving tells minimap tidiers not to fade it mid-drag, when the cursor
    -- can be well off the button.
    button:SetScript("OnDragStart", function(self)
        if tip then tip:Hide() end
        self.isMoving = true
        self:SetScript("OnUpdate", Follow)
    end)
    button:SetScript("OnDragStop", Drop)
    -- Hidden mid-drag: let go there, so it doesn't trail the cursor later.
    button:SetScript("OnHide", function(self)
        if tip then tip:Hide() end
        if self.isMoving then Drop(self) end
    end)
    button:SetScript("OnEnter", function(self)
        if self.isMoving then return end
        if not tip then BuildTip() end
        tip:ClearAllPoints()
        tip:SetPoint("TOPRIGHT", self, "BOTTOMLEFT", 4, 4)
        tip:Show()
    end)
    button:SetScript("OnLeave", function() if tip then tip:Hide() end end)
    -- The minimap can change size: stay on its edge.
    Minimap:HookScript("OnSizeChanged", function() M:Place() end)
    self:Apply()
end

function M:Tip()
    return tip
end
