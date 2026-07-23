extends Control

## Seafood market list with fish art (touch scroll via _input)

@onready var scroll: ScrollContainer = $Panel/VBox/Scroll
@onready var list: VBoxContainer = $Panel/VBox/Scroll/List
@onready var sentiment_label: Label = $Panel/VBox/SubHeader/Sentiment
@onready var up_label: Label = $Panel/VBox/SubHeader/UpDown/UpLabel
@onready var down_label: Label = $Panel/VBox/SubHeader/UpDown/DownLabel

var _scroll_active: bool = false
var _scroll_last_y: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 8
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	## Content must NOT expand-fill, or it never overflows / scrolls
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	var dim := get_node_or_null("Dim")
	if dim and not dim.gui_input.is_connected(_on_dim_input):
		dim.gui_input.connect(_on_dim_input)
	if not Market.prices_changed.is_connected(_on_prices_changed):
		Market.prices_changed.connect(_on_prices_changed)


func _on_prices_changed() -> void:
	if visible:
		refresh()


func _on_dim_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch and ev.pressed:
		visible = false
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _handle_touch_scroll(event):
		get_viewport().set_input_as_handled()


func _handle_touch_scroll(event: InputEvent) -> bool:
	if scroll == null or not is_instance_valid(scroll):
		return false
	var rect := scroll.get_global_rect()
	if event is InputEventScreenTouch:
		if event.pressed and rect.has_point(event.position):
			_scroll_active = true
			_scroll_last_y = event.position.y
		else:
			_scroll_active = false
		return false
	if event is InputEventScreenDrag and _scroll_active:
		scroll.scroll_vertical -= int(event.relative.y)
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and rect.has_point(event.position):
			_scroll_active = true
			_scroll_last_y = event.position.y
		else:
			_scroll_active = false
		return false
	if event is InputEventMouseMotion and _scroll_active and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var dy: float = event.position.y - _scroll_last_y
		_scroll_last_y = event.position.y
		scroll.scroll_vertical -= int(dy)
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if rect.has_point(event.position):
			scroll.scroll_vertical -= 48
			return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if rect.has_point(event.position):
			scroll.scroll_vertical += 48
			return true
	return false


func refresh() -> void:
	sentiment_label.text = "\u4eca\u65e5\u884c\u60c5  %s" % Market.sentiment
	up_label.text = "\u4e0a\u6da8 %d" % Market.up_count
	down_label.text = "\u4e0b\u8dcc %d" % Market.down_count
	while list.get_child_count() > 0:
		var old: Node = list.get_child(0)
		list.remove_child(old)
		old.free()
	list.add_theme_constant_override("separation", 12)
	for fish in FishDB.get_all():
		list.add_child(_make_row(fish))
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = 0


func _make_row(fish: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 110)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.14, 0.17, 0.55)
	row_style.set_corner_radius_all(14)
	row_style.set_content_margin_all(12)
	row.add_theme_stylebox_override("panel", row_style)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(hb)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(84, 84)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex := FishDB.get_texture(str(fish.id))
	if tex:
		icon.texture = tex
	else:
		icon.modulate = FishDB.get_color_for_fish(str(fish.id))
	hb.add_child(icon)

	var name_box := VBoxContainer.new()
	name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 4)
	var n := Label.new()
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.text = str(fish.name)
	n.add_theme_font_size_override("font_size", 28)
	var z := Label.new()
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z.text = FishDB.zone_display(str(fish.zone))
	z.add_theme_font_size_override("font_size", 20)
	z.modulate = Color(0.75, 0.85, 0.9)
	name_box.add_child(n)
	name_box.add_child(z)
	hb.add_child(name_box)

	var rarity := Label.new()
	rarity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity.text = FishDB.rarity_display(str(fish.rarity))
	rarity.custom_minimum_size = Vector2(88, 0)
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity.add_theme_font_size_override("font_size", 22)
	hb.add_child(rarity)

	var price := Label.new()
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.text = str(Market.get_price(str(fish.id)))
	price.custom_minimum_size = Vector2(72, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 28)
	price.add_theme_color_override("font_color", Color(0.957, 0.827, 0.369, 1))
	hb.add_child(price)

	var ch := Label.new()
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pct: float = Market.get_change(str(fish.id)) * 100.0
	if pct >= 0.0:
		ch.text = "\u25b2 %.0f%%" % pct
		ch.modulate = Color("E85A4F")
	else:
		ch.text = "\u25bc %.0f%%" % absf(pct)
		ch.modulate = Color("5BC0BE")
	ch.custom_minimum_size = Vector2(96, 0)
	ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ch.add_theme_font_size_override("font_size", 22)
	hb.add_child(ch)
	return row
