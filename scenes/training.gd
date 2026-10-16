extends Node2D
## 训练场景：固定 60 帧推进仿真，表现层每帧读取状态绘制。
## F1 判定框  F2 存档  F3 读档  F4 暂停  F5 单帧步进（暂停时）  F6 重置

const STAGE: StageDef = preload("res://stages/training_stage.tres")
const DUMMY: FighterDef = preload("res://characters/dummy/dummy.tres")

var sim: MatchSim
var paused := false
var step_once := false
var saved_state: Dictionary = {}
var last_inputs: Array[int] = [0, 0]

@onready var view: MatchView = $MatchView
@onready var hud: Label = $HUD/Info


func _ready() -> void:
	Engine.physics_ticks_per_second = SimConst.FPS
	LocalInput.register_actions()
	sim = MatchSim.new(STAGE, DUMMY, DUMMY)
	view.sim = sim


func _physics_process(_delta: float) -> void:
	if paused and not step_once:
		return
	step_once = false
	last_inputs = [LocalInput.read(0), LocalInput.read(1)]
	sim.step(last_inputs)


func _process(_delta: float) -> void:
	hud.text = _hud_text()


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


func _hud_text() -> String:
	var lines := PackedStringArray()
	lines.append("frame %d   hash %08x   camera %d px%s" % [
		sim.frame, sim.state_hash(), int(SimConst.px(sim.camera_x)), "   [PAUSED]" if paused else ""])
	for i in sim.fighters.size():
		var f := sim.fighters[i]
		lines.append("P%d  %-12s f%-3d  x %7.1f  y %6.1f  vx %5d  vy %5d  facing %+d  input %d" % [
			i + 1, Fighter.state_name(f.state), f.state_frame, SimConst.px(f.x), SimConst.px(f.y),
			f.vx, f.vy, f.facing, InputBits.to_numpad(InputBits.clean_socd(last_inputs[i]), f.facing)])
	lines.append("saved state: %s" % ("frame %d" % saved_state.frame if not saved_state.is_empty() else "none"))
	lines.append("P1 WASD   P2 Arrows   F1 boxes  F2 save  F3 load  F4 pause  F5 step  F6 reset")
	return "\n".join(lines)
