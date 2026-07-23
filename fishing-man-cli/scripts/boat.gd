extends CharacterBody2D

## 2D boat: tap destination move, fuel + hull wear

signal entered_dock
signal exited_dock
signal near_spot_changed(spot: Node2D)
signal near_storm_changed(storm: Node2D)

@export var move_speed: float = 220.0
@export var turn_speed: float = 8.0
@export var fuel_per_pixel: float = 0.004
@export var wear_per_pixel: float = 0.0022
@export var arrive_distance: float = 18.0

var target_pos: Vector2 = Vector2.ZERO
var has_target: bool = false
var at_dock: bool = false
var current_spot: Node2D = null
var current_storm: Node2D = null
var fishing_locked: bool = false


func _ready() -> void:
	add_to_group("player_boat")
	target_pos = global_position


func _physics_process(delta: float) -> void:
	if fishing_locked:
		has_target = false
		velocity = Vector2.ZERO
		move_and_slide()
		Sfx.set_boat_moving(false)
		return

	if has_target:
		var to := target_pos - global_position
		var dist := to.length()
		if dist <= arrive_distance:
			has_target = false
			velocity = Vector2.ZERO
		else:
			var dir := to / dist
			rotation = lerp_angle(rotation, dir.angle() + PI * 0.5, turn_speed * delta)
			var speed := move_speed
			if GameState.boat_speed > 0.0:
				speed = GameState.boat_speed
			speed *= GameState.get_hull_speed_mul()
			if GameState.fuel <= 0.0:
				speed *= 0.25
			if GameState.boat_hull <= 0.0:
				speed *= 0.2
			var step := minf(speed * delta, dist)
			velocity = dir * speed
			if GameState.fuel > 0.0:
				GameState.consume_fuel(step * fuel_per_pixel)
			var wear := step * wear_per_pixel
			if current_storm and current_storm.has_method("get_wear_mul"):
				wear *= float(current_storm.get_wear_mul())
			GameState.apply_boat_wear(wear)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 2.0 * delta)

	move_and_slide()
	_clamp_to_bounds()
	Sfx.set_boat_moving(velocity.length() > 12.0)


func _clamp_to_bounds() -> void:
	global_position = WorldConfig.clamp_boat(global_position)
	if has_target:
		target_pos = WorldConfig.clamp_boat(target_pos)


func set_destination(world_pos: Vector2) -> void:
	target_pos = WorldConfig.clamp_water(world_pos)
	has_target = true


func clear_destination() -> void:
	has_target = false
	velocity = Vector2.ZERO


func _on_dock_area_entered(_area: Area2D) -> void:
	at_dock = true
	entered_dock.emit()


func _on_dock_area_exited(_area: Area2D) -> void:
	at_dock = false
	exited_dock.emit()


func set_near_spot(spot: Node2D) -> void:
	if current_spot == spot:
		return
	current_spot = spot
	near_spot_changed.emit(spot)


func set_near_storm(storm: Node2D) -> void:
	if current_storm == storm:
		return
	current_storm = storm
	near_storm_changed.emit(storm)
