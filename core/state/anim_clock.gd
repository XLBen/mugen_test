class_name AnimClock
## 逻辑状态 → 动画第几帧。仿真（取逐帧判定盒）和表现层（取贴图）共用同一套规则，保证"画的就是判定的"。
##
## - jump：三帧的按垂直速度选 上升 / 顶点 / 下落；更多帧的是完整的空中弧线（月姬格斗式），
##   按 起跳速度 → 0 → 下落 的进度铺满整个滞空时间
## - 起跳 / 空中 / 落地按跳跃方向换动画（anim_name）
## - 攻击动画（5 帧）：蓄力 / 出手 / 持续 / 收势 / 复原，按招式阶段及阶段内进度切换，与具体帧数解耦
## - 攻击动画（3 帧）：发生 / 持续 / 收招
## - 其他：按每帧时长播放（循环或停在最后一帧）

const UP_SPEED := 600
const DIR_SUFFIX := ["_b", "", "_f"]


## 状态实际使用的动画名：分方向的状态在前跳 / 后跳时用 <anim>_f / <anim>_b（没有这套动画时由调用方退回 anim）。
static func anim_name(s: StateDef, jump_dir: int) -> String:
	return s.anim + DIR_SUFFIX[jump_dir + 1] if s.anim_dir else s.anim


## vy0：起跳速度（完整空中弧线按它算进度）。
static func frame(s: StateDef, anim: AnimData, state_frame: int, vy: int, vy0 := 0) -> int:
	var count := anim.count()
	if count == 0:
		return 0
	if s.anim == "jump":
		if count > 3 and vy0 > 0:
			var length := anim.ends[-1]
			return anim.index_at_time(clampi((vy0 - vy) * length / (2 * vy0), 0, length - 1))
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
