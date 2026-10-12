extends RefCounted
class_name Sfx

## Sound effects. There are no audio files: each effect is synthesized once,
## at first use, into a short 16-bit mono AudioStreamWAV. Played through a
## small pool of AudioStreamPlayers kept on the scene root (it survives
## scene reloads, and is rebuilt if something frees it).
##
##   Sfx.play("swing")               # full volume
##   Sfx.play("hatch", -12.0)        # quieter, e.g. far away

const SAMPLE_RATE := 22050
const POOL_SIZE := 8
const SOUNDS := ["swing", "hit", "shot", "kick", "grab", "switch", "hatch", "death", "ring_down"]

# The pool node also holds the synthesized streams (as metadata), so they
# are freed with the scene tree at exit - a static cache would still be
# alive at Godot's exit leak check and get reported as leaked.
static var _pool: Node = null

## Synthesizes every effect (~40ms) and builds the pool, so the first
## swing doesn't stutter.
static func warm_up() -> void:
	for name in SOUNDS:
		stream(name)

static func play(sound: String, volume_db: float = 0.0) -> void:
	warm_up() # no-op once warm
	if not is_instance_valid(_pool) or not _pool.is_inside_tree():
		return
	var player: AudioStreamPlayer = null
	for p in _pool.get_children():
		if not p.playing:
			player = p
			break
	if player == null: # all busy: steal the first one
		player = _pool.get_child(0)
	player.stream = stream(sound)
	player.volume_db = volume_db
	player.play()

static func stream(sound: String) -> AudioStreamWAV:
	if not is_instance_valid(_pool):
		_build_pool()
	if not is_instance_valid(_pool): # no scene tree to cache on
		return _make(sound)
	var streams: Dictionary = _pool.get_meta("streams")
	if not streams.has(sound):
		streams[sound] = _make(sound)
	return streams[sound]

static func _build_pool() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_pool = Node.new()
	_pool.name = "SfxPool"
	_pool.set_meta("streams", {})
	_pool.process_mode = Node.PROCESS_MODE_ALWAYS # sounds while paused
	for i in range(POOL_SIZE):
		_pool.add_child(AudioStreamPlayer.new())
	tree.root.add_child(_pool)

## Stops every sound. Quitting while a sound is still playing makes
## Godot report its playback as "leaked" at exit (harmless - the process
## is ending - but noisy), so the test runner calls this before quitting.
static func stop_all() -> void:
	if is_instance_valid(_pool):
		for p in _pool.get_children():
			p.stop()

## Builds one effect from a few primitives: tone (with pitch sweep),
## filtered noise, and an exponential decay envelope.
static func _make(sound: String) -> AudioStreamWAV:
	match sound:
		"swing":     return _render(0.12, func(t, n): return _lowpass_noise(n, 0.5) * 1.2 * minf(1.0, t * 60.0) * _decay(t, 0.035))
		"hit":       return _render(0.25, func(t, n): return (_tone(t, 110.0, 50.0, 0.25) * 0.8 + n * 0.2) * _decay(t, 0.07))
		"shot":      return _render(0.15, func(t, n): return (_tone(t, 900.0, 200.0, 0.1) * 0.6 + _lowpass_noise(n, 0.6) * 0.5) * _decay(t, 0.04))
		"kick":      return _render(0.18, func(t, n): return (_tone(t, 160.0, 70.0, 0.15) * 0.7 + _lowpass_noise(n, 0.2) * 0.4) * _decay(t, 0.05))
		"grab":      return _render(0.10, func(t, n): return (_tone(t, 240.0) * 0.5 + _lowpass_noise(n, 0.3) * 0.5) * _decay(t, 0.025))
		"switch":    return _render(0.30, func(t, n): return (_tone(t, 660.0) + _tone(t, 990.0) * 0.5) * 0.5 * _decay(t, 0.08))
		"hatch":     return _render(0.50, func(t, n): return _lowpass_noise(n, 0.1) * 1.8 * minf(1.0, t * 10.0) * _decay(t, 0.18))
		"death":     return _render(0.60, func(t, n): return (_tone(t, 300.0, 40.0, 0.6) * 0.7 + _lowpass_noise(n, 0.15) * 0.6) * _decay(t, 0.25))
		"ring_down": return _render(0.80, func(t, n): return _tone(t, 220.0, 40.0, 0.8) * 0.6 * _decay(t, 0.5))
	return _render(0.05, func(t, n): return 0.0)

static var _lp_state: float = 0.0

static func _lowpass_noise(n: float, amount: float) -> float:
	_lp_state += (n - _lp_state) * amount
	return _lp_state

static func _tone(t: float, from_hz: float, to_hz: float = -1.0, sweep_seconds: float = 1.0) -> float:
	if to_hz < 0.0:
		return sin(TAU * from_hz * t)
	# Integrated linear sweep, so the pitch glides without clicks.
	var k := (to_hz - from_hz) / sweep_seconds
	return sin(TAU * (from_hz * t + 0.5 * k * t * t))

static func _decay(t: float, time_constant: float) -> float:
	return exp(-t / time_constant)

static func _render(seconds: float, sample: Callable) -> AudioStreamWAV:
	_lp_state = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1 # the same sound every time
	var count := int(seconds * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var value: float = sample.call(i / float(SAMPLE_RATE), rng.randf_range(-1.0, 1.0))
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav
