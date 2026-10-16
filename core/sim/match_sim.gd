class_name MatchSim
extends RefCounted
## 一场对战的确定性仿真。step(inputs) 推进一帧；不依赖场景树、系统时间或浮点。
## 同样的初始状态 + 同样的输入序列，必然得到同样的结果（回滚联网的前提）。
##
## 每帧顺序：记录输入 → 角色更新（逻辑/事件/物理）→ 道具移动 → 墙与推挤 → 命中结算 → 摄像机

var stage: StageDef
var fighters: Array[Fighter] = []
var projectiles: Array[Projectile] = []

var frame := 0
var camera_x := 0 ## 摄像机中心（逻辑单位），屏幕墙由它推导


func _init(p_stage: StageDef, p1_def: FighterDef, p2_def: FighterDef) -> void:
	stage = p_stage
	fighters = [Fighter.new(p1_def), Fighter.new(p2_def)]
	for i in 2:
		fighters[i].index = i
	reset()


func reset() -> void:
	frame = 0
	camera_x = 0
	projectiles = []
	for f in fighters:
		f.reset_state()
	fighters[0].x = -stage.start_offset
	fighters[0].facing = 1
	fighters[1].x = stage.start_offset
	fighters[1].facing = -1


func opponent(f: Fighter) -> Fighter:
	return fighters[1 - f.index]


## inputs[i] 是第 i 名玩家本帧的 InputBits（会在此做 SOCD 清理）。
func step(inputs: Array[int]) -> void:
	frame += 1
	for i in 2:
		fighters[i].record_input(frame, InputBits.clean_socd(inputs[i]))

	for f in fighters:
		StateRunner.update(f, self)
	_move_projectiles()

	var wall_left := screen_wall_left()
	var wall_right := screen_wall_right()
	for f in fighters:
		var desired := f.x
		Pushbox.clamp_to_walls(f, wall_left, wall_right)
		# 版边被打：击退被墙挡住的部分反推给攻击方
		if f.push_transfer != 0 and f.x != desired:
			var other := opponent(f)
			other.x += f.x - desired
			Pushbox.clamp_to_walls(other, wall_left, wall_right)
	Pushbox.resolve(fighters[0], fighters[1], wall_left, wall_right)

	Combat.resolve(self)
	_update_camera()


# ---------------------------------------------------------------- 飞行道具

func spawn_projectile(owner: Fighter, def_name: String, offset_x: int, offset_y: int) -> void:
	var p := Projectile.new()
	p.owner = owner.index
	p.def_id = owner.moveset.projectile_index[def_name]
	var pd := projectile_def(p)
	p.facing = owner.facing
	p.x = owner.x + offset_x * owner.facing
	p.y = owner.y + offset_y
	p.vx = pd.speed * owner.facing
	p.hits = pd.hits
	projectiles.append(p)


func has_projectile(owner: Fighter) -> bool:
	for p in projectiles:
		if p.owner == owner.index:
			return true
	return false


func projectile_def(p: Projectile) -> ProjectileDef:
	return fighters[p.owner].moveset.projectiles[p.def_id]


func projectile_box(p: Projectile) -> PackedInt32Array:
	return Box.to_world(p.x, p.y, p.facing, projectile_def(p).box)


func _move_projectiles() -> void:
	var alive: Array[Projectile] = []
	for p in projectiles:
		p.x += p.vx
		p.age += 1
		if p.age < projectile_def(p).lifetime and absi(p.x) < stage.half_width + 20000:
			alive.append(p)
	projectiles = alive


# ---------------------------------------------------------------- 摄像机与墙

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


# ---------------------------------------------------------------- 存档与哈希

func save_state() -> Dictionary:
	return {
		"frame": frame,
		"camera_x": camera_x,
		"fighters": fighters.map(func(f: Fighter) -> Dictionary: return f.save_state()),
		"projectiles": projectiles.map(func(p: Projectile) -> Dictionary: return p.save_state()),
	}


func load_state(s: Dictionary) -> void:
	frame = s.frame
	camera_x = s.camera_x
	for i in fighters.size():
		fighters[i].load_state(s.fighters[i])
	var restored: Array[Projectile] = []
	for p: Dictionary in s.projectiles:
		restored.append(Projectile.from_state(p))
	projectiles = restored


## 32 位状态哈希，用于确定性校验与（以后的）联网不同步检测。
func state_hash() -> int:
	var values: Array[int] = [frame, camera_x, projectiles.size()]
	for f in fighters:
		values.append_array(f.hash_values())
	for p in projectiles:
		values.append_array(p.hash_values())
	var h := 2166136261
	for v in values:
		h = ((h ^ (v & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
	return h
