"""姿势与动画。姿势 = 关节角度字典；动画 = (姿势, 持续帧数) 列表。

角度约定：
- 肢体（thigh/shin/uarm/farm）：0° = 竖直向下，正值朝前。
- 躯干 torso：0° = 竖直向上，正值前倾；head 相对躯干。
- grounded=True 时自动把最低的脚放到地面；空中姿势用 dy 控制骨盆高度。
- flow：头发/衣摆的飘动，负值 = 向下拖（上升时），正值 = 向上扬（下落时）。
"""

import math

BASE = dict(
	dx=0, dy=0, torso=6, head=-4,
	thigh_f=14, shin_f=-2, thigh_b=-16, shin_b=-12,
	uarm_f=30, farm_f=120, uarm_b=15, farm_b=105,
	grounded=True, flow=0.0, knife=70,
)

ANGLES = [k for k, v in BASE.items() if isinstance(v, (int, float)) and not isinstance(v, bool)]


def pose(ch, **overrides):
	p = dict(BASE)
	p.update(ch.get("stance", {}))
	p.update(overrides)
	return p


def lerp(a, b, t):
	out = dict(b)
	for k in ANGLES:
		out[k] = a[k] + (b[k] - a[k]) * t
	return out


def _offset(p, **deltas):
	q = dict(p)
	for k, d in deltas.items():
		q[k] = q[k] + d
	return q


def idle(ch):
	base = pose(ch)
	frames = []
	for i in range(6):
		s = math.sin(i / 6 * math.tau)
		frames.append((_offset(base, thigh_f=2 * s, shin_f=-2 * s, thigh_b=1.5 * s, shin_b=-1.5 * s,
			farm_f=3 * s, farm_b=3 * s, flow=0.3 * s), 8))
	return frames


def _walk(ch, forward):
	base = pose(ch, torso=pose(ch)["torso"] + (3 if forward else -3), flow=0.4 if forward else -0.2)
	frames = []
	for i in range(8):
		p = i / 8 * math.tau
		if not forward:
			p = -p
		a = math.sin(p)
		thigh_f = 2 + 22 * a
		thigh_b = 2 - 22 * a
		frames.append((_offset(base,
			thigh_f=thigh_f - base["thigh_f"], thigh_b=thigh_b - base["thigh_b"],
			shin_f=thigh_f - 6 - 26 * max(0.0, math.cos(p)) - base["shin_f"],
			shin_b=thigh_b - 6 - 26 * max(0.0, -math.cos(p)) - base["shin_b"],
			farm_f=4 * a, farm_b=-4 * a), 5))
	return frames


def crouch_pose(ch):
	return pose(ch, torso=22, head=-14, thigh_f=78, shin_f=-12, thigh_b=40, shin_b=-72,
		uarm_f=40, farm_f=135, uarm_b=30, farm_b=120)


def crouch(ch):
	return [(lerp(pose(ch), crouch_pose(ch), 0.55), 3), (crouch_pose(ch), 1)]


def prejump_pose(ch):
	return pose(ch, torso=14, thigh_f=45, shin_f=-20, thigh_b=20, shin_b=-40)


def jump(ch):
	return [
		(pose(ch, grounded=False, torso=4, thigh_f=50, shin_f=-30, thigh_b=-5, shin_b=-45,
			uarm_f=60, farm_f=150, uarm_b=-10, farm_b=40, flow=-1.0), 1),
		(pose(ch, grounded=False, torso=12, head=-8, thigh_f=85, shin_f=-20, thigh_b=55, shin_b=-55,
			uarm_f=45, farm_f=130, flow=0.0), 1),
		(pose(ch, grounded=False, torso=6, thigh_f=28, shin_f=4, thigh_b=-12, shin_b=-18,
			uarm_f=55, farm_f=100, uarm_b=-30, farm_b=10, flow=1.0), 1),
	]


def air_pose(ch, **kw):
	base = dict(grounded=False, torso=10, head=-6, thigh_f=70, shin_f=-20, thigh_b=40, shin_b=-50,
		uarm_f=45, farm_f=120, uarm_b=10, farm_b=90, flow=0.3)
	base.update(kw)
	return pose(ch, **base)


def attack(start, active, recover=None):
	"""攻击动画固定三帧：发生 / 持续 / 收招，显示层按状态阶段选帧。"""
	if recover is None:
		recover = lerp(active, start, 0.45)
	return [(start, 1), (active, 1), (recover, 1)]


def stand_attack(ch, start_kw, active_kw):
	return attack(pose(ch, **start_kw), pose(ch, **active_kw))


def crouch_attack(ch, start_kw, active_kw):
	c = crouch_pose(ch)
	return attack(dict(c, **start_kw), dict(c, **active_kw))


def air_attack(ch, start_kw, active_kw):
	return attack(air_pose(ch, **start_kw), air_pose(ch, **active_kw))


KICK_STAND = dict(thigh_b=-4, shin_b=-6)

NORMALS = {
	"5lp": lambda ch: stand_attack(ch, dict(uarm_f=40, farm_f=150, torso=8),
		dict(uarm_f=86, farm_f=90, torso=12, knife=80)),
	"5mp": lambda ch: stand_attack(ch, dict(uarm_f=20, farm_f=140, torso=4, uarm_b=10),
		dict(uarm_f=84, farm_f=86, torso=16, uarm_b=-35, farm_b=60, thigh_f=25, knife=80)),
	"5hp": lambda ch: stand_attack(ch, dict(uarm_f=-25, farm_f=60, torso=-6, thigh_f=8),
		dict(uarm_f=82, farm_f=84, torso=24, uarm_b=-40, farm_b=40, thigh_f=36, shin_f=2, thigh_b=-32, knife=80)),
	"5lk": lambda ch: stand_attack(ch, dict(KICK_STAND, thigh_f=45, shin_f=-10, torso=0),
		dict(KICK_STAND, thigh_f=62, shin_f=78, torso=-6)),
	"5mk": lambda ch: stand_attack(ch, dict(KICK_STAND, thigh_f=60, shin_f=0, torso=-4),
		dict(KICK_STAND, thigh_f=84, shin_f=92, torso=-14, uarm_b=-20)),
	"5hk": lambda ch: stand_attack(ch, dict(KICK_STAND, thigh_f=70, shin_f=10, torso=-10),
		dict(KICK_STAND, thigh_f=112, shin_f=118, torso=-28, uarm_f=10, farm_f=60, uarm_b=-40, farm_b=0)),
	"2lp": lambda ch: crouch_attack(ch, dict(uarm_f=40, farm_f=140), dict(uarm_f=86, farm_f=90, knife=80)),
	"2mp": lambda ch: crouch_attack(ch, dict(uarm_f=20, farm_f=130), dict(uarm_f=80, farm_f=84, torso=30, knife=80)),
	"2hp": lambda ch: attack(dict(crouch_pose(ch), uarm_f=10, farm_f=40),
		pose(ch, torso=4, thigh_f=30, shin_f=-10, thigh_b=10, shin_b=-30, uarm_f=170, farm_f=176, uarm_b=-20)),
	"2lk": lambda ch: crouch_attack(ch, dict(thigh_f=70, shin_f=20), dict(thigh_f=80, shin_f=94, torso=12)),
	"2mk": lambda ch: crouch_attack(ch, dict(thigh_f=72, shin_f=30), dict(thigh_f=86, shin_f=96, torso=30)),
	"2hk": lambda ch: crouch_attack(ch, dict(thigh_f=60, shin_f=20, torso=30),
		dict(thigh_f=90, shin_f=93, torso=42, thigh_b=60, shin_b=-80, uarm_b=60, farm_b=20)),
	"j_lp": lambda ch: air_attack(ch, dict(uarm_f=40, farm_f=120), dict(uarm_f=72, farm_f=62)),
	"j_mp": lambda ch: air_attack(ch, dict(uarm_f=20, farm_f=110), dict(uarm_f=80, farm_f=74, torso=16)),
	"j_hp": lambda ch: air_attack(ch, dict(uarm_f=150, farm_f=170, torso=0), dict(uarm_f=62, farm_f=38, torso=24)),
	"j_lk": lambda ch: air_attack(ch, dict(thigh_f=60, shin_f=-40), dict(thigh_f=72, shin_f=40)),
	"j_mk": lambda ch: air_attack(ch, dict(thigh_f=60, shin_f=-40), dict(thigh_f=78, shin_f=66, torso=-4)),
	"j_hk": lambda ch: air_attack(ch, dict(thigh_f=50, shin_f=-50, torso=0),
		dict(thigh_f=66, shin_f=76, thigh_b=-10, shin_b=-30, torso=-12)),
}


def specials(ch):
	return {
		"fireball": attack(
			pose(ch, torso=-6, uarm_f=-20, farm_f=40, uarm_b=-30, farm_b=30, thigh_f=20),
			pose(ch, torso=18, uarm_f=86, farm_f=90, uarm_b=80, farm_b=88, thigh_f=34, shin_f=0, thigh_b=-30)),
		"dp": attack(
			dict(crouch_pose(ch), uarm_f=20, farm_f=40),
			pose(ch, grounded=False, torso=6, uarm_f=168, farm_f=176, uarm_b=-30, farm_b=0,
				thigh_f=30, shin_f=-40, thigh_b=-10, shin_b=-20, flow=-1.0),
			pose(ch, grounded=False, torso=-4, uarm_f=140, farm_f=160, thigh_f=40, shin_f=-30,
				thigh_b=10, shin_b=-40, flow=0.8)),
		"rush": attack(
			pose(ch, torso=-12, thigh_f=30, uarm_f=10, farm_f=60),
			pose(ch, torso=-22, thigh_f=96, shin_f=96, thigh_b=-24, shin_b=-40, uarm_f=-10, farm_f=40,
				uarm_b=-40, farm_b=0, flow=0.6)),
		"throw": attack(
			pose(ch, torso=14, uarm_f=60, farm_f=80, uarm_b=50, farm_b=70),
			pose(ch, torso=20, uarm_f=82, farm_f=90, uarm_b=76, farm_b=86, thigh_f=28)),
	}


def throw_hit(ch):
	hold = pose(ch, torso=14, uarm_f=80, farm_f=100, uarm_b=70, farm_b=95, thigh_f=24)
	toss = pose(ch, torso=26, uarm_f=130, farm_f=150, uarm_b=110, farm_b=140, thigh_f=36, shin_f=0, thigh_b=-30)
	return [(hold, 30), (toss, 15)]


def hurt(ch):
	block_arms = dict(uarm_f=25, farm_f=165, uarm_b=35, farm_b=168, head=-10)
	return {
		"hit_stand": [(pose(ch, torso=-16, head=-22, uarm_f=-25, farm_f=15, uarm_b=-40, farm_b=0, flow=0.5), 1)],
		"hit_crouch": [(dict(crouch_pose(ch), torso=2, head=-24, uarm_f=-10, farm_f=30), 1)],
		"block_stand": [(pose(ch, torso=2, **block_arms), 1)],
		"block_crouch": [(dict(crouch_pose(ch), **block_arms), 1)],
		"hit_air": [(pose(ch, grounded=False, torso=-50, head=-20, thigh_f=40, shin_f=60, thigh_b=10, shin_b=30,
			uarm_f=-140, farm_f=-120, uarm_b=-160, farm_b=-140, flow=1.0), 1)],
		"knockdown": [(pose(ch, torso=-92, head=-4, thigh_f=94, shin_f=90, thigh_b=88, shin_b=92,
			uarm_f=-60, farm_f=-80, uarm_b=-100, farm_b=-90, flow=0.0), 1)],
		"wakeup": [
			(pose(ch, torso=-40, head=-10, thigh_f=95, shin_f=10, thigh_b=80, shin_b=-40, uarm_f=-30, farm_f=0), 9),
			(crouch_pose(ch), 9),
		],
	}


ANIMS = {
	"idle": dict(loop=True, frames=idle),
	"walk_f": dict(loop=True, frames=lambda ch: _walk(ch, True)),
	"walk_b": dict(loop=True, frames=lambda ch: _walk(ch, False)),
	"crouch": dict(loop=False, frames=crouch),
	"prejump": dict(loop=False, frames=lambda ch: [(prejump_pose(ch), 1)]),
	"jump": dict(loop=False, frames=jump),  # 0 上升 / 1 顶点 / 2 下落，由显示层按 vy 选择
	"land": dict(loop=False, frames=lambda ch: [(prejump_pose(ch), 1)]),
	"throw_hit": dict(loop=False, frames=throw_hit),
}
for _name, _fn in NORMALS.items():
	ANIMS[_name] = dict(loop=False, frames=_fn)
for _name in ("fireball", "dp", "rush", "throw"):
	ANIMS[_name] = dict(loop=False, frames=lambda ch, n=_name: specials(ch)[n])
for _name in ("hit_stand", "hit_crouch", "block_stand", "block_crouch", "hit_air", "knockdown", "wakeup"):
	ANIMS[_name] = dict(loop=False, frames=lambda ch, n=_name: hurt(ch)[n])
