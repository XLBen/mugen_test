class_name InputScript
## 文本输入序列 → 每帧 InputBits，供测试和截图工具使用。
## 格式："6x30,2,3,6LP,5x10,5LP+LK"
##   每段 = 小键盘方向（按面朝右解释）+ 可选按键（用 + 连接多个）+ 可选 "x帧数"（默认 1 帧）
## mirror = true 时左右翻转（给面朝左的 P2 写"前/后"更直观）。

const BUTTONS := {"LP": InputBits.B0, "MP": InputBits.B1, "HP": InputBits.B2,
	"LK": InputBits.B3, "MK": InputBits.B4, "HK": InputBits.B5}


static func parse(text: String, mirror := false) -> Array[int]:
	var out: Array[int] = []
	for token in text.split(",", false):
		var parts := token.strip_edges().split("x")
		var spec := parts[0]
		var count := int(parts[1]) if parts.size() > 1 else 1
		var bits := dir_bits(int(spec.substr(0, 1)), mirror)
		for b in spec.substr(1).split("+", false):
			bits |= BUTTONS[b]
		for i in count:
			out.append(bits)
	return out


static func dir_bits(numpad: int, mirror := false) -> int:
	var bits := 0
	if numpad >= 7:
		bits |= InputBits.UP
	elif numpad <= 3:
		bits |= InputBits.DOWN
	var h := (numpad - 1) % 3 - 1
	if mirror:
		h = -h
	if h < 0:
		bits |= InputBits.LEFT
	elif h > 0:
		bits |= InputBits.RIGHT
	return bits
