class_name StateRunner
## 每帧推进一名角色：顿帧 → 帧号推进 → 状态逻辑（可连锁转移）→ 帧事件 → 物理。
##
## 帧号约定：set_state() 把 state_frame 置 0 并标记 fresh；下次更新时不推进帧号，
## 直接执行第 0 帧。这样被打进入硬直的角色会在顿帧结束后从第 0 帧开始，
## 攻击方则在顿帧结束后接着下一帧继续，不会重复执行同一帧的事件。

const MAX_CHAIN := 4 ## 同一帧内最多连续转移几次状态


static func update(f: Fighter, sim: MatchSim) -> void:
	if f.counter_timer > 0:
		f.counter_timer -= 1
	if f.hitstop > 0:
		f.hitstop -= 1
		return
	if f.fresh == 0:
		f.state_frame += 1
	f.fresh = 0
	if f.throw_protect > 0 and f.sd().kind != "hurt":
		f.throw_protect -= 1

	# 恢复可行动（不在受击/防御/被投中）即连段结束
	if f.sd().kind != "hurt" and f.combo_hits + f.juggle > 0:
		f.reset_combo()

	for i in MAX_CHAIN:
		var s := f.sd()
		if CommonStates.try_upgrade(f, sim):
			pass
		elif f.contact != 0 and s.can_cancel(f.state_frame) and CommonStates.try_cancel(f, sim):
			pass
		elif s.total > 0 and f.state_frame >= s.total:
			f.set_state(s.next)
			f.throw_protect = maxi(f.throw_protect, s.throw_protect)
		elif s.logic != "":
			CommonStates.run(s.logic, f, sim)
		if f.fresh == 0:
			break
		f.fresh = 0

	_events(f, sim)
	_physics(f)


static func _events(f: Fighter, sim: MatchSim) -> void:
	for e: Dictionary in f.sd().events:
		if e.frame != f.state_frame:
			continue
		if e.has("vx"):
			f.vx = e.vx * f.facing
		if e.has("vy"):
			f.vy = e.vy
		if e.has("freeze"):
			sim.freeze = e.freeze
			sim.emit("super", f.x, f.y + 12000)
		if e.has("spawn"):
			sim.spawn_projectile(f, e.spawn, e.get("x", 0) * SimConst.UNITS_PER_PX, e.get("y", 0) * SimConst.UNITS_PER_PX)


static func _physics(f: Fighter) -> void:
	var s := f.sd()
	if s.physics == "none":
		return
	f.x += f.vx
	var airborne := s.air_from >= 0 and f.state_frame >= s.air_from
	if not airborne:
		if s.friction > 0 and f.vx != 0:
			f.vx = maxi(f.vx - s.friction, 0) if f.vx > 0 else mini(f.vx + s.friction, 0)
		return
	f.y += f.vy
	if f.y <= 0:
		_land(f)
	else:
		f.vy -= f.def.gravity


static func _land(f: Fighter) -> void:
	f.y = 0
	f.vx = 0
	f.vy = 0
	f.air_used = 0
	var target := f.sd().land
	if target == "@hurt":
		target = "knockdown" if f.knockdown != 0 or f.health <= 0 else "land_recover"
	f.knockdown = 0
	if target != "landing":
		f.jump_dir = 0 # 不是普通跳跃的落地（升龙、被打落地）不用分方向的落地动画
	f.set_state(target)
	# 落地这一帧本身就是落地状态的第 0 帧
	f.fresh = 0
