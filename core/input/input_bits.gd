class_name InputBits
## 一帧输入编码为一个 int 位掩码。方向存"绝对方向"（屏幕左/右），
## 解释为前/后时再按角色朝向翻转。按键为抽象槽位 B0..B5，由规则模块决定含义。

const UP := 1 << 0
const DOWN := 1 << 1
const LEFT := 1 << 2
const RIGHT := 1 << 3
const B0 := 1 << 4
const B1 := 1 << 5
const B2 := 1 << 6
const B3 := 1 << 7
const B4 := 1 << 8
const B5 := 1 << 9

const DIRECTIONS := UP | DOWN | LEFT | RIGHT
const BUTTONS := B0 | B1 | B2 | B3 | B4 | B5


## SOCD 清理：左+右 = 中立，上+下 = 上。所有输入源都要先经过这里。
static func clean_socd(bits: int) -> int:
	if bits & LEFT and bits & RIGHT:
		bits &= ~(LEFT | RIGHT)
	if bits & UP and bits & DOWN:
		bits &= ~DOWN
	return bits


## 转成小键盘记法（1-9，5 为中立），facing = 1 表示面朝右。
static func to_numpad(bits: int, facing: int) -> int:
	var h := 0
	if bits & RIGHT:
		h = 1
	elif bits & LEFT:
		h = -1
	h *= facing
	var v := 0
	if bits & UP:
		v = 1
	elif bits & DOWN:
		v = -1
	return 5 + h + v * 3


static func is_up(numpad: int) -> bool:
	return numpad >= 7


static func is_down(numpad: int) -> bool:
	return numpad <= 3


## -1 = 后，0 = 中，1 = 前
static func horizontal(numpad: int) -> int:
	return (numpad - 1) % 3 - 1
