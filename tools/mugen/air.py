"""MUGEN 动画文件（.air）读取：每个 Action 的帧（精灵、偏移、时长）与判定盒 Clsn1 / Clsn2。

规则：
- "Clsn2Default: n" / "Clsn1Default: n" 之后的盒子对本 Action 后续所有帧有效；
- "Clsn2: n" / "Clsn1: n" 之后的盒子只对紧跟的下一帧有效；
- 帧行："group, image, x, y, time[, flip[, trans]]"，time = -1 表示无限；
- 坐标相对角色轴心（脚底），y 向下为正。
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

Box = tuple[int, int, int, int]  # x1, y1, x2, y2（MUGEN 原始坐标）


@dataclass
class Frame:
	group: int
	image: int
	offset: tuple[int, int]
	time: int
	flip: str = ""
	clsn1: list[Box] = field(default_factory=list)
	clsn2: list[Box] = field(default_factory=list)


@dataclass
class Action:
	number: int
	frames: list[Frame] = field(default_factory=list)
	loopstart: int = 0

	def first_attack_frame(self) -> int:
		for i, f in enumerate(self.frames):
			if f.clsn1:
				return i
		return -1


_BEGIN = re.compile(r"\[\s*begin\s+action\s+(-?\d+)\s*\]", re.I)
_CLSN_HEAD = re.compile(r"clsn([12])(default)?\s*:\s*(\d+)", re.I)
_CLSN_BOX = re.compile(r"clsn([12])\s*\[\s*\d+\s*\]\s*=\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)", re.I)


def parse(text: str) -> dict[int, Action]:
	actions: dict[int, Action] = {}
	cur: Action | None = None
	default = {"1": [], "2": []}
	pending = {"1": None, "2": None}  # 只作用于下一帧的盒子
	collecting = None  # ("1"/"2", "default"/"next")
	for raw in text.splitlines():
		line = raw.split(";", 1)[0].strip()
		if not line:
			continue
		m = _BEGIN.match(line)
		if m:
			cur = Action(int(m.group(1)))
			actions[cur.number] = cur
			default = {"1": [], "2": []}
			pending = {"1": None, "2": None}
			collecting = None
			continue
		if cur is None:
			continue
		m = _CLSN_HEAD.match(line)
		if m:
			kind = m.group(1)
			if m.group(2):
				default[kind] = []
				collecting = (kind, "default")
			else:
				pending[kind] = []
				collecting = (kind, "next")
			continue
		m = _CLSN_BOX.match(line)
		if m:
			box = tuple(int(m.group(k)) for k in range(2, 6))
			kind = m.group(1)
			if collecting and collecting[0] == kind and collecting[1] == "default":
				default[kind].append(box)
			else:
				if pending[kind] is None:
					pending[kind] = []
				pending[kind].append(box)
			continue
		if line.lower().startswith("loopstart"):
			cur.loopstart = len(cur.frames)
			continue
		parts = [p.strip() for p in line.split(",")]
		if len(parts) >= 5 and _is_int(parts[0]) and _is_int(parts[1]):
			f = Frame(int(parts[0]), int(parts[1]), (int(parts[2]), int(parts[3])), int(parts[4]),
				parts[5].upper() if len(parts) > 5 else "")
			f.clsn1 = list(pending["1"]) if pending["1"] is not None else list(default["1"])
			f.clsn2 = list(pending["2"]) if pending["2"] is not None else list(default["2"])
			pending = {"1": None, "2": None}
			collecting = None
			cur.frames.append(f)
	return actions


def load(path: str) -> dict[int, Action]:
	with open(path, "r", encoding="utf-8", errors="replace") as fh:
		return parse(fh.read())


def _is_int(s: str) -> bool:
	return bool(re.fullmatch(r"-?\d+", s))
