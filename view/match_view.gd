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

## 摄像机中心相对地面的高度（像素），让地面落在屏幕下方
const CAMERA_HEIGHT_PX := 260.0

var sim: MatchSim
var show_boxes := false ## 判定框显示（训练模式按 6 或 F1 切换）
var show_sprites := true
var _sprites: Array = [null, null] ## 每名玩家的 SpriteSet（没有精灵时为 null）

@onready var camera: Camera2D = $Camera2D
@onready var fx: FxLayer = $FxLayer

var _camera_y := -CAMERA_HEIGHT_PX


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
	_camera_y = lerpf(_camera_y, target_y, 0.2)
	camera.position = (Vector2(SimConst.px(sim.camera_x), _camera_y) + fx.shake_offset()).round()
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var font := ThemeDB.fallback_font
	_draw_stage()
	if sim.freeze > 0:
		# 超杀暂停：背景压暗，突出角色（纯表现）
		draw_rect(Rect2(SimConst.px(sim.camera_x) - 2000, -2000, 4000, 2600), Color(0.02, 0.0, 0.08, 0.6))
	for i in sim.fighters.size():
		var sprites: SpriteSet = _sprites[i]
		if show_sprites and sprites != null:
			_draw_sprite(sim.fighters[i], sprites)
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


func _draw_sprite(f: Fighter, sprites: SpriteSet) -> void:
	var shadow_w := SimConst.px(f.def.push_half_width) * 1.4
	var x := roundf(SimConst.px(f.x))
	draw_line(Vector2(x - shadow_w, 2), Vector2(x + shadow_w, 2), Color(0, 0, 0, 0.45), 4.0)
	draw_fighter_sprite(self, f)


## 把角色当前帧画到 canvas 上（受击闪光层也用它画同一位置的剪影）。
func draw_fighter_sprite(canvas: CanvasItem, f: Fighter, modulate := Color.WHITE) -> void:
	var sprites: SpriteSet = _sprites[f.index]
	if sprites == null or not show_sprites:
		return
	var tex := _sprite_frame(f, sprites)
	var feet := Vector2(SimConst.px(f.x), -SimConst.px(f.y)).round()
	# 顿帧中的被打方左右抖动（打击感）
	if f.hitstop > 0 and f.sd().kind == "hurt":
		feet.x += 3.0 if sim.frame % 2 == 0 else -3.0
	canvas.draw_set_transform(feet, 0.0, Vector2(sprites.scale * f.facing, sprites.scale))
	canvas.draw_texture(tex, -sprites.anchor, modulate)
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
	var fx := "fx_" + sim.projectile_def(p).anim
	if show_sprites and sprites != null and sprites.has(fx):
		var center := Vector2(SimConst.px(p.x), -SimConst.px(p.y))
		draw_set_transform(center, 0.0, Vector2(sprites.scale * p.facing, sprites.scale))
		# 未启动的设置物 / 多段间隔中的道具画得半透明
		var alpha := 1.0 if sim.projectile_live(p) else 0.45
		draw_texture(sprites.frame_at(fx, p.age), -sprites.anchor_of(fx), Color(1, 1, 1, alpha))
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
