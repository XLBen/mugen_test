class_name AnimData
extends RefCounted
## 一个动画的时序与逐帧判定盒（相当于 MUGEN AIR 里的一个 Action：每帧的时长 + Clsn1 / Clsn2）。
## 判定盒为逻辑单位，相对脚底、面朝右的 [x, y, w, h]。

var loop := false
var ends: Array[int] = [] ## 每帧结束时的累计时长
var hurt: Array = [] ## 每帧的受击盒 Array[PackedInt32Array]（可能为空 = 沿用默认身体盒）
var hit: Array = [] ## 每帧的攻击盒（只有持续帧有）

static var _cache := {} ## anims.json 路径 -> {name: AnimData}


## 读取精灵目录下 anims.json 的时序与判定盒（不读贴图，仿真层可用）。
static func load_library(dir: String) -> Dictionary:
	var path := dir.path_join("anims.json")
	if _cache.has(path):
		return _cache[path]
	var lib := {}
	var text := FileAccess.get_file_as_string(path)
	if not text.is_empty():
		var meta: Dictionary = JSON.parse_string(text)
		for anim_name: String in meta.anims:
			lib[anim_name] = from_meta(meta.anims[anim_name])
	_cache[path] = lib
	return lib


static func from_meta(m: Dictionary) -> AnimData:
	var a := AnimData.new()
	a.loop = m.get("loop", false)
	var t := 0
	for f: Array in m.frames:
		t += int(f[1])
		a.ends.append(t)
		var boxes: Dictionary = f[2] if f.size() > 2 else {}
		a.hurt.append(_convert(boxes.get("hurt", [])))
		a.hit.append(_convert(boxes.get("hit", [])))
	return a


static func _convert(list: Array) -> Array:
	var out := []
	for b: Array in list:
		out.append(Box.from_px([int(b[0]), int(b[1]), int(b[2]), int(b[3])]))
	return out


func count() -> int:
	return ends.size()


func has_boxes() -> bool:
	for list: Array in hurt:
		if not list.is_empty():
			return true
	return false


## 按时长播放：第 t 帧对应的动画帧（非循环动画停在最后一帧）。
func index_at_time(t: int) -> int:
	var total := ends[-1]
	t = t % total if loop else mini(t, total - 1)
	for i in ends.size():
		if t < ends[i]:
			return i
	return ends.size() - 1
