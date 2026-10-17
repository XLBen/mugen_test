extends Node2D
## 训练场景：固定 60 帧推进仿真，表现层每帧读取状态绘制。
## F1 判定框  F2 存档  F3 读档  F4 暂停  F5 单帧步进（暂停时）  F6 重置
## F7 精灵/白模  F8 切换 P1 角色  F9 切换 P2 角色
## F10 训练/对战模式  F11 资源常满（训练）  F12 显示/隐藏调试信息
## 训练模式：1 假人模式  2 自动防御  3 录制/回放  Shift+F6 版边重置

const STAGE: StageDef = preload("res://stages/training_stage.tres")
const ROSTER: Array[FighterDef] = [
	preload("res://characters/kagura/kagura.tres"),
	preload("res://characters/volk/volk.tres"),
	preload("res://characters/mio/mio.tres"),
	preload("res://characters/dummy/dummy.tres"),
]

var sim: MatchSim
var paused := false
var step_once := false
var saved_state: Dictionary = {}
var last_inputs: Array[int] = [0, 0]
var picks: Array[int] = [0, 1]
var meter := FrameMeter.new()
var dummy := TrainingDummy.new()
var logs := [InputLog.new(), InputLog.new()]

@onready var view: MatchView = $MatchView
@onready var hud: Label = $HUD/Info
@onready var hud_view: HudView = $HUD/HudView
@onready var overlay: TrainingOverlay = $HUD/TrainingOverlay
@onready var sfx: Sfx = $Sfx
@onready var combo_labels: Array[Label] = [$HUD/ComboP1, $HUD/ComboP2]


func _ready() -> void:
	Engine.physics_ticks_per_second = SimConst.FPS
	LocalInput.register_actions()
	sim = MatchSim.new(STAGE, ROSTER[picks[0]], ROSTER[picks[1]])
	sim.training = true
	sim.reset()
	view.sim = sim
	hud_view.sim = sim
	hud.visible = false
	overlay.sim = sim
	overlay.meter = meter
	overlay.dummy = dummy
	overlay.logs = logs
	view.load_sprites()


func _physics_process(_delta: float) -> void:
	if paused and not step_once:
		return
	step_once = false
	advance([LocalInput.read(0), LocalInput.read(1)])


## 推进一帧：训练模式下由假人决定 P2 输入，然后记录帧计量条和输入历史。
func advance(human: Array[int]) -> void:
	last_inputs = dummy.inputs_for(sim, human) if sim.training else human
	sim.step(last_inputs)
	view.fx.sim = sim
	view.fx.consume(sim.events)
	sfx.consume(sim.events)
	meter.record(sim)
	for i in 2:
		logs[i].record(InputBits.clean_socd(last_inputs[i]))


func _process(_delta: float) -> void:
	hud.text = _hud_text()
	for i in 2:
		combo_labels[i].text = _combo_text(sim.fighters[1 - i])


## 攻击方一侧显示：连段数 / 连段伤害 / 打康提示（数据取自被打方）。
func _combo_text(victim: Fighter) -> String:
	var lines := PackedStringArray()
	if victim.counter_timer > 0:
		lines.append("PUNISH COUNTER" if victim.counter_type == Combat.Counter.PUNISH else "COUNTER")
	if victim.combo_hits >= 2:
		lines.append("%d HITS  %d" % [victim.combo_hits, victim.combo_damage])
	return "\n".join(lines)


func _input(event: InputEvent) -> void:
	LocalInput.latch(event)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			view.show_boxes = not view.show_boxes
		KEY_F2:
			saved_state = sim.save_state()
		KEY_F3:
			if not saved_state.is_empty():
				sim.load_state(saved_state)
		KEY_F4:
			paused = not paused
		KEY_F5:
			step_once = true
		KEY_F6:
			sim.reset()
			if key.shift_pressed:
				var edge := sim.stage.half_width - sim.fighters[1].def.push_half_width
				sim.place(edge - 9000, edge)
		KEY_F7:
			view.show_sprites = not view.show_sprites
		KEY_F8:
			_cycle_character(0)
		KEY_F9:
			_cycle_character(1)
		KEY_F10:
			sim.versus = not sim.versus
			sim.training = not sim.versus
			sim.reset()
			saved_state = {}
		KEY_F11:
			sim.infinite_meter = not sim.infinite_meter
		KEY_F12:
			hud.visible = not hud.visible
		KEY_1:
			dummy.cycle_mode()
		KEY_2:
			dummy.guard = (dummy.guard + 1) % TrainingDummy.Guard.size()
		KEY_3:
			dummy.toggle_record()


## 换角色后重置对局（角色数据不同，旧状态不再有效）。
func _cycle_character(player: int) -> void:
	picks[player] = (picks[player] + 1) % ROSTER.size()
	sim.fighters[player].set_def(ROSTER[picks[player]])
	sim.reset()
	saved_state = {}
	view.load_sprites()


func _hud_text() -> String:
	var lines := PackedStringArray()
	lines.append("frame %d   hash %08x   camera %d px%s" % [
		sim.frame, sim.state_hash(), int(SimConst.px(sim.camera_x)), "   [PAUSED]" if paused else ""])
	for i in 2:
		var g := sim.fighters[i]
		lines.append("P%d  super %4d  drive %5d%s" % [i + 1, g.gauges[Gauges.SUPER], g.gauges[Gauges.DRIVE],
			"  BURNOUT" if g.burnout else ""])
	for i in sim.fighters.size():
		var f := sim.fighters[i]
		lines.append("P%d  HP %5d  %-12s f%-3d  x %7.1f  y %6.1f  vx %5d  vy %5d  stun %2d  stop %2d  input %d" % [
			i + 1, f.health, f.state_name(), f.state_frame, SimConst.px(f.x), SimConst.px(f.y),
			f.vx, f.vy, f.stun, f.hitstop, f.numpad_at(sim.frame)])
	lines.append("saved state: %s" % ("frame %d" % saved_state.frame if not saved_state.is_empty() else "none"))
	lines.append("P1 %s (WASD)   P2 %s (Arrows)" % [sim.fighters[0].def.display_name, sim.fighters[1].def.display_name])
	lines.append("F1 boxes  F2 save  F3 load  F4 pause  F5 step  F6 reset  F7 sprites  F8/F9 character")
	lines.append("F10 %s  F11 infinite meter %s  F12 hide this" % [
		"VERSUS" if sim.versus else "TRAINING", "ON" if sim.infinite_meter else "off"])
	return "\n".join(lines)
