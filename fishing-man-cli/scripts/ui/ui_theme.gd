class_name UiThemeFactory
extends RefCounted

## Shared mobile UI theme: CJK system font + fishing art-style colors


static func make_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"Noto Sans SC",
		"PingFang SC",
		"Source Han Sans SC",
		"WenQuanYi Micro Hei",
		"sans-serif",
	])
	font.multichannel_signed_distance_field = true
	return font


static func panel_style(radius: float = 18.0, alpha: float = 0.92) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.102, 0.165, 0.196, alpha)
	s.set_corner_radius_all(int(radius))
	s.set_content_margin_all(16)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(1, 1, 1, 0.12)
	return s


static func btn_dark(radius: float = 14.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.24, 0.28, 1)
	s.set_corner_radius_all(int(radius))
	s.set_content_margin_all(12)
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


static func btn_dark_pressed() -> StyleBoxFlat:
	var s := btn_dark()
	s.bg_color = Color(0.12, 0.18, 0.22, 1)
	return s


static func btn_primary() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.96, 0.96, 0.94, 1)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(12)
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


static func _btn_tex(path: String, margin: float = 14.0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	if ResourceLoader.exists(path):
		s.texture = load(path) as Texture2D
	s.texture_margin_left = 28
	s.texture_margin_top = 28
	s.texture_margin_right = 28
	s.texture_margin_bottom = 28
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s


## Light cyan -> white pill (highlighted list action)
static func btn_list_primary() -> StyleBoxTexture:
	return _btn_tex("res://assets/ui/btn_list_primary.png")


static func btn_list_primary_pressed() -> StyleBoxTexture:
	return _btn_tex("res://assets/ui/btn_list_primary_pressed.png")


## Translucent dark teal pill (secondary list action)
static func btn_list_secondary() -> StyleBoxTexture:
	return _btn_tex("res://assets/ui/btn_list_secondary.png")


static func btn_list_secondary_pressed() -> StyleBoxTexture:
	return _btn_tex("res://assets/ui/btn_list_secondary_pressed.png")


static func apply_list_primary(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", btn_list_primary())
	btn.add_theme_stylebox_override("hover", btn_list_primary())
	btn.add_theme_stylebox_override("pressed", btn_list_primary_pressed())
	btn.add_theme_stylebox_override("disabled", btn_list_secondary())
	btn.add_theme_stylebox_override("focus", btn_list_primary())
	btn.add_theme_color_override("font_color", Color(0.12, 0.16, 0.18, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.08, 0.12, 0.14, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.14, 0.16, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.62, 0.66, 1))
	btn.custom_minimum_size = Vector2(0, 60)
	btn.add_theme_font_size_override("font_size", 26)


static func apply_list_secondary(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", btn_list_secondary())
	btn.add_theme_stylebox_override("hover", btn_list_secondary())
	btn.add_theme_stylebox_override("pressed", btn_list_secondary_pressed())
	btn.add_theme_stylebox_override("disabled", btn_list_secondary())
	btn.add_theme_stylebox_override("focus", btn_list_secondary())
	btn.add_theme_color_override("font_color", Color(0.82, 0.88, 0.9, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.92, 0.96, 0.98, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.82, 0.85, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.58, 0.62, 1))
	btn.custom_minimum_size = Vector2(0, 60)
	btn.add_theme_font_size_override("font_size", 26)


static func btn_cast() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.98, 0.82, 0.2, 1)
	s.set_corner_radius_all(18)
	s.set_content_margin_all(10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.border_width_bottom = 3
	s.border_color = Color(0.75, 0.55, 0.05, 1)
	return s


static func bar_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(10)
	return s


static func bar_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.08, 0.1, 0.75)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(2)
	return s


static func build() -> Theme:
	var theme := Theme.new()
	var font := make_font()
	theme.default_font = font
	theme.default_font_size = 22
	theme.set_font("font", "Label", font)
	theme.set_font("font", "Button", font)
	theme.set_font("font", "LineEdit", font)
	theme.set_font_size("font_size", "Label", 22)
	theme.set_font_size("font_size", "Button", 24)
	theme.set_color("font_color", "Label", Color(0.95, 0.97, 0.98, 1))
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	## Default buttons use list secondary pill look
	theme.set_stylebox("normal", "Button", btn_list_secondary())
	theme.set_stylebox("hover", "Button", btn_list_secondary())
	theme.set_stylebox("pressed", "Button", btn_list_secondary_pressed())
	theme.set_stylebox("disabled", "Button", btn_list_secondary())
	theme.set_stylebox("focus", "Button", btn_list_secondary())
	theme.set_color("font_color", "Button", Color(0.82, 0.88, 0.9, 1))
	theme.set_color("font_hover_color", "Button", Color(0.92, 0.96, 0.98, 1))
	theme.set_color("font_pressed_color", "Button", Color(0.75, 0.82, 0.85, 1))
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.58, 0.62, 1))
	theme.set_stylebox("background", "ProgressBar", bar_bg())
	theme.set_stylebox("fill", "ProgressBar", bar_fill(Color(0.35, 0.78, 0.45, 1)))
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 8)
	return theme
