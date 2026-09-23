extends CharacterBody2D

const LAYER_WORLD := 1
const LAYER_ENEMY := 4

const Boxes := preload("res://scripts/boxes.gd")
const Look := preload("res://scripts/look.gd")
const Fx := preload("res://scripts/fx.gd")

@export var kind := "walker"
var game = null

var hp := 6
var max_hp := 6
var size := Vector2(40, 40)
var dir := 1
var stun := 0.0
var flash := 0.0
var dead := false
var contact_damage := 1
var touch_cd := 0.0

var _speed := 80.0
var _chase_speed := 170.0
var _sight := 300.0
var _gravity := 2000.0
var _bob := 0.0
var _home := Vector2.ZERO

var _art: Polygon2D
var _eye_l: Polygon2D
var _eye_r: Polygon2D
var _hp_bar: Polygon2D
var _shape: RectangleShape2D
var _ledge_ray: RayCast2D
var _wall_ray: RayCast2D


func _ready() -> void:
    add_to_group("enemy")
    collision_layer = LAYER_ENEMY
    collision_mask = LAYER_WORLD
    z_index = 8
    _home = global_position
    _bob = randf() * TAU

    var body_color := Look.BLOOD
    if kind == "flyer":
        size = Vector2(34, 34)
        max_hp = 4
        _speed = 0.0
        _chase_speed = 190.0
        _sight = 460.0
        _gravity = 0.0
        body_color = Look.EMBER
    else:
        size = Vector2(40, 40)
        max_hp = 6
        _speed = 85.0
        _chase_speed = 175.0
        _sight = 300.0
    hp = max_hp

    _shape = RectangleShape2D.new()
    _shape.size = size
    var cs := CollisionShape2D.new()
    cs.shape = _shape
    add_child(cs)

    _art = Boxes.make_box(size, body_color, Look.OUTLINE)
    add_child(_art)
    _eye_l = Boxes.make_box(Vector2(6, 6), Look.INK)
    _eye_r = Boxes.make_box(Vector2(6, 6), Look.INK)
    add_child(_eye_l)
    add_child(_eye_r)

    _hp_bar = Boxes.make_box(Vector2(size.x, 4), Look.GOLD)
    _hp_bar.position = Vector2(0, -size.y * 0.5 - 10)
    _hp_bar.visible = false
    add_child(_hp_bar)

    _ledge_ray = RayCast2D.new()
    _ledge_ray.target_position = Vector2(0, size.y)
    _ledge_ray.collision_mask = LAYER_WORLD
    add_child(_ledge_ray)
    _wall_ray = RayCast2D.new()
    _wall_ray.target_position = Vector2(size.x, 0)
    _wall_ray.collision_mask = LAYER_WORLD
    add_child(_wall_ray)


func _physics_process(delta: float) -> void:
    if dead:
        return
    if game != null and game.transitioning:
        return

    flash = max(0.0, flash - delta)
    touch_cd = max(0.0, touch_cd - delta)
    _art.color = _art.color.lerp(_base_color(), 1.0 - pow(0.001, delta))

    var player = get_tree().get_first_node_in_group("player")

    if stun > 0.0:
        stun -= delta
        velocity.y += _gravity * delta
        velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
        move_and_slide()
        _touch_check(player)
        return

    if kind == "flyer":
        _fly(delta, player)
    else:
        _walk(delta, player)

    _touch_check(player)
    _face()


func _base_color() -> Color:
    if kind == "flyer":
        return Look.EMBER
    return Look.BLOOD


func _walk(delta: float, player) -> void:
    var target_speed := _speed
    if player != null and not player.dead:
        var to_player: Vector2 = player.global_position - global_position
        if absf(to_player.x) < _sight and absf(to_player.y) < 90.0:
            dir = int(signf(to_player.x)) if absf(to_player.x) > 8.0 else dir
            target_speed = _chase_speed

    _ledge_ray.position = Vector2(dir * (size.x * 0.5 + 6), 0)
    _wall_ray.target_position = Vector2(dir * (size.x * 0.6 + 8), 0)
    _ledge_ray.force_raycast_update()
    _wall_ray.force_raycast_update()

    if is_on_floor() and (not _ledge_ray.is_colliding() or _wall_ray.is_colliding()):
        dir = -dir

    velocity.x = move_toward(velocity.x, dir * target_speed, 1400.0 * delta)
    velocity.y = min(velocity.y + _gravity * delta, 1200.0)
    move_and_slide()


func _fly(delta: float, player) -> void:
    _bob += delta * 2.4
    var target := _home + Vector2(0, sin(_bob) * 18.0)
    if player != null and not player.dead:
        var d: float = global_position.distance_to(player.global_position)
        if d < _sight:
            target = player.global_position + Vector2(0, -6)
    var desired: Vector2 = (target - global_position)
    if desired.length() > 6.0:
        desired = desired.normalized() * _chase_speed
    else:
        desired = Vector2.ZERO
    velocity = velocity.move_toward(desired, 900.0 * delta)
    if absf(velocity.x) > 12.0:
        dir = int(signf(velocity.x))
    move_and_slide()


func _face() -> void:
    _eye_l.position = Vector2(dir * 4 - 6, -3)
    _eye_r.position = Vector2(dir * 4 + 6, -3)


func _touch_check(player) -> void:
    if player == null or player.dead or touch_cd > 0.0:
        return
    var me := Rect2(global_position - size * 0.5, size)
    var ps := Vector2(28, 44)
    var you := Rect2(player.global_position - ps * 0.5, ps)
    if me.intersects(you):
        touch_cd = 0.4
        player.take_damage(contact_damage, global_position)


func take_hit(amount: int, from_dir: Vector2, from_pos: Vector2) -> void:
    if dead:
        return
    hp -= amount
    stun = 0.16
    flash = 0.12
    _art.color = Color(1, 1, 1)
    _hp_bar.visible = true
    _hp_bar.scale = Vector2(float(hp) / float(max_hp), 1.0)

    var push := Vector2.ZERO
    if from_dir == Vector2.UP:
        push = Vector2(0, -280)
    elif from_dir == Vector2.DOWN:
        push = Vector2(0, 260)
    else:
        push = Vector2(signf(global_position.x - from_pos.x) * 320.0, -120.0)
        if push.x == 0.0:
            push.x = from_dir.x * 320.0
    velocity = push
    if kind == "flyer":
        _home = global_position

    if hp <= 0:
        _die()


func _die() -> void:
    dead = true
    if game != null:
        game.hit_stop(0.08)
        game.shake(10.0)
    _burst()
    queue_free()


func _burst() -> void:
    var parent := get_parent()
    if parent == null:
        return
    for i in 9:
        var bit := Boxes.make_box(Vector2(8, 8), _base_color().lightened(0.2))
        bit.position = global_position
        bit.z_index = 9
        parent.add_child(bit)
        var dirv := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40, 120)
        var tw := bit.create_tween()
        tw.tween_property(bit, "position", bit.position + dirv, 0.45)
        tw.parallel().tween_property(bit, "modulate:a", 0.0, 0.45)
        tw.parallel().tween_property(bit, "rotation", randf_range(-4, 4), 0.45)
        tw.tween_callback(bit.queue_free)
