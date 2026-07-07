-- The 25x12 block grid: types, damage, pearl collision queries, gates.
-- Roomdef chars: c coral(1), B brain(2), * shard coral(1, drops a shard),
-- # bedrock (never breaks), S stone (2, Heavy Pearl only), k kelp curtain
-- (pearl passes through; Pincer Snap cuts; blocks the crab in row 12),
-- g glyph (1, needs all 3 temple keys), ! temple key block (1).
-- Gate cells (k/S/g/!) stay broken forever via G.save.gates["ROOM:r,c"].

Blocks = {}

local HP = { c = 1, B = 2, ["*"] = 1, ["#"] = 99, S = 2, k = 1, g = 1, ["!"] = 1, O = 1 }
local GATE = { S = true, k = true, g = true, ["!"] = true }
local BLASTABLE = { c = true, B = true, ["*"] = true, S = true, O = true }

function Blocks.load(def)
    G.grid = {}
    local n = 0
    if #def.grid ~= C.ROWS then
        error(def.name .. " grid has " .. #def.grid .. " rows, wants " .. C.ROWS)
    end
    for r = 1, C.ROWS do
        G.grid[r] = {}
        local row = def.grid[r]
        if #row ~= C.COLS then
            error(def.name .. " row " .. r .. " has " .. #row .. " cols, wants " .. C.COLS)
        end
        for c = 1, C.COLS do
            local ch = row:sub(c, c)
            if HP[ch] and not (GATE[ch] and G.save.gates[G.room .. ":" .. r .. "," .. c]) then
                G.grid[r][c] = { t = ch, hp = HP[ch] }
                if ch ~= "#" then n = n + 1 end
            end
        end
    end
    G.blocksLeft = n
end

function Blocks.remaining()
    return G.blocksLeft or 0
end

-- solid cell for the PEARL at pixel (px,py), or nil. Kelp is water to it.
function Blocks.at(px, py)
    if py < C.FIELD_Y or py >= C.SAND_Y then return nil end
    local c = math.floor(px / C.CELL) + 1
    local r = math.floor((py - C.FIELD_Y) / C.CELL) + 1
    if c < 1 or c > C.COLS or r < 1 or r > C.ROWS then return nil end
    local cell = G.grid[r][c]
    if cell and cell.t ~= "k" then return r, c end
    return nil
end

-- does a crab-blocking column (kelp/glyph in the bottom row) sit at pixel x?
function Blocks.crabBlockedAt(x)
    local c = math.floor(x / C.CELL) + 1
    if c < 1 or c > C.COLS then return false end
    local cell = G.grid[C.ROWS][c]
    return cell ~= nil and (cell.t == "k" or cell.t == "g")
end

-- any gate block in the bottom row over these columns? (seals vents/gaps)
function Blocks.gateInCols(cols)
    for c = cols[1], cols[2] do
        local cell = G.grid[C.ROWS][c]
        if cell and GATE[cell.t] then return true end
    end
    return false
end

local function remove(r, c, cell)
    G.grid[r][c] = nil
    G.blocksLeft = G.blocksLeft - 1
    if GATE[cell.t] and not cell.temp then -- boss-dropped kelp isn't a gate
        G.save.gates[G.room .. ":" .. r .. "," .. c] = true
        Save.store()
    end
    Fx.burst((c - 1) * C.CELL + 8, C.FIELD_Y + (r - 1) * C.CELL + 8, 6)
end

-- pincer snap cutting kelp (bottom two rows within reach)
function Blocks.cutKelp(cx)
    local cut = 0
    for r = C.ROWS - 1, C.ROWS do
        for c = 1, C.COLS do
            local cell = G.grid[r][c]
            if cell and cell.t == "k"
                and math.abs((c - 1) * C.CELL + 8 - cx) <= C.SNAP_REACH then
                remove(r, c, cell)
                cut = cut + 1
            end
        end
    end
    if cut > 0 then
        Sfx.brick(C.ROWS)
        Harness.count("kelpCut", cut)
    end
    return cut
end

-- a powder keg goes up: 3x3 blast, kegs chain with a beat between
function Blocks.explode(r, c)
    local cell = G.grid[r][c]
    if not cell or cell.t ~= "O" then return end
    remove(r, c, cell)
    Fx.burst((c - 1) * C.CELL + 8, C.FIELD_Y + (r - 1) * C.CELL + 8, 14)
    Sfx.boom()
    Harness.count("kegBlasts")
    if Bosses and Bosses.onBlast then
        Bosses.onBlast((c - 1) * C.CELL + 8, C.FIELD_Y + (r - 1) * C.CELL + 8)
    end
    for dr = -1, 1 do
        for dc = -1, 1 do
            local rr, cc = r + dr, c + dc
            if rr >= 1 and rr <= C.ROWS and cc >= 1 and cc <= C.COLS then
                local n = G.grid[rr][cc]
                if n then
                    if n.t == "O" then
                        Util.after(0.15, function() Blocks.explode(rr, cc) end)
                    elseif BLASTABLE[n.t] then
                        remove(rr, cc, n)
                        Harness.count("blasted")
                    end
                end
            end
        end
    end
end

function Blocks.hit(r, c)
    local cell = G.grid[r][c]
    if not cell then return end
    local t = cell.t
    if t == "O" then
        Blocks.explode(r, c)
        return
    end
    if t == "#" then
        Sfx.bedrock()
        Harness.count("bedrockHits")
        return
    end
    if t == "S" and not G.save.molts.heavy then
        Sfx.bedrock()
        Harness.count("stoneClanks")
        Game.hint("TOO HARD - the pearl skips off")
        return
    end
    if t == "g" and G.save.keys < 3 then
        Sfx.bedrock()
        Harness.count("glyphClanks")
        Game.hint("THE GLYPHS HOLD FAST (" .. G.save.keys .. "/3 keys)")
        return
    end
    cell.hp = cell.hp - 1
    if cell.hp > 0 then
        Sfx.chip()
        Harness.count("chips")
        return
    end
    remove(r, c, cell)
    Sfx.brick(r)
    if t == "!" then
        G.save.keys = G.save.keys + 1
        Save.store()
        Sfx.fanfare()
        Game.toast("A TEMPLE KEY (" .. G.save.keys .. "/3)")
        Harness.count("keysGot")
    elseif t == "*" then
        Items.dropShard((c - 1) * C.CELL + 8, C.FIELD_Y + (r - 1) * C.CELL + 8)
        Harness.count("blocksBroken")
    else
        Harness.count("blocksBroken")
    end
end
