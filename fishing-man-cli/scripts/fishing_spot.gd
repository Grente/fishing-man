extends Node2D

## Fishing hotspot / ambient school: fish leap out from under the surface

@export var zone: String = "near"
@export var radius: float = 110.0
@export var catchable: bool = true
@export var school_size: String = "normal" ## normal | small

var _players_near: int = 0
var _school: Node2D
## Each entry: node, base_x, base_y, phase, leap_cd, busy, facing, base_scale
var _fishes: Array = []


func build_visual() -> void:
	if catchable:
		add_to_group("fishing_spots")
	else:
		add_to_group("ambient_schools")
	_school = Node2D.new()
	_school.name = "School"
	add_child(_school)
	_spawn_school()
	if catchable:
		_setup_area()
	set_process(true)


func _spawn_school() -> void:
	_fishes.clear()
	var count := 4
	var spread_x := 42.0
	var spread_y := 28.0
	var scale_mul := 1.0
	if school_size == "small":
		count = 3
		spread_x = 28.0
		spread_y = 18.0
		scale_mul = 0.55
		match zone:
			"mid":
				count = 4
			"far":
				count = 4
	else:
		match zone:
			"mid":
				count = 5
			"far":
				count = 6
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(global_position) + zone + school_size)
	for i in count:
		var fish: Node2D = _make_fish(rng, scale_mul)
		var bx: float = rng.randf_range(-spread_x, spread_x)
		var by: float = rng.randf_range(-spread_y, spread_y)
		fish.position = Vector2(bx, by + 10.0)
		fish.modulate.a = 0.0
		fish.scale.y = absf(fish.scale.x) * 0.35
		_school.add_child(fish)
		_fishes.append({
			"node": fish,
			"base_x": bx,
			"base_y": by,
			"phase": rng.randf() * TAU,
			"leap_cd": rng.randf_range(1.5, 5.5),
			"busy": false,
			"facing": -1.0 if rng.randf() < 0.5 else 1.0,
			"base_scale": float(fish.scale.x),
		})


func _make_fish(rng: RandomNumberGenerator, scale_mul: float) -> Node2D:
	var root := Node2D.new()
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-10, 0),
		Vector2(-4, -4),
		Vector2(6, -3),
		Vector2(11, 0),
		Vector2(6, 3),
		Vector2(-4, 4),
	])
	body.color = _fish_color(rng)
	root.add_child(body)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([
		Vector2(-10, 0),
		Vector2(-16, -5),
		Vector2(-14, 0),
		Vector2(-16, 5),
	])
	tail.color = body.color.darkened(0.12)
	root.add_child(tail)
	var eye := Polygon2D.new()
	eye.polygon = PackedVector2Array([
		Vector2(5, -1),
		Vector2(7, -1),
		Vector2(7, 1),
		Vector2(5, 1),
	])
	eye.color = Color(0.08, 0.1, 0.12, 0.9)
	root.add_child(eye)
	var s: float = rng.randf_range(0.75, 1.15) * scale_mul
	root.scale = Vector2(s, s)
	return root


func _fish_color(rng: RandomNumberGenerator) -> Color:
	if school_size == "small":
		match zone:
			"far":
				return [Color("7EB6FF"), Color("B09CFF"), Color("8FD4D2")][rng.randi() % 3]
			"mid":
				return [Color("FFC89A"), Color("F5D98A"), Color("7BC9BC")][rng.randi() % 3]
			_:
				return [Color("E4F4F2"), Color("B8DFF0"), Color("FFE29A")][rng.randi() % 3]
	match zone:
		"far":
			return [Color("3A86FF"), Color("8338EC"), Color("5BC0BE")][rng.randi() % 3]
		"mid":
			return [Color("F4A261"), Color("E9C46A"), Color("2A9D8F")][rng.randi() % 3]
		_:
			return [Color("CFE8E6"), Color("8ECAE6"), Color("FFD166")][rng.randi() % 3]


func _setup_area() -> void:
	var area := Area2D.new()
	area.name = "SpotArea"
	area.monitoring = true
	area.collision_layer = 0
	area.collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _busy_count() -> int:
	var n := 0
	for item in _fishes:
		if bool(item.get("busy", false)):
			n += 1
	return n


func _fish_node(item: Dictionary) -> Node2D:
	var n: Variant = item.get("node", null)
	if n == null:
		return null
	if not is_instance_valid(n):
		return null
	return n as Node2D


func _process(delta: float) -> void:
	if _school == null or not is_instance_valid(_school):
		return
	## Allow a random burst of concurrent leaps (not capped at 2)
	var school_n: int = maxi(1, _fishes.size())
	var max_busy: int = 1
	if school_size == "small":
		max_busy = randi_range(1, mini(3, school_n))
	else:
		max_busy = randi_range(2, mini(school_n, 5))
	for item in _fishes:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if bool(item.get("busy", false)):
			continue
		var node: Node2D = _fish_node(item)
		if node == null:
			continue
		var phase: float = float(item.get("phase", 0.0)) + delta * 1.4
		item["phase"] = phase
		item["leap_cd"] = float(item.get("leap_cd", 0.0)) - delta
		var bx: float = float(item.get("base_x", 0.0))
		var by: float = float(item.get("base_y", 0.0))
		var under: Vector2 = Vector2(bx + cos(phase) * 1.5, by + 9.0 + sin(phase * 0.8) * 1.2)
		node.position = under
		node.modulate.a = 0.0
		var facing: float = float(item.get("facing", 1.0))
		var base_scale: float = float(item.get("base_scale", 1.0))
		node.scale = Vector2(absf(base_scale) * facing, absf(base_scale) * 0.3)
		if float(item.get("leap_cd", 0.0)) <= 0.0 and _busy_count() < max_busy:
			_start_surface_leap(item)


func _start_surface_leap(item: Dictionary) -> void:
	var node: Node2D = _fish_node(item)
	if node == null:
		return
	item["busy"] = true
	var bx: float = float(item.get("base_x", 0.0))
	var by: float = float(item.get("base_y", 0.0))
	var facing: float = float(item.get("facing", 1.0))
	var base_scale: float = float(item.get("base_scale", 1.0))
	var next_cd: float = randf_range(2.0, 5.5)
	var jump_h: float = 26.0 + randf() * 16.0
	var land_x: float = 16.0
	if school_size == "small":
		next_cd = randf_range(1.8, 4.8)
		jump_h = 16.0 + randf() * 10.0
		land_x = 10.0
	## Chance of a quicker follow-up leap so schools feel livelier
	if randf() < 0.28:
		next_cd *= 0.45
	var base := Vector2(bx, by)
	var peak := base + Vector2(facing * 6.0, -jump_h)
	var land := base + Vector2(facing * land_x, randf_range(-3.0, 3.0))
	item["base_x"] = land.x
	item["base_y"] = land.y

	_spawn_droplet(base)
	node.position = base + Vector2(0, 12)
	node.modulate.a = 0.0
	node.rotation = facing * 0.4
	node.scale = Vector2(absf(base_scale) * facing, absf(base_scale) * 0.25)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(node, "position", peak, 0.22).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "scale", Vector2(absf(base_scale) * facing, absf(base_scale)), 0.16)
	tween.parallel().tween_property(node, "rotation", facing * -0.55, 0.22)
	tween.tween_property(node, "position", land + Vector2(0, 11), 0.20).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(node, "rotation", facing * 0.35, 0.18)
	tween.parallel().tween_property(node, "scale:y", absf(base_scale) * 0.28, 0.18)
	tween.tween_callback(func():
		if not is_instance_valid(node):
			item["busy"] = false
			return
		_splash(land)
		node.modulate.a = 0.0
		item["busy"] = false
		item["leap_cd"] = next_cd
		item["facing"] = -facing if randf() < 0.4 else facing
	)


func _spawn_droplet(at: Vector2) -> void:
	if _school == null or not is_instance_valid(_school):
		return
	var ring := Node2D.new()
	ring.position = at + Vector2(0, 2)
	_school.add_child(ring)
	var poly := Polygon2D.new()
	poly.color = Color(0.85, 0.95, 1.0, 0.55)
	ring.add_child(poly)
	var tween := create_tween()
	tween.tween_method(func(t: float):
		if not is_instance_valid(poly):
			return
		var r: float = 2.0 + t * 10.0
		poly.polygon = PackedVector2Array([
			Vector2(-r, 0),
			Vector2(-r * 0.4, -r * 0.45),
			Vector2(r * 0.4, -r * 0.45),
			Vector2(r, 0),
			Vector2(r * 0.35, r * 0.2),
			Vector2(-r * 0.35, r * 0.2),
		])
		poly.color.a = 0.55 * (1.0 - t)
	, 0.0, 1.0, 0.22)
	tween.tween_callback(func():
		if is_instance_valid(ring):
			ring.queue_free()
	)


func _splash(at: Vector2) -> void:
	if _school == null or not is_instance_valid(_school):
		return
	var ring := Node2D.new()
	ring.position = at + Vector2(0, 4)
	_school.add_child(ring)
	var poly := Polygon2D.new()
	poly.color = Color(1, 1, 1, 0.5)
	ring.add_child(poly)
	var max_r: float = 11.0 if school_size == "small" else 16.0
	var tween := create_tween()
	tween.tween_method(func(t: float):
		if not is_instance_valid(poly):
			return
		var r: float = 3.0 + t * max_r
		poly.polygon = PackedVector2Array([
			Vector2(-r, 0),
			Vector2(-r * 0.5, -r * 0.35),
			Vector2(r * 0.5, -r * 0.35),
			Vector2(r, 0),
			Vector2(r * 0.5, r * 0.25),
			Vector2(-r * 0.5, r * 0.25),
		])
		poly.color.a = 0.5 * (1.0 - t)
	, 0.0, 1.0, 0.28)
	tween.tween_callback(func():
		if is_instance_valid(ring):
			ring.queue_free()
	)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_boat"):
		_players_near += 1
		if body.has_method("set_near_spot"):
			body.set_near_spot(self)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player_boat"):
		_players_near = maxi(0, _players_near - 1)
		if _players_near == 0 and body.has_method("set_near_spot"):
			body.set_near_spot(null)
