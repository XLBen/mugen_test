class_name MatchSim
extends RefCounted
## 一场对战的确定性仿真。step(inputs) 推进一帧；不依赖场景树、系统时间或浮点。
## 同样的初始状态 + 同样的输入序列，必然得到同样的结果（回滚联网的前提）。
##
## 每帧顺序：记录输入 → 角色更新（逻辑/事件/物理）→ 道具移动 → 墙与推挤 → 命中结算 → 摄像机

enum Round { INTRO, FIGHT, END, MATCH_OVER }

const ROUND_TIME := 99 * SimConst.FPS
const INTRO_FRAMES := 70
const END_FRAMES := 150
const WINS_NEEDED := 2

var stage: StageDef
var fighters: Array[Fighter] = []
var projectiles: Array[Projectile] = []

## 设置（不随对战变化，修改后调用 reset()）
var versus := false ## true = 回合制对战（开场、计时、KO、三局两胜）；false = 自由模式
var training := false ## 训练模式：不会 KO、恢复可行动后回满血
var infinite_meter := false ## 训练模式：资源槽常满
var health_floor := 0 ## 体力下限（训练模式为 1）

## 表现事件（命中、防御、霸体、道具相杀、KO……）：每帧开头清空，只给表现层（火花、震屏、音效）读取，
## 不属于仿真状态，不进存档也不影响确定性。
var events: Array[Dictionary] = []

## 可变状态
var frame := 0
var camera_x := 0 ## 摄像机中心（逻辑单位），屏幕墙由它推导
var freeze := 0 ## 超杀暂停剩余帧：期间整个世界静止，只记录输入
var round_state: int = Round.FIGHT
var round_frame := 0 ## 当前回合阶段经过的帧
var round_timer := ROUND_TIME
var round_number := 1
var wins: Array[int] = [0, 0]


func _init(p_stage: StageDef, p1_def: FighterDef, p2_def: FighterDef) -> void:
	stage = p_stage
	fighters = [Fighter.new(p1_def), Fighter.new(p2_def)]
	for i in 2:
		fighters[i].index = i
	reset()


## 整场重置。versus = true 时从第一回合开场开始。
func reset() -> void:
	frame = 0
	wins = [0, 0]
	round_number = 1
	health_floor = 1 if training else 0
	_reset_round(false)


func _reset_round(keep_gauges: bool) -> void:
	camera_x = 0
	freeze = 0
	projectiles = []
	for f in fighters:
		f.reset_state(keep_gauges)
	fighters[0].x = -stage.start_offset
	fighters[0].facing = 1
	fighters[1].x = stage.start_offset
	fighters[1].facing = -1
	round_timer = ROUND_TIME
	round_frame = 0
	round_state = Round.INTRO if versus else Round.FIGHT


## 把两人放到指定位置（训练模式的版边重置等），摄像机随之对齐。
func place(p1_x: int, p2_x: int) -> void:
	fighters[0].x = p1_x
	fighters[1].x = p2_x
	for f in fighters:
		f.facing = 1 if opponent(f).x > f.x else -1
	camera_x = clampi((p1_x + p2_x) / 2, -_camera_limit(), _camera_limit())


func emit(type: String, x: int, y: int, extra := {}) -> void:
	var e := {"type": type, "x": x, "y": y, "frame": frame}
	e.merge(extra)
	events.append(e)


func opponent(f: Fighter) -> Fighter:
	return fighters[1 - f.index]


## inputs[i] 是第 i 名玩家本帧的 InputBits（会在此做 SOCD 清理）。
func step(inputs: Array[int]) -> void:
	frame += 1
	events.clear()
	var accept_input := round_state == Round.FIGHT
	for i in 2:
		fighters[i].record_input(frame, InputBits.clean_socd(inputs[i]) if accept_input else 0)
	if freeze > 0:
		freeze -= 1
		for f in fighters:
			if f.held < f.sd().freeze_len:
				f.held += 1
		return

	for f in fighters:
		StateRunner.update(f, self)
		Gauges.tick(f)
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
	for f in fighters:
		Combat.check_wall(self, f)

	Combat.resolve(self)
	_update_camera()
	_update_round()


# ---------------------------------------------------------------- 回合

func _update_round() -> void:
	round_frame += 1
	if not versus:
		if training:
			_training_refill()
		return
	match round_state:
		Round.INTRO:
			if round_frame >= INTRO_FRAMES:
				_set_round_state(Round.FIGHT)
		Round.FIGHT:
			round_timer -= 1
			if fighters[0].health <= 0 or fighters[1].health <= 0 or round_timer <= 0:
				_end_round()
		Round.END:
			if round_frame >= END_FRAMES:
				if wins[0] >= WINS_NEEDED or wins[1] >= WINS_NEEDED:
					_set_round_state(Round.MATCH_OVER)
				else:
					round_number += 1
					_reset_round(true)


## 体力高的一方赢；相同（含双 KO、时间到同血）双方各得一胜。
func _end_round() -> void:
	var h0 := fighters[0].health
	var h1 := fighters[1].health
	if fighters[0].health <= 0 or fighters[1].health <= 0:
		var loser := fighters[0] if h0 <= h1 else fighters[1]
		emit("ko", loser.x, loser.y + 10000)
	if h0 >= h1:
		wins[0] += 1
	if h1 >= h0:
		wins[1] += 1
	_set_round_state(Round.END)


func _set_round_state(s: int) -> void:
	round_state = s
	round_frame = 0


## 训练模式：恢复可行动后回满血；可选资源常满。
func _training_refill() -> void:
	for f in fighters:
		if f.sd().ctrl and f.combo_hits == 0:
			f.health = f.def.max_health
		if infinite_meter:
			for i in Gauges.DEFS.size():
				f.gauges[i] = Gauges.DEFS[i].max
			f.burnout = 0


## 回合内的胜者（-1 = 平局/未结束），给 HUD 用。
func round_winner() -> int:
	if round_state != Round.END and round_state != Round.MATCH_OVER:
		return -1
	if fighters[0].health == fighters[1].health:
		return -1
	return 0 if fighters[0].health > fighters[1].health else 1


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
	p.vy = pd.speed_y
	p.hits = pd.hits
	projectiles.append(p)


## group 为空时任意道具都算；否则只看同组（波动 / 设置物 各自限制同屏数量）。
func has_projectile(owner: Fighter, group := "") -> bool:
	for p in projectiles:
		if p.owner == owner.index and (group == "" or projectile_def(p).group == group):
			return true
	return false


func projectile_def(p: Projectile) -> ProjectileDef:
	return fighters[p.owner].moveset.projectiles[p.def_id]


## 道具当前是否有攻击判定（设置物未启动、多段间隔中都没有）。
func projectile_live(p: Projectile) -> bool:
	return p.age >= projectile_def(p).arm and p.cooldown == 0


func projectile_box(p: Projectile) -> PackedInt32Array:
	return Box.to_world(p.x, p.y, p.facing, projectile_def(p).box)


func _move_projectiles() -> void:
	var alive: Array[Projectile] = []
	for p in projectiles:
		p.x += p.vx
		p.y += p.vy
		p.age += 1
		if p.cooldown > 0:
			p.cooldown -= 1
		var landed := p.vy < 0 and p.y <= 0
		if not landed and p.age < projectile_def(p).lifetime and absi(p.x) < stage.half_width + 20000:
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
		"freeze": freeze,
		"round": [round_state, round_frame, round_timer, round_number, wins[0], wins[1]],
		"fighters": fighters.map(func(f: Fighter) -> Dictionary: return f.save_state()),
		"projectiles": projectiles.map(func(p: Projectile) -> Dictionary: return p.save_state()),
	}


func load_state(s: Dictionary) -> void:
	frame = s.frame
	camera_x = s.camera_x
	freeze = s.freeze
	round_state = s.round[0]
	round_frame = s.round[1]
	round_timer = s.round[2]
	round_number = s.round[3]
	wins = [s.round[4], s.round[5]]
	for i in fighters.size():
		fighters[i].load_state(s.fighters[i])
	var restored: Array[Projectile] = []
	for p: Dictionary in s.projectiles:
		restored.append(Projectile.from_state(p))
	projectiles = restored


## 32 位状态哈希，用于确定性校验与（以后的）联网不同步检测。
func state_hash() -> int:
	var values: Array[int] = [frame, camera_x, projectiles.size(), freeze, round_state, round_frame,
		round_timer, round_number, wins[0], wins[1]]
	for f in fighters:
		values.append_array(f.hash_values())
	for p in projectiles:
		values.append_array(p.hash_values())
	var h := 2166136261
	for v in values:
		h = ((h ^ (v & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
	return h
