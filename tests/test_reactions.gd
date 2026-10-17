extends TestCase
## 受击反应：崩溃、贴墙 / 弹墙、倒地时长、后滚起身、新状态的动画回退。


## 让 P1 用给定的命中数据打中 P2（不经过招式，直接结算）。
func _hit(sim: MatchSim, d: Dictionary) -> void:
	var hd := HitDef.from_dict(d)
	Combat.apply_hit(sim, sim.fighters[0].x, sim.fighters[0].facing, sim.fighters[1], hd, false, sim.fighters[0])


func _wall_sim() -> MatchSim:
	# P2 背靠右边舞台墙，P1 贴着它
	var sim := new_sim()
	var wall := STAGE.half_width - DUMMY.push_half_width
	sim.place(wall - 7500, wall)
	return sim


func test_crumple_allows_a_full_combo() -> void:
	var sim := adjacent_sim()
	var p2 := sim.fighters[1]
	_hit(sim, {"damage": 800, "effect": "crumple", "hitstop": 10})
	check_eq(p2.state_name(), "crumple", "crumple effect")
	play(sim, "5x20,5HP", "", 12)
	check_eq(p2.state_name(), "hit_stand", "a crumpled opponent is hit like a standing one")
	check_eq(p2.combo_hits, 2, "the combo continues")


func test_crumple_falls_down_untouched() -> void:
	var sim := adjacent_sim()
	var p2 := sim.fighters[1]
	_hit(sim, {"damage": 800, "effect": "crumple", "hitstop": 10})
	hold(sim, 0, 0, 10 + Combat.CRUMPLE_FRAMES + 2)
	check_eq(p2.state_name(), "knockdown", "crumple ends in a knockdown")


func test_wall_splat_in_the_corner() -> void:
	var sim := _wall_sim()
	var p2 := sim.fighters[1]
	_hit(sim, {"damage": 800, "push": 1200, "wall": "splat", "hitstop": 10})
	hold(sim, 0, 0, 2)
	check_eq(p2.state_name(), "wall_splat", "hit into the stage wall splats")
	play(sim, "5x8,5HP", "", 10)
	check_eq(p2.combo_hits, 2, "the splatted opponent can be hit again")
	check_eq(p2.state_name(), "hit_air", "follow-up knocks them off the wall")


func test_no_wall_splat_midscreen_or_twice() -> void:
	var sim := adjacent_sim()
	var p2 := sim.fighters[1]
	_hit(sim, {"damage": 800, "wall": "splat", "hitstop": 10})
	hold(sim, 0, 0, 20)
	check(p2.state_name() != "wall_splat", "no wall nearby, no splat")
	sim = _wall_sim()
	p2 = sim.fighters[1]
	p2.wall_used = 1
	p2.combo_hits = 1
	_hit(sim, {"damage": 800, "wall": "splat", "hitstop": 10})
	hold(sim, 0, 0, 2)
	check(p2.state_name() != "wall_splat", "only one wall hit per combo")


func test_wall_bounce_sends_them_back() -> void:
	var sim := _wall_sim()
	var p2 := sim.fighters[1]
	_hit(sim, {"damage": 800, "effect": "launch", "air_vx": 600, "air_vy": 600, "wall": "bounce", "hitstop": 10})
	hold(sim, 0, 0, 14)
	check_eq(p2.state_name(), "hit_air", "still airborne")
	check(p2.vx < 0, "bounced back toward the middle (vx %d)" % p2.vx)
	check_eq(p2.juggle, 0, "bounce resets the juggle count")


func test_down_frames_and_back_rise() -> void:
	var sim := adjacent_sim(200)
	var p2 := sim.fighters[1]
	_hit(sim, {"damage": 800, "effect": "knockdown", "down": 50, "hitstop": 10})
	var downed := -1
	for i in 200:
		sim.step([0, 0])
		if downed < 0 and p2.state_name() == "knockdown":
			downed = sim.frame
		if downed >= 0 and p2.state_name() != "knockdown":
			break
	check_eq(sim.frame - downed, 50, "lies down for the move's down frames")
	check_eq(p2.state_name(), "wakeup", "no input: normal rise")

	sim = adjacent_sim(200)
	p2 = sim.fighters[1]
	_hit(sim, {"damage": 800, "effect": "knockdown", "hitstop": 10})
	var x0 := p2.x
	play(sim, "", "4x90", 0)
	check(p2.x > x0 + 8000, "holding back rolls away (moved %d px)" % ((p2.x - x0) / 100))

	sim = adjacent_sim()
	play(sim, "5LP+LK", "5x10,4x90", 0)
	check(sim.fighters[1].hard_kd != 0, "throws are hard knockdowns")


func test_hard_knockdown_has_no_back_rise() -> void:
	var sim := adjacent_sim(200)
	var p2 := sim.fighters[1]
	_hit(sim, {"damage": 800, "effect": "knockdown", "hard_kd": true, "hitstop": 10})
	var rose := ""
	var a := InputScript.parse("4x120", true)
	for i in a.size():
		sim.step([0, a[i]])
		if p2.state_name() in ["wakeup", "wakeup_back"]:
			rose = p2.state_name()
			break
	check_eq(rose, "wakeup", "hard knockdown: normal rise even when holding back")


func test_new_states_fall_back_to_existing_animations() -> void:
	var m := Moveset.build(CommonStates.states(), {})
	var hurt := {"hurt": [[-20, 0, 40, 100]]}
	var lib := {"wakeup": AnimData.from_meta({"frames": [["a", 4, hurt, ""], ["b", 4, hurt, ""]]})}
	m.apply_anim_boxes(lib)
	var s: StateDef = m.states[m.id("wakeup_back")]
	check(s.anim_data == lib.wakeup, "wakeup_back borrows the wakeup animation")
	check("wakeup" in AnimClock.candidates(s, 0), "view tries the fallback too")
