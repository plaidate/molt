-- Smoke-test harness (Bin Night pattern). The Makefile stages smokeflag.lua:
-- SMOKE_BUILD false for release (no-op), true for `make smoke` (pcall-wrapped
-- update writing errors to the "err" datastore, a 90-frame heartbeat to
-- "smoke", frame-stamped screenshots, and an autopilot Input consults).

import "smokeflag"

Harness = {
    enabled = SMOKE_BUILD,
    counters = {},
    autopilot = nil,
    extra = nil,
    shotPrefix = nil,
}

function Harness.count(key, n)
    if not Harness.enabled then return end
    Harness.counters[key] = (Harness.counters[key] or 0) + (n or 1)
end

function Harness.set(key, val)
    if not Harness.enabled then return end
    Harness.counters[key] = val
end

function Harness.frame(frame, updateFn)
    if not Harness.enabled then
        updateFn()
        return
    end
    local ok, err = pcall(updateFn)
    if not ok and not Harness.errWritten then
        Harness.errWritten = true -- keep the FIRST error; later frames repeat symptoms
        playdate.datastore.write({ err = tostring(err) }, "err")
    end
    if frame % 90 == 0 then
        local t = {}
        for k, v in pairs(Harness.counters) do t[k] = v end
        t.frame = frame
        if Harness.extra then pcall(Harness.extra, t) end
        playdate.datastore.write(t, "smoke")
    end
    if Harness.shotPrefix and playdate.simulator and (frame == 20 or frame % 300 == 0) then
        playdate.simulator.writeToFile(playdate.graphics.getDisplayImage(),
            string.format("%s%06d.png", Harness.shotPrefix, frame))
    end
end
