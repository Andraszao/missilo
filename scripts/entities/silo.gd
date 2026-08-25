extends Node3D
# Silo: Player's missile launcher and ammo storage
#
# Each silo can fire missiles at clicked locations and has limited ammo.
# Ammo reloads between waves. Silos can be destroyed by incoming missiles.
#
# Visual Feedback:
# - Selection indicator appears when this silo is selected
# - Material darkens when low ammo or destroyed
# - Launch point marker shows where missiles spawn from

# ============================================================================
# CONFIGURATION
# ============================================================================

# Which silo this is (0 = left, 1 = center, 2 = right)
@export var silo_index: int = 0

# Maximum ammunition capacity
@export var max_ammo: int = 7

# Starting ammunition
@export var start_ammo: int = 7

# Seconds between allowed shots (Speed Boost reduces this)
const BASE_FIRE_COOLDOWN: float = 0.25

# ============================================================================
# STATE
# ============================================================================

var current_ammo: int = 0
var is_active: bool = true
var is_selected: bool = false
var _last_fire_sec: float = -9999.0  # allows immediate first shot

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
	# Initialize ammo
	current_ammo = start_ammo

	# Setup visual state
	selection_indicator.visible = false

	# Register in group so UpgradeManager can find silos
	add_to_group("player_silo")

	# Connect signals
	EventBus.silo_selected.connect(_on_silo_selected)
	EventBus.silo_fired.connect(_on_silo_fired)
	GameManager.wave_cleared.connect(_on_wave_cleared)

	# Add hitbox to group and connect for incoming missile collisions
	if hitbox:
		hitbox.add_to_group("silo")
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	# If center silo, start selected
	if silo_index == 1:
		set_selected(true)

# ============================================================================
# FIRING
# ============================================================================

func fire(target: Vector3) -> bool:
	"""
	Attempt to fire a missile at target position.
	Returns true if fired successfully, false if unable.
	"""
	if not is_active:
		return false
	if current_ammo <= 0:
		return false

	var stats := calculate_stats()

	# Cooldown enforced here so Speed/Rapid upgrades reduce time-between-shots
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
	"""
	Reload ammo. If amount is -1, fully reload to max.
	"""
	if amount < 0:
		current_ammo = max_ammo
	else:
		current_ammo = min(current_ammo + amount, max_ammo)

	EventBus.silo_ammo_changed.emit(silo_index, current_ammo)
	_update_visuals()

func destroy() -> void:
	"""
	Mark this silo as destroyed (hit by incoming missile)
	"""
	if not is_active:
		return  # Already destroyed, silently ignore
	
	is_active = false
	is_selected = false
	selection_indicator.visible = false
	
	# Visual feedback: darken and collapse
	_play_destruction_animation()
	
	print("Silo %d destroyed!" % silo_index)
	EventBus.silo_destroyed.emit(silo_index)

func _play_destruction_animation() -> void:
	"""Darken and shrink the destroyed silo"""
	var material = mesh.get_surface_override_material(0)
	if material:
		material.albedo_color = Color(0.15, 0.1, 0.1)  # Dark red/black (destroyed)
		material.emission_energy_multiplier = 0.0  # Turn off glow
	
	# Shrink down
	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.0, 0.3, 1.0), 0.4)  # Flatten

# ============================================================================
# SELECTION
# ============================================================================

func set_selected(selected: bool) -> void:
	"""
	Update visual state to show/hide selection indicator
	"""
	is_selected = selected
	selection_indicator.visible = selected and is_active

# ============================================================================
# VISUAL UPDATES
# ============================================================================

func _update_visuals() -> void:
	"""
	Update mesh material based on ammo state
	"""
	if not is_active:
		return
	
	var material = mesh.get_surface_override_material(0)
	if material == null:
		return
	
	# Low ammo warning (< 30%)
	if current_ammo <= max_ammo * 0.3:
		material.albedo_color = Color(0.5, 0.8, 0.5)  # Dimmer green
	else:
		material.albedo_color = Color(0.0, 1.0, 0.0)  # Bright green

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_silo_selected(index: int) -> void:
	"""React to silo selection change"""
	set_selected(index == silo_index)

func _on_silo_fired(index: int, target_position: Vector3) -> void:
	"""React to firing command - fire if this is the selected silo"""
	if index == silo_index:
		fire(target_position)

func _on_wave_cleared(wave_number: int) -> void:
	"""Reload ammo between waves (only if still active)"""
	if is_active:
		reload()

func _on_hitbox_area_entered(area: Area3D) -> void:
	"""Detect incoming missile collision"""
	# Only respond to incoming missiles (not explosions or other areas)
	if area.is_in_group("incoming_missile"):
		destroy()

# ============================================================================
# UPGRADE SYSTEM
# ============================================================================

# Equipped modifiers that affect this silo's missiles
var equipped_modifiers: Array[MissileModifier] = []

func add_modifier(mod: MissileModifier) -> void:
	"""Add a new modifier to this silo"""
	equipped_modifiers.append(mod)
	print("Silo %d gained: %s" % [silo_index, mod.modifier_name])
	
	# If this modifier adds ammo, update max_ammo and reload
	if mod.ammo_addition != 0:
		max_ammo += mod.ammo_addition
		current_ammo += mod.ammo_addition  # Give the ammo immediately
		print("  → Max ammo increased to %d (current: %d)" % [max_ammo, current_ammo])
		EventBus.silo_ammo_changed.emit(silo_index, current_ammo)

	_update_visuals()

func calculate_stats() -> Dictionary:
	"""
	Calculate modified stats by applying all equipped modifiers.
	Stats are calculated fresh each time to allow for dynamic changes.
	"""
	# Start with base stats
	var stats = {
		"speed": 15.0,
		"speed_multiplier": 1.0,  # tracked so fire() can compute cooldown
		"explosion_radius": 6.0,
		"behaviors": []
	}

	# Apply each modifier
	for mod in equipped_modifiers:
		stats.speed *= mod.speed_multiplier
		stats.speed_multiplier *= mod.speed_multiplier
		stats.explosion_radius *= mod.radius_multiplier
		# ammo_addition already applied in add_modifier(); skip here to avoid double-count

		if mod.behavior_flag != "":
			stats.behaviors.append({
				"flag": mod.behavior_flag,
				"params": mod.behavior_params
			})

	return stats
