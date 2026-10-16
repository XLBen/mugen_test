class_name Combat
## 每帧的命中检测与结算。先收集本帧所有碰撞，再统一结算，P1/P2 处理完全对称：
##   1. 投 vs 投 → 双方拆投；投 vs 打 → 打击优先（投被打断）
##   2. 打 vs 打 → 相打，双方都吃到
##   3. 道具 vs 道具 → 互相抵消耐久
##   4. 道具 vs 角色
## 防御判定使用结算前的状态，所以相打时双方都不会"防住"。

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

	# 先做全部防御判定，再统一应用（相打）
	var decisions := []
	for st: Array in strikes:
		decisions.append(can_block(sim, st[1], st[0].x, st[3]))
	for i in strikes.size():
		var st: Array = strikes[i]
		st[0].hit_mask |= 1 << st[2]
		apply_hit(sim, st[0].x, st[0].facing, st[1], st[3], decisions[i], st[0])

	_resolve_projectiles(sim)


static func _find_strike(atk: Fighter, dfn: Fighter, s: StateDef) -> Array:
	if dfn.sd().is_invuln(dfn.state_frame, false):
		return []
	var hurt := dfn.hurtboxes()
	var i := 0
	for h: Dictionary in s.hitboxes:
		if atk.state_frame >= h.from and atk.state_frame <= h.to and not (atk.hit_mask & (1 << i)):
			var world := []
			for b: PackedInt32Array in h.boxes:
				world.append(Box.to_world(atk.x, atk.y, atk.facing, b))
			if Box.any_overlap(world, hurt):
				return [atk, dfn, i, h.hit]
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
	var hold: String = atk.sd().name + "_hit"
	atk.set_state(hold)
	atk.vx = 0
	dfn.set_state("thrown")
	dfn.vx = 0
	dfn.vy = 0


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


## 应用一次命中/防御。push_dir 为击退方向（远离攻击来源）；melee 为 null 表示飞行道具。
static func apply_hit(sim: MatchSim, source_x: int, source_facing: int, dfn: Fighter, hd: HitDef,
		blocked: bool, melee: Fighter) -> void:
	var dir := signi(dfn.x - source_x)
	if dir == 0:
		dir = source_facing
	var crouching := dfn.input_at(sim.frame) & InputBits.DOWN != 0
	dfn.health = maxi(dfn.health - (hd.chip if blocked else hd.damage), 0)
	if blocked and dfn.health > 0:
		dfn.set_state("block_crouch" if crouching else "block_stand")
		dfn.stun = hd.blockstun
		dfn.vx = hd.block_push * dir
	else:
		var launched := dfn.is_airborne() or hd.effect != HitDef.Effect.NORMAL or dfn.health <= 0
		if launched:
			dfn.set_state("hit_air")
			dfn.vx = hd.air_vx * dir
			dfn.vy = hd.air_vy if hd.effect == HitDef.Effect.LAUNCH or dfn.is_airborne() else 500
			dfn.y = maxi(dfn.y, 1)
			dfn.knockdown = 1 if hd.effect != HitDef.Effect.NORMAL or dfn.health <= 0 else 0
		else:
			var was_crouching := dfn.sd().type == "C"
			dfn.set_state("hit_crouch" if was_crouching else "hit_stand")
			dfn.stun = hd.hitstun
			dfn.vx = hd.push * dir
	dfn.facing = -dir
	dfn.hitstop = hd.hitstop
	if melee != null:
		melee.hitstop = hd.hitstop
		dfn.push_transfer = 1


static func apply_throw_release(sim: MatchSim, atk: Fighter, dfn: Fighter, hd: HitDef) -> void:
	dfn.health = maxi(dfn.health - hd.damage, 0)
	dfn.set_state("hit_air")
	dfn.vx = hd.air_vx * atk.facing
	dfn.vy = hd.air_vy
	dfn.y = 1
	dfn.knockdown = 1
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
			if Box.overlap(sim.projectile_box(a), sim.projectile_box(b)):
				a.hits -= 1
				b.hits -= 1
	# 道具命中角色
	for p in ps:
		if p.hits <= 0:
			continue
		var dfn := sim.fighters[1 - p.owner]
		if dfn.sd().is_invuln(dfn.state_frame, false):
			continue
		if not Box.any_overlap([sim.projectile_box(p)], dfn.hurtboxes()):
			continue
		var hd := sim.projectile_def(p).hit
		apply_hit(sim, p.x, p.facing, dfn, hd, can_block(sim, dfn, p.x, hd), null)
		p.hits -= 1
	var alive: Array[Projectile] = []
	for p in ps:
		if p.hits > 0:
			alive.append(p)
	sim.projectiles = alive
