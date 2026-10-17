class_name ComboDemo
extends RefCounted
## 连段演示：电脑操作 P1 按设计好的输入脚本打出连段（和 test_combo_routes 用同一份脚本、同样的站位），
## 用来在训练模式里检查连段的画面效果。可以只演示当前一条，也可以依次演示当前角色的全部连段。
## 纯逻辑：每帧给出双方输入，不碰场景树。

const TAIL := 160 ## 脚本打完后留给收尾（超杀暂停 + 多段命中、倒地）的帧数

var playing := false
var queue: Array[int] = [] ## 还要演示的连段下标（第一个是正在演示的）
var total := 0 ## 这次一共演示几条
var _p1: Array[int] = []
var _p2: Array[int] = []
var _frame := 0
var _pending := false ## 下一帧开始前要先布置场面


## all：依次演示全部连段；否则只演示 trial 当前选中的那条。
func start(trial: ComboTrial, all := false) -> void:
	queue = []
	if trial.combos.is_empty():
		return
	if all:
		for i in trial.combos.size():
			queue.append((trial.index + i) % trial.combos.size())
	else:
		queue.append(trial.index)
	total = queue.size()
	playing = true
	_pending = true


func stop() -> void:
	playing = false
	queue = []
	_pending = false


## 第几条（从 1 开始），给画面显示用。
func position() -> int:
	return total - queue.size() + 1


## 每帧调用，返回 [P1, P2] 输入。开始一条新连段时会重置对局并布置场面（同时让挑战跳到这一条）。
func inputs(sim: MatchSim, trial: ComboTrial) -> Array[int]:
	if not playing:
		return [0, 0]
	if _pending:
		_begin(sim, trial)
	var out: Array[int] = [_at(_p1, _frame), _at(_p2, _frame)]
	_frame += 1
	if _frame >= _p1.size() + TAIL:
		queue.pop_front()
		if queue.is_empty():
			playing = false
		else:
			_pending = true
	return out


func _begin(sim: MatchSim, trial: ComboTrial) -> void:
	_pending = false
	trial.index = queue[0]
	trial.restart()
	var c := trial.current()
	sim.reset()
	ComboTrial.prepare(sim, c)
	_p1 = InputScript.parse(ComboTrial.build_script(c))
	_p2 = InputScript.parse(c.get("p2", ""), true)
	_frame = 0


static func _at(list: Array[int], i: int) -> int:
	return list[i] if i < list.size() else 0
