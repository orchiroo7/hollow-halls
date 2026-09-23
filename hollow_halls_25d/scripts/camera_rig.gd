extends Node3D
## The player-controlled camera: two flat views, and a 3D reveal between them.
##
## At rest the game is 2D: a straight-down TOP view or a dead-level SIDE view,
## flat colours, no shading, no shadows - it looks like the original Hollow
## Halls. Switching views (Tab, 1/2) or turning the side view (Q/E) plays a
## short camera move that gives the secret away: the flat picture opens up into
## perspective, the light and shadows come on, the camera swings round the
## player, and everything folds back flat into the other view.
##
## "Flat" is a perspective camera at a 1 degree field of view, pulled far back
## so it frames the same height. That is indistinguishable from orthographic,
## but unlike a real orthographic camera it can be widened smoothly - a dolly
## zoom - which is what makes the reveal possible.
##
## There is a third mode, FREE (key 3), which stops pretending: a full
## perspective orbit you steer yourself, lit, with nothing hidden. The two flat
## views are then one way of reading the space rather than the only one. It runs
## on the same machinery - the swing in and out of it is the same dolly zoom,
## just ending somewhere you chose instead of somewhere flat.

enum View { TOP, SIDE }

## What a swing is doing. REVEAL opens into 3D and folds back flat; SPIN stays
## flat throughout; TO_FREE and FROM_FREE open into the orbit and back.
enum Swing { REVEAL, SPIN, TO_FREE, FROM_FREE }

const PITCH_DEG := [-90.0, 0.0]
const FRAME_HEIGHT := [24.0, 14.0]  # metres of world visible top to bottom
const VIEW_NAMES := ["TOP VIEW", "SIDE VIEW"]
const FLAT_FOV := 1.0
const REVEAL_FOV := 42.0
const SWING_TIME := 1.1   # a reveal: switching views, or turning the side view
const SPIN_TIME := 0.45   # turning the top view: stays flat, just spins
const FADED_ALPHA := 0.14   # something standing between the camera and you
const HIDDEN_ALPHA := 0.0   # side view: anything wholly in front of your depth plane
const FADE_SPEED := 6.0
const PLANE_HALF_DEPTH := 3.0  # side view shows moving things this close to your depth
const DEPTH_RANGE := 26.0   # metres behind you over which a box sinks back
const DEPTH_SINK := 0.62    # how far towards the sky colour it gets

# --- free orbit
const FREE_FOV := 55.0
const FREE_TIME := 0.9
const FREE_NAME := "FREE ORBIT"
const ORBIT_SPEED := 1.5    # radians a second on Q / E
const TILT_SPEED := 1.1     # radians a second on T / G
const ZOOM_SPEED := 1.1     # fraction of the distance a second on + / -
const MOUSE_ORBIT := 0.006  # radians a pixel, dragging with the middle button
const WHEEL_STEP := 0.12
const FREE_MIN_DIST := 5.0
const FREE_MAX_DIST := 150.0
const FREE_MIN_PITCH := -1.48   # very nearly straight down
const FREE_MAX_PITCH := 0.21    # a little below the horizon, looking up

const Look := preload("res://scripts/look.gd")

var game = null
var target = null
var camera: Camera3D
var view: int = View.TOP
var yaw_steps := 0
var occluders: Array = []

## Free orbit, kept between visits so going back looks how you left it.
var free := false
var free_yaw := 0.0
var free_pitch := -0.6
var free_dist := 26.0

## Live camera state. `depth` is how far into the 3D reveal we are: 0 flat, 1 full.
var pitch := -PI * 0.5
var yaw := 0.0
var frame_height := 24.0
var depth := 0.0

var _swinging := false
var _mode: int = Swing.REVEAL
var _peak := REVEAL_FOV
var _from_depth := 0.0
var _to_depth := 0.0
var _duration := SWING_TIME
var _t := 0.0
var _from_pitch := 0.0
var _from_yaw := 0.0
var _from_height := 0.0
var _follow := Vector3.ZERO
var _shake := 0.0
var _last_usec := 0


func _ready() -> void:
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    add_child(camera)
    camera.make_current()
    pitch = deg_to_rad(PITCH_DEG[view])
    frame_height = FRAME_HEIGHT[view]
    _last_usec = Time.get_ticks_usec()
    _apply()


# ------------------------------------------------------------------- control

func set_view(v: int) -> void:
    if v == view and not free:
        return
    var was_free := free
    view = v
    if was_free:
        _leave_free()
    else:
        _begin(Swing.REVEAL)


func cycle_view() -> void:
    set_view(View.SIDE if view == View.TOP else View.TOP)


func rotate_steps(steps: int) -> void:
    if free:
        return  # in the orbit, Q and E are held, not tapped - see _orbit()
    yaw_steps += steps
    # side view turns play the 3D reveal; top view just spins, flat
    _begin(Swing.REVEAL if is_side() else Swing.SPIN)


## Into the orbit and back out to whichever flat view you came from.
func toggle_free() -> void:
    if free:
        _leave_free()
    else:
        free = true
        free_yaw = yaw  # continuous: start facing where you were already facing
        _begin(Swing.TO_FREE)


func _leave_free() -> void:
    free = false
    # land on the quarter turn nearest where the orbit ended, so folding flat
    # is the shortest move rather than an arbitrary one
    yaw_steps = roundi(free_yaw / (PI * 0.5))
    _begin(Swing.FROM_FREE)


func is_side() -> bool:
    return view == View.SIDE and not free


func is_free() -> bool:
    return free


## Metres visible top to bottom at the player, for the orbit's current distance.
func free_frame_height() -> float:
    return 2.0 * free_dist * tan(deg_to_rad(FREE_FOV) * 0.5)


func swinging() -> bool:
    return _swinging


func looks_flat() -> bool:
    return depth < 0.01 and camera.fov <= FLAT_FOV + 0.01


func target_pitch() -> float:
    return free_pitch if free else deg_to_rad(PITCH_DEG[view])


func target_yaw() -> float:
    return free_yaw if free else deg_to_rad(90.0 * yaw_steps)


func target_height() -> float:
    return free_frame_height() if free else FRAME_HEIGHT[view]


func yaw_degrees() -> int:
    return posmod(yaw_steps * 90, 360)


func view_name() -> String:
    return FREE_NAME if free else VIEW_NAMES[view]


## Screen-right, flattened onto the ground. Read from where the camera is
## going, not where it is mid-swing, so controls settle the instant you press.
func right_axis() -> Vector3:
    var y := target_yaw()
    return Vector3(cos(y), 0.0, -sin(y))


## Screen-up in the top view (away from the camera), flattened onto the ground.
## In the side view this is the depth axis, which the player is locked out of.
func forward_axis() -> Vector3:
    var y := target_yaw()
    return Vector3(-sin(y), 0.0, -cos(y))


func add_shake(amount: float) -> void:
    _shake = maxf(_shake, amount)


func snap() -> void:
    if target != null:
        _follow = _goal()
        global_position = _follow


## Start a swing from wherever the camera is right now, so pressing again
## mid-swing just redirects it.
func _begin(mode: int) -> void:
    _from_pitch = pitch
    _from_yaw = yaw
    _from_height = frame_height
    _from_depth = depth
    _mode = mode
    match mode:
        Swing.SPIN:
            _duration = SPIN_TIME
            _peak = REVEAL_FOV
            _to_depth = 0.0
        Swing.TO_FREE:
            _duration = FREE_TIME
            _peak = FREE_FOV
            _to_depth = 1.0
        Swing.FROM_FREE:
            _duration = FREE_TIME
            _peak = FREE_FOV
            _to_depth = 0.0
        _:
            _duration = SWING_TIME
            _peak = REVEAL_FOV
            _to_depth = 0.0
    _t = 0.0
    _swinging = true


# ------------------------------------------------------------------- per frame

func _process(delta: float) -> void:
    # real time, so hit stop never stretches a swing
    var now := Time.get_ticks_usec()
    var real := minf((now - _last_usec) / 1000000.0, 0.1)
    _last_usec = now

    if free and not _swinging:
        _orbit(real)

    if _swinging:
        _t = minf(1.0, _t + real / _duration)
        var e := _ease(_t)
        match _mode:
            Swing.REVEAL:
                # the turn happens in the middle, while the picture is at its most 3D
                e = _ease(clampf((_t - 0.12) / 0.76, 0.0, 1.0))
                depth = smoothstep(0.0, 0.28, _t) * (1.0 - smoothstep(0.72, 1.0, _t))
            Swing.SPIN:
                depth = 0.0
            _:
                # in or out of the orbit: the picture opens once and stays open,
                # or closes once and stays shut
                depth = lerpf(_from_depth, _to_depth, e)
        pitch = lerpf(_from_pitch, target_pitch(), e)
        yaw = lerpf(_from_yaw, target_yaw(), e)
        frame_height = lerpf(_from_height, target_height(), e)
        if _t >= 1.0:
            _swinging = false
            pitch = target_pitch()
            yaw = target_yaw()
            frame_height = target_height()
            depth = 1.0 if free else 0.0

    if target != null:
        _follow = _follow.lerp(_goal(), 1.0 - pow(0.0005, delta))
        global_position = _follow

    if _shake > 0.0:
        _shake = maxf(0.0, _shake - delta * 1.6)
        camera.h_offset = randf_range(-_shake, _shake)
        camera.v_offset = randf_range(-_shake, _shake)
    else:
        camera.h_offset = 0.0
        camera.v_offset = 0.0

    _apply()
    _fade_occluders(real)
    _cull_off_plane()
    if game != null:
        game.set_depth_look(depth)


## Widening the lens while pulling in keeps the frame the same height at the
## player - the dolly zoom that turns the flat picture into a 3D one.
func _apply() -> void:
    rotation = Vector3(pitch, yaw, 0.0)
    var fov := lerpf(FLAT_FOV, _peak, depth)
    camera.fov = fov
    var dist := frame_height * 0.5 / tan(deg_to_rad(fov) * 0.5)
    camera.position = Vector3(0, 0, dist)
    # tight near/far around the level keeps depth precision good at 1 km out
    camera.near = maxf(0.05, dist - 150.0)
    camera.far = dist + 150.0


## Steering the orbit. Q / E swing round you, T / G raise and lower the camera,
## + / - pull in and push out; the middle mouse button drags, the wheel zooms.
func _orbit(real: float) -> void:
    var turn := Input.get_axis("cam_left", "cam_right")
    if turn != 0.0:
        free_yaw += turn * ORBIT_SPEED * real
    var tilt := Input.get_axis("cam_tilt_down", "cam_tilt_up")
    if tilt != 0.0:
        free_pitch = clampf(free_pitch - tilt * TILT_SPEED * real, FREE_MIN_PITCH, FREE_MAX_PITCH)
    var dolly := Input.get_axis("cam_closer", "cam_further")
    if dolly != 0.0:
        zoom_by(dolly * ZOOM_SPEED * real)


## Fraction of the current distance: positive pushes the camera out.
func zoom_by(amount: float) -> void:
    free_dist = clampf(free_dist * (1.0 + amount), FREE_MIN_DIST, FREE_MAX_DIST)


## Swing the orbit by a drag across the screen. Mouse and finger both.
func orbit_by(pixels: Vector2) -> void:
    if not free:
        return
    free_yaw -= pixels.x * MOUSE_ORBIT
    free_pitch = clampf(free_pitch - pixels.y * MOUSE_ORBIT, FREE_MIN_PITCH, FREE_MAX_PITCH)


func _unhandled_input(event: InputEvent) -> void:
    if not free:
        return
    if event is InputEventMouseMotion:
        if (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
            orbit_by(event.relative)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom_by(-WHEEL_STEP)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom_by(WHEEL_STEP)


func _ease(x: float) -> float:
    if x < 0.5:
        return 4.0 * x * x * x
    return 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5


func _goal() -> Vector3:
    var g: Vector3 = target.global_position + Vector3(0, 0.5, 0)
    if is_side():
        # look ahead of the player, Hollow Knight style
        var s: float = target.side_sign()
        g += right_axis() * s * 1.6
        g.y += 0.8
    return g


## Two rules. Any view: cast rays from the camera side toward the player's body
## and fade whatever they cross. Side view only: you cannot move in depth, so
## anything lying wholly in front of your depth plane is clutter - hide it.
func _fade_occluders(delta: float) -> void:
    if target == null:
        return
    var view_dir: Vector3 = -camera.global_transform.basis.z
    var body: Vector3 = target.global_position
    var points := [body + Vector3(0, 0.1, 0), body + Vector3(0, 0.6, 0)]
    var side := is_side()
    var depth_axis := forward_axis()  # horizontal, pointing away from the camera
    var my_depth := body.dot(depth_axis)
    for o in occluders:
        var aabb: AABB = o["aabb"]
        var want := 1.0
        if side and _far_depth(aabb, depth_axis) < my_depth - 0.6:
            want = HIDDEN_ALPHA
        else:
            for p in points:
                var pt: Vector3 = p
                if aabb.intersects_segment(pt - view_dir * 120.0, pt - view_dir * 0.45) != null:
                    want = FADED_ALPHA
                    break
        var mat: StandardMaterial3D = o["mat"]
        var mesh: Node3D = o["mesh"]
        var c := mat.albedo_color
        # a flat view has no perspective to say what is far away, so distance
        # is painted instead: the further behind your slice a box starts, the
        # more it sinks towards the colour of the sky
        var base: Color = o.get("base", c)
        if side:
            var behind := _near_depth(aabb, depth_axis) - my_depth
            var sink := clampf((behind - 2.0) / DEPTH_RANGE, 0.0, 1.0) * DEPTH_SINK
            base = base.lerp(Look.HORIZON, sink)
        if not is_equal_approx(c.a, want):
            c.a = move_toward(c.a, want, delta * FADE_SPEED)
        base.a = c.a
        c = base
        mat.albedo_color = c
        mesh.visible = c.a > 0.01
        var mode: BaseMaterial3D.Transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if c.a < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
        if mat.transparency != mode:
            mat.transparency = mode
        # an outline is a second pass on the same material: fade it with its box
        var edge := mat.next_pass as StandardMaterial3D
        if edge != null:
            var ec := edge.albedo_color
            ec.a = c.a
            edge.albedo_color = ec
            if edge.transparency != mode:
                edge.transparency = mode


## Side view is a single slice of the world. Enemies and signposts from other
## corridors would project straight into it and overlap what is really there,
## so anything in the "plane_only" group shows only when it shares your depth.
func _cull_off_plane() -> void:
    if target == null:
        return
    var side := is_side()
    var axis := forward_axis()
    var mine: float = target.global_position.dot(axis)
    for n in get_tree().get_nodes_in_group("plane_only"):
        var node: Node3D = n
        node.visible = not side or absf(node.global_position.dot(axis) - mine) < PLANE_HALF_DEPTH


## How far along `axis` the near side of a box starts.
func _near_depth(aabb: AABB, axis: Vector3) -> float:
    var half := aabb.size * 0.5
    return aabb.get_center().dot(axis) - half.x * absf(axis.x) - half.y * absf(axis.y) - half.z * absf(axis.z)


## How far along `axis` the far side of a box reaches.
func _far_depth(aabb: AABB, axis: Vector3) -> float:
    var half := aabb.size * 0.5
    return aabb.get_center().dot(axis) + half.x * absf(axis.x) + half.y * absf(axis.y) + half.z * absf(axis.z)


## True if the occluder currently reads as see-through (used by the tests).
func is_faded(aabb_center: Vector3) -> bool:
    for o in occluders:
        var aabb: AABB = o["aabb"]
        if aabb.get_center().is_equal_approx(aabb_center):
            var mat: StandardMaterial3D = o["mat"]
            return mat.albedo_color.a < 0.5
    return false
