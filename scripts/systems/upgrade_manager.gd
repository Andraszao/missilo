extends Node
# UpgradeManager: Roguelike upgrade selection between waves
#
# Listens for GameManager.upgrade_available, presents 3 random modifier
# choices via WaveEndScreen, applies the player's selection to their chosen
# silo, then calls GameManager.advance_when_ready() to continue.
#
# Auto-advances after SELECTION_TIMEOUT seconds if no input is received.

# ============================================================================
# CONFIGURATION
# ============================================================================

const SELECTION_TIMEOUT: float = 20.0
const MODIFIER_POOL_PATH: String = "res://resources/modifiers/"
const CHOICES_PER_WAVE: int = 3

# All modifier filenames available for the roguelike pool.
# Add new .tres files here to include them in the random draw.
const MODIFIER_FILES: Array = [
	"blast_radius.tres",
	"extra_ammo.tres",
	"speed_boost.tres",
	"mega_blast.tres",
	"rapid_shot.tres",
	"veteran_loader.tres",
	"tactical_warhead.tres",
]

# ============================================================================
# STATE
# ============================================================================

var _modifier_pool: Array[MissileModifier] = []
var _wave_end_screen: Control = null
var _timeout_timer: Timer = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_load_modifier_pool()
	_setup_timeout_timer()

	GameManager.upgrade_available.connect(_on_upgrade_available)
	GameManager.game_over.connect(_on_game_over)

	# Defer screen creation so the UI CanvasLayer is fully initialized first
	call_deferred("_create_wave_end_screen")

func _load_modifier_pool() -> void:
	for filename in MODIFIER_FILES:
		var mod: MissileModifier = load(MODIFIER_POOL_PATH + filename) as MissileModifier
		if mod:
			_modifier_pool.append(mod)
		else:
			push_warning("UpgradeManager: Could not load modifier: %s" % filename)

func _create_wave_end_screen() -> void:
	# Build the screen and attach it to the UI canvas layer
	var WaveEndScreenScript = load("res://scripts/ui/wave_end_screen.gd")
	_wave_end_screen = WaveEndScreenScript.new()

	var ui_layer: Node = get_node_or_null("/root/Main/UI")
	if ui_layer:
		ui_layer.add_child(_wave_end_screen)
		_wave_end_screen.upgrade_confirmed.connect(_on_upgrade_confirmed)
		_wave_end_screen.upgrade_skipped.connect(_on_upgrade_skipped)
	else:
		push_error("UpgradeManager: Could not find /root/Main/UI canvas layer")

func _setup_timeout_timer() -> void:
	_timeout_timer = Timer.new()
	_timeout_timer.one_shot = true
	_timeout_timer.timeout.connect(_on_selection_timeout)
	add_child(_timeout_timer)

# ============================================================================
# UPGRADE FLOW
# ============================================================================

func _on_upgrade_available(wave_number: int) -> void:
	var choices: Array[MissileModifier] = _draw_random_choices()
	_wave_end_screen.present_choices(wave_number, choices)
	_timeout_timer.start(SELECTION_TIMEOUT)

func _on_upgrade_confirmed(modifier: MissileModifier, silo_index: int) -> void:
	_timeout_timer.stop()
	_apply_modifier_to_silo(modifier, silo_index)
	_wave_end_screen.hide()
	GameManager.advance_when_ready()

func _on_upgrade_skipped() -> void:
	_timeout_timer.stop()
	_wave_end_screen.hide()
	GameManager.advance_when_ready()

func _on_selection_timeout() -> void:
	_wave_end_screen.hide()
	GameManager.advance_when_ready()

func _on_game_over(_score: int, _did_win: bool) -> void:
	_timeout_timer.stop()
	if _wave_end_screen:
		_wave_end_screen.hide()

# ============================================================================
# PRIVATE HELPERS
# ============================================================================

func _draw_random_choices() -> Array[MissileModifier]:
	var pool: Array = _modifier_pool.duplicate()
	pool.shuffle()
	var choices: Array[MissileModifier] = []
	for i in range(min(CHOICES_PER_WAVE, pool.size())):
		choices.append(pool[i])
	return choices

func _apply_modifier_to_silo(modifier: MissileModifier, silo_index: int) -> void:
	var silos_container: Node = get_node_or_null("/root/Main/Silos")
	if silos_container == null:
		push_error("UpgradeManager: Could not find /root/Main/Silos")
		return

	for child in silos_container.get_children():
		if "silo_index" in child and child.silo_index == silo_index:
			if child.has_method("add_modifier"):
				child.add_modifier(modifier)
			return
