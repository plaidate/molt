-- Small helpers + a deferred-call queue (used by Sfx arpeggios).

Util = {}

function Util.clamp(v, a, b)
    if v < a then return a elseif v > b then return b end
    return v
end

function Util.sign(v)
    if v > 0 then return 1 elseif v < 0 then return -1 end
    return 0
end

local pending = {}

function Util.after(t, fn)
    pending[#pending + 1] = { t = t, fn = fn }
end

function Util.runPending(dt)
    for i = #pending, 1, -1 do
        local p = pending[i]
        p.t = p.t - dt
        if p.t <= 0 then
            table.remove(pending, i)
            p.fn()
        end
    end
end
