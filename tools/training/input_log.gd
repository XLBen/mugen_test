class_name InputLog
extends RefCounted
## 输入历史（训练模式显示用）：相同输入合并为一条并计帧数，最新的在前。

const MAX_ENTRIES := 18

var entries: Array = [] ## [[bits, frames], ...]，0 号是最新


func record(bits: int) -> void:
	if not entries.is_empty() and entries[0][0] == bits:
		entries[0][1] += 1
		return
	entries.push_front([bits, 1])
	if entries.size() > MAX_ENTRIES:
		entries.pop_back()


## 一条记录的显示文本：小键盘方向（按面朝右）+ 按键名。
static func describe(bits: int, facing: int) -> String:
	var text := str(InputBits.to_numpad(bits, facing))
	var names := ["LP", "MP", "HP", "LK", "MK", "HK"]
	for i in names.size():
		if bits & (InputBits.B0 << i):
			text += " " + names[i]
	return text
