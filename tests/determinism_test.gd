extends SceneTree
## 无头测试：godot --headless --path . -s res://tests/determinism_test.gd
## 退出码 0 = 全部通过。

const STAGE: StageDef = preload("res://stages/training_stage.tres")
const DUMMY: FighterDef = preload("res://characters/dummy/dummy.tres")

const U := InputBits.UP
const D := InputBits.DOWN
const L := InputBits.LEFT
const R := InputBits.RIGHT

var failures := 0


func _initialize() -> void:
	test_determinism()
	test_save_load_replay()
	test_invariants_random()
	test_walk()
	test_neutral_jump()
	test_walk_back_stops_at_screen_wall()
	test_push_into_corner()
	test_auto_face()
	test_socd()
	print("\n%s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("  FAIL: ", msg)


func new_sim() -> MatchSim:
	return MatchSim.new(STAGE, DUMMY, DUMMY)


## 种子化的伪随机输入：每段随机方向持续 1~20 帧。
func random_inputs(seed_value: int, count: int) -> Array:
	var rng := seed_value
	var out := []
	var cur: Array[int] = [0, 0]
	var hold: Array[int] = [0, 0]
	for i in count:
		for p in 2:
			if hold[p] <= 0:
				rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF
				cur[p] = (rng >> 8) & InputBits.DIRECTIONS
				rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF
				hold[p] = 1 + (rng >> 8) % 20
			hold[p] -= 1
		out.append(cur.duplicate())
	return out


func run(sim: MatchSim, inputs: Array) -> Array[int]:
	var hashes: Array[int] = []
	for inp in inputs:
		var typed: Array[int] = [inp[0], inp[1]]
		sim.step(typed)
		hashes.append(sim.state_hash())
	return hashes


func hold(sim: MatchSim, p1: int, p2: int, frames: int) -> void:
	for i in frames:
		sim.step([p1, p2])


func test_determinism() -> void:
	print("determinism")
	var inputs := random_inputs(42, 3000)
	var a := run(new_sim(), inputs)
	var b := run(new_sim(), inputs)
	check(a == b, "same inputs produced different hashes")


func test_save_load_replay() -> void:
	print("save/load replay")
	var inputs := random_inputs(7, 1200)
	var sim := new_sim()
	run(sim, inputs.slice(0, 600))
	var snapshot := sim.save_state()
	var first := run(sim, inputs.slice(600))
	var end_state := sim.save_state()
	sim.load_state(snapshot)
	check(sim.save_state() == snapshot, "load_state did not restore saved state")
	var second := run(sim, inputs.slice(600))
	check(first == second, "replay after load diverged")
	check(sim.save_state() == end_state, "final state differs after replay")
	# 存档必须是深拷贝：继续推进不应改动已保存的快照
	check(snapshot.frame == 600, "snapshot was mutated")


func test_invariants_random() -> void:
	print("invariants (random play)")
	var max_span := 2 * SimConst.SCREEN_HALF_W
	for seed_value in [1, 2, 3, 4, 5]:
		var sim := new_sim()
		for inp in random_inputs(seed_value, 2000):
			sim.step([inp[0], inp[1]])
			var p1 := sim.fighters[0]
			var p2 := sim.fighters[1]
			var left := mini(p1.push_left(), p2.push_left())
			var right := maxi(p1.push_right(), p2.push_right())
			if right - left > max_span:
				check(false, "seed %d frame %d: fighters span %d > screen %d" % [seed_value, sim.frame, right - left, max_span])
				break
			if left < -STAGE.half_width or right > STAGE.half_width:
				check(false, "seed %d frame %d: fighter outside stage" % [seed_value, sim.frame])
				break
			if p1.y < 0 or p2.y < 0:
				check(false, "seed %d frame %d: fighter below ground" % [seed_value, sim.frame])
				break
			var y_overlap := p1.y < p2.y + p2.push_height() and p2.y < p1.y + p1.push_height()
			var x_overlap := p1.push_left() < p2.push_right() and p2.push_left() < p1.push_right()
			if y_overlap and x_overlap:
				check(false, "seed %d frame %d: pushboxes overlap" % [seed_value, sim.frame])
				break


func test_walk() -> void:
	print("walk")
	var sim := new_sim()
	var x0 := sim.fighters[0].x
	hold(sim, R, 0, 10)
	check(sim.fighters[0].x == x0 + 10 * DUMMY.walk_forward_speed, "walk forward distance")
	check(sim.fighters[0].state == Fighter.State.WALK_FORWARD, "walk forward state")
	var x1 := sim.fighters[0].x
	hold(sim, L, 0, 10)
	check(sim.fighters[0].x == x1 - 10 * DUMMY.walk_back_speed, "walk back distance")
	hold(sim, D, 0, 1)
	check(sim.fighters[0].state == Fighter.State.CROUCH, "crouch")


func test_neutral_jump() -> void:
	print("neutral jump")
	var sim := new_sim()
	var p1 := sim.fighters[0]
	var x0 := p1.x
	hold(sim, U, 0, 1)
	check(p1.state == Fighter.State.PREJUMP, "prejump entered")
	hold(sim, 0, 0, DUMMY.prejump_frames - 1)
	check(p1.state == Fighter.State.PREJUMP and p1.y == 0, "still grounded during prejump")
	hold(sim, 0, 0, 1)
	check(p1.state == Fighter.State.AIR and p1.y > 0, "airborne after prejump")
	var air_frames := 0
	var apex := 0
	while p1.state == Fighter.State.AIR and air_frames < 200:
		apex = maxi(apex, p1.y)
		hold(sim, 0, 0, 1)
		air_frames += 1
	print("  air frames %d, apex %.1f px" % [air_frames + 1, SimConst.px(apex)])
	check(p1.state == Fighter.State.LANDING, "landing after jump")
	check(air_frames > 30 and air_frames < 60, "jump duration plausible")
	check(p1.x == x0, "neutral jump returns to same x")
	hold(sim, 0, 0, DUMMY.landing_frames)
	check(p1.state == Fighter.State.STAND, "stand after landing recovery")


func test_walk_back_stops_at_screen_wall() -> void:
	print("walk back stops at screen wall")
	var sim := new_sim()
	var p2_x := sim.fighters[1].x
	hold(sim, L, 0, 600)
	var p1 := sim.fighters[0]
	var p2 := sim.fighters[1]
	check(p2.x == p2_x, "idle opponent must not be dragged")
	check(p1.push_left() == sim.screen_wall_left(), "p1 stops exactly at screen wall")
	check(sim.screen_wall_left() > -STAGE.half_width, "screen wall is not the stage edge here")


func test_push_into_corner() -> void:
	print("push into corner")
	var sim := new_sim()
	hold(sim, R, 0, 1200)
	var p1 := sim.fighters[0]
	var p2 := sim.fighters[1]
	check(p2.push_right() == STAGE.half_width, "opponent pushed into stage corner")
	check(p1.push_right() == p2.push_left(), "attacker stops flush against cornered opponent")


func test_auto_face() -> void:
	print("auto face")
	var sim := new_sim()
	sim.fighters[0].x = 20000
	sim.fighters[1].x = -20000
	hold(sim, 0, 0, 1)
	check(sim.fighters[0].facing == -1 and sim.fighters[1].facing == 1, "fighters turn to face each other")
	# 空中不转向
	sim.reset()
	hold(sim, U, 0, 1 + DUMMY.prejump_frames)
	sim.fighters[1].x = sim.fighters[0].x - 30000
	hold(sim, 0, 0, 1)
	check(sim.fighters[0].facing == 1, "airborne fighter keeps facing")


func test_socd() -> void:
	print("socd")
	check(InputBits.clean_socd(L | R) == 0, "left+right = neutral")
	check(InputBits.clean_socd(U | D) == U, "up+down = up")
	check(InputBits.to_numpad(R, 1) == 6 and InputBits.to_numpad(R, -1) == 4, "numpad flips with facing")
	check(InputBits.to_numpad(D | L, 1) == 1 and InputBits.to_numpad(U | L, -1) == 9, "diagonals")
