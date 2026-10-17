extends SceneTree
## 判定框对照表：把一个角色的各个状态（取攻击持续帧）连同判定框渲染成一张网格图，用来检查精灵与判定是否对得上。
## godot --path . -s res://tools/box_sheet.gd -- <out.png> <角色序号（见 training.gd ROSTER）>

const CELL := Vector2i(300, 330)
const COLS := 8

var _scene: Node
var _out := ""
var _roster := 0
var _states: Array[String] = []
var _index := -1
var _wait := 0
var _sheet: Image


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://boxes.png"
	_roster = int(args[1]) if args.size() > 1 else 0
	_scene = load("res://scenes/training.tscn").instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	if _index == -1:
		_setup()
		_index = 0
		_pose()
		return false
	_wait += 1
	if _wait < 3:
		return false
	_capture()
	_index += 1
	if _index >= _states.size():
		_sheet.save_png(_out)
		print("saved ", _out, " (", _states.size(), " states)")
		return true
	_pose()
	return false


func _setup() -> void:
	_scene.paused = true
	_scene.hud.visible = false
	var def: FighterDef = _scene.roster[_roster]
	_scene.sim.fighters[0].set_def(def)
	_scene.sim.reset()
	_scene.view.load_sprites()
	_scene.overlay.visible = false
	_scene.hud_view.visible = false
	for s: StateDef in _scene.sim.fighters[0].moveset.states:
		if s.name in ["thrown", "throw_tech", "ko", "landing_long", "dive_land"]:
			continue
		_states.append(s.name)
	var rows := ceili(_states.size() / float(COLS))
	_sheet = Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	_sheet.fill(Color(0.2, 0.2, 0.24))


## 把 P1 摆到状态的代表帧（攻击取第一个持续帧），P2 远远放开。
func _pose() -> void:
	_wait = 0
	var sim: MatchSim = _scene.sim
	var f := sim.fighters[0]
	var opp := sim.fighters[1]
	f.set_state(_states[_index])
	var s := f.sd()
	f.state_frame = maxi(s.first_active, 0)
	f.fresh = 0
	f.x = 0
	f.y = 0
	f.facing = 1
	if s.type == "A" or s.name == "hit_air":
		f.y = 9000
	opp.x = 100000
	sim.camera_x = 0


func _capture() -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	# 角色脚底在屏幕中央、地面线附近
	var center := Vector2i(img.get_width() / 2, int(img.get_height() * 0.86))
	var src := Rect2i(center.x - CELL.x / 2, center.y - CELL.y + 20, CELL.x, CELL.y)
	var col := _index % COLS
	var row := _index / COLS
	_sheet.blit_rect(img, src, Vector2i(col * CELL.x, row * CELL.y))
