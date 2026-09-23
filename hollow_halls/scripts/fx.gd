extends RefCounted
## Motes in the air, a puff when you land, sparks off a hit, and the ghosts a
## dash leaves behind. Nothing here touches gameplay.

const Boxes := preload("res://scripts/boxes.gd")


static func _mat(color: Color, spread: float, speed: float, gravity: float) -> ParticleProcessMaterial:
    var m := ParticleProcessMaterial.new()
    m.particle_flag_disable_z = true
    m.direction = Vector3(0, -1, 0)
    m.spread = spread
    m.initial_velocity_min = speed * 0.35
    m.initial_velocity_max = speed
    m.gravity = Vector3(0, gravity, 0)
    m.damping_min = 120.0
    m.damping_max = 320.0
    m.scale_min = 0.6
    m.scale_max = 1.4
    m.color = color
    return m


## Slow motes drifting through the area. Placed once, left alone.
static func dust(area: Vector2) -> GPUParticles2D:
    var p := GPUParticles2D.new()
    p.amount = 70
    p.lifetime = 9.0
    p.preprocess = 9.0
    p.local_coords = false
    p.z_index = -8
    p.visibility_rect = Rect2(-area * 0.5, area)
    var m := _mat(Color(0.85, 0.88, 1.0, 0.18), 45.0, 14.0, 4.0)
    m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    m.emission_box_extents = Vector3(area.x * 0.5, area.y * 0.5, 0)
    m.damping_min = 0.0
    m.damping_max = 0.0
    p.process_material = m
    p.texture = _dot(3)
    return p


static func _dot(size: int) -> Texture2D:
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    img.fill(Color(1, 1, 1))
    return ImageTexture.create_from_image(img)


## A one-shot burst, freed once it has played out.
static func burst(parent: Node2D, at: Vector2, color: Color, count: int, speed: float, size: int, up: bool) -> void:
    if parent == null or not parent.is_inside_tree():
        return
    var p := GPUParticles2D.new()
    p.amount = count
    p.lifetime = 0.45
    p.one_shot = true
    p.explosiveness = 1.0
    p.local_coords = false
    p.z_index = 11
    p.position = at
    p.visibility_rect = Rect2(-400, -400, 800, 800)
    var m := _mat(color, 180.0 if not up else 70.0, speed, 900.0)
    m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    m.emission_sphere_radius = 6.0
    p.process_material = m
    p.texture = _dot(size)
    parent.add_child(p)
    p.emitting = true
    var timer := parent.get_tree().create_timer(1.2, true, false, true)
    timer.timeout.connect(func() -> void:
        if is_instance_valid(p):
            p.queue_free()
    )


## The trail behind a dash: a still copy of the body, fading where it stood.
static func ghost(parent: Node2D, at: Vector2, size: Vector2, color: Color) -> void:
    if parent == null or not parent.is_inside_tree():
        return
    var g := Boxes.make_box(size, color)
    g.position = at
    g.z_index = 9
    parent.add_child(g)
    var tw := g.create_tween()
    tw.set_ignore_time_scale(true)
    tw.tween_property(g, "modulate:a", 0.0, 0.28)
    tw.parallel().tween_property(g, "scale", Vector2(0.8, 0.8), 0.28)
    tw.tween_callback(g.queue_free)
