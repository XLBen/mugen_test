class_name Fighter
extends RefCounted
## 角色的运行时状态。这里的每个字段都必须是整数，并完整出现在 save_state/load_state 中，
## 否则会破坏确定性与回滚。

enum State { STAND, CROUCH, WALK_FORWARD, WALK_BACK, PREJUMP, AIR, LANDING }

var def: FighterDef

var x := 0
var y := 0 ## 离地高度，0 = 地面，向上为正
var vx := 0
var vy := 0
var facing := 1 ## 1 = 面朝右，-1 = 面朝左
var state: int = State.STAND
var state_frame := 0 ## 进入当前状态后经过的帧数
var jump_dir := 0 ## -1 后跳 / 0 垂直跳 / 1 前跳（相对起跳时的朝向）


func _init(p_def: FighterDef) -> void:
	def = p_def


func set_state(new_state: int) -> void:
	state = new_state
	state_frame = 0


func is_grounded() -> bool:
	return state != State.AIR


func push_height() -> int:
	match state:
		State.CROUCH:
			return def.crouch_height
		State.AIR:
			return def.air_height
		_:
			return def.stand_height


func push_left() -> int:
	return x - def.push_half_width


func push_right() -> int:
	return x + def.push_half_width


func save_state() -> Dictionary:
	return {
		"x": x, "y": y, "vx": vx, "vy": vy, "facing": facing,
		"state": state, "state_frame": state_frame, "jump_dir": jump_dir,
	}


func load_state(s: Dictionary) -> void:
	x = s.x
	y = s.y
	vx = s.vx
	vy = s.vy
	facing = s.facing
	state = s.state
	state_frame = s.state_frame
	jump_dir = s.jump_dir


## 参与状态哈希的整数序列，顺序固定。
func hash_values() -> Array[int]:
	return [x, y, vx, vy, facing, state, state_frame, jump_dir]


static func state_name(s: int) -> String:
	return State.keys()[s]
