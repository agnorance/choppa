---
name: add-map
description: Add a new battle arena (map) to choppa - terrain, rocks, tunnels, vegetation, water, spawns, items - and register it in the menu. Use when the owner wants a new map.
---

# Adding a map

Read the Maps section of docs/DESIGN.md first. Arenas are enclosed (cliffs above the
flight ceiling), with cover, tunnels or trenches to fly through, and item rows on the
routes. `scripts/mesa_basin.gd` is the reference implementation.

1. **Script:** `scripts/<name>.gd` with `class_name`, `extends GameMap`. In `_init` set
   `ceiling`. In `_ready`, seed every RNG (and `seed(...)` for MapKit's global RNG) so the
   map is identical on every machine (matters for multiplayer).
2. **Building blocks** (`scripts/map_kit.gd`): `environment()` (sky, sun, fog per
   quality), `Terrain` with a `height_fn` and `MapKit.terrain_material(water_level)`,
   `backdrop()` mountains, `rock("mesa"|"arch_1"|"hoodoo_2"|"boulder_3"...)` from the
   Blender rock models, `tunnel_lights()`, `tree()`, `water()`, `item_row()`,
   `MapKit.block()` for solid boxes. Grass: a `Grass` node (only on MEDIUM and up),
   see Mesa Basin.
3. **Gameplay data:** fill `spawn_points` (8, facing the middle, above ground),
   `dummy_posts` (3, free flight), health crates, item rows, and `gates` only for race
   maps.
4. **Register:** `GameMap.catalog()` (menu name + id) and `GameMap.create()`.
5. **Performance:** use `Graphics.quality` for terrain resolution, grass density and
   view distance (phones are MEDIUM).
6. **Check:** tests (`tools/test.ps1` / `tools/test.sh`), then screenshots with
   `--map=<id>` from several spawns, and a bot battle
   (`--mode=battle --map=<id> --autopilot=bot`) to see that bots don't get stuck.
   Consider a test like `test_bots_battle_in_arena` for the new map.
7. **Docs:** Maps section in docs/DESIGN.md and the README.

Then use the `ship` skill.
