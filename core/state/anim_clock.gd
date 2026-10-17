class_name AnimClock
## 逻辑状态 → 动画第几帧。仿真（取逐帧判定盒）和表现层（取贴图）共用同一套规则，保证"画的就是判定的"。
##
## - jump：按垂直速度选 上升 / 顶点 / 下落
## - 攻击动画（5 帧）：蓄力 / 出手 / 持续 / 收势 / 复原，按招式阶段及阶段内进度切换，与具体帧数解耦
## - 攻击动画（3 帧）：发生 / 持续 / 收招
## - 其他：按每帧时长播放（循环或停在最后一帧）

const UP_SPEED := 600


static func frame(s: StateDef, anim: AnimData, state_frame: int, vy: int) -> int:
	var count := anim.count()
	if count == 0:
		return 0
	if s.anim == "jump":
		return mini(0 if vy > UP_SPEED else (2 if vy < -UP_SPEED else 1), count - 1)
	var phase := s.phase_at(state_frame)
	if phase != StateDef.Phase.NONE and count >= 3:
		if count < 5:
			return phase - 1
		match phase:
			StateDef.Phase.STARTUP:
				return 0 if state_frame * 2 < s.first_active else 1
			StateDef.Phase.ACTIVE:
				return 2
		var into := state_frame - s.last_active - 1
		var length := s.total - s.last_active - 1 if s.total > 0 else 12
		return 3 if into * 2 < length else 4
	return anim.index_at_time(state_frame)
