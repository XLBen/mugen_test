class_name Gauges
## 通用资源槽。每名角色持有若干整数槽（存档/哈希的一部分），槽的规则由规则模块定义：
##   上限 / 分格 / 开局值 / 自然回复 / 使用后回复停顿 / 耗尽后的 Burnout。
## 招式在数据里声明消耗 {"cost": {"drive": 20000}}，获取通过 gain() 在命中、出招等事件里发生。

## 街霸风：超杀槽 3 格 + Drive 槽 6 格。其他规则模块（GG 的 Tension/Burst 等）可以换一组定义。
const DEFS := [
	{"name": "super", "max": 3000, "segments": 3, "start": 0, "regen": 0, "delay": 0, "keep_between_rounds": true},
	{"name": "drive", "max": 60000, "segments": 6, "start": 60000, "regen": 40, "delay": 90,
		"burnout": true, "burnout_regen": 70},
]

const SUPER := 0
const DRIVE := 1


static func index(gauge_name: String) -> int:
	for i in DEFS.size():
		if DEFS[i].name == gauge_name:
			return i
	assert(false, "unknown gauge " + gauge_name)
	return -1


static func reset(f: Fighter, keep := false) -> void:
	if f.gauges.size() != DEFS.size():
		f.gauges.resize(DEFS.size())
		f.gauge_delay.resize(DEFS.size())
		keep = false
	for i in DEFS.size():
		if not (keep and DEFS[i].get("keep_between_rounds", false)):
			f.gauges[i] = DEFS[i].start
		f.gauge_delay[i] = 0
	f.burnout = 0


static func value(f: Fighter, i: int) -> int:
	return f.gauges[i]


static func gain(f: Fighter, i: int, amount: int) -> void:
	if amount == 0:
		return
	var d: Dictionary = DEFS[i]
	f.gauges[i] = clampi(f.gauges[i] + amount, 0, d.max)
	if amount < 0 and f.gauges[i] == 0 and d.get("burnout", false):
		f.burnout = 1


## 被动扣减（如防御被削 Drive）：和主动消耗一样触发回复停顿。
static func drain(f: Fighter, i: int, amount: int) -> void:
	gain(f, i, -amount)
	f.gauge_delay[i] = DEFS[i].delay


## cost: {gauge_name: amount}。Burnout 中不能使用会导致 Burnout 的槽。
static func can_afford(f: Fighter, cost: Dictionary) -> bool:
	for gauge_name: String in cost:
		var i := index(gauge_name)
		if DEFS[i].get("burnout", false) and f.burnout != 0:
			return false
		if f.gauges[i] < cost[gauge_name]:
			return false
	return true


static func spend(f: Fighter, cost: Dictionary) -> void:
	for gauge_name: String in cost:
		var i := index(gauge_name)
		gain(f, i, -cost[gauge_name])
		f.gauge_delay[i] = DEFS[i].delay


## 每帧回复。Burnout 中按 burnout_regen 回复，回满即解除。
static func tick(f: Fighter) -> void:
	for i in DEFS.size():
		var d: Dictionary = DEFS[i]
		if f.gauge_delay[i] > 0:
			f.gauge_delay[i] -= 1
			continue
		var regen: int = d.burnout_regen if d.get("burnout", false) and f.burnout != 0 else d.regen
		f.gauges[i] = mini(f.gauges[i] + regen, d.max)
		if f.burnout != 0 and d.get("burnout", false) and f.gauges[i] == d.max:
			f.burnout = 0
