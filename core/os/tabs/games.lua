-- GAMES tab: lists and launches registered games via GameLib

local ThemeManager = require("ThemeManager")
local GameLib      = require("GameLib")

local games = {}

local function th() return ThemeManager.getColors() end

-- ── Auto-discover game files in /core/os/games/ ───────────────────────────────
-- Each .lua file (except GameLib itself) may call GameLib.register() when loaded.

local GAMES_DIR = "/core/os/games"
local discovered = false

local function discoverGames()
    if discovered then return end
    discovered = true
    if not fs.exists(GAMES_DIR) then return end
    for _, name in ipairs(fs.list(GAMES_DIR)) do
        if name:match("%.lua$") and name ~= "GameLib.lua" then
            local modName = name:gsub("%.lua$", "")
            pcall(require, modName)
        end
    end
end

-- ── State ─────────────────────────────────────────────────────────────────────

local selected = 1
local message  = nil   -- feedback string after running a game

-- ── Drawing ───────────────────────────────────────────────────────────────────

local function drawGameList(list, w, h)
    local t   = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local dim = t.textSecondary or colors.lime
    local hl  = t.primary or colors.green

    term.setBackgroundColor(bg)
    term.clear()

    -- Title
    term.setTextColor(fg)
    term.setCursorPos(math.floor((w - 5) / 2) + 1, 2)
    term.write("GAMES")
    term.setTextColor(dim)
    term.setCursorPos(1, 3)
    term.write(string.rep("\x83", w))

    if #list == 0 then
        local msg1 = "[ NO GAMES INSTALLED ]"
        local msg2 = "Add game files to /core/os/games/"
        term.setTextColor(fg)
        term.setCursorPos(math.floor((w - #msg1) / 2) + 1, math.floor(h / 2))
        term.write(msg1)
        term.setTextColor(dim)
        term.setCursorPos(math.floor((w - #msg2) / 2) + 1, math.floor(h / 2) + 2)
        term.write(msg2)
        return
    end

    local listTop = 5
    for i, g in ipairs(list) do
        local row = listTop + (i - 1) * 3
        if row + 2 > h then break end

        if i == selected then
            term.setBackgroundColor(hl)
            term.setTextColor(bg)
        else
            term.setBackgroundColor(bg)
            term.setTextColor(fg)
        end

        -- Game name row
        term.setCursorPos(4, row)
        local nameLine = "  " .. g.name
        term.write(nameLine .. string.rep(" ", w - #nameLine - 3))

        -- Description row
        if i == selected then
            term.setBackgroundColor(bg)
            term.setTextColor(dim)
        else
            term.setTextColor(dim)
        end
        term.setCursorPos(6, row + 1)
        local desc = (g.description or ""):sub(1, w - 7)
        term.write(desc)
        term.setBackgroundColor(bg)
    end

    -- Hint bar
    term.setTextColor(dim)
    term.setCursorPos(1, h)
    local hint = " \x1e\x1f navigate   enter launch   click select"
    term.write(hint:sub(1, w))

    -- Message feedback
    if message then
        term.setCursorPos(math.floor((w - #message) / 2) + 1, h - 2)
        term.setTextColor(t.error or colors.red)
        term.write(message:sub(1, w))
    end
end

-- ── Public interface ──────────────────────────────────────────────────────────

function games.render(x, y, w, h)
    discoverGames()
    local list = GameLib.list()
    drawGameList(list, w, h)
end

function games.handleEvent(ev, p1, p2, p3)
    local list = GameLib.list()
    if #list == 0 then return end

    if ev == "key" then
        local k = p1
        if k == keys.up then
            selected = math.max(1, selected - 1)
            message  = nil
        elseif k == keys.down then
            selected = math.min(#list, selected + 1)
            message  = nil
        elseif k == keys.enter then
            local g = list[selected]
            if g then
                ThemeManager.resetPalette()
                local ok, err = GameLib.run(g.name, { x = 1, y = 1, w = 80, h = 26 })
                ThemeManager.restorePalette()
                if not ok then message = "Error: " .. tostring(err) end
            end
        end

    elseif ev == "mouse_click" then
        local my = p3
        local listTop = 5
        local idx = math.floor((my - listTop) / 3) + 1
        if idx >= 1 and idx <= #list then
            if idx == selected then
                ThemeManager.resetPalette()
                local ok, err = GameLib.run(list[selected].name, { x = 1, y = 1, w = 80, h = 26 })
                ThemeManager.restorePalette()
                if not ok then message = "Error: " .. tostring(err) end
            else
                selected = idx
                message  = nil
            end
        end
    end
end

function games.onEnter()
    discoverGames()
    message = nil
end

return games
