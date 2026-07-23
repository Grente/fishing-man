extends Control

## Fish tank + encyclopedia with art

@onready var progress_label: Label = $Panel/VBox/Header/Progress
@onready var tank: Control = $Panel/VBox/Tank
@onready var grid: GridContainer = $Panel/VBox/Scroll/Grid
@onready var scroll: ScrollContainer = $Panel/VBox/Scroll
@onready var detail: PanelContainer = $Detail
@onready var detail_name: Label = $Detail/VBox/NameLabel
@onready var detail_rarity: Label = $Detail/VBox/RarityLabel
@onready var detail_desc: Label = $Detail/VBox/DescLabel
@onready var detail_price: Label = $Detail/VBox/Stats/PriceBox/PriceValue
@onready var detail_zone: Label = $Detail/VBox/Stats/ZoneBox/ZoneValue
@onready var detail_swatch: Control = $Detail/VBox/Swatch

const GRID_COLS := 3
const CARD_ASPECT := 1.2
const TAP_SLOP := 14.0

var _ids: Array = []
var _index: int = 0
var _detail_tex: TextureRect
var _scroll_active: bool = false
var _scroll_last_y: float = 0.0
var _scroll_moved: bool = false
var _card_press_id: String = ""
var _card_press_pos: Vector2 = Vector2.ZERO
var _relayouting: bool = false
var _last_cell: Vector2 = Vector2.ZERO


func _ready() -> void:
	$Detail/VBox/CloseBtn.pressed.connect(func(): detail.visible = false)
	$Detail/VBox/Nav/PrevBtn.pressed.connect(func(): _nav(-1))
	$Detail/VBox/Nav/NextBtn.pressed.connect(func(): _nav(1))
	detail.visible = false
	_ensure_detail_tex()
	_setup_aquarium()
	var hint := get_node_or_null("Panel/VBox/Hint")
	if hint:
		hint.visible = false
	var title := get_node_or_null("Panel/VBox/Header/Title") as Label
	if title:
		title.text = "\u56fe\u9274"
		title.add_theme_font_size_override("font_size", 32)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 16
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## Must NOT expand-fill vertically, or content never overflows / scrolls
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	## Deferred once to avoid resized / min_size infinite layout loop (freeze)
	scroll.resized.connect(_on_ency_resized)
	resized.connect(_on_ency_resized)


func _on_ency_resized() -> void:
	if not visible or _relayouting:
		return
	call_deferred("_relayout_cards")


func _input(event: InputEvent) -> void:
	if not visible or detail.visible:
		return
	if _handle_touch_scroll(event):
		get_viewport().set_input_as_handled()


func _handle_touch_scroll(event: InputEvent) -> bool:
	var rect := scroll.get_global_rect()
	if event is InputEventScreenTouch:
		if event.pressed and rect.has_point(event.position):
			_scroll_active = true
			_scroll_moved = false
			_scroll_last_y = event.position.y
		else:
			_scroll_active = false
		return false
	if event is InputEventScreenDrag and _scroll_active:
		scroll.scroll_vertical -= int(event.relative.y)
		if absf(event.relative.y) > 0.5:
			_scroll_moved = true
			_card_press_id = ""
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
		scroll.scroll_vertical -= int(dy)
		if absf(dy) > 0.5:
			_scroll_moved = true
			_card_press_id = ""
		return true
	return false


func _ensure_detail_tex() -> void:
	if detail_swatch is TextureRect:
		_detail_tex = detail_swatch
		return
	if detail_swatch is ColorRect:
		detail_swatch.visible = false
	_detail_tex = detail_swatch.get_parent().get_node_or_null("FishArt") as TextureRect
	if _detail_tex == null:
		_detail_tex = TextureRect.new()
		_detail_tex.name = "FishArt"
		_detail_tex.custom_minimum_size = Vector2(0, 220)
		_detail_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_detail_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		detail_swatch.add_sibling(_detail_tex)


func refresh() -> void:
	var total := FishDB.get_all().size()
	progress_label.text = "%d/%d" % [GameState.get_discovered_count(), total]
	for c in grid.get_children():
		c.queue_free()
	for c in tank.get_children():
		if str(c.name).begins_with("Swim") or str(c.name).begins_with("Shadow"):
			c.queue_free()
	_ids.clear()
	_last_cell = Vector2.ZERO
	for fish in FishDB.get_all():
		_ids.append(fish.id)
		var discovered: bool = GameState.is_discovered(fish.id)
		var card := PanelContainer.new()
		card.name = "Card_%s" % fish.id
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.2, 0.24, 0.95)
		style.set_corner_radius_all(14)
		style.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", style)
		var vb := VBoxContainer.new()
		vb.name = "VBox"
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 4)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex := FishDB.get_texture(fish.id)
		if tex:
			icon.texture = tex
		if not discovered:
			icon.modulate = Color(0.4, 0.4, 0.4, 1)
		vb.add_child(icon)
		var n := Label.new()
		n.name = "Name"
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.text = str(fish.name)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_font_size_override("font_size", 22)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not discovered:
			n.modulate = Color(0.7, 0.7, 0.7, 1)
		vb.add_child(n)
		var r := Label.new()
		r.name = "Status"
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if discovered:
			r.text = FishDB.rarity_display(fish.rarity)
			r.modulate = Color(0.8, 0.88, 0.92)
		else:
			r.text = "\u672a\u6355\u83b7"
			r.modulate = Color(0.65, 0.65, 0.65)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_theme_font_size_override("font_size", 18)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vb.add_child(r)
		card.add_child(vb)
		var id: String = fish.id
		card.gui_input.connect(func(ev: InputEvent): _on_card_gui_input(ev, id))
		grid.add_child(card)
	await get_tree().process_frame
	_relayout_cards()
	await get_tree().process_frame
	for fish in FishDB.get_all():
		if GameState.is_discovered(fish.id):
			_spawn_tank_fish(fish.id)


func _on_card_gui_input(event: InputEvent, fish_id: String) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_card_press_id = fish_id
			_card_press_pos = event.position
			_scroll_moved = false
		elif _card_press_id == fish_id and not _scroll_moved:
			if event.position.distance_to(_card_press_pos) <= TAP_SLOP:
				_open_detail(fish_id)
			_card_press_id = ""
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_card_press_id = fish_id
			_card_press_pos = event.position
			_scroll_moved = false
		elif _card_press_id == fish_id and not _scroll_moved:
			if event.position.distance_to(_card_press_pos) <= TAP_SLOP:
				_open_detail(fish_id)
			_card_press_id = ""


func _relayout_cards() -> void:
	if _relayouting or grid.get_child_count() == 0:
		return
	_relayouting = true
	var avail_w: float = scroll.size.x
	if avail_w < 8.0:
		avail_w = 656.0
	var hsep: int = grid.get_theme_constant("h_separation")
	var cell_w: float = floor((avail_w - float(hsep * (GRID_COLS - 1)) - 4.0) / float(GRID_COLS))
	cell_w = clampf(cell_w, 120.0, 220.0)
	## Fixed card height from width so rows overflow the viewport and can scroll
	var cell_h: float = maxf(floor(cell_w * CARD_ASPECT), 160.0)
	var next := Vector2(cell_w, cell_h)
	## Skip if unchanged - prevents resized feedback freeze
	if next.distance_to(_last_cell) < 0.5:
		_relayouting = false
		return
	_last_cell = next
	var icon_h: float = maxf(cell_h - 56.0, 100.0)
	for card in grid.get_children():
		if card is Control:
			(card as Control).custom_minimum_size = next
		var icon := card.get_node_or_null("VBox/Icon") as TextureRect
		if icon:
			icon.custom_minimum_size = Vector2(cell_w - 16.0, icon_h)
	_relayouting = false


func _setup_aquarium() -> void:
	if tank == null:
		return
	tank.custom_minimum_size = Vector2(0, 380)
	tank.clip_contents = true
	if tank is ColorRect:
		(tank as ColorRect).color = Color(0.18, 0.55, 0.78, 1.0)
	## Build static decor once
	if tank.get_node_or_null("Sand") != null:
		return
	_build_aquarium_decor()


func _build_aquarium_decor() -> void:
	## Depth gradient strips (top brighter, bottom deeper)
	var layers := [
		{"y": 0.0, "h": 0.28, "c": Color(0.42, 0.78, 0.95, 0.55)},
		{"y": 0.22, "h": 0.35, "c": Color(0.22, 0.58, 0.82, 0.28)},
		{"y": 0.55, "h": 0.45, "c": Color(0.08, 0.28, 0.48, 0.45)},
	]
	for i in layers.size():
		var L: Dictionary = layers[i]
		var strip := ColorRect.new()
		strip.name = "Grad_%d" % i
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.color = L.c
		strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		strip.anchor_top = float(L.y)
		strip.anchor_bottom = float(L.y) + float(L.h)
		strip.offset_top = 0
		strip.offset_bottom = 0
		tank.add_child(strip)
		tank.move_child(strip, 0)

	## Sandy seabed
	var sand := ColorRect.new()
	sand.name = "Sand"
	sand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sand.color = Color(0.78, 0.62, 0.38, 1.0)
	sand.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sand.anchor_top = 0.86
	sand.offset_top = 0
	sand.offset_bottom = 0
	tank.add_child(sand)
	tank.move_child(sand, 1)

	## Soft sand highlight lip
	var sand_lip := ColorRect.new()
	sand_lip.name = "SandLip"
	sand_lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sand_lip.color = Color(0.88, 0.74, 0.48, 0.85)
	sand_lip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sand_lip.anchor_top = 0.86
	sand_lip.anchor_bottom = 0.90
	sand_lip.offset_top = 0
	sand_lip.offset_bottom = 0
	tank.add_child(sand_lip)

	_add_rock(Vector2(0.12, 0.78), Vector2(0.18, 0.14), Color(0.32, 0.34, 0.36))
	_add_rock(Vector2(0.78, 0.82), Vector2(0.12, 0.10), Color(0.28, 0.30, 0.33))
	_add_seagrass(0.06, 7)
	_add_seagrass(0.88, 6)
	_spawn_bubbles()


func _add_rock(anchor: Vector2, size_frac: Vector2, col: Color) -> void:
	var rock := Panel.new()
	rock.name = "Rock"
	rock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = col
	st.set_corner_radius_all(28)
	rock.add_theme_stylebox_override("panel", st)
	rock.set_anchor(SIDE_LEFT, anchor.x)
	rock.set_anchor(SIDE_RIGHT, anchor.x + size_frac.x)
	rock.set_anchor(SIDE_TOP, anchor.y)
	rock.set_anchor(SIDE_BOTTOM, minf(anchor.y + size_frac.y, 0.96))
	rock.offset_left = 0
	rock.offset_right = 0
	rock.offset_top = 0
	rock.offset_bottom = 0
	tank.add_child(rock)


func _add_seagrass(x_anchor: float, blades: int) -> void:
	for i in blades:
		var blade := ColorRect.new()
		blade.name = "Grass"
		blade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shade := 0.35 + 0.08 * float(i % 3)
		blade.color = Color(0.18, shade, 0.22, 0.95)
		var x := x_anchor + float(i) * 0.018
		blade.set_anchor(SIDE_LEFT, x)
		blade.set_anchor(SIDE_RIGHT, x + 0.012)
		blade.set_anchor(SIDE_TOP, 0.42 + randf_range(0.0, 0.12))
		blade.set_anchor(SIDE_BOTTOM, 0.90)
		blade.offset_left = 0
		blade.offset_right = 0
		blade.offset_top = 0
		blade.offset_bottom = 0
		blade.pivot_offset = Vector2(4, 80)
		tank.add_child(blade)
		var tw := create_tween().set_loops()
		var rot := deg_to_rad(randf_range(4.0, 10.0))
		tw.tween_property(blade, "rotation", rot, randf_range(1.6, 2.4))
		tw.tween_property(blade, "rotation", -rot, randf_range(1.6, 2.4))


func _spawn_bubbles() -> void:
	for i in 10:
		var b := ColorRect.new()
		b.name = "Bubble"
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := randf_range(4.0, 9.0)
		b.custom_minimum_size = Vector2(s, s)
		b.size = Vector2(s, s)
		b.color = Color(1, 1, 1, randf_range(0.25, 0.5))
		b.position = Vector2(randf_range(30, 620), randf_range(40, 280))
		tank.add_child(b)
		_animate_bubble(b)


func _animate_bubble(b: Control) -> void:
	var tw := create_tween().set_loops()
	var start := b.position
	var end := Vector2(start.x + randf_range(-18, 18), -20.0)
	var dur := randf_range(3.5, 6.5)
	tw.tween_property(b, "position", end, dur)
	tw.tween_callback(func():
		b.position = Vector2(randf_range(40, 620), randf_range(220, 320))
	)


func _spawn_tank_fish(fish_id: String) -> void:
	var tw := tank.size.x
	var th := tank.size.y
	if tw < 8.0:
		tw = 656.0
	if th < 8.0:
		th = 380.0
	var fish_size := Vector2(128, 86)
	## Soft drop shadow behind fish
	var shadow := TextureRect.new()
	shadow.name = "Shadow_%s" % fish_id
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.size = fish_size
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.modulate = Color(0, 0, 0, 0.28)
	var icon := TextureRect.new()
	icon.name = "Swim_%s" % fish_id
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = fish_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex := FishDB.get_texture(fish_id)
	if tex:
		icon.texture = tex
		shadow.texture = tex
	var margin := 24.0
	var y_min := 28.0
	var y_max := maxf(th - 100.0, 80.0)
	var pos := Vector2(randf_range(margin, maxf(tw - fish_size.x - margin, margin)), randf_range(y_min, y_max))
	icon.position = pos
	shadow.position = pos + Vector2(6, 8)
	tank.add_child(shadow)
	tank.add_child(icon)
	_swim_loop(icon, shadow, tw, th, fish_size)


func _swim_loop(icon: Control, shadow: Control, tw: float, th: float, fish_size: Vector2) -> void:
	var margin := 24.0
	var y_min := 28.0
	var y_max := maxf(th - 100.0, 80.0)
	var tween := create_tween().set_loops()
	for _i in 4:
		var to := Vector2(
			randf_range(margin, maxf(tw - fish_size.x - margin, margin)),
			randf_range(y_min, y_max)
		)
		var dur := randf_range(3.2, 5.5)
		tween.tween_callback(func():
			if to.x < icon.position.x:
				icon.flip_h = true
				shadow.flip_h = true
			else:
				icon.flip_h = false
				shadow.flip_h = false
		)
		tween.tween_property(icon, "position", to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(shadow, "position", to + Vector2(6, 8), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _open_detail(fish_id: String) -> void:
	_index = _ids.find(fish_id)
	if _index < 0:
		return
	_show_detail_at(_index)


func _nav(delta: int) -> void:
	if _ids.is_empty():
		return
	_index = (_index + delta + _ids.size()) % _ids.size()
	_show_detail_at(_index)


func _show_detail_at(i: int) -> void:
	_ensure_detail_tex()
	var fish_id: String = _ids[i]
	var fish: Dictionary = FishDB.get_fish(fish_id)
	var discovered: bool = GameState.is_discovered(fish_id)
	detail_name.text = str(fish.get("name", fish_id))
	if discovered:
		detail_rarity.text = FishDB.rarity_display(str(fish.get("rarity", "common")))
		detail_desc.text = str(fish.get("desc", ""))
		detail_price.text = "%d \u91d1\u5e01" % Market.get_price(fish_id)
		detail_name.modulate = Color.WHITE
		detail_rarity.modulate = Color.WHITE
		detail_desc.modulate = Color.WHITE
	else:
		detail_rarity.text = "\u672a\u6355\u83b7"
		detail_desc.text = "\u672a\u6355\u83b7"
		detail_price.text = "--"
		detail_name.modulate = Color(0.75, 0.75, 0.75)
		detail_rarity.modulate = Color(0.65, 0.65, 0.65)
		detail_desc.modulate = Color(0.65, 0.65, 0.65)
	detail_zone.text = FishDB.zone_display(str(fish.get("zone", "near")))
	var tex := FishDB.get_texture(fish_id)
	if detail_swatch:
		detail_swatch.visible = false
	if _detail_tex and tex:
		_detail_tex.texture = tex
		_detail_tex.visible = true
		_detail_tex.modulate = Color.WHITE if discovered else Color(0.38, 0.38, 0.38, 1)
	detail.visible = true
