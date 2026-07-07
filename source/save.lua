-- Persistence: last rest anemone + visited rooms, written to the "save"
-- datastore whenever the crab rests. Gates/molts/shards join in M3.

Save = {}

function Save.load()
    G.save = playdate.datastore.read("save") or {}
    G.save.visited = G.save.visited or {}
    G.save.molts = G.save.molts or {}
    G.save.bosses = G.save.bosses or {}
    G.save.gates = G.save.gates or {} -- broken gate cells: "ROOM:r,c"
    G.save.keys = G.save.keys or 0
    G.save.shards = G.save.shards or 0
    G.save.maxHearts = G.save.maxHearts or C.HEARTS
end

function Save.store()
    G.save.hearts = G.hearts
    playdate.datastore.write(G.save, "save")
    Harness.count("saves")
end
