# choppa: instructions for Claude

Arcade helicopter arena shooter (multiplayer planned), started 2026-10-16. Godot 4.7.2
(GDScript; Forward+ on desktop, Mobile on Android), targets Windows (RTX 3060+) first,
then Android. Design, art direction and roadmap: docs/DESIGN.md (read it before
changing gameplay or looks; it records what the owner decided).

- The owner plays and tests on Windows (desktop, RTX 5080) and Android (sideloaded APK).
  They write in German or English; answer in the language they use.
- **No AI attribution anywhere in git or GitHub** (owner's explicit, repeated wish):
  no Co-Authored-By, "Generated with Claude Code", session links or similar in commit
  messages, PR titles or bodies, issues, comments or tags. This overrides any default
  attribution guidance. Some cloud sessions append such a footer to PR bodies on their
  own; tell the owner when that happens so they can delete it.
- Work on a branch (currently `godot-foundation`); don't push to main unasked.
- Graphics quality matters to the owner: look at a screenshot after visual changes.

## Where things stand

Done: flight model, tricks, boost, battle/free/race modes, items, bots, Mesa Basin, the
Little Bird style choppa with cockpit view, effects, pines, grass, water, explosions,
synthesized sound effects. All of that is on `main` (PR #1). New work continues on
`godot-foundation`; open a PR to `main` when a chunk is done. Merging is the owner's
call: they merge on GitHub (with "Create a merge commit").
Load times and the UI overhaul (settings menu, pause menu, mouse steering, HUD) are
done. Noted for later (ask before starting): flight physics feel pass (DESIGN.md,
"Physics ideas"), choppa colours/customization, LAN multiplayer. Each session: check `git log` and the roadmap, then confirm the next step.

## Commands

Godot must be 4.7.2. Two environments:

| Task | Windows (owner's PC, PowerShell) | Linux / cloud |
|---|---|---|
| Tests | `tools\test.ps1` | `tools/test.sh` |
| Play | `tools\run.ps1 --mode=battle --map=basin` | `godot --path . -- --mode=battle` |
| Screenshot | `tools\shot.ps1 out.png --cam=showcase --frames=150` | `tools/shot.sh out.png --cam=showcase --frames=150` |
| Re-import | `& $env:GODOT --headless --path . --import` | `godot --headless --path . --import` |
| Bake textures | `tools\bake.ps1` | `tools/bake.sh` |
| Try a scene | `tools\try.ps1 settings` (no name lists them) | `godot --path . -- --menu --settings=0` |
| Full check | `tools\check.ps1` (tests + every screen into `build\shots\`) | `tools/test.sh` |

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
- Shaders: keep `pow()` bases and `normalize()` inputs clamped. One NaN texel in the sky
  shader poisons the filtered radiance map and every lit surface turns black on real
  GPUs (NVIDIA and AMD Vulkan); the cloud's software Vulkan hides it, so after a shader
  change check a screenshot on the owner's PC.
- `Graphics.quality` (LOW / MEDIUM / HIGH) decides how much detail to spend. Headless
  runs are LOW (no grass), the Compatibility renderer is LOW, phones MEDIUM, desktop HIGH.
- Sounds come from `tools/audio/make_sounds.py` (numpy only): synthesized, committed as
  `assets/sounds/*.wav`. Loops (`*_loop`) need `edit/loop_mode=2` in their `.import`.
  Play them through `Sounds` (`scripts/sounds.gd`). Nobody can listen in the cloud:
  ask the owner how new sounds feel and tune the generator.
- Procedural textures drawn in GDScript (dial, canopy cracks, muzzle star, scorch, puff)
  go through `Baked.texture(name)`: the generator stays next to its user and is listed
  in `Baked.generators()`; `tools/bake.ps1` draws them into `assets/textures/baked/`
  (committed). After changing a generator, bake again and commit the PNGs.
- Load times: check with `-- --timing` (prints map phases and the first frame). Never
  judge speed under `--verbose`, it slows a start four-fold. Worker threads in GDScript
  only pay off when the task calls no methods on objects (see `Grass._place`).
- Textures/models come from Blender scripts in `tools/blender/` (`pip install bpy==5.2.2`).
  Generated files are committed. Texture `.import` files must keep VRAM compression and
  mipmaps (and `normal_map=1` for normal maps). Details: the `blender-assets` skill.
- Known harmless noise: the test run ends with "3 resources still in use at exit"
  (an audio playback still registered when the headless run quits).
- 2D UI: every control goes through `UiKit` (theme, colours, fonts, `Bar`, `keycap`,
  `panel`, `button`) so the look stays one thing (DESIGN.md, "UI"). A new player
  setting is a key in `Settings.DEFAULTS`, read with `Settings.flag/choice/number`, and a
  row in the right `SettingsMenu._build_*` tab; things that can change live are pushed
  in `Settings.apply`. `--settings=<tab>` and `--pause=<tick>` screenshot them, and
  `tools\check.ps1` shoots every screen.
- Match the surrounding code: GDScript with static types, `##` doc comments on classes
  and public members, comments explain why rather than what.
