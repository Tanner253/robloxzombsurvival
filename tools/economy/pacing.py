"""Expected-value pacing model for docs/ECONOMY.md (free player, 2 x 75 min sessions a day).

Minute ticks. Stations are LDoE converters: one input slot (slotCap items), one output slot
(slotCap items), one fuel slot (slotCap items); a batch converts when inputs and fuel allow.
The player refills stations at every home visit during a session; between sessions the
stations run on whatever was loaded at the last visit.
"""
import math, sys, json, copy

P = dict(  # tunables (overridden from argv JSON)
    sessions=[(8 * 60, 75), (19 * 60, 75)],
    home_minutes=3,
    bag_slots=5,          # satchel from the hook
    reserved_slots=3,     # tools, meds, food
    stack=20,
    run_cap_min=14,
    hoard=0.02,
    energy_min=0.5,
    contested=0.6,
    xp_w=0.002,
    xp_w_gated=0.02,
)

# ---------------------------------------------------------------- items / stack sizes
STACK = {"scrap": 50}

# ---------------------------------------------------------------- nodes
# id: (tool kind, tool tier, hits, yields{item: units per yield}, yieldEvery, overhead s)
NODES = {
    "pine":      ("hatchet", 1, 3, {"timber": 1}, 1, 4.0),
    "ironbark":  ("hatchet", 2, 4, {"ironbark_log": 1}, 2, 4.5),
    "boulder":   ("pick", 1, 3, {"stone": 1}, 1, 4.0),
    "ironstone": ("pick", 1, 3, {"ironstone": 1}, 1, 4.0),
    "malachite": ("pick", 2, 6, {"malachite": 1}, 3, 4.5),
    "scrapheap": ("pick", 1, 4, {"scrap": 2}, 1, 4.0),
    "fatwood":   ("hatchet", 1, 3, {"fatwood": 1, "timber": 0.3}, 1, 4.0),
    "niter":     ("pick", 1, 3, {"niter": 1}, 1, 4.0),
    "branches":  (None, 0, 1, {"sticks": 2}, 1, 2.5),
    "stones":    (None, 0, 1, {"stone": 2}, 1, 2.5),
    "reeds":     (None, 0, 1, {"fiber": 2}, 1, 2.5),
    "bush":      (None, 0, 1, {"berry": 3}, 1, 2.5),
    "ashroot":   (None, 0, 2, {"ashroot": 1}, 1, 2.5),
    "pool":      (None, 0, 3, {"murky": 1}, 1, 2.5),
}

# ---------------------------------------------------------------- loot (EV per open)
def tbl(rolls, entries, guaranteed=None):
    return dict(rolls=rolls, entries=entries, guaranteed=guaranteed or {})

JUNK = tbl((1, 1), [("lantern", 45, 1, 1), ("wire_junk", 40, 1, 1), ("motor", 15, 1, 1)])
LOOT = {
    "zone_pack_t1": tbl((1, 3), [("tin", 10, 1, 1), ("water", 8, 1, 1), ("murky", 12, 1, 2), ("cloth", 14, 1, 2),
                                  ("cord", 12, 1, 2), ("dressing", 8, 1, 1), ("glue", 5, 1, 1), ("scrap", 5, 2, 4),
                                  ("wire_junk", 3, 1, 1), ("spring", 2, 1, 1)]),
    "zone_pack_t2": tbl((2, 3), [("tin", 10, 1, 2), ("water", 8, 1, 2), ("dressing", 12, 1, 2), ("cloth", 12, 2, 3),
                                  ("cord", 10, 2, 3), ("glue", 8, 1, 2), ("scrap", 8, 3, 6), ("iron_ingot", 6, 1, 2),
                                  ("spring", 4, 1, 1), ("wire_junk", 4, 1, 1), ("motor", 2, 1, 1), ("tonic", 2, 1, 1)]),
    "zone_pack_t3": tbl((2, 4), [("dressing", 14, 2, 3), ("stew", 10, 1, 1), ("tin", 8, 2, 2), ("water", 6, 2, 2),
                                  ("glue", 10, 1, 2), ("iron_ingot", 10, 2, 3), ("plate", 8, 1, 2), ("rivets", 8, 2, 4),
                                  ("spring", 8, 1, 2), ("tonic", 4, 1, 1), ("gear", 3, 1, 1), ("pipe", 3, 1, 1)]),
    "forest_crate_t1": tbl((2, 3), [("timber", 24, 3, 6), ("sticks", 18, 4, 8), ("plank", 14, 2, 3), ("cord", 14, 1, 2),
                                     ("fatwood", 12, 2, 3), ("glue", 8, 1, 1), ("stone_hatchet", 6, 1, 1), ("lantern", 4, 1, 1)]),
    "forest_crate_t2": tbl((2, 3), [("timber", 18, 5, 8), ("plank", 18, 3, 5), ("fatwood", 14, 3, 4), ("ironbark_log", 12, 2, 4),
                                     ("glue", 10, 1, 2), ("cord", 10, 2, 3), ("rivets", 8, 1, 2), ("coal", 6, 2, 4),
                                     ("forged_hatchet", 2, 1, 1), ("spring", 2, 1, 1)]),
    "forest_crate_t3": tbl((3, 4), [("plank", 16, 4, 6), ("ironbark_log", 16, 3, 6), ("ironbark_plank", 8, 1, 2),
                                     ("fatwood", 12, 4, 6), ("coal", 10, 3, 5), ("glue", 10, 2, 2), ("rivets", 10, 2, 4),
                                     ("spring", 6, 1, 1), ("forged_hatchet", 4, 1, 1), ("gear", 3, 1, 1),
                                     ("bp_pack_frame", 2, 1, 1), ("motor", 3, 1, 1)]),
    "mine_box_t1": tbl((2, 3), [("stone", 20, 4, 8), ("ironstone", 18, 2, 4), ("scrap", 18, 3, 6), ("cord", 10, 1, 2),
                                 ("glue", 6, 1, 1), ("stone_pick", 6, 1, 1), ("iron_ingot", 6, 1, 1), ("JUNK", 10, 1, 1),
                                 ("rivets", 4, 1, 2), ("spring", 2, 1, 1)]),
    "mine_box_t2": tbl((2, 3), [("ironstone", 18, 4, 6), ("scrap", 14, 5, 8), ("iron_ingot", 14, 1, 3), ("malachite", 10, 2, 3),
                                 ("block", 10, 2, 3), ("rivets", 10, 2, 3), ("JUNK", 10, 1, 1), ("spring", 6, 1, 1),
                                 ("forged_pick", 3, 1, 1), ("copper_ingot", 3, 1, 1), ("niter", 2, 1, 2),
                                 ("gear", 2, 1, 1)]),
    "mine_box_t3": tbl((3, 4), [("iron_ingot", 16, 2, 4), ("malachite", 12, 3, 5), ("plate", 12, 2, 3), ("block", 10, 3, 5),
                                 ("rivets", 10, 3, 5), ("copper_ingot", 8, 1, 2), ("copper_wire", 6, 2, 3), ("spring", 8, 1, 2),
                                 ("gear", 4, 1, 1), ("forged_pick", 4, 1, 1), ("JUNK", 8, 1, 1), ("powder", 2, 1, 2)]),
    # POIs (existing tables, with ECONOMY.md deltas)
    "pine_pack": tbl((1, 3), [("tin", 10, 1, 1), ("cord", 20, 1, 3), ("murky", 15, 1, 2), ("cloth", 15, 1, 2), ("water", 6, 1, 1),
                               ("lantern", 10, 1, 1), ("dressing", 8, 1, 1), ("wire_junk", 8, 1, 1), ("spring", 4, 1, 1),
                               ("club", 2, 1, 1)]),
    "pine_crate": tbl((2, 3), [("timber", 20, 3, 6), ("sticks", 15, 4, 8), ("plank", 20, 2, 4), ("scrap", 20, 2, 4), ("cord", 15, 1, 2),
                                ("glue", 5, 1, 1), ("ironstone", 6, 2, 4), ("stone_hatchet", 5, 1, 1), ("lantern", 5, 1, 1)]),
    "pine_band2": tbl((0, 1), [("cloth", 25, 1, 2), ("cord", 20, 1, 2), ("tin", 15, 1, 1), ("arrow", 15, 2, 4), ("dressing", 10, 1, 1),
                                ("rounds", 10, 1, 3), ("glue", 5, 1, 1)]),
    "pine_band3": tbl((1, 1), [("scrap", 25, 3, 5), ("rivets", 20, 1, 2), ("rounds", 18, 2, 4), ("spring", 12, 1, 1), ("pipe", 10, 1, 1),
                                ("tonic", 8, 1, 1), ("hood", 7, 1, 1)]),
    "quarry_toolbox": tbl((2, 3), [("scrap", 25, 3, 6), ("iron_ingot", 15, 1, 2), ("plate", 10, 1, 2), ("rivets", 15, 1, 3), ("JUNK", 22, 1, 1),
                                    ("arrow", 10, 4, 8), ("spring", 6, 1, 1), ("copper_wire", 4, 1, 2), ("stone_pick", 5, 1, 1), ("glue", 2, 1, 1)]),
    "quarry_locker": tbl((2, 3), [("tin", 12, 1, 2), ("water", 10, 1, 2), ("dressing", 15, 1, 2), ("cloth", 15, 2, 3), ("motor", 6, 1, 1),
                                   ("hood", 4, 1, 1), ("tonic", 3, 1, 1), ("bow", 2, 1, 1)]),
    "quarry_band2": tbl((1, 1), [("niter", 22, 1, 3), ("powder", 16, 1, 2), ("rounds", 16, 2, 5), ("pipe", 14, 1, 1), ("rivets", 14, 1, 3),
                                  ("trigger", 3, 1, 1), ("shells", 6, 1, 2), ("machete", 4, 1, 1)]),
    "quarry_band3": tbl((1, 2), [("powder", 20, 2, 3), ("pipe", 16, 1, 2), ("trigger", 5, 1, 1), ("rounds", 14, 3, 6), ("shells", 10, 2, 3),
                                  ("flare", 10, 1, 2), ("spring", 8, 1, 2), ("axe", 4, 1, 1), ("machete", 4, 1, 1)]),
    "depot_freight": tbl((3, 4), [("plate", 22, 2, 4), ("rivets", 18, 2, 4), ("block", 15, 2, 4), ("spring", 12, 1, 2), ("JUNK", 14, 1, 1),
                                   ("iron_ingot", 10, 2, 4), ("ironbark_plank", 6, 2, 3), ("copper_ingot", 4, 1, 1), ("arrow", 10, 6, 10),
                                   ("tin", 10, 1, 2), ("stew", 4, 1, 1), ("gear", 4, 1, 1)]),
    "depot_strongbox": tbl((1, 2), [("gear", 20, 1, 2), ("spring", 20, 1, 2), ("tonic", 16, 1, 1), ("bp_pack_frame", 14, 1, 1),
                                     ("bp_reinforced", 12, 1, 1), ("bow", 10, 1, 1), ("scrapblade", 8, 1, 1), ("vest", 8, 1, 1)],
                           {"rivets": 2}),
    "depot_band2": tbl((1, 2), [("niter", 20, 2, 4), ("powder", 18, 2, 3), ("trigger", 14, 1, 1), ("pipe", 14, 1, 2), ("shells", 12, 2, 4),
                                 ("rounds", 12, 4, 8), ("flare", 10, 1, 2)]),
    "depot_band3": tbl((1, 2), [("trigger", 20, 1, 2), ("powder", 18, 3, 5), ("shells", 14, 3, 6), ("flare", 12, 2, 3), ("gear", 10, 1, 1),
                                 ("axe", 8, 1, 1), ("pipe_pistol", 6, 1, 1), ("flare_pistol", 6, 1, 1), ("shotgun", 3, 1, 1)]),
}
LOOT["JUNK"] = JUNK

def loot_ev(tid, mult=1.0):
    t = LOOT[tid]
    rolls = (t["rolls"][0] + t["rolls"][1]) / 2 * mult
    W = sum(e[1] for e in t["entries"])
    out = {}
    for item, w, lo, hi in t["entries"]:
        n = rolls * w / W * (lo + hi) / 2
        if item == "JUNK":
            for k, v in loot_ev("JUNK").items():
                out[k] = out.get(k, 0) + v * n
        else:
            out[item] = out.get(item, 0) + n
    for k, v in t["guaranteed"].items():
        out[k] = out.get(k, 0) + v
    return out

# ---------------------------------------------------------------- locations
# containers: (table, avg count, search s); band2: table rolled by containers searched late
def L(tier, level, energy, walk, nodes, containers, enemies, band2=None, band3=None, gate=None, kind="zone"):
    return dict(tier=tier, level=level, energy=energy, walk=walk, nodes=nodes, containers=containers,
                enemies=enemies, band2=band2, band3=band3, gate=gate, kind=kind)

LOCS = {
    "bracken_edge": L(1, 1, 15, 12, {"pine": 30, "boulder": 3, "branches": 12, "stones": 12, "reeds": 20, "bush": 10, "ashroot": 6,
                                      "fatwood": 4, "pool": 1},
                      [("zone_pack_t1", 1.5, 3), ("forest_crate_t1", 0.5, 5)], {"shambler": 6, "runner": 1, "wolf": 1.5},
                      band2="pine_band2"),
    "ironbark_stand": L(2, 8, 22, 19, {"pine": 40, "ironbark": 15, "boulder": 5, "branches": 15, "stones": 12, "reeds": 30, "bush": 10,
                                        "ashroot": 6, "fatwood": 6, "pool": 1},
                        [("zone_pack_t2", 2, 3), ("forest_crate_t2", 1.5, 5)], {"shambler": 7, "runner": 3.5, "bloater": 1.5, "wolf": 2.5},
                        band2="quarry_band2", gate="tower_dense"),
    "gloaming_deep": L(3, 15, 33, 29, {"pine": 50, "ironbark": 25, "boulder": 5, "branches": 20, "stones": 10, "reeds": 40, "bush": 10,
                                        "ashroot": 6, "fatwood": 10, "pool": 1},
                       [("zone_pack_t3", 2.5, 3), ("forest_crate_t3", 2, 5)], {"shambler": 9, "runner": 6, "bloater": 2.5, "wolf": 2.5},
                       band2="depot_band2", gate="tower_black"),
    "rockfall_slope": L(1, 1, 15, 12, {"boulder": 25, "ironstone": 5, "scrapheap": 3, "pine": 10, "branches": 8, "stones": 20, "reeds": 20,
                                        "bush": 10, "pool": 1},
                        [("zone_pack_t1", 1.5, 3), ("mine_box_t1", 0.5, 5)], {"shambler": 6, "runner": 1.5, "wolf": 1.5},
                        band2="pine_band2"),
    "greenvein_bluffs": L(2, 8, 22, 19, {"boulder": 20, "ironstone": 30, "malachite": 10, "scrapheap": 4, "niter": 4, "pine": 13,
                                          "branches": 10, "stones": 15, "reeds": 30, "bush": 10, "pool": 1},
                          [("zone_pack_t2", 2, 3), ("mine_box_t2", 1.5, 5)], {"shambler": 7, "runner": 4, "bloater": 1.5},
                          band2="quarry_band2", gate="tower_dense"),
    "deepcut_pit": L(3, 15, 33, 29, {"boulder": 45, "ironstone": 50, "malachite": 20, "scrapheap": 6, "niter": 6, "pine": 20,
                                     "branches": 10, "stones": 22, "reeds": 40, "bush": 10, "pool": 1},
                     [("zone_pack_t3", 2.5, 3), ("mine_box_t3", 2, 5)], {"shambler": 10, "runner": 6, "bloater": 2.5},
                     band2="depot_band2", gate="tower_black"),
    # loot-heavy POIs (existing maps)
    "pine_hollow": L(1, 1, 15, 12, {"pine": 8, "boulder": 4, "branches": 8, "stones": 8, "reeds": 10, "bush": 6, "ashroot": 6, "pool": 2},
                     [("pine_pack", 4, 3), ("pine_crate", 2.5, 5)], {"shambler": 7.5, "runner": 1, "deer": 2.5, "wolf": 1.5},
                     band2="pine_band2", band3="pine_band3", kind="poi"),
    "rustwater": L(2, 8, 22, 19, {"scrapheap": 8, "boulder": 6, "fatwood": 4, "pine": 4, "ashroot": 4, "niter": 4, "pool": 2},
                   [("quarry_toolbox", 3.5, 5), ("quarry_toolbox", 2.5, 5), ("quarry_locker", 2.5, 5)],
                   {"shambler": 9, "runner": 4, "bloater": 1.5}, band2="quarry_band2", band3="quarry_band3", gate="tower_dense", kind="poi"),
    "ashfall_depot": L(3, 15, 33, 29, {"scrapheap": 14, "fatwood": 6, "boulder": 6, "ironstone": 8, "niter": 6, "pool": 1},
                       [("depot_freight", 5.5, 5), ("depot_strongbox", 1.5, 8)], {"shambler": 10, "runner": 8.5, "bloater": 2.5},
                       band2="depot_band2", band3="depot_band3", gate="tower_black", kind="poi"),
}
OVERHEAD_S = {1: 150, 2: 210, 3: 210}  # matchmaking, teleport, load, walking the map
KILL_S = {"shambler": 5, "runner": 8, "bloater": 9, "wolf": 8, "deer": 12}
KILL_XP = {"shambler": 10, "runner": 25, "bloater": 30, "wolf": 30, "deer": 15}
EXTRACT_S = {1: 15, 2: 45, 3: 45}
EXTRACT_XP = {1: 40, 2: 100, 3: 180}
LOSS = {1: 1.0, 2: 0.95, 3: 0.92}   # chance-weighted haul kept (deaths)
DEPOT_RESET_RUNS_PER_DAY = 1.2      # 20 h reset: the Depot strongbox/freight full only ~once a day

# ---------------------------------------------------------------- recipes
# station recipes: out -> (station, in item, in count, out count, minutes, station level, fuelled)
SREC = {
    "plank": ("wood", "timber", 2, 1, 4, 1),
    "ironbark_plank": ("wood", "ironbark_log", 5, 1, 20, 2),
    "block": ("stone", "stone", 3, 1, 5, 1),
    "iron_ingot": ("smelter", "ironstone", 2, 1, 4, 1),
    "iron_ingot_scrap": ("smelter", "scrap", 5, 1, 4, 1),
    "copper_ingot": ("smelter", "malachite", 5, 1, 60, 2),
    "plate": ("work", "iron_ingot", 1, 1, 20, 1),
    "rivets": ("work", "plate", 1, 2, 4, 1),
    "copper_wire": ("work", "copper_ingot", 1, 2, 10, 2),
    "cloth": ("work", "fiber", 2, 1, 2, 1),
    "coal": ("campfire", "timber", 2, 1, 4, 1),
    "glue": ("campfire", "fatwood", 2, 1, 4, 1),
    # survival sinks: cooking and boiling (Campfire), powder (Ammo Press)
    "cooked_meat": ("campfire", "raw_meat", 2, 2, 3, 1),
    "water": ("campfire", "murky", 1, 1, 2, 1),
    "roasted": ("campfire", "ashroot", 1, 1, 2, 1),
    "tea": ("campfire", "berry", 3, 1, 2, 1),
    "powder": ("press", "niter", 2, 1, 6, 1),
}
FOOD = {  # item: (hunger, thirst) restored
    "stew": (60, 15), "cooked_meat": (40, 0), "roasted": (30, 0), "tin": (25, 5), "tea": (5, 35), "water": (0, 45),
    "murky": (0, 15), "berry": (4, 2), "ashroot": (6, 0), "raw_meat": (6, 0),
}
SINK = dict(
    drain=6.0,
    hits_taken_per_kill={1: 0.8, 2: 1.2, 3: 1.5},
    dressings_per_run={1: 0.3, 2: 0.8, 3: 1.5},
    gun_shots_black=15,
)
WEAPONS = {
    "club": ({"plank": 4, "cord": 2, "scrap": 3}, 80, 14),
    "blade": ({"plate": 4, "plank": 2, "cloth": 2, "rivets": 2, "glue": 1}, 80, 24),
}
ARMOR = {"hood": ({"cloth": 4, "cord": 2}, 80), "vest": ({"cloth": 6, "cord": 3, "plate": 2, "glue": 1}, 100)}
GUN = ({"pipe": 1, "trigger": 1, "plank": 2, "rivets": 4, "spring": 1}, 50)
ROUNDS = ({"scrap": 2, "powder": 1}, 4)
DRESSING = ({"cloth": 5}, 1)
HP_SCALE = {1: 1.0, 2: 1.2, 3: 1.4}
EHP = {"shambler": 40, "runner": 70, "bloater": 60, "wolf": 55, "deer": 30}
FUELLED = {"smelter", "campfire", "press"}
RARE = {"trigger", "pipe", "spring", "gear", "bp_reinforced", "bp_pack_frame"}
SALV = {  # input -> (minutes, {output: expected count})
    "motor": (20, {"plate": 1.5, "spring": 0.9, "copper_wire": 0.53, "gear": 0.25}),
    "wire_junk": (5, {"scrap": 2, "copper_wire": 0.3, "rivets": 0.3}),
    "lantern": (6, {"scrap": 3, "glue": 0.5, "rivets": 0.6}),
}
BURN = {"sticks": 1, "timber": 2, "plank": 3, "fatwood": 5 + 1 / 3, "coal": 5 + 1 / 3, "ironbark_log": 2}
HAND = {  # hand-crafted intermediates
    "cord": {"fiber": 2},
}
TOOLS = {
    "stone_hatchet": ({"sticks": 3, "stone": 3}, 40, ("hatchet", 1)),
    "stone_pick": ({"sticks": 3, "stone": 3}, 40, ("pick", 1)),
    "forged_hatchet": ({"iron_ingot": 5, "plank": 3, "rivets": 2, "glue": 2}, 75, ("hatchet", 2)),
    "forged_pick": ({"iron_ingot": 5, "plank": 3, "rivets": 2, "glue": 2}, 75, ("pick", 2)),
}

# ---------------------------------------------------------------- build costs
B = dict(
    foundation_wood={"timber": 10},
    wall_wood={"timber": 8, "cord": 1},
    doorway_wood={"timber": 6, "cord": 1},
    door_wood={"timber": 5, "cord": 2},
    window_wood={"timber": 7, "cord": 1},
    crate_wood={"timber": 8, "cord": 4},
    # scrap tier: upgrade cost
    foundation_scrap={"plank": 6, "block": 4, "plate": 4},
    wall_scrap={"plank": 8, "block": 4, "plate": 3},
    doorway_scrap={"plank": 6, "block": 4, "plate": 3},
    door_scrap={"plank": 6, "plate": 4, "rivets": 4},
    window_scrap={"plank": 8, "block": 4, "plate": 3},
    # reinforced tier: upgrade cost
    foundation_reinforced={"block": 12, "plate": 8, "rivets": 4},
    wall_reinforced={"block": 10, "ironbark_plank": 6, "plate": 4, "rivets": 4, "copper_wire": 2},
    doorway_reinforced={"block": 8, "ironbark_plank": 6, "plate": 4, "rivets": 4, "copper_wire": 2},
    door_reinforced={"ironbark_plank": 6, "plate": 6, "rivets": 6, "copper_wire": 4, "spring": 1},
    window_reinforced={"block": 10, "ironbark_plank": 6, "plate": 4, "rivets": 4, "copper_wire": 2},
    # stations
    campfire={"sticks": 6, "stone": 5, "fiber": 2},
    woodworking_bench={"timber": 10, "stone": 6, "cord": 2},
    stonecutter={"plank": 8, "stone": 10, "cord": 2},
    smelter={"stone": 12, "block": 4, "sticks": 6},
    workbench={"plank": 10, "block": 6, "cord": 4},
    recycler={"plank": 15, "plate": 6, "rivets": 6, "spring": 2},
    wood_L2={"plank": 20, "plate": 6, "rivets": 4},
    smelter_L2={"block": 20, "plate": 10, "rivets": 4},
    work_L2={"plank": 20, "block": 10, "plate": 6},
    stone_L2={"block": 20, "plate": 6},
    tower_dense={"plank": 20, "plate": 6, "cord": 10, "spring": 1},
    tower_black={"plate": 16, "rivets": 12, "spring": 4, "gear": 2, "pipe": 2},
    pipe_pistol={"pipe": 1, "trigger": 1, "plank": 2, "rivets": 4, "spring": 1},
    ammo_press={"plank": 10, "plate": 8, "rivets": 6, "spring": 2},
    club={"plank": 4, "cord": 2, "scrap": 3},
    satchel={"cord": 2, "fiber": 3},
)

def room(n_found, n_wall, n_window, n_doorway, n_door, tier):
    return [(f"foundation_{tier}", n_found), (f"wall_{tier}", n_wall), (f"window_{tier}", n_window),
            (f"doorway_{tier}", n_doorway), (f"door_{tier}", n_door)]

GOALS = [
    ("hook", [("satchel", 1), ("campfire", 1), ("foundation_wood", 2), ("wall_wood", 2), ("woodworking_bench", 1),
              ("stonecutter", 1), ("workbench", 1)]),
    ("timber", room(9, 9, 2, 1, 1, "wood") + [("crate_wood", 2), ("smelter", 1), ("campfire", 1), ("club", 1),
                                               ("woodworking_bench", 1)]),
    ("scrap", room(9, 9, 2, 1, 1, "scrap") + [("work_L2", 1), ("recycler", 1), ("pipe_pistol", 1), ("tower_dense", 1),
                                               ("workbench", 1), ("smelter", 1), ("stonecutter", 1)]),
    ("reinforced", [("foundation_wood", 7), ("wall_wood", 4), ("foundation_scrap", 7), ("wall_scrap", 4),
                    ("wood_L2", 2), ("smelter_L2", 1), ("tower_black", 1), ("ammo_press", 1)] + room(16, 13, 2, 1, 1, "reinforced")),
]
GOAL_FLAGS = {"reinforced": ["bp_reinforced"], "scrap": []}

LEVELS = [0, 600, 1500, 2800, 4500, 7000, 11000, 16000, 21000, 26000, 32000, 38000, 44000, 50000, 57000,
          66000, 76000, 88000, 101000, 115000]
QUEST_XP = [150, 150, 200, 250, 250, 300, 350, 400, 300, 500]
QUEST_ITEMS = [{"tin": 2}, {"fiber": 6}, {"timber": 10, "cord": 4}, {"water": 2}, {"fatwood": 6}, {"scrap": 6},
               {"plank": 6, "cloth": 4}, {}, {"scrap": 4, "cloth": 4}, {"scrap": 6}]

# ---------------------------------------------------------------- raw expansion
def expand(need, out=None, depth=0):
    """Expand intermediate needs into raw needs (no stock considered)."""
    out = out if out is not None else {}
    for it, n in need.items():
        if n <= 0:
            continue
        if it in SREC and it != "iron_ingot_scrap":
            st, inp, ic, oc, mins, lvl = SREC[it]
            expand({inp: n * ic / oc}, out, depth + 1)
            if st in FUELLED:
                out["fuel_min"] = out.get("fuel_min", 0) + n / oc * mins
        elif it in HAND:
            for k, v in HAND[it].items():
                expand({k: n * v}, out, depth + 1)
        else:
            out[it] = out.get(it, 0) + n
    return out


class Sim:
    def __init__(self, p):
        self.p = p
        self.t = 0
        self.energy = 200.0
        self.xp = 0.0
        self.store = {}            # home storage + inbox
        self.tools = {("hatchet", 1): 0, ("hatchet", 2): 0, ("pick", 1): 0, ("pick", 2): 0}
        self.built = {}
        self.stations = []         # dicts
        self.goal_i = 0
        self.goal_left = [dict(g[1]) for g in GOALS]
        self.milestones = {}
        self.runs = []
        self.quests_paid = 0
        self.flags = set()
        self.log = []
        self.depot_cleared_at = -10 ** 9
        # home plot (finite, LDoE set)
        self.home_nodes = {"pine": 20, "boulder": 7, "scrapheap": 5, "bush": 7, "reeds": 20, "branches": 12, "stones": 10}
        self.store.update({"tin": 2, "water": 2})
        self.hunger, self.thirst = 100.0, 100.0
        self.melee = (None, 0)
        self.armor = {"hood": 0, "vest": 0}
        self.gun = 0
        self.spring_ready_at = 0

    # -- helpers
    def level(self):
        lv = 1
        for i, x in enumerate(LEVELS):
            if self.xp >= x:
                lv = i + 1
        return lv

    def add_xp(self, x):
        before = self.level()
        self.xp += x
        after = self.level()
        if after > before:
            self.energy = min(200, self.energy + 20 * (after - before))
            for lv in range(before + 1, after + 1):
                self.log.append((self.t, f"level {lv}"))
                self.level_at = getattr(self, 'level_at', {})
                self.level_at[lv] = self.t

    def count(self, cat, item, n):
        self.stats = getattr(self, "stats", {})
        key = (self.t // 1440 + 1, cat)
        d = self.stats.setdefault(key, {})
        d[item] = d.get(item, 0) + n

    def have(self, it):
        v = self.store.get(it, 0)
        return math.floor(v + 1e-6)

    def take(self, cost):
        for k, v in cost.items():
            if self.have(k) < v - 1e-9:
                return False
        for k, v in cost.items():
            self.store[k] = self.store.get(k, 0) - v
        return True

    def station_level(self, kind):
        lv = [s["level"] for s in self.stations if s["kind"] == kind]
        return max(lv) if lv else 0

    def slotcap(self, s):
        return 20 * s["level"]

    # -- what is still needed (intermediate level) for the current + next goal
    def needs(self):
        need = {}
        for gi in range(self.goal_i, min(self.goal_i + 1, len(GOALS))):
            for piece, n in self.goal_left[gi].items():
                for k, v in B[piece].items():
                    need[k] = need.get(k, 0) + v * n
        # tool upkeep: forged tools once the reinforced goal starts
        if self.goal_i >= 3:
            for t in ("forged_hatchet", "forged_pick"):
                for k, v in TOOLS[t][0].items():
                    need[k] = need.get(k, 0) + v * 2
        for f in GOAL_FLAGS.get(GOALS[min(self.goal_i, len(GOALS) - 1)][0], []):
            if f not in self.flags:
                need[f] = need.get(f, 0) + 1
        def add(cost, n=1):
            for k, v in cost.items():
                need[k] = need.get(k, 0) + v * n
        wname = "blade" if self.goal_i >= 2 else "club"
        add(WEAPONS[wname][0])
        # spare stone tools: 2 hatchets and 2 picks' worth of sticks and stone
        if self.tools[("hatchet", 1)] < 80 or self.tools[("pick", 1)] < 80:
            add({"sticks": 12, "stone": 12})
        if self.goal_i >= 1:
            add(ARMOR["hood"][0])
            add(ARMOR["vest"][0])
        add({"cloth": 5 * max(0, 4 - self.have("dressing"))})
        if self.built.get("ammo_press") and self.built.get("pipe_pistol"):
            r = max(0, 45 - self.have("rounds"))
            add({"scrap": r / 2, "powder": r / 4})
            add(GUN[0])
        hpts, tpts = self.food_points()
        if hpts < 1200:
            need["raw_meat"] = need.get("raw_meat", 0) + math.ceil((1200 - hpts) / 40)
        if tpts < 1200:
            need["murky"] = need.get("murky", 0) + math.ceil((1200 - tpts) / 45)
        return need

    def food_points(self):
        h = t = 0.0
        for k, (fh, ft) in FOOD.items():
            n = self.store.get(k, 0)
            if k == "raw_meat":
                fh = 40
            if k == "murky":
                ft = 45
            h += n * fh
            t += n * ft
        return h, t

    def eat(self, minutes):
        for _ in range(int(round(minutes))):
            self.hunger -= SINK["drain"]
            self.thirst -= SINK["drain"]
            self.count("sinks", "hunger_drained", SINK["drain"])
            for meter in ("hunger", "thirst"):
                guard = 0
                while getattr(self, meter) < 55 and guard < 6:
                    guard += 1
                    order = (["stew", "cooked_meat", "roasted", "tin", "ashroot", "berry", "raw_meat"] if meter == "hunger"
                             else ["water", "tea", "tin", "stew", "murky", "berry"])
                    ate = False
                    for k in order:
                        if self.store.get(k, 0) >= 1:
                            self.store[k] -= 1
                            fh, ft = FOOD[k]
                            self.hunger = min(100, self.hunger + fh)
                            self.thirst = min(100, self.thirst + ft)
                            self.count("ate", k, 1)
                            ate = True
                            break
                    if not ate:
                        break
            if self.hunger <= 0 or self.thirst <= 0:
                self.count("sinks", "starving_min", 1)
            self.hunger = max(0, self.hunger)
            self.thirst = max(0, self.thirst)

    def gear_up(self, lid):
        loc = LOCS[lid]
        t = loc["tier"]
        kills = {e: n * 0.6 for e, n in loc["enemies"].items()}
        hp = sum(EHP[e] * (1 if e in ("deer", "wolf") else HP_SCALE[t]) * n for e, n in kills.items() if e != "deer")
        gun_hp = 0
        if t == 3 and self.built.get("pipe_pistol"):
            if self.gun < SINK["gun_shots_black"]:
                if self.take(GUN[0]):
                    self.gun += GUN[1]
                    self.count("sinks", "gun_crafted", 1)
            rn = SINK["gun_shots_black"]
            while self.have("rounds") < rn and self.take(ROUNDS[0]):
                self.store["rounds"] = self.store.get("rounds", 0) + ROUNDS[1]
            if self.gun >= rn and self.have("rounds") >= rn:
                self.gun -= rn
                self.store["rounds"] -= rn
                gun_hp = rn * 34 * 0.7
                self.count("sinks", "shots", rn)
        wname = "blade" if self.goal_i >= 2 else "club"
        dmg = WEAPONS[wname][2]
        hits = max(0, hp - gun_hp) / dmg
        name, dur = self.melee
        if dur < hits:
            for wn in (wname, "club"):
                if self.take(WEAPONS[wn][0]):
                    name, dur = wn, dur + WEAPONS[wn][1]
                    self.count("sinks", wn + "_crafted", 1)
                    break
        used = min(dur, hits)
        self.melee = (name, dur - used)
        self.count("sinks", "melee_hits", used)
        if hits > used + 1:
            self.count("sinks", "fists_runs", 1)
        taken = sum(kills.get(e, 0) for e in ("shambler", "runner", "bloater", "wolf")) * SINK["hits_taken_per_kill"][t]
        if self.goal_i >= 1:
            for piece in ("hood", "vest"):
                if self.armor[piece] < taken and self.take(ARMOR[piece][0]):
                    self.armor[piece] += ARMOR[piece][1]
                    self.count("sinks", piece + "_crafted", 1)
                self.armor[piece] = max(0, self.armor[piece] - taken)
        need_d = SINK["dressings_per_run"][t]
        while self.have("dressing") < math.ceil(need_d) and self.take(DRESSING[0]):
            self.store["dressing"] = self.store.get("dressing", 0) + 1
        self.store["dressing"] = max(0, self.store.get("dressing", 0) - need_d)
        self.count("sinks", "dressings", need_d)

    def deficits(self):
        need = self.needs()
        d = {}
        # subtract stock at intermediate level, then expand remaining
        for k, v in need.items():
            rem = v - self.have(k)
            if rem > 0:
                d[k] = rem
        raw = expand(d)
        # raw stock
        out = {}
        for k, v in raw.items():
            if k == "fuel_min":
                out[k] = v
                continue
            rem = v - self.have(k)
            if k == "ironstone":  # scrap is an iron substitute (5 scrap = 1 ingot = 2 ironstone)
                rem -= self.have("scrap") * 2 / 5
            if rem > 0:
                out[k] = rem
        # fuel in timber-equivalent minutes
        if "fuel_min" in out:
            fuel_stock = sum(self.have(f) * BURN[f] for f in ("fatwood", "coal"))
            fm = max(0, out.pop("fuel_min") - fuel_stock)
            out["timber"] = out.get("timber", 0) + fm / BURN["timber"]
        return out, d

    # -- stations
    def ensure_station(self, kind, piece):
        self.stations.append(dict(kind=kind, level=1, line=None, inp=0, out=0, out_item=None, fuel=0, fuel_item=None,
                                  burn=0.0, work=0.0, outs={}))

    def tick_stations(self, minutes):
        for s in self.stations:
            if s["kind"] == "recycler":
                left = int(minutes)
                while left > 0 and s["line"] is not None and s["inp"] >= 1:
                    mins, outs = SALV[s["line"]]
                    step = min(left, mins - s["work"])
                    s["work"] += step
                    left -= step
                    if s["work"] >= mins:
                        s["work"] = 0
                        s["inp"] -= 1
                        for k, v in outs.items():
                            s["outs"][k] = s["outs"].get(k, 0) + v
                continue
            for _ in range(int(minutes)):
                if s["line"] is None:
                    break
                st, inp, ic, oc, mins, lvl = SREC[s["line"]]
                if s["inp"] < ic or s["out"] + oc > self.slotcap(s):
                    break
                if s["kind"] in FUELLED:
                    if s["burn"] <= 0:
                        if s["fuel"] <= 0:
                            break
                        s["fuel"] -= 1
                        s["burn"] += BURN[s["fuel_item"]]
                    s["burn"] -= 1
                s["work"] += 1
                if s["work"] >= mins:
                    s["work"] = 0
                    s["inp"] -= ic
                    s["out"] += oc
                    self.count("refined", s["out_item"], oc)

    def refill(self):
        _, dint = self.deficits()
        need = self.needs()
        for s in self.stations:
            if s["kind"] == "recycler":
                for k, v in s["outs"].items():
                    self.store[k] = self.store.get(k, 0) + v
                s["outs"] = {}
                if s["inp"] < 1:
                    for j in ("motor", "wire_junk", "lantern"):
                        if self.have(j) >= 1:
                            n = min(20, int(self.have(j)))
                            s["line"], s["inp"], s["work"] = j, n, 0
                            self.store[j] -= n
                            break
                continue
            if s["out"] > 0:
                item = SREC[s["line"]][0] and s["out_item"]
                self.store[item] = self.store.get(item, 0) + s["out"]
                s["out"] = 0
            # choose line: output with largest unmet intermediate need
            best, best_score = None, 0
            for out, (st, inp, ic, oc, mins, lvl) in SREC.items():
                if st != s["kind"] or s["level"] < lvl:
                    continue
                oitem = "iron_ingot" if out == "iron_ingot_scrap" else out
                down = 0
                for o2, (st2, in2, ic2, oc2, m2, l2) in SREC.items():
                    if in2 == oitem:
                        o2i = "iron_ingot" if o2 == "iron_ingot_scrap" else o2
                        down += max(0, dint.get(o2i, 0) - self.inflight(o2i)) * ic2 / oc2
                        if o2 == "plate":  # plates also feed rivets
                            down += max(0, dint.get("rivets", 0) - self.inflight("rivets")) / 2
                want = math.ceil(max(0, need.get(oitem, 0) + down - self.have(oitem) - self.inflight(oitem, s)))
                if oitem in ("cooked_meat", "water", "roasted", "tea"):
                    want = max(0, {"cooked_meat": 30, "water": 30, "roasted": 10, "tea": 10}[oitem] - self.have(oitem))
                if oitem == "powder":
                    want = max(0, 20 - self.have("powder"))
                if oitem == "coal":
                    want = 30 if any(x["kind"] == "smelter" and x["level"] >= 2 for x in self.stations) and self.have("coal") < 60 else 0
                if oitem == "glue":
                    want = max(0, 8 - self.have("glue")) if self.goal_i >= 2 else max(0, 2 - self.have("glue"))
                if oitem == "plank" and self.have("plank") < 30:
                    want += 10  # keep a small plank float (tools, fuel)
                avail = self.have(inp) + (s["inp"] if s["line"] == out else 0)
                if avail < ic or want <= 0:
                    continue
                score = want * (1 + mins / 60)
                if oitem in ("cooked_meat", "water"):
                    score *= 5  # a hungry survivor cooks before making coal
                if score > best_score:
                    best, best_score = out, score
            if best is None:
                continue
            if s["line"] != best:
                # return old input
                if s["line"] is not None and s["inp"] > 0:
                    old_in = SREC[s["line"]][1]
                    self.store[old_in] = self.store.get(old_in, 0) + s["inp"]
                s["line"], s["inp"], s["work"] = best, 0, 0
                s["out_item"] = "iron_ingot" if best == "iron_ingot_scrap" else best
            st, inp, ic, oc, mins, lvl = SREC[best]
            load = int(min(self.slotcap(s) - s["inp"], self.have(inp)))
            # don't starve building: keep timber for pieces unless it's the plank line
            load = max(0, load)
            s["inp"] += load
            self.store[inp] = self.have(inp) - load
            if s["kind"] in FUELLED:
                for f in ("coal", "fatwood", "timber", "plank", "sticks"):
                    if s["fuel"] >= self.slotcap(s):
                        break
                    if s["fuel"] > 0 and s["fuel_item"] != f:
                        continue
                    if f == "plank" and need.get("plank", 0) > self.have("plank"):
                        continue
                    if f == "sticks" and self.have("sticks") < 15:
                        continue
                    if f == "timber" and best == "coal":
                        pass
                    if s["fuel"] < 1:
                        s["fuel"] = 0
                    amt = int(min(self.slotcap(s) - s["fuel"], self.have(f)))
                    if f in ("coal",) and best != "copper_ingot":
                        amt = min(amt, max(0, self.have(f) - 0))
                    if amt > 0:
                        s["fuel"] += amt
                        s["fuel_item"] = f
                        self.store[f] -= amt

    def inflight(self, item, exclude=None):
        n = 0
        for s in self.stations:
            if s.get("out_item") == item:
                st, inp, ic, oc, mins, lvl = SREC[s["line"]]
                n += s["out"] + (s["inp"] // ic) * oc
        return n

    # -- building and crafting
    def craft_hand(self):
        # cord from fiber as needed
        need = self.needs()
        want_cord = need.get("cord", 0) + 2 - self.have("cord")
        while want_cord > 0 and self.have("fiber") >= 2:
            self.store["fiber"] -= 2
            self.store["cord"] = self.have("cord") + 1
            want_cord -= 1

    def build(self):
        progressed = True
        while progressed:
            progressed = False
            gl = self.goal_left[self.goal_i]
            PRIORITY = ("tower_dense", "tower_black", "work_L2", "wood_L2", "smelter_L2", "recycler")
            for piece, n in sorted(gl.items(), key=lambda kv: (kv[0] not in PRIORITY, sum(B[kv[0]].values()))):
                if n <= 0:
                    continue
                if not self.can_build(piece):
                    continue
                if self.take(B[piece]):
                    self.count("built", piece, 1)
                    self.last_built = getattr(self, "last_built", {})
                    self.last_built[(GOALS[self.goal_i][0], piece)] = self.t
                    gl[piece] -= 1
                    self.on_built(piece)
                    progressed = True
                    break
            if all(v <= 0 for v in gl.values()) and all(f in self.flags for f in GOAL_FLAGS.get(GOALS[self.goal_i][0], [])):
                name = GOALS[self.goal_i][0]
                if name == "hook" and self.level() < 5:
                    return
                if name in self.milestones:
                    return
                self.milestones[name] = self.t
                self.log.append((self.t, f"MILESTONE {name} lvl {self.level()}"))
                if self.goal_i + 1 < len(GOALS):
                    self.goal_i += 1
                    progressed = True
                else:
                    return

    def can_build(self, piece):
        if piece == "pipe_pistol":
            return self.station_level("work") >= 2
        if piece == "recycler":
            return self.built.get("foundation_scrap", 0) >= 1
        if piece in ("wood_L2",):
            return any(s["kind"] == "wood" and s["level"] == 1 for s in self.stations)
        if piece == "smelter_L2":
            return any(s["kind"] == "smelter" and s["level"] == 1 for s in self.stations)
        if piece == "work_L2":
            return any(s["kind"] == "work" for s in self.stations)
        if piece.endswith("_reinforced"):
            return "bp_reinforced" in self.flags
        return True

    def on_built(self, piece):
        self.built[piece] = self.built.get(piece, 0) + 1
        kinds = {"campfire": "campfire", "woodworking_bench": "wood", "stonecutter": "stone", "smelter": "smelter",
                 "workbench": "work", "recycler": "recycler", "ammo_press": "press"}
        if piece in kinds:
            self.ensure_station(kinds[piece], piece)
        if piece in ("wood_L2", "smelter_L2", "work_L2"):
            k = {"wood_L2": "wood", "smelter_L2": "smelter", "work_L2": "work"}[piece]
            for s in self.stations:
                if s["kind"] == k and s["level"] == 1:
                    s["level"] = 2
                    break
        if piece in ("tower_dense", "tower_black"):
            self.flags.add(piece)
        # Ember Trail rewards (approximate: one quest per early piece type)
        if self.quests_paid < len(QUEST_XP) and piece in ("satchel", "campfire", "foundation_wood", "wall_wood",
                                                         "woodworking_bench", "workbench", "club", "crate_wood",
                                                         "doorway_wood", "door_wood"):
            if piece not in self.flags:
                self.flags.add(piece)
                self.add_xp(QUEST_XP[self.quests_paid])
                for k, v in QUEST_ITEMS[self.quests_paid].items():
                    self.store[k] = self.store.get(k, 0) + v
                self.quests_paid += 1

    def ensure_tools(self, plan_hits):
        for key, hits in plan_hits.items():
            kind, tier = key
            while self.tools[key] < hits:
                name = f"{'stone' if tier == 1 else 'forged'}_{kind if kind == 'pick' else 'hatchet'}"
                cost, dur, _ = TOOLS[name]
                if self.take(cost):
                    self.tools[key] += dur
                else:
                    break

    # -- gathering
    def node_yield(self, nid):
        kind, tier, hits, ylds, every, over = NODES[nid]
        units = {k: v * (hits // every) for k, v in ylds.items()}
        return kind, tier, hits, units, over

    def plan_run(self, lid, deficits, value_only=False):
        loc = LOCS[lid]
        self._food_s = 0.0
        slots = 10 + self.p["bag_slots"] - self.p["reserved_slots"]
        if self.have("pack_frame_equipped"):
            slots += 5
        time_s = OVERHEAD_S[loc["tier"]] + EXTRACT_S[loc["tier"]]
        haul, xp, hits_used = {}, 0.0, {}
        # containers first
        for tid, cnt, search in loc["containers"]:
            if lid == "ashfall_depot":
                cnt = cnt * min(1, DEPOT_RESET_RUNS_PER_DAY / max(1, self.depot_runs_today))
            ev = loot_ev(tid, 1.15)
            share = self.p["contested"] if loc["tier"] >= 2 else 1.0
            cnt = cnt * share
            for k, v in ev.items():
                haul[k] = haul.get(k, 0) + v * cnt
            if loc["band2"]:
                for k, v in loot_ev(loc["band2"]).items():
                    haul[k] = haul.get(k, 0) + v * cnt * 0.45
            if loc["band3"]:
                for k, v in loot_ev(loc["band3"]).items():
                    haul[k] = haul.get(k, 0) + v * cnt * 0.15
            time_s += cnt * (search + 15)
        for e, n in loc["enemies"].items():
            time_s += n * 0.6 * KILL_S[e]
            xp += n * 0.6 * KILL_XP[e]
        en = loc["enemies"]
        self._food_s += en.get("deer", 0) * 0.6 * KILL_S["deer"]
        haul["raw_meat"] = haul.get("raw_meat", 0) + en.get("deer", 0) * 0.6 * 3 + en.get("wolf", 0) * 0.6 * 1.3
        haul["hide"] = haul.get("hide", 0) + en.get("deer", 0) * 0.6 * 1.5 + en.get("wolf", 0) * 0.6 * 0.7
        haul["niter"] = haul.get("niter", 0) + en.get("bloater", 0) * 0.6 * 0.675
        loot_slots = sum(math.ceil(v / STACK.get(k, 20)) * 0.6 for k, v in haul.items() if v > 0.3)
        slots_left = max(0, slots - loot_slots)
        # nodes by value
        VAL = dict(timber=1, stone=0.8, sticks=0.4, fiber=0.5, ironstone=3, scrap=1.3, ironbark_log=5, malachite=7,
                   fatwood=1.5, niter=0.5, berry=0.3, ashroot=0.3, murky=1.5)
        cand = []
        for nid, count in loc["nodes"].items():
            kind, tier, hits, units, over = self.node_yield(nid)
            if kind is not None:
                tool_ok = any(self.tools[(kind, t)] > 0 or self.can_make_tool(kind, t) for t in (1, 2) if t >= tier)
                if not tool_ok:
                    continue
            item = max(units, key=units.get)
            per = units[item]
            d = deficits.get(item, 0)
            v = VAL.get(item, 0.2) * (1.0 if d > 0 else 0.15)
            cand.append((v * per / (hits * 0.8 + over), nid, count, kind, tier, hits, units, over, item))
        cand.sort(reverse=True)
        stacks = {}
        for score, nid, count, kind, tier, hits, units, over, item in cand:
            if score <= 0.001:
                continue
            for _ in range(count):
                if time_s >= self.p["run_cap_min"] * 60:
                    break
                # slot check for the main item
                cur = stacks.get(item, 0)
                st = STACK.get(item, 20)
                new_slots = math.ceil((cur + units[item]) / st) - math.ceil(cur / st)
                if new_slots > slots_left:
                    break
                slots_left -= new_slots
                for k, v in units.items():
                    stacks[k] = stacks.get(k, 0) + v
                    xp += 10 * v
                time_s += hits * 0.8 + over
                if item in ("berry", "murky", "ashroot"):
                    self._food_s += hits * 0.8 + over
                if kind is not None:
                    key = (kind, max(tier, 1))
                    hits_used[key] = hits_used.get(key, 0) + hits
        for k, v in stacks.items():
            haul[k] = haul.get(k, 0) + v
        xp += EXTRACT_XP[loc["tier"]]
        self._food_min = self._food_s / 60
        return haul, xp, time_s / 60, hits_used

    def can_make_tool(self, kind, tier):
        name = f"{'stone' if tier == 1 else 'forged'}_{kind if kind == 'pick' else 'hatchet'}"
        cost = TOOLS[name][0]
        return all(self.have(k) >= v for k, v in cost.items())

    def choose_run(self, session_left):
        deficits, _ = self.deficits()
        best = None
        for lid, loc in LOCS.items():
            if self.level() < loc["level"]:
                continue
            if loc["gate"] and loc["gate"] not in self.flags:
                continue
            haul, xp, mins, hits = self.plan_run(lid, deficits)
            VAL = dict(timber=1, stone=0.8, sticks=0.4, fiber=0.5, ironstone=3, scrap=1.3, ironbark_log=5, malachite=7,
                       fatwood=1.5, plank=2, block=3, iron_ingot=7, plate=9, rivets=4, copper_ingot=40, copper_wire=20,
                       ironbark_plank=25, spring=150, gear=200, pipe=150, trigger=400, bp_reinforced=800, cord=1, glue=4,
                       raw_meat=3, murky=2, water=2, tin=2, stew=4, berry=0.3, cloth=1, powder=2, niter=1)
            hpts, tpts = self.food_points()
            if hpts < 400:
                VAL["raw_meat"] = 12
                VAL["tin"] = 8
                VAL["berry"] = 1
            if tpts < 400:
                VAL["murky"] = 8
                VAL["water"] = 8
                VAL["berry"] = 1
            value = 0
            for k, v in haul.items():
                d = deficits.get(k, 0) if k in deficits else (self.needs().get(k, 0) - self.have(k))
                d = max(d, 6) if d > 0 else 0  # the last few units still send a player out
                value += VAL.get(k, 0.05) * (min(v, d) + self.p["hoard"] * v)
            fv = sum(VAL.get(k, 0.05) * min(v, max(0, (deficits.get(k, 0) if k in deficits else (self.needs().get(k, 0) - self.have(k))))) for k, v in haul.items() if k in ("raw_meat", "murky", "berry", "tin", "water", "stew", "ashroot"))
            value *= LOSS[loc["tier"]]
            # XP matters when a level gate stands between the player and the next tier
            gate_levels = [x["level"] for x in LOCS.values() if x["level"] > self.level()]
            xp_w = self.p["xp_w_gated"] if gate_levels else self.p["xp_w"]
            value += xp * xp_w
            mode = None
            if self.energy >= loc["energy"]:
                mode, cost_min = "run", mins + 0.1
            elif session_left >= loc["walk"] + mins + self.p["home_minutes"]:
                mode, cost_min = "walk", loc["walk"] + mins
            if mode is None or session_left < mins + 1:
                continue
            rate = value / (cost_min + self.p["energy_min"] * (loc["energy"] if mode == "run" else 0))
            if best is None or rate > best[0]:
                best = (rate, lid, mode, haul, xp, mins, hits, cost_min)
                self._best_food = (fv / max(1e-6, value), self._food_min)
        return best

    def run(self, days=21):
        day_end = days * 1440
        self.depot_runs_today = 0
        last_day = -1
        while self.t < day_end:
            day = self.t // 1440
            if day != last_day:
                self.depot_runs_today = 0
                last_day = day
            in_session = None
            for st, ln in self.p["sessions"]:
                s0 = day * 1440 + st
                if s0 <= self.t < s0 + ln:
                    in_session = s0 + ln
            if in_session is None:
                # advance to next session start
                nxt = None
                for st, ln in self.p["sessions"]:
                    s0 = day * 1440 + st
                    if s0 > self.t:
                        nxt = s0
                        break
                if nxt is None:
                    nxt = (day + 1) * 1440 + self.p["sessions"][0][0]
                dt = nxt - self.t
                self.tick_stations(dt)
                self.energy = min(200, self.energy + dt / 5)
                self.t = nxt
                continue
            # home visit
            self.home_actions()
            if self.t >= self.spring_ready_at:
                self.store["murky"] = self.store.get("murky", 0) + 1
                self.spring_ready_at = self.t + 3
            hm = self.p["home_minutes"]
            self.eat(hm)
            self.tick_stations(hm)
            self.energy = min(200, self.energy + hm / 5)
            self.t += hm
            session_left = in_session - self.t
            if session_left <= 2:
                continue
            # home nodes first (the hook)
            if any(v > 0 for v in self.home_nodes.values()):
                self.gather_home()
                continue
            choice = self.choose_run(session_left)
            if choice is None:
                dt = min(10, session_left)
                self.eat(dt)
                self.tick_stations(dt)
                self.energy = min(200, self.energy + dt / 5)
                self.t += dt
                continue
            rate, lid, mode, haul, xp, mins, hits, cost_min = choice
            share, fmin = self._best_food
            self.count("sinks", "food_value_share_x_min", share * cost_min)
            self.count("sinks", "food_gather_min", fmin)
            self.count("sinks", "run_min", cost_min)
            loc = LOCS[lid]
            if mode == "run":
                self.energy -= loc["energy"]
            if lid == "ashfall_depot":
                self.depot_runs_today += 1
            self.ensure_tools(hits)
            self.gear_up(lid)
            for key, h in hits.items():
                self.tools[key] = max(0, self.tools[key] - h)
            keep = LOSS[loc["tier"]]
            self.count("energy", "spent", loc["energy"] if mode == "run" else 0)
            self.count("runs", lid, 1)
            for k, v in haul.items():
                self.count("haul", k, v * keep)
                self.store[k] = self.store.get(k, 0) + v * keep
            if self.have("bp_reinforced") >= 1:
                self.flags.add("bp_reinforced")
            if self.have("bp_pack_frame") >= 1 and not self.have("pack_frame_equipped"):
                self.store["pack_frame_equipped"] = 1
            self.add_xp(xp)
            self.day_xp = getattr(self, "day_xp", {})
            self.day_xp[self.t // 1440 + 1] = self.xp
            dt = int(math.ceil(cost_min))
            self.eat(dt)
            self.tick_stations(dt)
            self.energy = min(200, self.energy + dt / 5)
            self.t += dt
            self.runs.append((self.t, lid, mode))
        return self

    def gather_home(self):
        # clear home nodes in one go (about 12 minutes), tools first
        if self.tools[("hatchet", 1)] == 0 or self.tools[("pick", 1)] == 0:
            # sticks/stone by hand first
            for nid in ("branches", "stones", "reeds"):
                n = self.home_nodes[nid]
                kind, tier, hits, units, over = self.node_yield(nid)
                for k, v in units.items():
                    self.store[k] = self.store.get(k, 0) + v * n
                    self.add_xp(10 * v * n)
                self.home_nodes[nid] = 0
            self.ensure_tools({("hatchet", 1): 40, ("pick", 1): 40})
        mins = 0
        for nid, n in list(self.home_nodes.items()):
            if n <= 0:
                continue
            kind, tier, hits, units, over = self.node_yield(nid)
            if kind is not None:
                need = hits * n
                self.ensure_tools({(kind, 1): need})
                use = min(need, self.tools[(kind, 1)])
                n = use // hits
                self.tools[(kind, 1)] -= n * hits
            for k, v in units.items():
                self.store[k] = self.store.get(k, 0) + v * n
                self.add_xp(10 * v * n)
            mins += n * (hits * 0.8 + over) / 60
            self.home_nodes[nid] = 0
        dt = int(math.ceil(mins)) + 3
        self.eat(dt)
        self.tick_stations(dt)
        self.t += dt

    def home_actions(self):
        self.craft_hand()
        self.build()
        self.refill()
        self.build()


def fmt(t):
    if t is None:
        return "-"
    d = t // 1440
    m = t % 1440
    return f"day {d + 1} {m // 60:02d}:{m % 60:02d}"


def play_minutes(t, p):
    """Minutes of play by time t."""
    total = 0
    d = 0
    while d * 1440 <= t:
        for st, ln in p["sessions"]:
            s0 = d * 1440 + st
            total += max(0, min(t, s0 + ln) - s0)
        d += 1
    return total


if __name__ == "__main__":
    over = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}
    for k, v in over.get("B", {}).items():
        B[k] = v
    for k, v in over.get("SREC", {}).items():
        SREC[k] = tuple(v)
    p = dict(P)
    p.update(over.get("P", {}))
    sim = Sim(p).run(days=over.get("days", 21))
    for name in ("hook", "timber", "scrap", "reinforced"):
        t = sim.milestones.get(name)
        print(f"{name:11s} {fmt(t):18s} play {play_minutes(t, p) if t is not None else '-'} min")
    print("level", sim.level(), "xp", int(sim.xp))
    la = getattr(sim, 'level_at', {})
    print("L5", fmt(la.get(5)), play_minutes(la[5], p) if 5 in la else '-', "| L8", fmt(la.get(8)), "| L15", fmt(la.get(15)), "| L20", fmt(la.get(20)))
    lv_at = {}
    # count runs by location
    from collections import Counter
    c = Counter(l for _, l, _ in sim.runs)
    print(dict(c))
    w = Counter(m for _, _, m in sim.runs)
    print(dict(w))
    if over.get("daily"):
        for d in range(1, over.get("days", 21) + 1):
            print(f"--- day {d}")
            for cat in ("runs", "energy", "haul", "refined", "built", "ate", "sinks"):
                v = sim.stats.get((d, cat), {})
                if cat == "haul":
                    v = {k: round(x) for k, x in v.items() if x >= 3 and k in ("timber", "stone", "sticks", "fiber", "ironstone",
                         "scrap", "ironbark_log", "malachite", "fatwood", "spring", "gear", "trigger", "pipe", "bp_reinforced")}
                elif cat in ("ate", "sinks"):
                    v = {k: round(x, 1) for k, x in v.items()}
                elif cat == "refined":
                    v = {k: round(x) for k, x in v.items()}
                print(f"  {cat}: {v}")
    if over.get("verbose"):
        for t, msg in sim.log:
            print(fmt(t), msg)
        days = {}
        for t, l, m in sim.runs:
            days.setdefault(t // 1440 + 1, []).append(l[:6] + ("*" if m == "walk" else ""))
        for d, ls in days.items():
            print(d, int(sim.day_xp.get(d, 0)), " ".join(ls))
        print({k: round(v, 1) for k, v in sim.store.items() if v > 0.5})
        print(sim.goal_left[sim.goal_i])
        for (g, piece), t in sorted(sim.last_built.items(), key=lambda kv: kv[1]):
            if g in ("hook", "scrap", "reinforced"):
                print("  ", g, piece, fmt(t))
