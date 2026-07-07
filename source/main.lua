-- MOLT - an arkanoidvania for Playdate.
-- Six zones, 28 rooms, seven bosses. Each boss yields a molt shrine:
-- Pincer Snap cuts kelp and super-shots the pearl, Sticky Claw catches,
-- Heavy Pearl shatters stone, the Lantern Snail lights the Abyss, Anchor
-- Legs defy the deep currents. Three temple keys unlock the glyph door.

import "CoreLibs/graphics"

import "config"
import "util"
import "harness"
import "sfx"
import "music"
import "fx"
import "save"
import "blocks"
import "roomdefs"
import "rooms"
import "items"
import "enemies"
import "bosses"
import "crab"
import "pearl"
import "hud"
import "worldmap"
import "input"
import "draw"

Game = {}

math.randomseed(playdate.getSecondsSinceEpoch())
playdate.display.setRefreshRate(SMOKE_BUILD and 0 or 30)
Harness.shotPrefix = "build/shots/molt-"
if Harness.enabled then
    Harness.autopilot = Input.autopilot
    Harness.set("phase", "pincer")
end

function Game.toast(msg)
    G.toast = msg
    G.toastT = 2
end

-- quieter hint (same toast slot, longer cooldown via G.hintT)
function Game.hint(msg)
    if (G.hintT or 0) > 0 then return end
    G.hintT = 3
    Game.toast(msg)
end

local MOLT_TEXT = {
    pincer = { "PINCER SNAP", "Ⓐ snap: cut kelp, strike the pearl" },
    sticky = { "STICKY CLAW", "hold Ⓑ to catch the pearl" },
    heavy = { "HEAVY PEARL", "stone shatters before you" },
    lantern = { "LANTERN SNAIL", "the dark recedes" },
    anchor = { "ANCHOR LEGS", "no current can move you" },
}

function Game.molt(name)
    G.moltName = name
    G.mode = "molt"
    G.t = 0
    Sfx.fanfare()
    Harness.count("molts")
end

local function snap()
    local cb = G.crab
    if cb.snapT > 0.05 or not G.save.molts.pincer then return end
    cb.snapT = 0.25
    Harness.count("snaps")
    Blocks.cutKelp(cb.x)
    Pearl.snapShot()
    Enemies.snapAt(cb.x)
    Sfx.wall()
end

Save.load()
G.maxHearts = G.save.maxHearts
G.hearts = G.maxHearts
G.flash = 0
G.toastT = 0
G.hintT = 0
Crab.reset()
local home = G.save.anemone or "T1"
Rooms.load(home)
if RoomDefs[home].anemone then
    G.crab.x = (RoomDefs[home].anemone - 1) * C.CELL + 8
    G.pearl.x = G.crab.x
end
G.mode = "title"
G.t = 0
Music.set("title")

playdate.getSystemMenu():addMenuItem("world map", function()
    if G.mode == "play" then G.mode = "map" end
end)
playdate.getSystemMenu():addCheckmarkMenuItem("music", true, function()
    Music.toggle()
end)

local function tick()
    local dt = C.DT
    G.t = G.t + dt
    G.flash = math.max(0, G.flash - dt)
    G.toastT = math.max(0, G.toastT - dt)
    G.hintT = math.max(0, (G.hintT or 0) - dt)
    Util.runPending(dt)
    Fx.update(dt)
    Music.update(dt)

    if G.mode == "title" then
        Draw.title()
        if Input.confirm() then
            G.mode = "play"
            G.t = 0
            Sfx.serve()
            Music.set(Rooms.music())
        end
    elseif G.mode == "play" then
        local inp = Input.gather()
        Crab.update(dt, inp)
        Rooms.checkExits(inp)
        if G.mode == "transition" then
            Draw.transition()
        else
            if (inp.serve and not G.pearl.held) or inp.snapReq then
                snap()
            end
            Enemies.update(dt)
            Bosses.update(dt)
            Pearl.update(dt, inp)
            if G.mode == "play" then
                Items.update(dt)
                Rooms.anemoneCheck()
            end
            if G.mode == "play" then
                Rooms.clearCheck()
                if inp.map then
                    G.mode = "map"
                    Sfx.chip()
                end
            end
            if G.mode == "map" then
                WorldMap.draw()
            elseif G.mode == "molt" then
                Draw.moltCeremony()
            elseif G.mode == "victory" then
                Draw.victory()
            else
                Draw.play()
            end
        end
    elseif G.mode == "transition" then
        local tr = G.transition
        tr.t = tr.t + dt
        if tr.t >= C.TRANSITION_T then
            G.transition = nil
            G.mode = "play"
            Draw.play()
        else
            Draw.transition()
        end
    elseif G.mode == "map" then
        local inp = Input.gather()
        if inp.map then
            G.mode = "play"
            Sfx.chip()
        end
        WorldMap.draw()
    elseif G.mode == "molt" then
        -- shell fragments fly as the old carapace splits
        if math.floor(G.t / 0.4) ~= math.floor((G.t - dt) / 0.4) then
            Fx.burst(G.crab.x, 214, 7)
            Sfx.chip()
        end
        Draw.moltCeremony()
        if G.t > C.MOLT_T then
            G.save.molts[G.moltName] = true
            Save.store()
            G.mode = "play"
            local txt = MOLT_TEXT[G.moltName]
            Game.toast(txt and txt[2] or "")
        end
    elseif G.mode == "victory" then
        Music.set("title")
        Draw.victory()
        if G.t > 2 and Input.confirm() then
            G.mode = "play"
            G.t = 0
            Music.set(Rooms.music())
        end
    elseif G.mode == "moltback" then
        Draw.moltback()
        if G.t > C.MOLTBACK_T then
            G.hearts = G.maxHearts
            local back = G.save.anemone or "T1"
            Rooms.load(back)
            local def = RoomDefs[back]
            if def.anemone then
                G.crab.x = (def.anemone - 1) * C.CELL + 8
                G.pearl.x = G.crab.x
            end
            Harness.set("respawnRoom", back)
        end
    end
end

Game.MOLT_TEXT = MOLT_TEXT

Harness.extra = function(t)
    t.mode = G.mode
    t.room = G.room
    t.hearts = G.hearts .. "/" .. G.maxHearts
    t.blocksLeft = Blocks.remaining()
    t.crabX = math.floor(G.crab.x)
    local p = G.pearl
    t.pearl = p.held and "held" or (math.floor(p.x) .. "," .. math.floor(p.y))
    local n = 0
    for _ in pairs(G.save.visited) do n = n + 1 end
    t.visited = n
    t.anemone = G.save.anemone or "-"
    local m = G.save.molts
    t.molts = (m.pincer and "P" or "") .. (m.sticky and "S" or "")
        .. (m.heavy and "H" or "") .. (m.lantern and "L" or "")
        .. (m.anchor and "A" or "")
    t.keys = G.save.keys
    t.shards = G.save.shards
    t.updMs = math.floor((G.updMs or 0) * 10) / 10
end

local frame = 0
function playdate.update()
    frame = frame + 1
    local t0 = playdate.getCurrentTimeMilliseconds()
    Harness.frame(frame, tick)
    local ms = playdate.getCurrentTimeMilliseconds() - t0
    G.updMs = (G.updMs or 0) * 0.9 + ms * 0.1
end
