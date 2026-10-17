class_name Combat
## 每帧的命中检测与结算。先收集本帧所有碰撞，再统一结算，P1/P2 处理完全对称：
##   1. 投 vs 投 → 双方拆投；投 vs 打 → 打击优先（投被打断）
##   2. 打 vs 打 → 相打，双方都吃到（且都是打康）
##   3. 道具 vs 道具 → 互相抵消耐久
##   4. 道具 vs 角色
## 防御判定与打康判定都使用结算前的状态。

enum Counter { NONE, COUNTER, PUNISH }

## 街霸风打康参数
const COUNTER_HITSTUN := {Counter.COUNTER: 2, Counter.PUNISH: 4}
const COUNTER_DAMAGE_PCT := 120
const PUNISH_THROW_DAMAGE_PCT := 170
const COUNTER_DISPLAY := 45

## 街霸风连段补正：第 1、2 击 100%，第 3 击起每击 -10%，轻攻击起手再 -10%，最低 10%
const SCALE_STEP := 10
const SCALE_MIN := 10
const LIGHT_STARTER_PENALTY := 10

## 资源
const DEFENDER_METER := 10 ## 被打 / 防御时获得的超杀槽
const BURNOUT_BLOCKSTUN := 4 ## Burnout 中防御硬直增加
const CHIP_DIV := 4 ## 没有单独指定削血量时，削血 = 伤害 / 4（SF6 约 25%）


static func resolve(sim: MatchSim) -> void:
	var fighters := sim.fighters
	var strikes := [] ## [attacker, defender, hitbox_index, HitDef]
	var throws := [] ## [attacker, defender]
	for a in 2:
		var atk := fighters[a]
		var dfn := fighters[1 - a]
		if atk.hitstop > 0:
			continue
		var s := atk.sd()
		var strike := _find_strike(atk, dfn, s)
		if not strike.is_empty():
			strikes.append(strike)
		if _throw_connects(atk, dfn, s):
			throws.append([atk, dfn])

	var struck := {} ## 本帧被打中的角色
	for st: Array in strikes:
		struck[st[1]] = true

	# 投技：双方同时投 → 拆投；投方本帧被打 → 投失效
	if throws.size() == 2:
		for t: Array in throws:
			t[0].set_state("throw_tech")
	elif throws.size() == 1:
		var t: Array = throws[0]
		if not struck.has(t[0]):
			_start_throw(t[0], t[1])

	# 先做全部防御 / 打康判定，再统一应用（相打）
	var decisions := []
	for st: Array in strikes:
		var blocked := can_block(sim, st[1], st[0].x, st[3])
		decisions.append([blocked, Counter.NONE if blocked else counter_type(st[1])])
	for i in strikes.size():
		var st: Array = strikes[i]
		st[0].hit_mask |= 1 << st[2]
		apply_hit(sim, st[0].x, st[0].facing, st[1], st[3], decisions[i][0], st[0], decisions[i][1], st[4])

	_resolve_projectiles(sim)


static func _find_strike(atk: Fighter, dfn: Fighter, s: StateDef) -> Array:
	if dfn.sd().is_invuln(dfn.state_frame, false):
		return []
	var hurt := dfn.hurtboxes()
	var juggled := dfn.state_name() == "hit_air"
	var i := 0
	for h: Dictionary in s.hitboxes:
		if atk.state_frame >= h.from and atk.state_frame <= h.to and not (atk.hit_mask & (1 << i)):
			var hd: HitDef = h.hit
			# 浮空受击中的对手只能被追打上限足够的招式打中，否则直接穿过
			if juggled and hd.juggle_limit < dfn.juggle:
				i += 1
				continue
			var world := []
			for b: PackedInt32Array in h.boxes:
				world.append(Box.to_world(atk.x, atk.y, atk.facing, b))
			var point := Box.contact_point(world, hurt)
			if not point.is_empty():
				return [atk, dfn, i, hd, point]
		i += 1
	return []


static func _throw_connects(atk: Fighter, dfn: Fighter, s: StateDef) -> bool:
	var box := s.throwbox_at(atk.state_frame)
	if box.is_empty() or not throwable(dfn):
		return false
	return Box.overlap(Box.to_world(atk.x, atk.y, atk.facing, box), dfn.pushbox_world())


## 地面、非硬直、非投无敌才能被投。
static func throwable(f: Fighter) -> bool:
	var s := f.sd()
	if f.is_airborne() or s.kind == "hurt" or f.throw_protect > 0:
		return false
	return not s.is_invuln(f.state_frame, true)


static func _start_throw(atk: Fighter, dfn: Fighter) -> void:
	var counter := counter_type(dfn)
	var hold: String = atk.sd().name + "_hit"
	atk.set_state(hold)
	atk.vx = 0
	dfn.set_state("thrown")
	dfn.vx = 0
	dfn.vy = 0
	dfn.counter_type = counter


## 打康类型由被打者"当前招式所处阶段"决定：发生/持续 → Counter，收招 → Punish Counter。
static func counter_type(dfn: Fighter) -> int:
	var s := dfn.sd()
	if s.kind == "hurt" or s.kind == "guard":
		return Counter.NONE
	if s.punishable or (s.punishable_from >= 0 and dfn.state_frame >= s.punishable_from):
		return Counter.PUNISH
	match s.phase_at(dfn.state_frame):
		StateDef.Phase.STARTUP, StateDef.Phase.ACTIVE:
			return Counter.COUNTER
		StateDef.Phase.RECOVERY:
			return Counter.PUNISH
	return Counter.NONE


## 能否防住：可防御状态 + 按住远离攻击方的方向 + 段位匹配（站防中上段，蹲防中下段）。
static func can_block(sim: MatchSim, dfn: Fighter, attacker_x: int, hd: HitDef) -> bool:
	var s := dfn.sd()
	if not s.guard_ok or dfn.is_airborne() or hd.guard == HitDef.Guard.UNBLOCKABLE:
		return false
	var away := signi(dfn.x - attacker_x)
	if away == 0:
		away = -dfn.facing
	var bits := dfn.input_at(sim.frame)
	var holding_back := (away > 0 and bits & InputBits.RIGHT) or (away < 0 and bits & InputBits.LEFT)
	if not holding_back:
		return false
	var crouching := bits & InputBits.DOWN != 0
	match hd.guard:
		HitDef.Guard.LOW:
			return crouching
		HitDef.Guard.HIGH:
			return not crouching
	return true


## SF6 削血规则：普攻永不削血；必杀技只在防御方 Burnout 时削血；超杀总是削血。削血可以削死。
static func chip_damage(dfn: Fighter, hd: HitDef) -> int:
	var chip := hd.chip if hd.chip > 0 else hd.damage / CHIP_DIV
	match hd.source:
		"super":
			return chip
		"special":
			return chip if dfn.burnout != 0 else 0
	return 0


## 连段补正后的伤害（不含打康加成）。min_scale 为该招的补正下限（超杀保底）。
static func scaled_damage(dfn: Fighter, base: int, min_scale := SCALE_MIN) -> int:
	var n := dfn.combo_hits + 1
	var scale := 100
	if n >= 3:
		scale -= SCALE_STEP * (n - 1)
	if dfn.combo_light != 0 and n >= 2:
		scale -= LIGHT_STARTER_PENALTY
	return base * maxi(scale, maxi(min_scale, SCALE_MIN)) / 100


## 应用一次命中/防御。melee 为 null 表示飞行道具（发射者不顿帧、不反推）。
## point：接触点 [x, y]（火花位置），为空时取被打方身体中部。
static func apply_hit(sim: MatchSim, source_x: int, source_facing: int, dfn: Fighter, hd: HitDef,
		blocked: bool, melee: Fighter, counter := Counter.NONE, point := PackedInt32Array()) -> void:
	var dir := signi(dfn.x - source_x)
	if dir == 0:
		dir = source_facing
	if point.is_empty():
		point = PackedInt32Array([dfn.x - dir * dfn.def.push_half_width / 2, dfn.y + dfn.push_height() * 2 / 3])
	var fx := {"strength": hd.strength, "counter": counter, "dir": dir, "super": hd.source == "super"}
	if not blocked and _absorbs(dfn, hd):
		_armor_hit(sim, dfn, hd, melee)
		sim.emit("armor", point[0], point[1], fx)
		return
	sim.emit("block" if blocked else "hit", point[0], point[1], fx)
	var crouching := dfn.input_at(sim.frame) & InputBits.DOWN != 0
	var was_juggled := dfn.state_name() == "hit_air"

	var attacker := melee if melee != null else sim.opponent(dfn)
	if blocked:
		dfn.health = maxi(dfn.health - chip_damage(dfn, hd), sim.health_floor)
		dfn.reset_combo()
		Gauges.gain(attacker, Gauges.SUPER, hd.meter / 2)
		Gauges.gain(dfn, Gauges.SUPER, DEFENDER_METER)
		Gauges.drain(dfn, Gauges.DRIVE, hd.drive)
	else:
		Gauges.gain(attacker, Gauges.SUPER, hd.meter)
		Gauges.gain(dfn, Gauges.SUPER, DEFENDER_METER)
		if attacker.burnout == 0:
			Gauges.gain(attacker, Gauges.DRIVE, hd.drive / 2)
		var damage := scaled_damage(dfn, hd.damage, hd.min_scale)
		if counter != Counter.NONE:
			damage = damage * COUNTER_DAMAGE_PCT / 100
		if dfn.combo_hits == 0:
			dfn.combo_light = 1 if hd.strength == 0 else 0
		dfn.combo_hits += 1
		dfn.combo_damage += damage
		dfn.health = maxi(dfn.health - damage, sim.health_floor)
		dfn.counter_type = counter
		if counter != Counter.NONE:
			dfn.counter_timer = COUNTER_DISPLAY

	if blocked and dfn.health > 0:
		dfn.set_state("block_crouch" if crouching else "block_stand")
		dfn.stun = hd.blockstun + (BURNOUT_BLOCKSTUN if dfn.burnout != 0 else 0)
		dfn.vx = hd.block_push * dir
	else:
		var effect := hd.effect
		if counter != Counter.NONE and hd.counter_effect >= 0:
			effect = hd.counter_effect
		var launched := dfn.is_airborne() or effect != HitDef.Effect.NORMAL or dfn.health <= 0
		if launched:
			dfn.juggle = dfn.juggle + hd.juggle_add if was_juggled else hd.juggle_start
			dfn.set_state("hit_air")
			dfn.vx = hd.air_vx * dir
			dfn.vy = hd.air_vy if effect == HitDef.Effect.LAUNCH or dfn.is_airborne() else 500
			dfn.y = maxi(dfn.y, 1)
			dfn.knockdown = 1 if effect != HitDef.Effect.NORMAL or dfn.health <= 0 else 0
		else:
			var was_crouching := dfn.sd().type == "C"
			dfn.set_state("hit_crouch" if was_crouching else "hit_stand")
			dfn.stun = hd.hitstun + COUNTER_HITSTUN.get(counter, 0)
			dfn.vx = hd.push * dir
	dfn.facing = -dir
	dfn.hitstop = hd.hitstop
	if melee != null:
		melee.hitstop = hd.hitstop
		melee.contact = 1 if blocked else 2
		melee.last_hitstop = hd.hitstop
		dfn.push_transfer = 1


## 霸体：状态处于霸体帧且还有吸收次数，且不是超杀。
static func _absorbs(dfn: Fighter, hd: HitDef) -> bool:
	return hd.source != "super" and dfn.armor_used < dfn.sd().armor_at(dfn.state_frame)


## 霸体吸收：照常扣血、双方顿帧，但被打方不进入硬直、继续自己的招式。
static func _armor_hit(sim: MatchSim, dfn: Fighter, hd: HitDef, melee: Fighter) -> void:
	dfn.armor_used += 1
	dfn.health = maxi(dfn.health - hd.damage, sim.health_floor)
	dfn.hitstop = hd.hitstop
	if melee != null:
		melee.hitstop = hd.hitstop
		melee.contact = 2
		melee.last_hitstop = hd.hitstop


static func apply_throw_release(sim: MatchSim, atk: Fighter, dfn: Fighter, hd: HitDef) -> void:
	sim.emit("hit", dfn.x, dfn.y + 6000, {"strength": 2, "counter": dfn.counter_type, "dir": atk.facing, "super": false})
	var damage := hd.damage
	if dfn.counter_type == Counter.PUNISH:
		damage = damage * PUNISH_THROW_DAMAGE_PCT / 100
		dfn.counter_timer = COUNTER_DISPLAY
	dfn.health = maxi(dfn.health - damage, sim.health_floor)
	dfn.combo_hits += 1
	dfn.combo_damage += damage
	dfn.set_state("hit_air")
	dfn.vx = hd.air_vx * atk.facing
	dfn.vy = hd.air_vy
	dfn.y = 1
	dfn.knockdown = 1
	dfn.juggle = 99 ## 投后不可追打
	dfn.hitstop = hd.hitstop
	atk.hitstop = hd.hitstop


static func _resolve_projectiles(sim: MatchSim) -> void:
	var ps := sim.projectiles
	# 道具互相抵消
	for i in ps.size():
		for j in range(i + 1, ps.size()):
			var a := ps[i]
			var b := ps[j]
			if a.owner == b.owner or a.hits <= 0 or b.hits <= 0:
				continue
			if not sim.projectile_live(a) or not sim.projectile_live(b):
				continue
			if Box.overlap(sim.projectile_box(a), sim.projectile_box(b)):
				a.hits -= 1
				b.hits -= 1
				sim.emit("clash", (a.x + b.x) / 2, (a.y + b.y) / 2, {"strength": 1, "counter": 0, "dir": 1, "super": false})
	# 道具命中角色
	for p in ps:
		if p.hits <= 0 or not sim.projectile_live(p):
			continue
		var dfn := sim.fighters[1 - p.owner]
		var hd := sim.projectile_def(p).hit
		if dfn.sd().is_invuln(dfn.state_frame, false):
			continue
		if dfn.state_name() == "hit_air" and hd.juggle_limit < dfn.juggle:
			continue
		if not Box.any_overlap([sim.projectile_box(p)], dfn.hurtboxes()):
			continue
		var blocked := can_block(sim, dfn, p.x, hd)
		apply_hit(sim, p.x, p.facing, dfn, hd, blocked, null, Counter.NONE if blocked else counter_type(dfn),
			PackedInt32Array([p.x + p.facing * 1500, p.y]))
		p.hits -= 1
		p.cooldown = sim.projectile_def(p).hit_interval
	var alive: Array[Projectile] = []
	for p in ps:
		if p.hits > 0:
			alive.append(p)
	sim.projectiles = alive
