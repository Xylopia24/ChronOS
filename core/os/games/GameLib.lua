-- GameLib: framework for registering and launching ChronosOS games

local GameLib = {}

local registry = {}   -- { [name] = {name, description, run} }

-- Register a game. runFn receives an area table: {x,y,w,h}
function GameLib.register(name, description, runFn)
    registry[name] = { name = name, description = description, run = runFn }
end

-- Returns a sorted list of registered game tables
function GameLib.list()
    local out = {}
    for _, g in pairs(registry) do
        out[#out + 1] = g
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Run a game by name. area = {x, y, w, h} for the screen region to use.
-- The game runs inside a sub-window; the OS chrome is not touched.
function GameLib.run(name, area)
    local g = registry[name]
    if not g then return false, "Game not found: " .. tostring(name) end

    local win = window.create(term.current(), area.x, area.y, area.w, area.h, true)
    local old = term.redirect(win)
    local ok, err = pcall(g.run, area)
    term.redirect(old)

    if not ok then return false, err end
    return true
end

return GameLib
