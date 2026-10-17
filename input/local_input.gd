class_name LocalInput
## 把本机键盘/手柄读成 InputBits。只在表现层使用，仿真层只接收 int。
##
## P1 键盘：WASD 移动，U I O = B0 B1 B2，J K L = B3 B4 B5
## P2 键盘：方向键移动，小键盘 7 8 9 = B0 B1 B2，4 5 6 = B3 B4 B5；
##   没有小键盘（Mac 笔记本）时也可以用 ; ' \ = B0 B1 B2，, . / = B3 B4 B5
## 手柄：设备 0 → P1，设备 1 → P2（十字键 / 左摇杆 + 四个面键 + 两个肩键）

const ACTIONS := ["up", "down", "left", "right", "b0", "b1", "b2", "b3", "b4", "b5"]
const BITS := [
	InputBits.UP, InputBits.DOWN, InputBits.LEFT, InputBits.RIGHT,
	InputBits.B0, InputBits.B1, InputBits.B2, InputBits.B3, InputBits.B4, InputBits.B5,
]

const KEYS := [
	[KEY_W, KEY_S, KEY_A, KEY_D, KEY_U, KEY_I, KEY_O, KEY_J, KEY_K, KEY_L],
	[KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_KP_7, KEY_KP_8, KEY_KP_9, KEY_KP_4, KEY_KP_5, KEY_KP_6],
]

## 第二组键（只有按键，没有方向）：P2 的非小键盘替代键
const ALT_KEYS := [
	[],
	[KEY_SEMICOLON, KEY_APOSTROPHE, KEY_BACKSLASH, KEY_COMMA, KEY_PERIOD, KEY_SLASH],
]

const PAD_BUTTONS := [
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER,
	JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER,
]

const STICK_DEADZONE := 0.5

## 两次仿真帧之间按下过的按键（即使已经松开）。快速点按不会因为恰好没有在采样那一刻按住而丢失。
static var _latched: Array[int] = [0, 0]


static func action_name(player: int, i: int) -> String:
	return "p%d_%s" % [player + 1, ACTIONS[i]]


## 运行时注册输入动作，避免在 project.godot 里手写 InputEvent。
static func register_actions() -> void:
	for player in 2:
		for i in ACTIONS.size():
			var action := action_name(player, i)
			if InputMap.has_action(action):
				continue
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = KEYS[player][i]
			InputMap.action_add_event(action, key)
			var alt: Array = ALT_KEYS[player]
			if i >= 4 and i - 4 < alt.size():
				var key2 := InputEventKey.new()
				key2.physical_keycode = alt[i - 4]
				InputMap.action_add_event(action, key2)
			var pad := InputEventJoypadButton.new()
			pad.device = player
			pad.button_index = PAD_BUTTONS[i]
			InputMap.action_add_event(action, pad)


## 由场景的 _input 转发输入事件；只锁存按键，方向仍按当前按住状态读取（避免方向互相叠加）。
static func latch(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	for player in 2:
		for i in range(4, ACTIONS.size()):
			if event.is_action_pressed(action_name(player, i)):
				_latched[player] |= BITS[i]


static func read(player: int) -> int:
	var bits := _latched[player]
	_latched[player] = 0
	for i in ACTIONS.size():
		if Input.is_action_pressed(action_name(player, i)):
			bits |= BITS[i]
	var sx := Input.get_joy_axis(player, JOY_AXIS_LEFT_X)
	var sy := Input.get_joy_axis(player, JOY_AXIS_LEFT_Y)
	if sx < -STICK_DEADZONE:
		bits |= InputBits.LEFT
	elif sx > STICK_DEADZONE:
		bits |= InputBits.RIGHT
	if sy < -STICK_DEADZONE:
		bits |= InputBits.UP
	elif sy > STICK_DEADZONE:
		bits |= InputBits.DOWN
	return bits
