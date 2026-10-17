class_name TrainingOverlay
extends Control
## 训练模式叠加层：帧计量条、有利帧、输入历史、假人设置。只在训练模式显示。

const CELL := 10.0
const CELL_H := 12.0
const CAT_COLORS := {
	FrameMeter.Cat.IDLE: Color(0.22, 0.22, 0.26),
	FrameMeter.Cat.MOVE: Color(0.45, 0.7, 0.95),
	FrameMeter.Cat.STARTUP: Color(0.3, 0.85, 0.45),
	FrameMeter.Cat.ACTIVE: Color(0.95, 0.3, 0.3),
	FrameMeter.Cat.RECOVERY: Color(0.3, 0.45, 0.95),
	FrameMeter.Cat.STUN: Color(0.95, 0.85, 0.3),
	FrameMeter.Cat.DOWN: Color(0.65, 0.45, 0.9),
}
const LOG_ROWS := 10

var sim: MatchSim
var meter: FrameMeter
var dummy: TrainingDummy
var logs: Array = [] ## [InputLog, InputLog]


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null or sim.versus:
		return
	var font := ThemeDB.fallback_font
	_draw_meter(font)
	_draw_logs(font)
	var status := "[F8] P1 char  [F9] P2 char   dummy: %s   guard: %s   [1] mode  [2] guard  [3] record/playback  [Shift+F6] corner  [F12] debug  [Alt+Enter] fullscreen" % [
		TrainingDummy.MODE_NAMES[dummy.mode], TrainingDummy.GUARD_NAMES[dummy.guard]]
	if dummy.mode == TrainingDummy.Mode.RECORD:
		status += "   ● REC %d" % dummy.recording.size()
	draw_string(font, Vector2(0, size.y - 4), status, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(1, 1, 1, 0.85))


func _draw_meter(font: Font) -> void:
	var width := FrameMeter.WIDTH * CELL
	var x0 := (size.x - width) / 2
	var y0 := size.y - 74.0
	for i in 2:
		var row: Array = meter.rows[i]
		var y := y0 + i * (CELL_H + 3)
		draw_rect(Rect2(x0 - 2, y - 1, width + 4, CELL_H + 2), Color(0, 0, 0, 0.6))
		for k in row.size():
			draw_rect(Rect2(x0 + k * CELL, y, CELL - 1, CELL_H), CAT_COLORS[row[k]])
	var parts := PackedStringArray()
	for i in 2:
		if meter.move_name[i] != "":
			parts.append("P%d %s  startup %d  total %d" % [i + 1, meter.move_name[i], meter.startup[i], meter.total[i]])
	if meter.has_advantage:
		parts.append("advantage  P1 %+d" % meter.advantage)
	draw_string(font, Vector2(x0, y0 - 5), "    ".join(parts), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _draw_logs(font: Font) -> void:
	for i in 2:
		var log: InputLog = logs[i]
		var facing := sim.fighters[i].facing
		for k in mini(log.entries.size(), LOG_ROWS):
			var e: Array = log.entries[k]
			var text := "%3d  %s" % [e[1], InputLog.describe(e[0], facing)]
			var x := 12.0 if i == 0 else size.x - 140.0
			var a := 1.0 - k * 0.07
			draw_string(font, Vector2(x, 440 + k * 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, a))
