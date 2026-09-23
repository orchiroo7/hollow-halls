extends Node
## Scripted smoke test. Inert unless the game is launched with:
##     godot --path . ++ --autopilot [--shots <dir>]
## It drives the real input actions, so it exercises the same code paths a
## player does: door transitions, the view swap, combat, death and reload.

var enabled := false
var shots_dir := ""
var game = null
var results: Array[String] = []
const EXPECTED_CHECKS := 78

var failures := 0
var checks := 0


func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    enabled = args.has("--autopilot")
    if not enabled:
        return
    var i := args.find("--shots")
    if i >= 0 and i + 1 < args.size():
        shots_dir = args[i + 1]
    _run()


func _run() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    game = get_tree().current_scene
    _check(game != null, "main scene loaded")
    await _wait(1.0)

    if OS.get_cmdline_user_args().has("--shiftcap"):
        await _capture_shift()
        get_tree().quit(0)
        return

    _log("--- start room ---")
    await _test_start_room()
    _log("--- door wiring ---")
    await _test_doors()
    _log("--- walking into a hallway ---")
    await _test_walk_into_hallway()
    _log("--- corridor junction ---")
    await _test_junction()
    _log("--- combat ---")
    await _test_combat()
    _log("--- hazards ---")
    await _test_hazard()
    _log("--- every area loads ---")
    await _test_all_areas()
    _log("--- death and reload ---")
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

func _test_start_room() -> void:
    _check(game.area_id == "room_a", "starts in room_a (got %s)" % game.area_id)
    _check(game.area_kind == "topdown", "start view is top-down")
    _check(game.player.mode == 0, "player controller is TOPDOWN")
    _check(get_tree().get_nodes_in_group("enemy").is_empty(), "no enemies in a wide room")
    _check(not game.transitioning, "fade finished")
    await _shot("01_room_a")


func _test_doors() -> void:
    var LD = load("res://scripts/level_data.gd")
    for id in ["room_a", "room_b"]:
        var d = LD.get_area(id)
        _check(d["doors"].size() == 2, "%s has exactly 2 doors (%d)" % [id, d["doors"].size()])
    var seen := {}
    for id in ["room_a", "room_b", "hall_1", "hall_2", "hall_3"]:
        var d = LD.get_area(id)
        for door in d["doors"]:
            var t = LD.get_area(door["target"])
            _check(t["spawns"].has(door["spawn"]),
                "%s door leads to a real spawn %s/%s" % [id, door["target"], door["spawn"]])
            seen[door["target"]] = true
    for id in ["room_a", "room_b", "hall_1", "hall_2", "hall_3"]:
        _check(seen.has(id), "%s is reachable from some door" % id)


func _test_junction() -> void:
    await _goto("hall_2", "right")
    Input.action_press("move_right")
    var t0 := Time.get_ticks_msec()
    while game.area_id == "hall_2" and Time.get_ticks_msec() - t0 < 9000:
        await get_tree().process_frame
    _check(game.area_id == "hall_3", "hall_2 right end opens into hall_3 (got %s)" % game.area_id)
    _check(game.player.velocity.x > 0.0, "momentum carried through the doorway (vx=%.0f)" % game.player.velocity.x)
    _log("    junction camera pan: %.0f px" % game.last_slide)
    Input.action_release("move_right")
    await _wait(1.0)
    _check(game.player.mode == 1, "still side-on across a corridor junction")
    _check(game.old_world == null, "junction cleaned up the outgoing corridor")
    await _shot("06_junction")


func _test_walk_into_hallway() -> void:
    # from a known spot: wherever the last test left the player, they might be
    # behind an obstacle, and then walking east just leans on it until the
    # timeout rather than reaching the door
    await _goto("room_a", "start")
    # and let that reload's own fade finish first, or this test measures it
    # instead of the seamless shift it is actually about
    var t_fade := Time.get_ticks_msec()
    while game.fade.color.a > 0.001 and Time.get_ticks_msec() - t_fade < 4000:
        await get_tree().process_frame
    await _wait(0.2)
    var start_x: float = game.player.global_position.x
    Input.action_press("move_right")
    var t0 := Time.get_ticks_msec()
    var peak_fade := 0.0
    while game.area_id == "room_a" and Time.get_ticks_msec() - t0 < 12000:
        await get_tree().process_frame
        peak_fade = maxf(peak_fade, game.fade.color.a)
    Input.action_release("move_right")
    _check(game.old_world != null, "outgoing room stays on screen and dissolves")
    _log("    view-shift camera pan: %.0f px" % game.last_slide)
    var t1 := Time.get_ticks_msec()
    while Time.get_ticks_msec() - t1 < 1100:
        await get_tree().process_frame
        peak_fade = maxf(peak_fade, game.fade.color.a)
    _check(peak_fade < 0.01, "view shift never blacks the screen (peak fade %.3f)" % peak_fade)
    _check(game.old_world == null, "outgoing room cleaned up after the shift")
    _check(game.player.global_position.x != start_x, "player moved on input")
    _check(game.area_id == "hall_1", "walking east reached hall_1 in %dms (got %s)" % [Time.get_ticks_msec() - t0, game.area_id])
    await _wait(0.8)
    _check(game.area_kind == "side", "view swapped to side-on")
    _check(game.player.mode == 1, "player controller is SIDE")
    _check(is_equal_approx(game.camera.rotation, 0.0), "camera tilt settled back to 0")
    _check(game.camera.zoom.x > 1.0, "camera zoomed in for the hallway")
    _check(get_tree().get_nodes_in_group("enemy").size() == 5, "hall_1 spawned its 5 enemies")
    await _shot("02_hall_1_entry")


func _test_combat() -> void:
    await _goto("hall_1", "left")
    var walker = _find_enemy("walker")
    _check(walker != null, "found a walker to fight")
    if walker == null:
        return

    # --- duel: stand off its left shoulder and swing until it dies
    var swings := 0
    var hp_before: int = walker.hp
    var soul_before: int = game.player.soul
    while is_instance_valid(walker) and not walker.dead and swings < 14:
        game.player.health = 5  # keep the duel alive; damage is tested separately
        game.player.global_position = walker.global_position + Vector2(-64, -8)
        game.player.velocity = Vector2.ZERO
        game.player.facing = 1
        await _tap("attack", 0.06)
        await _wait(0.3)
        swings += 1
    var killed: bool = not is_instance_valid(walker) or walker.dead
    _check(killed, "walker died from nail hits")
    _check(swings <= 8, "walker (%d hp) died in %d swings" % [hp_before, swings])
    _check(game.player.soul > soul_before, "landing hits gained soul (%d -> %d)" % [soul_before, game.player.soul])
    await _shot("03_combat_duel")

    # --- pogo: fall onto an enemy with down held, swinging the whole way
    #
    # The down-slash box reaches 17..95 px below you, so drop from 70: at 95 the
    # enemy sat on the very edge of it and whether the pogo landed came down to
    # which frame the swing happened to be active on.
    var bounced := false
    var target = _find_enemy("walker")
    _check(target != null, "found a walker to pogo off")
    if target != null:
        game.player.health = 5
        game.player.invuln = 4.0  # the point here is the bounce, not the contact
        game.player.facing = 1
        Input.action_press("move_down")
        for i in 120:
            if not is_instance_valid(target) or target.dead:
                break
            # stay over it, and go back up if you land: a walker would otherwise
            # just step aside, and a pogo needs you airborne
            game.player.global_position.x = target.global_position.x
            if game.player.is_on_floor() or game.player.global_position.y > target.global_position.y:
                game.player.global_position = target.global_position + Vector2(0, -70)
                game.player.velocity = Vector2(0, 90)
            match i % 12:  # mash it, the way a player would
                0:
                    Input.action_press("attack")
                4:
                    Input.action_release("attack")
            await get_tree().process_frame
            if game.player.velocity.y < -400.0:
                bounced = true
                break
        Input.action_release("move_down")
        Input.action_release("attack")
    _check(bounced, "down-slash pogoed off the enemy")

    # --- contact damage: stand against an enemy and get bitten
    var biter = _find_enemy("walker")
    _check(biter != null, "found a walker to be bitten by")
    if biter != null:
        game.player.health = 5
        game.player.invuln = 0.0
        var hp0: int = game.player.health
        for i in 120:
            if not is_instance_valid(biter) or biter.dead:
                break
            # hold station on it every frame: a patrolling walker would step
            # away from a player who was only placed beside it once
            game.player.global_position = biter.global_position + Vector2(-26, 0)
            game.player.velocity = Vector2.ZERO
            await get_tree().process_frame
            if game.player.health < hp0:
                break
        _check(game.player.health < hp0, "touching an enemy costs a mask (%d -> %d)" % [hp0, game.player.health])
        _check(game.player.invuln > 0.0, "taking damage grants i-frames")

    # --- soul / focus healing
    game.player.health = 3
    game.player.soul = 99
    game.player.invuln = 0.0
    game.player.global_position = Vector2(170, 550)
    game.player.velocity = Vector2.ZERO
    await _wait(0.4)
    Input.action_press("focus")
    await _wait(1.3)
    Input.action_release("focus")
    _check(game.player.health > 3, "focus healed a mask (now %d)" % game.player.health)
    _check(game.player.soul < 99, "focus spent soul (now %d)" % game.player.soul)


func _test_hazard() -> void:
    await _goto("hall_1", "left")
    game.player.health = 5
    game.player.invuln = 0.0
    var hp0: int = game.player.health
    game.player.global_position = Vector2(2260, 600)
    game.player.velocity = Vector2(0, 200)
    var hurt := false
    for i in 120:
        await get_tree().process_frame
        if game.player.health < hp0:
            hurt = true
            break
    _check(hurt, "spikes cost a mask (%d -> %d)" % [hp0, game.player.health])
    await _wait(0.6)
    _check(game.player.global_position.x < 400.0, "spikes put the player back at the entrance (x=%d)" % game.player.global_position.x)

    # falling into the pit during i-frames must still rescue you
    game.player.invuln = 5.0
    game.player.global_position = Vector2(2260, 600)
    game.player.velocity = Vector2(0, 200)
    await _wait(1.5)
    _check(game.player.global_position.y < game.area_size.y, "a pit rescues you even during i-frames (y=%d)" % game.player.global_position.y)


func _test_all_areas() -> void:
    for pair in [["hall_2", "left"], ["hall_3", "left"], ["room_b", "west"], ["room_a", "start"]]:
        await _goto(pair[0], pair[1])
        _check(game.area_id == pair[0], "loaded %s" % pair[0])
        _check(not game.transitioning, "%s finished transitioning" % pair[0])
        var expect_side: bool = pair[0].begins_with("hall")
        _check((game.player.mode == 1) == expect_side, "%s uses the right controller" % pair[0])
        _check((not get_tree().get_nodes_in_group("enemy").is_empty()) == expect_side, "%s has enemies only if it is a hallway" % pair[0])
        var bounds := Rect2(Vector2.ZERO, game.area_size)
        _check(bounds.has_point(game.player.global_position), "%s spawn is inside the area" % pair[0])
        await _shot("04_%s" % pair[0])


func _test_death() -> void:
    await _goto("hall_3", "left")
    _log("    health carried in from the last area: %d" % game.player.health)
    game.player.health = 5

    for i in 7:
        game.player.invuln = 0.0
        game.player.take_damage(1, game.player.global_position + Vector2(60, 0))
        await _wait(0.12)
        if game.player.dead:
            break
    _check(game.player.dead, "running out of masks kills the player")

    var t0 := Time.get_ticks_msec()
    while game.player.dead and Time.get_ticks_msec() - t0 < 8000:
        await get_tree().process_frame
    _check(not game.player.dead, "player revived after death")
    _check(game.player.health == 5, "revive restored masks (%d)" % game.player.health)
    _check(game.area_id == "hall_3", "death reloaded the same area (%s)" % game.area_id)
    _check(get_tree().get_nodes_in_group("enemy").size() == 7, "death respawned hall_3 enemies (%d)" % get_tree().get_nodes_in_group("enemy").size())
    await _wait(1.0)
    _check(not game.transitioning, "world is playable again")
    _check(is_equal_approx(Engine.time_scale, 1.0), "time scale restored after hit stop (%f)" % Engine.time_scale)
    await _shot("05_after_death")


func _capture_shift() -> void:
    # walk into the east doorway, then photograph the view shift frame by frame
    Input.action_press("move_right")
    var t0 := Time.get_ticks_msec()
    while game.area_id == "room_a" and Time.get_ticks_msec() - t0 < 12000:
        await get_tree().process_frame
    Input.action_release("move_right")
    for i in 10:
        await _shot("shift_%02d" % i)
        _log("shift frame %d: zoom=%s slide=%s fade=%.2f" % [i, game.camera.zoom, game._cam_slide, game.fade.color.a])
        await _wait(0.06)


# --------------------------------------------------------------------- helpers

func _goto(id: String, spawn: String) -> void:
    while game.transitioning:
        await get_tree().process_frame
    game.enter_area(id, spawn)
    await _wait(0.2)
    while game.transitioning:
        await get_tree().process_frame
    await _wait(0.6)


func _find_enemy(kind: String):
    for e in get_tree().get_nodes_in_group("enemy"):
        if is_instance_valid(e) and not e.dead and (kind == "" or e.kind == kind):
            return e
    return null


func _check(cond: bool, label: String) -> void:
    checks += 1
    var line := ("  PASS  " if cond else "  FAIL  ") + label
    if not cond:
        failures += 1
    results.append(line)
    _log(line)


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


func _wait(t: float) -> void:
    await get_tree().create_timer(t, true, false, true).timeout


func _tap(action: String, hold := 0.06) -> void:
    Input.action_press(action)
    await _wait(hold)
    Input.action_release(action)


func _shot(name: String) -> void:
    if shots_dir == "":
        return
    # wait for a drawn frame, but never forever: an undrawn window (minimised,
    # display asleep) would otherwise hang the whole run
    var drawn := [false]
    var on_draw := func() -> void: drawn[0] = true
    RenderingServer.frame_post_draw.connect(on_draw, CONNECT_ONE_SHOT)
    var t0 := Time.get_ticks_msec()
    while not drawn[0] and Time.get_ticks_msec() - t0 < 1500:
        await get_tree().process_frame
    if not drawn[0]:
        # never leave the callback armed: firing into a freed node crashes
        if RenderingServer.frame_post_draw.is_connected(on_draw):
            RenderingServer.frame_post_draw.disconnect(on_draw)
        _log("    (screenshot %s skipped: window is not being drawn)" % name)
        return
    var vp := get_viewport()
    if vp == null:
        return
    var img := vp.get_texture().get_image()
    if img != null:
        img.save_png("%s/%s.png" % [shots_dir, name])
