extends Node
# EventBus: Central nervous system for the entire game
#
# This decouples all major systems so they can communicate without direct references.
# Think of it as a town square where systems shout announcements and others listen.
# 
# Why use this pattern?
# - Silo doesn't need to know GameManager exists
# - Adding new systems that react to events requires zero refactoring
# - Testing individual components becomes trivial
#
# Usage: EventBus.silo_fired.emit(0, Vector3(10, 0, 10))

# ============================================================================
# SILO EVENTS
# ============================================================================

# Fired when player selects a different silo (A/W/D keys)
# silo_index: 0 (left), 1 (center), 2 (right)
signal silo_selected(silo_index: int)

# Fired when a silo launches a missile
# silo_index: which silo fired
# target_position: where in world space the missile is headed
signal silo_fired(silo_index: int, target_position: Vector3)

# Fired when a silo is destroyed by incoming missile
# silo_index: which silo was destroyed
signal silo_destroyed(silo_index: int)

# Fired when a silo's ammo count changes (fire, reload, or modifier)
# silo_index: which silo changed
# new_ammo: the new ammo count
signal silo_ammo_changed(silo_index: int, new_ammo: int)

# ============================================================================
# CITY EVENTS
# ============================================================================

# Fired when a city is destroyed by incoming missile impact
# city_index: which city (0-5 for MVP)
signal city_destroyed(city_index: int)

# ============================================================================
# COMBAT EVENTS
# ============================================================================

# Fired when an enemy missile is destroyed by an explosion
# position: where the enemy was when killed (for effects)
# points: score value of this enemy
signal enemy_destroyed(position: Vector3, points: int)

# Fired when a player missile reaches its target and detonates
# position: detonation point (spawns explosion here)
# explosion_radius: size of explosion (modified by upgrades)
signal player_missile_detonated(position: Vector3, explosion_radius: float)

# Fired when an incoming missile reaches its target (city/silo/ground)
# position: impact point
signal incoming_missile_impacted(position: Vector3)

# Emitted when kill-streak combo multiplier changes (1 = no combo)
signal combo_changed(multiplier: int)

# ============================================================================
# WAVE EVENTS
# ============================================================================

# Fired when all enemies in current wave are destroyed/impacted
signal wave_complete()

# ============================================================================
# ACHIEVEMENT EVENTS
# ============================================================================

# Fired when an achievement is unlocked
# achievement_id: the string key from ACHIEVEMENT_TABLE
# label: human-readable display name
signal achievement_unlocked(achievement_id: String, label: String)
