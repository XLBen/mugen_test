extends Node2D
## 对局场景（训练 / 对战共用）：固定 60 帧推进仿真，表现层每帧读取状态绘制。
## 从标题 → 选人进来时按 Session 的模式和角色开局；直接运行时是训练模式。
## Esc / 手柄 Start 打开暂停菜单（继续 / 重新开始 / 重新选人 / 回到标题）；对战结束后弹出结算菜单（再来一局 / 重新选人 / 回到标题）。
## 功能键（括号里是 Mac 上不会触发媒体键的替代键，两个都能用）：
##   F1(6) 判定框  F2([) 存档  F3(]) 读档  F4(P) 暂停  F5(N) 单帧步进（暂停时）  F6(R) 重置（Shift 版边）
##   F7(V) 精灵/白模  F8(8) 切换 P1 角色  F9(9) 切换 P2 角色
##   F10(0) 训练/对战模式  F11(-) 资源常满（训练）  F12(=) 调试面板
## 训练模式：1 假人模式  2 自动防御  3 录制/回放  4 连段挑战  5 下一条连段（Shift+5 上一条）
##   7 电脑演示当前连段（Shift+7 依次演示全部，再按 7 或任意操作键停止）
## Alt+Enter 全屏 / 窗口；窗口任意大小都按 16:9 等比缩放（多余部分黑边）

const STAGE: StageDef = preload("res://stages/training_stage.tres")
const RESULT_DELAY := 90 ## 比赛结束后多久弹出结算菜单
const PAUSE_ITEMS := ["继续", "重新开始", "重新选人", "回到标题"]
const RESULT_ITEMS := ["再来一局", "重新选人", "回到标题"]

var roster: Array[FighterDef] = []
var sim: MatchSim
var paused := false
var step_once := false
var saved_state: Dictionary = {}
var last_inputs: Array[int] = [0, 0]
var picks: Array[int] = [0, 1]
var meter := FrameMeter.new()
var dummy := TrainingDummy.new()
var logs := [InputLog.new(), InputLog.new()]
var trial := ComboTrial.new()
var demo := ComboDemo.new()
var cpu: CpuPlayer ## 对战电脑模式下控制 P2
var pause_menu: MenuPanel
var result_menu: MenuPanel
var _over := 0 ## 比赛结束后经过的帧数
var _slow := 0 ## KO 慢动作剩余的显示帧
var _slow_tick := 0
const KO_SLOW := [60, 2, 30, 3] ## 前 60 帧 1/2 速度，之后 30 帧 1/3 速度（仿真本身仍是逐帧确定的）

@onready var view: MatchView = $MatchView
@onready var hud: DebugPanel = $HUD/Info
@onready var hud_view: HudView = $HUD/HudView
@onready var overlay: TrainingOverlay = $HUD/TrainingOverlay
@onready var sfx: Sfx = $Sfx
@onready var combo_labels: Array[Label] = [$HUD/ComboP1, $HUD/ComboP2]


func _enter_tree() -> void:
	UiFont.setup()


func _ready() -> void:
	Engine.physics_ticks_per_second = SimConst.FPS
	_fit_window_to_screen()
	LocalInput.register_actions()
	roster = Roster.load_all()
	var setup := session_setup(roster.size())
	picks = setup[0]
	var versus: bool = setup[1]
	sim = MatchSim.new(STAGE, roster[picks[0]], roster[picks[1]])
	sim.versus = versus
	sim.training = not versus
	sim.reset()
	if Session.from_menu and Session.mode == Session.Mode.VS_CPU:
		cpu = CpuPlayer.new(1, Session.cpu_level, Time.get_ticks_msec())
	pause_menu = _make_menu()
	pause_menu.chosen.connect(_on_pause_menu)
	result_menu = _make_menu()
	result_menu.chosen.connect(_on_result_menu)
	view.sim = sim
	hud_view.sim = sim
	hud.visible = false
	hud.sim = sim
	overlay.sim = sim
	overlay.meter = meter
	overlay.dummy = dummy
	overlay.logs = logs
	overlay.trial = trial
	overlay.demo = demo
	trial.setup(roster[picks[0]])
	view.load_sprites()


func _physics_process(_delta: float) -> void:
	if pause_menu.visible or result_menu.visible:
		return
	if paused and not step_once:
		return
	step_once = false
	if _slow > 0:
		# KO 慢动作：每隔几个显示帧才推进一帧仿真
		_slow -= 1
		_slow_tick += 1
		var div: int = KO_SLOW[1] if _slow >= KO_SLOW[2] else KO_SLOW[3]
		if _slow_tick % div != 0:
			return
	advance([LocalInput.read(0), LocalInput.read(1)])


## 推进一帧：训练模式下由假人决定 P2 输入（连段演示中由演示脚本操作双方），然后记录帧计量条和输入历史。
func advance(human: Array[int]) -> void:
	if demo.playing and (human[0] != 0 or human[1] != 0):
		demo.stop() # 有人按键就把控制交还给玩家
	if demo.playing and sim.training:
		last_inputs = demo.inputs(sim, trial)
	elif sim.training:
		last_inputs = dummy.inputs_for(sim, human)
	else:
		last_inputs = human.duplicate()
		if cpu != null:
			last_inputs[1] = cpu.inputs(sim)
	sim.step(last_inputs)
	view.fx.sim = sim
	view.fx.consume(sim.events)
	hud_view.consume(sim.events)
	sfx.consume(sim.events, sim)
	for e in sim.events:
		match e.type:
			"super":
				view.super_focus = e.get("target", -1)
				view.super_level = 3 if e.get("critical", false) else e.get("level", 1)
			"ko":
				_slow = KO_SLOW[0] + KO_SLOW[2]
	meter.record(sim)
	if sim.training:
		trial.record(sim)
	for i in 2:
		logs[i].record(InputBits.clean_socd(last_inputs[i]))
	if sim.round_state == MatchSim.Round.MATCH_OVER:
		_over += 1
		if _over == RESULT_DELAY and result_menu != null:
			result_menu.open("比赛结束", PackedStringArray(RESULT_ITEMS), false)
	else:
		_over = 0


func _process(_delta: float) -> void:
	hud.paused = paused
	overlay.debug_visible = hud.visible
	hud.saved_frame = saved_state.frame if not saved_state.is_empty() else -1
	for i in 2:
		combo_labels[i].text = _combo_text(sim.fighters[1 - i])


## 攻击方一侧显示：连段数 / 连段伤害（数据取自被打方；打康提示由 HUD 横幅显示）。
func _combo_text(victim: Fighter) -> String:
	var lines := PackedStringArray()
	if victim.combo_hits >= 2:
		lines.append("%d 连击  伤害 %d" % [victim.combo_hits, victim.combo_damage])
	return "\n".join(lines)


func _input(event: InputEvent) -> void:
	LocalInput.latch(event)


func _unhandled_input(event: InputEvent) -> void:
	for m in [pause_menu, result_menu]:
		if m.handle(event):
			get_viewport().set_input_as_handled()
			return
	if MenuInput.pause(event):
		pause_menu.open("暂停", PackedStringArray(PAUSE_ITEMS))
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER and key.alt_pressed:
		_toggle_fullscreen()
		return
	match key.keycode:
		KEY_F1, KEY_6:
			view.show_boxes = not view.show_boxes
		KEY_F2, KEY_BRACKETLEFT:
			saved_state = sim.save_state()
		KEY_F3, KEY_BRACKETRIGHT:
			if not saved_state.is_empty():
				sim.load_state(saved_state)
		KEY_F4, KEY_P:
			paused = not paused
		KEY_F5, KEY_N:
			step_once = true
		KEY_F6, KEY_R:
			demo.stop()
			sim.reset()
			if key.shift_pressed:
				var edge := sim.stage.half_width - sim.fighters[1].def.push_half_width
				sim.place(edge - 9000, edge)
		KEY_F7, KEY_V:
			view.show_sprites = not view.show_sprites
		KEY_F8, KEY_8:
			_cycle_character(0)
		KEY_F9, KEY_9:
			_cycle_character(1)
		KEY_F10, KEY_0:
			demo.stop()
			sim.versus = not sim.versus
			sim.training = not sim.versus
			sim.reset()
			saved_state = {}
		KEY_F11, KEY_MINUS:
			sim.infinite_meter = not sim.infinite_meter
		KEY_F12, KEY_EQUAL:
			hud.visible = not hud.visible
		KEY_1:
			dummy.cycle_mode()
		KEY_2:
			dummy.guard = (dummy.guard + 1) % TrainingDummy.Guard.size()
		KEY_3:
			dummy.toggle_record()
		KEY_4:
			trial.enabled = not trial.enabled
			trial.restart()
		KEY_5:
			trial.next(-1 if key.shift_pressed else 1)
		KEY_7:
			if demo.playing:
				demo.stop()
			elif sim.training:
				trial.enabled = true
				demo.start(trial, key.shift_pressed)


## 开局设置 [picks, versus]：从选人进来时按 Session，否则训练模式、前两个角色。
static func session_setup(roster_size: int) -> Array:
	var out: Array[int] = [0, mini(1, roster_size - 1)]
	if not Session.from_menu:
		return [out, false]
	for i in 2:
		out[i] = clampi(Session.picks[i], 0, roster_size - 1)
	return [out, Session.mode != Session.Mode.TRAINING]


func _make_menu() -> MenuPanel:
	var m := MenuPanel.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.visible = false
	$HUD.add_child(m)
	return m


func _on_pause_menu(i: int) -> void:
	match i:
		1:
			rematch()
		2:
			get_tree().change_scene_to_file("res://scenes/char_select.tscn")
		3:
			get_tree().change_scene_to_file("res://scenes/title.tscn")


func _on_result_menu(i: int) -> void:
	match i:
		0:
			rematch()
		1:
			get_tree().change_scene_to_file("res://scenes/char_select.tscn")
		2:
			get_tree().change_scene_to_file("res://scenes/title.tscn")


## 同样的角色重新开一局（对战回到第 1 回合）。
func rematch() -> void:
	demo.stop()
	sim.reset()
	saved_state = {}
	_over = 0
	_slow = 0


## 启动时把窗口放大到屏幕可用区域内最大的 16:9 尺寸并居中。
func _fit_window_to_screen() -> void:
	# 在编辑器的 Game 面板里内嵌运行时，窗口大小由编辑器决定，这里改不了（画面上会提示）
	if DisplayServer.get_name() == "headless" or Engine.is_embedded_in_editor():
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var k := minf(usable.size.x * 0.92 / base.x, usable.size.y * 0.92 / base.y)
	var size := Vector2i((base * k).round())
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


func _toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if full:
		_fit_window_to_screen.call_deferred()


## 本地导入人物（测试用；实际选人走 Roster.load_all()）。
static func local_fighters() -> Array[FighterDef]:
	return Roster.local_fighters()


## 换角色后重置对局（角色数据不同，旧状态不再有效）。
func _cycle_character(player: int) -> void:
	demo.stop()
	picks[player] = (picks[player] + 1) % roster.size()
	sim.fighters[player].set_def(roster[picks[player]])
	if player == 0:
		trial.setup(roster[picks[0]])
	sim.reset()
	saved_state = {}
	view.load_sprites()
