class_name FxLayer
extends Node2D
## 打击反馈（纯表现）：命中/防御火花、火星粒子、受击闪光、震屏、落地扬尘、超杀闪光。
## 由仿真的 events 驱动，特效的年龄按仿真帧计算（暂停时特效也停住，顿帧中照常播放）。
## 火花用着色器（view/shaders/hit_spark.gdshader）画在子节点 Sparks 上（加色混合）；
## 受击闪光用剪影着色器画在子节点 Flashes 上；OD 招式的金身和金色残影画在子节点 OdGold 上；
## 扬尘用普通混合画在本节点上。
## Drive 系统：招架时身上蓝色脉冲、成功是蓝色护盾火花（完美招架是白闪）；Drive Impact 发动时墨色剪影脉冲、命中大爆闪；
## 撞墙在墙上留裂纹；眩晕时头上转星星。

const DUST_LIFE := 16
const FLASH_LIFE := 4
const PART_LIFE := 18
const PART_GRAVITY := 0.35 ## 火星下落加速度（像素/帧²）
const CRACK_LIFE := 40
const PARRY_PULSE := 6 ## 招架中每几帧闪一次蓝
const C_PARRY := Color(0.4, 0.75, 1.0, 0.5)
const C_INK := Color(0.08, 0.02, 0.18, 0.7) ## Drive Impact 发动时的墨色

## 配色编号，与 hit_spark.gdshader 的 PAL 对应
enum Pal { HIT, COUNTER, PUNISH, SUPER, GUARD, ARMOR, CLASH, FLASH }
## 着色器模式
enum Mode { BURST, GUARD, PARTICLE, FLASH }

var sim: MatchSim
var shake := 0.0 ## 当前震屏强度（像素）
var _fx: Array[Dictionary] = []
var _flashes: Array[Dictionary] = [] ## 受击剪影 {target, born, color}
var _prev_state: Array[int] = [-1, -1]
var _sparks: Sparks
var _flash_layer: Flashes
var _od: OdGold


func _ready() -> void:
	_sparks = Sparks.new()
	_sparks.fx = self
	add_child(_sparks)
	_flash_layer = Flashes.new()
	_flash_layer.fx = self
	add_child(_flash_layer)
	move_child(_flash_layer, 0) # 剪影在火花下面
	_od = OdGold.new()
	_od.fx = self
	add_child(_od)
	move_child(_od, 0) # 金身在最下面（紧贴角色本体）


## 每推进一帧仿真后调用一次。
func consume(events: Array[Dictionary]) -> void:
	for e in events:
		var pos := Vector2(SimConst.px(e.x), -SimConst.px(e.y))
		match e.type:
			"hit", "block", "armor", "clash":
				_add_spark(e, pos)
			"tech":
				shake = maxf(shake, 3.0)
				_fx.append({"kind": "spark", "pos": pos, "born": sim.frame, "life": 14, "size": 90.0, "pal": Pal.CLASH,
					"mode": Mode.BURST, "power": 0.5, "dir": e.get("dir", 1), "seed": _seed(e),
					"parts": _particles(_seed(e), 3, false)})
			"super":
				_fx.append({"kind": "flash", "pos": pos, "born": sim.frame, "life": 26, "size": 150.0, "pal": Pal.SUPER,
					"seed": _seed(e)})
			"ko":
				shake = 12.0
				_fx.append({"kind": "flash", "pos": pos, "born": sim.frame, "life": 34, "size": 220.0, "pal": Pal.FLASH,
					"seed": _seed(e)})
			"parry":
				_fx.append({"kind": "spark", "pos": pos, "born": sim.frame, "life": 14, "size": 80.0, "pal": Pal.GUARD,
					"mode": Mode.GUARD, "power": 0.5, "dir": e.get("dir", 1), "seed": _seed(e),
					"parts": _particles(_seed(e), 2, true)})
				_flashes.append({"target": e.target, "born": sim.frame, "color": Color(0.55, 0.85, 1.0, 0.8)})
			"perfect_parry":
				shake = maxf(shake, 4.0)
				_fx.append({"kind": "flash", "pos": pos, "born": sim.frame, "life": 30, "size": 190.0, "pal": Pal.FLASH,
					"seed": _seed(e)})
				_flashes.append({"target": e.target, "born": sim.frame, "color": Color(1, 1, 1, 0.95)})
			"drive_impact", "drive_reversal":
				_fx.append({"kind": "flash", "pos": pos, "born": sim.frame, "life": 20, "size": 130.0, "pal": Pal.ARMOR,
					"seed": _seed(e)})
			"wall_splat", "wall_bounce", "stun":
				shake = maxf(shake, 8.0)
				_fx.append({"kind": "crack", "pos": pos, "born": sim.frame, "life": CRACK_LIFE, "dir": e.get("dir", 1),
					"seed": _seed(e)})
	_spawn_dust()
	_state_pulses()
	_od.record()
	shake = maxf(shake * 0.82 - 0.1, 0.0)
	_fx = _fx.filter(func(fx: Dictionary) -> bool: return sim.frame - fx.born < fx.get("life", DUST_LIFE) + PART_LIFE)
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return sim.frame - f.born < FLASH_LIFE)
	queue_redraw()
	_sparks.queue_redraw()
	_flash_layer.queue_redraw()
	_od.queue_redraw()


func _add_spark(e: Dictionary, pos: Vector2) -> void:
	var strength: int = e.get("strength", 0)
	var counter: int = e.get("counter", 0)
	var is_super: bool = e.get("super", false)
	var pal := Pal.HIT
	var mode := Mode.BURST
	match e.type:
		"block":
			pal = Pal.GUARD
			mode = Mode.GUARD
		"armor":
			pal = Pal.ARMOR
		"clash":
			pal = Pal.CLASH
		_:
			if is_super:
				pal = Pal.SUPER
			elif counter == Combat.Counter.PUNISH:
				pal = Pal.PUNISH
			elif counter != 0:
				pal = Pal.COUNTER
	var size: float = [56.0, 76.0, 100.0][strength] * (1.45 if is_super else 1.0) * (1.15 if counter else 1.0)
	if mode == Mode.GUARD:
		size *= 0.85
	var seed := _seed(e)
	var fx := {"kind": "spark", "pos": pos, "born": sim.frame, "life": 12 + strength * 3 + (6 if is_super else 0),
		"size": size, "pal": pal, "mode": mode, "power": strength / 2.0, "dir": e.get("dir", 1), "seed": seed,
		"parts": _particles(seed, strength + (2 if counter or is_super else 0), mode == Mode.GUARD)}
	_fx.append(fx)
	if e.type == "hit":
		shake = maxf(shake, [1.0, 2.5, 5.0][strength] + (3.0 if counter else 0.0) + (4.0 if is_super else 0.0)
			+ (6.0 if e.get("drive", false) else 0.0))
		if counter == Combat.Counter.PUNISH or e.get("drive", false):
			# 确反 / Drive Impact 命中：再加一圈大的白闪
			_fx.append({"kind": "flash", "pos": pos, "born": sim.frame, "life": 16, "size": size * 1.6, "pal": Pal.FLASH,
				"seed": fposmod(seed + 0.5, 1.0)})
	if e.has("target"):
		var c := Color(1, 1, 1, 0.85)
		match e.type:
			"block":
				c = Color(0.55, 0.85, 1.0, 0.55)
			"armor":
				c = Color(0.8, 0.55, 1.0, 0.8)
			_:
				if counter != 0:
					c = Color(1.0, 0.35, 0.3, 0.85)
		_flashes.append({"target": e.target, "born": sim.frame, "color": c})


## 特效的随机种子：由事件的帧号和位置决定（同一场对局重放时画面一致）。
func _seed(e: Dictionary) -> float:
	return fposmod(e.frame * 0.618 + e.x * 0.00071 + e.y * 0.0013, 1.0)


## 火星粒子：朝打击方向的扇形飞出，之后受重力下落。返回 [[vx, vy, size], ...]（像素/帧）。
func _particles(seed: float, amount: int, guard: bool) -> Array:
	var out := []
	var n := 5 + amount * 3
	for k in n:
		var h1 := fposmod(sin((seed * 97.0 + k) * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin((seed * 61.0 + k * 1.7) * 78.233) * 43758.5453, 1.0)
		var angle := (h1 - 0.5) * (2.6 if guard else 1.9) - 0.35
		var speed := 3.0 + h2 * (5.0 + amount * 1.2)
		var v := Vector2(cos(angle), sin(angle)) * speed
		if guard:
			v.x = -v.x * 0.7 # 防御火花朝攻击方弹回
		out.append([v.x, v.y, 3.0 + h2 * 3.0])
	return out


## 当前帧的震屏偏移（像素），交替方向，确定性的。
func shake_offset() -> Vector2:
	if shake <= 0.0:
		return Vector2.ZERO
	var s := 1.0 if sim.frame % 2 == 0 else -1.0
	return Vector2(s * shake, -s * shake * 0.5).round()


## 状态持续中的闪光：招架中周期性蓝闪，Drive Impact 发动到出手之间墨色脉冲。
func _state_pulses() -> void:
	for i in 2:
		var f := sim.fighters[i]
		var s := f.sd()
		if s.logic == "parry" and f.state_frame % PARRY_PULSE == 0:
			_flashes.append({"target": i, "born": sim.frame, "color": C_PARRY})
		elif s.name == "drive_impact" and f.state_frame < s.first_active and f.state_frame % 4 == 0:
			_flashes.append({"target": i, "born": sim.frame, "color": C_INK})


## 落地、冲刺起步、倒地时在脚下扬尘。
func _spawn_dust() -> void:
	for i in 2:
		var f := sim.fighters[i]
		if f.state != _prev_state[i] and f.state_frame == 0:
			var n := f.state_name()
			if f.sd().is_od():
				# OD 发动：角色身上一圈金色像素爆闪
				_fx.append({"kind": "flash", "pos": Vector2(SimConst.px(f.x), -SimConst.px(f.y + f.def.stand_height / 2)),
					"born": sim.frame, "life": 18, "size": 110.0, "pal": Pal.SUPER, "seed": fposmod(sim.frame * 0.37, 1.0)})
			if n in ["landing", "landing_long", "dive_land", "land_recover", "knockdown", "dash_f", "dash_b"]:
				_fx.append({"kind": "dust", "pos": Vector2(SimConst.px(f.x), 0), "born": sim.frame,
					"big": n == "knockdown", "life": DUST_LIFE})
		_prev_state[i] = f.state


func _draw() -> void:
	if sim == null:
		return
	for fx in _fx:
		if fx.kind == "dust":
			_draw_dust(fx, sim.frame - fx.born)
		elif fx.kind == "crack":
			_draw_crack(fx, sim.frame - fx.born)
	for f in sim.fighters:
		if f.sd().logic == "dizzy":
			_draw_stars(f)


## 撞墙裂纹：从撞击点放射出的折线，逐渐变淡。
func _draw_crack(fx: Dictionary, age: int) -> void:
	if age >= CRACK_LIFE:
		return
	var a := 0.8 * (1.0 - age / float(CRACK_LIFE))
	var c := Color(0.05, 0.04, 0.08, a)
	for k in 7:
		var h := fposmod(sin((fx.seed * 31.0 + k) * 12.9898) * 43758.5453, 1.0)
		var ang := PI / 2 + (k / 6.0 - 0.5) * 2.6 # 朝场内一侧的扇形
		var dir := Vector2(-cos(ang) * fx.dir, sin(ang) - 0.5)
		var p0: Vector2 = fx.pos
		var length := 30.0 + h * 50.0
		var p1 := p0 + dir * length * 0.5 + Vector2(0, (h - 0.5) * 10.0)
		var p2 := p0 + dir * length
		draw_polyline(PackedVector2Array([p0.round(), p1.round(), p2.round()]), c, 3.0)


## 眩晕：头上三颗转圈的星星。
func _draw_stars(f: Fighter) -> void:
	var head := Vector2(SimConst.px(f.x), -SimConst.px(f.y + f.def.stand_height) - 14.0)
	for k in 3:
		var ang := sim.frame * 0.12 + k * TAU / 3.0
		var p := head + Vector2(cos(ang) * 26.0, sin(ang) * 8.0)
		var pts := PackedVector2Array()
		for j in 10:
			var r := 7.0 if j % 2 == 0 else 3.0
			var a := j * PI / 5.0 - PI / 2
			pts.append((p + Vector2(cos(a), sin(a)) * r).round())
		draw_colored_polygon(pts, Color(1.0, 0.9, 0.3))


func _draw_dust(fx: Dictionary, age: int) -> void:
	if age >= DUST_LIFE:
		return
	var t := age / float(DUST_LIFE)
	var spread := (40.0 if fx.big else 22.0) * (0.4 + t)
	var c := Color(0.8, 0.78, 0.72, 0.55 * (1.0 - t))
	for k in [-1.0, -0.4, 0.4, 1.0]:
		var r := (5.0 if fx.big else 3.5) * (1.0 + t)
		draw_rect(Rect2(fx.pos + Vector2(k * spread - r, -6.0 - t * 8.0 - r), Vector2(r, r) * 2.0).abs(), c)


## 火花层：每个特效一个四边形，形状全部在着色器里算，参数编进顶点颜色。
class Sparks extends Node2D:
	const SHADER := preload("res://view/shaders/hit_spark.gdshader")

	var fx: FxLayer
	var _white: Texture2D

	func _ready() -> void:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		material = mat
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)

	func _draw() -> void:
		if fx == null or fx.sim == null:
			return
		for e in fx._fx:
			var age: int = fx.sim.frame - e.born
			match e.kind:
				"spark":
					if age < e.life:
						_quad(e.pos, Vector2(e.size * e.dir, e.size), age / float(e.life), e.seed, e.power, e.mode, e.pal)
					_draw_particles(e, age)
				"flash":
					if age < e.life:
						_quad(e.pos, Vector2(e.size, e.size), age / float(e.life), e.seed, 0.0, Mode.FLASH, e.pal)

	func _draw_particles(e: Dictionary, age: int) -> void:
		if age >= PART_LIFE or age == 0:
			return
		var t := age / float(PART_LIFE)
		for p: Array in e.parts:
			var v := Vector2(p[0] * e.dir, p[1])
			# 带空气阻力的抛物线，按年龄直接求位置（不保存逐帧状态）
			var drag := (1.0 - pow(0.86, age)) / 0.14
			var pos: Vector2 = e.pos + v * drag + Vector2(0, 0.5 * PART_GRAVITY * age * age)
			var s: float = p[2] * (1.0 - t * 0.5)
			_quad(pos, Vector2(s, s), t, e.seed, 0.0, Mode.PARTICLE, e.pal)

	func _quad(pos: Vector2, half: Vector2, t: float, seed: float, power: float, mode: int, pal: int) -> void:
		draw_set_transform(pos.round(), 0.0, half)
		var code := (mode * 8 + pal + 0.5) / 32.0
		draw_texture_rect(_white, Rect2(-1, -1, 2, 2), false, Color(t, seed, power, code))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 受击闪光层：被打 / 防御的一瞬间，用剪影着色器把角色当前帧画成纯色叠在上面。
class Flashes extends Node2D:
	const SHADER := preload("res://view/shaders/silhouette.gdshader")

	var fx: FxLayer

	func _ready() -> void:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		material = mat

	func _draw() -> void:
		if fx == null or fx.sim == null:
			return
		var view := fx.get_parent() as MatchView
		if view == null:
			return
		for f in fx._flashes:
			var age: int = fx.sim.frame - f.born
			var c: Color = f.color
			c.a *= 1.0 - age / float(FLASH_LIFE)
			view.draw_fighter_sprite(self, fx.sim.fighters[f.target], c)



## OD 金身：OD 招式期间把角色画成金色（着色器做像素风调色板映射 + 描边 + 扫光），身后拖几道棋盘格抖动的金色残影。
## 残影存的是前几个仿真帧的贴图和位置，所以暂停时也停在原地。
class OdGold extends Node2D:
	const SHADER := preload("res://view/shaders/od_gold.gdshader")
	const GHOSTS := [[6, 0.3], [4, 0.45], [2, 0.6]] ## [几帧前, 透明度]
	const KEEP := 8

	var fx: FxLayer
	var _history: Array = [[], []] ## 每名角色 [[仿真帧, pose], ...]

	func _ready() -> void:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		material = mat

	func record() -> void:
		var view := fx.get_parent() as MatchView
		if view == null:
			return
		var frame := fx.sim.frame
		for i in fx.sim.fighters.size():
			var f := fx.sim.fighters[i]
			var list: Array = _history[i]
			if f.sd().is_od():
				var pose := view.sprite_pose(f)
				if not pose.is_empty():
					list.append([frame, pose])
			while not list.is_empty() and frame - list[0][0] > KEEP:
				list.pop_front()

	func _draw() -> void:
		if fx == null or fx.sim == null:
			return
		var view := fx.get_parent() as MatchView
		if view == null:
			return
		var frame := fx.sim.frame
		var phase := (frame % 32) / 32.0
		for i in fx.sim.fighters.size():
			for g: Array in GHOSTS:
				var pose := _pose_at(i, frame - g[0])
				if not pose.is_empty():
					MatchView.draw_pose(self, pose, Color(phase, 1.0, 1.0, g[1]))
			var f := fx.sim.fighters[i]
			if f.sd().is_od():
				var now := view.sprite_pose(f)
				if not now.is_empty():
					MatchView.draw_pose(self, now, Color(phase, 1.0, 0.0, 1.0))

	func _pose_at(i: int, frame: int) -> Dictionary:
		for e: Array in _history[i]:
			if e[0] == frame:
				return e[1]
		return {}
