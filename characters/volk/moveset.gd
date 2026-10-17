extends MovesetBuilder
## Volk —— 投技型（重量级）。
##
## 特点：走得慢、体型大；普攻慢但距离长、伤害高；5HK 带一次霸体。
## 必杀技：
##   360P   钢铁粉碎   指令投（不可拆），P 越轻范围越大、伤害越低；起跳预备中也能出
##   214P   野牛冲撞   带一次霸体的肩撞，命中击倒
##   236P   公牛直拳   前冲直拳，L / M / H 越来越远，H 击倒；236PP 一次霸体两段
##   214K   地裂扫     贴地下段横扫，击倒；214KK 硬倒地
##   22P    铁山靠     贴身的全身撞击（发生 5），击倒，连段收尾
##   空中 236K  落锤    斜下俯冲，上段
##   623PP  OD 铁锤，无敌更长更痛
##   623P   铁锤       对空上勾拳，原地不起飞；L / M / H 打击无敌 4 / 6 / 8 帧，越重越痛、收招越长
## 指令普攻：4HP 对空直拳（判定偏上，可打浮空）。目标连段：5MP > HK（击倒）。
##   360PP / 214PP   OD 版本（范围更大 / 两次霸体）
##   236236P 西伯利亚坠落  SA1，超杀指令投，范围很大
##   214214P 重炮冲锋     SA2，三次霸体的多段冲撞
##   236236K 冻土崩落     SA3（体力 25% 以下为 Critical Art），范围更大的超杀指令投

const SPECIAL := ["special", "super"]
const LIGHT_CHAIN := ["special", "super", "5lp", "2lp", "2lk"]


func build() -> void:
	_normals()
	_air_normals()
	_grabs()
	_specials()
	_more_specials()
	throw(70, 1300, 5)
	dashes(800, 12, 22, 700, 14, 26, 8)
	dash_commands()
	drive_system()
	_combos()


func _normals() -> void:
	var heavy := with(H, {"damage": 1000, "hitstop": 12})
	normal("5lp", "S", "LP", 5, 2, 8, 3, -1, [25, 140, 58, 20], L, {}, LIGHT_CHAIN)
	normal("5mp", "S", "MP", 7, 3, 14, 3, -1, [28, 130, 80, 24], with(M, {"damage": 700}), {"step": [3, 9, 30]}, SPECIAL)
	normal("5hp", "S", "HP", 11, 4, 22, 2, -5, [28, 120, 100, 30], heavy,
		{"counter_effect": "launch", "air_vy": 1100, "push": 450, "step": [4, 12, 40]}, SPECIAL)
	normal("5lk", "S", "LK", 5, 3, 10, 2, -2, [22, 70, 62, 24], L, {"step": [3, 6, 20]}, LIGHT_CHAIN)
	normal("5mk", "S", "MK", 9, 3, 16, 2, -3, [28, 55, 95, 26], with(M, {"damage": 750}), {"step": [3, 10, 30]})
	normal("5hk", "S", "HK", 13, 4, 22, 1, -6, [28, 95, 110, 34], with(heavy, {"damage": 1100}),
		{"armor": {"frames": [5, 12], "hits": 1}, "step": [5, 15, 50]})
	normal("2lp", "C", "LP", 5, 2, 8, 3, 0, [25, 85, 52, 20], L, {}, LIGHT_CHAIN)
	normal("2mp", "C", "MP", 7, 3, 13, 3, -1, [28, 85, 75, 22], with(M, {"damage": 700}), {"step": [2, 8, 25]}, SPECIAL)
	normal("2hp", "C", "HP", 10, 4, 24, 1, -9, [10, 115, 58, 105], heavy, {"juggle_limit": 1})
	normal("2lk", "C", "LK", 5, 2, 9, 1, -2, [25, 0, 58, 22], L, {"guard": "low"}, LIGHT_CHAIN)
	normal("2mk", "C", "MK", 9, 3, 17, 1, -5, [28, 0, 90, 22], with(M, {"damage": 700}), {"guard": "low", "step": [2, 10, 30]}, SPECIAL)
	# 目标连段：5MP > HK，击倒
	target_combo("tc_mp_hk", "5mp", "HK", "5hk", 10, 4, 22, 0, -7, [28, 95, 110, 34], with(heavy, {"damage": 900}),
		{"effect": "knockdown"})
	# 4HP：对空直拳，判定偏上，可以打中浮空的对手
	command_normal("4hp", "4", "HP", 8, 4, 20, 1, -7, [10, 130, 70, 90], heavy, {"juggle_limit": 1, "damage": 900},
		[], ["2hp"])
	normal("2hk", "C", "HK", 11, 3, 26, 0, -14, [28, 0, 105, 24], with(heavy, {"damage": 1100}),
		{"guard": "low", "effect": "knockdown", "step": [2, 12, 40]})


func _air_normals() -> void:
	air("j_lp", "LP", 4, 5, 14, 10, [15, 60, 50, 26], L)
	air("j_mp", "MP", 6, 4, 17, 14, [15, 45, 62, 32], with(M, {"damage": 700}))
	air("j_hp", "HP", 9, 4, 21, 17, [10, 15, 68, 50], with(H, {"damage": 950, "hitstop": 12}))
	air("j_lk", "LK", 5, 6, 14, 10, [10, 20, 50, 30], L)
	air("j_mk", "MK", 8, 4, 17, 14, [15, 5, 66, 36], with(M, {"damage": 700}))
	air("j_hk", "HK", 10, 5, 21, 17, [12, 0, 80, 46], with(H, {"damage": 1000, "hitstop": 12}))


func _grabs() -> void:
	# 钢铁粉碎：360P。发生 3，不可拆，P 越轻范围越大伤害越低
	var crush := {"l": [100, 2000], "m": [92, 2200], "h": [85, 2400]}
	for k in ["h", "m", "l"]:
		_command_grab("crush_" + k, "crush", 3, crush[k][0], crush[k][1], 30, {})
		command("360" + k.to_upper() + "P", "special", {"motion": "360", "buttons": k.to_upper() + "P", "state": "crush_" + k})
	_command_grab("crush_od", "crush", 2, 115, 2800, 30, {"cost": {"drive": 20000}, "invuln": [{"frames": [1, 3], "throw": false}]})
	command("360PP", "od", {"motion": "360", "buttons": "PP", "state": "crush_od"})

	# 西伯利亚坠落（SA1）：236236P。超杀暂停后发生 3，范围 140
	_super_grab("super_grab", 1, 140, 2200)
	command("236236P", "super", {"motion": "236236", "buttons": "P", "state": "super_grab"})
	# 冻土崩落（SA3 / Critical Art）：236236K。范围 165
	_super_grab("super3_v_ca", 3, 165, 4600, true)
	command("236236K_ca", "super", {"motion": "236236", "buttons": "K", "state": "super3_v_ca", "cond": "critical"})
	_super_grab("super3_v", 3, 165, 4000)
	command("236236K", "super", {"motion": "236236", "buttons": "K", "state": "super3_v"})


## 投技超杀：等级决定消耗和暂停时间（MovesetBuilder.SUPER_LEVELS），超杀暂停后发生 3。
func _super_grab(state_name: String, level: int, range_px: int, damage: int, critical := false) -> void:
	var lv: Dictionary = SUPER_LEVELS[level]
	_command_grab(state_name, "super_grab", 3, range_px, damage, 50,
		{"cost": {"super": lv.cost}, "kind": "super", "invuln": [{"frames": [1, 4]}],
		"events": [{"frame": 1, "freeze": lv.freeze, "level": level, "critical": critical}]})
	states[state_name].anim = "super_grab"
	states[state_name + "_hit"].anim = "super_grab_hit"


func _command_grab(state_name: String, anim: String, startup: int, range_px: int, damage: int,
		whiff_recovery: int, extra: Dictionary) -> void:
	# 指令投算必杀技（可以从起跳预备、取消窗口里出），只是攻击判定是投判定
	var s := {
		"type": "S", "kind": "special", "total": startup + 2 + whiff_recovery - 1, "anim": anim,
		"throw": {"active": [startup, startup + 1], "box": [0, 0, range_px, 160]},
	}
	s.merge(extra, true)
	states[state_name] = s
	states[state_name + "_hit"] = {
		"type": "S", "kind": "throw", "total": 55, "anim": anim + "_hit", "logic": "throwing", "untechable": true,
		"throw_release": 38, "throw_offset": 80,
		"throw_hit": {"damage": damage, "hitstop": 10, "air_vx": 600, "air_vy": 900},
	}


func _specials() -> void:
	# 野牛冲撞：214P。3~14 帧一次霸体，命中击倒，被防 -6
	var total := 14 + 5 + 20 - 1
	states["charge"] = {
		"type": "S", "kind": "special", "total": total, "anim": "charge", "friction": 70,
		"armor": {"frames": [3, 14], "hits": 1},
		"events": [{"frame": 8, "vx": 900}, {"frame": 19, "vx": 0}],
		"hitboxes": [{"active": [14, 18], "boxes": [[15, 70, 65, 90]],
			"hit": {"damage": 1100, "hitstop": 12, "effect": "knockdown", "blockstun": -6 + total - 14,
				"push": 800, "block_push": 900, "strength": 2}}],
		"hurtboxes": [{"frames": [10, total], "boxes": [[10, 70, 55, 90]]}],
	}
	command("214P", "special", {"motion": "214", "buttons": "P", "state": "charge"})
	var od: Dictionary = states["charge"].duplicate(true)
	od["cost"] = {"drive": 20000}
	od["armor"] = {"frames": [1, 18], "hits": 2}
	od["events"] = [{"frame": 6, "vx": 1100}, {"frame": 18, "vx": 0}]
	od["hitboxes"][0]["active"] = [12, 17]
	states["charge_od"] = od
	command("214PP", "od", {"motion": "214", "buttons": "PP", "state": "charge_od"})

	# 重炮冲锋（SA2）：214214P。1~16 帧三次霸体的冲撞，四段，共约 2600
	var rush := []
	for w in [[12, 13], [15, 16], [18, 19]]:
		rush.append({"active": w, "boxes": [[15, 60, 75, 100]],
			"hit": {"damage": 450, "chip": 110, "hitstop": 6, "hitstun": 28, "blockstun": 20, "push": 100,
				"block_push": 150, "juggle_limit": 10, "strength": 1}})
	rush.append({"active": [22, 24], "boxes": [[15, 60, 80, 110]],
		"hit": {"damage": 1250, "chip": 310, "hitstop": 14, "effect": "knockdown", "air_vx": 600, "air_vy": 900,
			"blockstun": 18, "push": 900, "block_push": 1000, "juggle_limit": 10, "strength": 2}})
	super_art("super2_v", 2, "214214", "P", {"type": "S", "total": 24 + 28, "anim": "super2_v",
		"anim_fallback": ["charge"], "friction": 70, "armor": {"frames": [1, 16], "hits": 3},
		"events": [{"frame": 8, "vx": 1300}, {"frame": 22, "vx": 0}], "hitboxes": rush})

	# 铁锤：623P。原地对空，打击无敌（不防投），收招长；越重无敌越长、越痛、收招越长
	var hammer := {"l": [4, 1100, 24], "m": [6, 1200, 26], "h": [8, 1300, 28]}
	for k in ["h", "m", "l"]:
		var v: Array = hammer[k]
		states["hammer_" + k] = {
			"type": "S", "kind": "special", "total": 6 + 5 + v[2] - 1, "anim": "hammer",
			"invuln": [{"frames": [1, v[0]], "throw": false}],
			"hitboxes": [{"active": [6, 10], "boxes": [[5, 110, 62, 115]],
				"hit": {"damage": v[1], "hitstop": 12, "effect": "launch", "air_vx": 300, "air_vy": 1400,
					"juggle_limit": 3, "blockstun": 18, "push": 600, "block_push": 800, "strength": 2}}],
		}
		command("623" + k.to_upper() + "P", "special", {"motion": "623", "buttons": k.to_upper() + "P", "state": "hammer_" + k})


## SF6 式扩充：公牛直拳、地裂扫、铁山靠、落锤、OD 铁锤、目标连段 2MP > HP。
func _more_specials() -> void:
	# 公牛直拳：236P。前冲直拳
	var punch := {"l": [12, 900, 18, 1000, -4], "m": [14, 1100, 20, 1100, -6], "h": [16, 1300, 22, 1300, -8]}
	for k in ["h", "m", "l"]:
		var v: Array = punch[k]
		var total: int = v[0] + 3 + v[2] - 1
		states["punch_" + k] = {
			"type": "S", "kind": "special", "total": total, "anim": "punch", "anim_fallback": ["5mp"], "friction": 70,
			"keep_boxes": true, "events": [{"frame": 3, "vx": v[1]}, {"frame": v[0] + 2, "vx": 0}],
			"hitboxes": [{"active": [v[0], v[0] + 2], "boxes": [[20, 80, 95, 85]],
				"hit": {"damage": v[3], "hitstop": 12, "effect": "knockdown" if k == "h" else "normal", "hitstun": 22,
					"blockstun": v[4] + total - v[0], "push": 700, "block_push": 800, "strength": 2,
					"juggle_limit": 1 if k == "h" else 0}}],
			"cancel": ["super"],
		}
		command("236" + k.to_upper() + "P", "special", {"motion": "236", "buttons": k.to_upper() + "P", "state": "punch_" + k})
	states["punch_od"] = {
		"type": "S", "kind": "special", "total": 12 + 10 + 20, "anim": "punch", "anim_fallback": ["5mp"],
		"cost": {"drive": 20000}, "friction": 60, "reach_cap": 140, "armor": {"frames": [1, 14], "hits": 1},
		"events": [{"frame": 3, "vx": 1300}, {"frame": 18, "vx": 0}],
		"hitboxes": [
			{"active": [12, 13], "boxes": [[20, 110, 90, 40]],
				"hit": {"damage": 700, "hitstop": 9, "hitstun": 30, "blockstun": 20, "push": 100, "block_push": 150,
					"juggle_limit": 5, "strength": 1}},
			{"active": [18, 20], "boxes": [[20, 100, 95, 50]],
				"hit": {"damage": 800, "hitstop": 13, "effect": "knockdown", "air_vx": 600, "air_vy": 700,
					"blockstun": 18, "push": 900, "block_push": 900, "juggle_limit": 5, "strength": 2}},
		],
		"cancel": ["super"],
	}
	command("236PP", "od", {"motion": "236", "buttons": "PP", "state": "punch_od"})

	# 地裂扫：214K。贴地前滑的下段横扫，击倒，被防很亏
	var sweep_total := 14 + 3 + 26 - 1
	var sweep := {
		"type": "S", "kind": "special", "total": sweep_total, "anim": "sweep", "anim_fallback": ["2hk"], "reach_cap": 140,
		"hitboxes": [{"active": [14, 16], "boxes": [[20, 0, 110, 30]],
			"hit": {"damage": 1100, "hitstop": 12, "guard": "low", "effect": "knockdown", "air_vx": 300, "air_vy": 600,
				"blockstun": -12 + sweep_total - 14, "push": 700, "block_push": 800, "strength": 2}}],
		"cancel": ["super"],
	}
	sweep.merge(step(3, 14, 60))
	states["sweep"] = sweep
	command("214K", "special", {"motion": "214", "buttons": "K", "state": "sweep"})
	var sweep_od: Dictionary = sweep.duplicate(true)
	sweep_od.cost = {"drive": 20000}
	sweep_od.invuln = [{"frames": [1, 8], "throw": false}]
	sweep_od.hitboxes[0].hit.damage = 1300
	sweep_od.hitboxes[0].hit.hard_kd = true
	sweep_od.hitboxes[0].hit.down = 44
	states["sweep_od"] = sweep_od
	command("214KK", "od", {"motion": "214", "buttons": "KK", "state": "sweep_od"})

	# 铁山靠：22P。贴身全身撞击，发生 5，击倒
	states["burst"] = {
		"type": "S", "kind": "special", "total": 5 + 3 + 22 - 1, "anim": "burst", "anim_fallback": ["5hp"],
		"reach_cap": 115, "friction": 60, "events": [{"frame": 1, "vx": 600}, {"frame": 6, "vx": 0}],
		"hitboxes": [{"active": [5, 7], "boxes": [[-10, 30, 110, 150]],
			"hit": {"damage": 1000, "hitstop": 13, "effect": "knockdown", "air_vx": 650, "air_vy": 800,
				"blockstun": -8 + 29 - 5, "push": 900, "block_push": 900, "strength": 2}}],
		"cancel": ["super"],
	}
	command("22P", "special", {"motion": "22", "buttons": "P", "state": "burst"})

	# 落锤：空中 236K。斜下俯冲，上段，落地有硬直
	states["air_dive"] = {
		"type": "A", "kind": "special", "anim": "air_dive", "anim_fallback": ["j_hk"], "land": "air_dive_land",
		"reach_cap": 90,
		"events": [{"frame": 4, "vx": 650, "vy": -1200}],
		"hitboxes": [{"active": [5, 40], "boxes": [[10, 0, 60, 60]],
			"hit": {"damage": 900, "hitstop": 10, "hitstun": 18, "blockstun": 14, "guard": "high", "push": 500,
				"block_push": 600, "strength": 2}}],
	}
	states["air_dive_land"] = {"type": "S", "total": 12, "anim": "land", "punishable": true}
	command("j236K", "special", {"motion": "236", "buttons": "K", "where": "air", "state": "air_dive"})

	# OD 铁锤：623PP。1~10 帧完全无敌
	var hammer_od: Dictionary = states["hammer_h"].duplicate(true)
	hammer_od.anim = "hammer_od"
	hammer_od.anim_fallback = ["hammer"]
	hammer_od.cost = {"drive": 20000}
	hammer_od.invuln = [{"frames": [1, 10]}]
	hammer_od.hitboxes[0].hit.damage = 1500
	hammer_od.hitboxes[0].hit.juggle_limit = 5
	states["hammer_od"] = hammer_od
	command("623PP", "od", {"motion": "623", "buttons": "PP", "state": "hammer_od"})

	# 目标连段：2MP > HP，上勾拳浮空，可以必杀取消接重版公牛直拳
	target_combo("tc_2mp_hp", "2mp", "HP", "2hp", 9, 4, 22, 0, -8, [10, 115, 58, 105],
		with(H, {"damage": 900, "hitstop": 12}), {"effect": "launch", "air_vx": 0, "air_vy": 1250, "juggle_limit": 1,
		"step": [1, 8, 30]}, SPECIAL)


## 连段路线（投技型：连段短、伤害高；主要靠打康浮空和指令投二择，超杀是投技，不放进连段）。
func _combos() -> void:
	combo("轻攻击确认", "5LP > 5LP xx 623HP", ["5lp", "5lp", "hammer_h"],
		[["5LP", 8], ["5LP", 6], ["6,2,3HP", 0]], {"hits": 3, "imported_only": true})
	combo("下段确认", "2MK xx 214P", ["2mk", "charge"],
		[["2MK", 10], ["2,1,4HP", 0]], {"hits": 2})
	combo("跳入", "j.HP > 5HP xx 214P", ["j_hp", "5hp", "charge"],
		[["9", 34], ["5HP", 23], ["5HP", 12], ["2,1,4HP", 0]], {"hits": 3, "gap": 210, "strict": [0, 1]})
	combo("打康浮空", "CH 5HP xx 623HP", ["5hp", "hammer_h"],
		[["5HP", 12], ["6,2,3HP", 0]], {"hits": 2, "p2": "5x8,5LP", "gap": 110, "imported_only": true})
	combo("OD 冲撞", "5MP xx 214PP", ["5mp", "charge_od"],
		[["5MP", 10], ["2,1,4LP+MP", 0]], {"hits": 2})
	combo("目标连段", "5MP > HK", ["5mp", "tc_mp_hk"], [["5MP", 9], ["5HK", 0]], {"hits": 2})
	combo("冲拳确认", "5MP xx 236HP", ["5mp", "punch_h"], [["5MP", 10], ["2,3,6HP", 0]], {"hits": 2})
	combo("铁山靠", "2LP > 2LP xx 22P", ["2lp", "2lp", "burst"],
		[["2LP", 8], ["2LP", 7], ["2,5,2HP", 0]], {"hits": 3})
	combo("下段地裂", "2MK xx 214K", ["2mk", "sweep"], [["2MK", 10], ["2,1,4HK", 0]], {"hits": 2})
	combo("浮空冲拳", "2MP > HP xx 236HP", ["2mp", "tc_2mp_hp", "punch_h"],
		[["2MP", 10], ["5HP", 12], ["2,3,6HP", 0]], {"hits": 3})
	combo("OD 冲拳", "2MK xx 236PP", ["2mk", "punch_od"], [["2MK", 10], ["2,3,6LP+MP", 0]], {"hits": 3})
	combo("超杀收尾", "2MK xx 214214P", ["2mk", "super2_v"], [["2MK", 10], ["2,1,4,2,1,4HP", 0]], {"hits": 5, "meter": true})
