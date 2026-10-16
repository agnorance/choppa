---
name: add-item
description: Add a new Mario Kart style item (from item boxes) to choppa, end to end - odds table, effect, bot use, HUD/cockpit, tests and docs. Use when the owner wants a new pickup or power-up.
---

# Adding an item

Items are the "fool your friends" heart of the game (docs/DESIGN.md, Items table).
Check the design doc first; items should be readable at a glance and counterable.

1. **Odds:** add `"NAME": [weight when leading, weight when last, HUD colour]` to
   `Items.TABLE` (`scripts/items.gd`). Comeback items get 0 for the leader.
2. **Effect:** add a case in `Choppa.use_item()` (`scripts/choppa.gd`). Keep it in the
   simulation layer: timers as `var` on the choppa decremented in `step()`, world
   objects (projectiles, clouds) in `scripts/weapons.gd`, placed with `_drop()`.
   Area damage uses `Weapons.blast()`; all damage goes through `Choppa.damage()`,
   which already ignores `mortal == false` (races), spawn shields and the shield item.
3. **Visuals:** model/effect in `ChoppaModel.update_pose()` or the weapon's own node;
   particles via `Effects.puffs()`. Effects with world-space particles start in a
   deferred `_start()` (see `Effects.Explosion`).
4. **Feedback:** HUD callout (`scripts/hud.gd`, signals like `item_used`), cockpit
   lamp if it is a state (`scripts/cockpit.gd`), item colour shows on the HUD and the
   ordnance plate automatically.
5. **Bots:** teach `FighterBot._should_use_item()` (`scripts/fighter_bot.gd`) when to
   fire it; `RacerBot` for races if it makes sense there.
6. **Tests:** add `test_<item>` in `tests/run_tests.gd` (and register it in the list at
   the top): give the item with `give_item()`, `use_item()`, step with `_step_all()` /
   `_fly()`, check the outcome. `--autopilot=item:NAME` shows it in a screenshot.
7. **Docs:** Items table in docs/DESIGN.md, the item list in README.md.

Then use the `ship` skill.
