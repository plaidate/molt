-- Rooms: loading, exits/transitions, anemone rests, clear detection.
-- Field blocks reset on every entry (by design); persistent gate blocks
-- arrive in M3. Clearing a pool is a fanfare, not a freeze.

Rooms = {}

local function colRange(cols)
    return (cols[1] - 1) * C.CELL, cols[2] * C.CELL
end

function Rooms.inCols(x, cols)
    if not cols then return false end
    local x1, x2 = colRange(cols)
    return x >= x1 and x <= x2
end

function Rooms.colCenter(cols)
    local x1, x2 = colRange(cols)
    return (x1 + x2) / 2
end

function Rooms.load(name)
    G.room = name
    local def = RoomDefs[name]
    G.roomName = def.name
    Blocks.load(def)
    Fx.reset()
    Items.reset()
    Enemies.reset()
    Pearl.reset()
    G.crushNoted = false
    G.crab.burrow = 0
    G.clearedFlag = false
    G.rested = false
    G.hintT = 0
    G.refuseT = 0
    G.save.visited[name] = true
    G.mode = "play"
    G.t = 0
    if def.boss and not G.save.bosses[def.boss] then
        Bosses.spawn(def.boss)
    else
        G.boss = nil
        G.bossDark = false
    end
    Music.set(Rooms.music())
    if def.toast then Game.toast(def.toast) end
end

-- which track fits the room right now?
function Rooms.music()
    local def = RoomDefs[G.room]
    if def.boss and not G.save.bosses[def.boss] then return "boss" end
    return def.zone
end

function Rooms.transition(dir)
    local dest = RoomDefs[G.room].exits[dir]
    local old = playdate.graphics.getDisplayImage()
    Rooms.load(dest)
    local d = RoomDefs[dest]
    local cb = G.crab
    if dir == "L" then
        cb.x = C.W - C.CRAB_HW - 2
    elseif dir == "R" then
        cb.x = C.CRAB_HW + 2
    elseif dir == "U" then
        cb.x = d.gap and Rooms.colCenter(d.gap) or C.W / 2
    elseif dir == "D" then
        cb.x = d.vent and Rooms.colCenter(d.vent) or C.W / 2
    end
    G.pearl.x = cb.x
    G.transition = { dir = dir, t = 0, oldImg = old }
    G.mode = "transition"
    Harness.count("transitions")
    Sfx.whoosh()
end

-- an exit can be refused: by a missing molt (exitNeeds) or by a gate
-- block still sealing the vent/gap columns
local function refused(def, dir, cols)
    G.refuseT = math.max(0, (G.refuseT or 0) - C.DT)
    local need = def.exitNeeds and def.exitNeeds[dir]
    if need and not G.save.molts[need] then
        if G.refuseT == 0 then
            G.refuseT = 2
            Game.toast("THE CURRENT TEARS AT YOU")
            Harness.count("gateRefusals")
        end
        return true
    end
    if cols and Blocks.gateInCols(cols) then
        if G.refuseT == 0 then
            G.refuseT = 2
            Game.toast("SOMETHING SEALS THE WAY")
            Harness.count("gateRefusals")
        end
        return true
    end
    return false
end

function Rooms.checkExits(inp)
    if G.mode ~= "play" then return end
    local def = RoomDefs[G.room]
    local ex = def.exits or {}
    local cb = G.crab
    if ex.L and cb.x <= C.CRAB_HW + 1 and inp.mvx < 0 then
        if not refused(def, "L") then Rooms.transition("L") end
    elseif ex.R and cb.x >= C.W - C.CRAB_HW - 1 and inp.mvx > 0 then
        if not refused(def, "R") then Rooms.transition("R") end
    elseif ex.U and inp.up and Rooms.inCols(cb.x, def.vent) then
        if not refused(def, "U", def.vent) then Rooms.transition("U") end
    elseif ex.D and inp.burrow and Rooms.inCols(cb.x, def.gap) then
        if not refused(def, "D", def.gap) then Rooms.transition("D") end
    end
end

-- rest anemone: touch once per visit -> heal, mark the tide (save)
function Rooms.anemoneCheck()
    local def = RoomDefs[G.room]
    if not def.anemone or G.rested then return end
    local ax = (def.anemone - 1) * C.CELL + 8
    if math.abs(G.crab.x - ax) < C.ANEMONE_R then
        G.rested = true
        G.hearts = C.HEARTS
        G.save.anemone = G.room
        Save.store()
        Fx.burst(ax, 218, 10)
        Sfx.anemone()
        Game.toast("THE TIDE MARKS YOUR SHELL")
        Harness.count("anemoneRests")
    end
end

function Rooms.clearCheck()
    if not G.clearedFlag and Blocks.remaining() == 0 then
        G.clearedFlag = true
        G.pearl.held = true
        Harness.count("roomClears")
        Sfx.fanfare()
        Game.toast("POOL CLEARED")
    end
end
