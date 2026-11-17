extends Node
## Fully procedural audio: every SFX is synthesised at boot into an AudioStreamWAV,
## so the shipped APK needs zero audio files. When tools/fetch_assets.sh drops a
## real sound pack into assets/external/audio/, those .ogg files take priority.

const MIX_RATE := 22050

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var sfx_bus := 0
var music_bus := 0
var _asset_dir := "res://assets/external/audio/"


func _ready() -> void:
	_setup_buses()
	_build_pool()
	_prewarm()


func _setup_buses() -> void:
	sfx_bus = _ensure_bus("SFX")
	music_bus = _ensure_bus("Music")
	_apply_volumes()


func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	return idx


func _apply_volumes() -> void:
	var s := GameState.settings
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(clampf(float(s["sfx_volume"]), 0.0, 1.0)))
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(clampf(float(s["music_volume"]), 0.0, 1.0)))


func _build_pool() -> void:
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)


func _prewarm() -> void:
	for key in _recipes().keys():
		_stream(key)


func _recipes() -> Dictionary:
	## type: noise|tone ; env: exponential decay seconds ; lp: 0..1 lowpass amount
	return {
		"gun_ar":     {"type": "noise", "dur": 0.16, "decay": 9.0, "lp": 0.35, "gain": 0.85, "punch": 90.0},
		"gun_smg":    {"type": "noise", "dur": 0.10, "decay": 13.0, "lp": 0.45, "gain": 0.70, "punch": 140.0},
		"gun_sniper": {"type": "noise", "dur": 0.42, "decay": 5.0, "lp": 0.20, "gain": 1.0, "punch": 55.0},
		"gun_lmg":    {"type": "noise", "dur": 0.18, "decay": 8.0, "lp": 0.30, "gain": 0.90, "punch": 70.0},
		"gun_shotgun":{"type": "noise", "dur": 0.30, "decay": 6.0, "lp": 0.15, "gain": 1.0, "punch": 60.0},
		"gun_pistol": {"type": "noise", "dur": 0.11, "decay": 12.0, "lp": 0.40, "gain": 0.65, "punch": 120.0},
		"hit_flesh":  {"type": "noise", "dur": 0.09, "decay": 18.0, "lp": 0.75, "gain": 0.55, "punch": 0.0},
		"hit_head":   {"type": "tone",  "dur": 0.14, "decay": 14.0, "freq": 1650.0, "gain": 0.55},
		"hit_plate":  {"type": "tone",  "dur": 0.13, "decay": 16.0, "freq": 980.0, "gain": 0.45},
		"reload":     {"type": "noise", "dur": 0.07, "decay": 22.0, "lp": 0.55, "gain": 0.4, "punch": 0.0},
		"click":      {"type": "tone",  "dur": 0.05, "decay": 30.0, "freq": 2400.0, "gain": 0.3},
		"heal":       {"type": "tone",  "dur": 0.30, "decay": 4.0, "freq": 520.0, "gain": 0.35},
		"pickup":     {"type": "tone",  "dur": 0.12, "decay": 10.0, "freq": 880.0, "gain": 0.4},
		"footstep":   {"type": "noise", "dur": 0.07, "decay": 20.0, "lp": 0.85, "gain": 0.28, "punch": 0.0},
		"zone_warn":  {"type": "tone",  "dur": 0.70, "decay": 2.5, "freq": 220.0, "gain": 0.5},
		"zone_damage":{"type": "noise", "dur": 0.20, "decay": 9.0, "lp": 0.60, "gain": 0.5, "punch": 0.0},
		"explosion":  {"type": "noise", "dur": 0.90, "decay": 3.0, "lp": 0.10, "gain": 1.0, "punch": 40.0},
		"ui":         {"type": "tone",  "dur": 0.06, "decay": 24.0, "freq": 1200.0, "gain": 0.25},
		"deploy":     {"type": "tone",  "dur": 0.90, "decay": 2.0, "freq": 180.0, "gain": 0.5},
		"victory":    {"type": "tone",  "dur": 1.20, "decay": 1.4, "freq": 440.0, "gain": 0.55},
		"defeat":     {"type": "tone",  "dur": 1.20, "decay": 1.4, "freq": 130.0, "gain": 0.55},
	}


func _stream(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	# Real asset pack wins over synthesis.
	var asset_path := _asset_dir + key + ".ogg"
	if ResourceLoader.exists(asset_path):
		var res: AudioStream = load(asset_path)
		_cache[key] = res
		return res
	var recipes := _recipes()
	if not recipes.has(key):
		return null
	var stream := _synth(recipes[key])
	_cache[key] = stream
	return stream


func _synth(recipe: Dictionary) -> AudioStreamWAV:
	var dur := float(recipe["dur"])
	var decay := float(recipe["decay"])
	var gain := float(recipe.get("gain", 0.5))
	var frames := int(dur * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(recipe))
	var lowpass := 0.0
	var lp_amount := float(recipe.get("lp", 0.5))
	var punch := float(recipe.get("punch", 0.0))
	var freq := float(recipe.get("freq", 440.0))
	for i in frames:
		var t := float(i) / float(MIX_RATE)
		var env: float = exp(-decay * t)
		var s := 0.0
		if String(recipe["type"]) == "noise":
			var n := rng.randf_range(-1.0, 1.0)
			lowpass = lerpf(lowpass, n, 1.0 - lp_amount)
			s = lowpass * env
			if punch > 0.0:
				s += sin(TAU * punch * t * (1.0 - t * 2.0)) * env * 0.6
		else:
			s = sin(TAU * freq * t * (1.0 - t * 0.4)) * env
		data[i] = s * gain
	return _to_wav(data)


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func play(key: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _stream(key)
	if stream == null:
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.4, 2.5)
	p.play()


func play_at(key: String, world_pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _stream(key)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.4, 2.5)
	p.unit_size = 12.0
	p.max_distance = 260.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(p)
	p.global_position = world_pos
	p.play()
	p.finished.connect(p.queue_free)
