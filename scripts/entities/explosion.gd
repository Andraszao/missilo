extends Node3D
# Explosion: Area of effect that destroys incoming missiles
#
# Lifecycle:
# 1. Spawned at detonation point
# 2. Grows rapidly to max_radius
# 3. Holds at max_radius briefly
# 4. Shrinks back to zero
# 5. Returns to pool
#
# Collision Strategy:
# - Uses Area3D that scales with radius
# - Incoming missiles detect entry via area_entered signal
# - Only active during growth and hold phases

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var max_radius: float = 3.0
@export var growth_rate: float = 15.0  # Units per second
@export var hold_duration: float = 0.4  # Seconds to hold at max size
@export var shrink_rate: float = 8.0   # Units per second

# ============================================================================
# STATE
# ============================================================================

enum Phase { GROWING, HOLDING, SHRINKING, INACTIVE }

var current_phase: Phase = Phase.INACTIVE
var current_radius: float = 0.0
var hold_timer: float = 0.0
var chain_generation: int = 0  # 0 = player explosion, 1+ = chain reactions

# ============================================================================
# NODES
# ============================================================================

@onready var visual_mesh: MeshInstance3D = $VisualMesh
@onready var hitbox: Area3D = $Hitbox
@onready var collision_shape: CollisionShape3D = $Hitbox/CollisionShape3D

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	add_to_group("explosion")
	
	# Connect to area_entered signal to debug
	if hitbox:
		hitbox.area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	"""Explosion hit something - destroy if it's an incoming missile"""
	if area.is_in_group("incoming_missile"):
		# Get the parent IncomingMissile node and tell it what generation hit it
		var missile = area.get_parent()
		if missile and missile.has_method("set_hit_by_generation"):
			missile.set_hit_by_generation(chain_generation)
		if missile and missile.has_method("destroy"):
			missile.destroy()

func initialize(pos: Vector3) -> void:
	"""
	Setup explosion at position and begin growth.
	Called by ProjectileManager when spawning from pool.
	"""
	global_position = pos
	current_radius = 0.0
	current_phase = Phase.GROWING
	hold_timer = 0.0
	chain_generation = 0  # Default to player explosion
	
	# Reset to default size (in case it was changed)
	max_radius = 3.0  # Player missile explosions
	
	# Create unique collision shape for this explosion instance
	if collision_shape.shape is SphereShape3D:
		var new_shape = SphereShape3D.new()
		new_shape.radius = 0.1  # Start with small radius
		collision_shape.shape = new_shape
	
	# Ensure hitbox is active (deferred to avoid physics query conflicts)
	if hitbox:
		call_deferred("_enable_hitbox")
	
	_update_visuals()

func set_explosion_radius(radius: float) -> void:
	"""Set custom radius for this explosion (for chain reactions)"""
	max_radius = radius

func set_chain_generation(generation: int) -> void:
	"""Set the generation of this chain reaction"""
	chain_generation = generation

func _process(delta: float) -> void:
	"""
	Update explosion radius and phase
	"""
	match current_phase:
		Phase.GROWING:
			_process_growing(delta)
		Phase.HOLDING:
			_process_holding(delta)
		Phase.SHRINKING:
			_process_shrinking(delta)

# ============================================================================
# PHASE LOGIC
# ============================================================================

func _process_growing(delta: float) -> void:
	"""Expand explosion to max radius"""
	current_radius += growth_rate * delta
	
	if current_radius >= max_radius:
		current_radius = max_radius
		current_phase = Phase.HOLDING
		hold_timer = 0.0
	
	_update_visuals()

func _process_holding(delta: float) -> void:
	"""Hold at max radius for brief moment"""
	hold_timer += delta
	
	if hold_timer >= hold_duration:
		current_phase = Phase.SHRINKING

func _process_shrinking(delta: float) -> void:
	"""Shrink explosion back to zero"""
	current_radius -= shrink_rate * delta
	
	if current_radius <= 0.0:
		current_radius = 0.0
		current_phase = Phase.INACTIVE
		_return_to_pool()
	
	_update_visuals()

# ============================================================================
# VISUALS
# ============================================================================

func _update_visuals() -> void:
	"""Scale mesh and collision shape to match current radius"""
	# Scale visual mesh to match current radius exactly
	# The mesh sphere has radius 1.0, so scale it by current_radius
	visual_mesh.scale = Vector3.ONE * current_radius
	
	# Scale collision shape (sphere)
	if collision_shape.shape is SphereShape3D:
		collision_shape.shape.radius = current_radius
	
	# Color gradient: yellow -> orange -> red as it shrinks
	var material = visual_mesh.get_surface_override_material(0)
	if material:
		var t = 1.0 - (current_radius / max_radius)  # 0 at max, 1 at zero
		var color = Color.YELLOW.lerp(Color.ORANGE_RED, t)
		material.albedo_color = color

# ============================================================================
# POOLING
# ============================================================================

func _enable_hitbox() -> void:
	"""Enable hitbox monitoring (called deferred)"""
	if hitbox:
		hitbox.monitoring = true
		hitbox.monitorable = true

func _return_to_pool() -> void:
	"""Deactivate and return to ProjectileManager pool (or queue free in sandbox)"""
	var projectile_manager = get_node_or_null("/root/Main/ProjectileManager")
	if projectile_manager:
		projectile_manager.return_to_pool(self)
	else:
		queue_free()
