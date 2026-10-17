extends TestCase
## Drive 系统（SF6）：Drive Impact、Drive Reversal（之后加 Drive Parry）。


func _wall_sim(gap_px := 75) -> MatchSim:
	# P2 背靠右边舞台墙
	var sim := new_sim()
	var wall := STAGE.half_width - DUMMY.push_half_width
	sim.place(wall - gap_px * SimConst.UNITS_PER_PX, wall)
	return sim


func test_drive_impact_costs_one_bar_and_not_in_burnout() -> void:
	var sim := adjacent_sim()
	var p1 := sim.fighters[0]
	play(sim, "5HP+HK")
	check_eq(p1.state_name(), "drive_impact", "HP+HK is Drive Impact")
	check_eq(Gauges.value(p1, Gauges.DRIVE), 50000, "costs one bar")
	sim = adjacent_sim()
	p1 = sim.fighters[0]
	p1.gauges[Gauges.DRIVE] = 0
	p1.burnout = 1
	play(sim, "5HP+HK")
	check(p1.state_name() != "drive_impact", "not available in burnout")


func test_drive_impact_starts_on_frame_26() -> void:
	var sim := adjacent_sim()
	var p1 := sim.fighters[0]
	var p2 := sim.fighters[1]
	var a := InputScript.parse("5HP+HK")
	for i in 60:
		sim.step([a[i] if i < a.size() else 0, 0])
		if p2.sd().kind == "hurt":
			break
	check_eq(p1.state_frame + 1, MovesetBuilder.DRIVE_IMPACT.startup, "first active frame")
	check_eq(p2.state_name(), "crumple", "midscreen hit crumples")


func test_drive_impact_armor_absorbs_two_hits() -> void:
	var sim := adjacent_sim()
	var p1 := sim.fighters[0]
	play(sim, "5HP+HK", "", 4)
	var jab := HitDef.from_dict({"damage": 300, "hitstop": 7, "strength": 0})
	for i in 2:
		Combat.apply_hit(sim, sim.fighters[1].x, -1, p1, jab, false, sim.fighters[1])
		check_eq(p1.state_name(), "drive_impact", "hit %d absorbed" % (i + 1))
	Combat.apply_hit(sim, sim.fighters[1].x, -1, p1, jab, false, sim.fighters[1])
	check_eq(p1.state_name(), "hit_stand", "third hit breaks the armor")
	sim = adjacent_sim()
	play(sim, "5x10,5HP+HK", "5x14,5LP+LK", 10)
	check_eq(sim.fighters[0].state_name(), "thrown", "throws beat the armor")


func test_drive_impact_on_block() -> void:
	var sim := adjacent_sim()
	play(sim, "5HP+HK", "4")
	var adv := advantage(sim, 0, InputBits.RIGHT)
	check_eq(adv, MovesetBuilder.DRIVE_IMPACT.on_block, "Drive Impact on block")
	check_eq(Gauges.value(sim.fighters[1], Gauges.DRIVE), 60000 - MovesetBuilder.DRIVE_IMPACT.drive_block,
		"blocking drains half a bar")


func test_drive_impact_splats_in_the_corner() -> void:
	var sim := _wall_sim()
	play(sim, "5HP+HK", "", 80)
	check_eq(sim.fighters[1].state_name(), "wall_splat", "corner Drive Impact splats")
	check(sim.fighters[0].sd().ctrl, "attacker recovered while the opponent is still on the wall")
	play(sim, "5HP", "", 12)
	check_eq(sim.fighters[1].combo_hits, 2, "follow-up after the splat")


func test_burnout_block_at_the_wall_stuns() -> void:
	var sim := _wall_sim()
	var p2 := sim.fighters[1]
	p2.gauges[Gauges.DRIVE] = 0
	p2.burnout = 1
	play(sim, "5HP+HK", "4x40")
	check_eq(p2.state_name(), "dizzy", "burnout opponent blocking Drive Impact at the wall is stunned")
	sim = adjacent_sim()
	p2 = sim.fighters[1]
	p2.gauges[Gauges.DRIVE] = 0
	p2.burnout = 1
	play(sim, "5HP+HK", "4x40")
	check(p2.state_name() != "dizzy", "midscreen it is just blocked")


func test_drive_reversal_from_blockstun() -> void:
	var sim := adjacent_sim()
	var p1 := sim.fighters[0]
	var p2 := sim.fighters[1]
	p2.health = 300
	play(sim, "4x21", "5HP", 0)
	var drive := Gauges.value(p1, Gauges.DRIVE)
	play(sim, "6HP+HK", "", 0)
	check_eq(p1.state_name(), "drive_reversal", "6HP+HK in blockstun is Drive Reversal")
	check_eq(Gauges.value(p1, Gauges.DRIVE), drive - MovesetBuilder.DRIVE_REVERSAL.cost, "costs two bars")
	play(sim, "5x40", "", 0)
	check(p2.health < 300, "Drive Reversal hits")
	check_eq(p2.health, 1, "Drive Reversal cannot KO")
	sim = adjacent_sim()
	play(sim, "6HP+HK")
	check(sim.fighters[0].state_name() != "drive_reversal", "not outside blockstun")


func test_late_heavy_kick_upgrades_to_drive_impact() -> void:
	var sim := adjacent_sim()
	play(sim, "5HP,5HP+HK")
	check_eq(sim.fighters[0].state_name(), "drive_impact", "HK one frame after HP upgrades to Drive Impact")
	sim = adjacent_sim()
	play(sim, "5HP,5x4,5HP+HK")
	check_eq(sim.fighters[0].state_name(), "5hp", "too late: stays 5HP")


func test_parry_costs_and_drains_while_held() -> void:
	var sim := adjacent_sim(400)
	var p1 := sim.fighters[0]
	play(sim, "5MP+MKx30")
	check_eq(p1.state_name(), "parry", "MP+MK held is Drive Parry")
	var drive := Gauges.value(p1, Gauges.DRIVE)
	check(drive < 60000 - CommonStates.PARRY_COST and drive > 50000, "activation cost plus drain (%d)" % drive)
	play(sim, "5x3")
	check_eq(p1.state_name(), "parry_end", "release ends the parry")
	sim = adjacent_sim(400)
	sim.fighters[0].gauges[Gauges.DRIVE] = 0
	sim.fighters[0].burnout = 1
	play(sim, "5MP+MKx5")
	check(sim.fighters[0].state_name() != "parry", "no parry in burnout")


func test_parry_absorbs_strikes_projectiles_and_impact() -> void:
	var sim := adjacent_sim()
	var p2 := sim.fighters[1]
	play(sim, "5x10,5HP", "5MP+MKx40", 0)
	check_eq(p2.health, DUMMY.max_health, "parried 5HP does no damage")
	check_eq(p2.state_name(), "parry", "still parrying")
	sim = adjacent_sim(300)
	p2 = sim.fighters[1]
	play(sim, "2,3,6LP", "5MP+MKx60", 0)
	check_eq(p2.health, DUMMY.max_health, "parried fireball")
	sim = adjacent_sim()
	p2 = sim.fighters[1]
	play(sim, "5HP+HK", "5MP+MKx60", 0)
	check_eq(p2.health, DUMMY.max_health, "parried Drive Impact")
	check(p2.state_name() != "crumple", "no crumple")


func test_perfect_parry_freezes_and_halves_the_punish() -> void:
	var sim := adjacent_sim()
	var p1 := sim.fighters[0]
	var p2 := sim.fighters[1]
	play(sim, "5HP", "5x7,5MP+MKx2", 0)
	check_eq(p1.pp_scale, 1, "perfect parry marks the attacker")
	check(p1.hitstop >= Combat.PERFECT_PARRY_FREEZE - 2, "attacker frozen (%d)" % p1.hitstop)
	check_eq(p2.state_name(), "stand", "parrier acts immediately")
	play(sim, "5", "5HP", 12)
	var hit: int = 800 * Combat.PERFECT_PARRY_PCT / 100 * Combat.COUNTER_DAMAGE_PCT / 100
	check_eq(p1.health, DUMMY.max_health - hit, "punish after perfect parry deals 50%")


func test_throwing_a_parry_is_a_punish_counter() -> void:
	var sim := adjacent_sim()
	play(sim, "5x5,5LP+LK", "5MP+MKx60", 0)
	play(sim, "5", "", 60)
	check_eq(sim.fighters[1].health, DUMMY.max_health - 1200 * Combat.PUNISH_THROW_DAMAGE_PCT / 100, "throw beats parry at 170%")
