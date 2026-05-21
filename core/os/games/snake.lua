-- Snake for ChronosOS GameLib
local GameLib = require("GameLib")

-- Play field border corners (within the 80x26 game window)
local BX1, BY1 = 2,  2
local BX2, BY2 = 54, 24
local FX1 = BX1 + 1;  local FX2 = BX2 - 1
local FY1 = BY1 + 1;  local FY2 = BY2 - 1
local FW  = FX2 - FX1 + 1   -- playable width  (51)
local FH  = FY2 - FY1 + 1   -- playable height (21)

local function run(area)
    local w, h = area.w, area.h

    local snake, dir, nextDir, food, score, over, interval

    local function reset()
        snake    = {{ x = math.floor(FW / 2), y = math.floor(FH / 2) }}
        dir      = { x = 1, y = 0 }
        nextDir  = { x = 1, y = 0 }
        food     = nil
        score    = 0
        over     = false
        interval = 0.3
    end

    local function spawnFood()
        local occ = {}
        for _, s in ipairs(snake) do occ[s.y * 1000 + s.x] = true end
        local x, y, tries = 1, 1, 0
        repeat
            x = math.random(1, FW)
            y = math.random(1, FH)
            tries = tries + 1
        until not occ[y * 1000 + x] or tries > 200
        food = { x = x, y = y }
    end

    local function draw()
        term.setBackgroundColor(colors.black)
        term.clear()

        -- Title
        term.setTextColor(colors.green)
        term.setCursorPos(math.floor((w - 5) / 2) + 1, 1)
        term.write("SNAKE")

        -- Border
        term.setCursorPos(BX1, BY1)
        term.write("+" .. string.rep("-", BX2 - BX1 - 1) .. "+")
        for y = BY1 + 1, BY2 - 1 do
            term.setCursorPos(BX1, y); term.write("|")
            term.setCursorPos(BX2, y); term.write("|")
        end
        term.setCursorPos(BX1, BY2)
        term.write("+" .. string.rep("-", BX2 - BX1 - 1) .. "+")

        -- Clear field interior
        term.setTextColor(colors.black)
        for y = FY1, FY2 do
            term.setCursorPos(FX1, y)
            term.write(string.rep(" ", FW))
        end

        -- Food
        if food then
            term.setCursorPos(FX1 + food.x - 1, FY1 + food.y - 1)
            term.setTextColor(colors.red)
            term.write("*")
        end

        -- Snake body then head (so head draws on top)
        for i = #snake, 1, -1 do
            local seg = snake[i]
            term.setCursorPos(FX1 + seg.x - 1, FY1 + seg.y - 1)
            if i == 1 then
                term.setTextColor(colors.lime)
                term.write("@")
            else
                term.setTextColor(colors.green)
                term.write("#")
            end
        end

        -- Score panel (right of border)
        local px = BX2 + 3
        term.setTextColor(colors.green)
        term.setCursorPos(px, 3);  term.write("SCORE")
        term.setTextColor(colors.lime)
        term.setCursorPos(px, 4);  term.write(tostring(score))

        term.setTextColor(colors.green)
        term.setCursorPos(px, 6);  term.write("LENGTH")
        term.setTextColor(colors.lime)
        term.setCursorPos(px, 7);  term.write(tostring(#snake))

        term.setTextColor(colors.green)
        term.setCursorPos(px, 9);  term.write("SPEED")
        term.setTextColor(colors.lime)
        local pct = math.floor((1 - interval / 0.3) * 100)
        term.setCursorPos(px, 10); term.write(pct .. "%")

        -- Game-over overlay
        if over then
            local lines = {
                "  GAME OVER!  ",
                string.format("  Score: %d  ", score),
                "  N: New Game  ",
                "  Q: Quit      ",
            }
            local mw = 0
            for _, l in ipairs(lines) do mw = math.max(mw, #l) end
            local ox = math.floor((BX1 + BX2 - mw) / 2)
            local oy = math.floor((BY1 + BY2) / 2) - 1
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.white)
            for i, line in ipairs(lines) do
                local row = oy + i - 1
                term.setCursorPos(ox, row)
                term.write(string.rep(" ", mw))
                term.setCursorPos(ox + math.floor((mw - #line) / 2), row)
                term.write(line)
            end
            term.setBackgroundColor(colors.black)
        end

        -- Hint bar
        term.setTextColor(colors.green)
        term.setCursorPos(1, h)
        term.write(" arrow keys: steer  |  q: quit")
    end

    -- ── Main loop ─────────────────────────────────────────────────────────────

    reset()
    spawnFood()
    local timerId = os.startTimer(interval)
    draw()

    while true do
        local ev, p1 = os.pullEvent()

        if ev == "key" then
            if p1 == keys.q then
                return
            elseif p1 == keys.n and over then
                reset()
                spawnFood()
                timerId = os.startTimer(interval)
            elseif not over then
                if     p1 == keys.up    and dir.y == 0 then nextDir = { x=0,  y=-1 }
                elseif p1 == keys.down  and dir.y == 0 then nextDir = { x=0,  y=1  }
                elseif p1 == keys.left  and dir.x == 0 then nextDir = { x=-1, y=0  }
                elseif p1 == keys.right and dir.x == 0 then nextDir = { x=1,  y=0  }
                end
            end

        elseif ev == "timer" and p1 == timerId and not over then
            dir = nextDir
            local hd   = snake[1]
            local newH = { x = hd.x + dir.x, y = hd.y + dir.y }

            if newH.x < 1 or newH.x > FW or newH.y < 1 or newH.y > FH then
                over = true
            else
                -- Skip last segment in collision check (it vacates before new head arrives)
                local hit = false
                for i = 1, #snake - 1 do
                    if snake[i].x == newH.x and snake[i].y == newH.y then
                        hit = true; break
                    end
                end
                if hit then
                    over = true
                else
                    table.insert(snake, 1, newH)
                    if food and newH.x == food.x and newH.y == food.y then
                        score    = score + 10
                        interval = math.max(0.1, interval - 0.01)
                        spawnFood()
                    else
                        table.remove(snake)
                    end
                    timerId = os.startTimer(interval)
                end
            end
        end

        draw()
    end
end

GameLib.register("Snake", "Classic snake - eat, grow, don't hit the walls!", run)
