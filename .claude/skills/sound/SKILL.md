---
name: sound
description: Add, change or tune choppa's sound effects and music - recorded library sounds via tools/audio/import_sounds.py and recipes.json, synthesized stand-ins via make_sounds.py - and hook them into the game with the Sounds helper. Use for anything audio - new effects, mix levels, pitch behaviour, loops, music.
---

# Sound effects

The game uses recorded library sounds (owner's decision: synthesis sounded cheap).

## From a library (the normal way)

1. The library (e.g. the Sonniss GDC bundles) lives outside the repo; `CHOPPA_SFX`
   points at it.
2. Find candidates: `python tools/audio/audition.py gun machine gun --exclude silenced
   --length 0.4` writes `build/audition/gun/a.wav ..` and `list.txt`. Pick several per
   sound with different words. The owner listens and picks letters.
3. Put the picks into `tools/audio/recipes.json` (takes, start or "auto", length,
   pitch, loudness, filters, loop + crossfade, channels 2 for music) and run
   `python tools/audio/import_sounds.py gun`. Several takes become `gun_1.wav ..`;
   `Sounds.stream` picks one per play. Output lands in `assets/sounds/library/`,
   git-ignored while the repo is public; never commit those files.
4. Re-import, run the tests, ask the owner to judge it in the game.
5. Python runs without `-I` here: numpy is in the user site-packages.

## Music and the radio

- `tools/audio/make_music.py` synthesizes the techno (CHOPPA FM, the built-in radio
  station) and the menu track as stereo OGG loops (numpy + ffmpeg). Check the mix with
  the band-energy printout idea in its history: laptop speakers need mids and highs.
- `scripts/radio.gd`: stations are CHOPPA FM, one per folder in
  `assets/music/library/<Station>/` (royalty-free mp3/ogg/wav, git-ignored), and off.
  N switches in a match; the choice is Settings "radio_station".

## Synthesized stand-ins

Sounds without a recipe are synthesized by `tools/audio/make_sounds.py` (numpy, no
samples) as `assets/sounds/<name>.wav` (mono, 16-bit, 22050 Hz).

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
explosions and impacts in `Effects`; missile launch and motor, rocket launch and flares
in `Weapons`; station work and done in `ServiceStation`; cable strikes and wind in
`Hazards`; hit marker and part hits in `Hud`; missile lock warning in `Cockpit`.
Music: `Sounds.music(tree, "menu" | "battle" | "")` plays `music_<name>_loop.wav` on
the Music bus (`make_sounds.py` composes it from `_song`). A test checks that every
name passed to `Sounds.*` has a file and that loops loop. Sounds are visuals: keep them out of `Choppa.step`.
