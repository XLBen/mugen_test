class_name Projectile
extends RefCounted
## 飞行道具的运行时状态（全部整数，进入存档与哈希）。

var owner := 0 ## 发射者的玩家索引
var def_id := 0 ## 发射者 Moveset.projectiles 中的索引
var x := 0
var y := 0
var vx := 0
var facing := 1
var hits := 1 ## 剩余耐久
var age := 0


func save_state() -> Dictionary:
	return {"owner": owner, "def_id": def_id, "x": x, "y": y, "vx": vx, "facing": facing, "hits": hits, "age": age}


static func from_state(s: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.owner = s.owner
	p.def_id = s.def_id
	p.x = s.x
	p.y = s.y
	p.vx = s.vx
	p.facing = s.facing
	p.hits = s.hits
	p.age = s.age
	return p


func hash_values() -> Array[int]:
	return [owner, def_id, x, y, vx, facing, hits, age]
