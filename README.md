# Hollow Halls

Two prototypes built in Godot 4, from scratch, in GDScript. No assets, no
plugins — every box, collider and camera move is made in code.

**[▶ Play Hollow Halls 2.5D in your browser](https://ochiroo.github.io/hollow-halls/)**
— works on a desktop with a keyboard, or on a phone held sideways.

| | |
|---|---|
| [`hollow_halls_25d/`](hollow_halls_25d) | A 3D world that looks 2D. Two flat views, a free orbit, and a camera that reveals the trick as it moves between them. **137 automated checks.** |
| [`hollow_halls/`](hollow_halls) | The 2D original: top-down rooms, side-on combat corridors, seamless transitions with no fade to black. **78 automated checks.** |
| [`docs/`](docs) | The web build of the 2.5D game, which is what the link above serves. |

## The idea behind the 2.5D one

It is a real 3D world, but at rest it renders as a completely flat picture —
no perspective, no shading, no shadows. The camera is always a perspective
camera; "flat" is a 1° field of view parked about a kilometre back, framing the
same height. That is indistinguishable from an orthographic projection, but
unlike a real orthographic camera it can be animated. Switching views opens the
lens to 42°, swings the camera around the player, and folds it flat again, so
the 3D is only visible during the move.

Making a flat view *readable* turned out to be the harder half:

- **Occlusion.** Anything between the camera and the player is ray-tested every
  frame and faded out.
- **Slicing.** In the side view you can only move on two axes, so anything
  sitting in front of that plane is clutter — it is hidden outright.
- **Depth.** A flat projection gives no depth cue at all, so distance is
  painted: the further behind you a box starts, the further its colour is
  pulled towards the sky.

Press `3` for the free orbit, where it stops pretending — full perspective,
lights on, nothing hidden. The flat views are then one way of reading the space
rather than the only one.

## Testing

Both games can play themselves. The suite drives the real input actions, walks
the level, fights, dies, and asserts on state that is otherwise invisible —
that the field of view never rose above 1° during a flat turn, that the sun
never came on, that a door was fully open before the player reached it.

```bash
godot --path hollow_halls_25d ++ --autopilot
```

It exits non-zero on failure, so it is CI-ready. It also checks that it ran
every check it has: a test that quietly does not run is worse than one that
fails, and that assertion is what caught a flaky pogo test which had been
silently dropping a check on some runs.

## Running the source

Open either folder as a project in **Godot 4** (verified on 4.7.2-stable,
Forward+) and press F5. No build step and nothing to install.
