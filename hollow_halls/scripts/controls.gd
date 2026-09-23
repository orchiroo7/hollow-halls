extends Node

const ACTIONS := {
    "move_left": [KEY_A, KEY_LEFT],
    "move_right": [KEY_D, KEY_RIGHT],
    "move_up": [KEY_W, KEY_UP],
    "move_down": [KEY_S, KEY_DOWN],
    "jump": [KEY_SPACE, KEY_Z],
    "attack": [KEY_X, KEY_J],
    "dash": [KEY_SHIFT, KEY_C],
    "focus": [KEY_F, KEY_V],
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
    var mb := InputEventMouseButton.new()
    mb.button_index = MOUSE_BUTTON_LEFT
    InputMap.action_add_event("attack", mb)
    var mb2 := InputEventMouseButton.new()
    mb2.button_index = MOUSE_BUTTON_RIGHT
    InputMap.action_add_event("dash", mb2)
