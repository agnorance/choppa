---
name: sound
description: Add, change or tune choppa's synthesized sound effects (tools/audio/make_sounds.py) and hook them into the game with the Sounds helper. Use for anything audio - new effects, mix levels, pitch behaviour, loops.
---

# Sound effects

All sounds are synthesized by `tools/audio/make_sounds.py` (Python + numpy, no samples)
and committed as `assets/sounds/<name>.wav` (mono, 16-bit, 22050 Hz).

## Making or changing a sound

1. Add or edit a function in `make_sounds.py` and list it in `SOUNDS`. Building blocks:
   `noise`, `sine` (fixed or swept frequency), `env` (attack + exponential decay),
   `lowpass` / `highpass` / `bandpass` (cutoff may be a sweep array), `place` (drop a
   short sound into a longer buffer).
2. Loops: build them with `seamless(build, seconds)` so pulses and noise repeat exactly
   over the loop, and name them `*_loop`. Their `.import` must say `edit/loop_mode=2`
   (Godot writes 0 on first import: fix it, then re-import).
3. Run `python tools/audio/make_sounds.py <name>`, re-import, run the tests.
4. Keep energy in the 250-2000 Hz range for anything that must carry on laptop speakers
   (a pure sub-bass rumble is inaudible there). A quick check: the power-weighted
   spectral centroid with numpy's FFT.
5. Nobody can listen in a cloud session. Say what the sound is meant to be like and ask
   the owner to judge it in the game; tune from their words.

## Playing sounds (`scripts/sounds.gd`)

- `Sounds.play_at(parent, name, position, volume_db, pitch, reach)`: 3D one-shot. Pass
  a long-lived parent (map or scene root), not the thing that is about to be freed.
- `Sounds.play_on(node, name, ...)`: one-shot that rides along with a node.
- `Sounds.play_ui(parent, name, volume_db)`: non-positional, for the local player.
- `Sounds.loop_on(node, name, volume_db, reach)`: looping 3D player, caller adjusts
  `pitch_scale` / `stream_paused` every frame (see `ChoppaModel.update_pose`).

Where sounds are wired today: rotor, engine, boost and gun in `ChoppaModel`;
explosions and impacts in `Effects`; missile launch and motor in `Weapons.Missile`;
missile lock warning in `Cockpit`. Sounds are visuals: keep them out of `Choppa.step`.
