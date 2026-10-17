class_name CpuPlayer
extends RefCounted
## 电脑对手：每帧读仿真状态、给出一名玩家的 InputBits（和真人走同一条输入路径，所以对局照样确定、可重放）。
##
## - 感知延迟：对手的状态先记进环形缓冲，按难度隔 reaction 帧才"看到"（模拟人的反应时间）
## - 反应（每个对手动作只决定一次）：防御（按段位站防 / 蹲防）或招架、对空、确反（设计好的连段 / 超杀）、拆投
## - 中立（每 think 帧决定一次）：按距离选择投、连段起手、牵制、波动、Drive Impact、前走 / 冲刺 / 跳入、后退
## - 招式输入用 InputScript 文本按当时的朝向转成逐帧输入，排进计划队列一帧一帧按出
## 随机数是自己的 LCG（不进仿真存档）；同样的种子和对局得到同样的输入。

const MEMORY := 40 ## 感知缓冲长度（帧）
const CLOSE_PX := 115
const MID_PX := 260
const AA_PX := 220 ## 对空反应距离
const PROXIMITY_PX := 60 ## 判定长度之外多算的防御距离
const PUNISH_MARGIN := 6 ## 确反需要对手至少还剩这么多收招帧（扣掉反应延迟后）

var me := 1
var level := 4
var p: Dictionary
var _rng := 1
var _plan: Array[int] = []
var _hold := 0 ## 两次决策之间一直按着的方向（相对朝向的小键盘方向，5 = 不按）
var _wait := 0
var _seen: Array[Dictionary] = []
var _decided := {} ## 已经决定过的对手动作（同一招只反应一次）

static var _kits := {} ## FighterDef 路径 → 招式清单（静态数据，可共享）


func _init(player := 1, level_ := 4, seed_value := 1) -> void:
	me = player
	level = clampi(level_, 1, 8)
	p = CpuProfile.for_level(level)
	_rng = (seed_value * 2654435761 + 1) & 0x7FFFFFFF
	_hold = 5


func inputs(sim: MatchSim) -> int:
	var f := sim.fighters[me]
	var opp := sim.opponent(f)
	_observe(sim, f, opp)
	if sim.round_state != MatchSim.Round.FIGHT:
		_plan.clear()
		return 0
	var view: Dictionary = _seen[maxi(_seen.size() - 1 - p.reaction, 0)]
	var s := f.sd()
	# 被抓：拆投（这个靠反应，不排队）
	if s.name == "thrown":
		_plan.clear()
		return InputBits.B0 | InputBits.B3 if f.state_frame <= 2 and _once("tech%d" % (sim.frame - f.state_frame), p.tech) else 0
	if s.kind == "hurt":
		_plan.clear()
		if s.guard_ok:
			# 防御硬直中：保持防御；被压制时偶尔 Drive Reversal
			if Gauges.value(f, Gauges.DRIVE) >= 30000 and f.burnout == 0 and _once("dr%d" % (sim.frame - f.state_frame),
					p.drive * 0.5):
				_queue(f, "6HP+HK")
				return _plan.pop_front()
			return _guard(f, view)
		return 0
	if not _plan.is_empty():
		return _plan.pop_front()
	if not s.ctrl:
		return 0
	var kit := _kit(f)
	var d: int = view.d
	# —— 反应 ——
	if view.threat:
		var key := "threat%d" % view.id
		if not _decided.has(key):
			_decided[key] = _chance(p.block)
			if _decided[key] and Gauges.value(f, Gauges.DRIVE) >= 20000 and f.burnout == 0 and _chance(p.drive * 0.6):
				_decided[key] = false
				_queue(f, "5MP+MKx14")
				return _plan.pop_front()
		if _decided[key]:
			return _guard(f, view)
	if view.air and view.approaching and d < AA_PX and _once("aa%d" % view.id, p.anti_air):
		_queue(f, kit.anti_air)
		return _plan.pop_front()
	# 确反：看到时对手剩下的收招要比反应延迟 + 最快的出招还长，才值得出手
	if view.recovery and view.left > p.reaction + PUNISH_MARGIN and d < MID_PX and _once("punish%d" % view.id, p.punish):
		_queue(f, _punish(f, kit, d))
		return _plan.pop_front()
	# —— 中立 ——
	_wait -= 1
	if _wait <= 0:
		_wait = p.think + _rand(p.think + 1)
		_neutral(f, kit, d, view)
		if not _plan.is_empty():
			return _plan.pop_front()
	return InputScript.dir_bits(_hold, f.facing < 0)


# ---------------------------------------------------------------- 决策

func _neutral(f: Fighter, kit: Dictionary, d: int, view: Dictionary) -> void:
	_hold = 5
	var drive := Gauges.value(f, Gauges.DRIVE)
	# 人的反应来不及挡快招，所以防守主要靠"预先按住下后"；水平越高越会在对手够得着时守住
	var guard_hold := 1 if _chance(p.block) else 5
	if d < CLOSE_PX:
		if _chance(p.throw):
			_queue(f, "4LP+LK" if _chance(0.3) else "5LP+LK")
		elif _chance(p.aggro):
			_queue(f, _starter(kit, _chance(p.confirm)))
		else:
			_hold = guard_hold
		return
	if d < MID_PX:
		if drive >= 30000 and f.burnout == 0 and _chance(p.drive * 0.25):
			_queue(f, "5HP+HK")
		elif _chance(p.aggro):
			var poke := _poke(kit, d)
			if poke != "":
				_queue(f, poke)
			else:
				_hold = 6
		elif _chance(p.aggro * 0.8):
			_hold = 6
		else:
			_hold = guard_hold
		return
	# 远距离
	if kit.fireball != "" and _chance(0.35 + p.aggro * 0.2):
		_queue(f, kit.fireball)
	elif d < 330 and not kit.jump_ins.is_empty() and _chance(p.aggro * 0.25):
		_queue(f, kit.jump_ins[_rand(kit.jump_ins.size())])
	elif _chance(0.3):
		_queue(f, "6,5,6")
	else:
		_hold = 6


## 确反：有超杀槽时可能直接超杀，否则打一套设计好的连段（够不着就用最远的牵制）。
func _punish(f: Fighter, kit: Dictionary, d: int) -> String:
	var meter := Gauges.value(f, Gauges.SUPER)
	for sup: Array in kit.supers:
		if meter >= sup[1] and _chance(p.super * 0.5):
			return sup[0]
	if d < CLOSE_PX + 30:
		return _starter(kit, _chance(p.confirm), meter)
	var poke := _poke(kit, d)
	return poke if poke != "" else "6x8"


## 近身起手：confirm 时打一整套连段，否则只出第一招。
func _starter(kit: Dictionary, confirm: bool, meter := 0) -> String:
	var options: Array = []
	for c: Dictionary in kit.combos:
		if c.cost <= meter:
			options.append(c)
	if options.is_empty():
		return "2LK"
	var c: Dictionary = options[_rand(options.size())]
	return c.script if confirm else c.first


func _poke(kit: Dictionary, d: int) -> String:
	var fits: Array = []
	for pk: Array in kit.pokes:
		if pk[1] + 30 >= d:
			fits.append(pk[0])
	return "" if fits.is_empty() else fits[_rand(fits.size())]


## 防御：按对手当前招式的段位决定站防（中段 / 上段 / 空中攻击）或蹲防。
func _guard(f: Fighter, view: Dictionary) -> int:
	return InputScript.dir_bits(4 if view.high else 1, f.facing < 0)


func _queue(f: Fighter, script: String) -> void:
	_plan = InputScript.parse(script, f.facing < 0)


# ---------------------------------------------------------------- 感知

func _observe(sim: MatchSim, f: Fighter, opp: Fighter) -> void:
	var s := opp.sd()
	var d := absi(opp.x - f.x) / SimConst.UNITS_PER_PX
	var attacking := s.is_attack() and s.kind != "throw" and opp.state_frame <= s.last_active and s.last_active >= 0
	var reach := s.reach / SimConst.UNITS_PER_PX + f.def.push_half_width / SimConst.UNITS_PER_PX + PROXIMITY_PX
	var low := false
	var high := opp.is_airborne()
	for h: Dictionary in s.hitboxes:
		var hd: HitDef = h.hit
		low = low or hd.guard == HitDef.Guard.LOW
		high = high or hd.guard == HitDef.Guard.HIGH
	var projectile := false
	for pr in sim.projectiles:
		if pr.owner != me and absi(pr.x - f.x) < 30000 and signi(f.x - pr.x) == signi(pr.vx):
			projectile = true
	var recovering := s.kind != "hurt" and (s.punishable or (s.punishable_from >= 0 and opp.state_frame >= s.punishable_from)
		or (s.is_attack() and s.phase_at(opp.state_frame) == StateDef.Phase.RECOVERY))
	_seen.append({
		"d": d,
		"id": opp.state * 100000 + (sim.frame - opp.state_frame),
		"threat": (attacking and d < reach) or projectile,
		"high": high and not low,
		"air": opp.is_airborne() and s.kind != "hurt",
		"approaching": signi(f.x - opp.x) == signi(opp.vx) and opp.vx != 0,
		"recovery": recovering,
		"left": (s.total - opp.state_frame) if s.total > 0 else (99 if opp.is_airborne() else 0),
	})
	if _seen.size() > MEMORY:
		_seen.pop_front()
	if _decided.size() > 64:
		_decided.clear()


# ---------------------------------------------------------------- 随机

func _rand(n: int) -> int:
	_rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF
	return (_rng >> 8) % maxi(n, 1)


func _chance(prob: float) -> bool:
	return _rand(1000) < int(prob * 1000.0)


func _once(key: String, prob: float) -> bool:
	if _decided.has(key):
		return false
	_decided[key] = true
	return _chance(prob)


# ---------------------------------------------------------------- 招式清单

## 这个角色能用的招式（按出招表和设计好的连段整理一次，之后缓存）：
## combos 近身连段 {script, first, cost}、jump_ins 跳入连段、pokes [脚本, 判定长度像素]、fireball、anti_air、supers [脚本, 消耗]。
func _kit(f: Fighter) -> Dictionary:
	var key := f.def.resource_path + "|" + f.def.sprite_dir
	if _kits.has(key):
		return _kits[key]
	var m := f.moveset
	var data: Dictionary = f.def.moveset.new().data()
	var kit := {"combos": [], "jump_ins": [], "pokes": [], "fireball": "", "anti_air": "2HP", "supers": []}
	for c: Dictionary in data.combos:
		if not MovesetBuilder.combo_applies(c, f.def) or c.has("p2"):
			continue
		var script := ComboTrial.build_script(c)
		if script.begins_with("9"):
			kit.jump_ins.append(script)
			continue
		var cost := 0
		for st: String in c.states:
			cost = maxi(cost, m.states[m.id(st)].cost.get("super", 0))
		kit.combos.append({"script": script, "first": c.script[0][0], "cost": cost})
	var dp_rank := -1
	for c in m.commands:
		if c.where != "ground" or c.name.contains("_"):
			continue
		var s: StateDef = m.states[m.id(c.state)]
		var script := _script_for(c.name)
		if script == "":
			continue
		match s.kind:
			"normal":
				if s.reach > 0 and c.stance != "back":
					kit.pokes.append([script, s.reach / SimConst.UNITS_PER_PX])
			"special":
				if not s.cost.is_empty():
					continue
				var spawns := s.events.any(func(e: Dictionary) -> bool: return e.has("spawn"))
				if spawns and kit.fireball == "":
					kit.fireball = script # 出招表里重的先登记
				if s.is_invuln(0, false) and s.first_active >= 0 and not spawns:
					var rank := 2 if s.name.ends_with("_h") else (1 if s.name.ends_with("_m") else 0)
					if rank > dp_rank:
						dp_rank = rank
						kit.anti_air = script
			"super":
				kit.supers.append([script, s.cost.get("super", 1000)])
	_kits[key] = kit
	return kit


## 出招表里的指令名（如 236HK、623P、214214K、360LP、5mp、6mp）→ InputScript 文本（面朝右）。
static func _script_for(notation: String) -> String:
	var i := 0
	while i < notation.length() and notation[i] in "0123456789":
		i += 1
	var motion := notation.substr(0, i)
	var buttons := notation.substr(i).to_upper()
	if motion == "" or buttons == "" or buttons.contains("+") and motion.length() > 1:
		return ""
	match buttons:
		"P":
			buttons = "HP"
		"K":
			buttons = "HK"
		"PP":
			buttons = "LP+MP"
		"KK":
			buttons = "LK+MK"
	if not buttons in ["LP", "MP", "HP", "LK", "MK", "HK", "LP+MP", "LK+MK"]:
		return ""
	if motion.length() == 1:
		return motion + buttons
	if motion == "360":
		return "6,2,4,8" + buttons
	var dirs := PackedStringArray()
	for ch in motion:
		dirs.append(ch)
	return ",".join(dirs) + buttons
