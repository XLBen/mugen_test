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


## 确反（Punish Counter）：防御方损失 Drive，双方多顿 4 帧；普通打康不扣 Drive。
func test_punish_counter_drains_drive_and_adds_hitstop() -> void:
	var sim := adjacent_sim(150)
	var p2 := sim.fighters[1]
	var a := InputScript.parse("5x9,5HP")
	var b := InputScript.parse("5HK", true)
	for i in 30:
		sim.step([a[i] if i < a.size() else 0, b[i] if i < b.size() else 0])
		if p2.sd().kind == "hurt":
			break
	check_eq(p2.counter_type, Combat.Counter.PUNISH, "punish counter")
	check_eq(p2.hitstop, 11 + Combat.COUNTER_HITSTOP[Combat.Counter.PUNISH], "punish counter hitstop")
	check_eq(sim.fighters[0].hitstop, p2.hitstop, "attacker freezes as long")
	check_eq(Gauges.value(p2, Gauges.DRIVE), 60000 - 1500, "heavy punish counter drains the defender's drive")
	sim = adjacent_sim()
	play(sim, "5HK", "5HK", 12)
	check_eq(Gauges.value(sim.fighters[1], Gauges.DRIVE), 60000, "plain counter hit does not drain drive")


## 拆投可以预输入：被抓前几帧按下 LP+LK 并按住也能拆。
func test_throw_tech_prebuffered() -> void:
	var sim := adjacent_sim()
	sim.fighters[1].set_state("landing_long") # 收招中不能自己出投
	play(sim, "5LP+LK", "5x2,5LP+LK", 6)
	check_eq(sim.fighters[1].state_name(), "throw_tech", "tech pressed 2 frames before the grab")
	sim = adjacent_sim()
	sim.fighters[1].set_state("landing_long")
	play(sim, "5x6,5LP+LK,5x10", "5LP+LK", 0)
	check(sim.fighters[1].state_name() != "throw_tech", "a press long before the grab does not tech")


## 晚几帧按投：被抓时自己的投还在发生中，也算拆投。
func test_late_throw_techs() -> void:
	var sim := adjacent_sim()
	play(sim, "5LP+LK", "5x2,5LP+LK", 6)
	check_eq(sim.fighters[1].state_name(), "throw_tech", "own throw in startup techs")


## 起身后有短暂投无敌。
func test_throw_protect_after_wakeup() -> void:
	var sim := adjacent_sim()
	var p2 := sim.fighters[1]
	p2.set_state("wakeup")
	for i in 30:
		sim.step([0, 0])
		if not p2.is_in(["wakeup"]):
			break
	check(not Combat.throwable(p2), "first frame after wakeup is throw invulnerable")
	sim.step([0, 0])
	check(Combat.throwable(p2), "then throwable again")
