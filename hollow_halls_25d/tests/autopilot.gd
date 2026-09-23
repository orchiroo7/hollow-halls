extends Node
## Scripted smoke test. Inert unless the game is launched with:
##     godot --path . ++ --autopilot [--shots <dir>]
## Add --camcap to photograph a camera swing frame by frame instead.
## It drives the real input actions, so it exercises what a player does.

const LevelData := preload("res://scripts/level_data.gd")

const TOP := 0
const SIDE := 1

var shots_dir := ""
var game = null
const EXPECTED_CHECKS := 148

var failures := 0
var checks := 0


func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    if not args.has("--autopilot"):
        return
    var i := args.find("--shots")
    if i >= 0 and i + 1 < args.size():
        shots_dir = args[i + 1]
    _run(args)


func _run(args: PackedStringArray) -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    game = get_tree().current_scene
    _check(game != null, "main scene loaded")
    await _wait(0.8)

    if args.has("--camcap"):
        await _capture_swing()
        get_tree().quit(0)
        return

    _log("--- start ---")
    await _test_start()
    _log("--- camera views ---")
    await _test_views()
    _log("--- free orbit ---")
    await _test_free_orbit()
    _log("--- on-screen controls ---")
    await _test_touch()
    _log("--- controls follow the camera ---")
    await _test_controls()
    _log("--- walking into a hallway ---")
    await _test_walk_in()
    _log("--- doors ---")
    await _test_doors()
    _log("--- hall entry buffer ---")
    await _test_entry_buffer()
    _log("--- rooms stay safe ---")
    await _test_rooms_safe()
    _log("--- wall fading ---")
    await _test_occlusion()
    _log("--- combat ---")
    await _test_combat()
    _log("--- spikes ---")
    await _test_spikes()
    _log("--- every area ---")
    await _test_regions()
    _log("--- death ---")
    await _test_death()

    # a check that quietly did not run is worse than one that failed, so the
    # number of them is itself checked
    if checks != EXPECTED_CHECKS:
        failures += 1
        _log("  FAIL  ran %d checks, expected %d - something was skipped" % [checks, EXPECTED_CHECKS])
    else:
        _log("  ----  all %d checks ran" % checks)
    _log("=========== %d failed ===========" % failures)
    await _wait(0.2)
    get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------- tests

func _test_start() -> void:
    _check(game.region_id == "room_a", "starts in room_a (got %s)" % game.region_id)
    _check(game.rig.view == TOP, "starts in the top view")
    _check(_enemy_count() == LevelData.enemies().size(), "all %d enemies spawned" % LevelData.enemies().size())
    var t0 := Time.get_ticks_msec()
    while game.fade.color.a > 0.01 and Time.get_ticks_msec() - t0 < 3000:
        await get_tree().process_frame
    _check(game.fade.color.a < 0.01, "opening fade lifted (after a further %dms)" % (Time.get_ticks_msec() - t0))
    var doors := 0
    for s in LevelData.solids():
        if s["kind"] == "door":
            doors += 1
    _check(doors == 4, "two openings per room (%d door strips)" % doors)
    await _shot("01_room_a_top")


func _test_views() -> void:
    # the real keys are bound, and the in-between angle is gone
    var keys := {"cam_cycle": KEY_TAB, "cam_left": KEY_Q, "cam_right": KEY_E,
        "cam_top": KEY_1, "cam_side": KEY_2}
    for action in keys.keys():
        var bound := false
        for ev in InputMap.action_get_events(action):
            if ev is InputEventKey and ev.physical_keycode == keys[action]:
                bound = true
        _check(bound, "%s is bound to its key" % action)
    _check(not InputMap.has_action("cam_iso"), "there is no in-between angle any more")
    var attack_keys: Array = []
    for ev in InputMap.action_get_events("attack"):
        if ev is InputEventKey:
            attack_keys.append(ev.physical_keycode)
    _check(attack_keys == [KEY_K], "attack is on K and only K (%s)" % str(attack_keys))

    # Q/E in the top view: a flat spin, never the 3D reveal
    await _press("cam_right")
    var spin_depth := 0.0
    var spin_fov := 0.0
    var spin_pitch_off := 0.0
    var spin_frames := 0
    var t_spin := Time.get_ticks_msec()
    while Time.get_ticks_msec() - t_spin < 3000:
        await get_tree().process_frame
        spin_frames += 1
        spin_depth = maxf(spin_depth, game.rig.depth)
        spin_fov = maxf(spin_fov, game.rig.camera.fov)
        spin_pitch_off = maxf(spin_pitch_off, absf(rad_to_deg(game.rig.pitch) + 90.0))
        if spin_frames > 3 and not game.rig.swinging():
            break
    _check(spin_depth < 0.001 and spin_fov <= 1.01, "turning the top view stays flat 2D (peak fov %.1f°)" % spin_fov)
    _check(spin_pitch_off < 0.1, "and keeps looking straight down while it turns")
    _check(game.rig.yaw_degrees() == 90, "E still turns the top view (%d)" % game.rig.yaw_degrees())
    _check(game.sun.light_energy < 0.01, "no light comes on for a top view turn")
    await _press("cam_left")
    await _settle()

    # at rest it is 2D: straight down, effectively orthographic, no light
    _check(absf(rad_to_deg(game.rig.pitch) + 90.0) < 0.1, "top view looks straight down")
    _check(game.rig.looks_flat(), "at rest the top view is flat (fov %.1f°)" % game.rig.camera.fov)
    _check(game.sun.light_energy < 0.01, "at rest there is no sun: no shading, no shadows")
    await _shot("02_top_flat")

    # top -> side: the flat picture opens into 3D, swings, and folds back flat
    var p = game.player
    await _place(Vector3(0, 0.8, 0))
    var before: Vector3 = p.global_position
    Input.action_press("move_right")
    await _press("cam_side")
    var peak_fov := 0.0
    var peak_sun := 0.0
    var between := 0
    var frames := 0
    var paused_mid := false
    var trace := "view=%d swinging=%s" % [game.rig.view, game.rig.swinging()]
    var t0 := Time.get_ticks_msec()
    while Time.get_ticks_msec() - t0 < 4000:
        await get_tree().process_frame
        frames += 1
        if frames <= 30:
            trace += " | %dms p%.0f d%.2f sw%s pos%.1f" % [Time.get_ticks_msec() - t0, rad_to_deg(game.rig.pitch), game.rig.depth, "1" if game.rig.swinging() else "0", p.global_position.x]
        peak_fov = maxf(peak_fov, game.rig.camera.fov)
        peak_sun = maxf(peak_sun, game.sun.light_energy)
        var pitch: float = rad_to_deg(game.rig.pitch)
        if pitch < -10.0 and pitch > -80.0:
            between += 1
        if game.rig.depth > 0.5 and game.paused():
            paused_mid = true
        # no screenshot in here: a slow one blocks the sampling and lets the
        # swing finish unobserved (the --camcap mode photographs the reveal)
        if frames > 3 and not game.rig.swinging():
            break
    var moved: float = p.global_position.distance_to(before)
    Input.action_release("move_right")
    _check(peak_fov > 30.0, "switching opens into perspective (peak fov %.0f°)" % peak_fov)
    _check(peak_sun > 0.8, "and the light and shadows come on mid-swing (peak sun %.2f)" % peak_sun)
    _check(between >= 5, "the camera swings through the angles between (%d of %d frames)" % [between, frames])
    if between < 5 or moved >= 0.3:
        _log("    SWING TRACE: " + trace)
    _check(paused_mid, "gameplay pauses while the camera swings")
    _check(moved < 0.3, "holding a direction does not move you mid-swing (moved %.2f m)" % moved)

    _check(game.rig.view == SIDE, "2 -> side view")
    _check(absf(rad_to_deg(game.rig.pitch)) < 0.1, "side view is dead level (%.2f°)" % rad_to_deg(game.rig.pitch))
    _check(game.rig.looks_flat(), "and flat again once it lands (fov %.1f°)" % game.rig.camera.fov)
    _check(game.sun.light_energy < 0.01, "lights back off once it lands")
    _check(is_equal_approx(game.rig.frame_height, 14.0), "side view frames 14 m of height")
    await _shot("04_side_flat")

    # side -> side: turning the side view plays the same reveal
    await _press("cam_right")
    peak_fov = 0.0
    frames = 0
    t0 = Time.get_ticks_msec()
    while Time.get_ticks_msec() - t0 < 4000:
        await get_tree().process_frame
        frames += 1
        peak_fov = maxf(peak_fov, game.rig.camera.fov)
        if frames > 3 and not game.rig.swinging():
            break
    _check(peak_fov > 30.0, "turning the side view reveals too (peak fov %.0f°)" % peak_fov)
    _check(game.rig.yaw_degrees() == 90, "E turns the side view 90° (%d)" % game.rig.yaw_degrees())
    _check(absf(rad_to_deg(game.rig.yaw) - 90.0) < 0.1, "the turn lands exactly on 90°")
    _check(game.rig.looks_flat(), "flat again after the turn")
    await _press("cam_left")
    await _settle()
    _check(game.rig.yaw_degrees() == 0, "Q turns it back (%d)" % game.rig.yaw_degrees())

    # Tab just flips between the two
    await _press("cam_cycle")
    await _settle()
    _check(game.rig.view == TOP, "TAB flips side -> top")
    _check(absf(rad_to_deg(game.rig.pitch) + 90.0) < 0.1, "and lands straight down")
    await _press("cam_cycle")
    await _settle()
    _check(game.rig.view == SIDE, "TAB flips top -> side")
    await _press("cam_cycle")
    await _settle()
    _check(game.rig.view == TOP, "TAB flips back to top")


func _test_free_orbit() -> void:
    var rig = game.rig
    await _set_camera(TOP, 0)
    await _place(Vector3(0, 0.8, 0))
    await _wait(0.3)

    for action in ["cam_free", "cam_tilt_up", "cam_tilt_down", "cam_closer", "cam_further"]:
        _check(InputMap.has_action(action), "%s is bound" % action)

    # 3 opens the orbit: real perspective, lights on, nothing pretending to be flat
    await _press("cam_free")
    await _settle()
    _check(rig.is_free(), "3 opens the free orbit")
    _check(not rig.looks_flat(), "the orbit is not flat (fov %.0f°)" % rig.camera.fov)
    _check(absf(rig.camera.fov - rig.FREE_FOV) < 0.5, "it settles at the orbit's own lens (%.0f°)" % rig.camera.fov)
    _check(rig.depth > 0.99, "and stays open rather than folding back (depth %.2f)" % rig.depth)
    _check(game.sun.light_energy > 1.0, "the sun is on, so there are shadows")
    _check(not rig.is_side(), "it is not the side view, so nothing gets sliced away")
    var hidden := 0
    for n in get_tree().get_nodes_in_group("plane_only"):
        if not n.visible:
            hidden += 1
    _check(hidden == 0, "every enemy and sign is visible again (%d hidden)" % hidden)

    # steering it
    var yaw0: float = rig.free_yaw
    await _hold("cam_right", 0.5)
    _check(rig.free_yaw > yaw0 + 0.2, "E swings the orbit round you (%.2f rad)" % (rig.free_yaw - yaw0))
    var pitch0: float = rig.free_pitch
    await _hold("cam_tilt_up", 0.4)
    _check(rig.free_pitch < pitch0 - 0.1, "T lifts the camera towards straight down (%.2f rad)" % rig.free_pitch)
    await _hold("cam_tilt_up", 3.0)
    _check(rig.free_pitch >= rig.FREE_MIN_PITCH - 0.01, "and stops at straight down rather than rolling over")
    await _hold("cam_tilt_down", 1.0)
    var dist0: float = rig.free_dist
    await _hold("cam_further", 0.6)
    _check(rig.free_dist > dist0 + 1.0, "- pushes the camera out (%.1f m)" % rig.free_dist)
    await _hold("cam_closer", 0.6)
    _check(rig.free_dist < rig.FREE_MAX_DIST and rig.free_dist > rig.FREE_MIN_DIST, "+ pulls it back in, inside its limits (%.1f m)" % rig.free_dist)
    _check(rig.camera.position.z > 0.0, "the camera really is out at that distance")
    await _shot("09_free_orbit")

    # walking in an arbitrary frame: D goes screen-right whatever the orbit is
    await _place(Vector3(0, 0.8, 0))
    await _wait(0.4)
    var right: Vector3 = rig.right_axis()
    var before: Vector3 = game.player.global_position
    await _hold("move_right", 0.6)
    await _wait(0.2)
    var moved: Vector3 = game.player.global_position - before
    moved.y = 0.0
    _check(moved.length() > 0.8, "you can still walk in the orbit (%.1f m)" % moved.length())
    _check(moved.normalized().dot(right) > 0.8, "and D goes screen-right at whatever angle you are orbiting from")

    # and back out to a flat view, square to the world again
    await _press("cam_top")
    await _settle()
    _check(not rig.is_free(), "1 leaves the orbit")
    _check(rig.looks_flat(), "back to flat (fov %.1f°)" % rig.camera.fov)
    _check(game.sun.light_energy < 0.01, "and the lights go back off")
    _check(rig.yaw_degrees() % 90 == 0, "it lands square to the world (%d°)" % rig.yaw_degrees())
    await _set_camera(TOP, 0)


const TouchScript := preload("res://scripts/touch.gd")


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
    var ev := InputEventScreenTouch.new()
    ev.index = index
    ev.position = pos
    ev.pressed = pressed
    get_viewport().push_input(ev)
    await get_tree().process_frame


func _touch_drag(index: int, from_pos: Vector2, to: Vector2) -> void:
    var ev := InputEventScreenDrag.new()
    ev.index = index
    ev.position = to
    ev.relative = to - from_pos
    get_viewport().push_input(ev)
    await get_tree().process_frame


## The phone build: the same game, driven by fingers instead of keys.
func _test_touch() -> void:
    await _set_camera(TOP, 0)
    await _place(Vector3(0, 0.8, 0))
    await _wait(0.3)

    var made_here := game.touch == null
    if made_here:
        game.touch = TouchScript.new()
        game.touch.rig = game.rig
        game.add_child(game.touch)
        game.hud.set_compact(true)
        await get_tree().process_frame
    var t = game.touch
    _check(t != null, "the on-screen controls exist")

    # the buttons are where a thumb can reach and inside the screen
    var rect: Vector2 = get_viewport().get_visible_rect().size
    var orbit_at: Vector2 = t.hit_centre("cam_free")
    var attack_at: Vector2 = t.hit_centre("attack")
    _check(Rect2(Vector2.ZERO, rect).has_point(orbit_at), "the ORBIT button is on screen %s" % orbit_at)
    _check(attack_at.x > rect.x * 0.5 and attack_at.y > rect.y * 0.5, "attack sits under the right thumb")
    _check(t.hit_centre("jump").distance_to(Vector2(rect.x, rect.y)) < attack_at.distance_to(Vector2(rect.x, rect.y)),
        "jump has the corner, attack sits beside it")
    _check(t.stick_centre().x < rect.x * 0.5 and t.stick_centre().y > rect.y * 0.5, "the stick sits under the left one")

    # tapping ORBIT opens the orbit, tapping TOP closes it
    await _touch(0, orbit_at, true)
    await _touch(0, orbit_at, false)
    await _settle()
    _check(game.rig.is_free(), "tapping ORBIT opens the free orbit")
    var yaw0: float = game.rig.free_yaw
    await _touch(1, Vector2(rect.x * 0.78, rect.y * 0.4), true)
    await _touch_drag(1, Vector2(rect.x * 0.78, rect.y * 0.4), Vector2(rect.x * 0.62, rect.y * 0.4))
    await _touch(1, Vector2(rect.x * 0.62, rect.y * 0.4), false)
    _check(absf(game.rig.free_yaw - yaw0) > 0.1, "dragging the right of the screen swings it (%.2f rad)" % (game.rig.free_yaw - yaw0))
    # two fingers on empty space pinch the orbit in and out
    var dist0: float = game.rig.free_dist
    var mid := Vector2(rect.x * 0.7, rect.y * 0.45)
    await _touch(1, mid - Vector2(40, 0), true)
    await _touch(2, mid + Vector2(40, 0), true)
    await _touch_drag(1, mid - Vector2(40, 0), mid - Vector2(150, 0))
    await _touch_drag(2, mid + Vector2(40, 0), mid + Vector2(150, 0))
    _check(game.rig.free_dist < dist0 - 0.5, "spreading two fingers pulls the camera in (%.1f -> %.1f m)" % [dist0, game.rig.free_dist])
    var dist1: float = game.rig.free_dist
    await _touch_drag(1, mid - Vector2(150, 0), mid - Vector2(30, 0))
    await _touch_drag(2, mid + Vector2(150, 0), mid + Vector2(30, 0))
    _check(game.rig.free_dist > dist1 + 0.5, "and closing them pushes it back out (%.1f m)" % game.rig.free_dist)
    await _touch(1, mid, false)
    await _touch(2, mid, false)

    await _touch(0, t.hit_centre("cam_top"), true)
    await _touch(0, t.hit_centre("cam_top"), false)
    await _settle()
    _check(not game.rig.is_free(), "tapping TOP comes back out")
    _check(game.rig.looks_flat(), "and the picture is flat again")

    # the stick walks you, with a strength rather than all-or-nothing
    await _place(Vector3(0, 0.8, 0))
    await _wait(0.3)
    var home: Vector2 = t.stick_centre()
    var out: Vector2 = home + Vector2(t.stick_radius(), 0)
    var before: Vector3 = game.player.global_position
    await _touch(0, home, true)
    await _touch_drag(0, home, out)
    _check(Input.get_action_strength("move_right") > 0.6, "pushing the stick right presses move_right (%.2f)" % Input.get_action_strength("move_right"))
    var half: Vector2 = home + Vector2(t.stick_radius() * 0.5, 0)
    await _touch_drag(0, out, half)
    var soft: float = Input.get_action_strength("move_right")
    _check(soft > 0.2 and soft < 0.8, "and half way is half strength (%.2f)" % soft)
    await _touch_drag(0, half, out)
    await _wait(0.8)
    var moved: Vector3 = game.player.global_position - before
    moved.y = 0.0
    _check(moved.length() > 0.8, "so you actually walk (%.1f m)" % moved.length())
    _check(moved.normalized().dot(game.rig.right_axis()) > 0.8, "in the direction the stick points")
    await _touch(0, out, false)
    await get_tree().process_frame
    _check(Input.get_action_strength("move_right") == 0.0, "letting go stops you")

    # the stick stays put: touching empty floor well away from it is not a stick
    var far_left := Vector2(rect.x * 0.42, rect.y * 0.35)
    await _touch(0, far_left, true)
    await _touch_drag(0, far_left, far_left + Vector2(120, 0))
    _check(Input.get_action_strength("move_right") == 0.0, "touching away from the stick does not steer you")
    _check(t.stick_centre() == home, "and the stick has not moved to the finger")
    await _touch(0, far_left + Vector2(120, 0), false)

    # a flat view is only ever turned in quarters, by the arrows: dragging
    # across one must leave it exactly where it was
    await _set_camera(TOP, 0)
    var yaw_flat: int = game.rig.yaw_degrees()
    var pitch_flat: float = game.rig.pitch
    await _touch(0, far_left, true)
    await _touch_drag(0, far_left, far_left + Vector2(260, 90))
    await _touch(0, far_left + Vector2(260, 90), false)
    await _wait(0.3)
    _check(game.rig.yaw_degrees() == yaw_flat and is_equal_approx(game.rig.pitch, pitch_flat),
        "dragging a flat view does nothing to it (%d deg)" % game.rig.yaw_degrees())
    _check(not game.rig.is_free(), "and does not drop you into the orbit")

    # the arrows turn it a quarter, exactly as Q and E do on a keyboard
    await _touch(0, t.hit_centre("cam_right"), true)
    await _touch(0, t.hit_centre("cam_right"), false)
    await _settle()
    _check(game.rig.yaw_degrees() == posmod(yaw_flat + 90, 360),
        "the right arrow turns a flat view 90 deg (%d -> %d)" % [yaw_flat, game.rig.yaw_degrees()])
    await _touch(0, t.hit_centre("cam_left"), true)
    await _touch(0, t.hit_centre("cam_left"), false)
    await _settle()
    _check(game.rig.yaw_degrees() == yaw_flat, "and the left arrow turns it back (%d)" % game.rig.yaw_degrees())

    await _set_camera(TOP, 0)
    await _place(Vector3(0, 0.8, 0))
    await _wait(0.3)

    # and the action buttons reach the same code the keys do
    game.player.attack_cd = 0.0
    await _touch(0, attack_at, true)
    await get_tree().physics_frame
    await get_tree().physics_frame
    _check(game.player.attack_cd > 0.0, "the attack button swings the nail")
    await _touch(0, attack_at, false)

    if made_here:
        game.hud.set_compact(false)
        game.touch.queue_free()
        game.touch = null
        await get_tree().process_frame
    await _set_camera(TOP, 0)


func _test_controls() -> void:
    var p = game.player
    # side-on, yaw 0: right is +X, depth locked
    await _set_camera(SIDE, 0)
    await _place(Vector3(0, 0.8, 0))
    var a: Vector3 = p.global_position
    await _hold("move_right", 0.5)
    var b: Vector3 = p.global_position
    _check(b.x - a.x > 1.5 and absf(b.z - a.z) < 0.05, "side-on yaw 0: D walks +X (dx %.2f dz %.2f)" % [b.x - a.x, b.z - a.z])

    await _place(Vector3(0, 0.8, 0))
    a = p.global_position
    await _hold("move_up", 0.4)
    b = p.global_position
    _check(absf(b.z - a.z) < 0.05 and absf(b.x - a.x) < 0.05, "side-on: W does not move you in depth (dz %.3f)" % (b.z - a.z))

    # orbit 90°: the same key now walks north, along -Z
    await _set_camera(SIDE, 1)
    await _place(Vector3(0, 0.8, 0))
    a = p.global_position
    await _hold("move_right", 0.5)
    b = p.global_position
    _check(a.z - b.z > 1.5 and absf(b.x - a.x) < 0.05, "side-on yaw 90: D walks -Z (dz %.2f dx %.2f)" % [b.z - a.z, b.x - a.x])

    # top-down: full 8-way, W is north
    await _set_camera(TOP, 0)
    await _place(Vector3(0, 0.8, 0))
    a = p.global_position
    await _hold("move_up", 0.4)
    b = p.global_position
    _check(a.z - b.z > 1.0, "top-down yaw 0: W walks north (dz %.2f)" % (b.z - a.z))
    await _place(Vector3(0, 0.8, 0))
    a = p.global_position
    Input.action_press("move_right")
    await _hold("move_up", 0.4)
    Input.action_release("move_right")
    b = p.global_position
    _check(b.x - a.x > 0.8 and a.z - b.z > 0.8, "top-down: diagonals work (dx %.2f dz %.2f)" % [b.x - a.x, b.z - a.z])

    # jumping works in every view
    await _place(Vector3(0, 0.8, 0))
    await _hold("jump", 0.25)
    _check(p.global_position.y > 1.8, "jump works top-down (y %.2f)" % p.global_position.y)
    await _wait(0.8)


func _test_walk_in() -> void:
    await _set_camera(SIDE, 0)
    await _place(Vector3(6, 0.8, 0))
    var peak_fade := 0.0
    Input.action_press("move_right")
    var t0 := Time.get_ticks_msec()
    var frames := 0
    while game.region_id != "hall_1" and Time.get_ticks_msec() - t0 < 5000:
        await get_tree().process_frame
        peak_fade = maxf(peak_fade, game.fade.color.a)
        frames += 1
        if frames % 20 == 0:
            var pp: Vector3 = game.player.global_position
            var pv: Vector3 = game.player.velocity
            _log("    walk t=%dms pos=(%.2f, %.2f, %.2f) vel=(%.2f, %.2f, %.2f) hurt=%.2f frozen=%s" % [
                Time.get_ticks_msec() - t0, pp.x, pp.y, pp.z, pv.x, pv.y, pv.z, game.player.hurt_lock, game.frozen])
    Input.action_release("move_right")
    _check(game.region_id == "hall_1", "walked from room_a into hall_1 (got %s)" % game.region_id)
    _check(peak_fade < 0.01, "no transition at all: screen never faded (%.2f)" % peak_fade)
    await _wait(0.4)
    _check(game.checkpoint.x > 9.5, "entering a hallway dropped a checkpoint (x %.1f)" % game.checkpoint.x)


func _door_at(center: Vector3):
    for d in get_tree().get_nodes_in_group("door"):
        if d.closed_center.is_equal_approx(center):
            return d
    return null


func _test_doors() -> void:
    var p = game.player
    _check(get_tree().get_nodes_in_group("door").size() == 4, "every hallway entrance has a door (%d)" % get_tree().get_nodes_in_group("door").size())
    var east = _door_at(Vector3(10.5, 1.45, 0))
    var b_west = _door_at(Vector3(49.5, 1.45, 0))
    _check(east != null and b_west != null, "found the doors either end of hall_1")
    if east == null or b_west == null:
        return

    # far away: shut, and solid
    await _set_camera(SIDE, 0)
    await _place(Vector3(0, 0.8, 0))
    await _wait(1.5)
    _check(east.openness < 0.01, "a door stays shut with nobody near (%.2f)" % east.openness)
    var q := PhysicsRayQueryParameters3D.create(Vector3(47, 1, 0), Vector3(52, 1, 0), 1)
    var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
    _check(not hit.is_empty() and hit["collider"] == b_west, "a shut door is solid")

    # walk up to it: it opens by itself before you reach it, and you pass
    await _place(Vector3(5, 0.8, 0))
    Input.action_press("move_right")
    var opened_by := -1.0
    var t0 := Time.get_ticks_msec()
    while game.region_id != "hall_1" and Time.get_ticks_msec() - t0 < 5000:
        await get_tree().physics_frame
        if opened_by < 0.0 and east.openness > 0.99:
            opened_by = p.global_position.x
    _check(opened_by > 0.0 and opened_by < 10.0, "it slides fully open before you reach it (open at x=%.1f)" % opened_by)
    _check(game.region_id == "hall_1", "and you walk straight through into hall_1")
    # keep walking until well past: it shuts behind you
    while p.global_position.x < 18.0 and Time.get_ticks_msec() - t0 < 8000:  # past the 6 m close radius
        await get_tree().physics_frame
    Input.action_release("move_right")
    var closed := await _eventually(func() -> bool: return east.openness < 0.01, 2.0)
    _check(closed, "and slides shut again once you are clear (%.2f)" % east.openness)

    # top view: an open door is off to one side, tucked into the wall
    await _set_camera(TOP, 0)
    await _place(Vector3(9, 0.8, 0))
    await _wait(0.8)
    _check(east.global_position.z > 3.5, "open, it sits inside the wall beside the opening (z %.1f)" % east.global_position.z)
    await _shot("07_door_open_top")
    await _set_camera(SIDE, 0)


func _test_entry_buffer() -> void:
    var p = game.player
    game.reset_enemies()
    await _set_camera(SIDE, 0)
    await _place(Vector3(6, 0.8, 0))
    await _wait(0.3)
    p.invuln = 0.0
    _check(not p.is_hidden(), "in a room you are not hidden")

    Input.action_press("move_right")
    var t0 := Time.get_ticks_msec()
    while game.region_id != "hall_1" and Time.get_ticks_msec() - t0 < 5000:
        await get_tree().physics_frame
    Input.action_release("move_right")
    var entered := Time.get_ticks_msec()
    _check(p.is_hidden() and p.unseen > 1.8, "walking into a hallway starts the 2 s buffer (%.2f s)" % p.unseen)

    # unhittable: a direct hit and an enemy's touch both do nothing
    var hp0: int = p.health
    p.take_damage(1, p.global_position + Vector3(1, 0, 0))
    _check(p.health == hp0, "a hit during the buffer does no damage")
    var walker = _nearest_enemy("walker", p.global_position)
    if walker != null:
        for i in 20:
            p.global_position = walker.global_position + Vector3(0.3, 0.2, 0)
            p.velocity = Vector3.ZERO
            await get_tree().physics_frame
        _check(p.health == hp0, "touching an enemy during the buffer does no damage")
        _check(absf(walker.velocity.x) < 3.0, "and the enemy does not come for you (vx %.1f)" % walker.velocity.x)
    await _shot("08_entry_buffer")

    # it lasts 2 s, then you are back to normal
    var over := await _eventually(func() -> bool: return not p.is_hidden(), 3.0)
    var lasted := (Time.get_ticks_msec() - entered) / 1000.0
    _check(over and lasted > 1.8 and lasted < 2.6, "the buffer lasts about 2 s (%.2f s)" % lasted)
    p.invuln = 0.0
    p.take_damage(1, p.global_position + Vector3(1, 0, 0))
    _check(p.health == hp0 - 1, "after it, hits land again")

    # walking between rooms, or hall to hall, does not grant it
    p.health = 5
    await _place(Vector3(20, 0.8, 0))  # still hall_1
    await _wait(0.1)
    p.unseen = 0.0
    await _place(Vector3(0, 0.8, -20))  # straight into hall_2
    await _wait(0.1)
    _check(not p.is_hidden(), "going hall to hall does not grant the buffer")
    p.unseen = 0.0


func _test_rooms_safe() -> void:
    # bait: stand just inside room A by the hall_1 opening, where the hall_1
    # walker can see you, and make sure nothing follows you in
    game.reset_enemies()
    var p = game.player
    p.invuln = 10.0
    await _place(Vector3(8.5, 0.8, 0))
    var worst := ""
    var t0 := Time.get_ticks_msec()
    while Time.get_ticks_msec() - t0 < 4000:
        await get_tree().physics_frame
        for e in get_tree().get_nodes_in_group("enemy"):
            var r := LevelData.region_at(e.global_position)
            if r.get("kind", "hall") == "room":
                worst = "%s at %s" % [e.kind, e.global_position]
    _check(worst == "", "no enemy ever entered a room %s" % worst)
    _check(p.health == 5, "standing in a room you are never touched")


func _test_occlusion() -> void:
    # hall_1 walls: north at z -2.5, south at z +2.5. Side-on at yaw 0 the camera
    # sits on the +Z side, so the south wall is between it and you.
    await _set_camera(SIDE, 0)
    await _place(Vector3(12.5, 0.8, 0))
    var south := Vector3(30, -1, 2.5)
    var north := Vector3(30, -1, -2.5)
    _check(await _eventually(func() -> bool: return game.rig.is_faded(south)), "side-on: the near wall fades out")
    _check(not game.rig.is_faded(north), "side-on: the far wall stays solid")
    await _shot("03_hall_1_side")

    await _set_camera(SIDE, 2)  # orbit to the far side: the roles swap
    _check(await _eventually(func() -> bool: return game.rig.is_faded(north)), "orbited 180°: now the other wall fades (%s)" % _wall_debug(north, south))
    _check(await _eventually(func() -> bool: return not game.rig.is_faded(south)), "orbited 180°: and the first wall comes back")

    await _set_camera(TOP, 0)
    _check(await _eventually(func() -> bool: return not game.rig.is_faded(south) and not game.rig.is_faded(north)), "top-down: nothing in the way, nothing faded")
    await _set_camera(SIDE, 0)


func _wall_debug(north: Vector3, south: Vector3) -> String:
    var out := "player %s yaw %d fwd %s" % [game.player.global_position, game.rig.yaw_degrees(), game.rig.forward_axis()]
    for o in game.rig.occluders:
        var aabb: AABB = o["aabb"]
        if aabb.get_center().is_equal_approx(north) or aabb.get_center().is_equal_approx(south):
            var mat: StandardMaterial3D = o["mat"]
            out += " | %s a=%.2f" % [aabb.get_center(), mat.albedo_color.a]
    return out


func _test_combat() -> void:
    game.reset_enemies()
    await _wait(0.1)
    await _set_camera(SIDE, 0)
    var walker = _nearest_enemy("walker", Vector3(15, 0, 0))
    _check(walker != null, "found a walker to fight")
    if walker == null:
        return
    var p = game.player
    var swings := 0
    var soul_before: int = p.soul
    while is_instance_valid(walker) and not walker.dead and swings < 14:
        p.health = 5
        p.invuln = 2.0  # getting hit cancels a swing; this duel tests dealing damage
        p.global_position = walker.global_position + Vector3(-1.3, 0.2, 0)
        p.velocity = Vector3.ZERO
        p.facing_vec = Vector3(1, 0, 0)
        await _press("attack")
        await _wait(0.4)  # hit stop stretches the 0.3s cooldown slightly
        swings += 1
    var killed: bool = not is_instance_valid(walker) or walker.dead
    _check(killed, "walker died from nail hits")
    _check(swings <= 8, "6 hp walker died in %d swings" % swings)
    _check(p.soul > soul_before, "hits gained soul (%d -> %d)" % [soul_before, p.soul])

    # pogo: side view, fall onto an enemy holding down. Use hall_1's walker on
    # open floor (x 44, nothing overhead) from a fresh spawn - "nearest" by
    # straight-line distance can pick one in another corridor under a platform.
    game.reset_enemies()
    await get_tree().physics_frame
    var bounced := false
    for attempt in 5:
        var target = _nearest_enemy("walker", Vector3(44, 0, 0))
        if target == null:
            break
        p.health = 5
        p.invuln = 2.0
        p.global_position = target.global_position + Vector3(0, 2.0, 0)
        p.velocity = Vector3(0, -3, 0)
        Input.action_press("move_down")
        await get_tree().process_frame
        Input.action_press("attack")
        for i in 30:
            await get_tree().process_frame
            if i == 3:
                Input.action_release("attack")
            if p.velocity.y > 8.0:
                bounced = true
                break
        Input.action_release("move_down")
        Input.action_release("attack")
        if bounced:
            break
        await _wait(0.35)
    _check(bounced, "down-slash pogoed off an enemy")

    # top-view slashing hits in whatever direction you face. Done in hall_2,
    # which runs north-south, so standing south of a walker never puts you
    # inside a corridor wall.
    await _set_camera(TOP, 0)
    game.reset_enemies()
    await get_tree().physics_frame
    var victim = _nearest_enemy("walker", Vector3(0, 0, -12.5))
    _check(victim != null, "found a walker in hall_2 to slash at")
    if victim != null:
        var hp0: int = victim.hp
        p.invuln = 2.0
        p.global_position = victim.global_position + Vector3(0, 0.2, 1.3)
        p.velocity = Vector3.ZERO
        p.facing_vec = Vector3(0, 0, -1)
        var placed: Vector3 = p.global_position
        # the nail's cooldown does not run down while a camera swing has
        # gameplay paused, so whatever the last test left on it is still there
        p.attack_cd = 0.0
        p.attack_time = 0.0
        await _press("attack")
        await _wait(0.2)
        var hp1: int = victim.hp if is_instance_valid(victim) else 0
        _check(hp1 < hp0, "top-view slash lands facing north (%d -> %d, victim %s, player placed %s now %s)" % [
            hp0, hp1, victim.global_position if is_instance_valid(victim) else Vector3.ZERO, placed, p.global_position])
    await _shot("04_combat_top")

    # contact damage
    var biter = _nearest_enemy("", p.global_position)
    _check(biter != null, "found an enemy to be bitten by")
    if biter != null:
        p.health = 5
        p.invuln = 0.0
        p.unseen = 0.0
        var hp_before: int = p.health
        for i in 90:
            if is_instance_valid(biter):
                p.global_position = biter.global_position + Vector3(0.3, 0.2, 0)
            await get_tree().process_frame
            if p.health < hp_before:
                break
        _check(p.health < hp_before, "touching an enemy costs a mask")
        _check(p.invuln > 0.0, "and grants i-frames")

    # focus
    await _place(Vector3(0, 0.8, 0))
    p.health = 3
    p.soul = 99
    p.invuln = 0.0
    await _wait(0.2)
    await _hold("focus", 1.3)
    _check(p.health > 3, "focus healed a mask (%d)" % p.health)
    _check(p.soul < 99, "focus spent soul (%d)" % p.soul)
    await _set_camera(SIDE, 0)


func _test_spikes() -> void:
    var p = game.player
    game.reset_enemies()
    await _place(Vector3(13, 0.8, 0))  # stand in hall_1 so its checkpoint is set
    await _wait(0.3)
    var cp: Vector3 = game.checkpoint
    p.health = 5
    p.invuln = 0.0
    p.unseen = 0.0
    p.global_position = Vector3(28.5, 0.8, 0)  # over the pit, clear of the stepping stone
    p.velocity = Vector3.ZERO
    var hurt := false
    for i in 120:
        await get_tree().process_frame
        if p.health < 5:
            hurt = true
            break
    _check(hurt, "spikes cost a mask")
    await _wait(0.3)
    _check(p.global_position.distance_to(cp) < 1.0, "spikes return you to the checkpoint")

    # falling while invulnerable must still rescue you (no falling forever)
    p.invuln = 5.0
    p.global_position = Vector3(28.5, 0.8, 0)
    p.velocity = Vector3.ZERO
    await _wait(1.2)
    _check(p.global_position.y > -1.0, "a pit rescues you even during i-frames (y %.1f)" % p.global_position.y)


func _test_regions() -> void:
    var p = game.player
    var spots := {
        "room_a": Vector3(0, 0.8, 0),
        "hall_1": Vector3(20, 0.8, 0),
        "room_b": Vector3(60, 0.8, 0),
        "hall_2": Vector3(0, 0.8, -15),
        "hall_3": Vector3(10, 0.8, -42),
    }
    for id in spots.keys():
        p.invuln = 5.0
        await _place(spots[id])
        await _wait(0.1)
        _check(game.region_id == id, "%s is where it should be (got %s)" % [id, game.region_id])
    # the far bend of hall_3 and the way into room_b
    await _place(Vector3(60, 0.8, -35))
    await _wait(0.1)
    _check(game.region_id == "hall_3", "hall_3 south leg is hall_3")
    await _set_camera(SIDE, 1)
    await _place(Vector3(0, 0.8, -12))
    await _wait(0.7)
    await _shot("05_hall_2_side_orbited")

    # side view is one slice: enemies from other corridors must not show
    var shown_here := 0
    var ghosts := ""
    for e in get_tree().get_nodes_in_group("enemy"):
        var home: String = LevelData.region_at(e.global_position).get("id", "")
        if e.visible and home != "hall_2":
            ghosts += " %s@%s" % [e.kind, home]
        if e.visible and home == "hall_2":
            shown_here += 1
    _check(ghosts == "", "side view shows no enemies from other corridors%s" % ghosts)
    _check(shown_here > 0, "but it does show this corridor's (%d)" % shown_here)
    await _set_camera(TOP, 0)
    var hidden := 0
    for e in get_tree().get_nodes_in_group("enemy"):
        if not e.visible:
            hidden += 1
    _check(hidden == 0, "top view shows every enemy again (%d hidden)" % hidden)
    await _set_camera(TOP, 0)
    await _place(Vector3(60, 0.8, 0))
    await _wait(0.7)
    await _shot("06_room_b_top")


func _test_death() -> void:
    var p = game.player
    await _set_camera(SIDE, 0)
    await _place(Vector3(13, 0.8, 0))
    await _wait(0.3)
    var cp: Vector3 = game.checkpoint
    p.health = 5
    p.unseen = 0.0
    for i in 7:
        p.invuln = 0.0
        p.take_damage(1, p.global_position + Vector3(1, 0, 0))
        await _wait(0.12)
        if p.dead:
            break
    _check(p.dead, "running out of masks kills you")
    var t0 := Time.get_ticks_msec()
    while (p.dead or game.frozen) and Time.get_ticks_msec() - t0 < 8000:
        await get_tree().process_frame
    _check(not p.dead and not game.frozen, "revived and playable again")
    _check(p.health == 5, "full masks after death (%d)" % p.health)
    _check(p.global_position.distance_to(cp) < 1.0, "back at the checkpoint")
    _check(_enemy_count() == LevelData.enemies().size(), "enemies respawned (%d)" % _enemy_count())
    _check(is_equal_approx(Engine.time_scale, 1.0), "time scale restored")


# -------------------------------------------------------------------- capture

func _capture_swing() -> void:
    game.player.invuln = 60.0
    await _set_camera(TOP, 0)
    await _place(Vector3(20, 0.8, 0))
    await _wait(0.6)
    game.rig.set_view(SIDE)
    for i in 12:
        await _shot("reveal_%02d" % i)
        _log("reveal %d pitch %.1f fov %.1f depth %.2f sun %.2f" % [i, rad_to_deg(game.rig.pitch), game.rig.camera.fov, game.rig.depth, game.sun.light_energy])
        await _wait(0.09)
    await _settle()
    await _place(Vector3(0, 0.8, -20.5))
    game.rig.rotate_steps(1)
    for i in 12:
        await _shot("turn_%02d" % i)
        await _wait(0.09)
    await _settle()
    await _shot("hall_2_side_flat")


# -------------------------------------------------------------------- helpers

func _set_camera(view: int, yaw_steps: int) -> void:
    if game.rig.is_free():
        game.rig.toggle_free()
        await _settle()
    game.rig.yaw_steps = yaw_steps
    game.rig.view = -1
    game.rig.set_view(view)
    await _settle()


## Wait for the camera swing to actually finish.
func _settle() -> void:
    await get_tree().process_frame
    var t0 := Time.get_ticks_msec()
    while game.rig.swinging() and Time.get_ticks_msec() - t0 < 3000:
        await get_tree().process_frame
    await get_tree().process_frame


func _place(pos: Vector3) -> void:
    var p = game.player
    p.global_position = pos
    p.velocity = Vector3.ZERO
    game.rig.snap()
    for i in 6:
        await get_tree().physics_frame


func _enemy_count() -> int:
    return get_tree().get_nodes_in_group("enemy").size()


func _nearest_enemy(kind: String, near: Vector3):
    var best = null
    var best_d := INF
    for e in get_tree().get_nodes_in_group("enemy"):
        if not is_instance_valid(e) or e.dead:
            continue
        if kind != "" and e.kind != kind:
            continue
        var d: float = e.global_position.distance_to(near)
        if d < best_d:
            best_d = d
            best = e
    return best


func _check(cond: bool, label: String) -> void:
    checks += 1
    if not cond:
        failures += 1
    _log(("  PASS  " if cond else "  FAIL  ") + label)


func _log(line: String) -> void:
    print(line)
    if shots_dir == "":
        return
    var f := FileAccess.open("%s/log.txt" % shots_dir, FileAccess.READ_WRITE)
    if f == null:
        f = FileAccess.open("%s/log.txt" % shots_dir, FileAccess.WRITE)
    if f == null:
        return
    f.seek_end()
    f.store_line(line)
    f.close()


## Poll a condition for up to `timeout` seconds of real time. Checks that are
## about something *settling* use this, so a slow or starved frame cannot fail
## them - only the condition never becoming true can.
func _eventually(cond: Callable, timeout := 2.0) -> bool:
    var t0 := Time.get_ticks_msec()
    while Time.get_ticks_msec() - t0 < timeout * 1000.0:
        if cond.call():
            return true
        await get_tree().process_frame
    return cond.call()


func _wait(t: float) -> void:
    await get_tree().create_timer(t, true, false, true).timeout


## Press and release an action so both kinds of listener see it: polling
## (Input.is_action_*, used for jump/attack) via action_press, and event
## handlers (_unhandled_input, where the camera keys live) via push_input,
## which dispatches synchronously. Input.parse_input_event would queue the
## event for a later frame and race the checks.
func _press(action: String) -> void:
    var down := InputEventAction.new()
    down.action = action
    down.pressed = true
    Input.action_press(action)
    get_viewport().push_input(down)
    await get_tree().process_frame
    await get_tree().physics_frame
    Input.action_release(action)
    var up := InputEventAction.new()
    up.action = action
    up.pressed = false
    get_viewport().push_input(up)
    await get_tree().process_frame


func _hold(action: String, t: float) -> void:
    Input.action_press(action)
    await _wait(t)
    Input.action_release(action)
    await get_tree().physics_frame


func _shot(name: String) -> void:
    if shots_dir == "":
        return
    var drawn := [false]
    var on_draw := func() -> void: drawn[0] = true
    RenderingServer.frame_post_draw.connect(on_draw, CONNECT_ONE_SHOT)
    var t0 := Time.get_ticks_msec()
    while not drawn[0] and Time.get_ticks_msec() - t0 < 1500:
        await get_tree().process_frame
    if not drawn[0]:
        # never leave the callback armed: if it fires after this node is freed
        # (e.g. during shutdown) it calls into a dead script instance and crashes
        if RenderingServer.frame_post_draw.is_connected(on_draw):
            RenderingServer.frame_post_draw.disconnect(on_draw)
        _log("    (screenshot %s skipped: window is not being drawn)" % name)
        return
    var img := get_viewport().get_texture().get_image()
    if img != null:
        img.save_png("%s/%s.png" % [shots_dir, name])
