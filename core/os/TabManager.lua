-- TabManager: renders PipBoy chrome and routes between tab modules

local ThemeManager = require("ThemeManager")
local Peripherals  = require("Peripherals")
local taskmaster   = require("taskmaster")

local TabManager = {}

-- ── Tab registry ──────────────────────────────────────────────────────────────

local TAB_NAMES = { "STAT", "DATA", "GAMES", "RADIO", "SETTINGS" }
local TAB_PATHS = {
    STAT     = "tabs.stat",
    DATA     = "tabs.data",
    GAMES    = "tabs.games",
    RADIO    = "tabs.radio",
    SETTINGS = "tabs.settings",
}

local loadedTabs  = {}  -- cache of required tab modules
local activeTab   = 1   -- index into TAB_NAMES
local statusCache = { speaker = false, modem = false }

-- ── Layout constants ──────────────────────────────────────────────────────────

local W = 80
local HEADER_ROW  = 1
local TABBAR_ROW  = 2
local SEP_ROW     = 3
local CONTENT_TOP = 3   -- rows 3–28 (26 rows)
local CONTENT_H   = 26
local STATUS_ROW  = 29
local HINT_ROW    = 30

-- ── Tab column layout (pre-computed) ─────────────────────────────────────────
-- Each tab entry has { label, startX, width }
-- We spread them evenly across 80 columns (leave 2-char margins)

local TAB_LAYOUT = {}
do
    local labels = TAB_NAMES
    local totalPad = W - 4  -- leave 2 chars each side
    local tabW = math.floor(totalPad / #labels)
    local startX = 3
    for i, name in ipairs(labels) do
        TAB_LAYOUT[i] = { label = name, x = startX, w = tabW }
        startX = startX + tabW
    end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function tc(col) term.setTextColor(col) end
local function bc(col) term.setBackgroundColor(col) end

local function hline(y, char, fg, bg)
    tc(fg) bc(bg)
    term.setCursorPos(1, y)
    term.write(string.rep(char, W))
end

local function writeAt(x, y, text, fg, bg)
    if fg then tc(fg) end
    if bg then bc(bg) end
    term.setCursorPos(x, y)
    term.write(text)
end

local function pad(str, width)
    local s = tostring(str)
    if #s >= width then return s:sub(1, width) end
    local lpad = math.floor((width - #s) / 2)
    local rpad = width - #s - lpad
    return string.rep(" ", lpad) .. s .. string.rep(" ", rpad)
end

local function getTheme()
    return ThemeManager.getColors()
end

-- ── Clock ─────────────────────────────────────────────────────────────────────

local function formatTime()
    local t = os.time()
    local h = math.floor(t)
    local m = math.floor((t - h) * 60)
    return string.format("%02d:%02d", h % 24, m)
end

local function formatDay()
    return "Day " .. os.day()
end

-- ── Chrome drawing ────────────────────────────────────────────────────────────

local function drawHeader()
    local th = getTheme()
    local fg = th.primary or colors.green
    local bg = th.background or colors.black
    bc(bg) tc(fg)
    term.setCursorPos(1, HEADER_ROW)
    term.clearLine()

    -- Left: OS name
    local title = " \xbb CHRONO OS "
    writeAt(1, HEADER_ROW, title, fg, bg)

    -- Right: time + day
    local timeStr = formatTime()
    local dayStr  = formatDay()
    local right   = "[" .. timeStr .. "] [" .. dayStr .. "] "
    writeAt(W - #right, HEADER_ROW, right, fg, bg)
end

local function drawTabBar()
    local th  = getTheme()
    local fg  = th.primary   or colors.green
    local bg  = th.background or colors.black
    local hlf = th.secondary  or colors.lime    -- active tab FG

    bc(bg) tc(fg)
    term.setCursorPos(1, TABBAR_ROW)
    term.clearLine()

    for i, entry in ipairs(TAB_LAYOUT) do
        local label = pad(entry.label, entry.w)
        if i == activeTab then
            writeAt(entry.x, TABBAR_ROW, label, hlf, fg)
        else
            writeAt(entry.x, TABBAR_ROW, label, fg, bg)
        end
    end
end

local function drawSeparator()
    local th = getTheme()
    local fg = th.border or colors.green
    local bg = th.background or colors.black
    hline(SEP_ROW, "\x83", fg, bg)   -- CC half-block separator
end

local function drawStatusBar()
    local th  = getTheme()
    local fg  = th.primary   or colors.green
    local bg  = th.background or colors.black
    local okc = th.success   or colors.lime
    local erc = th.error     or colors.red

    hline(STATUS_ROW, "\x83", fg, bg)

    local st = statusCache
    local spk = st.speaker and "\x10 SPK:OK" or "\x10 SPK:--"
    local mdm = st.modem   and "MDM:OK \x11" or "MDM:-- \x11"

    bc(bg)
    term.setCursorPos(1, HINT_ROW)
    term.clearLine()

    writeAt(2, HINT_ROW, "\x1b Click tab to navigate \x1a", fg, bg)

    local spkColor = st.speaker and okc or erc
    local mdmColor = st.modem   and okc or erc
    local col = W - #spk - #mdm - 3
    writeAt(col, HINT_ROW, spk, spkColor, bg)
    writeAt(col + #spk + 2, HINT_ROW, mdm, mdmColor, bg)
end

local function drawChrome()
    drawHeader()
    drawTabBar()
    drawSeparator()
    drawStatusBar()
end

-- ── Content area ──────────────────────────────────────────────────────────────

local function getTab(idx)
    if not loadedTabs[idx] then
        local modPath = TAB_PATHS[TAB_NAMES[idx]]
        local ok, mod = pcall(require, modPath)
        if ok then
            loadedTabs[idx] = mod
        else
            -- Fallback stub so the OS doesn't crash on a bad tab
            loadedTabs[idx] = {
                render = function()
                    local th = ThemeManager.getColors()
                    tc(th.error or colors.red) bc(th.background or colors.black)
                    term.setCursorPos(3, CONTENT_TOP + 2)
                    term.write("Error loading tab: " .. tostring(mod))
                end,
                handleEvent = function() end,
            }
        end
    end
    return loadedTabs[idx]
end

local contentWin = nil

local function makeContentWindow()
    contentWin = window.create(
        term.current(),
        1, CONTENT_TOP,
        W, CONTENT_H,
        true
    )
end

local function drawContent()
    local tab = getTab(activeTab)
    local old = term.redirect(contentWin)
    local th  = getTheme()
    bc(th.background or colors.black)
    contentWin.clear()
    local ok, err = pcall(tab.render, 1, 1, W, CONTENT_H)
    term.redirect(old)
    if not ok then
        writeAt(2, CONTENT_TOP + 1, "Tab error: " .. tostring(err),
                th.error or colors.red, th.background or colors.black)
    end
end

local function fullRedraw()
    local th = getTheme()
    bc(th.background or colors.black)
    term.clear()
    drawChrome()
    drawContent()
end

-- ── Tab switching ─────────────────────────────────────────────────────────────

local function switchTab(idx)
    if idx == activeTab then return end
    local old = getTab(activeTab)
    if old.onExit then pcall(old.onExit) end

    activeTab = idx
    -- onEnter first so state is populated before the first render
    local new = getTab(activeTab)
    if new.onEnter then pcall(new.onEnter) end

    drawTabBar()
    drawContent()
end

-- Returns the tab index whose column range contains x on the tab bar row,
-- or nil if x doesn't land on any tab.
local function tabAtX(x)
    for i, entry in ipairs(TAB_LAYOUT) do
        if x >= entry.x and x < entry.x + entry.w then
            return i
        end
    end
    return nil
end

-- ── Event dispatch ────────────────────────────────────────────────────────────

local function handleEvent(ev, p1, p2, p3, p4, p5)
    if ev == "mouse_click" then
        local y = p3
        if y == TABBAR_ROW then
            local x = p2
            local idx = tabAtX(x)
            if idx then switchTab(idx) end
            return
        end
        -- Forward clicks inside the content area to the active tab
        if y >= CONTENT_TOP and y < CONTENT_TOP + CONTENT_H then
            local tab = getTab(activeTab)
            if tab.handleEvent then
                -- Translate y to be relative to content window
                local old = term.redirect(contentWin)
                pcall(tab.handleEvent, ev, p1, p2, y - CONTENT_TOP + 1, p4, p5)
                term.redirect(old)
                drawContent()
            end
        end

    elseif ev == "mouse_scroll" then
        local y = p3
        if y >= CONTENT_TOP and y < CONTENT_TOP + CONTENT_H then
            local tab = getTab(activeTab)
            if tab.handleEvent then
                local old = term.redirect(contentWin)
                pcall(tab.handleEvent, ev, p1, p2, y - CONTENT_TOP + 1, p4, p5)
                term.redirect(old)
                drawContent()
            end
        end

    elseif ev == "char" or ev == "key" or ev == "key_up" or ev == "paste" then
        local tab = getTab(activeTab)
        if tab.handleEvent then
            local old = term.redirect(contentWin)
            local redraw = pcall(tab.handleEvent, ev, p1, p2, p3, p4, p5)
            term.redirect(old)
            if redraw ~= false then drawContent() end
        end

    elseif ev == "chronos_tick" then
        drawHeader()
        drawStatusBar()
        drawContent()  -- keeps all tab content live (uptime, file lists, etc.)

    elseif ev == "chronos_theme_changed" then
        -- Full redraw needed when theme switches
        makeContentWindow()
        fullRedraw()

    elseif ev == "terminate" then
        -- Clean up and exit
        local th = getTheme()
        bc(th.background or colors.black)
        term.clear()
        term.setCursorPos(1, 1)
        tc(colors.white)
        print("ChronosOS terminated.")
        os.exit()
    end
end

-- ── Main loop ─────────────────────────────────────────────────────────────────

function TabManager.run()
    -- Ensure terminal is text mode
    if term.setGraphicsMode then
        term.setGraphicsMode(0)
    end

    makeContentWindow()

    -- Fire onEnter for the initial tab so it can populate state before first draw
    local initialTab = getTab(activeTab)
    if initialTab.onEnter then pcall(initialTab.onEnter) end

    fullRedraw()

    local loop = taskmaster()

    -- Main UI task
    loop:addTask(function()
        while true do
            local ev = table.pack(os.pullEventRaw())
            handleEvent(table.unpack(ev, 1, ev.n))
        end
    end)

    -- Tick task: every game tick (0.05s = minimum CC timer resolution)
    loop:addTimer(0.05, function()
        os.queueEvent("chronos_tick")
    end)

    -- Peripheral status refresh: slow so it never blocks the render path
    statusCache = Peripherals.status()
    loop:addTimer(3, function()
        statusCache = Peripherals.status()
    end)

    loop:waitForAll()
end

-- Expose for use by tab modules (e.g. settings tab triggers theme change)
function TabManager.notifyThemeChanged()
    os.queueEvent("chronos_theme_changed")
end

return TabManager
