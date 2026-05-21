-- AdventureGame for ChronosOS GameLib
-- A customizable text adventure set in Vault 13
local GameLib = require("GameLib")

-- ==========================================================================
-- WORLD DATA  —  Edit freely to build your own adventure
--
-- ITEMS: Each key is the item's internal ID.
--   name     : display name shown to the player
--   desc     : text shown when the player examines the item
--   takeable : true if the player can pick it up
--   onUse    : (optional) message shown when player types "use <item>"
--              if nil, a generic "not sure how to use that" message appears
--
-- ROOMS: Each key is the room's internal ID.
--   name  : display name shown in the header
--   desc  : description shown when looking at the room
--   exits : table of direction -> destination
--             direction can be: north south east west up down (or any string)
--             destination is either:
--               "room_id"  — open passage
--               { dest="room_id", key="item_id", msg="locked message" }
--                           — locked: player needs item_id in inventory
--             Special dest "__WIN__" triggers the victory screen.
--   items : list of item IDs that start in this room
--
-- START_ROOM: ID of the room where the player begins.
-- ==========================================================================

local ITEMS = {
    notes = {
        name     = "Pip-Boy Notes",
        desc     = "MISSION LOG: The vault's water purification chip has failed. A replacement is stored in the reactor room. WARNING: Dangerous radiation — a suit is mandatory.",
        takeable = true,
    },
    stimpak = {
        name     = "Stimpak",
        desc     = "A medical stimulant injector. Standard Vault-Tec issue.",
        takeable = true,
        onUse    = "You inject the stimpak. A warm, healing feeling washes over you.",
    },
    pistol = {
        name     = "10mm Pistol",
        desc     = "A worn 10mm pistol. The magazine is empty, but it's comforting to hold.",
        takeable = true,
    },
    cap = {
        name     = "Bottle Cap",
        desc     = "A shiny pre-war bottle cap. Currency of the Wasteland.",
        takeable = true,
    },
    holotape = {
        name     = "Holotape",
        desc     = "A personal recording: 'Day 847. Overseer locked the generator access again. Found his keycard tucked under the desk lamp. He doesn't know I saw it.  — R'",
        takeable = true,
    },
    keycard = {
        name     = "Overseer's Keycard",
        desc     = "A magnetic keycard stamped OVERSEER — ALL ACCESS.",
        takeable = true,
    },
    rad_suit = {
        name     = "Radiation Suit",
        desc     = "A bright yellow full-body hazmat suit. Bulky, but it will keep the rads out.",
        takeable = true,
        onUse    = "You pull on the radiation suit. It seals with a hiss.",
    },
    water_chip = {
        name     = "Water Chip",
        desc     = "The vault's water purification chip. This is exactly what you came for.",
        takeable = true,
    },
}

local ROOMS = {
    entrance = {
        name  = "Vault Entrance Hall",
        desc  = "The main hall of Vault 13. Emergency lighting flickers above cracked concrete. The vault door behind you is sealed. A corridor leads north.",
        exits = { north = "corridor" },
        items = { "notes" },
    },
    corridor = {
        name  = "Main Corridor",
        desc  = "A long intersection. Water stains streak the walls. Faded signs point to the cafeteria (north), medical bay (east), and armory (west).",
        exits = { south="entrance", north="cafeteria", east="medical", west="armory" },
        items = {},
    },
    cafeteria = {
        name  = "Cafeteria",
        desc  = "Rows of overturned metal tables and benches. A vending machine still hums in the corner. Someone left in a real hurry.",
        exits = { south="corridor", north="rec_room" },
        items = { "cap", "stimpak" },
    },
    medical = {
        name  = "Medical Bay",
        desc  = "Smells of old antiseptic and dust. Most of the shelves are bare. A stimpak sits forgotten in an open cabinet.",
        exits = { west="corridor" },
        items = { "stimpak" },
    },
    armory = {
        name  = "Armory",
        desc  = "Metal weapon racks line the walls, mostly stripped bare. A heavy security door on the south wall has an electronic lock blinking red.",
        exits = {
            east  = "corridor",
            south = { dest="generator", key="keycard",
                      msg="The security lock blinks red. A keycard slot waits next to the door." },
        },
        items = { "pistol" },
    },
    rec_room = {
        name  = "Recreation Room",
        desc  = "A billiards table with torn felt dominates the room. Dusty shelves line the walls. A holotape has been left on the table.",
        exits = { south="cafeteria", west="overseer" },
        items = { "holotape" },
    },
    overseer = {
        name  = "Overseer's Office",
        desc  = "A heavy desk fills most of this room. Vault-Tec propaganda covers every wall. A keycard glints under the desk lamp, nearly hidden.",
        exits = { east="rec_room" },
        items = { "keycard" },
    },
    generator = {
        name  = "Generator Room",
        desc  = "Ancient machines hum and shudder. Yellow radiation warning signs plaster the south door. A radiation suit hangs on a peg by the wall.",
        exits = {
            north = "armory",
            south = { dest="reactor", key="rad_suit",
                      msg="The radiation beyond that door would be lethal without protection." },
        },
        items = { "rad_suit" },
    },
    reactor = {
        name  = "Reactor Chamber",
        desc  = "The reactor core pulses with a pale blue light. Pipes and conduits cover every surface. On a reinforced shelf: the water chip.",
        exits = { north="generator", east="tunnel" },
        items = { "water_chip" },
    },
    tunnel = {
        name  = "Exit Tunnel",
        desc  = "A rough-hewn tunnel slopes upward. Light filters down from the surface far above. The Wasteland waits.",
        exits = {
            west = "reactor",
            up   = { dest="__WIN__", key="water_chip",
                     msg="You can't leave without the water chip — the vault is counting on you." },
        },
        items = {},
    },
}

local START_ROOM = "entrance"

-- ==========================================================================
-- ENGINE  —  No need to edit below this line
-- ==========================================================================

-- ── Layout ────────────────────────────────────────────────────────────────────

local ROOM_TOP  = 3    -- row where room description starts
local ROOM_H    = 10   -- rows available for description text
local EXIT_ROW  = ROOM_TOP + ROOM_H       -- 13
local ITEM_ROW  = ROOM_TOP + ROOM_H + 1  -- 14
local SEP1_ROW  = 15
local MSG_TOP   = 16
local MSG_H     = 8
local SEP2_ROW  = MSG_TOP + MSG_H   -- 24
local INPUT_ROW = 25
local HINT_ROW  = 26

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function wrap(text, width)
    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
        local need = (line == "" and 0 or 1) + #word
        if #line + need > width then
            if line ~= "" then lines[#lines + 1] = line end
            line = word
        else
            line = line == "" and word or (line .. " " .. word)
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

local function findItem(query, list)
    if query == "" then return nil end
    query = query:lower()
    for _, id in ipairs(list) do
        local item = ITEMS[id]
        if item and (id:lower() == query or item.name:lower():find(query, 1, true)) then
            return id
        end
    end
    return nil
end

local function invList(state)
    local t = {}
    for id in pairs(state.inventory) do t[#t + 1] = id end
    return t
end

local function log(state, msg)
    state.messages[#state.messages + 1] = msg
end

local function autoLook(state)
    local room = ROOMS[state.room]
    log(state, "[ " .. room.name .. " ]")
    local exits = {}
    for dir in pairs(room.exits) do exits[#exits + 1] = dir end
    table.sort(exits)
    log(state, "Exits: " .. table.concat(exits, "  "))
    local ri = state.roomItems[state.room]
    if #ri > 0 then
        local names = {}
        for _, id in ipairs(ri) do if ITEMS[id] then names[#names + 1] = ITEMS[id].name end end
        log(state, "You see: " .. table.concat(names, ", "))
    end
end

-- ── Command dispatcher ────────────────────────────────────────────────────────

local VERB_MAP = {
    go="go", move="go", walk="go", head="go",
    north="go", south="go", east="go", west="go", up="go", down="go",
    n="go", s="go", e="go", w="go", u="go", d="go",
    look="look", l="look",
    take="take", get="take", grab="take", pick="take",
    drop="drop", put="drop",
    inventory="inv", inv="inv", i="inv",
    examine="examine", x="examine", read="examine", inspect="examine",
    use="use",
    help="help", h="help", ["?"]="help",
    quit="quit", q="quit", ["exit"]="quit",
}

local DIR_EXPAND = {
    north="north", south="south", east="east", west="west", up="up", down="down",
    n="north", s="south", e="east", w="west", u="up", d="down",
}

local function doCommand(state, input)
    input = input:match("^%s*(.-)%s*$"):lower()
    if input == "" then return nil end

    -- Bare direction shorthand
    if DIR_EXPAND[input] then input = "go " .. DIR_EXPAND[input] end

    local verb, rest = input:match("^(%S+)%s*(.*)")
    rest = (rest or ""):match("^%s*(.-)%s*$")

    -- Bare direction as verb (e.g. player typed "north rest")
    if DIR_EXPAND[verb] then rest = verb; verb = "go" end

    local action = VERB_MAP[verb]
    if not action then
        return "Unknown command '" .. verb .. "'. Type HELP for a command list."
    end

    -- ── GO ────────────────────────────────────────────────────────────────────
    if action == "go" then
        local d = DIR_EXPAND[rest]
        if not d then return "Go where? (north south east west up down)" end

        local room = ROOMS[state.room]
        local exit = room.exits[d]
        if not exit then return "You can't go " .. d .. " from here." end

        local dest
        if type(exit) == "string" then
            dest = exit
        else
            if exit.key and not state.inventory[exit.key] then
                return exit.msg or "That way is blocked."
            end
            dest = exit.dest
        end

        if dest == "__WIN__" then
            state.won = true
            return "You climb up through the tunnel into the blinding surface sun, water chip in hand. Vault 13 is saved."
        end

        if not ROOMS[dest] then return "(Error: unknown room '" .. dest .. "')" end
        state.room = dest
        autoLook(state)
        return nil

    -- ── LOOK ──────────────────────────────────────────────────────────────────
    elseif action == "look" then
        log(state, ROOMS[state.room].desc)
        autoLook(state)
        return nil

    -- ── TAKE ──────────────────────────────────────────────────────────────────
    elseif action == "take" then
        if rest == "" then return "Take what?" end
        local ri = state.roomItems[state.room]
        local id = findItem(rest, ri)
        if not id then return "You don't see that here." end
        if not ITEMS[id].takeable then return "You can't take that." end
        for i, v in ipairs(ri) do if v == id then table.remove(ri, i); break end end
        state.inventory[id] = true
        return "You take the " .. ITEMS[id].name .. "."

    -- ── DROP ──────────────────────────────────────────────────────────────────
    elseif action == "drop" then
        if rest == "" then return "Drop what?" end
        local id = findItem(rest, invList(state))
        if not id then return "You're not carrying that." end
        state.inventory[id] = nil
        local ri = state.roomItems[state.room]
        ri[#ri + 1] = id
        return "You drop the " .. ITEMS[id].name .. "."

    -- ── INVENTORY ─────────────────────────────────────────────────────────────
    elseif action == "inv" then
        local names = {}
        for id in pairs(state.inventory) do
            if ITEMS[id] then names[#names + 1] = ITEMS[id].name end
        end
        if #names == 0 then return "You're not carrying anything." end
        table.sort(names)
        return "Carrying: " .. table.concat(names, ", ")

    -- ── EXAMINE ───────────────────────────────────────────────────────────────
    elseif action == "examine" then
        if rest == "" then return "Examine what?" end
        local id = findItem(rest, state.roomItems[state.room])
                or findItem(rest, invList(state))
        if not id then return "You don't see that." end
        return ITEMS[id].desc

    -- ── USE ───────────────────────────────────────────────────────────────────
    elseif action == "use" then
        if rest == "" then return "Use what?" end
        local id = findItem(rest, invList(state))
        if not id then return "You're not carrying that." end
        local item = ITEMS[id]
        if item.onUse then
            if id == "stimpak" then state.inventory[id] = nil end
            return item.onUse
        end
        return "You're not sure how to use the " .. item.name .. " here."

    -- ── HELP ──────────────────────────────────────────────────────────────────
    elseif action == "help" then
        log(state, "Commands:")
        log(state, "  go [dir]  north/south/east/west/up/down  (or n/s/e/w/u/d)")
        log(state, "  look  take [item]  drop [item]  examine [item]")
        log(state, "  use [item]  inventory (inv)  quit")
        return nil

    -- ── QUIT ──────────────────────────────────────────────────────────────────
    elseif action == "quit" then
        state.quit = true
        return nil
    end
end

-- ── Drawing ───────────────────────────────────────────────────────────────────

local function draw(state, w)
    local room = ROOMS[state.room]
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Header: separator + room name
    term.setTextColor(colors.green)
    term.setCursorPos(1, 1)
    term.write(string.rep("\x83", w))
    term.setCursorPos(2, 2)
    term.write("\xbb " .. room.name)

    -- Room description (word-wrapped into ROOM_H rows)
    local descLines = wrap(room.desc, w - 3)
    for i = 1, math.min(#descLines, ROOM_H) do
        term.setCursorPos(3, ROOM_TOP + i - 1)
        term.setTextColor(colors.white)
        term.write(descLines[i])
    end

    -- Exits
    local exits = {}
    for dir in pairs(room.exits) do exits[#exits + 1] = dir end
    table.sort(exits)
    term.setCursorPos(2, EXIT_ROW)
    term.setTextColor(colors.lime)
    term.write("Exits: " .. (#exits > 0 and table.concat(exits, "  ") or "none"))

    -- Items in room
    local ri = state.roomItems[state.room]
    if #ri > 0 then
        local names = {}
        for _, id in ipairs(ri) do if ITEMS[id] then names[#names + 1] = ITEMS[id].name end end
        term.setCursorPos(2, ITEM_ROW)
        term.setTextColor(colors.yellow)
        local s = "Items: " .. table.concat(names, ", ")
        term.write(s:sub(1, w - 2))
    end

    -- Separators
    for _, sr in ipairs({ SEP1_ROW, SEP2_ROW }) do
        term.setCursorPos(1, sr)
        term.setTextColor(colors.green)
        term.write(string.rep("\x83", w))
    end

    -- Message log (last MSG_H entries)
    local msgStart = math.max(1, #state.messages - MSG_H + 1)
    for i = 0, MSG_H - 1 do
        local msg = state.messages[msgStart + i]
        term.setCursorPos(2, MSG_TOP + i)
        term.clearLine()
        if msg then
            -- Room entry headers in green, normal responses in lime
            local isHeader = msg:sub(1, 1) == "["
            term.setTextColor(isHeader and colors.green or colors.lime)
            term.write(msg:sub(1, w - 2))
        end
    end

    -- Input line
    term.setCursorPos(1, INPUT_ROW)
    term.setTextColor(colors.white)
    term.clearLine()
    local prompt = "> " .. state.inputStr
    term.write(prompt:sub(1, w))
    term.setCursorPos(math.min(#prompt + 1, w), INPUT_ROW)
    term.setCursorBlink(true)

    -- Hint bar
    term.setCursorPos(1, HINT_ROW)
    term.setTextColor(colors.green)
    term.write(" go [dir] | take | drop | examine | inv | use | help | quit")
end

local function drawWin(w, h)
    term.setBackgroundColor(colors.black)
    term.clear()
    local lines = {
        "",
        "  YOU MADE IT OUT!  ",
        "",
        "  Vault 13 will survive another generation.",
        "  You climb into the scorching Wasteland sun,",
        "  water chip clutched in your hands.",
        "",
        "  War... War never changes.",
        "",
        "  *** CONGRATULATIONS ***",
        "",
        "  Press any key.",
    }
    local cy = math.floor(h / 2) - math.floor(#lines / 2)
    for i, line in ipairs(lines) do
        local col = colors.green
        if i == 2  then col = colors.lime   end
        if i == 10 then col = colors.yellow end
        term.setCursorPos(math.floor((w - #line) / 2) + 1, cy + i - 1)
        term.setTextColor(col)
        term.write(line)
    end
end

-- ── Entry point ───────────────────────────────────────────────────────────────

local function run(area)
    local w, h = area.w, area.h

    -- Build mutable per-room item lists (copy from world data)
    local roomItems = {}
    for id, room in pairs(ROOMS) do
        roomItems[id] = {}
        for _, itemId in ipairs(room.items) do
            roomItems[id][#roomItems[id] + 1] = itemId
        end
    end

    local state = {
        room      = START_ROOM,
        inventory = {},
        roomItems = roomItems,
        messages  = {},
        inputStr  = "",
        won       = false,
        quit      = false,
    }

    -- Describe starting room
    log(state, ROOMS[START_ROOM].desc)
    autoLook(state)

    draw(state, w)

    while not state.won and not state.quit do
        local ev, p1 = os.pullEvent()
        if ev == "char" then
            if #state.inputStr < w - 4 then
                state.inputStr = state.inputStr .. p1
            end
        elseif ev == "key" then
            if p1 == keys.backspace then
                if #state.inputStr > 0 then
                    state.inputStr = state.inputStr:sub(1, -2)
                end
            elseif p1 == keys.enter then
                local cmd = state.inputStr
                state.inputStr = ""
                if cmd:match("%S") then
                    log(state, "> " .. cmd)
                    local resp = doCommand(state, cmd)
                    if resp then log(state, resp) end
                end
            end
        end
        if not state.won and not state.quit then
            draw(state, w)
        end
    end

    term.setCursorBlink(false)

    if state.won then
        drawWin(w, h)
        os.pullEvent("key")
    end
end

GameLib.register("AdventureGame", "Escape Vault 13 - a customizable text adventure", run)
