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
	"41236": [["4", "1", "2", "3", "6"]],
	"63214": [["6", "3", "2", "1", "4"]],
	"360": [["369", "123", "147", "789"], ["123", "147", "789", "369"], ["147", "789", "369", "123"],
		["789", "369", "123", "147"], ["369", "789", "147", "123"], ["789", "147", "123", "369"],
		["147", "123", "369", "789"], ["123", "369", "789", "147"]],
	"214214": [["2", "1", "4", "2", "1", "4"]],
	"66": [["6", "124578", "6"]],
	"22": [["2", "456789", "2"]],
	"44": [["4", "235689", "4"]],
	# 蓄力：先按住 [方向] 至少 CHARGE_FRAMES 帧，松开后 CHARGE_RELEASE 帧内输入后一个方向（蓄力角色用）
	"[4]6": [["147", "369"]],
	"[2]8": [["123", "789"]],
}
const CHARGE_FRAMES := 40 ## 蓄力时间（未核实，SF6 多数蓄力招约 40 帧）
const CHARGE_RELEASE := 10 ## 蓄力方向松开后还能输入后续方向的帧数

var patterns: Array = [] ## Array[Array[int]]，每步是允许的小键盘方向的位掩码
var max_gap := 8 ## 相邻两步之间允许的最大帧数
var final_gap := 4 ## 最后一个方向到结束帧（按键帧）之间允许的最大帧数
var window := 11 ## 整个指令必须在多少帧内完成（SF6：1/4 圈 11 帧，半圈 12 帧，一圈 32 帧）
var fresh_end := false ## 无按键指令（冲刺）：最后一步必须是刚刚输入的
var charge := 0 ## >0：蓄力指令，第一步要连续按住这么多帧


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
	match motion_name:
		"66", "44", "22":
			m.max_gap = 6
			m.final_gap = 0
			m.window = 14
			m.fresh_end = true
		"41236", "63214":
			m.window = 12
		"360":
			m.window = 32
			m.max_gap = 12
		"236236", "214214":
			m.window = 24
	if motion_name.begins_with("["):
		m.charge = CHARGE_FRAMES
	return m


func matches(f: Fighter, end_frame: int) -> bool:
	if fresh_end:
		var last: Array = patterns[0]
		if last[-1] & (1 << f.numpad_at(end_frame - 1)):
			return false
	if charge > 0:
		return _match_charge(patterns[0], f, end_frame)
	for pattern: Array in patterns:
		if _match(pattern, f, end_frame):
			return true
	return false


## 蓄力指令：结束帧前 final_gap 帧内出现后一个方向，且在它之前 CHARGE_RELEASE 帧内，蓄力方向已经连续按住了 charge 帧。
func _match_charge(pattern: Array, f: Fighter, end_frame: int) -> bool:
	var hold: int = pattern[0]
	var release: int = pattern[1]
	for t in range(end_frame, end_frame - final_gap - 1, -1):
		if not release & (1 << f.numpad_at(t)):
			continue
		for r in range(t - 1, t - 1 - CHARGE_RELEASE, -1):
			if _held(f, r, hold) >= charge:
				return true
	return false


func _held(f: Fighter, until: int, mask: int) -> int:
	var n := 0
	while n < charge and mask & (1 << f.numpad_at(until - n)):
		n += 1
	return n


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
