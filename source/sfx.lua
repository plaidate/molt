-- All-synth audio, no assets: bounce blips pitched by surface, break
-- arpeggios pitched by row, miss thud, molt-back dirge, clear fanfare.

Sfx = {}

local snd = playdate.sound
local pad = snd.synth.new(snd.kWaveTriangle)
local wall = snd.synth.new(snd.kWaveTriangle)
local brickA = snd.synth.new(snd.kWaveSquare)
local brickB = snd.synth.new(snd.kWaveSquare)
local ui = snd.synth.new(snd.kWaveSquare)
local thud = snd.synth.new(snd.kWaveNoise)

function Sfx.paddle(off) -- off in [-1,1]: edge hits ring higher
    pad:playNote(170 + math.abs(off) * 80, 0.35, 0.07)
end

function Sfx.wall() wall:playNote(130, 0.25, 0.05) end
function Sfx.bedrock() wall:playNote(85, 0.3, 0.07) end
function Sfx.chip() brickA:playNote(311, 0.3, 0.05) end

function Sfx.brick(row) -- deeper rows crunch lower
    brickA:playNote(370 + (C.ROWS - row) * 18, 0.35, 0.05)
    Util.after(0.06, function() brickB:playNote(587, 0.3, 0.06) end)
end

function Sfx.serve() ui:playNote(523, 0.35, 0.07) end
function Sfx.miss() thud:playNote(70, 0.5, 0.35) end
function Sfx.whoosh() pad:playNote(98, 0.3, 0.18) end
function Sfx.stun() thud:playNote(180, 0.4, 0.12) end

function Sfx.boom()
    thud:playNote(50, 0.6, 0.4)
    Util.after(0.08, function() wall:playNote(65, 0.4, 0.2) end)
end

function Sfx.anemone()
    ui:playNote(659, 0.3, 0.1)
    Util.after(0.12, function() brickB:playNote(880, 0.25, 0.14) end)
end

function Sfx.moltback()
    for i, f in ipairs({ 392, 311, 247, 196 }) do
        Util.after((i - 1) * 0.16, function() ui:playNote(f, 0.35, 0.14) end)
    end
end

function Sfx.fanfare()
    for i, f in ipairs({ 392, 523, 659, 784 }) do
        Util.after((i - 1) * 0.11, function() ui:playNote(f, 0.35, 0.1) end)
    end
end
