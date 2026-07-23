extends Node2D

## Sea storm patch: wear boost + rare catch bias while boat is inside

@export var storm_kind: String = "small" ## small | large
@export var radius: float = 200.0

var _players_near: int = 0
var _visual: Node2D
var _rain: Node2D
var _pulse: float = 0.0


func build_visual() -> void:
	add_to_group("storm_zones")
	_build_look()
	_setup_area()
	set_process(true)


func get_wear_mul() -> float:
	return 2.4 if storm_kind == "large" else 1.55


func get_rare_mul() -> float:
	return 2.15 if storm_kind == "large" else 1.55


func get_label() -> String:
	return "\u5927\u66b4\u98ce\u96e8" if storm_kind == "large" else "\u5c0f\u66b4\u98ce\u96e8"


func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _build_look() -> void:
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)

	## Dark water tint circle
	var tint := Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	var steps := 28
	for i in steps:
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	tint.polygon = pts
	if storm_kind == "large":
		tint.color = Color(0.08, 0.12, 0.22, 0.42)
	else:
		tint.color = Color(0.12, 0.18, 0.28, 0.32)
	_visual.add_child(tint)

	var path := "res://assets/world/weather/storm_large.png" if storm_kind == "large" else "res://assets/world/weather/storm_small.png"
	var tex := _tex(path)
	if tex:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr.position = Vector2(0, -radius * 0.15)
		var th := 220.0 if storm_kind == "large" else 160.0
		var sc := th / float(tex.get_height())
		spr.scale = Vector2(sc, sc)
		spr.modulate = Color(1, 1, 1, 0.92)
		_visual.add_child(spr)

	## Procedural thin rain needles (avoid blocky sprite streaks)
	_rain = Node2D.new()
	_rain.name = "Rain"
	_visual.add_child(_rain)
	var count := 22 if storm_kind == "large" else 14
	for i in count:
		var drop := Line2D.new()
		drop.width = 1.4
		drop.default_color = Color(0.78, 0.88, 0.98, randf_range(0.35, 0.65))
		drop.antialiased = true
		var len_y: float = randf_range(14.0, 28.0)
		drop.points = PackedVector2Array([Vector2(0, 0), Vector2(-3.5, len_y)])
		drop.position = Vector2(
			randf_range(-radius * 0.75, radius * 0.75),
			randf_range(-radius * 0.5, radius * 0.45)
		)
		drop.set_meta("speed", randf_range(110.0, 190.0))
		drop.set_meta("len", len_y)
		_rain.add_child(drop)

	var label := Label.new()
	label.text = get_label()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-70, -radius * 0.55)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(label)


func _setup_area() -> void:
	var area := Area2D.new()
	area.name = "StormArea"
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


func _process(delta: float) -> void:
	_pulse += delta
	if _visual:
		_visual.modulate.a = 0.88 + 0.08 * sin(_pulse * 1.7)
	if _rain:
		for c in _rain.get_children():
			if not (c is Line2D):
				continue
			if not is_instance_valid(c):
				continue
			var drop: Line2D = c as Line2D
			var spd: float = float(drop.get_meta("speed", 140.0))
			drop.position.y += spd * delta
			drop.position.x -= spd * 0.1 * delta
			if drop.position.y > radius * 0.7:
				drop.position.y = -radius * 0.5
				drop.position.x = randf_range(-radius * 0.75, radius * 0.75)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_boat"):
		_players_near += 1
		if body.has_method("set_near_storm"):
			body.set_near_storm(self)
		GameState.toast.emit("\u8fdb\u5165%s\uff01\u8239\u4f53\u6469\u635f\u52a0\u5267\uff0c\u7a00\u6709\u9c7c\u589e\u591a" % get_label())
		Sfx.storm_enter(storm_kind == "large")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player_boat"):
		_players_near = maxi(0, _players_near - 1)
		if _players_near == 0 and body.has_method("set_near_storm"):
			body.set_near_storm(null)
		Sfx.storm_leave()
