# Molt — an arkanoidvania

*Design doc, written 2026-07-05, before any code (Bin Night convention).*

## Pitch

You are a small crab on the sea bed. Your carapace is the paddle. You
bounce a pearl to smash coral, kelp, stone and shipwreck blocks, fighting
sea creatures — real and mythical — across a connected undersea world.
Every boss you defeat lets you **molt**: you shed your shell and grow a
new ability that opens previously impassable rooms. Arkanoid moment to
moment; Metroid in structure.

References: *The Trial of Kharzoid* (screen-by-screen paddle exploration,
keys and gates), *Mega Kaiju Boom Ball* (character-as-paddle with
personality), Wonder Boy III (curse/transformation progression tone).

Crabs move sideways. That is the whole joke and the whole design: the
player character IS a paddle, fictionally, not abstractly.

- Directory: `molt/` (standalone, like peckish/binnight)
- Bundle ID: `com.sdwfrost.molt`
- Original game, 1-bit art, all-synth audio. Local until told otherwise.

## Screen layout

400x240, 1-bit, 30fps fixed DT = 1/30.

- Top 16px: HUD strip — shell hearts, zone name, pearl state, mini-compass.
- Middle 196px: block field, 25 cols x 12 rows of 16x16 cells (192px used).
- Bottom 28px: sand floor band where the crab scuttles.

Rooms are one screen each (no scrolling — Kharzoid model). Exits are
gaps: walk off left/right edges, ride bubble vents up through ceiling
gaps, sink through floor gaps. Room transitions are a quick slide.

## Controls

- **d-pad ←/→**: scuttle. Crab is fast — this is the paddle.
- **d-pad ↓**: burrow into sand (dodge enemy shots; the pearl passes
  overhead — deliberate "let it through" play).
- **A**: serve the pearl / **Pincer Snap** (after molt 1): a short melee
  snap that super-shots the ball if timed on contact, and cuts kelp.
- **B**: catch (after molt 2, Sticky Claw) — pearl sticks to claw.
- **Crank**: aim. While holding the pearl (serve or sticky-catch) the
  crank sets launch angle, drawn as a dotted aim line. On a normal bounce,
  cranking during contact applies english (bends the exit angle up to
  ±20°). Docked crank = fixed 60° serves, no english — game stays fully
  playable docked.
- **Menu**: map screen (explored rooms grid), save-and-quit.

Bounce rule: exit angle depends on where the pearl hits the carapace
(edge hits = shallow angles), Arkanoid-classic, then english on top.

## The pearl

- One pearl, speed fixed per zone (ramps zone 1 → 6), angle-only physics,
  AABB vs the 25x12 grid + paddle + enemies.
- The pearl only exists while "in play". Walking out of a room despawns
  it; serving is free and instant. No ball babysitting between rooms.
- **Missing the pearl costs 1 shell heart** (it cracks on the vents under
  the sand), then respawns held. No lives, no game over screen mid-world.
- At 0 hearts you "molt back": respawn at the last **rest anemone**
  (checkpoint/save point), keeping all upgrades and map. Non-gate blocks
  in the current room reset.

## Blocks

| Type | Breaks with | Notes |
| --- | --- | --- |
| Coral | any hit | 1-hit, the standard brick |
| Brain coral | 2 hits | shows crack state |
| Kelp curtain | Pincer Snap only | blocks crab, not pearl |
| Stone / hull iron | Heavy Pearl molt | zone gates |
| Barnacle cluster | 3 hits | regrown by starfish enemies |
| Glyph block | any hit, but only after its temple key | 3 in the world |
| Bedrock | never | level geometry |
| Bubble block | touch | releases a lift bubble (vertical exits) |

Gate blocks (stone seals, glyph blocks, kelp curtains) stay broken
forever — saved to datastore. Decorative field blocks reset on room
entry so every room stays playable/farmable.

Drops (from marked blocks): shell shards (4 = +1 max heart), map
tablets (reveal zone map), temple keys (see below).

## World

~26 rooms, 6 zones, one connected map. Sketch (rooms as cells):

```
                      [K3]--[K4]--[K5 KELPIE]
                        |
  [T1 start]--[T2]--[T3]--[K1]--[K2]
                 |                |
        [T4 HERMIT]      [R1]--[R2]--[R3]--[R4 SIREN]
                                 |            |
                               [R5]--[R6]   [S1]--[S2]--[S3 UMIBOZU]
                                 |                  |
                    [A1]--[A2]--[A3]              [S4]--[S5]
                      |           |
                    [A4]--[A5 CHARYBDIS]
                              |
                    [M1]--[M2 HIPPOCAMPUS]--[M3 KRAKEN]
```

1. **TIDEPOOLS** (T1–T4, 4 rooms) — tutorial. Shallow, bright, simple
   coral fields. Boss: **The Old Hermit** — a giant hermit crab living in
   a bottle; you must break his bottle-shell (block cluster) to hit him.
   Molt reward: **Pincer Snap**.
2. **KELP FOREST** (K1–K5) — kelp curtains carve the rooms into channels;
   currents push the pearl sideways (per-room drift vector). Boss:
   **The Kelpie** — mythical water-horse woven from kelp, gallops along
   the ceiling, drops kelp curtains mid-fight. Molt: **Sticky Claw**
   (catch + crank-aim).
3. **CORAL REEF** (R1–R6) — dense brick-heavy rooms, starfish repair
   crews, urchin-lined floors that shrink your safe scuttling zone.
   Boss: **The Siren** — her song *charms the pearl*, curving its flight
   toward her barrier of brain coral; fight rhythm is breaking the choir
   coral that amplifies her. Molt: **Heavy Pearl** (breaks stone/iron,
   slightly slower ball).
4. **SHIPWRECK** (S1–S5) — a sunken galleon; iron hull blocks, powder
   kegs (chain explosions), moray eels in portholes that swallow the
   pearl (snap them to get it back). Boss: **Umibōzu** — the huge black
   sea-spirit head rising behind the wreck, only its eyes are
   vulnerable, it dims the water as it attacks. Molt: **Lantern Snail**
   (a glowing snail rides your shell — lights dark rooms in a radius
   around you and the pearl).
5. **ABYSS** (A1–A5) — pitch dark without the Lantern Snail (rooms render
   only near crab/pearl — strong 1-bit look). Ghost fish visible only in
   light; crush-current rooms. Boss: **Charybdis** — a whirlpool that
   swallows and re-spits the pearl at random angles; feed it powder kegs
   knocked from above. Molt: **Anchor Legs** (walk against currents,
   immune to knockback; opens the temple descent).
6. **SUNKEN TEMPLE** (M1–M3) — mythic endgame. Entry needs all **3 temple
   keys** hidden in optional backtrack rooms (T-zone stone alcove, K-zone
   dark grotto, S-zone keg vault — each requires a later ability, forcing
   Metroid-style return trips). Mini-boss: **Hippocampus** — a seahorse
   knight who jousts along the floor, contesting your paddle lane. Final
   boss: **The Kraken** — tentacles rise from floor gaps and act as rival
   paddles, batting your pearl back and smashing blocks you need; bounce
   the pearl into the eye between tentacle waves; three phases, arena
   degrades.

Rest anemones: one per zone (T3, K2, R5, S4, A3, M1). Interact to save +
heal full.

## Enemies (field)

| Enemy | Zone | Behaviour |
| --- | --- | --- |
| Jellyfish | all | slow drift; stuns crab 1s on touch; pearl kills |
| Pufferfish | K, R | inflates when pearl nears — random hard deflect |
| Starfish | R | crawls the field repairing barnacle/coral blocks |
| Urchin | R, A | floor hazard; burrow-proof; shrinks paddle lane |
| Barnacle turret | S | spits pellets at the crab (burrow to dodge) |
| Moray eel | S | swallows pearl from porthole; snap its nose |
| Ghost fish | A | only visible in lantern light; fast ram |
| Sprat swarm | T, K | harmless block-like shoal — free bounces, breaks apart |

Enemies are pearl-vulnerable (most die in 1 hit) and respawn on room
re-entry. They exist to bend pearl trajectories and contest floor space,
not to be a separate combat game.

## Molt sequence (the metroidvania spine)

1. **Pincer Snap** — melee super-shot + cuts kelp → opens Kelp Forest.
2. **Sticky Claw** — catch & crank-aim → makes Reef's precision shots
   possible (progression there is layout-gated on aimed serves).
3. **Heavy Pearl** — breaks stone/iron → opens Shipwreck (and T-zone key
   alcove backtrack).
4. **Lantern Snail** — light → makes the Abyss playable (and K-zone
   grotto key).
5. **Anchor Legs** — current immunity → temple descent (and lets you
   shove powder kegs, S-zone key vault).
6. Shell shards throughout: 3 hearts → up to 6.

Each molt is a short ceremony: shell cracks open, soft crab scurries,
new shell forms — one image sequence, big narrative beat, no gameplay.

## Art & audio

- 1-bit, white-on-black underwater (like Bin Night's night palette):
  black water, white outlined creatures, dithered light pools/god rays.
  Zone identity via block texture + backdrop motif (kelp verticals,
  ship ribs, temple columns).
- Crab: chunky 32x20 sprite, expressive eyestalks, distinct silhouettes
  per molt (each new shell visibly different — progression you can see).
- All-synth audio (no assets): bounce = short square blips pitched by
  block type; zone music = clock-driven step-sequencer loops
  (weaselwardance technique, zero drift), one motif per zone, boss
  variants; molt fanfare.

## Save format

`playdate.datastore.write` to `com.sdwfrost.molt`:
`{ molts={}, hearts, maxHearts, shards, keys={}, gatesBroken={"K1:12,4",...},
roomsVisited={}, anemone="R5", mapTablets={} }`. Autosave at anemones and
on molt; delete test saves after smoke runs.

## Code layout (multi-file global-namespace convention)

```
molt/
  source/
    main.lua        -- entry, update loop, pcall smoke wrapper
    config.lua      -- Config: speeds, sizes, smoke-tunables (X = SMOKE_BUILD and a or b)
    gamestate.lua   -- State: mode machine (title/play/molt/map/boss/gameover)
    crab.lua        -- Crab: movement, burrow, snap, catch, molt visuals
    pearl.lua       -- Pearl: physics, grid sweep, english, charm/whirlpool forces
    blocks.lua      -- Blocks: grid, types, damage, drops, persistent gates
    rooms.lua       -- Rooms: loader, transitions, current/darkness per room
    roomdefs.lua    -- data: 26 rooms as string grids + exits + spawns
    enemies.lua     -- Enemies: the 8 field types
    bosses.lua      -- Bosses: 7 fights (6 zone + hippocampus)
    upgrades.lua    -- Molts: ability flags, gating checks, ceremonies
    worldmap.lua    -- Map screen + visited tracking
    hud.lua         -- HUD strip
    draw.lua        -- Draw: layers, darkness mask, dither pools
    sfx.lua         -- Sfx + step-sequencer music
    save.lua        -- Save: datastore round-trip
    input.lua       -- Input: real input + AUTOPILOT harness
    pdxinfo         -- com.sdwfrost.molt
  Makefile          -- build, smoke (stages smokeflag.lua), clean
  tools/smoke.sh    -- headless run + heartbeat until-grep + screenshots
  DESIGN.md, README.md, screenshot.png
```

Room data: string grids, one char per cell (`.` empty, `c` coral, `B`
brain, `k` kelp, `S` stone, `g` glyph, `#` bedrock, `o` bubble, `*`
drop-marked), plus `exits={L=,R=,U=,D=}`, `spawn list`, `current`,
`dark`, `music`.

## Autopilot & smoke plan (designed in from day one)

- **Predictive intercept**: simulate the pearl forward to the paddle line
  each frame, walk there. This is also the "perfect player" — tune
  difficulty against it.
- Errand list (ordered, counter-gated, Bin Night style): serve → clear a
  room → traverse each exit type → miss deliberately (death path) →
  molt-back respawn → boss script per boss (each boss gets a scripted
  win) → acquire each molt → use each molt's gate → collect keys →
  beat Kraken → verify save/reload.
- need(kind) summoning n/a (single character) but keep scripted-blunder
  DEADLINES: every errand gets a playT window so a stuck errand can't
  eat the run.
- Heartbeat every 90 frames: bounces, blocksBroken, roomsVisited, deaths,
  heartsLost, molts, bossHP, keys, updMs/drwMs. Count EVERYTHING.
- Screenshots frame 20 + every 300 frames via simulator.writeToFile;
  LOOK at them (darkness mask and HUD collisions won't show in counters).
- refreshRate(0) in smoke builds; pkill sim first; delete datastore after.

## Milestones (each ends with a green smoke run)

1. **M1 Paddle core**: one room, crab + pearl + coral grid, bounce feel,
   english, serve/miss/heart loop. *The game must already be fun here.*
2. **M2 World shell**: room graph, transitions, exits, map screen,
   anemone save/load, roomdefs for zones T+K.
3. **M3 Molts & gates**: all 6 abilities, gate blocks, persistent
   breakage, backtrack key rooms; zones R+S+A+M roomdefs.
4. **M4 Creatures**: 8 field enemies + currents + darkness.
5. **M5 Bosses**: 7 fights + molt ceremonies + Kraken finale.
6. **M6 Polish**: music per zone, HUD, title, README/screenshots, full
   autopilot coverage checklist clean.

## Open decisions (defaults chosen, flag to change)

1. **Title**: *Molt* (alt: *Carapace*, *Pinch & Pearl*, *Scuttlevania*).
2. **Miss penalty**: 1 heart per drop (default) vs Kharzoid-style lives.
3. **Scope**: 26 rooms/6 zones (default) vs trimmed 16 rooms/4 zones
   (fold Reef into Kelp, Abyss into Temple) if build time matters.
4. **Crank english** ±20° on bounce: in (default) or aim-only crank.
