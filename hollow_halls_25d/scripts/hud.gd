extends CanvasLayer
## Masks, soul, where you are, which view you are in, and control hints.
##
## The stretch mode is "expand", so the window's aspect decides how much of the
## world you see and the design size is only a starting point. Nothing here is
## positioned against that size: the HUD hangs off four anchored corners, so it
## stays put whatever shape the window is - a phone browser included.

const Look := preload("res://scripts/look.gd")

const LEFT_W := 300.0
const RIGHT_W := 520.0
const BAR_H := 64.0
const EDGE := 24.0

var _masks: Array[Panel] = []
var _soul_fill: Panel
var _area_label: Label
var _chip: Panel
var _chip_label: Label
var _cam_label: Label
var _hint_label: Label
var _death_label: Label
var _death_tint: ColorRect
var _root: Control
var _tl: Control
var _tr: Control
var _bar: Panel
var _last_cam := ""


func _ready() -> void:
    layer = 10
    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)

    var tl := _corner(0.0, 0.0, 0.0, 0.0, Vector2(0, 0), Vector2(LEFT_W, 110))
    var tr := _corner(1.0, 0.0, 1.0, 0.0, Vector2(-RIGHT_W, 0), Vector2(0, 120))
    _tl = tl
    _tr = tr
    tr.pivot_offset = Vector2(RIGHT_W, 0)
    var bottom := _corner(0.0, 1.0, 1.0, 1.0, Vector2(0, -BAR_H), Vector2(0, 0))
    var middle := Control.new()
    middle.set_anchors_preset(Control.PRESET_FULL_RECT)
    middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(middle)

    # --- top left: masks and soul
    _panel(tl, Vector2(20, 20), Vector2(266, 74), Color(0.05, 0.05, 0.09, 0.55), 10, Color(1, 1, 1, 0.07))
    for i in 5:
        _panel(tl, Vector2(34 + i * 32, 34), Vector2(24, 24), Color(0.12, 0.12, 0.18, 0.9), 6, Color(1, 1, 1, 0.1))
        _masks.append(_panel(tl, Vector2(37 + i * 32, 37), Vector2(18, 18), Look.BONE, 4))
    _label(tl, "SOUL", Vector2(34, 66), 12, Color(0.55, 0.72, 0.88, 0.9))
    _panel(tl, Vector2(82, 69), Vector2(186, 10), Color(0.1, 0.12, 0.18, 0.95), 5, Color(1, 1, 1, 0.08))
    _soul_fill = _panel(tl, Vector2(84, 71), Vector2(182, 6), Look.CYAN, 3)

    # --- top right: where you are, and which view
    _area_label = _label(tr, "", Vector2(0, 26), 24, Color(1, 1, 1, 0.92))
    _area_label.size = Vector2(RIGHT_W - EDGE, 32)
    _area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    _chip = _panel(tr, Vector2(RIGHT_W - EDGE - 106, 62), Vector2(106, 22), Color(0.3, 0.7, 0.45, 0.25), 11, Color(0.4, 0.85, 0.6, 0.5))
    _chip_label = _label(tr, "", Vector2(RIGHT_W - EDGE - 106, 63), 12, Color(0.6, 0.95, 0.75))
    _chip_label.size = Vector2(106, 20)
    _chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    _cam_label = _label(tr, "", Vector2(0, 62), 15, Look.GOLD)
    _cam_label.size = Vector2(RIGHT_W - EDGE - 118, 22)
    _cam_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _cam_label.pivot_offset = Vector2(_cam_label.size.x, 11)

    # --- bottom: the control hints, on a bar as wide as the window is
    var bar := _panel(bottom, Vector2.ZERO, Vector2(0, BAR_H), Color(0.04, 0.035, 0.07, 0.5), 0)
    bar.set_anchors_preset(Control.PRESET_FULL_RECT)
    _bar = bar
    _hint_label = _label(bottom, "", Vector2(0, 12), 13, Color(1, 1, 1, 0.5))
    _hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    _hint_label.offset_top = 12
    _hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    # --- middle: death
    _death_tint = ColorRect.new()
    _death_tint.color = Color(0.3, 0.02, 0.06, 0.35)
    _death_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
    _death_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _death_tint.visible = false
    middle.add_child(_death_tint)

    _death_label = _label(middle, "YOU DIED", Vector2.ZERO, 52, Color(1, 0.42, 0.48))
    _death_label.set_anchors_preset(Control.PRESET_CENTER)
    _death_label.size = Vector2(600, 90)
    _death_label.pivot_offset = Vector2(300, 45)
    _death_label.position = Vector2(-300, -45)
    _death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _death_label.visible = false


# --------------------------------------------------------------------- pieces

## A corner of the screen: the anchors first, then how far its edges sit in.
func _corner(al: float, at: float, ar: float, ab: float, tl: Vector2, br: Vector2) -> Control:
    var c := Control.new()
    c.anchor_left = al
    c.anchor_top = at
    c.anchor_right = ar
    c.anchor_bottom = ab
    c.offset_left = tl.x
    c.offset_top = tl.y
    c.offset_right = br.x
    c.offset_bottom = br.y
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(c)
    return c


func _panel(parent: Control, pos: Vector2, size: Vector2, color: Color, radius: int, border := Color(0, 0, 0, 0)) -> Panel:
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
    parent.add_child(p)
    return p


func _label(parent: Control, text: String, pos: Vector2, font_size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.85))
    l.add_theme_constant_override("outline_size", 5)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(l)
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
    var room := kind == "room"
    _chip_label.text = "SAFE" if room else "ENEMIES"
    var tint := Color(0.42, 0.85, 0.6) if room else Color(0.95, 0.4, 0.45)
    _chip_label.add_theme_color_override("font_color", tint)
    var sb: StyleBoxFlat = _chip.get_theme_stylebox("panel")
    sb.bg_color = Color(tint.r, tint.g, tint.b, 0.16)
    sb.border_color = Color(tint.r, tint.g, tint.b, 0.5)


func set_camera(view_name: String, side: bool, free := false) -> void:
    if view_name == _last_cam:
        return
    _last_cam = view_name
    _cam_label.text = view_name
    _cam_label.scale = Vector2(1.15, 1.15)
    var tw := create_tween()
    tw.set_ignore_time_scale(true)
    tw.tween_property(_cam_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
    if free:
        _hint_label.text = "WASD move (relative to the camera)     SPACE jump     K attack     SHIFT dash\nQ / E orbit     T / G raise and lower     + / - zoom     middle-drag or wheel with a mouse     1 / 2 / TAB back to a flat view"
    elif side:
        _hint_label.text = "A/D move     SPACE jump     K attack  (hold W / S to aim, S midair = pogo)     SHIFT dash     F focus-heal\nTAB top view          Q / E turn the view          3 free orbit          R respawn"
    else:
        _hint_label.text = "WASD move     SPACE jump     K attack     SHIFT dash     F focus-heal\nTAB side view          Q / E turn the view          3 free orbit          R respawn"


## On a phone the keyboard hints are a lie and everything is half the size it
## needs to be, so the hints go and the two corners grow.
func set_compact(on: bool) -> void:
    _bar.visible = not on
    _hint_label.visible = not on
    var k := Vector2(1.35, 1.35) if on else Vector2.ONE
    _tl.scale = k
    _tr.scale = k


func show_death(on: bool) -> void:
    _death_label.visible = on
    _death_tint.visible = on
