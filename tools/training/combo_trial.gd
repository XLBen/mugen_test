class_name ComboTrial
extends RefCounted
## 连段挑战：显示当前 P1 角色设计好的连段（moveset.gd 的 combo()），跟踪玩家按顺序打出的招式。
## 每出一招就和下一步比较；连段中断（对手恢复可行动、P1 回到中立且没有连段）或出错就回到第一步；
## 全部招式打出且连段数达到要求即成功。纯逻辑，只读仿真状态。

const SUCCESS_SHOW := 120 ## SUCCESS 显示帧数

var enabled := false
var combos: Array = [] ## 当前角色适用的连段
var index := 0
var step := 0 ## 已完成的步数
var success_timer := 0
var cleared := {} ## 已经成功过的连段下标
var _last_state := -1
var _last_frame := 0


func setup(def: FighterDef) -> void:
	combos = []
	for c: Dictionary in def.moveset.new().data().combos:
		if MovesetBuilder.combo_applies(c, def):
			combos.append(c)
	index = 0
	cleared = {}
	restart()


func restart() -> void:
	step = 0
	success_timer = 0


func next(delta := 1) -> void:
	if combos.is_empty():
		return
	index = posmod(index + delta, combos.size())
	restart()


func current() -> Dictionary:
	return combos[index] if not combos.is_empty() else {}


## 每推进一帧仿真后调用。
func record(sim: MatchSim) -> void:
	if not enabled or combos.is_empty():
		return
	if success_timer > 0:
		success_timer -= 1
	var f := sim.fighters[0]
	var opp := sim.fighters[1]
	var c := current()
	var states: Array = c.states
	var new_move := f.sd().is_attack() and (f.state != _last_state or f.state_frame < _last_frame)
	_last_state = f.state
	_last_frame = f.state_frame
	var in_combo := opp.combo_hits > 0
	if new_move:
		var name := f.state_name()
		if step < states.size() and name == states[step] and (step == 0 or in_combo):
			step += 1
		else:
			step = 1 if name == states[0] else 0
	elif step > 0 and not in_combo and f.sd().ctrl:
		step = 0 # 连段断了（或者第一招就没打中）
	if step == states.size() and in_combo and opp.combo_hits >= c.hits:
		success_timer = SUCCESS_SHOW
		cleared[index] = true
		step = 0


## 连段写法按 > 和 xx 拆成每一步（与 states 一一对应），给叠加层高亮用。
static func notation_parts(c: Dictionary) -> PackedStringArray:
	var parts := PackedStringArray()
	var text: String = c.notation
	var chunks := text.split(" > ")
	for i in chunks.size():
		var sub := chunks[i].split(" xx ")
		for k in sub.size():
			parts.append(("xx " if k > 0 else ("> " if i > 0 else "")) + sub[k])
	return parts
