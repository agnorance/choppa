# choppa: instructions for Claude

Arcade helicopter arena shooter (multiplayer planned), started 2026-10-16. Godot 4.7 (GDScript, Compatibility
renderer), targets Windows and Android. Design and roadmap: docs/DESIGN.md.

- The owner plays and tests on Windows (desktop) and Android (sideloaded APK).
- Commits: no AI attribution (no Co-Authored-By or similar lines).
- Work on a branch; don't push to main unasked.

## Working on the project

- Run tests: `godot --headless --fixed-fps 60 --path . --script res://tests/run_tests.gd`
  (`--fixed-fps` runs physics as fast as possible; whole bot races take seconds). After
  adding a new `class_name`, run `godot --headless --path . --import` first.
- Screenshot the game (needs Xvfb): `tools/shot.sh out.png [extra game args]`, e.g.
  `tools/shot.sh out.png --autopilot=forward --frames=120`. Look at screenshots after
  visual changes.
- Game arguments go after `--`; see `scripts/main.gd` for the list. Useful:
  `--mode=battle --map=basin --autopilot=bot` (a bot flies you), `--menu` (title screen).
  The software renderer here is slow (~5 fps), so long screenshots take minutes.
- A choppa only reads a `PilotInput`; keep input sources (keyboard, touch, network, bots)
  out of `choppa.gd` so multiplayer stays straightforward.
- Maps and models are built from primitives in code for now; keep scene files minimal.
  Maps extend `GameMap`; reusable pieces live in `MapKit`; terrain is `Terrain`.
- Particles: use `Effects.puffs()`. On the Compatibility renderer `BILLBOARD_PARTICLES`
  drops per-particle scale, and CPUParticles3D default gravity pulls puffs into the ground.
- CI (`.github/workflows/build.yml`) runs the tests and exports Windows + Android builds.
