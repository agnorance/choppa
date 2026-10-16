---
name: add-weapon
description: Add a new weapon to the choppa loadout end to end - ammo per helicopter class, firing, the weapon object, bot use, HUD/cockpit, controls, tests and docs. Use when the owner wants a new weapon or a new thing to drop. Item boxes are gone; everything is a loadout refilled at service stations.
---

# Adding a weapon

The loadout is finite and refilled only at service stations (docs/DESIGN.md, "Service
stations and loadout"). Every weapon should be readable at a glance and counterable.

1. **Ammo:** add the key to `Choppa.ammo`, `Choppa._cooldowns` and `WEAPON_INTERVAL`
   (`scripts/choppa.gd`), and to `restock()`. Per-class amounts go in `Airframe.TABLE`
   (`scripts/airframe.gd`) and `full_ammo()`.
2. **Input:** a bool in `PilotInput` (and `copy_from`), an action in `Controls._bindings`
   and `cheat_sheet`, `LocalPilot` reads it, a touch button if it matters on phones.
3. **Firing:** a `fire_x()` / `drop_x()` in `Choppa` that calls `_take("x")` and places
   the object with `_drop(thing, offset, along_body)`; `_update_weapons` calls it.
4. **The object:** a class in `scripts/weapons.gd` (see `Rocket`, `Missile`, `Mine`).
   Hits go through `Choppa.take_hit(impulse, shooter, damage, at)` so the part model
   applies; area damage through `Weapons.blast`. World-space particles start after
   placement (`call_deferred`), see CLAUDE.md.
5. **Bots:** decide when to use it in `FighterBot._use_weapons`.
6. **HUD / cockpit:** the loadout line in `Hud._process`, the plate in `Cockpit`.
7. **Tests:** fire it, run out, restock, and what it does to a target
   (`tests/run_tests.gd`). Add a `--autopilot=weapon:x` case in `ScriptedPilot` and a
   `tools\try.ps1` scene, then look at a screenshot.
8. **Docs:** the loadout table in DESIGN.md, the controls table in README.md.
