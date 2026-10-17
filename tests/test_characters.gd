extends TestCase
## 三个角色的差异：体格属性、各自普攻帧数据、招牌机制。


func _frame_table(def: FighterDef) -> Dictionary:
	var builder: MovesetBuilder = def.moveset.new()
	builder.data()
	return builder.frame_table


func _gap(def: FighterDef) -> int:
	return (def.push_half_width + DUMMY.push_half_width) / SimConst.UNITS_PER_PX + 4


func m_lib(def: FighterDef) -> Dictionary:
	return AnimData.load_library(def.sprite_dir)


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
	for def: FighterDef in [KAGURA, VOLK, MIO]:
		check_eq(def.max_health, 10000, "%s health is the SF6 standard" % def.display_name)
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

func test_kagura_target_combo_replaces_gatlings() -> void:
	var sim := char_sim(KAGURA, DUMMY, _gap(KAGURA))
	check_eq(max_combo(sim, "5MP,5x8,5HP", "", 40), 2, "5MP > HP target combo")
	sim = char_sim(KAGURA, DUMMY, _gap(KAGURA))
	check_eq(max_combo(sim, "5LP,5x5,5MP", "", 40), 1, "no light-into-medium gatling (SF6)")


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
	var sim := char_sim(MIO, DUMMY, 175)
	play(sim, "5HP", "", 15)
	check(sim.fighters[1].health < DUMMY.max_health, "Mio 5HP (lunging thrust) reaches 175px")
	sim = char_sim(KAGURA, DUMMY, 175)
	play(sim, "5HP", "", 15)
	check_eq(sim.fighters[1].health, DUMMY.max_health, "Kagura 5HP does not")


# ---------------------------------------------------------------- 画面与判定同源

func test_attack_boxes_come_from_animation_frames() -> void:
	for def: FighterDef in [KAGURA, VOLK, MIO]:
		var m := Moveset.for_def(def)
		for s in m.states:
			if s.hitboxes.is_empty() or s.anim_data == null or s.keep_boxes or s.anim_data != m_lib(def).get(s.anim):
				continue
			var anim := s.anim_data
			if not anim.has_phase(AnimData.Phase.ACTIVE):
				continue
			for h: Dictionary in s.hitboxes:
				var drawn := []
				for t in range(h.from, h.to + 1):
					var i := anim.index_at_time(AnimClock.attack_tick(s, anim, t))
					check_eq(anim.phase[i], AnimData.Phase.ACTIVE, "%s %s f%d: active frame shows an active pose" % [
						def.display_name, s.name, t])
					for b in anim.hit[i]:
						if not drawn.has(b):
							drawn.append(b)
				check(not drawn.is_empty(), "%s %s: active frames have drawn hitboxes" % [def.display_name, s.name])
				drawn = Moveset._capped(drawn, s.reach_cap)
				for b in h.boxes:
					check(drawn.has(b), "%s %s: hitbox comes from the drawn frames" % [def.display_name, s.name])


## 攻击动画按阶段对齐：发生段在持续帧之前播完，收招段在持续帧之后。
func test_attack_animation_phases_line_up() -> void:
	var s := StateDef.build("x", {"type": "S", "kind": "normal", "total": 20,
		"hitboxes": [{"active": [6, 7], "boxes": [[0, 0, 10, 10]], "hit": {}}]})
	var anim := AnimData.from_meta({"frames": [["a", 3, {}, "s"], ["b", 3, {}, "s"], ["c", 2, {"hit": [[0, 0, 9, 9]]}, "a"],
		["d", 4, {}, "r"], ["e", 4, {}, "r"], ["f", 4, {}, "r"]]})
	var shown := []
	for t in 20:
		shown.append(anim.index_at_time(AnimClock.attack_tick(s, anim, t)))
	check_eq(shown.slice(0, 5), [0, 0, 0, 1, 1], "startup frames spread over the 5 startup frames")
	check_eq(shown.slice(5, 7), [2, 2], "active frames show the active pose")
	check_eq(shown[7], 3, "recovery starts right after the active frames")
	check_eq(shown[19], 5, "recovery reaches the last pose (12 ticks fit in 12 frames)")


## 预备动作比发生帧短：按原速播到预备姿势，停在那里等出手；比 2 倍速还长：跳过开头，只播后面一段。
func test_startup_holds_or_skips() -> void:
	var s := StateDef.build("x", {"type": "S", "kind": "normal", "total": 20,
		"hitboxes": [{"active": [6, 7], "boxes": [[0, 0, 10, 10]], "hit": {}}]})
	var short := AnimData.from_meta({"frames": [["a", 1, {}, "s"], ["b", 1, {}, "s"], ["c", 2, {"hit": [[0, 0, 9, 9]]}, "a"],
		["d", 4, {}, "r"]]})
	var shown := []
	for t in 5:
		shown.append(short.index_at_time(AnimClock.attack_tick(s, short, t)))
	check_eq(shown, [0, 1, 1, 1, 1], "short windup reaches the ready pose and holds it")
	var long := AnimData.from_meta({"frames": [["a", 20, {}, "s"], ["b", 5, {}, "s"], ["c", 5, {}, "s"],
		["d", 2, {"hit": [[0, 0, 9, 9]]}, "a"], ["e", 4, {}, "r"]]})
	shown = []
	for t in 5:
		shown.append(long.index_at_time(AnimClock.attack_tick(s, long, t)))
	check_eq(shown, [1, 1, 1, 2, 2], "a windup longer than 2x skips its beginning instead of fast-forwarding")


## 超杀暂停期间预备动作照播（暂停帧数算进发生段），暂停结束后接着播。
func test_super_freeze_plays_the_windup() -> void:
	var s := StateDef.build("x", {"type": "S", "kind": "super", "total": 40, "events": [{"frame": 1, "freeze": 30}],
		"hitboxes": [{"active": [6, 7], "boxes": [[0, 0, 10, 10]], "hit": {}}]})
	check_eq(s.freeze_len, 30, "freeze before the first active frame counts")
	var anim := AnimData.from_meta({"frames": [["a", 10, {}, "s"], ["b", 10, {}, "s"], ["c", 10, {}, "s"],
		["d", 2, {"hit": [[0, 0, 9, 9]]}, "a"], ["e", 4, {}, "r"]]})
	check_eq(anim.index_at_time(AnimClock.attack_tick(s, anim, 0, 0)), 0, "starts at the first pose")
	check_eq(anim.index_at_time(AnimClock.attack_tick(s, anim, 0, 15)), 1, "halfway through the freeze")
	check_eq(anim.index_at_time(AnimClock.attack_tick(s, anim, 4, 30)), 2, "after the freeze, last windup pose")
	var sim := char_sim(KAGURA, DUMMY, 150)
	var k := sim.fighters[0]
	k.gauges[Gauges.SUPER] = Gauges.DEFS[Gauges.SUPER].max
	play(sim, "2,3,6,2,3,6HK", "", 3)
	check(sim.freeze > 0, "super freeze started")
	var before := k.held
	sim.step([0, 0])
	check_eq(k.held, before + 1, "held counts frozen frames of the super")


## 收招动画比收招帧短：放慢最多 1.5 倍，不会一下播完然后定住。
func test_short_recovery_is_stretched() -> void:
	var s := StateDef.build("x", {"type": "S", "kind": "normal", "total": 20,
		"hitboxes": [{"active": [2, 2], "boxes": [[0, 0, 10, 10]], "hit": {}}]})
	var anim := AnimData.from_meta({"frames": [["a", 1, {}, "s"], ["b", 1, {"hit": [[0, 0, 9, 9]]}, "a"],
		["c", 4, {}, "r"], ["d", 4, {}, "r"]]})
	# 收招 18 帧，动画 8 刻：放慢到 12 帧播完
	check_eq(anim.index_at_time(AnimClock.attack_tick(s, anim, 2 + 5)), 2, "still on the first recovery pose")
	check_eq(anim.index_at_time(AnimClock.attack_tick(s, anim, 2 + 7)), 3, "second recovery pose")


## 踏步：step [第几帧, 到第几帧, 像素] 先快后慢地走完给定距离。
func test_step_moves_forward() -> void:
	var sim := char_sim(KAGURA, DUMMY, 400)
	var k := sim.fighters[0]
	var x0 := k.x
	play(sim, "2HK", "", 30)
	var moved := (k.x - x0) / SimConst.UNITS_PER_PX
	check(moved >= 75 and moved <= 82, "Kagura 2HK slides about 80px (%d)" % moved)


func test_hurtboxes_follow_the_pose() -> void:
	var sim := char_sim(KAGURA, DUMMY, 400)
	var k := sim.fighters[0]
	var standing := k.hurtboxes()
	k.set_state("knockdown")
	var lying := k.hurtboxes()
	var top_standing := 0
	var top_lying := 0
	for b: PackedInt32Array in standing:
		top_standing = maxi(top_standing, b[3])
	for b: PackedInt32Array in lying:
		top_lying = maxi(top_lying, b[3])
	check(top_lying < top_standing / 2, "lying hurtboxes are low (%d vs %d)" % [top_lying, top_standing])


## 本地导入的人物（local_assets，不在仓库里；没有时跳过）：每个打击招式的动画都有攻击判定帧，持续帧显示出招姿势。
func test_imported_attacks_have_drawn_hits() -> void:
	var training: GDScript = load("res://scenes/training.gd")
	for def: FighterDef in training.local_fighters():
		var m := Moveset.for_def(def)
		for s in m.states:
			if s.hitboxes.is_empty() or s.kind == "throw":
				continue
			var anim := s.anim_data
			check(anim != null and anim.has_phase(AnimData.Phase.ACTIVE) or s.kind == "super",
				"%s %s: animation shows the strike" % [def.display_name, s.name])


# ---------------------------------------------------------------- 指令普攻 / 目标连段 / 后投 / 升龙强度

func test_command_normal_overhead() -> void:
	var sim := char_sim(KAGURA, DUMMY, _gap(KAGURA))
	play(sim, "6MP")
	check_eq(sim.fighters[0].state_name(), "6mp", "forward + MP is the command normal")
	sim = char_sim(KAGURA, DUMMY, _gap(KAGURA))
	play(sim, "6MP", "1x30")
	check(sim.fighters[1].health < DUMMY.max_health, "6MP overhead beats a crouching block")
	sim = char_sim(KAGURA, DUMMY, _gap(KAGURA))
	play(sim, "6MP", "4x30")
	check_eq(sim.fighters[1].health, DUMMY.max_health, "standing block stops it")
	sim = char_sim(KAGURA, DUMMY, _gap(KAGURA))
	play(sim, "6LP,6LP+LK")
	check(sim.fighters[1].is_in(["thrown"]) or sim.fighters[0].state_name() == "throw", "forward LP then LK still throws")


func test_back_throw_switches_sides() -> void:
	var sim := adjacent_sim()
	var x1 := sim.fighters[0].x
	play(sim, "4LP+LK", "", 60)
	check(sim.fighters[1].x < x1, "back throw lands the opponent behind (x %d vs %d)" % [sim.fighters[1].x, x1])
	check(sim.fighters[1].health < DUMMY.max_health, "back throw deals damage")


func test_light_kicks_chain() -> void:
	for def: FighterDef in [VOLK, MIO]:
		var sim := char_sim(def, DUMMY, _gap(def))
		check_eq(max_combo(sim, "2LK,5x5,2LP", "", 30), 2, "%s 2LK chains into 2LP" % def.display_name)


func test_dp_strengths_differ() -> void:
	var m := Moveset.for_def(KAGURA)
	var l: StateDef = m.states[m.id("rising_l")]
	var h: StateDef = m.states[m.id("rising_h")]
	check(not l.is_invuln(1, true), "light DP is not throw invulnerable")
	check(h.is_invuln(6, false) and not l.is_invuln(6, false), "heavy DP has longer invulnerability")
	var sim := char_sim(KAGURA, DUMMY, 400)
	play(sim, "6,2,3LK", "", 20)
	var low := sim.fighters[0].y
	sim = char_sim(KAGURA, DUMMY, 400)
	play(sim, "6,2,3HK", "", 20)
	check(sim.fighters[0].y > low, "heavy DP rises higher")


func test_kagura_step_follow_up_turns_around() -> void:
	var sim := char_sim(KAGURA, DUMMY, _gap(KAGURA))
	play(sim, "2,1,4LP,5x6,5LP", "", 20)
	check_eq(sim.fighters[0].facing, -1, "follow-up faces the opponent after passing through")
	check(sim.fighters[1].health < DUMMY.max_health, "shadow slash hits from behind")
	sim = char_sim(KAGURA, DUMMY, _gap(KAGURA))
	play(sim, "2LK,5x4,2LP", "", 20)
	check(sim.fighters[0].state_name() != "step_slash", "the follow-up only comes out of the step")


func test_kagura_new_specials() -> void:
	for script: String in ["2,3,6LP", "4,2,1LK", "2,3,6LP+MP", "4,2,1LK+MK"]:
		var sim := char_sim(KAGURA, DUMMY, _gap(KAGURA))
		play(sim, script, "", 40)
		check(sim.fighters[1].health < DUMMY.max_health, "%s hits" % script)


func test_volk_new_specials() -> void:
	for script: String in ["2,3,6HP", "2,1,4HK", "2,5,2HP", "2,3,6LP+MP", "6,2,3LP+MP"]:
		var sim := char_sim(VOLK, DUMMY, _gap(VOLK))
		play(sim, script, "", 50)
		check(sim.fighters[1].health < DUMMY.max_health, "%s hits" % script)
	var sim := char_sim(VOLK, DUMMY, _gap(VOLK))
	play(sim, "2,1,4HK", "4x40", 0)
	check(sim.fighters[1].health < DUMMY.max_health, "214K sweep is low (beats standing block)")


func test_mio_teleport() -> void:
	var sim := char_sim(MIO, DUMMY, 300)
	play(sim, "2,1,4MK", "", 40)
	check(sim.fighters[0].x > sim.fighters[1].x, "MK teleport appears behind the opponent")
	check_eq(sim.fighters[0].facing, -1, "and faces them")
	sim = char_sim(MIO, DUMMY, 300)
	play(sim, "2,1,4LK", "", 40)
	check(sim.fighters[0].x < sim.fighters[1].x and sim.fighters[1].x - sim.fighters[0].x < 15000,
		"LK teleport appears in front, close")


func test_mio_new_specials() -> void:
	var sim := char_sim(MIO, DUMMY, _gap(MIO))
	play(sim, "2,3,6LK", "4x40", 0)
	check(sim.fighters[1].health < DUMMY.max_health, "236K slide is low")
	sim = char_sim(MIO, DUMMY, 200)
	play(sim, "2,5,2HP", "", 0)
	play(sim, "5x14")
	var up := false
	for p in sim.projectiles:
		up = up or p.vy > 0
	check(up, "22P throws a key upward")
	sim = char_sim(MIO, DUMMY, 250)
	play(sim, "9x12,2,1,4LP", "", 2)
	play(sim, "5x14")
	check_eq(sim.projectiles.size(), 2, "air 214P throws two keys")
