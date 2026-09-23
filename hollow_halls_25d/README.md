# Hollow Halls 2.5D (prototype)

Hollow Halls rebuilt as a 3D box world that pretends to be 2D. At rest you are
always in a flat **top view** or a flat **side view** that look just like the
original — flat colours, no shading, no shadows. Switch views, or turn the side
view to face another corridor, and the camera gives the secret away: the flat
picture opens up into 3D, the lights come on, the camera swings round you, and
it all folds back flat. Untextured boxes on purpose.

## Run it

Open this folder as a project in **Godot 4** and press F5. No build step, no
external assets. Verified against **Godot 4.7.2-stable** (Forward+/Vulkan).

```bash
godot --path .
```

## The camera

| key | does |
|---|---|
| `Tab` | switch between top view and side view |
| `1` / `2` | top view / side view |
| `3` | free orbit, and back again |
| `Q` / `E` | turn the view 90° left / right (in the orbit, hold to swing round) |
| `T` / `G` | orbit only: raise and lower the camera |
| `+` / `-` | orbit only: pull in and push out |
| middle-drag, wheel | orbit only, with a mouse |
| touch | on a touch screen the game grows its own controls - see **On a phone** |

There are two flat views and, behind key `3`, a third that stops pretending -
see **Free orbit** below.

 Switching between them, and turning the side view with
`Q`/`E` (to face a different corridor), plays the **reveal**: the lens opens from a flat 1° to a 42° perspective, the sun and its
shadows fade in while the picture is still straight on, the camera swings round
the player, then it all flattens back out. Gameplay pauses for the 1.1 s swing.
Turning the **top** view with `Q`/`E` is different: it stays flat 2D and just
spins the map round, in 0.45 s.
No compass or angle readout, just `TOP VIEW` / `SIDE VIEW` in the corner.

"Flat" is really a perspective camera at a 1° field of view pulled about a
kilometre back, which is indistinguishable from orthographic but, unlike a true
orthographic camera, can be widened smoothly. That dolly zoom is what makes the
reveal possible. Flat lighting is no sun, white ambient and a linear tonemap, so
every surface shows exactly its colour.

**The view changes the game:**

* **Top view** — full 8-way movement on the ground; your slash goes wherever
  you are facing. With no shadows to show a jump, the player grows slightly as
  it rises, the way a 2D game would fake it.
* **Side view** — your depth is **locked**, exactly like Hollow Halls'
  corridors. W/S aim instead: hold W to slash up, hold S in the air to slash
  down, and down-slashing an enemy **pogoes** you off it.

The side view is a single slice of the world. Walls, floors and pits in front of
your depth are cleared away, and enemies and signposts from other corridors are
hidden, so each corridor reads as a clean side-scroller. In top view anything
standing between the camera and you (a platform overhead) fades out.

## Free orbit

Key `3` opens a full perspective orbit around the player: real lens, sun and
shadows on, nothing hidden, steered with `Q`/`E`, `T`/`G` and `+`/`-` (or the
mouse). `1`, `2` or `Tab` folds it back into a flat view, landing on the quarter
turn nearest where you left the orbit.

It runs on the same machinery as the reveal - the move in and out of it is the
same dolly zoom, ending at an angle and distance you picked rather than at a
flat one. The point of it is that the two flat views then read as *choices*
about how to look at the space, not as all there is.

Walking still works while you orbit, and the movement axes follow the live
camera yaw rather than a fixed one, so `D` is screen-right at any angle.

## On a phone

There is a web build in [`../docs`](../docs),
and on a touch screen `scripts/touch.gd` adds on-screen controls: a stick that
springs to wherever your left thumb lands, ATTACK / JUMP / DASH under the right
one, and a camera bar of TOP / SIDE / ORBIT with turn arrows either side. In the
free orbit, dragging the right of the screen swings the camera.

It is purely additive. The touch layer presses the same input actions the keys
do - with a strength, so the stick is analogue - and nothing else in the game
knows a finger is involved. Held in portrait it asks to be turned sideways,
because a 16:9 game in a portrait strip shows almost nothing.

Nothing appears on a desktop: the layer is only built when
`DisplayServer.is_touchscreen_available()` says so, or you pass `--touch`.

## The level

The same shape as Hollow Halls — two rooms with exactly two openings each,
three hallways — but as **one continuous world**, so there are no transitions:
you just walk through a doorway.

```
            hall_3, east leg (along X) ---------------+
            |                                          |
        hall_2 (along Z)                   hall_3, south leg (along Z)
            |                                          |
        [ROOM A] ------- hall_1 (along X) ------- [ROOM B]
```

hall_2 and both legs of hall_3 run in different directions, so to side-scroll
one you turn the side view round to face it. That is what `Q`/`E` are for.

* **Doors.** Every hallway entrance has an automatic sliding door. It opens by
  itself when you come within 5 m, slides sideways into the wall, and shuts
  once you are 6 m clear. Shut, it is solid.
* **Entry buffer.** Walking from a room into a hallway gives you **2 seconds**
  where you cannot take damage and enemies cannot see you — they will not chase
  you and touching them does nothing. You are drawn see-through while it lasts.
  Going hall to hall does not grant it.
* **Rooms** are safe. Enemies are confined to their own hallway and will not
  follow you through a doorway, even when they can see you.
* **Hallways** have platforms, spike pits (with a stepping stone over each) and
  enemies: `walker`s patrol and chase along the corridor floor without walking
  off edges, `flyer`s hover until they spot you and then home in.
* Walking into a new area drops a **checkpoint** on the first solid ground you
  touch. Spikes cost a mask and send you back to it; dying respawns every enemy
  and sends you back to it with full masks.

## Combat

Straight from Hollow Halls: directional nail slash, hit stop and screen shake on
every connect, recoil, pogo, 5 masks with i-frames and knockback, soul gained
per hit, and focus (hold `F` standing still) to spend 33 soul on a mask.
Getting hit cancels a swing in progress.

| | |
|---|---|
| WASD / arrows | move (relative to the camera) |
| Space / Z | jump (cut, coyote time, buffer) |
| K / LMB | attack |
| Shift / C / RMB | dash |
| F / V | focus-heal |
| R | respawn at the last checkpoint |
| Esc | quit |

## Verifying it works

`tests/autopilot.gd` is an autoload that stays completely inert unless you pass
the flag:

```bash
godot --path . --resolution 1280x720 ++ --autopilot --shots C:/some/dir
```

It drives the real inputs and asserts 137 things, among them: attack is on K, the two flat
views plus the orbit, at rest both are flat (1° lens, no sun) with the side view dead
level, a switch opens into perspective (42°) with the sun up mid-swing and
passes through the angles in between (sampled every frame), gameplay is paused
during the swing, a side-view turn plays the same reveal while a top-view turn
stays flat, key `3` opens a real perspective orbit with the sun on and
nothing culled, steering it moves and clamps as it should, walking in it follows
the live camera yaw, and leaving it lands square to the world,
doors are shut and solid until you approach, open before you reach
them and shut behind you, the entry buffer lasts 2 s and blocks hits and enemy
contact, controls rotate with the
camera (side view at 0° `D` walks +X, at 90° the same key walks -Z), W does not
move you in depth in the side view, side view shows no enemies from other
corridors, the near corridor wall fades while the far one stays
solid and the roles swap when you turn 180°, you can walk from a room into a
hallway with no fade at all, no enemy ever enters a room even with you standing
in the doorway as bait, a 6 hp walker dies in 6 swings, pogo and top-view
slashes land, spikes send you to the checkpoint (even during i-frames), and
death restores masks and all 16 enemies. It exits non-zero on failure.

`++ --autopilot --camcap --shots <dir>` instead photographs a top-to-side reveal
and a side turn frame by frame.

## How it looks

Still boxes, but dressed: one palette in `scripts/look.gd`, a tile texture laid
over every floor and wall in world space so the grid runs straight across the
level, a dark outline drawn as a second material pass on everything you can
stand on or hit, a sky gradient instead of a black void, bloom on the gold
doors and on you, drifting dust, and a vignette.

None of it breaks the flat rule — there is still no light and no shadow at rest.
Two tricks stand in for what lighting would normally do:

- **Outlines.** Flat boxes of similar colour merge into each other. A grown,
  inside-out copy of the same mesh in near-black keeps them apart, and costs no
  extra node (`look.gd` hangs it off the material's `next_pass`).
- **Sinking.** A flat view has no perspective to say what is far away, so in the
  side view the camera paints it: the further behind your slice a box starts,
  the further its colour is pulled towards the sky. Same idea as a darker
  parallax layer in a 2D game.

The suite also checks that it ran every check it has (`EXPECTED_CHECKS`). A test
that quietly does not run is worse than one that fails, and that assertion is
what caught the flaky pogo test: it had been dropping a check some runs rather
than failing.

## Files

| file | what |
|---|---|
| `scripts/game.gd` | root: flat/3D lighting blend, world, checkpoints, respawn, death, hit stop |
| `scripts/camera_rig.gd` | the camera: two flat views, the 3D reveal between them, control axes, clearing the side view |
| `scripts/player.gd` | camera-relative movement and all the combat; feel constants at the top |
| `scripts/enemy.gd` | walker + flyer, confined to their hallway |
| `scripts/door.gd` | the automatic sliding doors |
| `scripts/level_data.gd` | every box, pit, area, enemy and signpost as plain data — **edit here to change the level** |
| `scripts/world_builder.gd` | turns that data into lit boxes, colliders, spikes and signposts |
| `scripts/hud.gd` | masks, soul, area name, which view you are in, hints |
| `scripts/controls.gd` | autoload, registers the input map at runtime |
| `scripts/meshes.gd` | the one shared box-mesh helper (tiles and outlines live here) |
| `scripts/look.gd` | palette, tile texture, the outline pass, the vignette |
| `scripts/fx.gd` | dust, landing puffs, hit sparks, dash ghosts |
| `tests/autopilot.gd` | the smoke test |

## Notes for changing things

* The player and walkers use **capsule** colliders on purpose. A box collider
  snags on the seam where two floor boxes meet (the first build got stuck
  dead at x = 9.58, right at the room/hallway seam).
* Jump clears about 3 m of height and 5.9 m of distance; pits are 3.5 m. Low
  platforms sit with their undersides at 2 m or more so you can walk under
  them — the player is 1.4 m tall.
* Camera tuning lives at the top of `camera_rig.gd`: `FRAME_HEIGHT` (zoom of
  each view), `REVEAL_FOV` (how 3D the reveal gets), `SWING_TIME`, and
  `PLANE_HALF_DEPTH` (how thick the side-view slice is).
