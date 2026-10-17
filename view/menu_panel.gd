class_name MenuPanel
extends Control
## 竖排菜单（暂停、结算用）：压暗背景、标题、选项。场景把输入事件转给 handle()，选中后发 chosen 信号。

signal chosen(index: int)
signal cancelled

const C_DIM := Color(0, 0, 0, 0.55)
const C_ITEM := Color(0.85, 0.85, 0.9)
const C_PICK := Color(1.0, 0.85, 0.3)

var title := ""
var items := PackedStringArray()
var index := 0
var cancel_closes := true ## 按返回键关闭（暂停菜单）；结算菜单不能关


func open(title_: String, items_: PackedStringArray, cancel_closes_ := true) -> void:
	title = title_
	items = items_
	index = 0
	cancel_closes = cancel_closes_
	visible = true
	queue_redraw()


## 处理一个输入事件；返回 true 表示菜单用掉了它。
func handle(event: InputEvent) -> bool:
	if not visible:
		return false
	var d := MenuInput.vertical(event)
	if d != 0:
		index = move(index, d, items.size())
		queue_redraw()
		return true
	if MenuInput.confirm(event):
		visible = false
		chosen.emit(index)
		return true
	if MenuInput.back(event) and cancel_closes:
		visible = false
		cancelled.emit()
		return true
	return MenuInput.key(event) >= 0


## 上下移动选中项（首尾相接）。
static func move(i: int, delta: int, count: int) -> int:
	return posmod(i + delta, maxi(count, 1))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), C_DIM)
	var top := size.y * 0.3
	draw_string_outline(font, Vector2(0, top), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, 8, Color.BLACK)
	draw_string(font, Vector2(0, top), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, Color.WHITE)
	for k in items.size():
		var y := top + 80.0 + k * 52.0
		var picked := k == index
		var text := ("▶  " + items[k] + "  ◀") if picked else items[k]
		draw_string_outline(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, 6, Color.BLACK)
		draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, C_PICK if picked else C_ITEM)
