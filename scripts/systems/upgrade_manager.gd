class_name UpgradeManager extends Node
# UpgradeManager: Drives the wave-end upgrade selection flow
#
# Loads all .tres modifier resources from the modifiers directory,
# presents 3 random choices after each wave, and applies the chosen
# modifier to the selected silo before advancing to the next wave.

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
	var dir = DirAccess.open("res://resources/modifiers/")
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var mod = load("res://resources/modifiers/" + fname) as MissileModifier
			if mod:
				_modifier_pool.append(mod)
		fname = dir.get_next()

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
