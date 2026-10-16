# choppa: design

Living document. Decisions marked **(decided)** came from the owner; everything else is a
proposal that can change after playtesting.

## Pitch

**Arcade arena shooter with helicopters (decided).** Battlefield-style helicopter knife
fights in enclosed desert arenas: canyons, tunnels, power lines and cover. Flying is the
skill (two flight models, easy and realistic), machines break part by part, and the
arena's service stations are what everyone fights over. GET TO THE CHOPPA!

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

Two models, chosen on the title screen ("Flight") or in the settings:

- **Realistic** (default): real forces, arcade numbers, no hand-holding, the owner's
  request after flying the first build (like the helicopters in Wardogs, with some
  weight to it). Built in `Choppa.step`, deterministic and cheap for netcode.
- **Easy** (`Choppa._step_easy`): the first build's drone, kept for newcomers. No
  gravity, hovers by itself, WASD moves and strafes, Q/E or the mouse turn, mouse Y
  aims the nose and the choppa flies where it points (so nose down plus forward
  descends), Space/C climb and dive, the nose capped at about 45 degrees. The body
  leans into the motion. Rolling hard is not a thing here, so missiles cannot be
  shaken off.

The realistic model:

- **Forces:** gravity; rotor thrust along the body's up axis (collective 0 holds a
  level hover, +-1 adds or takes 60 %); the afterburner along the nose; drag per body
  axis, lowest along the nose, so the choppa flies best the way it points and slides
  in a turn. Tilting the nose down is what accelerates you; bank to slide sideways;
  a hard pull makes a loop, a hard roll a barrel roll. No scripted moves.
- **Attitude:** the stick asks for rotation rates (pitch 2.0, roll 2.8, yaw 1.6 rad/s
  at full deflection) and the body follows with inertia (7 rad/s^2). Thrust follows
  the collective with a 0.35 s lag. That inertia and lag, plus low drag across the
  body so it keeps sliding, are the "weight" the owner asked for. Nothing levels the
  nose by itself. *Flight assist* (setting, off by default) adds auto-level and
  height hold.
- **Afterburner:** Shift / RB. About two seconds of charge, back in five when off;
  the HUD bar shows it. The TURBO item is a stronger burst.
- **Ground effect:** a little extra thrust in the last six metres. **Translational
  lift:** up to 12 % more thrust at airspeed (full at 25 m/s), so a moving choppa needs
  less collective and a hover is the hardest place to hold height.
- **Ceiling:** no climbing above the map's ceiling.
- Collisions bounce you off walls, stun you briefly and kill most of the spin. Any
  impact over 8 m/s costs health (2 per m/s above that), at most once every 0.4 s so
  scraping along terrain is not instant death. On the ground only the sink rate counts
  and the skids drag you to a stop, so landings are safe below 8 m/s. A crash soon
  after being shot credits the shooter.
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

### Damage model

Hits land somewhere. Bullets and blasts are attributed to the part of the body they
struck (`Choppa.part_at`), collisions to the part that touched first:

| Part | Health | When wrecked |
|---|---|---|
| Hull | 100 | Shot down. Everything else costs hull too (part hits 60 %). |
| Main rotor | 40 | Lift down 15 %, the whole machine shakes (random pitch and roll). |
| Tail rotor | 30 | The main rotor's torque spins you (2.2 rad/s at hover, more with collective); the pedals keep 25 % authority. |
| Engine | 50 | Thrust down 35 %: you sink at hover collective; no afterburner. |

Effects scale with wear, so a half-wrecked part is half as bad. Tail strikes wreck the
tail rotor, and a body banked or pitched past 35 degrees has its blades in whatever
it hits. Repair kits fix parts as well as hull. Smoke pours from a wrecked tail rotor
and engine; the HUD shows the three parts under the hull bar.

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

## Service stations and loadout (decided, replaces item boxes)

The owner did not like Mario Kart pickups. Instead every arena has a few **service
stations**: lit helipads with a mast.

- Set down on the pad (skids within 3 m of it, below 4 m/s) and the station works on
  you: hull and parts repair, ammunition refills, over about 4 s. You are a sitting
  duck while it does.
- Afterwards it **powers down for 45 s** (light red), for everyone. Taking a station
  somebody else needs is a tactic; camping one is not possible.
- **Loadout**, refilled only at stations:

| Weapon | Ammo | What it does |
|---|---|---|
| Machine gun | unlimited | 12.5 rounds/s, 4 damage, overheats (see Machine gun). |
| Rockets | 8 / 14 / 20 | Unguided, fast, 12 damage plus a small blast, hit the part they strike. Alternate pods. |
| Missiles | 1 / 2 / 3 | Lock on in a 45° cone, chase the target, 35 damage and a big shove. |
| Flares | 3 / 2 / 4 | Break every missile lock on you; the missile flies wide. Rolling hard also works. |
| Mine | 1 | Dropped below, arms after 1 s, 40 damage blast. Good for denying a station. |
| Smoke | 1 | Cloud for 9 s: nobody inside can lock on or be locked on. |

- Keys: LMB / Ctrl gun, RMB rockets, F missile, X flares, R mine, G smoke (gamepad:
  RT gun, LT rockets, RB missile, B flares, X mine, D-pad down smoke; afterburner moves to
  LB / Shift).
- Bots land at a station when hurt or out of ammunition, fire rockets at close range,
  missiles with a lock, flares when a missile closes in.
- Gone with the item boxes: turbo, fake box, scrambler, shield, GET TO THE CHOPPA (the
  name stays as the battle cry). Health crates are replaced by stations too.

## Helicopter classes (decided)

Pick one on the title screen. Same controls, different numbers; each has its own model.

| Class | Model | Hull | Speed and handling | Loadout |
|---|---|---|---|---|
| **Scout** | Little Bird (the original) | 100 | Fastest, sharpest rates, lightest: drifts most | 8 rockets, 1 missile, 3 flares |
| **Gunship** | Slim tandem attack helicopter | 130 | Middle | 14 rockets, 2 missiles, 2 flares |
| **Heavy** | Armoured twin-engine transport | 170, parts 1.8x tougher | Slow, heavy, sluggish, big target | 20 rockets, 3 missiles, 4 flares, double gun |

Bots pick classes at random (seeded per name), so matches mix them.

## Maps

Enclosed arenas: cliffs or walls all round that rise above the flight ceiling. Plenty of
cover, tunnels to dive through and height differences. Built from a heightmap terrain
plus modular pieces (`MapKit`: mesas with tunnels, arches, hoodoos, ruins, trees,
boulders, water, props from Blender), so new maps are mostly a height function and
placement. Every map has service stations.

- **Mesa Basin** *(exists)*: desert basin ringed by sandstone cliffs; central mesa with
  crossing tunnels, ring of ruined arches, a trench for sneaking up low, a lake, hoodoo
  field, pine groves.
- **Slot Canyon** *(next)*: a long winding canyon a few rotor spans wide with side
  alcoves, a shallow river, natural bridges and an old mining camp (trestle, water tower,
  shacks, power lines strung across the canyon). Forces low, tight flying.
- **Test range** *(exists)*: open field with two tunnels; also the race course.
- Later: **Quarry** (terraced pit, cranes, conveyor bridge), **Dam** (spillway tunnels,
  pylons and power lines), **Ruined Town** (streets as corridors, towers, a hangar).

### Obstacle kit

- **Power lines** *(next)*: thin cables between pylons, hard to see against the sky.
  Touching one with the rotor wrecks it; with the body, it snaps you back and hurts.
- **Wind** *(next)*: gust zones in canyons that push you sideways, shown by blowing dust.
- **Tunnels**, arches, bridges *(exist)*.
- Later: moving obstacles (trains, blast doors), destructible towers, night variants.

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

1. **Foundation** *(done)*: project, flight model, cameras, gun, touch, tests, CI.
2. **Battle mode and first arena** *(done)*: Mesa Basin, bots, effects.
3. **Items** *(done, being replaced by 9)*.
4. **Load times** *(done)*: measured with `--timing`; grass on worker threads, baked
   procedural textures. Map 1.7 s to 1.1 s, first frame 4.1 s to 3.6 s on the owner's PC.
5. **UI overhaul** *(done)*: UiKit theme, tabbed settings, pause menu, HUD.
6. **Flight and damage** *(done)*: easy and realistic flight models, modular damage
   (rotor, tail rotor, engine, hull), safe landings, bot difficulty.
7. **Plan after the owner's second playtest** *(this list)*.
8. **Helicopter classes**: Scout, Gunship, Heavy, with Blender models.
9. **Service stations and loadout**: replace item boxes and crates; rockets, missiles,
   flares, mine, smoke; bots use them.
10. **Slot Canyon** with power lines, wind and Blender props.
11. **Feel pass** on real hardware: flight numbers, sound mix, hit markers, music.
12. **LAN multiplayer**, then more arenas, internet play, colours and customization.

Every step comes with tests (owner's rule: so we know where something broke).

## Decided after the first build

- Machine gun: yes.
- Control scheme: two flight models. Easy is the original drone; realistic is the default.
- Testing: every feature gets automated tests in `tests/run_tests.gd`.
- Genre: arena shooter first, not a racing game.
