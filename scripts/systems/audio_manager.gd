class_name AudioManager
extends Node
# Fully procedural audio — zero audio files, everything synthesized in GDScript.
#
# Architecture:
#   - 8 pre-allocated always-playing AudioStreamGenerator slots (SFX pool)
#   - 1 dedicated music player, filled each _process frame
#   - All synthesis uses PackedVector2Array + push_frames() for zero-GC pushes
#   - Generators are created ONCE in _ready(); never recreated per-sound

const SAMPLE_RATE := 44100
const SFX_SLOTS   := 8

# SFX pool — pre-allocated, always playing, we push frames to add sounds
var _sfx: Array[AudioStreamPlayer] = []

# Continuous music player
var _music_player: AudioStreamPlayer
var _music_pb: AudioStreamGeneratorPlayback = null
var _music_enabled: bool = true

# Music oscillator state (advanced sample-by-sample in _process)
const MUSIC_BPM   := 90.0
# A natural minor scale starting at A2
const MUSIC_SCALE := [110.0, 123.47, 130.81, 146.83, 164.81, 174.61, 185.0, 220.0]
# 16-step melodic sequence (indices into MUSIC_SCALE)
const MUSIC_SEQ   := [0, 2, 4, 3, 7, 4, 2, 5, 0, 2, 4, 6, 5, 3, 2, 4]
var _beat_dur: float = 60.0 / MUSIC_BPM
var _seq_idx:  int   = 0
var _note_t:   float = 0.0   # time within the current beat
var _osc_phase: float = 0.0  # continuous oscillator phase (0–1)
var _music_vol: float = 0.0  # fades in over the first few seconds


# ── Setup ──────────────────────────────────────────────────────────────

func _ready() -> void:
	# Pre-allocate SFX pool — each slot is a 0.5 s buffer always playing silence
	for i in SFX_SLOTS:
		var gen = AudioStreamGenerator.new()
		gen.mix_rate    = SAMPLE_RATE
		gen.buffer_length = 0.5
		var p = AudioStreamPlayer.new()
		p.stream    = gen
		p.volume_db = -4.0
		add_child(p)
		p.play()
		_sfx.append(p)

	# Music player — filled every _process frame
	var mgen = AudioStreamGenerator.new()
	mgen.mix_rate     = SAMPLE_RATE
	mgen.buffer_length = 0.5
	_music_player = AudioStreamPlayer.new()
	_music_player.stream    = mgen
	_music_player.volume_db = -14.0
	add_child(_music_player)
	_music_player.play()
	_music_pb = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback

	# — Signal connections —
	EventBus.silo_fired.connect(func(_i, _t):    play_launch())
	EventBus.player_missile_detonated.connect(   _on_detonated)
	EventBus.enemy_destroyed.connect(            _on_enemy_killed)
	EventBus.city_destroyed.connect(func(_i):    play_city_hit())
	EventBus.silo_destroyed.connect(func(_i):    play_silo_hit())
	EventBus.combo_changed.connect(func(m):      if m > 1: play_combo_ping(m))
	EventBus.incoming_missile_impacted.connect(func(_p): play_impact())
	EventBus.mirv_split.connect(func(_p):        play_mirv_split())
	GameManager.wave_cleared.connect(func(_w):   play_wave_clear())
	GameManager.game_over.connect(func(_s, _w):  play_game_over())
	GameManager.game_started.connect(func():     _music_vol = 0.0)
	if EventBus.has_signal("achievement_unlocked"):
		EventBus.achievement_unlocked.connect(func(_id, _lbl): play_achievement())


# ── Music ──────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _music_pb == null or not _music_enabled:
		return
	var available := _music_pb.get_frames_available()
	if available <= 0:
		return

	# Fade music in over ~4 seconds from game start
	_music_vol = min(_music_vol + float(available) / float(SAMPLE_RATE * 4), 1.0)

	var buf := PackedVector2Array()
	buf.resize(available)

	for i in available:
		_note_t += 1.0 / SAMPLE_RATE
		if _note_t >= _beat_dur:
			_note_t -= _beat_dur
			_seq_idx = (_seq_idx + 1) % MUSIC_SEQ.size()

		var freq: float = MUSIC_SCALE[MUSIC_SEQ[_seq_idx]]
		var p: float    = _note_t / _beat_dur  # 0→1 within note

		# ADSR per note
		var env: float
		if   p < 0.04: env = p / 0.04
		elif p < 0.15: env = 1.0 - (p - 0.04) / 0.11 * 0.22
		elif p < 0.78: env = 0.78
		else:          env = 0.78 * (1.0 - (p - 0.78) / 0.22)

		_osc_phase += freq / SAMPLE_RATE
		if _osc_phase > 1.0:
			_osc_phase -= 1.0

		# Fundamental + quiet natural 5th (freq × 1.5) for warmth
		var s: float = sin(_osc_phase * TAU) * 0.72
		s += sin(_osc_phase * TAU * 1.5) * 0.14
		s *= env * 0.26 * _music_vol

		buf[i] = Vector2(s, s)

	_music_pb.push_frames(buf)


# ── Pool helpers ──────────────────────────────────────────────────────────

func _get_pb() -> AudioStreamGeneratorPlayback:
	# Find a slot with at least 50 ms of free buffer
	for p in _sfx:
		var pb := p.get_stream_playback() as AudioStreamGeneratorPlayback
		if pb and pb.get_frames_available() >= int(SAMPLE_RATE * 0.05):
			return pb
	# All busy — steal the first slot (oldest sound gets truncated)
	return _sfx[0].get_stream_playback() as AudioStreamGeneratorPlayback

func _push(pb: AudioStreamGeneratorPlayback, buf: PackedVector2Array) -> void:
	if pb:
		pb.push_frames(buf)


# ── Frame generators (pure DSP, no side effects) ───────────────────────────

func _sine_buf(freq: float, dur: float, amp: float, attack: float = 0.008, release: float = 0.0) -> PackedVector2Array:
	var n   := int(SAMPLE_RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var p: float = float(i) / n
		var env: float
		if t < attack:
			env = t / attack
		elif release > 0.0 and p > 1.0 - release:
			env = (1.0 - p) / release
		else:
			env = 1.0
		phase += freq / SAMPLE_RATE
		if phase > 1.0: phase -= 1.0
		var s: float = sin(phase * TAU) * amp * env
		buf[i] = Vector2(s, s)
	return buf

func _sweep_buf(f0: float, f1: float, dur: float, amp: float) -> PackedVector2Array:
	var n   := int(SAMPLE_RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var p: float    = float(i) / n
		var freq: float = lerp(f0, f1, p)
		var env: float  = sin(p * PI)   # bell envelope
		phase += freq / SAMPLE_RATE
		if phase > 1.0: phase -= 1.0
		var s: float = sin(phase * TAU) * amp * env
		buf[i] = Vector2(s, s)
	return buf

func _noise_buf(dur: float, amp: float, thump_hz: float = 60.0, thump_amp: float = 0.7) -> PackedVector2Array:
	var n   := int(SAMPLE_RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(n)
	var tp := 0.0  # thump oscillator phase
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var noise_env: float = exp(-t * 10.0)
		var thump_env: float = exp(-t * 22.0)
		var noise: float = randf_range(-1.0, 1.0) * noise_env * (1.0 - thump_amp)
		tp += thump_hz / SAMPLE_RATE
		var thump: float = sin(tp * TAU) * thump_env * thump_amp
		var s: float = (noise + thump) * amp
		buf[i] = Vector2(s, s)
	return buf

func _chord_buf(freqs: Array, dur: float, amp: float) -> PackedVector2Array:
	var n   := int(SAMPLE_RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(n)
	var phases := []
	for f in freqs: phases.append(0.0)
	for i in n:
		var p: float  = float(i) / n
		var env: float = sin(p * PI)
		var s: float = 0.0
		for j in freqs.size():
			phases[j] = fmod(phases[j] + freqs[j] / SAMPLE_RATE, 1.0)
			s += sin(phases[j] * TAU)
		buf[i] = Vector2(s / freqs.size() * amp * env, s / freqs.size() * amp * env)
	return buf


# ── Public SFX API ─────────────────────────────────────────────────────────

func play_launch() -> void:
	# Quick rising chirp: silo fires
	_push(_get_pb(), _sweep_buf(520.0, 1080.0, 0.09, 0.38))

func play_explosion(radius: float) -> void:
	# Thump + noise burst, scaled to explosion size
	var amp := clamp(0.55 + radius / 20.0, 0.55, 1.0)
	var dur := clamp(0.14 + radius / 60.0, 0.14, 0.30)
	_push(_get_pb(), _noise_buf(dur, amp, 52.0, 0.68))

func play_chain_explosion() -> void:
	# Chain reaction: same noise but higher thump, softer
	_push(_get_pb(), _noise_buf(0.12, 0.4, 110.0, 0.5))

func play_city_hit() -> void:
	# Heavy low thud
	_push(_get_pb(), _noise_buf(0.30, 0.92, 38.0, 0.80))

func play_silo_hit() -> void:
	# Mid thud + descending sine
	_push(_get_pb(), _noise_buf(0.22, 0.80, 58.0, 0.65))
	_push(_get_pb(), _sweep_buf(380.0, 160.0, 0.22, 0.35))

func play_impact() -> void:
	# Incoming missile hits ground
	_push(_get_pb(), _noise_buf(0.12, 0.60, 70.0, 0.55))

func play_combo_ping(mult: int) -> void:
	# Pitch rises with combo multiplier — satisfying escalation
	var freq := 550.0 + (mult - 1) * 95.0
	_push(_get_pb(), _sweep_buf(freq, freq * 1.04, 0.07, 0.28))

func play_mirv_split() -> void:
	# Three quick ascending pings — one per MIRV child
	for i in 3:
		var f := 660.0 + i * 220.0
		_push(_get_pb(), _sine_buf(f, 0.055, 0.30, 0.005, 0.3))

func play_armor_hit() -> void:
	# Metallic clang: mid-high sine + brief noise
	_push(_get_pb(), _sine_buf(880.0, 0.09, 0.45, 0.003, 0.4))
	_push(_get_pb(), _noise_buf(0.06, 0.35, 400.0, 0.3))

func play_wave_clear() -> void:
	# Ascending major arpeggio: C4 E4 G4 C5
	var notes := [261.63, 329.63, 392.0, 523.25]
	for i in notes.size():
		var pb := _get_pb()
		var buf := _sine_buf(notes[i], 0.08, 0.50, 0.005, 0.25)
		await get_tree().create_timer(i * 0.095).timeout
		_push(pb, buf)

func play_game_over() -> void:
	# Descending minor sequence: A3 F3 E3 A2
	var notes := [220.0, 174.61, 164.81, 110.0]
	for i in notes.size():
		var pb := _get_pb()
		var buf := _sine_buf(notes[i], 0.30, 0.55, 0.01, 0.4)
		await get_tree().create_timer(i * 0.30).timeout
		_push(pb, buf)

func play_achievement() -> void:
	# Short triumphant jingle: three rising notes
	for i in 3:
		var f := 523.25 * pow(1.26, i)  # major thirds
		var pb := _get_pb()
		var buf := _sine_buf(f, 0.10, 0.42, 0.005, 0.3)
		await get_tree().create_timer(i * 0.11).timeout
		_push(pb, buf)

func play_homing_launch() -> void:
	_push(_get_pb(), _sweep_buf(200.0, 600.0, 0.28, 0.22))

func play_chain_cascade() -> void:
	for freq in [800.0, 650.0, 500.0, 380.0]:
		_push(_get_pb(), _sine_buf(freq, 0.05, 0.28, 0.003, 0.3))
		await get_tree().create_timer(0.10).timeout

func play_split_pop() -> void:
	for _i in 3:
		_push(_get_pb(), _sine_buf(440.0, 0.05, 0.20, 0.003, 0.3))
		await get_tree().create_timer(0.11).timeout

func set_music_volume(v: float) -> void:
	if _music_player:
		_music_player.volume_db = linear_to_db(max(v * 0.25, 0.001))  # music is already quieter
	_music_enabled = v > 0.0


# ── Signal handlers ─────────────────────────────────────────────────────────

func _on_detonated(pos: Vector3, radius: float) -> void:
	if radius > 10.0:
		play_split_pop()
	elif radius < 4.5:
		play_chain_explosion()
	else:
		play_explosion(radius)

func _on_enemy_killed(_pos: Vector3, _pts: int) -> void:
	# Short upward tick — satisfying per-kill feedback
	_push(_get_pb(), _sweep_buf(600.0, 900.0, 0.055, 0.32))
