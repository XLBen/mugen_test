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
const COUNTER_HITSTOP := {Counter.COUNTER: 0, Counter.PUNISH: 4} ## 确反额外顿帧（双方相同，不改变有利帧）
const PUNISH_DRIVE_PCT := 100 ## 确反时防御方损失的 Drive = 该招被防时削的量 × 这个比例（SF6 确反削 Drive，具体量未核实）
const COUNTER_DAMAGE_PCT := 120
const PUNISH_THROW_DAMAGE_PCT := 170
const COUNTER_DISPLAY := 45
const PERFECT_PARRY_PCT := 50 ## 完美招架后的反击连段伤害比例
## Drive Parry（数值未逐项核实）
const PERFECT_PARRY_WINDOW := 2 ## 开始招架后几帧内被打算完美招架
const PERFECT_PARRY_FREEZE := 30 ## 完美招架时攻击方的停顿（防御方立刻可以行动）
const PARRY_GAIN := 5000 ## 招架成功回复的 Drive
const PARRY_PUSH_PCT := 50 ## 招架时的后退 = 被防击退的这个比例

## 街霸风连段补正：第 1、2 击 100%，第 3 击 80%，之后每击再 -10%（70%、60%…），轻攻击起手从第 2 击起再 -10%，最低 10%
const SCALE_STEP := 10
const SCALE_MIN := 10
const LIGHT_STARTER_PENALTY := 10

## 资源
const DEFENDER_METER := 10 ## 被打 / 防御时获得的超杀槽
const BURNOUT_BLOCKSTUN := 4 ## Burnout 中防御硬直增加
const CHIP_DIV := 4 ## 没有单独指定削血量时，削血 = 伤害 / 4（SF6 约 25%）
const HIGH_HIT_PCT := 60 ## 受击动画：接触点高于身高的这个比例算上段

## 受击反应
const CRUMPLE_FRAMES := 70 ## 崩溃（慢慢瘫倒）多久后倒地；期间被打当作站立受击，可以继续完整连段
const CRUMPLE_DOWN_EXTRA := 10 ## 崩溃没被追打、自己倒下时多躺几帧
const FREE_COMBO := ["crumple", "dizzy"] ## 处于这些逻辑的状态时被打：当作站立受击（不浮空），可以接完整连段
const JUGGLE_STATES := ["hit_air", "wall_splat"] ## 追打计数生效的受击状态
const WALL_SPLAT_Y := 6000 ## 地面上被打到墙上时贴墙的高度
const WALL_HITSTOP := 10 ## 撞墙瞬间的顿帧
const WALL_BOUNCE_VX := 450 ## 弹墙后离墙的水平速度
const WALL_BOUNCE_VY := 1000


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
		var parried := parrying(st[1])
		var blocked := not parried and can_block(sim, st[1], st[0].x, st[3])
		decisions.append([blocked, Counter.NONE if blocked or parried else counter_type(st[1]), parried])
	for i in strikes.size():
		var st: Array = strikes[i]
		st[0].hit_mask |= 1 << st[2]
		if decisions[i][2]:
			apply_parry(sim, st[0].x, st[1], st[3], st[0], st[4])
		else:
			apply_hit(sim, st[0].x, st[0].facing, st[1], st[3], decisions[i][0], st[0], decisions[i][1], st[4])

	_resolve_projectiles(sim)


static func _find_strike(atk: Fighter, dfn: Fighter, s: StateDef) -> Array:
	if dfn.sd().is_invuln(dfn.state_frame, false):
		return []
	var hurt := dfn.hurtboxes()
	var juggled := dfn.state_name() in JUGGLE_STATES
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
	# 被抓时自己的投正在发生中（晚几帧按了投）也算拆投
	if dfn.sd().kind == "throw" and dfn.state_frame < dfn.sd().first_active and not atk.sd().untechable:
		atk.set_state("throw_tech")
		dfn.set_state("throw_tech")
		return
	var counter := counter_type(dfn)
	var hold: String = atk.sd().name + "_hit"
	var back := atk.state_name() == "throw_back"
	atk.set_state(hold)
	atk.vx = 0
	if back:
		atk.facing = -atk.facing # 后投：抓住后转身，把对手放到原来的身后
	dfn.set_state("thrown")
	dfn.vx = 0
	dfn.vy = 0
	dfn.counter_type = counter


## 打康类型由被打者"当前招式所处阶段"决定：发生/持续 → Counter，收招 → Punish Counter。
## 招架中被投算 Punish Counter（SF6）。
static func counter_type(dfn: Fighter) -> int:
	var s := dfn.sd()
	if s.logic == "parry":
		return Counter.PUNISH
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
		"special", "drive":
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
	var fx := {"strength": hd.strength, "counter": counter, "dir": dir, "super": hd.source == "super",
		"drive": hd.source == "drive", "target": dfn.index}
	if not blocked and _absorbs(dfn, hd):
		_armor_hit(sim, dfn, hd, melee)
		sim.emit("armor", point[0], point[1], fx)
		return
	sim.emit("block" if blocked else "hit", point[0], point[1], fx)
	var crouching := dfn.input_at(sim.frame) & InputBits.DOWN != 0
	var was_juggled := dfn.state_name() in JUGGLE_STATES
	var free := dfn.sd().logic in FREE_COMBO

	var attacker := melee if melee != null else sim.opponent(dfn)
	if blocked:
		dfn.health = maxi(dfn.health - chip_damage(dfn, hd), _floor(sim, dfn, hd))
		dfn.reset_combo()
		dfn.wall_fx = HitDef.Wall.STUN if hd.burnout_stun and dfn.burnout != 0 else HitDef.Wall.NONE
		Gauges.gain(attacker, Gauges.SUPER, hd.meter / 2)
		Gauges.gain(dfn, Gauges.SUPER, DEFENDER_METER)
		Gauges.drain(dfn, Gauges.DRIVE, hd.drive_block)
	else:
		Gauges.gain(attacker, Gauges.SUPER, hd.meter)
		Gauges.gain(dfn, Gauges.SUPER, DEFENDER_METER)
		if attacker.burnout == 0:
			Gauges.gain(attacker, Gauges.DRIVE, hd.drive / 2)
		var damage := scaled_damage(dfn, hd.damage, hd.min_scale)
		if dfn.pp_scale != 0:
			damage = damage * PERFECT_PARRY_PCT / 100
		if counter != Counter.NONE:
			damage = damage * COUNTER_DAMAGE_PCT / 100
		if dfn.combo_hits == 0:
			dfn.combo_light = 1 if hd.strength == 0 else 0
		dfn.combo_hits += 1
		dfn.combo_damage += damage
		dfn.health = maxi(dfn.health - damage, _floor(sim, dfn, hd))
		dfn.counter_type = counter
		if counter != Counter.NONE:
			dfn.counter_timer = COUNTER_DISPLAY
		if counter == Counter.PUNISH:
			Gauges.drain(dfn, Gauges.DRIVE, hd.drive * PUNISH_DRIVE_PCT / 100)

	if blocked and dfn.health > 0:
		dfn.set_state("block_crouch" if crouching else "block_stand")
		dfn.stun = hd.blockstun + (BURNOUT_BLOCKSTUN if dfn.burnout != 0 else 0)
		dfn.vx = hd.block_push * dir
	else:
		var effect := hit_effect(hd, counter)
		if effect == HitDef.Effect.CRUMPLE and dfn.is_airborne():
			effect = HitDef.Effect.KNOCKDOWN
		if dfn.wall_used == 0:
			dfn.wall_fx = hd.wall
		dfn.down_frames = hd.down
		dfn.hard_kd = 1 if hd.hard_kd else 0
		var launched := dfn.is_airborne() or effect == HitDef.Effect.KNOCKDOWN or effect == HitDef.Effect.LAUNCH \
			or dfn.health <= 0
		if launched:
			dfn.juggle = dfn.juggle + hd.juggle_add if was_juggled else hd.juggle_start
			# 已经在追打中的对手被普通招式打中仍然会倒地（不在空中重置）
			var stays_down := was_juggled and dfn.knockdown != 0
			dfn.set_state("hit_air")
			dfn.vx = hd.air_vx * dir
			dfn.vy = hd.air_vy if effect == HitDef.Effect.LAUNCH or dfn.is_airborne() else 500
			dfn.y = maxi(dfn.y, 1)
			dfn.knockdown = 1 if effect != HitDef.Effect.NORMAL or dfn.health <= 0 or stays_down else 0
		elif effect == HitDef.Effect.CRUMPLE:
			dfn.set_state("crumple")
			dfn.stun = CRUMPLE_FRAMES
			dfn.vx = hd.push * dir
		else:
			var was_crouching := dfn.sd().type == "C" and not free
			dfn.hit_var = hit_variant(dfn, hd, point, attacker)
			dfn.set_state("hit_crouch" if was_crouching else "hit_stand")
			dfn.stun = hd.hitstun + COUNTER_HITSTUN.get(counter, 0)
			dfn.vx = hd.push * dir
	dfn.facing = -dir
	var hitstop: int = hd.hitstop + COUNTER_HITSTOP.get(counter, 0)
	dfn.hitstop = hitstop
	if melee != null:
		melee.hitstop = hitstop
		melee.contact = 1 if blocked else 2
		melee.last_hitstop = hitstop
		dfn.push_transfer = 1


## 正在 Drive Parry：打击和道具都被招架（投除外，投由投判定处理）。
static func parrying(f: Fighter) -> bool:
	return f.sd().logic == "parry"


## 招架成功：不受伤、回 Drive、双方顿帧（攻击方像被防一样可以取消）。
## 开始招架后 PERFECT_PARRY_WINDOW 帧内被打 = 完美招架：攻击方停顿 30 帧，防御方立刻可以行动，之后的反击连段伤害减半。
static func apply_parry(sim: MatchSim, source_x: int, dfn: Fighter, hd: HitDef, melee: Fighter,
		point := PackedInt32Array()) -> void:
	var dir := signi(dfn.x - source_x)
	if dir == 0:
		dir = -dfn.facing
	if point.is_empty():
		point = PackedInt32Array([dfn.x - dir * dfn.def.push_half_width / 2, dfn.y + dfn.push_height() * 2 / 3])
	var perfect := dfn.state_frame < PERFECT_PARRY_WINDOW
	sim.emit("perfect_parry" if perfect else "parry", point[0], point[1],
		{"strength": hd.strength, "counter": 0, "dir": dir, "super": false, "target": dfn.index})
	if dfn.burnout == 0:
		Gauges.gain(dfn, Gauges.DRIVE, PARRY_GAIN)
	dfn.facing = -dir
	if perfect:
		dfn.set_state("stand")
		dfn.hitstop = 0
		if melee != null:
			melee.hitstop = PERFECT_PARRY_FREEZE
			melee.contact = 1
			melee.last_hitstop = 0
			melee.pp_scale = 1
		return
	dfn.vx = hd.block_push * PARRY_PUSH_PCT / 100 * dir
	dfn.hitstop = hd.hitstop
	if melee != null:
		melee.hitstop = hd.hitstop
		melee.contact = 1
		melee.last_hitstop = hd.hitstop


## 血量下限：训练模式的锁血，或不能打死的招式（Drive Reversal）。
static func _floor(sim: MatchSim, dfn: Fighter, hd: HitDef) -> int:
	return maxi(sim.health_floor, mini(1, dfn.health) if hd.no_ko else 0)


## 实际的命中效果：确反替换 > 打康替换 > 本来的效果。
static func hit_effect(hd: HitDef, counter: int) -> int:
	if counter == Counter.PUNISH and hd.punish_effect >= 0:
		return hd.punish_effect
	if counter != Counter.NONE and hd.counter_effect >= 0:
		return hd.counter_effect
	return hd.effect


## 受击方带着撞墙效果碰到舞台墙（不是屏幕墙）：贴墙或弹墙，每个连段一次。match_sim 在推挤后每帧调用。
static func check_wall(sim: MatchSim, f: Fighter) -> void:
	if f.wall_fx == HitDef.Wall.NONE or f.wall_used != 0 or f.sd().kind != "hurt":
		return
	var limit := sim.stage.half_width - f.def.push_half_width
	if absi(f.x) < limit:
		return
	var side := signi(f.x)
	f.wall_used = 1
	var fx := f.wall_fx
	f.wall_fx = HitDef.Wall.NONE
	f.facing = side # 背对墙、面朝场内
	if fx == HitDef.Wall.STUN:
		# Burnout 中防住 Drive Impact 被推到墙上：眩晕
		f.set_state("dizzy")
		f.vx = 0
		sim.emit("stun", f.x, f.y + f.push_height(), {"target": f.index, "dir": side})
	elif fx == HitDef.Wall.SPLAT:
		f.set_state("wall_splat")
		f.vx = 0
		f.vy = 0
		f.y = maxi(f.y, WALL_SPLAT_Y)
		f.juggle = 0
		f.knockdown = 1
		sim.emit("wall_splat", f.x + side * f.def.push_half_width, f.y + f.push_height() / 2, {"target": f.index, "dir": side})
	else:
		if f.state_name() != "hit_air":
			f.set_state("hit_air")
		f.vx = -side * WALL_BOUNCE_VX
		f.vy = WALL_BOUNCE_VY
		f.y = maxi(f.y, 1)
		f.juggle = 0
		f.knockdown = 1
		sim.emit("wall_bounce", f.x + side * f.def.push_half_width, f.y + f.push_height() / 2, {"target": f.index, "dir": side})
	f.hitstop = WALL_HITSTOP
	var opp := sim.opponent(f)
	opp.hitstop = maxi(opp.hitstop, WALL_HITSTOP)


## 受击动画变体（纯表现，AnimClock.HIT_SUFFIX）：上下段 * 3 + 强度。
## 打在被打方身高 60% 以上、或攻击方在空中算上段（头部后仰），下段判定和打在身体上算下段（弯腰）。
static func hit_variant(dfn: Fighter, hd: HitDef, point: PackedInt32Array, attacker: Fighter) -> int:
	var low := hd.guard == HitDef.Guard.LOW or point[1] - dfn.y < dfn.def.stand_height * HIGH_HIT_PCT / 100
	if attacker.is_airborne() and hd.guard != HitDef.Guard.LOW:
		low = false
	return (3 if low else 0) + clampi(hd.strength, 0, 2)


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
	sim.emit("hit", dfn.x, dfn.y + 6000, {"strength": 2, "counter": dfn.counter_type, "dir": atk.facing, "super": false,
		"target": dfn.index})
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
	dfn.down_frames = hd.down
	dfn.hard_kd = 1 # 投总是硬倒地
	dfn.wall_fx = hd.wall
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
		var point := PackedInt32Array([p.x + p.facing * 1500, p.y])
		if parrying(dfn):
			apply_parry(sim, p.x, dfn, hd, null, point)
		else:
			var blocked := can_block(sim, dfn, p.x, hd)
			apply_hit(sim, p.x, p.facing, dfn, hd, blocked, null, Counter.NONE if blocked else counter_type(dfn), point)
		p.hits -= 1
		p.cooldown = sim.projectile_def(p).hit_interval
	var alive: Array[Projectile] = []
	for p in ps:
		if p.hits > 0:
			alive.append(p)
	sim.projectiles = alive
