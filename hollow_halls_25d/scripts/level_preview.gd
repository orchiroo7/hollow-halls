@tool
extends Node3D

const LevelData := preload("res://scripts/level_data.gd")
const WorldBuilder := preload("res://scripts/world_builder.gd")
const Meshes := preload("res://scripts/meshes.gd")
const Look := preload("res://scripts/look.gd")
const Lang := preload("res://scripts/lang.gd")

@export var show_level := true:
    set(value):
        show_level = value
        _rebuild()

@export var rebuild_now := false:
    set(value):
        rebuild_now = false
        _rebuild()


func _ready() -> void:
    if not Engine.is_editor_hint():
        queue_free()
        return
    _rebuild()


func _rebuild() -> void:
    if not Engine.is_editor_hint():
        return
    for child in get_children():
        remove_child(child)
        child.free()
    if show_level:
        draw_into(self)


static func draw_into(root: Node3D) -> void:
    for s in LevelData.solids():
        var kind: String = s["kind"]
        var aabb: AABB = s["aabb"]
        var tiled: bool = kind in WorldBuilder.TILED
        var edge: float = Look.OUTLINE_THICK if kind in WorldBuilder.OUTLINED else 0.0
        _box(root, aabb, WorldBuilder.COLORS.get(kind, Color.MAGENTA), tiled, edge)

    for d in LevelData.decor():
        var dk: String = d["kind"]
        _box(root, d["aabb"], WorldBuilder.COLORS.get(dk, Color.MAGENTA), dk in WorldBuilder.TILED, 0.0)

    for door in LevelData.doors():
        var size: Vector3 = door["size"]
        _box(root, AABB(door["center"] - size * 0.5, size), Look.GOLD, false, Look.OUTLINE_THIN)

    for h in LevelData.hazards():
        var box: AABB = h["aabb"]
        _box(root, AABB(box.position, Vector3(box.size.x, 0.6, box.size.z)), Look.BLOOD, false, 0.0)

    for e in LevelData.enemies():
        var colour: Color = Look.EMBER if e["kind"] == "flyer" else Look.BLOOD
        _marker(root, e["pos"], Vector3(0.9, 0.9, 0.9), colour)

    _marker(root, LevelData.START, Vector3(0.8, 1.4, 0.8), Look.BONE)

    for l in LevelData.labels():
        var label := Label3D.new()
        label.text = Lang.t(l["key"])
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.font_size = 56
        label.outline_size = 14
        label.pixel_size = 0.008
        label.modulate = Look.GOLD
        label.outline_modulate = Look.INK
        label.position = l["pos"]
        root.add_child(label)


static func _box(root: Node3D, aabb: AABB, colour: Color, tiled: bool, edge: float) -> void:
    var mesh := Meshes.box(aabb.size, colour, false, tiled, edge)
    mesh.position = aabb.get_center()
    root.add_child(mesh)


static func _marker(root: Node3D, at: Vector3, size: Vector3, colour: Color) -> void:
    var mesh := Meshes.box(size, Color(colour.r, colour.g, colour.b, 0.75), true)
    var mat: StandardMaterial3D = mesh.material_override
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mesh.position = at
    root.add_child(mesh)
