---
name: screenshot
description: Take and judge screenshots of the choppa game to check a visual change (models, cockpit, effects, maps, lighting). Use after any change that affects how the game looks, or when the owner asks to see something.
---

# Screenshots of the game

The game saves a PNG after N physics ticks and quits when started with `--shot`:

- Windows (owner's PC, fast GPU): `tools\shot.ps1 out.png [game args]`
- Linux / cloud (software Vulkan, ~1 fps): `tools/shot.sh out.png [game args]`

Then open the PNG with the Read tool and actually look at it. Say what you see, good and
bad, before claiming a change works.

## Useful arguments (full list at the top of scripts/main.gd)

| Goal | Arguments |
|---|---|
| Model from the front | `--cam=showcase --autopilot=hover --frames=150 --dummies=0` |
| Chase view in flight | `--autopilot=forward --frames=120` |
| Cockpit | `--cam=fp --autopilot=hover --frames=40` |
| Specific place / facing | `--spawn=x,y,z,yaw_degrees` (free mode); lake on Mesa Basin: `--spawn=150,4,150,45` |
| Damage look (cracks, smoke) | `--health=20` |
| Explosion | `--explode=60 --frames=64` (blast 26 m ahead and above the trees at tick 60) |
| Shooting | `--autopilot=shoot` |
| Item in use | `--autopilot=item:MISSILE` (item given at tick 20, used at tick 30) |
| Battle with bots | `--mode=battle --map=basin --autopilot=bot` |
| Title menu | `--menu` |

Free mode is the default with `--shot`; `--map=basin` is the main arena.

## Pitfalls

- **Spawn shield:** for 2 s after spawning the hull blinks. Use `--frames=150` or more
  for model shots, or the choppa may be invisible.
- **Timing on slow renderers:** without `--fixed-fps 60` (shot.ps1 adds it; shot.sh
  does not) a 1 fps renderer runs many physics ticks per frame, so short effects are
  over before a frame is drawn. On Linux, timed effects need
  `xvfb-run -a -s "-screen 0 960x540x24" godot --path . --fixed-fps 60 --resolution 960x540 -- --shot=...`
  and take ~15 minutes; prefer asking the owner to check effect timing on their PC.
- **Black world, sky and HUD fine:** a NaN in a shader (usually the sky) has poisoned
  the radiance map; it only shows on hardware Vulkan, not in cloud shots. Bisect with
  `--rendering-method mobile` / `--rendering-driver d3d12` (both unaffected) and by
  removing the sun or the sky.
- **Occlusion:** check the subject isn't behind a tree or rock before concluding an
  effect is broken (trace positions with a temporary `print`).
- **Backlight:** the sun is low (golden hour). Some yaws put the choppa in silhouette;
  try another `--spawn` yaw.
- Crop and scale with Python/PIL to compare several shots side by side in one image.
