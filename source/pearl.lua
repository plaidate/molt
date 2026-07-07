-- The pearl: angle-only physics vs walls, the block grid and the carapace.
-- Exit angle off the shell depends on hit offset, plus crank english.
-- Sticky Claw (hold B) catches instead of bouncing; Pincer Snap can
-- super-shot it; Heavy Pearl is a touch slower but shatters stone.

Pearl = {}

function Pearl.speed()
    return C.PEARL_SPD * (G.save.molts.heavy and C.HEAVY_FACTOR or 1)
end

function Pearl.reset()
    G.pearl = {
        x = G.crab.x, y = C.PADDLE_Y - C.PEARL_R,
        vx = 0, vy = 0,
        held = true, aim = 0, lock = 0,
    }
end

local function launch(aimDeg)
    local p = G.pearl
    local a = math.rad(Util.clamp(aimDeg, -C.SERVE_CAP, C.SERVE_CAP))
    local spd = Pearl.speed()
    p.vx = spd * math.sin(a)
    p.vy = -spd * math.cos(a)
    p.held = false
    Harness.count("serves")
    Sfx.serve()
end

-- pincer super-shot: relaunch a nearby falling pearl, fast and steep
function Pearl.snapShot()
    local p, cb = G.pearl, G.crab
    if p.held then return false end
    if math.abs(p.x - cb.x) > C.SNAP_REACH or p.y < 170 then return false end
    local tilt = Util.clamp((p.x - cb.x) * 2, -25, 25)
    local a = math.rad(tilt)
    local spd = Pearl.speed() * 1.35
    p.vx = spd * math.sin(a)
    p.vy = -spd * math.cos(a)
    Harness.count("snapShots")
    Sfx.paddle(1)
    return true
end

local function paddleBounce(p, inp)
    local cb = G.crab
    if inp.catch and G.save.molts.sticky then
        p.held = true
        p.lock = 0.3
        p.x, p.y = cb.x, C.PADDLE_Y - C.PEARL_R
        p.vx, p.vy = 0, 0
        Harness.count("catches")
        Sfx.chip()
        return
    end
    local off = Util.clamp((p.x - cb.x) / (C.CRAB_HW + C.PEARL_R), -1, 1)
    local tilt = off * C.BOUNCE_MAX
    if inp.english ~= 0 then
        tilt = tilt + Util.clamp(inp.english, -C.ENGLISH_MAX, C.ENGLISH_MAX)
        Harness.count("english")
    end
    tilt = Util.clamp(tilt, -C.TILT_CAP, C.TILT_CAP)
    local a = math.rad(tilt)
    local spd = Pearl.speed()
    p.vx = spd * math.sin(a)
    p.vy = -spd * math.cos(a)
    p.y = C.PADDLE_Y - C.PEARL_R
    cb.squash = 1
    Harness.count("paddleBounces")
    Sfx.paddle(off)
end

local function miss(p)
    Harness.count("misses")
    Sfx.miss()
    Fx.burst(p.x, 234, 8)
    G.flash = 0.25
    G.hearts = G.hearts - 1
    if G.hearts <= 0 then
        G.mode = "moltback"
        G.t = 0
        Harness.count("moltbacks")
        Sfx.moltback()
    else
        p.held = true
        p.lock = C.MISS_LOCK
        p.x, p.y = G.crab.x, C.PADDLE_Y - C.PEARL_R
        p.vx, p.vy = 0, 0
    end
end

function Pearl.update(dt, inp)
    local p = G.pearl
    p.lock = math.max(0, p.lock - dt)
    if p.eaten then return end -- a moray has it; snap its nose

    if p.held then
        p.aim = Util.clamp(inp.aim, -C.SERVE_CAP, C.SERVE_CAP)
        p.x = G.crab.x
        p.y = C.PADDLE_Y - C.PEARL_R - G.crab.burrow * 10
        if inp.serve and p.lock <= 0 and G.crab.burrow < 0.3 then
            launch(p.aim)
        end
        return
    end

    Bosses.steerPearl(p, dt) -- the siren's song
    -- zone current bends the flight without changing speed
    local cur = RoomDefs[G.room].current
    if cur then
        p.vx = p.vx + cur * dt
        local s = Pearl.speed() / math.max(1, math.sqrt(p.vx * p.vx + p.vy * p.vy))
        p.vx, p.vy = p.vx * s, p.vy * s
    end

    local h = dt / 2
    for _ = 1, 2 do
        local nx = p.x + p.vx * h
        if nx - C.PEARL_R < 0 then
            nx = C.PEARL_R
            p.vx = -p.vx
            Sfx.wall()
            Harness.count("wallBounces")
        elseif nx + C.PEARL_R > C.W then
            nx = C.W - C.PEARL_R
            p.vx = -p.vx
            Sfx.wall()
            Harness.count("wallBounces")
        end
        local r, c = Blocks.at(nx + Util.sign(p.vx) * C.PEARL_R, p.y)
        if r then
            Blocks.hit(r, c)
            p.vx = -p.vx
            Harness.count("gridBounces")
        else
            p.x = nx
        end

        local ny = p.y + p.vy * h
        if ny - C.PEARL_R < C.FIELD_Y then
            ny = C.FIELD_Y + C.PEARL_R
            p.vy = -p.vy
            Sfx.wall()
            Harness.count("wallBounces")
        end
        r, c = Blocks.at(p.x, ny + Util.sign(p.vy) * C.PEARL_R)
        if r then
            Blocks.hit(r, c)
            p.vy = -p.vy
            Harness.count("gridBounces")
        else
            p.y = ny
        end

        local cb = G.crab
        if p.vy > 0 and cb.burrow < 0.5
            and p.y + C.PEARL_R >= C.PADDLE_Y and p.y + C.PEARL_R < C.PADDLE_Y + 12
            and math.abs(p.x - cb.x) <= C.CRAB_HW + C.PEARL_R then
            paddleBounce(p, inp)
            if p.held then return end
        end

        if p.y - C.PEARL_R > C.H then
            miss(p)
            return
        end
    end
    Enemies.pearlCheck(p)
    Bosses.pearlCheck(p)
end

function Pearl.draw()
    local gfx = playdate.graphics
    local p = G.pearl
    if p.eaten then return end
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(p.x, p.y, C.PEARL_R)
    if p.held then
        local a = math.rad(p.aim)
        local dx, dy = math.sin(a), -math.cos(a)
        for i = 1, 5 do
            gfx.fillCircleAtPoint(p.x + dx * i * 11, p.y + dy * i * 11, 1)
        end
    end
end
