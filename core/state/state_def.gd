class_name StateDef
extends RefCounted
## 一个状态的静态数据：标志、帧时间轴（盒子、速度、事件）、退出规则。
## 数据里的帧号从 1 开始书写（第 N 帧 = state_frame N-1），构建时转成从 0 开始。

enum Phase { NONE, STARTUP, ACTIVE, RECOVERY }

var name := ""
var type := "S" ## S 站 / C 蹲 / A 空中 / L 倒地（决定默认受击盒、推挤盒高度）
var kind := "move" ## move / normal / special / super / throw / hurt / guard
var ctrl := false ## 可以接受新指令
var guard_ok := false ## 可以防御
var total := 0 ## >0 时到这一帧自动转入 next
var next := "stand"
var anim := ""
var physics := "ground" ## ground / air / none
var friction := 0 ## 地面减速度（单位/帧²）
var air_from := -1 ## 从第几帧起改用空中物理（升龙这类先在地面后起飞）
var land := "landing" ## 空中物理落地后进入的状态；"@hurt" 表示按击倒标志决定
var logic := "" ## 公共逻辑名（CommonStates.run 分发），空表示纯数据状态
var hurtboxes: Array = [] ## [{from, to, boxes: Array[PackedInt32Array]}]
var hitboxes: Array = [] ## [{from, to, boxes, hit: HitDef}]
var throwbox: Dictionary = {} ## {from, to, box}
var throw_release := -1 ## 投技：在这一帧对被投方结算伤害
var throw_hit: HitDef
var throw_offset := 0 ## 被投方相对投方的位置（单位，向前）
var invuln: Array = [] ## [{from, to, strike, throw}]
var events: Array = [] ## [{frame, vx?, vy?, spawn?}]
var first_active := -1
var last_active := -1
var reach := 0 ## 攻击判定最远能伸到身前多远（单位），近距离防御用
var anim_data: AnimData ## 动画逐帧判定盒（有则受击盒按动画帧取）
var variants := "" ## 动画变体来源："jump"（按跳跃方向）/ "hit"（按受击的上下段与强度），见 AnimClock
var anim_alts: Array = [] ## 每个变体实际使用的 AnimData（按变体值索引）
var tail_ok := false ## 可行动状态：进入时可以继续播上一个招式剩下的动画（尾巴）
var cancel_targets: Array = [] ## 接触对手后可以取消成哪些招：kind 名（special/super）或状态名
var cancel_until := -1 ## 取消窗口最后一帧（默认持续帧结束后 3 帧）
var cost: Dictionary = {} ## 进入此状态消耗的资源 {gauge_name: amount}
var armor: Dictionary = {} ## 霸体 {from, to, hits}：期间吸收 hits 次打击（超杀与投可以破）
var untechable := false ## 投技：被投方不能拆（指令投）
var no_push: Array = [] ## [from, to]：这段帧数不参与推挤（可以穿过对手）
var punishable := false ## 整个状态都算收招（被打 = Punish Counter），如升龙落地硬直
var punishable_from := -1 ## 从第几帧起算收招（后撤步后段）
var freeze_len := 0 ## 发生前的超杀暂停总帧数（暂停期间出招动画继续播预备动作）
var reach_cap := 0 ## >0：动画攻击盒向前最远到这里（单位），原作攻击框太长时收回到招式表的范围


static func build(state_name: String, d: Dictionary) -> StateDef:
	var s := StateDef.new()
	s.name = state_name
	s.type = d.get("type", s.type)
	s.kind = d.get("kind", s.kind)
	s.ctrl = d.get("ctrl", s.ctrl)
	s.guard_ok = d.get("guard_ok", s.guard_ok)
	s.total = d.get("total", s.total)
	s.next = d.get("next", "crouch" if s.type == "C" else s.next)
	s.anim = d.get("anim", state_name)
	s.variants = d.get("variants", "")
	s.tail_ok = d.get("tail_ok", false)
	s.physics = d.get("physics", "air" if s.type == "A" else s.physics)
	s.friction = d.get("friction", s.friction)
	if d.has("air_from"):
		s.air_from = d.air_from - 1
	elif s.physics == "air":
		s.air_from = 0
	s.land = d.get("land", s.land)
	s.logic = d.get("logic", s.logic)
	for h: Dictionary in d.get("hurtboxes", []):
		s.hurtboxes.append({"from": h.frames[0] - 1, "to": h.frames[1] - 1, "boxes": _boxes(h.boxes)})
	for h: Dictionary in d.get("hitboxes", []):
		var hd := HitDef.from_dict(h.hit)
		hd.source = s.kind
		var entry := {"from": h.active[0] - 1, "to": h.active[1] - 1, "boxes": _boxes(h.boxes), "hit": hd}
		s.hitboxes.append(entry)
		for b: PackedInt32Array in entry.boxes:
			s.reach = maxi(s.reach, b[0] + b[2])
		s.first_active = entry.from if s.first_active < 0 else mini(s.first_active, entry.from)
		s.last_active = maxi(s.last_active, entry.to)
	if d.has("throw"):
		var t: Dictionary = d.throw
		s.throwbox = {"from": t.active[0] - 1, "to": t.active[1] - 1, "box": Box.from_px(t.box)}
		s.first_active = s.throwbox.from
		s.last_active = s.throwbox.to
	if d.has("throw_release"):
		s.throw_release = d.throw_release - 1
		s.throw_hit = HitDef.from_dict(d.throw_hit)
		s.throw_offset = d.get("throw_offset", 70) * SimConst.UNITS_PER_PX
	if d.has("active_hint") and s.first_active < 0:
		s.first_active = d.active_hint[0] - 1
		s.last_active = d.active_hint[1] - 1
	s.cancel_targets = d.get("cancel", [])
	if not s.cancel_targets.is_empty():
		s.cancel_until = d.get("cancel_until", s.last_active + 1 + 3) - 1
	s.punishable = d.get("punishable", false)
	s.punishable_from = d.get("punishable_from", 0) - 1
	s.cost = d.get("cost", {})
	if d.has("armor"):
		s.armor = {"from": d.armor.frames[0] - 1, "to": d.armor.frames[1] - 1, "hits": d.armor.get("hits", 1)}
	s.untechable = d.get("untechable", false)
	if d.has("no_push"):
		s.no_push = [d.no_push[0] - 1, d.no_push[1] - 1]
	for v: Dictionary in d.get("invuln", []):
		s.invuln.append({"from": v.frames[0] - 1, "to": v.frames[1] - 1,
			"strike": v.get("strike", true), "throw": v.get("throw", true)})
	for e: Dictionary in d.get("events", []):
		var ev := e.duplicate()
		ev.frame = e.frame - 1
		s.events.append(ev)
		if e.has("freeze") and (s.first_active < 0 or ev.frame < s.first_active):
			s.freeze_len += e.freeze
	s.reach_cap = d.get("reach_cap", 0) * SimConst.UNITS_PER_PX
	return s


static func _boxes(list: Array) -> Array:
	var out := []
	for b: Array in list:
		out.append(Box.from_px(b))
	return out


func hitboxes_at(frame: int) -> Array:
	return hitboxes.filter(func(h: Dictionary) -> bool: return frame >= h.from and frame <= h.to)


func extra_hurtboxes_at(frame: int) -> Array:
	var out := []
	for h: Dictionary in hurtboxes:
		if frame >= h.from and frame <= h.to:
			out.append_array(h.boxes)
	return out


func throwbox_at(frame: int) -> PackedInt32Array:
	if throwbox.is_empty() or frame < throwbox.from or frame > throwbox.to:
		return PackedInt32Array()
	return throwbox.box


func is_invuln(frame: int, to_throw: bool) -> bool:
	for v: Dictionary in invuln:
		if frame >= v.from and frame <= v.to and (v.throw if to_throw else v.strike):
			return true
	return false


## 攻击阶段（打康判定与表现层选帧用）。没有攻击判定的状态返回 NONE。
func phase_at(frame: int) -> int:
	if first_active < 0:
		return Phase.NONE
	if frame < first_active:
		return Phase.STARTUP
	if frame <= last_active:
		return Phase.ACTIVE
	return Phase.RECOVERY


func armor_at(frame: int) -> int:
	if armor.is_empty() or frame < armor.from or frame > armor.to:
		return 0
	return armor.hits


func pushes_at(frame: int) -> bool:
	return no_push.is_empty() or frame < no_push[0] or frame > no_push[1]


func can_cancel(frame: int) -> bool:
	return frame <= cancel_until and not cancel_targets.is_empty()


func cancel_allows(target: StateDef) -> bool:
	return target.kind in cancel_targets or target.name in cancel_targets


## OD 招式（消耗 Drive 的招式），表现层用来画金身。
func is_od() -> bool:
	return cost.has("drive")


func is_attack() -> bool:
	return kind == "normal" or kind == "special" or kind == "super" or kind == "throw"
