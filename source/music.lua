-- Zone music: a clock-driven step sequencer (accumulate dt, fire steps
-- on beat boundaries — zero drift). One 16-step motif per zone, a driving
-- boss variant, a calm title loop. All synth, mixed quiet under the sfx.

Music = {}

local snd = playdate.sound
local bass = snd.synth.new(snd.kWaveTriangle)
local lead = snd.synth.new(snd.kWaveSquare)
local pad = snd.synth.new(snd.kWaveSine)

local function f(n) -- midi -> Hz
    return 440 * 2 ^ ((n - 69) / 12)
end

-- 16 steps each; 0 = rest. bass/lead midi notes, optional pad drone.
local TRACKS = {
    T = { bpm = 104, drone = 36,
        bass = { 48, 0, 43, 0, 45, 0, 43, 0, 48, 0, 43, 0, 41, 0, 43, 0 },
        lead = { 72, 0, 76, 0, 79, 0, 76, 0, 74, 0, 79, 0, 81, 79, 76, 0 } },
    K = { bpm = 96, drone = 33,
        bass = { 45, 0, 0, 40, 0, 0, 43, 0, 45, 0, 0, 40, 0, 0, 38, 0 },
        lead = { 69, 0, 72, 0, 76, 0, 0, 72, 0, 71, 0, 69, 0, 64, 0, 0 } },
    R = { bpm = 118, drone = 38,
        bass = { 38, 0, 38, 45, 0, 38, 0, 45, 38, 0, 38, 45, 0, 41, 0, 43 },
        lead = { 62, 65, 0, 69, 0, 65, 62, 0, 60, 0, 62, 0, 65, 0, 67, 0 } },
    S = { bpm = 84, drone = 28,
        bass = { 40, 0, 0, 0, 47, 0, 0, 0, 40, 0, 0, 0, 35, 0, 0, 0 },
        lead = { 0, 0, 64, 0, 0, 0, 0, 67, 0, 0, 0, 64, 0, 0, 59, 0 } },
    A = { bpm = 66, drone = 26,
        bass = { 33, 0, 0, 0, 0, 0, 0, 0, 31, 0, 0, 0, 0, 0, 0, 0 },
        lead = { 0, 0, 0, 0, 57, 0, 0, 0, 0, 0, 0, 0, 0, 0, 56, 0 } },
    M = { bpm = 88, drone = 28,
        bass = { 40, 0, 41, 0, 40, 0, 36, 0, 40, 0, 41, 0, 43, 0, 41, 0 },
        lead = { 64, 0, 65, 64, 0, 60, 0, 0, 64, 0, 67, 65, 0, 64, 0, 0 } },
    boss = { bpm = 148, drone = 31,
        bass = { 38, 38, 45, 38, 41, 38, 45, 38, 36, 36, 43, 36, 41, 36, 46, 36 },
        lead = { 62, 0, 65, 69, 0, 62, 74, 0, 60, 0, 65, 67, 0, 72, 0, 65 } },
    title = { bpm = 72, drone = 36,
        bass = { 48, 0, 0, 0, 43, 0, 0, 0, 45, 0, 0, 0, 43, 0, 0, 0 },
        lead = { 0, 0, 72, 0, 0, 0, 76, 0, 0, 0, 79, 0, 0, 76, 0, 0 } },
}

local cur, curName
local clock, stepI = 0, 0
Music.on = true

function Music.set(name)
    if name == curName then return end
    curName = name
    cur = TRACKS[name]
    clock, stepI = 0, 0
end

function Music.toggle()
    Music.on = not Music.on
end

function Music.update(dt)
    if not cur or not Music.on then return end
    local stepDur = 60 / cur.bpm / 4 -- sixteenth notes
    clock = clock + dt
    while clock >= stepDur do
        clock = clock - stepDur
        stepI = stepI % 16 + 1
        local b = cur.bass[stepI]
        if b and b ~= 0 then
            bass:playNote(f(b), 0.13, stepDur * 1.8)
        end
        local l = cur.lead[stepI]
        if l and l ~= 0 then
            lead:playNote(f(l), 0.07, stepDur * 0.9)
        end
        if stepI == 1 then
            if cur.drone then
                pad:playNote(f(cur.drone), 0.05, stepDur * 16)
            end
            Harness.count("musicBars")
        end
    end
end
