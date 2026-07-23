extends Control

## Gear screen: top equipped preview, bottom tabs + grid. Bait on props tab.

const _UiTheme = preload("res://scripts/ui/ui_theme.gd")

enum Tab { BOAT, ROD, PROP }

var _tab: int = Tab.BOAT
var _built: bool = false

var _title: Label
var _rod_slot: PanelContainer
var _boat_slot: PanelContainer
var _rod_icon: TextureRect
var _boat_icon: TextureRect
var _rod_name: Label
var _boat_name: Label
var _rod_info: Label
var _boat_info: Label
var _bait_chip: Label
var _tabs: VBoxContainer
var _grid: GridContainer
var _action: Control
var _action_title: Label
var _action_kind: String = ""
var _action_btn_upgrade: Button
var _action_btn_equip: Button
var _action_btn_unequip: Button
var _action_btn_repair: Button
var _pending_boat_id: String = ""
var _action_guard_ms: int = 0
const _CELL_SIZE := Vector2(150, 156)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_chrome()
	if not GameState.gear_changed.is_connected(_on_gear_changed):
		GameState.gear_changed.connect(_on_gear_changed)
	if not GameState.resources_changed.is_connected(_on_gear_changed):
		GameState.resources_changed.connect(_on_gear_changed)


func _on_gear_changed() -> void:
	if visible:
		call_deferred("refresh")


func _ensure_chrome() -> void:
	if _built and is_instance_valid(_rod_info) and is_instance_valid(_boat_info) \
		and _rod_slot != null and _rod_slot.has_meta("slot_v7"):
		return
	_built = true
	## Clear leftover list chrome from older versions
	var panel := get_node_or_null("Panel") as PanelContainer
	if panel == null:
		return
	while panel.get_child_count() > 0:
		var c: Node = panel.get_child(0)
		panel.remove_child(c)
		c.free()

	panel.add_theme_stylebox_override("panel", _sheet_style())
	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	panel.add_child(root)

	## Header
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 56)
	root.add_child(header)
	_title = Label.new()
	_title.text = "\u88c5\u5907"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	header.add_child(_title)
	var close_btn := Button.new()
	close_btn.text = "\u5173\u95ed"
	close_btn.custom_minimum_size = Vector2(88, 48)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	## Preview (upper)
	var preview := Control.new()
	preview.name = "Preview"
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_stretch_ratio = 1.45
	root.add_child(preview)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.22, 0.34, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.add_child(bg)
	## Soft vignette strip at bottom of preview
	var fade := ColorRect.new()
	fade.color = Color(0.08, 0.14, 0.18, 0.55)
	fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	fade.offset_top = -48
	preview.add_child(fade)
	var pv := VBoxContainer.new()
	pv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pv.offset_left = 20
	pv.offset_right = -20
	pv.offset_top = 10
	pv.offset_bottom = -8
	pv.add_theme_constant_override("separation", 10)
	preview.add_child(pv)

	_rod_slot = _make_equip_slot("\u9c7c\u7aff", true)
	_rod_slot.gui_input.connect(_on_rod_slot_input)
	pv.add_child(_rod_slot)
	_rod_icon = _rod_slot.get_node("Pad/IconBox/Icon") as TextureRect
	_rod_name = _rod_slot.get_node("Pad/Name") as Label
	_rod_info = _rod_slot.get_node("Pad/Info") as Label

	_boat_slot = _make_equip_slot("\u8239", false)
	_boat_slot.gui_input.connect(_on_boat_slot_input)
	pv.add_child(_boat_slot)
	_boat_icon = _boat_slot.get_node("Pad/IconBox/Icon") as TextureRect
	_boat_name = _boat_slot.get_node("Pad/Name") as Label
	_boat_info = _boat_slot.get_node("Pad/Info") as Label

	_bait_chip = Label.new()
	_bait_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bait_chip.add_theme_font_size_override("font_size", 20)
	_bait_chip.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	pv.add_child(_bait_chip)

	## Bottom sheet
	var bottom := PanelContainer.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.size_flags_stretch_ratio = 1.35
	var bst := StyleBoxFlat.new()
	bst.bg_color = Color(0.93, 0.88, 0.78, 0.98)
	bst.set_corner_radius_all(0)
	bst.corner_radius_top_left = 22
	bst.corner_radius_top_right = 22
	bst.set_content_margin_all(12)
	bottom.add_theme_stylebox_override("panel", bst)
	root.add_child(bottom)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	bottom.add_child(hb)

	_tabs = VBoxContainer.new()
	_tabs.custom_minimum_size = Vector2(88, 0)
	_tabs.add_theme_constant_override("separation", 8)
	hb.add_child(_tabs)
	_add_tab_btn("\u8239", Tab.BOAT)
	_add_tab_btn("\u9c7c\u7aff", Tab.ROD)
	_add_tab_btn("\u9053\u5177", Tab.PROP)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hb.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	## Slot action popup (replace if chrome rebuilt)
	var old_action := get_node_or_null("SlotAction")
	if old_action:
		old_action.free()
	_action = Control.new()
	_action.name = "SlotAction"
	_action.visible = false
	_action.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_action.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_action)
	var adim := ColorRect.new()
	adim.color = Color(0, 0, 0, 0.45)
	adim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	adim.gui_input.connect(_on_action_dim_input)
	_action.add_child(adim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 280)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _UiTheme.panel_style(18, 0.96))
	center.add_child(card)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 12)
	card.add_child(av)
	_action_title = Label.new()
	_action_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_title.add_theme_font_size_override("font_size", 24)
	av.add_child(_action_title)
	_action_btn_upgrade = Button.new()
	_action_btn_upgrade.text = "\u5347\u7ea7"
	_action_btn_upgrade.custom_minimum_size = Vector2(0, 52)
	_UiTheme.apply_list_primary(_action_btn_upgrade)
	_action_btn_upgrade.pressed.connect(_on_action_upgrade)
	av.add_child(_action_btn_upgrade)
	_action_btn_repair = Button.new()
	_action_btn_repair.text = "\u7ef4\u4fee"
	_action_btn_repair.custom_minimum_size = Vector2(0, 52)
	_UiTheme.apply_list_primary(_action_btn_repair)
	_action_btn_repair.pressed.connect(_on_action_repair)
	av.add_child(_action_btn_repair)
	_action_btn_equip = Button.new()
	_action_btn_equip.text = "\u88c5\u5907"
	_action_btn_equip.custom_minimum_size = Vector2(0, 52)
	_UiTheme.apply_list_primary(_action_btn_equip)
	_action_btn_equip.pressed.connect(_on_action_equip)
	av.add_child(_action_btn_equip)
	_action_btn_unequip = Button.new()
	_action_btn_unequip.text = "\u5378\u4e0b"
	_action_btn_unequip.custom_minimum_size = Vector2(0, 52)
	_UiTheme.apply_list_secondary(_action_btn_unequip)
	_action_btn_unequip.pressed.connect(_on_action_unequip)
	av.add_child(_action_btn_unequip)
	var cancel := Button.new()
	cancel.text = "\u53d6\u6d88"
	cancel.custom_minimum_size = Vector2(0, 48)
	cancel.pressed.connect(func(): _action.visible = false)
	av.add_child(cancel)

	var dim := get_node_or_null("Dim")
	if dim and not dim.gui_input.is_connected(_on_dim_input):
		dim.gui_input.connect(_on_dim_input)


func _sheet_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.14, 0.18, 0.92)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(0)
	return s


func _make_equip_slot(fallback: String, horizontal_icon: bool = false) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.set_meta("slot_v7", true)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	## Glass sea card - no white plate
	st.bg_color = Color(0.06, 0.16, 0.24, 0.42)
	st.set_corner_radius_all(18)
	st.set_content_margin_all(12)
	st.border_width_left = 1
	st.border_width_top = 1
	st.border_width_right = 1
	st.border_width_bottom = 1
	st.border_color = Color(0.55, 0.85, 0.95, 0.28)
	st.shadow_color = Color(0, 0, 0, 0.25)
	st.shadow_size = 6
	st.shadow_offset = Vector2(0, 3)
	slot.add_theme_stylebox_override("panel", st)
	var pad := VBoxContainer.new()
	pad.name = "Pad"
	pad.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("separation", 6)
	slot.add_child(pad)

	var icon_box := Control.new()
	icon_box.name = "IconBox"
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if horizontal_icon:
		icon_box.custom_minimum_size = Vector2(360, 110)
	else:
		icon_box.custom_minimum_size = Vector2(300, 170)
	pad.add_child(icon_box)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if horizontal_icon:
		## Standing rod art -> rotate to lie horizontal, keep centered in box
		icon.custom_minimum_size = Vector2(90, 340)
		icon.pivot_offset = Vector2(45, 170)
		icon.rotation_degrees = 90.0
		icon.resized.connect(func():
			icon.pivot_offset = icon.size * 0.5
			icon.position = (icon_box.size - icon.size) * 0.5
		)
		icon_box.resized.connect(func():
			icon.pivot_offset = icon.size * 0.5
			icon.position = (icon_box.size - icon.size) * 0.5
		)
		icon.position = Vector2(135, -115)
	else:
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_box.add_child(icon)

	var name_l := Label.new()
	name_l.name = "Name"
	name_l.text = fallback
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 32)
	name_l.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	pad.add_child(name_l)

	var info := Label.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", Color(0.72, 0.88, 0.95, 0.95))
	pad.add_child(info)
	return slot


func _add_tab_btn(text: String, tab: int) -> void:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(80, 72)
	btn.pressed.connect(func():
		_tab = tab
		refresh()
	)
	_tabs.add_child(btn)


func _on_dim_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch and ev.pressed:
		visible = false
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		visible = false


func refresh() -> void:
	_ensure_chrome()
	if _grid == null:
		return
	_refresh_preview()
	_refresh_tabs()
	## Free immediately so old cells don't linger and inflate the grid
	while _grid.get_child_count() > 0:
		var old: Node = _grid.get_child(0)
		_grid.remove_child(old)
		old.free()
	match _tab:
		Tab.BOAT:
			for boat in GameState.BOAT_CATALOG:
				if GameState.owns_boat(str(boat.id)):
					var bid := str(boat.id)
					var selected := GameState.equipped_boat == bid
					var sub := "\u8d27%d \u00b7 \u6cb9%d \u00b7 \u901f%d" % [int(boat.cargo), int(boat.fuel), int(boat.speed)]
					if selected:
						sub = "Lv%d \u00b7 \u88c5\u5907\u4e2d" % GameState.boat_level
					elif not GameState.at_harbor:
						sub = "\u7801\u5934\u53ef\u6362"
					_add_grid_item(str(boat.texture), str(boat.name), sub, selected, func():
						_open_boat_equip_dialog(bid)
					, not GameState.at_harbor and not selected, false)
		Tab.ROD:
			for rod in GameState.ROD_CATALOG:
				if GameState.owns_rod(str(rod.id)):
					var rid := str(rod.id)
					var selected_r := GameState.equipped_rod == rid
					var rsub := "\u57fa\u7840%d" % int(rod.level)
					if selected_r:
						rsub = "Lv%d \u00b7 \u88c5\u5907\u4e2d" % GameState.rod_level
					_add_grid_item(str(rod.texture), str(rod.name), rsub, selected_r, func():
						if GameState.equipped_rod == rid:
							GameState.toast.emit("\u5df2\u88c5\u5907\uff1a%s" % str(rod.name))
						else:
							GameState.equip_rod(rid)
					)
		Tab.PROP:
			for bait in GameState.BAIT_CATALOG:
				var id := str(bait.id)
				var infinite := GameState.is_bait_infinite(id)
				var n := GameState.get_bait_count(id)
				var sub := "\u221e" if infinite else ("x%d" % n)
				if not infinite and n <= 0:
					sub = "\u65e0"
				_add_grid_item(str(bait.texture), str(bait.name), sub, GameState.equipped_bait == id, func():
					if not infinite and n <= 0:
						GameState.toast.emit("\u9975\u6599\u4e0d\u8db3\uff0c\u53bb\u5de5\u5177\u5e97\u8d2d\u4e70")
						return
					if GameState.equipped_bait == id:
						GameState.set_equipped_bait("bait_plain")
					else:
						GameState.set_equipped_bait(id)
				, not infinite and n <= 0)


func _refresh_preview() -> void:
	var bdef: Dictionary = GameState.get_boat_def(GameState.equipped_boat)
	var rdef: Dictionary = GameState.get_rod_def(GameState.equipped_rod)
	_set_tex(_boat_icon, str(bdef.get("texture", "")))
	_set_tex(_rod_icon, str(rdef.get("texture", "")))
	_boat_name.text = str(bdef.get("name", "\u8239"))
	_rod_name.text = str(rdef.get("name", "\u9c7c\u7aff"))
	if _boat_info:
		_boat_info.text = "\u7b49\u7ea7 %d  \u00b7  \u8d27\u8231 %d  \u00b7  \u6cb9 %d/%d  \u00b7  \u8239\u4f53 %d%%" % [
			GameState.boat_level,
			GameState.cargo_capacity,
			int(GameState.fuel),
			int(GameState.fuel_max),
			int(round(GameState.get_hull_ratio() * 100.0)),
		]
	if _rod_info:
		var base_lv := int(rdef.get("level", 1))
		_rod_info.text = "\u7b49\u7ea7 %d  \u00b7  \u57fa\u7840%d  \u00b7  %s" % [
			GameState.rod_level,
			base_lv,
			str(rdef.get("desc", "")),
		]
	if GameState.equipped_bait.is_empty() or GameState.is_bait_infinite(GameState.equipped_bait):
		var bd0: Dictionary = GameState.get_bait_def("bait_plain" if GameState.equipped_bait.is_empty() else GameState.equipped_bait)
		_bait_chip.text = "\u9975\u6599\uff1a%s" % str(bd0.get("name", "\u666e\u901a\u9975"))
	else:
		var bd: Dictionary = GameState.get_bait_def(GameState.equipped_bait)
		_bait_chip.text = "\u9975\u6599\uff1a%s x%d" % [str(bd.get("name", "?")), GameState.get_bait_count(GameState.equipped_bait)]


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
		st.bg_color = Color(0.75, 0.7, 0.6, 0.85)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_color_override("font_color", Color.WHITE if on else Color(0.25, 0.22, 0.18))
	btn.add_theme_font_size_override("font_size", 18)


func _add_grid_item(tex_path: String, title: String, sub: String, selected: bool, on_tap: Callable, dimmed: bool = false, refresh_after: bool = true) -> void:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = _CELL_SIZE
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.clip_contents = true
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.98, 0.95, 0.88, 1) if not selected else Color(0.75, 0.9, 0.95, 1)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(8)
	if selected:
		st.border_width_left = 2
		st.border_width_top = 2
		st.border_width_right = 2
		st.border_width_bottom = 2
		st.border_color = Color(0.2, 0.55, 0.7)
	cell.add_theme_stylebox_override("panel", st)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_child(vb)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(88, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_tex(icon, tex_path)
	if dimmed:
		icon.modulate = Color(1, 1, 1, 0.4)
	vb.add_child(icon)
	var n := Label.new()
	n.text = title
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.add_theme_font_size_override("font_size", 16)
	n.add_theme_color_override("font_color", Color(0.2, 0.22, 0.25))
	vb.add_child(n)
	if not sub.is_empty():
		var s := Label.new()
		s.text = sub
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		s.add_theme_font_size_override("font_size", 14)
		s.add_theme_color_override("font_color", Color(0.45, 0.4, 0.35))
		vb.add_child(s)
	cell.gui_input.connect(func(ev):
		if not _is_press(ev):
			return
		on_tap.call()
		if refresh_after:
			refresh()
	)
	_grid.add_child(cell)


func _is_press(ev: InputEvent) -> bool:
	if ev is InputEventScreenTouch:
		return ev.pressed
	if ev is InputEventMouseButton:
		return ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
	return false


func _on_action_dim_input(ev: InputEvent) -> void:
	if not _is_press(ev):
		return
	## Ignore the same tap/mouse echo that opened this popup
	if Time.get_ticks_msec() - _action_guard_ms < 280:
		return
	_action.visible = false


func _show_action_popup() -> void:
	_action_guard_ms = Time.get_ticks_msec()
	_action.visible = true
	move_child(_action, get_child_count() - 1)


func _set_tex(tr: TextureRect, path: String) -> void:
	if tr == null:
		return
	if path.is_empty() or not ResourceLoader.exists(path):
		tr.texture = null
		return
	tr.texture = load(path) as Texture2D


func _on_rod_slot_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
		or (ev is InputEventScreenTouch and ev.pressed):
		_open_slot_action("rod")


func _on_boat_slot_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
		or (ev is InputEventScreenTouch and ev.pressed):
		_open_slot_action("boat")


func _open_boat_equip_dialog(boat_id: String) -> void:
	_action_kind = "equip_boat"
	_pending_boat_id = boat_id
	var d: Dictionary = GameState.get_boat_def(boat_id)
	var equipped := GameState.equipped_boat == boat_id
	_action_title.text = "%s\n\u8d27\u8231%d  \u00b7  \u6cb9%d  \u00b7  \u901f%d" % [
		str(d.get("name", "\u8239")),
		int(d.get("cargo", 0)),
		int(d.get("fuel", 0)),
		int(d.get("speed", 0)),
	]
	if _action_btn_upgrade:
		_action_btn_upgrade.visible = false
	if _action_btn_repair:
		_action_btn_repair.visible = false
	if _action_btn_unequip:
		_action_btn_unequip.visible = false
	if _action_btn_equip:
		_action_btn_equip.visible = true
		if equipped:
			_action_btn_equip.text = "\u5df2\u88c5\u5907"
			_action_btn_equip.disabled = true
		elif not GameState.at_harbor:
			_action_btn_equip.text = "\u7801\u5934\u53ef\u6362"
			_action_btn_equip.disabled = true
			_action_title.text += "\n\n\u8bf7\u56de\u7801\u5934\u540e\u66f4\u6362"
		else:
			_action_btn_equip.text = "\u88c5\u5907"
			_action_btn_equip.disabled = false
	_show_action_popup()


func _open_slot_action(kind: String) -> void:
	_action_kind = kind
	_pending_boat_id = ""
	if _action_btn_equip:
		_action_btn_equip.visible = false
		_action_btn_equip.disabled = false
	if _action_btn_upgrade:
		_action_btn_upgrade.visible = true
		_action_btn_upgrade.disabled = false
	if kind == "boat":
		var d: Dictionary = GameState.get_boat_def(GameState.equipped_boat)
		var repair_cost := GameState.get_repair_cost()
		_action_title.text = "%s\n\u7b49\u7ea7 %d\n\u8239\u4f53 %d/%d\n\u8d27\u8231%d  \u00b7  \u6cb9%d  \u00b7  \u901f%d\n\u5347\u7ea7\u6d88\u8017 %d" % [
			str(d.get("name", "")),
			GameState.boat_level,
			int(GameState.boat_hull),
			int(GameState.boat_hull_max),
			GameState.cargo_capacity,
			int(GameState.fuel_max),
			int(GameState.boat_speed),
			GameState.boat_upgrade_cost,
		]
		if _action_btn_unequip:
			_action_btn_unequip.visible = false
		if _action_btn_upgrade:
			_action_btn_upgrade.text = "\u5347\u7ea7 (-%d)" % GameState.boat_upgrade_cost
		if _action_btn_repair:
			_action_btn_repair.visible = true
			if repair_cost <= 0:
				_action_btn_repair.text = "\u8239\u4f53\u826f\u597d"
				_action_btn_repair.disabled = true
			elif not GameState.at_harbor:
				_action_btn_repair.text = "\u7801\u5934\u53ef\u4fee"
				_action_btn_repair.disabled = true
			else:
				_action_btn_repair.text = "\u7ef4\u4fee (-%d)" % repair_cost
				_action_btn_repair.disabled = false
	else:
		var d2: Dictionary = GameState.get_rod_def(GameState.equipped_rod)
		_action_title.text = "%s\n\u7b49\u7ea7 %d  \u00b7  \u5347\u7ea7 -%d\n%s" % [
			str(d2.get("name", "")),
			GameState.rod_level,
			GameState.rod_upgrade_cost,
			str(d2.get("desc", "")),
		]
		if _action_btn_unequip:
			_action_btn_unequip.visible = true
		if _action_btn_repair:
			_action_btn_repair.visible = false
		if _action_btn_upgrade:
			_action_btn_upgrade.text = "\u5347\u7ea7 (-%d)" % GameState.rod_upgrade_cost
	_show_action_popup()


func _on_action_equip() -> void:
	if _action_kind != "equip_boat":
		return
	if _pending_boat_id.is_empty():
		return
	var bid := _pending_boat_id
	_action.visible = false
	_pending_boat_id = ""
	GameState.equip_boat(bid)
	refresh()


func _on_action_upgrade() -> void:
	if _action_kind == "boat":
		GameState.upgrade_boat()
	elif _action_kind == "rod":
		GameState.upgrade_rod()
	_action.visible = false
	refresh()


func _on_action_repair() -> void:
	if _action_kind == "boat":
		GameState.repair_boat()
	_action.visible = false
	refresh()


func _on_action_unequip() -> void:
	if _action_kind == "boat":
		GameState.unequip_boat()
	elif _action_kind == "rod":
		GameState.unequip_rod()
	_action.visible = false
	refresh()
