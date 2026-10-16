# choppa

GET TO THE CHOPPA! An arcade helicopter arena shooter: battle your friends through
tunnels, trenches and ruins in three classes of helicopter, with rockets, missiles and
flares, and fight over the service stations that patch you up.

Made with [Godot 4.7](https://godotengine.org). PC only (Windows). Design and
roadmap: [docs/DESIGN.md](docs/DESIGN.md).

## Play

Every push builds a Windows zip in GitHub Actions: open the run under the **Actions**
tab, download it from **Artifacts**, unzip and run `choppa.exe`.

## Modes

Pick a map in the menu (Mesa Basin, Slot Canyon or Test Range), then:

- **Battle vs 3 bots** (Easy / Normal / Hard on the title screen): free-for-all. First to 8 kills, or the leader after 5 minutes.
  You respawn 3 s after being shot down, with a short spawn shield and a full loadout.
- **Stations:** land on a green pad to repair and rearm (4 s, then it is down for
  45 s), or on a blue ammo pad to rearm only (2 s, back after 20 s).
- **Free flight:** explore the map with three training dummies to shoot.
- **Race (test range):** 3 laps through both tunnels against bots. No damage in races.

Esc (or Start) pauses: resume, settings, restart the match,
back to the title.

## Multiplayer

**Multiplayer** on the title screen: enter your pilot name, then

- **Join** a server by address (`1.2.3.4`, or `1.2.3.4:7778` for another port), or
- **Host a battle** on the map chosen on the title screen. Friends join with your IP
  address. From outside your home network they need UDP port 7777 forwarded to your PC.

Online battles have six seats; bots fly the free ones and players take them over as
they join. A new round starts by itself 12 seconds after one ends. XP counts as usual.

A dedicated server has no window: `tools\server.ps1 --map=canyon` on Windows, or the
Linux build from CI: `./choppa_server.x86_64 --headless -- --server=7777 --map=basin`.

## Settings

From the title or the pause menu; saved in `user://settings.cfg`. Tabs switch with the
mouse, Q / E or the shoulder buttons.

- **Video:** window mode (windowed, fullscreen, exclusive), resolution, v-sync (off, on,
  adaptive), FPS limit, render scale with bilinear / FSR 1 / FSR 2 upscaling,
  anti-aliasing (FXAA, TAA, MSAA 2x to 8x), brightness, FPS counter.
- **Graphics:** quality preset, shadows, global illumination, ambient occlusion,
  reflections, volumetric fog, bloom, grass. "Auto" follows the preset; the preset and
  the grass apply when the next match starts, everything else at once.
- **Gameplay:** field of view, camera shake, default view (chase or cockpit), HUD size,
  damage flash, aim assist, flight assist, controls overlay.
- **Controls:** mouse steering, mouse controls (pitch & roll / pitch & yaw), sensitivity,
  invert, gamepad deadzone; key bindings beside them.
- **Audio:** master, effects and music volume.
- **Reset to defaults** at the bottom.

## Controls

| Action | Keyboard + mouse | Gamepad |
|---|---|---|
| Pitch and roll | Mouse (or arrow keys) | Left stick |
| Turn (yaw) | A D (or Q E) | Right stick X |
| Collective (climb / descend) | W S (or Space / C) | Right stick Y |
| Afterburner | Shift | LB |
| Machine gun | Ctrl or left mouse | RT |
| Rockets (hold) | Right mouse | LT |
| Missile (locks on) | F | RB |
| Flares | X | B |
| Mine / smoke | R / G | X / D-pad down |
| Camera: chase view / cockpit | V | Y |
| Respawn (race: at your last gate; not in battle) | Backspace | Back/Select |
| Pause | Esc | Start |
| Controls overlay on/off | F1 | |

Two flight models, chosen on the title screen. **Realistic** (default): the mouse flies
the choppa, push forward to put the nose down and accelerate, pull back to climb or
loop, move sideways to bank; nothing levels the nose for you. **Easy**: a drone that
hovers by itself, WASD moves and strafes, Q/E or the mouse turn, mouse Y aims the nose
and you fly where it points, Space/C climb and dive. "Mouse controls" in the settings swaps roll for yaw
on the mouse (then A/D roll), "Flight assist" adds auto-level and height hold, and
"Aim assist" (off by default) snaps the guns onto targets. Rolling hard throws off
bullets and missiles.

The machine gun overheats after about two seconds of continuous fire. Crashing hurts
(anything over 8 m/s into an obstacle), and where you get hit matters: a wrecked tail
rotor spins you, a chewed main rotor shakes you and loses lift, a dead engine cannot
hold a hover. Service stations fix all of it.

**Service stations** are the lit helipads: land on one and it repairs hull and parts and
refills your loadout in about four seconds, then powers down for 45 s (lamp red) for
everybody. **Loadout** (refilled only at stations): rockets (unguided, hit the part they
strike), homing missiles (flares or a hard roll shake them off), flares, one mine, one
smoke screen.

**Hangar** (title screen): your pilot level and XP, and a camo per helicopter. Earned
camos unlock with level (Desert at 5 up to Centurion at 100, Ace past it) and can never
be bought; the Hangar and Collector packs are style only; Apex is worn only by the
world's #1 ranked pilot. XP comes from battles: kills, assists, wrecked parts, damage,
stations taken from under an enemy's nose, finishing and winning. Offline for now
(`user://profile.cfg`); the store and Apex open with online play.

**Helicopters** (title screen): Scout (light, fast, 100 hull, few rockets), Gunship
(130 hull, more rockets, two missiles, harder-hitting guns), Heavy (170 hull, tough
parts, big loadout, slow and sluggish).

## Develop

Full Windows setup (Godot, Git, tests, local Windows builds, Blender asset
scripts): [docs/SETUP_WINDOWS.md](docs/SETUP_WINDOWS.md).

1. Install Godot 4.7.2 (standard build, not .NET).
2. Open `project.godot` in Godot and press F5.

Tests: `godot --headless --fixed-fps 60 --path . --script res://tests/run_tests.gd`

Game arguments for trying things out go after `--` (full list at the top of
`scripts/main.gd`), for example:

```
godot --path . -- --mode=free --map=basin --autopilot=hover --cam=showcase --explode=60
```

- `--mode=battle|free|race`, `--map=basin|range`: skip the menu.
- `--autopilot=hover|shoot|bot|weapon:missile`: let a script or bot fly (`weapon:` rockets, missile, flares, mine, smoke).
- `--airframe=scout|gunship|heavy`: fly that class.
- `--camo=<id>`, `--level=<n>`, `--entitle=hangar,collector,apex`, `--hangar`: try camos, levels and packs without touching your saved profile.
- `--cam=fp|showcase`: start in the cockpit, or with a fixed front view of the choppa.
- `--health=30`: start damaged (cracked canopy, smoke); `--wear=tail,engine`: start with wrecked parts.
- `--explode=60`: set off an explosion ahead of you at physics tick 60.
- `--timing`: print how long the map build and the first frame take.
- `--settings=2` (with `--menu`): open the settings screen on tab 2 (0 video .. 4 audio); `--pause=60`: open the pause menu at tick 60.

### Quick test

```powershell
tools\try.ps1              # lists the scenes
tools\try.ps1 settings     # straight into a scene: menu, settings, hangar, hangarmax, battle, free, easy, race, cockpit,
                           # lake, damaged, tailrotor, engine, bots, missile, rockets,
                           # gunship, heavy, canyon, canyonbattle, explode,
                           # online, host, join, lagjoin
tools\check.ps1            # import, all tests, and screenshots of every screen into build\shots\
```
- `--shot=out.png --frames=90`: save a screenshot after 90 ticks and quit.
- `--host[=port]`, `--server[=port]`, `--connect=addr[:port]`, `--name=Ace`: play online;
  `--lag=150 --loss=3` simulates a bad connection (round trip in ms, percent lost).

Two windows on one PC: `tools\try.ps1 host` in one, `tools\try.ps1 join` (or `lagjoin`)
in the other.
