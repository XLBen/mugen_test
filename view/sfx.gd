class_name Sfx
extends Node
## 程序合成的占位音效（纯表现）：命中（轻/中/重）、防御、霸体、相杀、超杀、KO。
## 启动时生成 PCM 波形，避免引入音频文件；以后可以直接换成真正的音效资源。

const RATE := 22050
const VOICES := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_streams["hit0"] = _make(0.07, 900.0, 0.65, 0.5)
	_streams["hit1"] = _make(0.10, 520.0, 0.7, 0.6)
	_streams["hit2"] = _make(0.16, 260.0, 0.75, 0.75)
	_streams["block"] = _make(0.06, 1800.0, 0.25, 0.4)
	_streams["armor"] = _make(0.12, 140.0, 0.3, 0.6)
	_streams["clash"] = _make(0.09, 2400.0, 0.2, 0.45)
	_streams["super"] = _make(0.35, 180.0, 0.4, 0.5, true)
	_streams["ko"] = _make(0.5, 110.0, 0.6, 0.8)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func consume(events: Array[Dictionary]) -> void:
	for e in events:
		match e.type:
			"hit":
				_play("hit%d" % e.get("strength", 0), 2.0 if e.get("counter", 0) else 0.0)
			"block", "armor", "clash", "super", "ko":
				_play(e.type)


func _play(stream_name: String, boost_db := 0.0) -> void:
	if not _streams.has(stream_name):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[stream_name]
	p.volume_db = -8.0 + boost_db
	p.play()


## 噪声 + 下滑正弦的短促打击声。noise：噪声占比；rise：true 为上扬（超杀）。
func _make(length: float, freq: float, noise: float, punch: float, rise := false) -> AudioStreamWAV:
	var n := int(RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 1000.0 + length * 100.0)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := i / float(n)
		var env := pow(1.0 - t, 2.2) * (1.0 if t > 0.01 else t / 0.01)
		var f := freq * (1.0 + 2.0 * t if rise else 1.0 - 0.6 * t)
		phase += TAU * f / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		var v := (sin(phase) * (1.0 - noise) + lp * noise) * env * punch
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s
