class_name HudView
extends Control
## 对战 HUD：体力条、Drive 槽、超杀槽、计时、回合胜场、回合提示、超杀暂停压暗。
## 只读取 MatchSim。

const BAR_W := 500.0
const BAR_H := 22.0
const TOP := 18.0
const MARGIN := 40.0
const C_FRAME := Color(0.08, 0.08, 0.1, 0.85)
const C_HEALTH := Color(0.95, 0.8, 0.25)
const C_HEALTH_LOW := Color(0.95, 0.3, 0.25)
const C_DRIVE := Color(0.35, 0.95, 0.55)
const C_BURNOUT := Color(0.45, 0.45, 0.45)
const C_SUPER := Color(0.3, 0.65, 1.0)
const C_TEXT := Color(1, 1, 1)

var sim: MatchSim


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var font := ThemeDB.fallback_font
	var w := size.x
	if sim.freeze > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	for i in 2:
		_draw_side(i, sim.fighters[i], w, font)
	var timer_text := "∞" if not sim.versus else str(ceili(sim.round_timer / float(SimConst.FPS)))
	draw_string(font, Vector2(w / 2 - 40, TOP + 30), timer_text, HORIZONTAL_ALIGNMENT_CENTER, 80, 34, C_TEXT)
	var banner := _banner()
	if banner != "":
		draw_string_outline(font, Vector2(0, size.y * 0.42), banner, HORIZONTAL_ALIGNMENT_CENTER, w, 64, 10, Color.BLACK)
		draw_string(font, Vector2(0, size.y * 0.42), banner, HORIZONTAL_ALIGNMENT_CENTER, w, 64, C_TEXT)


## 一侧的全部计量条。体力条固定在外侧，受伤时从靠中间的一端减少；P2 镜像。
func _draw_side(i: int, f: Fighter, w: float, font: Font) -> void:
	var left := i == 0
	var x0 := MARGIN if left else w - MARGIN - BAR_W
	# 体力
	var ratio := float(f.health) / f.def.max_health
	draw_rect(Rect2(x0 - 3, TOP - 3, BAR_W + 6, BAR_H + 6), C_FRAME)
	var hw := BAR_W * ratio
	var hx := x0 + (0.0 if left else BAR_W - hw)
	draw_rect(Rect2(hx, TOP, hw, BAR_H), C_HEALTH if ratio > 0.25 else C_HEALTH_LOW)
	draw_string(font, Vector2(x0, TOP + BAR_H + 20), f.def.display_name, HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT, BAR_W, 18, C_TEXT)
	# Drive：6 格，从中间往外排
	var drive_def: Dictionary = Gauges.DEFS[Gauges.DRIVE]
	_segments(x0 + (BAR_W * 0.4 if left else 0.0), TOP + BAR_H + 30, BAR_W * 0.6, 10.0, f.gauges[Gauges.DRIVE],
		drive_def.max, drive_def.segments, C_BURNOUT if f.burnout != 0 else C_DRIVE, not left)
	if f.burnout != 0:
		draw_string(font, Vector2(x0, TOP + BAR_H + 60), "BURNOUT", HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT, BAR_W, 16, C_HEALTH_LOW)
	# 超杀槽：底部
	var super_def: Dictionary = Gauges.DEFS[Gauges.SUPER]
	var sy := size.y - 36.0
	var sw := 300.0
	var sx := MARGIN if left else w - MARGIN - sw
	_segments(sx, sy, sw, 14.0, f.gauges[Gauges.SUPER], super_def.max, super_def.segments, C_SUPER, left)
	var stocks: int = f.gauges[Gauges.SUPER] / (super_def.max / super_def.segments)
	draw_string(font, Vector2(sx + (sw + 10 if left else -40), sy + 14), str(stocks), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, C_SUPER)
	# 回合胜场
	if sim.versus:
		for k in MatchSim.WINS_NEEDED:
			var cx := (x0 + BAR_W - 12 - k * 22) if left else (x0 + 12 + k * 22)
			var c := Vector2(cx, TOP + BAR_H + 50)
			draw_circle(c, 7, C_FRAME)
			if k < sim.wins[i]:
				draw_circle(c, 5, C_HEALTH)


## 分格计量条。from_left = 从左往右填充。
func _segments(x: float, y: float, w: float, h: float, value: int, max_value: int, count: int,
		color: Color, from_left: bool) -> void:
	var seg_w := w / count
	var per := max_value / count
	draw_rect(Rect2(x - 2, y - 2, w + 4, h + 4), C_FRAME)
	for k in count:
		var fill := clampf(float(value - k * per) / per, 0.0, 1.0)
		if fill <= 0.0:
			continue
		var idx := k if from_left else count - 1 - k
		var sx := x + idx * seg_w
		var fw := (seg_w - 2) * fill
		var c := color if fill >= 1.0 else color.darkened(0.45)
		draw_rect(Rect2(sx + (0.0 if from_left else seg_w - 2 - fw), y, fw, h), c)


func _banner() -> String:
	if not sim.versus:
		return ""
	match sim.round_state:
		MatchSim.Round.INTRO:
			return "ROUND %d" % sim.round_number if sim.round_frame < MatchSim.INTRO_FRAMES - 25 else "FIGHT!"
		MatchSim.Round.END:
			if sim.round_frame < 70:
				return "TIME" if sim.round_timer <= 0 else "K.O."
			var winner := sim.round_winner()
			return "DRAW" if winner < 0 else "P%d WINS" % (winner + 1)
		MatchSim.Round.MATCH_OVER:
			var w := 0 if sim.wins[0] > sim.wins[1] else (1 if sim.wins[1] > sim.wins[0] else -1)
			return "DRAW GAME" if w < 0 else "P%d WINS THE MATCH" % (w + 1)
	return ""
