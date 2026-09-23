extends Node2D
## Root. Owns the player, the camera, area loading and the view shift.
##
## Door transitions are seamless: no fade to black. The outgoing area stays on
## screen and dissolves while the incoming one builds underneath it, and the
## camera never cuts - at the first frame of a shift the player and the old
## geometry are exactly where they were, and the camera then slides and tips
## into the new framing. Tipping is faked by squashing the camera vertically
## (zoom.y) down to a grazing angle and back out, which is what going from an
## overhead view to a side-on one looks like.

const LevelData := preload("res://scripts/level_data.gd")
const WorldBuilder := preload("res://scripts/world_builder.gd")
const PlayerScript := preload("res://scripts/player.gd")
const HudScript := preload("res://scripts/hud.gd")
const Look := preload("res://scripts/look.gd")

const START_AREA := "room_a"
const START_SPAWN := "start"

const ZOOM_TOPDOWN := Vector2(0.8, 0.8)
const ZOOM_SIDE := Vector2(1.15, 1.15)

const SHIFT_TIME := 0.55        # length of a seamless door transition
const PITCH := 0.24             # how flat the view gets at the tip of a view change
const PITCH_IN := 0.42          # fraction of the shift spent tipping over
const MAX_CAM_SLIDE := 1600.0   # cap on how far the camera slides to stay continuous
const ENTRY_SPEED := 220.0      # forward nudge when stepping out of a doorway

var world: Node2D
var old_world: Node2D = null
var player = null
var camera: Camera2D
var hud = null
var fade: ColorRect

var area_id := START_AREA
var spawn_key := START_SPAWN
var area_kind := "topdown"
var area_size := Vector2(1600, 1000)

var transitioning := false
var door_lock := 0.0
var _shake := 0.0
var _cam_pos := Vector2.ZERO
var _cam_slide := Vector2.ZERO
var _hitstops := 0
var last_slide := 0.0  # diagnostic: how far the last shift had to pan


func _ready() -> void:
	RenderingServer.set_default_clear_color(Look.VOID)
	add_child(Look.environment())

	world = Node2D.new()
	world.name = "World"
	add_child(world)

	player = PlayerScript.new()
	player.game = self
	add_child(player)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.ignore_rotation = false
	add_child(camera)
	camera.make_current()

	hud = HudScript.new()
	add_child(hud)

	add_child(Look.vignette())

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 20
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade)

	await get_tree().process_frame
	enter_area(START_AREA, START_SPAWN, true)


func _process(delta: float) -> void:
	door_lock = max(0.0, door_lock - delta)

	if player != null:
		var target: Vector2 = player.global_position
		if area_kind == "side":
			target.y -= 40.0
			target.x += player.facing * 50.0
		var t := 1.0 - pow(0.0008, delta)
		_cam_pos = _cam_pos.lerp(_clamp_cam(target), t)
		camera.global_position = _cam_pos + _cam_slide

	if _shake > 0.0:
		_shake = max(0.0, _shake - delta * 42.0)
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		camera.offset = camera.offset.lerp(Vector2.ZERO, 0.4)

	hud.set_health(player.health, PlayerScript.MAX_HEALTH)
	hud.set_soul(player.soul, PlayerScript.SOUL_MAX)


## Keep the view inside the area. Done by hand rather than with Camera2D limits
## because the zoom animates during a shift: when the view grows taller than the
## area we centre on it instead, which stays continuous with the clamped case.
func _clamp_cam(pos: Vector2) -> Vector2:
	var half: Vector2 = get_viewport_rect().size * 0.5 / camera.zoom
	var p := pos
	if area_size.x <= half.x * 2.0:
		p.x = area_size.x * 0.5
	else:
		p.x = clampf(p.x, half.x, area_size.x - half.x)
	if area_size.y <= half.y * 2.0:
		p.y = area_size.y * 0.5
	else:
		p.y = clampf(p.y, half.y, area_size.y - half.y)
	return p


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		get_tree().quit()
	elif event.is_action_pressed("restart") and not transitioning:
		player.revive()
		hud.show_death(false)
		enter_area(area_id, spawn_key, false, true)


# ---------------------------------------------------------------- transitions

func request_transition(target: String, spawn: String) -> void:
	if transitioning or door_lock > 0.0 or player.dead:
		return
	# doors fire from inside a physics callback, so never touch the tree here
	call_deferred("enter_area", target, spawn, false, false)


func enter_area(id: String, spawn: String, instant := false, use_fade := false) -> void:
	if transitioning and not instant:
		return
	transitioning = true

	var from_kind := area_kind
	var cam_before: Vector2 = camera.global_position
	var zoom_before: Vector2 = camera.zoom
	var pos_before: Vector2 = player.global_position
	var vel_before: Vector2 = player.velocity
	var seamless := not instant and not use_fade
	player.velocity = Vector2.ZERO

	if use_fade and not instant:
		await _fade_to(1.0, 0.16)

	# retire the outgoing area: for a seamless shift it stays on screen and
	# dissolves, otherwise it goes immediately
	if old_world != null:
		old_world.queue_free()
		old_world = null
	if seamless:
		old_world = world
		old_world.name = "OldWorld"
		_retire(old_world)
	else:
		world.queue_free()

	var fresh := Node2D.new()
	fresh.name = "World"
	add_child(fresh)
	move_child(fresh, 0)  # behind the dissolving old area, both behind the player
	world = fresh

	area_id = id
	spawn_key = spawn
	var data := LevelData.get_area(id)
	area_kind = data["kind"]
	area_size = data["size"]
	WorldBuilder.build(data, world, self)

	player.set_mode(area_kind)
	player.global_position = data["spawns"][spawn]
	_carry_momentum(from_kind, spawn, vel_before)

	hud.set_area(data["name"], area_kind)
	door_lock = SHIFT_TIME + 0.15

	var target_zoom: Vector2 = ZOOM_SIDE if area_kind == "side" else ZOOM_TOPDOWN

	if not seamless:
		camera.zoom = target_zoom
		camera.rotation = 0.0
		_cam_slide = Vector2.ZERO
		_cam_pos = _clamp_cam(player.global_position)
		camera.global_position = _cam_pos
		# covers both the first load (opens from black) and a death reload
		await _fade_to(0.0, 0.22)
		transitioning = false
		return

	await _shift(from_kind, target_zoom, zoom_before, cam_before, pos_before)
	transitioning = false


## The seamless view shift. Starts as a pixel-perfect continuation of the last
## frame, then slides, dissolves and (on a view change) tips the camera over.
func _shift(from_kind: String, target_zoom: Vector2, zoom_before: Vector2,
		cam_before: Vector2, pos_before: Vector2) -> void:
	var changed_view := from_kind != area_kind

	# hold the zoom, so frame zero looks exactly like the frame before it
	camera.zoom = zoom_before
	var cam_new := _clamp_cam(player.global_position)
	_cam_pos = cam_new

	# slide the camera so the player does not jump on screen, then ease it out
	var slide: Vector2 = (player.global_position - cam_new) - (pos_before - cam_before)
	last_slide = slide.length()
	slide = slide.limit_length(MAX_CAM_SLIDE)
	_cam_slide = slide
	camera.global_position = cam_new + slide

	# pin the outgoing area to where it already was on screen
	old_world.position = cam_new + slide - cam_before

	world.modulate.a = 0.0
	if changed_view:
		camera.rotation = deg_to_rad(2.5 if area_kind == "side" else -2.5)

	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(self, "_cam_slide", Vector2.ZERO, SHIFT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "zoom:x", target_zoom.x, SHIFT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "rotation", 0.0, SHIFT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(old_world, "modulate:a", 0.0, SHIFT_TIME * 0.75)
	tw.tween_property(world, "modulate:a", 1.0, SHIFT_TIME * 0.6)

	if changed_view:
		# tip over: flatten the view to a grazing angle, then open it back up
		var tip := create_tween()
		tip.set_ignore_time_scale(true)
		tip.tween_property(camera, "zoom:y", target_zoom.y * PITCH, SHIFT_TIME * PITCH_IN) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tip.tween_property(camera, "zoom:y", target_zoom.y, SHIFT_TIME * (1.0 - PITCH_IN)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(camera, "zoom:y", target_zoom.y, SHIFT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	await tw.finished
	camera.zoom = target_zoom
	camera.rotation = 0.0
	_cam_slide = Vector2.ZERO
	if old_world != null:
		old_world.queue_free()
		old_world = null


## An area on its way out keeps drawing but must stop being part of the game:
## no collision, and its enemies leave the group so nothing counts them twice.
func _retire(w: Node) -> void:
	w.process_mode = Node.PROCESS_MODE_DISABLED
	for n in w.get_children():
		if n is CollisionObject2D:
			n.collision_layer = 0
			n.collision_mask = 0
		if n.is_in_group("enemy"):
			n.remove_from_group("enemy")


## Step out of a doorway still moving, instead of landing at a dead stop.
func _carry_momentum(from_kind: String, spawn: String, vel_before: Vector2) -> void:
	if area_kind != "side":
		return
	if from_kind == "side":
		player.velocity.x = clampf(vel_before.x, -PlayerScript.RUN_SPEED, PlayerScript.RUN_SPEED)
		if absf(player.velocity.x) < ENTRY_SPEED:
			player.velocity.x = ENTRY_SPEED * (1.0 if spawn == "left" else -1.0)
	else:
		player.velocity.x = ENTRY_SPEED * (1.0 if spawn == "left" else -1.0)
	player.facing = 1 if player.velocity.x >= 0.0 else -1


func _fade_to(alpha: float, time: float) -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(fade, "color:a", alpha, time)
	await tw.finished


# ------------------------------------------------------------------- feedback

func hit_stop(duration: float) -> void:
	_hitstops += 1
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	_hitstops -= 1
	if _hitstops <= 0:
		_hitstops = 0
		Engine.time_scale = 1.0


func shake(amount: float) -> void:
	_shake = max(_shake, amount)


func on_heal() -> void:
	shake(3.0)


func respawn_at_safe_spot() -> void:
	call_deferred("_do_respawn")


func _do_respawn() -> void:
	if transitioning:
		return
	var data := LevelData.get_area(area_id)
	player.global_position = data["spawns"][spawn_key]
	player.velocity = Vector2.ZERO
	_cam_pos = _clamp_cam(player.global_position)


func on_player_died() -> void:
	hud.show_death(true)
	_die_and_reload()


func _die_and_reload() -> void:
	transitioning = true
	Engine.time_scale = 1.0
	_hitstops = 0
	await get_tree().create_timer(1.1, true, false, true).timeout
	hud.show_death(false)
	player.revive()
	transitioning = false
	enter_area(area_id, spawn_key, false, true)
