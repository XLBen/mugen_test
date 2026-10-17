class_name DebugPanel
extends Control
## 调试信息面板：上面一行是对局信息，下面是双方状态的对齐表格（每列固定位置，中英文混排也能对齐）。

const ROW_H := 20.0
const PAD := 10.0
const C_BG := Color(0, 0, 0, 0.6)
const C_HEAD := Color(1, 0.85, 0.3)
const C_TEXT := Color(1, 1, 1, 0.92)
const C_DIM := Color(1, 1, 1, 0.55)
const P_COLORS := [Color(0.5, 0.75, 1.0), Color(1.0, 0.55, 0.5)]
## [标题, 列宽]
const COLUMNS := [["玩家", 44], ["角色", 76], ["体力", 58], ["超杀槽", 64], ["Drive", 76], ["状态", 104], ["帧", 40],
	["位置 X", 72], ["高度", 56], ["速度 X", 64], ["速度 Y", 64], ["硬直", 48], ["顿帧", 48], ["输入", 44]]

var sim: MatchSim
var paused := false
var saved_frame := -1 ## -1 = 没有存档


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var font := ThemeDB.fallback_font
	var width := 0.0
	for c: Array in COLUMNS:
		width += c[1]
	var origin := Vector2((size.x - width) / 2, 0)
	draw_rect(Rect2(origin - Vector2(PAD, PAD), Vector2(width + PAD * 2, ROW_H * 5 + PAD * 2)), C_BG)

	var info := PackedStringArray([
		"第 %d 帧" % sim.frame,
		"状态哈希 %08x" % sim.state_hash(),
		"镜头 %d 像素" % int(SimConst.px(sim.camera_x)),
		"模式：%s" % ("对战" if sim.versus else "训练"),
		"资源常满：%s" % ("开" if sim.infinite_meter else "关"),
		"存档：%s" % ("第 %d 帧" % saved_frame if saved_frame >= 0 else "无"),
	])
	if paused:
		info.append("已暂停")
	draw_string(font, origin + Vector2(0, ROW_H - 5), "    ".join(info), HORIZONTAL_ALIGNMENT_LEFT, width, 14, C_TEXT)

	var y := origin.y + ROW_H * 2
	var x := origin.x
	for c: Array in COLUMNS:
		draw_string(font, Vector2(x, y - 5), c[0], HORIZONTAL_ALIGNMENT_LEFT, c[1], 13, C_HEAD)
		x += c[1]
	draw_line(Vector2(origin.x, y), Vector2(origin.x + width, y), C_DIM, 1.0)
	for i in sim.fighters.size():
		_draw_row(font, origin.x, y + ROW_H * (i + 1), i, sim.fighters[i])
	var controls := "P1：WASD 移动  U I O 拳  J K L 脚        P2：方向键移动  小键盘 7 8 9 拳  4 5 6 脚"
	draw_string(font, Vector2(origin.x, y + ROW_H * 3 + 4), controls, HORIZONTAL_ALIGNMENT_LEFT, width, 13, C_DIM)


func _draw_row(font: Font, x: float, y: float, i: int, f: Fighter) -> void:
	var drive := str(f.gauges[Gauges.DRIVE]) if f.burnout == 0 else "Burnout"
	var cells := ["P%d" % (i + 1), f.def.display_name, str(f.health), str(f.gauges[Gauges.SUPER]), drive,
		UiText.state(f.state_name()), str(f.state_frame), "%.1f" % SimConst.px(f.x), "%.1f" % SimConst.px(f.y),
		str(f.vx), str(f.vy), str(f.stun), str(f.hitstop), str(f.numpad_at(sim.frame))]
	for k in cells.size():
		var w: float = COLUMNS[k][1]
		var color: Color = P_COLORS[i] if k == 0 else C_TEXT
		draw_string(font, Vector2(x, y - 5), cells[k], HORIZONTAL_ALIGNMENT_LEFT, w - 6, 14, color)
		x += w
