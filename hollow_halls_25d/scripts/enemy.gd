extends CharacterBody3D
## Hallway enemies, as boxes in 3D.
##   walker - patrols along its corridor, turns at ledges and walls, chases you
##            when you are close and level with it (but will not walk off edges)
##   flyer  - bobs in place until it spots you, then homes in through the air

const Meshes := preload("res://scripts/meshes.gd")
const Look := preload("res://scripts/look.gd")

const LAYER_WORLD := 1
const LAYER_ENEMY := 4
const PLAYER_SIZE := Vector3(0.8, 1.4, 0.8)

var kind := "walker"
var axis := Vector3(1, 0, 0)
var game = null
var home_rects: Array = []  # the hallway this enemy belongs to; it never leaves

var hp := 6
var max_hp := 6
var size := Vector3.ONE
var dir := 1
var stun := 0.0
var dead := false
var touch_cd := 0.0

var _speed := 2.5
var _chase_speed := 5.0
var _sight := 7.0
var _gravity := 38.0
var _bob := 0.0
var _home := Vector3.ZERO
var _face := Vector3(1, 0, 0)
var _base_color := Look.BLOOD

var _visual: Node3D
var _mat: StandardMaterial3D
var _hp_bar: MeshInstance3D
var _ledge_ray: RayCast3D
var _wall_ray: RayCast3D


func _ready() -> void:
    add_to_group("enemy")
    add_to_group("plane_only")
    collision_layer = LAYER_ENEMY
    collision_mask = LAYER_WORLD
    _home = global_position
    _bob = randf() * TAU

    if kind == "flyer":
        size = Vector3(0.8, 0.8, 0.8)
        max_hp = 4
        _chase_speed = 5.5
        _sight = 9.0
        _gravity = 0.0
        _base_color = Look.EMBER
    hp = max_hp

    var cs := CollisionShape3D.new()
    if kind == "flyer":
        var box := BoxShape3D.new()
        box.size = size
        cs.shape = box
    else:
        # walkers cross floor seams too, so they get the capsule treatment
        var cap := CapsuleShape3D.new()
        cap.radius = size.x * 0.45
        cap.height = size.y
        cs.shape = cap
    add_child(cs)

    _visual = Node3D.new()
    add_child(_visual)
    var body := Meshes.box(size, _base_color, false, false, Look.OUTLINE_THICK)
    _mat = body.material_override
    _mat.emission_enabled = true
    _mat.emission = _base_color
    _mat.emission_energy_multiplier = 0.3
    _visual.add_child(body)
    for side in [-1.0, 1.0]:
        var sx: float = side
        var eye := Meshes.box(Vector3(0.12, 0.12, 0.06), Look.INK, true)
        eye.position = Vector3(sx * size.x * 0.22, size.y * 0.15, size.z * 0.5 + 0.02)
        _visual.add_child(eye)

    _hp_bar = Meshes.box(Vector3(size.x, 0.1, 0.1), Look.GOLD, true)
    _hp_bar.position = Vector3(0, size.y * 0.5 + 0.35, 0)
    _hp_bar.visible = false
    add_child(_hp_bar)

    _ledge_ray = RayCast3D.new()
    _ledge_ray.collision_mask = LAYER_WORLD
    add_child(_ledge_ray)
    _wall_ray = RayCast3D.new()
    _wall_ray.collision_mask = LAYER_WORLD
    add_child(_wall_ray)
    _face = axis


func _physics_process(delta: float) -> void:
    if dead:
        return
    if game != null and game.paused():
        return

    touch_cd = maxf(0.0, touch_cd - delta)
    _mat.albedo_color = _mat.albedo_color.lerp(_base_color, 1.0 - pow(0.001, delta))
    var player = get_tree().get_first_node_in_group("player")

    if stun > 0.0:
        stun -= delta
        if kind == "flyer":
            velocity = velocity.move_toward(Vector3.ZERO, 20.0 * delta)
        else:
            velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
            velocity.y = maxf(velocity.y - _gravity * delta, -30.0)
        move_and_slide()
        _touch_check(player)
        return

    if kind == "flyer":
        _fly(delta, player)
    else:
        _walk(delta, player)
    _touch_check(player)
    _visual.rotation.y = atan2(_face.x, _face.z)


func _walk(delta: float, player) -> void:
    var desired: Vector3 = axis * dir
    var speed := _speed
    var chasing := false
    if player != null and not player.dead and not player.is_hidden():
        var to: Vector3 = player.global_position - global_position
        var flat := Vector3(to.x, 0.0, to.z)
        if flat.length() < _sight and absf(to.y) < 1.6 and flat.length() > 0.2:
            desired = flat.normalized()
            speed = _chase_speed
            chasing = true

    # the world is continuous, so nothing but this keeps enemies out of the
    # rooms: treat the edge of the home hallway like a ledge
    if not _inside_home(global_position, 0.0):
        var back := _home - global_position
        back.y = 0.0
        desired = back.normalized()
        speed = _speed
        chasing = false
    var ahead := global_position + desired * (size.x * 0.5 + 0.3)
    var leaving := _inside_home(global_position, 0.0) and not _inside_home(ahead, 1.0)

    _ledge_ray.position = desired * (size.x * 0.5 + 0.25)
    _ledge_ray.target_position = Vector3(0, -1.6, 0)
    _wall_ray.position = Vector3.ZERO
    _wall_ray.target_position = desired * (size.x * 0.5 + 0.3)
    _ledge_ray.force_raycast_update()
    _wall_ray.force_raycast_update()

    if leaving or (is_on_floor() and (not _ledge_ray.is_colliding() or _wall_ray.is_colliding())):
        if chasing:
            desired = Vector3.ZERO  # glare at you from the edge
        else:
            dir = -dir
            desired = axis * dir

    var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired * speed, 30.0 * delta)
    velocity.x = hv.x
    velocity.z = hv.z
    velocity.y = maxf(velocity.y - _gravity * delta, -30.0)
    move_and_slide()
    if desired.length() > 0.1:
        _face = desired


func _fly(delta: float, player) -> void:
    _bob += delta * 2.4
    var goal := _home + Vector3(0, sin(_bob) * 0.35, 0)
    if player != null and not player.dead and not player.is_hidden():
        var d: float = global_position.distance_to(player.global_position)
        if d < _sight and _inside_home(player.global_position, 0.5):
            goal = player.global_position + Vector3(0, 0.3, 0)
    var desired := goal - global_position
    if desired.length() > 0.15:
        desired = desired.normalized() * _chase_speed
    else:
        desired = Vector3.ZERO
    velocity = velocity.move_toward(desired, 18.0 * delta)
    move_and_slide()
    var flat := Vector3(velocity.x, 0.0, velocity.z)
    if flat.length() > 0.3:
        _face = flat.normalized()


func _inside_home(p: Vector3, margin: float) -> bool:
    if home_rects.is_empty():
        return true
    var q := Vector2(p.x, p.z)
    for r in home_rects:
        var rr: Rect2 = r
        if rr.grow(-margin).has_point(q):
            return true
    return false


func _touch_check(player) -> void:
    if player == null or player.dead or player.is_hidden() or touch_cd > 0.0:
        return
    var me := AABB(global_position - size * 0.5, size)
    var ppos: Vector3 = player.global_position
    var you := AABB(ppos - PLAYER_SIZE * 0.5, PLAYER_SIZE)
    if me.intersects(you):
        touch_cd = 0.4
        player.take_damage(1, global_position)


func take_hit(amount: int, from_dir: Vector3, from_pos: Vector3) -> void:
    if dead:
        return
    hp -= amount
    stun = 0.16
    _mat.albedo_color = Color(1, 1, 1)
    _hp_bar.visible = true
    _hp_bar.scale = Vector3(maxf(float(hp) / float(max_hp), 0.01), 1.0, 1.0)

    var push := Vector3.ZERO
    if from_dir == Vector3.UP:
        push = Vector3(0, 7, 0)
    elif from_dir == Vector3.DOWN:
        push = Vector3(0, -5, 0)
    else:
        var away := global_position - from_pos
        away.y = 0.0
        if away.length() < 0.01:
            away = from_dir
        push = away.normalized() * 7.0 + Vector3(0, 3, 0)
    velocity = push
    if kind == "flyer" and _inside_home(global_position, 0.5):
        _home = global_position

    if hp <= 0:
        _die()


func _die() -> void:
    dead = true
    remove_from_group("enemy")
    if game != null:
        game.hit_stop(0.08)
        game.shake(0.3)
    _burst()
    queue_free()


func _burst() -> void:
    var parent := get_parent()
    if parent == null:
        return
    for i in 10:
        var bit := Meshes.box(Vector3(0.18, 0.18, 0.18), _base_color.lightened(0.2), true)
        parent.add_child(bit)
        bit.global_position = global_position
        var out := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized() * randf_range(0.8, 2.0)
        var tw := bit.create_tween()
        tw.tween_property(bit, "position", bit.position + out, 0.45)
        tw.parallel().tween_property(bit, "scale", Vector3.ZERO, 0.45)
        tw.parallel().tween_property(bit, "rotation", Vector3(randf() * 6, randf() * 6, 0), 0.45)
        tw.tween_callback(bit.queue_free)
