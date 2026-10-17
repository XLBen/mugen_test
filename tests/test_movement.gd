extends TestCase
## 移动、跳跃、墙与推挤（M1）。

const U := InputBits.UP
const D := InputBits.DOWN
const L := InputBits.LEFT
const R := InputBits.RIGHT


func test_walk() -> void:
	var sim := new_sim()
	var p1 := sim.fighters[0]
	var x0 := p1.x
	hold(sim, R, 0, 10)
	check_eq(p1.x, x0 + 10 * DUMMY.walk_forward_speed, "walk forward distance")
	check_eq(p1.state_name(), "walk_f", "walk forward state")
	var x1 := p1.x
	hold(sim, L, 0, 10)
	check_eq(p1.x, x1 - 10 * DUMMY.walk_back_speed, "walk back distance")
	hold(sim, D, 0, 1)
	check_eq(p1.state_name(), "crouch", "crouch")


func test_neutral_jump() -> void:
	var sim := new_sim()
	var p1 := sim.fighters[0]
	var x0 := p1.x
	hold(sim, U, 0, 1)
	check_eq(p1.state_name(), "prejump", "prejump entered")
	hold(sim, 0, 0, DUMMY.prejump_frames - 1)
	check(p1.state_name() == "prejump" and p1.y == 0, "still grounded during prejump")
	hold(sim, 0, 0, 1)
	check(p1.state_name() == "air" and p1.y > 0, "airborne after prejump")
	var air_frames := 0
	while p1.state_name() == "air" and air_frames < 200:
		hold(sim, 0, 0, 1)
		air_frames += 1
	check_eq(p1.state_name(), "landing", "landing after jump")
	check(air_frames > 30 and air_frames < 60, "jump duration plausible (%d)" % air_frames)
	check_eq(p1.x, x0, "neutral jump returns to same x")
	hold(sim, 0, 0, DUMMY.landing_frames)
	check_eq(p1.state_name(), "stand", "stand after landing recovery")


func test_walk_back_stops_at_screen_wall() -> void:
	var sim := new_sim()
	var p2_x := sim.fighters[1].x
	hold(sim, L, 0, 600)
	var p1 := sim.fighters[0]
	check_eq(sim.fighters[1].x, p2_x, "idle opponent must not be dragged")
	check_eq(p1.push_left(), sim.screen_wall_left(), "p1 stops exactly at screen wall")
	check(sim.screen_wall_left() > -STAGE.half_width, "screen wall is not the stage edge here")


func test_push_into_corner() -> void:
	var sim := new_sim()
	hold(sim, R, 0, 1200)
	var p1 := sim.fighters[0]
	var p2 := sim.fighters[1]
	check_eq(p2.push_right(), STAGE.half_width, "opponent pushed into stage corner")
	check_eq(p1.push_right(), p2.push_left(), "attacker stops flush against cornered opponent")


func test_auto_face() -> void:
	var sim := new_sim()
	sim.fighters[0].x = 20000
	sim.fighters[1].x = -20000
	hold(sim, 0, 0, 1)
	check(sim.fighters[0].facing == -1 and sim.fighters[1].facing == 1, "fighters turn to face each other")
	sim.reset()
	hold(sim, U, 0, 1 + DUMMY.prejump_frames)
	sim.fighters[1].x = sim.fighters[0].x - 30000
	hold(sim, 0, 0, 1)
	check_eq(sim.fighters[0].facing, 1, "airborne fighter keeps facing")


func test_dash() -> void:
	var sim := new_sim()
	var p1 := sim.fighters[0]
	var x0 := p1.x
	play(sim, "6,5,6x30")
	check(p1.x - x0 > 9000, "forward dash travels further than walking alone")
	sim.reset()
	play(sim, "6x40")
	check_eq(p1.state_name(), "walk_f", "holding forward never dashes")


func test_socd() -> void:
	check_eq(InputBits.clean_socd(L | R), 0, "left+right = neutral")
	check_eq(InputBits.clean_socd(U | D), U, "up+down = up")
	check(InputBits.to_numpad(R, 1) == 6 and InputBits.to_numpad(R, -1) == 4, "numpad flips with facing")
	check(InputBits.to_numpad(D | L, 1) == 1 and InputBits.to_numpad(U | L, -1) == 9, "diagonals")


## 月姬格斗式跳跃：前 / 中 / 后跳各一套完整空中动画，按 上升 → 顶点 → 下落 的进度播放。
func test_jump_animation_by_direction_and_arc() -> void:
	var sim := new_sim()
	var p1 := sim.fighters[0]
	hold(sim, U | R, 0, 1)
	var air := p1.moveset.states[p1.moveset.id("air")]
	check_eq(AnimClock.anim_name(air, p1.jump_dir), "jump_f", "forward jump uses jump_f")
	check_eq(AnimClock.anim_name(air, -1), "jump_b", "back jump uses jump_b")
	check_eq(AnimClock.anim_name(air, 0), "jump", "neutral jump uses jump")
	var stand := p1.moveset.states[p1.moveset.id("stand")]
	check_eq(AnimClock.anim_name(stand, 1), stand.anim, "other states ignore jump direction")
	var arc := AnimData.from_meta({"frames": [["a", 2], ["b", 2], ["c", 2], ["d", 2], ["e", 2], ["f", 2]]})
	var v0 := 2000
	check_eq(AnimClock.frame(air, arc, 0, v0, v0), 0, "takeoff = first frame")
	check_eq(AnimClock.frame(air, arc, 0, 0, v0), 3, "apex = middle of the animation")
	check_eq(AnimClock.frame(air, arc, 0, -v0, v0), 5, "landing speed = last frame")
	while p1.state_name() != "landing":
		hold(sim, 0, 0, 1)
	check_eq(p1.jump_dir, 1, "landing keeps the jump direction (land_f)")
	hold(sim, 0, 0, DUMMY.landing_frames + 1)
	check_eq(p1.jump_dir, 0, "direction cleared once standing")
