extends Node

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	_streams["pop"] = _wav(_pop_samples(), false)
	_streams["whoosh"] = _wav(_whoosh_samples(), false)
	_streams["ding"] = _wav(_ding_samples(), false)
	_streams["cheer"] = _wav(_cheer_samples(), false)
	_streams["thud"] = _wav(_thud_samples(), false)
	_streams["music"] = _wav(_music_samples(), true)
	for _i in 10:
		var player := AudioStreamPlayer.new()
		player.volume_db = -4.0
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -18.0
	_music.stream = _streams["music"]
	add_child(_music)
	_music.play()


func _exit_tree() -> void:
	if _music != null:
		_music.stop()
		_music.stream = null
	for player in _players:
		player.stop()
		player.stream = null
	_streams.clear()


func play(sound_name: String) -> void:
	var stream: AudioStream = _streams.get(sound_name)
	if stream == null:
		return
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	_players[0].stream = stream
	_players[0].play()


func _wav(samples: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = _pcm16(samples)
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


func _pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size() * 2)
	for i in samples.size():
		var s := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		out[i * 2] = s & 255
		out[i * 2 + 1] = (s >> 8) & 255
	return out


func _tone(freq: float, seconds: float, decay: float, gain: float, rate: int) -> PackedFloat32Array:
	var n := int(rate * seconds)
	var data := PackedFloat32Array()
	data.resize(n)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * decay)
		data[i] = sin(TAU * freq * t) * env * gain
	return data


func _mix(into: PackedFloat32Array, extra: PackedFloat32Array, at: int) -> void:
	for i in extra.size():
		var idx := at + i
		if idx >= into.size():
			break
		into[idx] = clampf(into[idx] + extra[i], -1.0, 1.0)


func _pop_samples() -> PackedFloat32Array:
	var rate := 22050
	var n := int(rate * 0.16)
	var data := PackedFloat32Array()
	data.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1402
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 26.0)
		var freq := 680.0 - t * 2400.0
		var s := sin(TAU * freq * t) * 0.75 + sin(TAU * freq * 1.9 * t) * 0.15
		s += rng.randf_range(-1.0, 1.0) * 0.35 * env
		data[i] = clampf(s * env * 0.85, -1.0, 1.0)
	return data


func _whoosh_samples() -> PackedFloat32Array:
	var rate := 22050
	var n := int(rate * 0.22)
	var data := PackedFloat32Array()
	data.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in n:
		var t := float(i) / float(rate)
		var env := sin(PI * clampf(t / 0.22, 0.0, 1.0))
		var noise := rng.randf_range(-1.0, 1.0)
		var tone := sin(TAU * (180.0 + t * 420.0) * t)
		data[i] = clampf((noise * 0.55 + tone * 0.25) * env * 0.55, -1.0, 1.0)
	return data


func _ding_samples() -> PackedFloat32Array:
	var rate := 22050
	var data := _tone(880.0, 0.28, 7.0, 0.32, rate)
	_mix(data, _tone(1320.0, 0.22, 8.0, 0.18, rate), 0)
	return data


func _thud_samples() -> PackedFloat32Array:
	return _tone(140.0, 0.18, 18.0, 0.5, 22050)


func _cheer_samples() -> PackedFloat32Array:
	var rate := 22050
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	var data := PackedFloat32Array()
	data.resize(int(rate * 0.72))
	for n in notes.size():
		_mix(data, _tone(notes[n], 0.2, 6.5, 0.28, rate), int(rate * 0.12 * n))
	return data


func _music_samples() -> PackedFloat32Array:
	var rate := 22050
	var notes: Array[float] = [523.25, 659.25, 783.99, 880.0, 783.99, 659.25, 587.33, 659.25]
	var step := int(rate * 0.28)
	var data := PackedFloat32Array()
	data.resize(step * notes.size())
	for n in notes.size():
		_mix(data, _tone(notes[n], 0.26, 8.0, 0.16, rate), step * n)
	return data
