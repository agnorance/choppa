# choppa: design

Living document. Decisions marked **(decided)** came from the owner; everything else is a
proposal that can change after playtesting.

## Pitch

**Arcade arena shooter with helicopters (decided).** Mario Kart battle-mode energy in the
air: enclosed arenas with tunnels, trenches, arches and cover, flashy tricks that feed
your boost, a machine gun for everyone, and item boxes full of dirty tricks to fool your
friends. GET TO THE CHOPPA!

## Art direction (decided)

Richly detailed, atmospheric 3D. Reference: **PVKK: Planetenverteidigungskanonenkommandant**
(Bippinbits, also made in Godot): mechanical designs with a WW1/WW2 feel plus a sci-fi
twist, heavy atmosphere, strong lighting and post-processing.

- **Target hardware: desktop with an RTX 3060 or better** (`Graphics.Quality.HIGH`):
  Forward+ with SDFGI, SSIL, SSAO, SSR, volumetric fog, glow, AgX tone mapping, dense
  terrain. Android gets a reduced MEDIUM preset on the Mobile renderer.
- Materials are tileable PBR textures generated in Blender (`tools/blender/`), terrain is
  splatted by slope and height in `shaders/terrain.gdshader`.
- Done: sculpted rock formations (`make_rocks.py`), golden-hour sky and snowy backdrop.
- The choppa (`make_choppa.py`): a single-seat dieselpunk Little Bird. Egg cabin whose
  glass wraps under the pilot's feet, a seven-cylinder radial engine lying flat around
  the mast (fins, rocker boxes, pushrods, ignition harness, exhaust collector), a
  five-blade articulated rotor head, slim boom with T-tail, skids, an AH-6 style weapons
  bench (two machine guns, two rocket pods), riveted access panels and stencils. The
  canopy frame comes from `choppa_shared.py`, which the cockpit uses too, so the view
  from inside matches the outside. Other players see the cockpit through the glass.
- Cockpit view (`make_cockpit.py` + `scripts/cockpit.gd`): mostly window, a compact
  panel on a pedestal in the chin glass (all of it on screen at the default FOV):
  gauges with aged faces, red zones, tapered needles and glass glints in brass bezels,
  amber radar, nixie kill counter, hull lamp bar, ordnance plate, warning lamps,
  missile beacon, and a reflector gunsight above the radar. The 2D HUD steps back.
- Choppa effects: star muzzle flashes with light from the gun that fired, brass casings,
  heat shimmer behind the exhausts, a downwash ring on the ground (spray over water),
  and canopy cracks that spread as the hull takes damage (seen from inside too).
- Pines (`make_trees.py`): tapered bark trunks with whorls of drooping branches, crossed
  needle-spray cards with crown-shaped normals, swaying in the wind
  (`shaders/foliage.gdshader`).
- Grass (`scripts/grass.gd`): tufts of real blades in MultiMesh chunks on flat dry
  ground, fading out at 110 m (55 m and sparser on phones, none on LOW). Gusts roll
  across it and rotor downwash blows it flat around a low choppa.
- Water (`scripts/water.gd`, `shaders/water.gdshader`): scrolling ripple normals over a
  swell, refraction of the lake bed, colour by depth, sky sheen at grazing angles, shore
  foam, and rings plus churned foam under a low choppa (with spray instead of dust).
  The Compatibility renderer gets a plain waving surface.
- Explosions: fireball, lingering smoke column, glowing embers, debris, a flash, a
  shock wave of bent air, a light, a scorch mark on the ground, and camera shake.
  Bullet hits spark off metal, kick up dust and chips from the ground, splash on water.
  Tracers glow.
- Sound (`tools/audio/make_sounds.py`, all synthesized): rotor blade slap and a lumpy
  radial engine (pitch follows rotor speed and lift), boost roar, machine gun rounds,
  impacts on metal, dirt and water, explosions (deeper for bigger blasts), missile
  launch and motor, missile lock warning in the cockpit, item pickup chime. 3D
  positioned, far sounds lose their highs. To tune on real speakers.

## UI (decided)

Modern and slick, nothing unnecessary (owner's request after the first build; it
replaces the earlier idea of worn-metal PVKK-style panels for the 2D layer, which the
3D cockpit already provides). `scripts/ui_kit.gd` holds the whole look: Barlow and
Barlow Condensed (OFL, `assets/fonts/`), near-white text with one amber accent (the
cockpit's), dark translucent panels with 1 px lines, thin bars, no gradients or chrome.

- **Title:** the arena orbits behind a left-aligned column: modes, map selector,
  settings, quit. Version bottom left, navigation hints bottom right.
- **Settings** (`SettingsMenu`, shared by title and pause menu): tabs Video,
  Graphics, Gameplay, Controls, Audio (Q/E or LB/RB switch), each a column of
  `SettingRow`s (name left, value right, left/right to change; mouse, keyboard and
  gamepad), plus Reset to defaults. Video: window mode, resolution, v-sync, FPS limit,
  render scale and upscaler, anti-aliasing, brightness, FPS counter. Graphics:
  quality preset, shadows, GI, ambient occlusion, reflections, volumetric fog, bloom,
  grass ("Auto" follows the preset; `Settings.apply_environment` flips the live
  Environment, the preset and the grass wait for the next map). Gameplay: FOV, camera
  shake, default view, HUD size, damage flash, aim assist, controls overlay. Controls:
  mouse steering, sensitivity, invert, gamepad deadzone, touch controls; key bindings
  beside them on desktop. Audio: master and effects (bus "Effects"). Saved by
  `Settings` (one dictionary, `DEFAULTS` lists every key) in `user://settings.cfg`.
- **HUD:** speed and altitude top left, item top right, kills/rank/time top centre,
  hull bottom left, boost (heat as a hairline) bottom centre. Call-outs in amber.
  The controls overlay (key caps) sits bottom right, toggled in settings or with F1.
  The cockpit view hides the flight readouts.
- **Pause** (Esc / Start): resume, settings, restart, main menu, quit; the match stops.
- **Mouse flying:** pitch and roll (or pitch and yaw, a setting), captured while
  flying and released in menus and on the results screen.
- **Touch:** translucent discs with thin rings; a held button fills amber.

## Game feel (decided)

**Easy to pick up, very hard to master.**

- Easy: a level choppa with the collective centred hovers by itself, items are one
  button, a crash is never instant death. Newcomers can switch on flight assist and
  aim assist in the settings.
- Deep: the flying itself (owner's request after the first build: free controls, no
  help, Wardogs-like): momentum, tilt-to-accelerate, energy in dives and climbs,
  rolls timed against bullets and missiles, item tactics, reading the arena.
- Rule for new features: they may add depth for experts, but must not make the first
  minute harder than the settings can make it easy.

## Platform and tech (decided)

- **Engine:** Godot 4.7, GDScript. Forward+ renderer on desktop, Mobile renderer on
  Android, automatic fallback to Compatibility on devices without Vulkan.
- **Targets:** Windows desktop and Android (sideloaded APK). Gamepad, keyboard and touch.
- **Camera:** third person from right behind the choppa, with a first-person cockpit view
  toggle.
- **Builds:** GitHub Actions exports a Windows zip and an Android APK on every push.

## Flight model (decided)

Real forces, arcade numbers, no hand-holding: the owner wants flying to depend on the
pilot alone, like the helicopters in Wardogs. Built in `Choppa.step`, deterministic and
cheap for netcode.

- **Forces:** gravity; rotor thrust along the body's up axis (collective 0 holds a
  level hover, +-1 adds or takes 60 %); the afterburner along the nose; drag per body
  axis, lowest along the nose, so the choppa flies best the way it points and slides
  in a turn. Tilting the nose down is what accelerates you; bank to slide sideways;
  a hard pull makes a loop, a hard roll a barrel roll. No scripted moves.
- **Attitude:** the stick asks for rotation rates (pitch 2.4, roll 3.6, yaw 2.0 rad/s
  at full deflection) and the body follows with inertia. Nothing levels the nose by
  itself. *Flight assist* (setting, off by default) adds auto-level and height hold.
- **Afterburner:** Shift / RB. About two seconds of charge, back in five when off;
  the HUD bar shows it. The TURBO item is a stronger burst.
- **Ground effect:** a little extra thrust in the last six metres.
- **Ceiling:** no climbing above the map's ceiling.
- Collisions bounce you off walls, stun you briefly and kill most of the spin. Hard
  crashes cost health; a crash soon after being shot credits the shooter.
- Rolling hard (over 2.8 rad/s) throws off bullets and shakes a missile's lock, which
  then veers wide. Pilot skill, not a button.

| Input | Keyboard + mouse (default "pitch & roll") | Alternative "pitch & yaw" | Gamepad |
|---|---|---|---|
| Pitch | Mouse forward/back (or arrows) | Mouse | Left stick Y |
| Roll | Mouse left/right (or arrows) | A / D | Left stick X |
| Yaw | A / D (Q / E) | Mouse left/right | Right stick X |
| Collective | W / S (Space / C) | same | Right stick Y |
| Afterburner | Shift | same | RB |
| Fire | LMB / Ctrl | same | RT |
| Item | R | same | X |
| Camera | V | same | Y |

Touch: left half drag is the cyclic, right half yaw and collective.

### Bots

Bots fly through `Autopilot`: a proportional controller that turns "fly at this
velocity, look there" into stick, collective and pedals. Difficulty (title screen:
Easy / Normal / Hard) scales their skill: speed, aim lead, dodging, trigger discipline.

### Machine gun (decided)

Every choppa has a twin machine gun. In battle it does **light damage plus a little
knockback** (25 hits from full health); in races it only pushes. Items are meant to be
the big hitters.

- Rapid fire (12.5 rounds/s, 4 damage each), tracers, rounds stopped by walls.
- Aim assist (setting, **off by default** on desktop): rounds snap to a choppa inside a
  12° cone ahead (lock ring on the HUD). Bots and touch players use it.
- Overheats after ~2.3 s of continuous fire, then cools down.
- Rolling hard dodges bullets.
- On touch screens it auto-fires while locked on, since the right thumb is steering.

### Moves

There is no trick button any more (owner's decision after flying the first build):
every move is flown. A barrel roll is full roll stick, a loop full back stick, a hard
turn bank plus pedal. Rolling hard still dodges bullets and shakes off missiles.
Later: near-miss and tunnel-threading bonuses that reward daring flying.

## Modes

1. **Battle** *(main mode, first version done)*: free-for-all deathmatch. 100 health,
   respawn after 3 s with a 2 s spawn shield at the spawn point farthest from enemies.
   First to 8 kills wins, or the leader after 5 minutes. Repair kits restore 40 health.
2. Later battle variants: team deathmatch, balloon battle (3 hearts, last choppa flying
   wins), king of the hill, capture the flag, hostage rescue ("GET TO THE CHOPPA").
3. **Race** *(side mode)*: checkpoint race on the test range, kept because it exists.

Bots fill empty slots in every mode. They also let me test multiplayer headless.

## Items ("fool your friends")

Item boxes respawn a few seconds after pickup. Odds depend on the scoreboard: the leader
gets defensive items, those trailing get the strong ones (`Items.TABLE`).

| Item | What it does | Status |
|---|---|---|
| Turbo | Instant speed burst. | done |
| Homing missile | Chases the choppa in a 45° cone ahead; 35 damage and a big shove. A barrel roll as it closes in shakes it off. | done |
| Mine | Dropped behind you, arms after 1 s, 40 damage blast. Your own mine is safe for 3 s. | done |
| Fake item box | Looks like an item box (upside-down "?"), 30 damage blast. | done |
| Smoke screen | Cloud behind you for 9 s: inside, you can't lock on, nobody can lock onto you, and your screen goes dark. | done |
| Control scrambler | Hits the leader: left/right swapped for 5 s. Never rolled by the leader. | done |
| Shield | Bubble that absorbs 40 damage for up to 12 s. | done |
| GET TO THE CHOPPA | Last place only (25% of their rolls): 6 s invulnerable, double gun damage, turbo. | done |
| Winch hook | Grab the choppa in front and steal its item. | idea |
| Decoy flare | Breaks missile locks; held behind you like a banana. | idea |

Bots grab boxes when nobody is close, use items when it makes sense (missiles with a
target, mines and fake boxes with someone behind, shields under fire) and barrel-roll
away from incoming missiles.

## Maps

Enclosed arenas: cliffs or walls all round that rise above the flight ceiling. Plenty of
cover, tunnels to dive through and height differences. Built from a heightmap terrain
plus modular pieces (`MapKit`: mesas with tunnels, arches, hoodoos, ruins, trees,
boulders, water, clouds), so new maps are mostly a height function and placement.
Low-poly, flat-shaded look with strong colours.

- **Mesa Basin** *(exists)*: desert basin ringed by sandstone cliffs; central mesa with
  crossing tunnels, ring of ruined arches, a trench for sneaking up low, a lake, hoodoo
  field, pine groves.
- **Test range** *(exists)*: open field with two tunnels; also the race course.
- Ideas: **Dockyard** (shipping containers, cranes, a warehouse to fly through),
  **Ice canyon** (frozen river, ice caves), **City block** (rooftops, streets, a tunnel).

## Multiplayer

- **Host-authoritative listen server** with Godot's high-level multiplayer over ENet (UDP).
  One player hosts, the others join; clients send inputs, the host simulates and
  broadcasts state.
- Own choppa is predicted on the client for responsive controls; other players are
  interpolated.
- **Phase 1:** LAN with automatic discovery (same Wi-Fi: PC and phones together).
- **Phase 2:** internet play via a small relay/lobby server or Steam networking, so nobody
  has to open ports.
- Optional local split-screen on Windows with gamepads.
- Code is structured for this from day one: a choppa only ever reads a `PilotInput`, so it
  can come from the keyboard, the network or a bot.

## Milestones

1. **Foundation** *(done)*: project, flight model, chase/cockpit camera,
   machine gun, touch controls, tests, CI builds.
2. **Battle mode and first arena** *(done)*: health, damage, death, respawn, deathmatch
   rules, kill feed, scoreboard, combat bots, Mesa Basin, terrain, effects (explosions,
   rotor dust, boost flame, muzzle flash, damage smoke).
3. **Items** *(done)*: missile, mine, fake box, smoke, scrambler, shield, GET TO THE
   CHOPPA, with scoreboard-weighted odds; bots use them.
4. **Load times** *(done)*: Python stays for the offline tools (Blender's API is Python
   only; they run once), GDScript stays for the game (the C++ engine does the heavy
   work). Measured with `--timing` on the owner's PC (RTX 5080), Mesa Basin battle:
   - Before: map 1.7 s (grass 0.52 s, terrain 0.44 s, rocks 0.23 s, backdrop 0.19 s),
     first frame 4.1 s after launch. (The roadmap's 2.5 s came from a `--verbose` run,
     which slows everything four-fold.)
   - Grass on worker threads, one MultiMesh buffer per chunk: 0.06 s. The worker
     reads only plain arrays; any method call on an object from a thread serializes.
   - Procedural textures baked to `assets/textures/baked/` (`tools/bake.ps1`).
   - After: map 1.1 s, first frame 3.6 s. What remains: terrain mesh and collision
     (0.44 s, height function called per vertex), rock meshes, and ~2.3 s between
     the built scene and the first frame (shader and pipeline compilation, SDFGI).
   - Only if profiling ever shows a hot spot (bots, netcode): a GDExtension in C++.
     Not C#: it complicates the Android export.
5. **Feel pass:** the flight model is now force-based (above); tune its numbers on real
   hardware (Windows + Android), then sound mix, camera shake, hit markers. Music is
   still missing.
   **UI overhaul** *(done, see "UI" below)*.
6. **LAN multiplayer:** host/join, discovery, prediction and interpolation.
7. **More arenas** and battle variants.
8. **Internet play**, choppa colours and customization.

## Decided after the first build

- Machine gun: yes.
- Control scheme: keep the current drone-style controls (steering plus separate lift).
- Genre: arena shooter first, not a racing game.
