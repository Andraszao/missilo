class_name AudioManager extends Node

var _sfx_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in range(4):
		var p = AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	# Connect to EventBus
	EventBus.player_missile_detonated.connect(_on_detonated)
	EventBus.enemy_destroyed.connect(_on_enemy_killed)
	EventBus.city_destroyed.connect(_on_city_lost)
	EventBus.incoming_missile_impacted.connect(_on_impact)
	GameManager.wave_cleared.connect(_on_wave_clear)

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

func _on_detonated(_pos: Vector3, radius: float) -> void:
	var p = _get_free_player()
	var freq = 120.0 - clamp(radius * 2.0, 0.0, 60.0)
	_push_sine(p, freq, 0.25, 0.9)

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
