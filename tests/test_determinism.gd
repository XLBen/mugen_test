extends TestCase
## 确定性、存读档重放、随机对局中的不变量。


func test_same_inputs_same_hashes() -> void:
	var inputs := random_inputs(42, 3000)
	check(run(new_sim(), inputs) == run(new_sim(), inputs), "same inputs produced different hashes")


func test_save_load_replay() -> void:
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
	check_eq(snapshot.frame, 600, "snapshot was mutated")


func test_invariants_random_play() -> void:
	var max_span := 2 * SimConst.SCREEN_HALF_W
	for seed_value in [1, 2, 3, 4, 5]:
		var sim := new_sim()
		for inp: Array in random_inputs(seed_value, 2500):
			sim.step([inp[0], inp[1]])
			var p1 := sim.fighters[0]
			var p2 := sim.fighters[1]
			var left := mini(p1.push_left(), p2.push_left())
			var right := maxi(p1.push_right(), p2.push_right())
			var where := "seed %d frame %d" % [seed_value, sim.frame]
			if right - left > max_span:
				check(false, "%s: fighters span %d > screen %d" % [where, right - left, max_span])
				break
			if left < -STAGE.half_width or right > STAGE.half_width:
				check(false, "%s: fighter outside stage" % where)
				break
			if p1.y < 0 or p2.y < 0:
				check(false, "%s: fighter below ground" % where)
				break
			if p1.health < 0 or p2.health < 0:
				check(false, "%s: negative health" % where)
				break
			if Box.overlap(p1.pushbox_world(), p2.pushbox_world()) and not p1.is_in(["thrown"]) and not p2.is_in(["thrown"]):
				check(false, "%s: pushboxes overlap (%s / %s)" % [where, p1.state_name(), p2.state_name()])
				break
