-- The Trail page: the preview at the top, then the trail's switches and its
-- look in two columns, and the extras. Every change shows at once, in the
-- preview and on the real cursor.
local _, ns = ...
local T = ns.Theme
local P = ns.PageParts

local NOTES = {
    trail = "A trail of soft dots follows the cursor and fades out behind it. Off, nothing is drawn and nothing runs.",
    trailCombat = "Draw the trail only in a fight. Once the fight ends, its last dots fade and it stops.",
    trailSpacing = "How far apart the dots are along the path, in pixels. Closer is smoother; wider is lighter.",
    trailLife = "How long each dot lasts before it has faded out, in seconds. Longer makes a longer trail.",
    trailMax = "The most dots at once. A long, close trail on a fast flick needs more; fewer is lighter.",
    trailAlpha = "How solid the trail is at the cursor, in percent. It fades out from there.",
    trailWidth = "Each dot's width, in pixels.",
    trailHeight = "Each dot's height, in pixels.",
    trailX = "Moves the trail left (below 0) or right of the cursor's point, in pixels.",
    trailY = "Moves the trail down (below 0) or up from the cursor's point, in pixels.",
    trailGlow = "The dots add their light together, so they glow brighter where they overlap.",
    trailShrink = "Each dot shrinks as it fades, so the trail tapers to a point.",
    trailAlign = "Each dot turns to point along the path: it shows once Width and Height differ.",
}
ns.TRAIL_NOTES = NOTES

function ns.BuildTrailPage(window, page)
    local L, R, Y = P.LEFT, P.RIGHT, P.Y
    local controls = {}
    local function Add(control) controls[#controls + 1] = control; return control end
    local function Tick(label, key, x, y) return Add(P.Tick(window, page, label, key, x, y, NOTES[key])) end
    local function Slider(label, key, x, y) return Add(P.Slider(window, page, label, key, x, y, NOTES[key])) end

    local trail = Tick("Show the cursor trail", "trail", L, Y(0))
    window.trailTick = trail
    Tick("Only in combat", "trailCombat", R, Y(0))
    Slider("Dot spacing", "trailSpacing", L, Y(1))
    Slider("Lifetime", "trailLife", R, Y(1))
    Slider("Max dots", "trailMax", L, Y(2))
    Slider("Opacity", "trailAlpha", R, Y(2))
    Slider("Width", "trailWidth", L, Y(3))
    Slider("Height", "trailHeight", R, Y(3))
    Slider("X offset", "trailX", L, Y(4))
    Slider("Y offset", "trailY", R, Y(4))

    T:Heading(page, "Extras"):SetPoint("TOPLEFT", L, Y(5) + 4)
    Tick("Glow", "trailGlow", L, Y(5) - 16)
    Tick("Shrink as it fades", "trailShrink", 140, Y(5) - 16)
    Tick("Turn dots along the path", "trailAlign", R, Y(5) - 16)
    Add(P.Notice(page, "trail", L, Y(6) - 6))

    page.controls = controls
    page.focus = "trail"
    function page:Refresh()
        P.SyncAll(controls)
        -- Off, its tick is lit in the accent: the one thing to click first.
        trail:SetNudged(not ns.Get("trail"))
    end
end
