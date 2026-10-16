extends TestCase
## 回合流程：开场、KO、时间到、双 KO、三局两胜、跨回合保留超杀槽；训练模式。

const R := MatchSim.Round


func versus_sim() -> MatchSim:
	var sim := new_sim()
	sim.versus = true
	sim.reset()
	return sim


func _skip_intro(sim: MatchSim) -> void:
	hold(sim, 0, 0, MatchSim.INTRO_FRAMES)


func test_intro_ignores_input() -> void:
	var sim := versus_sim()
	var x0 := sim.fighters[0].x
	hold(sim, InputBits.RIGHT, 0, MatchSim.INTRO_FRAMES - 1)
	check_eq(sim.fighters[0].x, x0, "cannot move during the intro")
	check_eq(sim.round_state, R.INTRO, "still in intro")
	hold(sim, 0, 0, 1)
	check_eq(sim.round_state, R.FIGHT, "fight starts")


func test_ko_ends_round_and_next_round_resets() -> void:
	var sim := versus_sim()
	_skip_intro(sim)
	sim.fighters[1].health = 100
	sim.fighters[0].gauges[Gauges.SUPER] = 1500
	sim.fighters[0].x = sim.fighters[1].x - 7500
	hold(sim, InputBits.B0, 0, 1)
	hold(sim, 0, 0, 20)
	check_eq(sim.round_state, R.END, "KO ends the round")
	check_eq(sim.wins, [1, 0] as Array[int], "P1 wins the round")
	hold(sim, 0, 0, MatchSim.END_FRAMES)
	check_eq(sim.round_number, 2, "second round")
	check_eq(sim.round_state, R.INTRO, "next round starts with an intro")
	check_eq(sim.fighters[1].health, DUMMY.max_health, "health refilled")
	check(Gauges.value(sim.fighters[0], Gauges.SUPER) >= 1500, "super meter carries over")
	check_eq(Gauges.value(sim.fighters[0], Gauges.DRIVE), 60000, "drive resets")


func test_time_over_higher_health_wins() -> void:
	var sim := versus_sim()
	_skip_intro(sim)
	sim.fighters[0].health = 5000
	sim.round_timer = 2
	hold(sim, 0, 0, 3)
	check_eq(sim.round_state, R.END, "time over")
	check_eq(sim.wins, [0, 1] as Array[int], "more health wins")


func test_draw_gives_both_a_win() -> void:
	var sim := versus_sim()
	_skip_intro(sim)
	sim.round_timer = 1
	hold(sim, 0, 0, 2)
	check_eq(sim.wins, [1, 1] as Array[int], "draw: both get the round")


func test_match_over_after_two_wins() -> void:
	var sim := versus_sim()
	for r in 2:
		_skip_intro(sim)
		sim.fighters[1].health = 0
		hold(sim, 0, 0, 1)
		hold(sim, 0, 0, MatchSim.END_FRAMES)
	check_eq(sim.round_state, R.MATCH_OVER, "best of three decided")
	check_eq(sim.wins[0], 2, "P1 has two wins")


func test_training_never_kos_and_refills() -> void:
	var sim := new_sim()
	sim.training = true
	sim.reset()
	sim.fighters[0].x = sim.fighters[1].x - 7500
	sim.fighters[1].health = 100
	play(sim, "5HP", "", 3)
	hold(sim, 0, 0, 20)
	check(sim.fighters[1].health >= 1, "training health floor")
	hold(sim, 0, 0, 60)
	check_eq(sim.fighters[1].health, DUMMY.max_health, "health refills after recovering")


func test_versus_determinism_across_rounds() -> void:
	var inputs := random_inputs(99, 4000)
	var a := versus_sim()
	var b := versus_sim()
	check(run(a, inputs) == run(b, inputs), "versus mode is deterministic")
	var mid := versus_sim()
	run(mid, inputs.slice(0, 2000))
	var snap := mid.save_state()
	var first := run(mid, inputs.slice(2000))
	mid.load_state(snap)
	check(run(mid, inputs.slice(2000)) == first, "save/load replay across rounds")
