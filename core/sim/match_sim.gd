class_name MatchSim
extends RefCounted
## 一场对战的确定性仿真。step(inputs) 推进一帧；不依赖场景树、系统时间或浮点。
## 同样的初始状态 + 同样的输入序列，必然得到同样的结果（回滚联网的前提）。

var stage: StageDef
var fighters: Array[Fighter] = []

var frame := 0
var camera_x := 0 ## 摄像机中心（逻辑单位），屏幕墙由它推导


func _init(p_stage: StageDef, p1_def: FighterDef, p2_def: FighterDef) -> void:
	stage = p_stage
	fighters = [Fighter.new(p1_def), Fighter.new(p2_def)]
	reset()


func reset() -> void:
	frame = 0
	camera_x = 0
	var p1 := fighters[0]
	var p2 := fighters[1]
	for f in fighters:
		f.load_state(Fighter.new(f.def).save_state())
	p1.x = -stage.start_offset
	p1.facing = 1
	p2.x = stage.start_offset
	p2.facing = -1


## inputs[i] 是第 i 名玩家本帧的 InputBits（会在此做 SOCD 清理）。
func step(inputs: Array[int]) -> void:
	var p1 := fighters[0]
	var p2 := fighters[1]
	var x1 := p1.x
	var x2 := p2.x

	MovementStates.think(p1, InputBits.clean_socd(inputs[0]), x2)
	MovementStates.think(p2, InputBits.clean_socd(inputs[1]), x1)

	for f in fighters:
		MovementStates.integrate(f)

	var wall_left := screen_wall_left()
	var wall_right := screen_wall_right()
	for f in fighters:
		Pushbox.clamp_to_walls(f, wall_left, wall_right)
	Pushbox.resolve(p1, p2, wall_left, wall_right)

	_update_camera()
	for f in fighters:
		f.state_frame += 1
	frame += 1


## 屏幕墙：摄像机两侧向内收 CAMERA_WALL_MARGIN。
## 摄像机顶到舞台尽头时，那一侧的墙就是版边本身（角落贴着版边，不留边距）。
func screen_wall_left() -> int:
	if camera_x <= -_camera_limit():
		return -stage.half_width
	return camera_x - SimConst.SCREEN_HALF_W + SimConst.CAMERA_WALL_MARGIN


func screen_wall_right() -> int:
	if camera_x >= _camera_limit():
		return stage.half_width
	return camera_x + SimConst.SCREEN_HALF_W - SimConst.CAMERA_WALL_MARGIN


## 摄像机跟随两人中点，并且不拍到舞台之外。
func _update_camera() -> void:
	var mid := (fighters[0].x + fighters[1].x) / 2
	camera_x = clampi(mid, -_camera_limit(), _camera_limit())


func _camera_limit() -> int:
	return stage.half_width - SimConst.SCREEN_HALF_W


func save_state() -> Dictionary:
	return {
		"frame": frame,
		"camera_x": camera_x,
		"fighters": fighters.map(func(f: Fighter) -> Dictionary: return f.save_state()),
	}


func load_state(s: Dictionary) -> void:
	frame = s.frame
	camera_x = s.camera_x
	for i in fighters.size():
		fighters[i].load_state(s.fighters[i])


## 32 位状态哈希，用于确定性校验与（以后的）联网不同步检测。
func state_hash() -> int:
	var values: Array[int] = [frame, camera_x]
	for f in fighters:
		values.append_array(f.hash_values())
	var h := 2166136261
	for v in values:
		h = ((h ^ (v & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
	return h
