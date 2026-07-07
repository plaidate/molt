-- Particle bursts: block shatter, pearl cracking on the vents.

Fx = {}

local ps = {}

function Fx.reset() ps = {} end

function Fx.burst(x, y, n)
    for _ = 1, n or 5 do
        local a = math.random() * 6.283
        local s = 30 + math.random() * 70
        ps[#ps + 1] = {
            x = x, y = y,
            vx = math.cos(a) * s, vy = math.sin(a) * s - 20,
            t = 0.35 + math.random() * 0.2,
        }
    end
end

function Fx.update(dt)
    for i = #ps, 1, -1 do
        local p = ps[i]
        p.t = p.t - dt
        if p.t <= 0 then
            table.remove(ps, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + 90 * dt
        end
    end
end

function Fx.draw()
    local gfx = playdate.graphics
    gfx.setColor(gfx.kColorWhite)
    for _, p in ipairs(ps) do
        gfx.fillRect(p.x - 1, p.y - 1, 2, 2)
    end
end
