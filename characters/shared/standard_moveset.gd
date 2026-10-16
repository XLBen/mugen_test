extends RefCounted
## 标准街霸风招式表（三个占位角色暂时共用）。
##
## 普攻按格斗游戏常见的帧数据格式书写：发生 / 持续 / 收招 / 命中有利 / 防御有利，
## 受击与防御硬直由有利帧反推：硬直 = 有利帧 + (总帧数 - 发生帧)。
## 判定盒以像素书写：[x 向前, y 向上, 宽, 高]，相对脚底中心、面朝右。
##
## 连段路线（接触对手后的取消）：
##   必杀取消：轻/中普攻、5HP、2MK → 必杀技 / 超必杀
##   连打：轻攻击之间互相取消（5LP / 2LP / 2LK）
##   Target Combo：5MP > HP

const L := {"damage": 300, "hitstop": 7, "push": 500, "block_push": 550, "strength": 0}
const M := {"damage": 600, "hitstop": 9, "push": 600, "block_push": 650, "strength": 1}
const H := {"damage": 800, "hitstop": 11, "push": 700, "block_push": 750, "strength": 2}

const SPECIAL_CANCEL := ["special", "super"]
const LIGHT_CHAIN := ["special", "super", "5lp", "2lp", "2lk"]

var states := {}
var commands := []


func data() -> Dictionary:
	_specials()
	_throw()
	_ground_normals()
	_air_normals()
	commands.append({"name": "66", "motion": "66", "state": "dash_f"})
	commands.append({"name": "44", "motion": "44", "state": "dash_b"})
	return {"states": states, "commands": commands, "projectiles": _projectiles()}


func _ground_normals() -> void:
	# 名字, 类型, 按键, 发生, 持续, 收招, 命中有利, 防御有利, 攻击盒, 强度, 额外
	_normal("5hp", "S", "HP", 9, 3, 20, 2, -4, [25, 125, 85, 26], H, {}, SPECIAL_CANCEL)
	_normal("5mp", "S", "MP", 6, 3, 13, 5, 1, [25, 130, 70, 22], M, {}, SPECIAL_CANCEL + ["tc_hp"])
	_normal("5lp", "S", "LP", 4, 2, 7, 4, -1, [25, 135, 55, 20], L, {}, LIGHT_CHAIN)
	_normal("5hk", "S", "HK", 11, 4, 20, 1, -5, [25, 100, 95, 30], H, {"counter_effect": "launch", "air_vy": 1200})
	_normal("5mk", "S", "MK", 8, 3, 15, 2, -3, [25, 60, 80, 25], M)
	_normal("5lk", "S", "LK", 5, 3, 9, 3, -2, [20, 70, 60, 24], L, {}, SPECIAL_CANCEL)
	_normal("2hp", "C", "HP", 8, 4, 22, 1, -8, [10, 110, 50, 95], H, {"juggle_limit": 1})
	_normal("2mp", "C", "MP", 6, 3, 12, 4, 0, [25, 85, 65, 22], M, {}, SPECIAL_CANCEL)
	_normal("2lp", "C", "LP", 4, 2, 7, 4, -1, [25, 85, 50, 20], L, {}, LIGHT_CHAIN)
	_normal("2hk", "C", "HK", 9, 3, 24, 0, -12, [25, 0, 95, 22], H, {"guard": "low", "effect": "knockdown"})
	_normal("2mk", "C", "MK", 8, 3, 16, 1, -4, [25, 0, 80, 22], M, {"guard": "low"}, SPECIAL_CANCEL)
	_normal("2lk", "C", "LK", 5, 2, 8, 2, -1, [25, 0, 55, 22], L, {"guard": "low"}, LIGHT_CHAIN)

	# Target Combo：5MP 命中/被防后按 HP。比 5HP 发生快，命中击倒，可以再取消必杀
	_normal("tc_hp", "S", "HP", 7, 3, 22, 0, -6, [25, 120, 90, 28], H,
		{"damage": 700, "effect": "knockdown"}, SPECIAL_CANCEL)
	states["tc_hp"].anim = "5hp"
	commands.pop_back()
	commands.append({"name": "5MP>HP", "buttons": "HP", "where": "cancel", "state": "tc_hp"})


func _air_normals() -> void:
	# 空中技命中/防御硬直直接给定（有利帧取决于跳入高度）。全部是上段（必须站防）。
	_air("j_hp", "HP", 8, 4, 20, 16, [10, 20, 60, 45], H)
	_air("j_mp", "MP", 6, 4, 17, 14, [15, 50, 55, 30], M)
	_air("j_lp", "LP", 4, 6, 14, 10, [15, 60, 45, 25], L)
	_air("j_hk", "HK", 9, 5, 20, 16, [15, 10, 75, 40], H)
	_air("j_mk", "MK", 7, 4, 17, 14, [15, 5, 60, 35], M)
	_air("j_lk", "LK", 5, 8, 14, 10, [10, 20, 45, 30], L)


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
	commands.append({"name": "623P", "motion": "623", "buttons": "P", "state": "dp"})

	# 波动：三种强度只差道具速度
	for strength in ["l", "m", "h"]:
		states["fireball_" + strength] = {
			"type": "S", "kind": "special", "total": 46, "anim": "fireball", "active_hint": [13, 16],
			"events": [{"frame": 13, "spawn": "fireball_" + strength, "x": 60, "y": 120}],
		}
	commands.append({"name": "236HP", "motion": "236", "buttons": "HP", "state": "fireball_h", "cond": "no_projectile"})
	commands.append({"name": "236MP", "motion": "236", "buttons": "MP", "state": "fireball_m", "cond": "no_projectile"})
	commands.append({"name": "236LP", "motion": "236", "buttons": "LP", "state": "fireball_l", "cond": "no_projectile"})

	# 突进踢：命中击倒，被防 -6
	var rush_total := 14 + 5 + 18 - 1
	states["rush"] = {
		"type": "S", "kind": "special", "total": rush_total, "anim": "rush", "friction": 50,
		"events": [{"frame": 8, "vx": 750}, {"frame": 19, "vx": 0}],
		"hitboxes": [{"active": [14, 18], "boxes": [[20, 60, 70, 40]],
			"hit": {"damage": 1000, "hitstop": 11, "effect": "knockdown", "blockstun": -6 + rush_total - 14,
				"chip": 120, "push": 700, "block_push": 900, "strength": 2}}],
		"hurtboxes": [{"frames": [12, rush_total], "boxes": [[15, 60, 60, 40]]}],
	}
	commands.append({"name": "214K", "motion": "214", "buttons": "K", "state": "rush"})


func _throw() -> void:
	states["throw"] = {
		"type": "S", "kind": "throw", "total": 5 + 3 + 20 - 1, "anim": "throw",
		"throw": {"active": [5, 7], "box": [0, 0, 60, 150]},
	}
	states["throw_hit"] = {
		"type": "S", "kind": "throw", "total": 45, "anim": "throw_hit", "logic": "throwing",
		"throw_release": 30, "throw_offset": 72,
		"throw_hit": {"damage": 1200, "hitstop": 6, "air_vx": 500, "air_vy": 700},
	}
	commands.append({"name": "throw", "buttons": "LP+LK", "state": "throw"})


func _projectiles() -> Dictionary:
	var hit := {"damage": 600, "chip": 150, "hitstun": 20, "blockstun": 17, "hitstop": 8,
		"push": 600, "block_push": 700, "strength": 1}
	return {
		"fireball_l": {"speed": 450, "box": [-20, -20, 40, 40], "hit": hit},
		"fireball_m": {"speed": 600, "box": [-20, -20, 40, 40], "hit": hit},
		"fireball_h": {"speed": 800, "box": [-20, -20, 40, 40], "hit": hit},
	}


func _normal(state_name: String, type: String, button: String, startup: int, active: int, recovery: int,
		on_hit: int, on_block: int, box: Array, base: Dictionary, extra := {}, cancel := []) -> void:
	var total := startup + active + recovery - 1
	var hit := base.duplicate()
	hit.hitstun = on_hit + total - startup
	hit.blockstun = on_block + total - startup
	hit.merge(extra, true)
	states[state_name] = {
		"type": type, "kind": "normal", "total": total, "anim": state_name,
		"hitboxes": [{"active": [startup, startup + active - 1], "boxes": [box], "hit": hit}],
		"hurtboxes": [{"frames": [startup, total], "boxes": [_limb(box)]}],
		"cancel": cancel,
	}
	commands.append({"name": state_name, "buttons": button, "stance": "crouch" if type == "C" else "stand",
		"state": state_name})


func _air(state_name: String, button: String, startup: int, active: int, hitstun: int, blockstun: int,
		box: Array, base: Dictionary) -> void:
	var hit := base.duplicate()
	hit.hitstun = hitstun
	hit.blockstun = blockstun
	hit.guard = "high"
	states[state_name] = {
		"type": "A", "kind": "normal", "total": startup + active + 10, "next": "air", "anim": state_name,
		"hitboxes": [{"active": [startup, startup + active - 1], "boxes": [box], "hit": hit}],
	}
	commands.append({"name": state_name, "buttons": button, "where": "air", "state": state_name})


## 出招时伸出的手脚也是受击区域（比攻击判定略短），这样才有"拆招"。
func _limb(box: Array) -> Array:
	return [box[0] - 5, box[1], int(box[2] * 0.8), box[3]]
