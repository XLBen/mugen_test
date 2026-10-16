class_name ProjectileDef
extends RefCounted
## 飞行道具的静态数据。

var name := ""
var speed := 600
var box: PackedInt32Array
var hit: HitDef
var hits := 1
var lifetime := 180
var anim := "fireball"


static func build(p_name: String, d: Dictionary) -> ProjectileDef:
	var p := ProjectileDef.new()
	p.name = p_name
	p.speed = d.get("speed", p.speed)
	p.box = Box.from_px(d.box)
	p.hit = HitDef.from_dict(d.hit)
	p.hits = d.get("hits", p.hits)
	p.lifetime = d.get("lifetime", p.lifetime)
	p.anim = d.get("anim", p.anim)
	return p
