class_name Box
## 判定盒工具。数据里的盒子是相对脚底、面朝右的 [x, y, w, h]（逻辑单位，x 向前、y 向上）；
## 世界盒子是 [left, bottom, right, top]。只有 AABB，朝向翻转在运行时做。


## 数据里以像素书写，构建时转成逻辑单位。
static func from_px(a: Array) -> PackedInt32Array:
	return PackedInt32Array([a[0] * SimConst.UNITS_PER_PX, a[1] * SimConst.UNITS_PER_PX,
		a[2] * SimConst.UNITS_PER_PX, a[3] * SimConst.UNITS_PER_PX])


static func to_world(x: int, y: int, facing: int, box: PackedInt32Array) -> PackedInt32Array:
	var left := x + box[0] if facing > 0 else x - box[0] - box[2]
	return PackedInt32Array([left, y + box[1], left + box[2], y + box[1] + box[3]])


static func overlap(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


static func any_overlap(list_a: Array, list_b: Array) -> bool:
	for a: PackedInt32Array in list_a:
		for b: PackedInt32Array in list_b:
			if overlap(a, b):
				return true
	return false


## 第一对相交盒子的交集中心 [x, y]；没有相交返回空数组。用来确定火花出现的位置。
static func contact_point(list_a: Array, list_b: Array) -> PackedInt32Array:
	for a: PackedInt32Array in list_a:
		for b: PackedInt32Array in list_b:
			if overlap(a, b):
				return PackedInt32Array([(maxi(a[0], b[0]) + mini(a[2], b[2])) / 2,
					(maxi(a[1], b[1]) + mini(a[3], b[3])) / 2])
	return PackedInt32Array()
