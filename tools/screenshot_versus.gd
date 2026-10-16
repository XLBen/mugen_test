extends "res://tools/screenshot.gd"
## 与 screenshot.gd 相同，但先切到对战模式（用于检查回合 HUD）。第 4 个参数：额外推进的空白帧数。


func _process(delta: float) -> bool:
	if _tick == 1:
		_scene.sim.versus = true
		_scene.sim.training = false
		_scene.sim.reset()
	return super(delta)
