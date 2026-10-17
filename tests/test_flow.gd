extends TestCase
## 游戏流程：标题 → 选人 → 对局（训练 / 对战），暂停与结算菜单。


func after() -> void:
	Session.reset()


func test_roster_always_has_fighters() -> void:
	var r := Roster.load_all()
	check(r.size() >= 2, "at least two fighters to pick")
	if Roster.local_fighters().is_empty():
		check_eq(r.size(), Roster.BUILTIN.size(), "falls back to the built-in roster")


func test_menu_navigation_wraps() -> void:
	check_eq(MenuPanel.move(0, -1, 4), 3, "up from the first item goes to the last")
	check_eq(MenuPanel.move(3, 1, 4), 0, "down from the last goes to the first")


func test_menu_input_keys() -> void:
	var down := InputEventKey.new()
	down.pressed = true
	down.physical_keycode = KEY_S
	check_eq(MenuInput.vertical(down), 1, "S moves down")
	check_eq(MenuInput.player(down), 0, "WASD belongs to P1")
	var p2 := InputEventKey.new()
	p2.pressed = true
	p2.physical_keycode = KEY_SEMICOLON
	check(MenuInput.confirm(p2) and MenuInput.player(p2) == 1, "P2's alternate LP key confirms")
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.physical_keycode = KEY_ESCAPE
	check(MenuInput.pause(esc) and MenuInput.back(esc), "Esc pauses / goes back")


## 各场景能实例化；从选人进入时按 Session 开局。
func test_scenes_and_session_setup() -> void:
	for path in ["res://scenes/title.tscn", "res://scenes/char_select.tscn", "res://scenes/training.tscn"]:
		var n: Node = load(path).instantiate()
		check(n != null, path + " instantiates")
		n.free()
	var training: GDScript = load("res://scenes/training.gd")
	Session.reset()
	var setup: Array = training.session_setup(3)
	check_eq(setup[1], false, "run directly: training mode")
	Session.mode = Session.Mode.VS_CPU
	Session.from_menu = true
	Session.picks = [2, 9]
	setup = training.session_setup(3)
	check(setup[1], "versus CPU from the menu")
	check_eq(setup[0], [2, 2], "picks come from the menu (clamped)")
	Session.reset()
