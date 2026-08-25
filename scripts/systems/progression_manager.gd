class_name ProgressionManager extends Node

const SAVE_PATH = "user://progression.cfg"

const UNLOCK_TABLE = {
	# ── Stat anchors (always available) ──────────────────────────────
	"blast_radius":      {"wave": 0, "wins": 0},
	"extra_ammo":        {"wave": 0, "wins": 0},
	"speed_boost":       {"wave": 0, "wins": 0},
	"warhead":           {"wave": 0, "wins": 0},
	# ── Behavioral primitives (early access) ─────────────────────────
	"scatter_volley":    {"wave": 0, "wins": 0},
	"homing_warhead":    {"wave": 0, "wins": 0},
	"chain_reaction":    {"wave": 1, "wins": 0},
	"pulse_wave":        {"wave": 2, "wins": 0},
	"iron_curtain":      {"wave": 2, "wins": 0},
	"kill_streak":       {"wave": 2, "wins": 0},
	# ── Synergy composites (mid-game) ─────────────────────────────────
	"amplified_scatter": {"wave": 3, "wins": 0},
	"seeking_swarm":     {"wave": 4, "wins": 0},
	"iron_cascade":      {"wave": 5, "wins": 0},
	# ── S-tier composites (late-game locked) ─────────────────────────
	"frag_chain":        {"wave": 7, "wins": 0},
	"pulse_swarm":       {"wave": 8, "wins": 0},
}

var _best_wave: int = 0
var _win_count: int = 0
var _run_count: int = 0

func _ready() -> void:
	_load()
	GameManager.game_over.connect(_on_game_over)

func _load() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_best_wave = cfg.get_value("stats", "best_wave", 0)
		_win_count = cfg.get_value("stats", "win_count", 0)
		_run_count = cfg.get_value("stats", "run_count", 0)

func _save() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("stats", "best_wave", _best_wave)
	cfg.set_value("stats", "win_count", _win_count)
	cfg.set_value("stats", "run_count", _run_count)
	cfg.save(SAVE_PATH)

func _on_game_over(_score: int, did_win: bool) -> void:
	_run_count += 1
	if GameManager.current_wave > _best_wave:
		_best_wave = GameManager.current_wave
	if did_win:
		_win_count += 1
	_save()

func get_unlocked_stems() -> Array[String]:
	var result: Array[String] = []
	for stem in UNLOCK_TABLE:
		var req = UNLOCK_TABLE[stem]
		if _best_wave >= req["wave"] and _win_count >= req["wins"]:
			result.append(stem)
	return result

func get_best_wave() -> int: return _best_wave
func get_win_count() -> int: return _win_count
func get_run_count() -> int: return _run_count
