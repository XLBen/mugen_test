extends SceneTree
## 逐帧截图自查：用脚本输入推进训练场景，从第 from 帧起每 step 帧截一次画面中部，拼成一张网格图。
## godot --path . -s res://tools/filmstrip.gd -- <out.png> <p1 输入序列> [p2 输入序列] [from] [count] [step] [p1 角色号] [p2 角色号]
## 输入序列格式见 tools/input_script.gd；角色号是训练场景 roster 的下标（F8/F9 的顺序）。

const COLS := 6
const CROP := Vector2i(560, 420) ## 截取的区域（视口像素，以两名角色中点为中心）

var _scene: Node
var _frames: Array = [[], []]
var _out := ""
var _from := 0
var _count := 12
var _step := 2
var _tick := 0
var _done := 0
var _shots: Array[Image] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	for p in 2:
		if args.size() > p + 1:
			_frames[p] = InputScript.parse(args[p + 1], p == 1)
	_from = int(args[3]) if args.size() > 3 else 0
	_count = int(args[4]) if args.size() > 4 else _count
	_step = int(args[5]) if args.size() > 5 else _step
	_scene = load("res://scenes/training.tscn").instantiate()
	root.add_child(_scene)
	if args.size() > 6:
		_scene.set_meta("picks", [int(args[6]), int(args[7]) if args.size() > 7 else 1])


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick == 2:
		_scene.paused = true
		_scene.dummy.mode = TrainingDummy.Mode.PLAYER
		_scene.view.show_boxes = false
		if _scene.has_meta("picks"):
			var picks: Array = _scene.get_meta("picks")
			for p in 2:
				_scene.picks[p] = picks[p] - 1
				_scene._cycle_character(p)
		for i in _from:
			_advance(i)
		return false
	if _tick < 3:
		return false
	# 每个渲染帧截一张，然后推进 step 帧
	if _tick > 3:
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var scale := img.get_width() / 1280.0
		var size := Vector2i(Vector2(CROP) * scale)
		var center := Vector2i(img.get_width() / 2, int(img.get_height() * 0.62))
		var shot := img.get_region(Rect2i(center - size / 2, size))
		shot.resize(CROP.x / 2, CROP.y / 2)
		_shots.append(shot)
		_done += 1
		if _done >= _count:
			_save()
			return true
	for k in _step:
		_advance(_from + _done * _step + k)
	return false


func _advance(i: int) -> void:
	var inputs: Array[int] = [_at(0, i), _at(1, i)]
	_scene.advance(inputs)


func _at(p: int, i: int) -> int:
	return _frames[p][i] if i < _frames[p].size() else 0


func _save() -> void:
	var w := CROP.x / 2
	var h := CROP.y / 2
	var rows := ceili(_shots.size() / float(COLS))
	var sheet := Image.create(w * COLS, h * rows, false, Image.FORMAT_RGBA8)
	for i in _shots.size():
		sheet.blit_rect(_shots[i], Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i((i % COLS) * w, (i / COLS) * h))
	sheet.save_png(_out)
	print("saved ", _out)
