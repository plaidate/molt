-- All rendering: black water, white outlined creatures, dithered sand,
-- zone backdrops, gate blocks, items, darkness (Lantern Snail), toasts,
-- transitions, molt ceremony. Map screen lives in worldmap.lua.

Draw = {}

local gfx = playdate.graphics
local DITHER = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 }
local darkMask = gfx.image.new(400, 240)

local function blockCell(r, c, cell)
    local x, y = (c - 1) * C.CELL, C.FIELD_Y + (r - 1) * C.CELL
    local t = cell.t
    if t == "#" then
        gfx.setPattern(DITHER)
        gfx.fillRect(x, y, C.CELL, C.CELL)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRect(x, y, C.CELL, C.CELL)
    elseif t == "S" then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(x + 1, y + 1, 14, 14)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(x + 1, y + 5, x + 15, y + 5)
        gfx.drawLine(x + 1, y + 10, x + 15, y + 10)
        gfx.drawLine(x + 8, y + 1, x + 8, y + 5)
        gfx.drawLine(x + 4, y + 5, x + 4, y + 10)
        gfx.drawLine(x + 11, y + 10, x + 11, y + 15)
        if cell.hp == 1 then
            gfx.drawLine(x + 2, y + 13, x + 13, y + 3)
        end
        gfx.setColor(gfx.kColorWhite)
    elseif t == "k" then
        gfx.setColor(gfx.kColorWhite)
        for i = 0, 2 do
            local kx = x + 3 + i * 5
            local sway = math.sin(G.t * 2 + r + i) * 1.5
            gfx.drawLine(kx, y + 15, kx + sway, y + 8)
            gfx.drawLine(kx + sway, y + 8, kx, y + 1)
        end
    elseif t == "g" then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(x + 1, y + 1, 14, 14, 2)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(x + 8, y + 3, x + 12, y + 8)
        gfx.drawLine(x + 12, y + 8, x + 8, y + 13)
        gfx.drawLine(x + 8, y + 13, x + 4, y + 8)
        gfx.drawLine(x + 4, y + 8, x + 8, y + 3)
        gfx.fillCircleAtPoint(x + 8, y + 8, 1.5)
        gfx.setColor(gfx.kColorWhite)
    elseif t == "!" then
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRect(x + 1, y + 1, 14, 14)
        gfx.drawCircleAtPoint(x + 8, y + 6, 3)
        gfx.drawLine(x + 8, y + 9, x + 8, y + 13)
        gfx.drawLine(x + 8, y + 12, x + 11, y + 12)
        if math.floor(G.t * 4) % 2 == 0 then
            gfx.drawRect(x - 1, y - 1, 18, 18)
        end
    elseif t == "B" then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(x + 1, y + 1, 14, 14, 4)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(x + 4, y + 5, x + 12, y + 5)
        gfx.drawLine(x + 3, y + 8, x + 11, y + 8)
        gfx.drawLine(x + 5, y + 11, x + 12, y + 11)
        if cell.hp == 1 then
            gfx.drawLine(x + 2, y + 13, x + 13, y + 3)
        end
        gfx.setColor(gfx.kColorWhite)
    else -- coral, or shard coral (*)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(x + 1, y + 1, 14, 14, 3)
        gfx.setColor(gfx.kColorBlack)
        if t == "*" then
            gfx.drawLine(x + 8, y + 4, x + 8, y + 12)
            gfx.drawLine(x + 4, y + 8, x + 12, y + 8)
            gfx.drawLine(x + 5, y + 5, x + 11, y + 11)
            gfx.drawLine(x + 11, y + 5, x + 5, y + 11)
        else
            local k = (r * 7 + c * 13) % 3
            gfx.fillCircleAtPoint(x + 5 + k, y + 6, 1)
            gfx.fillCircleAtPoint(x + 10, y + 10 - k, 1)
        end
        gfx.setColor(gfx.kColorWhite)
    end
end

local function field()
    for r = 1, C.ROWS do
        local row = G.grid[r]
        for c = 1, C.COLS do
            if row[c] then blockCell(r, c, row[c]) end
        end
    end
    -- kelp/glyph gate columns hang down into the sand: draw the tails
    for c = 1, C.COLS do
        local cell = G.grid[C.ROWS][c]
        if cell and (cell.t == "k" or cell.t == "g") then
            local x = (c - 1) * C.CELL
            gfx.setColor(gfx.kColorWhite)
            gfx.drawLine(x + 4, C.SAND_Y, x + 4, 228)
            gfx.drawLine(x + 11, C.SAND_Y, x + 11, 228)
        end
    end
end

local function backdrop(def)
    gfx.setColor(gfx.kColorWhite)
    if def.zone == "K" then
        for i = 1, 5 do
            local x0 = 20 + i * 63
            for y = 24, 204, 9 do
                local x = x0 + math.sin(y * 0.045 + G.t * 1.2 + i * 2) * 7
                gfx.fillRect(x, y, 2, 4)
            end
        end
    elseif def.zone == "R" then
        for i = 1, 4 do
            local x0 = 40 + i * 80
            gfx.drawArc(x0, 232, 22 + (i % 2) * 10, -70, 70)
            gfx.drawArc(x0, 232, 12, -50, 50)
        end
    elseif def.zone == "S" then
        for i = 1, 5 do
            gfx.drawArc(80 + i * 50, 300, 90, -28, 28)
        end
    elseif def.zone == "A" then
        for i = 1, 12 do
            local y = (i * 53 + G.t * 8) % 190 + 20
            gfx.fillRect((i * 137) % 390 + 4, y, 1, 2)
        end
    elseif def.zone == "M" then
        for i = 0, 2 do
            local x = 64 + i * 136
            gfx.drawLine(x, 24, x, 206)
            gfx.drawLine(x + 8, 24, x + 8, 206)
            gfx.fillRect(x - 3, 22, 15, 4)
        end
    end
end

local function ventBubbles(def)
    if not (def.vent and def.exits and def.exits.U) then return end
    local x1, x2 = (def.vent[1] - 1) * C.CELL, def.vent[2] * C.CELL
    gfx.setColor(gfx.kColorWhite)
    for i = 1, 5 do
        local ph = (G.t * 55 + i * 41) % 200
        local y = 226 - ph
        if y > C.FIELD_Y + 4 then
            local bx = x1 + 4 + ((i * 53) % (x2 - x1 - 8))
            gfx.drawCircleAtPoint(bx + math.sin((y + i * 30) * 0.07) * 3, y, 1 + (i % 3))
        end
    end
end

local function sand(def)
    gfx.setPattern(DITHER)
    gfx.fillRect(0, 228, C.W, 12)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(0, 228, C.W, 228)
    if def.gap and def.exits and def.exits.D then
        local x1, x2 = (def.gap[1] - 1) * C.CELL, def.gap[2] * C.CELL
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x1, 228, x2 - x1, 12)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(x1, 228, x1 + 3, 234)
        gfx.drawLine(x2, 228, x2 - 3, 234)
        local cx = (x1 + x2) / 2
        gfx.drawLine(cx - 4, 232, cx, 236)
        gfx.drawLine(cx + 4, 232, cx, 236)
    end
end

local function anemone(def)
    if not def.anemone then return end
    local ax = (def.anemone - 1) * C.CELL + 8
    gfx.setColor(gfx.kColorWhite)
    for i = 0, 7 do
        local a = -math.pi / 2 + ((i - 3.5) / 3.5) * 0.8 + math.sin(G.t * 2 + i) * 0.12
        gfx.drawLine(ax, 227, ax + math.cos(a) * 12, 227 + math.sin(a) * 12)
    end
    gfx.fillCircleAtPoint(ax, 227, 3)
end

local function darkness(def)
    if not (def.dark or G.bossDark) then return end
    gfx.pushContext(darkMask)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, C.W, C.H)
    gfx.setColor(gfx.kColorClear)
    local lantern = G.save.molts.lantern
    gfx.fillCircleAtPoint(G.crab.x, 216, lantern and C.DARK_R_LANTERN or C.DARK_R)
    if lantern and not G.pearl.held then
        gfx.fillCircleAtPoint(G.pearl.x, G.pearl.y, C.DARK_R_PEARL)
    end
    gfx.popContext()
    darkMask:draw(0, 0)
end

local function toast()
    if not G.toastT or G.toastT <= 0 then return end
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(70, 176, 260, 18)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(70, 176, 260, 18)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned(G.toast, C.W / 2, 179, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

local function banner(a, b)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(60, 92, 280, 52)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(60, 92, 280, 52)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned(a, C.W / 2, 102, kTextAlignment.center)
    if b then gfx.drawTextAligned(b, C.W / 2, 122, kTextAlignment.center) end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function Draw.scene()
    gfx.clear(gfx.kColorBlack)
    local def = RoomDefs[G.room]
    backdrop(def)
    Bosses.drawBack()
    field()
    ventBubbles(def)
    sand(def)
    anemone(def)
    Items.draw()
    Enemies.draw()
    Bosses.drawFront()
    Crab.draw()
    -- current speckles: the water itself is moving
    if def.current then
        gfx.setColor(gfx.kColorWhite)
        for i = 1, 8 do
            local sx = ((i * 157) + G.t * def.current * 2) % C.W
            gfx.fillRect(sx, 30 + (i * 83) % 170, 3, 1)
        end
    end
    Pearl.draw()
    Fx.draw()
    darkness(def)
    Hud.draw()
    toast()
end

function Draw.play()
    Draw.scene()
    if G.flash > 0 then
        gfx.setColor(gfx.kColorXOR)
        gfx.fillRect(0, 0, C.W, C.H)
        gfx.setColor(gfx.kColorWhite)
    end
end

function Draw.transition()
    local tr = G.transition
    local p = Util.clamp(tr.t / C.TRANSITION_T, 0, 1)
    p = p * p * (3 - 2 * p)
    local nx, ny, ox, oy = 0, 0, 0, 0
    if tr.dir == "R" then
        nx, ox = (1 - p) * C.W, -p * C.W
    elseif tr.dir == "L" then
        nx, ox = -(1 - p) * C.W, p * C.W
    elseif tr.dir == "U" then
        ny, oy = -(1 - p) * C.H, p * C.H
    elseif tr.dir == "D" then
        ny, oy = (1 - p) * C.H, -p * C.H
    end
    gfx.setDrawOffset(nx, ny)
    Draw.scene()
    gfx.setDrawOffset(0, 0)
    tr.oldImg:draw(ox, oy)
end

function Draw.moltback()
    Draw.play()
    banner("*YOUR SHELL CRACKS*", "the tide carries you back...")
end

function Draw.victory()
    Draw.scene()
    banner("*THE DEEP EXHALES*", "the reef is yours, little crab")
    gfx.setColor(gfx.kColorWhite)
    local r = 10 + (G.t % 1.2) * 60
    gfx.drawCircleAtPoint(C.W / 2, 118, r)
    local m = G.save.molts
    local n = (m.pincer and 1 or 0) + (m.sticky and 1 or 0) + (m.heavy and 1 or 0)
        + (m.lantern and 1 or 0) + (m.anchor and 1 or 0)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned("molts " .. n .. "/5   keys " .. G.save.keys .. "/3   shell " .. G.maxHearts,
        C.W / 2, 152, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function Draw.moltCeremony()
    Draw.scene()
    local txt = Game.MOLT_TEXT[G.moltName] or { "?", "" }
    banner("*MOLT: " .. txt[1] .. "*", txt[2])
    -- the shell splits: pulsing rings around the crab
    gfx.setColor(gfx.kColorWhite)
    local r = 10 + (G.t % 0.8) * 40
    gfx.drawCircleAtPoint(G.crab.x, 216, r)
end

local titleImg

function Draw.title()
    gfx.clear(gfx.kColorBlack)
    -- swaying kelp frames the title
    gfx.setColor(gfx.kColorWhite)
    for i = 0, 1 do
        local x0 = 20 + i * 356
        for y = 30, 210, 9 do
            local x = x0 + math.sin(y * 0.05 + G.t * 1.2 + i * 3) * 5
            gfx.fillRect(x, y, 2, 4)
        end
    end
    sand(RoomDefs[G.room])
    Crab.draw()
    if not titleImg then
        local w, h = gfx.getTextSize("*MOLT*")
        titleImg = gfx.image.new(w, h)
        gfx.pushContext(titleImg)
        gfx.drawText("*MOLT*", 0, 0)
        gfx.popContext()
    end
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    local tw = titleImg:getSize()
    titleImg:drawScaled(C.W / 2 - tw * 3 / 2, 42, 3)
    gfx.drawTextAligned("an arkanoidvania", C.W / 2, 106, kTextAlignment.center)
    local hasSave = G.save.anemone ~= nil
    gfx.drawTextAligned(hasSave and "the tide remembers - Ⓐ continue" or "Ⓐ begin",
        C.W / 2, 136, kTextAlignment.center)
    gfx.drawTextAligned("✛ scuttle + burrow   🎣 aim", C.W / 2, 162, kTextAlignment.center)
    gfx.drawTextAligned("Ⓐ serve / snap   Ⓑ catch / map", C.W / 2, 180, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.fillCircleAtPoint(C.W / 2, 30 + math.sin(G.t * 3) * 4, C.PEARL_R + 1)
end
