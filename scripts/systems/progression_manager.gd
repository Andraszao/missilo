class_name ProgressionManager extends Node

const SAVE_PATH = "user://progression.cfg"

const UNLOCK_TABLE = {
	# ── Stat anchors (always available) ──────────────────────────────────────────────
	"blast_radius":      {"wave": 0, "wins": 0},
	"extra_ammo":        {"wave": 0, "wins": 0},
	"speed_boost":       {"wave": 0, "wins": 0},
	"warhead":           {"wave": 0, "wins": 0},
	# ── Behavioral primitives (early access) ──────────────────────────
	"scatter_volley":    {"wave": 0, "wins": 0},
	"homing_warhead":    {"wave": 0, "wins": 0},
	"chain_reaction":    {"wave": 1, "wins": 0},
	"pulse_wave":        {"wave": 2, "wins": 0},
	"iron_curtain":      {"wave": 2, "wins": 0},
	"kill_streak":       {"wave": 2, "wins": 0},
	# ── Synergy composites (mid-game) ─────────────────────────────────────
	"amplified_scatter": {"wave": 3, "wins": 0},
	"seeking_swarm":     {"wave": 4, "wins": 0},
	"iron_cascade":      {"wave": 5, "wins": 0},
	# ── S-tier composites (late-game locked) ────────────────────────────
	"frag_chain":        {"wave": 7, "wins": 0},
	"pulse_swarm":       {"wave": 8, "wins": 0},
}

const UNLOCK_TREE = {
	# Tier 1 — starting bonuses (always available, cheap)
	"extra_ammo":             {"cost": 50,  "requires": [],                          "tier": 1, "effect": "Start each run with +2 ammo per silo"},
	"wider_radius":           {"cost": 50,  "requires": [],                          "tier": 1, "effect": "Start with +15% explosion radius"},
	"fast_reload":            {"cost": 75,  "requires": [],                          "tier": 1, "effect": "Silos reload 20% faster between waves"},
	"reroll_charge":          {"cost": 100, "requires": [],                          "tier": 1, "effect": "Get 1 free modifier reroll per run"},
	# Tier 2 — modifier pool expansion (requires 1 tier-1 purchase)
	"unlock_pulse_swarm":     {"cost": 150, "requires": ["extra_ammo"],              "tier": 2, "effect": "Adds PULSE_SWARM to the upgrade pool"},
	"unlock_frag_chain":      {"cost": 150, "requires": ["wider_radius"],            "tier": 2, "effect": "Adds FRAG_CHAIN to the upgrade pool"},
	"unlock_iron_cascade":    {"cost": 200, "requires": ["fast_reload"],             "tier": 2, "effect": "Adds IRON_CASCADE to the upgrade pool"},
	# Tier 3 — city tech branch
	"city_shield":            {"cost": 100, "requires": [],                          "tier": 1, "effect": "Cities absorb one hit before being destroyed"},
	"city_repair_discount":   {"cost": 150, "requires": ["city_shield"],             "tier": 2, "effect": "City repairs cost 50% fewer points"},
	"extra_starting_city":    {"cost": 200, "requires": ["city_repair_discount"],    "tier": 3, "effect": "Start each run with 6 cities instead of 5"},
	# Loadout slots (P5)
	"silo_loadout_left":      {"cost": 175, "requires": ["unlock_frag_chain"],       "tier": 3, "effect": "Left silo always starts with FRAG_CHAIN"},
	"silo_loadout_center":    {"cost": 175, "requires": ["unlock_pulse_swarm"],      "tier": 3, "effect": "Center silo always starts with PULSE_SWARM"},
	"silo_loadout_right":     {"cost": 175, "requires": ["unlock_iron_cascade"],     "tier": 3, "effect": "Right silo always starts with IRON_CASCADE"},
}

## Run mutators: optional per-run rule modifiers unlocked by win count.
## Each entry maps a mutator id to its display label, description, and the
## minimum _win_count required to offer it to the player.
const MUTATOR_TABLE = {
	"double_missiles": {"label": "BLITZ",      "description": "+100% missile count, +50% salvage",          "requires_win": 1},
	"half_ammo":       {"label": "RATIONED",   "description": "50% ammo per silo, +75% salvage",            "requires_win": 1},
	"iron_city":       {"label": "IRON CITY",  "description": "Cities have 1 HP, +100% salvage",            "requires_win": 2},
	"chain_world":     {"label": "CHAIN WORLD","description": "All explosions chain once for free",          "requires_win": 3},
}

# ============================================================================
# P7 ACHIEVEMENT TABLE
# ============================================================================

const ACHIEVEMENT_TABLE = {
	"first_blood":  {"label": "First Blood",    "desc": "Destroy your first missile",  "trigger": "missiles_1",   "salvage": 25},
	"chain_killer": {"label": "Chain Killer",   "desc": "Get a chain kill",             "trigger": "chain_kill_1", "salvage": 50},
	"combo_x5":     {"label": "Combo!",         "desc": "Reach x5 combo",              "trigger": "combo_5",      "salvage": 50},
	"combo_x10":    {"label": "Destroyer",      "desc": "Reach x10 combo",             "trigger": "combo_10",     "salvage": 100},
	"wave_10":      {"label": "Veteran",        "desc": "Survive wave 10",             "trigger": "wave_10",      "salvage": 150},
	"first_win":    {"label": "Defender",       "desc": "Win your first run",          "trigger": "win_1",        "salvage": 200},
	"missiles_500": {"label": "Annihilator",    "desc": "Destroy 500 missiles total",  "trigger": "missiles_500", "salvage": 300},
	"prestige_1":   {"label": "Decommissioned", "desc": "Prestige once",               "trigger": "prestige_1",   "salvage": 500},
}

var _best_wave: int = 0
var _win_count: int = 0
var _run_count: int = 0
var _run_history: Array = []
var _salvage_points: int = 0
var _salvage_this_run: int = 0
var _purchased_nodes: Array[String] = []
var _prestige_count: int = 0
var _achievements_unlocked: Array[String] = []
var _missiles_destroyed_total: int = 0
var _peak_combo_ever: int = 0

# Per-run tracking (reset each game_over, not persisted)
var _missiles_destroyed_this_run: int = 0
var _peak_combo_this_run: int = 0

## Mutators active for the current run.  Reset to empty between runs.
## Set via set_active_mutators() before start_game() is called.
var _active_mutators: Array[String] = []

func _ready() -> void:
	_load()
	GameManager.game_over.connect(_on_game_over)
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed_meta)
	EventBus.combo_changed.connect(_on_combo_changed_meta)

func _load() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_best_wave = cfg.get_value("stats", "best_wave", 0)
		_win_count = cfg.get_value("stats", "win_count", 0)
		_run_count = cfg.get_value("stats", "run_count", 0)
		var raw = cfg.get_value("stats", "run_history", [])
		_run_history = raw
		_salvage_points = cfg.get_value("stats", "salvage_points", 0)
		_purchased_nodes = cfg.get_value("stats", "purchased_nodes", [])
		_prestige_count = cfg.get_value("stats", "prestige_count", 0)
		_achievements_unlocked = cfg.get_value("stats", "achievements_unlocked", [])
		_missiles_destroyed_total = cfg.get_value("stats", "missiles_destroyed_total", 0)
		_peak_combo_ever = cfg.get_value("stats", "peak_combo_ever", 0)

func _save() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("stats", "best_wave", _best_wave)
	cfg.set_value("stats", "win_count", _win_count)
	cfg.set_value("stats", "run_count", _run_count)
	cfg.set_value("stats", "run_history", _run_history)
	cfg.set_value("stats", "salvage_points", _salvage_points)
	cfg.set_value("stats", "purchased_nodes", _purchased_nodes)
	cfg.set_value("stats", "prestige_count", _prestige_count)
	cfg.set_value("stats", "achievements_unlocked", _achievements_unlocked)
	cfg.set_value("stats", "missiles_destroyed_total", _missiles_destroyed_total)
	cfg.set_value("stats", "peak_combo_ever", _peak_combo_ever)
	cfg.save(SAVE_PATH)

func _on_game_over(_score: int, did_win: bool) -> void:
	_run_count += 1
	var wave = GameManager.current_wave
	if wave > _best_wave:
		_best_wave = wave
	if did_win:
		_win_count += 1
	var base_salvage: int = max(1, wave) * 10 + _score / 100
	var salvage: int = int(base_salvage * get_salvage_multiplier())
	_salvage_points += salvage
	_run_history.append({
		"wave":       wave,
		"score":      _score,
		"salvage":    salvage,
		"modifiers":  [],
		"missiles":   _missiles_destroyed_this_run,
		"peak_combo": _peak_combo_this_run,
	})
	if _run_history.size() > 10:
		_run_history = _run_history.slice(_run_history.size() - 10)
	_salvage_this_run = 0
	_missiles_destroyed_this_run = 0
	_peak_combo_this_run = 0
	_active_mutators.clear()
	_check_achievements()
	_save()

func _on_enemy_destroyed_meta(_pos, _pts) -> void:
	_salvage_this_run += 1
	_missiles_destroyed_total += 1
	_missiles_destroyed_this_run += 1

func _on_combo_changed_meta(mult: int) -> void:
	if mult > _peak_combo_ever:
		_peak_combo_ever = mult
	if mult > _peak_combo_this_run:
		_peak_combo_this_run = mult
	_check_achievements()

# ============================================================================
# P7 ACHIEVEMENT LOGIC
# ============================================================================

func _check_achievements() -> void:
	_try_unlock("first_blood",  _missiles_destroyed_total >= 1)
	_try_unlock("chain_killer", false)  # triggered externally via unlock_achievement()
	_try_unlock("combo_x5",     _peak_combo_ever >= 5)
	_try_unlock("combo_x10",    _peak_combo_ever >= 10)
	_try_unlock("wave_10",      _best_wave >= 10)
	_try_unlock("first_win",    _win_count >= 1)
	_try_unlock("missiles_500", _missiles_destroyed_total >= 500)
	_try_unlock("prestige_1",   _prestige_count >= 1)

func _try_unlock(id: String, condition: bool) -> void:
	if condition and not id in _achievements_unlocked:
		_achievements_unlocked.append(id)
		_salvage_points += ACHIEVEMENT_TABLE[id]["salvage"]
		EventBus.achievement_unlocked.emit(id, ACHIEVEMENT_TABLE[id]["label"])
		_save()

func unlock_achievement(id: String) -> void:
	"""Externally trigger an achievement unlock (e.g. chain_killer from kill-streak logic)."""
	_try_unlock(id, true)

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
func get_run_history() -> Array: return _run_history.duplicate()
func get_salvage_points() -> int: return _salvage_points
func get_purchased_nodes() -> Array: return _purchased_nodes.duplicate()
func get_prestige_count() -> int: return _prestige_count
func get_peak_combo_ever() -> int: return _peak_combo_ever
func is_node_purchased(id: String) -> bool: return id in _purchased_nodes

func can_purchase_node(id: String) -> bool:
	if not id in UNLOCK_TREE: return false
	if id in _purchased_nodes: return false
	var node = UNLOCK_TREE[id]
	if _salvage_points < node["cost"]: return false
	for req in node["requires"]:
		if not req in _purchased_nodes: return false
	return true

func purchase_node(id: String) -> bool:
	if not can_purchase_node(id): return false
	_salvage_points -= UNLOCK_TREE[id]["cost"]
	_purchased_nodes.append(id)
	_save()
	return true

func get_available_nodes() -> Array[String]:
	var result: Array[String] = []
	for id in UNLOCK_TREE:
		if can_purchase_node(id): result.append(id)
	return result

func has_bonus(key: String) -> bool:
	return key in _purchased_nodes

func get_starting_ammo_bonus() -> int:
	return 2 if "extra_ammo" in _purchased_nodes else 0

func get_radius_bonus() -> float:
	return 1.15 if "wider_radius" in _purchased_nodes else 1.0

func get_city_shield() -> bool:
	return "city_shield" in _purchased_nodes

func get_starting_city_count() -> int:
	return 6 if "extra_starting_city" in _purchased_nodes else 5

func get_silo_loadout(silo_index: int) -> String:
	match silo_index:
		0: return "frag_chain" if "silo_loadout_left" in _purchased_nodes else ""
		1: return "pulse_swarm" if "silo_loadout_center" in _purchased_nodes else ""
		2: return "iron_cascade" if "silo_loadout_right" in _purchased_nodes else ""
	return ""

func get_reroll_charges() -> int:
	return 1 if "reroll_charge" in _purchased_nodes else 0

func can_prestige() -> bool:
	return _win_count >= 3 and _prestige_count < 5

func prestige() -> void:
	if not can_prestige(): return
	_purchased_nodes.clear()
	_prestige_count += 1
	_check_achievements()
	_save()

func get_prestige_radius_aura() -> float:
	return 1.0 + _prestige_count * 0.10

# ============================================================================
# P6 RUN MUTATOR API
# ============================================================================

func get_available_mutators() -> Array[String]:
	"""Return mutator ids the player has earned (requires_win <= current win count)."""
	var result: Array[String] = []
	for id in MUTATOR_TABLE:
		if _win_count >= MUTATOR_TABLE[id]["requires_win"]:
			result.append(id)
	return result

func set_active_mutators(ids: Array[String]) -> void:
	"""Set the mutators active for the upcoming run.  Call before start_game()."""
	_active_mutators = ids.duplicate()

func get_active_mutators() -> Array[String]:
	"""Return a copy of the currently active mutator id list."""
	return _active_mutators.duplicate()

func has_mutator(id: String) -> bool:
	"""True if the given mutator is active this run."""
	return id in _active_mutators

func get_salvage_multiplier() -> float:
	"""Cumulative salvage multiplier from all active mutators."""
	var mult: float = 1.0
	if has_mutator("double_missiles"): mult *= 1.5
	if has_mutator("half_ammo"):       mult *= 1.75
	if has_mutator("iron_city"):       mult *= 2.0
	return mult
