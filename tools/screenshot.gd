extends SceneTree
## 截图自查工具：加载训练场景，用脚本输入推进仿真，然后保存画面。
## godot --path . -s res://tools/screenshot.gd -- <out.png> [p1 输入序列] [p2 输入序列]
## 输入序列格式："6x30,9x1,5x20"（小键盘方向 x 帧数，按面朝右解释），可选按键后缀如 "5LPx3"。

const BUTTONS := {"LP": InputBits.B0, "MP": InputBits.B1, "HP": InputBits.B2,
	"LK": InputBits.B3, "MK": InputBits.B4, "HK": InputBits.B5}

var _scene: Node
var _frames: Array = [[], []]
var _out := ""
var _tick := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shot.png"
	for p in 2:
		if args.size() > p + 1:
			_frames[p] = _parse(args[p + 1])
	_scene = load("res://scenes/training.tscn").instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick == 2:
		_scene.paused = true
		var n := maxi(_frames[0].size(), _frames[1].size())
		for i in n:
			var inputs: Array[int] = [_at(0, i), _at(1, i)]
			_scene.sim.step(inputs)
	if _tick == 6:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		return true
	return false


func _at(p: int, i: int) -> int:
	return _frames[p][i] if i < _frames[p].size() else 0


func _parse(text: String) -> Array:
	var out := []
	for token in text.split(",", false):
		var parts := token.split("x")
		var spec := parts[0]
		var count := int(parts[1]) if parts.size() > 1 else 1
		var bits := _dir_bits(int(spec.substr(0, 1)))
		var button := spec.substr(1)
		if button != "":
			bits |= BUTTONS[button]
		for i in count:
			out.append(bits)
	return out


func _dir_bits(numpad: int) -> int:
	var bits := 0
	if numpad >= 7:
		bits |= InputBits.UP
	elif numpad <= 3:
		bits |= InputBits.DOWN
	match (numpad - 1) % 3:
		0:
			bits |= InputBits.LEFT
		2:
			bits |= InputBits.RIGHT
	return bits
