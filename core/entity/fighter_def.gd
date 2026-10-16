class_name FighterDef
extends Resource
## 角色的静态数据（不会在对战中改变，不进入存档）。所有长度为逻辑单位，时间为帧。

@export var display_name := "Dummy"
## 精灵目录（含 anims.json），为空则只画白模。只给表现层用，仿真层不读。
@export_dir var sprite_dir := ""
## 招式数据脚本（提供 data() -> Dictionary）
@export var moveset: Script = preload("res://characters/shared/standard_moveset.gd")
@export var max_health := 10000

@export_group("Walk")
@export var walk_forward_speed := 450
@export var walk_back_speed := 350

@export_group("Jump")
@export var prejump_frames := 4
@export var jump_velocity := 1900
@export var jump_forward_speed := 420
@export var jump_back_speed := 380
@export var gravity := 85
@export var landing_frames := 3

@export_group("Pushbox")
@export var push_half_width := 3500
@export var stand_height := 20000
@export var crouch_height := 13000
@export var air_height := 15000

@export_group("Hurtbox (px: x, y, w, h)")
@export var stand_hurtbox := PackedInt32Array([-30, 0, 60, 185])
@export var crouch_hurtbox := PackedInt32Array([-32, 0, 64, 120])
@export var air_hurtbox := PackedInt32Array([-28, 30, 56, 140])
@export var down_hurtbox := PackedInt32Array([-60, 0, 120, 30])

var _hurt_cache := {}


## 按状态类型给出的身体受击盒（逻辑单位，相对脚底、面朝右）。
func body_hurtbox(type: String) -> Array:
	if not _hurt_cache.has(type):
		var px: PackedInt32Array
		match type:
			"C":
				px = crouch_hurtbox
			"A":
				px = air_hurtbox
			"L":
				px = down_hurtbox
			_:
				px = stand_hurtbox
		_hurt_cache[type] = [Box.from_px(Array(px))]
	return _hurt_cache[type]
