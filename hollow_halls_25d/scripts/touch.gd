extends CanvasLayer
## On-screen controls, for playing and demoing this on a phone.
##
## It drives the same input actions the keys do - a stick that presses the move
## actions with a strength, buttons that press the rest - so nothing else in the
## game knows or cares that a finger is involved. The one exception is the free
## orbit, where dragging anywhere empty swings the camera, because a stick
## cannot say "look over there" half as well as a drag can.
##
## Everything is sized from the visible rect rather than in fixed units, so a
## button is a thumb's width on a phone and still a button on a tablet.

const Look := preload("res://scripts/look.gd")

## Which actions the round buttons press, top to bottom on the right.
const BUTTONS := [
    {"action": "attack", "label": "ATTACK", "big": true},
    {"action": "jump", "label": "JUMP", "big": false},
    {"action": "dash", "label": "DASH", "big": false},
]

## The camera bar across the top.
const CAMERA_BAR := [
    {"action": "cam_left", "label": "<", "hold": true},
    {"action": "cam_top", "label": "TOP", "hold": false},
    {"action": "cam_side", "label": "SIDE", "hold": false},
    {"action": "cam_free", "label": "ORBIT", "hold": false},
    {"action": "cam_right", "label": ">", "hold": true},
]

const DEAD_ZONE := 0.16

var rig = null

var _root: Control
var _portrait: Control
var _stick_base: Panel
var _stick_knob: Panel
var _hits: Array = []          # {node, centre, radius, action, hold}
var _stick_home := Vector2.ZERO
var _stick_radius := 90.0
var _owners: Dictionary = {}   # touch index -> "stick" | "orbit" | an action name
var _held: Dictionary = {}     # action -> how many fingers are on it


static func wanted() -> bool:
    return DisplayServer.is_touchscreen_available() \
        or OS.has_feature("mobile") \
        or OS.get_cmdline_user_args().has("--touch")


func _ready() -> void:
    layer = 12
    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)

    _stick_base = _circle(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.16))
    _stick_knob = _circle(Color(Look.CYAN.r, Look.CYAN.g, Look.CYAN.b, 0.3), Color(Look.CYAN.r, Look.CYAN.g, Look.CYAN.b, 0.7))

    for b in BUTTONS:
        _hits.append({"node": _pill(b["label"], true), "action": b["action"], "hold": true, "big": b["big"]})
    for c in CAMERA_BAR:
        _hits.append({"node": _pill(c["label"], false), "action": c["action"], "hold": c["hold"], "bar": true})

    _portrait = Control.new()
    _portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
    _portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_portrait)
    var shade := ColorRect.new()
    shade.color = Color(0.043, 0.039, 0.07, 0.96)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _portrait.add_child(shade)
    var turn := Label.new()
    turn.text = "turn your phone sideways"
    turn.set_anchors_preset(Control.PRESET_FULL_RECT)
    turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    turn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    turn.add_theme_color_override("font_color", Look.GOLD)
    turn.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _portrait.add_child(turn)
    _turn_label = turn

    get_viewport().size_changed.connect(_layout)
    _layout()


var _turn_label: Label


# ------------------------------------------------------------------- building

func _circle(fill: Color, border: Color) -> Panel:
    var p := Panel.new()
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sb := StyleBoxFlat.new()
    sb.bg_color = fill
    sb.set_border_width_all(2)
    sb.border_color = border
    p.add_theme_stylebox_override("panel", sb)
    _root.add_child(p)
    return p


func _pill(text: String, round_shape: bool) -> Panel:
    var p := _circle(Color(0.08, 0.075, 0.13, 0.55), Color(1, 1, 1, 0.22))
    p.set_meta("round", round_shape)
    var l := Label.new()
    l.text = text
    l.set_anchors_preset(Control.PRESET_FULL_RECT)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.add_theme_color_override("font_color", Color(0.93, 0.95, 1.0, 0.85))
    l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.85))
    l.add_theme_constant_override("outline_size", 5)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(l)
    p.set_meta("label", l)
    return p


## Everything is placed from the visible rect, so it survives a rotation.
func _layout() -> void:
    var rect: Vector2 = get_viewport().get_visible_rect().size
    var u: float = minf(rect.x, rect.y)
    var portrait := rect.y > rect.x
    _portrait.visible = portrait
    _turn_label.add_theme_font_size_override("font_size", int(u * 0.075))
    for h in _hits:
        h["node"].visible = not portrait
    _stick_base.visible = not portrait
    _stick_knob.visible = not portrait
    if portrait:
        return

    var m: float = u * 0.05
    var r: float = u * 0.085

    _stick_radius = u * 0.13
    _stick_home = Vector2(m + _stick_radius, rect.y - m - _stick_radius)
    _place(_stick_base, _stick_home, _stick_radius, true)
    _place(_stick_knob, _stick_home, _stick_radius * 0.42, true)

    # the right-hand cluster: attack biggest and lowest, under the thumb
    var spots := [
        Vector2(rect.x - m - r * 1.15, rect.y - m - r * 1.15),
        Vector2(rect.x - m - r * 3.4, rect.y - m - r * 1.5),
        Vector2(rect.x - m - r * 1.7, rect.y - m - r * 3.6),
    ]
    var i := 0
    for h in _hits:
        if h.has("bar"):
            continue
        var rad: float = r * (1.15 if h["big"] else 0.85)
        _place(h["node"], spots[i], rad, true)
        h["centre"] = spots[i]
        h["radius"] = rad
        _fit(h["node"], Vector2(rad * 2.0, rad * 2.0))
        i += 1

    # the camera bar, centred along the bottom between the stick and the
    # buttons - the top belongs to the HUD, and thumbs do not wander there
    var bw: float = u * 0.155
    var bh: float = u * 0.085
    var gap: float = u * 0.014
    var total: float = CAMERA_BAR.size() * bw + (CAMERA_BAR.size() - 1) * gap
    var x: float = rect.x * 0.5 - total * 0.5 + bw * 0.5
    var y: float = rect.y - m - bh * 0.5
    for h in _hits:
        if not h.has("bar"):
            continue
        var c := Vector2(x, y)
        h["node"].position = c - Vector2(bw, bh) * 0.5
        h["node"].size = Vector2(bw, bh)
        _radius(h["node"], int(bh * 0.5))
        h["centre"] = c
        h["radius"] = maxf(bw, bh) * 0.5
        h["box"] = Vector2(bw, bh) * 0.5
        _fit(h["node"], Vector2(bw, bh))
        x += bw + gap


func _place(p: Panel, centre: Vector2, radius: float, round_shape: bool) -> void:
    p.position = centre - Vector2(radius, radius)
    p.size = Vector2(radius, radius) * 2.0
    _radius(p, int(radius) if round_shape else 8)


func _radius(p: Panel, r: int) -> void:
    var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
    sb.set_corner_radius_all(r)


## Size the caption to the box it sits in and to how long the word is, so
## ATTACK and > both end up inside their buttons.
func _fit(p: Panel, box: Vector2) -> void:
    if not p.has_meta("label"):
        return
    var l: Label = p.get_meta("label")
    var by_width: float = box.x * 1.2 / maxf(2.0, float(l.text.length()))
    l.add_theme_font_size_override("font_size", maxi(int(minf(by_width, box.y * 0.45)), 8))


## Where a given button sits, in viewport coordinates. For the tests, and for
## anything else that needs to point at one.
func hit_centre(action: String) -> Vector2:
    for h in _hits:
        if h["action"] == action and h.has("centre"):
            return h["centre"]
    return Vector2.ZERO


func stick_centre() -> Vector2:
    return _stick_home


func stick_radius() -> float:
    return _stick_radius


# --------------------------------------------------------------------- input

const MOUSE := -1  # the mouse counts as one more finger, so these are testable

func _input(event: InputEvent) -> void:
    if _portrait.visible:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            _down(event.index, event.position)
        else:
            _up(event.index)
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        _drag(event.index, event.position, event.relative)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _down(MOUSE, event.position)
        else:
            _up(MOUSE)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
        _drag(MOUSE, event.position, event.relative)
        get_viewport().set_input_as_handled()


func _down(index: int, pos: Vector2) -> void:
    for h in _hits:
        if _inside(h, pos):
            _owners[index] = h["action"]
            _press(h["action"], h["hold"])
            _lit(h["node"], true)
            return
    if pos.x < get_viewport().get_visible_rect().size.x * 0.5:
        _owners[index] = "stick"
        _stick_home = pos
        _place(_stick_base, _stick_home, _stick_radius, true)
        _drag_stick(pos)
    else:
        _owners[index] = "orbit"


func _drag(index: int, pos: Vector2, relative: Vector2) -> void:
    match _owners.get(index, ""):
        "stick":
            _drag_stick(pos)
        "orbit":
            if rig != null:
                rig.orbit_by(relative)
        _:
            pass


func _up(index: int) -> void:
    var who: String = _owners.get(index, "")
    _owners.erase(index)
    if who == "stick":
        _release_moves()
        _place(_stick_knob, _stick_home, _stick_radius * 0.42, true)
    elif who != "" and who != "orbit":
        _release(who)
        for h in _hits:
            if h["action"] == who:
                _lit(h["node"], false)


func _inside(h: Dictionary, pos: Vector2) -> bool:
    if not h.has("centre"):
        return false
    if h.has("box"):
        var d: Vector2 = (pos - h["centre"]).abs()
        var b: Vector2 = h["box"]
        return d.x <= b.x and d.y <= b.y
    return pos.distance_to(h["centre"]) <= h["radius"] * 1.15


func _drag_stick(pos: Vector2) -> void:
    var off: Vector2 = pos - _stick_home
    if off.length() > _stick_radius:
        off = off.normalized() * _stick_radius
    _place(_stick_knob, _stick_home + off, _stick_radius * 0.42, true)
    var v: Vector2 = off / _stick_radius
    if v.length() < DEAD_ZONE:
        _release_moves()
        return
    _axis("move_left", "move_right", v.x)
    _axis("move_down", "move_up", -v.y)  # screen y grows downward


func _axis(neg: String, pos: String, amount: float) -> void:
    if amount > DEAD_ZONE:
        Input.action_release(neg)
        Input.action_press(pos, minf(absf(amount), 1.0))
    elif amount < -DEAD_ZONE:
        Input.action_release(pos)
        Input.action_press(neg, minf(absf(amount), 1.0))
    else:
        Input.action_release(neg)
        Input.action_release(pos)


func _release_moves() -> void:
    for a in ["move_left", "move_right", "move_up", "move_down"]:
        Input.action_release(a)


## The camera keys are read as events in _unhandled_input, the rest are polled,
## so a press has to be both: a real action event and a held action state.
func _press(action: String, hold: bool) -> void:
    _held[action] = int(_held.get(action, 0)) + 1
    Input.action_press(action)
    var ev := InputEventAction.new()
    ev.action = action
    ev.pressed = true
    get_viewport().push_input(ev)
    if not hold:
        _release_soon(action)


func _release(action: String) -> void:
    _held[action] = maxi(0, int(_held.get(action, 0)) - 1)
    if _held[action] > 0:
        return
    Input.action_release(action)
    var ev := InputEventAction.new()
    ev.action = action
    ev.pressed = false
    get_viewport().push_input(ev)


## A tap-style button lets go by itself, so holding TOP does not fire it twice.
func _release_soon(action: String) -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if int(_held.get(action, 0)) > 0:
        Input.action_release(action)


func _lit(node: Panel, on: bool) -> void:
    var sb: StyleBoxFlat = node.get_theme_stylebox("panel")
    sb.bg_color = Color(Look.CYAN.r, Look.CYAN.g, Look.CYAN.b, 0.32) if on else Color(0.08, 0.075, 0.13, 0.55)
