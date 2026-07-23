extends Control

## Tool shop: top tabs + item grid, tap cell to confirm purchase.

const _UiTheme = preload("res://scripts/ui/ui_theme.gd")

enum Tab { BOAT, ROD, BAIT }

const _CELL_SIZE := Vector2(150, 168)

var _tab: int = Tab.BOAT
var _built: bool = false

var _title: Label
var _tabs: HBoxContainer
var _grid: GridContainer
var _buy: Control
var _buy_title: Label
var _buy_btn: Button
var _buy_kind: String = ""
var _buy_id: String = ""
var _buy_guard_ms: int = 0
var _scroll_active: bool = false
var _scroll_last_y: float = 0.0
var _scroll_moved: bool = false
var _scroll: ScrollContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_chrome()
	if not GameState.gear_changed.is_connected(_on_state_changed):
		GameState.gear_changed.connect(_on_state_changed)
	if not GameState.resources_changed.is_connected(_on_state_changed):
		GameState.resources_changed.connect(_on_state_changed)


func _on_state_changed() -> void:
	if visible:
		call_deferred("refresh")


func _ensure_chrome() -> void:
	if _built and is_instance_valid(_grid) and is_instance_valid(_buy_btn) \
		and _grid.has_meta("shop_v3"):
		return
	_built = true

	var panel := get_node_or_null("Panel") as PanelContainer
	if panel == null:
		panel = PanelContainer.new()
		panel.name = "Panel"
		add_child(panel)
	panel.add_theme_stylebox_override("panel", _UiTheme.panel_style(18, 0.96))
	while panel.get_child_count() > 0:
		var c: Node = panel.get_child(0)
		panel.remove_child(c)
		c.free()

	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 56)
	root.add_child(header)
	_title = Label.new()
	_title.text = "\u5de5\u5177\u5e97"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	header.add_child(_title)
	var close_btn := Button.new()
	close_btn.text = "\u5173\u95ed"
	close_btn.custom_minimum_size = Vector2(88, 48)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 10)
	root.add_child(_tabs)
	_add_tab_btn("\u8239", Tab.BOAT)
	_add_tab_btn("\u9c7c\u7aff", Tab.ROD)
	_add_tab_btn("\u9975\u6599", Tab.BAIT)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 8
	root.add_child(scroll)
	_grid = GridContainer.new()
	_grid.set_meta("shop_v3", true)
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	_scroll = scroll

	var dim := get_node_or_null("Dim")
	if dim and not dim.gui_input.is_connected(_on_dim_input):
		dim.gui_input.connect(_on_dim_input)

	var old_buy := get_node_or_null("BuyPopup")
	if old_buy:
		old_buy.free()
	_buy = Control.new()
	_buy.name = "BuyPopup"
	_buy.visible = false
	_buy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buy.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_buy)
	var bdim := ColorRect.new()
	bdim.color = Color(0, 0, 0, 0.45)
	bdim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bdim.gui_input.connect(_on_buy_dim_input)
	_buy.add_child(bdim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buy.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 280)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _UiTheme.panel_style(18, 0.96))
	center.add_child(card)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 14)
	card.add_child(av)
	_buy_title = Label.new()
	_buy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buy_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buy_title.add_theme_font_size_override("font_size", 24)
	av.add_child(_buy_title)
	_buy_btn = Button.new()
	_buy_btn.text = "\u8d2d\u4e70"
	_buy_btn.custom_minimum_size = Vector2(0, 56)
	_UiTheme.apply_list_primary(_buy_btn)
	_buy_btn.pressed.connect(_on_buy_confirm)
	av.add_child(_buy_btn)
	var cancel := Button.new()
	cancel.text = "\u53d6\u6d88"
	cancel.custom_minimum_size = Vector2(0, 48)
	cancel.pressed.connect(func(): _buy.visible = false)
	av.add_child(cancel)


func _add_tab_btn(text: String, tab: int) -> void:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 56)
	btn.pressed.connect(func():
		_tab = tab
		refresh()
	)
	_tabs.add_child(btn)


func _on_dim_input(ev: InputEvent) -> void:
	if _is_press(ev):
		visible = false


func _on_buy_dim_input(ev: InputEvent) -> void:
	if not _is_press(ev):
		return
	if Time.get_ticks_msec() - _buy_guard_ms < 280:
		return
	_buy.visible = false


func _is_press(ev: InputEvent) -> bool:
	if ev is InputEventScreenTouch:
		return ev.pressed
	if ev is InputEventMouseButton:
		return ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
	return false


func _input(event: InputEvent) -> void:
	if not visible or (_buy != null and _buy.visible):
		return
	if _handle_touch_scroll(event):
		get_viewport().set_input_as_handled()


func _handle_touch_scroll(event: InputEvent) -> bool:
	if _scroll == null or not is_instance_valid(_scroll):
		return false
	var rect := _scroll.get_global_rect()
	if event is InputEventScreenTouch:
		if event.pressed and rect.has_point(event.position):
			_scroll_active = true
			_scroll_moved = false
			_scroll_last_y = event.position.y
		else:
			_scroll_active = false
		return false
	if event is InputEventScreenDrag and _scroll_active:
		_scroll.scroll_vertical -= int(event.relative.y)
		if absf(event.relative.y) > 0.5:
			_scroll_moved = true
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and rect.has_point(event.position):
			_scroll_active = true
			_scroll_moved = false
			_scroll_last_y = event.position.y
		else:
			_scroll_active = false
		return false
	if event is InputEventMouseMotion and _scroll_active and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var dy: float = event.position.y - _scroll_last_y
		_scroll_last_y = event.position.y
		_scroll.scroll_vertical -= int(dy)
		if absf(dy) > 0.5:
			_scroll_moved = true
		return true
	return false


func refresh() -> void:
	_ensure_chrome()
	if _grid == null:
		return
	_refresh_tabs()
	while _grid.get_child_count() > 0:
		var old: Node = _grid.get_child(0)
		_grid.remove_child(old)
		old.free()
	match _tab:
		Tab.BOAT:
			for boat in GameState.BOAT_CATALOG:
				var id := str(boat.id)
				var owned := GameState.owns_boat(id)
				var price := int(boat.price)
				var sub := "\u5df2\u62e5\u6709" if owned else ("%d" % price)
				if owned and GameState.equipped_boat == id:
					sub = "\u4f7f\u7528\u4e2d"
				_add_grid_item(str(boat.get("texture", "")), str(boat.name), sub, owned, func():
					_open_buy_dialog("boat", id)
				)
		Tab.ROD:
			for rod in GameState.ROD_CATALOG:
				var id := str(rod.id)
				var owned := GameState.owns_rod(id)
				var price := int(rod.price)
				var sub := "\u5df2\u62e5\u6709" if owned else ("%d" % price)
				if owned and GameState.equipped_rod == id:
					sub = "\u4f7f\u7528\u4e2d"
				_add_grid_item(str(rod.get("texture", "")), str(rod.name), sub, owned, func():
					_open_buy_dialog("rod", id)
				)
		Tab.BAIT:
			for bait in GameState.BAIT_CATALOG:
				if bool(bait.get("infinite", false)):
					continue
				var id := str(bait.id)
				var price := int(bait.price)
				var pack := int(bait.get("pack", 5))
				var sub := "%d / x%d" % [price, pack]
				_add_grid_item(str(bait.get("texture", "")), str(bait.name), sub, false, func():
					_open_buy_dialog("bait", id)
				)


func _refresh_tabs() -> void:
	var i := 0
	for c in _tabs.get_children():
		if c is Button:
			(c as Button).set_pressed_no_signal(i == _tab)
			_style_tab(c as Button, i == _tab)
			i += 1


func _style_tab(btn: Button, on: bool) -> void:
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(12)
	st.set_content_margin_all(8)
	if on:
		st.bg_color = Color(0.25, 0.45, 0.55, 1)
	else:
		st.bg_color = Color(0.18, 0.26, 0.30, 1)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 20)


func _add_grid_item(tex_path: String, title: String, sub: String, owned: bool, on_tap: Callable) -> void:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = _CELL_SIZE
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.clip_contents = true
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.14, 0.22, 0.26, 1) if not owned else Color(0.16, 0.28, 0.30, 1)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(8)
	if owned:
		st.border_width_left = 2
		st.border_width_top = 2
		st.border_width_right = 2
		st.border_width_bottom = 2
		st.border_color = Color(0.35, 0.7, 0.55, 0.8)
	cell.add_theme_stylebox_override("panel", st)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_child(vb)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(96, 80)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_tex(icon, tex_path)
	vb.add_child(icon)
	var n := Label.new()
	n.text = title
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.add_theme_font_size_override("font_size", 16)
	n.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	vb.add_child(n)
	var s := Label.new()
	s.text = sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.add_theme_font_size_override("font_size", 15)
	s.add_theme_color_override("font_color", Color(0.96, 0.83, 0.37) if not owned else Color(0.7, 0.88, 0.78))
	vb.add_child(s)
	cell.gui_input.connect(func(ev):
		if not _is_press(ev):
			return
		if _scroll_moved:
			return
		on_tap.call()
	)
	_grid.add_child(cell)


func _set_tex(tr: TextureRect, path: String) -> void:
	if tr == null:
		return
	if path.is_empty() or not ResourceLoader.exists(path):
		tr.texture = null
		return
	tr.texture = load(path) as Texture2D


func _open_buy_dialog(kind: String, id: String) -> void:
	_buy_kind = kind
	_buy_id = id
	var can_buy := true
	var price := 0
	var name_s := ""
	var detail := ""
	match kind:
		"boat":
			var d: Dictionary = GameState.get_boat_def(id)
			name_s = str(d.get("name", ""))
			price = int(d.get("price", 0))
			detail = "\u8d27\u8231%d  \u00b7  \u6cb9%d  \u00b7  \u901f%d\n%s" % [
				int(d.get("cargo", 0)),
				int(d.get("fuel", 0)),
				int(d.get("speed", 0)),
				str(d.get("desc", "")),
			]
			if GameState.owns_boat(id):
				can_buy = false
				_buy_title.text = "%s\n\n%s\n\n\u5df2\u62e5\u6709" % [name_s, detail]
			else:
				_buy_title.text = "%s\n\n%s\n\n\u4ef7\u683c %d" % [name_s, detail, price]
		"rod":
			var r: Dictionary = GameState.get_rod_def(id)
			name_s = str(r.get("name", ""))
			price = int(r.get("price", 0))
			detail = "\u7b49\u7ea7 %d\n%s" % [int(r.get("level", 1)), str(r.get("desc", ""))]
			if GameState.owns_rod(id):
				can_buy = false
				_buy_title.text = "%s\n\n%s\n\n\u5df2\u62e5\u6709" % [name_s, detail]
			else:
				_buy_title.text = "%s\n\n%s\n\n\u4ef7\u683c %d" % [name_s, detail, price]
		"bait":
			var b: Dictionary = GameState.get_bait_def(id)
			name_s = str(b.get("name", ""))
			price = int(b.get("price", 0))
			var pack := int(b.get("pack", 5))
			detail = "%s\n\u5e93\u5b58 %d  \u00b7  %d\u91d1/\u5305x%d" % [
				str(b.get("desc", "")),
				GameState.get_bait_count(id),
				price,
				pack,
			]
			_buy_title.text = "%s\n\n%s" % [name_s, detail]
		_:
			return
	_buy_btn.visible = can_buy
	_buy_btn.disabled = not can_buy
	if can_buy:
		_buy_btn.text = "\u8d2d\u4e70 (-%d)" % price
	_buy_guard_ms = Time.get_ticks_msec()
	_buy.visible = true
	move_child(_buy, get_child_count() - 1)


func _on_buy_confirm() -> void:
	var ok := false
	match _buy_kind:
		"boat":
			ok = GameState.buy_boat(_buy_id)
		"rod":
			ok = GameState.buy_rod(_buy_id)
		"bait":
			ok = GameState.buy_bait(_buy_id)
	_buy.visible = false
	_buy_kind = ""
	_buy_id = ""
	if ok:
		refresh()
