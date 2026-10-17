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
const EMBED_HINT := "Running inside the editor's Game tab: its size is set by the editor. For a full-size window, turn off \"Embed Game on Next Play\" in the Game tab, then run again."

var sim: MatchSim
var meter: FrameMeter
var dummy: TrainingDummy
var logs: Array = [] ## [InputLog, InputLog]
var trial: ComboTrial


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var font := ThemeDB.fallback_font
	if Engine.is_embedded_in_editor():
		draw_string(font, Vector2(0, 150), EMBED_HINT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(1, 0.85, 0.3))
	if sim.versus:
		return
	_draw_meter(font)
	_draw_logs(font)
	_draw_trial(font)
	var status := "[F8] P1 char  [F9] P2 char   dummy: %s   guard: %s   [1] mode  [2] guard  [3] record/playback  [4] combo trial  [Shift+F6] corner  [F12] debug  [Alt+Enter] fullscreen" % [
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


## 连段挑战：标题、连段写法（已完成的步骤高亮）、成功提示。
func _draw_trial(font: Font) -> void:
	if trial == null or not trial.enabled:
		return
	var c := trial.current()
	var y := 128.0
	if c.is_empty():
		draw_string(font, Vector2(0, y), "No combos for this character", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color.WHITE)
		return
	var title := "COMBO TRIAL %d/%d   %s%s   [5] next  [Shift+5] prev  [4] close" % [trial.index + 1, trial.combos.size(),
		c.name, "  (cleared)" if trial.cleared.has(trial.index) else ""]
	draw_rect(Rect2(size.x / 2 - 330, y - 18, 660, 64), Color(0, 0, 0, 0.55))
	draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(1, 0.85, 0.3))
	var parts := ComboTrial.notation_parts(c)
	var widths := []
	var total := 0.0
	for p in parts:
		var w := font.get_string_size(p + "   ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		widths.append(w)
		total += w
	var x := (size.x - total) / 2
	for k in parts.size():
		var done: bool = k < trial.step
		draw_string(font, Vector2(x, y + 28), parts[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			Color(0.4, 1, 0.5) if done else Color.WHITE)
		x += widths[k]
	var notes := PackedStringArray()
	if c.has("p2"):
		notes.append("starts on a counter-hit (record the dummy attacking with [3])")
	if c.get("meter", false):
		notes.append("needs 1 super bar ([F11] infinite meter)")
	if not notes.is_empty():
		draw_string(font, Vector2(0, y + 44), "  /  ".join(notes), HORIZONTAL_ALIGNMENT_CENTER, size.x, 12,
			Color(1, 1, 1, 0.7))
	if trial.success_timer > 0:
		draw_string(font, Vector2(0, y + 80), "SUCCESS!", HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color(0.4, 1, 0.5))
