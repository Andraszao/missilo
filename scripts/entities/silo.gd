extends Node3D
# Silo: Player's missile launcher and ammo storage

@export var silo_index: int = 0
@export var max_ammo: int = 7
@export var start_ammo: int = 7

const BASE_FIRE_COOLDOWN: float = 0.25

var current_ammo: int = 0
var is_active: bool = true
var is_selected: bool = false
var _last_fire_sec: float = -9999.0
var _amplify_stack: int = 0  # incremented per enemy kill when AMPLIFY is held

@onready var mesh: MeshInstance3D = $Mesh
@onready var selection_indicator: MeshInstance3D = $SelectionIndicator
@onready var launch_point: Marker3D = $LaunchPoint
@onready var hitbox: Area3D = $Hitbox

func _ready() -> void:
	current_ammo = start_ammo
	selection_indicator.visible = false
	add_to_group("player_silo")

	EventBus.silo_selected.connect(_on_silo_selected)
	EventBus.silo_fired.connect(_on_silo_fired)
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
	GameManager.wave_cleared.connect(_on_wave_cleared)

	if hitbox:
		hitbox.add_to_group("silo")
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	if silo_index == 1:
		set_selected(true)

# ── Firing ────────────────────────────────────────────────────────────────

func fire(target: Vector3) -> bool:
	if not is_active:
		return false
	if current_ammo <= 0:
		return false

	var stats := calculate_stats()

	var now := Time.get_ticks_msec() / 1000.0
	var cooldown := BASE_FIRE_COOLDOWN / stats.get("speed_multiplier", 1.0)
	if now - _last_fire_sec < cooldown:
		return false
	_last_fire_sec = now

	var projectile_manager = get_node_or_null("/root/Main/ProjectileManager")
	if projectile_manager == null:
		push_error("Silo %d: ProjectileManager not found" % silo_index)
		return false
	projectile_manager.spawn_player_missile(launch_point.global_position, target, stats)

	current_ammo -= 1
	EventBus.silo_ammo_changed.emit(silo_index, current_ammo)
	_update_visuals()
	return true

func reload(amount: int = -1) -> void:
	if amount < 0:
		current_ammo = max_ammo
	else:
		current_ammo = min(current_ammo + amount, max_ammo)
	EventBus.silo_ammo_changed.emit(silo_index, current_ammo)
	_update_visuals()

func destroy() -> void:
	if not is_active:
		return
	is_active = false
	is_selected = false
	selection_indicator.visible = false
	_play_destruction_animation()
	print("Silo %d destroyed!" % silo_index)
	EventBus.silo_destroyed.emit(silo_index)

func _play_destruction_animation() -> void:
	var material = mesh.get_surface_override_material(0)
	if material:
		material.albedo_color = Color(0.15, 0.1, 0.1)
		material.emission_energy_multiplier = 0.0
	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.0, 0.3, 1.0), 0.4)

# ── Selection ─────────────────────────────────────────────────────────────

func set_selected(selected: bool) -> void:
	is_selected = selected
	selection_indicator.visible = selected and is_active

# ── Visuals ───────────────────────────────────────────────────────────────

func _update_visuals() -> void:
	if not is_active:
		return
	var material = mesh.get_surface_override_material(0)
	if material == null:
		return
	if current_ammo <= max_ammo * 0.3:
		material.albedo_color = Color(0.5, 0.8, 0.5)
	else:
		material.albedo_color = Color(0.0, 1.0, 0.0)

# ── Event handlers ────────────────────────────────────────────────────────

func _on_silo_selected(index: int) -> void:
	set_selected(index == silo_index)

func _on_silo_fired(index: int, target_position: Vector3) -> void:
	if index == silo_index:
		fire(target_position)

func _on_wave_cleared(wave_number: int) -> void:
	if is_active:
		reload()
	_amplify_stack = 0

func _on_enemy_destroyed(_position: Vector3, _points: int) -> void:
	if _has_amplify_modifier():
		_amplify_stack += 1

func _on_hitbox_area_entered(area: Area3D) -> void:
	if area.is_in_group("incoming_missile"):
		destroy()

# ── Upgrade system ────────────────────────────────────────────────────────

var equipped_modifiers: Array[MissileModifier] = []

func add_modifier(mod: MissileModifier) -> void:
	equipped_modifiers.append(mod)
	print("Silo %d gained: %s" % [silo_index, mod.modifier_name])
	if mod.ammo_addition != 0:
		max_ammo += mod.ammo_addition
		current_ammo += mod.ammo_addition
		print("  -> Max ammo increased to %d (current: %d)" % [max_ammo, current_ammo])
		EventBus.silo_ammo_changed.emit(silo_index, current_ammo)
	_update_visuals()

func _has_amplify_modifier() -> bool:
	for mod in equipped_modifiers:
		if mod.amplify:
			return true
	return false

func calculate_stats() -> Dictionary:
	var stats = {
		"speed": 15.0,
		"speed_multiplier": 1.0,
		"explosion_radius": 6.0,
		"behaviors": {
			"homing": 0.0,
			"split": 1,
			"chain_depth": 0,
			"pulse": 1,
			"magnetic": false,
			"amplify": false,
			"homing_frags": 0.0,
		}
	}

	for mod in equipped_modifiers:
		stats["speed"] *= mod.speed_multiplier
		stats["speed_multiplier"] *= mod.speed_multiplier
		stats["explosion_radius"] *= mod.radius_multiplier

		var b = stats["behaviors"]
		b["homing"] = max(b["homing"], mod.homing_strength)
		b["split"] = max(b["split"], mod.split_count)
		b["chain_depth"] += mod.chain_depth
		b["pulse"] = max(b["pulse"], mod.pulse_count)
		if mod.magnetic:
			b["magnetic"] = true
		if mod.amplify:
			b["amplify"] = true

		# Legacy behavior_flag compat
		if mod.behavior_flag == "chain_boost":
			b["chain_depth"] += 1

	# Compose synergies
	var b = stats["behaviors"]
	if b["homing"] > 0.0 and b["split"] > 1:
		# HOMING x SPLIT: fragments inherit partial homing
		b["homing_frags"] = b["homing"] * 0.55
	if b["homing"] > 0.0 and b["pulse"] > 1:
		# HOMING x PULSE: homing amplified by multiple windows
		b["homing"] = min(b["homing"] * 1.25, 0.92)
	if b["magnetic"] and b["chain_depth"] > 0:
		# MAGNETIC x CHAIN: density bonus grants an extra chain depth
		b["chain_depth"] += 1

	# AMPLIFY: scale radius by accumulated kill streak (resets each wave)
	if b["amplify"]:
		var bonus = 1.0 + _amplify_stack * 0.025
		stats["explosion_radius"] *= bonus

	return stats
