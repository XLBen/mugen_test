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
const EMBED_HINT := "正在编辑器的 Game 面板里内嵌运行，画面大小由编辑器决定。要大窗口请在 Game 面板关闭 “Embed Game on Next Play” 后重新运行。"

var sim: MatchSim
var meter: FrameMeter
var dummy: TrainingDummy
var logs: Array = [] ## [InputLog, InputLog]
var trial: ComboTrial
var demo: ComboDemo
var debug_visible := false ## 调试面板打开时，连段挑战往下挪


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var font := ThemeDB.fallback_font
	if Engine.is_embedded_in_editor():
		draw_string(font, Vector2(0, 118), EMBED_HINT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(1, 0.85, 0.3))
	if sim.versus:
		return
	_draw_meter(font)
	_draw_logs(font)
	_draw_trial(font)
	var status := "假人：%s    自动防御：%s        [1] 假人模式    [2] 自动防御    [3] 录制 / 回放    [4] 连段挑战    [6] 判定框    [7] 演示连段" % [
		UiText.DUMMY_MODES[dummy.mode], UiText.DUMMY_GUARD[dummy.guard]]
	if dummy.mode == TrainingDummy.Mode.RECORD:
		status += "    ● 录制 %d 帧" % dummy.recording.size()
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
			parts.append("P%d %s  发生 %d  全体 %d" % [i + 1, UiText.state(meter.move_name[i]), meter.startup[i], meter.total[i]])
	if meter.has_advantage:
		parts.append("有利帧  P1 %+d" % meter.advantage)
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
	var y := 290.0 if debug_visible else 140.0
	if c.is_empty():
		draw_string(font, Vector2(0, y), "这个角色还没有设计连段", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color.WHITE)
		return
	var title := "连段挑战 %d / %d    %s%s        [5] 下一条    [Shift+5] 上一条    [7] 演示    [4] 关闭" % [
		trial.index + 1, trial.combos.size(), c.name, "（已完成）" if trial.cleared.has(trial.index) else ""]
	if demo != null and demo.playing:
		title = "电脑演示中%s    %s        [7] 停止" % [
			" %d / %d" % [demo.position(), demo.total] if demo.total > 1 else "", c.name]
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
		notes.append("需要打康起手：先用 [3] 录一段假人出招再回放")
	if c.has("p2_recovery"):
		notes.append("确反：在对手出招的收招中打中（[7] 演示会自动布置）")
	if c.get("meter", false):
		notes.append("需要 1 格超杀槽")
	if not notes.is_empty():
		draw_string(font, Vector2(0, y + 44), "  /  ".join(notes), HORIZONTAL_ALIGNMENT_CENTER, size.x, 12,
			Color(1, 1, 1, 0.7))
	if trial.success_timer > 0:
		draw_string(font, Vector2(0, y + 80), "成功！", HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color(0.4, 1, 0.5))
