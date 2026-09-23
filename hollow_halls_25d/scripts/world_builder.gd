extends RefCounted
## Turns level_data.gd into nodes: lit boxes, colliders, spike pits, signposts
## and enemies.

const LevelData := preload("res://scripts/level_data.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const Meshes := preload("res://scripts/meshes.gd")
const DoorScript := preload("res://scripts/door.gd")
const Look := preload("res://scripts/look.gd")

const LAYER_WORLD := 1
const LAYER_PLAYER := 2

const COLORS := {
    "floor_room": Look.FLOOR_ROOM,
    "wall_room": Look.WALL_ROOM,
    "floor_hall": Look.FLOOR_HALL,
    "wall_hall": Look.WALL_HALL,
    "platform": Look.PLATFORM,
    "crate": Look.CRATE,
    "pit_floor": Look.PIT,
    "door": Look.GOLD,
    "inlay": Color(0.115, 0.12, 0.185),
    "trim": Color(0.42, 0.42, 0.6),
}

## Terrain reads as terrain because it is tiled; the things you stand on, climb
## and bump into read as objects because they are outlined.
const TILED := ["floor_room", "wall_room", "floor_hall", "wall_hall", "pit_floor"]
const OUTLINED := ["platform", "crate"]

## Kinds the camera is allowed to fade when they get between it and the player.
const OCCLUDER_KINDS := ["wall_room", "wall_hall", "platform", "crate", "floor_room", "floor_hall", "pit_floor", "door"]


## Builds all static geometry under root. Returns the occluders: one entry per
## box the camera can fade, {mesh, mat, aabb}.
static func build(root: Node3D) -> Array:
    var occluders: Array = []
    for s in LevelData.solids():
        var kind: String = s["kind"]
        var aabb: AABB = s["aabb"]
        var color: Color = COLORS.get(kind, Color.MAGENTA)
        var info := add_box(root, aabb, color, kind != "door", kind == "door", kind in TILED, Look.OUTLINE_THICK if kind in OUTLINED else 0.0)
        if kind in OCCLUDER_KINDS:
            occluders.append(info)
    for d in LevelData.decor():
        var dk: String = d["kind"]
        occluders.append(add_box(root, d["aabb"], COLORS.get(dk, Color.MAGENTA), false, false, dk in TILED))
    for h in LevelData.hazards():
        occluders.append(add_hazard(root, h["aabb"], h["axis"]))
    for d in LevelData.doors():
        occluders.append(add_door(root, d["center"], d["size"], d["slide"]))
    for l in LevelData.labels():
        add_label(root, l["text"], l["pos"])
    return occluders


static func spawn_enemies(root: Node3D, game) -> void:
    for e in LevelData.enemies():
        var en = EnemyScript.new()
        en.kind = e["kind"]
        en.axis = e["axis"]
        en.game = game
        en.position = e["pos"]
        en.home_rects = LevelData.region_at(e["pos"]).get("rects", [])
        root.add_child(en)


# ---------------------------------------------------------------- primitives

static func make_mesh(size: Vector3, color: Color, unshaded := false) -> MeshInstance3D:
    return Meshes.box(size, color, unshaded)


static func add_box(root: Node3D, aabb: AABB, color: Color, collide: bool, glow := false, grid := false, outline := 0.0) -> Dictionary:
    var mi := Meshes.box(aabb.size, color, false, grid, outline)
    var mat: StandardMaterial3D = mi.material_override
    if glow:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 0.45
        Look.outline(mat, Look.OUTLINE_THIN)
    mi.position = aabb.get_center()
    root.add_child(mi)
    if collide:
        var body := StaticBody3D.new()
        body.collision_layer = LAYER_WORLD
        body.collision_mask = 0
        var cs := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = aabb.size
        cs.shape = shape
        body.add_child(cs)
        body.position = aabb.get_center()
        root.add_child(body)
    return {"mesh": mi, "mat": mat, "aabb": aabb, "base": color}


## Returns an occluder entry for the teeth, so the camera can clear a pit away
## like any other box when it sits in front of a side view.
static func add_hazard(root: Node3D, aabb: AABB, axis: Vector3) -> Dictionary:
    var area := Area3D.new()
    area.collision_layer = 0
    area.collision_mask = LAYER_PLAYER
    var cs := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = aabb.size
    cs.shape = shape
    area.add_child(cs)
    area.position = aabb.get_center()
    area.body_entered.connect(func(body: Node3D) -> void:
        if body.is_in_group("player"):
            var p = body
            p.hazard_hit()
    )
    root.add_child(area)

    var teeth := Node3D.new()
    root.add_child(teeth)
    var spike_mat := StandardMaterial3D.new()  # one per pit, so pits fade separately
    spike_mat.albedo_color = Look.BLOOD
    spike_mat.emission_enabled = true
    spike_mat.emission = Color(0.6, 0.1, 0.15)
    spike_mat.emission_energy_multiplier = 0.7
    var along_x := absf(axis.x) > 0.5
    var run := aabb.size.x if along_x else aabb.size.z
    var across := aabb.size.z if along_x else aabb.size.x
    var count := int(run / 0.5)
    for i in count:
        var spike := MeshInstance3D.new()
        var pm := PrismMesh.new()
        pm.size = Vector3(0.45, 0.6, across * 0.95)
        spike.mesh = pm
        spike.material_override = spike_mat
        var c := aabb.get_center()
        var t := 0.25 + i * 0.5
        if along_x:
            spike.position = Vector3(aabb.position.x + t, aabb.position.y + 0.3, c.z)
        else:
            spike.position = Vector3(c.x, aabb.position.y + 0.3, aabb.position.z + t)
            spike.rotation.y = PI * 0.5
        teeth.add_child(spike)
    return {"mesh": teeth, "mat": spike_mat, "aabb": aabb, "base": Look.BLOOD}


static func add_door(root: Node3D, center: Vector3, size: Vector3, slide: Vector3) -> Dictionary:
    var door = DoorScript.new()
    door.closed_center = center
    door.size = size
    door.slide = slide
    root.add_child(door)
    var info := {"mesh": door, "mat": door.material, "aabb": AABB(center - size * 0.5, size), "base": Look.GOLD}
    door.occluder = info
    return info


static func add_label(root: Node3D, text: String, pos: Vector3) -> void:
    var l := Label3D.new()
    l.text = text
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = true
    l.font_size = 56
    l.outline_size = 14
    l.pixel_size = 0.008
    l.modulate = Look.GOLD
    l.outline_modulate = Look.INK
    l.position = pos
    l.add_to_group("plane_only")
    root.add_child(l)
