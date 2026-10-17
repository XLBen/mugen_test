extends Control
## 标题画面：对战电脑 / 双人对战 / 训练模式 / 退出。

const ITEMS := ["对战电脑", "双人对战", "训练模式", "退出"]
const MODES := [Session.Mode.VS_CPU, Session.Mode.VS_2P, Session.Mode.TRAINING]
const HINT := "W / S 或 ↑ / ↓ 选择    U / Enter 确定"

var index := 0
var _t := 0.0


func _enter_tree() -> void:
	UiFont.setup()


func _ready() -> void:
	LocalInput.register_actions()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var d := MenuInput.vertical(event)
	if d != 0:
		index = MenuPanel.move(index, d, ITEMS.size())
	elif MenuInput.confirm(event):
		choose(index)


func choose(i: int) -> void:
	if i >= MODES.size():
		get_tree().quit()
		return
	Session.mode = MODES[i]
	get_tree().change_scene_to_file("res://scenes/char_select.tscn")


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := size.x
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.09))
	# 斜向扫过的光带
	for k in 6:
		var x := fposmod(_t * 120.0 + k * 260.0, w + 400.0) - 200.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 60, 0), Vector2(x - 140, size.y),
			Vector2(x - 200, size.y)]), Color(0.35, 0.2, 0.6, 0.08))
	var y := size.y * 0.32
	draw_string_outline(font, Vector2(0, y), "MUGENLIKE", HORIZONTAL_ALIGNMENT_CENTER, w, 96, 14, Color(0.1, 0.0, 0.2))
	draw_string(font, Vector2(0, y), "MUGENLIKE", HORIZONTAL_ALIGNMENT_CENTER, w, 96, Color(1.0, 0.85, 0.3))
	draw_string(font, Vector2(0, y + 44), "SF6 规则 · 2D 格斗基础框架", HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color(0.8, 0.8, 0.9))
	for k in ITEMS.size():
		var picked := k == index
		var text: String = ("▶  " + ITEMS[k] + "  ◀") if picked else ITEMS[k]
		var iy := size.y * 0.55 + k * 54.0
		draw_string_outline(font, Vector2(0, iy), text, HORIZONTAL_ALIGNMENT_CENTER, w, 34, 6, Color.BLACK)
		draw_string(font, Vector2(0, iy), text, HORIZONTAL_ALIGNMENT_CENTER, w, 34,
			Color(1.0, 0.85, 0.3) if picked else Color(0.85, 0.85, 0.9))
	draw_string(font, Vector2(0, size.y - 30), HINT, HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(0.6, 0.6, 0.7))
