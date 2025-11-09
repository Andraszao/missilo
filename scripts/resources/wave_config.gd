class_name WaveConfig
extends Resource
# WaveConfig: Data definition for a single wave of enemies
#
# This resource defines how a wave behaves - how many missiles, how fast they spawn,
# and what data they use. Create .tres files for each wave (wave_01.tres, wave_02.tres, etc)
# and tweak values without touching code.
#
# Design Philosophy:
# - Waves escalate in difficulty through missile count, spawn rate, and speed multiplier
# - All behavior is data-driven - designer can create wave 11+ without programmer help
# - Future: Add boss waves, special events, etc by extending this resource

# Which wave this is (1-indexed, for display purposes)
@export var wave_number: int = 1

# How many missiles to spawn this wave
@export var missile_count: int = 10

# Time (in seconds) between each missile spawn
# Lower = more intense, less time to react
@export var spawn_interval: float = 0.5

# What type of missile to spawn (references a MissileData resource)
# Future: Could be an array for mixed waves
@export var missile_data: MissileData

# Multiplier applied to missile speeds
# 1.0 = base speed, 1.5 = 50% faster, etc
# Use this to escalate difficulty without creating new MissileData resources
@export var speed_multiplier: float = 1.0

# ============================================================================
# FUTURE EXPANSION HOOKS
# ============================================================================

# Future: Special wave modifiers
# Examples: "split_on_death", "shield_missiles", "cluster_spawn"
@export var special_modifiers: Array[String] = []

# Future: Target bias - prefer cities vs silos vs random
# "random", "cities", "silos", "spread"
@export var targeting_strategy: String = "random"
