class_name MissileData
extends Resource
# MissileData: Defines characteristics of a missile type
#
# This resource defines how an incoming missile behaves and looks.
# Create different .tres files for different enemy types (basic, fast, armored, etc)
#
# Design Philosophy:
# - Separation of data from behavior
# - Future missile types can be added by creating new .tres files
# - Special behaviors hook into code via string identifiers (extensible)

# How fast this missile moves (units per second)
@export var speed: float = 3.0

# How many points the player gets for destroying this missile
@export var points_value: int = 25

# Color of the missile mesh (for visual variety)
@export var mesh_color: Color = Color.RED

# Color of the trail effect
@export var trail_color: Color = Color.ORANGE

# ============================================================================
# FUTURE EXPANSION HOOKS
# ============================================================================

# Special behaviors that modify missile logic
# "none" = standard missile
# Future examples:
#   "split" - splits into 2-3 missiles mid-flight
#   "cluster" - spawns multiple on death
#   "evasive" - changes direction to avoid explosions
#   "armored" - requires 2 explosion hits to destroy
@export var special_behavior: String = "none"

# Health for future armored missiles
# MVP: All missiles have 1 HP (instant death)
@export var health: int = 1

# Future: Explosion radius if missile reaches target
# Could make some missiles more dangerous on impact
@export var impact_radius: float = 0.0
