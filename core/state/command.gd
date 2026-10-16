class_name Command
extends RefCounted
## 一条出招规则：指令 + 按键 + 前提 → 进入某状态。Moveset 里按优先级排序（先写的优先）。

const BUTTON_NAMES := {
	"LP": InputBits.B0, "MP": InputBits.B1, "HP": InputBits.B2,
	"LK": InputBits.B3, "MK": InputBits.B4, "HK": InputBits.B5,
	"P": InputBits.B0 | InputBits.B1 | InputBits.B2,
	"K": InputBits.B3 | InputBits.B4 | InputBits.B5,
}

const BUFFER := 4 ## 按键在多少帧内仍然有效（用于硬直结束、落地等一帧窗口）

var name := ""
var motion: Motion
var buttons := 0 ## 按键位掩码；0 表示纯方向指令（冲刺）
var all_buttons := false ## true：buttons 必须同时按住（投技）
var min_buttons := 1 ## 至少同时按住几个（"PP" = 任意两个拳，EX 必杀）
var where := "ground" ## ground / air / cancel（只能从取消窗口里出，如 Target Combo 后续）
var stance := "any" ## any / stand / crouch（地面普攻按是否按下区分）
var state := "" ## 目标状态名
var cond := "" ## 额外条件：no_projectile 等


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
	return c


## 返回触发它的按键帧（>= 0），不成立返回 -1。
func check(f: Fighter, frame: int, buffer := BUFFER) -> int:
	if stance != "any":
		var down := InputBits.is_down(f.numpad_at(frame))
		if down != (stance == "crouch"):
			return -1
	if buttons == 0:
		return frame if motion != null and motion.matches(f, frame) else -1
	var press := _press_frame(f, frame, buffer)
	if press < 0:
		return -1
	if motion != null and not motion.matches(f, press):
		return -1
	return press


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
