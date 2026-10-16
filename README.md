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

- **Battle vs 3 bots:** free-for-all. First to 8 kills, or the leader after 5 minutes.
  You respawn 3 s after being shot down, with a short spawn shield. Red-cross crates
  repair 40 health.
- **Free flight:** explore the map with three training dummies to shoot.
- **Race (test range):** 3 laps through both tunnels against bots. No damage in races.

Esc (or the Android back button) returns to the menu.

## Controls

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Fly / strafe | W A S D | Left stick | Left half: drag |
| Turn | Q E or ← → | Right stick X | Right half: drag sideways |
| Climb / dive | Space / C or ↑ ↓ | Right stick Y | Right half: drag up/down |
| Boost | Shift | RB | BOOST |
| Machine gun | Ctrl or left mouse | RT | FIRE (also auto-fires when locked on) |
| Trick (+ direction) | F | A | TRICK |
| Use item | R | X | ITEM |
| Camera: chase view / cockpit | V | Y | CAM |
| Respawn (race: at your last gate; not in battle) | Backspace | Back/Select | |

The machine gun snaps onto targets in a narrow cone ahead (white ring) and overheats
after about two seconds of continuous fire. A barrel roll dodges bullets. Crashing into
walls hurts too.

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
