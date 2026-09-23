extends RefCounted

const LevelData := preload("res://scripts/level_data.gd")
const Boxes := preload("res://scripts/boxes.gd")
const Look := preload("res://scripts/look.gd")
const Fx := preload("res://scripts/fx.gd")
const EnemyScript := preload("res://scripts/enemy.gd")

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4


static func build(data: Dictionary, world: Node2D, game: Node) -> void:
    if data["kind"] == "topdown":
        _build_topdown(data, world, game)
    else:
        _build_side(data, world, game)


static func make_box(size: Vector2, color: Color) -> Polygon2D:
    return Boxes.make_box(size, color)


static func add_solid(parent: Node, rect: Rect2, color: Color) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = rect.position + rect.size * 0.5
    body.collision_layer = LAYER_WORLD
    body.collision_mask = 0
    var cs := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    cs.shape = shape
    body.add_child(cs)
    var face := Boxes.make_box(rect.size, color, Look.OUTLINE)
    Look.tile(face, rect.position, 96.0)
    body.add_child(face)
    var hi := make_box(Vector2(rect.size.x, min(6.0, rect.size.y * 0.25)), color.lightened(0.25))
    hi.position = Vector2(0, -rect.size.y * 0.5 + min(3.0, rect.size.y * 0.125))
    body.add_child(hi)
    parent.add_child(body)
    return body


static func add_decor(parent: Node, rect: Rect2, color: Color) -> Polygon2D:
    var p := make_box(rect.size, color)
    p.position = rect.position + rect.size * 0.5
    parent.add_child(p)
    return p


static func add_label(parent: Node, text: String, pos: Vector2, color := Color(0.6, 0.62, 0.7), size := 20) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_color_override("font_color", color)
    l.add_theme_font_size_override("font_size", size)
    l.position = pos
    l.z_index = 5
    parent.add_child(l)
    return l


static func add_door(parent: Node, rect: Rect2, target: String, spawn: String, game: Node, color: Color) -> Area2D:
    var area := Area2D.new()
    area.position = rect.position + rect.size * 0.5
    area.collision_layer = 0
    area.collision_mask = LAYER_PLAYER
    var cs := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    cs.shape = shape
    area.add_child(cs)

    var glow := make_box(rect.size * 1.25, Color(color.r, color.g, color.b, 0.22))
    glow.z_index = -1
    area.add_child(glow)
    var frame := make_box(rect.size, Color(color.r, color.g, color.b, 0.75))
    area.add_child(frame)
    var inner := make_box(rect.size * 0.62, Look.GOLD)
    area.add_child(inner)

    var g = game
    area.body_entered.connect(func(body: Node) -> void:
        if body.is_in_group("player"):
            g.request_transition(target, spawn)
    )
    parent.add_child(area)
    return area


static func add_hazard(parent: Node, rect: Rect2, game: Node) -> Area2D:
    var area := Area2D.new()
    area.position = rect.position + rect.size * 0.5
    area.collision_layer = 0
    area.collision_mask = LAYER_PLAYER
    var cs := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    cs.shape = shape
    area.add_child(cs)
    var teeth := int(rect.size.x / 22.0)
    for i in teeth:
        var t := Polygon2D.new()
        t.polygon = PackedVector2Array([Vector2(-10, 12), Vector2(0, -14), Vector2(10, 12)])
        t.color = Look.BLOOD
        t.position = Vector2(-rect.size.x * 0.5 + 11 + i * 22, -rect.size.y * 0.5 + 6)
        area.add_child(t)
    area.body_entered.connect(func(body: Node) -> void:
        if body.is_in_group("player"):
            var p = body
            p.hazard_hit()
    )
    parent.add_child(area)
    return area


static func _build_topdown(data: Dictionary, world: Node2D, game: Node) -> void:
    var size: Vector2 = data["size"]
    var floor_color: Color = data["floor_color"]
    var wall_color: Color = data["wall_color"]

    var bg := Boxes.gradient_box(size * 3.0, floor_color.lightened(0.06), floor_color.darkened(0.3))
    bg.position = size * 0.5
    bg.z_index = -20
    world.add_child(bg)

    var tiles := Boxes.make_box(size, floor_color.lightened(0.04))
    Look.tile(tiles, Vector2.ZERO, 100.0)
    tiles.position = size * 0.5
    tiles.z_index = -19
    world.add_child(tiles)
    _add_inlays(world, size, floor_color)

    var gaps := {"north": [], "south": [], "east": [], "west": []}
    for d in data["doors"]:
        gaps[d["side"]].append(Vector2(d["at"] - d["span"] * 0.5, d["at"] + d["span"] * 0.5))

    for seg in _segments(size.x, gaps["north"]):
        add_solid(world, Rect2(seg.x, 0, seg.y - seg.x, LevelData.WALL), wall_color)
    for seg in _segments(size.x, gaps["south"]):
        add_solid(world, Rect2(seg.x, size.y - LevelData.WALL, seg.y - seg.x, LevelData.WALL), wall_color)
    for seg in _segments(size.y, gaps["west"]):
        add_solid(world, Rect2(0, seg.x, LevelData.WALL, seg.y - seg.x), wall_color)
    for seg in _segments(size.y, gaps["east"]):
        add_solid(world, Rect2(size.x - LevelData.WALL, seg.x, LevelData.WALL, seg.y - seg.x), wall_color)

    for r in data["obstacles"]:
        add_solid(world, r, wall_color.darkened(0.25))

    for d in data["doors"]:
        var rect := _door_rect(d, size)
        add_door(world, rect, d["target"], d["spawn"], game, Look.GOLD)
        var lp: Vector2 = rect.position + rect.size * 0.5 + _door_label_offset(d["side"])
        add_label(world, "HALLWAY", lp - Vector2(46, 12), Color(Look.GOLD.r, Look.GOLD.g, Look.GOLD.b, 0.9), 18)


static func _add_inlays(world: Node2D, size: Vector2, floor_color: Color) -> void:
    var c := size * 0.5
    var ring := Rect2(c - Vector2(260, 180), Vector2(520, 360))
    add_decor(world, ring, floor_color.lightened(0.05)).z_index = -18
    add_decor(world, ring.grow(-14), floor_color.darkened(0.22)).z_index = -17
    add_decor(world, Rect2(c - Vector2(56, 56), Vector2(112, 112)), floor_color.lightened(0.1)).z_index = -16
    for x in [size.x * 0.18, size.x * 0.82]:
        var sx: float = x
        add_decor(world, Rect2(sx - 5, 120, 10, size.y - 240), floor_color.lightened(0.08)).z_index = -18


static func _door_rect(d: Dictionary, size: Vector2) -> Rect2:
    var w := LevelData.WALL
    match d["side"]:
        "north": return Rect2(d["at"] - d["span"] * 0.5, 0, d["span"], w)
        "south": return Rect2(d["at"] - d["span"] * 0.5, size.y - w, d["span"], w)
        "west": return Rect2(0, d["at"] - d["span"] * 0.5, w, d["span"])
        _: return Rect2(size.x - w, d["at"] - d["span"] * 0.5, w, d["span"])


static func _door_label_offset(side: String) -> Vector2:
    match side:
        "north": return Vector2(0, 54)
        "south": return Vector2(0, -54)
        "west": return Vector2(96, 0)
        _: return Vector2(-96, 0)


static func _segments(length: float, gaps: Array) -> Array:
    var sorted_gaps := gaps.duplicate()
    sorted_gaps.sort_custom(func(a, b): return a.x < b.x)
    var segs := []
    var cursor := 0.0
    for g in sorted_gaps:
        if g.x > cursor:
            segs.append(Vector2(cursor, g.x))
        cursor = max(cursor, g.y)
    if cursor < length:
        segs.append(Vector2(cursor, length))
    return segs


static func _build_side(data: Dictionary, world: Node2D, game: Node) -> void:
    var size: Vector2 = data["size"]
    var sky: Color = data["bg_color"]
    var bg := Boxes.gradient_box(size * 3.0, sky.darkened(0.45), sky.lightened(0.3))
    bg.position = size * 0.5
    bg.z_index = -20
    world.add_child(bg)

    var rng := RandomNumberGenerator.new()
    rng.seed = hash(data["id"])
    for band in 2:
        var lift := 0.22 + band * 0.2
        for i in 9:
            var w := rng.randf_range(140, 420)
            var h := rng.randf_range(160, 520)
            var r := Rect2(rng.randf_range(-100, size.x - w + 100), rng.randf_range(0, size.y - h), w, h)
            var slab := add_decor(world, r, sky.lerp(Color(0.34, 0.31, 0.5), lift))
            slab.z_index = -19 + band
            Look.tile(slab, r.position, 80.0)

    var motes := Fx.dust(size * 1.2)
    motes.position = size * 0.5
    world.add_child(motes)

    for r in data["solids"]:
        add_solid(world, r, data["solid_color"])

    for r in data["hazards"]:
        add_hazard(world, r, game)

    for e in data["enemies"]:
        var enemy = EnemyScript.new()
        enemy.kind = e["kind"]
        enemy.position = e["pos"]
        enemy.game = game
        world.add_child(enemy)

    for d in data["doors"]:
        add_door(world, d["rect"], d["target"], d["spawn"], game, Look.GOLD)
        add_label(world, "ROOM", d["rect"].position + Vector2(0, -34), Color(Look.GOLD.r, Look.GOLD.g, Look.GOLD.b, 0.9), 18)
