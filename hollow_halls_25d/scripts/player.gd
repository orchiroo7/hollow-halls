extends CharacterBody3D

const Meshes := preload("res://scripts/meshes.gd")
const Look := preload("res://scripts/look.gd")
const Fx := preload("res://scripts/fx.gd")

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4

const SIZE := Vector3(0.8, 1.4, 0.8)

const RUN_SPEED := 7.5
const GROUND_ACCEL := 80.0
const AIR_ACCEL := 55.0
const FRICTION := 90.0
const GRAVITY := 38.0
const MAX_FALL := 30.0
const JUMP_VELOCITY := 15.0
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12

const DASH_SPEED := 20.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.45

const ATTACK_COOLDOWN := 0.30
const ATTACK_ACTIVE := 0.12
const RECOIL_SPEED := 6.0
const POGO_SPEED := 14.0

const MAX_HEALTH := 5
const IFRAME_TIME := 1.1
const HURT_LOCK := 0.22

const SOUL_MAX := 99
const SOUL_PER_HIT := 11
const FOCUS_COST := 33
const FOCUS_TIME := 0.85

const KILL_Y := -12.0

const ENTRY_BUFFER := 2.0
const GHOST_ALPHA := 0.35

var game = null
var rig = null

var health := MAX_HEALTH
var soul := 0
var facing_vec := Vector3(1, 0, 0)

var coyote := 0.0
var buffer := 0.0
var dash_time := 0.0
var dash_cd := 0.0
var dash_dir := Vector3(1, 0, 0)
var attack_time := 0.0
var attack_cd := 0.0
var attack_dir := Vector3(1, 0, 0)
var swing_hits: Array = []
var invuln := 0.0
var hurt_lock := 0.0
var focus_time := 0.0
var dead := false
var unseen := 0.0

var _visual: Node3D
var _body_mat: StandardMaterial3D
var _edge_mat: StandardMaterial3D
var _crest_mat: StandardMaterial3D
var _prev_floor := true
var _fall_speed := 0.0
var _ghost_t := 0.0
var _slash: MeshInstance3D
var _slash_mesh: BoxMesh
var _slash_mat: StandardMaterial3D
var _focus_ring: MeshInstance3D
var _blink := 0.0


func _ready() -> void:
    add_to_group("player")
    collision_layer = LAYER_PLAYER
    collision_mask = LAYER_WORLD
    floor_snap_length = 0.3

    var cs := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = SIZE.x * 0.48
    shape.height = SIZE.y
    cs.shape = shape
    add_child(cs)

    _visual = Node3D.new()
    add_child(_visual)
    var body := Meshes.box(SIZE, Look.BONE, false, false, Look.OUTLINE_THICK)
    _body_mat = body.material_override
    _edge_mat = _body_mat.next_pass
    _body_mat.emission_enabled = true
    _body_mat.emission = Look.BONE
    _body_mat.emission_energy_multiplier = 0.35
    _visual.add_child(body)
    var visor := Meshes.box(Vector3(0.5, 0.16, 0.08), Look.INK, true)
    visor.position = Vector3(0, 0.32, SIZE.z * 0.5 + 0.02)
    _visual.add_child(visor)
    var crest := Meshes.box(Vector3(0.24, 0.34, 0.5), Look.CYAN, true)
    _crest_mat = crest.material_override
    _crest_mat.emission_enabled = true
    _crest_mat.emission = Look.CYAN
    _crest_mat.emission_energy_multiplier = 1.6
    crest.position = Vector3(0, SIZE.y * 0.5 + 0.06, -0.12)
    _visual.add_child(crest)
    var nose := Meshes.box(Vector3(0.18, 0.06, 0.34), Look.CYAN, true)
    nose.position = Vector3(0, SIZE.y * 0.5 + 0.02, SIZE.z * 0.28)
    _visual.add_child(nose)

    _slash = MeshInstance3D.new()
    _slash_mesh = BoxMesh.new()
    _slash.mesh = _slash_mesh
    _slash_mat = StandardMaterial3D.new()
    _slash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _slash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _slash_mat.albedo_color = Color(1, 1, 1, 0.85)
    _slash.material_override = _slash_mat
    _slash.visible = false
    add_child(_slash)

    _focus_ring = MeshInstance3D.new()
    var ring := CylinderMesh.new()
    ring.top_radius = 1.0
    ring.bottom_radius = 1.0
    ring.height = 0.05
    _focus_ring.mesh = ring
    var ring_mat := StandardMaterial3D.new()
    ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring_mat.albedo_color = Color(Look.CYAN.r, Look.CYAN.g, Look.CYAN.b, 0.45)
    ring_mat.emission_enabled = true
    ring_mat.emission = Look.CYAN
    ring_mat.emission_energy_multiplier = 1.2
    _focus_ring.material_override = ring_mat
    _focus_ring.position = Vector3(0, -SIZE.y * 0.5 + 0.05, 0)
    _focus_ring.visible = false
    add_child(_focus_ring)


func _physics_process(delta: float) -> void:
    if dead or rig == null:
        return
    if game != null and game.paused():
        return

    invuln = maxf(0.0, invuln - delta)
    unseen = maxf(0.0, unseen - delta)
    hurt_lock = maxf(0.0, hurt_lock - delta)
    attack_cd = maxf(0.0, attack_cd - delta)
    dash_cd = maxf(0.0, dash_cd - delta)

    if global_position.y < KILL_Y:
        hazard_hit()
        return

    var on_floor := is_on_floor()
    coyote = COYOTE_TIME if on_floor else maxf(0.0, coyote - delta)
    buffer = maxf(0.0, buffer - delta)
    if Input.is_action_just_pressed("jump"):
        buffer = JUMP_BUFFER

    var side: bool = rig.is_side()
    var right: Vector3 = rig.right_axis()
    var fwd: Vector3 = rig.forward_axis()
    var ix := Input.get_axis("move_left", "move_right")
    var iy := Input.get_axis("move_down", "move_up")
    if hurt_lock > 0.0:
        ix = 0.0
        iy = 0.0
    var wish := right * ix
    if not side:
        wish += fwd * iy
    if wish.length() > 1.0:
        wish = wish.normalized()
    if wish.length() > 0.1:
        facing_vec = wish.normalized()

    var focusing := Input.is_action_pressed("focus") and on_floor and hurt_lock <= 0.0 \
        and wish.length() < 0.1 and soul >= FOCUS_COST and health < MAX_HEALTH and dash_time <= 0.0
    if focusing:
        focus_time += delta
        _focus_ring.visible = true
        var k := lerpf(0.3, 1.0, clampf(focus_time / FOCUS_TIME, 0.0, 1.0))
        _focus_ring.scale = Vector3(k, 1.0, k)
        if focus_time >= FOCUS_TIME:
            focus_time = 0.0
            soul -= FOCUS_COST
            health = mini(MAX_HEALTH, health + 1)
            if game != null:
                game.shake(0.1)
        velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
        velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
        velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL)
        move_and_slide()
        _update_visuals(delta, side)
        return
    focus_time = 0.0
    _focus_ring.visible = false

    if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and hurt_lock <= 0.0:
        dash_time = DASH_TIME
        dash_cd = DASH_COOLDOWN
        if wish.length() > 0.1:
            dash_dir = wish.normalized()
        else:
            dash_dir = side_facing() if side else facing_vec
        facing_vec = dash_dir
        if game != null:
            game.shake(0.12)

    if dash_time > 0.0:
        dash_time -= delta
        _ghost_t -= delta
        if _ghost_t <= 0.0:
            _ghost_t = 0.035
            Fx.ghost(get_parent(), global_position, SIZE, _visual.rotation.y, Color(Look.CYAN.r, Look.CYAN.g, Look.CYAN.b, 0.5))
        velocity = dash_dir * DASH_SPEED
        move_and_slide()
        _tick_attack(delta)
        _update_visuals(delta, side)
        return

    if Input.is_action_just_pressed("attack") and attack_cd <= 0.0:
        _start_attack(side)

    var hv := Vector3(velocity.x, 0.0, velocity.z)
    if wish.length() > 0.1:
        hv = hv.move_toward(wish * RUN_SPEED, (GROUND_ACCEL if on_floor else AIR_ACCEL) * delta)
    else:
        hv = hv.move_toward(Vector3.ZERO, FRICTION * delta)
    if side:
        hv -= fwd * hv.dot(fwd)
    velocity.x = hv.x
    velocity.z = hv.z

    if buffer > 0.0 and coyote > 0.0:
        velocity.y = JUMP_VELOCITY
        buffer = 0.0
        coyote = 0.0
    if Input.is_action_just_released("jump") and velocity.y > 0.0:
        velocity.y *= JUMP_CUT

    velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL)
    move_and_slide()
    _tick_attack(delta)
    _update_visuals(delta, side)


func side_sign() -> float:
    if rig == null:
        return 1.0
    var r: Vector3 = rig.right_axis()
    var s := signf(facing_vec.dot(r))
    return s if s != 0.0 else 1.0


func side_facing() -> Vector3:
    var r: Vector3 = rig.right_axis()
    return r * side_sign()


func _start_attack(side: bool) -> void:
    attack_cd = ATTACK_COOLDOWN
    attack_time = ATTACK_ACTIVE
    swing_hits.clear()
    if side and Input.is_action_pressed("move_up"):
        attack_dir = Vector3.UP
    elif side and Input.is_action_pressed("move_down") and not is_on_floor():
        attack_dir = Vector3.DOWN
    elif side:
        attack_dir = side_facing()
    else:
        attack_dir = facing_vec
    _show_slash()


func _tick_attack(delta: float) -> void:
    if attack_time <= 0.0:
        return
    attack_time -= delta
    _hit_query()
    if attack_time <= 0.0:
        _slash.visible = false


func _attack_box() -> Array:
    if attack_dir == Vector3.UP:
        return [Vector3(0, 1.3, 0), Vector3(1.5, 1.8, 1.5)]
    if attack_dir == Vector3.DOWN:
        return [Vector3(0, -1.2, 0), Vector3(1.5, 1.8, 1.5)]
    return [attack_dir * 1.15, Vector3(2.0, 1.5, 2.0)]


func _hit_query() -> void:
    var box := _attack_box()
    var offset: Vector3 = box[0]
    var size: Vector3 = box[1]
    var params := PhysicsShapeQueryParameters3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    params.shape = shape
    params.transform = Transform3D(Basis(), global_position + offset)
    params.collision_mask = LAYER_ENEMY
    var hits := get_world_3d().direct_space_state.intersect_shape(params, 8)
    for h in hits:
        var col = h["collider"]
        if col == null or swing_hits.has(col) or not col.has_method("take_hit"):
            continue
        swing_hits.append(col)
        col.take_hit(1, attack_dir, global_position)
        _on_hit_landed()


func _on_hit_landed() -> void:
    soul = mini(SOUL_MAX, soul + SOUL_PER_HIT)
    if attack_dir == Vector3.DOWN:
        velocity.y = POGO_SPEED
        coyote = 0.0
        dash_cd = 0.0
    elif attack_dir == Vector3.UP:
        velocity.y = minf(velocity.y, -1.0)
    else:
        velocity.x = -attack_dir.x * RECOIL_SPEED
        velocity.z = -attack_dir.z * RECOIL_SPEED
    Fx.burst(get_parent(), global_position + attack_dir * 1.1, Color(1, 1, 1, 0.9), 12, 7.0, 0.14, 0.2)
    if game != null:
        game.hit_stop(0.055)
        game.shake(0.18)


func _show_slash() -> void:
    var box := _attack_box()
    var offset: Vector3 = box[0]
    var size: Vector3 = box[1]
    if attack_dir == Vector3.UP or attack_dir == Vector3.DOWN:
        _slash_mesh.size = Vector3(size.x, 0.2, size.z)
        _slash.rotation = Vector3.ZERO
    else:
        _slash_mesh.size = Vector3(size.x, size.y * 0.9, 0.25)
        _slash.rotation = Vector3(0, atan2(attack_dir.x, attack_dir.z), 0)
    _slash.position = offset
    _slash.scale = Vector3(0.7, 1.0, 0.7)
    _slash.visible = true
    _slash_mat.albedo_color = Color(1, 1, 1, 0.85)
    var tw := create_tween()
    tw.tween_property(_slash, "scale", Vector3(1.2, 0.85, 1.2), ATTACK_ACTIVE)
    tw.parallel().tween_property(_slash_mat, "albedo_color:a", 0.0, ATTACK_ACTIVE)


func is_hidden() -> bool:
    return unseen > 0.0


func start_entry_buffer() -> void:
    unseen = ENTRY_BUFFER


func take_damage(amount: int, from_pos: Vector3) -> void:
    if dead or invuln > 0.0 or unseen > 0.0 or (game != null and game.frozen):
        return
    health -= amount
    invuln = IFRAME_TIME
    hurt_lock = HURT_LOCK
    focus_time = 0.0
    dash_time = 0.0
    attack_time = 0.0
    _slash.visible = false

    var away := global_position - from_pos
    away.y = 0.0
    if rig != null and rig.is_side():
        var f: Vector3 = rig.forward_axis()
        away -= f * away.dot(f)
    if away.length() < 0.01:
        away = -facing_vec
    velocity = away.normalized() * 8.0 + Vector3(0, 7.0, 0)

    if game != null:
        game.hit_stop(0.09)
        game.shake(0.35)
    if health <= 0:
        _die()


func hazard_hit() -> void:
    if dead or (game != null and game.frozen):
        return
    if invuln <= 0.0 and unseen <= 0.0:
        health -= 1
        invuln = IFRAME_TIME
        hurt_lock = HURT_LOCK
        if game != null:
            game.hit_stop(0.09)
            game.shake(0.4)
        if health <= 0:
            _die()
            return
    velocity = Vector3.ZERO
    if game != null:
        game.respawn_at_checkpoint()


func _die() -> void:
    dead = true
    velocity = Vector3.ZERO
    if game != null:
        game.on_player_died()


func revive() -> void:
    dead = false
    health = MAX_HEALTH
    soul = 0
    invuln = 1.0
    unseen = 0.0
    velocity = Vector3.ZERO
    _visual.visible = true


func _update_visuals(delta: float, side: bool) -> void:
    var grounded := is_on_floor()
    if not grounded:
        _fall_speed = minf(_fall_speed, velocity.y)
    elif not _prev_floor:
        if _fall_speed < -9.0:
            Fx.burst(get_parent(), global_position - Vector3(0, SIZE.y * 0.5, 0), Color(0.82, 0.85, 0.98, 0.5), 10, 3.5, 0.12, 0.35)
        _fall_speed = 0.0
    _prev_floor = grounded

    var face: Vector3 = side_facing() if side else facing_vec
    _visual.rotation.y = atan2(face.x, face.z)

    var want_a := GHOST_ALPHA if unseen > 0.0 else 1.0
    if not is_equal_approx(_body_mat.albedo_color.a, want_a):
        var mode: BaseMaterial3D.Transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if want_a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
        for m in [_body_mat, _edge_mat, _crest_mat]:
            var mat: StandardMaterial3D = m
            var c := mat.albedo_color
            c.a = want_a
            mat.albedo_color = c
            mat.transparency = mode

    if invuln > 0.0:
        _blink += delta
        _visual.visible = fmod(_blink, 0.12) < 0.07
    else:
        _blink = 0.0
        _visual.visible = true

    if side:
        if not is_on_floor():
            var st := clampf(velocity.y / 30.0, -0.35, 0.35)
            _visual.scale = Vector3(1.0 - absf(st) * 0.4, 1.0 + absf(st) * 0.35, 1.0 - absf(st) * 0.4)
        else:
            _visual.scale = Vector3.ONE
    elif rig != null and rig.is_free():
        _visual.scale = Vector3.ONE
    else:
        var k := 1.0 + clampf(height_above_ground(), 0.0, 6.0) * 0.08
        _visual.scale = Vector3(k, k, k)


func height_above_ground() -> float:
    var from := global_position
    var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -30, 0), LAYER_WORLD)
    var hit := get_world_3d().direct_space_state.intersect_ray(q)
    if hit.is_empty():
        return 6.0
    var ground: Vector3 = hit["position"]
    return maxf(0.0, from.y - ground.y - SIZE.y * 0.5)
