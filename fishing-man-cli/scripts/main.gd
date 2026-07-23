extends Node2D

## Main: harbor buildings, go-sea / return-port, tap-to-move at sea

@onready var world: Node2D = $OceanWorld
@onready var boat: CharacterBody2D = $OceanWorld/Boat
@onready var camera: Camera2D = $Camera2D
@onready var ui: CanvasLayer = $GameUI
@onready var session: Node = $FishingSession

const DRAG_THRESHOLD := 18.0

var at_sea: bool = false
var _returning: bool = false
var _pointer_id: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _drag_last: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _cam_extra: Vector2 = Vector2.ZERO


func _ready() -> void:
	session.add_to_group("fishing_session")
	boat.entered_dock.connect(_on_entered_dock)
	boat.exited_dock.connect(_on_exited_dock)
	boat.near_spot_changed.connect(_on_near_spot)
	ui.cast_pressed.connect(_on_cast)
	ui.reel_pressed.connect(_on_reel)
	ui.reel_released.connect(_on_reel_release)
	ui.open_market.connect(ui.show_market)
	ui.open_encyclopedia.connect(ui.show_encyclopedia)
	ui.sell_cargo.connect(_on_sell)
	ui.upgrade_boat.connect(func(): GameState.upgrade_boat())
	ui.upgrade_rod.connect(func(): GameState.upgrade_rod())
	ui.go_to_sea.connect(_on_go_to_sea)
	ui.sail_here.connect(_on_sail_here)
	ui.return_to_port.connect(_on_return_to_port)
	ui.camera_pan.connect(_on_camera_pan)
	ui.camera_focus.connect(_on_camera_focus)
	session.state_changed.connect(_on_fish_state)
	session.bite_progress.connect(ui.update_wait)
	session.timing_tick.connect(ui.update_timing)
	session.tension_tick.connect(ui.update_tension)
	session.catch_result.connect(_on_catch)
	session.failed.connect(_on_fish_fail)
	await get_tree().process_frame
	var dock: Area2D = world.get_node_or_null("DockArea")
	if dock:
		dock.body_entered.connect(func(b):
			if b == boat:
				boat._on_dock_area_entered(dock)
		)
		dock.body_exited.connect(func(b):
			if b == boat:
				boat._on_dock_area_exited(dock)
		)
		for b in dock.get_overlapping_bodies():
			if b == boat:
				boat.at_dock = true
	## Start in harbor - boat parked, no free sail yet
	at_sea = false
	GameState.at_harbor = true
	boat.global_position = WorldConfig.DOCK_BERTH
	boat.rotation = 0.0
	boat.clear_destination()
	## Manual lerp in _update_camera; engine smoothing fights drag pan
	camera.position_smoothing_enabled = false
	_cam_extra = Vector2.ZERO
	_update_camera()
	## Ensure no leftover modal from a previous play session blocks the map
	ui.force_close_overlays()


func _process(_delta: float) -> void:
	_update_camera()
	if session.is_busy():
		boat.clear_destination()
	if _returning and not boat.has_target:
		## Arrived berth
		if boat.global_position.distance_to(WorldConfig.DOCK_BERTH) <= boat.arrive_distance + 8.0:
			_finish_return_to_port()


func _view_half() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5 / camera.zoom


func _clamp_camera_target(pos: Vector2) -> Vector2:
	var half := _view_half()
	return Vector2(
		clampf(pos.x, half.x, WorldConfig.WIDTH - half.x),
		clampf(pos.y, half.y, WorldConfig.HEIGHT - half.y)
	)


func _apply_camera_extra(extra: Vector2) -> void:
	var target := _clamp_camera_target(boat.global_position + extra)
	_cam_extra = target - boat.global_position


func _update_camera() -> void:
	var target := _clamp_camera_target(boat.global_position + _cam_extra)
	_cam_extra = target - boat.global_position
	## Snap while dragging so pan feels 1:1; ease when idle
	if _dragging:
		camera.global_position = target
	else:
		camera.global_position = camera.global_position.lerp(target, 0.22)


func _on_camera_pan(world_delta: Vector2) -> void:
	if session.is_busy() or ui.blocks_map_pan():
		return
	_apply_camera_extra(_cam_extra + world_delta)
	camera.global_position = _clamp_camera_target(boat.global_position + _cam_extra)


func _on_camera_focus(world_pos: Vector2) -> void:
	if session.is_busy() or ui.blocks_map_pan():
		return
	_apply_camera_extra(world_pos - boat.global_position)
	camera.global_position = _clamp_camera_target(boat.global_position + _cam_extra)


func _input(event: InputEvent) -> void:
	## Use _input (not only unhandled): world used to be covered by ColorRects
	## that swallowed events before they became unhandled.
	if ui.blocks_map_pan() or session.is_busy():
		return
	if _pointer_over_blocking_ui(event):
		return
	if event is InputEventScreenTouch:
		_on_pointer(event.index, event.pressed, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _pointer_id:
			_on_pointer_move(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_pointer(0, event.pressed, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pointer_id == 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_on_pointer_move(event.position)
		get_viewport().set_input_as_handled()


func _pointer_over_blocking_ui(_event: InputEvent) -> bool:
	## While already dragging the map, keep ownership even if cursor crosses HUD
	if _dragging and _pointer_id >= 0:
		return false
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	## Any interactive GameUI control (buttons / panels / minimap / top-left)
	return ui.owns_control(hovered)


func _on_pointer(id: int, pressed: bool, screen_pos: Vector2) -> void:
	if pressed:
		_pointer_id = id
		_press_pos = screen_pos
		_drag_last = screen_pos
		_dragging = false
	else:
		if id != _pointer_id:
			return
		if not _dragging:
			_handle_tap(screen_pos)
		_pointer_id = -1
		_dragging = false


func _on_pointer_move(screen_pos: Vector2) -> void:
	if _pointer_id < 0:
		return
	var total := screen_pos - _press_pos
	if not _dragging and total.length() >= DRAG_THRESHOLD:
		_dragging = true
	if _dragging:
		var d: Vector2 = screen_pos - _drag_last
		_drag_last = screen_pos
		## Drag the map with your finger (content follows finger)
		_apply_camera_extra(_cam_extra - d / camera.zoom)


func _handle_tap(screen_pos: Vector2) -> void:
	var canvas := get_viewport().get_canvas_transform()
	var world_pos: Vector2 = canvas.affine_inverse() * screen_pos
	var building: String = world.hit_building(world_pos)
	if building != "":
		_on_building_clicked(building)
		return
	## Tap boat in harbor -> boat upgrade menu
	if not at_sea and not _returning and _hit_boat(world_pos):
		ui.show_boat_menu()
		return
	if at_sea and not _returning:
		boat.set_destination(world_pos)
		return
	## In harbor: tap open water -> choose sail here (same as go-to-sea)
	if not at_sea and not _returning and _is_open_water(world_pos):
		ui.show_sail_here_menu(world_pos)


func _hit_boat(world_pos: Vector2) -> bool:
	return boat.global_position.distance_to(world_pos) <= 72.0


func _is_open_water(world_pos: Vector2) -> bool:
	return WorldConfig.is_open_water(world_pos)


func _on_building_clicked(id: String) -> void:
	match id:
		"dock":
			if _returning:
				return
			if at_sea:
				ui.show_return_menu()
			else:
				ui.show_harbor_menu()
		"market":
			ui.hide_dock_menu()
			ui.show_market()
		"encyclopedia":
			ui.hide_dock_menu()
			ui.show_encyclopedia()
		"toolshop":
			ui.hide_dock_menu()
			ui.show_tool_shop()


func _on_go_to_sea() -> void:
	_begin_voyage(WorldConfig.DEFAULT_SEA_DEST)


func _on_sail_here(world_pos: Vector2) -> void:
	_begin_voyage(WorldConfig.clamp_water(world_pos))


func _begin_voyage(dest: Vector2) -> void:
	at_sea = true
	_returning = false
	GameState.at_harbor = false
	ui.hide_dock_menu()
	ui.hide_harbor_hint()
	GameState.refill_fuel()
	boat.set_destination(dest)


func _on_return_to_port() -> void:
	ui.hide_dock_menu()
	_returning = true
	boat.clear_destination()
	boat.set_destination(WorldConfig.DOCK_BERTH)
	ui.show_toast("\u6b63\u5728\u56de\u6e2f\u2026")


func _finish_return_to_port() -> void:
	if not _returning and not at_sea:
		return
	_returning = false
	at_sea = false
	GameState.at_harbor = true
	boat.clear_destination()
	boat.global_position = WorldConfig.DOCK_BERTH
	boat.rotation = 0.0
	GameState.refill_fuel()
	Sfx.drop()
	ui.show_harbor_menu()
	ui.show_toast("\u5df2\u56de\u6e2f")


func _on_entered_dock() -> void:
	## Auto-open harbor menu only when finishing a return voyage
	if _returning:
		_finish_return_to_port()
	elif at_sea:
		GameState.refill_fuel()


func _on_exited_dock() -> void:
	pass


func _on_near_spot(spot: Node2D) -> void:
	ui.set_cast_visible(at_sea and spot != null and not session.is_busy())


func _on_cast() -> void:
	if not at_sea or boat.current_spot == null:
		return
	var zone: String = str(boat.current_spot.get("zone"))
	boat.fishing_locked = true
	boat.clear_destination()
	if not session.start_cast(zone):
		boat.fishing_locked = false
		return
	Sfx.cast()


func _on_reel() -> void:
	if session.is_reeling():
		session.set_reel_holding(true)
		Sfx.reel()
		return
	Sfx.reel()
	session.try_reel()


func _on_reel_release() -> void:
	if session.is_reeling():
		session.set_reel_holding(false)


func _on_fish_state(state: String) -> void:
	match state:
		"casting", "waiting":
			ui.show_fishing_casting()
		"timing":
			Sfx.bite()
			ui.show_fishing_timing()
		"reeling":
			ui.show_fishing_reeling(session.get_pull_curve())
		"idle":
			ui.hide_fishing()
			boat.fishing_locked = false
			ui.set_cast_visible(at_sea and boat.current_spot != null)


func _on_catch(fish_id: String, perfect: bool, is_new: bool, weight: float = -1.0) -> void:
	boat.fishing_locked = false
	ui.hide_fishing()
	Sfx.catch_ok(is_new, perfect)
	ui.show_catch(fish_id, perfect, is_new, weight)
	ui.set_cast_visible(at_sea and boat.current_spot != null)


func _on_fish_fail(reason: String) -> void:
	boat.fishing_locked = false
	ui.hide_fishing()
	Sfx.catch_fail()
	GameState.toast.emit(reason)
	ui.set_cast_visible(at_sea and boat.current_spot != null)


func _on_sell() -> void:
	GameState.sell_cargo()
	ui.show_harbor_menu()
