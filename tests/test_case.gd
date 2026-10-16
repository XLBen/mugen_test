class_name TestCase
extends RefCounted
## 测试基类。子类里所有 test_ 开头的方法都会被 run_all.gd 执行。

const STAGE: StageDef = preload("res://stages/training_stage.tres")
const DUMMY: FighterDef = preload("res://characters/dummy/dummy.tres")

var failures := 0
var current := ""


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("  FAIL [%s] %s" % [current, msg])


func check_eq(actual: Variant, expected: Variant, msg: String) -> void:
	check(actual == expected, "%s: expected %s, got %s" % [msg, str(expected), str(actual)])


func new_sim() -> MatchSim:
	return MatchSim.new(STAGE, DUMMY, DUMMY)


## 两人贴身站好：P1 在 x，P2 在 x + gap（像素）。
func adjacent_sim(gap_px := 75, x_px := 0) -> MatchSim:
	var sim := new_sim()
	sim.fighters[0].x = x_px * SimConst.UNITS_PER_PX
	sim.fighters[1].x = (x_px + gap_px) * SimConst.UNITS_PER_PX
	sim.camera_x = (sim.fighters[0].x + sim.fighters[1].x) / 2
	return sim


func hold(sim: MatchSim, p1: int, p2: int, frames: int) -> void:
	for i in frames:
		sim.step([p1, p2])


## 按脚本推进；P2 的脚本按"面朝左"书写（4 = 后退 = 物理右）。
func play(sim: MatchSim, p1_script: String, p2_script := "", extra := 0) -> void:
	var a := InputScript.parse(p1_script)
	var b := InputScript.parse(p2_script, true)
	var n := maxi(a.size(), b.size()) + extra
	var a_last := a[-1] if not a.is_empty() else 0
	var b_last := b[-1] if not b.is_empty() else 0
	for i in n:
		sim.step([a[i] if i < a.size() else a_last & InputBits.DIRECTIONS,
			b[i] if i < b.size() else b_last & InputBits.DIRECTIONS])


## 推进到双方都恢复可行动为止，返回 (P2 可行动帧 - P1 可行动帧)，即 P1 的有利帧。
## p1_hold / p2_hold 为期间持续按住的输入。
## 从 P2 进入受击/防御硬直开始计算，P1 的出招必须已经开始。
func advantage(sim: MatchSim, p1_hold := 0, p2_hold := 0) -> int:
	var free := [-1, -1]
	var started := false
	for i in 400:
		sim.step([p1_hold, p2_hold])
		if not started:
			started = sim.fighters[1].sd().kind == "hurt"
			continue
		for k in 2:
			if free[k] < 0 and sim.fighters[k].sd().ctrl:
				free[k] = sim.frame
		if free[0] >= 0 and free[1] >= 0:
			break
	return free[1] - free[0]


## 种子化的伪随机输入（方向 + 按键），每段持续 1~20 帧。
func random_inputs(seed_value: int, count: int, with_buttons := true) -> Array:
	var rng := seed_value
	var out := []
	var cur: Array[int] = [0, 0]
	var left: Array[int] = [0, 0]
	var mask := InputBits.DIRECTIONS | (InputBits.BUTTONS if with_buttons else 0)
	for i in count:
		for p in 2:
			if left[p] <= 0:
				rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF
				cur[p] = (rng >> 4) & mask
				rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF
				left[p] = 1 + (rng >> 8) % 20
			left[p] -= 1
		out.append(cur.duplicate())
	return out


func run(sim: MatchSim, inputs: Array) -> Array[int]:
	var hashes: Array[int] = []
	for inp: Array in inputs:
		sim.step([inp[0], inp[1]])
		hashes.append(sim.state_hash())
	return hashes
