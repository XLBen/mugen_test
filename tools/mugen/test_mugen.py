"""MUGEN 导入器测试：python3 -m unittest tools/mugen/test_mugen.py（或在 tools/mugen 下 python3 -m unittest）

用手工构造的 SFF v1 / v2 文件和 AIR 文本验证解析；端到端导入一个假人物到临时目录。
"""

import io
import json
import shutil
import struct
import sys
import unittest
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))

import air  # noqa: E402
import import_char  # noqa: E402
import sff  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def make_pcx(pixels: bytes, w: int, h: int, palette: list) -> bytes:
	header = bytearray(128)
	header[0], header[1], header[2], header[3] = 10, 5, 1, 8
	struct.pack_into("<HHHH", header, 4, 0, 0, w - 1, h - 1)
	header[65] = 1
	struct.pack_into("<H", header, 66, w)
	body = bytearray()
	for b in pixels:  # 每个像素单独编码；>= 0xC0 的值用长度 1 的游程
		if b >= 0xC0:
			body += bytes([0xC1, b])
		else:
			body.append(b)
	pal = bytes(c for rgb in palette for c in rgb)
	return bytes(header) + bytes(body) + b"\x0c" + pal


def make_sff_v1(sprites: list) -> bytes:
	"""sprites: [(group, number, (ax, ay), pcx_bytes)]"""
	head = bytearray(512)
	head[:12] = sff.SIGNATURE
	head[12:16] = bytes([0, 1, 0, 1])
	struct.pack_into("<IIII", head, 16, len(sprites), len(sprites), 512, 32)
	out = bytearray(head)
	ofs = 512
	for k, (g, n, (ax, ay), pcx) in enumerate(sprites):
		nxt = ofs + 32 + len(pcx) if k < len(sprites) - 1 else 0
		sub = bytearray(32)
		struct.pack_into("<IIhhHHHB", sub, 0, nxt, len(pcx), ax, ay, g, n, 0, 0)
		out += sub + pcx
		ofs += 32 + len(pcx)
	return bytes(out)


def make_sff_v2(sprites: list, palettes: list) -> bytes:
	"""sprites: [(group, number, w, h, (ax, ay), fmt, payload, pal_idx)]；palettes: [((group, item), [(r,g,b)...])]"""
	ldata = bytearray()
	pal_nodes = bytearray()
	for (g, item), cols in palettes:
		raw = b"".join(bytes([r, gg, b, 0]) for r, gg, b in cols)
		pal_nodes += struct.pack("<HHHHII", g, item, len(cols), 0, len(ldata), len(raw))
		ldata += raw
	spr_nodes = bytearray()
	for g, n, w, h, (ax, ay), fmt, payload, pal in sprites:
		spr_nodes += struct.pack("<HHHHhhHBBIIHH", g, n, w, h, ax, ay, 0, fmt, 8, len(ldata), len(payload), pal, 0)
		ldata += payload
	head = bytearray(512)
	head[:12] = sff.SIGNATURE
	head[12:16] = bytes([0, 1, 0, 2])
	spr_ofs = 512
	pal_ofs = spr_ofs + len(spr_nodes)
	lofs = pal_ofs + len(pal_nodes)
	struct.pack_into("<IIIIIII", head, 36, spr_ofs, len(sprites), pal_ofs, len(palettes), lofs, len(ldata), lofs + len(ldata))
	return bytes(head) + bytes(spr_nodes) + bytes(pal_nodes) + bytes(ldata)


def rle8_encode(px: bytes) -> bytes:
	out = bytearray()
	for b in px:
		if b & 0xC0 == 0x40:
			out += bytes([0x41, b])
		else:
			out.append(b)
	return bytes(out)


PALETTE = [(0, 0, 0), (255, 0, 0), (0, 255, 0), (0, 0, 255)] + [(9, 9, 9)] * 252


class SffTests(unittest.TestCase):
	def test_pcx_roundtrip(self):
		px = bytes([0, 1, 2, 3, 0xC5, 1])
		img, pal = sff.decode_pcx(make_pcx(px, 3, 2, PALETTE))
		self.assertEqual(img.size, (3, 2))
		self.assertEqual(img.tobytes(), px)
		self.assertEqual(pal[1], (255, 0, 0))

	def test_sff_v1(self, tmp=None):
		data = make_sff_v1([(0, 0, (5, 10), make_pcx(bytes([1] * 6), 3, 2, PALETTE)),
			(20, 1, (1, 2), make_pcx(bytes([2] * 4), 2, 2, PALETTE))])
		path = ROOT / "local_assets" / "_test_v1.sff"
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_bytes(data)
		try:
			s = sff.load(str(path))
		finally:
			path.unlink()
		self.assertEqual(s.version, 1)
		self.assertEqual(len(s.sprites), 2)
		self.assertEqual(s.find(20, 1).axis, (1, 2))
		self.assertEqual(s.find(0, 0).image.size, (3, 2))

	def test_sff_v2_rle8_and_png(self):
		px = bytes([0, 1, 0x45, 3, 3, 2])
		png = io.BytesIO()
		Image.new("RGBA", (2, 2), (10, 20, 30, 255)).save(png, "PNG")
		data = make_sff_v2([
			(0, 0, 3, 2, (1, 2), 2, struct.pack("<I", len(px)) + rle8_encode(px), 0),
			(1, 0, 2, 2, (0, 0), 12, struct.pack("<I", 0) + png.getvalue(), 0),
		], [((1, 1), PALETTE)])
		path = ROOT / "local_assets" / "_test_v2.sff"
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_bytes(data)
		try:
			s = sff.load(str(path))
		finally:
			path.unlink()
		self.assertEqual(s.version, 2)
		self.assertEqual(s.find(0, 0).image.tobytes(), px)
		self.assertIs(s.find(0, 0).palette, s.palette_by_key(1, 1))
		self.assertEqual(s.find(1, 0).image.getpixel((0, 0)), (10, 20, 30, 255))

	def test_lz5_rle_and_short_copy(self):
		# 控制字节 0b10：第一个包是 RLE（颜色 5 × 2），第二个包是短 LZ（距离 1，复制 2 个）
		src = bytes([0b10, (2 << 5) | 5, 0x01, 0x00])
		self.assertEqual(list(sff.lz5_decode(src, 4)), [5, 5, 5, 5])

	def test_lz5_long_rle(self):
		src = bytes([0, 0x03, 2])  # 颜色 3，长度 2 + 8
		self.assertEqual(list(sff.lz5_decode(src, 10)), [3] * 10)

	def test_to_rgba_makes_index0_transparent(self):
		img = Image.frombytes("P", (2, 1), bytes([0, 1]))
		rgba = sff.to_rgba(img, PALETTE)
		self.assertEqual(rgba.getpixel((0, 0))[3], 0)
		self.assertEqual(rgba.getpixel((1, 0)), (255, 0, 0, 255))

	def test_act_is_reversed(self):
		path = ROOT / "local_assets" / "_test.act"
		path.parent.mkdir(parents=True, exist_ok=True)
		raw = bytearray(768)
		raw[0:3] = bytes([1, 2, 3])  # 文件里的第一个颜色 = 255 号色
		path.write_bytes(bytes(raw))
		try:
			pal = sff.load_act(str(path))
		finally:
			path.unlink()
		self.assertEqual(pal[255], (1, 2, 3))


AIR_TEXT = """
; sample
[Begin Action 0]
Clsn2Default: 1
 Clsn2[0] = -10, -80, 10, 0
0,0, 0,0, 5
0,1, 0,0, 5
Loopstart
0,2, 2,0, -1

[Begin Action 200]
Clsn2Default: 1
 Clsn2[0] = -10, -80, 10, 0
200,0, 0,0, 3
Clsn1: 1
 Clsn1[0] = 10, -60, 40, -50
200,1, 0,0, 2
200,2, 0,0, 4
"""


class AirTests(unittest.TestCase):
	def test_parse(self):
		acts = air.parse(AIR_TEXT)
		self.assertEqual(sorted(acts), [0, 200])
		a0 = acts[0]
		self.assertEqual(len(a0.frames), 3)
		self.assertEqual(a0.loopstart, 2)
		self.assertEqual(a0.frames[2].offset, (2, 0))
		self.assertEqual(a0.frames[2].time, -1)
		self.assertEqual(a0.frames[1].clsn2, [(-10, -80, 10, 0)])
		a200 = acts[200]
		self.assertEqual(a200.first_attack_frame(), 1)
		self.assertEqual(a200.frames[1].clsn1, [(10, -60, 40, -50)])
		self.assertEqual(a200.frames[2].clsn1, [], "one-shot Clsn1 only applies to the next frame")

	def test_compress_attack(self):
		frames = air.parse(AIR_TEXT)[200].frames
		five = import_char.compress_attack(frames)
		self.assertEqual(len(five), 5)
		self.assertEqual(five[2][0].clsn1, [(10, -60, 40, -50)])
		self.assertEqual(five[0][0].image, 0)
		self.assertEqual(five[4][0].image, 2)

	def test_convert_box(self):
		self.assertEqual(import_char.convert_box((-10, -80, 10, 0), 1.5), [-15, 0, 30, 120])


class ImportTests(unittest.TestCase):
	def test_end_to_end(self):
		work = ROOT / "local_assets" / "_test_char"
		out_root = ROOT / "local_assets" / "_test_out"
		shutil.rmtree(work, ignore_errors=True)
		shutil.rmtree(out_root, ignore_errors=True)
		work.mkdir(parents=True)
		try:
			body = bytes([1] * (4 * 8))
			sprites = []
			for g, n in [(0, 0), (0, 1), (0, 2), (200, 0), (200, 1), (200, 2)]:
				sprites.append((g, n, 4, 8, (2, 8), 2, struct.pack("<I", len(body)) + rle8_encode(body), 0))
			(work / "test.sff").write_bytes(make_sff_v2(sprites, [((1, 1), PALETTE), ((1, 2), PALETTE)]))
			(work / "test.air").write_text(AIR_TEXT)
			(work / "test.def").write_text("[Info]\nname = \"Test\"\nauthor = me\n[Files]\nsprite = test.sff\nanim = test.air\n")
			mapping = {"id": "test", "name": "Test", "base": "kagura", "target_height": 16,
				"anims": {"idle": 0, "5lp": 200, "5mp": 999}}
			(work / "map.json").write_text(json.dumps(mapping))
			out = import_char.cmd_import(work, work / "map.json", out_root)
			meta = json.loads((out / "sprites" / "anims.json").read_text())
			self.assertEqual(meta["scale"], 2.0)
			self.assertEqual(set(meta["anims"]), {"idle", "5lp"})
			attack = meta["anims"]["5lp"]["frames"]
			self.assertEqual(len(attack), 5)
			self.assertEqual(attack[2][2]["hit"], [[20, 100, 60, 20]])
			self.assertTrue((out / "sprites" / "pal1" / "5lp_02.png").exists())
			self.assertIn('display_name = "Test"', (out / "fighter.tres").read_text())
		finally:
			shutil.rmtree(work, ignore_errors=True)
			shutil.rmtree(out_root, ignore_errors=True)


if __name__ == "__main__":
	unittest.main()
