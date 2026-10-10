-- The public API ------------------------------------------------------------------------
-- For other addons, read-only. EraUI (Squirt's own) has cursor effects of its
-- own and can step aside for this addon's while it's loaded: hide its own
-- trail, cursor ring and cast ring and their options, and point its players
-- here instead.
--   ForeverEnhancedCursorAPI.version                   1
--   ForeverEnhancedCursorAPI.OwnsCursorEffects()       true while this addon is loaded: it draws the
--       cursor trail, the ring round the cursor and cast progress round the cursor
--   ForeverEnhancedCursorAPI.OwnsCursorEffects(kind)   the same for one effect: true for "trail",
--       "ring" and "cast" (the three EraUI has), false for anything else
--   ForeverEnhancedCursorAPI.IsShown(kind)             whether an effect is on in the profile showing:
--       kind "trail", "ring", "cast", "look" (the highlight while looking) or "marker" (the marker on
--       the pointer); false for anything else
--   ForeverEnhancedCursorAPI.OpenSettings(page)        opens the /fec window, on a page if one is
--       named ("trail", "colours", "rings", "marker", "profiles", "autoswitch" or "general"); true if it opened
-- Nothing here changes a setting.
local _, ns = ...

local api = { version = 1 }

local KINDS = { trail = "trail", ring = "ring", cast = "cast", look = "look", marker = "marker" }
local OWNED = { trail = true, ring = true, cast = true }

function api.OwnsCursorEffects(kind)
    if kind == nil then return true end
    return type(kind) == "string" and OWNED[kind] == true
end

function api.IsShown(kind)
    local key = type(kind) == "string" and KINDS[kind]
    if not key then return false end
    return ns.Get(key) == true
end

function api.OpenSettings(page)
    if not ns.ShowWindow then return false end
    local ok = pcall(ns.ShowWindow)
    if not ok or not ns.window then return false end
    if type(page) == "string" and ns.window.pages[page] then ns.window:Select(page) end
    return true
end

ForeverEnhancedCursorAPI = setmetatable({}, {
    __index = api,
    __newindex = function() error("ForeverEnhancedCursorAPI is read-only", 2) end,
    __metatable = false,
})
