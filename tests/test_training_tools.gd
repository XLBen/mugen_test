extends TestCase
## 训练工具：帧计量条、训练假人（自动防御 / 录制回放）、输入历史。


func _run_with_meter(sim: MatchSim, p1_script: String, p2_script := "", extra := 60) -> FrameMeter:
	var meter := FrameMeter.new()
	var a := InputScript.parse(p1_script)
	var b := InputScript.parse(p2_script, true)
	var b_last := b[-1] & InputBits.DIRECTIONS if not b.is_empty() else 0
	for i in maxi(a.size(), b.size()) + extra:
		sim.step([a[i] if i < a.size() else 0, b[i] if i < b.size() else b_last])
		meter.record(sim)
	return meter


func test_frame_meter_matches_frame_data() -> void:
	var meter := _run_with_meter(adjacent_sim(), "5LP")
	check_eq(meter.startup[0], 4, "5LP startup")
	check_eq(meter.total[0], 12, "5LP total")
	check(meter.has_advantage, "advantage measured")
	check_eq(meter.advantage, 4, "5LP on hit")
	meter = _run_with_meter(adjacent_sim(), "5HK", "4")
	check_eq(meter.advantage, -5, "5HK on block")


func test_frame_meter_categories() -> void:
	var sim := adjacent_sim(400)
	var meter := _run_with_meter(sim, "5LP", "", 14)
	var row: Array = meter.rows[0]
	var startup := row.count(FrameMeter.Cat.STARTUP)
	var active := row.count(FrameMeter.Cat.ACTIVE)
	check_eq(startup, 3, "3 startup frames before the first active frame")
	check_eq(active, 2, "2 active frames")
	check_eq(row.count(FrameMeter.Cat.RECOVERY), 7, "7 recovery frames")


func test_no_advantage_without_contact() -> void:
	var meter := _run_with_meter(adjacent_sim(400), "5LP")
	check(not meter.has_advantage, "whiffs do not report advantage")


func _dummy_sim(dummy: TrainingDummy, p1_script: String, frames: int) -> MatchSim:
	var sim := adjacent_sim()
	var a := InputScript.parse(p1_script)
	for i in frames:
		var human: Array[int] = [a[i] if i < a.size() else 0, 0]
		sim.step(dummy.inputs_for(sim, human))
	return sim


func test_dummy_auto_guard_low() -> void:
	var dummy := TrainingDummy.new()
	dummy.guard = TrainingDummy.Guard.ALL
	var sim := _dummy_sim(dummy, "2LK", 8)
	check_eq(sim.fighters[1].state_name(), "block_crouch", "dummy crouch-blocks a low")
	check_eq(sim.fighters[1].health, DUMMY.max_health, "no damage")


func test_dummy_auto_guard_overhead() -> void:
	var dummy := TrainingDummy.new()
	dummy.mode = TrainingDummy.Mode.CROUCH
	dummy.guard = TrainingDummy.Guard.ALL
	var sim := adjacent_sim(60)
	var p1 := sim.fighters[0]
	p1.y = 9000
	p1.vy = -400
	p1.set_state("j_hk")
	for i in 30:
		sim.step(dummy.inputs_for(sim, [0, 0] as Array[int]))
	check_eq(sim.fighters[1].health, DUMMY.max_health, "crouching dummy stands up to block a jump-in")


func test_dummy_without_guard_gets_hit() -> void:
	var dummy := TrainingDummy.new()
	var sim := _dummy_sim(dummy, "2LK", 8)
	check(sim.fighters[1].health < DUMMY.max_health, "guard off: dummy is hit")


func test_record_and_playback() -> void:
	var dummy := TrainingDummy.new()
	dummy.set_mode(TrainingDummy.Mode.RECORD)
	var sim := adjacent_sim(400)
	var script := InputScript.parse("4x5,6x3,2LP")
	for bits in script:
		var out := dummy.inputs_for(sim, [bits, 0] as Array[int])
		check_eq(out[0], 0, "P1 is idle while recording the dummy")
	check_eq(dummy.recording, script, "recorded inputs")
	dummy.toggle_record()
	check_eq(dummy.mode, TrainingDummy.Mode.PLAYBACK, "toggle switches to playback")
	var played: Array[int] = []
	for i in script.size() * 2:
		played.append(dummy.inputs_for(sim, [0, 0] as Array[int])[1])
	check_eq(played.slice(0, script.size()), script, "playback repeats the recording")
	check_eq(played.slice(script.size()), script, "playback loops")


func test_input_log_compresses() -> void:
	var log := InputLog.new()
	for bits in InputScript.parse("6x5,2,3,6LP"):
		log.record(bits)
	check_eq(log.entries.size(), 4, "consecutive identical inputs merge")
	check_eq(log.entries[3][1], 5, "held frames counted")
	check_eq(InputLog.describe(log.entries[0][0], 1), "6 LP", "latest entry text")


## 连段挑战：按设计脚本打出就判成功；只打第一招则停在第 1 步并在连段结束后归零。
func test_combo_trial_tracks_progress() -> void:
	var trial := ComboTrial.new()
	trial.setup(KAGURA)
	trial.enabled = true
	var c := trial.current()
	var sim := char_sim(KAGURA, DUMMY, c.get("gap", 75))
	var inputs := InputScript.parse(ComboTrial.build_script(c))
	var succeeded := false
	for i in inputs.size() + 60:
		sim.step([inputs[i] if i < inputs.size() else 0, 0])
		trial.record(sim)
		succeeded = succeeded or trial.success_timer > 0
	check(succeeded, "designed input clears the trial")
	check(trial.cleared.has(0), "marked as cleared")
	sim = char_sim(KAGURA, DUMMY, c.get("gap", 75))
	trial.restart()
	var first: String = c.script[0][0]
	inputs = InputScript.parse(first)
	var peak := 0
	for i in 80:
		sim.step([inputs[i] if i < inputs.size() else 0, 0])
		trial.record(sim)
		peak = maxi(peak, trial.step)
	check_eq(peak, 1, "first move counts as step 1")
	check_eq(trial.step, 0, "dropping the combo resets the trial")
	check_eq(ComboTrial.notation_parts(c).size(), c.states.size(), "notation splits into one part per move")


## 连段演示：电脑按脚本打出当前连段，连段挑战判定成功；演示全部时依次跑完每一条后自动停止。
func test_combo_demo_plays_routes() -> void:
	var trial := ComboTrial.new()
	trial.setup(KAGURA)
	trial.enabled = true
	var demo := ComboDemo.new()
	var sim := char_sim(KAGURA, VOLK, 300)
	demo.start(trial, true)
	check_eq(demo.total, trial.combos.size(), "queues every combo")
	var guard := 0
	while demo.playing and guard < 3000:
		sim.step(demo.inputs(sim, trial))
		trial.record(sim)
		guard += 1
	check(not demo.playing, "stops after the last combo")
	check_eq(trial.cleared.size(), trial.combos.size(), "every demonstrated combo clears the trial against Volk")


func test_combo_demo_single_and_stop() -> void:
	var trial := ComboTrial.new()
	trial.setup(MIO)
	trial.next()
	var demo := ComboDemo.new()
	var sim := char_sim(MIO, KAGURA, 300)
	demo.start(trial)
	check_eq(demo.total, 1, "single combo")
	sim.step(demo.inputs(sim, trial))
	check_eq(sim.fighters[1].x - sim.fighters[0].x, trial.current().get("gap", 75) * SimConst.UNITS_PER_PX,
		"demo places the fighters like the route test")
	demo.stop()
	check(not demo.playing, "stop ends the demo")
	check_eq(demo.inputs(sim, trial), [0, 0] as Array[int], "no inputs once stopped")
