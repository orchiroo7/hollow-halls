extends RefCounted

const Look := preload("res://scripts/look.gd")


static func _flat_mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color = color
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.billboard_keep_scale = true
    return m


static func _quad(size: float, color: Color) -> QuadMesh:
    var q := QuadMesh.new()
    q.size = Vector2(size, size)
    q.material = _flat_mat(color)
    return q


static func dust(extents: Vector3) -> GPUParticles3D:
    var p := GPUParticles3D.new()
    p.amount = 90
    p.lifetime = 7.0
    p.preprocess = 7.0
    p.local_coords = false
    p.visibility_aabb = AABB(-extents, extents * 2.0)
    var m := ParticleProcessMaterial.new()
    m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    m.emission_box_extents = extents
    m.direction = Vector3(0.3, 1, 0)
    m.spread = 80.0
    m.initial_velocity_min = 0.05
    m.initial_velocity_max = 0.35
    m.gravity = Vector3(0, -0.06, 0)
    m.scale_min = 0.5
    m.scale_max = 1.6
    m.color = Color(0.85, 0.88, 1.0, 0.22)
    p.process_material = m
    p.draw_pass_1 = _quad(0.06, Color(0.85, 0.88, 1.0, 0.22))
    return p


static func burst(parent: Node3D, at: Vector3, color: Color, count: int, speed: float, size: float, up: float) -> void:
    if parent == null or not parent.is_inside_tree():
        return
    var p := GPUParticles3D.new()
    p.amount = count
    p.lifetime = 0.45
    p.one_shot = true
    p.explosiveness = 1.0
    p.local_coords = false
    p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
    var m := ParticleProcessMaterial.new()
    m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    m.emission_sphere_radius = 0.2
    m.direction = Vector3(0, up, 0)
    m.spread = 180.0
    m.initial_velocity_min = speed * 0.4
    m.initial_velocity_max = speed
    m.gravity = Vector3(0, -12, 0)
    m.damping_min = 2.0
    m.damping_max = 5.0
    m.scale_min = 0.6
    m.scale_max = 1.3
    m.color = color
    p.process_material = m
    p.draw_pass_1 = _quad(size, color)
    p.position = at
    parent.add_child(p)
    p.emitting = true
    var timer := parent.get_tree().create_timer(1.2, true, false, true)
    timer.timeout.connect(func() -> void:
        if is_instance_valid(p):
            p.queue_free()
    )


static func ghost(parent: Node3D, at: Vector3, size: Vector3, facing: float, color: Color) -> void:
    if parent == null or not parent.is_inside_tree():
        return
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = color
    mi.material_override = mat
    mi.position = at
    mi.rotation.y = facing
    parent.add_child(mi)
    var tw := mi.create_tween()
    tw.set_ignore_time_scale(true)
    tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
    tw.parallel().tween_property(mi, "scale", Vector3(0.8, 0.8, 0.8), 0.3)
    tw.tween_callback(mi.queue_free)
