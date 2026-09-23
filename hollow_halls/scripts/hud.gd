extends CanvasLayer
## Masks, soul, area name, the view badge and the death prompt.
## Built in code against the fixed 1280x720 design resolution.

const Look := preload("res://scripts/look.gd")


var _masks: Array[Panel] = []
var _soul_fill: Panel
var _area_label: Label
var _chip: Panel
var _chip_label: Label
var _view_label: Label
var _hint_label: Label
var _death_label: Label
var _death_tint: ColorRect
var _root: Control


func _ready() -> void:
    layer = 10
    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)

    _panel(Vector2(20, 20), Vector2(266, 74), Color(0.05, 0.05, 0.09, 0.55), 10, Color(1, 1, 1, 0.07))
    for i in 5:
        _panel(Vector2(34 + i * 32, 34), Vector2(24, 24), Color(0.12, 0.12, 0.18, 0.9), 6, Color(1, 1, 1, 0.1))
        _masks.append(_panel(Vector2(37 + i * 32, 37), Vector2(18, 18), Look.BONE, 4))

    _label("SOUL", Vector2(34, 66), 12, Color(0.55, 0.72, 0.88, 0.9))
    _panel(Vector2(82, 69), Vector2(186, 10), Color(0.1, 0.12, 0.18, 0.95), 5, Color(1, 1, 1, 0.08))
    _soul_fill = _panel(Vector2(84, 71), Vector2(182, 6), Look.CYAN, 3)

    _area_label = _label("", Vector2(760, 26), 24, Color(1, 1, 1, 0.92))
    _area_label.size = Vector2(496, 32)
    _area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    _chip = _panel(Vector2(1150, 62), Vector2(106, 22), Color(0.3, 0.7, 0.45, 0.25), 11, Color(0.4, 0.85, 0.6, 0.5))
    _chip_label = _label("", Vector2(1150, 63), 12, Color(0.6, 0.95, 0.75))
    _chip_label.size = Vector2(106, 20)
    _chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    _view_label = _label("", Vector2(760, 62), 15, Look.GOLD)
    _view_label.size = Vector2(376, 22)
    _view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _view_label.pivot_offset = Vector2(376, 11)

    _panel(Vector2(0, 664), Vector2(1280, 56), Color(0.04, 0.035, 0.07, 0.5), 0)
    _hint_label = _label("", Vector2(20, 678), 13, Color(1, 1, 1, 0.5))
    _hint_label.size = Vector2(1240, 24)
    _hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    _death_tint = ColorRect.new()
    _death_tint.color = Color(0.3, 0.02, 0.06, 0.35)
    _death_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
    _death_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _death_tint.visible = false
    _root.add_child(_death_tint)

    _death_label = _label("YOU DIED", Vector2(340, 300), 52, Color(1, 0.42, 0.48))
    _death_label.size = Vector2(600, 90)
    _death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _death_label.visible = false


# --------------------------------------------------------------------- pieces

func _panel(pos: Vector2, size: Vector2, color: Color, radius: int, border := Color(0, 0, 0, 0)) -> Panel:
    var p := Panel.new()
    p.position = pos
    p.size = size
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sb := StyleBoxFlat.new()
    sb.bg_color = color
    sb.set_corner_radius_all(radius)
    if border.a > 0.0:
        sb.set_border_width_all(1)
        sb.border_color = border
    p.add_theme_stylebox_override("panel", sb)
    _root.add_child(p)
    return p


func _label(text: String, pos: Vector2, font_size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.85))
    l.add_theme_constant_override("outline_size", 5)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(l)
    return l


# ----------------------------------------------------------------------- feed

func set_health(cur: int, total: int) -> void:
    for i in _masks.size():
        var filled := i < cur
        _masks[i].visible = i < total
        var sb: StyleBoxFlat = _masks[i].get_theme_stylebox("panel")
        sb.bg_color = Look.BONE if filled else Color(0.24, 0.24, 0.3)


func set_soul(value: int, total: int) -> void:
    _soul_fill.size.x = 182.0 * clampf(float(value) / float(total), 0.0, 1.0)


func set_area(area_name: String, kind: String) -> void:
    _area_label.text = area_name
    var side := kind == "side"
    _chip_label.text = "COMBAT" if side else "SAFE"
    var tint := Color(0.95, 0.4, 0.45) if side else Color(0.42, 0.85, 0.6)
    _chip_label.add_theme_color_override("font_color", tint)
    var sb: StyleBoxFlat = _chip.get_theme_stylebox("panel")
    sb.bg_color = Color(tint.r, tint.g, tint.b, 0.16)
    sb.border_color = Color(tint.r, tint.g, tint.b, 0.5)

    if side:
        _view_label.text = "SIDE-ON"
        _hint_label.text = "A/D move     SPACE jump     X attack  (hold W / S to aim, S midair = pogo)     SHIFT dash     F focus-heal     R restart"
    else:
        _view_label.text = "TOP-DOWN"
        _hint_label.text = "WASD walk          step into a glowing doorway to enter a hallway          R restart area"
    _view_label.scale = Vector2(1.15, 1.15)
    var tw := create_tween()
    tw.set_ignore_time_scale(true)
    tw.tween_property(_view_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


func show_death(on: bool) -> void:
    _death_label.visible = on
    _death_tint.visible = on
