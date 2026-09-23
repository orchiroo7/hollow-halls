extends RefCounted

const JA := 0
const EN := 1

static var current: int = JA

const TEXT := {
    "soul": ["ソウル", "SOUL"],
    "safe": ["安全", "SAFE"],
    "enemies": ["敵あり", "ENEMIES"],
    "top_view": ["俯瞰視点", "TOP VIEW"],
    "side_view": ["横視点", "SIDE VIEW"],
    "free_orbit": ["自由視点", "FREE ORBIT"],
    "you_died": ["死亡", "YOU DIED"],

    "room_a": ["アトリウム", "THE ATRIUM"],
    "room_b": ["貯水槽", "THE CISTERN"],
    "hall_1": ["陽の差さぬ回廊", "SUNLESS CORRIDOR"],
    "hall_2": ["昇降路", "THE ASCENT"],
    "hall_3": ["長き闇", "THE LONG DARK"],

    "btn_jump": ["ジャンプ", "JUMP"],
    "btn_attack": ["攻撃", "ATTACK"],
    "btn_dash": ["ダッシュ", "DASH"],
    "btn_top": ["俯瞰", "TOP"],
    "btn_side": ["横", "SIDE"],
    "btn_orbit": ["自由", "ORBIT"],

    "hint_top": [
        "WASD 移動     SPACE ジャンプ     K 攻撃     SHIFT ダッシュ     F 集中回復\n TAB 横視点          Q / E 視点回転          3 自由視点          R 復帰",
        "WASD move     SPACE jump     K attack     SHIFT dash     F focus-heal\nTAB side view          Q / E turn the view          3 free orbit          R respawn",
    ],
    "hint_side": [
        "A/D 移動     SPACE ジャンプ     K 攻撃（W / S で狙う、空中で S は踏みつけ）     SHIFT ダッシュ     F 集中回復\n TAB 俯瞰視点          Q / E 視点回転          3 自由視点          R 復帰",
        "A/D move     SPACE jump     K attack  (hold W / S to aim, S midair = pogo)     SHIFT dash     F focus-heal\nTAB top view          Q / E turn the view          3 free orbit          R respawn",
    ],
    "hint_free": [
        "WASD 移動（視点基準）     SPACE ジャンプ     K 攻撃     SHIFT ダッシュ\n Q / E 旋回     + / - 遠近     中ボタンで視点を掴む、ホイールで遠近     1 / 2 / TAB で平面視点へ",
        "WASD move (relative to the camera)     SPACE jump     K attack     SHIFT dash\nQ / E orbit     + / - zoom     middle-drag grabs the camera, wheel zooms     1 / 2 / TAB back to a flat view",
    ],
    "hint_touch_free": [
        "ドラッグで視点、二本指で遠近",
        "drag to look, pinch to zoom",
    ],
    "hint_touch_flat": [
        "矢印で 90 度ずつ回転",
        "the arrows turn it 90 degrees",
    ],
}


static func toggle() -> void:
    current = EN if current == JA else JA


static func japanese() -> bool:
    return current == JA


static func t(key: String) -> String:
    if not TEXT.has(key):
        return key
    return TEXT[key][current]


static func every_glyph() -> String:
    var all := ""
    for key in TEXT:
        for variant in TEXT[key]:
            all += variant
    return all
