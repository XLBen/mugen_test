class_name CommonStates
## 街霸风规则的公共状态：移动、受击、防御、倒地、被投。所有角色共用，角色只写自己的招式。
## 纯数据描述放在 states()，需要读输入或做判断的部分放在 run() 分发的逻辑函数里。

const HURT_FRICTION := 60
const THROW_TECH_WINDOW := 7 ## 被抓后多少帧内可以拆投
const THROW_PROTECT := 3 ## 硬直结束后的投无敌帧数
const PROXIMITY_GUARD := 26000 ## 近距离防御的触发距离（单位）


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
		"dash_b": {"type": "S", "total": 22, "anim": "walk_b",
			"invuln": [{"frames": [1, 7], "strike": true, "throw": true}],
			"events": [{"frame": 1, "vx": -850}, {"frame": 13, "vx": 0}]},
		"prejump": {"type": "S", "logic": "prejump", "anim": "prejump"},
		"air": {"type": "A", "logic": "air", "anim": "jump"},
		"landing": {"type": "S", "guard_ok": true, "logic": "landing", "anim": "land"},
		"landing_long": {"type": "S", "total": 16, "anim": "land"},
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
static func try_commands(f: Fighter, sim: MatchSim, where: String) -> bool:
	for c in f.moveset.commands:
		if c.where != where:
			continue
		if c.cond == "no_projectile" and sim.has_projectile(f):
			continue
		var press := c.check(f, sim.frame)
		if press < 0:
			continue
		if c.buttons != 0:
			f.consumed = press
		f.set_state(c.state)
		if where == "air":
			f.air_used = 1
		else:
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
	if f.state_frame >= THROW_TECH_WINDOW:
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


static func _enter(f: Fighter, state_name: String) -> void:
	if f.state_name() != state_name:
		f.set_state(state_name)
