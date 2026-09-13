class_name MissileModifier
extends Resource
# MissileModifier: Data structure for player missile upgrades
#
# Each modifier grants behavioral primitives that compose with other modifiers
# to create emergent synergies. Six behaviors can be mixed: HOMING, SPLIT,
# CHAIN, PULSE, MAGNETIC, AMPLIFY.

@export var modifier_name: String = "Speed Boost"
@export_multiline var description: String = "+50% missile speed"
@export_enum("Stat", "Behavior") var category: String = "Stat"

# ── Stat modifiers ────────────────────────────────────────────────────────
@export var speed_multiplier: float = 1.0
@export var radius_multiplier: float = 1.0
@export var ammo_addition: int = 0

# ── Legacy behavior flag (retained for backward compatibility) ────────────
@export var behavior_flag: String = ""
@export var behavior_params: String = "{}"

# ── Behavioral primitives ─────────────────────────────────────────────────
# HOMING: missile self-corrects toward nearest incoming threat during flight
@export_range(0.0, 1.0, 0.05) var homing_strength: float = 0.0

# SPLIT: detonation creates N simultaneous coverage zones (fragment explosions)
@export_range(1, 4) var split_count: int = 1

# CHAIN: a confirmed kill triggers a free secondary explosion at 62% radius
@export_range(0, 3) var chain_depth: int = 0

# PULSE: N detonation windows per shot, staggered 0.45 s apart
@export_range(1, 4) var pulse_count: int = 1

# MAGNETIC: widens explosion hitbox to 1.35x radius during hold phase
@export var magnetic: bool = false

# AMPLIFY: each wave kill increases next-shot radius by 2.5% (resets per wave)
@export var amplify: bool = false
