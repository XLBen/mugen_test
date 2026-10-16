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


ANIMS = {
	"idle": dict(loop=True, frames=idle),
	"walk_f": dict(loop=True, frames=lambda ch: _walk(ch, True)),
	"walk_b": dict(loop=True, frames=lambda ch: _walk(ch, False)),
	"crouch": dict(loop=False, frames=crouch),
	"prejump": dict(loop=False, frames=lambda ch: [(prejump_pose(ch), 1)]),
	"jump": dict(loop=False, frames=jump),  # 0 上升 / 1 顶点 / 2 下落，由显示层按 vy 选择
	"land": dict(loop=False, frames=lambda ch: [(prejump_pose(ch), 1)]),
}
