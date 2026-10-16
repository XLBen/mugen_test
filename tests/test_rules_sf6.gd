extends TestCase
## SF6 规则模板：同时按宽容（投 / OD）、OD 优先于超杀、后撤步收招 Punish Counter、指令窗口。


func _far_sim() -> MatchSim:
	return adjacent_sim(500)


func test_late_second_button_upgrades_to_throw() -> void:
	var sim := adjacent_sim()
	play(sim, "5LP,5LP+LK", "", 10)
	check_eq(sim.fighters[1].state_name(), "thrown", "LP then LK one frame later is still a throw")


func test_late_second_punch_upgrades_to_od() -> void:
	var sim := _far_sim()
	play(sim, "2,3,6LP,6LP+MP")
	check_eq(sim.fighters[0].state_name(), "fireball_ex", "second punch within the window upgrades to OD")
	check_eq(Gauges.value(sim.fighters[0], Gauges.DRIVE), 60000 - 20000, "OD cost paid once")


func test_too_late_second_button_does_nothing() -> void:
	var sim := _far_sim()
	play(sim, "2,3,6LP,6x4,6LP+MP")
	check_eq(sim.fighters[0].state_name(), "fireball_l", "outside the window the first move stays")


func test_od_beats_super_with_two_punches() -> void:
	var sim := _far_sim()
	sim.fighters[0].gauges[Gauges.SUPER] = 3000
	play(sim, "2,3,6,2,3,6LP+MP")
	# 236236 里含 6-2-3，本引擎按出招表顺序给 OD 升龙；关键是两拳时不出超杀
	check(sim.fighters[0].state_name() in ["fireball_ex", "dp_ex"], "236236PP gives an OD special, not the super")
	sim = _far_sim()
	sim.fighters[0].gauges[Gauges.SUPER] = 3000
	play(sim, "2,3,6,2,3,6LP")
	check_eq(sim.fighters[0].state_name(), "super1", "236236P with one punch is the super")


func test_backdash_recovery_is_punish_counter() -> void:
	var sim := adjacent_sim()
	var p2 := sim.fighters[1]
	p2.set_state("dash_b")
	p2.state_frame = 9
	p2.fresh = 0
	play(sim, "5LP", "", 5)
	check_eq(p2.counter_type, Combat.Counter.PUNISH, "hit during backdash recovery")
	sim = adjacent_sim()
	sim.fighters[1].set_state("dash_b")
	play(sim, "5LP", "", 5)
	check_eq(sim.fighters[1].health, DUMMY.max_health, "early backdash frames are invulnerable")


func test_quarter_circle_window() -> void:
	var sim := _far_sim()
	play(sim, "2,5x3,3,5x3,6LP")
	check_eq(sim.fighters[0].state_name(), "fireball_l", "236 within 11 frames")
	sim = _far_sim()
	play(sim, "2,5x7,3,5x3,6LP")
	check(sim.fighters[0].state_name() != "fireball_l", "236 slower than 11 frames fails")
