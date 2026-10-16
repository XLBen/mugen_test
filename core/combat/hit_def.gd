class_name HitDef
extends RefCounted
## 一次攻击命中时的全部参数（静态数据）。时间单位为帧，速度为逻辑单位/帧。

enum Guard { MID, LOW, HIGH, UNBLOCKABLE }
enum Effect { NORMAL, KNOCKDOWN, LAUNCH }

const GUARD_NAMES := {"mid": Guard.MID, "low": Guard.LOW, "high": Guard.HIGH, "unblockable": Guard.UNBLOCKABLE}
const EFFECT_NAMES := {"normal": Effect.NORMAL, "knockdown": Effect.KNOCKDOWN, "launch": Effect.LAUNCH}

var damage := 0
var chip := 0
var hitstun := 12
var blockstun := 8
var hitstop := 8
var guard: int = Guard.MID
var effect: int = Effect.NORMAL
var push := 500 ## 地面被打时的击退初速度
var block_push := 600
var air_vx := 350 ## 空中被打 / 浮空时的水平速度（远离攻击方）
var air_vy := 900
var strength := 0 ## 0 轻 / 1 中 / 2 重，表现层选受击动画用


static func from_dict(d: Dictionary) -> HitDef:
	var h := HitDef.new()
	h.damage = d.get("damage", h.damage)
	h.chip = d.get("chip", h.chip)
	h.hitstun = d.get("hitstun", h.hitstun)
	h.blockstun = d.get("blockstun", h.blockstun)
	h.hitstop = d.get("hitstop", h.hitstop)
	h.guard = GUARD_NAMES[d.get("guard", "mid")]
	h.effect = EFFECT_NAMES[d.get("effect", "normal")]
	h.push = d.get("push", h.push)
	h.block_push = d.get("block_push", h.block_push)
	h.air_vx = d.get("air_vx", h.air_vx)
	h.air_vy = d.get("air_vy", h.air_vy)
	h.strength = d.get("strength", h.strength)
	return h
