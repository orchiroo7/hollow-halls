extends RefCounted

const INK := Color(0.04, 0.035, 0.07)
const VOID := Color(0.055, 0.05, 0.09)
const HORIZON := Color(0.13, 0.11, 0.2)

const FLOOR_ROOM := Color(0.165, 0.17, 0.26)
const WALL_ROOM := Color(0.33, 0.33, 0.48)
const FLOOR_HALL := Color(0.125, 0.11, 0.19)
const WALL_HALL := Color(0.25, 0.21, 0.35)
const PLATFORM := Color(0.56, 0.55, 0.76)
const CRATE := Color(0.3, 0.3, 0.45)
const PIT := Color(0.05, 0.045, 0.08)

const GOLD := Color(0.93, 0.72, 0.31)
const CYAN := Color(0.55, 0.88, 1.0)
const BONE := Color(0.93, 0.95, 1.0)         # masks, the player's body
const BLOOD := Color(0.87, 0.31, 0.42)
const EMBER := Color(0.95, 0.58, 0.25)

const OUTLINE_THIN := 0.012
const OUTLINE_THICK := 0.03

static var _grid: Texture2D = null


static func grid_texture() -> Texture2D:
    if _grid != null:
        return _grid
    var n := 128
    var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
    img.fill(Color(1, 1, 1))
    for i in n:
        var f := float(i) / float(n)
        for j in n:
            var g := float(j) / float(n)
            var edge: bool = i < 2 or j < 2 or i > n - 3 or j > n - 3
            var mid: bool = absf(f - 0.5) < 0.004 or absf(g - 0.5) < 0.004
            if edge:
                img.set_pixel(i, j, Color(0.72, 0.72, 0.78))
            elif mid:
                img.set_pixel(i, j, Color(0.9, 0.9, 0.93))
    img.generate_mipmaps()
    _grid = ImageTexture.create_from_image(img)
    return _grid


static func tile(mat: StandardMaterial3D, scale := 0.5) -> void:
    mat.albedo_texture = grid_texture()
    mat.uv1_triplanar = true
    mat.uv1_world_triplanar = true
    mat.uv1_scale = Vector3(scale, scale, scale)
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


static func outline(mat: StandardMaterial3D, width := OUTLINE_THIN) -> StandardMaterial3D:
    var o := StandardMaterial3D.new()
    o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    o.cull_mode = BaseMaterial3D.CULL_FRONT
    o.grow = true
    o.grow_amount = width
    o.albedo_color = INK
    mat.next_pass = o
    return o


const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.55;
void fragment() {
    vec2 d = (UV - vec2(0.5)) * vec2(1.0, 0.78);
    float v = smoothstep(0.24, 0.62, length(d));
    COLOR = vec4(0.02, 0.015, 0.04, v * strength);
}
"""


static func vignette() -> CanvasLayer:
    var layer := CanvasLayer.new()
    layer.layer = 15
    var sh := Shader.new()
    sh.code = VIGNETTE_SHADER
    var mat := ShaderMaterial.new()
    mat.shader = sh
    var rect := ColorRect.new()
    rect.material = mat
    rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(rect)
    return layer
