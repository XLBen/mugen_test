extends TestCase
## 资源槽：获取、消耗、回复停顿、Burnout、超杀与超杀暂停、EX 必杀。

const S := Gauges.SUPER
const D := Gauges.DRIVE
const DRIVE_MAX := 60000


func test_meter_gain_on_hit_and_block() -> void:
	var sim := adjacent_sim()
	play(sim, "5LP", "", 20)
	check_eq(Gauges.value(sim.fighters[0], S), 20, "attacker meter on light hit")
	check_eq(Gauges.value(sim.fighters[1], S), 10, "defender meter on being hit")
	sim = adjacent_sim()
	play(sim, "5LP", "4", 20)
	check_eq(Gauges.value(sim.fighters[0], S), 10, "attacker meter halved on block")
	check_eq(Gauges.value(sim.fighters[1], D), DRIVE_MAX - 500, "blocking drains drive (and pauses regen)")


func test_special_whiff_builds_meter() -> void:
	var sim := adjacent_sim(500)
	play(sim, "2,3,6LP")
	check_eq(Gauges.value(sim.fighters[0], S), CommonStates.SPECIAL_METER, "special move builds meter on startup")


func test_super_needs_meter() -> void:
	var sim := adjacent_sim(400)
	play(sim, "2,3,6,2,3,6LP")
	# 236236 里包含 6-2-3，没有超杀槽时按优先级出升龙（与街霸一致）
	check(sim.fighters[0].state_name() in ["dp", "fireball_l"], "no meter: falls back to a special")
	sim = adjacent_sim(400)
	sim.fighters[0].gauges[S] = 1000
	play(sim, "2,3,6,2,3,6LP")
	check_eq(sim.fighters[0].state_name(), "super1", "super with one bar")
	check_eq(Gauges.value(sim.fighters[0], S), 0, "super spends one bar")


func test_superfreeze_stops_the_world() -> void:
	var sim := adjacent_sim(400)
	sim.fighters[0].gauges[S] = 1000
	play(sim, "2,3,6,2,3,6LP")
	var p2_frame := sim.fighters[1].state_frame
	var p1_frame := sim.fighters[0].state_frame
	hold(sim, 0, InputBits.RIGHT, 30)
	check_eq(sim.fighters[1].state_frame, p2_frame, "opponent frozen during superfreeze")
	check_eq(sim.fighters[0].state_frame, p1_frame, "attacker also frozen (startup counts after the flash)")
	hold(sim, 0, 0, 30)
	check(sim.fighters[0].state_frame > p1_frame, "time resumes after the freeze")


func test_super_hits_with_damage_floor() -> void:
	var sim := adjacent_sim()
	sim.fighters[0].gauges[S] = 1000
	play(sim, "2,3,6,2,3,6LP", "", 80)
	check_eq(sim.fighters[1].health, DUMMY.max_health - 2600, "super damage")
	var f := sim.fighters[1]
	f.combo_hits = 12
	check_eq(Combat.scaled_damage(f, 2600, 30), 780, "super keeps 30% minimum in long combos")


func test_ex_special_costs_drive() -> void:
	var sim := adjacent_sim(500)
	play(sim, "2,3,6LP+MP")
	check_eq(sim.fighters[0].state_name(), "fireball_ex", "236PP -> EX fireball")
	check_eq(Gauges.value(sim.fighters[0], D), DRIVE_MAX - 20000, "EX spends two drive bars")
	sim = adjacent_sim(500)
	sim.fighters[0].gauges[D] = 15000
	play(sim, "2,3,6LP+MP")
	check(sim.fighters[0].state_name() != "fireball_ex", "not enough drive: no EX")


func test_regen_delay_after_spending() -> void:
	var sim := adjacent_sim(500)
	play(sim, "2,3,6LP+MP")
	var after := Gauges.value(sim.fighters[0], D)
	hold(sim, 0, 0, 60)
	check_eq(Gauges.value(sim.fighters[0], D), after, "no regen right after spending")
	hold(sim, 0, 0, 60)
	check(Gauges.value(sim.fighters[0], D) > after, "regen resumes after the delay")


func test_burnout() -> void:
	var sim := adjacent_sim()
	var p2 := sim.fighters[1]
	Gauges.gain(p2, D, -DRIVE_MAX)
	check_eq(p2.burnout, 1, "empty drive -> burnout")
	play(sim, "5HP", "4", 2)
	hold(sim, 0, InputBits.RIGHT, 10)
	check_eq(p2.state_name(), "block_stand", "still blocks in burnout")
	check_eq(p2.health, DUMMY.max_health, "SF6: normals never chip, even in burnout")
	check_eq(p2.stun, 18 + Combat.BURNOUT_BLOCKSTUN, "burnout adds blockstun")
	p2.gauges[D] = DRIVE_MAX - 10
	p2.gauge_delay[D] = 0
	hold(sim, 0, 0, 5)
	check_eq(p2.burnout, 0, "refilling the gauge ends burnout")
