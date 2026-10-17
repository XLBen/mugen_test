extends MovesetBuilder
## Mio —— 远程立回型（长袖）。
##
## 特点：普攻距离最长但发生偏慢、后退速度快；靠道具和设置物控场。
## 必杀技：
##   236P   纸符       地面飞行道具（三种速度，飞得快，像飞刀）
##   空中 236P  落符   斜下方飞行道具
##   214P   封印       在前方放置符阵（P 越重越远），25 帧后启动，踩中浮空；同屏一个
##   623K   缎带旋     三段对空，1~6 帧无敌
##   236PP / 623KK   OD 版本（两段纸符 / 更长无敌）
##   236236P 纸吹雪     超杀，慢速多段巨型道具

const SPECIAL := ["special", "super"]
const LIGHT_CHAIN := ["special", "super", "5lp", "2lp"]


func build() -> void:
	_normals()
	_air_normals()
	_charms()
	_seals()
	_spin()
	_super()
	throw(58, 1100, 5)
	dashes(900, 10, 20, 950, 13, 22, 8)
	dash_commands()
	_combos()


func _normals() -> void:
	normal("5lp", "S", "LP", 4, 2, 8, 3, -1, [22, 135, 62, 18], L, {}, LIGHT_CHAIN)
	normal("5mp", "S", "MP", 7, 3, 14, 2, -2, [28, 128, 95, 22], M, {"step": [3, 9, 30]}, SPECIAL)
	normal("5hp", "S", "HP", 10, 4, 22, 1, -6, [30, 120, 115, 26], H, {"step": [5, 12, 45], "reach_cap": 145}, SPECIAL)
	normal("5lk", "S", "LK", 5, 3, 10, 2, -2, [20, 70, 70, 22], L)
	normal("5mk", "S", "MK", 8, 3, 16, 1, -3, [25, 55, 100, 24], M, {"step": [3, 9, 20]}, SPECIAL)
	normal("5hk", "S", "HK", 12, 4, 22, 1, -6, [20, 130, 90, 40], H, {"juggle_limit": 1})
	normal("2lp", "C", "LP", 4, 2, 8, 3, -1, [22, 85, 55, 18], L, {}, LIGHT_CHAIN)
	normal("2mp", "C", "MP", 6, 3, 14, 2, -2, [25, 85, 80, 20], M, {}, SPECIAL)
	normal("2hp", "C", "HP", 9, 5, 22, 1, -8, [0, 110, 70, 100], H, {"juggle_limit": 1})
	normal("2lk", "C", "LK", 5, 2, 9, 1, -2, [22, 0, 60, 20], L, {"guard": "low"})
	normal("2mk", "C", "MK", 9, 3, 17, 1, -5, [25, 0, 105, 20], M, {"guard": "low", "step": [4, 11, 15]}, SPECIAL)
	normal("2hk", "C", "HK", 10, 3, 26, 0, -14, [25, 0, 110, 20], H, {"guard": "low", "effect": "knockdown",
		"step": [4, 13, 45]})


func _air_normals() -> void:
	air("j_lp", "LP", 4, 6, 14, 10, [15, 60, 55, 24], L)
	air("j_mp", "MP", 6, 4, 17, 14, [15, 40, 70, 30], M)
	air("j_hp", "HP", 9, 4, 20, 16, [10, 10, 75, 45], H)
	air("j_lk", "LK", 5, 8, 14, 10, [10, 20, 50, 28], L)
	air("j_mk", "MK", 7, 4, 17, 14, [15, 5, 65, 34], M)
	air("j_hk", "HK", 9, 5, 20, 16, [15, 10, 80, 40], H)


func _charms() -> void:
	var hit := {"damage": 600, "chip": 150, "hitstun": 20, "blockstun": 17, "hitstop": 10,
		"push": 600, "block_push": 700, "strength": 1}
	for k in ["h", "m", "l"]:
		states["charm_" + k] = {
			"type": "S", "kind": "special", "total": 44, "anim": "charm", "active_hint": [12, 15],
			"events": [{"frame": 12, "spawn": "charm_" + k, "x": 65, "y": 125}],
		}
		command("236" + k.to_upper() + "P", "special", {"motion": "236", "buttons": k.to_upper() + "P",
			"state": "charm_" + k, "cond": "limit:fireball"})
	projectiles["charm_l"] = {"speed": 900, "box": [-18, -22, 36, 44], "hit": hit, "anim": "charm"}
	projectiles["charm_m"] = {"speed": 1150, "box": [-18, -22, 36, 44], "hit": hit, "anim": "charm"}
	projectiles["charm_h"] = {"speed": 1400, "box": [-18, -22, 36, 44], "hit": hit, "anim": "charm"}

	# OD 纸符：两段命中，比普通版快得多
	states["charm_od"] = {
		"type": "S", "kind": "special", "total": 40, "anim": "charm", "active_hint": [10, 13], "cost": {"drive": 20000},
		"events": [{"frame": 10, "spawn": "charm_od", "x": 65, "y": 125}],
	}
	command("236PP", "od", {"motion": "236", "buttons": "PP", "state": "charm_od", "cond": "limit:fireball"})
	projectiles["charm_od"] = {"speed": 1800, "box": [-24, -28, 48, 56], "hits": 2, "hit_interval": 3, "anim": "charm",
		"hit": {"damage": 500, "chip": 125, "hitstun": 24, "blockstun": 18, "hitstop": 7, "push": 200,
			"block_push": 300, "strength": 1, "meter": 0, "juggle_limit": 3}}

	# 落符：空中 236P，空中停顿后向斜下方发射
	states["air_charm"] = {
		"type": "A", "kind": "special", "total": 30, "next": "air", "anim": "air_charm", "active_hint": [10, 13],
		"events": [{"frame": 1, "vx": 0, "vy": 250}, {"frame": 10, "spawn": "air_charm", "x": 40, "y": 60}],
	}
	command("j236P", "special", {"motion": "236", "buttons": "P", "where": "air", "state": "air_charm",
		"cond": "limit:fireball"})
	projectiles["air_charm"] = {"speed": 1000, "speed_y": -920, "box": [-18, -22, 36, 44], "anim": "air_charm",
		"anim_fallback": "charm",
		"hit": with(hit, {"guard": "high"})}


func _seals() -> void:
	# 封印：214P。放在前方 120 / 220 / 320 像素处，25 帧后启动，持续 6 秒
	var dist := {"l": 120, "m": 220, "h": 320}
	for k in ["h", "m", "l"]:
		states["seal_" + k] = {
			"type": "S", "kind": "special", "total": 32, "anim": "seal", "active_hint": [14, 16],
			"events": [{"frame": 14, "spawn": "seal", "x": dist[k], "y": 0}],
		}
		command("214" + k.to_upper() + "P", "special", {"motion": "214", "buttons": k.to_upper() + "P",
			"state": "seal_" + k, "cond": "limit:trap"})
	projectiles["seal"] = {"speed": 0, "box": [-28, 0, 56, 40], "arm": 25, "lifetime": 360, "group": "trap",
		"anim": "seal",
		"hit": {"damage": 500, "hitstop": 10, "effect": "launch", "air_vx": 150, "air_vy": 1300, "juggle_start": 0,
			"blockstun": 14, "push": 300, "block_push": 400, "strength": 1}}


func _spin() -> void:
	# 缎带旋：623K。三段上升，1~6 帧无敌，最后一段浮空。像 SF6 的升龙一样高高飞起（峰值约 200 像素，前进约 90 像素），
	# 落地硬直随之变长
	var hits := []
	for w in [[5, 6], [8, 9]]:
		hits.append({"active": w, "boxes": [[0, 80, 60, 130]],
			"hit": {"damage": 350, "hitstop": 6, "hitstun": 26, "blockstun": 20, "push": 0, "block_push": 100,
				"air_vx": 50, "air_vy": 900, "juggle_limit": 5, "strength": 1}})
	hits.append({"active": [11, 13], "boxes": [[0, 90, 60, 130]],
		"hit": {"damage": 600, "hitstop": 11, "effect": "launch", "air_vx": 300, "air_vy": 1300, "juggle_limit": 5,
			"blockstun": 18, "push": 600, "block_push": 800, "strength": 2}})
	states["spin"] = {
		"type": "S", "kind": "special", "air_from": 5, "land": "landing_long", "anim": "spin",
		"invuln": [{"frames": [1, 6]}], "events": [{"frame": 5, "vx": 220, "vy": 1900}], "hitboxes": hits,
	}
	command("623K", "special", {"motion": "623", "buttons": "K", "state": "spin"})
	var od: Dictionary = states["spin"].duplicate(true)
	od["cost"] = {"drive": 20000}
	od["invuln"] = [{"frames": [1, 13]}]
	od["events"] = [{"frame": 5, "vx": 260, "vy": 2100}]
	states["spin_od"] = od
	command("623KK", "od", {"motion": "623", "buttons": "KK", "state": "spin_od"})


func _super() -> void:
	# 纸吹雪：236236P。超杀暂停后放出缓慢的巨型多段道具
	states["storm"] = {
		"type": "S", "kind": "super", "total": 50, "anim": "storm", "active_hint": [10, 14], "cost": {"super": 1000},
		"invuln": [{"frames": [1, 12]}],
		"events": [{"frame": 1, "freeze": 40}, {"frame": 10, "spawn": "storm", "x": 70, "y": 110}],
	}
	command("236236P", "super", {"motion": "236236", "buttons": "P", "state": "storm"})
	projectiles["storm"] = {"speed": 550, "box": [-70, -80, 140, 160], "hits": 6, "hit_interval": 4, "kind": "super",
		"anim": "storm", "lifetime": 120,
		"hit": {"damage": 450, "chip": 110, "hitstun": 30, "blockstun": 20, "hitstop": 5, "push": 150, "block_push": 150,
			"juggle_limit": 10, "min_scale": 30, "meter": 0, "strength": 1}}


## 连段路线（远程型：中距离用 2MK / 5MP 取消纸符确认，近身才用轻攻击；623K 三段作收尾）。
func _combos() -> void:
	combo("近身确认", "2LP > 5LP xx 236LP", ["2lp", "5lp", "charm_l"],
		[["2LP", 8], ["5LP", 6], ["2,3,6LP", 0]], {"hits": 3})
	combo("牵制确认", "2MK xx 236HP", ["2mk", "charm_h"],
		[["2MK", 10], ["2,3,6HP", 0]], {"hits": 2, "gap": 110})
	combo("升龙收尾", "5LP > 5LP xx 623K", ["5lp", "5lp", "spin"],
		[["5LP", 8], ["5LP", 6], ["6,2,3MK", 0]], {"hits": 3, "imported_only": true})
	combo("跳入", "j.HP > 5MP xx 236HP", ["j_hp", "5mp", "charm_h"],
		[["9", 33], ["5HP", 23], ["5MP", 10], ["2,3,6HP", 0]], {"hits": 3, "gap": 210, "strict": [0, 1]})
	combo("OD 纸符", "5HP xx 236PP", ["5hp", "charm_od"],
		[["5HP", 12], ["2,3,6LP+MP", 0]], {"hits": 3})
	combo("超杀收尾", "5MP xx 236236P", ["5mp", "storm"],
		[["5MP", 10], ["2,3,6,2,3,6HP", 0]], {"hits": 5, "meter": true})
