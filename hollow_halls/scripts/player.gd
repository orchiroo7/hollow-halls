extends CharacterBody2D
## One body, two control schemes.
##
## TOPDOWN: 8-directional walking around the wide rooms. No combat.
## SIDE:    Hollow-Knight-ish platforming in the hallways - tight jump with
##          cut + coyote + buffer, a dash, a directional nail slash with
##          recoil / pogo, i-frames, and soul-powered healing.

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4

# --- top-down tuning
const TD_SPEED := 300.0
const TD_ACCEL := 3000.0
const TD_FRICTION := 3600.0

# --- side-view tuning
const RUN_SPEED := 340.0
const GROUND_ACCEL := 4200.0
const AIR_ACCEL := 3000.0
const FRICTION := 4800.0
const GRAVITY := 2000.0
const MAX_FALL := 1150.0
const JUMP_VELOCITY := -820.0
const JUMP_CUT := 0.42
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12

const DASH_SPEED := 900.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.45

const ATTACK_COOLDOWN := 0.30
const ATTACK_ACTIVE := 0.12
const RECOIL_SPEED := 260.0
const POGO_SPEED := 700.0

const MAX_HEALTH := 5
const IFRAME_TIME := 1.1
const HURT_LOCK := 0.22
const HURT_KNOCKBACK := Vector2(320, -320)

const SOUL_MAX := 99
const SOUL_PER_HIT := 11
const FOCUS_COST := 33
const FOCUS_TIME := 0.85

enum Mode { TOPDOWN, SIDE }

var game = null
var mode: int = Mode.TOPDOWN

var health := MAX_HEALTH
var soul := 0
var facing := 1

var coyote := 0.0
var buffer := 0.0
var dash_time := 0.0
var dash_cd := 0.0
var dash_dir := 1
var attack_time := 0.0
var attack_cd := 0.0
var attack_dir := Vector2.RIGHT
var swing_hits: Array = []
var invuln := 0.0
var hurt_lock := 0.0
var focus_time := 0.0
var dead := false

var _shape: RectangleShape2D
var _body_art: Polygon2D
var _edge: Polygon2D
var _crest: Polygon2D
var _eye: Polygon2D
var _prev_floor := true
var _fall_speed := 0.0
var _ghost_t := 0.0
var _slash: Polygon2D
var _focus_ring: Polygon2D
var _blink := 0.0

const Boxes := preload("res://scripts/boxes.gd")
const Look := preload("res://scripts/look.gd")
const Fx := preload("res://scripts/fx.gd")


func _ready() -> void:
    add_to_group("player")
    collision_layer = LAYER_PLAYER
    collision_mask = LAYER_WORLD
    floor_snap_length = 10.0
    floor_constant_speed = true
    z_index = 10

    _shape = RectangleShape2D.new()
    _shape.size = Vector2(28, 44)
    var cs := CollisionShape2D.new()
    cs.shape = _shape
    add_child(cs)

    _body_art = Boxes.make_box(Vector2(28, 44), Look.BONE)
    add_child(_body_art)
    _edge = Boxes.make_box(Vector2(34, 50), Look.INK)
    _edge.show_behind_parent = true
    _body_art.add_child(_edge)
    # a crest, so the silhouette is yours and nothing else's
    _crest = Boxes.make_box(Vector2(16, 8), Look.CYAN)
    add_child(_crest)
    _eye = Boxes.make_box(Vector2(8, 8), Look.INK)
    add_child(_eye)

    _slash = Polygon2D.new()
    _slash.color = Color(1, 1, 1, 0.9)
    _slash.visible = false
    _slash.z_index = 12
    add_child(_slash)

    _focus_ring = Boxes.make_box(Vector2(60, 60), Color(Look.CYAN.r, Look.CYAN.g, Look.CYAN.b, 0.35))
    _focus_ring.visible = false
    add_child(_focus_ring)


func set_mode(kind: String) -> void:
    mode = Mode.SIDE if kind == "side" else Mode.TOPDOWN
    velocity = Vector2.ZERO
    dash_time = 0.0
    attack_time = 0.0
    focus_time = 0.0
    swing_hits.clear()
    _slash.visible = false
    _focus_ring.visible = false
    if mode == Mode.SIDE:
        _shape.size = Vector2(28, 44)
        _set_art(Vector2(28, 44))
    else:
        _shape.size = Vector2(30, 34)
        _set_art(Vector2(30, 34))


func _set_art(size: Vector2) -> void:
    var h := size * 0.5
    _body_art.polygon = PackedVector2Array([
        Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)
    ])


func _physics_process(delta: float) -> void:
    if dead:
        return
    if game != null and game.transitioning:
        return  # frozen mid-shift, but keep velocity so momentum carries through

    invuln = max(0.0, invuln - delta)
    hurt_lock = max(0.0, hurt_lock - delta)
    attack_cd = max(0.0, attack_cd - delta)
    dash_cd = max(0.0, dash_cd - delta)

    # backstop: anything that ends up below the area counts as a pit
    if game != null and global_position.y > game.area_size.y + 200.0:
        hazard_hit()
        return

    if mode == Mode.SIDE:
        _side_process(delta)
    else:
        _topdown_process(delta)

    _update_visuals(delta)


# ------------------------------------------------------------------ top-down

func _topdown_process(delta: float) -> void:
    var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if hurt_lock > 0.0:
        dir = Vector2.ZERO
    if dir.length() > 0.01:
        velocity = velocity.move_toward(dir.normalized() * TD_SPEED, TD_ACCEL * delta)
        if absf(dir.x) > 0.2:
            facing = signi(int(signf(dir.x)))
    else:
        velocity = velocity.move_toward(Vector2.ZERO, TD_FRICTION * delta)
    move_and_slide()


# ----------------------------------------------------------------- side-view

func _side_process(delta: float) -> void:
    var on_floor := is_on_floor()
    coyote = COYOTE_TIME if on_floor else max(0.0, coyote - delta)
    buffer = max(0.0, buffer - delta)

    if Input.is_action_just_pressed("jump"):
        buffer = JUMP_BUFFER

    var move := Input.get_axis("move_left", "move_right")
    if hurt_lock > 0.0:
        move = 0.0

    # --- focus / heal (stand still, hold the key)
    var focusing := Input.is_action_pressed("focus") and on_floor and hurt_lock <= 0.0 \
        and absf(move) < 0.1 and soul >= FOCUS_COST and health < MAX_HEALTH and dash_time <= 0.0
    if focusing:
        focus_time += delta
        _focus_ring.visible = true
        _focus_ring.scale = Vector2.ONE * lerpf(0.3, 1.0, clampf(focus_time / FOCUS_TIME, 0.0, 1.0))
        if focus_time >= FOCUS_TIME:
            focus_time = 0.0
            soul -= FOCUS_COST
            health = min(MAX_HEALTH, health + 1)
            if game != null:
                game.on_heal()
        velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
        velocity.y += GRAVITY * delta
        move_and_slide()
        return
    else:
        focus_time = 0.0
        _focus_ring.visible = false

    # --- dash
    if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and hurt_lock <= 0.0:
        dash_time = DASH_TIME
        dash_cd = DASH_COOLDOWN
        dash_dir = int(signf(move)) if absf(move) > 0.1 else facing
        facing = dash_dir
        if game != null:
            game.shake(4.0)

    if dash_time > 0.0:
        dash_time -= delta
        _ghost_t -= delta
        if _ghost_t <= 0.0:
            _ghost_t = 0.035
            Fx.ghost(get_parent(), global_position, _shape.size, Color(Look.CYAN.r, Look.CYAN.g, Look.CYAN.b, 0.45))
        velocity = Vector2(dash_dir * DASH_SPEED, 0.0)
        move_and_slide()
        _tick_attack(delta)
        return

    # --- attack
    if Input.is_action_just_pressed("attack") and attack_cd <= 0.0:
        _start_attack()

    # --- horizontal
    if absf(move) > 0.1:
        facing = int(signf(move))
        var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
        velocity.x = move_toward(velocity.x, move * RUN_SPEED, accel * delta)
    else:
        velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

    # --- jump
    if buffer > 0.0 and coyote > 0.0:
        velocity.y = JUMP_VELOCITY
        buffer = 0.0
        coyote = 0.0
    if Input.is_action_just_released("jump") and velocity.y < 0.0:
        velocity.y *= JUMP_CUT

    velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL)
    move_and_slide()
    _tick_attack(delta)


func _start_attack() -> void:
    attack_cd = ATTACK_COOLDOWN
    attack_time = ATTACK_ACTIVE
    swing_hits.clear()
    if Input.is_action_pressed("move_up"):
        attack_dir = Vector2.UP
    elif Input.is_action_pressed("move_down") and not is_on_floor():
        attack_dir = Vector2.DOWN
    else:
        attack_dir = Vector2(facing, 0)
    _show_slash()


func _tick_attack(delta: float) -> void:
    if attack_time <= 0.0:
        return
    attack_time -= delta
    _hit_query()
    if attack_time <= 0.0:
        _slash.visible = false


func _hit_query() -> void:
    var box := _attack_box()
    var params := PhysicsShapeQueryParameters2D.new()
    var shape := RectangleShape2D.new()
    shape.size = box.size
    params.shape = shape
    params.transform = Transform2D(0.0, global_position + box.position)
    params.collision_mask = LAYER_ENEMY
    params.collide_with_bodies = true
    params.collide_with_areas = false
    var hits := get_world_2d().direct_space_state.intersect_shape(params, 8)
    for h in hits:
        var col = h["collider"]
        if col == null or swing_hits.has(col) or not col.has_method("take_hit"):
            continue
        swing_hits.append(col)
        col.take_hit(1, attack_dir, global_position)
        _on_hit_landed()


func _on_hit_landed() -> void:
    soul = min(SOUL_MAX, soul + SOUL_PER_HIT)
    if attack_dir == Vector2.DOWN:
        velocity.y = -POGO_SPEED
        coyote = 0.0
        dash_cd = 0.0
    elif attack_dir == Vector2.UP:
        velocity.y = max(velocity.y, 120.0)
    else:
        velocity.x = -facing * RECOIL_SPEED
    if game != null:
        game.hit_stop(0.055)
        game.shake(7.0)


func _attack_box() -> Rect2:
    if attack_dir == Vector2.UP:
        return Rect2(Vector2(0, -56), Vector2(58, 78))
    if attack_dir == Vector2.DOWN:
        return Rect2(Vector2(0, 56), Vector2(58, 78))
    return Rect2(Vector2(facing * 52, 0), Vector2(84, 58))


func _show_slash() -> void:
    var box := _attack_box()
    var h := box.size * 0.5
    _slash.polygon = PackedVector2Array([
        Vector2(-h.x, -h.y * 0.55), Vector2(h.x * 0.15, -h.y),
        Vector2(h.x, 0), Vector2(h.x * 0.15, h.y), Vector2(-h.x, h.y * 0.55)
    ])
    _slash.rotation = box.position.angle()
    _slash.position = box.position
    _slash.visible = true
    _slash.modulate = Color(1, 1, 1, 1)
    _slash.scale = Vector2(0.75, 1.0)
    var tw := create_tween()
    tw.tween_property(_slash, "scale", Vector2(1.15, 0.8), ATTACK_ACTIVE)
    tw.parallel().tween_property(_slash, "modulate:a", 0.0, ATTACK_ACTIVE)


# --------------------------------------------------------------------- state

func take_damage(amount: int, from_pos: Vector2) -> void:
    if dead or invuln > 0.0 or (game != null and game.transitioning):
        return
    health -= amount
    invuln = IFRAME_TIME
    hurt_lock = HURT_LOCK
    focus_time = 0.0
    dash_time = 0.0
    attack_time = 0.0
    _slash.visible = false
    var away := signf(global_position.x - from_pos.x)
    if away == 0.0:
        away = -facing
    if mode == Mode.SIDE:
        velocity = Vector2(away * HURT_KNOCKBACK.x, HURT_KNOCKBACK.y)
    else:
        velocity = Vector2(away * 200.0, 0)
    if game != null:
        game.hit_stop(0.09)
        game.shake(14.0)
    if health <= 0:
        _die()


func hazard_hit() -> void:
    if dead or (game != null and game.transitioning):
        return
    # i-frames skip the damage, never the rescue: the pits have no floor, so
    # returning early here used to let you fall forever
    if invuln <= 0.0:
        health -= 1
        invuln = IFRAME_TIME
        hurt_lock = HURT_LOCK
        if game != null:
            game.hit_stop(0.09)
            game.shake(16.0)
        if health <= 0:
            _die()
            return
    if game != null:
        game.respawn_at_safe_spot()


func _die() -> void:
    dead = true
    velocity = Vector2.ZERO
    if game != null:
        game.on_player_died()


func revive() -> void:
    dead = false
    health = MAX_HEALTH
    soul = 0
    invuln = 1.0
    velocity = Vector2.ZERO


func _update_visuals(delta: float) -> void:
    var grounded := is_on_floor()
    if mode == Mode.SIDE:
        if not grounded:
            _fall_speed = maxf(_fall_speed, velocity.y)
        elif not _prev_floor:
            if _fall_speed > 620.0:
                Fx.burst(get_parent(), global_position + Vector2(0, _shape.size.y * 0.5), Color(0.82, 0.85, 0.98, 0.5), 10, 200.0, 3, true)
            _fall_speed = 0.0
    _prev_floor = grounded

    _eye.position = Vector2(facing * 7, -6) if mode == Mode.SIDE else Vector2(facing * 8, -4)
    _crest.position = Vector2(-facing * 4, -_shape.size.y * 0.5 - 4)
    if invuln > 0.0:
        _blink += delta
        var on := fmod(_blink, 0.12) < 0.06
        _body_art.color = Look.BLOOD if on else Color(Look.BONE.r, Look.BONE.g, Look.BONE.b, 0.45)
    else:
        _blink = 0.0
        _body_art.color = Look.BONE
    # squash/stretch while airborne
    if mode == Mode.SIDE:
        var s := clampf(velocity.y / 900.0, -0.35, 0.35)
        _body_art.scale = Vector2(1.0 - absf(s) * 0.4, 1.0 + s * 0.35) if not is_on_floor() else Vector2.ONE
    else:
        _body_art.scale = Vector2.ONE
