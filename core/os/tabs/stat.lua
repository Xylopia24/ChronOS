-- STAT tab: placeholder — awaiting stats peripheral/API

local ThemeManager = require("ThemeManager")

local stat = {}

local function th() return ThemeManager.getColors() end

function stat.render(x, y, w, h)
    local t = th()
    local fg = t.primary or colors.green
    local bg = t.background or colors.black
    local dim = t.textSecondary or colors.lime

    term.setBackgroundColor(bg)
    term.clear()

    -- Title
    term.setTextColor(fg)
    term.setCursorPos(math.floor((w - 13) / 2) + x, y + 1)
    term.write("S.P.E.C.I.A.L.")

    -- Separator
    term.setTextColor(dim)
    term.setCursorPos(x, y + 2)
    term.write(string.rep("\x83", w))

    -- Placeholder box
    local boxW, boxH = 36, 7
    local bx = math.floor((w - boxW) / 2) + x
    local by = y + 4

    term.setTextColor(fg)
    term.setCursorPos(bx, by)
    term.write("\x9c" .. string.rep("\x8c", boxW - 2) .. "\x93")
    for i = 1, boxH - 2 do
        term.setCursorPos(bx, by + i)
        term.write("\x95" .. string.rep(" ", boxW - 2) .. "\x95")
    end
    term.setCursorPos(bx, by + boxH - 1)
    term.write("\x8d" .. string.rep("\x8c", boxW - 2) .. "\x8e")

    -- Content inside box
    local lines = {
        "",
        "  [ COMING SOON ]",
        "",
        "  Awaiting stats API connection.",
        "",
        "  Link an inventory/stats peripheral",
        "  to populate this screen.",
    }
    for i, line in ipairs(lines) do
        if by + i < by + boxH - 1 then
            term.setCursorPos(bx + 1, by + i)
            term.setTextColor(i == 2 and dim or fg)
            term.write(line:sub(1, boxW - 2))
        end
    end

    -- System info below box
    local infoY = by + boxH + 1
    term.setTextColor(dim)
    term.setCursorPos(x + 2, infoY)
    term.write("Computer ID : " .. os.getComputerID())
    term.setCursorPos(x + 2, infoY + 1)
    term.write(string.format("Uptime      : %.1fs", os.clock()))
    term.setCursorPos(x + 2, infoY + 2)
    term.write("CC Version  : " .. (tostring(_HOST or "CC:Tweaked"):match("ComputerCraft (.+)") or "Unknown"))
end

function stat.handleEvent() end

return stat
