extends AnimatableBody3D

const Meshes := preload("res://scripts/meshes.gd")
const Look := preload("res://scripts/look.gd")

const OPEN_RADIUS := 5.0
const CLOSE_RADIUS := 6.0
const TRAVEL_TIME := 0.3
const COLOR := Look.GOLD

var closed_center := Vector3.ZERO
var size := Vector3.ONE
var slide := Vector3.ZERO
var occluder: Dictionary = {}  # the camera's fade entry; kept in step as it moves
var material: StandardMaterial3D
var openness := 0.0

var _want_open := false


func _ready() -> void:
    add_to_group("door")
    collision_layer = 1
    collision_mask = 0
    sync_to_physics = false
    var cs := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    cs.shape = shape
    add_child(cs)
    var mesh := Meshes.box(size, COLOR, false, false, Look.OUTLINE_THIN)
    material = mesh.material_override
    material.emission_enabled = true
    material.emission = COLOR
    material.emission_energy_multiplier = 0.45
    add_child(mesh)
    position = closed_center


func _physics_process(delta: float) -> void:
    var game = get_tree().current_scene
    if game != null and game.has_method("paused") and game.paused():
        return
    var player = get_tree().get_first_node_in_group("player")
    if player != null:
        var pp: Vector3 = player.global_position
        var d := Vector2(pp.x - closed_center.x, pp.z - closed_center.z).length()
        if d < OPEN_RADIUS:
            _want_open = true
        elif d > CLOSE_RADIUS:
            _want_open = false
    openness = move_toward(openness, 1.0 if _want_open else 0.0, delta / TRAVEL_TIME)
    var eased := openness * openness * (3.0 - 2.0 * openness)
    position = closed_center + slide * eased
    if not occluder.is_empty():
        occluder["aabb"] = AABB(position - size * 0.5, size)
