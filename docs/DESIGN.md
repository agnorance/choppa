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
  terrain. MEDIUM and LOW presets for weaker PCs.
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
- Cockpit view (`make_cockpit.py` + `cockpit_parts.py` + `scripts/cockpit.gd`): one
  interior per class (owner 2026-10-17: "individual and way more detailed and
  realistic"), each with its canopy frame, seat and harness, pedals, stick and
  collective, side consoles with switch fields and breakers, wiring, placards. Scout:
  the Little Bird's compact pedestal panel of aged round gauges, amber radar scope,
  reflector gunsight. Gunship: an Apache style tandem tub, two multi-function displays
  (flight and radar pages) under a glare hood, standby gauges, a helmet-style HUD.
  Heavy: a Hind pilot's bubble, a wide panel of three rows of round instruments in
  Soviet turquoise, an overhead panel, the gunner's glazed nose below. Striker: a
  Ka-52 style side-by-side glass cockpit, the pilot on the left, four displays, a HUD
  combiner, a centre console with a keypad. Mule: Chinook style, the pilot on the
  right, five displays, an overhead console, a flat two-pane windscreen. The panels sit in the bottom of the view
  at the default FOV; free look (Alt) shows the rest. The 2D HUD steps back.
- Choppa effects: star muzzle flashes with light from the gun that fired, brass casings,
  heat shimmer behind the exhausts, a downwash ring on the ground (spray over water),
  and canopy cracks that spread as the hull takes damage (seen from inside too).
- Pines (`make_trees.py`): tapered bark trunks with whorls of drooping branches, crossed
  needle-spray cards with crown-shaped normals, swaying in the wind
  (`shaders/foliage.gdshader`).
- Grass (`scripts/grass.gd`): tufts of real blades in MultiMesh chunks on flat dry
  ground, fading out at 110 m (55 m and sparser on MEDIUM, none on LOW). Gusts roll
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

## Death (2026-10-17)

A shot-down choppa blows up and leaves its charred body (`Effects.Wreck`): it tumbles
down, lands, burns with a smoke column and fades after half a minute (visual only, no
collision). The kill feed and the shot-down screen name the cause (gunned down,
rocketed, missile, mined, crashed, hard landing, rotor strike, burned out, power line;
`Choppa.cause`). Until you respawn the camera turns to whoever shot you down (kill cam).

## Time of day (2026-10-17)

Settings, Graphics tab: Afternoon (the golden hour every map was made in), Dusk or
Night, for the next match (`--time=` for screenshots). `MapKit.TIMES` holds each look:
sun pitch, colour and strength, the sky's colours, cloud light, stars, fog, exposure,
ambient, and the water's faked sky reflection and foam. At night every choppa carries a
searchlight under its nose: it lights the way and gives you away.

## Brand (2026-10-17, owner: "the logo is quite shitty currently")

`tools/brand/make_brand.py` builds everything into `assets/brand/`: the wordmark
(CHOPPA in chamfered block letters leaning 12 degrees forward, a level rotor blade
over the top on a mast out of the O; orange with a light rotor, plus all-light, ink
and all-orange variants), the mark (the same C under the same rotor on a dark rounded
tile with an orange keyline: the app icon, `icon.svg`, `icon.ico` for Windows, PNGs 16
to 1024 px), a lockup, a 1280x640 social banner and the boot splash. Colours: orange
#FF9E33 (UiKit.ACCENT), ink #121418, light #F0F2F5. Type: Barlow Condensed. The title
screen shows the wordmark (`UiKit.logo`).

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
  distance, camera shake, default view, HUD size, damage flash, aim assist, controls
  overlay. Flight: the flight model and six assists, each on or off (owner 2026-10-17,
  "like Wardogs"): auto-level, auto-hover, altitude hold, coordinated turns, landing
  assist, engine auto-start; the beginner set (level, landing, start) is on by default.
  Controls: mouse steering, mouse layout, sensitivity, mouse vertical, invert, roll /
  pitch / yaw rate for keys and pad (roll 60 % by default: "A and D roll way too fast"),
  key stick ramp, gamepad deadzone; beside them every keyboard and mouse binding, click
  to change (`Controls.REBINDABLE`, Settings "bindings"; the gamepad keeps its layout).
  Audio: master, effects and music. Saved by `Settings` (one dictionary, `DEFAULTS`
  lists every key) in `user://settings.cfg`; the tests save to their own file.
- **HUD:** a head-up flight display framed round the middle (owner 2026-10-17, from
  a reference shot): heading tape over the top, speed tape left with the climb rate,
  altitude tape right, a pitch ladder that banks; thin near-white lines, the small
  gunsight and target brackets in amber (red with LOCK). Radar bottom left over the
  hull (heading up, 300 m), ammo panel bottom right (rounds and heat, one icon per
  missile, rocket tubes, pips for flares, mines, smoke). Both the flight display and
  the radar are settings. Kills/rank/time top centre, class and effects top right,
  boost bottom centre. Call-outs in amber. The controls overlay (key caps) sits over
  the ammo panel, toggled in settings or with F1. The cockpit view hides it all but
  the sight, which is drawn to fit the cockpit's reflex sight glass.
- **Pause** (Esc / Start): resume, settings, restart, main menu, quit; the match stops.
- **Mouse flying:** pitch and roll (or pitch and yaw, a setting), captured while
  flying and released in menus and on the results screen.

## Game feel (decided)

**Easy to pick up, very hard to master.**

- Easy: a level choppa with the collective centred hovers by itself, items are one
  button, and the assists (on by default: auto-level, landing assist, engine auto-start)
  catch beginners. Crashes are real (owner 2026-10-17: "more realistic"): see Collisions.
- Deep: the flying itself (owner's request after the first build: free controls, no
  help, Wardogs-like): momentum, tilt-to-accelerate, energy in dives and climbs,
  rolls timed against bullets and missiles, item tactics, reading the arena.
- Rule for new features: they may add depth for experts, but must not make the first
  minute harder than the settings can make it easy.

## Platform and tech (decided)

- **PC only (decided).** Windows first; the owner dropped phones. Keyboard and mouse,
  and gamepads.
- **Engine:** Godot 4.7, GDScript, Forward+ (Vulkan or D3D12), automatic fallback to the
  Compatibility renderer on machines without Vulkan.
- **Camera:** third person from right behind the choppa, with a first-person cockpit view
  toggle.
- **Builds:** GitHub Actions runs the tests and exports a Windows build on every push.
- **Distribution (proposal):** Steam. It gives accounts, friends, purchases and
  anti-tamper for free, and PC players expect it.

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
  nose by itself unless an assist is on (`Choppa.ASSIST_*`, sent to the server with the
  hello so it flies the seat the same way): auto-level and auto-hover act with the stick
  centred, altitude hold with the collective centred, coordinated turns with the pedals
  centred; landing assist holds the sink rate near the ground to what the skids take.
- **Afterburner:** Shift / RB. About two seconds of charge, back in five when off;
  the HUD bar shows it. The TURBO item is a stronger burst.
- **Ground effect:** a little extra thrust in the last six metres. **Translational
  lift:** up to 12 % more thrust at airspeed (full at 25 m/s), so a moving choppa needs
  less collective and a hover is the hardest place to hold height.
- **Ceiling:** no climbing above the map's ceiling.
- Collisions bounce you off walls, stun you briefly and kill most of the spin. A crash
  costs a share of the hull whatever the class: nothing below 6 m/s into the obstacle,
  all of it at 32 (25 m/s nearly kills), at most once every 0.4 s. On the ground the
  sink rate counts (5 m/s is safe, 13 flattens you) and sliding faster than 14 m/s
  grinds the hull. **Rotor strikes:** the blade disc (75 % of its radius, per class in
  `Airframe` "rotor") touching a wall, a roof or the ground costs the rotor 60 % and
  the hull 12 %, shoves you off and throws the body over; a wrecked rotor that strikes
  again comes apart. A choppa on its side on the ground burns out after 2 s. Races
  ignore rotor strikes. A crash soon after being shot credits the shooter. Bots feel
  around their rotor disc and brake for walls.
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

### Engine and ground starts (owner, 2026-10-17: "like Wardogs")

- Everyone starts a match (and a new online round) on the ground with the engine off.
  Throttle up (or I) starts it: the rotor spools up over about 3.5 s and lifts from
  55 % rpm. Respawns after being shot down come back with the engine running.
- I switches the engine off and on in flight too: the rotor runs down over 7 s and you
  come down (some autorotation lift in the realistic model). No rpm, no control.
- Easy model keys are separate from the rest: W/S forward and back, A/D strafe, Q/E or
  the mouse turn, Space/C climb and dive. (C used to drive backwards as well.)
- Choppas resting on their skids no longer gather downward speed (they had to burn
  it off before lifting, and bots skimming the ground were slowed by it).

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
- **Snappy but heavy** (owner, 2026-10-17): rounds fly at 380 m/s (about 300 m reach),
  so hits land as you line up. The guns cross on the nose line 150 m ahead, where the
  pipper sits, and with aim assist they lead the target (owner: "full on target, I
  don't hit anything": the rounds went where the target had been). Every round punches the camera (a short kick and FOV
  pulse, scaled by the camera shake setting), a long burst rumbles and drags the
  choppa back a little (recoil), and the spread blooms as the barrels heat up (from
  0.2° cold to about 1.4° hot), so bursts beat holding the trigger. Hot barrels smoke.
  The spread is a fixed spiral, not random, so server and clients agree.
- A belt of rounds per class (Scout 300, Gunship 400, Heavy 500), refilled at stations.
- Aim assist (setting, **off by default** on desktop): rounds snap to a choppa inside a
  12° cone ahead, out to 200 m (brackets on the HUD). Bots use it. Smoke (a 24 m cloud
  for 12 s) hides whoever is inside it and blocks every lock that would look through it.
- Overheats after ~6 s of continuous fire (owner: 2.3 s was far too soon), then cools down.
- Rolling hard dodges bullets.

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
| Machine gun | 300 / 400 / 500 | 12.5 rounds/s, 4 damage, overheats (see Machine gun). |
| Rockets | 8 / 14 / 20 | Unguided, fast, 12 damage plus a small blast, hit the part they strike. Alternate pods. |
| Missiles | 1 / 2 / 3 | Lock by keeping the target on the nose (8° cone, pitch counts) for 1.2 s, out to 300 m; the lock fades if it slips out (12°) or behind smoke. Fired locked they chase it hard and hit unless shaken off; unlocked they fly straight. 35 damage and a big shove. |
| Flares | 3 / 2 / 4 | Break every missile lock on you; the missile flies wide. Rolling hard also works. |
| Mine | 1 | Dropped below, arms after 1 s, 40 damage blast. Good for denying a station. |
| Smoke | 1 | Cloud for 9 s: nobody inside can lock on or be locked on. |

- Keys: LMB / Ctrl gun, RMB rockets, F missile, X flares, R mine, G smoke (gamepad:
  RT gun, LT rockets, RB missile, B flares, X mine, D-pad down smoke; afterburner moves to
  LB / Shift).
- **Placement is tactical** (owner, 2026-10-17): repair pads are few and exposed or
  awkward (Mesa Basin: on top of the mesa, down in the trench, in a clearing in the
  hoodoo field; Slot Canyon: the open camp and mid-canyon). Ammo pads are quick and
  in cover (behind the arches, beside the trench bridge, on the lake shore; the canyon
  ends). New cover: tall pillars between the basin's arches, rock pillars on the
  canyon floor, power lines strung across the basin trench.
- **Ammo stations** (owner's request): blue lamp and rim, crates by the mast. They only
  rearm (no repairs), in 2 s, and are back after 20 s. Two per battle map, between the
  repair pads, and one on the test range.
- Bots land at a station when hurt or low on ammunition (an ammo station only when not
  hurt), fire rockets at close range,
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

### Feel apart (owner, 2026-10-17)

The classes differ in every system, not only the numbers on the hangar card:

| | Scout | Gunship | Heavy |
|---|---|---|---|
| Turn / response | 1.2x, snappy | 0.85x | 0.55x, slow to settle |
| Top speed, climb | 1.12x, 1.2x | 0.92x, 0.95x | 0.76x, 0.7x |
| Engine start | 2.5 s | 3.5 s | 5 s |
| Gun | fast light rounds (0.8 dmg, 0.064 s) | 1.2 dmg, 0.08 s | cannon rounds (2.2 dmg, 0.116 s), big kick |
| Hull | 100 | 140 | 200 |
| Sound | higher, buzzing | | deeper, droning |

Overheating takes about 6 s for all of them (heat per round scales with the interval).

**Striker** (fourth class, 2026-10-17): a coaxial attack helicopter, Ka-52 in spirit.
Two counter-rotating rotors and no tail rotor, so a wrecked tail only dulls the yaw and
never spins it. Quick (1.05x turn, 1.04x speed), hull 125, twin 30 mm (1.5 damage,
0.096 s), 10 rockets, 2 missiles, 3 flares, engine start 3 s, a lower voice.

**Mule** (fifth class, 2026-10-17): a tandem-rotor transport gunship, Chinook in
spirit. Two big rotors fore and aft turning against each other, no tail rotor; both
discs count for rotor strikes (Airframe "rotor2"). The slowest to turn (0.5x) but not
the slowest in a straight line (0.86x), the toughest (hull 230, parts 2.2x), door
miniguns (700 rounds, quick and light), no rockets but 4 missiles and 6 flares, a 5.5 s
engine start and the deepest voice. Its cockpit: a Chinook style side-by-side glass
cockpit, the pilot on the right, five displays, a big overhead console.

## Maps

Enclosed arenas: cliffs or walls all round that rise above the flight ceiling. Plenty of
cover, tunnels to dive through and height differences. Built from a heightmap terrain
plus modular pieces (`MapKit`: mesas with tunnels, arches, hoodoos, ruins, trees,
boulders, water, props from Blender), so new maps are mostly a height function and
placement. Every map has service stations.

- **Mesa Basin** *(exists)*: desert basin ringed by sandstone cliffs; central mesa with
  crossing tunnels, ring of ruined arches, a trench for sneaking up low, a lake, hoodoo
  field, pine groves.
- **Slot Canyon** *(exists)*: a 900 m S-shaped canyon through a 150 m plateau, the floor
  50 to 120 m wide with a shallow river and gravel banks, terraced walls far above the
  85 m ceiling. An old mining camp in the wide bend (headframe, water tower, shacks,
  fuel tank, crates), a timber trestle across the narrows, two natural arches spanning
  the canyon, power lines strung across it twice and along the camp, gusting
  crosswinds in two narrows, four service stations. Props from Blender
  (`tools/blender/make_props.py`).
- **Test range** *(exists)*: open field with two tunnels; also the race course.
- Later: **Quarry** (terraced pit, cranes, conveyor bridge), **Dam** (spillway tunnels,
  pylons and power lines), **Ruined Town** (streets as corridors, towers, a hangar).

### Rust Harbor (2026-10-17, owner: "lots of obstacles for manoeuvring and cool fights")

A derelict port between two concrete quays, hills all round. West quay: a maze of
container stacks one to four high (alleys to thread, stacks to hop, a clearing with a
repair pad in the middle), five gantry cranes with their booms over the water, three
warehouses open at both ends (fly through; one ammo pad sits inside one). In the
basin: a moored freighter and a sunk one. East quay: fuel tanks, a radio mast, a
warehouse, three jetties, a repair pad out in the open. A power line spans the water
at the south end. Containers are MultiMeshes with one box shape per stack, so the
yard stays cheap. Props from tools/blender/make_props.py.

Second pass (owner, same day: "lacks obstacles... way more, but in a natural way, so
players can use it tactically"): three layers. Low: a freight line with container
trains along the back of the west quay, waiting rows under the cranes, scrap heaps in
the south-east, a tetrapod breakwater half closing the basin's north end. Middle:
straddle carriers parked over the yard alleys, a walkway between the southern
warehouses at 8 m, pipe racks, two conveyor bridges at 16 m out of a grain terminal.
High: eight silos, fifteen floodlight masts, a lighthouse, a tall empty-container
depot in the south-west, a freighter in dry dock. The basin got a second freighter,
four tugs, two container barges and a buoy line: the fast, exposed way across.

### Big cover (2026-10-17, owner: "bigger structures... to fly through or hide behind")

Mesa Basin: two giant natural arches (80 m across, 40 high), one standing in the lake,
one in the hoodoo field, and three clusters of rock towers in the open. Slot Canyon:
three rock arches fallen across its narrows, to fly under or climb over. Iron Dam: an
old railway viaduct across the valley, its deck 30 m up on piers 50 m apart, and rock
spires rising out of the reservoir. All of it breaks line of sight (and missile locks)
and gives a fight something to turn around.

### Iron Dam (2026-10-17)

A river valley shut by a 57 m concrete dam. North: the reservoir, its water 38 m up
and close under the crest, drowned trees and rock islands, narrow shore terraces with
spawns and an ammo pad. The dam: a thick base and a thinner upper wall with three
spillway openings (18 m wide, 40 to 52 m up) to fly through from lake to valley, the
crest road with a repair pad in the middle and an ammo pad, gate towers at both ends.
South: the old river bed, the power station at the dam's foot (repair pad on its roof)
with three penstock pipes down the dam face and a tank yard, one transmission line down
the valley and one strung across it, a ruined hamlet, wrecks, a radar post. High and
exposed over the lake, or low and fast along the river: the routes cross at the dam.

### Obstacle kit

- **Power lines** *(exist, `Hazards.power_line`)*: three thin cables between lattice
  pylons, sagging, hard to see against the sky. The rotor disc touching one takes 60
  rotor damage; any touch throws you back and costs 25 hull. Bots steer under them.
- **Wind** *(exists, `Hazards.wind`)*: gusting zones that push choppas sideways,
  shown by blowing dust.
- **Tunnels**, arches, bridges *(exist)*.
- Later: moving obstacles (trains, blast doors), destructible towers, night variants.

## Multiplayer (decided: internet from the start)

No LAN-first detour: the owner wants internet play from the beginning. Ranked play and
the world #1 skin need a server nobody can tamper with, so the server is authoritative.

- **Dedicated servers.** A headless Godot build of the game runs the simulation on a
  Linux server; players are clients. Private matches can also run on a player's PC
  (listen server) for testing and friends, with the same code.
- **Transport:** UDP via Godot's ENet (`ENetMultiplayerPeer`), one channel reliable for
  events (kills, stations, chat), one unreliable for inputs and snapshots.
- **Tick:** the server simulates at 60 Hz. Clients send their `PilotInput` every tick,
  stamped with the tick number. The server sends snapshots at 30 Hz (positions,
  attitudes, velocities, health, parts, ammo, weapon objects), delta-compressed
  against the last snapshot the client acknowledged.
- **Own choppa:** predicted on the client (it runs `Choppa.step` on its own inputs) and
  reconciled when the server's snapshot disagrees: rewind to the server state, replay
  the unacknowledged inputs. This is why the simulation only reads `PilotInput` and
  stays independent of visuals.
- **Other choppas:** interpolated about 100 ms in the past between snapshots.
- **Hits:** decided on the server, with lag compensation for the gun and rockets
  (rewind the targets to what the shooter saw, capped at 200 ms).
- **Backend** (accounts, matchmaking, parties, leaderboards, progression, store):
  [Nakama](https://heroiclabs.com/nakama/) (open source, self-hostable, has a Godot
  client), or Steam's services once the game is on Steam. Accounts: Steam login, or a
  device account during development.
- **Matchmaking:** casual battles (bots fill empty slots) and ranked battles (skill
  rating, no bots). Regions: Europe first, the owner's.
- **Cheating:** the server owns everything that matters (hits, damage, XP, unlocks,
  purchases); the client only renders and predicts.

Steps:
1. *(done)* Determinism: the simulation steps on the fixed tick only (no frame times),
   and a test replays an input log and gets the same flight and damage.
2. *(done)* Headless server and direct connect (IP and port), prediction,
   reconciliation and interpolation, tested with simulated latency and packet loss.
3. Backend: accounts, matchmaking, server browser for private matches; a cloud server
   (the owner picks the provider; the Linux server build is ready).
4. Progression on the server (below), then ranked, then the store.

### What exists now (step 2)

- `NetGame` (`scripts/net/net_game.gd`) is the whole netcode, one node with a server
  and a client role, at the same path on every machine. `NetCodec` packs inputs (29
  bytes, the last 4 repeated in every packet so a lost one costs nothing) and choppa
  states (snapshots at 30 Hz, everyone in every snapshot, no delta compression yet).
- The server runs a normal battle. Players take over bot seats (6 seats); a bot takes
  a seat back when its player leaves. Rounds follow each other: 12 s after a round ends
  the server starts the next one on the same field.
- The client predicts its own choppa, and corrects and replays only when the server's
  state at the acknowledged tick differs. Others are drawn 100 ms behind. Damage,
  deaths, scores, stations and ammo come from the server (`authority` is false on
  the client's choppas, battle and stations). Other pilots' rockets, missiles, flares,
  mines and smoke are shown from reliable "fired" events and cannot hurt anyone there.
- XP: the server counts each player's stats and sends them at the round end; the client
  adds them to its own profile (still a local profile until the backend exists).
  Only level camos are shown to others; packs and Apex wait for a server-side
  entitlement check.
- Ways in: Multiplayer on the title screen (name, address, Join; Host a battle), or
  `--host`, `--server`, `--connect=addr[:port]`; `--lag` and `--loss` simulate a bad line.
- Not yet: lag compensation for hits (the server checks hits where things are now, so
  a high ping means leading targets a little), delta compression, a server browser,
  chat, NAT punch-through (hosting at home needs UDP 7777 forwarded).

## Progression, camos and the store (plan)

Two tiers, as the owner wants: **skill earns the rarest looks; money buys style, never
power.** Nothing that changes how a helicopter flies or fights is ever for sale.

### Pilot level

- XP per battle: 100 per kill, 40 per assist (damage within 5 s of the kill), 25 for
  wrecking a part (tail rotor, rotor, engine), 1 per point of damage dealt, 50 for a
  station you denied (served while an enemy was within 150 m), 100 for finishing the
  match, 200 for winning it. First win of the day doubles that match's XP.
- Levels 1 to 100. XP from level n to n + 1: 1000 + 50 x (n - 1), so a level takes
  about one match early on and about four near the top; level 100 is around 250
  matches. Past 100, every further 10 000 XP adds an **Ace star** (shown next to the
  name, no cap).
- Per class, a **class mastery** level (XP earned in that class) unlocks class insignia
  and nose art.
- Ranked play has a separate **skill rating** (Glicko-2), reset softly each season.

### Earned camos (cannot be bought)

Military patterns that say how long and how well you have flown. Each works on every
class.

| Camo | Unlocked by |
|---|---|
| Factory olive | Level 1 |
| Desert | Level 5 |
| Woodland | Level 10 |
| Tiger stripe | Level 20 |
| Splinter | Level 30 |
| Digital | Level 40 |
| Arctic | Level 50 |
| Night ops | Level 60 |
| Veteran (worn steel, kill tallies) | Level 75 |
| Centurion (gold leaf) | Level 100 |
| Ace (black with one gold star per Ace star) | First Ace star |
| Challenge camos (e.g. Butcher: 100 tail-rotor kills) | Challenges |

### Paid packs (style only)

Bright liveries in a different visual family from the earned camos, so nobody mistakes
one for the other.

- **Hangar Pack** (tier 1, about 5 euro): four liveries (Racing, Hornet, Sunset,
  Checkerboard), eight paint colours for any camo, two nose arts.
- **Collector Pack** (tier 2, about 15 euro): everything in the Hangar Pack, plus
  metallic and pearl finishes, coloured rotor tips, a coloured smoke trail, a cockpit
  trinket and a name plate on the boom.
- Packs are cosmetic only: no XP boosts, no weapons, no stats.

### The Apex skin (one player in the world)

- **Apex**: black chrome with molten-gold panel lines, gold rotor tips, a crown on the
  tail and a faint gold heat shimmer. Only one player can wear it: whoever is **#1 on
  the global ranked leaderboard** right now.
- The server grants it as a signed entitlement and takes it back when the player is
  dethroned. Former holders keep a small "Former Apex" badge with the season and date.
- Shown to everyone in the match, so the whole lobby knows who the best pilot is.

### What exists now (built, offline)

The profile, level curve, XP awards, camo catalogue, unlock rules and the hangar are in
the game and tested: `Progression` and `Profile` (scripts/progression.gd), the camos in
the hull shader, the HANGAR screen on the title, XP and level-ups on the results
screen. Until the server exists the profile lives in `user://profile.cfg` and counts
as offline progress (it will not carry over to the online profile). Paid packs and
Apex are entitlements the server grants; offline they can only be previewed
(`--entitle=hangar,collector,apex` for testing).

## Milestones

1. **Foundation** *(done)*: project, flight model, cameras, gun, tests, CI.
2. **Battle mode and first arena** *(done)*: Mesa Basin, bots, effects.
3. **Items** *(done, replaced by 9)*.
4. **Load times** *(done)*: grass on worker threads, baked procedural textures.
5. **UI overhaul** *(done)*: UiKit theme, tabbed settings, pause menu, HUD.
6. **Flight and damage** *(done)*: easy and realistic flight models, modular damage.
7. **Plan after the second playtest** *(done)*.
8. **Helicopter classes** *(done)*: Scout, Gunship, Heavy, with Blender models.
9. **Service stations and loadout** *(done)*.
10. **Slot Canyon** *(done)* with power lines, wind and Blender props.
11. **PC only** *(done)*: phones dropped (owner's decision).
12. **Polish** *(done)*: sounds for rockets, flares, stations, cables, wind, hit markers
    and wrecked parts; hit markers and part callouts; visible damage (the tail rotor
    gone, a wobbling main rotor, a burning engine); a synthesized dieselpunk march for
    the menu and battles on its own Music bus.
13. **Progression foundation** *(done, offline, see above)*: levels, XP, earned camos, hangar.
14. **Internet multiplayer**: steps 1 and 2 *(done)*: host, dedicated server and direct
    connect with prediction. Next: a cloud server (owner picks the provider), then the
    backend (step 3).
15. **Ranked, store and Apex** on the backend.
16. Feel pass on the owner's PC throughout; more arenas and battle variants after.
17. **Cockpit pass, one class at a time** (owner, 2026-10-17, after the cabin rework): a
    debug session per helicopter. Known: in the Gunship the nose is in the way of the
    sight, and in general you see too little from inside (sight lines, seat height,
    frame and panel heights against the exterior).

Every step comes with tests (owner's rule: so we know where something broke).

## Decided after the first build

- Machine gun: yes.
- Control scheme: two flight models. Easy is the original drone; realistic is the default.
- Testing: every feature gets automated tests in `tests/run_tests.gd`.
- Genre: arena shooter first, not a racing game.
