# choppa: design

Living document. Decisions marked **(decided)** came from the owner; everything else is a
proposal that can change after playtesting.

## Pitch

Arcade multiplayer helicopter battles. Mario Kart energy in the air: tight courses with
tunnels and canyons, flashy tricks that feed your boost, and item boxes full of dirty
tricks to fool your friends. GET TO THE CHOPPA!

## Platform and tech (decided)

- **Engine:** Godot 4.7, GDScript, Compatibility (OpenGL) renderer so the same build runs on
  cheap Android phones and in CI.
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
| Trick (A / F) + direction | Pull a move (below). |
| Item (X / R) | Use the held item. |
| Camera (Y / V) | Toggle chase / cockpit view. |

Collisions bounce you off walls and stun you briefly; no instant death from scraping a wall.

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

1. **Race:** checkpoint courses with ring gates, tunnels, canyons and shortcuts. Laps,
   positions, Mario Kart style catch-up item odds.
2. **Battle:** arena, everyone has 3 hearts (like Mario Kart balloons). Items are the
   weapons. Last choppa flying wins, or most hits in a time limit.
3. Later ideas: hostage rescue race (carry the most soldiers to the pad, "GET TO THE
   CHOPPA"), king of the hill, tag.

Bots fill empty slots in every mode. They also let me test multiplayer headless.

## Items ("fool your friends")

Item boxes respawn a few seconds after pickup. Odds depend on your position: leaders get
defensive items, those trailing get the strong ones.

| Item | What it does |
|---|---|
| Turbo | Instant full boost burst. *(implemented)* |
| Homing missile | Locks onto the choppa ahead. Dodge with a barrel roll. |
| Mine | Drops behind you, hovers in place. |
| Fake item box | Looks exactly like an item box. |
| Smoke screen | Ink cloud behind you; anyone flying through gets a blacked-out screen. |
| Control scrambler | Hits the leader: their left/right controls swap for a few seconds. |
| Winch hook | Grab the choppa in front and steal its item. |
| Decoy flare | Breaks missile locks; held behind you like a banana. |
| Shield | Blocks one hit. |
| GET TO THE CHOPPA | Last-place only: autopilot rocket through the course, knocking others aside. |

## Maps

Built from modular pieces (tunnel segments, mesas, canyons, arches, ring gates, boost
pads) so new maps are mostly assembly. Low-poly, flat-shaded look with strong colors and
fog for depth. Planned first maps:

- **Test range** (exists): open field, a mesa with a tunnel, pillars, rings, item boxes.
- **Canyon run:** a race through a winding canyon with a cave shortcut.
- **Dockyard:** battle arena of shipping containers, cranes and a warehouse to fly through.

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

1. **Foundation** *(this branch)*: project, flight model, tricks, boost, chase/cockpit
   camera, test range with tunnel, item boxes with Turbo, touch controls, tests, CI builds.
2. **Feel pass:** tune flight on real hardware (Windows + Android), audio, particles, camera
   shake, trick popups.
3. **Race mode:** checkpoints, laps, positions, first race map, bots.
4. **Items:** the full item set with position-weighted odds.
5. **LAN multiplayer:** host/join, discovery, prediction and interpolation.
6. **Battle mode** and an arena map.
7. **Internet play**, menus, choppa colors and customization.

## Open questions

- Should choppas also have a weak machine gun (knockback, no damage), or only items?
- Simple or "pro" control scheme? Today's is drone-style: steering plus separate lift.
