-- The eight field creatures. They bend pearl trajectories and contest
-- floor space; only pearl misses cost hearts — creatures STUN.
--   jelly   drifts wide; stuns the crab on touch; pearl kills
--   puffer  inflates when the pearl nears: hard random deflect
--   star    starfish crawls the field repairing broken coral
--   urchin  floor spikes: stun + shove (i-frames let you push past)
--   barn    barnacle turret: floor-skimming pellets (burrow under them)
--   eel     moray in a porthole: swallows the pearl; SNAP its nose
--   ghost   abyss fish, seen only in lantern light; dashing ram
--   sprat   harmless shoal: a free bounce that scatters a little

Enemies = {}

local gfx = playdate.graphics
local list, pellets = {}, {}

function Enemies.reset()
    list, pellets = {}, {}
    local def = RoomDefs[G.room]
    for _, s in ipairs(def.spawns or {}) do
        local e = {
            t = s.t, x = s.x, y = s.y or 222, ox = s.x, oy = s.y or 222,
            dir = s.dir or 1, hp = 1, r = 9, ph = math.random() * 6,
        }
        if s.t == "puffer" then
            e.puff = 0
        elseif s.t == "star" then
            e.repairT = 3.5
        elseif s.t == "urchin" then
            e.hp = 2
            e.r = 12
            e.y = 221
        elseif s.t == "barn" then
            e.y = 222
            e.fireT = 2.5
        elseif s.t == "eel" then
            e.out = 0
            e.holds = false
        elseif s.t == "ghost" then
            e.dashT = 2
            e.vx, e.vy = 0, 0
        elseif s.t == "sprat" then
            e.n = 12
            e.r = 16
        end
        list[#list + 1] = e
        Harness.count("spawn_" .. s.t)
    end
end

function Enemies.first(t)
    for _, e in ipairs(list) do
        if e.t == t and not e.dead then return e end
    end
end

local function die(e, counterName)
    e.dead = true
    Fx.burst(e.x, e.y, 8)
    Sfx.brick(6)
    Harness.count(counterName)
end

local function stunCrab(e, counterName)
    local cb = G.crab
    if cb.invulnT > 0 or cb.stunT > 0 then return end
    cb.stunT = 1
    cb.invulnT = 2.5
    cb.x = Util.clamp(cb.x - Util.sign(e.x - cb.x) * 18, C.CRAB_HW, C.W - C.CRAB_HW)
    Fx.burst(cb.x, 214, 6)
    Sfx.stun()
    G.flash = 0.1
    Harness.count(counterName)
end

local function eelMouth(e)
    return e.x + e.dir * (10 + e.out * 16), e.y
end

local function eelSpit(e)
    local p = G.pearl
    p.eaten = false
    p.x, p.y = eelMouth(e)
    local spd = Pearl.speed()
    p.vx = e.dir * -spd * 0.5
    p.vy = -spd * 0.87
    e.holds = false
    e.out = 0
    Fx.burst(p.x, p.y, 6)
    Sfx.serve()
    Harness.count("eelSpits")
end

-- pincer snap near a porthole shakes the pearl loose
function Enemies.snapAt(cx)
    for _, e in ipairs(list) do
        if e.t == "eel" and e.holds and math.abs(e.x - cx) < C.SNAP_REACH + 30 then
            eelSpit(e)
        end
    end
end

function Enemies.update(dt)
    local cb = G.crab
    local p = G.pearl
    local def = RoomDefs[G.room]

    for _, e in ipairs(list) do
        if not e.dead then
            e.ph = e.ph + dt
            if e.t == "jelly" then
                e.x = e.ox + math.sin(e.ph * 0.5) * 60
                e.y = Util.clamp(e.oy + math.sin(e.ph * 0.27) * 75, 40, 208)
                if e.y > 192 and math.abs(e.x - cb.x) < e.r + 14 then
                    stunCrab(e, "jellyStuns")
                end
            elseif e.t == "puffer" then
                e.x = e.ox + math.sin(e.ph * 0.4) * 40
                e.y = e.oy + math.sin(e.ph * 0.6) * 12
                local near = not p.held and not p.eaten
                    and math.abs(p.x - e.x) < 46 and math.abs(p.y - e.y) < 46
                e.puff = Util.clamp(e.puff + (near and 4 or -2) * dt, 0, 1)
                e.r = 8 + e.puff * 6
            elseif e.t == "star" then
                e.repairT = e.repairT - dt
                if e.repairT <= 0 then
                    -- crawl to the nearest broken plain coral and regrow it
                    local best, br, bc
                    for r = 1, C.ROWS do
                        local row = def.grid[r]
                        for c = 1, C.COLS do
                            if row:sub(c, c) == "c" and not G.grid[r][c] then
                                local x = (c - 1) * C.CELL + 8
                                local y = C.FIELD_Y + (r - 1) * C.CELL + 8
                                local d = math.abs(x - e.x) + math.abs(y - e.y)
                                if not best or d < best then best, br, bc = d, r, c end
                            end
                        end
                    end
                    if br then
                        local tx = (bc - 1) * C.CELL + 8
                        local ty = C.FIELD_Y + (br - 1) * C.CELL + 8
                        local d = math.max(1, math.sqrt((tx - e.x) ^ 2 + (ty - e.y) ^ 2))
                        if d < 6 then
                            G.grid[br][bc] = { t = "c", hp = 1 }
                            G.blocksLeft = G.blocksLeft + 1
                            e.repairT = 3.5
                            Fx.burst(tx, ty, 4)
                            Sfx.chip()
                            Harness.count("repairs")
                        else
                            e.x = e.x + (tx - e.x) / d * 26 * dt
                            e.y = e.y + (ty - e.y) / d * 26 * dt
                        end
                    else
                        e.x = e.ox + math.sin(e.ph * 0.3) * 30
                        e.repairT = 1
                    end
                end
            elseif e.t == "urchin" then
                if math.abs(e.x - cb.x) < e.r + 12 and cb.burrow < 0.5 then
                    stunCrab(e, "urchinStuns")
                end
            elseif e.t == "barn" then
                e.fireT = e.fireT - dt
                if e.fireT <= 0 then
                    e.fireT = 3
                    pellets[#pellets + 1] = {
                        x = e.x, y = 218,
                        vx = Util.sign(cb.x - e.x + 0.001) * 85,
                    }
                    Sfx.chip()
                    Harness.count("pellets")
                end
            elseif e.t == "eel" then
                if e.holds then
                    e.holdT = (e.holdT or 6) - dt
                    if e.holdT <= 0 then eelSpit(e) end
                else
                    e.holdT = 6
                    local want = (math.floor(e.ph / 2.2) % 2 == 0) and 1 or 0
                    e.out = Util.clamp(e.out + (want * 2 - 1) * 2 * dt, 0, 1)
                end
            elseif e.t == "ghost" then
                e.dashT = e.dashT - dt
                if e.dashT <= 0 then
                    e.dashT = 2.5
                    local dx, dy = cb.x - e.x, 210 - e.y
                    local d = math.max(1, math.sqrt(dx * dx + dy * dy))
                    e.vx, e.vy = dx / d * 150, dy / d * 150
                end
                e.vx = e.vx * (1 - 2.2 * dt)
                e.vy = e.vy * (1 - 2.2 * dt)
                e.x = Util.clamp(e.x + e.vx * dt, 10, C.W - 10)
                e.y = Util.clamp(e.y + e.vy * dt, 30, 214)
                if e.y > 194 and math.abs(e.x - cb.x) < e.r + 12 then
                    stunCrab(e, "ghostStuns")
                end
            elseif e.t == "sprat" then
                e.x = Util.clamp(e.ox + math.sin(e.ph * 0.35) * 70, 20, C.W - 20)
                e.y = e.oy + math.sin(e.ph * 0.8) * 10
            end
        end
    end

    for i = #pellets, 1, -1 do
        local pl = pellets[i]
        pl.x = pl.x + pl.vx * dt
        if pl.x < 4 or pl.x > C.W - 4 then
            table.remove(pellets, i)
        elseif math.abs(pl.x - cb.x) < 12 and cb.burrow < 0.5 and cb.invulnT <= 0 then
            table.remove(pellets, i)
            stunCrab(pl, "pelletStuns")
        end
    end
end

-- pearl vs creatures, once per frame after pearl physics
function Enemies.pearlCheck(p)
    if p.held or p.eaten then return end
    for _, e in ipairs(list) do
        if not e.dead then
            local dx, dy = p.x - e.x, p.y - e.y
            local hit = dx * dx + dy * dy < (e.r + C.PEARL_R) ^ 2
            if e.t == "eel" then
                local mx, my = eelMouth(e)
                if e.out > 0.5 and not e.holds
                    and math.abs(p.x - mx) < 14 and math.abs(p.y - my) < 14 then
                    p.eaten = true
                    e.holds = true
                    e.holdT = 6
                    Sfx.miss()
                    Harness.count("eelSwallows")
                    return
                end
            elseif hit then
                if e.t == "puffer" and e.puff > 0.5 then
                    local a = math.random() * 6.283
                    local spd = Pearl.speed()
                    p.vx, p.vy = math.cos(a) * spd, math.sin(a) * spd
                    Sfx.paddle(1)
                    Harness.count("pufferDeflects")
                elseif e.t == "sprat" then
                    if math.abs(p.vy) > math.abs(p.vx) then p.vy = -p.vy else p.vx = -p.vx end
                    e.n = e.n - 4
                    e.r = 6 + e.n
                    Fx.burst(p.x, p.y, 3)
                    Sfx.wall()
                    Harness.count("spratBounces")
                    if e.n <= 0 then die(e, "spratScattered") end
                else
                    e.hp = e.hp - 1
                    if e.hp <= 0 then
                        die(e, e.t == "jelly" and "jellyKills"
                            or e.t == "star" and "starKills"
                            or e.t == "ghost" and "ghostKills"
                            or e.t == "urchin" and "urchinKills"
                            or e.t == "puffer" and "pufferKills"
                            or "kills")
                    else
                        Sfx.chip()
                    end
                end
            end
        end
    end
end

-- ---- drawing -----------------------------------------------------------

local function drawJelly(e)
    gfx.setColor(gfx.kColorWhite)
    local squish = 1 + math.sin(e.ph * 3) * 0.15
    gfx.fillEllipseInRect(e.x - 9, e.y - 7 * squish, 18, 10 * squish)
    for i = -1, 1 do
        local tx = e.x + i * 5
        gfx.drawLine(tx, e.y + 2, tx + math.sin(e.ph * 2 + i) * 3, e.y + 11)
    end
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(e.x - 3, e.y - 2, 1)
    gfx.fillCircleAtPoint(e.x + 3, e.y - 2, 1)
    gfx.setColor(gfx.kColorWhite)
end

local function drawPuffer(e)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(e.x, e.y, e.r)
    if e.puff > 0.3 then
        for i = 0, 7 do
            local a = i / 8 * 6.283 + e.ph
            gfx.drawLine(e.x + math.cos(a) * e.r, e.y + math.sin(a) * e.r,
                e.x + math.cos(a) * (e.r + 4), e.y + math.sin(a) * (e.r + 4))
        end
    end
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(e.x + 4, e.y - 2, 1.5)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(e.x - e.r, e.y, e.x - e.r - 4, e.y - 3)
    gfx.drawLine(e.x - e.r, e.y, e.x - e.r - 4, e.y + 3)
end

local function drawStar(e)
    gfx.setColor(gfx.kColorWhite)
    for i = 0, 4 do
        local a = i / 5 * 6.283 + e.ph * 0.5
        gfx.drawLine(e.x, e.y, e.x + math.cos(a) * 9, e.y + math.sin(a) * 9)
    end
    gfx.fillCircleAtPoint(e.x, e.y, 3)
end

local function drawUrchin(e)
    gfx.setColor(gfx.kColorWhite)
    for i = 0, 8 do
        local a = math.pi + i / 8 * math.pi
        gfx.drawLine(e.x, 226, e.x + math.cos(a) * -13, 226 + math.sin(a) * -13)
    end
    gfx.fillCircleAtPoint(e.x, 224, 5)
    if e.hp == 1 then
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(e.x - 3, 222, e.x + 3, 225)
        gfx.setColor(gfx.kColorWhite)
    end
end

local function drawBarn(e)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(e.x - 8, 228, e.x - 3, 216)
    gfx.drawLine(e.x + 8, 228, e.x + 3, 216)
    gfx.drawLine(e.x - 3, 216, e.x + 3, 216)
    if e.fireT < 0.5 then
        gfx.fillCircleAtPoint(e.x, 214, 2)
    end
end

local function drawEel(e)
    gfx.setColor(gfx.kColorWhite)
    local mx = eelMouth(e)
    local wall = e.x + e.dir * 6
    gfx.drawCircleAtPoint(wall, e.y, 9) -- porthole
    if e.out > 0.1 then
        gfx.fillRect(math.min(wall, mx), e.y - 4, math.abs(mx - wall) + 4, 8)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(mx - e.dir * 2, e.y - 2, 1.5)
        if not e.holds then
            gfx.drawLine(mx - e.dir * 4, e.y + 2, mx, e.y + 3)
        end
        gfx.setColor(gfx.kColorWhite)
    end
    if e.holds then
        gfx.fillCircleAtPoint(mx, e.y, C.PEARL_R) -- the stolen pearl in its jaws
    end
end

local function drawGhost(e)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawEllipseInRect(e.x - 9, e.y - 5, 18, 10)
    gfx.drawLine(e.x - 9, e.y, e.x - 14, e.y - 4)
    gfx.drawLine(e.x - 9, e.y, e.x - 14, e.y + 4)
    gfx.fillCircleAtPoint(e.x + 4, e.y - 1, 1.5)
end

local function drawSprat(e)
    gfx.setColor(gfx.kColorWhite)
    for i = 1, e.n do
        local a = i / e.n * 6.283
        local sx = e.x + math.cos(a + e.ph) * (e.r - 4)
        local sy = e.y + math.sin(a * 2 + e.ph * 2) * (e.r - 8)
        gfx.fillRect(sx, sy, 3, 1)
        gfx.fillRect(sx - 1, sy, 1, 1)
    end
end

function Enemies.draw()
    for _, e in ipairs(list) do
        if not e.dead then
            if e.t == "jelly" then drawJelly(e)
            elseif e.t == "puffer" then drawPuffer(e)
            elseif e.t == "star" then drawStar(e)
            elseif e.t == "urchin" then drawUrchin(e)
            elseif e.t == "barn" then drawBarn(e)
            elseif e.t == "eel" then drawEel(e)
            elseif e.t == "ghost" then drawGhost(e)
            elseif e.t == "sprat" then drawSprat(e)
            end
        end
    end
    gfx.setColor(gfx.kColorWhite)
    for _, pl in ipairs(pellets) do
        gfx.fillCircleAtPoint(pl.x, pl.y, 2)
    end
end
