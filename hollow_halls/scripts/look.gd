extends RefCounted

const INK := Color(0.04, 0.035, 0.07)
const VOID := Color(0.055, 0.05, 0.09)

const GOLD := Color(0.93, 0.72, 0.31)
const CYAN := Color(0.55, 0.88, 1.0)
const BONE := Color(0.93, 0.95, 1.0)
const BLOOD := Color(0.87, 0.31, 0.42)
const EMBER := Color(0.95, 0.58, 0.25)

const OUTLINE := 3.0

static var _grid: Texture2D = null


static func grid_texture() -> Texture2D:
    if _grid != null:
        return _grid
    var n := 64
    var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
    img.fill(Color(1, 1, 1))
    for i in n:
        for j in n:
            var edge: bool = i < 3 or j < 3
            var mid: bool = absi(i - n / 2) < 1 or absi(j - n / 2) < 1
            if edge:
                img.set_pixel(i, j, Color(0.74, 0.74, 0.8))
            elif mid:
                img.set_pixel(i, j, Color(0.91, 0.91, 0.94))
    _grid = ImageTexture.create_from_image(img)
    return _grid


static func tile(p: Polygon2D, world_origin: Vector2, scale := 1.0) -> void:
    p.texture = grid_texture()
    p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    p.texture_scale = Vector2(scale, scale)
    p.texture_offset = -world_origin / scale
    p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


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


static func environment() -> WorldEnvironment:
    var env := Environment.new()
    env.background_mode = Environment.BG_CANVAS
    env.glow_enabled = true
    env.glow_intensity = 0.55
    env.glow_bloom = 0.08
    env.glow_strength = 1.1
    env.glow_hdr_threshold = 0.88
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
    var we := WorldEnvironment.new()
    we.environment = env
    return we
