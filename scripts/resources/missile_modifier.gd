class_name MissileModifier
extends Resource
# MissileModifier: Data structure for player missile upgrades
#
# Modifiers can boost stats (speed, radius) or add behaviors (split, spread).
# Multiple modifiers can stack on a single silo for emergent gameplay.
#
# Category Types:
# - "Stat": Multipliers and additions to base stats
# - "Behavior": Special missile behaviors (split, spread, etc.)

# ============================================================================
# BASIC INFO
# ============================================================================

@export var modifier_name: String = "Speed Boost"
@export_multiline var description: String = "+50% missile speed"
@export_enum("Stat", "Behavior") var category: String = "Stat"

# ============================================================================
# STAT MODIFIERS (Multiplicative)
# ============================================================================

# Speed multiplier (1.0 = normal, 1.5 = +50% faster)
@export var speed_multiplier: float = 1.0

# Explosion radius multiplier (1.0 = normal, 1.3 = +30% bigger)
@export var radius_multiplier: float = 1.0

# ============================================================================
# STAT MODIFIERS (Additive)
# ============================================================================

# Ammo addition (added to max_ammo)
@export var ammo_addition: int = 0

# ============================================================================
# BEHAVIOR FLAGS
# ============================================================================

# Behavior identifier (empty = none, "split" = recursive split, etc.)
@export var behavior_flag: String = ""

# Behavior parameters (stored as JSON string for flexibility)
@export var behavior_params: String = "{}"

