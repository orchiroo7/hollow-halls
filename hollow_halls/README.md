# Hollow Halls (prototype)

Top-down RPG rooms + side-on Metroidvania hallways, in Godot 4. Everything is
untextured boxes on purpose — the geometry and feel are the point.

## Run it

Open the folder as a project in **Godot 4** and press F5. No build step, no
external assets. Verified against **Godot 4.7.2-stable** (Forward+/Vulkan).

```bash
godot --path .
```

## The shape of it

Two wide top-down rooms and three narrow hallways. Each room has exactly **two
doors**, which is four door slots for three hallways, so hall_2 and hall_3 meet
end to end at a corridor junction rather than passing through a room:

```
   [ROOM A] ----- hall_1 -----> [ROOM B]
    ATRIUM    (SUNLESS CORRIDOR)  CISTERN
       ^ north                       | south
       |                             v
       +--- hall_2 <=== junction === hall_3
          (THE ASCENT)          (THE LONG DARK)
```

Every area is reachable and every door leads back the way you came. The
junction is hallway-to-hallway, so you stay side-on across it.

* **Rooms** are top-down. 8-directional walking, the whole room width in view,
  no enemies, no attacking. Doorways glow yellow.
* **Hallways** are side-on: platformer physics, and the only place combat
  exists.

## The view shift

Walking into a doorway never fades to black. The transition is one continuous
camera move:

* The outgoing area **stays on screen** and dissolves while the incoming one
  builds behind it.
* Frame zero of a shift is a pixel-perfect continuation of the frame before it.
  The camera is offset by exactly the amount needed to hold the player and the
  old geometry still, then that offset eases to zero — so nothing ever pops,
  the camera just slides into the new framing (a ~1400px pan out of a room, and
  ~870px across the junction).
* On a top-down to side-on change the camera **tips over**: the view squashes
  vertically down to a grazing angle (zoom.y drops to ~0.41) and springs back
  out, which is what pitching a camera from overhead to horizontal looks like.
  Area backgrounds are drawn well past their bounds so the tip never reveals
  empty space.
* Your horizontal momentum carries through the doorway, so you step out of a
  door still running instead of at a dead stop.

A fade to black is still used for the two places it belongs: the first load,
and dying.

## Controls

| | |
|---|---|
| WASD / arrows | move (8-way in rooms, run in hallways) |
| Space / Z | jump (has cut, coyote time, input buffer) |
| X / J / LMB | nail attack — hold W to slash up, hold S midair to slash down |
| Shift / C / RMB | dash |
| F / V | focus — hold still on the ground to burn soul and heal a mask |
| R | restart the current area |
| Esc | quit |

## Combat notes (the Hollow Knight / Silksong bits)

* Attacks are a short-lived directional hitbox, not a projectile. The swing
  queries physics directly, so each swing hits a given enemy once.
* **Recoil**: landing a side hit shoves you backwards; an up-slash kills your
  rise; a **down-slash bounces you** off the enemy (pogo) and refunds your dash.
* **Hit stop**: every connect freezes the game at 5% time scale for ~55ms, plus
  screen shake. Kills and taking damage freeze harder.
* **Soul**: +11 per hit, capped at 99. 33 soul + 0.85s of standing still = one
  mask back. Moving, jumping or getting hit cancels it.
* 5 masks, 1.1s of i-frames with a blink, knockback away from whatever hit you.
* Enemies: `walker` (patrols its ledge, chases when you are near and level with
  it, 6 hp) and `flyer` (bobs in place until it spots you, then homes in, 4 hp).
  Both flash white, get knocked back and show an hp bar once hit.
* Spikes over the pits cost a mask and put you back at the hallway entrance.
  Running out of masks reloads the whole hallway.

## Verifying it works

`tests/autopilot.gd` is a scripted smoke test. It is an autoload but stays
completely inert unless you pass the flag, so it never affects normal play:

```bash
godot --path . --resolution 1280x720 ++ --autopilot --shots C:/some/dir
```

It drives the real input actions and asserts 78 things: the start room is safe
and enemy-free, walking east actually reaches hall_1, the view swaps to side-on
with the camera zoomed and the tilt settled, a walker dies in 6 swings, hits
grant soul, the down-slash pogos, contact damage costs a mask and grants
i-frames, focus heals, spikes hurt and return you to the entrance, every area
loads with the right controller, every door on both sides points at a spawn
that exists, each room has exactly 2 doors, the shift never blacks the screen,
momentum carries through a doorway, and death reloads the hallway with masks
and enemies restored. It exits non-zero on failure and writes `log.txt` plus
screenshots to `--shots`.

## How it looks

Boxes, but dressed: one palette in `scripts/look.gd`, a tile texture on every
surface, a dark outline behind anything solid, a gradient sky, two bands of
far-off masonry behind the corridors, drifting dust, bloom on the doorways, and
a vignette. The HUD and title card match the 2.5D game's.

The suite also checks that it ran every check it has (`EXPECTED_CHECKS`). A test
that quietly does not run is worse than one that fails, and that assertion is
what caught the flaky pogo test: it had been dropping a check some runs rather
than failing.

## Files

| file | what |
|---|---|
| `scripts/game.gd` | root: area loading, fades, camera, hit stop, shake, death |
| `scripts/player.gd` | both control modes in one body; all the combat feel constants live at the top |
| `scripts/enemy.gd` | walker + flyer |
| `scripts/level_data.gd` | every room and hallway as plain `Rect2` data — **edit here to change layouts** |
| `scripts/world_builder.gd` | turns that data into nodes (walls split around doorways, doors, spikes, enemies) |
| `scripts/hud.gd` | masks, soul bar, area name, view badge |
| `scripts/controls.gd` | autoload, registers the input map at runtime |
| `scripts/boxes.gd` | the shared helpers that make a centred rectangle, outlined or gradient-filled |
| `scripts/look.gd` | palette, tile texture, vignette, bloom |
| `scripts/fx.gd` | dust, landing puffs, hit sparks, dash ghosts |
| `tests/autopilot.gd` | the scripted smoke test described above |

## Tuning

All the game feel numbers are consts at the top of `player.gd` — run speed,
gravity, jump velocity, jump cut, coyote, buffer, dash, attack cooldown and
active window, recoil, pogo, i-frames, soul costs.

Jump clears roughly 168px of height and ~280px of distance, which is what the
pit widths (220px) and platform spacing are built around. If you change
`GRAVITY` or `JUMP_VELOCITY`, re-check the gaps in `level_data.gd`.

## Not done yet

No save/load, no audio, no sprites, no bosses, no attack chaining or charge
attack, and enemies do not have telegraphed wind-up attacks (they are contact
damage only). All of that is the obvious next layer.
