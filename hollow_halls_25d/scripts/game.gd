extends Node3D
## Root. Builds the world, owns the player, the camera rig, checkpoints,
## hit stop and death.
##
## The level is one continuous 3D space, so there are no area transitions at
## all: you walk from a room into a hallway and the only thing that changes is
## the name in the corner. The camera is entirely in the player's hands.
##
## Lighting has two looks, blended by the camera rig as it swings: FLAT (no sun,
## pure white ambient, linear tonemap - every surface shows its exact colour,
## no shading, no shadows, like the 2D original) and DEPTH (sun and shadows on,
## dimmer tinted ambient) for the 3D reveal between views.

const LevelData := preload("res://scripts/level_data.gd")
const WorldBuilder := preload("res://scripts/world_builder.gd")
const PlayerScript := preload("res://scripts/player.gd")
const RigScript := preload("res://scripts/camera_rig.gd")
const HudScript := preload("res://scripts/hud.gd")
const Look := preload("res://scripts/look.gd")
const Fx := preload("res://scripts/fx.gd")
const TouchScript := preload("res://scripts/touch.gd")

var world: Node3D
var enemies_root: Node3D
var env: Environment
var sun: DirectionalLight3D
var player = null
var rig = null
var hud = null
var fade: ColorRect
var dust: GPUParticles3D
var touch = null

var region_id := ""
var region_kind := ""
var checkpoint := LevelData.START
var frozen := false  # death / respawn sequence: player and enemies hold still

var _checkpoint_pending := false
var _hitstops := 0


func _ready() -> void:
    env = Environment.new()
    # a gradient in every direction instead of a black void - the flat views
    # have no horizon of their own, so the sky is all the depth they get
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Look.VOID
    sky_mat.sky_horizon_color = Look.HORIZON
    sky_mat.ground_horizon_color = Look.HORIZON
    sky_mat.ground_bottom_color = Look.VOID
    sky_mat.sky_energy_multiplier = 1.0
    sky_mat.use_debanding = true
    var sky := Sky.new()
    sky.sky_material = sky_mat
    env.sky = sky
    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
    env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    # bloom, so the gold doors, the spikes and you carry light of your own
    env.glow_enabled = true
    env.glow_intensity = 0.55
    env.glow_bloom = 0.05
    env.glow_strength = 1.1
    env.glow_hdr_threshold = 0.95
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)

    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-60, 30, 0)
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 250.0
    add_child(sun)
    set_depth_look(0.0)

    world = Node3D.new()
    world.name = "World"
    add_child(world)
    var occluders := WorldBuilder.build(world)

    enemies_root = Node3D.new()
    enemies_root.name = "Enemies"
    add_child(enemies_root)
    WorldBuilder.spawn_enemies(enemies_root, self)

    player = PlayerScript.new()
    player.game = self
    player.position = checkpoint
    add_child(player)

    rig = RigScript.new()
    rig.game = self
    rig.target = player
    rig.occluders = occluders
    add_child(rig)
    rig.snap()
    player.rig = rig

    hud = HudScript.new()
    add_child(hud)

    # a phone gets its own controls, and a HUD sized for a hand
    if TouchScript.wanted():
        touch = TouchScript.new()
        touch.rig = rig
        add_child(touch)
        hud.set_compact(true)

    add_child(Look.vignette())

    dust = Fx.dust(Vector3(22, 9, 22))
    add_child(dust)

    var fade_layer := CanvasLayer.new()
    fade_layer.layer = 20
    add_child(fade_layer)
    fade = ColorRect.new()
    fade.color = Color(0, 0, 0, 1)
    fade.set_anchors_preset(Control.PRESET_FULL_RECT)
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fade_layer.add_child(fade)
    _fade_to(0.0, 0.4)


func _process(_delta: float) -> void:
    dust.global_position = player.global_position
    _track_region()
    hud.set_health(player.health, PlayerScript.MAX_HEALTH)
    hud.set_soul(player.soul, PlayerScript.SOUL_MAX)
    hud.set_camera(rig.view_name(), rig.is_side(), rig.is_free())


## Name the area you are in, and drop a checkpoint on the first solid ground
## you touch after entering a new one.
func _track_region() -> void:
    var r := LevelData.region_at(player.global_position)
    if not r.is_empty() and r["id"] != region_id:
        var came_from := region_kind
        region_id = r["id"]
        region_kind = r["kind"]
        hud.set_area(r["name"], r["kind"])
        _checkpoint_pending = true
        # stepping through a door into a hallway: a moment to get your bearings
        if region_kind == "hall" and came_from == "room":
            player.start_entry_buffer()
    if _checkpoint_pending and not frozen and player.is_on_floor():
        checkpoint = player.global_position + Vector3(0, 0.1, 0)
        _checkpoint_pending = false


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("quit_game"):
        get_tree().quit()
    elif event.is_action_pressed("restart") and not frozen:
        _reset_sequence(false)
    elif event.is_action_pressed("cam_cycle"):
        rig.cycle_view()
    elif event.is_action_pressed("cam_free"):
        rig.toggle_free()
    elif event.is_action_pressed("cam_left"):
        rig.rotate_steps(-1)   # ignored in the orbit, which polls Q/E held
    elif event.is_action_pressed("cam_right"):
        rig.rotate_steps(1)
    elif event.is_action_pressed("cam_top"):
        rig.set_view(0)
    elif event.is_action_pressed("cam_side"):
        rig.set_view(1)


## 0 = flat 2D look, 1 = full 3D look. Driven every frame by the camera rig.
func set_depth_look(amount: float) -> void:
    sun.light_energy = 1.3 * amount
    env.ambient_light_color = Color.WHITE.lerp(Color(0.55, 0.58, 0.75), amount)
    env.ambient_light_energy = lerpf(1.0, 0.55, amount)


## Gameplay holds still during death, respawns, and while the camera swings.
func paused() -> bool:
    return frozen or (rig != null and rig.swinging())


# ------------------------------------------------------------------ respawns

func respawn_at_checkpoint() -> void:
    call_deferred("_do_respawn")  # spikes fire from inside a physics callback


func _do_respawn() -> void:
    if frozen:
        return
    player.global_position = checkpoint
    player.velocity = Vector3.ZERO
    rig.snap()


func on_player_died() -> void:
    _reset_sequence(true)


## Death (and R): brief pause, fade, enemies respawn, you return to the last
## checkpoint with full masks.
func _reset_sequence(died: bool) -> void:
    frozen = true
    Engine.time_scale = 1.0
    _hitstops = 0
    if died:
        hud.show_death(true)
        await get_tree().create_timer(1.0, true, false, true).timeout
    await _fade_to(1.0, 0.2)
    reset_enemies()
    player.revive()
    player.global_position = checkpoint
    rig.snap()
    hud.show_death(false)
    await _fade_to(0.0, 0.25)
    frozen = false


func reset_enemies() -> void:
    for e in enemies_root.get_children():
        e.remove_from_group("enemy")
        enemies_root.remove_child(e)
        e.queue_free()
    WorldBuilder.spawn_enemies(enemies_root, self)


func _fade_to(alpha: float, time: float) -> void:
    var tw := create_tween()
    tw.set_ignore_time_scale(true)
    tw.tween_property(fade, "color:a", alpha, time)
    await tw.finished


# ------------------------------------------------------------------ feedback

func hit_stop(duration: float) -> void:
    _hitstops += 1
    Engine.time_scale = 0.05
    await get_tree().create_timer(duration, true, false, true).timeout
    _hitstops -= 1
    if _hitstops <= 0:
        _hitstops = 0
        Engine.time_scale = 1.0


func shake(amount: float) -> void:
    rig.add_shake(amount)
