class_name Pushbox
## 推挤盒与墙。墙 = 舞台版边 ∩ 屏幕墙（随摄像机移动）。
## 墙约束的是推挤盒边缘，不是角色中心。


## 把角色限制在 [wall_left, wall_right] 之内。
static func clamp_to_walls(f: Fighter, wall_left: int, wall_right: int) -> void:
	f.x = clampi(f.x, wall_left + f.def.push_half_width, wall_right - f.def.push_half_width)


## 两人推挤盒重叠时对称推开；一方顶到墙时，剩余推力全部转给另一方。
static func resolve(a: Fighter, b: Fighter, wall_left: int, wall_right: int) -> void:
	if not _overlap_y(a, b):
		return
	var left := a
	var right := b
	if _is_left_of(b, a):
		left = b
		right = a
	var overlap := left.push_right() - right.push_left()
	if overlap <= 0:
		return

	var half := overlap / 2
	left.x -= half
	right.x += overlap - half

	var left_min := wall_left + left.def.push_half_width
	if left.x < left_min:
		right.x += left_min - left.x
		left.x = left_min
	var right_max := wall_right - right.def.push_half_width
	if right.x > right_max:
		left.x -= right.x - right_max
		right.x = right_max
		left.x = maxi(left.x, left_min)


static func _overlap_y(a: Fighter, b: Fighter) -> bool:
	return a.y < b.y + b.push_height() and b.y < a.y + a.push_height()


## 判断谁在左边。中心完全重合时按朝向决定（面朝右的在左），仍相同则保持参数顺序。
## 规则必须与 P1/P2 的身份无关，避免出现 1P 优势。
static func _is_left_of(p: Fighter, q: Fighter) -> bool:
	if p.x != q.x:
		return p.x < q.x
	return p.facing > q.facing
