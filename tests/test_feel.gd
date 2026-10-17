extends TestCase
## 手感相关：越身、近距离防御范围、快速点按不丢。


func test_forward_jump_crosses_up_a_close_opponent() -> void:
	var sim := adjacent_sim(80)
	play(sim, "9", "", 60)
	var p1 := sim.fighters[0]
	var p2 := sim.fighters[1]
	check(p1.x > p2.x, "close forward jump lands on the other side")
	check_eq(p1.facing, -1, "and faces back after landing")


func test_far_jump_does_not_cross() -> void:
	var sim := adjacent_sim(260)
	play(sim, "9", "", 60)
	check(sim.fighters[0].x < sim.fighters[1].x, "a jump from far away stays in front")


func test_proximity_guard_respects_reach() -> void:
	var sim := adjacent_sim(250)
	play(sim, "5LP", "4x3")
	check_eq(sim.fighters[1].state_name(), "walk_b", "a jab that cannot reach does not stop walking back")
	sim = adjacent_sim(140)
	play(sim, "5LP", "4x3")
	check_eq(sim.fighters[1].state_name(), "guard_stand", "a jab in range triggers proximity guard")


func test_quick_tap_between_ticks_is_kept() -> void:
	LocalInput.register_actions()
	LocalInput.read(0)
	var tap := InputEventAction.new()
	tap.action = LocalInput.action_name(0, 4)
	tap.pressed = true
	LocalInput.latch(tap)
	check(LocalInput.read(0) & InputBits.B0 != 0, "press-and-release before the tick still registers")
	check_eq(LocalInput.read(0) & InputBits.B0, 0, "latch clears after being read")
