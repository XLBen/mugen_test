class_name Fighter
extends RefCounted
## 角色的运行时状态。这里的每个字段都必须是整数（或整数数组），并完整出现在
## save_state/load_state 中，否则会破坏确定性与回滚。

const HISTORY := 64 ## 输入历史长度（帧）

const CROUCH_UP_FRAMES := 6 ## 蹲 → 站的过渡最多几帧
const TURN_FRAMES := 4 ## 转身过渡最多几帧

var def: FighterDef
var moveset: Moveset
var index := 0 ## 玩家索引（0 = P1），不属于可变状态

var x := 0
var y := 0 ## 离地高度，0 = 地面，向上为正
var vx := 0
var vy := 0
var facing := 1 ## 1 = 面朝右，-1 = 面朝左
var state := 0 ## Moveset.states 的索引
var state_frame := 0 ## 进入当前状态后经过的帧数
var fresh := 1 ## 1 = 刚进入状态，第 0 帧逻辑尚未执行
var jump_dir := 0 ## -1 后跳 / 0 垂直跳 / 1 前跳
var hit_var := 0 ## 最近一次被打的受击动画变体：上下段 * 3 + 强度（AnimClock.HIT_SUFFIX）
# 动画尾巴（AnimClock）：上一个状态的动画在可行动状态里继续播的部分
var tail_state := 0 ## 动画来自哪个状态
var tail_var := 0 ## 那个状态当时的变体
var tail_from := 0 ## 从动画的哪个时刻开始
var tail_ticks := 0 ## 剩余动画时长
var tail_len := 0 ## 用几帧播完（0 = 没有尾巴）
var tail_at := 0 ## 尾巴从当前状态的第几帧开始（转身这类在状态中途开始的过渡动画）
var held := 0 ## 当前状态里已经过的超杀暂停帧数（暂停期间动画照播，见 AnimClock.attack_tick）
var health := 0
var stun := 0 ## 当前受击/防御硬直的长度
var hitstop := 0 ## 剩余顿帧
var hit_mask := 0 ## 当前状态里已经命中过的攻击判定（按 hitboxes 下标）
var air_used := 0 ## 本次跳跃已经出过空中技
var knockdown := 0 ## 当前浮空受击落地后是否倒地
var throw_protect := 0 ## 硬直结束后的投无敌剩余帧
var push_transfer := 0 ## 版边被打时，击退是否反推给攻击方
var consumed := -1 ## 最近一次被指令消耗的按键帧
var contact := 0 ## 当前招式是否已接触对手：0 无 / 1 被防 / 2 命中（取消窗口用）
var last_hitstop := 0 ## 最近一次接触的顿帧长度（取消时延长按键缓冲）
# 以下是"作为被打方"的连段状态，恢复可行动时清零
var combo_hits := 0
var combo_damage := 0
var combo_light := 0 ## 连段由轻攻击起手（额外补正）
var juggle := 0 ## 浮空追打计数
var counter_type := 0 ## 最近一次被打的打康类型（Combat.Counter）
var counter_timer := 0 ## 打康提示剩余显示帧
var cmd_index := -1 ## 当前招式由出招表第几条指令发动（-1 = 不是指令发动的）
var upgrade_until := -1 ## 这一帧之前，可以被更高优先级的指令"升级"（同时按宽容）
var armor_used := 0 ## 当前状态已经吸收的打击次数
var wall_fx := 0 ## 这次受击撞到舞台墙时的效果（HitDef.Wall），离开受击清零
var wall_used := 0 ## 本连段已经撞过墙
var down_frames := HitDef.DOWN_FRAMES ## 这次倒地躺多久
var hard_kd := 0 ## 这次倒地不能后滚
var pp_scale := 0 ## 被完美招架后的反击：本连段伤害减半
var reversal_buffer := 0 ## 起身后的第一帧：指令用长缓冲（起身反击）
var history := PackedInt32Array() ## 输入历史，按 frame % HISTORY 存放
var gauges := PackedInt32Array() ## 资源槽当前值（Gauges.DEFS 顺序）
var gauge_delay := PackedInt32Array() ## 资源槽回复停顿剩余帧
var burnout := 0 ## Drive 耗尽状态


func _init(p_def: FighterDef) -> void:
	set_def(p_def)


func set_def(p_def: FighterDef) -> void:
	def = p_def
	moveset = Moveset.for_def(def)


## keep_gauges：回合之间保留标记为跨回合的槽（超杀槽）。
func reset_state(keep_gauges := false) -> void:
	Gauges.reset(self, keep_gauges)
	x = 0
	y = 0
	vx = 0
	vy = 0
	facing = 1
	jump_dir = 0
	hit_var = 0
	health = def.max_health
	stun = 0
	hitstop = 0
	air_used = 0
	knockdown = 0
	throw_protect = 0
	push_transfer = 0
	wall_fx = 0
	down_frames = HitDef.DOWN_FRAMES
	hard_kd = 0
	consumed = -1
	contact = 0
	last_hitstop = 0
	reset_combo()
	counter_timer = 0
	history = PackedInt32Array()
	history.resize(HISTORY)
	set_state("stand")
	tail_len = 0


# ---------------------------------------------------------------- 状态

func sd() -> StateDef:
	return moveset.states[state]


func state_name() -> String:
	return moveset.states[state].name


func is_in(state_names: Array) -> bool:
	return state_name() in state_names


func set_state(state_name_: String) -> void:
	# 离开攻击 / 落地等状态时，剩下的动画交给下一个可行动状态继续播（AnimClock 尾巴）
	var valid := state < moveset.states.size() # 换角色后旧的状态索引可能不属于新招式表
	var tail: Array[int] = AnimClock.tail_after(self, sd(), state_frame) if valid else []
	var old_state := state
	var old_var := AnimClock.variant(self, sd()) if valid else 0
	state = moveset.id(state_name_)
	tail_len = 0
	if not tail.is_empty() and sd().tail_ok:
		tail_state = old_state
		tail_var = old_var
		tail_from = tail[0]
		tail_ticks = tail[1]
		tail_len = tail[2]
	state_frame = 0
	tail_at = 0
	held = 0
	fresh = 1
	# 从蹲回到站：没有别的尾巴时播一段起身过渡
	if tail_len == 0 and valid and moveset.states[old_state].type == "C" and moveset.states[old_state].ctrl \
			and sd().name == "stand":
		play_transition("crouch_up", CROUCH_UP_FRAMES)
	hit_mask = 0
	push_transfer = 0
	contact = 0
	cmd_index = -1
	armor_used = 0


## 过渡动画（起身、转身）：借尾巴机制在当前状态里播一段指定动画，只影响画面和受击盒；没有这套动画就不播。
func play_transition(anim_state: String, max_frames: int) -> void:
	if not moveset.index.has(anim_state):
		return
	var s: StateDef = moveset.states[moveset.id(anim_state)]
	if s.anim_data == null:
		return
	tail_state = moveset.id(anim_state)
	tail_var = 0
	tail_from = 0
	tail_ticks = s.anim_data.length()
	tail_len = mini(max_frames, tail_ticks)
	tail_at = state_frame


func reset_combo() -> void:
	combo_hits = 0
	combo_damage = 0
	combo_light = 0
	juggle = 0
	counter_type = 0
	wall_used = 0
	pp_scale = 0


func is_airborne() -> bool:
	return y > 0 or sd().type == "A"


func push_height() -> int:
	match sd().type:
		"C":
			return def.crouch_height
		"L":
			return def.down_height
		"A":
			return def.air_height
		_:
			return def.stand_height


## 推挤盒底边离脚底的高度（空中抬高，方便越身）。
func push_bottom() -> int:
	return y + (def.air_push_offset if sd().type == "A" else 0)


func push_left() -> int:
	return x - def.push_half_width


func push_right() -> int:
	return x + def.push_half_width


## 当前帧的世界受击盒：按状态类型的身体盒 + 招式额外受击盒（伸出的手脚）。
func hurtboxes() -> Array:
	var s := sd()
	var local: Array
	var anim := AnimClock.sim_anim(self)
	if anim != null:
		local = anim.hurt[AnimClock.index(self, anim)]
	if local.is_empty():
		local = def.body_hurtbox(s.type) + s.extra_hurtboxes_at(state_frame)
	elif s.kind == "hurt" and (s.type == "S" or s.type == "C"):
		# 地面受击 / 防御中，受击盒至少包含身体盒：后仰的受击姿势不会让连段比 SF6 更容易断
		local = local + def.body_hurtbox(s.type)
	var out := []
	for b: PackedInt32Array in local:
		out.append(Box.to_world(x, y, facing, b))
	return out


func pushbox_world() -> PackedInt32Array:
	var b := push_bottom()
	return PackedInt32Array([push_left(), b, push_right(), b + push_height()])


# ---------------------------------------------------------------- 输入

func record_input(frame: int, bits: int) -> void:
	history[frame % HISTORY] = bits


func input_at(frame: int) -> int:
	if frame < 0:
		return 0
	return history[frame % HISTORY]


func pressed_at(frame: int) -> int:
	return input_at(frame) & ~input_at(frame - 1) & InputBits.BUTTONS


func numpad_at(frame: int) -> int:
	return InputBits.to_numpad(input_at(frame), facing)


# ---------------------------------------------------------------- 存档

const _FIELDS := ["x", "y", "vx", "vy", "facing", "state", "state_frame", "fresh", "jump_dir", "hit_var",
	"tail_state", "tail_var", "tail_from", "tail_ticks", "tail_len", "tail_at", "held", "health",
	"stun", "hitstop", "hit_mask", "air_used", "knockdown", "throw_protect", "push_transfer", "consumed",
	"contact", "last_hitstop", "combo_hits", "combo_damage", "combo_light", "juggle", "counter_type", "counter_timer",
	"cmd_index", "upgrade_until", "armor_used", "wall_fx", "wall_used", "down_frames", "hard_kd", "pp_scale", "reversal_buffer"]


func save_state() -> Dictionary:
	var s := {}
	for field: String in _FIELDS:
		s[field] = get(field)
	s.history = history.duplicate()
	s.gauges = gauges.duplicate()
	s.gauge_delay = gauge_delay.duplicate()
	s.burnout = burnout
	return s


func load_state(s: Dictionary) -> void:
	for field: String in _FIELDS:
		set(field, s[field])
	history = s.history.duplicate()
	gauges = s.gauges.duplicate()
	gauge_delay = s.gauge_delay.duplicate()
	burnout = s.burnout


## 参与状态哈希的整数序列，顺序固定。
func hash_values() -> Array[int]:
	var out: Array[int] = []
	for field: String in _FIELDS:
		out.append(get(field))
	for arr in [history, gauges, gauge_delay]:
		for v in arr:
			out.append(v)
	out.append(burnout)
	return out
