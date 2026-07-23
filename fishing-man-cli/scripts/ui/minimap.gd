extends ColorRect

## 2D minimap: boat + spots + camera view; drag/tap to pan main view

signal view_pan(world_delta: Vector2)
signal view_focus(world_pos: Vector2)

const WORLD_W := 2880.0
const WORLD_H := 2560.0
const DRAG_THRESHOLD := 8.0

var _pointer_down: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_press(event.pressed, event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		if _pointer_down:
			_handle_move(event.position)
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_press(event.pressed, event.position)
		accept_event()
	elif event is InputEventMouseMotion and _pointer_down:
		_handle_move(event.position)
		accept_event()


func _handle_press(pressed: bool, pos: Vector2) -> void:
	if pressed:
		_pointer_down = true
		_dragging = false
		_press_pos = pos
		_last_pos = pos
	else:
		if _pointer_down and not _dragging:
			view_focus.emit(_map_to_world(pos))
		_pointer_down = false
		_dragging = false


func _handle_move(pos: Vector2) -> void:
	if not _pointer_down:
		return
	if not _dragging and pos.distance_to(_press_pos) >= DRAG_THRESHOLD:
		_dragging = true
	if _dragging:
		var d: Vector2 = pos - _last_pos
		_last_pos = pos
		## Drag viewport on the chart: finger direction = camera move
		view_pan.emit(_map_delta_to_world(d))


func _draw() -> void:
	var w := size.x
	var h := size.y
	var shore_ny := WorldConfig.SHORE_Y / WORLD_H
	## Soft depth gradient on the chart (deep -> mid -> near)
	var steps := 24
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var y0 := h * shore_ny * t0
		var y1 := h * shore_ny * t1
		var deep := Color(0.08, 0.28, 0.72, 1)
		var midc := Color(0.14, 0.45, 0.62, 1)
		var nearc := Color(0.22, 0.62, 0.58, 1)
		var c: Color
		if t0 < 0.4:
			c = deep.lerp(midc, t0 / 0.4)
		elif t0 < 0.75:
			c = midc.lerp(nearc, (t0 - 0.4) / 0.35)
		else:
			c = nearc
		draw_rect(Rect2(Vector2(0, y0), Vector2(w, maxf(y1 - y0, 1.0))), c, true)
	## Land below shore
	draw_rect(Rect2(Vector2(0, h * shore_ny), Vector2(w, h * (1.0 - shore_ny))), Color(0.85, 0.75, 0.5, 1), true)
	draw_line(Vector2(0, h * shore_ny), Vector2(w, h * shore_ny), Color(0.9, 0.82, 0.55, 0.7), 2.0)
	## Dock / pier
	draw_circle(_world_to_map(WorldConfig.DOCK_BERTH, w, h), 5.0, Color(0.8, 0.7, 0.4))
	var pier_tl := _world_to_map(Vector2(WorldConfig.DOCK_X - 60.0, WorldConfig.SHORE_Y - 220.0), w, h)
	draw_rect(Rect2(pier_tl, Vector2(w * 0.04, h * 0.12)), Color(0.55, 0.38, 0.22, 0.85), true)
	## Ambient small schools
	for s in get_tree().get_nodes_in_group("ambient_schools"):
		if s is Node2D:
			var ap := _world_to_map(s.global_position, w, h)
			draw_circle(ap, 1.4, Color(0.7, 0.9, 0.95, 0.55))
	## Catchable fish schools
	for s in get_tree().get_nodes_in_group("fishing_spots"):
		if s is Node2D:
			var p := _world_to_map(s.global_position, w, h)
			draw_circle(p + Vector2(-3, 1), 2.2, Color(0.55, 0.85, 0.95, 0.95))
			draw_circle(p + Vector2(2, -1), 2.0, Color(1.0, 0.82, 0.35, 0.95))
			draw_circle(p + Vector2(1, 3), 1.8, Color(0.4, 0.75, 0.7, 0.9))
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat and boat is Node2D:
		var bp := _world_to_map(boat.global_position, w, h)
		draw_circle(bp, 5.0, Color(0.35, 0.75, 1.0))
		var forward := Vector2.UP.rotated(boat.rotation) * 10.0
		draw_line(bp, bp + forward, Color(1, 1, 1), 2.0)
	## Current camera viewport on the chart
	var cam := get_viewport().get_camera_2d()
	if cam:
		var half: Vector2 = get_viewport().get_visible_rect().size * 0.5 / cam.zoom
		var tl := _world_to_map(cam.global_position - half, w, h)
		var br := _world_to_map(cam.global_position + half, w, h)
		var rect := Rect2(tl, br - tl)
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.12), true)
		draw_rect(rect, Color(1.0, 0.95, 0.7, 0.9), false, 1.5)


func _world_to_map(pos: Vector2, w: float, h: float) -> Vector2:
	var nx := inverse_lerp(0.0, WORLD_W, pos.x)
	var ny := inverse_lerp(0.0, WORLD_H, pos.y)
	return Vector2(nx * w, ny * h)


func _map_to_world(map_pos: Vector2) -> Vector2:
	var nx := 0.0 if size.x <= 0.0 else map_pos.x / size.x
	var ny := 0.0 if size.y <= 0.0 else map_pos.y / size.y
	return Vector2(lerp(0.0, WORLD_W, nx), lerp(0.0, WORLD_H, ny))


func _map_delta_to_world(map_delta: Vector2) -> Vector2:
	var sx := 0.0 if size.x <= 0.0 else WORLD_W / size.x
	var sy := 0.0 if size.y <= 0.0 else WORLD_H / size.y
	return Vector2(map_delta.x * sx, map_delta.y * sy)
