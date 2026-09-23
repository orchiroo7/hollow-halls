extends Node

const ACTIONS := {
    "move_left": [KEY_A, KEY_LEFT],
    "move_right": [KEY_D, KEY_RIGHT],
    "move_up": [KEY_W, KEY_UP],
    "move_down": [KEY_S, KEY_DOWN],
    "jump": [KEY_SPACE, KEY_Z],
    "attack": [KEY_K],
    "dash": [KEY_SHIFT, KEY_C],
    "focus": [KEY_F, KEY_V],
    "cam_cycle": [KEY_TAB],
    "cam_left": [KEY_Q],
    "cam_right": [KEY_E],
    "cam_top": [KEY_1],
    "cam_side": [KEY_2],
    "cam_free": [KEY_3],
    "lang_toggle": [KEY_8],
    "cam_closer": [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD],
    "cam_further": [KEY_MINUS, KEY_KP_SUBTRACT],
    "restart": [KEY_R],
    "quit_game": [KEY_ESCAPE],
}

func _ready() -> void:
    for action in ACTIONS.keys():
        if not InputMap.has_action(action):
            InputMap.add_action(action, 0.2)
        for key in ACTIONS[action]:
            var ev := InputEventKey.new()
            ev.physical_keycode = key
            InputMap.action_add_event(action, ev)
    for ui in ["ui_focus_next", "ui_focus_prev"]:
        if InputMap.has_action(ui):
            InputMap.action_erase_events(ui)

    var mb := InputEventMouseButton.new()
    mb.button_index = MOUSE_BUTTON_LEFT
    InputMap.action_add_event("attack", mb)
    var mb2 := InputEventMouseButton.new()
    mb2.button_index = MOUSE_BUTTON_RIGHT
    InputMap.action_add_event("dash", mb2)
