extends RefCounted

const WALL := 40.0

static func get_area(id: String) -> Dictionary:
    match id:
        "room_a": return room_a()
        "room_b": return room_b()
        "hall_1": return hall_1()
        "hall_2": return hall_2()
        "hall_3": return hall_3()
    push_error("Unknown area: %s" % id)
    return room_a()


static func room_a() -> Dictionary:
    return {
        "id": "room_a",
        "name": "THE ATRIUM",
        "kind": "topdown",
        "size": Vector2(1600, 1000),
        "floor_color": Color(0.165, 0.17, 0.26),
        "wall_color": Color(0.33, 0.33, 0.48),
        "obstacles": [
            Rect2(300, 300, 120, 120),
            Rect2(1100, 260, 160, 90),
            Rect2(700, 640, 200, 120),
            Rect2(420, 780, 110, 110),
            Rect2(1180, 700, 120, 200),
        ],
        "doors": [
            {"side": "east", "at": 500.0, "span": 200.0, "target": "hall_1", "spawn": "left"},
            {"side": "north", "at": 800.0, "span": 200.0, "target": "hall_2", "spawn": "left"},
        ],
        "spawns": {
            "start": Vector2(800, 500),
            "east": Vector2(1440, 500),
            "north": Vector2(800, 160),
        },
    }


static func room_b() -> Dictionary:
    return {
        "id": "room_b",
        "name": "THE CISTERN",
        "kind": "topdown",
        "size": Vector2(1600, 1000),
        "floor_color": Color(0.13, 0.185, 0.225),
        "wall_color": Color(0.28, 0.41, 0.45),
        "obstacles": [
            Rect2(260, 240, 180, 180),
            Rect2(950, 300, 240, 120),
            Rect2(600, 600, 160, 160),
            Rect2(1150, 650, 180, 120),
            Rect2(320, 640, 100, 100),
        ],
        "doors": [
            {"side": "west", "at": 500.0, "span": 200.0, "target": "hall_1", "spawn": "right"},
            {"side": "south", "at": 800.0, "span": 200.0, "target": "hall_3", "spawn": "right"},
        ],
        "spawns": {
            "west": Vector2(160, 500),
            "south": Vector2(800, 840),
        },
    }


static func hall_1() -> Dictionary:
    return {
        "id": "hall_1",
        "name": "SUNLESS CORRIDOR",
        "kind": "side",
        "size": Vector2(3000, 720),
        "bg_color": Color(0.095, 0.085, 0.145),
        "solid_color": Color(0.27, 0.24, 0.38),
        "solids": [
            Rect2(0, 0, 3000, 40),
            Rect2(0, 0, 40, 420),
            Rect2(2960, 0, 40, 420),
            Rect2(40, 600, 2110, 120),
            Rect2(2370, 600, 590, 120),
            Rect2(560, 470, 240, 28),
            Rect2(940, 360, 220, 28),
            Rect2(1420, 450, 300, 28),
            Rect2(1880, 340, 200, 28),
            Rect2(2200, 470, 130, 28),
        ],
        "hazards": [Rect2(2150, 676, 220, 44)],
        "enemies": [
            {"kind": "walker", "pos": Vector2(820, 560)},
            {"kind": "flyer", "pos": Vector2(1200, 380)},
            {"kind": "walker", "pos": Vector2(1560, 410)},
            {"kind": "flyer", "pos": Vector2(2560, 400)},
            {"kind": "walker", "pos": Vector2(2750, 560)},
        ],
        "doors": [
            {"rect": Rect2(0, 420, 74, 180), "target": "room_a", "spawn": "east"},
            {"rect": Rect2(2926, 420, 74, 180), "target": "room_b", "spawn": "west"},
        ],
        "spawns": {
            "left": Vector2(170, 550),
            "right": Vector2(2830, 550),
        },
    }


static func hall_2() -> Dictionary:
    return {
        "id": "hall_2",
        "name": "THE ASCENT",
        "kind": "side",
        "size": Vector2(2400, 900),
        "bg_color": Color(0.08, 0.115, 0.155),
        "solid_color": Color(0.24, 0.31, 0.42),
        "solids": [
            Rect2(0, 0, 2400, 40),
            Rect2(0, 0, 40, 600),
            Rect2(2360, 0, 40, 600),
            Rect2(40, 780, 2320, 120),
            Rect2(420, 660, 200, 28),
            Rect2(760, 560, 200, 28),
            Rect2(1100, 460, 200, 28),
            Rect2(1460, 560, 200, 28),
            Rect2(1800, 660, 200, 28),
            Rect2(880, 280, 280, 28),
        ],
        "hazards": [],
        "enemies": [
            {"kind": "walker", "pos": Vector2(520, 620)},
            {"kind": "flyer", "pos": Vector2(1000, 380)},
            {"kind": "walker", "pos": Vector2(1180, 420)},
            {"kind": "flyer", "pos": Vector2(1700, 400)},
            {"kind": "walker", "pos": Vector2(2050, 740)},
        ],
        "doors": [
            {"rect": Rect2(0, 600, 74, 180), "target": "room_a", "spawn": "north"},
            {"rect": Rect2(2326, 600, 74, 180), "target": "hall_3", "spawn": "left"},
        ],
        "spawns": {
            "left": Vector2(170, 730),
            "right": Vector2(2230, 730),
        },
    }


static func hall_3() -> Dictionary:
    return {
        "id": "hall_3",
        "name": "THE LONG DARK",
        "kind": "side",
        "size": Vector2(3400, 760),
        "bg_color": Color(0.12, 0.085, 0.15),
        "solid_color": Color(0.34, 0.24, 0.42),
        "solids": [
            Rect2(0, 0, 3400, 40),
            Rect2(0, 0, 40, 460),
            Rect2(3360, 0, 40, 460),
            Rect2(40, 640, 1060, 120),
            Rect2(1320, 640, 930, 120),
            Rect2(2470, 640, 930, 120),
            Rect2(600, 500, 220, 28),
            Rect2(1140, 540, 130, 28),
            Rect2(1600, 480, 240, 28),
            Rect2(2000, 400, 200, 28),
            Rect2(2290, 540, 130, 28),
            Rect2(2700, 480, 220, 28),
            Rect2(3050, 380, 200, 28),
        ],
        "hazards": [
            Rect2(1100, 716, 220, 44),
            Rect2(2250, 716, 220, 44),
        ],
        "enemies": [
            {"kind": "walker", "pos": Vector2(400, 600)},
            {"kind": "flyer", "pos": Vector2(820, 400)},
            {"kind": "walker", "pos": Vector2(1700, 440)},
            {"kind": "flyer", "pos": Vector2(2100, 320)},
            {"kind": "walker", "pos": Vector2(2790, 440)},
            {"kind": "flyer", "pos": Vector2(3150, 300)},
            {"kind": "walker", "pos": Vector2(3000, 600)},
        ],
        "doors": [
            {"rect": Rect2(0, 460, 74, 180), "target": "hall_2", "spawn": "right"},
            {"rect": Rect2(3326, 460, 74, 180), "target": "room_b", "spawn": "south"},
        ],
        "spawns": {
            "left": Vector2(170, 590),
            "right": Vector2(3230, 590),
        },
    }
