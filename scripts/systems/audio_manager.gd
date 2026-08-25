class_name AudioManager extends Node

var _sfx_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in range(4):
		var p = AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	# Connect to EventBus
	EventBus.player_missile_detonated.connect(_on_detonated_sound)
	EventBus.enemy_destroyed.connect(_on_enemy_killed)
	EventBus.city_destroyed.connect(_on_city_lost)
	EventBus.incoming_missile_impacted.connect(_on_impact)
	GameManager.wave_cleared.connect(_on_wave_clear)
	EventBus.silo_fired.connect(func(_i, _t): _maybe_play_homing_sound())

func _get_free_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing: return p
	return _sfx_players[0]  # steal oldest

func _push_sine(player: AudioStreamPlayer, freq: float, duration: float, vol: float = 0.8) -> void:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = duration + 0.05
	player.stream = gen
	player.play()
	var pb = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null: return
	var frames = int(44100.0 * duration)
	for i in range(frames):
		var t = float(i) / 44100.0
		var env = clamp(1.0 - t / duration, 0.0, 1.0)
		var sample = sin(TAU * freq * t) * env * vol
		pb.push_frame(Vector2(sample, sample))

func _push_noise(player: AudioStreamPlayer, duration: float, vol: float = 0.5) -> void:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = duration + 0.05
	player.stream = gen
	player.play()
	var pb = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null: return
	var frames = int(44100.0 * duration)
	for i in range(frames):
		var t = float(i) / 44100.0
		var env = exp(-t * 10.0)
		var sample = randf_range(-1.0, 1.0) * env * vol
		pb.push_frame(Vector2(sample, sample))

# Frequency-sweep sine: accumulates phase to avoid discontinuities
func _push_sweep(player: AudioStreamPlayer, freq_start: float, freq_end: float, duration: float, vol: float = 0.8) -> void:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = duration + 0.05
	player.stream = gen
	player.play()
	var pb = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null: return
	var frames = int(44100.0 * duration)
	var phase := 0.0
	for i in range(frames):
		var t = float(i) / 44100.0
		var frac = t / duration
		var freq = lerp(freq_start, freq_end, frac)
		# Fast fade-out in last 20% of duration
		var env = clamp((1.0 - frac) / 0.2, 0.0, 1.0) if frac > 0.8 else 1.0
		phase += TAU * freq / 44100.0
		var sample = sin(phase) * env * vol
		pb.push_frame(Vector2(sample, sample))

# --- New behaviour-differentiated sounds ---

func play_homing_launch() -> void:
	# Ascending whine: 200 Hz sweeping to 600 Hz over 0.3 s
	var p = _get_free_player()
	_push_sweep(p, 200.0, 600.0, 0.3, 0.25)

func play_chain_cascade() -> void:
	# Rapid descending clicks: 4 pulses at 800/650/500/380 Hz, 50 ms each, 50 ms gap
	var freqs = [800.0, 650.0, 500.0, 380.0]
	for freq in freqs:
		var p = _get_free_player()
		_push_sine(p, freq, 0.05, 0.3)
		await get_tree().create_timer(0.1).timeout  # 50 ms tone + 50 ms gap

func play_split_pop() -> void:
	# Triple pop: 3 sine bursts at 440 Hz, 50 ms each, 60 ms gap
	for _i in range(3):
		var p = _get_free_player()
		_push_sine(p, 440.0, 0.05, 0.2)
		await get_tree().create_timer(0.11).timeout  # 50 ms tone + 60 ms gap

func play_wave_danger() -> void:
	# Pulsing warning tone at 110 Hz, 0.5 s
	var p = _get_free_player()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = 0.55
	p.stream = gen
	p.play()
	var pb = p.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null: return
	var duration = 0.5
	var frames = int(44100.0 * duration)
	for i in range(frames):
		var t = float(i) / 44100.0
		var pulse = abs(sin(t * 12.0))
		var sample = sin(TAU * 110.0 * t) * pulse * 0.4
		pb.push_frame(Vector2(sample, sample))

# --- Event handlers ---

func _on_detonated_sound(pos: Vector3, radius: float) -> void:
	if radius > 10.0:
		play_split_pop()      # large radius = split / warhead
	elif radius < 4.5:
		play_chain_cascade()  # small radius = chain-reaction follow-up
	else:
		# Normal detonation: existing explosion synthesis
		var p = _get_free_player()
		var freq = 120.0 - clamp(radius * 2.0, 0.0, 60.0)
		_push_sine(p, freq, 0.25, 0.9)

func _maybe_play_homing_sound() -> void:
	# 30% chance of homing-launch whine for variety
	if randf() < 0.3:
		play_homing_launch()

func _on_enemy_killed(_pos: Vector3, _pts: int) -> void:
	var p = _get_free_player()
	_push_sine(p, 660.0, 0.08, 0.5)

func _on_city_lost(_idx: int) -> void:
	var p = _get_free_player()
	_push_sine(p, 220.0, 0.6, 0.9)

func _on_impact(_pos: Vector3) -> void:
	var p = _get_free_player()
	_push_noise(p, 0.12, 0.7)

func _on_wave_clear(_wave: int) -> void:
	var p = _get_free_player()
	# Play ascending 4-note arp via deferred calls
	_push_sine(p, 523.0, 0.07)  # C5
	await get_tree().create_timer(0.09).timeout
	p = _get_free_player()
	_push_sine(p, 659.0, 0.07)  # E5
	await get_tree().create_timer(0.09).timeout
	p = _get_free_player()
	_push_sine(p, 784.0, 0.07)  # G5
	await get_tree().create_timer(0.09).timeout
	p = _get_free_player()
	_push_sine(p, 1047.0, 0.12) # C6
