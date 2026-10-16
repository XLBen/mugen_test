extends SceneTree
## 截图自查工具：加载训练场景，用脚本输入推进仿真，然后保存画面。
## godot --path . -s res://tools/screenshot.gd -- <out.png> [p1 输入序列] [p2 输入序列]
## 输入序列格式见 tools/input_script.gd；P2 的序列按面朝左书写（4 = 后退）。

var _scene: Node
var _frames: Array = [[], []]
var _out := ""
var _tick := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shot.png"
	for p in 2:
		if args.size() > p + 1:
			_frames[p] = InputScript.parse(args[p + 1], p == 1)
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
