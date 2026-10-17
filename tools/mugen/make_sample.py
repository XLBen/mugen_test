#!/usr/bin/env python3
"""把本工程的程序化角色打包成一个 MUGEN 格式的样例人物（SFF v2 RLE8 + AIR Clsn + DEF），用来端到端验证导入流程。

    python3 tools/mugen/make_sample.py [角色id=kagura]
输出：local_assets/mugen_src/sample_<id>/（人物目录）与 local_assets/mugen_src/sample_<id>/map.json（映射）。
"""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))

from test_mugen import make_sff_v2, rle8_encode  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]

ACTIONS = {
	"idle": 0, "crouch": 11, "walk_f": 20, "walk_b": 21, "prejump": 40, "jump": 41, "land": 47,
	"block_stand": 150, "block_crouch": 152, "hit_stand": 5000, "hit_crouch": 5020, "hit_air": 5030,
	"knockdown": 5110, "wakeup": 5120, "throw": 800, "throw_hit": 810,
	"5lp": 200, "5mp": 210, "5hp": 220, "5lk": 230, "5mk": 240, "5hk": 250,
	"2lp": 400, "2mp": 410, "2hp": 420, "2lk": 430, "2mk": 440, "2hk": 450,
	"j_lp": 600, "j_mp": 610, "j_hp": 620, "j_lk": 630, "j_mk": 640, "j_hk": 650,
}
SPECIAL_BASE = 1000


def main(char_id: str = "kagura") -> Path:
	src = ROOT / "characters" / char_id / "sprites"
	meta = json.loads((src / "anims.json").read_text())
	anchor = meta["anchor"]
	scale = meta["scale"]
	out = ROOT / "local_assets" / "mugen_src" / f"sample_{char_id}"
	out.mkdir(parents=True, exist_ok=True)

	actions = dict(ACTIONS)
	next_special = SPECIAL_BASE
	for name in meta["anims"]:
		if name not in actions and not name.startswith("fx_"):
			actions[name] = next_special
			next_special += 10

	# 统一量化到一个 255 色调色板（0 号透明）
	frames = []
	for name, number in actions.items():
		if name not in meta["anims"]:
			continue
		for k, f in enumerate(meta["anims"][name]["frames"]):
			frames.append((name, number, k, f, Image.open(src / "pal0" / f"{f[0]}.png").convert("RGBA")))
	sheet = Image.new("RGBA", (sum(img.width for *_, img in frames), max(img.height for *_, img in frames)))
	x = 0
	for *_, img in frames:
		sheet.paste(img, (x, 0))
		x += img.width
	quant = sheet.convert("RGB").quantize(colors=255)
	qpal = quant.getpalette()[:255 * 3]
	palette = [(0, 0, 0)] + [tuple(qpal[i * 3:i * 3 + 3]) for i in range(len(qpal) // 3)]
	palette += [(0, 0, 0)] * (256 - len(palette))

	sprites = []
	air_lines = []
	current = None
	for name, number, k, f, img in frames:
		q = img.convert("RGB").quantize(palette=quant, dither=Image.Dither.NONE)
		px = bytes((v + 1) if a > 127 else 0 for v, a in zip(q.tobytes(), img.getchannel("A").tobytes()))
		sprites.append((number, k, img.width, img.height, (anchor[0], anchor[1]), 2,
			struct.pack("<I", len(px)) + rle8_encode(px), 0))
		if number != current:
			air_lines.append(f"\n[Begin Action {number}]")
			current = number
		boxes = f[2] if len(f) > 2 else {}
		for kind, key in (("2", "hurt"), ("1", "hit")):
			lst = boxes.get(key, [])
			if lst:
				air_lines.append(f"Clsn{kind}: {len(lst)}")
				for i, (bx, by, bw, bh) in enumerate(lst):
					x1, x2 = round(bx / scale), round((bx + bw) / scale)
					y1, y2 = -round((by + bh) / scale), -round(by / scale)
					air_lines.append(f" Clsn{kind}[{i}] = {x1}, {y1}, {x2}, {y2}")
		air_lines.append(f"{number},{k}, 0,0, {f[1]}")

	(out / f"sample_{char_id}.sff").write_bytes(make_sff_v2(sprites, [((1, 1), palette), ((1, 2), palette)]))
	(out / f"sample_{char_id}.air").write_text("; generated sample\n" + "\n".join(air_lines) + "\n")
	(out / f"sample_{char_id}.def").write_text(
		f'[Info]\nname = "Sample {char_id}"\nauthor = "mugenlike sample"\nlocalcoord = 640,480\n\n'
		f"[Files]\nsprite = sample_{char_id}.sff\nanim = sample_{char_id}.air\n")
	base = {"kagura": "kagura", "volk": "volk", "mio": "mio"}[char_id]
	mapping = {"id": f"sample_{char_id}", "name": f"Sample {char_id.title()}", "base": base,
		"target_height": 0, "anims": {name: number for name, number in actions.items() if name in meta["anims"]}}
	mapping["anims"]["jump"] = {"frames": [[41, 0], [41, 1], [41, 2]]}
	# 保持原来的显示大小：站立精灵高度 × 原缩放
	mapping["target_height"] = round(next(img.height for n, _, k, _, img in frames if n == "idle") * scale)
	(out / "map.json").write_text(json.dumps(mapping, indent="\t"))
	print(f"sample MUGEN character -> {out} ({len(sprites)} sprites, {len(set(n for _, n, *_ in frames))} actions)")
	return out


if __name__ == "__main__":
	main(*sys.argv[1:])
