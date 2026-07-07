-- Floor items: shell shards (drop from * coral, fall, crab collects;
-- 4 shards = +1 max heart) and molt shrines (touch to molt — placeholder
-- for the M5 bosses).

Items = {}

local shards = {}

function Items.reset()
    shards = {}
end

function Items.dropShard(x, y)
    shards[#shards + 1] = { x = x, y = y, vy = 30 }
    Harness.count("shardsDropped")
end

local function collect(i)
    table.remove(shards, i)
    G.save.shards = G.save.shards + 1
    Harness.count("shardsGot")
    Sfx.anemone()
    if G.save.shards >= C.SHARDS_PER_HEART and G.maxHearts < C.MAX_HEARTS then
        G.save.shards = G.save.shards - C.SHARDS_PER_HEART
        G.maxHearts = G.maxHearts + 1
        G.save.maxHearts = G.maxHearts
        G.hearts = G.maxHearts
        Save.store()
        Sfx.fanfare()
        Game.toast("YOUR SHELL GROWS")
        Harness.count("heartUps")
    end
end

function Items.update(dt)
    for i = #shards, 1, -1 do
        local s = shards[i]
        if s.y < 224 then
            s.y = s.y + s.vy * dt
            s.vy = math.min(90, s.vy + 60 * dt)
        end
        if s.y >= 210 and math.abs(G.crab.x - s.x) < 16 then
            collect(i)
        end
    end

    -- molt shrine touch (only once the room's guardian has yielded)
    local def = RoomDefs[G.room]
    if def.shrine and not G.save.molts[def.shrine.molt]
        and (not def.boss or G.save.bosses[def.boss]) then
        local sx = (def.shrine.col - 1) * C.CELL + 8
        if math.abs(G.crab.x - sx) < 18 then
            Game.molt(def.shrine.molt)
        end
    end
end

function Items.draw()
    local gfx = playdate.graphics
    gfx.setColor(gfx.kColorWhite)
    for _, s in ipairs(shards) do
        -- little shard triangle, glinting
        gfx.fillTriangle(s.x - 4, s.y + 3, s.x + 4, s.y + 3, s.x, s.y - 4)
        if math.floor(G.t * 6) % 3 == 0 then
            gfx.drawLine(s.x + 5, s.y - 5, s.x + 7, s.y - 7)
        end
    end
    local def = RoomDefs[G.room]
    if def.shrine and not G.save.molts[def.shrine.molt]
        and (not def.boss or G.save.bosses[def.boss]) then
        local sx = (def.shrine.col - 1) * C.CELL + 8
        local pulse = 2 + math.sin(G.t * 4)
        -- empty shell on a pedestal
        gfx.fillRect(sx - 8, 222, 16, 5)
        gfx.drawEllipseInRect(sx - 7, 208, 14, 12)
        gfx.drawLine(sx, 210, sx, 218)
        gfx.drawCircleAtPoint(sx, 214, 10 + pulse)
    end
end
