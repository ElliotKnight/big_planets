class_name Sfx
extends Node
## Sound effects synthesised at startup (sine/triangle/saw tones and filtered
## noise), so there are no audio assets and nothing to license.

static var inst: Sfx = null
const RATE := 22050

var enabled := true
var _streams: Dictionary = {}
var _players: Array = []
var _idx := 0


func _ready() -> void:
	inst = self
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_all()


static func play(name: String, pitch: float = 1.0, volume_db: float = -4.0) -> void:
	if inst == null or not inst.enabled or not inst._streams.has(name):
		return
	var p: AudioStreamPlayer = inst._players[inst._idx]
	inst._idx = (inst._idx + 1) % inst._players.size()
	p.stream = inst._streams[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


# ---------------------------------------------------------------- synthesis

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s


## Tone sweeping from f0 to f1 over dur seconds. kind: sine, tri, saw, square.
func _tone(f0: float, f1: float, dur: float, kind: String = "sine", gain: float = 0.3, attack: float = 0.005, decay: float = 2.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var f := f0 * pow(f1 / f0, k)
		phase += f / RATE
		var x := fmod(phase, 1.0)
		var v := 0.0
		match kind:
			"tri": v = 4.0 * absf(x - 0.5) - 1.0
			"saw": v = 2.0 * x - 1.0
			"square": v = 1.0 if x < 0.5 else -1.0
			_: v = sin(x * TAU)
		var env := minf(1.0, t / attack) * pow(1.0 - k, decay)
		out[i] = v * env * gain
	return out


func _noise(dur: float, gain: float = 0.3, lowpass: float = 0.2, attack: float = 0.005, decay: float = 2.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in n:
		var t := float(i) / RATE
		y += lowpass * (rng.randf_range(-1.0, 1.0) - y)
		var env := minf(1.0, t / attack) * pow(1.0 - t / dur, decay)
		out[i] = y * env * gain
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	# parts: [[samples, start_seconds], ...]
	var total := 0
	for p in parts:
		total = maxi(total, int(p[1] * RATE) + p[0].size())
	var out := PackedFloat32Array()
	out.resize(total)
	out.fill(0.0)
	for p in parts:
		var off := int(p[1] * RATE)
		var s: PackedFloat32Array = p[0]
		for i in s.size():
			out[off + i] += s[i]
	return out


func _build_all() -> void:
	_streams["select"] = _wav(_tone(880, 880, 0.07, "sine", 0.3, 0.003, 3.0))
	_streams["move"] = _wav(_mix([
		[_noise(0.08, 0.35, 0.12), 0.0], [_tone(220, 110, 0.1, "sine", 0.3), 0.0],
		[_noise(0.08, 0.3, 0.12), 0.1], [_tone(200, 100, 0.1, "sine", 0.25), 0.1],
	]))
	_streams["hit"] = _wav(_mix([[_noise(0.2, 0.7, 0.35), 0.0], [_tone(180, 50, 0.2, "sine", 0.5), 0.0]]))
	_streams["death"] = _wav(_mix([[_tone(700, 110, 0.45, "saw", 0.25, 0.005, 1.5), 0.0], [_noise(0.35, 0.3, 0.15), 0.02]]))
	_streams["capture"] = _wav(_mix([
		[_tone(523, 523, 0.3, "tri", 0.25), 0.0], [_tone(659, 659, 0.3, "tri", 0.25), 0.1],
		[_tone(784, 784, 0.35, "tri", 0.25), 0.2], [_tone(1047, 1047, 0.6, "tri", 0.3, 0.005, 1.5), 0.3],
		[_tone(2093, 2093, 0.6, "sine", 0.08, 0.005, 1.5), 0.3],
	]))
	_streams["levelup"] = _wav(_mix([
		[_tone(880, 880, 0.5, "sine", 0.28, 0.005, 1.6), 0.0], [_tone(1109, 1109, 0.5, "sine", 0.26, 0.005, 1.6), 0.12],
		[_tone(1319, 1319, 0.7, "sine", 0.3, 0.005, 1.4), 0.24], [_tone(2637, 2637, 0.7, "sine", 0.07, 0.005, 1.4), 0.24],
	]))
	var sparkle: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 8:
		var f: float = [1319.0, 1568.0, 1760.0, 2093.0, 2349.0][rng.randi_range(0, 4)]
		sparkle.append([_tone(f, f, 0.14, "sine", 0.18, 0.003, 3.0), i * 0.045])
	_streams["research"] = _wav(_mix(sparkle))
	_streams["star"] = _wav(_mix([[_tone(1300, 1250, 0.16, "sine", 0.32, 0.002, 4.0), 0.0], [_tone(2600, 2500, 0.1, "sine", 0.08, 0.002, 4.0), 0.0]]))
	_streams["turn"] = _wav(_noise(0.4, 0.28, 0.08, 0.12, 1.2))
	_streams["error"] = _wav(_tone(140, 130, 0.18, "square", 0.18, 0.005, 1.2))
	_streams["pop"] = _wav(_tone(320, 760, 0.13, "sine", 0.32, 0.003, 2.0))
	_streams["spawn"] = _wav(_mix([[_tone(220, 640, 0.13, "tri", 0.28, 0.003, 0.4), 0.0], [_tone(640, 380, 0.18, "tri", 0.28, 0.003, 2.0), 0.13]]))
	_streams["glow"] = _wav(_mix([[_tone(440, 880, 0.5, "sine", 0.18, 0.05, 1.5), 0.0], [_tone(660, 1320, 0.5, "sine", 0.1, 0.05, 1.5), 0.05]]))
