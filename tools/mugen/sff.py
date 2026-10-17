"""MUGEN 精灵文件（.sff）读取：支持 SFF v1（PCX）与 SFF v2（raw / RLE8 / RLE5 / LZ5 / PNG8/24/32）。

只依赖 Pillow。每个精灵解出为：
    Sprite(group, number, axis=(x, y), image=PIL.Image 'P' 或 'RGBA', palette=[(r,g,b)*256] 或 None)
索引色图像里 0 号色视为透明。

格式依据：Elecbyte 文档（Sprmake2 说明 LZ5 / RLE5 只用于 5 位 32 色精灵）与开源引擎的公开实现。
RLE5 / LZ5 的位级细节没有找到官方逐位说明，如果解出的图像错乱，可先用 Fighter Factory 把精灵
重新保存为 RLE8 或 PNG 再导入。
"""

from __future__ import annotations

import io
import struct
from dataclasses import dataclass, field

from PIL import Image

SIGNATURE = b"ElecbyteSpr\x00"


@dataclass
class Sprite:
	group: int
	number: int
	axis: tuple[int, int]
	image: Image.Image | None = None
	palette: list | None = None  # 256 个 (r, g, b)
	palette_index: int = -1  # SFF v2：所用调色板序号
	link: int = -1


@dataclass
class Sff:
	version: int
	sprites: list[Sprite] = field(default_factory=list)
	palettes: list[list] = field(default_factory=list)  # SFF v2 调色板列表
	palette_keys: list[tuple[int, int]] = field(default_factory=list)  # (group, item)

	def find(self, group: int, number: int) -> Sprite | None:
		for s in self.sprites:
			if s.group == group and s.number == number:
				return s
		return None

	def palette_by_key(self, group: int, item: int) -> list | None:
		for k, pal in zip(self.palette_keys, self.palettes):
			if k == (group, item):
				return pal
		return None


def load(path: str) -> Sff:
	with open(path, "rb") as fh:
		data = fh.read()
	if data[:12] != SIGNATURE:
		raise ValueError(f"{path}: not an SFF file")
	ver_hi = data[15]
	if ver_hi == 1:
		return _load_v1(data)
	if ver_hi == 2:
		return _load_v2(data)
	raise ValueError(f"{path}: unsupported SFF version {ver_hi}")


# ---------------------------------------------------------------- SFF v1

def _load_v1(data: bytes) -> Sff:
	n_images, first_ofs = struct.unpack_from("<II", data, 20)
	sff = Sff(version=1)
	ofs = first_ofs
	prev_palette = None
	for i in range(n_images):
		if ofs <= 0 or ofs + 32 > len(data):
			break
		next_ofs, size, ax, ay, group, number, link, same_pal = struct.unpack_from("<IIhhHHHB", data, ofs)
		sprite = Sprite(group, number, (ax, ay), link=link if size == 0 else -1)
		if size > 0:
			pcx = data[ofs + 32: ofs + 32 + size]
			image, palette = decode_pcx(pcx)
			if same_pal and prev_palette is not None:
				palette = prev_palette
			sprite.image = image
			sprite.palette = palette
			prev_palette = palette
		sff.sprites.append(sprite)
		ofs = next_ofs
	_resolve_links(sff)
	return sff


def decode_pcx(pcx: bytes):
	"""8 位单平面 PCX → ('P' 图像, 调色板)。调色板缺失时返回 None。"""
	xmin, ymin, xmax, ymax = struct.unpack_from("<HHHH", pcx, 4)
	planes = pcx[65]
	bpl = struct.unpack_from("<H", pcx, 66)[0]
	w, h = xmax - xmin + 1, ymax - ymin + 1
	line = bpl * planes
	out = bytearray(line * h)
	i, j = 128, 0
	while j < len(out) and i < len(pcx):
		c = pcx[i]
		i += 1
		if c & 0xC0 == 0xC0:
			n = c & 0x3F
			v = pcx[i]
			i += 1
			out[j:j + n] = bytes([v]) * min(n, len(out) - j)
			j += n
		else:
			out[j] = c
			j += 1
	pixels = bytearray()
	for y in range(h):
		pixels += out[y * line: y * line + w]
	palette = None
	if len(pcx) >= 769 and pcx[-769] == 0x0C:
		raw = pcx[-768:]
		palette = [tuple(raw[k * 3:k * 3 + 3]) for k in range(256)]
	img = Image.frombytes("P", (w, h), bytes(pixels))
	return img, palette


# ---------------------------------------------------------------- SFF v2

def _load_v2(data: bytes) -> Sff:
	spr_ofs, n_spr, pal_ofs, n_pal, lofs, _llen, tofs = struct.unpack_from("<IIIIIII", data, 36)
	sff = Sff(version=2)
	for k in range(n_pal):
		group, item, ncols, link, ofs, size = struct.unpack_from("<HHHHII", data, pal_ofs + k * 16)
		sff.palette_keys.append((group, item))
		if size == 0:
			sff.palettes.append(sff.palettes[link] if link < len(sff.palettes) else None)
			continue
		raw = data[lofs + ofs: lofs + ofs + size]
		pal = [tuple(raw[c * 4:c * 4 + 3]) for c in range(min(ncols, len(raw) // 4))]
		pal += [(0, 0, 0)] * (256 - len(pal))
		sff.palettes.append(pal)
	for k in range(n_spr):
		(group, number, w, h, ax, ay, link, fmt, depth, ofs, size, pal_idx, flags) = struct.unpack_from(
			"<HHHHhhHBBIIHH", data, spr_ofs + k * 28)
		sprite = Sprite(group, number, (ax, ay), palette_index=pal_idx, link=link if size == 0 else -1)
		if size > 0:
			base = tofs if flags & 1 else lofs
			blob = data[base + ofs: base + ofs + size]
			sprite.image = _decode_v2(blob, fmt, w, h)
			if sprite.image.mode == "P" and pal_idx < len(sff.palettes):
				sprite.palette = sff.palettes[pal_idx]
		sff.sprites.append(sprite)
	_resolve_links(sff)
	return sff


def _decode_v2(blob: bytes, fmt: int, w: int, h: int) -> Image.Image:
	if fmt == 0:
		return Image.frombytes("P", (w, h), bytes(blob[:w * h]).ljust(w * h, b"\0"))
	if fmt in (10, 11, 12):
		start = blob.find(b"\x89PNG")
		img = Image.open(io.BytesIO(blob[start if start >= 0 else 4:]))
		img.load()
		return img if img.mode == "P" else img.convert("RGBA")
	payload = blob[4:]  # 前 4 字节是解压后的长度
	if fmt == 2:
		px = rle8_decode(payload, w * h)
	elif fmt == 3:
		px = rle5_decode(payload, w * h)
	elif fmt == 4:
		px = lz5_decode(payload, w * h)
	else:
		raise ValueError(f"unknown SFF v2 sprite format {fmt}")
	return Image.frombytes("P", (w, h), bytes(px))


def rle8_decode(src: bytes, n: int) -> bytearray:
	out = bytearray(n)
	i = j = 0
	while j < n and i < len(src):
		b = src[i]
		i += 1
		if b & 0xC0 == 0x40:
			run = b & 0x3F
			v = src[i]
			i += 1
			for _ in range(run):
				if j < n:
					out[j] = v
					j += 1
		else:
			out[j] = b
			j += 1
	return out


def rle5_decode(src: bytes, n: int) -> bytearray:
	out = bytearray(n)
	i = j = 0
	while j < n and i + 1 < len(src):
		rl = src[i]
		i += 1
		dl = src[i] & 0x7F
		c = 0
		if src[i] >> 7:
			i += 1
			c = src[i]
		i += 1
		while True:
			if j < n:
				out[j] = c
				j += 1
			rl -= 1
			if rl < 0:
				dl -= 1
				if dl < 0 or i >= len(src):
					break
				c = src[i] & 0x1F
				rl = src[i] >> 5
				i += 1
	return out


def lz5_decode(src: bytes, n: int) -> bytearray:
	"""LZ5：控制字节的每一位决定下一个包是 RLE 包（0）还是 LZ 包（1），低位先用。"""
	out = bytearray(n)
	if not src:
		return out
	i, j = 0, 0
	ct, cts = src[0], 0
	i = 1
	rb, rbc = 0, 0  # 短 LZ 包回收的高 2 位
	while j < n and i < len(src):
		d = src[i]
		i += 1
		if ct & (1 << cts):
			if d & 0x3F == 0:
				dist = ((d << 2) | src[i]) + 1
				i += 1
				length = src[i] + 2
				i += 1
			else:
				rb |= (d & 0xC0) >> rbc
				rbc += 2
				length = d & 0x3F
				if rbc < 8:
					dist = src[i] + 1
					i += 1
				else:
					dist = rb + 1
					rb, rbc = 0, 0
			while True:
				if j < n:
					out[j] = out[j - dist] if j - dist >= 0 else 0
					j += 1
				length -= 1
				if length < 0:
					break
		else:
			if d & 0xE0 == 0:
				run = src[i] + 8
				i += 1
			else:
				run = d >> 5
				d &= 0x1F
			for _ in range(run):
				if j < n:
					out[j] = d
					j += 1
		cts += 1
		if cts >= 8 and i < len(src):
			ct, cts = src[i], 0
			i += 1
	return out


def _resolve_links(sff: Sff) -> None:
	for s in sff.sprites:
		if s.image is None and 0 <= s.link < len(sff.sprites):
			target = sff.sprites[s.link]
			s.image, s.palette = target.image, target.palette
			if s.palette_index < 0:
				s.palette_index = target.palette_index


# ---------------------------------------------------------------- 调色板

def load_act(path: str) -> list:
	"""MUGEN 的 .act 调色板：768 字节 RGB，顺序是倒过来存的（最后一个颜色在最前）。"""
	with open(path, "rb") as fh:
		raw = fh.read()[:768]
	pal = [tuple(raw[k * 3:k * 3 + 3]) for k in range(len(raw) // 3)]
	pal.reverse()
	return pal + [(0, 0, 0)] * (256 - len(pal))


def to_rgba(image: Image.Image, palette: list | None) -> Image.Image:
	"""索引色 → RGBA，0 号色透明。"""
	if image.mode != "P":
		return image.convert("RGBA")
	img = image.copy()
	if palette:
		flat = [c for rgb in palette[:256] for c in rgb]
		img.putpalette(flat + [0] * (768 - len(flat)))
	rgba = img.convert("RGBA")
	alpha = Image.frombytes("L", image.size, bytes(0 if v == 0 else 255 for v in image.tobytes()))
	rgba.putalpha(alpha)
	return rgba
