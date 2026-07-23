# -*- coding: utf-8 -*-
# Patch encyclopedia_panel.gd tank visuals (UTF-8, ASCII comments).
from __future__ import print_function

p = r"C:\Users\admin\Desktop\Godot\fishing-man\scripts\ui\encyclopedia_panel.gd"
text = open(p, "rb").read().decode("utf-8")

# Replace _ready tank sizing block
old_ready_snip = """\t## Give the grid most of the panel; tank stays as a compact strip
\ttank.custom_minimum_size = Vector2(0, 120)
\tvar hint := get_node_or_null(\"Panel/VBox/Hint\")
\tif hint:
\t\thint.visible = false"""

new_ready_snip = """\t_setup_aquarium()
\tvar hint := get_node_or_null(\"Panel/VBox/Hint\")
\tif hint:
\t\thint.visible = false
\tvar title := get_node_or_null(\"Panel/VBox/Header/Title\") as Label
\tif title:
\t\ttitle.text = \"\\u56fe\\u9274\"
\t\ttitle.add_theme_font_size_override(\"font_size\", 32)"""

if old_ready_snip not in text:
	# try current 120 or other
	import re
	m = re.search(r"\t## Give the grid.*?hint\.visible = false\n", text, re.S)
	if not m:
		raise SystemExit("ready snip not found")
	text = text[:m.start()] + new_ready_snip + "\n" + text[m.end():]
	print("ready patched via regex")
else:
	text = text.replace(old_ready_snip, new_ready_snip)
	print("ready patched")

# Replace refresh tank clear + spawn to also clear decor carefully
old_clear = """\tfor c in tank.get_children():
\t\tif str(c.name).begins_with(\"Swim\"):
\t\t\tc.queue_free()"""

new_clear = """\tfor c in tank.get_children():
\t\tif str(c.name).begins_with(\"Swim\") or str(c.name).begins_with(\"Shadow\"):
\t\t\tc.queue_free()"""

if old_clear not in text:
	raise SystemExit("clear snip not found")
text = text.replace(old_clear, new_clear)

# Replace _spawn_tank_fish entire function through end of function before _open_detail
start = text.find("func _spawn_tank_fish")
end = text.find("func _open_detail")
if start < 0 or end < 0:
	raise SystemExit("spawn/open markers missing")

new_funcs = r'''func _setup_aquarium() -> void:
	if tank == null:
		return
	tank.custom_minimum_size = Vector2(0, 360)
	tank.clip_contents = true
	if tank is ColorRect:
		(tank as ColorRect).color = Color(0.18, 0.55, 0.78, 1.0)
	## Rebuild static decor once
	for c in tank.get_children():
		if not str(c.name).begins_with("Swim") and not str(c.name).begins_with("Shadow"):
			c.queue_free()
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
	var rock := ColorRect.new()
	rock.name = "Rock"
	rock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rock.color = col
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
		th = 360.0
	var fish_size := Vector2(108, 72)
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
			var facing := -1.0 if to.x < icon.position.x else 1.0
			icon.pivot_offset = fish_size * 0.5
			shadow.pivot_offset = fish_size * 0.5
			icon.scale = Vector2(facing, 1.0)
			shadow.scale = Vector2(facing, 1.0)
		)
		tween.tween_property(icon, "position", to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(shadow, "position", to + Vector2(6, 8), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


'''

text = text[:start] + new_funcs + text[end:]
open(p, "wb").write(text.encode("utf-8"))
open(p, "rb").read().decode("utf-8")
print("encyclopedia_panel.gd patched", len(text))
