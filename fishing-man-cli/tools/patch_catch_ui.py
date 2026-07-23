# -*- coding: utf-8 -*-
path = r"C:\Users\admin\Desktop\Godot\fishing-man\scripts\ui\game_ui.gd"
with open(path, "r", encoding="utf-8") as f:
	src = f.read()
start = src.find("func _setup_catch_art_frame() -> void:")
end = src.find("func show_market() -> void:")
assert start > 0 and end > start

new = """func _setup_catch_art_frame() -> void:
	var vb: VBoxContainer = $CatchPanel/VBox
	var old_badge: Label = vb.get_node_or_null(\"NewBadge\") as Label
	var swatch: Control = vb.get_node_or_null(\"FishSwatch\") as Control
	var frame: Control = vb.get_node_or_null(\"ArtFrame\") as Control
	if frame == null:
		frame = Control.new()
		frame.name = \"ArtFrame\"
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if swatch:
			var idx := swatch.get_index()
			vb.add_child(frame)
			vb.move_child(frame, idx)
			swatch.reparent(frame)
		else:
			vb.add_child(frame)
	frame.custom_minimum_size = Vector2(0, 380)
	frame.clip_contents = true

	var plate: PanelContainer = frame.get_node_or_null(\"Plate\") as PanelContainer
	if plate == null:
		plate = PanelContainer.new()
		plate.name = \"Plate\"
		plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var plate_st := StyleBoxFlat.new()
		plate_st.bg_color = Color(0.06, 0.16, 0.2, 0.75)
		plate_st.set_corner_radius_all(18)
		plate.add_theme_stylebox_override(\"panel\", plate_st)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(plate)
		frame.move_child(plate, 0)

	var burst: TextureRect = frame.get_node_or_null(\"Sunburst\") as TextureRect
	if burst == null:
		burst = TextureRect.new()
		burst.name = \"Sunburst\"
		burst.texture = _tex(\"res://assets/ui/catch_sunburst.png\")
		burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		burst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		burst.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		burst.offset_left = -280.0
		burst.offset_top = -200.0
		burst.offset_right = 280.0
		burst.offset_bottom = 200.0
		burst.pivot_offset = Vector2(280, 200)
		frame.add_child(burst)
		frame.move_child(burst, mini(1, frame.get_child_count() - 1))

	if swatch and swatch.get_parent() == frame:
		swatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		swatch.offset_left = 28.0
		swatch.offset_top = 28.0
		swatch.offset_right = -28.0
		swatch.offset_bottom = -28.0
		swatch.custom_minimum_size = Vector2.ZERO
		swatch.visible = false

	var art: TextureRect = frame.get_node_or_null(\"FishArt\") as TextureRect
	if art == null:
		art = TextureRect.new()
		art.name = \"FishArt\"
		frame.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 28.0
	art.offset_top = 20.0
	art.offset_right = -28.0
	art.offset_bottom = -20.0
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var badge: TextureRect = frame.get_node_or_null(\"NewBadgeIcon\") as TextureRect
	if badge == null:
		badge = TextureRect.new()
		badge.name = \"NewBadgeIcon\"
		badge.texture = _tex(\"res://assets/ui/icons/new.png\")
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(badge)
	badge.custom_minimum_size = Vector2(110, 70)
	badge.anchor_left = 1.0
	badge.anchor_top = 0.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 0.0
	badge.offset_left = -120.0
	badge.offset_top = 4.0
	badge.offset_right = -6.0
	badge.offset_bottom = 74.0
	badge.visible = false

	if old_badge:
		old_badge.visible = false
		old_badge.text = \"\"

	var desc: Label = vb.get_node_or_null(\"DescLabel\") as Label
	if desc:
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override(\"font_size\", 24)
		desc.add_theme_color_override(\"font_color\", Color(0.95, 0.97, 0.98, 1))
	var price: Label = vb.get_node_or_null(\"PriceLabel\") as Label
	if price:
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_font_size_override(\"font_size\", 26)


func _play_catch_sunburst() -> void:
	var burst: TextureRect = $CatchPanel/VBox/ArtFrame.get_node_or_null(\"Sunburst\") as TextureRect
	if burst == null:
		return
	if _catch_burst_tween and _catch_burst_tween.is_valid():
		_catch_burst_tween.kill()
	burst.rotation = 0.0
	burst.modulate = Color(1, 1, 1, 0.95)
	_catch_burst_tween = create_tween()
	_catch_burst_tween.set_loops()
	_catch_burst_tween.tween_property(burst, \"rotation\", TAU, 14.0).from(0.0)


func show_catch(fish_id: String, perfect: bool, is_new: bool, weight: float = -1.0) -> void:
	_setup_catch_art_frame()
	var fish: Dictionary = FishDB.get_fish(fish_id)
	var w := weight
	if w <= 0.0:
		w = FishDB.get_standard_weight(fish_id)
	var sell := Market.get_sell_price(fish_id, w, perfect)
	$CatchPanel/VBox/TitleRow/NameLabel.text = str(fish.get(\"name\", fish_id))
	$CatchPanel/VBox/TitleRow/RarityLabel.text = FishDB.rarity_display(str(fish.get(\"rarity\", \"common\")))
	$CatchPanel/VBox/PriceLabel.text = \"\\u91cd\\u91cf %.1fkg\\n\\u4f30\\u4ef7\\uff1a%d\" % [w, sell]
	var desc: Label = $CatchPanel/VBox/DescLabel
	desc.text = str(fish.get(\"desc\", \"\"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override(\"font_size\", 24)
	var frame: Control = $CatchPanel/VBox/ArtFrame
	var swatch: Control = frame.get_node_or_null(\"FishSwatch\") as Control
	var art: TextureRect = frame.get_node_or_null(\"FishArt\") as TextureRect
	var badge: TextureRect = frame.get_node_or_null(\"NewBadgeIcon\") as TextureRect
	var tex := FishDB.get_texture(fish_id)
	if art:
		if tex:
			art.texture = tex
			art.visible = true
			if swatch:
				swatch.visible = false
		else:
			art.visible = false
			if swatch is ColorRect:
				(swatch as ColorRect).color = FishDB.get_color_for_fish(fish_id)
				swatch.visible = true
	if badge:
		badge.visible = is_new
	var old_badge: Label = $CatchPanel/VBox.get_node_or_null(\"NewBadge\") as Label
	if old_badge:
		old_badge.visible = false
	if perfect:
		desc.text += \"\\n\\uff08\\u5b8c\\u7f8e\\u6536\\u7ebf +10% \\u552e\\u4ef7\\uff09\"
	_center_floating_panel(catch_panel, Vector2(580, 880))
	catch_panel.visible = true
	move_child(catch_panel, get_child_count() - 1)
	call_deferred(\"_play_catch_sunburst\")


func _hide_catch() -> void:
	if _catch_burst_tween and _catch_burst_tween.is_valid():
		_catch_burst_tween.kill()
	_catch_burst_tween = null
	catch_panel.visible = false


"""

out = src[:start] + new + src[end:]
with open(path, "w", encoding="utf-8", newline="\n") as f:
	f.write(out)
print("ok", len(new))
