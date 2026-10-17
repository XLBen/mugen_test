extends SceneTree
## 手感体检：列出导入人物每个攻击招式的"动画 ↔ 帧数据"对齐情况和判定大小，找出播放过快 / 过慢、判定比设计大太多的招。
## godot --headless --path . -s res://tools/feel_audit.gd [-- 角色id...]
##
## 列：发生 原动画时长/招式帧数（含超杀暂停）=实际倍速（短于发生帧时按原速播完停在预备姿势；超过 2 倍速的部分跳过开头）；持续 同理；
##     收招 原动画/招式收招帧=原动画/(收招帧+尾巴上限)（>1.3 明显加速）；
##     判定 动画攻击盒的 前伸 / 上沿 / 下沿 与招式表手写盒子的对比（像素）。

const HOLD := 5 ## 预备姿势停住超过几帧要看一眼
const REACH_DIFF := 30 ## 前伸差超过多少像素算不一致


func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	var base := "res://local_assets/mugen"
	for d in DirAccess.get_directories_at(base):
		if not only.is_empty() and not only.has(d):
			continue
		var path := base.path_join(d).path_join("fighter.tres")
		if ResourceLoader.exists(path):
			_audit(load(path))
	quit()


func _audit(def: FighterDef) -> void:
	var raw := Moveset.build(CommonStates.states(), def.moveset.new().data())
	var m := Moveset.for_def(def)
	print("\n== %s (%s)" % [def.display_name, def.sprite_dir])
	print("%-12s %-16s %-16s %-18s %-26s %s" % ["招式", "发生", "持续", "收招", "判定 前伸/上/下", "问题"])
	for s in m.states:
		if s.anim_data == null or s.first_active < 0:
			continue
		var a := s.anim_data
		var flags := PackedStringArray()
		var st := a.segment(AnimData.Phase.STARTUP)
		var ac := a.segment(AnimData.Phase.ACTIVE)
		var rec_len := a.length() - ac.x - ac.y
		var g_st := s.first_active
		var g_ac := s.last_active - s.first_active + 1
		var g_rec := s.total - s.last_active - 1 if s.total > 0 else -1
		# 按 AnimClock 的规则算实际播放：发生段（含超杀暂停）最多 2 倍速，收招段最多放慢到 1.5 倍
		var span := maxi(g_st + s.freeze_len, 1)
		var played := mini(st.y, span * AnimClock.STARTUP_MAX_SPEED)
		var r_st := maxf(float(played) / span, 1.0) if st.y > 0 else 0.0
		var r_ac := float(ac.y) / g_ac
		if st.y > played:
			flags.append("跳过开头%d" % (st.y - played))
		if st.y > 0 and span - st.y > HOLD:
			flags.append("蓄势停%d帧" % (span - st.y))
		if r_ac < 0.34 and g_ac >= 3:
			flags.append("持续定格")
		var r_rec := -1.0
		if g_rec >= 0:
			r_rec = float(rec_len) / (g_rec + AnimClock.TAIL_MAX)
			if r_rec > 1.3:
				flags.append("收招加速")
			if rec_len * AnimClock.STRETCH_MAX[0] / AnimClock.STRETCH_MAX[1] < g_rec * 0.7:
				flags.append("收招定格")
		var box := ""
		var ri: StateDef = raw.states[raw.id(s.name)]
		if not s.hitboxes.is_empty() and not ri.hitboxes.is_empty():
			var mine := _extent(s.hitboxes)
			var plan := _extent(ri.hitboxes)
			box = "%d/%d/%d 设计%d/%d/%d" % [mine.x / 100, mine.y / 100, mine.z / 100, plan.x / 100, plan.y / 100, plan.z / 100]
			if (mine.x - plan.x) / 100 > REACH_DIFF:
				flags.append("判定过长")
			if (plan.x - mine.x) / 100 > REACH_DIFF:
				flags.append("判定过短")
		print("%-12s %-16s %-16s %-18s %-26s %s" % [s.name,
			"%d/%d=%.1f" % [st.y, g_st, r_st], "%d/%d=%.1f" % [ac.y, g_ac, r_ac],
			"%d/%d=%.1f" % [rec_len, g_rec, r_rec] if g_rec >= 0 else "%d/空中" % rec_len,
			box, " ".join(flags)])


## 一组攻击判定的 前伸 / 上沿 / 下沿（单位）。
static func _extent(hitboxes: Array) -> Vector3i:
	var out := Vector3i(-1000000, -1000000, 1000000)
	for h: Dictionary in hitboxes:
		for b: PackedInt32Array in h.boxes:
			out.x = maxi(out.x, b[0] + b[2])
			out.y = maxi(out.y, b[1] + b[3])
			out.z = mini(out.z, b[1])
	return out
