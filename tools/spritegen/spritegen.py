#!/usr/bin/env python3
"""程序化像素角色生成器（开发期工具，只依赖 Pillow）。

用 2D 骨骼 + 部件多边形拼出角色，每个部件单独做赛璐璐阴影与有色描边，
画风参考 2D 格斗游戏的高精度像素精灵（修长比例、深色有色描边、三阶阴影）。
角色均为原创。

用法：
    python3 tools/spritegen/spritegen.py            # 生成全部角色
    python3 tools/spritegen/spritegen.py kagura     # 只生成一个
    python3 tools/spritegen/spritegen.py --preview out.png

输出：characters/<id>/sprites/pal<N>/<anim>_<nn>.png 与 characters/<id>/sprites/anims.json
"""

from __future__ import annotations

import colorsys
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

from characters import CHARACTERS
from poses import anims_for

ROOT = Path(__file__).resolve().parents[2]

CANVAS_W, CANVAS_H = 192, 160
ANCHOR = (96, 152)  # 脚底中心
DISPLAY_SCALE = 2

# 光源在角色前上方（角色面朝右）：阴影落在后下方，高光在前上方边缘。
SHADOW_DIR = (-1, 1)
HIGHLIGHT_DIR = (1, -1)


# ---------------------------------------------------------------- 颜色

def _adjust(rgb, value=1.0, sat=1.0, hue_shift=0.0):
	h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
	h = (h + hue_shift) % 1.0
	s = min(1.0, s * sat)
	v = min(1.0, v * value)
	return tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h, s, v))


def ramp(base, depth=1.0):
	"""由底色推出 (底色, 暗部, 高光, 描边)。暗部偏冷、描边是加深的有色线而不是纯黑。"""
	base = _adjust(base, value=depth)
	shadow = _adjust(base, value=0.72, sat=1.15, hue_shift=0.02)
	light = _adjust(base, value=1.12, sat=0.85)
	line = _adjust(base, value=0.32, sat=1.3, hue_shift=0.03)
	if max(line) > 70:
		line = _adjust(line, value=70 / max(line))
	return base, shadow, light, line


# ---------------------------------------------------------------- 几何

def v_add(a, b):
	return (a[0] + b[0], a[1] + b[1])


def v_mul(a, k):
	return (a[0] * k, a[1] * k)


def limb_dir(deg):
	"""肢体方向：0° = 竖直向下，正值朝前（+x）。"""
	r = math.radians(deg)
	return (math.sin(r), math.cos(r))


def up_dir(deg):
	"""躯干方向：0° = 竖直向上，正值前倾。"""
	r = math.radians(deg)
	return (math.sin(r), -math.cos(r))


def perp(d):
	return (-d[1], d[0])


class Layer:
	"""一个部件的遮罩。画完后统一着色、描边、合成。"""

	def __init__(self, size=None):
		self.mask = Image.new("L", size or (CANVAS_W, CANVAS_H), 0)
		self.draw = ImageDraw.Draw(self.mask)

	def poly(self, pts):
		self.draw.polygon([(round(x), round(y)) for x, y in pts], fill=255)

	def circle(self, c, r):
		self.draw.ellipse([round(c[0] - r), round(c[1] - r), round(c[0] + r), round(c[1] + r)], fill=255)

	def ellipse(self, c, rx, ry):
		self.draw.ellipse([round(c[0] - rx), round(c[1] - ry), round(c[0] + rx), round(c[1] + ry)], fill=255)

	def capsule(self, a, b, wa, wb):
		d = (b[0] - a[0], b[1] - a[1])
		length = math.hypot(*d) or 1.0
		n = perp((d[0] / length, d[1] / length))
		self.poly([
			v_add(a, v_mul(n, wa / 2)), v_add(b, v_mul(n, wb / 2)),
			v_add(b, v_mul(n, -wb / 2)), v_add(a, v_mul(n, -wa / 2)),
		])
		self.circle(a, wa / 2 - 0.3)
		self.circle(b, wb / 2 - 0.3)

	def chain(self, pts, w0, w1):
		"""沿折线画逐渐变细的带子（头发、围巾、衣摆）。"""
		n = len(pts) - 1
		for i in range(n):
			wa = w0 + (w1 - w0) * i / n
			wb = w0 + (w1 - w0) * (i + 1) / n
			self.capsule(pts[i], pts[i + 1], max(wa, 1.2), max(wb, 1.2))


def _shift(mask, d, k):
	"""out(p) = mask(p + d*k)"""
	return ImageChops.offset(mask, -d[0] * k, -d[1] * k)


def shade(layer: Layer, colors, shadow_k=2, highlight=True):
	base, shadow, light, line = colors
	m = layer.mask.point(lambda v: 255 if v > 127 else 0)
	img = Image.new("RGBA", m.size, (0, 0, 0, 0))
	img.paste(base + (255,), (0, 0), m)
	if shadow_k > 0:
		img.paste(shadow + (255,), (0, 0), ImageChops.subtract(m, _shift(m, SHADOW_DIR, shadow_k)))
	inner = m.filter(ImageFilter.MinFilter(3))
	if highlight:
		img.paste(light + (255,), (0, 0), ImageChops.subtract(inner, _shift(inner, HIGHLIGHT_DIR, 1)))
	img.paste(line + (255,), (0, 0), ImageChops.subtract(m, inner))
	return img


# ---------------------------------------------------------------- 骨骼

class Skeleton:
	def __init__(self, body, pose):
		self.body = body
		self.pose = pose
		b = body
		leg = b["thigh"] + b["shin"] + 2
		pelvis = (ANCHOR[0] + pose["dx"], ANCHOR[1] - leg - pose["dy"])
		self.lean = pose["torso"]
		up = up_dir(self.lean)
		self.up = up
		self.pelvis = pelvis
		self.hip_f = v_add(pelvis, (2, 0))
		self.hip_b = v_add(pelvis, (-2, 0))
		self.knee_f = v_add(self.hip_f, v_mul(limb_dir(pose["thigh_f"]), b["thigh"]))
		self.knee_b = v_add(self.hip_b, v_mul(limb_dir(pose["thigh_b"]), b["thigh"]))
		self.ankle_f = v_add(self.knee_f, v_mul(limb_dir(pose["shin_f"]), b["shin"]))
		self.ankle_b = v_add(self.knee_b, v_mul(limb_dir(pose["shin_b"]), b["shin"]))
		self.neck = v_add(pelvis, v_mul(up, b["torso"]))
		shoulder = v_add(pelvis, v_mul(up, b["torso"] - 3))
		self.shoulder_f = v_add(shoulder, (2, 0))
		self.shoulder_b = v_add(shoulder, (-3, 1))
		self.elbow_f = v_add(self.shoulder_f, v_mul(limb_dir(pose["uarm_f"]), b["uarm"]))
		self.elbow_b = v_add(self.shoulder_b, v_mul(limb_dir(pose["uarm_b"]), b["uarm"]))
		self.wrist_f = v_add(self.elbow_f, v_mul(limb_dir(pose["farm_f"]), b["farm"]))
		self.wrist_b = v_add(self.elbow_b, v_mul(limb_dir(pose["farm_b"]), b["farm"]))
		head_up = up_dir(self.lean + pose["head"])
		self.head_up = head_up
		self.head = v_add(self.neck, v_mul(head_up, b["head_ry"] + 1))

		if pose["grounded"]:
			lowest = max(self.ankle_f[1], self.ankle_b[1]) + 2
			self._offset(0, ANCHOR[1] - lowest)

	def _offset(self, dx, dy):
		for name, value in list(vars(self).items()):
			if isinstance(value, tuple) and name not in ("up", "head_up"):
				setattr(self, name, (value[0] + dx, value[1] + dy))

	def torso_point(self, h, side):
		"""躯干轴上高度 h 处、偏向前(side>0)/后(side<0) 的点。"""
		n = (math.cos(math.radians(self.lean)), math.sin(math.radians(self.lean)))
		return v_add(v_add(self.pelvis, v_mul(self.up, h)), v_mul(n, side))

	def torso_outline(self, profile):
		front = [self.torso_point(h, wf) for h, wf, wb in profile]
		back = [self.torso_point(h, -wb) for h, wf, wb in reversed(profile)]
		return front + back


# ---------------------------------------------------------------- 部件

def foot_poly(ankle, length, angle=0):
	r = math.radians(angle)
	fwd = (math.cos(r), math.sin(r))
	return [
		v_add(ankle, (-2, -1)), v_add(ankle, (1.5, -1.5)),
		v_add(ankle, v_add(v_mul(fwd, length), (0, 0.5))),
		v_add(ankle, v_add(v_mul(fwd, length), (0, 2.5))),
		v_add(ankle, (-2.5, 2.5)),
	]


def draw_leg(sk, front, outfit, depth):
	b = sk.body
	hip, knee, ankle = (sk.hip_f, sk.knee_f, sk.ankle_f) if front else (sk.hip_b, sk.knee_b, sk.ankle_b)
	parts = []
	leg = Layer()
	leg.capsule(hip, knee, b["thigh_w"], b["knee_w"])
	leg.capsule(knee, ankle, b["knee_w"], b["ankle_w"])
	parts.append(shade(leg, ramp(outfit["legs"], depth)))
	if outfit.get("thigh_skin"):
		skin = Layer()
		mid = v_add(hip, v_mul((knee[0] - hip[0], knee[1] - hip[1]), 0.55))
		skin.capsule(hip, mid, b["thigh_w"], b["thigh_w"] - 0.5)
		parts.append(shade(skin, ramp(outfit["skin"], depth)))
	foot = Layer()
	foot.poly(foot_poly(ankle, b["foot"]))
	parts.append(shade(foot, ramp(outfit["shoes"], depth), shadow_k=1))
	return parts


def draw_arm(sk, front, outfit, depth, ch):
	b = sk.body
	sh, el, wr = (sk.shoulder_f, sk.elbow_f, sk.wrist_f) if front else (sk.shoulder_b, sk.elbow_b, sk.wrist_b)
	farm_deg = sk.pose["farm_f" if front else "farm_b"]
	parts = []
	arm = Layer()
	arm.capsule(sh, el, b["uarm_w"], b["elbow_w"])
	cuff = b.get("sleeve_flare", 0)
	arm.capsule(el, wr, b["elbow_w"], b["wrist_w"] + cuff)
	parts.append(shade(arm, ramp(outfit["sleeve"], depth)))
	if outfit.get("cuff"):
		c = Layer()
		d = limb_dir(farm_deg)
		c.capsule(v_add(wr, v_mul(d, -2)), wr, b["wrist_w"] + cuff, b["wrist_w"] + cuff)
		parts.append(shade(c, ramp(outfit["cuff"], depth), shadow_k=1))
	hand = Layer()
	hand.circle(v_add(wr, v_mul(limb_dir(farm_deg), 2)), b["hand_r"])
	parts.append(shade(hand, ramp(outfit.get("gloves", outfit["skin"]), depth), shadow_k=1, highlight=False))
	if front and ch.get("weapon") == "ribbon" and sk.pose.get("ribbon", 0) > 1:
		rib = Layer()
		d = limb_dir(farm_deg)
		n = perp(d)
		start = v_add(wr, v_mul(d, 2))
		length = sk.pose["ribbon"]
		pts = [v_add(v_add(start, v_mul(d, length * k / 4)), v_mul(n, math.sin(k * 1.4) * 2)) for k in range(5)]
		rib.chain(pts, 3.5, 2.2)
		parts.insert(0, shade(rib, ramp(outfit.get("ribbon", (200, 40, 60))), shadow_k=1))
	if front and ch.get("weapon") == "knife":
		blade = Layer()
		d = limb_dir(farm_deg + sk.pose.get("knife", 70))
		start = v_add(wr, v_mul(limb_dir(farm_deg), 3))
		blade.capsule(start, v_add(start, v_mul(d, 11)), 2.4, 1.2)
		parts.insert(0, shade(blade, ramp((205, 212, 225)), shadow_k=1))
	return parts


def draw_torso(sk, ch, outfit):
	b = sk.body
	t = b["torso"]
	profile = [
		(-2, b["hip_w"], b["hip_w"]),
		(t * 0.32, b["waist_w"], b["waist_w"]),
		(t * 0.62, b["chest_w"], b["waist_w"] + 0.5),
		(t * 0.86, b["shoulder_w"] * 0.55, b["shoulder_w"] * 0.5),
		(t - 1, b["shoulder_w"] * 0.45, b["shoulder_w"] * 0.45),
		(t + 1, 2.2, 2.2),
	]
	body = Layer()
	body.poly(sk.torso_outline(profile))
	parts = [shade(body, ramp(outfit["top"]), shadow_k=3)]
	if outfit.get("collar"):
		col = Layer()
		col.poly([sk.torso_point(t + 0.5, 3.5), sk.torso_point(t * 0.72, 1.5), sk.torso_point(t + 0.5, -2.5)])
		parts.append(shade(col, ramp(outfit["collar"]), shadow_k=1))
	if outfit.get("sash"):
		s = Layer()
		s.poly([sk.torso_point(t * 0.22, b["waist_w"] + 0.6), sk.torso_point(t * 0.4, b["waist_w"] + 0.4),
			sk.torso_point(t * 0.4, -b["waist_w"] - 0.4), sk.torso_point(t * 0.22, -b["waist_w"] - 0.6)])
		parts.append(shade(s, ramp(outfit["sash"]), shadow_k=1))
	neck = Layer()
	neck.capsule(sk.torso_point(t - 2, 0.5), v_add(sk.neck, v_mul(sk.up, 2)), 4, 3.5)
	return [shade(neck, ramp(outfit["skin"]), shadow_k=1, highlight=False)] + parts


def draw_skirt(sk, outfit, length, flare, flow):
	"""从腰到 length 比例处（0 = 臀，1 = 脚踝）的裙/衣摆，前后边缘跟随两腿。"""
	b = sk.body
	t = b["torso"]
	def along(hip, knee, ankle, k):
		if k <= 1:
			return v_add(hip, v_mul((knee[0] - hip[0], knee[1] - hip[1]), k))
		return v_add(knee, v_mul((ankle[0] - knee[0], ankle[1] - knee[1]), k - 1))
	hem_f = along(sk.hip_f, sk.knee_f, sk.ankle_f, length * 2)
	hem_b = along(sk.hip_b, sk.knee_b, sk.ankle_b, length * 2)
	front_x = max(hem_f[0], hem_b[0]) + flare
	back_x = min(hem_f[0], hem_b[0]) - flare - flow * 3
	hem_y = max(hem_f[1], hem_b[1])
	skirt = Layer()
	skirt.poly([
		sk.torso_point(t * 0.3, b["waist_w"] + 0.5),
		(front_x, hem_y - 1 - flow),
		((front_x + back_x) / 2, hem_y + 1),
		(back_x, hem_y - 1 + flow * 2),
		sk.torso_point(t * 0.3, -b["waist_w"] - 0.5),
	])
	return shade(skirt, ramp(outfit["skirt"]), shadow_k=3)


def draw_apron(sk, outfit):
	"""长裙前方的围裙：只覆盖裙子前半部分。"""
	b = sk.body
	t = b["torso"]
	knee_y = max(sk.knee_f[1], sk.knee_b[1])
	hem_y = knee_y + (max(sk.ankle_f[1], sk.ankle_b[1]) - knee_y) * 0.55
	front_x = max(sk.knee_f[0], sk.knee_b[0]) + 1
	apron = Layer()
	apron.poly([
		sk.torso_point(t * 0.32, b["waist_w"] + 0.6),
		sk.torso_point(t * 0.32, -1),
		(front_x - 9, hem_y + 1),
		(front_x + 1, hem_y),
	])
	return shade(apron, ramp(outfit["apron"]), shadow_k=2)


def draw_head(sk, ch, outfit):
	b = sk.body
	c = sk.head
	rx, ry = b["head_rx"], b["head_ry"]
	hu = sk.head_up
	n = (-hu[1], hu[0])  # 头部朝前方向
	head = Layer()
	head.ellipse(c, rx, ry)
	jaw = v_add(v_add(c, v_mul(hu, -ry - 0.5)), v_mul(n, rx * 0.45))
	head.poly([v_add(c, v_mul(n, -rx * 0.6)), v_add(c, v_mul(n, rx * 0.95)), jaw])
	img = shade(head, ramp(outfit["skin"]), shadow_k=2, highlight=False)
	# 眼睛：面朝方向一侧，两像素高；后方眼睛只露出一像素
	d = ImageDraw.Draw(img)
	eye = v_add(v_add(c, v_mul(n, rx * 0.55)), v_mul(hu, -1.0))
	ex, ey = round(eye[0]), round(eye[1])
	line = ramp(outfit["skin"])[3]
	d.rectangle([ex, ey - 1, ex + 1, ey + 1], fill=line + (255,))
	d.point((ex + 1, ey), fill=ch["eyes"] + (255,))
	d.point((ex - 4, ey), fill=line + (255,))
	mouth = v_add(v_add(c, v_mul(n, rx * 0.6)), v_mul(hu, -ry * 0.62))
	d.point((round(mouth[0]), round(mouth[1])), fill=_adjust(outfit["skin"], value=0.7) + (255,))
	return img


# ---------------------------------------------------------------- 头发

def hair_chain(start, angle, seg, count, sway, curl=0.0):
	pts = [start]
	a = angle
	for i in range(count):
		a += sway + curl
		pts.append(v_add(pts[-1], v_mul(limb_dir(a), seg)))
	return pts


def draw_hair_back(sk, ch, outfit):
	style = ch["hair"]
	c = sk.head
	hu = sk.head_up
	n = (-hu[1], hu[0])
	flow = sk.pose["flow"]
	layers = []
	hair = Layer()
	if style == "long":
		top = v_add(c, v_mul(hu, sk.body["head_ry"] * 0.6))
		start = v_add(top, v_mul(n, -4))
		pts = hair_chain(start, -38 - sk.lean, 11, 5, 5 - flow * 9, 0)
		hair.chain(pts, 13, 7)
		hair.ellipse(v_add(c, v_mul(n, -1.5)), sk.body["head_rx"] + 2, sk.body["head_ry"] + 1.5)
	elif style == "spiky":
		hair.ellipse(v_add(c, v_mul(n, -1.2)), sk.body["head_rx"] + 1.8, sk.body["head_ry"] + 1.2)
		for ang, ln in ((-150, 9), (-120, 10), (-95, 8), (-65, 7), (-170, 6)):
			a = ang - sk.lean - flow * 8
			base = v_add(c, v_mul(limb_dir(a), sk.body["head_rx"]))
			tip = v_add(c, v_mul(limb_dir(a), sk.body["head_rx"] + ln))
			side = v_mul(perp(limb_dir(a)), 3)
			hair.poly([v_add(base, side), tip, v_add(base, v_mul(side, -1))])
	elif style == "twintails":
		hair.ellipse(v_add(c, v_mul(n, -1.2)), sk.body["head_rx"] + 1.8, sk.body["head_ry"] + 1.3)
		root = v_add(v_add(c, v_mul(hu, 3)), v_mul(n, -6))
		pts = hair_chain(root, -40 - sk.lean, 9, 6, 2 - flow * 7, 1.0)
		hair.chain(pts, 9, 3)
	layers.append(shade(hair, ramp(outfit["hair"]), shadow_k=2))
	if style == "twintails":
		rib = Layer()
		root = v_add(v_add(c, v_mul(hu, 3)), v_mul(n, -6))
		rib.poly([v_add(root, (-3, -3)), v_add(root, (3, -1)), v_add(root, (-3, 2))])
		layers.append(shade(rib, ramp(outfit["ribbon"]), shadow_k=1))
	return layers


def draw_hair_front(sk, ch, outfit):
	style = ch["hair"]
	c = sk.head
	hu = sk.head_up
	n = (-hu[1], hu[0])
	flow = sk.pose["flow"]
	rx, ry = sk.body["head_rx"], sk.body["head_ry"]
	hair = Layer()
	# 刘海：头顶到眉毛，前缘锯齿状发束
	crown = v_add(c, v_mul(hu, ry + 1.5))
	pts = [v_add(crown, v_mul(n, -rx - 1)), v_add(crown, v_mul(n, rx * 0.4))]
	for i, k in enumerate((1.05, 0.8, 0.95, 0.55)):
		p = v_add(c, v_add(v_mul(n, rx * k), v_mul(hu, (1.5 - i * 1.1) if i % 2 == 0 else (2.5 - i * 0.8))))
		pts.append(p)
	pts.append(v_add(c, v_add(v_mul(n, rx * 0.15), v_mul(hu, 2.5))))
	pts.append(v_add(c, v_mul(n, -rx - 1)))
	hair.poly(pts)
	if style == "long":
		lock = hair_chain(v_add(c, v_mul(n, 1)), 5 - sk.lean, 6, 4, 1 - flow * 4)
		hair.chain(lock, 4, 2)
	elif style == "twintails":
		root = v_add(v_add(c, v_mul(hu, 3)), v_mul(n, -3))
		pts = hair_chain(root, -25 - sk.lean, 9, 6, 2.5 - flow * 7, 0.8)
		hair.chain(pts, 8, 3)
	layers = [shade(hair, ramp(outfit["hair"]), shadow_k=2)]
	if style == "twintails":
		rib = Layer()
		root = v_add(v_add(c, v_mul(hu, 3)), v_mul(n, -3))
		rib.poly([v_add(root, (-3, -3)), v_add(root, (3, -2)), v_add(root, (0, 3))])
		layers.append(shade(rib, ramp(outfit["ribbon"]), shadow_k=1))
	return layers


def draw_scarf(sk, outfit):
	flow = sk.pose["flow"]
	start = v_add(sk.neck, v_mul(sk.up, -1))
	pts = hair_chain(v_add(start, (-2, 0)), -70 - sk.lean, 8, 5, 4 - flow * 6, 0)
	s = Layer()
	s.chain(pts, 5, 3.5)
	s.capsule(v_add(start, (-3, 0)), v_add(start, (3, 0)), 5, 5)
	return shade(s, ramp(outfit["scarf"]), shadow_k=2)


def draw_coat_tail(sk, outfit, behind):
	flow = sk.pose["flow"]
	b = sk.body
	t = b["torso"]
	tail = Layer()
	waist_b = sk.torso_point(t * 0.3, -b["waist_w"] - 0.5)
	waist_f = sk.torso_point(t * 0.3, b["waist_w"] + 0.5)
	knee_y = max(sk.knee_f[1], sk.knee_b[1]) + 4
	if behind:
		hem = (min(sk.knee_b[0], sk.knee_f[0]) - 6 - flow * 4, knee_y + 2 - flow * 3)
		tail.poly([waist_f, waist_b, v_add(hem, (-3, -6)), hem, (sk.pelvis[0] + 1, knee_y)])
	else:
		hem = (sk.knee_f[0] + 2, knee_y - 2)
		tail.poly([waist_f, sk.torso_point(t * 0.3, 0), (sk.knee_f[0] - 3, knee_y), hem])
	return shade(tail, ramp(outfit["coat"], 0.9 if behind else 1.0), shadow_k=3)


# ---------------------------------------------------------------- 组装

def render(ch, outfit, pose):
	sk = Skeleton(ch["body"], pose)
	back = 0.82  # 远侧肢体压暗，制造前后层次
	layers = []
	layers += draw_hair_back(sk, ch, outfit)
	if ch.get("scarf"):
		layers.append(draw_scarf(sk, outfit))
	layers += draw_arm(sk, False, outfit, back, ch)
	if ch.get("coat"):
		layers.append(draw_coat_tail(sk, outfit, behind=True))
	layers += draw_leg(sk, False, outfit, back)
	if ch.get("skirt") == "long":
		layers.append(draw_skirt(sk, outfit, 0.92, 3, pose["flow"]))
	layers += draw_leg(sk, True, outfit, 1.0)
	layers += draw_torso(sk, ch, outfit)
	if ch.get("skirt") == "short":
		layers.append(draw_skirt(sk, outfit, 0.24, 4, pose["flow"]))
	if ch.get("skirt") == "long":
		layers.append(draw_apron(sk, outfit))
	if ch.get("coat"):
		layers.append(draw_coat_tail(sk, outfit, behind=False))
	layers.append(draw_head(sk, ch, outfit))
	layers += draw_hair_front(sk, ch, outfit)
	layers += draw_arm(sk, True, outfit, 1.0, ch)

	img = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
	for layer in layers:
		img = Image.alpha_composite(img, layer)
	return img


FX_SIZE = 40


def accent(outfit):
	for key in ("fx", "scarf", "ribbon", "collar"):
		if key in outfit:
			return outfit[key]
	return (120, 180, 255)


def render_fireball(outfit, i):
	"""能量球：拖尾 + 外层光晕 + 赛璐璐核心，三帧循环闪烁。面朝右，锚点在中心。"""
	c = (FX_SIZE / 2, FX_SIZE / 2)
	base = accent(outfit)
	glow = _adjust(base, value=1.35, sat=0.55)
	img = Image.new("RGBA", (FX_SIZE, FX_SIZE), (0, 0, 0, 0))
	tail = Layer((FX_SIZE, FX_SIZE))
	wobble = (0, 1.5, -1.5)[i % 3]
	tail.poly([(c[0] - 2, c[1] - 7), (c[0] - 18, c[1] - 3 + wobble), (c[0] - 15, c[1] + wobble),
		(c[0] - 18, c[1] + 4 + wobble), (c[0] - 2, c[1] + 7)])
	img = Image.alpha_composite(img, shade(tail, ramp(glow), shadow_k=0))
	halo = Layer((FX_SIZE, FX_SIZE))
	halo.circle(c, 10 + (i % 2))
	img = Image.alpha_composite(img, shade(halo, ramp(glow), shadow_k=0))
	core = Layer((FX_SIZE, FX_SIZE))
	core.circle((c[0] + 1, c[1]), 7)
	img = Image.alpha_composite(img, shade(core, ramp(base), shadow_k=2))
	d = ImageDraw.Draw(img)
	d.rectangle([c[0] + 2, c[1] - 4, c[0] + 4, c[1] - 2], fill=(255, 255, 255, 255))
	return img


def render_charm(outfit, i):
	"""纸符：象牙色长条纸片 + 有色符纹，三帧轻微翻转。"""
	size = 40
	img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	c = (size / 2, size / 2)
	tilt = (-12, 0, 12)[i % 3]
	r = math.radians(tilt)
	def rot(dx, dy):
		return (c[0] + dx * math.cos(r) - dy * math.sin(r), c[1] + dx * math.sin(r) + dy * math.cos(r))
	glow = Layer((size, size))
	glow.ellipse(c, 13, 15)
	img = Image.alpha_composite(img, shade(glow, ramp(_adjust(accent(outfit), value=1.4, sat=0.4)), shadow_k=0))
	paper = Layer((size, size))
	paper.poly([rot(-6, -11), rot(6, -11), rot(6, 11), rot(-6, 11)])
	img = Image.alpha_composite(img, shade(paper, ramp((240, 232, 210)), shadow_k=1))
	mark = Layer((size, size))
	mark.poly([rot(-2, -7), rot(2, -7), rot(2, 6), rot(-2, 6)])
	img = Image.alpha_composite(img, shade(mark, ramp(accent(outfit)), shadow_k=0, highlight=False))
	return img


def render_seal(outfit, i):
	"""地面符阵：扁平的环 + 内符纹，两帧明暗交替。锚点在底边中心。"""
	w, h = 64, 24
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	c = (w / 2, h - 7)
	base = accent(outfit)
	ring = Layer((w, h))
	ring.ellipse(c, 28, 6)
	img = Image.alpha_composite(img, shade(ring, ramp(_adjust(base, value=1.2 if i else 0.9)), shadow_k=0))
	inner = Layer((w, h))
	inner.ellipse(c, 20, 4)
	img = Image.alpha_composite(img, shade(inner, ramp((240, 232, 210)), shadow_k=0, highlight=False))
	core = Layer((w, h))
	core.ellipse(c, 9, 2)
	img = Image.alpha_composite(img, shade(core, ramp(base), shadow_k=0, highlight=False))
	return img


def render_storm(outfit, i):
	"""纸吹雪：旋转的光环 + 四散的纸片，四帧循环。"""
	size = 96
	img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	c = (size / 2, size / 2)
	base = accent(outfit)
	halo = Layer((size, size))
	halo.ellipse(c, 34, 40)
	img = Image.alpha_composite(img, shade(halo, ramp(_adjust(base, value=1.4, sat=0.35)), shadow_k=0))
	for k in range(9):
		a = math.radians(k * 40 + i * 22)
		rad = 12 + (k * 7) % 26
		pc = (c[0] + math.cos(a) * rad, c[1] + math.sin(a) * rad * 1.15)
		paper = Layer((size, size))
		d = (math.cos(a + 1.2) * 5, math.sin(a + 1.2) * 5)
		n = (-d[1] * 0.5, d[0] * 0.5)
		paper.poly([v_add(pc, v_add(d, n)), v_add(pc, v_add(d, v_mul(n, -1))),
			v_add(pc, v_add(v_mul(d, -1), v_mul(n, -1))), v_add(pc, v_add(v_mul(d, -1), n))])
		img = Image.alpha_composite(img, shade(paper, ramp((240, 232, 210) if k % 3 else base), shadow_k=1))
	return img


## 角色专属特效：名字 → (绘制函数, 帧数, 每帧时长, 锚点)。道具的 anim 名对应 fx_<名字>。
FX = {
	"mio": {
		"charm": (render_charm, 3, 4, (20, 20)),
		"seal": (render_seal, 2, 10, (32, 17)),
		"storm": (render_storm, 4, 3, (48, 48)),
	},
}


def generate(char_id, out_root=ROOT / "characters"):
	from boxes import frame_boxes  # boxes 依赖本模块的 Skeleton，延迟导入避免循环
	ch = CHARACTERS[char_id]
	sprite_dir = out_root / char_id / "sprites"
	anims_meta = {}
	for pal_index, outfit in enumerate(ch["palettes"]):
		pal_dir = sprite_dir / f"pal{pal_index}"
		pal_dir.mkdir(parents=True, exist_ok=True)
		for old in pal_dir.glob("*.png"):
			old.unlink()
		for anim_name, anim in anims_for(char_id, ch).items():
			frames = []
			poses = anim["frames"](ch)
			for i, (pose, duration) in enumerate(poses):
				name = f"{anim_name}_{i:02d}"
				render(ch, outfit, pose).save(pal_dir / f"{name}.png")
				frames.append([name, duration, frame_boxes(ch, pose, anim_name, i, len(poses))])
			anims_meta[anim_name] = {"loop": anim["loop"], "frames": frames}
		for fx_name, (fn, count, duration, anchor) in FX.get(char_id, {}).items():
			frames = []
			for i in range(count):
				name = f"fx_{fx_name}_{i:02d}"
				fn(outfit, i).save(pal_dir / f"{name}.png")
				frames.append([name, duration])
			anims_meta["fx_" + fx_name] = {"loop": True, "anchor": list(anchor), "frames": frames}
	meta = {
		"canvas": [CANVAS_W, CANVAS_H],
		"anchor": list(ANCHOR),
		"scale": DISPLAY_SCALE,
		"palettes": len(ch["palettes"]),
		"anims": anims_meta,
	}
	text = json.dumps(meta, indent="\t", ensure_ascii=False)
	# 帧列表压成一行，便于阅读 diff
	import re
	text = re.sub(r"\[\s+\"([^\"]+)\",\s+(\d+)\s+\]", r'["\1", \2]', text)
	# 每帧 [名字, 时长, {hurt, hit}] 压成一行
	text = re.sub(r"\[\s+\"([^\"]+)\",\s+(\d+),\s+(\{.*?\n\t+\})\s+\]",
		lambda m: '["%s", %s, %s]' % (m.group(1), m.group(2), json.dumps(json.loads(m.group(3)), separators=(",", ":"))),
		text, flags=re.S)
	(sprite_dir / "anims.json").write_text(text + "\n")
	return sprite_dir


def preview(path, scale=3):
	"""每个角色 × 配色一行：共用动画取第一帧，专属招式取持续帧。"""
	rows = []
	for cid, ch in CHARACTERS.items():
		for outfit in ch["palettes"]:
			row = []
			for name, anim in anims_for(cid, ch).items():
				frames = anim["frames"](ch)
				if name in ("idle", "walk_f", "crouch", "jump", "5hp", "5hk", "2hk", "hit_air", "knockdown") \
						or name not in ("walk_b", "prejump", "land") and len(frames) == 5 and name[0] not in "25j":
					row.append(render(ch, outfit, frames[2 if len(frames) == 5 else 0][0]))
			rows.append(row)
	cols = max(len(r) for r in rows)
	sheet = Image.new("RGBA", (cols * CANVAS_W, len(rows) * CANVAS_H), (70, 72, 82, 255))
	for y, row in enumerate(rows):
		for x, img in enumerate(row):
			sheet.alpha_composite(img, (x * CANVAS_W, y * CANVAS_H))
	sheet = sheet.resize((sheet.width * scale // 2, sheet.height * scale // 2), Image.NEAREST)
	sheet.save(path)


if __name__ == "__main__":
	args = sys.argv[1:]
	if args[:1] == ["--preview"]:
		preview(args[1])
	else:
		for cid in args or CHARACTERS:
			print("generated", generate(cid))
