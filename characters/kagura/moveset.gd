extends MovesetBuilder
## Kagura —— 速攻型（短刀）。
##
## 特点：走速与冲刺最快、普攻发生快但距离短，没有飞行道具。
## 连段路线（SF6 式）：轻攻击互相连打，中攻击 / 重拳可必杀取消；目标连段 5MP > HP、5LK > MK；突进斩可超杀取消。
## 指令普攻：6MP 中段（发生 20）。
## 必杀技：
##   236K  裂空斩     突进斩，K 越重距离越远，HK 命中击倒
##   214P  影步       快速前冲，可穿过对手（不参与推挤），前段打击无敌
##   623K  月轮       对空翻踢，L / M / H 无敌 4（只防打击）/ 5 / 7 帧，越重越高越痛
##   空中 214K  坠星  斜下俯冲踢，上段
##   236KK / 623KK   OD 版本
##   236P  蛇咬       突刺上挑，L / M / H 越来越远，H 命中浮空；236PP 两段（上挑 + 下劈）
##   421K  千刃乱舞   原地连斩五段，连段收尾；421KK 七段，版边贴墙
##   214P 中按 P  影斩  影步的派生上挑（穿过对手后自动转身），浮空；214PP 无敌更长
##   空中 214KK  OD 坠星，更快更痛
##   236236K 千刃     SA1，突进五连斩
##   214214K 月华     SA2，无敌上升多段（对空）
##   236236P 千刃·极   SA3（体力 25% 以下为 Critical Art），更长的突进连斩

const SPECIAL := ["special", "super"]
const FROM_LIGHT := ["special", "super", "5lp", "2lp", "2lk"]
const FROM_MEDIUM := ["special", "super"]


func build() -> void:
	_normals()
	_air_normals()
	_specials()
	_more_specials()
	_super()
	throw(58, 1200, 5)
	dashes(1150, 9, 16, 950, 11, 20, 7)
	dash_commands()
	drive_system()
	_combos()


func _normals() -> void:
	normal("5lp", "S", "LP", 4, 2, 6, 5, -1, [22, 135, 50, 18], L, {"step": [2, 5, 10]}, FROM_LIGHT)
	normal("5mp", "S", "MP", 5, 2, 11, 5, 1, [22, 128, 62, 20], M, {"step": [1, 6, 25]}, FROM_MEDIUM)
	normal("5hp", "S", "HP", 8, 3, 16, 3, -2, [22, 120, 75, 24], H, {"push": 450, "step": [3, 10, 30]}, SPECIAL)
	normal("5lk", "S", "LK", 4, 2, 8, 3, -1, [18, 70, 50, 22], L, {}, FROM_LIGHT)
	normal("5mk", "S", "MK", 6, 3, 12, 3, -2, [22, 55, 70, 22], M, {}, FROM_MEDIUM)
	normal("5hk", "S", "HK", 9, 3, 18, 2, -4, [22, 95, 85, 28], H, {"counter_effect": "launch", "air_vy": 1200,
		"step": [2, 9, 20]})
	normal("2lp", "C", "LP", 4, 2, 6, 4, -1, [22, 85, 45, 18], L, {}, FROM_LIGHT)
	normal("2mp", "C", "MP", 5, 2, 10, 4, -2, [22, 85, 58, 20], M, {}, FROM_MEDIUM)
	normal("2hp", "C", "HP", 7, 4, 18, 1, -6, [8, 110, 48, 90], H, {"juggle_limit": 1, "step": [1, 8, 45]})
	normal("2lk", "C", "LK", 4, 2, 7, 2, -1, [22, 0, 50, 20], L, {"guard": "low"}, FROM_LIGHT)
	normal("2mk", "C", "MK", 7, 3, 14, 1, -3, [22, 0, 72, 20], M, {"guard": "low"}, FROM_MEDIUM)
	normal("2hk", "C", "HK", 8, 3, 22, 0, -11, [22, 0, 85, 20], H, {"guard": "low", "effect": "knockdown",
		"step": [3, 12, 80]})
	# 目标连段：5MP > HP（命中可必杀取消）、5LK > MK
	target_combo("tc_mp_hp", "5mp", "HP", "5hp", 8, 3, 18, 2, -5, [22, 120, 75, 24], H, {"damage": 700, "push": 450},
		SPECIAL)
	target_combo("tc_lk_mk", "5lk", "MK", "5mk", 6, 3, 13, 3, -3, [22, 55, 70, 22], M, {"damage": 500}, SPECIAL)
	# 6MP：中段（站着才能防），发生慢
	command_normal("6mp", "6", "MP", 20, 2, 16, 2, -2, [20, 70, 65, 70], M, {"guard": "high", "damage": 600,
		"step": [6, 18, 30]}, [], ["5mp"])


func _air_normals() -> void:
	air("j_lp", "LP", 3, 6, 13, 10, [15, 60, 42, 24], L)
	air("j_mp", "MP", 5, 4, 16, 13, [15, 50, 50, 28], M)
	air("j_hp", "HP", 7, 4, 19, 15, [10, 20, 55, 42], H)
	air("j_lk", "LK", 4, 8, 13, 10, [10, 20, 42, 28], L)
	air("j_mk", "MK", 6, 4, 16, 13, [15, 5, 55, 32], M)
	air("j_hk", "HK", 8, 5, 19, 15, [15, 10, 68, 38], H)


func _specials() -> void:
	# 裂空斩：236K。发生 / 速度 / 收招随强度变化，越重越远越不安全
	var slash := {
		"l": {"startup": 10, "speed": 900, "recovery": 18, "on_block": -4, "damage": 900, "effect": "normal"},
		"m": {"startup": 12, "speed": 1150, "recovery": 20, "on_block": -6, "damage": 1000, "effect": "normal"},
		"h": {"startup": 14, "speed": 1450, "recovery": 22, "on_block": -8, "damage": 1200, "effect": "knockdown"},
	}
	for k in ["h", "m", "l"]:
		var v: Dictionary = slash[k]
		var total: int = v.startup + 3 + v.recovery - 1
		states["slash_" + k] = {
			"type": "S", "kind": "special", "total": total, "anim": "slash", "friction": 80,
			"events": [{"frame": 3, "vx": v.speed}, {"frame": v.startup + 3, "vx": 0}],
			"hitboxes": [{"active": [v.startup, v.startup + 2], "boxes": [[10, 80, 70, 60]],
				"hit": {"damage": v.damage, "hitstop": 10, "effect": v.effect, "hitstun": 22,
					"blockstun": v.on_block + total - v.startup, "push": 700, "block_push": 800, "strength": 2}}],
			"hurtboxes": [{"frames": [v.startup, total], "boxes": [[10, 80, 55, 60]]}],
			"cancel": ["super"],
		}
		command("236" + k.to_upper() + "K", "special", {"motion": "236", "buttons": k.to_upper() + "K", "state": "slash_" + k})

	# OD 裂空斩：两段，1~10 帧打击无敌，被防 -2；冲得比普通版远（打空约 280 像素，命中时推着对手一起走）
	states["slash_od"] = {
		"type": "S", "kind": "special", "total": 10 + 8 + 18 - 1, "anim": "slash", "cost": {"drive": 20000},
		"friction": 40, "invuln": [{"frames": [1, 10], "throw": false}],
		"events": [{"frame": 3, "vx": 1900}, {"frame": 22, "vx": 0}],
		"hitboxes": [
			{"active": [10, 11], "boxes": [[10, 80, 70, 60]],
				"hit": {"damage": 600, "hitstop": 8, "hitstun": 30, "blockstun": 20, "push": 100, "block_push": 100, "strength": 1}},
			{"active": [15, 17], "boxes": [[10, 80, 75, 60]],
				"hit": {"damage": 700, "hitstop": 11, "effect": "knockdown", "blockstun": 16, "push": 700,
					"block_push": 900, "strength": 2, "juggle_limit": 2}},
		],
	}
	command("236KK", "od", {"motion": "236", "buttons": "KK", "state": "slash_od"})

	# 影步：214P。向前快速移动，2~16 帧不参与推挤（可以穿到对手身后），1~12 帧打击无敌（可被投）
	states["step"] = {
		"type": "S", "kind": "special", "total": 24, "anim": "step", "punishable_from": 17,
		"no_push": [2, 16], "invuln": [{"frames": [1, 12], "throw": false}],
		"events": [{"frame": 2, "vx": 1400}, {"frame": 13, "vx": 0}],
	}
	command("214P", "special", {"motion": "214", "buttons": "P", "state": "step"})

	# 月轮：623K，对空翻踢。L 只有打击无敌、飞得低；H 无敌最长、最高最痛
	var rising := {
		"l": {"invuln": [{"frames": [1, 4], "throw": false}], "vy": 1300, "active": [5, 11], "damage": 900},
		"m": {"invuln": [{"frames": [1, 5]}], "vy": 1450, "active": [5, 12], "damage": 1000},
		"h": {"invuln": [{"frames": [1, 7]}], "vy": 1600, "active": [5, 13], "damage": 1200},
	}
	for k in ["h", "m", "l"]:
		var v: Dictionary = rising[k]
		states["rising_" + k] = {
			"type": "S", "kind": "special", "air_from": 5, "land": "landing_long", "anim": "rising",
			"invuln": v.invuln,
			"events": [{"frame": 5, "vx": 150, "vy": v.vy}],
			"hitboxes": [{"active": v.active, "boxes": [[5, 90, 55, 110]],
				"hit": {"damage": v.damage, "hitstop": 11, "effect": "launch", "air_vx": 250, "air_vy": 1300,
					"juggle_limit": 3, "blockstun": 18, "push": 600, "block_push": 800, "strength": 2}}],
		}
		command("623" + k.to_upper() + "K", "special", {"motion": "623", "buttons": k.to_upper() + "K", "state": "rising_" + k})
	states["rising_od"] = {
		"type": "S", "kind": "special", "air_from": 5, "land": "landing_long", "anim": "rising", "cost": {"drive": 20000},
		"invuln": [{"frames": [1, 12]}],
		"events": [{"frame": 5, "vx": 200, "vy": 1600}],
		"hitboxes": [{"active": [5, 14], "boxes": [[5, 90, 60, 120]],
			"hit": {"damage": 1400, "hitstop": 12, "effect": "launch", "air_vx": 250, "air_vy": 1450,
				"juggle_limit": 5, "blockstun": 18, "push": 600, "block_push": 800, "strength": 2}}],
	}
	command("623KK", "od", {"motion": "623", "buttons": "KK", "state": "rising_od"})

	# 坠星：空中 214K，斜下俯冲，上段；落地有硬直
	states["dive"] = {
		"type": "A", "kind": "special", "anim": "dive", "land": "dive_land",
		"events": [{"frame": 3, "vx": 750, "vy": -1100}],
		"hitboxes": [{"active": [4, 40], "boxes": [[10, 0, 55, 50]],
			"hit": {"damage": 800, "hitstop": 9, "hitstun": 17, "blockstun": 13, "guard": "high",
				"push": 500, "block_push": 600, "strength": 1}}],
	}
	states["dive_land"] = {"type": "S", "total": 10, "anim": "land", "punishable": true}
	command("j214K", "special", {"motion": "214", "buttons": "K", "where": "air", "state": "dive"})


func _super() -> void:
	# 千刃（SA1）：236236K。超杀暂停后高速突进，四段斩 + 最后一击浮空，共约 2000
	super_art("super_k", 1, "236236", "K", _slashes([[9, 10], [12, 13], [15, 16], [18, 19]], 250, [22, 24], 1000, 24))

	# 月华（SA2）：214214K。1~12 帧无敌，原地起跳的多段上升踢，对空用，共约 2600
	var rise := []
	for w in [[6, 7], [9, 10], [12, 13]]:
		rise.append({"active": w, "boxes": [[0, 70, 70, 150]],
			"hit": {"damage": 500, "chip": 120, "hitstop": 6, "hitstun": 30, "blockstun": 20, "push": 0, "block_push": 100,
				"air_vx": 60, "air_vy": 1300, "juggle_limit": 10, "strength": 1}})
	rise.append({"active": [16, 19], "boxes": [[0, 90, 75, 150]],
		"hit": {"damage": 1100, "chip": 270, "hitstop": 14, "effect": "launch", "air_vx": 400, "air_vy": 1600,
			"blockstun": 18, "push": 700, "block_push": 900, "juggle_limit": 10, "strength": 2}})
	super_art("super2_k", 2, "214214", "K", {"type": "S", "air_from": 6, "land": "landing_long", "anim": "super2_k",
		"anim_fallback": ["rising"], "invuln": [{"frames": [1, 12]}], "events": [{"frame": 6, "vx": 150, "vy": 1750}],
		"hitboxes": rise})

	# 千刃·极（SA3 / Critical Art）：236236P。突进更远的八段斩，共约 4000
	var sa3 := _slashes([[9, 10], [12, 13], [15, 16], [18, 19], [21, 22], [24, 25], [27, 28]], 330, [31, 33], 1700, 33)
	sa3.anim = "super3_k"
	sa3.anim_fallback = ["super_k"]
	super_art("super3_k", 3, "236236", "P", sa3, true)
	super_art("super3_k", 3, "236236", "P", sa3)


## SF6 式扩充：蛇咬、千刃乱舞、影步派生、OD 影步 / 坠星、目标连段 5HP > HK。
func _more_specials() -> void:
	# 蛇咬：236P。前冲突刺上挑；L 快而短，H 远且命中浮空（可以追 623K）
	var fang := {"l": [8, 650, 16, 900, -3], "m": [10, 850, 18, 1000, -5], "h": [12, 1050, 20, 1100, -7]}
	for k in ["h", "m", "l"]:
		var v: Array = fang[k]
		var total: int = v[0] + 3 + v[2] - 1
		var hit := {"damage": v[3], "hitstop": 10, "hitstun": 20, "blockstun": v[4] + total - v[0], "push": 600,
			"block_push": 700, "strength": 2}
		if k == "h":
			hit.merge({"effect": "launch", "air_vx": 200, "air_vy": 1300, "juggle_limit": 2})
		states["fang_" + k] = {
			"type": "S", "kind": "special", "total": total, "anim": "fang", "anim_fallback": ["2hp"], "friction": 70,
			"reach_cap": 120,
			"events": [{"frame": 2, "vx": v[1]}, {"frame": v[0] + 2, "vx": 0}],
			"hitboxes": [{"active": [v[0], v[0] + 2], "boxes": [[10, 100, 65, 70]], "hit": hit}],
			"cancel": ["super"],
		}
		command("236" + k.to_upper() + "P", "special", {"motion": "236", "buttons": k.to_upper() + "P", "state": "fang_" + k})
	# OD 蛇咬：236PP。1~8 帧打击无敌，上挑浮空 + 下劈击倒
	states["fang_od"] = {
		"type": "S", "kind": "special", "total": 9 + 12 + 18, "anim": "fang_od", "anim_fallback": ["fang", "2hp"],
		"cost": {"drive": 20000}, "friction": 60, "invuln": [{"frames": [1, 8], "throw": false}],
		"events": [{"frame": 2, "vx": 1100}, {"frame": 11, "vx": 0}],
		"hitboxes": [
			{"active": [9, 10], "boxes": [[10, 100, 65, 80]],
				"hit": {"damage": 600, "hitstop": 8, "effect": "launch", "air_vx": 80, "air_vy": 1100, "juggle_limit": 5,
					"blockstun": 22, "push": 200, "block_push": 300, "strength": 1}},
			{"active": [16, 18], "boxes": [[10, 40, 75, 110]],
				"hit": {"damage": 700, "hitstop": 12, "effect": "knockdown", "air_vx": 500, "air_vy": 600, "juggle_limit": 5,
					"blockstun": 16, "push": 700, "block_push": 800, "strength": 2}},
		],
		"cancel": ["super"],
	}
	command("236PP", "od", {"motion": "236", "buttons": "PP", "state": "fang_od"})

	# 千刃乱舞：421K。原地快速连斩，五段 + 最后一刀击倒
	var flurry := func(n: int, each: int, last: int, extra: Dictionary) -> Dictionary:
		var hits := []
		for i in n:
			hits.append({"active": [7 + i * 3, 7 + i * 3], "boxes": [[10, 60, 95, 90]],
				"hit": {"damage": each, "hitstop": 5, "hitstun": 22, "blockstun": 18, "push": 0, "block_push": 40,
					"juggle_limit": 10, "strength": 1}})
		var last_hit := {"damage": last, "hitstop": 12, "effect": "knockdown", "air_vx": 450, "air_vy": 700,
			"blockstun": 14, "push": 800, "block_push": 900, "juggle_limit": 10, "strength": 2}
		last_hit.merge(extra, true)
		hits.append({"active": [7 + n * 3 + 2, 7 + n * 3 + 3], "boxes": [[10, 60, 85, 100]], "hit": last_hit})
		# 边砍边小步前进，被击退的对手不会漏刀
		return {"type": "S", "kind": "special", "total": 7 + n * 3 + 3 + 24, "hitboxes": hits, "cancel": ["super"],
			"reach_cap": 130,
			"friction": 20, "events": [{"frame": 5, "vx": 260}, {"frame": 7 + n * 3 + 3, "vx": 0}]}
	var flurry_k: Dictionary = flurry.call(5, 160, 450, {})
	flurry_k.anim = "flurry"
	flurry_k.anim_fallback = ["super_k"]
	states["flurry"] = flurry_k
	command("421K", "special", {"motion": "421", "buttons": "K", "state": "flurry"})
	var flurry_od: Dictionary = flurry.call(7, 150, 500, {"wall": "splat"})
	flurry_od.anim = "flurry_od"
	flurry_od.anim_fallback = ["flurry", "super_k"]
	flurry_od.cost = {"drive": 20000}
	flurry_od.invuln = [{"frames": [1, 6], "throw": false}]
	states["flurry_od"] = flurry_od
	command("421KK", "od", {"motion": "421", "buttons": "KK", "state": "flurry_od"})

	# 影斩：影步第 4~16 帧按 P 派生，转向对手上挑浮空
	states["step"].cancel = ["step_slash"]
	states["step"].cancel_from = 4
	states["step"].cancel_until = 16
	states["step"].cancel_free = true
	states["step_slash"] = {
		"type": "S", "kind": "special", "total": 6 + 3 + 20 - 1, "anim": "step_slash", "anim_fallback": ["2hp"],
		"events": [{"frame": 1, "face": true}],
		"hitboxes": [{"active": [6, 8], "boxes": [[5, 90, 65, 100]],
			"hit": {"damage": 800, "hitstop": 10, "effect": "launch", "air_vx": 150, "air_vy": 1250, "juggle_limit": 2,
				"blockstun": 14, "push": 500, "block_push": 600, "strength": 2}}],
	}
	command("214P>P", "special", {"buttons": "P", "where": "cancel", "state": "step_slash", "after": ["step", "step_od"]})
	var step_od: Dictionary = states["step"].duplicate(true)
	step_od.cost = {"drive": 20000}
	step_od.invuln = [{"frames": [1, 16]}]
	step_od.events = [{"frame": 2, "vx": 1800}, {"frame": 12, "vx": 0}]
	states["step_od"] = step_od # 派生窗口和普通影步相同
	command("214PP", "od", {"motion": "214", "buttons": "PP", "state": "step_od"})

	# OD 坠星：空中 214KK，更快更痛
	var dive_od: Dictionary = states["dive"].duplicate(true)
	dive_od.cost = {"drive": 20000}
	dive_od.events = [{"frame": 3, "vx": 1000, "vy": -1450}]
	dive_od.hitboxes[0].hit.damage = 1000
	dive_od.hitboxes[0].hit.hitstun = 22
	states["dive_od"] = dive_od
	command("j214KK", "od", {"motion": "214", "buttons": "KK", "where": "air", "state": "dive_od"})

	# 目标连段：5HP > HK，把对手踢上天，可以必杀取消追打
	target_combo("tc_hp_hk", "5hp", "HK", "5hk", 9, 3, 20, 0, -6, [22, 95, 85, 28], H,
		{"damage": 600, "effect": "launch", "air_vx": 200, "air_vy": 1250, "juggle_limit": 1}, SPECIAL)


## 突进连斩超杀：windows 每段的持续帧，each 每段伤害，last 最后一击（浮空）的持续帧与伤害，end 最后一击结束帧。
func _slashes(windows: Array, each: int, last_window: Array, last: int, end: int) -> Dictionary:
	var hits := []
	for w in windows:
		hits.append({"active": w, "boxes": [[5, 40, 85, 130]],
			"hit": {"damage": each, "chip": each / 4, "hitstop": 5, "hitstun": 30, "blockstun": 22, "push": 50,
				"block_push": 50, "juggle_limit": 10, "strength": 1}})
	hits.append({"active": last_window, "boxes": [[5, 40, 90, 140]],
		"hit": {"damage": last, "chip": last / 4, "hitstop": 14, "effect": "launch", "air_vx": 450, "air_vy": 1500,
			"blockstun": 18, "push": 900, "block_push": 1000, "juggle_limit": 10, "strength": 2}})
	var events := [{"frame": 6, "vx": 1600}, {"frame": 12, "vx": 200}]
	# 后面几段每段前再小步追上（击退会把对手推远）
	for w: Array in windows.slice(4) + [last_window]:
		events.append({"frame": w[0] - 2, "vx": 450})
	events.append({"frame": end, "vx": 0})
	return {
		"type": "S", "total": end + 30, "anim": "super_k", "invuln": [{"frames": [1, 14]}], "friction": 60,
		"events": events, "hitboxes": hits,
	}


## 连段路线（SF6 式：轻攻击连打确认、中攻击 Gatling、跳入、打康、超杀 / OD 收尾）。
func _combos() -> void:
	combo("下段确认", "2LK > 2LP > 5LP xx 236LK", ["2lk", "2lp", "5lp", "slash_l"],
		[["2LK", 7], ["2LP", 7], ["5LP", 6], ["2,3,6LK", 0]], {"hits": 4})
	combo("目标连段", "5MP > HP xx 236HK", ["5mp", "tc_mp_hp", "slash_h"],
		[["5MP", 8], ["5HP", 10], ["2,3,6HK", 0]], {"hits": 3})
	combo("跳入", "j.HK > 5HP xx 236HK", ["j_hk", "5hp", "slash_h"],
		[["9", 33], ["5HK", 19], ["5HP", 10], ["2,3,6HK", 0]], {"hits": 3, "gap": 210, "strict": [0, 1]})
	combo("确反", "PC 5HP > 5MP xx 236HK", ["5hp", "5mp", "slash_h"],
		[["5HP", 40], ["5MP", 8], ["2,3,6HK", 0]], {"hits": 3, "gap": 95, "p2_recovery": "5hk"})
	combo("超杀收尾", "5MP > HP xx 236MK xx 236236K", ["5mp", "tc_mp_hp", "slash_m", "super_k"],
		[["5MP", 8], ["5HP", 10], ["2,3,6MK", 22], ["2,3,6,2,3,6HK", 0]], {"hits": 8, "meter": true})
	combo("OD 追加", "5MP > HP xx 236KK", ["5mp", "tc_mp_hp", "slash_od"],
		[["5MP", 8], ["5HP", 10], ["2,3,6LK+MK", 0]], {"hits": 4})
	combo("目标连段（脚）", "5LK > MK xx 236LK", ["5lk", "tc_lk_mk", "slash_l"],
		[["5LK", 6], ["5MK", 8], ["2,3,6LK", 0]], {"hits": 3})
	combo("千刃乱舞", "5MP > HP xx 421K", ["5mp", "tc_mp_hp", "flurry"],
		[["5MP", 8], ["5HP", 10], ["4,2,1HK", 0]], {"hits": 8})
	combo("蛇咬确认", "2LK > 2LP > 5LP xx 236LP", ["2lk", "2lp", "5lp", "fang_l"],
		[["2LK", 7], ["2LP", 7], ["5LP", 6], ["2,3,6LP", 0]], {"hits": 4})
	combo("浮空追打", "5HP > HK xx 623HK", ["5hp", "tc_hp_hk", "rising_h"],
		[["5HP", 12], ["5HK", 12], ["6,2,3HK", 0]], {"hits": 3})
	combo("OD 千刃", "5MP > HP xx 421KK", ["5mp", "tc_mp_hp", "flurry_od"],
		[["5MP", 8], ["5HP", 10], ["4,2,1LK+MK", 0]], {"hits": 10})
	combo("OD 蛇咬", "2MK xx 236PP", ["2mk", "fang_od"], [["2MK", 10], ["2,3,6LP+MP", 0]], {"hits": 3})
	combo("3 格收尾", "5MP > HP xx 236MK xx 236236P", ["5mp", "tc_mp_hp", "slash_m", "super3_k"],
		[["5MP", 8], ["5HP", 10], ["2,3,6MK", 22], ["2,3,6,2,3,6HP", 0]], {"hits": 11, "meter": true})
