extends Node3D
# Sandbox Reticle: Shows aim point in test environment

@onready var sandbox: Node = get_parent()
@onready var ring: MeshInstance3D = MeshInstance3D.new()

func _ready() -> void:
	# Create visual ring
	var torus = TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.6
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = Color(0.8, 1, 1)
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	ring.mesh = torus
	ring.material_override = material
	ring.rotation.x = -PI / 2  # Lay flat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	add_child(ring)

func _process(_delta: float) -> void:
	"""Keep the reticle glued to the sandbox aim point."""
	if sandbox:
		global_position = sandbox.mouse_world_position
		# Lift ever so slightly so the ring doesn't z-fight with the ground.
		global_position.z = 0.2

