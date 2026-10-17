class_name Sfx
extends Node
## 程序合成的音效（纯表现，不入存档）。启动时生成 PCM 波形，不需要音频文件。
## 每种打击声由几层叠成：
##   起音"咔"（极短的高频噪声）+ 打肉的"啪"（带通滤波噪声）+ 下沉的低频"咚"（音高快速下滑的正弦），
##   重攻击再加饱和失真和短混响尾巴；Counter 额外叠一声清脆的"叮"。
## 防御是几个不成谐波的正弦叠成的金属"锵"；出招时按强度播放挥空的"呼"（扫频带通噪声）；
## OD 发动是刀锋出鞘的"锵"，打康是结实的"啪"，超杀发动是低沉的"轰"，放出飞行道具是飞刀破空的"嗖"。
## Drive 系统：招架是清亮的金属"叮"（完美招架再叠一声"啪"），Drive Impact 发动是低沉的"轰"，撞墙 / 眩晕是重击加回响；
## 倒地有沉闷的"咚"，回合开始有"轰"、开打有出鞘声。
## 每种声音生成几个音高略有不同的版本轮流播放，连打时不会像机关枪一样完全重复。

const RATE := 44100
const VOICES := 12
const VARIANTS := 3

var _streams := {} ## 名字 -> Array[AudioStreamWAV]
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _count := 0
var _prev_state: Array[int] = [-1, -1]
var _prev_frame: Array[int] = [0, 0]
var _prev_projectiles := 0
var _prev_round := -1


func _ready() -> void:
	for v in VARIANTS:
		var p := 1.0 + (v - 1) * 0.06
		_add("hit0", _hit(0.09, 1.0 * p, 0.0))
		_add("hit1", _hit(0.14, 0.75 * p, 0.25))
		_add("hit2", _hit(0.24, 0.55 * p, 0.6))
		_add("block", _metal(0.12, [1450.0 * p, 2210.0 * p, 3170.0 * p], 0.55))
		_add("whoosh0", _whoosh(0.10, 900.0 * p, 2600.0 * p, 0.28))
		_add("whoosh1", _whoosh(0.15, 650.0 * p, 2000.0 * p, 0.34))
		_add("whoosh2", _whoosh(0.22, 420.0 * p, 1500.0 * p, 0.42))
	_add("counter", _crack(0.16))
	_add("armor", _metal(0.30, [180.0, 271.0, 397.0], 0.8))
	_add("clash", _metal(0.30, [1760.0, 2490.0, 3720.0], 0.7))
	_add("super", _boom(0.6))
	_add("ko", _hit(0.9, 0.35, 1.0))
	_add("land", _thud(0.08, 0.35))
	_add("od", _blade(0.28))
	_add("throw", _knife(0.12))
	_add("down", _thud(0.2, 0.7))
	_add("parry", _metal(0.18, [2600.0, 3900.0, 5300.0], 0.45))
	_add("di", _boom(0.45))
	_add("wall", _hit(0.45, 0.4, 1.0))
	_add("round", _boom(0.35))
	_add("fight", _blade(0.35))
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## 每推进一帧仿真后调用：播放本帧事件的声音，并给新出的招式配挥空声。
func consume(events: Array[Dictionary], sim: MatchSim = null) -> void:
	for e in events:
		match e.type:
			"hit":
				var strength: int = e.get("strength", 0)
				_play("hit%d" % strength, (3.0 if e.get("super", false) else 0.0))
				if e.get("counter", 0):
					_play("counter", -2.0)
			"block", "armor", "clash", "super", "ko", "parry":
				_play(e.type)
			"perfect_parry":
				_play("parry", 2.0)
				_play("counter", -1.0)
			"drive_impact", "drive_reversal":
				_play("di", -2.0)
			"wall_splat", "wall_bounce", "stun":
				_play("wall")
	if sim != null:
		_watch_moves(sim)
		_watch_round(sim)


## 回合开始 / 开打的提示音。
func _watch_round(sim: MatchSim) -> void:
	if sim.round_state != _prev_round and sim.versus:
		if sim.round_state == MatchSim.Round.INTRO:
			_play("round", -4.0)
		elif sim.round_state == MatchSim.Round.FIGHT:
			_play("fight", -2.0)
	_prev_round = sim.round_state


func _watch_moves(sim: MatchSim) -> void:
	for i in sim.fighters.size():
		var f := sim.fighters[i]
		var started := f.state != _prev_state[i] or f.state_frame < _prev_frame[i]
		if started and f.state_frame <= 1:
			var s := f.sd()
			if s.is_od():
				_play("od", -4.0)
			if s.is_attack() and s.kind != "throw":
				var strength := 0
				for h: Dictionary in s.hitboxes:
					strength = maxi(strength, (h.hit as HitDef).strength)
				_play("whoosh%d" % strength, -6.0)
			elif s.name in ["landing", "dash_f", "dash_b"]:
				_play("land", -8.0)
			elif s.name == "knockdown":
				_play("down", -3.0)
		_prev_state[i] = f.state
		_prev_frame[i] = f.state_frame
	# 新放出的飞行道具：飞刀破空声
	if sim.projectiles.size() > _prev_projectiles:
		_play("throw", -5.0)
	_prev_projectiles = sim.projectiles.size()


func _add(stream_name: String, s: AudioStreamWAV) -> void:
	if not _streams.has(stream_name):
		_streams[stream_name] = []
	_streams[stream_name].append(s)


func _play(stream_name: String, boost_db := 0.0) -> void:
	if not _streams.has(stream_name):
		return
	var list: Array = _streams[stream_name]
	_count += 1
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = list[_count % list.size()]
	p.volume_db = -6.0 + boost_db
	p.play()


# ---------------------------------------------------------------- 合成

## 打击声。pitch：整体音高（越小越沉）；weight：重量感（失真、混响、低频比例）。
func _hit(length: float, pitch: float, weight: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pitch * 9973.0 + weight * 31.0)
	var bp := _Svf.new(1800.0 * pitch, 2.2)
	var hp_prev := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		# 起音"咔"：前 4 毫秒的高频噪声
		var click := 0.0
		if t < 0.004:
			click = (noise - hp_prev) * (1.0 - t / 0.004) * 0.9
		hp_prev = noise
		# 打肉的"啪"：带通噪声，快速衰减
		var slap := bp.process(noise) * exp(-t * (38.0 - weight * 18.0)) * 1.4
		# 低频"咚"：音高从高快速滑到低
		var f0 := 90.0 + 260.0 * pitch * exp(-t * 32.0)
		phase += TAU * f0 / RATE
		var thump := sin(phase) * exp(-t * (22.0 - weight * 12.0)) * (0.55 + weight * 0.5)
		var v := click + slap + thump
		v = tanh(v * (1.2 + weight * 2.0)) * 0.8
		out[i] = v
	if weight > 0.3:
		_reverb(out, 0.031, 0.35 * weight)
	return _to_wav(out, 0.004)


## 金属声：不成谐波的几个正弦（高的衰减快）+ 起音噪声。
func _metal(length: float, freqs: Array, ring: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freqs[0])
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * freqs[k] * t) * exp(-t * (6.0 + k * 9.0) / ring) / (k + 1.0)
		if t < 0.006:
			v += rng.randf_range(-1.0, 1.0) * (1.0 - t / 0.006) * 0.8
		out[i] = tanh(v * 1.4) * 0.7
	_reverb(out, 0.023, 0.25)
	return _to_wav(out, 0.002)


## 挥空声：带通噪声，中心频率由低扫到高再回落，音量先升后降。
func _whoosh(length: float, f_from: float, f_to: float, gain: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f_from)
	var bp := _Svf.new(f_from, 1.6)
	for i in n:
		var x := float(i) / n
		bp.set_freq(lerpf(f_from, f_to, sin(x * PI * 0.8)))
		var env := sin(x * PI) * pow(1.0 - x, 0.6)
		out[i] = bp.process(rng.randf_range(-1.0, 1.0)) * env * gain * 2.2
	return _to_wav(out, 0.0)


## 刀锋出鞘 / 交击（OD 发动）：极短的金属起音 + 由低往高刮过的带通噪声 + 几个不成谐波、很快衰减的高频泛音，干净利落。
func _blade(length: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var bp := _Svf.new(2500.0, 3.0)
	for i in n:
		var t := float(i) / RATE
		var x := float(i) / n
		bp.set_freq(2500.0 + 5000.0 * minf(x * 3.0, 1.0))
		var scrape := bp.process(rng.randf_range(-1.0, 1.0)) * exp(-t * 16.0) * 1.3
		var ring := 0.0
		for f: float in [2930.0, 4370.0, 6110.0]:
			ring += sin(TAU * f * t) * exp(-t * (14.0 + f / 600.0))
		var click := rng.randf_range(-1.0, 1.0) * maxf(0.0, 1.0 - t / 0.003)
		out[i] = tanh((scrape + ring * 0.45 + click) * 1.3) * 0.8
	return _to_wav(out, 0.0005)


## 打康的"啪"：宽频噪声爆音 + 高通的脆响 + 很短的低频，像结实地打在身上。
func _crack(length: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var prev := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var snap := (noise - prev) * exp(-t * 90.0)
		prev = noise
		var body := noise * exp(-t * 45.0) * 0.6
		phase += TAU * (140.0 + 200.0 * exp(-t * 60.0)) / RATE
		var low := sin(phase) * exp(-t * 30.0) * 0.8
		out[i] = tanh((snap + body + low) * 1.6) * 0.85
	return _to_wav(out, 0.0005)


## 超杀发动：低沉的蓄力"轰"——低通噪声由暗到亮扫过，加一个膨胀的超低频，最后一记重击。
func _boom(length: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := float(i) / n
		lp += (rng.randf_range(-1.0, 1.0) - lp) * (0.02 + 0.25 * x * x)
		var swell := lp * sin(x * PI) * 2.2
		phase += TAU * (48.0 + 30.0 * x) / RATE
		var sub := sin(phase) * sin(x * PI) * 0.7
		out[i] = tanh((swell + sub) * 1.5) * 0.85
	_reverb(out, 0.037, 0.3)
	return _to_wav(out, 0.01)


## 飞刀出手：很短的高频破空声 + 一点刀身反光似的高音。
func _knife(length: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var bp := _Svf.new(3000.0, 2.0)
	for i in n:
		var t := float(i) / RATE
		var x := float(i) / n
		bp.set_freq(lerpf(3200.0, 6500.0, x))
		var air := bp.process(rng.randf_range(-1.0, 1.0)) * sin(x * PI) * 1.8
		var glint := sin(TAU * 5300.0 * t) * exp(-t * 40.0) * 0.25
		out[i] = (air + glint) * 0.8
	return _to_wav(out, 0.001)


## 落地 / 冲刺的脚步闷响。
func _thud(length: float, gain: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.06
		phase += TAU * (70.0 + 60.0 * exp(-t * 40.0)) / RATE
		out[i] = (lp * 1.5 + sin(phase) * 0.6) * exp(-t * 45.0) * gain
	return _to_wav(out, 0.002)


## 简单的梳状混响（加一点空间感）。
func _reverb(buf: PackedFloat32Array, delay_s: float, amount: float) -> void:
	var d := int(delay_s * RATE)
	for i in range(d, buf.size()):
		buf[i] += buf[i - d] * amount
	var d2 := int(delay_s * 1.7 * RATE)
	for i in range(d2, buf.size()):
		buf[i] += buf[i - d2] * amount * 0.6


func _to_wav(buf: PackedFloat32Array, attack_s: float) -> AudioStreamWAV:
	var n := buf.size()
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var scale := minf(1.0, 0.95 / peak)
	var attack := maxi(int(attack_s * RATE), 1)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var env := minf(1.0, float(i) / attack)
		var fade := minf(1.0, float(n - i) / (0.01 * RATE)) # 结尾淡出，避免爆音
		data.encode_s16(i * 2, int(clampf(buf[i] * scale * env * fade, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s


## 状态变量滤波器（带通）。
class _Svf:
	var low := 0.0
	var band := 0.0
	var f := 0.0
	var q := 1.0

	func _init(freq: float, resonance: float) -> void:
		q = 1.0 / resonance
		set_freq(freq)

	func set_freq(freq: float) -> void:
		f = 2.0 * sin(PI * minf(freq, RATE / 6.0) / RATE)

	func process(x: float) -> float:
		low += f * band
		var high := x - low - q * band
		band += f * high
		return band
