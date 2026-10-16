class_name MovementStates
## M1 的公共移动状态：站 / 蹲 / 前走 / 后走 / 起跳预备 / 空中 / 落地硬直。
## M2 引入 StateDef 后，这些会迁移为数据驱动的公共状态。


## 根据输入决定状态与速度。opponent_x 取帧开始时的值，保证 P1/P2 处理对称。
static func think(f: Fighter, input: int, opponent_x: int) -> void:
	var d := f.def
	match f.state:
		Fighter.State.PREJUMP:
			if f.state_frame >= d.prejump_frames:
				_launch_jump(f)
			return
		Fighter.State.AIR:
			return
		Fighter.State.LANDING:
			if f.state_frame < d.landing_frames:
				return
			f.set_state(Fighter.State.STAND)

	# 以下为地面可行动状态
	_auto_face(f, opponent_x)
	var numpad := InputBits.to_numpad(input, f.facing)
	if InputBits.is_up(numpad):
		f.jump_dir = InputBits.horizontal(numpad)
		f.vx = 0
		f.set_state(Fighter.State.PREJUMP)
	elif InputBits.is_down(numpad):
		f.vx = 0
		_enter(f, Fighter.State.CROUCH)
	else:
		match InputBits.horizontal(numpad):
			1:
				f.vx = d.walk_forward_speed * f.facing
				_enter(f, Fighter.State.WALK_FORWARD)
			-1:
				f.vx = -d.walk_back_speed * f.facing
				_enter(f, Fighter.State.WALK_BACK)
			_:
				f.vx = 0
				_enter(f, Fighter.State.STAND)


## 积分位置；空中受重力，落地进入落地硬直。
static func integrate(f: Fighter) -> void:
	f.x += f.vx
	if f.state != Fighter.State.AIR:
		return
	f.y += f.vy
	f.vy -= f.def.gravity
	if f.y <= 0:
		f.y = 0
		f.vx = 0
		f.vy = 0
		f.set_state(Fighter.State.LANDING)


## 只有地面可行动时才转向，空中保持起跳时的朝向。
static func _auto_face(f: Fighter, opponent_x: int) -> void:
	if opponent_x > f.x:
		f.facing = 1
	elif opponent_x < f.x:
		f.facing = -1


static func _launch_jump(f: Fighter) -> void:
	var d := f.def
	f.vy = d.jump_velocity
	match f.jump_dir:
		1:
			f.vx = d.jump_forward_speed * f.facing
		-1:
			f.vx = -d.jump_back_speed * f.facing
		_:
			f.vx = 0
	f.set_state(Fighter.State.AIR)


## 状态不变时不重置 state_frame。
static func _enter(f: Fighter, s: int) -> void:
	if f.state != s:
		f.set_state(s)
