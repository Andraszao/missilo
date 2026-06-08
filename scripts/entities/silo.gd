extends Node3D
# Silo: Player's missile launcher and ammo storage
#
# Each silo can fire missiles at clicked locations and has limited ammo.
# Ammo reloads between waves. Silos can be destroyed by incoming missiles.
# Modifiers can be equipped to boost stats.

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var silo_index: int = 0
@export var max_ammo: int = 10
@export var start_ammo: int = 10

# ============================================================================
# STATE
# ============================================================================

var current_ammo: int = 0
var is_active: bool = true
var is_selected: bool = false
var equipped_modifiers: Array[MissileModifier] = []

# ============================================================================
# NODES
# ============================================================================

@onready var mesh: MeshInstance3D = $Mesh
@onready var selection_indicator: MeshInstance3D = $SelectionIndicator
@onready var launch_point: Marker3D = $LaunchPoint
@onready var hitbox: Area3D = $Hitbox

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	current_ammo = start_ammo

	selection_indicator.visible = false

	EventBus.silo_selected.connect(_on_silo_selected)
	EventBus.silo_fired.connect(_on_silo_fired)
	GameManager.wave_cleared.connect(_on_wave_cleared)

	if hitbox:
		hitbox.add_to_group("silo")
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	if silo_index == 1:
		set_selected(true)

# ============================================================================
# FIRING
# ============================================================================

func fire(target: Vector3) -> bool:
	if not is_active:
		return false
	if current_ammo <= 0:
		return false

	var pm: Node = get_node_or_null("/root/Main/ProjectileManager")
	if pm == null:
		push_error("Silo %d: ProjectileManager not found at /root/Main/ProjectileManager" % silo_index)
		return false

	pm.spawn_player_missile(launch_point.global_position, target, calculate_stats())

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

# ============================================================================
# UPGRADE SYSTEM
# ============================================================================

func add_modifier(mod: MissileModifier) -> void:
	equipped_modifiers.append(mod)
	print("Silo %d gained: %s" % [silo_index, mod.modifier_name])

	if mod.ammo_addition != 0:
		max_ammo += mod.ammo_addition
		current_ammo += mod.ammo_addition
		EventBus.silo_ammo_changed.emit(silo_index, current_ammo)
		print("  → Max ammo increased to %d (current: %d)" % [max_ammo, current_ammo])

	_update_visuals()

# ============================================================================
# SELECTION
# ============================================================================

func set_selected(selected: bool) -> void:
	is_selected = selected
	selection_indicator.visible = selected and is_active

# ============================================================================
# PRIVATE IMPLEMENTATION
# ============================================================================

func calculate_stats() -> Dictionary:
	# Start from base values — do NOT seed with self.max_ammo to avoid
	# double-counting ammo_addition (add_modifier already updates max_ammo)
	var stats: Dictionary = {
		"speed": 15.0,
		"explosion_radius": 6.0,
		"behaviors": []
	}

	for mod in equipped_modifiers:
		stats.speed *= mod.speed_multiplier
		stats.explosion_radius *= mod.radius_multiplier
		if mod.behavior_flag != "":
			stats.behaviors.append({
				"flag": mod.behavior_flag,
				"params": mod.behavior_params
			})

	return stats

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

func _play_destruction_animation() -> void:
	var material = mesh.get_surface_override_material(0)
	if material:
		material.albedo_color = Color(0.15, 0.1, 0.1)
		material.emission_energy_multiplier = 0.0

	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.0, 0.3, 1.0), 0.4)

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_silo_selected(index: int) -> void:
	set_selected(index == silo_index)

func _on_silo_fired(index: int, target_position: Vector3) -> void:
	if index == silo_index:
		fire(target_position)

func _on_wave_cleared(_wave_number: int) -> void:
	if is_active:
		reload()

func _on_hitbox_area_entered(area: Area3D) -> void:
	if area.is_in_group("incoming_missile"):
		destroy()
