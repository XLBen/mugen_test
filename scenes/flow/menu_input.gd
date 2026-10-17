class_name MenuInput
extends RefCounted
## 菜单用的按键解释（不经过仿真）：方向 = WASD / 方向键 / 手柄十字键；确定 = U / Enter / 空格 / 小键盘 7 / 手柄 A；
## 返回 = J / Esc / Backspace / 小键盘 4 / 手柄 B；暂停 = Esc / 手柄 Start。不用 F 键（Mac 上是媒体键）。

const P1_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_U, KEY_I, KEY_O, KEY_J, KEY_K, KEY_L]
const P2_KEYS := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_KP_7, KEY_KP_8, KEY_KP_9, KEY_KP_4, KEY_KP_5, KEY_KP_6,
	KEY_SEMICOLON, KEY_APOSTROPHE, KEY_BACKSLASH, KEY_COMMA, KEY_PERIOD, KEY_SLASH]
const UP := [KEY_W, KEY_UP]
const DOWN := [KEY_S, KEY_DOWN]
const LEFT := [KEY_A, KEY_LEFT]
const RIGHT := [KEY_D, KEY_RIGHT]
const CONFIRM := [KEY_U, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_KP_7, KEY_SEMICOLON]
const BACK := [KEY_J, KEY_ESCAPE, KEY_BACKSPACE, KEY_KP_4, KEY_COMMA]


## 按下的键码（物理键优先），不是新按下的键返回 -1。
static func key(event: InputEvent) -> int:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return -1
	return k.physical_keycode if k.physical_keycode != 0 else k.keycode


static func _pad(event: InputEvent) -> int:
	var b := event as InputEventJoypadButton
	return b.button_index if b != null and b.pressed else -1


static func vertical(event: InputEvent) -> int:
	var k := key(event)
	var b := _pad(event)
	if k in UP or b == JOY_BUTTON_DPAD_UP:
		return -1
	if k in DOWN or b == JOY_BUTTON_DPAD_DOWN:
		return 1
	return 0


static func horizontal(event: InputEvent) -> int:
	var k := key(event)
	var b := _pad(event)
	if k in LEFT or b == JOY_BUTTON_DPAD_LEFT:
		return -1
	if k in RIGHT or b == JOY_BUTTON_DPAD_RIGHT:
		return 1
	return 0


static func confirm(event: InputEvent) -> bool:
	return key(event) in CONFIRM or _pad(event) == JOY_BUTTON_A


static func back(event: InputEvent) -> bool:
	return key(event) in BACK or _pad(event) == JOY_BUTTON_B


static func pause(event: InputEvent) -> bool:
	return key(event) == KEY_ESCAPE or _pad(event) == JOY_BUTTON_START


## 这个按键属于哪名玩家：0 / 1，通用键（Enter、Esc 等）返回 -1。
static func player(event: InputEvent) -> int:
	var b := event as InputEventJoypadButton
	if b != null:
		return clampi(b.device, 0, 1)
	var k := key(event)
	if k in P1_KEYS:
		return 0
	if k in P2_KEYS:
		return 1
	return -1
