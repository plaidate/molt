-- The seven guardians of the deep. Each boss room fights until defeated
-- (persisted in G.save.bosses); the molt shrine appears only after.
-- Bosses stun the crab, never wound — dropped pearls cost the hearts.
--   hermit    T4: crack the six bottle-shell plates, then hit the crab
--   kelpie    K5: kelp horse galloping the ceiling, drops kelp curtains
--   siren     R4: charms the pearl while her choir (brain coral) sings
--   umibozu   S3: vast sea-spirit; strike the open eyes; it dims the water
--   charybdis A3: whirlpool that swallows the pearl — feed it powder kegs
--   hippo     M2: seahorse knight jousting your paddle lane (drops shards)
--   kraken    M3: tentacle rival-paddles, eye opens between waves; 3 phases

Bosses = {}

local gfx = playdate.graphics
local DITHER = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 }

local HP = { hermit = 3, kelpie = 6, siren = 5, umibozu = 6,
    charybdis = 4, hippo = 5, kraken = 9 }

function Bosses.spawn(name)
    -- wounds persist within a session: coming back resumes the fight
    G.bossWounds = G.bossWounds or {}
    local hp0 = G.bossWounds[name] or HP[name]
    local b = { name = name, hp = hp0, maxHp = HP[name],
        t = 0, hitCool = 0, x = 200, y = 90 }
    if name == "hermit" then
        b.x, b.y = 200, 88
        b.armor = {}
        for i = 0, 5 do
            b.armor[#b.armor + 1] = { a = i / 6 * 6.283, alive = true }
        end
        b.exposed = false
    elseif name == "kelpie" then
        b.x, b.y = 60, 34
        b.vx = 90
        b.dropT = 4
    elseif name == "siren" then
        b.x, b.y = 200, 36
        b.shielded = true
    elseif name == "umibozu" then
        b.x, b.y = 200, 150
        b.eyes = { { dx = -28, hp = math.ceil(hp0 / 2) }, { dx = 28, hp = math.floor(hp0 / 2) } }
        b.open = true
        b.cycT = 4
    elseif name == "charybdis" then
        b.x, b.y = 272, 120
        b.spin = 0
    elseif name == "hippo" then
        b.x, b.y = 80, 212
        b.vx = 1
        b.charge = 0
        b.chargeT = 3
    elseif name == "kraken" then
        b.x, b.y = 200, 118
        b.open = true
        b.cycT = 3
        b.tents = {}
        b.spawnT = 2
    end
    if SMOKE_BUILD then G.hearts = G.maxHearts end -- fair start for the autopilot
    G.boss = b
    Harness.set("boss", name)
    Harness.set("bossHp", b.hp)
end

local function defeat(b)
    G.save.bosses[b.name] = true
    Save.store()
    G.boss = nil
    G.bossDark = false
    Fx.burst(b.x, b.y, 24)
    Fx.burst(b.x - 20, b.y + 10, 12)
    Fx.burst(b.x + 20, b.y - 10, 12)
    Sfx.fanfare()
    Game.toast(string.upper(b.name) .. " YIELDS")
    Harness.count(b.name .. "Slain")
    Harness.set("boss", "-")
    Music.set(RoomDefs[G.room].zone)
    if b.name == "hippo" then
        Items.dropShard(b.x - 10, 120)
        Items.dropShard(b.x + 10, 110)
    end
    if b.name == "kraken" then
        G.mode = "victory"
        G.t = 0
    end
end

local function damage(b, ignoreCool)
    if b.hitCool > 0 and not ignoreCool then return end
    b.hitCool = 0.5
    b.hp = b.hp - 1
    G.bossWounds[b.name] = b.hp
    Fx.burst(G.pearl.x, G.pearl.y, 8)
    Sfx.brick(3)
    Harness.count("bossHits")
    Harness.set("bossHp", b.hp)
    if b.hp <= 0 then defeat(b) end
end

local function stun(cb, fromX, counterName)
    if cb.invulnT > 0 or cb.stunT > 0 then return end
    cb.stunT = 1
    cb.invulnT = 2.5
    cb.x = Util.clamp(cb.x - Util.sign(fromX - cb.x) * 24, C.CRAB_HW, C.W - C.CRAB_HW)
    Sfx.stun()
    G.flash = 0.1
    Harness.count(counterName)
end

function Bosses.update(dt)
    local b = G.boss
    if not b then
        G.bossDark = false
        return
    end
    b.t = b.t + dt
    b.hitCool = math.max(0, b.hitCool - dt)
    local cb = G.crab
    local p = G.pearl

    if b.name == "hermit" then
        local n = 0
        for _, ch in ipairs(b.armor) do if ch.alive then n = n + 1 end end
        b.exposed = n == 0
        if b.exposed then
            b.x = 200 + math.sin(b.t * 1.4) * 110
        end
    elseif b.name == "kelpie" then
        b.x = b.x + b.vx * dt
        if b.x < 40 then b.x, b.vx = 40, math.abs(b.vx) end
        if b.x > 360 then b.x, b.vx = 360, -math.abs(b.vx) end
        b.y = 34 + math.abs(math.sin(b.t * 6)) * 9 -- gallop
        b.dropT = b.dropT - dt
        if b.dropT <= 0 then
            b.dropT = 6
            -- never more than two curtains standing: lane pressure, not a forest
            local standing = 0
            for c = 1, C.COLS do
                local cell = G.grid[C.ROWS][c]
                if cell and cell.t == "k" and cell.temp then
                    standing = standing + 1
                end
            end
            if standing < 2 then
                local c = Util.clamp(math.floor(b.x / C.CELL) + 1, 2, 24)
                for r = C.ROWS - 3, C.ROWS do
                    if not G.grid[r][c] then
                        G.grid[r][c] = { t = "k", hp = 1, temp = true }
                        G.blocksLeft = G.blocksLeft + 1
                    end
                end
                Sfx.chip()
                Harness.count("kelpDrops")
            end
        end
    elseif b.name == "siren" then
        b.x = 200 + math.sin(b.t * 0.7) * 60
        local shielded = false
        for r = 1, C.ROWS do
            for c = 1, C.COLS do
                local cell = G.grid[r][c]
                if cell and cell.t == "B" then shielded = true break end
            end
            if shielded then break end
        end
        b.shielded = shielded
    elseif b.name == "umibozu" then
        b.cycT = b.cycT - dt
        if b.cycT <= 0 then
            b.open = not b.open
            b.cycT = b.open and 4 or 3
            if not b.open then Harness.count("dims") end
        end
        G.bossDark = not b.open
    elseif b.name == "charybdis" then
        b.spin = b.spin + dt * 7
        if not p.held and not p.eaten and not b.holding then
            local dx, dy = p.x - b.x, p.y - b.y
            if dx * dx + dy * dy < 26 * 26 then
                b.holding = 1.2
                p.eaten = true
                Sfx.miss()
                Harness.count("whirlSwallows")
            end
        end
        if b.holding then
            b.holding = b.holding - dt
            if b.holding <= 0 then
                b.holding = nil
                p.eaten = false
                p.x, p.y = b.x, b.y - 38
                local a = math.rad(math.random(-70, 70))
                local spd = Pearl.speed()
                p.vx = spd * math.sin(a)
                p.vy = -spd * math.cos(a)
                Sfx.serve()
            end
        end
    elseif b.name == "hippo" then
        b.chargeT = b.chargeT - dt
        if b.chargeT <= 0 then
            b.charge = 1.2
            b.chargeT = 3.5
            Sfx.stun()
            Harness.count("hippoCharges")
        end
        b.charge = math.max(0, b.charge - dt)
        b.x = b.x + b.vx * (b.charge > 0 and 240 or 70) * dt
        if b.x < 30 then b.x, b.vx = 30, 1 end
        if b.x > 370 then b.x, b.vx = 370, -1 end
        if math.abs(b.x - cb.x) < 20 and cb.burrow < 0.5 then
            stun(cb, b.x, "hippoStuns")
        end
    elseif b.name == "kraken" then
        b.cycT = b.cycT - dt
        if b.cycT <= 0 then
            b.open = not b.open
            b.cycT = b.open and 3 or 2.5
        end
        b.phase = math.min(3, 1 + math.floor((b.maxHp - b.hp) / 3))
        b.spawnT = b.spawnT - dt
        local maxTents = SMOKE_BUILD and math.min(b.phase, 2) or (1 + b.phase)
        if b.spawnT <= 0 and #b.tents < maxTents then
            b.spawnT = (SMOKE_BUILD and 3.4 or 2.6) - b.phase * 0.3
            b.tents[#b.tents + 1] = { x = 50 + math.random(0, 300), h = 0, st = "rise", t = 0 }
            Harness.count("tentacles")
        end
        for i = #b.tents, 1, -1 do
            local tn = b.tents[i]
            tn.t = tn.t + dt
            if tn.st == "rise" then
                tn.h = tn.h + 150 * dt
                if tn.h >= 105 then tn.h, tn.st, tn.t = 105, "hold", 0 end
            elseif tn.st == "hold" then
                if tn.t > 1.6 then tn.st = "sink" end
            else
                tn.h = tn.h - 120 * dt
                if tn.h <= 0 then table.remove(b.tents, i) end
            end
            if tn.h and tn.h > 0 then
                local top = 228 - tn.h
                if not p.held and not p.eaten and tn.h > 20
                    and math.abs(p.x - tn.x) < 10 + C.PEARL_R
                    and p.y > top - C.PEARL_R then
                    if p.vy > 0 and p.y < top + 8 then
                        p.vy = -math.abs(p.vy)
                        p.vx = p.vx + (math.random() - 0.5) * 60
                        local s = Pearl.speed() / math.max(1, math.sqrt(p.vx * p.vx + p.vy * p.vy))
                        p.vx, p.vy = p.vx * s, p.vy * s
                        Sfx.paddle(1)
                        Harness.count("tentacleBats")
                    else
                        p.vx = Util.sign(p.x - tn.x) * math.abs(p.vx)
                    end
                end
                if tn.h > 10 and math.abs(tn.x - cb.x) < 22 then
                    stun(cb, tn.x, "tentacleStuns")
                end
            end
        end
    end
end

-- pearl vs boss, after enemy checks
function Bosses.pearlCheck(p)
    local b = G.boss
    if not b or p.held or p.eaten then return end
    local dx, dy = p.x - b.x, p.y - b.y

    if b.name == "hermit" then
        for _, ch in ipairs(b.armor) do
            if ch.alive then
                local ax = b.x + math.cos(ch.a) * 30
                local ay = b.y + math.sin(ch.a) * 26
                if (p.x - ax) ^ 2 + (p.y - ay) ^ 2 < 11 * 11 then
                    ch.alive = false
                    Fx.burst(ax, ay, 6)
                    Sfx.brick(4)
                    Harness.count("armorBroken")
                    p.vx, p.vy = -p.vx, -p.vy
                    return
                end
            end
        end
        if b.exposed and dx * dx + dy * dy < 20 * 20 then damage(b) end
    elseif b.name == "kelpie" then
        if dx * dx + dy * dy < 22 * 22 then damage(b) end
    elseif b.name == "siren" then
        if dx * dx + dy * dy < 18 * 18 then
            if b.shielded then
                p.vy = math.abs(p.vy)
                Sfx.wall()
                Harness.count("sirenShrugs")
            else
                damage(b)
            end
        end
    elseif b.name == "umibozu" then
        if b.open and b.hitCool <= 0 then
            for _, eye in ipairs(b.eyes) do
                if eye.hp > 0 then
                    local ex, ey = b.x + eye.dx, b.y - 22
                    if (p.x - ex) ^ 2 + (p.y - ey) ^ 2 < 12 * 12 then
                        eye.hp = eye.hp - 1
                        b.hp = b.eyes[1].hp + b.eyes[2].hp
                        G.bossWounds[b.name] = b.hp
                        b.hitCool = 0.5
                        Fx.burst(ex, ey, 8)
                        Sfx.brick(3)
                        Harness.count("bossHits")
                        Harness.set("bossHp", b.hp)
                        if b.hp <= 0 then defeat(b) end
                        return
                    end
                end
            end
        end
    elseif b.name == "hippo" then
        if math.abs(p.x - b.x) < 16 and math.abs(p.y - (b.y - 22)) < 16 then
            if b.charge > 0 then
                p.vy = -math.abs(p.vy) -- shield bash
                Sfx.wall()
                Harness.count("hippoParries")
            else
                damage(b)
                p.vy = -math.abs(p.vy) -- off the helmet
            end
        end
    elseif b.name == "kraken" then
        if b.open and dx * dx + dy * dy < 17 * 17 then damage(b) end
    end
end

-- the siren's song bends the pearl toward her
function Bosses.steerPearl(p, dt)
    local b = G.boss
    if not b or b.name ~= "siren" or not b.shielded or p.held or p.eaten then return end
    local dx, dy = b.x - p.x, b.y - p.y
    local d = math.max(1, math.sqrt(dx * dx + dy * dy))
    local pull = SMOKE_BUILD and 40 or 60
    p.vx = p.vx + dx / d * pull * dt
    p.vy = p.vy + dy / d * pull * dt
    local s = Pearl.speed() / math.max(1, math.sqrt(p.vx * p.vx + p.vy * p.vy))
    p.vx, p.vy = p.vx * s, p.vy * s
end

-- powder keg blast feeding Charybdis
function Bosses.onBlast(x, y)
    local b = G.boss
    if b and b.name == "charybdis" then
        local dx, dy = x - b.x, y - b.y
        if dx * dx + dy * dy < 80 * 80 then
            damage(b, true)
            Harness.count("whirlFed")
        end
    end
end

-- what should the autopilot shoot at right now? nil = use blocks
function Bosses.aim()
    local b = G.boss
    if not b then return end
    if b.name == "hermit" then
        if b.exposed then return b.x, b.y end
        for _, ch in ipairs(b.armor) do
            if ch.alive then
                return b.x + math.cos(ch.a) * 30, b.y + math.sin(ch.a) * 26
            end
        end
    elseif b.name == "kelpie" then
        return b.x + b.vx * 0.35, b.y
    elseif b.name == "siren" then
        if not b.shielded then return b.x, b.y end
    elseif b.name == "umibozu" then
        if b.open then
            for _, eye in ipairs(b.eyes) do
                if eye.hp > 0 then return b.x + eye.dx, b.y - 22 end
            end
        end
    elseif b.name == "hippo" then
        if b.charge <= 0 then return b.x, b.y - 22 end
    elseif b.name == "kraken" then
        if b.open then return b.x, b.y end
    end
end

-- ---- drawing -----------------------------------------------------------

function Bosses.drawBack()
    local b = G.boss
    if not b then return end
    gfx.setColor(gfx.kColorWhite)
    if b.name == "umibozu" then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillEllipseInRect(b.x - 70, b.y - 60, 140, 130)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawEllipseInRect(b.x - 70, b.y - 60, 140, 130)
        for _, eye in ipairs(b.eyes) do
            local ex, ey = b.x + eye.dx, b.y - 22
            if b.open and eye.hp > 0 then
                gfx.fillCircleAtPoint(ex, ey, 9)
                gfx.setColor(gfx.kColorBlack)
                gfx.fillCircleAtPoint(ex, ey, 3)
                gfx.setColor(gfx.kColorWhite)
            else
                gfx.drawLine(ex - 8, ey, ex + 8, ey)
            end
        end
    elseif b.name == "charybdis" then
        for i = 1, 4 do
            local a0 = math.deg(b.spin * (5 - i)) % 360
            gfx.drawArc(b.x, b.y, 8 + i * 8, a0, a0 + 250)
        end
        if b.holding then
            gfx.fillCircleAtPoint(b.x, b.y, C.PEARL_R)
        end
    elseif b.name == "kraken" then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillEllipseInRect(b.x - 90, b.y - 45, 180, 110)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawEllipseInRect(b.x - 90, b.y - 45, 180, 110)
        if b.open then
            gfx.fillEllipseInRect(b.x - 16, b.y - 12, 32, 24)
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(b.x, b.y, 5)
            gfx.setColor(gfx.kColorWhite)
        else
            gfx.drawLine(b.x - 14, b.y, b.x + 14, b.y)
        end
    elseif b.name == "siren" then
        local r = (b.t * 30) % 60
        gfx.drawCircleAtPoint(b.x, b.y, 14 + r) -- song ring
    end
end

function Bosses.drawFront()
    local b = G.boss
    if not b then return end
    gfx.setColor(gfx.kColorWhite)
    if b.name == "hermit" then
        gfx.fillEllipseInRect(b.x - 16, b.y - 10, 32, 20)
        for s = -1, 1, 2 do
            gfx.fillCircleAtPoint(b.x + s * 20, b.y + 6, 5)
        end
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(b.x - 5, b.y - 4, 2)
        gfx.fillCircleAtPoint(b.x + 5, b.y - 4, 2)
        gfx.setColor(gfx.kColorWhite)
        for _, ch in ipairs(b.armor) do
            if ch.alive then
                local ax = b.x + math.cos(ch.a) * 30
                local ay = b.y + math.sin(ch.a) * 26
                gfx.setPattern(DITHER)
                gfx.fillCircleAtPoint(ax, ay, 10)
                gfx.setColor(gfx.kColorWhite)
                gfx.drawCircleAtPoint(ax, ay, 10)
            end
        end
    elseif b.name == "kelpie" then
        local d = Util.sign(b.vx)
        gfx.fillEllipseInRect(b.x - 18, b.y - 8, 36, 16)
        gfx.drawLine(b.x + d * 14, b.y - 4, b.x + d * 26, b.y - 16)
        gfx.fillEllipseInRect(b.x + d * 20 - 7, b.y - 26, 14, 9)
        for i = 0, 3 do
            gfx.drawLine(b.x - d * i * 8, b.y - 6,
                b.x - d * (i * 8 + 6), b.y + 4 + math.sin(b.t * 5 + i) * 3)
        end
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(b.x + d * 24, b.y - 22, 1.5)
        gfx.setColor(gfx.kColorWhite)
    elseif b.name == "siren" then
        gfx.fillCircleAtPoint(b.x, b.y - 8, 6)
        gfx.fillEllipseInRect(b.x - 7, b.y - 2, 14, 16)
        gfx.drawLine(b.x - 4, b.y + 14, b.x - 10, b.y + 22)
        gfx.drawLine(b.x + 4, b.y + 14, b.x + 10, b.y + 22)
        for s = -1, 1, 2 do
            gfx.drawLine(b.x + s * 5, b.y - 12,
                b.x + s * (9 + math.sin(b.t * 2) * 3), b.y - 2)
        end
    elseif b.name == "hippo" then
        local d = b.vx
        gfx.fillEllipseInRect(b.x - 8, b.y - 26, 16, 22)
        gfx.fillCircleAtPoint(b.x, b.y - 30, 6)
        gfx.drawLine(b.x + d * 5, b.y - 30, b.x + d * 22, b.y - 28)
        gfx.drawCircleAtPoint(b.x - d * 2, b.y - 8, 5)
        if b.charge > 0 then
            for i = 1, 3 do
                gfx.drawLine(b.x - d * (14 + i * 7), b.y - 16 - i * 4,
                    b.x - d * (22 + i * 7), b.y - 16 - i * 4)
            end
        end
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(b.x + d * 2, b.y - 31, 1.5)
        gfx.setColor(gfx.kColorWhite)
    elseif b.name == "kraken" then
        for _, tn in ipairs(b.tents) do
            if tn.h > 0 then
                local top = 228 - tn.h
                gfx.fillRoundRect(tn.x - 7, top, 14, tn.h + 6, 6)
                gfx.setColor(gfx.kColorBlack)
                for i = 1, math.floor(tn.h / 16) do
                    gfx.fillCircleAtPoint(tn.x, top + i * 16 - 6, 2)
                end
                gfx.setColor(gfx.kColorWhite)
            end
        end
    end
end
