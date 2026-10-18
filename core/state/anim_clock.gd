class_name AnimClock
## 逻辑状态 → 显示哪个动画的第几帧。仿真（取逐帧判定盒）和表现层（取贴图）共用同一套规则，保证"画的就是判定的"。
##
## - 动画名：状态的基础动画 + 变体后缀（跳跃方向 _f/_b；受击的上下段 / 强度 _hi_l … _lo_h），没有这套就退回基础动画
## - jump：三帧的按垂直速度选 上升 / 顶点 / 下落；更多帧的是完整空中弧线，按 起跳速度 → 0 → 下落 的进度铺满
## - 攻击：动画的 发生 / 持续 / 收招 段分别对齐到招式的发生帧、持续帧、收招帧（持续帧必定显示有攻击盒的帧）；
##   发生段按原速播到预备姿势后停住等出手（蓄势），比发生帧长时加速、最多 2 倍速，再长就只播后面一段；
##   超杀暂停期间预备动作照播（暂停帧数算进发生段）；
##   收招段按原速播放，太长时才加速、太短时稍微放慢，播不完的部分在下一个可行动状态里作为"尾巴"继续播
## - 受击 / 防御：受击段从顿帧开始按原速播放并停住，恢复段放在硬直的最后几帧
## - 浮空受击：上升时按时长播放，下落时按下落速度播放下落段
## - 其他：按时长播放；有固定总帧数的状态太长时同样加速并把剩余部分交给尾巴
## - 尾巴：攻击 / 落地 / 起身之类结束、进入可行动状态（tail_ok）后，继续播原动画剩下的部分，
##   期间任何状态切换都会打断它；只影响画面与受击盒，不影响可行动时间

const UP_SPEED := 600
const TAIL_MAX := 12 ## 尾巴最长帧数
const STARTUP_MAX_SPEED := 2 ## 发生段最多按 2 倍速播放：预备动作更长时只播后面一段（开头的起势直接跳过），免得像快进
const STRETCH_MAX := [3, 2] ## 动画比给它的帧数短时最多放慢到 3/2，再短就停在最后一帧（免得一下播完然后定住）
## 变体后缀表（按 Fighter 上的变体值索引）
const JUMP_SUFFIX := ["_b", "", "_f"]
const HIT_SUFFIX := ["_hi_l", "_hi_m", "_hi_h", "_lo_l", "_lo_m", "_lo_h"]
const STRENGTH_SUFFIX := ["_l", "_m", "_h"]
const HOLD_IMPACT := ["crumple", "dizzy"] ## 这些逻辑的状态借用受击动画时停在受击姿势
const STRIDE_RATE := [50, 250] ## 按移动速度播放走路动画时的倍速范围（%）


# ---------------------------------------------------------------- 选动画

## 状态有几个变体（anim_alts 的长度）。
static func variant_count(s: StateDef) -> int:
	match s.variants:
		"jump":
			return JUMP_SUFFIX.size()
		"hit":
			return HIT_SUFFIX.size()
	return 1


## 当前状态的变体值。
static func variant(f: Fighter, s: StateDef) -> int:
	match s.variants:
		"jump":
			return f.jump_dir + 1
		"hit":
			return f.hit_var
	return 0


## 某个变体依次尝试的动画名（先精确，再退化，最后是基础动画）。
static func candidates(s: StateDef, v: int) -> PackedStringArray:
	var out := PackedStringArray()
	match s.variants:
		"jump":
			if JUMP_SUFFIX[v] != "":
				out.append(s.anim + JUMP_SUFFIX[v])
		"hit":
			if s.type == "C":
				out.append(s.anim + STRENGTH_SUFFIX[v % 3])
			else:
				out.append(s.anim + HIT_SUFFIX[v])
				out.append(s.anim + STRENGTH_SUFFIX[v % 3])
	out.append(s.anim)
	for alt: String in s.anim_fallback:
		out.append(alt)
	return out


static func has_tail(f: Fighter) -> bool:
	return f.tail_len > 0 and f.state_frame < f.tail_len and f.sd().tail_ok


## 当前显示的是哪个状态的动画（尾巴期间是上一个状态的）。
static func shown_state(f: Fighter) -> StateDef:
	return f.moveset.states[f.tail_state] if has_tail(f) else f.sd()


static func shown_variant(f: Fighter) -> int:
	return f.tail_var if has_tail(f) else variant(f, f.sd())


## 仿真层：当前显示的动画数据（没有逐帧数据时为 null）。
static func sim_anim(f: Fighter) -> AnimData:
	return state_anim(shown_state(f), shown_variant(f))


## 状态某个变体的动画数据（没有逐帧数据时为 null）。
static func state_anim(s: StateDef, v: int) -> AnimData:
	return s.anim_alts[v] if v < s.anim_alts.size() else s.anim_data


# ---------------------------------------------------------------- 选帧

## 当前应显示 anim 的第几帧（anim 必须是 shown_state 对应的动画）。
static func index(f: Fighter, anim: AnimData) -> int:
	if anim.count() == 0:
		return 0
	if has_tail(f):
		return anim.index_at_time(f.tail_from + f.state_frame * f.tail_ticks / f.tail_len)
	return frame(f, f.sd(), anim)


static func frame(f: Fighter, s: StateDef, anim: AnimData) -> int:
	var count := anim.count()
	if count == 0:
		return 0
	var t := f.state_frame
	if s.anim == "jump":
		var vy0 := f.def.jump_velocity
		if count > 3 and vy0 > 0:
			var length := anim.length()
			return anim.index_at_time(clampi((vy0 - f.vy) * length / (2 * vy0), 0, length - 1))
		return mini(0 if f.vy > UP_SPEED else (2 if f.vy < -UP_SPEED else 1), count - 1)
	if s.first_active >= 0 and anim.has_phase(AnimData.Phase.ACTIVE):
		return anim.index_at_time(attack_tick(s, anim, t, f.held))
	if anim.stride > 0 and f.vx != 0:
		# 走路：按实际移动速度和原作速度之比加快 / 放慢动画，脚步和位移对得上（不打滑）
		var rate := clampi(absi(f.vx) * 100 / anim.stride, STRIDE_RATE[0], STRIDE_RATE[1])
		return anim.index_at_time(t * rate / 100)
	if s.logic == "down":
		return anim.index_at_time(_budget_tick(t, anim.length(), f.down_frames))
	if s.logic in HOLD_IMPACT and anim.has_phase(AnimData.Phase.RECOVERY):
		# 崩溃 / 眩晕：借用受击动画时只播受击段并停住，不播站回来的恢复段
		return anim.index_at_time(mini(t, maxi(anim.segment(AnimData.Phase.RECOVERY).x - 1, 0)))
	if s.logic == "hurt" and anim.has_phase(AnimData.Phase.RECOVERY):
		return anim.index_at_time(_hurt_tick(anim, t, f.stun))
	if anim.has_phase(AnimData.Phase.FALL):
		return anim.index_at_time(_fall_tick(anim, t, f.vy, f.def.jump_velocity))
	if s.total > 0 and not anim.loop:
		return anim.index_at_time(_budget_tick(t, anim.length(), s.total))
	return anim.index_at_time(t)


## 攻击动画在招式第 t 帧时的动画时刻（不需要 Fighter，判定盒预处理也用它）。
## held：已经过的超杀暂停帧数（只影响发生段；暂停期间 t 不走，靠它推进预备动作）。
static func attack_tick(s: StateDef, anim: AnimData, t: int, held := 0) -> int:
	var startup := anim.segment(AnimData.Phase.STARTUP)
	var active := anim.segment(AnimData.Phase.ACTIVE)
	if t < s.first_active:
		if startup.y == 0:
			return active.x
		var span := maxi(s.first_active + s.freeze_len, 1)
		var v := mini(t + held, span - 1)
		if startup.y <= span:
			return startup.x + mini(v, startup.y - 1) # 按原速播到预备姿势，停在那里等出手
		var length := mini(startup.y, span * STARTUP_MAX_SPEED)
		return startup.x + startup.y - length + v * length / span
	if t <= s.last_active:
		var span := s.last_active - s.first_active + 1
		return active.x + (t - s.first_active) * active.y / span
	var rec_start := active.x + active.y
	var rec_len := anim.length() - rec_start
	var into := t - s.last_active - 1
	if s.total <= 0:
		return rec_start + into
	return rec_start + _budget_tick(into, rec_len, s.total - s.last_active - 1)


## 动画段长 length、状态给它 frames 帧：超过 frames + TAIL_MAX 时按比例加速；比 frames 短时放慢（最多 STRETCH_MAX）；
## 其余按原速。
static func _budget_tick(into: int, length: int, frames: int) -> int:
	var budget := frames + TAIL_MAX
	if length > budget:
		return into * length / budget
	if length < frames:
		return into * length / mini(frames, length * STRETCH_MAX[0] / STRETCH_MAX[1])
	return into


## 受击 / 防御：恢复段占硬直最后 rec 帧（最多一半），之前播受击段并停在最后一帧。
static func _hurt_tick(anim: AnimData, t: int, stun: int) -> int:
	var rec := anim.segment(AnimData.Phase.RECOVERY)
	var frames := mini(rec.y, stun / 2)
	var rec_from := stun - frames
	if t < rec_from or frames <= 0:
		return mini(t, maxi(rec.x - 1, 0))
	return rec.x + (t - rec_from) * rec.y / frames


## 浮空受击：上升时播下落段之前的帧，下落时按下落速度播下落段。
static func _fall_tick(anim: AnimData, t: int, vy: int, vy0: int) -> int:
	var fall := anim.segment(AnimData.Phase.FALL)
	if vy >= 0:
		return mini(t, maxi(fall.x - 1, 0))
	return fall.x + clampi(-vy * fall.y / maxi(vy0, 1), 0, fall.y - 1)


# ---------------------------------------------------------------- 尾巴

## 离开状态 s（停在第 t 帧）时，动画还剩多少可以作为尾巴：返回 [起始时刻, 剩余时长, 帧数]，没有则为空。
static func tail_after(f: Fighter, s: StateDef, t: int) -> Array[int]:
	if s.tail_ok:
		return []
	var anim := state_anim(s, variant(f, s))
	if anim == null or anim.loop or anim.count() == 0 or s.anim == "jump":
		return []
	var length := anim.length()
	var reached: int
	var frames: int
	if s.first_active >= 0 and anim.has_phase(AnimData.Phase.ACTIVE):
		if t <= s.last_active or s.total <= 0:
			return []
		reached = attack_tick(s, anim, t)
		var active := anim.segment(AnimData.Phase.ACTIVE)
		var rec_len := length - active.x - active.y
		frames = mini(TAIL_MAX, maxi(rec_len - (s.total - s.last_active - 1), 0))
	elif s.logic == "hurt" or anim.has_phase(AnimData.Phase.FALL):
		return []
	else:
		var limit := s.total if s.total > 0 else t
		reached = _budget_tick(t, length, limit) if s.total > 0 else t
		frames = mini(TAIL_MAX, maxi(length - limit, 0))
	var rest := length - reached
	if rest <= 0 or frames <= 0:
		return []
	return [reached, rest, frames]
