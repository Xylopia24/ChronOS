-- SETTINGS tab: theme picker and OS options

local ThemeManager = require("ThemeManager")
local TabManager   = require("TabManager")

local settings = {}

local function th() return ThemeManager.getColors() end

-- ── State ─────────────────────────────────────────────────────────────────────

local SECTIONS = { "THEME", "DISPLAY", "ABOUT" }
local activeSection = 1

local themeList     = {}
local themeSelected = 1

-- ── Theme helpers ─────────────────────────────────────────────────────────────

local function refreshThemeList()
    themeList = ThemeManager.listThemes()
    local active = ThemeManager.getActive()
    for i, name in ipairs(themeList) do
        if name == active then themeSelected = i; break end
    end
end

local function applyTheme(name)
    ThemeManager.loadTheme(name)
    ThemeManager.savePreference(name)
    TabManager.notifyThemeChanged()
end

-- ── Drawing constants ─────────────────────────────────────────────────────────

local SECTION_LABELS = { "[THEME]", "[DISPLAY]", "[ABOUT]" }
local THEME_LIST_Y = 7
local THEME_LIST_H = 10
local GFX_BTN_ROW  = 11

-- ── Graphics mode demo ────────────────────────────────────────────────────────

local function launchGfxDemo()
    local native = (term.native and term.native()) or term
    if not native.setGraphicsMode then return end

    native.setGraphicsMode(1)

    -- Get pixel dimensions; fall back to text-mode * 6/9 ratio
    local tw, tht = native.getSize()
    local pw, ph  = tw * 6, tht * 9
    local ok, pxw, pxh = pcall(native.getSize, true)
    if ok and type(pxw) == "number" then pw, ph = pxw, pxh end

    -- Draw a 4x4 grid showing all 16 CC color indices (0-15)
    local cols, rows = 4, 4
    local swW = math.floor(pw / cols)
    local swH = math.floor(ph / rows)
    for ci = 0, 15 do
        local gx = (ci % cols) * swW
        local gy = math.floor(ci / cols) * swH
        if native.drawPixels then
            local rowStr = string.rep(string.char(ci), swW)
            for dy = 0, swH - 1 do
                native.drawPixels(gx, gy + dy, rowStr)
            end
        else
            for dy = 0, swH - 1 do
                for dx = 0, swW - 1 do
                    native.setPixel(gx + dx, gy + dy, ci)
                end
            end
        end
    end

    os.pullEvent("key")
    native.setGraphicsMode(0)
    TabManager.notifyThemeChanged()
end

-- ── Section drawing ───────────────────────────────────────────────────────────

local function drawSectionBar(w)
    local t   = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local hl  = t.primary or colors.green
    local dim = t.textSecondary or colors.lime

    term.setCursorPos(1, 2)
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    term.write(string.rep(" ", w))
    term.setCursorPos(1, 2)

    local col = 2
    for i, label in ipairs(SECTION_LABELS) do
        if i == activeSection then
            term.setBackgroundColor(hl)
            term.setTextColor(bg)
        else
            term.setBackgroundColor(bg)
            term.setTextColor(dim)
        end
        term.write(" " .. label .. " ")
        term.setBackgroundColor(bg)
        term.setTextColor(fg)
        term.write("  ")
        col = col + #label + 4
    end
end

local function drawThemeSection(w, h)
    local t   = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local dim = t.textSecondary or colors.lime
    local hl  = t.primary or colors.green

    term.setTextColor(fg)
    term.setCursorPos(2, 4)
    term.write("Select a color theme:")
    term.setTextColor(dim)
    term.setCursorPos(1, 5)
    term.write(string.rep("\x83", w))

    term.setCursorPos(2, 6)
    term.setTextColor(dim)
    term.write("Active: " .. ThemeManager.getActive())

    for row = 0, THEME_LIST_H - 1 do
        local idx  = row + 1
        local name = themeList[idx]
        term.setCursorPos(4, THEME_LIST_Y + row)
        if not name then
            term.setBackgroundColor(bg)
            term.write(string.rep(" ", 30))
        elseif idx == themeSelected then
            term.setBackgroundColor(hl)
            term.setTextColor(bg)
            local label = "  \xbb " .. name
            term.write(label .. string.rep(" ", 30 - #label))
            term.setBackgroundColor(bg)
        else
            term.setBackgroundColor(bg)
            term.setTextColor(fg)
            local label = "    " .. name
            term.write(label .. string.rep(" ", 30 - #label))
        end
    end

    local btnY = THEME_LIST_Y + THEME_LIST_H + 1
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    term.setCursorPos(4, btnY)
    term.write("[ Apply Theme ]")

    term.setTextColor(dim)
    term.setCursorPos(1, h)
    term.write(" \x1e\x1f navigate   enter apply   click select")
end

local function drawDisplaySection(w, h)
    local t   = th()
    local fg  = t.primary or colors.green
    local dim = t.textSecondary or colors.lime

    term.setTextColor(fg)
    term.setCursorPos(2, 4)
    term.write("Display Options")
    term.setTextColor(dim)
    term.setCursorPos(1, 5)
    term.write(string.rep("\x83", w))

    -- Pull size from the native terminal so we see the full 80x30, not the
    -- content-window dimensions that term currently points to.
    local native        = (term.native and term.native()) or term
    local fullW, fullH  = native.getSize()
    term.setCursorPos(2, 7)
    term.setTextColor(fg)
    term.write(string.format("Screen Size  : %d \xd7 %d", fullW, fullH))

    local hasGfx = native.setGraphicsMode ~= nil
    term.setCursorPos(2, 8)
    if hasGfx then
        local mode    = native.getGraphicsMode and native.getGraphicsMode() or 0
        local modeStr = mode == 0 and "Text (Mode 0)" or ("Pixel (Mode " .. mode .. ")")
        term.write("Graphics Mode: " .. modeStr)

        term.setCursorPos(2, 9)
        term.setTextColor(dim)
        term.write(string.format("Pixel Canvas : %d \xd7 %d", fullW * 6, fullH * 9))

        term.setCursorPos(2, GFX_BTN_ROW)
        term.setTextColor(fg)
        term.write("[ Launch Pixel Demo ]")
        term.setCursorPos(2, GFX_BTN_ROW + 1)
        term.setTextColor(dim)
        term.write("16-color swatch. Press any key to return.")
        term.setCursorPos(1, h)
        term.write(" enter / click to launch demo")
    else
        term.write("Graphics Mode: N/A  (CraftOS-PC required)")
        term.setCursorPos(2, 9)
        term.setTextColor(dim)
        term.write("Run inside CraftOS-PC for graphics mode support.")
    end
end

local function drawAboutSection(w)
    local t   = th()
    local fg  = t.primary or colors.green
    local dim = t.textSecondary or colors.lime

    local lines = {
        "   \xbb C H R O N O S  O S \xab",
        "",
        "   Version   : 1.0.0",
        "   Platform  : ComputerCraft Pocket PC",
        "   Screen    : 80 \xd7 30",
        "   Libraries : PixelUI, Taskmaster",
        "   Shell     : Mildly Better Shell",
        "",
        "   \x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83",
        "",
        "   \"War. War never changes.\"",
    }

    local startY = 4
    for i, line in ipairs(lines) do
        term.setCursorPos(1, startY + i - 1)
        term.setTextColor(i == 1 and fg or dim)
        term.write(line:sub(1, w))
    end
end

-- ── Public interface ──────────────────────────────────────────────────────────

function settings.render(_, _, w, h)
    local t  = th()
    local bg = t.background or colors.black
    local fg = t.primary or colors.green

    term.setBackgroundColor(bg)
    term.clear()

    term.setTextColor(fg)
    term.setCursorPos(math.floor((w - 8) / 2) + 1, 1)
    term.write("SETTINGS")

    drawSectionBar(w)

    if activeSection == 1 then
        drawThemeSection(w, h)
    elseif activeSection == 2 then
        drawDisplaySection(w, h)
    else
        drawAboutSection(w)
    end
end

function settings.handleEvent(ev, p1, p2, p3)
    if ev == "key" then
        local k = p1
        if k == keys.left then
            activeSection = math.max(1, activeSection - 1)
        elseif k == keys.right then
            activeSection = math.min(#SECTIONS, activeSection + 1)
        elseif activeSection == 1 then
            if k == keys.up then
                themeSelected = math.max(1, themeSelected - 1)
            elseif k == keys.down then
                themeSelected = math.min(#themeList, themeSelected + 1)
            elseif k == keys.enter then
                local name = themeList[themeSelected]
                if name then applyTheme(name) end
            end
        elseif activeSection == 2 then
            if k == keys.enter then launchGfxDemo() end
        end

    elseif ev == "mouse_click" then
        local mx, my = p2, p3

        -- Section bar (row 2)
        if my == 2 then
            local col = 2
            for i, label in ipairs(SECTION_LABELS) do
                local labelLen = #label + 4
                if mx >= col and mx < col + labelLen then
                    activeSection = i
                    break
                end
                col = col + labelLen
            end
            return
        end

        if activeSection == 1 then
            if my >= THEME_LIST_Y and my < THEME_LIST_Y + THEME_LIST_H then
                local idx = my - THEME_LIST_Y + 1
                if idx >= 1 and idx <= #themeList then
                    if idx == themeSelected then
                        local name = themeList[themeSelected]
                        if name then applyTheme(name) end
                    else
                        themeSelected = idx
                    end
                end
            end
            local btnY = THEME_LIST_Y + THEME_LIST_H + 1
            if my == btnY and mx >= 4 and mx <= 18 then
                local name = themeList[themeSelected]
                if name then applyTheme(name) end
            end

        elseif activeSection == 2 then
            if my == GFX_BTN_ROW and mx >= 2 and mx <= 22 then
                launchGfxDemo()
            end
        end
    end
end

function settings.onEnter()
    refreshThemeList()
end

return settings
