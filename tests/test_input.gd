extends TestCase
## 指令识别：搓招、捷径、优先级、朝向翻转、缓冲。


func _far_sim() -> MatchSim:
	var sim := new_sim()
	sim.fighters[0].x = -40000
	sim.fighters[1].x = 40000
	sim.camera_x = 0
	return sim


func test_quarter_circle_forward() -> void:
	var sim := _far_sim()
	play(sim, "2,3,6LP")
	check_eq(sim.fighters[0].state_name(), "fireball_l", "236LP -> fireball")


func test_quarter_circle_back() -> void:
	var sim := _far_sim()
	play(sim, "2,1,4LK")
	check_eq(sim.fighters[0].state_name(), "rush", "214K -> rush")


func test_dragon_punch_and_shortcut() -> void:
	var sim := _far_sim()
	play(sim, "6,2,3HP")
	check_eq(sim.fighters[0].state_name(), "dp", "623P -> dp")
	sim = _far_sim()
	play(sim, "3,2,3HP")
	check_eq(sim.fighters[0].state_name(), "dp", "323P shortcut -> dp")


func test_dp_beats_fireball_priority() -> void:
	var sim := _far_sim()
	play(sim, "6,2,3,6LP")
	check_eq(sim.fighters[0].state_name(), "dp", "6236+P resolves to dp, not fireball")


func test_motion_gaps() -> void:
	var sim := _far_sim()
	play(sim, "2x2,3x2,6x2,5,5LP")
	check_eq(sim.fighters[0].state_name(), "fireball_l", "short pause before button is fine")
	sim = _far_sim()
	play(sim, "2,3,6,5x12,5LP")
	check_eq(sim.fighters[0].state_name(), "5lp", "button long after motion is just a normal")
	sim = _far_sim()
	play(sim, "2,5x12,3,6LP")
	check_eq(sim.fighters[0].state_name(), "5lp", "motion broken by long gap")


func test_motion_respects_facing() -> void:
	# P2 面朝左：物理上的 2,1,4 = 相对的 2,3,6
	var sim := _far_sim()
	play(sim, "", "2,3,6LP")
	check_eq(sim.fighters[1].state_name(), "fireball_l", "P2 fireball uses relative directions")


func test_stance_selects_normal() -> void:
	var sim := _far_sim()
	play(sim, "2MK")
	check_eq(sim.fighters[0].state_name(), "2mk", "down + MK -> crouching normal")
	sim = _far_sim()
	play(sim, "6MK")
	check_eq(sim.fighters[0].state_name(), "5mk", "forward + MK -> standing normal")


func test_button_buffer() -> void:
	# 收招中按下的键在恢复可行动的前几帧内仍然有效
	var sim := _far_sim()
	play(sim, "5HP")
	var total: int = sim.fighters[0].sd().total
	play(sim, "5x%d,5LP" % (total - 3))
	play(sim, "5x3")
	check_eq(sim.fighters[0].state_name(), "5lp", "buffered press comes out on first free frame")
	sim = _far_sim()
	play(sim, "5HP")
	play(sim, "5x%d,5LP" % (total - 9))
	play(sim, "5x9")
	check(sim.fighters[0].state_name() != "5lp", "press too early is dropped")


func test_one_fireball_at_a_time() -> void:
	var sim := _far_sim()
	play(sim, "2,3,6LP,5x50")
	check_eq(sim.projectiles.size(), 1, "fireball spawned")
	play(sim, "2,3,6LP")
	check(sim.fighters[0].state_name() != "fireball_l", "second fireball blocked while first is alive")


## 蓄力指令（引擎支持，目前的角色没有用到）：按住后 40 帧再按前。
func test_charge_motion() -> void:
	var m := Motion.preset("[4]6")
	var cases := [["4x45,6", true, "charged long enough"], ["4x20,6", false, "not charged long enough"],
		["4x45,5x15,6", false, "released too long before forward"], ["1x45,3", true, "diagonals count"]]
	for c: Array in cases:
		var sim := adjacent_sim(400)
		play(sim, c[0])
		check_eq(m.matches(sim.fighters[0], sim.frame), c[1], c[2])


## SF6 缓冲：提前 4 帧按的普攻在恢复的第一帧出来；冲刺和起身反击提前 7 帧也行。
func test_sf6_buffer_windows() -> void:
	var sim := _far_sim()
	play(sim, "5HP")
	var total: int = sim.fighters[0].sd().total
	play(sim, "5x%d,5LP" % (total - 5))
	play(sim, "5x6")
	check_eq(sim.fighters[0].state_name(), "5lp", "4 frames early still comes out")
	sim = _far_sim()
	play(sim, "5HP")
	play(sim, "5x%d,5LP" % (total - 6))
	play(sim, "5x7")
	check(sim.fighters[0].state_name() != "5lp", "5 frames early is too early")
	sim = _far_sim()
	play(sim, "5HP")
	play(sim, "5x%d,6,5,6" % (total - 9))
	play(sim, "5x8")
	check_eq(sim.fighters[0].state_name(), "dash_f", "dash input during recovery comes out")
	sim = _far_sim()
	var p1 := sim.fighters[0]
	p1.set_state("wakeup")
	play(sim, "5x10,6,2,3HP", "", 0)
	play(sim, "5x8")
	check_eq(p1.state_name(), "dp", "reversal DP buffered 7 frames before wakeup ends")
