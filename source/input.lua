-- Real input + the smoke autopilot.
-- Real: d-pad scuttles/burrows/rides vents, A serves (pearl held) or
-- Pincer Snaps (pearl loose), B hold = Sticky Claw catch, B tap = world
-- map. Modal crank: while the pearl is HELD the crank aims the serve
-- (1:1); while it FLIES the crank scuttles the crab (the same sweep also
-- adds english on the bounce). Docked crank = d-pad only, fixed serve.
-- Autopilot: one scripted expedition — every molt in order, every gate
-- exercised (incl. refusals), all 3 keys, AND every creature verified:
-- jelly/sprat/puffer/starfish-repair/urchin-stun/keg-chain/pellet-stun/
-- eel-swallow-snap/ghost-kill. Step kinds: dir/walk/molt/brk/try/catch/
-- stunAt/pellet/eel. Travel auto-snaps kelp when stuck.

Input = {}

local eng = { 0, 0, 0, 0, 0 }
local ei = 0
local bT = 0

function Input.gather()
    if Harness.enabled and Harness.autopilot then
        return Harness.autopilot()
    end
    local inp = { mvx = 0, up = false, burrow = false, serve = false,
        map = false, catch = false, aim = 0, english = 0 }
    if playdate.buttonIsPressed(playdate.kButtonLeft) then inp.mvx = -1 end
    if playdate.buttonIsPressed(playdate.kButtonRight) then inp.mvx = 1 end
    inp.up = playdate.buttonIsPressed(playdate.kButtonUp)
    inp.burrow = playdate.buttonIsPressed(playdate.kButtonDown)
    inp.serve = playdate.buttonJustPressed(playdate.kButtonA)

    if playdate.buttonIsPressed(playdate.kButtonB) then
        bT = bT + C.DT
        inp.catch = G.save.molts.sticky ~= nil
    else
        if bT > 0 and bT < 0.3 then inp.map = true end
        bT = 0
    end

    ei = ei % 5 + 1
    eng[ei] = playdate.getCrankChange()
    local sum = 0
    for _, v in ipairs(eng) do sum = sum + v end
    -- modal crank: aims while the pearl is held (1:1), scuttles the crab
    -- while it flies (and the same sweep bends the bounce). Docked = d-pad
    -- only, fixed serve.
    if playdate.isCrankDocked() then
        inp.aim = G.crab.x < C.W / 2 and 45 or -45
    elseif G.pearl and G.pearl.held then
        local pos = playdate.getCrankPosition()
        inp.aim = Util.clamp(((pos + 180) % 360) - 180, -C.SERVE_CAP, C.SERVE_CAP)
    else
        if inp.mvx == 0 then          -- a pressed d-pad overrides the crank
            local m = sum / C.CRANK_MOVE
            if math.abs(m) < C.CRANK_DEADZONE then m = 0 end
            inp.mvx = Util.clamp(m, -C.CRANK_MVX_MAX, C.CRANK_MVX_MAX)
        end
        inp.english = Util.clamp(sum * 0.2, -C.ENGLISH_MAX, C.ENGLISH_MAX)
    end
    return inp
end

function Input.confirm()
    if Harness.enabled then return G.t > 0.7 end
    return playdate.buttonJustPressed(playdate.kButtonA)
end

-- ---- autopilot ---------------------------------------------------------

local AP = { errandI = 1, t = 0, holdT = 0, sinceServe = 1e9, lastX = 0, stuck = 0 }

local function counter(k) return Harness.counters[k] or 0 end

local function moveToward(inp, x, dead)
    dead = dead or 4
    if math.abs(x - G.crab.x) > dead then
        inp.mvx = Util.sign(x - G.crab.x)
    end
end

local function predictX()
    local p = G.pearl
    if p.eaten then return G.crab.x end
    local x, y, vx, vy = p.x, p.y, p.vx, p.vy
    for _ = 1, 300 do
        x = x + vx * C.DT
        y = y + vy * C.DT
        if x < C.PEARL_R then
            x = 2 * C.PEARL_R - x
            vx = -vx
        elseif x > C.W - C.PEARL_R then
            x = 2 * (C.W - C.PEARL_R) - x
            vx = -vx
        end
        if y < C.FIELD_Y + C.PEARL_R and vy < 0 then
            y = 2 * (C.FIELD_Y + C.PEARL_R) - y
            vy = -vy
        end
        if vy > 0 and y + C.PEARL_R >= C.PADDLE_Y then return x end
    end
    return p.x
end

local function targetable(cell)
    local t = cell.t
    if t == "k" or t == "#" then return false end
    if t == "S" and not G.save.molts.heavy then return false end
    if t == "g" and G.save.keys < 3 then return false end
    return true
end

local function targetBlock(pref)
    for pass = 1, pref and 2 or 1 do
        for r = C.ROWS, 1, -1 do
            local bestC, bestD
            for c = 1, C.COLS do
                local cell = G.grid[r][c]
                if cell and targetable(cell)
                    and (pass == 2 or not pref or pref[cell.t]) then
                    local d = math.abs((c - 1) * C.CELL + 8 - G.pearl.x)
                    if not bestD or d < bestD then bestC, bestD = c, d end
                end
            end
            if bestC then
                return (bestC - 1) * C.CELL + 8, C.FIELD_Y + (r - 1) * C.CELL + 8
            end
        end
    end
end

local function rallyRun(inp, cruise, pref)
    local p = G.pearl
    if p.eaten then return end
    if p.held then
        local tx, ty = targetBlock(pref)
        if tx then
            inp.aim = Util.clamp(math.deg(math.atan(tx - p.x, p.y - ty)),
                -C.SERVE_CAP, C.SERVE_CAP)
        end
        AP.holdT = AP.holdT + 1
        if AP.holdT > 12 and p.lock <= 0 then
            inp.serve = true
            AP.holdT = 0
            AP.sinceServe = 0
        end
        return
    end
    local xi = predictX()
    local off = 0
    local tx, ty = targetBlock(pref)
    if tx then
        local want = Util.clamp(math.deg(math.atan(tx - xi, C.PADDLE_Y - ty)),
            -C.BOUNCE_MAX, C.BOUNCE_MAX)
        off = Util.clamp((want / C.BOUNCE_MAX) * (C.CRAB_HW + C.PEARL_R - 2), -10, 10)
    end
    moveToward(inp, Util.clamp(xi - off, C.CRAB_HW + 6, C.W - C.CRAB_HW - 6), 3)
    if cruise then
        if p.vy > 0 and p.y > 160 then inp.english = C.ENGLISH_MAX * 0.6 end
        if AP.sinceServe > 8 and AP.sinceServe < 30 and p.vy < 0 then inp.burrow = true end
    end
end

local function travel(inp, dir)
    local def = RoomDefs[G.room]
    local cb = G.crab
    if dir == "L" then
        inp.mvx = -1
    elseif dir == "R" then
        inp.mvx = 1
    elseif dir == "U" and def.vent then
        moveToward(inp, Rooms.colCenter(def.vent), 3)
        if Rooms.inCols(cb.x, def.vent) then inp.up = true end
    elseif dir == "D" and def.gap then
        moveToward(inp, Rooms.colCenter(def.gap), 3)
        if Rooms.inCols(cb.x, def.gap) then inp.burrow = true end
    end
    if math.abs(cb.x - AP.lastX) < 0.5 and (inp.mvx ~= 0 or inp.up or inp.burrow) then
        AP.stuck = AP.stuck + 1
        if AP.stuck > 20 and G.save.molts.pincer and G.pearl.held then
            inp.serve = false
            inp.snapReq = true
            AP.stuck = 0
        end
    else
        AP.stuck = 0
    end
    AP.lastX = cb.x
end

local function catchRun(inp)
    local p = G.pearl
    if p.held then
        inp.aim = 0
        AP.holdT = AP.holdT + 1
        if AP.holdT > 10 and p.lock <= 0 then
            inp.serve = true
            AP.holdT = 0
        end
        return
    end
    moveToward(inp, predictX(), 3)
    if p.vy > 0 then inp.catch = true end
end

local function dieRun(inp)
    local p = G.pearl
    if p.held then
        inp.aim = 15
        AP.holdT = AP.holdT + 1
        if AP.holdT > 10 and p.lock <= 0 then
            inp.serve = true
            AP.holdT = 0
        end
        return
    end
    moveToward(inp, predictX() < C.W / 2 and C.W - 60 or 60)
end

local function S(t) local m = {} for _, k in ipairs(t) do m[k] = true end return m end

-- BFS over the room graph: which way from here toward `to`? Skips exits
-- whose molt requirement is unmet. Lets any step recover after a
-- moltback teleports the crab across the map.
local function bfsNext(from, to)
    if from == to then return nil end
    local prev = { [from] = false }
    local q, qi = { from }, 1
    while q[qi] do
        local r = q[qi]
        qi = qi + 1
        local def = RoomDefs[r]
        for dir, dest in pairs(def.exits or {}) do
            local need = def.exitNeeds and def.exitNeeds[dir]
            if (not need or G.save.molts[need]) and prev[dest] == nil then
                prev[dest] = { r, dir }
                if dest == to then
                    local cur = dest
                    while prev[cur][1] ~= from do
                        cur = prev[cur][1]
                    end
                    return prev[cur][2]
                end
                q[#q + 1] = dest
            end
        end
    end
end

-- generic boss fight: shoot what Bosses.aim() offers, else the pref
-- blocks (siren choir, charybdis kegs); intercept clamped off the exits
local function bossFight(inp)
    local p = G.pearl
    local b = G.boss
    if not b then return end
    if p.eaten then -- charybdis is chewing; hover near mid
        moveToward(inp, Util.clamp(b.x, C.CRAB_HW + 6, C.W - C.CRAB_HW - 6), 8)
        return
    end
    -- clear any kelp within reach on principle (the kelpie sows it)
    if G.save.molts.pincer then
        for c = 1, C.COLS do
            local cell = G.grid[C.ROWS][c]
            if cell and cell.t == "k"
                and math.abs((c - 1) * C.CELL + 8 - G.crab.x) <= C.SNAP_REACH then
                inp.snapReq = true
                break
            end
        end
    end
    if p.held then
        local ax, ay = Bosses.aim()
        if not ax then
            ax, ay = targetBlock(b.name == "charybdis" and S({ "O" }) or S({ "B" }))
        end
        if ax then
            inp.aim = Util.clamp(math.deg(math.atan(ax - p.x, p.y - ay)),
                -C.SERVE_CAP, C.SERVE_CAP)
        end
        AP.holdT = AP.holdT + 1
        if AP.holdT > 12 and p.lock <= 0 then
            inp.serve = true
            AP.holdT = 0
        end
        return
    end
    -- flying: offset-aim the NEXT bounce at the boss weak point, and with
    -- the Sticky Claw just catch it for a fresh aimed serve every cycle
    local xi = predictX()
    local off = 0
    local ax, ay = Bosses.aim()
    if not ax then
        ax, ay = targetBlock(b.name == "charybdis" and S({ "O" }) or S({ "B" }))
    end
    if ax then
        local want = Util.clamp(math.deg(math.atan(ax - xi, C.PADDLE_Y - ay)),
            -C.BOUNCE_MAX, C.BOUNCE_MAX)
        off = Util.clamp((want / C.BOUNCE_MAX) * (C.CRAB_HW + C.PEARL_R - 2), -12, 12)
    end
    if G.save.molts.sticky and p.vy > 0 and p.y > 170 then
        inp.catch = true
    end
    moveToward(inp, Util.clamp(xi - off, C.CRAB_HW + 6, C.W - C.CRAB_HW - 6), 3)
    -- kelpie drops kelp into the lane: snap through it
    if math.abs(G.crab.x - AP.lastX) < 0.5 then
        AP.stuck = AP.stuck + 1
        if AP.stuck > 20 and G.save.molts.pincer then
            inp.snapReq = true
            AP.stuck = 0
        end
    else
        AP.stuck = 0
    end
    AP.lastX = G.crab.x
end

local EXPEDITION = {
    { name = "jelly", deadline = 3600, steps = {
        { dir = "R", to = "T2" },
        { brk = function() return counter("jellyKills") >= 1 end, room = "T2" },
    } },
    { name = "pincer", deadline = 7200, steps = {
        { dir = "D", to = "T4" },
        { boss = "hermit", room = "T4" }, { molt = "pincer", room = "T4" },
    } },
    { name = "sprat", deadline = 5400, steps = {
        { dir = "U", to = "T2" }, { dir = "R", to = "T3" },
        { dir = "U", to = "K3" }, -- kelp column auto-snapped en route
        { brk = function() return counter("spratBounces") >= 1 end, room = "K3" },
    } },
    { name = "sticky", deadline = 10800, steps = {
        { dir = "R", to = "K4" }, { dir = "R", to = "K5" },
        { boss = "kelpie", room = "K5" }, { molt = "sticky", room = "K5" },
    } },
    { name = "catch", deadline = 1800, steps = { { catch = true } } },
    { name = "puffer", deadline = 3600, steps = {
        { dir = "L", to = "K4" },
        { brk = function() return counter("pufferDeflects") + counter("pufferKills") >= 1 end, room = "K4" },
    } },
    { name = "reef", deadline = 9000, steps = {
        { dir = "L", to = "K3" }, { dir = "D", to = "T3" },
        { dir = "R", to = "K1" }, { dir = "R", to = "K2" }, { dir = "D", to = "R1" },
        { brk = function() return counter("repairs") >= 1 end, room = "R1" },
    } },
    { name = "urchin", deadline = 2700, steps = {
        { dir = "L", to = "R2" }, { dir = "L", to = "R3" },
        { stunAt = 180, cnt = "urchinStuns", room = "R3" },
    } },
    { name = "heavy", deadline = 10800, steps = {
        { dir = "D", to = "R4" },
        { boss = "siren", room = "R4" }, { molt = "heavy", room = "R4" },
    } },
    { name = "smash", deadline = 5400, steps = {
        { brk = function() return not Blocks.gateInCols({ 18, 20 }) end,
          pref = S({ "S" }), room = "R4" },
    } },
    { name = "keg", deadline = 3600, steps = {
        { dir = "D", to = "S1" },
        { brk = function() return counter("kegBlasts") >= 2 end,
          pref = S({ "O" }), room = "S1" },
    } },
    { name = "pellet", deadline = 2700, steps = {
        { pellet = 150, room = "S1" }, -- stand by the barnacle, take one
    } },
    { name = "eel", deadline = 5400, steps = {
        { dir = "L", to = "S2" }, { walk = 21, room = "S2" },
        { eel = true, room = "S2" },
    } },
    { name = "lantern", deadline = 10800, steps = {
        { dir = "L", to = "S3" },
        { boss = "umibozu", room = "S3" }, { molt = "lantern", room = "S3" },
    } },
    { name = "vaultno", deadline = 1800, steps = {
        { dir = "R", to = "S2" }, { dir = "D", to = "S4" }, { try = "L", room = "S4" },
    } },
    { name = "ghost", deadline = 7200, steps = {
        { dir = "U", to = "S2" }, { dir = "R", to = "S1" }, { dir = "U", to = "R4" },
        { dir = "U", to = "R3" }, { dir = "R", to = "R2" }, { dir = "D", to = "R5" },
        { dir = "D", to = "A1" },
        { brk = function() return counter("ghostKills") >= 1 end, room = "A1" },
    } },
    { name = "anchor", deadline = 10800, steps = {
        { dir = "R", to = "A2" }, { dir = "D", to = "A3" },
        { boss = "charybdis", room = "A3" }, { molt = "anchor", room = "A3" },
    } },
    { name = "knock", deadline = 2700, steps = {
        { dir = "R", to = "M1" },
        { brk = function() return counter("glyphClanks") >= 1 end,
          pref = S({ "g" }), room = "M1" },
    } },
    { name = "keyTK", deadline = 10800, steps = {
        { dir = "L", to = "A3" }, { dir = "U", to = "A2" }, { dir = "L", to = "A1" },
        { dir = "U", to = "R5" }, { dir = "U", to = "R2" }, { dir = "R", to = "R1" },
        { dir = "U", to = "K2" }, { dir = "L", to = "K1" }, { dir = "L", to = "T3" },
        { dir = "L", to = "T2" }, { dir = "L", to = "T1" }, { dir = "L", to = "TK" },
        { brk = function() return G.save.keys >= 1 end,
          pref = S({ "S", "!" }), room = "TK" },
    } },
    { name = "keyKG", deadline = 7200, steps = {
        { dir = "R", to = "T1" }, { dir = "R", to = "T2" }, { dir = "R", to = "T3" },
        { dir = "U", to = "K3" }, { dir = "R", to = "K4" }, { dir = "U", to = "KG" },
        { brk = function() return G.save.keys >= 2 end,
          pref = S({ "!" }), room = "KG" },
    } },
    { name = "keySV", deadline = 10800, steps = {
        { dir = "D", to = "K4" }, { dir = "L", to = "K3" }, { dir = "D", to = "T3" },
        { dir = "R", to = "K1" }, { dir = "R", to = "K2" }, { dir = "D", to = "R1" },
        { dir = "L", to = "R2" }, { dir = "L", to = "R3" }, { dir = "D", to = "R4" },
        { dir = "D", to = "S1" }, -- persistence: the smashed slab stays open
        { dir = "L", to = "S2" }, { dir = "D", to = "S4" }, { dir = "L", to = "S5" },
        { brk = function() return G.save.keys >= 3 end,
          pref = S({ "S", "!" }), room = "S5" },
    } },
    { name = "kraken", deadline = 21600, steps = {
        { dir = "R", to = "S4" }, { dir = "U", to = "S2" }, { dir = "R", to = "S1" },
        { dir = "U", to = "R4" }, { dir = "U", to = "R3" }, { dir = "R", to = "R2" },
        { dir = "D", to = "R5" }, { dir = "D", to = "A1" }, { dir = "R", to = "A2" },
        { dir = "D", to = "A3" }, { dir = "R", to = "M1" },
        { brk = function() return not Blocks.gateInCols({ 17, 17 }) end,
          pref = S({ "g" }), room = "M1" },
        { dir = "R", to = "M2" }, { boss = "hippo", room = "M2" },
        { dir = "U", to = "M3" }, { boss = "kraken", room = "M3" },
    } },
    { name = "die", deadline = 5400, steps = {} },
    { name = "cruise", deadline = math.huge, steps = {} },
}

local function stepRun(inp, er)
    er.i = er.i or 1
    local st = er.steps[er.i]
    if not st then return true end
    -- knocked back to an anemone mid-step? find the way back first
    if st.room and G.room ~= st.room then
        local dir = bfsNext(G.room, st.room)
        if dir then travel(inp, dir) end
        return false
    end
    if st.dir then
        if G.room == st.to then
            er.i = er.i + 1
        else
            travel(inp, st.dir)
        end
    elseif st.walk then
        local x = (st.walk - 1) * C.CELL + 8
        moveToward(inp, x)
        if math.abs(G.crab.x - x) <= 6 then er.i = er.i + 1 end
    elseif st.molt then
        if G.save.molts[st.molt] then
            er.i = er.i + 1
        else
            local def = RoomDefs[G.room]
            if def.shrine then moveToward(inp, (def.shrine.col - 1) * C.CELL + 8) end
        end
    elseif st.try then
        if counter("gateRefusals") >= 1 then
            er.i = er.i + 1
        else
            travel(inp, st.try)
        end
    elseif st.boss then
        if G.save.bosses[st.boss] then
            er.i = er.i + 1
        else
            bossFight(inp)
        end
    elseif st.brk then
        if st.brk() then
            er.i = er.i + 1
        else
            rallyRun(inp, false, st.pref)
        end
    elseif st.catch then
        if counter("catches") >= 1 then
            er.i = er.i + 1
        else
            catchRun(inp)
        end
    elseif st.stunAt then
        if counter(st.cnt) >= 1 then
            er.i = er.i + 1
        else
            moveToward(inp, st.stunAt, 2)
        end
    elseif st.pellet then
        if counter("pelletStuns") >= 1 then
            er.i = er.i + 1
        else
            moveToward(inp, st.pellet, 4)
        end
    elseif st.eel then
        if counter("eelSpits") >= 1 then
            er.i = er.i + 1
        elseif st.room and G.room ~= st.room then
            -- strayed out mid-rally: walk back to the porthole room
            travel(inp, (st.back and st.back[G.room]) or "L")
        else
            local e = Enemies.first("eel")
            if not e then
                Harness.count("eelStepNoEel")
                Harness.set("eelStepRoom", G.room)
                er.i = er.i + 1
            elseif G.pearl.eaten then
                local px = e.x + e.dir * 30
                moveToward(inp, px, 3)
                if math.abs(G.crab.x - px) < 20 then inp.snapReq = true end
            elseif G.pearl.held then
                inp.aim = Util.clamp(
                    math.deg(math.atan(e.x - G.pearl.x, G.pearl.y - e.y)),
                    -C.SERVE_CAP, C.SERVE_CAP)
                AP.holdT = AP.holdT + 1
                if AP.holdT > 10 and G.pearl.lock <= 0 then
                    inp.serve = true
                    AP.holdT = 0
                end
            else
                -- clamp clear of the exit-trigger zones (learned the hard way)
                moveToward(inp, Util.clamp(predictX(),
                    C.CRAB_HW + 6, C.W - C.CRAB_HW - 6), 3)
            end
        end
    end
    return er.i > #er.steps
end

function Input.autopilot()
    local inp = { mvx = 0, up = false, burrow = false, serve = false,
        map = false, catch = false, aim = 0, english = 0 }
    AP.t = AP.t + 1
    AP.sinceServe = AP.sinceServe + 1

    local er = EXPEDITION[AP.errandI]
    local function advance()
        AP.errandI = math.min(AP.errandI + 1, #EXPEDITION)
        AP.t = 0
        Harness.set("phase", EXPEDITION[AP.errandI].name)
    end
    if AP.t > er.deadline then
        Harness.count("apTimeouts")
        advance()
        er = EXPEDITION[AP.errandI]
    end

    if G.mode ~= "play" then return inp end

    if er.name == "die" then
        if counter("moltbacks") >= 1 then advance() else dieRun(inp) end
    elseif er.name == "cruise" then
        rallyRun(inp, true)
    else
        if stepRun(inp, er) then advance() end
    end
    Harness.set("step", (er.i or 0))
    return inp
end
