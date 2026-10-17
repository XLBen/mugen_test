#!/usr/bin/env python3
"""MUGEN 人物 → 本工程的精灵格式（anims.json + PNG + 逐帧判定盒）。只在本地使用，输出放在 local_assets/（不入库）。

用法：
    python3 tools/mugen/import_char.py list   <人物目录>                 # 看 .def 信息和全部动作（哪些带攻击判定）
    python3 tools/mugen/import_char.py import <人物目录> <映射.json>    # 按映射导出到 local_assets/mugen/<id>/

映射文件（见 tools/mugen/maps/*.json）把本工程的动画名对应到 MUGEN 动作号：
    "idle": 0                              一个动作，按原时长播放
    "crouch": [10, 11]                     多个动作首尾相接
    "jump": {"frames": [[41, 0], [41, -1], [44, 0]]}   手动挑帧（-1 = 最后一帧）
带 Clsn1（攻击判定）的动作会自动压成本工程的五帧攻击动画（蓄力 / 出手 / 持续 / 收势 / 复原），
持续帧的攻击盒取所有攻击帧 Clsn1 的并集；每帧受击盒取 Clsn2。招式的发生 / 持续 / 收招帧数仍以本工程招式表为准。

注意：这些人物大多由商业游戏素材提取而来，只能本地自用，不要提交到公开仓库。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from PIL import Image

import air as air_mod
import sff as sff_mod

ROOT = Path(__file__).resolve().parents[2]


# ---------------------------------------------------------------- .def

def parse_def(path: Path) -> dict:
	"""简单的 INI 解析：返回 {section: {key: value}}，键名小写。"""
	out: dict = {}
	section = ""
	for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
		line = raw.split(";", 1)[0].strip()
		if not line:
			continue
		m = re.match(r"\[(.+)\]", line)
		if m:
			section = m.group(1).strip().lower()
			out.setdefault(section, {})
			continue
		if "=" in line:
			k, v = line.split("=", 1)
			out.setdefault(section, {})[k.strip().lower()] = v.strip().strip('"')
	return out


def find_def(char_dir: Path) -> Path:
	defs = sorted(p for p in char_dir.glob("*.def") if not p.name.lower().startswith("ending"))
	if not defs:
		raise SystemExit(f"{char_dir}: 找不到 .def 文件")
	same = [p for p in defs if p.stem.lower() == char_dir.name.lower()]
	return same[0] if same else defs[0]


def load_char(char_dir: Path):
	def_path = find_def(char_dir)
	d = parse_def(def_path)
	files = d.get("files", {})
	sff = sff_mod.load(str(char_dir / files["sprite"]))
	actions = air_mod.load(str(char_dir / files["anim"]))
	acts = []
	for k in range(1, 13):
		name = files.get(f"pal{k}")
		if name and (char_dir / name).exists():
			acts.append(sff_mod.load_act(str(char_dir / name)))
	return d, sff, actions, acts


# ---------------------------------------------------------------- list

STANDARD = {0: "stand", 5: "turn", 10: "stand>crouch", 11: "crouch", 12: "crouch>stand", 20: "walk fwd", 21: "walk back",
	40: "jump start", 41: "jump neutral", 42: "jump fwd", 43: "jump back", 44: "jump fall", 47: "jump land",
	100: "run fwd", 105: "hop back", 120: "guard start", 130: "stand guard", 131: "crouch guard", 150: "stand guard hit",
	152: "crouch guard hit", 5000: "stand hit high light", 5010: "stand hit low light", 5020: "crouch hit light",
	5030: "air hit", 5100: "hit ground", 5110: "lie down", 5120: "get up", 5150: "lie dead"}


def cmd_list(char_dir: Path) -> None:
	d, sff, actions, acts = load_char(char_dir)
	info = d.get("info", {})
	print(f"name: {info.get('displayname') or info.get('name')}   author: {info.get('author', '?')}   "
		f"localcoord: {info.get('localcoord', '320,240')}")
	print(f"SFF v{sff.version}: {len(sff.sprites)} sprites, {len(sff.palettes)} palettes; act palettes: {len(acts)}")
	print("action  frames  time  attack-frames  note")
	for n in sorted(actions):
		a = actions[n]
		total = sum(max(f.time, 0) for f in a.frames)
		hits = [i for i, f in enumerate(a.frames) if f.clsn1]
		hit_txt = f"{hits[0]}-{hits[-1]}" if hits else ""
		print(f"{n:6d}  {len(a.frames):6d}  {total:4d}  {hit_txt:13s}  {STANDARD.get(n, '')}")


# ---------------------------------------------------------------- import

def pick_frames(actions: dict, spec) -> tuple[list, bool]:
	"""映射项 → [(Frame, 时长)] 和"是否攻击动画"。"""
	if isinstance(spec, int):
		spec = [spec]
	if isinstance(spec, dict):
		frames = []
		for n, idx in spec["frames"]:
			a = actions[n]
			frames.append((a.frames[idx], spec.get("dur", 1)))
		return frames, False
	frames = []
	for n in spec:
		for f in actions[n].frames:
			frames.append((f, f.time if f.time > 0 else 60))
	attack = any(f.clsn1 for f, _ in frames)
	if attack:
		frames = compress_attack([f for f, _ in frames])
	return frames, attack


def compress_attack(frames: list) -> list:
	"""任意长度的攻击动作 → 五帧（蓄力 / 出手 / 持续 / 收势 / 复原）。"""
	hits = [i for i, f in enumerate(frames) if f.clsn1]
	a, b = hits[0], hits[-1]
	startup = frames[:a] or [frames[a]]
	recovery = frames[b + 1:] or [frames[b]]
	active = air_mod.Frame(frames[a].group, frames[a].image, frames[a].offset, frames[a].time, frames[a].flip,
		[], list(frames[a].clsn2))
	for f in frames[a:b + 1]:
		for box in f.clsn1:
			if box not in active.clsn1:
				active.clsn1.append(box)
	return [(startup[0], 1), (startup[-1], 1), (active, 1), (recovery[0], 1), (recovery[-1], 1)]


def sprite_for(sff, frame):
	return sff.find(frame.group, frame.image)


def frame_rect(sprite, frame):
	"""精灵左上角相对脚底的位置与尺寸（MUGEN 坐标，y 向下）。"""
	w, h = sprite.image.size
	ax, ay = sprite.axis
	ox, oy = frame.offset
	left = ox + (ax - w if "H" in frame.flip else -ax)
	top = oy + (ay - h if "V" in frame.flip else -ay)
	return left, top, w, h


def convert_box(box, scale):
	x1, y1, x2, y2 = box
	return [round(min(x1, x2) * scale), round(-max(y1, y2) * scale), max(1, round(abs(x2 - x1) * scale)),
		max(1, round(abs(y2 - y1) * scale))]


def cmd_import(char_dir: Path, map_path: Path, out_root: Path) -> Path:
	mapping = json.loads(map_path.read_text(encoding="utf-8"))
	d, sff, actions, acts = load_char(char_dir)
	out = out_root / mapping["id"]
	sprite_dir = out / "sprites"

	# 1. 选帧
	anims = {}
	for name, spec in mapping["anims"].items():
		missing = [n for n in ([spec] if isinstance(spec, int) else spec if isinstance(spec, list)
			else [n for n, _ in spec["frames"]]) if n not in actions]
		if missing:
			print(f"  skip {name}: action {missing} not found")
			continue
		frames, attack = pick_frames(actions, spec)
		frames = [(f, dur) for f, dur in frames if sprite_for(sff, f) is not None and sprite_for(sff, f).image]
		if frames:
			anims[name] = {"frames": frames, "attack": attack, "loop": name in ("idle", "walk_f", "walk_b")}

	# 2. 统一画布（所有帧的外接矩形），锚点 = 脚底
	left = top = 10 ** 9
	right = bottom = -10 ** 9
	for a in anims.values():
		for f, _ in a["frames"]:
			l, t, w, h = frame_rect(sprite_for(sff, f), f)
			left, top, right, bottom = min(left, l), min(top, t), max(right, l + w), max(bottom, t + h)
	canvas = (right - left, bottom - top)
	anchor = (-left, -top)

	# 3. 缩放：让站立高度接近目标高度
	stand = sprite_for(sff, anims["idle"]["frames"][0][0]) if "idle" in anims else None
	height = stand.image.size[1] if stand else canvas[1]
	scale = round(mapping.get("target_height", 230) / max(height, 1), 2)

	# 4. 调色板：第二套给同角色镜像用
	palettes = _palettes(sff, acts)

	# 5. 输出 PNG + anims.json
	meta_anims = {}
	for pal_index, pal_fn in enumerate(palettes):
		pal_dir = sprite_dir / f"pal{pal_index}"
		pal_dir.mkdir(parents=True, exist_ok=True)
		for old in pal_dir.glob("*.png"):
			old.unlink()
		for name, a in anims.items():
			frames_meta = []
			for k, (f, dur) in enumerate(a["frames"]):
				spr = sprite_for(sff, f)
				img = sff_mod.to_rgba(spr.image, pal_fn(spr))
				if "H" in f.flip:
					img = img.transpose(Image.FLIP_LEFT_RIGHT)
				if "V" in f.flip:
					img = img.transpose(Image.FLIP_TOP_BOTTOM)
				l, t, _, _ = frame_rect(spr, f)
				cv = Image.new("RGBA", canvas, (0, 0, 0, 0))
				cv.alpha_composite(img, (l + anchor[0], t + anchor[1]))
				file = f"{name}_{k:02d}"
				cv.save(pal_dir / f"{file}.png")
				boxes = {"hurt": [convert_box(b, scale) for b in f.clsn2]}
				if f.clsn1:
					boxes["hit"] = [convert_box(b, scale) for b in f.clsn1]
				frames_meta.append([file, max(int(dur), 1), boxes])
			meta_anims[name] = {"loop": a["loop"], "frames": frames_meta}
	meta = {"canvas": list(canvas), "anchor": list(anchor), "scale": scale, "palettes": len(palettes),
		"anims": meta_anims, "source": {"char": char_dir.name, "author": d.get("info", {}).get("author", "")}}
	(sprite_dir / "anims.json").write_text(json.dumps(meta, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")

	# 6. FighterDef：沿用本工程对应角色的招式表与体格，只换精灵目录和名字
	base = (ROOT / "characters" / mapping["base"] / f"{mapping['base']}.tres").read_text(encoding="utf-8")
	rel = out.resolve().relative_to(ROOT)
	tres = re.sub(r'^display_name = .*$', f'display_name = "{mapping["name"]}"', base, flags=re.M)
	tres = re.sub(r'^sprite_dir = .*$', f'sprite_dir = "res://{rel.as_posix()}/sprites"', tres, flags=re.M)
	(out / "fighter.tres").write_text(tres, encoding="utf-8")
	print(f"imported {len(anims)} animations -> {out}  (scale {scale}, canvas {canvas})")
	not_mapped = sorted(set(mapping["anims"]) - set(anims))
	if not_mapped:
		print("  not imported:", ", ".join(not_mapped))
	return out


def _palettes(sff, acts):
	"""返回两套"精灵 → 调色板"函数。SFF v2 用 (1,1)/(1,2)，SFF v1 用 .act（没有则用 PCX 自带）。"""
	if sff.version == 2:
		p1 = sff.palette_by_key(1, 1)
		p2 = sff.palette_by_key(1, 2) or p1
		def make(alt):
			def fn(spr):
				own = spr.palette
				if p1 is not None and own is p1:
					return alt
				return own
			return fn
		return [make(p1), make(p2)]
	if acts:
		second = acts[1] if len(acts) > 1 else acts[0]
		return [lambda spr: acts[0], lambda spr: second]
	return [lambda spr: spr.palette, lambda spr: spr.palette]


def main(argv):
	if len(argv) >= 2 and argv[0] == "list":
		cmd_list(Path(argv[1]))
	elif len(argv) >= 3 and argv[0] == "import":
		out_root = Path(argv[3]) if len(argv) > 3 else ROOT / "local_assets" / "mugen"
		cmd_import(Path(argv[1]), Path(argv[2]), out_root)
	else:
		print(__doc__)


if __name__ == "__main__":
	main(sys.argv[1:])
