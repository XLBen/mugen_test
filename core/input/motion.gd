class_name Motion
extends RefCounted
## 声明式指令识别：从结束帧向前搜索每一步方向，相邻两步间隔不超过 max_gap。
## 方向按角色"当前"朝向解释（小键盘记法）。一个指令可以有多种写法（捷径）。

const PRESETS := {
	"236": [["2", "3", "6"]],
	"214": [["2", "1", "4"]],
	"623": [["6", "12", "3"], ["6", "3", "2", "3"], ["3", "2", "3"]],
	"421": [["4", "2", "1"]],
	"236236": [["2", "3", "6", "2", "3", "6"]],
	"214214": [["2", "1", "4", "2", "1", "4"]],
	"66": [["6", "124578", "6"]],
	"44": [["4", "235689", "4"]],
}

var patterns: Array = [] ## Array[Array[int]]，每步是允许的小键盘方向的位掩码
var max_gap := 8 ## 相邻两步之间允许的最大帧数
var final_gap := 4 ## 最后一个方向到结束帧（按键帧）之间允许的最大帧数
var window := 30 ## 整个指令必须在多少帧内完成
var fresh_end := false ## 无按键指令（冲刺）：最后一步必须是刚刚输入的


static func preset(motion_name: String) -> Motion:
	var m := Motion.new()
	for pattern: Array in PRESETS[motion_name]:
		var steps: Array[int] = []
		for step: String in pattern:
			var mask := 0
			for ch in step:
				mask |= 1 << int(ch)
			steps.append(mask)
		m.patterns.append(steps)
	if motion_name in ["66", "44"]:
		m.max_gap = 6
		m.final_gap = 0
		m.window = 14
		m.fresh_end = true
	elif motion_name.length() >= 6:
		m.window = 45
	return m


func matches(f: Fighter, end_frame: int) -> bool:
	if fresh_end:
		var last: Array = patterns[0]
		if last[-1] & (1 << f.numpad_at(end_frame - 1)):
			return false
	for pattern: Array in patterns:
		if _match(pattern, f, end_frame):
			return true
	return false


func _match(pattern: Array, f: Fighter, end_frame: int) -> bool:
	var t := end_frame
	var earliest := end_frame - window
	for i in range(pattern.size() - 1, -1, -1):
		var gap := final_gap if i == pattern.size() - 1 else max_gap
		var limit := maxi(t - gap, earliest)
		var found := -1
		var tt := t
		while tt >= limit:
			if pattern[i] & (1 << f.numpad_at(tt)):
				found = tt
				break
			tt -= 1
		if found < 0:
			return false
		t = found - 1
	return true
