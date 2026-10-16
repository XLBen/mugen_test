extends TestCase
## 三个角色的差异：体格属性、各自普攻帧数据、招牌机制。


func _frame_table(def: FighterDef) -> Dictionary:
	var builder: MovesetBuilder = def.moveset.new()
	builder.data()
	return builder.frame_table


func _gap(def: FighterDef) -> int:
	return (def.push_half_width + DUMMY.push_half_width) / SimConst.UNITS_PER_PX + 4


func _press(normal: String) -> String:
	return normal.substr(0, 1) + normal.substr(1).to_upper()


func max_combo(sim: MatchSim, p1_script: String, p2_script := "", extra := 0) -> int:
	var a := InputScript.parse(p1_script)
	var b := InputScript.parse(p2_script, true)
	var best := 0
	for i in maxi(a.size(), b.size()) + extra:
		sim.step([a[i] if i < a.size() else 0, b[i] if i < b.size() else 0])
		best = maxi(best, sim.fighters[1].combo_hits)
	return best


# ---------------------------------------------------------------- 通用

func test_attributes_differ() -> void:
	check(KAGURA.max_health < MIO.max_health and MIO.max_health < VOLK.max_health, "health: Kagura < Mio < Volk")
	var dist := {}
	for def: FighterDef in [KAGURA, VOLK, MIO]:
		var sim := char_sim(def, DUMMY, 600)
		var x0 := sim.fighters[0].x
		hold(sim, InputBits.RIGHT, 0, 30)
		dist[def.display_name] = sim.fighters[0].x - x0
	check(dist.Kagura > dist.Mio and dist.Mio > dist.Volk, "walk speed: Kagura > Mio > Volk (%s)" % str(dist))


func test_every_ground_normal_matches_its_frame_data() -> void:
	for def: FighterDef in [KAGURA, VOLK, MIO]:
		var table := _frame_table(def)
		for normal: String in table:
			if table[normal].knockdown or normal.begins_with("j_"):
				continue
			var low := normal in ["2lk", "2mk", "2hk"]
			var crouch := normal.begins_with("2")
			var sim := char_sim(def, DUMMY, _gap(def))
			play(sim, _press(normal))
			var adv := advantage(sim, InputBits.DOWN if crouch else 0, 0)
			check_eq(adv, table[normal].on_hit, "%s %s on hit" % [def.display_name, normal])
			sim = char_sim(def, DUMMY, _gap(def))
			var guard := InputBits.RIGHT | (InputBits.DOWN if low else 0)
			play(sim, _press(normal), "1" if low else "4")
			adv = advantage(sim, InputBits.DOWN if crouch else 0, guard)
			check_eq(adv, table[normal].on_block, "%s %s on block" % [def.display_name, normal])


func test_unique_command_lists() -> void:
	var names := {}
	for def: FighterDef in [KAGURA, VOLK, MIO]:
		var m := Moveset.for_def(def)
		names[def.display_name] = m.commands.map(func(c: Command) -> String: return c.state)
	check("slash_h" in names.Kagura and not "slash_h" in names.Volk, "Kagura has slashes")
	check("crush_l" in names.Volk and not "crush_l" in names.Mio, "Volk has command grabs")
	check("seal_l" in names.Mio and not "seal_l" in names.Kagura, "Mio has seals")
	check(not "fireball_l" in names.Kagura and not "fireball_l" in names.Volk, "no shoto fireballs on Kagura / Volk")


func test_random_play_all_pairings() -> void:
	var defs := [KAGURA, VOLK, MIO]
	var seed_value := 11
	for a: FighterDef in defs:
		for b: FighterDef in defs:
			seed_value += 1
			var inputs := random_inputs(seed_value, 1500)
			var s1 := MatchSim.new(STAGE, a, b)
			var s2 := MatchSim.new(STAGE, a, b)
			check(run(s1, inputs) == run(s2, inputs), "%s vs %s deterministic" % [a.display_name, b.display_name])
			for f in s1.fighters:
				check(f.health >= 0 and f.y >= 0, "%s vs %s sane state" % [a.display_name, b.display_name])


# ---------------------------------------------------------------- Kagura

func test_kagura_gatling() -> void:
	var sim := char_sim(KAGURA, DUMMY, _gap(KAGURA))
	var best := max_combo(sim, "5LP,5x5,5MP,5x8,5HP", "", 40)
	check_eq(best, 3, "5LP > 5MP > 5HP gatling")


func test_kagura_step_passes_through() -> void:
	var sim := char_sim(KAGURA, DUMMY, _gap(KAGURA))
	play(sim, "2,1,4LP", "", 30)
	check(sim.fighters[0].x > sim.fighters[1].x, "shadow step ends behind the opponent")
	check_eq(sim.fighters[0].facing, -1, "and turns around")


func test_kagura_dive_is_overhead() -> void:
	var sim := char_sim(KAGURA, DUMMY, 90)
	var k := sim.fighters[0]
	k.set_state("air")
	k.y = 12000
	k.vy = 0
	play(sim, "2,1,4LK", "1x40")
	check(sim.fighters[1].health < DUMMY.max_health, "crouch block loses to the dive")


func test_kagura_slash_travels() -> void:
	var sim := char_sim(KAGURA, DUMMY, 240)
	play(sim, "2,3,6HK", "", 40)
	check(sim.fighters[1].is_in(["hit_air", "knockdown"]), "HK slash reaches far and knocks down")


# ---------------------------------------------------------------- Volk

func test_volk_360_grab() -> void:
	var sim := char_sim(VOLK, DUMMY, _gap(VOLK))
	play(sim, "6,2,4,8LP", "", 2)
	check_eq(sim.fighters[1].state_name(), "thrown", "360 + LP grabs")
	play(sim, "5", "", 80)
	check_eq(sim.fighters[1].health, DUMMY.max_health - 2000, "command grab damage")


func test_volk_360_through_prejump() -> void:
	var sim := char_sim(VOLK, DUMMY, _gap(VOLK))
	play(sim, "6,2,4,8,8LP", "", 2)
	check_eq(sim.fighters[1].state_name(), "thrown", "special comes out of prejump")
	check_eq(sim.fighters[0].y, 0, "Volk never left the ground")


func test_volk_grab_is_untechable() -> void:
	var sim := char_sim(VOLK, DUMMY, _gap(VOLK))
	play(sim, "6,2,4,8HP", "5x6,5LP+LK", 80)
	check_eq(sim.fighters[1].health, DUMMY.max_health - 2400, "command grab cannot be teched")


func test_volk_grab_range_by_strength() -> void:
	var sim := char_sim(VOLK, DUMMY, 125)
	play(sim, "6,2,4,8LP", "", 4)
	check_eq(sim.fighters[1].state_name(), "thrown", "LP version has the most range")
	sim = char_sim(VOLK, DUMMY, 125)
	play(sim, "6,2,4,8HP", "", 4)
	check(sim.fighters[1].state_name() != "thrown", "HP version is shorter")


func test_volk_armor_absorbs_a_hit() -> void:
	var sim := char_sim(VOLK, DUMMY, _gap(VOLK))
	play(sim, "2,1,4LP", "5,5,5,5LP", 30)
	check_eq(sim.fighters[0].health, VOLK.max_health - 300, "armor took the jab's damage")
	check(sim.fighters[1].is_in(["hit_air", "knockdown"]), "charge still connects")


# ---------------------------------------------------------------- Mio

func test_mio_seal_arms_then_triggers() -> void:
	var sim := char_sim(MIO, DUMMY, 160)
	play(sim, "2,1,4LP", "", 20)
	check_eq(sim.projectiles.size(), 1, "seal placed")
	check_eq(sim.fighters[1].health, DUMMY.max_health, "not armed yet")
	play(sim, "5", "", 40)
	check(sim.fighters[1].health < DUMMY.max_health, "armed seal launches")


func test_mio_air_charm_goes_down() -> void:
	var sim := char_sim(MIO, DUMMY, 200)
	var m := sim.fighters[0]
	m.set_state("air")
	m.y = 15000
	m.vy = 0
	play(sim, "2,3,6LP", "", 60)
	check(sim.fighters[1].health < DUMMY.max_health, "diagonal charm hits a grounded opponent")


func test_mio_storm_multi_hit() -> void:
	var sim := char_sim(MIO, DUMMY, 150)
	sim.fighters[0].gauges[Gauges.SUPER] = 1000
	var best := max_combo(sim, "2,3,6,2,3,6LP", "", 120)
	check(best >= 3, "super hits several times (%d)" % best)


func test_mio_long_pokes() -> void:
	var sim := char_sim(MIO, DUMMY, 140)
	play(sim, "5HP", "", 15)
	check(sim.fighters[1].health < DUMMY.max_health, "Mio 5HP reaches 140px")
	sim = char_sim(KAGURA, DUMMY, 140)
	play(sim, "5HP", "", 15)
	check_eq(sim.fighters[1].health, DUMMY.max_health, "Kagura 5HP does not")
