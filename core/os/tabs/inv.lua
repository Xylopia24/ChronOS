-- INV tab: placeholder — awaiting inventory peripheral connection

local ThemeManager = require("ThemeManager")

local inv = {}

local function th() return ThemeManager.getColors() end

function inv.render(x, y, w, h)
    local t = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local dim = t.textSecondary or colors.lime

    term.setBackgroundColor(bg)
    term.clear()

    -- Title
    term.setTextColor(fg)
    term.setCursorPos(math.floor((w - 9) / 2) + x, y + 1)
    term.write("INVENTORY")

    -- Separator
    term.setTextColor(dim)
    term.setCursorPos(x, y + 2)
    term.write(string.rep("\x83", w))

    -- Grid placeholder lines
    local gridTop = y + 4
    local colW = 18
    local cols = math.floor(w / colW)

    term.setTextColor(fg)
    for col = 0, cols - 1 do
        for row = 0, 8 do
            local gx = x + col * colW + 1
            local gy = gridTop + row * 2
            if gy < y + h - 2 then
                term.setCursorPos(gx, gy)
                term.write("[\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83]")
            end
        end
    end

    -- Overlay message
    local msg1 = "[ INVENTORY OFFLINE ]"
    local msg2 = "Connect an inventory peripheral"
    local msg3 = "to the Pocket Computer."
    local cy = y + math.floor(h / 2) - 1
    local bx = math.floor((w - #msg1 - 4) / 2) + x

    term.setBackgroundColor(bg)
    term.setTextColor(dim)
    term.setCursorPos(bx, cy - 1)
    term.write(string.rep("\x83", #msg1 + 4))
    term.setCursorPos(bx, cy)
    term.setTextColor(fg)
    term.write("  " .. msg1 .. "  ")
    term.setTextColor(dim)
    term.setCursorPos(bx, cy + 1)
    term.write(string.rep("\x83", #msg1 + 4))

    term.setTextColor(fg)
    term.setCursorPos(math.floor((w - #msg2) / 2) + x, cy + 3)
    term.write(msg2)
    term.setCursorPos(math.floor((w - #msg3) / 2) + x, cy + 4)
    term.write(msg3)
end

function inv.handleEvent() end

return inv
