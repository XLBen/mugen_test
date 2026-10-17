extends MovesetBuilder
## Kagura —— 速攻型（短刀）。
##
## 特点：走速与冲刺最快、普攻发生快但距离短、体力低（9000），没有飞行道具。
## 连段路线（类 Gatling）：轻 → 中 → 重 逐级取消，普攻可必杀取消，突进斩可超杀取消。
## 必杀技：
##   236K  裂空斩     突进斩，K 越重距离越远，HK 命中击倒
##   214P  影步       快速前冲，可穿过对手（不参与推挤），前段打击无敌
##   623K  月轮       对空翻踢，1~5 帧无敌
##   空中 214K  坠星  斜下俯冲踢，上段
##   236KK / 623KK   OD 版本
##   236236K 千刃     超必杀，突进五连斩

const SPECIAL := ["special", "super"]
const FROM_LIGHT := ["special", "super", "5lp", "2lp", "2lk", "5mp", "2mp", "5mk", "2mk"]
const FROM_MEDIUM := ["special", "super", "5hp", "2hp", "5hk", "2hk"]


func build() -> void:
	_normals()
	_air_normals()
	_specials()
	_super()
	throw(58, 1200, 5)
	dashes(1150, 9, 16, 950, 11, 20, 7)
	dash_commands()
	_combos()


func _normals() -> void:
	normal("5lp", "S", "LP", 4, 2, 6, 5, 1, [22, 135, 50, 18], L, {}, FROM_LIGHT)
	normal("5mp", "S", "MP", 5, 2, 11, 5, 1, [22, 128, 62, 20], M, {}, FROM_MEDIUM)
	normal("5hp", "S", "HP", 8, 3, 16, 3, -2, [22, 120, 75, 24], H, {"push": 450}, SPECIAL)
	normal("5lk", "S", "LK", 4, 2, 8, 3, -1, [18, 70, 50, 22], L, {}, FROM_LIGHT)
	normal("5mk", "S", "MK", 6, 3, 12, 3, -2, [22, 55, 70, 22], M, {}, FROM_MEDIUM)
	normal("5hk", "S", "HK", 9, 3, 18, 2, -4, [22, 95, 85, 28], H, {"counter_effect": "launch", "air_vy": 1200})
	normal("2lp", "C", "LP", 4, 2, 6, 4, 0, [22, 85, 45, 18], L, {}, FROM_LIGHT)
	normal("2mp", "C", "MP", 5, 2, 10, 4, 1, [22, 85, 58, 20], M, {}, FROM_MEDIUM)
	normal("2hp", "C", "HP", 7, 4, 18, 1, -6, [8, 110, 48, 90], H, {"juggle_limit": 1})
	normal("2lk", "C", "LK", 4, 2, 7, 2, -1, [22, 0, 50, 20], L, {"guard": "low"}, FROM_LIGHT)
	normal("2mk", "C", "MK", 7, 3, 14, 1, -3, [22, 0, 72, 20], M, {"guard": "low"}, FROM_MEDIUM)
	normal("2hk", "C", "HK", 8, 3, 22, 0, -11, [22, 0, 85, 20], H, {"guard": "low", "effect": "knockdown"})


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

	# OD 裂空斩：两段，1~10 帧打击无敌，被防 -2
	states["slash_od"] = {
		"type": "S", "kind": "special", "total": 10 + 8 + 18 - 1, "anim": "slash", "cost": {"drive": 20000},
		"friction": 80, "invuln": [{"frames": [1, 10], "throw": false}],
		"events": [{"frame": 3, "vx": 1400}, {"frame": 18, "vx": 0}],
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

	# 月轮：623K，对空翻踢
	states["rising"] = {
		"type": "S", "kind": "special", "air_from": 5, "land": "landing_long", "anim": "rising",
		"invuln": [{"frames": [1, 5]}],
		"events": [{"frame": 5, "vx": 150, "vy": 1450}],
		"hitboxes": [{"active": [5, 12], "boxes": [[5, 90, 55, 110]],
			"hit": {"damage": 1100, "hitstop": 11, "effect": "launch", "air_vx": 250, "air_vy": 1300,
				"juggle_limit": 3, "blockstun": 18, "push": 600, "block_push": 800, "strength": 2}}],
	}
	command("623K", "special", {"motion": "623", "buttons": "K", "state": "rising"})
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
	# 千刃：236236K。超杀暂停后高速突进，四段斩 + 最后一击浮空
	var hits := []
	for w in [[9, 10], [12, 13], [15, 16], [18, 19]]:
		hits.append({"active": w, "boxes": [[5, 40, 85, 130]],
			"hit": {"damage": 400, "chip": 100, "hitstop": 5, "hitstun": 30, "blockstun": 22, "push": 50,
				"block_push": 50, "juggle_limit": 10, "min_scale": 30, "meter": 0, "strength": 1}})
	hits.append({"active": [22, 24], "boxes": [[5, 40, 90, 140]],
		"hit": {"damage": 1200, "chip": 300, "hitstop": 14, "effect": "launch", "air_vx": 450, "air_vy": 1500,
			"blockstun": 18, "push": 900, "block_push": 1000, "juggle_limit": 10, "min_scale": 30, "meter": 0, "strength": 2}})
	states["super_k"] = {
		"type": "S", "kind": "super", "total": 24 + 30, "anim": "super_k", "cost": {"super": 1000},
		"invuln": [{"frames": [1, 14]}], "friction": 60,
		"events": [{"frame": 1, "freeze": 40}, {"frame": 6, "vx": 1600}, {"frame": 12, "vx": 200}, {"frame": 24, "vx": 0}],
		"hitboxes": hits,
	}
	command("236236K", "super", {"motion": "236236", "buttons": "K", "state": "super_k"})


## 连段路线（SF6 式：轻攻击连打确认、中攻击 Gatling、跳入、打康、超杀 / OD 收尾）。
func _combos() -> void:
	combo("下段确认", "2LK > 2LP > 5LP xx 236LK", ["2lk", "2lp", "5lp", "slash_l"],
		[["2LK", 7], ["2LP", 7], ["5LP", 6], ["2,3,6LK", 0]], {"hits": 4})
	combo("Gatling 连续技", "5MP > 5HP xx 236HK", ["5mp", "5hp", "slash_h"],
		[["5MP", 8], ["5HP", 10], ["2,3,6HK", 0]], {"hits": 3})
	combo("跳入", "j.HK > 5HP xx 236HK", ["j_hk", "5hp", "slash_h"],
		[["9", 33], ["5HK", 19], ["5HP", 10], ["2,3,6HK", 0]], {"hits": 3, "gap": 210, "strict": [0, 1]})
	combo("确反", "PC 5HP > 5MP xx 236HK", ["5hp", "5mp", "slash_h"],
		[["5", 40], ["5HP", 36], ["5MP", 8], ["2,3,6HK", 0]], {"hits": 3, "gap": 180, "p2": "6,2,3LP", "strict": [0]})
	combo("超杀收尾", "5MP > 5HP xx 236MK xx 236236K", ["5mp", "5hp", "slash_m", "super_k"],
		[["5MP", 8], ["5HP", 10], ["2,3,6MK", 22], ["2,3,6,2,3,6HK", 0]], {"hits": 8, "meter": true})
	combo("OD 追加", "5MP > 5HP xx 236KK", ["5mp", "5hp", "slash_od"],
		[["5MP", 8], ["5HP", 10], ["2,3,6LK+MK", 0]], {"hits": 4})
