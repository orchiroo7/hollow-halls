extends RefCounted

const Look := preload("res://scripts/look.gd")

static func box(size: Vector3, color: Color, unshaded := false, grid := false, outline := 0.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.85
    if unshaded:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if grid:
        Look.tile(mat)
    if outline > 0.0:
        Look.outline(mat, outline)
    mi.material_override = mat
    return mi
