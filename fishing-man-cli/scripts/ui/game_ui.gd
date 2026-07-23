extends CanvasLayer

## HUD / dock / fishing / catch / market / encyclopedia

signal cast_pressed
signal reel_pressed
signal reel_released
signal open_market
signal open_encyclopedia
signal sell_cargo
signal upgrade_boat
signal upgrade_rod
signal go_to_sea
signal sail_here(world_pos: Vector2)
signal return_to_port
signal dock_closed
signal camera_pan(world_delta: Vector2)
signal camera_focus(world_pos: Vector2)

@onready var hud: Control = $HUD
@onready var gold_label: Label = $HUD/TopLeft/GoldLabel
@onready var cargo_label: Label = $HUD/TopLeft/CargoLabel
@onready var cargo_bar: ProgressBar = $HUD/TopLeft/CargoBar
@onready var fuel_label: Label = $HUD/TopLeft/FuelRow/FuelLabel
@onready var fuel_bar: ProgressBar = $HUD/TopLeft/FuelRow/FuelBar
var hull_label: Label
var hull_bar: ProgressBar
@onready var fish_btn: Button = $HUD/BottomRight/FishBtn
@onready var cast_btn: Button = $HUD/CastBtn
@onready var dock_panel: PanelContainer = $DockPanel
@onready var fishing_panel: PanelContainer = $FishingPanel
@onready var wait_label: Label = $FishingPanel/VBox/WaitLabel
@onready var timer_label: Label = $FishingPanel/VBox/Header/TimerLabel
@onready var timing_bar: Control = $FishingPanel/VBox/TimingTrack
@onready var catch_panel: PanelContainer = $CatchPanel
@onready var market_panel: Control = $MarketPanel
@onready var encyclopedia_panel: Control = $EncyclopediaPanel
@onready var toast_label: Label = $Toast
@onready var minimap: ColorRect = $HUD/Minimap/VBox/MapDraw
@onready var hint_label: Label = $HUD/Hint

var tool_shop_panel: Control
var _cursor: ColorRect
var _green: ColorRect
var _perfect: ColorRect
var _tension_track: Control
var _tension_bg: ColorRect
var _tension_safe: ColorRect
var _tension_needle: ColorRect
var _progress_track: Control
var _progress_fill: ColorRect
var _fish_hint: Label
var _reel_mode: String = "timing" ## timing | reeling
var _toast_time: float = 0.0
var _dock_mode: String = "harbor" ## harbor | return | boat | sail_here
var _toast_panel: PanelContainer
var _dock_dim: ColorRect
var _theme: Theme
var _sail_target: Vector2 = Vector2.ZERO
var _catch_burst_tween: Tween

var _title: Label
var _sell_btn: Button
var _boat_btn: Button
var _rod_btn: Button
var _go_sea_btn: Button
var _return_btn: Button
var _close_btn: Button

var gear_panel: Control


const _ThemeFactory = preload("res://scripts/ui/ui_theme.gd")


func _ready() -> void:
	_theme = _ThemeFactory.build()
	_apply_theme(_theme)
	_cursor = timing_bar.get_node("Cursor") as ColorRect
	_green = timing_bar.get_node("Green") as ColorRect
	_perfect = timing_bar.get_node("Perfect") as ColorRect
	_setup_dock_buttons()
	_polish_layout()
	_setup_fishing_input()
	_ensure_tool_shop()
	_ensure_gear_panel()
	cast_btn.pressed.connect(func():
		cast_pressed.emit()
	)
	## Bottom-right encyclopedia shortcut removed; open via shore building
	if fish_btn:
		fish_btn.visible = false
	if has_node("HUD/BottomRight"):
		$HUD/BottomRight.visible = false
	$CatchPanel/VBox/ContinueBtn.pressed.connect(_hide_catch)
	$MarketPanel/Panel/VBox/Header/CloseBtn.pressed.connect(func():
		market_panel.visible = false
	)
	$EncyclopediaPanel/Panel/VBox/Header/CloseBtn.pressed.connect(func():
		encyclopedia_panel.visible = false
	)
	if minimap:
		minimap.view_pan.connect(func(d): camera_pan.emit(d))
		minimap.view_focus.connect(func(p): camera_focus.emit(p))
	dock_panel.visible = false
	fishing_panel.visible = false
	catch_panel.visible = false
	market_panel.visible = false
	encyclopedia_panel.visible = false
	cast_btn.visible = false
	GameState.resources_changed.connect(refresh_hud)
	GameState.cargo_changed.connect(refresh_hud)
	GameState.discovered_changed.connect(refresh_hud)
	GameState.toast.connect(show_toast)
	refresh_hud()


func _apply_theme(t: Theme) -> void:
	for n in [hud, dock_panel, fishing_panel, catch_panel, market_panel, encyclopedia_panel, tool_shop_panel, gear_panel, toast_label]:
		if n:
			n.theme = t


func _polish_layout() -> void:
	_setup_resource_icons()
	## Hull row is created in _setup_resource_icons; style after
	_style_progress_bars()
	_style_buttons()
	_setup_toast_panel()
	_setup_dock_dim()
	_layout_panels()
	_setup_catch_art_frame()
	_fix_broken_labels()


func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _icon_rect(tex: Texture2D, size: Vector2 = Vector2(36, 36)) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _setup_resource_icons() -> void:
	var top: VBoxContainer = $HUD/TopLeft
	## Absorb taps so HUD clicks do not fall through to world / toast
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	top.add_theme_constant_override("separation", 10)
	var coin := _tex("res://assets/ui/icons/coin.png")
	var crate := _tex("res://assets/ui/icons/crate.png")
	var fuel_icon := _tex("res://assets/ui/icons/fuel.png")
	## Gold row
	if top.get_node_or_null("GoldRow") == null and coin:
		var row := HBoxContainer.new()
		row.name = "GoldRow"
		row.add_theme_constant_override("separation", 8)
		top.add_child(row)
		top.move_child(row, 0)
		row.add_child(_icon_rect(coin, Vector2(32, 32)))
		gold_label.reparent(row)
		gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## Cargo row with icon
	if top.get_node_or_null("CargoRow") == null and crate:
		var row2 := HBoxContainer.new()
		row2.name = "CargoRow"
		row2.add_theme_constant_override("separation", 8)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		top.add_child(row2)
		top.move_child(row2, 1)
		row2.add_child(_icon_rect(crate, Vector2(32, 32)))
		row2.add_child(col)
		cargo_label.reparent(col)
		cargo_bar.reparent(col)
	## Fuel icon
	var fuel_row: HBoxContainer = $HUD/TopLeft/FuelRow
	if fuel_row.get_node_or_null("FuelIcon") == null and fuel_icon:
		var ic := _icon_rect(fuel_icon, Vector2(28, 28))
		ic.name = "FuelIcon"
		fuel_row.add_child(ic)
		fuel_row.move_child(ic, 0)
	fuel_row.add_theme_constant_override("separation", 8)
	## Dedicated hull row  -  bar and % must stay in sync (not shared with fuel)
	if top.get_node_or_null("HullRow") == null:
		var hull_row := HBoxContainer.new()
		hull_row.name = "HullRow"
		hull_row.add_theme_constant_override("separation", 8)
		top.add_child(hull_row)
		var fuel_idx: int = fuel_row.get_index()
		top.move_child(hull_row, fuel_idx + 1)
		hull_label = Label.new()
		hull_label.name = "HullLabel"
		hull_label.add_theme_font_size_override("font_size", 20)
		hull_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		hull_label.text = "\u8239 100%"
		hull_bar = ProgressBar.new()
		hull_bar.name = "HullBar"
		hull_bar.custom_minimum_size = Vector2(140, 18)
		hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hull_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hull_bar.max_value = 100.0
		hull_bar.value = 100.0
		hull_bar.show_percentage = false
		hull_row.add_child(hull_label)
		hull_row.add_child(hull_bar)
	else:
		var existing: HBoxContainer = top.get_node("HullRow") as HBoxContainer
		hull_label = existing.get_node_or_null("HullLabel") as Label
		hull_bar = existing.get_node_or_null("HullBar") as ProgressBar
	gold_label.add_theme_font_size_override("font_size", 28)
	gold_label.add_theme_color_override("font_color", Color(0.957, 0.827, 0.369, 1))
	_outline(gold_label)
	cargo_label.add_theme_font_size_override("font_size", 20)
	cargo_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_outline(cargo_label)
	fuel_label.add_theme_font_size_override("font_size", 20)
	fuel_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_outline(fuel_label)
	if hull_label:
		_outline(hull_label)
	_wrap_top_left_panel(top)


func _top_left_panel_style() -> StyleBoxFlat:
	## Same glass teal as minimap (top-right)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.102, 0.165, 0.196, 0.92)
	style.set_corner_radius_all(16)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.12)
	return style


func _wrap_top_left_panel(top: VBoxContainer) -> void:
	if top.get_parent() and str(top.get_parent().name) == "TopLeftPanel":
		var existing: PanelContainer = top.get_parent() as PanelContainer
		existing.offset_left = 16.0
		existing.offset_top = 16.0
		existing.offset_right = 292.0
		existing.offset_bottom = 250.0
		existing.add_theme_stylebox_override("panel", _top_left_panel_style())
		return
	var parent: Node = top.get_parent()
	var idx := top.get_index()
	var panel := PanelContainer.new()
	panel.name = "TopLeftPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.layout_mode = 0
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 292.0
	panel.offset_bottom = 250.0
	panel.add_theme_stylebox_override("panel", _top_left_panel_style())
	parent.add_child(panel)
	parent.move_child(panel, idx)
	top.reparent(panel)
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.offset_left = 0.0
	top.offset_top = 0.0
	top.offset_right = 0.0
	top.offset_bottom = 0.0


func _outline(label: Label, size: int = 3) -> void:
	label.add_theme_constant_override("outline_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.08, 0.7))


func _style_progress_bars() -> void:
	cargo_bar.custom_minimum_size = Vector2(180, 18)
	fuel_bar.custom_minimum_size = Vector2(140, 18)
	fuel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fuel_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cargo_bar.add_theme_stylebox_override("background", _ThemeFactory.bar_bg())
	cargo_bar.add_theme_stylebox_override("fill", _ThemeFactory.bar_fill(Color(0.32, 0.78, 0.48, 1)))
	fuel_bar.add_theme_stylebox_override("background", _ThemeFactory.bar_bg())
	fuel_bar.add_theme_stylebox_override("fill", _ThemeFactory.bar_fill(Color(0.96, 0.62, 0.18, 1)))
	cargo_bar.show_percentage = false
	fuel_bar.show_percentage = false
	if hull_bar:
		hull_bar.custom_minimum_size = Vector2(140, 18)
		hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hull_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hull_bar.add_theme_stylebox_override("background", _ThemeFactory.bar_bg())
		hull_bar.add_theme_stylebox_override("fill", _ThemeFactory.bar_fill(Color(0.45, 0.78, 0.92, 1)))
		hull_bar.show_percentage = false


func _style_buttons() -> void:
	cast_btn.text = "\u629b\u7aff"
	cast_btn.custom_minimum_size = Vector2(220, 72)
	cast_btn.offset_left = 250.0
	cast_btn.offset_top = 560.0
	cast_btn.offset_right = 470.0
	cast_btn.offset_bottom = 632.0
	cast_btn.add_theme_stylebox_override("normal", _ThemeFactory.btn_cast())
	cast_btn.add_theme_stylebox_override("hover", _ThemeFactory.btn_cast())
	cast_btn.add_theme_stylebox_override("pressed", _ThemeFactory.btn_cast())
	cast_btn.add_theme_font_size_override("font_size", 34)
	cast_btn.add_theme_color_override("font_color", Color(0.12, 0.1, 0.05, 1))
	var cont: Button = $CatchPanel/VBox/ContinueBtn
	_ThemeFactory.apply_list_primary(cont)
	## Dock list: first action highlighted, others secondary pills
	_ThemeFactory.apply_list_primary(_sell_btn)
	_ThemeFactory.apply_list_primary(_go_sea_btn)
	_ThemeFactory.apply_list_primary(_return_btn)
	_ThemeFactory.apply_list_secondary(_boat_btn)
	_ThemeFactory.apply_list_secondary(_rod_btn)
	_ThemeFactory.apply_list_secondary(_close_btn)
	var coin := _tex("res://assets/ui/icons/coin.png")
	for b in [_sell_btn, _boat_btn, _rod_btn]:
		if b and coin:
			b.icon = coin
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 28)


func _setup_toast_panel() -> void:
	if get_node_or_null("ToastPanel") != null:
		_toast_panel = $ToastPanel
	else:
		_toast_panel = PanelContainer.new()
		_toast_panel.name = "ToastPanel"
		_toast_panel.visible = false
		_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := _ThemeFactory.panel_style(14, 0.94)
		style.set_content_margin_all(18)
		style.bg_color = Color(0.08, 0.14, 0.18, 0.94)
		_toast_panel.add_theme_stylebox_override("panel", style)
		if toast_label.get_parent() != _toast_panel:
			toast_label.reparent(_toast_panel)
		add_child(_toast_panel)
	if toast_label.get_parent() != _toast_panel:
		toast_label.reparent(_toast_panel)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_font_size_override("font_size", 24)
	toast_label.custom_minimum_size = Vector2(200, 0)
	toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toast_label.visible = true
	if _theme:
		_toast_panel.theme = _theme
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_floating_panel(_toast_panel, Vector2(360, 64))
	move_child(_toast_panel, get_child_count() - 1)


func _center_floating_panel(panel: Control, size: Vector2) -> void:
	## Anchor at screen center; offsets expand equally left/right/up/down
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -size.x * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_bottom = size.y * 0.5


func _relayout_toast() -> void:
	if _toast_panel == null:
		return
	_toast_panel.reset_size()
	var sz := _toast_panel.get_combined_minimum_size()
	sz.x = clampf(maxf(sz.x, 240.0), 240.0, 560.0)
	sz.y = maxf(sz.y, 56.0)
	_center_floating_panel(_toast_panel, sz)


func _setup_dock_dim() -> void:
	_dock_dim = get_node_or_null("DockDim") as ColorRect
	if _dock_dim == null:
		_dock_dim = ColorRect.new()
		_dock_dim.name = "DockDim"
		_dock_dim.color = Color(0, 0, 0, 0.45)
		_dock_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dock_dim.mouse_filter = Control.MOUSE_FILTER_STOP
		_dock_dim.visible = false
		add_child(_dock_dim)
		move_child(_dock_dim, dock_panel.get_index())
	_dock_dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			hide_dock_menu()
		elif ev is InputEventScreenTouch and ev.pressed:
			hide_dock_menu()
	)


func _layout_panels() -> void:
	## Dock / harbor / boat menus: centered card
	_center_floating_panel(dock_panel, Vector2(500, 480))
	dock_panel.add_theme_stylebox_override("panel", _ThemeFactory.panel_style(20, 0.94))
	var dock_vb: VBoxContainer = $DockPanel/VBox
	dock_vb.add_theme_constant_override("separation", 14)

	## Catch result: centered modal card
	_center_floating_panel(catch_panel, Vector2(560, 760))
	catch_panel.add_theme_stylebox_override("panel", _ThemeFactory.panel_style(20, 0.95))

	## Fishing timing: centered near lower third (above cast button)
	fishing_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fishing_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fishing_panel.offset_left = -340.0
	fishing_panel.offset_right = 340.0
	fishing_panel.offset_top = -420.0
	fishing_panel.offset_bottom = -140.0
	fishing_panel.add_theme_stylebox_override("panel", _ThemeFactory.panel_style(18, 0.94))
	timing_bar.custom_minimum_size = Vector2(640, 48)
	if _cursor:
		_cursor.size.y = 48
	if _green:
		_green.size.y = 48
	if _perfect:
		_perfect.size.y = 48
	var bg: ColorRect = timing_bar.get_node_or_null("Bg") as ColorRect
	if bg:
		bg.size = Vector2(640, 48)

	## Floating centered sheets (not full-screen)
	## Viewport 720x1280 -> half height ~640
	_center_floating_panel(market_panel.get_node_or_null("Panel") as Control, Vector2(672, 640))
	_layout_modal_sheet(encyclopedia_panel.get_node_or_null("Panel") as Control, 16.0, 32.0)
	var enc_detail: Control = encyclopedia_panel.get_node_or_null("Detail") as Control
	if enc_detail:
		_center_floating_panel(enc_detail, Vector2(520, 720))
	if tool_shop_panel:
		_center_floating_panel(tool_shop_panel.get_node_or_null("Panel") as Control, Vector2(672, 640))

	## Minimap slightly larger
	var mm: PanelContainer = $HUD/Minimap
	mm.offset_left = 508.0
	mm.offset_top = 12.0
	mm.offset_right = 708.0
	mm.offset_bottom = 220.0
	minimap.custom_minimum_size = Vector2(176, 156)
	$HUD/Minimap/VBox/Title.add_theme_font_size_override("font_size", 22)
	## Hint chip
	## Short, non-nagging tip; hide after first sea trip
	_wrap_label_chip(hint_label, Color(0.08, 0.12, 0.16, 0.72))
	hint_label.offset_left = 16.0
	hint_label.offset_top = 1188.0
	hint_label.offset_right = 420.0
	hint_label.offset_bottom = 1264.0
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_outline(hint_label)
	hint_label.text = "\u62d6\u52a8\u6d4f\u89c8\u6d77\u57df"


func _layout_modal_sheet(panel: Control, margin_x: float, margin_y: float) -> void:
	if panel == null:
		return
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = margin_x
	panel.offset_top = margin_y
	panel.offset_right = -margin_x
	panel.offset_bottom = -margin_y


func _wrap_label_chip(label: Label, bg: Color) -> void:
	if label.get_parent() and str(label.get_parent().name).ends_with("Chip"):
		return
	var parent: Node = label.get_parent()
	var idx := label.get_index()
	var chip := PanelContainer.new()
	chip.name = label.name + "Chip"
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", style)
	## Keep absolute placement if the label was free-positioned under HUD
	if parent == hud:
		chip.layout_mode = 0
		chip.position = label.position
		chip.size = label.size
		chip.offset_left = label.offset_left
		chip.offset_top = label.offset_top
		chip.offset_right = label.offset_right
		chip.offset_bottom = label.offset_bottom
	parent.add_child(chip)
	parent.move_child(chip, idx)
	label.reparent(chip)
	if parent == hud:
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _fix_broken_labels() -> void:
	var m_close: Button = $MarketPanel/Panel/VBox/Header/CloseBtn
	m_close.text = "\u5173\u95ed"
	m_close.custom_minimum_size = Vector2(88, 48)
	var e_close: Button = $EncyclopediaPanel/Panel/VBox/Header/CloseBtn
	e_close.text = "\u5173\u95ed"
	e_close.custom_minimum_size = Vector2(88, 48)
	var d_close: Button = $EncyclopediaPanel/Detail/VBox/CloseBtn
	d_close.text = "\u5173\u95ed"
	d_close.custom_minimum_size = Vector2(0, 48)
	var prev: Button = $EncyclopediaPanel/Detail/VBox/Nav/PrevBtn
	var next: Button = $EncyclopediaPanel/Detail/VBox/Nav/NextBtn
	prev.text = "\u4e0a\u4e00\u4e2a"
	next.text = "\u4e0b\u4e00\u4e2a"
	prev.custom_minimum_size = Vector2(110, 48)
	next.custom_minimum_size = Vector2(110, 48)


func _setup_dock_buttons() -> void:
	var vb: VBoxContainer = $DockPanel/VBox
	_title = vb.get_node("Title") as Label
	_sell_btn = vb.get_node("SellBtn") as Button
	_boat_btn = vb.get_node("BoatBtn") as Button
	_rod_btn = vb.get_node("RodBtn") as Button
	_go_sea_btn = vb.get_node_or_null("MarketBtn") as Button
	if _go_sea_btn == null:
		_go_sea_btn = Button.new()
		_go_sea_btn.name = "GoSeaBtn"
		vb.add_child(_go_sea_btn)
		vb.move_child(_go_sea_btn, 1)
	else:
		_go_sea_btn.name = "GoSeaBtn"
		vb.move_child(_go_sea_btn, 1)
	_go_sea_btn.text = "\u51fa\u6d77"
	_return_btn = vb.get_node_or_null("ReturnBtn") as Button
	if _return_btn == null:
		_return_btn = Button.new()
		_return_btn.name = "ReturnBtn"
		vb.add_child(_return_btn)
		vb.move_child(_return_btn, 1)
	_return_btn.text = "\u56de\u6e2f"
	_close_btn = vb.get_node_or_null("CloseBtn") as Button
	if _close_btn == null:
		_close_btn = Button.new()
		_close_btn.name = "CloseBtn"
		vb.add_child(_close_btn)
	_close_btn.text = "\u5173\u95ed"
	_title.add_theme_font_size_override("font_size", 28)
	_sell_btn.pressed.connect(func():
		sell_cargo.emit()
	)
	_boat_btn.pressed.connect(func():
		upgrade_boat.emit()
	)
	_rod_btn.pressed.connect(func():
		upgrade_rod.emit()
	)
	_go_sea_btn.pressed.connect(_on_go_sea_pressed)
	_return_btn.pressed.connect(func():
		return_to_port.emit()
	)
	_close_btn.pressed.connect(func(): hide_dock_menu())


func _on_go_sea_pressed() -> void:
	if _dock_mode == "sail_here":
		sail_here.emit(_sail_target)
	else:
		go_to_sea.emit()


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			if _toast_panel:
				_toast_panel.visible = false
			else:
				toast_label.visible = false


func refresh_hud() -> void:
	gold_label.text = "%d" % GameState.gold
	cargo_label.text = "\u8d27\u8231 %d/%d" % [GameState.get_cargo_count(), GameState.cargo_capacity]
	cargo_bar.max_value = GameState.cargo_capacity
	cargo_bar.value = GameState.get_cargo_count()
	fuel_label.text = "\u6cb9 %d/%d" % [int(GameState.fuel), int(GameState.fuel_max)]
	fuel_bar.max_value = GameState.fuel_max
	fuel_bar.value = GameState.fuel
	var hull_pct: int = int(round(GameState.get_hull_ratio() * 100.0))
	if hull_label:
		hull_label.text = "\u8239 %d%%" % hull_pct
	if hull_bar:
		hull_bar.max_value = 100.0
		hull_bar.value = float(hull_pct)
		## Tint shifts as hull wears down
		var fill_col := Color(0.45, 0.78, 0.92, 1)
		if hull_pct <= 30:
			fill_col = Color(0.92, 0.35, 0.28, 1)
		elif hull_pct <= 60:
			fill_col = Color(0.96, 0.72, 0.28, 1)
		hull_bar.add_theme_stylebox_override("fill", _ThemeFactory.bar_fill(fill_col))
	if _boat_btn:
		_boat_btn.text = "\u5347\u7ea7\u8239\u53ea (-%d)" % GameState.boat_upgrade_cost
	if _rod_btn:
		_rod_btn.text = "\u5347\u7ea7\u9493\u7aff (-%d)" % GameState.rod_upgrade_cost
	if dock_panel.visible and _dock_mode == "harbor":
		_refresh_sell_label()
		_boat_btn.visible = false
		_rod_btn.visible = false
	elif dock_panel.visible and _dock_mode == "boat":
		_boat_btn.visible = true
		_rod_btn.visible = true


func _setup_fishing_input() -> void:
	## Timing / tension ColorRects must not swallow taps; reel is handled in _input
	fishing_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n in [timing_bar, _cursor, _green, _perfect]:
		if n:
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := timing_bar.get_node_or_null("Bg") as Control
	if bg:
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_tension_ui()
	for child in fishing_panel.find_children("*", "Control", true, false):
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ensure_tension_ui() -> void:
	var vb: VBoxContainer = fishing_panel.get_node_or_null("VBox") as VBoxContainer
	if vb == null:
		return
	_fish_hint = vb.get_node_or_null("Hint") as Label
	if vb.get_node_or_null("TensionTrack") != null:
		_tension_track = vb.get_node("TensionTrack") as Control
		_tension_bg = _tension_track.get_node_or_null("Bg") as ColorRect
		_tension_safe = _tension_track.get_node_or_null("Safe") as ColorRect
		_tension_needle = _tension_track.get_node_or_null("Needle") as ColorRect
		_progress_track = vb.get_node_or_null("ProgressTrack") as Control
		if _progress_track:
			_progress_fill = _progress_track.get_node_or_null("Fill") as ColorRect
		return

	_tension_track = Control.new()
	_tension_track.name = "TensionTrack"
	_tension_track.custom_minimum_size = Vector2(640, 40)
	_tension_track.visible = false
	vb.add_child(_tension_track)
	## Insert after TimingTrack if possible
	var timing_idx := timing_bar.get_index() if timing_bar else vb.get_child_count() - 1
	vb.move_child(_tension_track, timing_idx + 1)

	_tension_bg = ColorRect.new()
	_tension_bg.name = "Bg"
	_tension_bg.color = Color(0.06, 0.08, 0.10, 1)
	_tension_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tension_track.add_child(_tension_bg)

	_tension_safe = ColorRect.new()
	_tension_safe.name = "Safe"
	_tension_safe.color = Color(0.22, 0.72, 0.42, 0.75)
	_tension_track.add_child(_tension_safe)

	_tension_needle = ColorRect.new()
	_tension_needle.name = "Needle"
	_tension_needle.color = Color(0.98, 0.92, 0.35, 1)
	_tension_needle.size = Vector2(8, 40)
	_tension_track.add_child(_tension_needle)

	_progress_track = Control.new()
	_progress_track.name = "ProgressTrack"
	_progress_track.custom_minimum_size = Vector2(640, 18)
	_progress_track.visible = false
	vb.add_child(_progress_track)
	vb.move_child(_progress_track, _tension_track.get_index() + 1)
	var pbg := ColorRect.new()
	pbg.name = "Bg"
	pbg.color = Color(0.08, 0.10, 0.12, 1)
	pbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_progress_track.add_child(pbg)
	_progress_fill = ColorRect.new()
	_progress_fill.name = "Fill"
	_progress_fill.color = Color(0.35, 0.75, 0.95, 0.95)
	_progress_fill.size = Vector2(0, 18)
	_progress_track.add_child(_progress_fill)


func _is_reel_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch and event.pressed:
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return false


func _is_reel_release(event: InputEvent) -> bool:
	if event is InputEventScreenTouch and not event.pressed:
		return true
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return false


func _refresh_sell_label() -> void:
	var estimate := 0
	var counts: Dictionary = {}
	for item in GameState.cargo:
		var id := str(item.id)
		var n: int = int(counts.get(id, 0))
		estimate += Market.get_sell_price(
			id,
			float(item.get("weight", -1.0)),
			bool(item.get("perfect", false)),
			n
		)
		counts[id] = n + 1
	_sell_btn.text = "\u5356\u51fa\u8d27\u8231 (+%d)" % estimate


func set_cast_visible(v: bool) -> void:
	cast_btn.visible = v and not fishing_panel.visible and not catch_panel.visible


func show_harbor_menu() -> void:
	_dock_mode = "harbor"
	_title.text = "\u7801\u5934"
	_go_sea_btn.text = "\u51fa\u6d77"
	_go_sea_btn.visible = true
	_return_btn.visible = false
	_sell_btn.visible = true
	_boat_btn.visible = false
	_rod_btn.visible = false
	_refresh_sell_label()
	if _dock_dim:
		_dock_dim.visible = true
	dock_panel.visible = true


func show_boat_menu() -> void:
	## Click boat -> loadout panel (boat / rod / line set)
	hide_dock_menu()
	show_gear_panel()


func show_sail_here_menu(world_pos: Vector2) -> void:
	_dock_mode = "sail_here"
	_sail_target = world_pos
	_title.text = "\u51fa\u6d77"
	_go_sea_btn.text = "\u524d\u5f80\u6b64\u5904"
	_go_sea_btn.visible = true
	_return_btn.visible = false
	_sell_btn.visible = false
	_boat_btn.visible = false
	_rod_btn.visible = false
	if _dock_dim:
		_dock_dim.visible = true
	dock_panel.visible = true


func show_return_menu() -> void:
	_dock_mode = "return"
	_title.text = "\u7801\u5934"
	_go_sea_btn.visible = false
	_return_btn.visible = true
	_sell_btn.visible = false
	_boat_btn.visible = false
	_rod_btn.visible = false
	if _dock_dim:
		_dock_dim.visible = true
	dock_panel.visible = true


func hide_dock_menu() -> void:
	dock_panel.visible = false
	if _dock_dim:
		_dock_dim.visible = false
	_go_sea_btn.text = "\u51fa\u6d77"
	dock_closed.emit()


func hide_harbor_hint() -> void:
	hint_label.visible = false
	var chip := hud.get_node_or_null("HintChip")
	if chip:
		chip.visible = false


func set_dock_visible(v: bool) -> void:
	if v:
		show_harbor_menu()
	else:
		hide_dock_menu()


func show_fishing_casting() -> void:
	## Casting: floating toast only - no timing panel yet
	fishing_panel.visible = false
	cast_btn.visible = false
	hide_harbor_hint()
	show_toast("\u9493\u9c7c\u4e2d")


func show_fishing_waiting() -> void:
	## Compat alias: casting phase
	show_fishing_casting()


func show_fishing_timing() -> void:
	## Bite! Show the timing / reel panel
	_reel_mode = "timing"
	_ensure_tension_ui()
	fishing_panel.visible = true
	cast_btn.visible = false
	if timing_bar:
		timing_bar.visible = true
	if _tension_track:
		_tension_track.visible = false
	if _progress_track:
		_progress_track.visible = false
	wait_label.text = "\u7b49\u5f85\u9c7c\u4e0a\u94a9\uff01\u9ec4\u8272\u533a\u57df\u70b9\u51fb"
	if _fish_hint:
		_fish_hint.text = "\u6536\u7ebf\u65f6\u673a \u00b7 \u70b9\u51fb\u5c4f\u5e55 \u00b7 \u767d\u7ebf\u843d\u5165\u4eae\u8272\u533a"
	if _cursor:
		_cursor.visible = true
	_set_zones()
	_layout_fishing_panel(false)


func show_fishing_reeling(pull_curve: String = "steady") -> void:
	_reel_mode = "reeling"
	_ensure_tension_ui()
	fishing_panel.visible = true
	cast_btn.visible = false
	if timing_bar:
		timing_bar.visible = false
	if _cursor:
		_cursor.visible = false
	if _tension_track:
		_tension_track.visible = true
	if _progress_track:
		_progress_track.visible = true
	var curve_name := FishDB.pull_curve_display(pull_curve)
	wait_label.text = "\u62c9\u952f\u4e2d\uff01%s" % curve_name
	if _fish_hint:
		_fish_hint.text = "\u6309\u4f4f\u6536\u7ebf \u00b7 \u677e\u5f00\u6cc4\u529b \u00b7 \u4fdd\u6301\u5f20\u529b\u5728\u7eff\u533a"
	timer_label.text = "\u5f20\u529b"
	_layout_fishing_panel(true)


func _layout_fishing_panel(reeling: bool) -> void:
	## Slightly taller while showing tension + progress
	fishing_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fishing_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fishing_panel.offset_left = -340.0
	fishing_panel.offset_right = 340.0
	if reeling:
		fishing_panel.offset_top = -480.0
		fishing_panel.offset_bottom = -120.0
	else:
		fishing_panel.offset_top = -420.0
		fishing_panel.offset_bottom = -140.0


func hide_fishing() -> void:
	fishing_panel.visible = false
	_reel_mode = "timing"
	if _tension_track:
		_tension_track.visible = false
	if _progress_track:
		_progress_track.visible = false
	if timing_bar:
		timing_bar.visible = true


func is_blocking() -> bool:
	return market_panel.visible or encyclopedia_panel.visible or catch_panel.visible or dock_panel.visible \
		or (tool_shop_panel != null and tool_shop_panel.visible) \
		or (gear_panel != null and gear_panel.visible)


func blocks_map_pan() -> bool:
	## Full-screen modals / fishing only. Harbor dock card must not freeze the map.
	return market_panel.visible or encyclopedia_panel.visible or catch_panel.visible or fishing_panel.visible \
		or (tool_shop_panel != null and tool_shop_panel.visible) \
		or (gear_panel != null and gear_panel.visible)


func force_close_overlays() -> void:
	market_panel.visible = false
	encyclopedia_panel.visible = false
	catch_panel.visible = false
	fishing_panel.visible = false
	if tool_shop_panel:
		tool_shop_panel.visible = false
	if gear_panel:
		gear_panel.visible = false
	hide_dock_menu()
	if get_node_or_null("ToastPanel"):
		$ToastPanel.visible = false


func owns_control(c: Control) -> bool:
	var n: Node = c
	while n:
		if n == self:
			return true
		n = n.get_parent()
	return false


func update_wait(remain: float) -> void:
	timer_label.text = "%.1fs" % maxf(0.0, remain)


func update_timing(t: float) -> void:
	timer_label.text = "\u6536\u7ebf"
	var w: float = timing_bar.size.x
	if w <= 1.0:
		w = 640.0
	_cursor.position.x = clampf(t, 0.0, 1.0) * (w - _cursor.size.x)
	_cursor.size.y = timing_bar.custom_minimum_size.y


func update_tension(tension: float, progress: float, safe_lo: float, safe_hi: float) -> void:
	_ensure_tension_ui()
	if _tension_track == null:
		return
	var w: float = _tension_track.size.x
	if w <= 1.0:
		w = 640.0
	var h: float = _tension_track.custom_minimum_size.y
	if _tension_safe:
		_tension_safe.position = Vector2(safe_lo * w, 0)
		_tension_safe.size = Vector2(maxf((safe_hi - safe_lo) * w, 4.0), h)
	if _tension_needle:
		var nx := clampf(tension, 0.0, 1.0) * (w - 8.0)
		_tension_needle.position = Vector2(nx, 0)
		_tension_needle.size = Vector2(8, h)
		## Color warn when near edges
		if tension > safe_hi or tension < safe_lo:
			_tension_needle.color = Color(0.95, 0.28, 0.22, 1)
		elif tension > safe_hi - 0.08 or tension < safe_lo + 0.08:
			_tension_needle.color = Color(0.98, 0.75, 0.2, 1)
		else:
			_tension_needle.color = Color(0.98, 0.92, 0.35, 1)
	if _progress_fill and _progress_track:
		var pw: float = _progress_track.size.x
		if pw <= 1.0:
			pw = 640.0
		_progress_fill.size = Vector2(clampf(progress, 0.0, 1.0) * pw, _progress_track.custom_minimum_size.y)
	timer_label.text = "%d%%" % int(clampf(progress, 0.0, 1.0) * 100.0)


func _set_zones() -> void:
	await get_tree().process_frame
	var w: float = timing_bar.size.x
	if w <= 1.0:
		w = 640.0
	var h: float = timing_bar.custom_minimum_size.y
	var sess: Node = get_tree().get_first_node_in_group("fishing_session")
	var gs := 0.45
	var ge := 0.72
	var ps := 0.54
	var pe := 0.64
	if sess:
		gs = sess.green_start
		ge = sess.green_end
		ps = sess.perfect_start
		pe = sess.perfect_end
	_green.position.x = gs * w
	_green.size = Vector2((ge - gs) * w, h)
	_perfect.position.x = ps * w
	_perfect.size = Vector2((pe - ps) * w, h)
	_cursor.size = Vector2(maxf(4.0, _cursor.size.x), h)
	var bg: ColorRect = timing_bar.get_node_or_null("Bg") as ColorRect
	if bg:
		bg.size = Vector2(w, h)


func _setup_catch_art_frame() -> void:
	var vb: VBoxContainer = $CatchPanel/VBox
	var old_badge: Label = vb.get_node_or_null("NewBadge") as Label
	var swatch: Control = vb.get_node_or_null("FishSwatch") as Control
	var frame: Control = vb.get_node_or_null("ArtFrame") as Control
	if frame == null:
		frame = Control.new()
		frame.name = "ArtFrame"
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

	var plate: PanelContainer = frame.get_node_or_null("Plate") as PanelContainer
	if plate == null:
		plate = PanelContainer.new()
		plate.name = "Plate"
		plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var plate_st := StyleBoxFlat.new()
		plate_st.bg_color = Color(0.06, 0.16, 0.2, 0.75)
		plate_st.set_corner_radius_all(18)
		plate.add_theme_stylebox_override("panel", plate_st)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(plate)
		frame.move_child(plate, 0)

	## Fixed oval glow; rays cross via shader (not rotating the oval sprite)
	var old_tex_burst := frame.get_node_or_null("Sunburst")
	if old_tex_burst and not (old_tex_burst is ColorRect):
		old_tex_burst.queue_free()
	var burst: ColorRect = frame.get_node_or_null("Sunburst") as ColorRect
	if burst == null:
		burst = ColorRect.new()
		burst.name = "Sunburst"
		burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		burst.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		burst.offset_left = -300.0
		burst.offset_top = -210.0
		burst.offset_right = 300.0
		burst.offset_bottom = 210.0
		burst.color = Color(1, 1, 1, 1)
		var sh := load("res://shaders/catch_sunburst.gdshader") as Shader
		if sh:
			var mat := ShaderMaterial.new()
			mat.shader = sh
			burst.material = mat
		frame.add_child(burst)
		frame.move_child(burst, mini(1, frame.get_child_count() - 1))
	elif burst.material == null:
		var sh2 := load("res://shaders/catch_sunburst.gdshader") as Shader
		if sh2:
			var mat2 := ShaderMaterial.new()
			mat2.shader = sh2
			burst.material = mat2

	if swatch and swatch.get_parent() == frame:
		swatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		swatch.offset_left = 28.0
		swatch.offset_top = 28.0
		swatch.offset_right = -28.0
		swatch.offset_bottom = -28.0
		swatch.custom_minimum_size = Vector2.ZERO
		swatch.visible = false

	var art: TextureRect = frame.get_node_or_null("FishArt") as TextureRect
	if art == null:
		art = TextureRect.new()
		art.name = "FishArt"
		frame.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 28.0
	art.offset_top = 20.0
	art.offset_right = -28.0
	art.offset_bottom = -20.0
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.move_child(art, frame.get_child_count() - 1)

	var badge: TextureRect = frame.get_node_or_null("NewBadgeIcon") as TextureRect
	if badge == null:
		badge = TextureRect.new()
		badge.name = "NewBadgeIcon"
		badge.texture = _tex("res://assets/ui/icons/new.png")
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
	frame.move_child(badge, frame.get_child_count() - 1)

	if old_badge:
		old_badge.visible = false
		old_badge.text = ""

	var desc: Label = vb.get_node_or_null("DescLabel") as Label
	if desc:
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 24)
		desc.add_theme_color_override("font_color", Color(0.95, 0.97, 0.98, 1))
	var price: Label = vb.get_node_or_null("PriceLabel") as Label
	if price:
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_font_size_override("font_size", 26)


func _play_catch_sunburst() -> void:
	var burst: CanvasItem = $CatchPanel/VBox/ArtFrame.get_node_or_null("Sunburst") as CanvasItem
	if burst == null:
		return
	if _catch_burst_tween and _catch_burst_tween.is_valid():
		_catch_burst_tween.kill()
	_catch_burst_tween = null
	## Oval stays fixed; stripe crossing is driven by TIME in the shader
	burst.rotation = 0.0
	burst.modulate = Color(1, 1, 1, 1)
	burst.visible = true


func show_catch(fish_id: String, perfect: bool, is_new: bool, weight: float = -1.0) -> void:
	_setup_catch_art_frame()
	var fish: Dictionary = FishDB.get_fish(fish_id)
	var w := weight
	if w <= 0.0:
		w = FishDB.get_standard_weight(fish_id)
	var sell := Market.get_sell_price(fish_id, w, perfect)
	$CatchPanel/VBox/TitleRow/NameLabel.text = str(fish.get("name", fish_id))
	$CatchPanel/VBox/TitleRow/RarityLabel.text = FishDB.rarity_display(str(fish.get("rarity", "common")))
	$CatchPanel/VBox/PriceLabel.text = "\u91cd\u91cf %.1fkg\n\u4f30\u4ef7\uff1a%d" % [w, sell]
	var desc: Label = $CatchPanel/VBox/DescLabel
	desc.text = str(fish.get("desc", ""))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 24)
	var frame: Control = $CatchPanel/VBox/ArtFrame
	var swatch: Control = frame.get_node_or_null("FishSwatch") as Control
	var art: TextureRect = frame.get_node_or_null("FishArt") as TextureRect
	var badge: TextureRect = frame.get_node_or_null("NewBadgeIcon") as TextureRect
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
	var old_badge: Label = $CatchPanel/VBox.get_node_or_null("NewBadge") as Label
	if old_badge:
		old_badge.visible = false
	if perfect:
		desc.text += "\n\uff08\u5b8c\u7f8e\u4e0a\u94a9 +10% \u552e\u4ef7\uff09"
	_center_floating_panel(catch_panel, Vector2(580, 880))
	catch_panel.visible = true
	move_child(catch_panel, get_child_count() - 1)
	call_deferred("_play_catch_sunburst")


func _hide_catch() -> void:
	if _catch_burst_tween and _catch_burst_tween.is_valid():
		_catch_burst_tween.kill()
	_catch_burst_tween = null
	catch_panel.visible = false


func show_market() -> void:
	_center_floating_panel(market_panel.get_node_or_null("Panel") as Control, Vector2(672, 640))
	market_panel.visible = true
	move_child(market_panel, get_child_count() - 1)
	$MarketPanel.refresh()


func show_encyclopedia() -> void:
	encyclopedia_panel.visible = true
	$EncyclopediaPanel.refresh()


func show_gear_panel() -> void:
	_ensure_gear_panel()
	if gear_panel == null:
		return
	gear_panel.visible = true
	if gear_panel.has_method("refresh"):
		gear_panel.refresh()
	move_child(gear_panel, get_child_count() - 1)


func show_tool_shop() -> void:
	_ensure_tool_shop()
	if tool_shop_panel == null:
		return
	_center_floating_panel(tool_shop_panel.get_node_or_null("Panel") as Control, Vector2(672, 640))
	tool_shop_panel.visible = true
	if tool_shop_panel.has_method("refresh"):
		tool_shop_panel.refresh()
	move_child(tool_shop_panel, get_child_count() - 1)


func _ensure_tool_shop() -> void:
	if tool_shop_panel != null and tool_shop_panel.has_method("refresh"):
		return
	if tool_shop_panel != null:
		tool_shop_panel.queue_free()
		tool_shop_panel = null
	var script := load("res://scripts/ui/tool_shop_panel.gd")
	if script == null:
		push_error("Failed to load tool_shop_panel.gd")
		return
	tool_shop_panel = Control.new()
	tool_shop_panel.name = "ToolShopPanel"
	tool_shop_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tool_shop_panel.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	tool_shop_panel.add_child(panel)
	_center_floating_panel(panel, Vector2(672, 640))
	tool_shop_panel.set_script(script)
	add_child(tool_shop_panel)
	if _theme:
		tool_shop_panel.theme = _theme
	tool_shop_panel.visible = false


func _ensure_gear_panel() -> void:
	if gear_panel != null and gear_panel.has_method("refresh"):
		return
	if gear_panel != null:
		gear_panel.queue_free()
		gear_panel = null
	var script = load("res://scripts/ui/gear_panel.gd")
	if script == null:
		push_error("Failed to load gear_panel.gd")
		return
	gear_panel = Control.new()
	gear_panel.name = "GearPanel"
	gear_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gear_panel.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16.0
	panel.offset_top = 36.0
	panel.offset_right = -16.0
	panel.offset_bottom = -36.0
	gear_panel.add_child(panel)
	gear_panel.set_script(script)
	add_child(gear_panel)
	if _theme:
		gear_panel.theme = _theme
	gear_panel.visible = false


func show_toast(msg: String) -> void:
	toast_label.text = msg
	if _toast_panel:
		_toast_panel.visible = true
		call_deferred("_relayout_toast")
		move_child(_toast_panel, get_child_count() - 1)
	else:
		toast_label.visible = true
	_toast_time = 2.4


func _input(event: InputEvent) -> void:
	## Use _input (not unhandled): FishingPanel used to eat taps before reel fired
	if not fishing_panel.visible:
		return
	if catch_panel.visible or market_panel.visible or encyclopedia_panel.visible:
		return
	if tool_shop_panel != null and tool_shop_panel.visible:
		return
	if gear_panel != null and gear_panel.visible:
		return
	if _is_reel_press(event):
		reel_pressed.emit()
		get_viewport().set_input_as_handled()
		return
	if _is_reel_release(event):
		reel_released.emit()
		get_viewport().set_input_as_handled()
