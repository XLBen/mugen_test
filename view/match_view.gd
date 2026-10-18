class_name MatchView
extends Node2D
## 渲染：只读取 MatchSim 的状态来绘制，不修改任何逻辑数据。
## 世界坐标：x 向右，地面 y = 0，逻辑 y 向上为正 → 屏幕 y = -y。

const P_COLORS := [Color(0.35, 0.6, 1.0), Color(1.0, 0.4, 0.35)]
const PUSHBOX_COLOR := Color(1.0, 0.85, 0.2)
const HURTBOX_COLOR := Color(0.3, 0.6, 1.0)
const HITBOX_COLOR := Color(1.0, 0.2, 0.2)
const THROWBOX_COLOR := Color(0.3, 1.0, 0.4)
const WALL_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const STAGE_EDGE_COLOR := Color(1.0, 0.3, 0.3, 0.8)
const GROUND_COLOR := Color(0.55, 0.55, 0.6)
const GRID_COLOR := Color(1, 1, 1, 0.06)
const FIREBALL_COLORS := [Color(0.5, 0.8, 1.0), Color(1.0, 0.6, 0.3)]
const TRAIL_SPEED_PX := 8.0 ## 每帧移动超过这么多像素的道具画拖影
const TRAIL_ALPHA := [0.5, 0.3, 0.15]
const BURNOUT_TINT := Color(0.72, 0.72, 0.78) ## Burnout 中角色发灰
const VANISH_FADE := 3.0

## 摄像机中心相对地面的高度（像素），让地面落在屏幕下方
const CAMERA_HEIGHT_PX := 260.0
## 镜头缩放（纯表现，不影响仿真里的屏幕墙）：两人靠近时略微拉近；超杀暂停时推近并偏向出招方
const ZOOM_NEAR := 1.12
const ZOOM_NEAR_FROM_PX := 520.0
const ZOOM_SUPER := [1.0, 1.25, 1.3, 1.4] ## 按超杀等级
const ZOOM_EASE := 0.15

var sim: MatchSim
var show_boxes := false ## 判定框显示（训练模式按 6 或 F1 切换）
var show_sprites := true
var _sprites: Array = [null, null] ## 每名玩家的 SpriteSet（没有精灵时为 null）

@onready var camera: Camera2D = $Camera2D
@onready var fx: FxLayer = $FxLayer

var _camera_y := -CAMERA_HEIGHT_PX
var _zoom := 1.0
var _top := 1 ## 画在上层的角色（攻击方在前）
var super_focus := -1 ## 超杀暂停中的出招方（场景根据事件设置，-1 = 没有）
var super_level := 1


## 角色变更后调用。同角色镜像时 P2 用第二套配色。
func load_sprites() -> void:
	for i in 2:
		var def := sim.fighters[i].def
		var palette := 1 if i == 1 and def.sprite_dir == sim.fighters[0].def.sprite_dir else 0
		_sprites[i] = SpriteSet.load_from(def.sprite_dir, palette) if def.sprite_dir != "" else null


func _process(_delta: float) -> void:
	if sim == null:
		return
	fx.sim = sim
	# 摄像机：水平跟随仿真里的摄像机，垂直方向在有人跳高时适度上移；加上震屏；对齐整数像素避免像素抖动
	var top := maxf(SimConst.px(sim.fighters[0].y), SimConst.px(sim.fighters[1].y))
	var target_y := -CAMERA_HEIGHT_PX - maxf(top - 140.0, 0.0) * 0.5
	var focus := super_focus if sim.freeze > 0 else -1
	var dist := absf(SimConst.px(sim.fighters[0].x - sim.fighters[1].x))
	_zoom = lerpf(_zoom, zoom_for(dist, focus, super_level), ZOOM_EASE)
	var cx := SimConst.px(sim.camera_x)
	if focus >= 0:
		# 超杀特写：镜头偏向出招方，并稍微压低到角色上半身
		cx = lerpf(cx, SimConst.px(sim.fighters[focus].x), 0.5)
		target_y += 40.0
	_camera_y = lerpf(_camera_y, target_y, 0.2)
	camera.zoom = Vector2(_zoom, _zoom)
	camera.position = (Vector2(cx, _camera_y) + fx.shake_offset()).round()
	_top = draw_order(sim, _top)
	queue_redraw()


## 瞬移这类招式的隐身：隐身帧内完全看不见，前后各 VANISH_FADE 帧淡出 / 淡入。
static func vanish_alpha(f: Fighter) -> float:
	var v := f.sd().vanish
	if v.is_empty():
		return 1.0
	var t := f.state_frame
	if t >= v[0] and t <= v[1]:
		return 0.0
	var d := mini(absi(t - v[0]), absi(t - v[1]))
	return clampf(float(d) / VANISH_FADE, 0.0, 1.0)


## 镜头缩放：超杀暂停中按等级推近；否则两人越近越拉近一点（最多 ZOOM_NEAR）。
static func zoom_for(distance_px: float, focus: int, level := 1) -> float:
	if focus >= 0:
		return ZOOM_SUPER[clampi(level, 1, 3)]
	return clampf(1.0 + (ZOOM_NEAR_FROM_PX - distance_px) / 2000.0, 1.0, ZOOM_NEAR)


## 谁画在上层：正在出招的一方在前（两人都在出招时保持原来的）；都没出招时被打的一方在后。
static func draw_order(s: MatchSim, prev_top: int) -> int:
	var a0 := s.fighters[0].sd().is_attack()
	var a1 := s.fighters[1].sd().is_attack()
	if a0 != a1:
		return 0 if a0 else 1
	var h0 := s.fighters[0].sd().kind == "hurt"
	var h1 := s.fighters[1].sd().kind == "hurt"
	if h0 != h1:
		return 1 if h0 else 0
	return prev_top


func _draw() -> void:
	if sim == null:
		return
	var font := ThemeDB.fallback_font
	_draw_stage()
	if sim.freeze > 0:
		# 超杀暂停：背景压暗，突出角色（纯表现）
		draw_rect(Rect2(SimConst.px(sim.camera_x) - 2000, -2000, 4000, 2600), Color(0.02, 0.0, 0.08, 0.6))
	for i in sim.fighters.size():
		_draw_shadow(sim.fighters[i])
	for i in [1 - _top, _top]:
		var sprites: SpriteSet = _sprites[i]
		if show_sprites and sprites != null:
			var c := BURNOUT_TINT if sim.fighters[i].burnout != 0 else Color.WHITE
			c.a = vanish_alpha(sim.fighters[i])
			if c.a > 0.0:
				draw_fighter_sprite(self, sim.fighters[i], c)
		else:
			_draw_whitebox(sim.fighters[i], P_COLORS[i])
	for p in sim.projectiles:
		_draw_projectile(p)
	if show_boxes:
		for f in sim.fighters:
			_draw_boxes(f)
		var wl := SimConst.px(sim.screen_wall_left())
		var wr := SimConst.px(sim.screen_wall_right())
		draw_line(Vector2(wl, -720), Vector2(wl, 40), WALL_COLOR, 2.0)
		draw_line(Vector2(wr, -720), Vector2(wr, 40), WALL_COLOR, 2.0)
	if show_boxes:
		for i in sim.fighters.size():
			_draw_label(sim.fighters[i], P_COLORS[i], "P%d" % (i + 1), font)


func _draw_stage() -> void:
	var half := SimConst.px(sim.stage.half_width)
	# 天空背景（窗口清屏色是黑色，用作等比缩放时的黑边）
	draw_rect(Rect2(-half - 800, -1600, half * 2 + 1600, 1600), Color(0.3, 0.3, 0.32))
	draw_rect(Rect2(-half - 800, 0, half * 2 + 1600, 400), Color(0.16, 0.16, 0.2))
	var x := -half
	while x <= half:
		draw_line(Vector2(x, -720), Vector2(x, 0), GRID_COLOR, 1.0)
		x += 100.0
	draw_line(Vector2(-half, 0), Vector2(half, 0), GROUND_COLOR, 2.0)
	draw_line(Vector2(-half, -720), Vector2(-half, 200), STAGE_EDGE_COLOR, 3.0)
	draw_line(Vector2(half, -720), Vector2(half, 200), STAGE_EDGE_COLOR, 3.0)


func _draw_whitebox(f: Fighter, color: Color) -> void:
	var body := _rect(f.pushbox_world())
	var fill := color
	fill.a = 0.55
	draw_rect(body, fill)
	# 朝向标记：身体前方的小三角
	var nose_x := body.position.x + (body.size.x if f.facing > 0 else 0.0)
	var nose_y := body.position.y + 30.0
	var tip := Vector2(nose_x + 16.0 * f.facing, nose_y)
	draw_colored_polygon(PackedVector2Array([Vector2(nose_x, nose_y - 10), tip, Vector2(nose_x, nose_y + 10)]), color)
	draw_line(Vector2(body.position.x, 2), Vector2(body.end.x, 2), Color(0, 0, 0, 0.6), 4.0)


## 脚下的椭圆影子：离地越高越小越淡。
func _draw_shadow(f: Fighter) -> void:
	if vanish_alpha(f) <= 0.0:
		return
	var lift := clampf(SimConst.px(f.y) / 300.0, 0.0, 0.6)
	var r := SimConst.px(f.def.push_half_width) * 1.5 * (1.0 - lift)
	draw_set_transform(Vector2(roundf(SimConst.px(f.x)), 2.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.4 * (1.0 - lift)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 把角色当前帧画到 canvas 上（受击闪光、OD 金身也用它画同一位置的剪影）。
func draw_fighter_sprite(canvas: CanvasItem, f: Fighter, modulate := Color.WHITE) -> void:
	var pose := sprite_pose(f)
	if not pose.is_empty():
		draw_pose(canvas, pose, modulate)


## 角色当前帧的贴图和位置 {tex, feet, scale, anchor}（没有精灵时为空）；OD 残影会把它存下来过几帧再画。
func sprite_pose(f: Fighter) -> Dictionary:
	var sprites: SpriteSet = _sprites[f.index]
	if sprites == null or not show_sprites:
		return {}
	var feet := Vector2(SimConst.px(f.x), -SimConst.px(f.y)).round()
	# 顿帧中的被打方左右抖动（打击感）
	if f.hitstop > 0 and f.sd().kind == "hurt":
		feet.x += 3.0 if sim.frame % 2 == 0 else -3.0
	return {"tex": _sprite_frame(f, sprites), "feet": feet, "scale": Vector2(sprites.scale * f.facing, sprites.scale),
		"anchor": sprites.anchor}


static func draw_pose(canvas: CanvasItem, pose: Dictionary, modulate := Color.WHITE) -> void:
	canvas.draw_set_transform(pose.feet, 0.0, pose.scale)
	canvas.draw_texture(pose.tex, -pose.anchor, modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 逻辑状态 → 动画帧：与仿真取判定盒用同一个 AnimClock，画面和判定逐帧一致。
func _sprite_frame(f: Fighter, sprites: SpriteSet) -> Texture2D:
	var s := AnimClock.shown_state(f)
	for anim in AnimClock.candidates(s, AnimClock.shown_variant(f)):
		if sprites.has(anim):
			return sprites.frame_index(anim, AnimClock.index(f, sprites.data(anim)))
	var fallback: String = {"C": "crouch", "A": "jump", "L": "crouch"}.get(f.sd().type, "idle")
	return sprites.frame_index(fallback, 1 if fallback == "jump" else 0)


func _draw_projectile(p: Projectile) -> void:
	var sprites: SpriteSet = _sprites[p.owner]
	var pd := sim.projectile_def(p)
	var fx := "fx_" + pd.anim
	if sprites != null and not sprites.has(fx) and pd.anim_fallback != "":
		fx = "fx_" + pd.anim_fallback
	if show_sprites and sprites != null and sprites.has(fx):
		var center := Vector2(SimConst.px(p.x), -SimConst.px(p.y))
		# 未启动的设置物 / 多段间隔中的道具画得半透明
		var alpha := 1.0 if sim.projectile_live(p) else 0.45
		# OD 版放出的道具染成金色
		var tint := Color(1.0, 0.82, 0.32, alpha) if pd.name.ends_with("_od") else Color(1, 1, 1, alpha)
		var tex := sprites.frame_at(fx, p.age)
		var scale := Vector2(sprites.scale * p.facing, sprites.scale)
		# 高速道具（飞刀）身后拖几道越来越淡的残影，按整数像素错开
		var step := Vector2(SimConst.px(p.vx), -SimConst.px(p.vy))
		if step.length() >= TRAIL_SPEED_PX:
			for k in TRAIL_ALPHA.size():
				var c := tint
				c.a *= TRAIL_ALPHA[k]
				draw_set_transform((center - step * (k + 1) * 0.9).round(), 0.0, scale)
				draw_texture(tex, -sprites.anchor_of(fx), c)
		draw_set_transform(center.round(), 0.0, scale)
		draw_texture(tex, -sprites.anchor_of(fx), tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var r := _rect(sim.projectile_box(p))
	var c: Color = FIREBALL_COLORS[p.owner]
	var center := r.get_center()
	draw_circle(center, r.size.x * 0.6, Color(c, 0.35))
	draw_circle(center, r.size.x * 0.42, c)
	draw_circle(center + Vector2(p.facing * 4, -3), r.size.x * 0.18, Color.WHITE)


func _draw_boxes(f: Fighter) -> void:
	draw_rect(_rect(f.pushbox_world()), PUSHBOX_COLOR, false, 1.0)
	var s := f.sd()
	if not s.is_invuln(f.state_frame, false):
		for b: PackedInt32Array in f.hurtboxes():
			draw_rect(_rect(b), Color(HURTBOX_COLOR, 0.18))
			draw_rect(_rect(b), HURTBOX_COLOR, false, 1.0)
	for h: Dictionary in s.hitboxes_at(f.state_frame):
		for b: PackedInt32Array in h.boxes:
			var r := _rect(Box.to_world(f.x, f.y, f.facing, b))
			draw_rect(r, Color(HITBOX_COLOR, 0.3))
			draw_rect(r, HITBOX_COLOR, false, 1.0)
	var tb := s.throwbox_at(f.state_frame)
	if not tb.is_empty():
		draw_rect(_rect(Box.to_world(f.x, f.y, f.facing, tb)), THROWBOX_COLOR, false, 2.0)
	for p in sim.projectiles:
		draw_rect(_rect(sim.projectile_box(p)), HITBOX_COLOR, false, 1.0)


func _draw_label(f: Fighter, color: Color, label: String, font: Font) -> void:
	var top := 1e9
	for b: PackedInt32Array in f.hurtboxes():
		top = minf(top, -SimConst.px(b[3]))
	top = minf(top, -SimConst.px(f.pushbox_world()[3])) - 12.0
	var text := "%s  %s" % [label, UiText.state(f.state_name())]
	draw_string(font, Vector2(SimConst.px(f.x) - 40, top), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


## 世界盒 [left, bottom, right, top]（逻辑单位）→ 屏幕矩形（像素，y 向下）。
func _rect(b: PackedInt32Array) -> Rect2:
	return Rect2(SimConst.px(b[0]), -SimConst.px(b[3]), SimConst.px(b[2] - b[0]), SimConst.px(b[3] - b[1]))
