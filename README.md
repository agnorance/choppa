# choppa

GET TO THE CHOPPA! An arcade multiplayer helicopter game: race and battle your friends
through tunnels and canyons, pull sick moves, and use Mario Kart style items to fool
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

- **Race vs 3 bots:** 3 laps through both tunnels on the test range. Fly through the
  glowing cyan gate next; an arrow at the screen edge points to it when it's off screen.
- **Free flight:** the test range with loose boost rings and three training dummies.

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
| Camera | V | Y | CAM |
| Respawn (race: at your last gate) | Backspace | Back/Select | |

The machine gun knocks other choppas around instead of damaging them. It snaps onto
targets in a narrow cone ahead (white ring) and overheats after about two seconds of
continuous fire. A barrel roll dodges bullets. Three training dummies hover around the
test range to shoot at.

Tricks: roll (trick + left/right), front flip (trick + forward), 180 snap (trick + back),
pirouette (trick alone). Landing a trick close to the ground fills your boost meter
twice as much.

## Develop

1. Install Godot 4.7.2 (standard build, not .NET).
2. Open `project.godot` in Godot and press F5.

Tests: `godot --headless --fixed-fps 60 --path . --script res://tests/run_tests.gd`
