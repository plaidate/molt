-- The world map screen: visited rooms as boxes on a fixed grid
-- (def.mapPos), connections between visited neighbours, blinking dot on
-- the current room, ring on the saved anemone.

WorldMap = {}

local gfx = playdate.graphics
local CW, CH = 40, 18 -- room box
local SX, SY = 50, 30 -- grid pitch
local OX, OY = 8, 34  -- top-left of map cell (0,0)

local function cellXY(def)
    return OX + def.mapPos[1] * SX, OY + def.mapPos[2] * SY
end

function WorldMap.draw()
    gfx.clear(gfx.kColorBlack)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned("*THE SHALLOWS*", C.W / 2, 10, kTextAlignment.center)
    gfx.drawTextAligned("Ⓑ back", C.W / 2, 220, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorWhite)

    -- connections under the boxes
    for name, def in pairs(RoomDefs) do
        if G.save.visited[name] and def.mapPos and def.exits then
            local x, y = cellXY(def)
            for _, dest in pairs(def.exits) do
                local dd = RoomDefs[dest]
                if G.save.visited[dest] and dd.mapPos then
                    local x2, y2 = cellXY(dd)
                    gfx.drawLine(x + CW / 2, y + CH / 2, x2 + CW / 2, y2 + CH / 2)
                end
            end
        end
    end

    for name, def in pairs(RoomDefs) do
        if G.save.visited[name] and def.mapPos then
            local x, y = cellXY(def)
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(x, y, CW, CH)
            gfx.setColor(gfx.kColorWhite)
            gfx.drawRect(x, y, CW, CH)
            if def.anemone then
                gfx.fillCircleAtPoint(x + CW - 7, y + CH - 7, 2)
                if G.save.anemone == name then
                    gfx.drawCircleAtPoint(x + CW - 7, y + CH - 7, 5)
                end
            end
            if name == G.room then
                gfx.drawRect(x - 2, y - 2, CW + 4, CH + 4)
                if math.floor(G.t * 3) % 2 == 0 then
                    gfx.fillCircleAtPoint(x + CW / 2, y + CH / 2, 3)
                end
            end
        end
    end
end
