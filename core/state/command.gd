class_name Command
extends RefCounted
## 一条出招规则：指令 + 按键 + 前提 → 进入某状态。Moveset 里按优先级排序（先写的优先）。

const BUTTON_NAMES := {
	"LP": InputBits.B0, "MP": InputBits.B1, "HP": InputBits.B2,
	"LK": InputBits.B3, "MK": InputBits.B4, "HK": InputBits.B5,
	"P": InputBits.B0 | InputBits.B1 | InputBits.B2,
	"K": InputBits.B3 | InputBits.B4 | InputBits.B5,
}

## 输入缓冲（SF6）：任何招式最多可以提前 4 帧按，连同当前帧共 5 帧窗口；冲刺和起身反击提前 7 帧（共 8 帧）
const BUFFER := 5
const LONG_BUFFER := 8

var name := ""
var motion: Motion
var buttons := 0 ## 按键位掩码；0 表示纯方向指令（冲刺）
var all_buttons := false ## true：buttons 必须同时按住（投技）
var min_buttons := 1 ## 至少同时按住几个（"PP" = 任意两个拳，EX 必杀）
var where := "ground" ## ground / air / cancel（只能从取消窗口里出，如 Target Combo 后续）/ guard（防御硬直中，Drive Reversal）
var stance := "any" ## any / stand / crouch（地面普攻按是否按下区分）/ forward / back（按键那一帧按着前 / 后，且没按下）
var state := "" ## 目标状态名
var cond := "" ## 额外条件：no_projectile 等
var after: Array = [] ## 派生招：只能从这些状态取消出来（空 = 不限）


static func build(d: Dictionary) -> Command:
	var c := Command.new()
	c.name = d.name
	c.state = d.state
	if d.has("motion"):
		c.motion = Motion.preset(d.motion)
	var spec: String = d.get("buttons", "")
	if spec == "PP" or spec == "KK":
		c.buttons = BUTTON_NAMES[spec.substr(0, 1)]
		c.min_buttons = 2
	else:
		for b: String in spec.split("+", false):
			c.buttons |= BUTTON_NAMES[b]
		c.all_buttons = spec.contains("+")
	c.where = d.get("where", c.where)
	c.stance = d.get("stance", c.stance)
	c.cond = d.get("cond", c.cond)
	c.after = d.get("after", [])
	return c


## 返回触发它的按键帧（>= 0），不成立返回 -1。
## 站 / 蹲普攻按"按键那一帧"有没有按下方向区分：缓冲中的 2LP 在顿帧后出招时，即使已经松开下也还是 2LP。
func check(f: Fighter, frame: int, buffer := BUFFER) -> int:
	if buttons == 0:
		# 纯方向指令（冲刺）：最近 LONG_BUFFER 帧内完成的也算（硬直中输入的冲刺在恢复时出来）
		if motion == null:
			return -1
		var t := frame
		while t > frame - maxi(buffer, LONG_BUFFER) and t > f.consumed:
			if motion.matches(f, t):
				return t
			t -= 1
		return -1
	var press := _press_frame(f, frame, buffer)
	if press < 0:
		return -1
	if not stance_ok(f.numpad_at(press)):
		return -1
	if motion != null and not motion.matches(f, press):
		return -1
	return press


func stance_ok(numpad: int) -> bool:
	match stance:
		"stand":
			return not InputBits.is_down(numpad)
		"crouch":
			return InputBits.is_down(numpad)
		"forward":
			return not InputBits.is_down(numpad) and InputBits.horizontal(numpad) == 1
		"back":
			return not InputBits.is_down(numpad) and InputBits.horizontal(numpad) == -1
	return true


## 在缓冲窗口内找最近一次满足条件的按键帧（且晚于已经被消耗的输入）。
func _press_frame(f: Fighter, frame: int, buffer: int) -> int:
	var t := frame
	while t > frame - buffer and t > f.consumed:
		var pressed := f.pressed_at(t) & buttons
		if pressed != 0:
			var held := f.input_at(t) & buttons
			if all_buttons and held != buttons:
				pass
			elif min_buttons > 1 and _count_bits(held) < min_buttons:
				pass
			else:
				return t
		t -= 1
	return -1


static func _count_bits(v: int) -> int:
	var n := 0
	while v != 0:
		n += v & 1
		v >>= 1
	return n
