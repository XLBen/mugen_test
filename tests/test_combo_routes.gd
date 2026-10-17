extends TestCase
## 各角色设计好的连段（moveset.gd 里的 combo()）：按脚本完整打出能连上，
## 并且每一步都有至少 WINDOW 帧连续都能成功的输入窗口（包含设计的时机），保证真人输入有余量。
## strict 里列出的步骤（跳入的出招高度这类本身就靠技术的时机）不检查窗口。

const WINDOW := 3


## 内置角色 + 本地导入的人物（导入人物的攻击判定来自自己的动画，连段也要在它们身上成立；没有导入时只测内置）。
static func roster() -> Array[FighterDef]:
	var out: Array[FighterDef] = [load("res://characters/kagura/kagura.tres"), load("res://characters/volk/volk.tres"),
		load("res://characters/mio/mio.tres")]
	var training: GDScript = load("res://scenes/training.gd")
	out.append_array(training.local_fighters())
	return out


## 按连段脚本生成逐帧输入。shift：[第几步, 改变的帧数]。
static func build_script(c: Dictionary, shift := [-1, 0]) -> String:
	var parts := PackedStringArray()
	for k in c.script.size():
		var step: Array = c.script[k]
		parts.append(step[0])
		var wait: int = step[1] + (shift[1] if shift[0] == k else 0)
		if wait > 0:
			parts.append("5x%d" % wait)
	return ",".join(parts)


## 打一遍连段，返回 [最大连段数, P1 依次进入过的招式状态]。
static func run_combo(def: FighterDef, c: Dictionary, shift := [-1, 0]) -> Array:
	var sim := MatchSim.new(load("res://stages/training_stage.tres"), def, load("res://characters/dummy/dummy.tres"))
	sim.place(0, c.get("gap", 75) * SimConst.UNITS_PER_PX)
	if c.get("meter", false):
		sim.fighters[0].gauges[Gauges.SUPER] = Gauges.DEFS[Gauges.SUPER].max
	var a := InputScript.parse(build_script(c, shift))
	var b := InputScript.parse(c.get("p2", ""), true)
	var best := 0
	var entered := []
	var last := -1
	var last_frame := 0
	for i in a.size() + 90:
		sim.step([a[i] if i < a.size() else 0, b[i] if i < b.size() else 0])
		best = maxi(best, sim.fighters[1].combo_hits)
		var f := sim.fighters[0]
		# 同一招连打（5LP > 5LP）状态不变，但帧号会重新开始
		if (f.state != last or f.state_frame < last_frame) and f.sd().is_attack():
			entered.append(f.state_name())
		last = f.state
		last_frame = f.state_frame
	return [best, entered]


func test_every_designed_combo_connects() -> void:
	for def: FighterDef in roster():
		for c: Dictionary in def.moveset.new().data().combos:
			if not MovesetBuilder.combo_applies(c, def):
				continue
			check_eq(ComboTrial.notation_parts(c).size(), c.states.size(), "%s %s: one notation part per move" % [
				def.display_name, c.name])
			var r := run_combo(def, c)
			var label := "%s %s (%s)" % [def.display_name, c.name, c.notation]
			check(r[0] >= c.hits, "%s: %d hits, expected %d; moves %s" % [label, r[0], c.hits, r[1]])
			for s: String in c.states:
				check(s in r[1], "%s: %s came out (got %s)" % [label, s, r[1]])


func test_combos_tolerate_input_timing() -> void:
	for def: FighterDef in roster():
		for c: Dictionary in def.moveset.new().data().combos:
			if not MovesetBuilder.combo_applies(c, def):
				continue
			for k in c.script.size() - 1:
				if c.get("strict", []).has(k):
					continue
				var ok := []
				for d in range(-WINDOW + 1, WINDOW):
					ok.append(c.script[k][1] + d >= 0 and run_combo(def, c, [k, d])[0] >= c.hits)
				var best := 0
				for start in WINDOW:
					if ok.slice(start, start + WINDOW).all(func(v: bool) -> bool: return v):
						best = WINDOW
				check(best == WINDOW, "%s %s: step %d needs a %d-frame window around wait %d (results %s)" % [
					def.display_name, c.name, k + 1, WINDOW, c.script[k][1], ok])
