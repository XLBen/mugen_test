extends MovesetBuilder
## Volk —— 投技型（重量级）。
##
## 特点：走得慢、体型大；普攻慢但距离长、伤害高；5HK 带一次霸体。
## 必杀技：
##   360P   钢铁粉碎   指令投（不可拆），P 越轻范围越大、伤害越低；起跳预备中也能出
##   214P   野牛冲撞   带一次霸体的肩撞，命中击倒
##   623P   铁锤       对空上勾拳，1~7 帧打击无敌，原地不起飞
##   360PP / 214PP   OD 版本（范围更大 / 两次霸体）
##   236236P 西伯利亚坠落  超杀指令投，范围很大

const SPECIAL := ["special", "super"]
const LIGHT_CHAIN := ["special", "super", "5lp", "2lp"]


func build() -> void:
	_normals()
	_air_normals()
	_grabs()
	_specials()
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
	normal("5lk", "S", "LK", 5, 3, 10, 2, -2, [22, 70, 62, 24], L, {"step": [3, 6, 20]})
	normal("5mk", "S", "MK", 9, 3, 16, 2, -3, [28, 55, 95, 26], with(M, {"damage": 750}), {"step": [3, 10, 30]})
	normal("5hk", "S", "HK", 13, 4, 22, 1, -6, [28, 95, 110, 34], with(heavy, {"damage": 1100}),
		{"armor": {"frames": [5, 12], "hits": 1}, "step": [5, 15, 50]})
	normal("2lp", "C", "LP", 5, 2, 8, 3, 0, [25, 85, 52, 20], L, {}, LIGHT_CHAIN)
	normal("2mp", "C", "MP", 7, 3, 13, 3, -1, [28, 85, 75, 22], with(M, {"damage": 700}), {"step": [2, 8, 25]}, SPECIAL)
	normal("2hp", "C", "HP", 10, 4, 24, 1, -9, [10, 115, 58, 105], heavy, {"juggle_limit": 1})
	normal("2lk", "C", "LK", 5, 2, 9, 1, -2, [25, 0, 58, 22], L, {"guard": "low"})
	normal("2mk", "C", "MK", 9, 3, 17, 1, -5, [28, 0, 90, 22], with(M, {"damage": 700}), {"guard": "low", "step": [2, 10, 30]}, SPECIAL)
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

	# 西伯利亚坠落：236236P。超杀暂停后发生 3，范围 140
	_command_grab("super_grab", "super_grab", 3, 140, 3600, 50,
		{"cost": {"super": 1000}, "kind": "super", "invuln": [{"frames": [1, 4]}],
		"events": [{"frame": 1, "freeze": 40}]})
	command("236236P", "super", {"motion": "236236", "buttons": "P", "state": "super_grab"})


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

	# 铁锤：623P。原地对空，1~7 帧打击无敌，收招长
	states["hammer"] = {
		"type": "S", "kind": "special", "total": 6 + 5 + 28 - 1, "anim": "hammer",
		"invuln": [{"frames": [1, 7], "throw": false}],
		"hitboxes": [{"active": [6, 10], "boxes": [[5, 110, 62, 115]],
			"hit": {"damage": 1300, "hitstop": 12, "effect": "launch", "air_vx": 300, "air_vy": 1400,
				"juggle_limit": 3, "blockstun": 18, "push": 600, "block_push": 800, "strength": 2}}],
	}
	command("623P", "special", {"motion": "623", "buttons": "P", "state": "hammer"})


## 连段路线（投技型：连段短、伤害高；主要靠打康浮空和指令投二择，超杀是投技，不放进连段）。
func _combos() -> void:
	combo("轻攻击确认", "5LP > 5LP xx 623P", ["5lp", "5lp", "hammer"],
		[["5LP", 8], ["5LP", 6], ["6,2,3HP", 0]], {"hits": 3, "imported_only": true})
	combo("下段确认", "2MK xx 214P", ["2mk", "charge"],
		[["2MK", 10], ["2,1,4HP", 0]], {"hits": 2})
	combo("跳入", "j.HP > 5HP xx 214P", ["j_hp", "5hp", "charge"],
		[["9", 34], ["5HP", 23], ["5HP", 12], ["2,1,4HP", 0]], {"hits": 3, "gap": 210, "strict": [0, 1]})
	combo("打康浮空", "CH 5HP xx 623P", ["5hp", "hammer"],
		[["5HP", 12], ["6,2,3HP", 0]], {"hits": 2, "p2": "5x8,5LP", "gap": 110, "imported_only": true})
	combo("OD 冲撞", "5MP xx 214PP", ["5mp", "charge_od"],
		[["5MP", 10], ["2,1,4LP+MP", 0]], {"hits": 2})
