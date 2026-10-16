# choppa: instructions for Claude

Arcade helicopter arena shooter (multiplayer planned), started 2026-10-16. Godot 4.7.2
(GDScript; Forward+ on desktop, Mobile on Android), targets Windows (RTX 3060+) first,
then Android. Design, art direction and roadmap: docs/DESIGN.md (read it before
changing gameplay or looks; it records what the owner decided).

- The owner plays and tests on Windows (desktop, RTX 5080) and Android (sideloaded APK).
  They write in German or English; answer in the language they use.
- Commits: no AI attribution (no Co-Authored-By or similar lines).
- Work on a branch (currently `godot-foundation`); don't push to main unasked.
- Graphics quality matters to the owner: look at a screenshot after visual changes.

## Where things stand

Done: flight model, tricks, boost, battle/free/race modes, items, bots, Mesa Basin, the
Little Bird style choppa with cockpit view, effects, pines, grass, water, explosions,
synthesized sound effects. PR #1 (`godot-foundation` -> `main`) waits for the owner to
merge it on GitHub (merging is the owner's call).
Noted for later (ask before starting): flight physics feel pass (DESIGN.md, "Physics
ideas"), UI overhaul (DESIGN.md, Milestones), choppa colours/customization, LAN
multiplayer. Each session: check `git log` and the roadmap, then confirm the next step.

## Commands

Godot must be 4.7.2. Two environments:

| Task | Windows (owner's PC, PowerShell) | Linux / cloud |
|---|---|---|
| Tests | `tools\test.ps1` | `tools/test.sh` |
| Play | `tools\run.ps1 --mode=battle --map=basin` | `godot --path . -- --mode=battle` |
| Screenshot | `tools\shot.ps1 out.png --cam=showcase --frames=150` | `tools/shot.sh out.png --cam=showcase --frames=150` |
| Re-import | `& $env:GODOT --headless --path . --import` | `godot --headless --path . --import` |

- Windows scripts find Godot via `$env:GODOT` (path to `Godot_v4.7.2-stable_win64_console.exe`),
  the PATH, or `C:\Tools\Godot\`. Setup: docs/SETUP_WINDOWS.md.
- Tests: `--fixed-fps 60` runs physics as fast as possible; whole bot races take
  seconds. After adding a new `class_name` or asset, re-import first (test scripts do).
- Linux screenshots need Xvfb and Vulkan (`apt-get install -y mesa-vulkan-drivers`,
  lavapipe). That software renderer runs at ~1 fps, so a screenshot takes minutes and
  a timed effect (`--explode`) needs `--fixed-fps 60`, i.e. ~15 min per shot: prefer
  leaving effect timing checks to the owner's PC.
- Game arguments go after `--`; the list is at the top of `scripts/main.gd` (mode, map,
  autopilot, cam, spawn, health, explode, shot, frames, dummies...).
- CI (`.github/workflows/build.yml`) runs the tests and exports Windows + Android builds
  on every push. Check with `gh run list -R agnorance/choppa -b <branch>`.

## Skills (`.claude/skills/`)

- `screenshot`: take and judge screenshots of the game (views, arguments, pitfalls).
- `blender-assets`: regenerate or change textures and models made in Blender.
- `add-item`: add a new item (box pickup) end to end.
- `add-map`: add a new arena.
- `sound`: synthesize, tune and wire up sound effects.
- `ship`: test, document, commit and push a change, then watch CI.

## Code rules

- A choppa only reads a `PilotInput`; keep input sources (keyboard, touch, network, bots)
  out of `choppa.gd` so multiplayer stays straightforward. The simulation (`Choppa.step`)
  must stay independent of visuals (`ChoppaModel` is purely visual).
- Maps and models are built from primitives in code or Blender scripts; keep scene files
  minimal. Maps extend `GameMap`; reusable pieces live in `MapKit`; terrain is `Terrain`.
- Particles: use `Effects.puffs()`. On the Compatibility renderer `BILLBOARD_PARTICLES`
  drops per-particle scale, and CPUParticles3D default gravity pulls puffs into the ground.
- Effects with world-space particles must start emitting only after the caller placed
  them (see `Effects.Explosion._start`), or they burst at the origin.
- Very bright HDR colours wash out to cream under AgX tone mapping; keep fire colours
  near 1 and saturated.
- `Graphics.quality` (LOW / MEDIUM / HIGH) decides how much detail to spend. Headless
  runs are LOW (no grass), the Compatibility renderer is LOW, phones MEDIUM, desktop HIGH.
- Sounds come from `tools/audio/make_sounds.py` (numpy only): synthesized, committed as
  `assets/sounds/*.wav`. Loops (`*_loop`) need `edit/loop_mode=2` in their `.import`.
  Play them through `Sounds` (`scripts/sounds.gd`). Nobody can listen in the cloud:
  ask the owner how new sounds feel and tune the generator.
- Textures/models come from Blender scripts in `tools/blender/` (`pip install bpy==5.2.2`).
  Generated files are committed. Texture `.import` files must keep VRAM compression and
  mipmaps (and `normal_map=1` for normal maps). Details: the `blender-assets` skill.
- Known harmless noise: the test run ends with "3 resources still in use at exit"
  (an audio playback still registered when the headless run quits).
- Match the surrounding code: GDScript with static types, `##` doc comments on classes
  and public members, comments explain why rather than what.
