extends "res://tools/screenshot.gd"
## 指定双方角色截图：-- <out.png> <p1 输入> <p2 输入> <p1 角色序号> <p2 角色序号>（序号见 training.gd 的 roster：内置角色 + 本地导入）


func _process(delta: float) -> bool:
	if _tick == 1:
		var args := OS.get_cmdline_user_args()
		for p in 2:
			if args.size() > p + 3:
				var def: FighterDef = _scene.roster[int(args[p + 3])]
				_scene.picks[p] = int(args[p + 3])
				_scene.sim.fighters[p].set_def(def)
		_scene.sim.reset()
		_scene.sim.infinite_meter = true
		_scene.view.load_sprites()
	return super(delta)
