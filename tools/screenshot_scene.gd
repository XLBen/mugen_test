extends SceneTree
## 截取任意场景的画面（检查标题、选人等界面）：
## godot --path . -s res://tools/screenshot_scene.gd -- <场景路径> <out.png> [Session.mode]
var _n := 0
var _out := ""
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[1]
	if args.size() > 2:
		Session.mode = int(args[2])
	root.add_child(load(args[0]).instantiate())
func _process(_d: float) -> bool:
	_n += 1
	if _n == 10:
		var img := root.get_texture().get_image()
		img.resize(960, 540)
		img.save_png(_out)
		return true
	return false
