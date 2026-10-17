class_name Fighter
extends RefCounted
## 角色的运行时状态。这里的每个字段都必须是整数（或整数数组），并完整出现在
## save_state/load_state 中，否则会破坏确定性与回滚。

const HISTORY := 64 ## 输入历史长度（帧）

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
	health = def.max_health
	stun = 0
	hitstop = 0
	air_used = 0
	knockdown = 0
	throw_protect = 0
	push_transfer = 0
	consumed = -1
	contact = 0
	last_hitstop = 0
	reset_combo()
	counter_timer = 0
	history = PackedInt32Array()
	history.resize(HISTORY)
	set_state("stand")


# ---------------------------------------------------------------- 状态

func sd() -> StateDef:
	return moveset.states[state]


func state_name() -> String:
	return moveset.states[state].name


func is_in(state_names: Array) -> bool:
	return state_name() in state_names


func set_state(state_name_: String) -> void:
	state = moveset.id(state_name_)
	state_frame = 0
	fresh = 1
	hit_mask = 0
	push_transfer = 0
	contact = 0
	cmd_index = -1
	armor_used = 0


func reset_combo() -> void:
	combo_hits = 0
	combo_damage = 0
	combo_light = 0
	juggle = 0
	counter_type = 0


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
	var anim: AnimData = s.anim_alts[jump_dir + 1] if s.anim_dir else s.anim_data
	if anim != null:
		local = anim.hurt[AnimClock.frame(s, anim, state_frame, vy, def.jump_velocity)]
	if local.is_empty():
		local = def.body_hurtbox(s.type) + s.extra_hurtboxes_at(state_frame)
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

const _FIELDS := ["x", "y", "vx", "vy", "facing", "state", "state_frame", "fresh", "jump_dir", "health",
	"stun", "hitstop", "hit_mask", "air_used", "knockdown", "throw_protect", "push_transfer", "consumed",
	"contact", "last_hitstop", "combo_hits", "combo_damage", "combo_light", "juggle", "counter_type", "counter_timer",
	"cmd_index", "upgrade_until", "armor_used"]


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
