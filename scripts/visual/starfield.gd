extends Node3D
# Starfield: Random stars in the background for visual appeal
#
# Spawns small glowing points to make the space feel alive

@export var star_count: int = 40
@export var area_width: float = 70.0
@export var area_height: float = 45.0

func _ready() -> void:
	_generate_stars()

func _generate_stars() -> void:
	"""Create random stars in the background"""
	var star_material = load("res://materials/star_mat.tres")
	
	for i in range(star_count):
		var star = MeshInstance3D.new()
		var mesh = SphereMesh.new()
		mesh.radius = randf_range(0.1, 0.3)
		mesh.height = mesh.radius * 2.0
		
		star.mesh = mesh
		star.material_override = star_material
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		# Random position in background
		var x = randf_range(-area_width / 2.0, area_width / 2.0)
		var y = randf_range(5.0, area_height)
		var z = randf_range(-6.0, -4.0)  # Behind gameplay plane
		
		star.position = Vector3(x, y, z)
		add_child(star)

