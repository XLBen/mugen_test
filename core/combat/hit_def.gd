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
var strength := 0 ## 0 轻 / 1 中 / 2 重（轻攻击起手的连段有额外补正）
var juggle_start := 1 ## 把站立/跳跃中的对手打成浮空时，对方的追打计数初值
var juggle_limit := 0 ## 对手追打计数 <= 此值时才能打中浮空受击中的对手
var juggle_add := 1 ## 追打命中后对方计数增加
var counter_effect := -1 ## 打康时替换的命中效果（-1 = 不替换）
var meter := -1 ## 命中时攻击方获得的超杀槽（-1 = 按强度取默认值，被防减半）
var drive := -1 ## 命中时攻击方获得 / 被防时防御方损失的 Drive（-1 = 按强度取默认值）
var min_scale := 10 ## 连段补正的下限（超杀有保底）


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
	h.juggle_start = d.get("juggle_start", h.juggle_start)
	h.juggle_limit = d.get("juggle_limit", h.juggle_limit)
	h.juggle_add = d.get("juggle_add", h.juggle_add)
	h.meter = d.get("meter", [20, 40, 60][h.strength])
	h.drive = d.get("drive", [500, 1000, 1500][h.strength])
	h.min_scale = d.get("min_scale", h.min_scale)
	if d.has("counter_effect"):
		h.counter_effect = EFFECT_NAMES[d.counter_effect]
	return h
