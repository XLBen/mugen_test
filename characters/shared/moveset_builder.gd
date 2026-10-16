class_name MovesetBuilder
extends RefCounted
## 招式表编写工具。每个角色的 moveset.gd 继承它，在 build() 里用下面的函数登记招式。
##
## 普攻按格斗游戏常见的帧数据格式书写：发生 / 持续 / 收招 / 命中有利 / 防御有利，
## 受击与防御硬直由有利帧反推：硬直 = 有利帧 + (总帧数 - 发生帧)。
## 判定盒以像素书写：[x 向前, y 向上, 宽, 高]，相对脚底中心、面朝右。
## 出招表顺序即优先级（SF6）：OD 必杀 > 超杀 > 普通必杀 > 投 > 普攻 > 冲刺。
## 登记顺序随意，data() 会按 priority 稳定排序。

const L := {"damage": 300, "hitstop": 7, "push": 500, "block_push": 550, "strength": 0}
const M := {"damage": 600, "hitstop": 9, "push": 600, "block_push": 650, "strength": 1}
const H := {"damage": 800, "hitstop": 11, "push": 700, "block_push": 750, "strength": 2}

const PRIORITY := {"od": 0, "super": 1, "special": 2, "throw": 3, "normal": 4, "move": 5}

var states := {}
var commands := []
var projectiles := {}
## 普攻帧数据表（测试用）：名字 → {on_hit, on_block, knockdown}
var frame_table := {}


## 子类实现：登记全部招式。
func build() -> void:
	pass


func data() -> Dictionary:
	build()
	commands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return PRIORITY[a.priority] < PRIORITY[b.priority] if a.priority != b.priority else a.order < b.order)
	return {"states": states, "commands": commands, "projectiles": projectiles}


func command(name: String, priority: String, d: Dictionary) -> void:
	var c := d.duplicate()
	c.name = name
	c.priority = priority
	c.order = commands.size()
	commands.append(c)


## 地面普攻。cancel：接触后可以取消到的目标（kind 名或状态名）。
func normal(state_name: String, type: String, button: String, startup: int, active: int, recovery: int,
		on_hit: int, on_block: int, box: Array, base: Dictionary, extra := {}, cancel := []) -> void:
	var total := startup + active + recovery - 1
	var hit := base.duplicate()
	hit.hitstun = on_hit + total - startup
	hit.blockstun = on_block + total - startup
	hit.merge(extra, true)
	var state := {
		"type": type, "kind": "normal", "total": total, "anim": state_name,
		"hitboxes": [{"active": [startup, startup + active - 1], "boxes": [box], "hit": hit}],
		"hurtboxes": [{"frames": [startup, total], "boxes": [limb(box)]}],
		"cancel": cancel,
	}
	for key in ["armor"]:
		if extra.has(key):
			state[key] = extra[key]
			hit.erase(key)
	states[state_name] = state
	frame_table[state_name] = {"on_hit": on_hit, "on_block": on_block,
		"knockdown": hit.get("effect", "normal") != "normal"}
	command(state_name, "normal", {"buttons": button, "stance": "crouch" if type == "C" else "stand",
		"state": state_name})


## 空中普攻：命中/防御硬直直接给定（有利帧取决于跳入高度），全部是上段。
func air(state_name: String, button: String, startup: int, active: int, hitstun: int, blockstun: int,
		box: Array, base: Dictionary, extra := {}) -> void:
	var hit := base.duplicate()
	hit.hitstun = hitstun
	hit.blockstun = blockstun
	hit.guard = "high"
	hit.merge(extra, true)
	states[state_name] = {
		"type": "A", "kind": "normal", "total": startup + active + 10, "next": "air", "anim": state_name,
		"hitboxes": [{"active": [startup, startup + active - 1], "boxes": [box], "hit": hit}],
	}
	command(state_name, "normal", {"buttons": button, "where": "air", "state": state_name})


## 通用投（LP+LK）。range_px：投判定向前的长度。
func throw(range_px := 60, damage := 1200, startup := 5) -> void:
	states["throw"] = {
		"type": "S", "kind": "throw", "total": startup + 3 + 20 - 1, "anim": "throw",
		"throw": {"active": [startup, startup + 2], "box": [0, 0, range_px, 150]},
	}
	states["throw_hit"] = {
		"type": "S", "kind": "throw", "total": 45, "anim": "throw_hit", "logic": "throwing",
		"throw_release": 30, "throw_offset": 72,
		"throw_hit": {"damage": damage, "hitstop": 6, "air_vx": 500, "air_vy": 700},
	}
	command("throw", "throw", {"buttons": "LP+LK", "state": "throw"})


func dashes(forward_speed: int, forward_frames: int, forward_total: int,
		back_speed: int, back_frames: int, back_total: int, back_invuln: int) -> void:
	states["dash_f"] = {"type": "S", "total": forward_total, "anim": "walk_f",
		"events": [{"frame": 1, "vx": forward_speed}, {"frame": forward_frames + 1, "vx": 0}]}
	states["dash_b"] = {"type": "S", "total": back_total, "anim": "walk_b", "punishable_from": back_invuln + 1,
		"invuln": [{"frames": [1, back_invuln], "strike": true, "throw": true}],
		"events": [{"frame": 1, "vx": -back_speed}, {"frame": back_frames + 1, "vx": 0}]}


func dash_commands() -> void:
	command("66", "move", {"motion": "66", "state": "dash_f"})
	command("44", "move", {"motion": "44", "state": "dash_b"})


## 出招时伸出的手脚也是受击区域（比攻击判定略短），这样才有"拆招"。
static func limb(box: Array) -> Array:
	return [box[0] - 5, box[1], int(box[2] * 0.8), box[3]]


static func with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var d := base.duplicate()
	d.merge(extra, true)
	return d
