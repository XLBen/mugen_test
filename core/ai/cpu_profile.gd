class_name CpuProfile
extends RefCounted
## 电脑难度 1–8 级：在 1 / 4 / 8 级三组锚点之间线性插值。
##   reaction 看到对手动作到做出反应的延迟帧数（模拟人的反应时间）
##   think    进攻决策的间隔帧数
##   block / anti_air / punish / confirm / tech / throw / drive / super  各种行为的概率
##   aggro    中立时主动进攻的倾向

const ANCHORS := {
	1: {"reaction": 30, "think": 22, "block": 0.15, "anti_air": 0.05, "punish": 0.1, "confirm": 0.2, "tech": 0.0,
		"throw": 0.04, "drive": 0.0, "super": 0.0, "aggro": 0.35},
	4: {"reaction": 18, "think": 12, "block": 0.55, "anti_air": 0.4, "punish": 0.6, "confirm": 0.6, "tech": 0.3,
		"throw": 0.08, "drive": 0.08, "super": 0.5, "aggro": 0.5},
	8: {"reaction": 12, "think": 5, "block": 0.92, "anti_air": 0.85, "punish": 0.95, "confirm": 0.95, "tech": 0.6,
		"throw": 0.12, "drive": 0.2, "super": 0.9, "aggro": 0.6},
}


static func for_level(level: int) -> Dictionary:
	level = clampi(level, 1, 8)
	var lo := 1 if level <= 4 else 4
	var hi := 4 if level <= 4 else 8
	var t := float(level - lo) / (hi - lo)
	var out := {}
	for k: String in ANCHORS[1]:
		var v := lerpf(ANCHORS[lo][k], ANCHORS[hi][k], t)
		out[k] = roundi(v) if k in ["reaction", "think"] else v
	return out
