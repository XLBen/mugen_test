extends MovesetBuilder
## 标准波动升龙型（参考角色 dummy 使用，测试也以它为基准）。
##
## 连段路线：轻/中普攻、5HP、2MK 可必杀取消；轻攻击互相连打；5MP > HP 为 Target Combo；突进踢可超杀取消。

const SPECIAL_CANCEL := ["special", "super"]
const LIGHT_CHAIN := ["special", "super", "5lp", "2lp", "2lk"]


func build() -> void:
	_normals()
	_air_normals()
	_specials()
	throw()
	dash_commands()


func _normals() -> void:
	# 名字, 类型, 按键, 发生, 持续, 收招, 命中有利, 防御有利, 攻击盒, 强度, 额外, 取消
	normal("5lp", "S", "LP", 4, 2, 7, 4, -1, [25, 135, 55, 20], L, {}, LIGHT_CHAIN)
	normal("5mp", "S", "MP", 6, 3, 13, 5, 1, [25, 130, 70, 22], M, {}, SPECIAL_CANCEL + ["tc_hp"])
	normal("5hp", "S", "HP", 9, 3, 20, 2, -4, [25, 125, 85, 26], H, {}, SPECIAL_CANCEL)
	normal("5lk", "S", "LK", 5, 3, 9, 3, -2, [20, 70, 60, 24], L, {}, SPECIAL_CANCEL)
	normal("5mk", "S", "MK", 8, 3, 15, 2, -3, [25, 60, 80, 25], M)
	normal("5hk", "S", "HK", 11, 4, 20, 1, -5, [25, 100, 95, 30], H, {"counter_effect": "launch", "air_vy": 1200})
	normal("2lp", "C", "LP", 4, 2, 7, 4, -1, [25, 85, 50, 20], L, {}, LIGHT_CHAIN)
	normal("2mp", "C", "MP", 6, 3, 12, 4, 0, [25, 85, 65, 22], M, {}, SPECIAL_CANCEL)
	normal("2hp", "C", "HP", 8, 4, 22, 1, -8, [10, 110, 50, 95], H, {"juggle_limit": 1})
	normal("2lk", "C", "LK", 5, 2, 8, 2, -1, [25, 0, 55, 22], L, {"guard": "low"}, LIGHT_CHAIN)
	normal("2mk", "C", "MK", 8, 3, 16, 1, -4, [25, 0, 80, 22], M, {"guard": "low"}, SPECIAL_CANCEL)
	normal("2hk", "C", "HK", 9, 3, 24, 0, -12, [25, 0, 95, 22], H, {"guard": "low", "effect": "knockdown"})

	# Target Combo：5MP 命中/被防后按 HP。比 5HP 发生快，命中击倒，可以再取消必杀
	normal("tc_hp", "S", "HP", 7, 3, 22, 0, -6, [25, 120, 90, 28], H,
		{"damage": 700, "effect": "knockdown"}, SPECIAL_CANCEL)
	states["tc_hp"].anim = "5hp"
	frame_table.erase("tc_hp")
	commands.pop_back()
	command("5MP>HP", "normal", {"buttons": "HP", "where": "cancel", "state": "tc_hp"})


func _air_normals() -> void:
	air("j_lp", "LP", 4, 6, 14, 10, [15, 60, 45, 25], L)
	air("j_mp", "MP", 6, 4, 17, 14, [15, 50, 55, 30], M)
	air("j_hp", "HP", 8, 4, 20, 16, [10, 20, 60, 45], H)
	air("j_lk", "LK", 5, 8, 14, 10, [10, 20, 45, 30], L)
	air("j_mk", "MK", 7, 4, 17, 14, [15, 5, 60, 35], M)
	air("j_hk", "HK", 9, 5, 20, 16, [15, 10, 75, 40], H)


func _specials() -> void:
	# 升龙：发生 4，1~6 帧打击/投无敌，起飞后直到落地都可被惩罚
	states["dp"] = {
		"type": "S", "kind": "special", "air_from": 4, "land": "landing_long", "anim": "dp",
		"invuln": [{"frames": [1, 6]}],
		"events": [{"frame": 4, "vx": 250, "vy": 1500}],
		"hitboxes": [{"active": [4, 14], "boxes": [[10, 100, 50, 110]],
			"hit": {"damage": 1300, "hitstop": 12, "effect": "launch", "air_vx": 300, "air_vy": 1400, "juggle_limit": 3,
				"blockstun": 20, "push": 600, "block_push": 800, "strength": 2}}],
	}
	command("623P", "special", {"motion": "623", "buttons": "P", "state": "dp"})

	# OD 升龙：消耗 2 格 Drive，1~12 帧全身无敌，可以追打
	states["dp_ex"] = {
		"type": "S", "kind": "special", "air_from": 4, "land": "landing_long", "anim": "dp", "cost": {"drive": 20000},
		"invuln": [{"frames": [1, 12]}],
		"events": [{"frame": 4, "vx": 300, "vy": 1650}],
		"hitboxes": [{"active": [4, 16], "boxes": [[10, 100, 55, 120]],
			"hit": {"damage": 1500, "hitstop": 12, "effect": "launch", "air_vx": 300, "air_vy": 1500, "juggle_limit": 5,
				"blockstun": 20, "push": 600, "block_push": 800, "strength": 2}}],
	}
	command("623PP", "od", {"motion": "623", "buttons": "PP", "state": "dp_ex"})

	# 波动：三种强度只差道具速度
	for strength in ["h", "m", "l"]:
		states["fireball_" + strength] = {
			"type": "S", "kind": "special", "total": 46, "anim": "fireball", "active_hint": [13, 16],
			"events": [{"frame": 13, "spawn": "fireball_" + strength, "x": 60, "y": 120}],
		}
		command("236" + strength.to_upper() + "P", "special", {"motion": "236", "buttons": strength.to_upper() + "P",
			"state": "fireball_" + strength, "cond": "limit:fireball"})

	# OD 波动：耐久 2（能抵消一发普通波动后继续前进）
	states["fireball_ex"] = {
		"type": "S", "kind": "special", "total": 42, "anim": "fireball", "active_hint": [11, 14],
		"cost": {"drive": 20000},
		"events": [{"frame": 11, "spawn": "fireball_ex", "x": 60, "y": 120}],
	}
	command("236PP", "od", {"motion": "236", "buttons": "PP", "state": "fireball_ex", "cond": "limit:fireball"})

	var fb_hit := {"damage": 600, "chip": 150, "hitstun": 20, "blockstun": 17, "hitstop": 8,
		"push": 600, "block_push": 700, "strength": 1}
	projectiles["fireball_l"] = {"speed": 450, "box": [-20, -20, 40, 40], "hit": fb_hit}
	projectiles["fireball_m"] = {"speed": 600, "box": [-20, -20, 40, 40], "hit": fb_hit}
	projectiles["fireball_h"] = {"speed": 800, "box": [-20, -20, 40, 40], "hit": fb_hit}
	projectiles["fireball_ex"] = {"speed": 750, "box": [-24, -24, 48, 48], "hits": 2,
		"hit": {"damage": 800, "chip": 200, "hitstun": 24, "blockstun": 20, "hitstop": 9,
			"push": 650, "block_push": 750, "strength": 1, "meter": 0}}

	# 突进踢：命中击倒，被防 -6，可超杀取消
	var rush_total := 14 + 5 + 18 - 1
	states["rush"] = {
		"type": "S", "kind": "special", "total": rush_total, "anim": "rush", "friction": 50,
		"events": [{"frame": 8, "vx": 750}, {"frame": 19, "vx": 0}],
		"hitboxes": [{"active": [14, 18], "boxes": [[20, 60, 70, 40]],
			"hit": {"damage": 1000, "hitstop": 11, "effect": "knockdown", "blockstun": -6 + rush_total - 14,
				"chip": 120, "push": 700, "block_push": 900, "strength": 2}}],
		"hurtboxes": [{"frames": [12, rush_total], "boxes": [[15, 60, 60, 40]]}],
		"cancel": ["super"],
	}
	command("214K", "special", {"motion": "214", "buttons": "K", "state": "rush"})

	# 超必杀 Lv1：236236P，1 格超杀槽。第 1 帧超杀暂停 40 帧，1~12 帧无敌，伤害保底 30%
	var super_total := 8 + 6 + 34 - 1
	states["super1"] = {
		"type": "S", "kind": "super", "total": super_total, "anim": "super", "cost": {"super": 1000},
		"invuln": [{"frames": [1, 12]}],
		"events": [{"frame": 1, "freeze": 40}, {"frame": 6, "vx": 900}, {"frame": 14, "vx": 0}],
		"friction": 60,
		"hitboxes": [{"active": [8, 13], "boxes": [[15, 40, 85, 130]],
			"hit": {"damage": 2600, "chip": 650, "hitstop": 14, "effect": "launch", "air_vx": 400, "air_vy": 1500,
				"blockstun": 18, "push": 800, "block_push": 1000, "juggle_limit": 10, "min_scale": 30,
				"meter": 0, "strength": 2}}],
	}
	command("236236P", "super", {"motion": "236236", "buttons": "P", "state": "super1"})
