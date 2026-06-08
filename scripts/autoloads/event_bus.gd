extends Node
# EventBus: Central nervous system for the entire game
#
# Decouples all major systems — they communicate without direct references.
# Usage: EventBus.silo_fired.emit(0, Vector3(10, 0, 10))

# ============================================================================
# SILO EVENTS
# ============================================================================

# Fired when player selects a different silo (A/W/D keys)
signal silo_selected(silo_index: int)

# Fired when a silo launches a missile
signal silo_fired(silo_index: int, target_position: Vector3)

# Fired when a silo is destroyed by incoming missile
signal silo_destroyed(silo_index: int)

# Fired whenever a silo's ammo count changes (fire, reload, modifier)
# Allows HUD and other systems to stay in sync without hardcoding values
signal silo_ammo_changed(silo_index: int, new_ammo: int)

# ============================================================================
# CITY EVENTS
# ============================================================================

# Fired when a city is destroyed by incoming missile impact
signal city_destroyed(city_index: int)

# ============================================================================
# COMBAT EVENTS
# ============================================================================

# Fired when an enemy missile is destroyed by an explosion
signal enemy_destroyed(position: Vector3, points: int)

# Fired when a player missile reaches its target and detonates
signal player_missile_detonated(position: Vector3, explosion_radius: float)

# Fired when an incoming missile reaches its target (city/silo/ground)
signal incoming_missile_impacted(position: Vector3)

# ============================================================================
# WAVE EVENTS
# ============================================================================

# Fired when all enemies in current wave are destroyed/impacted
signal wave_complete()
