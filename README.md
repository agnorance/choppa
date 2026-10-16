# choppa

GET TO THE CHOPPA! An arcade helicopter arena shooter: battle your friends through
tunnels, trenches and ruins, pull sick moves, and use Mario Kart style items to fool
them.

Made with [Godot 4.7](https://godotengine.org). Runs on Windows and Android. Design and
roadmap: [docs/DESIGN.md](docs/DESIGN.md).

## Play

Every push builds a Windows zip and an Android APK in GitHub Actions: open the run under
the **Actions** tab and download them from **Artifacts**.

- **Windows:** unzip and run `choppa.exe`.
- **Android:** install the APK (allow installs from unknown sources).

### Stable Android signing (one-time setup)

Android only installs a new APK over an old one if both are signed with the same key.
Until this is set up, CI signs with a throwaway key and you must uninstall before each
update. To fix it, create a key once (`keytool` ships with any Java JDK):

```
keytool -genkeypair -keystore choppa.keystore -alias choppa -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=choppa"
```

Then add two repository secrets under **Settings > Secrets and variables > Actions**:
`ANDROID_KEYSTORE_BASE64` (the file base64-encoded; on Windows:
`certutil -encodehex -f choppa.keystore out.txt 0x40000001`) and
`ANDROID_KEYSTORE_PASSWORD`. Keep the keystore file safe and out of the repo.

## Modes

Pick a map in the menu (Mesa Basin or Test Range), then:

- **Battle vs 3 bots** (Easy / Normal / Hard on the title screen): free-for-all. First to 8 kills, or the leader after 5 minutes.
  You respawn 3 s after being shot down, with a short spawn shield. Red-cross crates
  repair 40 health.
- **Free flight:** explore the map with three training dummies to shoot.
- **Race (test range):** 3 laps through both tunnels against bots. No damage in races.

Esc (or Start, or the Android back button) pauses: resume, settings, restart the match,
back to the title.

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
  invert, gamepad deadzone, touch controls (auto, off, on); key bindings beside them.
- **Audio:** master and effects volume.
- **Reset to defaults** at the bottom.

## Controls

| Action | Keyboard + mouse | Gamepad | Touch |
|---|---|---|---|
| Pitch and roll | Mouse (or arrow keys) | Left stick | Left half: drag |
| Turn (yaw) | A D (or Q E) | Right stick X | Right half: drag sideways |
| Collective (climb / descend) | W S (or Space / C) | Right stick Y | Right half: drag up/down |
| Afterburner | Shift | RB | BURN |
| Machine gun | Ctrl or left mouse | RT | FIRE (also auto-fires when locked on) |
| Use item | R | X | ITEM |
| Camera: chase view / cockpit | V | Y | CAM |
| Respawn (race: at your last gate; not in battle) | Backspace | Back/Select | |
| Pause | Esc | Start | Back button |
| Controls overlay on/off | F1 | | |

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
hold a hover. Repair crates fix all of it.

Item boxes (rainbow "?") give a random item; the further behind you are, the better:
turbo, homing missile (barrel-roll to shake one off), mine, fake item box (watch for the
upside-down "?"), smoke screen, control scrambler (hits the leader), shield, and for last
place only: GET TO THE CHOPPA.

Tricks: roll (trick + left/right), front flip (trick + forward), 180 snap (trick + back),
pirouette (trick alone). Landing a trick close to the ground fills your boost meter
twice as much.

## Develop

Full Windows setup (Godot, Git, tests, local Windows/Android builds, Blender asset
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
- `--autopilot=hover|shoot|bot|item:MISSILE`: let a script or bot fly.
- `--cam=fp|showcase`: start in the cockpit, or with a fixed front view of the choppa.
- `--health=30`: start damaged (cracked canopy, smoke); `--wear=tail,engine`: start with wrecked parts.
- `--explode=60`: set off an explosion ahead of you at physics tick 60.
- `--timing`: print how long the map build and the first frame take.
- `--settings=2` (with `--menu`): open the settings screen on tab 2 (0 video .. 4 audio); `--pause=60`: open the pause menu at tick 60.

### Quick test

```powershell
tools\try.ps1              # lists the scenes
tools\try.ps1 settings     # straight into a scene: menu, settings, battle, free, easy, race, cockpit,
                           # lake, damaged, tailrotor, engine, touch, bots, missile, explode
tools\check.ps1            # import, all tests, and screenshots of every screen into build\shots\
```
- `--shot=out.png --frames=90`: save a screenshot after 90 ticks and quit.
