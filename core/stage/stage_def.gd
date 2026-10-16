class_name StageDef
extends Resource
## 舞台的静态数据。舞台左右边界即"版边"，与随摄像机移动的屏幕墙是两回事。

@export var display_name := "Training"
@export var half_width := 120000 ## 舞台中心到版边的距离（逻辑单位）
@export var start_offset := 15000 ## 开局时两人到舞台中心的距离
