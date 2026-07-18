-- The crab: your paddle. Scuttles the sand band, burrows to dodge,
-- balances the pearl on its shell between serves. Drawn parametrically:
-- carapace ellipse, phase-animated legs, claws, blinking eyestalks.

Crab = {}

function Crab.reset()
    G.crab = {
        x = C.W / 2,
        burrow = 0, moving = 0,
        walkPhase = 0, squash = 0,
        blink = 0, blinkT = 2,
    }
end

function Crab.update(dt, inp)
    local cb = G.crab
    cb.stunT = math.max(0, (cb.stunT or 0) - dt)
    cb.invulnT = math.max(0, (cb.invulnT or 0) - dt)
    if cb.stunT > 0 then
        cb.moving = 0
        cb.snapT = math.max(0, (cb.snapT or 0) - dt)
        return
    end
    -- abyss crush-currents drag the crab; Anchor Legs hold fast
    local crush = RoomDefs[G.room].crush
    if crush and not G.save.molts.anchor then
        cb.x = Util.clamp(cb.x + crush * dt, C.CRAB_HW, C.W - C.CRAB_HW)
        if not G.crushNoted then
            G.crushNoted = true
            Harness.count("crushPushed")
        end
    end
    if inp.mvx ~= 0 and cb.burrow < 0.5 then
        local nx = Util.clamp(cb.x + inp.mvx * C.CRAB_SPD * dt, C.CRAB_HW, C.W - C.CRAB_HW)
        -- kelp curtains and glyph walls block the crab at the leading edge
        -- (sign, not mvx: crank scuttle can exceed 1 and must not overshoot)
        if not Blocks.crabBlockedAt(nx + Util.sign(inp.mvx) * C.CRAB_HW) then
            cb.x = nx
        end
        cb.walkPhase = cb.walkPhase + dt * 14
        cb.moving = 1
    else
        cb.moving = 0
    end
    cb.snapT = math.max(0, (cb.snapT or 0) - dt)

    local want = inp.burrow and 1 or 0
    if want > cb.burrow then
        if cb.burrow == 0 then Harness.count("burrows") end
        cb.burrow = math.min(1, cb.burrow + C.BURROW_SPD * dt)
    elseif want < cb.burrow then
        cb.burrow = math.max(0, cb.burrow - C.BURROW_SPD * dt)
    end

    cb.squash = math.max(0, cb.squash - dt * 4)
    cb.blink = math.max(0, cb.blink - dt)
    cb.blinkT = cb.blinkT - dt
    if cb.blinkT <= 0 then
        cb.blink = 0.12
        cb.blinkT = 1.5 + math.random() * 3
    end
end

function Crab.draw()
    local gfx = playdate.graphics
    local cb = G.crab
    local sink = cb.burrow * 16
    local bx, by = cb.x, 221 + sink -- carapace centre
    local sq = 1 - cb.squash * 0.3
    local h = 15 * sq
    local topY = by - h + 4

    gfx.setColor(gfx.kColorWhite)
    if cb.burrow < 0.6 then
        -- legs, three a side, lifting with the walk phase
        for i = -1, 1 do
            for s = -1, 1, 2 do
                local lift = math.abs(math.sin(cb.walkPhase + i * 1.2)) * 3 * cb.moving
                gfx.drawLine(bx + s * 9, by + 2, bx + s * (14 + i * 3), 233 - lift)
            end
        end
        -- claws (raised, flashing arcs while snapping; each molt shows)
        local snap = (cb.snapT or 0) > 0
        local clawR = (G.save.molts.pincer and 5 or 4)
        for s = -1, 1, 2 do
            gfx.fillCircleAtPoint(bx + s * 16, snap and by - 8 or by, snap and clawR + 1 or clawR)
            if G.save.molts.sticky then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillCircleAtPoint(bx + s * 16, snap and by - 8 or by, 1.5)
                gfx.setColor(gfx.kColorWhite)
            end
        end
        if snap then
            gfx.drawCircleAtPoint(bx, by - 6, C.SNAP_REACH)
        end
        gfx.setColor(gfx.kColorBlack)
        for s = -1, 1, 2 do
            gfx.drawLine(bx + s * 16, by - 3, bx + s * 19, by - 1) -- pincer notch
        end
        gfx.setColor(gfx.kColorWhite)
    end

    -- carapace (heavier shell rings as you molt)
    gfx.fillEllipseInRect(bx - C.CRAB_HW, topY, C.CRAB_HW * 2, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawEllipseInRect(bx - C.CRAB_HW + 4, topY + 3, C.CRAB_HW * 2 - 8, h - 6)
    if G.save.molts.heavy then
        gfx.drawEllipseInRect(bx - C.CRAB_HW + 8, topY + 5, C.CRAB_HW * 2 - 16, h - 10)
    end
    gfx.setColor(gfx.kColorWhite)
    -- the lantern snail rides the shell
    if G.save.molts.lantern then
        gfx.fillCircleAtPoint(bx - 8, topY, 3.5)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawCircleAtPoint(bx - 8, topY, 1.5)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(bx - 6, topY - 3, bx - 5, topY - 6)
    end
    -- anchor legs: braced stance spikes
    if G.save.molts.anchor and cb.burrow < 0.6 then
        for s = -1, 1, 2 do
            gfx.drawLine(bx + s * 12, by + 4, bx + s * 12, 233)
        end
    end
    gfx.setColor(gfx.kColorBlack)

    -- eyestalks
    for s = -1, 1, 2 do
        local ex = bx + s * 5
        gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(ex, topY + 2, ex + s * 2, topY - 5)
        if cb.blink > 0 then
            gfx.drawLine(ex + s * 2 - 2, topY - 5, ex + s * 2 + 2, topY - 5)
        else
            gfx.fillCircleAtPoint(ex + s * 2, topY - 6, 2.5)
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(ex + s * 2 + s, topY - 6, 1)
        end
    end

    -- stunned: little orbiting stars; invulnerable: skip-frame blink
    if (cb.stunT or 0) > 0 then
        for i = 0, 2 do
            local a = G.t * 6 + i * 2.1
            gfx.fillCircleAtPoint(bx + math.cos(a) * 14, topY - 10 + math.sin(a) * 4, 1.5)
        end
    end
    -- burrow mound
    if cb.burrow > 0.3 then
        gfx.setPattern({ 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 })
        gfx.fillEllipseInRect(bx - 20, 226, 40, 12)
    end
    gfx.setColor(gfx.kColorWhite)
end
