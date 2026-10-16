class_name TrainingDummy
extends RefCounted
## 训练假人（控制 P2）：站 / 蹲 / 跳 / 玩家操作 / 录制 / 回放，可选自动防御。
## 录制时由 P1 的操作控制假人（P1 站着不动），回放时循环播放录下的输入。
## 输出的仍然是普通 InputBits，所以假人行为同样确定、可存读档重放。

enum Mode { PLAYER, STAND, CROUCH, JUMP, RECORD, PLAYBACK }
enum Guard { NONE, ALL }

const MODE_NAMES := ["player", "stand", "crouch", "jump", "record", "playback"]
const GUARD_NAMES := ["none", "all"]

var mode: int = Mode.STAND
var guard: int = Guard.NONE
var recording: Array[int] = []
var _play_index := 0


## 给出本帧双方的输入。human = [P1 手柄/键盘, P2 手柄/键盘]
func inputs_for(sim: MatchSim, human: Array[int]) -> Array[int]:
	var p1 := human[0]
	var p2 := 0
	match mode:
		Mode.PLAYER:
			p2 = human[1]
		Mode.CROUCH:
			p2 = InputBits.DOWN
		Mode.JUMP:
			p2 = InputBits.UP
		Mode.RECORD:
			p2 = human[0]
			p1 = 0
			recording.append(p2)
		Mode.PLAYBACK:
			if not recording.is_empty():
				p2 = recording[_play_index % recording.size()]
				_play_index += 1
	if guard == Guard.ALL and mode != Mode.PLAYER and mode != Mode.RECORD:
		p2 = guarded(sim, p2)
	return [p1, p2]


func cycle_mode() -> void:
	set_mode((mode + 1) % Mode.size())


func set_mode(m: int) -> void:
	mode = m
	if mode == Mode.RECORD:
		recording.clear()
	_play_index = 0


## 录制 ↔ 回放切换（录制中按下 → 开始回放；其他模式按下 → 开始录制）
func toggle_record() -> void:
	set_mode(Mode.PLAYBACK if mode == Mode.RECORD else Mode.RECORD)


## 自动防御：对手出招（或道具接近）时按住"远离对手"的方向，按招式段位决定站防 / 蹲防。
func guarded(sim: MatchSim, bits: int) -> int:
	var me := sim.fighters[1]
	var opp := sim.fighters[0]
	var s := opp.sd()
	var attacking := s.is_attack() and opp.state_frame <= s.last_active
	var projectile := false
	for p in sim.projectiles:
		if p.owner == 0:
			projectile = true
	if not attacking and not projectile and me.sd().kind != "hurt":
		return bits
	var crouch := bits & InputBits.DOWN != 0
	for h: Dictionary in s.hitboxes:
		var hd: HitDef = h.hit
		if hd.guard == HitDef.Guard.LOW:
			crouch = true
		elif hd.guard == HitDef.Guard.HIGH:
			crouch = false
	var away := InputBits.RIGHT if me.x >= opp.x else InputBits.LEFT
	return away | (InputBits.DOWN if crouch else 0)
