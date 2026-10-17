class_name FxLayer
extends Node2D
## 打击反馈（纯表现）：命中/防御火花、震屏、落地扬尘、超杀闪光。
## 由仿真的 events 驱动，特效的年龄按仿真帧计算（暂停时特效也停住，顿帧中照常播放）。

const SPARK_LIFE := 14
const DUST_LIFE := 16

var sim: MatchSim
var shake := 0.0 ## 当前震屏强度（像素）
var _fx: Array[Dictionary] = []
var _prev_state: Array[int] = [-1, -1]


## 每推进一帧仿真后调用一次。
func consume(events: Array[Dictionary]) -> void:
	for e in events:
		var pos := Vector2(SimConst.px(e.x), -SimConst.px(e.y))
		match e.type:
			"hit", "block", "armor", "clash":
				_fx.append({"kind": e.type, "pos": pos, "born": sim.frame, "strength": e.get("strength", 0),
					"counter": e.get("counter", 0), "super": e.get("super", false), "dir": e.get("dir", 1)})
				if e.type == "hit":
					shake = maxf(shake, [1.0, 2.5, 5.0][e.strength] + (3.0 if e.counter else 0.0) + (4.0 if e.super else 0.0))
			"super":
				_fx.append({"kind": "flash", "pos": pos, "born": sim.frame})
			"ko":
				shake = 12.0
				_fx.append({"kind": "flash", "pos": pos, "born": sim.frame})
	_spawn_dust()
	shake = maxf(shake * 0.82 - 0.1, 0.0)
	_fx = _fx.filter(func(fx: Dictionary) -> bool: return sim.frame - fx.born < 40)
	queue_redraw()


## 当前帧的震屏偏移（像素），交替方向，确定性的。
func shake_offset() -> Vector2:
	if shake <= 0.0:
		return Vector2.ZERO
	var s := 1.0 if sim.frame % 2 == 0 else -1.0
	return Vector2(s * shake, -s * shake * 0.5).round()


## 落地、冲刺起步、倒地时在脚下扬尘。
func _spawn_dust() -> void:
	for i in 2:
		var f := sim.fighters[i]
		if f.state != _prev_state[i] and f.state_frame == 0:
			var n := f.state_name()
			if n in ["landing", "landing_long", "dive_land", "land_recover", "knockdown", "dash_f", "dash_b"]:
				_fx.append({"kind": "dust", "pos": Vector2(SimConst.px(f.x), 0), "born": sim.frame,
					"big": n == "knockdown"})
		_prev_state[i] = f.state


func _draw() -> void:
	if sim == null:
		return
	for fx in _fx:
		var age: int = sim.frame - fx.born
		match fx.kind:
			"hit":
				_draw_hit(fx, age)
			"block":
				_draw_block(fx, age)
			"armor":
				_draw_ring(fx.pos, age, Color(0.75, 0.5, 1.0), 26.0)
			"clash":
				_draw_star(fx.pos, age, Color(1, 1, 1), 22.0)
			"dust":
				_draw_dust(fx, age)
			"flash":
				_draw_ring(fx.pos, age, Color(1.0, 0.95, 0.6), 90.0)


func _draw_hit(fx: Dictionary, age: int) -> void:
	if age >= SPARK_LIFE:
		return
	var t := age / float(SPARK_LIFE)
	var size: float = [22.0, 32.0, 44.0][fx.strength] * (1.5 if fx.super else 1.0)
	var core := Color(1.0, 0.97, 0.85)
	var rim := Color(1.0, 0.65, 0.2) if not fx.counter else Color(1.0, 0.25, 0.2)
	if fx.super:
		rim = Color(1.0, 0.85, 0.2)
	var pos: Vector2 = fx.pos
	# 放射状的光线，朝攻击方向偏
	for k in 10:
		var a := k * TAU / 10.0 + 0.3
		var dir := Vector2(cos(a), sin(a))
		if signf(dir.x) == fx.dir:
			dir.x *= 1.6
		var inner := pos + dir * size * 0.35 * t
		var outer := pos + dir * size * (0.6 + t)
		draw_line(inner, outer, Color(rim, 1.0 - t), 3.0 - t * 2.0)
	draw_circle(pos, size * 0.45 * (1.0 - t), Color(core, 1.0 - t))
	if fx.counter:
		draw_arc(pos, size * (0.8 + t), 0, TAU, 24, Color(rim, 1.0 - t), 3.0)


func _draw_block(fx: Dictionary, age: int) -> void:
	if age >= SPARK_LIFE:
		return
	var t := age / float(SPARK_LIFE)
	var c := Color(0.55, 0.8, 1.0, 1.0 - t)
	var pos: Vector2 = fx.pos
	var face := -float(fx.dir)
	for k in 3:
		var r := 14.0 + k * 7.0 + t * 10.0
		var mid := PI if face < 0 else 0.0
		draw_arc(pos, r, mid - 1.0, mid + 1.0, 10, c, 2.5)
	draw_circle(pos, 6.0 * (1.0 - t), Color(1, 1, 1, 1.0 - t))


func _draw_ring(pos: Vector2, age: int, color: Color, size: float) -> void:
	if age >= SPARK_LIFE:
		return
	var t := age / float(SPARK_LIFE)
	draw_arc(pos, size * (0.3 + t), 0, TAU, 32, Color(color, 1.0 - t), 4.0)
	draw_circle(pos, size * 0.25 * (1.0 - t), Color(color, 0.8 * (1.0 - t)))


func _draw_star(pos: Vector2, age: int, color: Color, size: float) -> void:
	if age >= SPARK_LIFE:
		return
	var t := age / float(SPARK_LIFE)
	for k in 4:
		var a := k * PI / 4.0
		var d := Vector2(cos(a), sin(a)) * size * (0.5 + t)
		draw_line(pos - d, pos + d, Color(color, 1.0 - t), 3.0)


func _draw_dust(fx: Dictionary, age: int) -> void:
	if age >= DUST_LIFE:
		return
	var t := age / float(DUST_LIFE)
	var spread := (40.0 if fx.big else 22.0) * (0.4 + t)
	var c := Color(0.8, 0.78, 0.72, 0.55 * (1.0 - t))
	for k in [-1.0, -0.4, 0.4, 1.0]:
		draw_circle(fx.pos + Vector2(k * spread, -6.0 - t * 8.0), (5.0 if fx.big else 3.5) * (1.0 + t), c)
