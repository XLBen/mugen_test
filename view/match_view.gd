class_name MatchView
extends Node2D
## 白模渲染：只读取 MatchSim 的状态来绘制，不修改任何逻辑数据。
## 世界坐标：x 向右，地面 y = 0，逻辑 y 向上为正 → 屏幕 y = -y。

const P_COLORS := [Color(0.35, 0.6, 1.0), Color(1.0, 0.4, 0.35)]
const PUSHBOX_COLOR := Color(1.0, 0.85, 0.2)
const WALL_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const STAGE_EDGE_COLOR := Color(1.0, 0.3, 0.3, 0.8)
const GROUND_COLOR := Color(0.55, 0.55, 0.6)
const GRID_COLOR := Color(1, 1, 1, 0.06)

## 摄像机中心相对地面的高度（像素），让地面落在屏幕下方
const CAMERA_HEIGHT_PX := 260.0

var sim: MatchSim
var show_boxes := true

@onready var camera: Camera2D = $Camera2D


func _process(_delta: float) -> void:
	if sim == null:
		return
	camera.position = Vector2(SimConst.px(sim.camera_x), -CAMERA_HEIGHT_PX)
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var font := ThemeDB.fallback_font
	_draw_stage()
	for i in sim.fighters.size():
		_draw_fighter(sim.fighters[i], P_COLORS[i], "P%d" % (i + 1), font)
	if show_boxes:
		for f in sim.fighters:
			draw_rect(_push_rect(f), PUSHBOX_COLOR, false, 1.0)
		var wl := SimConst.px(sim.screen_wall_left())
		var wr := SimConst.px(sim.screen_wall_right())
		draw_line(Vector2(wl, -720), Vector2(wl, 40), WALL_COLOR, 2.0)
		draw_line(Vector2(wr, -720), Vector2(wr, 40), WALL_COLOR, 2.0)


func _draw_stage() -> void:
	var half := SimConst.px(sim.stage.half_width)
	draw_rect(Rect2(-half, 0, half * 2, 200), Color(0.16, 0.16, 0.2))
	var x := -half
	while x <= half:
		draw_line(Vector2(x, -720), Vector2(x, 0), GRID_COLOR, 1.0)
		x += 100.0
	draw_line(Vector2(-half, 0), Vector2(half, 0), GROUND_COLOR, 2.0)
	draw_line(Vector2(-half, -720), Vector2(-half, 200), STAGE_EDGE_COLOR, 3.0)
	draw_line(Vector2(half, -720), Vector2(half, 200), STAGE_EDGE_COLOR, 3.0)


func _draw_fighter(f: Fighter, color: Color, label: String, font: Font) -> void:
	var body := _push_rect(f)
	var fill := color
	fill.a = 0.55
	draw_rect(body, fill)
	# 朝向标记：身体前方的小三角
	var nose_x := body.position.x + (body.size.x if f.facing > 0 else 0.0)
	var nose_y := body.position.y + 30.0
	var tip := Vector2(nose_x + 16.0 * f.facing, nose_y)
	draw_colored_polygon(PackedVector2Array([Vector2(nose_x, nose_y - 10), tip, Vector2(nose_x, nose_y + 10)]), color)
	# 地面阴影，便于看清空中位置
	draw_line(Vector2(body.position.x, 2), Vector2(body.end.x, 2), Color(0, 0, 0, 0.6), 4.0)
	var text := "%s  %s" % [label, Fighter.state_name(f.state)]
	draw_string(font, Vector2(body.position.x - 20, body.position.y - 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


func _push_rect(f: Fighter) -> Rect2:
	var left := SimConst.px(f.push_left())
	var w := SimConst.px(f.def.push_half_width * 2)
	var h := SimConst.px(f.push_height())
	var bottom := -SimConst.px(f.y)
	return Rect2(left, bottom - h, w, h)
