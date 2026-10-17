"""从骨骼计算每一帧的判定盒（与 MUGEN 的 Clsn1 / Clsn2 同义）：

- hurt（受击盒，Clsn2）：身体（头 + 躯干）、两条腿各一个、伸出去的前臂一个。头发、衣摆、围巾不算。
- hit（攻击盒，Clsn1）：只在攻击动画的持续帧给出，覆盖出招的那一段肢体（前臂 + 手 + 刀 / 小腿 + 脚）。

输出坐标与游戏一致：像素，相对脚底锚点、面朝右，x 向前、y 向上，[x, y, w, h]。
"""

import math

from spritegen import ANCHOR, DISPLAY_SCALE, Skeleton, limb_dir, v_add, v_mul

# 招式 → 出招部位。普攻按名字推断（含 p 的是手，含 k 的是脚），这里列出例外和必杀技。
STRIKE = {
	"slash": "arm_f", "super_k": "arm_f", "rising": "leg_f", "dive": "leg_f",
	"charge": "body", "hammer": "arm_f", "spin": "both_arms",
	"dp": "arm_f", "rush": "leg_f", "super": "arm_f",
}

# 攻击动画五帧里的持续帧
ACTIVE_FRAME = 2


def strike_for(anim_name):
	if anim_name in STRIKE:
		return STRIKE[anim_name]
	base = anim_name[-2:]
	if (anim_name[0] in "25" and len(anim_name) == 3 or anim_name.startswith("j_")) and base[0] in "lmh":
		return "arm_f" if base[1] == "p" else "leg_f"
	return None


def _bbox(points, pad):
	xs = [p[0] for p in points]
	ys = [p[1] for p in points]
	return (min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad)


def _to_game(box):
	"""画布像素 bbox (x0, y0, x1, y1) → 游戏 [x, y, w, h]（像素，y 向上，相对锚点）。"""
	x0, y0, x1, y1 = box
	s = DISPLAY_SCALE
	x, y = round((x0 - ANCHOR[0]) * s), round((ANCHOR[1] - y1) * s)
	w, h = max(1, round((x1 - x0) * s)), max(1, round((y1 - y0) * s))
	if y < 0:  # 不伸到地面以下
		h, y = max(1, h + y), 0
	return [x, y, w, h]


def _hand(sk, front):
	wrist = sk.wrist_f if front else sk.wrist_b
	deg = sk.pose["farm_f" if front else "farm_b"]
	return v_add(wrist, v_mul(limb_dir(deg), 3))


def _toe(sk, front):
	ankle = sk.ankle_f if front else sk.ankle_b
	return v_add(ankle, (sk.body["foot"], 1))


def _knife_tip(sk):
	deg = sk.pose["farm_f"]
	start = v_add(sk.wrist_f, v_mul(limb_dir(deg), 3))
	return v_add(start, v_mul(limb_dir(deg + sk.pose.get("knife", 70)), 11))


def hurt_boxes(ch, sk):
	b = sk.body
	head_r = max(b["head_rx"], b["head_ry"])
	body = _bbox([v_add(sk.head, (-head_r, -head_r)), v_add(sk.head, (head_r, head_r)),
		sk.shoulder_f, sk.shoulder_b, sk.torso_point(-2, b["hip_w"]), sk.torso_point(-2, -b["hip_w"])], 1)
	boxes = [body]
	for front in (True, False):
		hip, knee, ankle = (sk.hip_f, sk.knee_f, sk.ankle_f) if front else (sk.hip_b, sk.knee_b, sk.ankle_b)
		boxes.append(_bbox([hip, knee, ankle, _toe(sk, front)], b["knee_w"] / 2))
	# 手臂伸出身体之外时才单独给受击盒（拆招的目标）
	hand = _hand(sk, True)
	if abs(hand[0] - sk.shoulder_f[0]) > 12 or hand[1] < body[1]:
		boxes.append(_bbox([sk.elbow_f, sk.wrist_f, hand], b["elbow_w"] / 2 + 1))
	return [_to_game(x) for x in boxes]


def hit_boxes(ch, sk, strike):
	b = sk.body
	pad = 3
	if strike == "arm_f":
		pts = [sk.elbow_f, sk.wrist_f, _hand(sk, True)]
		if ch.get("weapon") == "knife":
			pts.append(_knife_tip(sk))
		if ch.get("weapon") == "ribbon" and sk.pose.get("ribbon", 0) > 1:
			pts.append(v_add(_hand(sk, True), v_mul(limb_dir(sk.pose["farm_f"]), sk.pose["ribbon"])))
		return [_to_game(_bbox(pts, b["wrist_w"] / 2 + pad))]
	if strike == "leg_f":
		return [_to_game(_bbox([sk.knee_f, sk.ankle_f, _toe(sk, True)], b["ankle_w"] / 2 + pad))]
	if strike == "both_arms":
		return [_to_game(_bbox([sk.elbow_f, _hand(sk, True)], b["wrist_w"] / 2 + pad)),
			_to_game(_bbox([sk.elbow_b, _hand(sk, False)], b["wrist_w"] / 2 + pad))]
	if strike == "body":
		return [_to_game(_bbox([sk.shoulder_f, sk.torso_point(b["torso"] * 0.3, b["waist_w"] + 4),
			sk.torso_point(b["torso"] * 0.8, b["chest_w"] + 6)], pad))]
	return []


def frame_boxes(ch, pose, anim_name, frame_index, frame_count):
	sk = Skeleton(ch["body"], pose)
	out = {"hurt": hurt_boxes(ch, sk)}
	strike = strike_for(anim_name)
	if strike and frame_count == 5 and frame_index == ACTIVE_FRAME:
		out["hit"] = hit_boxes(ch, sk, strike)
	return out
