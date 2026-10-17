class_name AnimData
extends RefCounted
## 一个动画的时序与逐帧判定盒（相当于 MUGEN AIR 里的一个 Action：每帧的时长 + Clsn1 / Clsn2）。
## 判定盒为逻辑单位，相对脚底、面朝右的 [x, y, w, h]。
## 每帧还有一个阶段标记（导入器写在帧条目第 4 项，没写时按攻击盒推断），AnimClock 用它把动画对齐到招式帧数：
##   s 发生 / a 持续（有攻击判定）/ r 收招或受击恢复 / f 浮空受击的下落段 / 空 = 不分段

enum Phase { NONE, STARTUP, ACTIVE, RECOVERY, FALL }
const PHASE_CODES := {"": Phase.NONE, "s": Phase.STARTUP, "a": Phase.ACTIVE, "r": Phase.RECOVERY, "f": Phase.FALL}

var loop := false
var ends: Array[int] = [] ## 每帧结束时的累计时长
var hurt: Array = [] ## 每帧的受击盒 Array[PackedInt32Array]（可能为空 = 沿用默认身体盒）
var hit: Array = [] ## 每帧的攻击盒（只有持续帧有）
var phase: Array[int] = [] ## 每帧的阶段（Phase）

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
		a.phase.append(PHASE_CODES.get(str(f[3]) if f.size() > 3 else "", Phase.NONE))
	if not a.phase.has(Phase.ACTIVE) and not a.phase.has(Phase.STARTUP):
		a._infer_attack_phases()
	return a


## 没有阶段标记的攻击动画（如生成器的五帧动画）：第一个攻击盒之前是发生，有攻击盒的是持续，之后是收招。
func _infer_attack_phases() -> void:
	var first := -1
	var last := -1
	for i in hit.size():
		if not hit[i].is_empty():
			first = i if first < 0 else first
			last = i
	if first < 0:
		return
	for i in phase.size():
		if phase[i] == Phase.NONE:
			phase[i] = Phase.STARTUP if i < first else (Phase.ACTIVE if i <= last else Phase.RECOVERY)


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


func length() -> int:
	return ends[-1] if not ends.is_empty() else 0


## 第 i 帧开始的时刻。
func start_of(i: int) -> int:
	return ends[i - 1] if i > 0 else 0


## 某个阶段的时间段 [开始时刻, 时长]；没有这个阶段时时长为 0。
func segment(p: int) -> Vector2i:
	var first := phase.find(p)
	if first < 0:
		return Vector2i(0, 0)
	var last := phase.rfind(p)
	return Vector2i(start_of(first), ends[last] - start_of(first))


func has_phase(p: int) -> bool:
	return phase.has(p)


## 按时长播放：第 t 帧对应的动画帧（非循环动画停在最后一帧）。
func index_at_time(t: int) -> int:
	var total := ends[-1]
	t = t % total if loop else mini(t, total - 1)
	for i in ends.size():
		if t < ends[i]:
			return i
	return ends.size() - 1
