extends TestCase
## 连段（目押 / 取消 / 连打 / Target Combo）、补正、追打限制、打康。

const LP := InputBits.B0
const MP := InputBits.B1
const HP := InputBits.B2
const HK := InputBits.B5


## 逐帧推进并记录 P2 的最大连段数。
func max_combo(sim: MatchSim, p1_script: String, p2_script := "", extra := 0) -> int:
	var a := InputScript.parse(p1_script)
	var b := InputScript.parse(p2_script, true)
	var best := 0
	for i in maxi(a.size(), b.size()) + extra:
		sim.step([a[i] if i < a.size() else 0, b[i] if i < b.size() else 0])
		best = maxi(best, sim.fighters[1].combo_hits)
	return best


func _step_until_free(sim: MatchSim, who: int) -> void:
	for i in 100:
		if sim.fighters[who].sd().ctrl:
			return
		sim.step([0, 0])


func test_link_light_into_light() -> void:
	var sim := adjacent_sim()
	play(sim, "5LP")
	_step_until_free(sim, 0)
	# 第一个可行动帧（已经推进了一帧）立刻按 LP：+4 有利，发生 4，刚好连上
	sim.step([LP, 0])
	hold(sim, 0, 0, 6)
	check_eq(sim.fighters[1].combo_hits, 2, "5LP links into 5LP")


func test_link_fails_with_slow_move() -> void:
	var sim := adjacent_sim()
	play(sim, "5LP")
	_step_until_free(sim, 0)
	sim.step([HP, 0])
	var best := max_combo(sim, "5x20")
	check_eq(best, 1, "5HP (startup 9) does not link after +4")


func test_special_cancel_during_hitstop() -> void:
	var sim := adjacent_sim()
	var best := max_combo(sim, "5MP,5x6,2,3,6HP", "", 40)
	check_eq(best, 2, "5MP xx 236HP combos")


func test_no_cancel_on_whiff() -> void:
	var sim := adjacent_sim(400)
	play(sim, "5MP,5,2,3,6HP")
	hold(sim, 0, 0, 3)
	check_eq(sim.fighters[0].state_name(), "5mp", "whiffed normal is not cancelable")


func test_chain_lights() -> void:
	var sim := adjacent_sim()
	play(sim, "5LP,5x3,5LP", "", 12)
	check_eq(sim.fighters[1].combo_hits, 2, "5LP chains into 5LP well before link timing")


func test_target_combo() -> void:
	var sim := adjacent_sim()
	var best := max_combo(sim, "5MP,5x5,5HP", "", 25)
	check_eq(best, 2, "5MP > HP target combo")
	check(sim.fighters[1].is_in(["hit_air", "knockdown"]), "target combo knocks down")
	var no_tc := adjacent_sim(400)
	play(no_tc, "5MP,5x5,5HP", "", 2)
	check(no_tc.fighters[0].state_name() != "tc_hp", "target combo needs contact")


func test_damage_scaling() -> void:
	# 5LP > 5LP xx 236HP：300 + 300×90% + 600×70% = 990（轻攻击起手每击额外 -10%）
	var sim := adjacent_sim()
	var best := max_combo(sim, "5LP,5x3,5LP,5x5,2,3,6HP", "", 40)
	check_eq(best, 3, "three hit combo")
	check_eq(sim.fighters[1].health, DUMMY.max_health - 990, "scaled combo damage")


func test_scaling_floor() -> void:
	var sim := new_sim()
	var f := sim.fighters[1]
	f.combo_hits = 30
	check_eq(Combat.scaled_damage(f, 1000), 100, "scaling never drops below 10%")


func test_juggle_limit() -> void:
	for juggle in [0, 1]:
		var sim := adjacent_sim()
		var p2 := sim.fighters[1]
		p2.set_state("hit_air")
		p2.y = 10000
		p2.vy = 0
		p2.juggle = juggle
		play(sim, "5LP", "", 4)
		var hit := p2.health < DUMMY.max_health
		if juggle == 0:
			check(hit, "fresh air-hurt opponent can be juggled by a normal")
		else:
			check(not hit, "juggle counter above the move's limit: normal passes through")


func test_counter_hit() -> void:
	# P2 出 5HP（发生 9），P1 的 5LP 在其发生阶段打中 → Counter
	var sim := adjacent_sim()
	play(sim, "5,5,5LP", "5HP", 4)
	var p2 := sim.fighters[1]
	check_eq(p2.counter_type, Combat.Counter.COUNTER, "hit during startup is a counter hit")
	check_eq(p2.health, DUMMY.max_health - 360, "counter hit damage x1.2")
	var adv := advantage(sim)
	check_eq(adv, 4 + 2, "counter hit adds 2 frames of hitstun")


func test_punish_counter() -> void:
	# P2 空挥 5HK，P1 的 5HP 打中其伸出的腿（收招阶段）→ Punish Counter
	var sim := adjacent_sim(150)
	play(sim, "5x9,5HP", "5HK", 14)
	var p2 := sim.fighters[1]
	check_eq(p2.counter_type, Combat.Counter.PUNISH, "hit during recovery is a punish counter")
	check_eq(p2.health, DUMMY.max_health - 960, "punish counter damage x1.2")


func test_counter_effect_launches() -> void:
	# 同时出 5HK：相打，双方都是打康，5HK 打康变成浮空
	var sim := adjacent_sim()
	play(sim, "5HK", "5HK", 12)
	check(sim.fighters[0].is_in(["hit_air"]) and sim.fighters[1].is_in(["hit_air"]), "counter-hit 5HK launches")


func test_throw_punish() -> void:
	var sim := adjacent_sim()
	sim.fighters[1].set_state("landing_long")
	play(sim, "5LP+LK", "", 60)
	check_eq(sim.fighters[1].health, DUMMY.max_health - 2040, "throwing a recovering opponent deals 170%")


func test_combo_resets_after_recovery() -> void:
	var sim := adjacent_sim()
	play(sim, "5LP", "", 40)
	check_eq(sim.fighters[1].combo_hits, 0, "combo counter resets once the victim can act")
