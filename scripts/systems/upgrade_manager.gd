class_name UpgradeManager extends Node
# UpgradeManager: Drives the wave-end upgrade selection flow
#
# Loads all .tres modifier resources from the modifiers directory,
# presents 3 random choices after each wave, and applies the chosen
# modifier to the selected silo before advancing to the next wave.
#
# S-tier modifiers (pulse_swarm, frag_chain, iron_cascade) are excluded
# from the pool unless the matching unlock-tree node has been purchased.

var _modifier_pool: Array[MissileModifier] = []
var _wave_end_screen: WaveEndScreen  # created in _ready

func _ready() -> void:
	_load_modifier_pool()
	var screen = WaveEndScreen.new()
	get_tree().root.call_deferred("add_child", screen)
	_wave_end_screen = screen
	screen.upgrade_confirmed.connect(_on_upgrade_confirmed)
	screen.upgrade_skipped.connect(_on_upgrade_skipped)
	GameManager.upgrade_available.connect(_on_upgrade_available)

func _load_modifier_pool() -> void:
	var unlocked = ProgressionManager.get_unlocked_stems()
	var dir = DirAccess.open("res://resources/modifiers/")
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var stem = fname.get_basename()
			if stem in unlocked and _is_modifier_available(stem):
				var mod = load("res://resources/modifiers/" + fname) as MissileModifier
				if mod:
					_modifier_pool.append(mod)
		fname = dir.get_next()

## Returns false for S-tier modifiers that require an unlock-tree purchase.
## All other modifiers return true (gated only by wave/wins in UNLOCK_TABLE).
func _is_modifier_available(stem: String) -> bool:
	match stem:
		"pulse_swarm":   return ProgressionManager.is_node_purchased("unlock_pulse_swarm")
		"frag_chain":    return ProgressionManager.is_node_purchased("unlock_frag_chain")
		"iron_cascade":  return ProgressionManager.is_node_purchased("unlock_iron_cascade")
	return true  # all others always available once unlocked by wave/wins

func _on_upgrade_available(wave_number: int) -> void:
	_modifier_pool.shuffle()
	var choices: Array[MissileModifier] = []
	for i in range(min(3, _modifier_pool.size())):
		choices.append(_modifier_pool[i])
	_wave_end_screen.present_choices(wave_number, choices)

func _on_upgrade_confirmed(modifier: MissileModifier, silo_index: int) -> void:
	# Apply to the correct silo
	var silos = get_tree().get_nodes_in_group("player_silo")
	for silo in silos:
		if silo.silo_index == silo_index:
			silo.add_modifier(modifier)
			break
	GameManager.advance_when_ready()

func _on_upgrade_skipped() -> void:
	GameManager.advance_when_ready()
