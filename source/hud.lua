-- Top 16px strip: shell hearts, zone name, blocks left.

Hud = {}

function Hud.draw()
    local gfx = playdate.graphics
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(0, C.HUD_H - 1, C.W, C.HUD_H - 1)

    -- hearts as little scallop shells, shard pips after them
    local mh = G.maxHearts or C.HEARTS
    for i = 1, mh do
        local x, y = 5 + (i - 1) * 15, 3
        if i <= G.hearts then
            gfx.fillEllipseInRect(x, y, 12, 10)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawLine(x + 6, y + 2, x + 6, y + 8)
            gfx.drawLine(x + 3, y + 3, x + 4, y + 7)
            gfx.drawLine(x + 9, y + 3, x + 8, y + 7)
            gfx.setColor(gfx.kColorWhite)
        else
            gfx.drawEllipseInRect(x, y, 12, 10)
        end
    end
    for i = 1, G.save.shards % C.SHARDS_PER_HEART do
        gfx.fillCircleAtPoint(8 + mh * 15 + i * 7, 8, 2)
    end
    if G.boss then
        -- boss health bar where the keys usually sit
        local b = G.boss
        gfx.drawRect(C.W - 110, 4, 80, 8)
        gfx.fillRect(C.W - 110, 4, math.max(0, 80 * b.hp / b.maxHp), 8)
    else
        -- temple keys
        for i = 1, G.save.keys do
            local x = C.W - 40 - i * 11
            gfx.drawCircleAtPoint(x, 6, 3)
            gfx.drawLine(x, 9, x, 13)
            gfx.drawLine(x, 12, x + 3, 12)
        end
    end

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned((G.roomName or "") .. " - " .. (G.room or ""), C.W / 2, 1, kTextAlignment.center)
    gfx.drawTextAligned(tostring(Blocks.remaining()), C.W - 6, 1, kTextAlignment.right)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end
