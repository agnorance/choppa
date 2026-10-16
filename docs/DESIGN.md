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

## Game feel (decided)

**Easy to pick up, very hard to master.**

- Easy: the choppa hovers by itself, the gun has aim assist, items are one button, a
  crash is never instant death.
- Deep: boost economy fed by tricks (double reward flying low), momentum and drifting,
  barrel rolls timed against bullets and missiles, item tactics, reading the arena.
- Rule for new features: they may add depth for experts, but must not make the first
  minute harder.

## Platform and tech (decided)

- **Engine:** Godot 4.7, GDScript. Forward+ renderer on desktop, Mobile renderer on
  Android, automatic fallback to Compatibility on devices without Vulkan.
- **Targets:** Windows desktop and Android (sideloaded APK). Gamepad, keyboard and touch.
- **Camera:** third person from right behind the choppa, with a first-person cockpit view
  toggle.
- **Builds:** GitHub Actions exports a Windows zip and an Android APK on every push.

## Flight model

Arcade, not a sim. The choppa hovers by itself when you let go; everything is about
moving fast and looking good.

| Input | Effect |
|---|---|
| Move (left stick / WASD) | Fly forward/back, strafe left/right. The body tilts into it. |
| Yaw (right stick X / Q E / arrows) | Turn. |
| Lift (right stick Y / Space C / arrows) | Climb and dive. |
| Boost (RB / Shift) | Burn boost meter for top speed. |
| Fire (RT / Ctrl / mouse) | Machine gun. |
| Trick (A / F) + direction | Pull a move (below). |
| Item (X / R) | Use the held item. |
| Camera (Y / V) | Toggle chase / cockpit view. |

Collisions bounce you off walls and stun you briefly. Hard crashes cost health; if you
crash soon after being shot, the kill goes to whoever shot you.

### Physics ideas (proposal, not built yet)

Today the flight is purely kinematic (`Choppa.step`): velocity eases toward the wished
velocity at a fixed acceleration, lift is a target climb rate with no gravity, and the
body tilt is only visual. Easy, predictable and good for netcode, but shallow. Ideas
for the feel pass, keeping the auto-hover and aim assist so the first minute stays easy:

1. **Momentum and drift:** sideways speed bleeds off slowly, so experts slide round
   corners and juke; beginners barely notice.
2. **Thrust from tilt:** the choppa has to lean before it accelerates, like a real one;
   heavier, more mechanical feel.
3. **Gravity and energy:** without lift it sinks a little; dive for speed, trade speed
   for a zoom climb.
4. **Ground effect:** a little extra lift and speed close to the ground, matching the
   double boost for low tricks.
5. **Outside forces:** blasts and other choppas' downwash push you; missile hits send
   you spinning.
6. **Skid suspension:** soft, springy landings.

Recommended first: 1, 3 and 4, tuned with a gamepad on real hardware. Keep the model
deterministic and cheap so client-side prediction stays simple for multiplayer.

### Machine gun (decided)

Every choppa has a twin machine gun. In battle it does **light damage plus a little
knockback** (25 hits from full health); in races it only pushes. Items are meant to be
the big hitters.

- Rapid fire (12.5 rounds/s, 4 damage each), tracers, rounds stopped by walls.
- Aim assist: rounds snap to a choppa inside a 12° cone ahead (lock ring on the HUD).
- Overheats after ~2.3 s of continuous fire, then cools down.
- A barrel roll dodges bullets.
- On touch screens it auto-fires while locked on, since the right thumb is steering.

### Sick moves

Tricks are short committed animations with a gameplay effect. Landing one cleanly
(no collision while it plays) fills the boost meter, and doing it **low to the ground**
doubles the reward. So the loop is: trick → boost → go faster → take risks.

| Trick | Input | Effect |
|---|---|---|
| Barrel roll | Trick + left/right | Sideways dash with a full roll. Dodges missiles. |
| Front flip | Trick + forward | Forward burst with a full flip. |
| 180 snap | Trick + back | Whip around to face the other way, keeping speed. Great for battle mode. |
| Pirouette | Trick alone | Vertical hop with a spin. |

Later: chained tricks for combo multipliers, near-miss bonus (skimming walls and
opponents), tunnel-threading bonus, and tricks that cancel incoming items when timed.

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

1. **Foundation** *(done)*: project, flight model, tricks, boost, chase/cockpit camera,
   machine gun, touch controls, tests, CI builds.
2. **Battle mode and first arena** *(done)*: health, damage, death, respawn, deathmatch
   rules, kill feed, scoreboard, combat bots, Mesa Basin, terrain, effects (explosions,
   rotor dust, boost flame, muzzle flash, damage smoke).
3. **Items** *(done)*: missile, mine, fake box, smoke, scrambler, shield, GET TO THE
   CHOPPA, with scoreboard-weighted odds; bots use them.
4. **Feel pass:** tune on real hardware (Windows + Android): physics (see Physics
   ideas), sound mix, camera shake, hit markers. Music is still missing.
   **UI overhaul (owner's request, to do):** menus, HUD, scoreboard and touch controls
   are still placeholder Godot controls; restyle them to match the PVKK-like look
   (stencil type, worn metal panels, amber/cream instruments).
5. **LAN multiplayer:** host/join, discovery, prediction and interpolation.
6. **More arenas** and battle variants.
7. **Internet play**, choppa colours and customization.

## Decided after the first build

- Machine gun: yes.
- Control scheme: keep the current drone-style controls (steering plus separate lift).
- Genre: arena shooter first, not a racing game.
