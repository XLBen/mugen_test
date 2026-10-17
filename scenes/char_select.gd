extends Control
## 选人画面。双人对战：两名玩家各自用自己的键移动光标、确定（P1 WASD + U，P2 方向键 + 小键盘 7 或 ;）。
## 对战电脑 / 训练：一个光标先选自己、再选对手（对战电脑最后用左右选电脑等级）。返回键退回上一步，第一步退回标题。

const CELL := Vector2(150, 190)
const GAP := 18.0
const PORTRAIT_H := 132.0 ## 角色在格子里的身高（像素）
const C_P := [Color(0.35, 0.6, 1.0), Color(1.0, 0.4, 0.35)]

var roster: Array[FighterDef] = []
var cursor: Array[int] = [0, 1]
var locked: Array[bool] = [false, false]
var step := 0 ## 单光标模式：0 选自己 / 1 选对手 / 2 选电脑等级
var _portraits: Array = [] ## 每个角色的待机第一帧 [Texture2D, scale, anchor] 或 null


func _enter_tree() -> void:
	UiFont.setup()


func _ready() -> void:
	LocalInput.register_actions()
	roster = Roster.load_all()
	cursor = [0, mini(1, roster.size() - 1)]
	for def in roster:
		var s := SpriteSet.load_from(def.sprite_dir, 0) if def.sprite_dir != "" else null
		_portraits.append(null if s == null or not s.has("idle") else [s.frame_index("idle", 0), s.scale, s.anchor])


func single() -> bool:
	return Session.mode != Session.Mode.VS_2P


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if single():
		_single_input(event)
	else:
		_versus_input(event)


func _single_input(event: InputEvent) -> void:
	var h := MenuInput.horizontal(event)
	if MenuInput.back(event):
		if step == 0:
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		else:
			step -= 1
		return
	if step == 2:
		if h != 0:
			Session.cpu_level = clampi(Session.cpu_level + h, 1, Session.CPU_LEVELS)
		elif MenuInput.confirm(event):
			start()
		return
	if h != 0:
		cursor[step] = posmod(cursor[step] + h, roster.size())
	elif MenuInput.confirm(event):
		step += 1
		if step == 2 and Session.mode != Session.Mode.VS_CPU:
			start()


func _versus_input(event: InputEvent) -> void:
	var p := MenuInput.player(event)
	var players := [p] if p >= 0 else [0, 1]
	for i: int in players:
		var h := MenuInput.horizontal(event)
		if MenuInput.back(event):
			if locked[i]:
				locked[i] = false
			elif not locked[0] and not locked[1]:
				get_tree().change_scene_to_file("res://scenes/title.tscn")
			return
		if locked[i]:
			continue
		if h != 0:
			cursor[i] = posmod(cursor[i] + h, roster.size())
		elif MenuInput.confirm(event):
			locked[i] = true
		if p < 0:
			break # 通用键只给第一个没锁定的玩家用
	if locked[0] and locked[1]:
		start()


func start() -> void:
	Session.picks = [cursor[0], cursor[1]]
	Session.from_menu = true
	get_tree().change_scene_to_file("res://scenes/training.tscn")


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := size.x
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.05, 0.1))
	draw_string(font, Vector2(0, 70), "选择角色 · " + Session.MODE_NAMES[Session.mode], HORIZONTAL_ALIGNMENT_CENTER, w, 40,
		Color.WHITE)
	var total := roster.size() * CELL.x + (roster.size() - 1) * GAP
	var x0 := (w - total) / 2.0
	var y0 := size.y * 0.3
	for k in roster.size():
		var r := Rect2(Vector2(x0 + k * (CELL.x + GAP), y0), CELL)
		draw_rect(r, Color(0.12, 0.12, 0.18))
		_draw_portrait(k, r)
		draw_string(font, Vector2(r.position.x, r.end.y + 26), roster[k].display_name, HORIZONTAL_ALIGNMENT_CENTER,
			CELL.x, 20, Color(0.9, 0.9, 0.95))
		for i in 2:
			if cursor[i] == k and _cursor_visible(i):
				var g := 4.0 + i * 6.0
				draw_rect(r.grow(g), C_P[i], false, 4.0)
				draw_string(font, Vector2(r.position.x + (0 if i == 0 else CELL.x - 40), r.position.y - 10 - i * 0),
					"P%d" % (i + 1) if not (single() and i == 1) else ("CPU" if Session.mode == Session.Mode.VS_CPU else "P2"),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 18, C_P[i])
	draw_string(font, Vector2(0, size.y - 110), _status(), HORIZONTAL_ALIGNMENT_CENTER, w, 26, Color(1.0, 0.85, 0.3))
	draw_string(font, Vector2(0, size.y - 40), "A / D 或 ← / → 选择    U / Enter 确定    J / Esc 返回",
		HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(0.6, 0.6, 0.7))


func _cursor_visible(i: int) -> bool:
	return not single() or i <= step


func _status() -> String:
	if not single():
		return "P1 %s    P2 %s" % ["已确定" if locked[0] else "选择中", "已确定" if locked[1] else "选择中"]
	match step:
		0:
			return "选择你的角色"
		1:
			return "选择对手"
	return "电脑等级  ◀ %d ▶" % Session.cpu_level


func _draw_portrait(k: int, r: Rect2) -> void:
	var p = _portraits[k]
	if p == null:
		return
	var tex: Texture2D = p[0]
	# 按角色身高缩放（画布大小因人而异），让每个人在格子里差不多高
	var scale: float = p[1] * PORTRAIT_H / maxf(SimConst.px(roster[k].stand_height), 1.0)
	var feet := Vector2(r.get_center().x, r.end.y - 8)
	draw_set_transform(feet, 0.0, Vector2(scale, scale))
	draw_texture(tex, -p[2])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
