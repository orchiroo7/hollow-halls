extends RefCounted

const START := Vector3(0, 0.8, 0)


static func _b(center: Vector3, size: Vector3, kind: String) -> Dictionary:
    return {"aabb": AABB(center - size * 0.5, size), "kind": kind}


static func decor() -> Array:
    var d: Array = []

    d.append(_b(Vector3(0, 0.02, 0), Vector3(9, 0.04, 9), "inlay"))
    d.append(_b(Vector3(0, 0.03, 0), Vector3(7.6, 0.04, 7.6), "floor_room"))
    d.append(_b(Vector3(0, 0.04, 0), Vector3(2.4, 0.04, 2.4), "trim"))
    for z in [-10.0, 10.0]:
        d.append(_b(Vector3(0, 0.02, z * 0.86), Vector3(18, 0.04, 0.3), "trim"))

    for z in [-5.5, -1.8, 1.8, 5.5]:
        d.append(_b(Vector3(60, 0.02, z), Vector3(17, 0.04, 1.5), "inlay"))
    d.append(_b(Vector3(60, 0.02, 0), Vector3(1.0, 0.04, 17), "trim"))

    for x in range(12, 49, 3):
        d.append(_b(Vector3(float(x), 0.02, 0), Vector3(0.25, 0.04, 3.2), "trim"))
    for z in range(-48, -13, 3):
        d.append(_b(Vector3(0, 0.02, float(z)), Vector3(3.2, 0.04, 0.25), "trim"))
    for z in range(-48, -13, 3):
        d.append(_b(Vector3(60, 0.02, float(z)), Vector3(3.2, 0.04, 0.25), "trim"))
    for x in range(12, 59, 3):
        d.append(_b(Vector3(float(x), 0.02, -50), Vector3(0.25, 0.04, 3.2), "trim"))
    return d


static func solids() -> Array:
    var s: Array = []

    s.append(_b(Vector3(0, -0.5, 0), Vector3(20, 1, 20), "floor_room"))
    s.append(_b(Vector3(0, 1.5, 10.5), Vector3(22, 3, 1), "wall_room"))
    s.append(_b(Vector3(-10.5, 1.5, 0), Vector3(1, 3, 20), "wall_room"))
    s.append(_b(Vector3(-6.5, 1.5, -10.5), Vector3(9, 3, 1), "wall_room"))
    s.append(_b(Vector3(6.5, 1.5, -10.5), Vector3(9, 3, 1), "wall_room"))
    s.append(_b(Vector3(10.5, 1.5, -6.5), Vector3(1, 3, 9), "wall_room"))
    s.append(_b(Vector3(10.5, 1.5, 6.5), Vector3(1, 3, 9), "wall_room"))
    s.append(_b(Vector3(-5, 0.75, -4), Vector3(2, 1.5, 2), "crate"))
    s.append(_b(Vector3(4, 1, 5), Vector3(3, 2, 2), "crate"))
    s.append(_b(Vector3(-4, 0.5, 5), Vector3(2, 1, 2), "crate"))
    s.append(_b(Vector3(5, 0.5, -5), Vector3(1.5, 1, 1.5), "crate"))
    s.append(_b(Vector3(9.8, 0.02, 0), Vector3(0.4, 0.04, 4), "door"))
    s.append(_b(Vector3(0, 0.02, -9.8), Vector3(4, 0.04, 0.4), "door"))

    s.append(_b(Vector3(19, -0.5, 0), Vector3(18, 1, 4), "floor_hall"))
    s.append(_b(Vector3(40.75, -0.5, 0), Vector3(18.5, 1, 4), "floor_hall"))
    s.append(_b(Vector3(29.75, -4.5, 0), Vector3(3.5, 1, 4), "pit_floor"))
    s.append(_b(Vector3(30, -1, -2.5), Vector3(40, 8, 1), "wall_hall"))
    s.append(_b(Vector3(30, -1, 2.5), Vector3(40, 8, 1), "wall_hall"))
    s.append(_b(Vector3(18, 2.2, 0), Vector3(3, 0.4, 4), "platform"))
    s.append(_b(Vector3(22.5, 3.4, 0), Vector3(2.5, 0.4, 4), "platform"))
    s.append(_b(Vector3(29.75, 0.8, 0), Vector3(1.6, 0.4, 4), "platform"))
    s.append(_b(Vector3(36, 2.2, 0), Vector3(4, 0.4, 4), "platform"))

    s.append(_b(Vector3(60, -0.5, 0), Vector3(20, 1, 20), "floor_room"))
    s.append(_b(Vector3(60, 1.5, 10.5), Vector3(22, 3, 1), "wall_room"))
    s.append(_b(Vector3(70.5, 1.5, 0), Vector3(1, 3, 20), "wall_room"))
    s.append(_b(Vector3(49.5, 1.5, -6.5), Vector3(1, 3, 9), "wall_room"))
    s.append(_b(Vector3(49.5, 1.5, 6.5), Vector3(1, 3, 9), "wall_room"))
    s.append(_b(Vector3(53.5, 1.5, -10.5), Vector3(9, 3, 1), "wall_room"))
    s.append(_b(Vector3(66.5, 1.5, -10.5), Vector3(9, 3, 1), "wall_room"))
    s.append(_b(Vector3(56, 0.75, 5), Vector3(2, 1.5, 2), "crate"))
    s.append(_b(Vector3(64, 1, -4), Vector3(3, 2, 2), "crate"))
    s.append(_b(Vector3(66, 0.5, 6), Vector3(2, 1, 2), "crate"))
    s.append(_b(Vector3(55, 0.5, -5), Vector3(1.5, 1, 1.5), "crate"))
    s.append(_b(Vector3(50.2, 0.02, 0), Vector3(0.4, 0.04, 4), "door"))
    s.append(_b(Vector3(60, 0.02, -9.8), Vector3(4, 0.04, 0.4), "door"))

    s.append(_b(Vector3(0, -0.5, -16), Vector3(4, 1, 12), "floor_hall"))
    s.append(_b(Vector3(0, -0.5, -32.75), Vector3(4, 1, 14.5), "floor_hall"))
    s.append(_b(Vector3(0, -4.5, -23.75), Vector3(4, 1, 3.5), "pit_floor"))
    s.append(_b(Vector3(-2.5, -1, -27.25), Vector3(1, 8, 34.5), "wall_hall"))
    s.append(_b(Vector3(2.5, -1, -25), Vector3(1, 8, 30), "wall_hall"))
    s.append(_b(Vector3(0, 2.2, -14), Vector3(4, 0.4, 3), "platform"))
    s.append(_b(Vector3(0, 3.4, -18.5), Vector3(4, 0.4, 2.5), "platform"))
    s.append(_b(Vector3(0, 0.8, -23.75), Vector3(4, 0.4, 1.6), "platform"))
    s.append(_b(Vector3(0, 2.2, -29), Vector3(4, 0.4, 3), "platform"))
    s.append(_b(Vector3(0, 2.2, -35), Vector3(4, 0.4, 3), "platform"))

    s.append(_b(Vector3(8, -0.5, -42), Vector3(20, 1, 4), "floor_hall"))
    s.append(_b(Vector3(29.75, -0.5, -42), Vector3(16.5, 1, 4), "floor_hall"))
    s.append(_b(Vector3(51.75, -0.5, -42), Vector3(20.5, 1, 4), "floor_hall"))
    s.append(_b(Vector3(19.75, -4.5, -42), Vector3(3.5, 1, 4), "pit_floor"))
    s.append(_b(Vector3(39.75, -4.5, -42), Vector3(3.5, 1, 4), "pit_floor"))
    s.append(_b(Vector3(30, -1, -44.5), Vector3(65, 8, 1), "wall_hall"))
    s.append(_b(Vector3(30, -1, -39.5), Vector3(56, 8, 1), "wall_hall"))
    s.append(_b(Vector3(62.5, -1, -27.25), Vector3(1, 8, 34.5), "wall_hall"))
    s.append(_b(Vector3(8, 2.2, -42), Vector3(3, 0.4, 4), "platform"))
    s.append(_b(Vector3(19.75, 0.8, -42), Vector3(1.6, 0.4, 4), "platform"))
    s.append(_b(Vector3(27, 2.2, -42), Vector3(3, 0.4, 4), "platform"))
    s.append(_b(Vector3(39.75, 0.8, -42), Vector3(1.6, 0.4, 4), "platform"))
    s.append(_b(Vector3(48, 2.2, -42), Vector3(4, 0.4, 4), "platform"))
    s.append(_b(Vector3(60, -0.5, -25), Vector3(4, 1, 30), "floor_hall"))
    s.append(_b(Vector3(57.5, -1, -24.75), Vector3(1, 8, 29.5), "wall_hall"))
    s.append(_b(Vector3(60, 2.2, -30), Vector3(4, 0.4, 3), "platform"))
    s.append(_b(Vector3(60, 2.2, -22), Vector3(4, 0.4, 3), "platform"))

    return s


static func doors() -> Array:
    return [
        {"center": Vector3(10.5, 1.45, 0), "size": Vector3(0.5, 2.9, 4), "slide": Vector3(0, 0, 4.2)},
        {"center": Vector3(0, 1.45, -10.5), "size": Vector3(4, 2.9, 0.5), "slide": Vector3(4.2, 0, 0)},
        {"center": Vector3(49.5, 1.45, 0), "size": Vector3(0.5, 2.9, 4), "slide": Vector3(0, 0, 4.2)},
        {"center": Vector3(60, 1.45, -10.5), "size": Vector3(4, 2.9, 0.5), "slide": Vector3(4.2, 0, 0)},
    ]


static func hazards() -> Array:
    var x := Vector3(1, 0, 0)
    var z := Vector3(0, 0, 1)
    return [
        {"aabb": AABB(Vector3(28, -4, -2), Vector3(3.5, 1.5, 4)), "axis": x},
        {"aabb": AABB(Vector3(-2, -4, -25.5), Vector3(4, 1.5, 3.5)), "axis": z},
        {"aabb": AABB(Vector3(18, -4, -44), Vector3(3.5, 1.5, 4)), "axis": x},
        {"aabb": AABB(Vector3(38, -4, -44), Vector3(3.5, 1.5, 4)), "axis": x},
    ]


static func regions() -> Array:
    return [
        {"id": "room_a", "name": "THE ATRIUM", "kind": "room", "rects": [Rect2(-10, -10, 20, 20)]},
        {"id": "hall_1", "name": "SUNLESS CORRIDOR", "kind": "hall", "rects": [Rect2(10, -2, 40, 4)]},
        {"id": "room_b", "name": "THE CISTERN", "kind": "room", "rects": [Rect2(50, -10, 20, 20)]},
        {"id": "hall_2", "name": "THE ASCENT", "kind": "hall", "rects": [Rect2(-2, -40, 4, 30)]},
        {"id": "hall_3", "name": "THE LONG DARK", "kind": "hall", "rects": [Rect2(-2, -44, 64, 4), Rect2(58, -40, 4, 30)]},
    ]


static func region_at(pos: Vector3) -> Dictionary:
    var p := Vector2(pos.x, pos.z)
    for r in regions():
        for rect in r["rects"]:
            var rr: Rect2 = rect
            if rr.has_point(p):
                return r
    return {}


static func enemies() -> Array:
    var x := Vector3(1, 0, 0)
    var z := Vector3(0, 0, 1)
    return [
        {"kind": "walker", "pos": Vector3(15, 0.6, 0), "axis": x},
        {"kind": "flyer", "pos": Vector3(26, 3.2, 0), "axis": x},
        {"kind": "walker", "pos": Vector3(36, 3.0, 0), "axis": x},
        {"kind": "walker", "pos": Vector3(44, 0.6, 0), "axis": x},
        {"kind": "flyer", "pos": Vector3(47, 3.0, 0), "axis": x},

        {"kind": "walker", "pos": Vector3(0, 0.6, -12.5), "axis": z},
        {"kind": "flyer", "pos": Vector3(0, 3.4, -21), "axis": z},
        {"kind": "walker", "pos": Vector3(0, 3.0, -29), "axis": z},
        {"kind": "walker", "pos": Vector3(0, 0.6, -37), "axis": z},

        {"kind": "walker", "pos": Vector3(10, 0.6, -42), "axis": x},
        {"kind": "flyer", "pos": Vector3(15, 3.0, -42), "axis": x},
        {"kind": "walker", "pos": Vector3(30, 0.6, -42), "axis": x},
        {"kind": "flyer", "pos": Vector3(35, 3.4, -42), "axis": x},
        {"kind": "walker", "pos": Vector3(52, 0.6, -42), "axis": x},
        {"kind": "walker", "pos": Vector3(60, 0.6, -26), "axis": z},
        {"kind": "flyer", "pos": Vector3(60, 3.0, -15), "axis": z},
    ]


static func labels() -> Array:
    return [
        {"key": "hall_1", "pos": Vector3(8.5, 3.2, 0)},
        {"key": "hall_2", "pos": Vector3(0, 3.2, -8.5)},
        {"key": "hall_1", "pos": Vector3(51.5, 3.2, 0)},
        {"key": "hall_3", "pos": Vector3(60, 3.2, -8.5)},
    ]
