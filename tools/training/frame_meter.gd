class_name FrameMeter
extends RefCounted
## 帧计量条（SF6 / Strive 风格）：逐帧记录双方处于什么阶段，并自动算出最近一次攻防的有利帧。
## 只观察仿真，不影响仿真；超杀暂停和双方同时顿帧的帧不计入（与帧数据表的口径一致）。

enum Cat { IDLE, MOVE, STARTUP, ACTIVE, RECOVERY, STUN, DOWN }

const WIDTH := 100 ## 显示的帧数

var rows: Array = [[], []] ## 每名玩家最近 WIDTH 帧的 Cat
var startup: Array[int] = [0, 0] ## 最近一次出招的发生帧
var total: Array[int] = [0, 0] ## 最近一次出招的总帧数
var move_name: Array[String] = ["", ""]
var advantage := 0 ## 最近一次攻防结束后 P1 的有利帧（P2 = -advantage）
var has_advantage := false

var _t := 0
var _busy := false
var _contact := false
var _free_at: Array[int] = [-1, -1]
var _prev_state: Array[int] = [-1, -1]


func record(sim: MatchSim) -> void:
	var f := sim.fighters
	if sim.freeze > 0 or (f[0].hitstop > 0 and f[1].hitstop > 0):
		return
	_t += 1
	for i in 2:
		var row: Array = rows[i]
		row.append(categorize(f[i]))
		if row.size() > WIDTH:
			row.pop_front()
		var s := f[i].sd()
		if f[i].state != _prev_state[i] and s.is_attack():
			startup[i] = s.first_active + 1 if s.first_active >= 0 else 0
			total[i] = s.total
			move_name[i] = s.name
		_prev_state[i] = f[i].state
	_track_advantage(f)


## 双方都恢复可行动时结算：有利帧 = P2 恢复帧 - P1 恢复帧。只有发生过接触（受击/防御）才显示。
func _track_advantage(f: Array[Fighter]) -> void:
	var ctrl := [f[0].sd().ctrl, f[1].sd().ctrl]
	if not _busy:
		if ctrl[0] and ctrl[1]:
			return
		_busy = true
		_contact = false
		_free_at = [-1, -1]
	for i in 2:
		if f[i].sd().kind == "hurt":
			_contact = true
		if not ctrl[i]:
			_free_at[i] = -1
		elif _free_at[i] < 0:
			_free_at[i] = _t
	if _free_at[0] >= 0 and _free_at[1] >= 0:
		_busy = false
		if _contact:
			advantage = _free_at[1] - _free_at[0]
			has_advantage = true


static func categorize(f: Fighter) -> int:
	var s := f.sd()
	if s.ctrl:
		return Cat.IDLE
	if s.kind == "hurt":
		return Cat.DOWN if s.type == "L" or s.name == "wakeup" else Cat.STUN
	if s.is_attack():
		match s.phase_at(f.state_frame):
			StateDef.Phase.STARTUP:
				return Cat.STARTUP
			StateDef.Phase.ACTIVE:
				return Cat.ACTIVE
		return Cat.RECOVERY
	return Cat.MOVE
