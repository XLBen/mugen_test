extends TestCase
## 命中、防御、有利帧、投、相打、飞行道具、无敌、版边反推。

const BACK_P2 := InputBits.RIGHT ## P2 面朝左，按右 = 后
const DOWN_BACK_P2 := InputBits.RIGHT | InputBits.DOWN

## 地面普攻的帧数据表：名字 → [命中有利, 防御有利]（与 standard_moveset.gd 一致）
const NORMALS := {
	"5lp": [4, -1], "5mp": [5, 1], "5hp": [2, -4], "5lk": [3, -2], "5mk": [2, -3], "5hk": [1, -5],
	"2lp": [4, -1], "2mp": [4, 0], "2hp": [1, -8], "2lk": [2, -1], "2mk": [1, -4],
}
const BUTTONS := {"lp": "LP", "mp": "MP", "hp": "HP", "lk": "LK", "mk": "MK", "hk": "HK"}


func _press(normal: String) -> String:
	return normal.substr(0, 1) + BUTTONS[normal.substr(1)]


func test_whiff_total_frames() -> void:
	var sim := adjacent_sim(400)
	play(sim, "5LP")
	var n := 1
	while not sim.fighters[0].sd().ctrl and n < 100:
		hold(sim, 0, 0, 1)
		n += 1
	var total: int = sim.fighters[0].moveset.states[sim.fighters[0].moveset.id("5lp")].total
	check_eq(n, total + 1, "5LP whiff: first actionable frame is total + 1")


func test_hit_advantage_matches_frame_data() -> void:
	for normal: String in NORMALS:
		var sim := adjacent_sim()
		var crouch := normal.begins_with("2")
		play(sim, _press(normal))
		var adv := advantage(sim, InputBits.DOWN if crouch else 0, 0)
		check_eq(adv, NORMALS[normal][0], normal + " on hit")
		check(sim.fighters[1].health < DUMMY.max_health, normal + " dealt damage")


func test_block_advantage_matches_frame_data() -> void:
	for normal: String in NORMALS:
		var sim := adjacent_sim()
		var crouch := normal.begins_with("2")
		var guard := DOWN_BACK_P2 if normal in ["2lk", "2mk"] else BACK_P2
		play(sim, _press(normal), "4" if guard == BACK_P2 else "1")
		var adv := advantage(sim, InputBits.DOWN if crouch else 0, guard)
		check_eq(adv, NORMALS[normal][1], normal + " on block")
		check_eq(sim.fighters[1].health, DUMMY.max_health, normal + " normals deal no chip")


func test_low_must_be_crouch_blocked() -> void:
	var sim := adjacent_sim()
	play(sim, "2LK", "4", 5)
	check_eq(sim.fighters[1].state_name(), "hit_stand", "standing block loses to low")
	sim = adjacent_sim()
	play(sim, "2LK", "1", 5)
	check_eq(sim.fighters[1].state_name(), "block_crouch", "crouch block stops low")


func test_overhead_must_be_stand_blocked() -> void:
	for guard in ["1", "4"]:
		var sim := adjacent_sim(60)
		var p1 := sim.fighters[0]
		p1.y = 9000
		p1.vy = -400
		p1.set_state("j_hk")
		play(sim, "5", guard + "x30")
		var got := sim.fighters[1].state_name()
		if guard == "1":
			check(got != "block_crouch" and sim.fighters[1].health < DUMMY.max_health, "crouch block loses to jump-in (%s)" % got)
		else:
			check_eq(sim.fighters[1].health, DUMMY.max_health, "standing block stops jump-in")


func test_throw_connects_and_releases() -> void:
	var sim := adjacent_sim()
	play(sim, "5LP+LK", "", 10)
	check_eq(sim.fighters[1].state_name(), "thrown", "opponent grabbed")
	play(sim, "5", "", 60)
	check_eq(sim.fighters[1].health, DUMMY.max_health - 1200, "throw damage")
	check(sim.fighters[1].is_in(["knockdown", "wakeup", "hit_air"]), "throw knocks down")


func test_throw_tech() -> void:
	var sim := adjacent_sim()
	play(sim, "5LP+LK", "5x6,5LP+LK", 0)
	check_eq(sim.fighters[1].state_name(), "throw_tech", "defender teched")
	check_eq(sim.fighters[0].state_name(), "throw_tech", "attacker pushed into tech")
	play(sim, "5", "", 60)
	check_eq(sim.fighters[1].health, DUMMY.max_health, "tech takes no damage")


func test_cannot_throw_during_blockstun() -> void:
	var sim := adjacent_sim()
	play(sim, "5MP", "4")
	play(sim, "5x5", "4x5")
	check_eq(sim.fighters[1].state_name(), "block_stand", "in blockstun")
	play(sim, "5LP+LK", "4", 10)
	check(sim.fighters[1].state_name() != "thrown", "blockstun is throw invulnerable")


func test_trade() -> void:
	var sim := adjacent_sim()
	play(sim, "5LP", "5LP", 5)
	check(sim.fighters[0].health < DUMMY.max_health and sim.fighters[1].health < DUMMY.max_health,
		"same-frame normals trade")


func test_fireball_hits_and_disappears() -> void:
	var sim := adjacent_sim(300)
	play(sim, "2,3,6HP", "", 60)
	check_eq(sim.fighters[1].health, DUMMY.max_health - 600, "fireball damage")
	check_eq(sim.projectiles.size(), 0, "fireball consumed on hit")


func test_fireball_chip_only_in_burnout() -> void:
	var sim := adjacent_sim(300)
	play(sim, "2,3,6HP", "4x60")
	check_eq(sim.fighters[1].health, DUMMY.max_health, "SF6: specials do not chip outside burnout")
	sim = adjacent_sim(300)
	Gauges.gain(sim.fighters[1], Gauges.DRIVE, -60000)
	play(sim, "2,3,6HP", "4x60")
	check_eq(sim.fighters[1].health, DUMMY.max_health - 150, "burnout: fireball chips")


func test_super_always_chips() -> void:
	var sim := adjacent_sim()
	sim.fighters[0].gauges[Gauges.SUPER] = 1000
	play(sim, "2,3,6,2,3,6LP", "4x80")
	check_eq(sim.fighters[1].health, DUMMY.max_health - 650, "super chip damage")


func test_fireballs_clash() -> void:
	var sim := adjacent_sim(500)
	play(sim, "2,3,6HP", "2,3,6HP", 60)
	check_eq(sim.projectiles.size(), 0, "fireballs cancel each other")
	check(sim.fighters[0].health == DUMMY.max_health and sim.fighters[1].health == DUMMY.max_health, "nobody hit")


func test_dp_invincible_startup() -> void:
	# P2 先出 5LP，P1 在其持续帧前一帧出升龙：升龙无敌穿过并打中 P2
	var sim := adjacent_sim()
	play(sim, "5,6,2,3HP", "5LP", 40)
	check_eq(sim.fighters[0].health, DUMMY.max_health, "dp startup is invulnerable")
	check(sim.fighters[1].health < DUMMY.max_health, "dp hits through")


func test_corner_pushback_goes_to_attacker() -> void:
	var sim := adjacent_sim(75, 1200 - 35 - 75)
	sim.camera_x = 1200 * 100 - SimConst.SCREEN_HALF_W
	var p1_x := sim.fighters[0].x
	play(sim, "5LP", "", 25)
	check_eq(sim.fighters[1].push_right(), STAGE.half_width, "defender stays in corner")
	check(sim.fighters[0].x < p1_x, "attacker pushed back instead")


func test_proximity_guard() -> void:
	var sim := adjacent_sim(150)
	play(sim, "5HK", "4x3")
	check_eq(sim.fighters[1].state_name(), "guard_stand", "holding back near an attack enters guard")
	var far := adjacent_sim(600)
	play(far, "5HK", "4x3")
	check_eq(far.fighters[1].state_name(), "walk_b", "far away just walks back")


func test_knockdown_and_wakeup() -> void:
	var sim := adjacent_sim()
	play(sim, "2HK", "", 45)
	check_eq(sim.fighters[1].state_name(), "knockdown", "sweep knocks down")
	play(sim, "5", "", 80)
	check_eq(sim.fighters[1].state_name(), "stand", "gets up")


func test_ko() -> void:
	var sim := adjacent_sim()
	sim.fighters[1].health = 200
	play(sim, "5LP", "", 120)
	check_eq(sim.fighters[1].health, 0, "health clamped at zero")
	check_eq(sim.fighters[1].state_name(), "ko", "stays down when KO'd")


## 受击动画按 上下段 × 强度 区分（纯表现）。
func test_hit_reaction_variant() -> void:
	var sim := adjacent_sim()
	play(sim, "5HP", "", 3)
	hold(sim, 0, 0, 12)
	var p2 := sim.fighters[1]
	check_eq(p2.state_name(), "hit_stand", "standing hit")
	check_eq(p2.hit_var, 2, "5HP hits high with a heavy reaction")
	sim = adjacent_sim()
	play(sim, "2LK", "", 3)
	hold(sim, InputBits.DOWN, 0, 8)
	check_eq(sim.fighters[1].hit_var, 3, "low light kick: low light reaction")
