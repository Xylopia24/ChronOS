-- DATA tab: file browser, text editor, read-only viewer, file/folder creation

local ThemeManager = require("ThemeManager")

local data = {}

local function th() return ThemeManager.getColors() end

-- ── Layout constants ──────────────────────────────────────────────────────────

local LIST_X      = 2
local LIST_Y      = 4
local LIST_H      = 17
local LIST_W      = 30
local VIEWER_X    = 34
local VIEWER_W    = 46
local SANDBOX_ROOT = "/user"

-- ── Right-panel mode ──────────────────────────────────────────────────────────
-- "help"  → help guide (default, shown before any file is opened)
-- "view"  → read-only viewer for non-text files
-- "edit"  → text editor for editable files

local rightPanel = "help"

-- ── Browse state ──────────────────────────────────────────────────────────────

local cwd      = SANDBOX_ROOT
local dirStack = {}
local entries  = {}
local selected = 1
local scroll   = 0

-- ── View state ────────────────────────────────────────────────────────────────

local viewLines  = {}
local viewScroll = 0
local viewTitle  = ""

-- ── Editor state ──────────────────────────────────────────────────────────────

local editorLines    = {}
local editorCursorX  = 1
local editorCursorY  = 1
local editorScrollY  = 0
local editorModified = false
local editorPath     = nil
local editorTitle    = ""
local ctrlHeld       = false
local closePrompt    = false   -- true = "save / discard / cancel?" overlay

-- ── Creation / deletion dialog state ─────────────────────────────────────────

local creating   = false
local deleting   = false
local createStep = 1       -- 1 = choose type, 2 = enter name
local createType = nil     -- "file" | "folder"
local createName = ""

-- ── File-type detection ───────────────────────────────────────────────────────

local TEXT_EXTS = {
    txt=true, lua=true, json=true, md=true,
    cfg=true, log=true, sh=true, toml=true, csv=true,
}

local function isTextFile(name)
    local ext = name:match("%.([^%.]+)$")
    if not ext then return true end          -- no extension → treat as text
    return TEXT_EXTS[ext:lower()] == true
end

-- ── Path helpers ──────────────────────────────────────────────────────────────

local function joinPath(dir, name)
    if dir == "/" then return "/" .. name end
    return dir .. "/" .. name
end

-- ── Directory loading ─────────────────────────────────────────────────────────

local function loadDir(path)
    cwd = path
    entries = {}
    local ok, list = pcall(fs.list, path)
    if ok then
        local dirs, files = {}, {}
        for _, name in ipairs(list) do
            if fs.isDir(joinPath(path, name)) then dirs[#dirs+1] = name
            else files[#files+1] = name end
        end
        table.sort(dirs)
        table.sort(files)
        for _, n in ipairs(dirs)  do entries[#entries+1] = {name=n, isDir=true}  end
        for _, n in ipairs(files) do entries[#entries+1] = {name=n, isDir=false} end
    end
    selected = 1
    scroll   = 0
end

local function goInto(name)
    dirStack[#dirStack+1] = cwd
    loadDir(joinPath(cwd, name))
end

local function goUp()
    if cwd ~= SANDBOX_ROOT and #dirStack > 0 then
        loadDir(table.remove(dirStack))
    end
end

-- ── File I/O ──────────────────────────────────────────────────────────────────

local function readLines(path)
    local ok, f = pcall(fs.open, path, "r")
    if not ok or not f then return {""} end
    local lines, line = {}, f.readLine()
    while line do lines[#lines+1] = line; line = f.readLine() end
    f.close()
    return #lines > 0 and lines or {""}
end

local function saveEditor()
    if not editorPath then return false end
    local ok, f = pcall(fs.open, editorPath, "w")
    if not ok or not f then return false end
    for i, line in ipairs(editorLines) do
        if i < #editorLines then f.writeLine(line) else f.write(line) end
    end
    f.close()
    editorModified = false
    return true
end

-- ── Entry opening ─────────────────────────────────────────────────────────────

local function openEntry(entry)
    if not entry then return end
    if entry.isDir then goInto(entry.name); return end
    local full = joinPath(cwd, entry.name)
    if isTextFile(entry.name) then
        editorLines    = readLines(full)
        editorCursorX  = 1
        editorCursorY  = 1
        editorScrollY  = 0
        editorModified = false
        editorPath     = full
        editorTitle    = entry.name
        closePrompt    = false
        rightPanel     = "edit"
    else
        viewLines  = readLines(full)
        viewScroll = 0
        viewTitle  = entry.name
        rightPanel = "view"
    end
end

local function requestClose()
    if rightPanel == "edit" and editorModified then
        closePrompt = true
    else
        rightPanel  = "help"
        closePrompt = false
        term.setCursorBlink(false)
    end
end

-- ── Editor helpers ────────────────────────────────────────────────────────────

local function clampCursor()
    editorCursorY = math.max(1, math.min(#editorLines, editorCursorY))
    editorCursorX = math.max(1, math.min(#(editorLines[editorCursorY] or "") + 1, editorCursorX))
end

local function adjustScroll(contentH)
    if editorCursorY - 1 < editorScrollY then
        editorScrollY = editorCursorY - 1
    elseif editorCursorY > editorScrollY + contentH then
        editorScrollY = editorCursorY - contentH
    end
    editorScrollY = math.max(0, editorScrollY)
end

local function editorInsertChar(ch)
    local line = editorLines[editorCursorY] or ""
    editorLines[editorCursorY] = line:sub(1, editorCursorX-1) .. ch .. line:sub(editorCursorX)
    editorCursorX  = editorCursorX + 1
    editorModified = true
end

local function editorBackspace()
    if editorCursorX > 1 then
        local line = editorLines[editorCursorY] or ""
        editorLines[editorCursorY] = line:sub(1, editorCursorX-2) .. line:sub(editorCursorX)
        editorCursorX  = editorCursorX - 1
        editorModified = true
    elseif editorCursorY > 1 then
        local prev = editorLines[editorCursorY-1]
        editorCursorX = #prev + 1
        editorLines[editorCursorY-1] = prev .. (editorLines[editorCursorY] or "")
        table.remove(editorLines, editorCursorY)
        editorCursorY  = editorCursorY - 1
        editorModified = true
    end
end

local function editorDelete()
    local line = editorLines[editorCursorY] or ""
    if editorCursorX <= #line then
        editorLines[editorCursorY] = line:sub(1, editorCursorX-1) .. line:sub(editorCursorX+1)
        editorModified = true
    elseif editorCursorY < #editorLines then
        editorLines[editorCursorY] = line .. (editorLines[editorCursorY+1] or "")
        table.remove(editorLines, editorCursorY+1)
        editorModified = true
    end
end

local function editorEnter()
    local line   = editorLines[editorCursorY] or ""
    editorLines[editorCursorY] = line:sub(1, editorCursorX-1)
    table.insert(editorLines, editorCursorY+1, line:sub(editorCursorX))
    editorCursorY  = editorCursorY + 1
    editorCursorX  = 1
    editorModified = true
end

-- ── Drawing: left panel ───────────────────────────────────────────────────────

local function drawBreadcrumb(w)
    local t   = th()
    local fg  = t.primary or colors.green
    local dim = t.textSecondary or colors.lime
    local bg  = t.background or colors.black

    term.setBackgroundColor(bg)
    term.setTextColor(dim)
    term.setCursorPos(1, 1)
    -- Show path relative to sandbox root for a cleaner display
    local rel = cwd
    if rel:sub(1, #SANDBOX_ROOT) == SANDBOX_ROOT then
        rel = rel:sub(#SANDBOX_ROOT + 1)
        if rel == "" then rel = "/" end
    end
    local crumb = "LOC: " .. rel
    if #crumb > w then crumb = "..." .. crumb:sub(-(w-3)) end
    term.write(crumb .. string.rep(" ", w - #crumb))
    if #dirStack > 0 then
        local tag = " \x1b" .. #dirStack .. " "
        term.setCursorPos(w - #tag + 1, 1)
        term.setTextColor(fg)
        term.write(tag)
    end
    term.setTextColor(fg)
    term.setCursorPos(1, 2)
    term.write(string.rep("\x83", w))
end

local function drawFileList()
    local t   = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local hl  = t.primary or colors.green
    local dim = t.textSecondary or colors.lime

    for row = 0, LIST_H - 1 do
        local idx   = row + scroll + 1
        local entry = entries[idx]
        term.setCursorPos(LIST_X, LIST_Y + row)
        term.setBackgroundColor(bg)
        if not entry then
            term.write(string.rep(" ", LIST_W))
        elseif idx == selected then
            term.setBackgroundColor(hl)
            term.setTextColor(bg)
            local label = (entry.isDir and "\x10 " or "  ") .. entry.name
            local len   = math.min(#label, LIST_W)
            term.write(label:sub(1, len) .. string.rep(" ", LIST_W - len))
            term.setBackgroundColor(bg)
        else
            term.setTextColor(entry.isDir and dim or fg)
            local label = (entry.isDir and "\x10 " or "  ") .. entry.name
            local len   = math.min(#label, LIST_W)
            term.write(label:sub(1, len) .. string.rep(" ", LIST_W - len))
        end
    end
end

local function drawCreationDialog()
    local t   = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local dim = t.textSecondary or colors.lime
    local hi  = t.secondary or colors.lime
    local dy  = LIST_Y + LIST_H

    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    term.setCursorPos(LIST_X, dy)
    term.write(string.rep("\x83", LIST_W))

    if createStep == 1 then
        term.setCursorPos(LIST_X, dy+1)
        term.setTextColor(dim)
        term.write("New: ")
        term.setTextColor(fg)
        term.write("[F]ile  [D]ir")
        term.setCursorPos(LIST_X, dy+2)
        term.setTextColor(dim)
        term.write("[tab] cancel")
    else
        local prompt = createType == "folder" and "Dir:  " or "File: "
        term.setCursorPos(LIST_X, dy+1)
        term.setTextColor(dim)
        term.write(prompt)
        term.setTextColor(hi)
        local inputW  = LIST_W - #prompt - 1
        local display = (createName .. "\x95"):sub(1, inputW)
        term.write(display .. string.rep(" ", inputW - math.min(#display, inputW)))
        term.setCursorPos(LIST_X, dy+2)
        term.setTextColor(dim)
        term.write("[enter] create  [tab] cancel")
    end
end

local function drawDeleteDialog()
    local t   = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local dim = t.textSecondary or colors.lime
    local err = t.error or colors.red
    local dy  = LIST_Y + LIST_H

    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    term.setCursorPos(LIST_X, dy)
    term.write(string.rep("\x83", LIST_W))

    local entry = entries[selected]
    local name  = entry and entry.name or "?"
    term.setCursorPos(LIST_X, dy+1)
    term.setTextColor(err)
    local label = ("DEL: " .. name):sub(1, LIST_W)
    term.write(label .. string.rep(" ", LIST_W - #label))
    term.setCursorPos(LIST_X, dy+2)
    term.setTextColor(dim)
    term.write("[enter] confirm  [tab] cancel")
end

local function drawStorageBar()
    local t   = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local dim = t.textSecondary or colors.lime
    local dy  = LIST_Y + LIST_H

    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    term.setCursorPos(LIST_X, dy)
    term.write(string.rep("\x83", LIST_W))

    local free = fs.getFreeSpace("/")
    local cap  = fs.getCapacity and fs.getCapacity("/") or nil

    term.setCursorPos(LIST_X, dy+1)
    if cap and cap > 0 then
        local used   = cap - free
        local barW   = LIST_W - 2
        local filled = math.floor(barW * used / cap)
        term.setTextColor(dim)
        term.write("[")
        term.setTextColor(fg)
        term.write(string.rep("\x83", filled))
        term.setTextColor(dim)
        term.write(string.rep("-", barW - filled) .. "]")
        term.setCursorPos(LIST_X, dy+2)
        local pct     = math.floor(used / cap * 100)
        local used_kb = math.floor(used / 1024)
        local cap_kb  = math.floor(cap  / 1024)
        local info    = string.format("%dKB/%dKB %d%% used", used_kb, cap_kb, pct)
        info = info:sub(1, LIST_W)
        term.write(info .. string.rep(" ", LIST_W - #info))
    else
        term.setTextColor(fg)
        local info = string.format("Free: %dKB", math.floor(free / 1024)):sub(1, LIST_W)
        term.write(info .. string.rep(" ", LIST_W - #info))
        term.setCursorPos(LIST_X, dy+2)
        term.setTextColor(bg)
        term.write(string.rep(" ", LIST_W))
    end
end

local function drawHints(h)
    local t   = th()
    local bg  = t.background or colors.black
    local dim = t.textSecondary or colors.lime
    term.setBackgroundColor(bg)
    term.setTextColor(dim)
    term.setCursorPos(LIST_X, h)
    term.write(("\x1e\x1f move  ent open  n new d del"):sub(1, LIST_W))
end

-- ── Drawing: right panel ──────────────────────────────────────────────────────

local function drawHelp(h)
    local t   = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local dim = t.textSecondary or colors.lime
    local ox  = VIEWER_X

    -- Title
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    term.setCursorPos(ox, 1)
    local hdr = " \xbb DATA: HELP"
    term.write(hdr .. string.rep(" ", VIEWER_W - #hdr))
    term.setCursorPos(ox, 2)
    term.write(string.rep("\x83", VIEWER_W))

    local guide = {
        {" NAVIGATION",                        fg },
        {"  \x1e\x1f      Move selection",     dim},
        {"  Enter   Open file or folder",       dim},
        {"  Bksp    Go back / close panel",     dim},
        {"  Scroll  Scroll list or viewer",     dim},
        {"  PgUp/Dn Scroll viewer lines",       dim},
        {"",                                    dim},
        {" CREATING   (press N)",               fg },
        {"  N \x1a F  New text file (.txt)",    dim},
        {"  N \x1a D  New directory",           dim},
        {"  Enter   Confirm name",              dim},
        {"  Tab     Cancel at any time",        dim},
        {"",                                    dim},
        {" DELETING   (press D on selection)",  fg },
        {"  D        Mark selected for delete", dim},
        {"  Enter    Confirm deletion",         dim},
        {"  Tab      Cancel",                   dim},
        {"",                                    dim},
        {" TEXT EDITOR",                        fg },
        {"  Type    Insert characters",         dim},
        {"  Arrows  Move cursor",               dim},
        {"  Home/End  Start / end of line",     dim},
        {"  Enter   New line",                  dim},
        {"  Del     Delete character forward",  dim},
        {"  Ctrl+S  Save file",                 dim},
        {"  Tab     Close (asks if unsaved)",   dim},
        {"",                                    dim},
        {" Non-text files open read-only.",     dim},
    }

    for i, entry in ipairs(guide) do
        local row = 2 + i
        if row > h then break end
        term.setCursorPos(ox, row)
        term.setTextColor(entry[2])
        term.setBackgroundColor(bg)
        local text = entry[1]:sub(1, VIEWER_W)
        term.write(text .. string.rep(" ", VIEWER_W - #text))
    end
end

local function drawViewer(h)
    local t   = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local dim = t.textSecondary or colors.lime
    local ox  = VIEWER_X

    term.setBackgroundColor(bg)
    term.setTextColor(dim)
    term.setCursorPos(ox, 1)
    local hdr = (" \xbb " .. viewTitle .. " [read-only]"):sub(1, VIEWER_W)
    term.write(hdr .. string.rep(" ", VIEWER_W - #hdr))
    term.setCursorPos(ox, 2)
    term.setTextColor(fg)
    term.write(string.rep("\x83", VIEWER_W))

    local contentH = h - 3
    for row = 0, contentH - 1 do
        local line = (viewLines[row + viewScroll + 1] or ""):sub(1, VIEWER_W)
        term.setCursorPos(ox, 3 + row)
        term.setTextColor(fg)
        term.setBackgroundColor(bg)
        term.write(line .. string.rep(" ", VIEWER_W - #line))
    end

    term.setCursorPos(ox, h)
    term.setTextColor(dim)
    local hint = string.format("ln %d/%d  pgup/dn  bksp close", viewScroll+1, #viewLines)
    hint = hint:sub(1, VIEWER_W)
    term.write(hint .. string.rep(" ", VIEWER_W - #hint))
end

local function drawEditor(h)
    local t   = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local dim = t.textSecondary or colors.lime
    local hi  = t.secondary or colors.lime
    local ox  = VIEWER_X
    local contentH = h - 3

    -- Adjust scroll before drawing so lines are correct
    adjustScroll(contentH)

    -- Title bar: flickers secondary color when modified
    term.setBackgroundColor(bg)
    term.setTextColor(editorModified and hi or dim)
    term.setCursorPos(ox, 1)
    local marker = editorModified and " \x07" or ""
    local hdr    = (" \xbb " .. editorTitle .. marker):sub(1, VIEWER_W)
    term.write(hdr .. string.rep(" ", VIEWER_W - #hdr))
    term.setCursorPos(ox, 2)
    term.setTextColor(fg)
    term.write(string.rep("\x83", VIEWER_W))

    -- Unsaved-changes prompt overlay
    if closePrompt then
        for row = 0, contentH - 1 do
            local line = (editorLines[row + editorScrollY + 1] or ""):sub(1, VIEWER_W)
            term.setCursorPos(ox, 3 + row)
            term.setTextColor(dim)
            term.setBackgroundColor(bg)
            term.write(line .. string.rep(" ", VIEWER_W - #line))
        end
        local py = 3 + math.floor(contentH / 2) - 1
        term.setTextColor(fg)
        term.setBackgroundColor(bg)
        for _, row in ipairs({py-1, py, py+1, py+2}) do
            term.setCursorPos(ox, row)
            term.write(string.rep(" ", VIEWER_W))
        end
        term.setCursorPos(ox, py-1); term.write(string.rep("\x83", VIEWER_W))
        term.setCursorPos(ox, py);   term.write("  Unsaved changes in " .. editorTitle)
        term.setCursorPos(ox, py+1); term.write("  [S]ave   [D]iscard   [C]ancel")
        term.setCursorPos(ox, py+2); term.write(string.rep("\x83", VIEWER_W))
        return
    end

    -- Editor lines
    for row = 0, contentH - 1 do
        local lineIdx = row + editorScrollY + 1
        local line    = editorLines[lineIdx] or ""
        term.setCursorPos(ox, 3 + row)
        term.setBackgroundColor(bg)

        if lineIdx == editorCursorY then
            -- Render line with block cursor at editorCursorX
            local before = line:sub(1, editorCursorX - 1):sub(1, VIEWER_W)
            local atChar = line:sub(editorCursorX, editorCursorX)
            local after  = line:sub(editorCursorX + 1)

            term.setTextColor(fg)
            term.write(before)

            local curScreenX = ox + #before
            if curScreenX <= ox + VIEWER_W - 1 then
                term.setCursorPos(curScreenX, 3 + row)
                term.setBackgroundColor(fg)
                term.setTextColor(bg)
                term.write(atChar == "" and " " or atChar:sub(1,1))
                term.setBackgroundColor(bg)
                term.setTextColor(fg)
                local rem = VIEWER_W - #before - 1
                if rem > 0 then
                    local a = after:sub(1, rem)
                    term.write(a .. string.rep(" ", rem - #a))
                end
            end
        else
            term.setTextColor(fg)
            local sub = line:sub(1, VIEWER_W)
            term.write(sub .. string.rep(" ", VIEWER_W - #sub))
        end
    end

    -- Status bar
    term.setCursorPos(ox, h)
    term.setTextColor(dim)
    local status = string.format("Ln:%d/%d Col:%d  ^S save  tab close",
        editorCursorY, #editorLines, editorCursorX)
    status = status:sub(1, VIEWER_W)
    term.write(status .. string.rep(" ", VIEWER_W - #status))

    -- Position real terminal cursor for OS-level blink
    local screenRow = 3 + (editorCursorY - 1 - editorScrollY)
    local screenCol = ox + math.min(editorCursorX - 1, VIEWER_W - 1)
    if screenRow >= 3 and screenRow < 3 + contentH then
        term.setCursorPos(screenCol, screenRow)
        term.setCursorBlink(true)
    else
        term.setCursorBlink(false)
    end
end

-- ── Public interface ──────────────────────────────────────────────────────────

local function createItem()
    if createName == "" then return end
    local name = createName
    if createType == "file" and not name:find("%.") then name = name .. ".txt" end
    local full = joinPath(cwd, name)
    if createType == "folder" then
        pcall(fs.makeDir, full)
    else
        local ok, f = pcall(fs.open, full, "w")
        if ok and f then f.close() end
    end
    creating = false; createName = ""; createType = nil; createStep = 1
    loadDir(cwd)
end

function data.render(_, _, w, h)
    local t  = th()
    local fg = t.primary or colors.green
    local bg = t.background or colors.black

    -- Suppress cursor flicker while drawing
    if rightPanel ~= "edit" then term.setCursorBlink(false) end

    term.setBackgroundColor(bg)
    term.clear()

    drawBreadcrumb(w)

    -- Panel divider
    term.setTextColor(fg)
    term.setBackgroundColor(bg)
    for row = 1, h do
        term.setCursorPos(LIST_X + LIST_W + 1, row)
        term.write("\x95")
    end

    drawFileList()

    if creating then
        drawCreationDialog()
    elseif deleting then
        drawDeleteDialog()
    else
        drawStorageBar()
    end
    drawHints(h)

    if     rightPanel == "help" then drawHelp(h)
    elseif rightPanel == "view" then drawViewer(h)
    elseif rightPanel == "edit" then drawEditor(h)
    end
end

function data.handleEvent(ev, p1, p2, p3)
    -- Track Ctrl key held state for Ctrl+S
    if ev == "key_up" then
        if p1 == keys.leftCtrl or p1 == keys.rightCtrl then ctrlHeld = false end
        return
    end
    if ev == "key" then
        if p1 == keys.leftCtrl or p1 == keys.rightCtrl then ctrlHeld = true end
    end

    -- ── Creation dialog ────────────────────────────────────────────────────────
    if creating then
        if ev == "key" then
            local k = p1
            if k == keys.tab then
                creating = false; createName = ""; createType = nil; createStep = 1
            elseif createStep == 1 then
                if     k == keys.f then createType = "file";   createStep = 2
                elseif k == keys.d then createType = "folder"; createStep = 2 end
            elseif createStep == 2 then
                if     k == keys.enter     then createItem()
                elseif k == keys.backspace then createName = createName:sub(1, -2) end
            end
        elseif ev == "char" and createStep == 2 then
            if p1 ~= "/" and p1 ~= "\\" then createName = createName .. p1 end
        end
        return
    end

    -- ── Deletion confirmation ──────────────────────────────────────────────────
    if deleting then
        if ev == "key" then
            local k = p1
            if k == keys.tab then
                deleting = false
            elseif k == keys.enter then
                local entry = entries[selected]
                if entry then
                    pcall(fs.delete, joinPath(cwd, entry.name))
                    deleting = false
                    loadDir(cwd)
                end
            end
        end
        return
    end

    -- ── Unsaved-changes prompt ─────────────────────────────────────────────────
    if closePrompt then
        if ev == "key" then
            local k = p1
            if k == keys.s then
                saveEditor(); rightPanel = "help"; closePrompt = false
                term.setCursorBlink(false)
            elseif k == keys.d then
                editorModified = false; rightPanel = "help"; closePrompt = false
                term.setCursorBlink(false)
            elseif k == keys.c or k == keys.tab then
                closePrompt = false
            end
        end
        return
    end

    -- ── Text editor ────────────────────────────────────────────────────────────
    if rightPanel == "edit" then
        if ev == "key" then
            local k = p1
            if ctrlHeld then
                if k == keys.s then saveEditor() end
            elseif k == keys.tab then
                requestClose()
            elseif k == keys.backspace then
                editorBackspace()
            elseif k == keys.delete then
                editorDelete()
            elseif k == keys.enter then
                editorEnter()
            elseif k == keys.left then
                if editorCursorX > 1 then
                    editorCursorX = editorCursorX - 1
                elseif editorCursorY > 1 then
                    editorCursorY = editorCursorY - 1
                    editorCursorX = #(editorLines[editorCursorY] or "") + 1
                end
            elseif k == keys.right then
                local ll = #(editorLines[editorCursorY] or "")
                if editorCursorX <= ll then
                    editorCursorX = editorCursorX + 1
                elseif editorCursorY < #editorLines then
                    editorCursorY = editorCursorY + 1; editorCursorX = 1
                end
            elseif k == keys.up then
                if editorCursorY > 1 then editorCursorY = editorCursorY - 1; clampCursor() end
            elseif k == keys.down then
                if editorCursorY < #editorLines then editorCursorY = editorCursorY + 1; clampCursor() end
            elseif k == keys.home then
                editorCursorX = 1
            elseif k == keys["end"] then
                editorCursorX = #(editorLines[editorCursorY] or "") + 1
            elseif k == keys.pageUp then
                editorCursorY = math.max(1, editorCursorY - 10); clampCursor()
            elseif k == keys.pageDown then
                editorCursorY = math.min(#editorLines, editorCursorY + 10); clampCursor()
            end
        elseif ev == "char" then
            editorInsertChar(p1)
        end
        return
    end

    -- ── Read-only viewer ───────────────────────────────────────────────────────
    if rightPanel == "view" then
        if ev == "key" then
            local k = p1
            if k == keys.backspace or k == keys.tab then
                rightPanel = "help"
            elseif k == keys.pageUp   then viewScroll = math.max(0, viewScroll - 10)
            elseif k == keys.pageDown then viewScroll = math.min(math.max(0, #viewLines - 10), viewScroll + 10)
            end
        elseif ev == "mouse_scroll" and p2 >= VIEWER_X then
            viewScroll = math.max(0, math.min(math.max(0, #viewLines - 10), viewScroll + p1))
        end
        return
    end

    -- ── Browse mode ────────────────────────────────────────────────────────────
    if ev == "key" then
        local k = p1
        if k == keys.up then
            if selected > 1 then
                selected = selected - 1
                if selected <= scroll then scroll = scroll - 1 end
            end
        elseif k == keys.down then
            if selected < #entries then
                selected = selected + 1
                if selected > scroll + LIST_H then scroll = scroll + 1 end
            end
        elseif k == keys.enter then
            openEntry(entries[selected])
        elseif k == keys.backspace then
            goUp()
        elseif k == keys.n then
            creating = true; createStep = 1; createName = ""; createType = nil
        elseif k == keys.d then
            if #entries > 0 then deleting = true end
        end

    elseif ev == "mouse_scroll" and p2 < VIEWER_X then
        scroll   = math.max(0, math.min(math.max(0, #entries - LIST_H), scroll + p1))
        selected = math.max(scroll+1, math.min(scroll+LIST_H, selected))

    elseif ev == "mouse_click" then
        local mx, my = p2, p3
        if mx >= LIST_X and mx < LIST_X + LIST_W and my >= LIST_Y and my < LIST_Y + LIST_H then
            local idx = my - LIST_Y + scroll + 1
            if idx >= 1 and idx <= #entries then
                if selected == idx then openEntry(entries[selected])
                else selected = idx end
            end
        end
    end
end

function data.onEnter()
    if not fs.exists(SANDBOX_ROOT) then
        pcall(fs.makeDir, SANDBOX_ROOT)
    end
    if #entries == 0 then
        dirStack = {}
        loadDir(SANDBOX_ROOT)
    end
end

function data.onExit()
    term.setCursorBlink(false)
end

return data
