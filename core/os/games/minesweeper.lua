-- Minesweeper for ChronosOS GameLib
local GameLib = require("GameLib")

local ROWS, COLS, MINES = 9, 9, 10
local CELL_W = 3

-- Pre-compute grid anchor (centered in 80-wide area)
local GX = math.floor((80 - COLS * CELL_W) / 2) + 1
local GY = 4

-- ── State ─────────────────────────────────────────────────────────────────────

local function newState()
    local grid = {}
    for r = 1, ROWS do
        grid[r] = {}
        for c = 1, COLS do
            grid[r][c] = { mine=false, revealed=false, flagged=false, count=0 }
        end
    end
    return {
        grid        = grid,
        curR        = 1, curC = 1,
        phase       = "waiting",  -- waiting | playing | won | lost
        flagCount   = 0,
        revealCount = 0,
        startTime   = nil,
    }
end

local function placeMines(gs, skipR, skipC)
    local placed = 0
    while placed < MINES do
        local r = math.random(1, ROWS)
        local c = math.random(1, COLS)
        if not gs.grid[r][c].mine and not (r == skipR and c == skipC) then
            gs.grid[r][c].mine = true
            placed = placed + 1
        end
    end
    for r = 1, ROWS do
        for c = 1, COLS do
            if not gs.grid[r][c].mine then
                local n = 0
                for dr = -1, 1 do
                    for dc = -1, 1 do
                        local nr, nc = r + dr, c + dc
                        if nr >= 1 and nr <= ROWS and nc >= 1 and nc <= COLS
                           and gs.grid[nr][nc].mine then
                            n = n + 1
                        end
                    end
                end
                gs.grid[r][c].count = n
            end
        end
    end
end

local function floodReveal(gs, r, c)
    local cell = gs.grid[r][c]
    if cell.revealed or cell.flagged then return end
    cell.revealed      = true
    gs.revealCount     = gs.revealCount + 1
    if cell.count == 0 and not cell.mine then
        for dr = -1, 1 do
            for dc = -1, 1 do
                local nr, nc = r + dr, c + dc
                if nr >= 1 and nr <= ROWS and nc >= 1 and nc <= COLS then
                    floodReveal(gs, nr, nc)
                end
            end
        end
    end
end

local function doReveal(gs, r, c)
    if gs.phase == "won" or gs.phase == "lost" then return end
    if gs.grid[r][c].flagged then return end
    if gs.phase == "waiting" then
        placeMines(gs, r, c)
        gs.startTime = os.clock()
        gs.phase     = "playing"
    end
    if gs.grid[r][c].mine then
        gs.grid[r][c].revealed = true
        gs.phase = "lost"
    else
        floodReveal(gs, r, c)
        if gs.revealCount == ROWS * COLS - MINES then gs.phase = "won" end
    end
end

local function doFlag(gs, r, c)
    if gs.phase == "won" or gs.phase == "lost" then return end
    local cell = gs.grid[r][c]
    if cell.revealed then return end
    if cell.flagged then
        cell.flagged  = false
        gs.flagCount  = gs.flagCount - 1
    else
        cell.flagged  = true
        gs.flagCount  = gs.flagCount + 1
    end
end

-- ── Drawing ───────────────────────────────────────────────────────────────────

local NUM_FG = {
    [1]=colors.blue,   [2]=colors.green,  [3]=colors.red,
    [4]=colors.purple, [5]=colors.brown,  [6]=colors.cyan,
    [7]=colors.white,  [8]=colors.gray,
}

local function draw(gs, w, h)
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Title
    term.setTextColor(colors.green)
    term.setCursorPos(math.floor((w - 11) / 2) + 1, 1)
    term.write("MINESWEEPER")

    -- Stats bar
    term.setTextColor(colors.lime)
    term.setCursorPos(2, 2)
    term.write(string.format("Mines: %d  Flagged: %d  Remaining: %d",
        MINES, gs.flagCount, MINES - gs.flagCount))
    if gs.startTime then
        local ts = string.format("Time: %ds", math.floor(os.clock() - gs.startTime))
        term.setCursorPos(w - #ts, 2)
        term.write(ts)
    end

    -- Separator
    term.setTextColor(colors.green)
    term.setCursorPos(1, 3)
    term.write(string.rep("\x83", w))

    -- Grid
    for r = 1, ROWS do
        for c = 1, COLS do
            local cell  = gs.grid[r][c]
            local x     = GX + (c - 1) * CELL_W
            local y     = GY + (r - 1)
            local isCur = (r == gs.curR and c == gs.curC)
            term.setCursorPos(x, y)
            if cell.revealed then
                if cell.mine then
                    term.setBackgroundColor(colors.red)
                    term.setTextColor(colors.white)
                    term.write("[*]")
                elseif cell.count == 0 then
                    term.setBackgroundColor(isCur and colors.gray or colors.black)
                    term.setTextColor(colors.black)
                    term.write("   ")
                else
                    term.setBackgroundColor(isCur and colors.gray or colors.black)
                    term.setTextColor(NUM_FG[cell.count] or colors.white)
                    term.write(string.format("[%d]", cell.count))
                end
            elseif cell.flagged then
                term.setBackgroundColor(isCur and colors.orange or colors.gray)
                term.setTextColor(colors.red)
                term.write("[F]")
            else
                term.setBackgroundColor(isCur and colors.lime or colors.gray)
                term.setTextColor(colors.black)
                term.write("[ ]")
            end
        end
    end
    term.setBackgroundColor(colors.black)

    -- Status
    local statusY = GY + ROWS + 1
    term.setCursorPos(1, statusY)
    term.setTextColor(colors.green)
    term.write(string.rep("\x83", w))
    term.setCursorPos(2, statusY + 1)
    if gs.phase == "won" then
        term.setTextColor(colors.lime)
        term.write("YOU WIN!  All " .. MINES .. " mines avoided.  N = new game")
    elseif gs.phase == "lost" then
        term.setTextColor(colors.red)
        term.write("BOOM!  You hit a mine.  N = new game")
    elseif gs.phase == "waiting" then
        term.setTextColor(colors.lime)
        term.write("First reveal is always safe.  Good luck, Vault Dweller!")
    else
        term.setTextColor(colors.lime)
        term.write(string.format("%d cells remaining.", ROWS * COLS - MINES - gs.revealCount))
    end

    -- Hint bar
    term.setCursorPos(1, h)
    term.setTextColor(colors.green)
    term.write(" arrows move | enter/lclick reveal | f/rclick flag | n new | q quit")
end

-- ── Hit-test ──────────────────────────────────────────────────────────────────

local function hitTest(mx, my)
    local c = math.floor((mx - GX) / CELL_W) + 1
    local r = my - GY + 1
    if r >= 1 and r <= ROWS and c >= 1 and c <= COLS then return r, c end
end

-- ── Main ──────────────────────────────────────────────────────────────────────

local function run(area)
    local w, h = area.w, area.h
    local gs   = newState()
    draw(gs, w, h)

    while true do
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "key" then
            if     p1 == keys.q     then return
            elseif p1 == keys.n     then gs = newState()
            elseif p1 == keys.up    then gs.curR = math.max(1,    gs.curR - 1)
            elseif p1 == keys.down  then gs.curR = math.min(ROWS, gs.curR + 1)
            elseif p1 == keys.left  then gs.curC = math.max(1,    gs.curC - 1)
            elseif p1 == keys.right then gs.curC = math.min(COLS, gs.curC + 1)
            elseif p1 == keys.enter or p1 == keys.space then
                doReveal(gs, gs.curR, gs.curC)
            elseif p1 == keys.f then
                doFlag(gs, gs.curR, gs.curC)
            end
        elseif ev == "mouse_click" then
            local btn, mx, my = p1, p2, p3
            local r, c = hitTest(mx, my)
            if r then
                gs.curR, gs.curC = r, c
                if     btn == 1 then doReveal(gs, r, c)
                elseif btn == 2 then doFlag(gs, r, c)
                end
            end
        end
        draw(gs, w, h)
    end
end

GameLib.register("Minesweeper", "Classic mine-avoidance puzzle", run)
