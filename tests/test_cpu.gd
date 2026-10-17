extends TestCase
## 电脑对手：确定性、防御水平随等级变化、确反、能打完整场、能打出连段。


func _step(sim: MatchSim, cpus: Array, fixed := [0, 0]) -> void:
	var inp: Array[int] = [fixed[0], fixed[1]]
	for i in 2:
		if cpus[i] != null:
			inp[i] = cpus[i].inputs(sim)
	sim.step(inp)


func test_cpu_vs_cpu_is_deterministic() -> void:
	for seed_value in [3, 17, 42]:
		var hashes := []
		for run_i in 2:
			var sim := MatchSim.new(STAGE, KAGURA, VOLK)
			var cpus := [CpuPlayer.new(0, 8, seed_value), CpuPlayer.new(1, 5, seed_value + 9)]
			var trail: Array[int] = []
			for i in 2400:
				_step(sim, cpus)
				if i % 60 == 0:
					trail.append(sim.state_hash())
			hashes.append(trail)
			if run_i == 0:
				var lost := KAGURA.max_health - sim.fighters[0].health + VOLK.max_health - sim.fighters[1].health
				check(lost > 0, "seed %d: the CPUs actually fight" % seed_value)
				for f in sim.fighters:
					check(f.health >= 0 and f.health <= f.def.max_health, "health stays in range")
		check(hashes[0] == hashes[1], "seed %d: same seed, same match" % seed_value)


## 对手反复上前出 2MP：高等级的电脑大多能防住，低等级的大多挨打。
func _block_rate(level: int) -> float:
	var sim := adjacent_sim(140)
	var cpu := CpuPlayer.new(1, level, 5)
	cpu.p.aggro = 0.0 # 只看防守
	cpu.p.throw = 0.0
	var script := InputScript.parse("6x16,2MP,5x14")
	var blocked := 0
	var hit := 0
	for i in 1800:
		sim.step([script[i % script.size()], cpu.inputs(sim)])
		for e in sim.events:
			if e.get("target", -1) == 1:
				if e.type in ["block", "parry", "perfect_parry"]:
					blocked += 1
				elif e.type == "hit":
					hit += 1
	return blocked / maxf(blocked + hit, 1.0)


func test_cpu_block_skill_scales_with_level() -> void:
	var high := _block_rate(8)
	var low := _block_rate(1)
	check(high >= 0.7, "level 8 blocks most pokes (%.2f)" % high)
	check(low < 0.4, "level 1 gets hit a lot (%.2f)" % low)


func test_cpu_punishes_a_whiffed_dragon_punch() -> void:
	var hits := 0
	for seed_value in [1, 2, 3]:
		var sim := adjacent_sim(200)
		var cpu := CpuPlayer.new(1, 8, seed_value)
		var script := InputScript.parse("6,2,3HP")
		for i in 120:
			sim.step([script[i] if i < script.size() else 0, cpu.inputs(sim)])
		if sim.fighters[0].health < DUMMY.max_health:
			hits += 1
	check(hits >= 2, "level 8 punishes the whiffed DP (%d / 3)" % hits)


func test_cpu_plays_a_whole_match() -> void:
	var sim := MatchSim.new(STAGE, MIO, KAGURA)
	sim.versus = true
	sim.training = false
	sim.reset()
	var cpus := [CpuPlayer.new(0, 7, 11), CpuPlayer.new(1, 7, 12)]
	for i in 3 * 99 * 60 + 2000:
		_step(sim, cpus)
		if sim.round_state == MatchSim.Round.MATCH_OVER:
			break
	check_eq(sim.round_state, MatchSim.Round.MATCH_OVER, "CPU vs CPU reaches the end of the match")


func test_cpu_lands_combos_with_every_character() -> void:
	for def: FighterDef in [KAGURA, VOLK, MIO]:
		var sim := char_sim(def, DUMMY, 200)
		var cpu := CpuPlayer.new(0, 8, 7)
		var best := 0
		for i in 1500:
			sim.step([cpu.inputs(sim), 0])
			best = maxi(best, sim.fighters[1].combo_hits)
		check(best >= 2, "%s CPU lands a combo on a standing dummy (best %d)" % [def.display_name, best])
