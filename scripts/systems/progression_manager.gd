class_name ProgressionManager extends Node

const SAVE_PATH = "user://progression.cfg"

# Milestone unlock map: modifier filename stem -> minimum wave required or win count
const UNLOCK_TABLE = {
	"blast_radius": {"wave": 0, "wins": 0},
	"extra_ammo": {"wave": 0, "wins": 0},
	"speed_boost": {"wave": 0, "wins": 0},
	"tactical_warhead": {"wave": 5, "wins": 0},
	"mega_blast": {"wave": 7, "wins": 0},
	"rapid_shot": {"wave": 0, "wins": 1},
	"veteran_loader": {"wave": 0, "wins": 3},
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
