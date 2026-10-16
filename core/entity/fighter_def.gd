class_name FighterDef
extends Resource
## 角色的静态数据（不会在对战中改变，不进入存档）。所有长度为逻辑单位，时间为帧。

@export var display_name := "Dummy"

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
