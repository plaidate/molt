-- MOLT tunables (C) and live state (G). Fixed 30fps step.
-- Screen: 16px HUD strip, 25x12 grid of 16px cells (y 16..208), sand band
-- below where the crab scuttles. The carapace bounce line is PADDLE_Y.

C = {
    DT = 1 / 30,
    W = 400,
    H = 240,
    HUD_H = 16,

    CELL = 16,
    COLS = 25,
    ROWS = 12,
    FIELD_Y = 16,
    SAND_Y = 208,       -- grid bottom / open water ends

    PADDLE_Y = 214,     -- carapace crown: the bounce line
    CRAB_HW = 17,       -- carapace half-width
    CRAB_SPD = 175,
    BURROW_SPD = 5,     -- burrow ease in/out per second

    -- crank-as-paddle (modal: crank scuttles the crab while the pearl flies,
    -- aims while it is held). mvx from crank = crankChange summed over 5
    -- frames / CRANK_MOVE, so a brisk crank out-scuttles the d-pad.
    CRANK_MOVE = 60,       -- summed crank degrees per unit of scuttle
    CRANK_MVX_MAX = 2.4,   -- crank tops out at 2.4x d-pad speed
    CRANK_DEADZONE = 0.12, -- ignore crank drift below this scuttle fraction

    PEARL_R = 3,
    PEARL_SPD = 150,    -- zone 1 pace
    BOUNCE_MAX = 65,    -- max exit tilt (deg from vertical) off the carapace
    ENGLISH_MAX = 20,   -- crank english on a bounce
    TILT_CAP = 78,      -- absolute exit tilt cap (keeps a vertical component)
    SERVE_CAP = 70,     -- aim clamp while holding the pearl

    HEARTS = 3,
    MISS_LOCK = 0.7,    -- serve lockout after a miss
    MOLTBACK_T = 2.2,

    TRANSITION_T = 0.35, -- room slide
    ANEMONE_R = 22,      -- rest reach (px from the anemone)

    MAX_HEARTS = 6,
    SHARDS_PER_HEART = 4,
    HEAVY_FACTOR = 0.93, -- heavy pearl is a touch slower
    SNAP_REACH = 30,     -- pincer reach (px from crab centre)
    MOLT_T = 2.5,        -- ceremony length
    DARK_R = 55,         -- lightless sight radius (crab only)
    DARK_R_LANTERN = 95, -- with the lantern snail
    DARK_R_PEARL = 70,   -- pearl glow with the lantern
}

G = {}
