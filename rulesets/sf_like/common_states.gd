class_name CommonStates
## 街霸风规则的公共状态：移动、受击、防御、倒地、被投。所有角色共用，角色只写自己的招式。
## 纯数据描述放在 states()，需要读输入或做判断的部分放在 run() 分发的逻辑函数里。

const HURT_FRICTION := 60
const THROW_TECH_WINDOW := 7 ## 被抓后多少帧内可以拆投
const THROW_PROTECT := 3 ## 硬直结束后的投无敌帧数
const PROXIMITY_GUARD := 26000 ## 近距离防御的触发距离（单位）
const SPECIAL_METER := 20 ## 出必杀技（无论是否命中）获得的超杀槽
const FORWARD_DRIVE := 20 ## 前走每帧额外回复的 Drive
const UPGRADE_WINDOW := 3 ## 同时按宽容：出招后几帧内补按的键可以升级成更高优先级的指令（OD、投）


static func states() -> Dictionary:
	return {
		"stand": {"type": "S", "ctrl": true, "guard_ok": true, "logic": "ground", "anim": "idle"},
		"crouch": {"type": "C", "ctrl": true, "guard_ok": true, "logic": "ground", "anim": "crouch"},
		"walk_f": {"type": "S", "ctrl": true, "guard_ok": true, "logic": "ground", "anim": "walk_f"},
		"walk_b": {"type": "S", "ctrl": true, "guard_ok": true, "logic": "ground", "anim": "walk_b"},
		"guard_stand": {"type": "S", "ctrl": true, "guard_ok": true, "logic": "ground", "anim": "block_stand", "kind": "guard"},
		"guard_crouch": {"type": "C", "ctrl": true, "guard_ok": true, "logic": "ground", "anim": "block_crouch", "kind": "guard"},
		"dash_f": {"type": "S", "total": 18, "anim": "walk_f",
			"events": [{"frame": 1, "vx": 950}, {"frame": 11, "vx": 0}]},
		"dash_b": {"type": "S", "total": 22, "anim": "walk_b", "punishable_from": 8,
			"invuln": [{"frames": [1, 7], "strike": true, "throw": true}],
			"events": [{"frame": 1, "vx": -850}, {"frame": 13, "vx": 0}]},
		"prejump": {"type": "S", "logic": "prejump", "anim": "prejump"},
		"air": {"type": "A", "logic": "air", "anim": "jump"},
		"landing": {"type": "S", "guard_ok": true, "logic": "landing", "anim": "land"},
		"landing_long": {"type": "S", "total": 16, "anim": "land", "punishable": true},
		"hit_stand": {"type": "S", "kind": "hurt", "logic": "hurt", "friction": HURT_FRICTION, "anim": "hit_stand"},
		"hit_crouch": {"type": "C", "kind": "hurt", "logic": "hurt", "friction": HURT_FRICTION, "anim": "hit_crouch"},
		"block_stand": {"type": "S", "kind": "hurt", "guard_ok": true, "logic": "hurt", "friction": HURT_FRICTION,
			"anim": "block_stand"},
		"block_crouch": {"type": "C", "kind": "hurt", "guard_ok": true, "logic": "hurt", "friction": HURT_FRICTION,
			"anim": "block_crouch"},
		"hit_air": {"type": "A", "kind": "hurt", "land": "@hurt", "anim": "hit_air"},
		"land_recover": {"type": "S", "kind": "hurt", "total": 6, "anim": "land"},
		"knockdown": {"type": "L", "kind": "hurt", "total": 34, "next": "wakeup", "logic": "down", "anim": "knockdown",
			"invuln": [{"frames": [1, 34]}]},
		"wakeup": {"type": "S", "kind": "hurt", "total": 18, "anim": "wakeup", "invuln": [{"frames": [1, 18]}]},
		"ko": {"type": "L", "kind": "hurt", "anim": "knockdown", "invuln": [{"frames": [1, 99999]}]},
		"thrown": {"type": "S", "kind": "hurt", "physics": "none", "logic": "thrown", "anim": "hit_stand",
			"invuln": [{"frames": [1, 99999], "strike": true, "throw": true}]},
		"throw_tech": {"type": "S", "kind": "hurt", "total": 20, "friction": HURT_FRICTION, "anim": "block_stand",
			"events": [{"frame": 1, "vx": -700}]},
	}


static func run(logic: String, f: Fighter, sim: MatchSim) -> void:
	match logic:
		"ground":
			_ground(f, sim)
		"prejump":
			# 起跳预备中可以出必杀（360 指令投需要经过上方向）
			if try_commands(f, sim, "ground", true):
				return
			if f.state_frame >= f.def.prejump_frames:
				_launch_jump(f)
		"air":
			if f.air_used == 0:
				try_commands(f, sim, "air")
		"landing":
			if f.state_frame >= f.def.landing_frames:
				f.set_state("stand")
		"hurt":
			if f.state_frame >= f.stun:
				f.throw_protect = THROW_PROTECT
				f.set_state("crouch" if f.sd().type == "C" else "stand")
		"down":
			if f.health <= 0:
				f.set_state("ko")
		"thrown":
			_thrown(f, sim)
		"throwing":
			_throwing(f, sim)


## 地面可行动状态：先查出招表，再处理移动 / 近距离防御。
static func _ground(f: Fighter, sim: MatchSim) -> void:
	var opp := sim.opponent(f)
	if opp.x > f.x:
		f.facing = 1
	elif opp.x < f.x:
		f.facing = -1
	if try_commands(f, sim, "ground"):
		return
	var numpad := f.numpad_at(sim.frame)
	var back := InputBits.horizontal(numpad) == -1
	if InputBits.is_up(numpad):
		f.jump_dir = InputBits.horizontal(numpad)
		f.vx = 0
		f.set_state("prejump")
	elif InputBits.is_down(numpad):
		f.vx = 0
		_enter(f, "guard_crouch" if back and _threatened(f, sim) else "crouch")
	else:
		match InputBits.horizontal(numpad):
			1:
				f.vx = f.def.walk_forward_speed * f.facing
				_enter(f, "walk_f")
				if f.burnout == 0:
					Gauges.gain(f, Gauges.DRIVE, FORWARD_DRIVE)
			-1:
				if _threatened(f, sim):
					f.vx = 0
					_enter(f, "guard_stand")
				else:
					f.vx = -f.def.walk_back_speed * f.facing
					_enter(f, "walk_b")
			_:
				f.vx = 0
				_enter(f, "stand")


## 按出招表顺序（优先级）检查指令，成立则进入对应状态并消耗按键。
## specials_only：只接受必杀 / 超杀（起跳预备中使用）。
## limit：只检查出招表前 limit 条，且只看多键指令（同时按宽容的升级用）。
static func try_commands(f: Fighter, sim: MatchSim, where: String, specials_only := false, limit := -1) -> bool:
	var commands := f.moveset.commands
	var n := commands.size() if limit < 0 else limit
	for idx in n:
		var c := commands[idx]
		if c.where != where:
			continue
		if limit >= 0 and not (c.all_buttons or c.min_buttons > 1):
			continue
		var target: StateDef = f.moveset.states[f.moveset.id(c.state)]
		if specials_only and target.kind != "special" and target.kind != "super":
			continue
		if not _usable(f, sim, c, target):
			continue
		var press := c.check(f, sim.frame)
		if press < 0:
			continue
		if c.buttons != 0:
			f.consumed = press
		_enter_move(f, sim, target, idx)
		if where == "air":
			f.air_used = 1
		else:
			f.vx = 0
		return true
	return false


## 同时按宽容：刚由指令发动的招式，在 UPGRADE_WINDOW 帧内如果补按的键让更高优先级的指令成立
## （LP 后补 LK = 投；一拳后补第二拳 = OD），就改出那一招，并退还原招式的消耗。
static func try_upgrade(f: Fighter, sim: MatchSim) -> bool:
	if f.cmd_index <= 0 or sim.frame > f.upgrade_until:
		return false
	var old := f.sd()
	var where: String = f.moveset.commands[f.cmd_index].where
	if where == "cancel":
		return false
	var x := f.x
	var vx := f.vx
	if not try_commands(f, sim, where, false, f.cmd_index):
		return false
	for gauge_name: String in old.cost:
		Gauges.gain(f, Gauges.index(gauge_name), old.cost[gauge_name])
	f.x = x
	f.vx = vx if where == "air" else 0
	return true


static func _usable(f: Fighter, sim: MatchSim, c: Command, target: StateDef) -> bool:
	if c.cond.begins_with("limit:") and sim.has_projectile(f, c.cond.substr(6)):
		return false
	if c.cond == "no_projectile" and sim.has_projectile(f):
		return false
	return Gauges.can_afford(f, target.cost)


## 取消：当前招式接触对手后，在取消窗口内按出招表找允许的目标招式。
## 顿帧期间按下的键也有效（缓冲延长顿帧长度），这样"打中后立刻搓招"总能取消。
static func try_cancel(f: Fighter, sim: MatchSim) -> bool:
	var s := f.sd()
	var air := f.is_airborne()
	var commands := f.moveset.commands
	for idx in commands.size():
		var c := commands[idx]
		if c.where != "cancel" and c.where != ("air" if air else "ground"):
			continue
		var target: StateDef = f.moveset.states[f.moveset.id(c.state)]
		if not s.cancel_allows(target):
			continue
		if not _usable(f, sim, c, target):
			continue
		var press := c.check(f, sim.frame, Command.BUFFER + f.last_hitstop)
		if press < 0:
			continue
		f.consumed = press
		_enter_move(f, sim, target, idx)
		if not air:
			f.vx = 0
		return true
	return false


## 对手正在出招（含飞行道具接近）时，按后会进入防御姿势而不是后退。
static func _threatened(f: Fighter, sim: MatchSim) -> bool:
	var opp := sim.opponent(f)
	var s := opp.sd()
	if s.is_attack() and opp.state_frame <= s.last_active and absi(opp.x - f.x) < PROXIMITY_GUARD:
		return true
	for p in sim.projectiles:
		if p.owner != f.index and absi(p.x - f.x) < PROXIMITY_GUARD:
			return true
	return false


static func _launch_jump(f: Fighter) -> void:
	var d := f.def
	f.vy = d.jump_velocity
	match f.jump_dir:
		1:
			f.vx = d.jump_forward_speed * f.facing
		-1:
			f.vx = -d.jump_back_speed * f.facing
		_:
			f.vx = 0
	f.air_used = 0
	f.set_state("air")


## 被抓住的前几帧内同时按 LP+LK（任一刚按下）即可拆投。
static func _thrown(f: Fighter, sim: MatchSim) -> void:
	if f.state_frame >= THROW_TECH_WINDOW or sim.opponent(f).sd().untechable:
		return
	var tech := InputBits.B0 | InputBits.B3
	if f.input_at(sim.frame) & tech == tech and f.pressed_at(sim.frame) & tech:
		var opp := sim.opponent(f)
		f.set_state("throw_tech")
		opp.set_state("throw_tech")
		f.consumed = sim.frame


## 投技成功后：把被投方固定在身前，到指定帧结算伤害并击倒。
static func _throwing(f: Fighter, sim: MatchSim) -> void:
	var opp := sim.opponent(f)
	var s := f.sd()
	if not opp.is_in(["thrown"]):
		return
	if f.state_frame < s.throw_release:
		opp.x = f.x + s.throw_offset * f.facing
		opp.y = 0
		opp.facing = -f.facing
	elif f.state_frame == s.throw_release:
		Combat.apply_throw_release(sim, f, opp, s.throw_hit)


## 进入招式：扣资源，出必杀技涨超杀槽。
static func _enter_move(f: Fighter, sim: MatchSim, target: StateDef, cmd_index: int) -> void:
	Gauges.spend(f, target.cost)
	if target.kind == "special" and target.cost.is_empty() and f.sd().kind != "special":
		Gauges.gain(f, Gauges.SUPER, SPECIAL_METER)
	f.set_state(target.name)
	f.cmd_index = cmd_index
	f.upgrade_until = sim.frame + UPGRADE_WINDOW


static func _enter(f: Fighter, state_name: String) -> void:
	if f.state_name() != state_name:
		f.set_state(state_name)
