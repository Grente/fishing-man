extends Node2D

## Build 2D ocean map + clickable shore buildings

const SPOT_SCRIPT := preload("res://scripts/fishing_spot.gd")
const STORM_SCRIPT := preload("res://scripts/storm_zone.gd")
const TEX_WATER := "res://assets/world/water_tile.png"
const TEX_BOAT_FALLBACK := "res://assets/world/boat.png"
const TEX_PIER_DOCK := "res://assets/world/pier_dock.png"
const TEX_MARKET := "res://assets/world/building_market.png"
const TEX_ENCY := "res://assets/world/building_encyclopedia.png"
const TEX_TOOLSHOP := "res://assets/world/building_toolshop.png"
const TEX_PALM_A := "res://assets/world/palm_a.png"
const TEX_PALM_B := "res://assets/world/palm_b.png"
const TEX_BUSH := "res://assets/world/bush.png"
const TEX_BUSH_B := "res://assets/world/bush_b.png"
const TEX_CRATES := "res://assets/world/crates.png"
const TEX_LIFEBUOY := "res://assets/world/lifebuoy_post.png"
const TEX_SIGN := "res://assets/world/sign_blue.png"
const TEX_UMBRELLA := "res://assets/world/beach_umbrella.png"

## id -> Rect2 in world space
var building_rects: Dictionary = {}

@onready var boat: CharacterBody2D = $Boat
@onready var spots_root: Node2D = $Spots
@onready var environment_root: Node2D = $Environment


func _ready() -> void:
	_build_environment()
	_build_spots()
	_build_storms()
	_build_boat_visual()
	if not GameState.gear_changed.is_connected(_on_gear_changed):
		GameState.gear_changed.connect(_on_gear_changed)


func _on_gear_changed() -> void:
	_build_boat_visual()


func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func hit_building(world_pos: Vector2) -> String:
	var ids: Array = building_rects.keys()
	ids.reverse()
	for id in ids:
		var r: Rect2 = building_rects[id]
		var pad := r.grow(28.0)
		if pad.has_point(world_pos):
			return str(id)
	return ""


func _ignore_mouse(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _rect(color: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var body := ColorRect.new()
	body.color = color
	body.position = pos
	body.size = size
	_ignore_mouse(body)
	environment_root.add_child(body)
	return body


func _sprite(path: String, pos: Vector2, target_h: float = 0.0, target_w: float = 0.0) -> Sprite2D:
	var tex := _tex(path)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.position = pos
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var sx := 1.0
	var sy := 1.0
	if target_w > 0.0 and tw > 0.0:
		sx = target_w / tw
	if target_h > 0.0 and th > 0.0:
		sy = target_h / th
	if target_w > 0.0 and target_h <= 0.0:
		sy = sx
	elif target_h > 0.0 and target_w <= 0.0:
		sx = sy
	spr.scale = Vector2(sx, sy)
	environment_root.add_child(spr)
	return spr


func _sprite_bounds(spr: Sprite2D) -> Rect2:
	var tex: Texture2D = spr.texture
	var sz := Vector2(float(tex.get_width()) * spr.scale.x, float(tex.get_height()) * spr.scale.y)
	return Rect2(spr.position, sz)


func _label_at(text: String, pos: Vector2, font_size: int = 16) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	_ignore_mouse(label)
	environment_root.add_child(label)


func _add_building_sprite(id: String, path: String, pos: Vector2, target_h: float, title: String) -> void:
	var spr := _sprite(path, pos, target_h)
	if spr:
		var r := _sprite_bounds(spr)
		building_rects[id] = r
		_label_at(title, Vector2(r.position.x + 8.0, r.position.y + r.size.y - 28.0), 15)
	else:
		var rect := Rect2(pos, Vector2(180, 120))
		building_rects[id] = rect
		_rect(Color("1D6F9F"), rect.position, rect.size)
		_label_at(title, Vector2(rect.position.x + 8.0, rect.position.y + 40.0))


func _build_environment() -> void:
	var w := WorldConfig.WIDTH
	var h := WorldConfig.HEIGHT
	var shore := WorldConfig.SHORE_Y
	_rect(Color("4EC6C0"), Vector2.ZERO, Vector2(w, h))

	var water_tex := _tex(TEX_WATER)
	if water_tex:
		var water := Sprite2D.new()
		water.texture = water_tex
		water.centered = false
		water.position = Vector2.ZERO
		water.scale = Vector2(w / float(water_tex.get_width()), h / float(water_tex.get_height()))
		environment_root.add_child(water)

	## Depth tint: far/deep sea (north, small Y) more blue; near shore stays turquoise
	_add_sea_depth_tint(w, shore)

	## Beach / shore (taller land band)
	_rect(Color("E8D5A3"), Vector2(0, shore), Vector2(w, h - shore))
	## Inner dry sand
	_rect(Color("F0E0B8"), Vector2(0, shore + 120.0), Vector2(w, h - shore - 120.0))
	## Soft surf foam
	_rect(Color(1.0, 1.0, 1.0, 0.22), Vector2(0, WorldConfig.FOAM_Y), Vector2(w, 16))

	## Buildings first so scenery can avoid their footprints
	_build_pier_dock()
	_build_shore_buildings()
	_build_scenery()

	var dock_area := Area2D.new()
	dock_area.name = "DockArea"
	## Cover pier + berth water just outside the planks
	dock_area.position = Vector2(WorldConfig.DOCK_X + 60.0, shore - 80.0)
	dock_area.monitoring = true
	dock_area.collision_layer = 0
	dock_area.collision_mask = 1
	var dock_col := CollisionShape2D.new()
	var dock_shape := RectangleShape2D.new()
	dock_shape.size = Vector2(480, 720)
	dock_col.shape = dock_shape
	dock_area.add_child(dock_col)
	add_child(dock_area)


func _add_sea_depth_tint(w: float, shore: float) -> void:
	## Continuous vertical gradient: deep blue -> mid blue -> near turquoise (no hard bands).
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.28, 0.55, 0.78, 1.0])
	grad.colors = PackedColorArray([
		Color(0.04, 0.18, 0.72, 0.58),
		Color(0.08, 0.32, 0.78, 0.42),
		Color(0.14, 0.45, 0.72, 0.26),
		Color(0.28, 0.62, 0.70, 0.10),
		Color(0.35, 0.72, 0.68, 0.0),
	])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 8
	gtex.height = 512
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	var spr := Sprite2D.new()
	spr.name = "SeaDepthGradient"
	spr.texture = gtex
	spr.centered = false
	spr.position = Vector2.ZERO
	spr.scale = Vector2(w / float(gtex.width), shore / float(gtex.height))
	spr.z_index = 0
	environment_root.add_child(spr)


func _build_pier_dock() -> void:
	var shore := WorldConfig.SHORE_Y
	var dock_x := WorldConfig.DOCK_X
	var target_h := 520.0
	var pos := Vector2(dock_x - 80.0, shore - 220.0)
	var tex := _tex(TEX_PIER_DOCK)
	if tex:
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var scale := target_h / th
		var ww := tw * scale
		pos = Vector2(dock_x - ww * 0.5, shore - 220.0)
		var spr := _sprite(TEX_PIER_DOCK, pos, target_h)
		if spr:
			var r := _sprite_bounds(spr)
			building_rects["dock"] = r
			_label_at("\u7801\u5934", Vector2(r.position.x + r.size.x * 0.28, r.position.y + r.size.y - 36.0), 18)
			return
	building_rects["dock"] = Rect2(dock_x - 120.0, shore - 220.0, 240, 520)
	_rect(Color("6B4A38"), Vector2(dock_x - 80.0, shore + 200.0), Vector2(160, 100))
	_label_at("\u7801\u5934", Vector2(dock_x - 40.0, shore + 240.0))


func _build_shore_buildings() -> void:
	var shore := WorldConfig.SHORE_Y
	## Three shops in a row to the right of the pier, with breathing room
	var row_y := shore + 90.0
	var start_x := WorldConfig.DOCK_X + 220.0
	var gap := 360.0
	_add_building_sprite("toolshop", TEX_TOOLSHOP, Vector2(start_x, row_y), 180.0, "\u5de5\u5177\u5e97")
	_add_building_sprite("market", TEX_MARKET, Vector2(start_x + gap, row_y), 180.0, "\u6d77\u9c9c\u5e02\u573a")
	_add_building_sprite("encyclopedia", TEX_ENCY, Vector2(start_x + gap * 2.0, row_y), 175.0, "\u56fe\u9274\u6536\u85cf")


func _build_scenery() -> void:
	var shore := WorldConfig.SHORE_Y
	var dock_x := WorldConfig.DOCK_X
	var w := WorldConfig.WIDTH
	var land_bottom := WorldConfig.HEIGHT - 40.0

	## Occupancy: buildings + already placed decor
	var blocked: Array = []
	for id in building_rects.keys():
		blocked.append((building_rects[id] as Rect2).grow(28.0))

	## Dock-side props (tight to pier, not over shops)
	_place_decor(blocked, TEX_CRATES, Vector2(dock_x + 95.0, shore + 290.0), 70.0, 12.0)
	_place_decor(blocked, TEX_LIFEBUOY, Vector2(dock_x - 70.0, shore + 250.0), 80.0, 12.0)
	_place_decor(blocked, TEX_SIGN, Vector2(dock_x + 155.0, shore + 280.0), 0.0, 10.0, 70.0)

	## Near-pier palms / bushes
	var near_pier := [
		{"path": TEX_PALM_A, "pos": Vector2(dock_x - 220.0, shore + 30.0), "h": 145.0},
		{"path": TEX_PALM_B, "pos": Vector2(dock_x - 320.0, shore + 80.0), "h": 125.0},
		{"path": TEX_PALM_A, "pos": Vector2(dock_x + 160.0, shore + 15.0), "h": 130.0},
		{"path": TEX_BUSH, "pos": Vector2(dock_x - 160.0, shore + 260.0), "h": 50.0},
		{"path": TEX_BUSH_B, "pos": Vector2(dock_x + 175.0, shore + 270.0), "h": 46.0},
	]
	for d in near_pier:
		_place_decor(blocked, str(d.path), d.pos, float(d.h), 18.0)

	## Gaps between / behind shop buildings
	var shop_gaps := [
		{"path": TEX_PALM_B, "pos": Vector2(dock_x + 360.0, shore + 20.0), "h": 120.0},
		{"path": TEX_BUSH, "pos": Vector2(dock_x + 400.0, shore + 300.0), "h": 48.0},
		{"path": TEX_BUSH_B, "pos": Vector2(dock_x + 740.0, shore + 310.0), "h": 44.0},
		{"path": TEX_UMBRELLA, "pos": Vector2(dock_x + 420.0, shore + 320.0), "h": 88.0},
		{"path": TEX_PALM_A, "pos": Vector2(dock_x + 1080.0, shore + 25.0), "h": 135.0},
		{"path": TEX_BUSH, "pos": Vector2(dock_x + 1060.0, shore + 300.0), "h": 50.0},
		{"path": TEX_PALM_B, "pos": Vector2(dock_x + 720.0, shore + 15.0), "h": 125.0},
		{"path": TEX_UMBRELLA, "pos": Vector2(dock_x + 780.0, shore + 330.0), "h": 86.0},
	]
	for d in shop_gaps:
		_place_decor(blocked, str(d.path), d.pos, float(d.h), 20.0)

	## Left beach stretch (far from pier)
	var left_land := [
		{"path": TEX_PALM_A, "pos": Vector2(80.0, shore + 40.0), "h": 150.0},
		{"path": TEX_PALM_B, "pos": Vector2(260.0, shore + 70.0), "h": 130.0},
		{"path": TEX_PALM_A, "pos": Vector2(480.0, shore + 35.0), "h": 140.0},
		{"path": TEX_UMBRELLA, "pos": Vector2(180.0, shore + 220.0), "h": 92.0},
		{"path": TEX_UMBRELLA, "pos": Vector2(420.0, shore + 250.0), "h": 85.0},
		{"path": TEX_BUSH, "pos": Vector2(120.0, shore + 280.0), "h": 52.0},
		{"path": TEX_BUSH_B, "pos": Vector2(340.0, shore + 300.0), "h": 48.0},
		{"path": TEX_BUSH, "pos": Vector2(560.0, shore + 270.0), "h": 50.0},
		{"path": TEX_PALM_B, "pos": Vector2(700.0, shore + 55.0), "h": 128.0},
		{"path": TEX_BUSH_B, "pos": Vector2(760.0, shore + 290.0), "h": 46.0},
	]
	for d in left_land:
		_place_decor(blocked, str(d.path), d.pos, float(d.h), 22.0)

	## Far-right land past shops
	var right_land := [
		{"path": TEX_PALM_A, "pos": Vector2(2100.0, shore + 30.0), "h": 145.0},
		{"path": TEX_PALM_B, "pos": Vector2(2320.0, shore + 60.0), "h": 132.0},
		{"path": TEX_PALM_A, "pos": Vector2(2550.0, shore + 40.0), "h": 138.0},
		{"path": TEX_PALM_B, "pos": Vector2(2720.0, shore + 80.0), "h": 120.0},
		{"path": TEX_UMBRELLA, "pos": Vector2(2200.0, shore + 230.0), "h": 90.0},
		{"path": TEX_UMBRELLA, "pos": Vector2(2480.0, shore + 260.0), "h": 86.0},
		{"path": TEX_BUSH, "pos": Vector2(2050.0, shore + 290.0), "h": 52.0},
		{"path": TEX_BUSH_B, "pos": Vector2(2280.0, shore + 310.0), "h": 48.0},
		{"path": TEX_BUSH, "pos": Vector2(2520.0, shore + 280.0), "h": 50.0},
		{"path": TEX_BUSH_B, "pos": Vector2(2680.0, shore + 300.0), "h": 46.0},
	]
	for d in right_land:
		_place_decor(blocked, str(d.path), d.pos, float(d.h), 22.0)

	## Deep inland sprinkle
	var deep := [
		{"path": TEX_PALM_B, "pos": Vector2(150.0, shore + 360.0), "h": 118.0},
		{"path": TEX_PALM_A, "pos": Vector2(900.0, shore + 380.0), "h": 125.0},
		{"path": TEX_PALM_B, "pos": Vector2(1600.0, shore + 370.0), "h": 122.0},
		{"path": TEX_PALM_A, "pos": Vector2(2400.0, shore + 390.0), "h": 128.0},
		{"path": TEX_UMBRELLA, "pos": Vector2(600.0, shore + 360.0), "h": 84.0},
		{"path": TEX_UMBRELLA, "pos": Vector2(1900.0, shore + 350.0), "h": 88.0},
		{"path": TEX_BUSH, "pos": Vector2(400.0, shore + 400.0), "h": 48.0},
		{"path": TEX_BUSH_B, "pos": Vector2(1100.0, shore + 420.0), "h": 44.0},
		{"path": TEX_BUSH, "pos": Vector2(1450.0, shore + 410.0), "h": 50.0},
		{"path": TEX_BUSH_B, "pos": Vector2(1750.0, shore + 430.0), "h": 46.0},
		{"path": TEX_BUSH, "pos": Vector2(2150.0, shore + 400.0), "h": 48.0},
		{"path": TEX_BUSH_B, "pos": Vector2(2600.0, shore + 420.0), "h": 45.0},
	]
	for d in deep:
		var p: Vector2 = d.pos
		if p.y + float(d.h) > land_bottom:
			p.y = land_bottom - float(d.h) - 8.0
		if p.x < 20.0 or p.x > w - 80.0:
			continue
		_place_decor(blocked, str(d.path), p, float(d.h), 24.0)


func _place_decor(blocked: Array, path: String, pos: Vector2, target_h: float, pad: float, target_w: float = 0.0) -> Sprite2D:
	var tex := _tex(path)
	if tex == null:
		return null
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var sx := 1.0
	var sy := 1.0
	if target_w > 0.0 and tw > 0.0:
		sx = target_w / tw
		sy = sx
	elif target_h > 0.0 and th > 0.0:
		sy = target_h / th
		sx = sy
	var size := Vector2(tw * sx, th * sy)
	var cand := Rect2(pos, size)
	for b in blocked:
		if cand.intersects(b as Rect2):
			return null
	var spr := _sprite(path, pos, target_h, target_w)
	if spr:
		blocked.append(cand.grow(pad))
	return spr


func _build_spots() -> void:
	## All schools must stay on open water (y < SHORE_Y)
	var max_y := WorldConfig.SHORE_Y - 80.0
	var defs := [
		{"pos": Vector2(WorldConfig.map_x(360), 1600), "zone": "near"},
		{"pos": Vector2(WorldConfig.map_x(1080), 1500), "zone": "near"},
		{"pos": Vector2(WorldConfig.map_x(200), 1700), "zone": "near"},
		{"pos": Vector2(WorldConfig.map_x(1280), 1650), "zone": "near"},
		{"pos": Vector2(WorldConfig.map_x(480), 1100), "zone": "mid"},
		{"pos": Vector2(WorldConfig.map_x(1000), 900), "zone": "mid"},
		{"pos": Vector2(WorldConfig.map_x(200), 1000), "zone": "mid"},
		{"pos": Vector2(WorldConfig.map_x(720), 420), "zone": "far"},
		{"pos": Vector2(WorldConfig.map_x(400), 500), "zone": "far"},
		{"pos": Vector2(WorldConfig.map_x(1100), 380), "zone": "far"},
	]
	for d in defs:
		var p: Vector2 = d.pos
		if p.y >= max_y:
			p.y = max_y - 20.0
		var spot := Node2D.new()
		spot.set_script(SPOT_SCRIPT)
		spot.position = p
		spot.set("zone", d.zone)
		spot.set("catchable", true)
		spot.set("school_size", "normal")
		spots_root.add_child(spot)
		spot.call("build_visual")
	_build_ambient_schools()


func _build_storms() -> void:
	## Sparse storm patches on open water (not near dock)
	var root := get_node_or_null("Storms") as Node2D
	if root == null:
		root = Node2D.new()
		root.name = "Storms"
		## Between water env and boat: after Spots so rain draws over schools lightly
		add_child(root)
		move_child(root, spots_root.get_index() + 1)
	for c in root.get_children():
		c.queue_free()
	var defs := [
		{"pos": Vector2(520, 980), "kind": "small", "r": 190.0},
		{"pos": Vector2(2100, 720), "kind": "small", "r": 200.0},
		{"pos": Vector2(1680, 1180), "kind": "small", "r": 175.0},
		{"pos": Vector2(900, 480), "kind": "large", "r": 260.0},
		{"pos": Vector2(2400, 420), "kind": "large", "r": 250.0},
	]
	for d in defs:
		var p: Vector2 = d.pos
		if not WorldConfig.is_open_water(p):
			continue
		## Keep clear of dock berth
		if p.distance_to(WorldConfig.DOCK_BERTH) < 420.0:
			continue
		var storm := Node2D.new()
		storm.set_script(STORM_SCRIPT)
		storm.position = p
		storm.set("storm_kind", d.kind)
		storm.set("radius", d.r)
		root.add_child(storm)
		storm.call("build_visual")


func _build_ambient_schools() -> void:
	## Decorative schools on water only
	var max_y := WorldConfig.SHORE_Y - 100.0
	var defs := [
		{"pos": Vector2(360, 1780), "zone": "near"},
		{"pos": Vector2(1120, 1700), "zone": "near"},
		{"pos": Vector2(1840, 1750), "zone": "near"},
		{"pos": Vector2(2520, 1680), "zone": "near"},
		{"pos": Vector2(480, 1350), "zone": "mid"},
		{"pos": Vector2(1400, 1280), "zone": "mid"},
		{"pos": Vector2(2360, 1200), "zone": "mid"},
		{"pos": Vector2(800, 750), "zone": "mid"},
		{"pos": Vector2(1800, 650), "zone": "far"},
		{"pos": Vector2(1040, 500), "zone": "far"},
		{"pos": Vector2(2200, 380), "zone": "far"},
		{"pos": Vector2(560, 980), "zone": "mid"},
	]
	for d in defs:
		var p: Vector2 = d.pos
		if p.y >= max_y:
			continue
		var spot := Node2D.new()
		spot.set_script(SPOT_SCRIPT)
		spot.position = p
		spot.set("zone", d.zone)
		spot.set("catchable", false)
		spot.set("school_size", "small")
		spots_root.add_child(spot)
		spot.call("build_visual")


func _build_boat_visual() -> void:
	if boat == null:
		return
	var root: Node2D = boat.get_node_or_null("Visual")
	if root == null:
		return
	for c in root.get_children():
		root.remove_child(c)
		c.free()

	## Hull from currently equipped boat
	var boat_path := GameState.get_boat_texture()
	var boat_tex := _tex(boat_path)
	if boat_tex == null:
		boat_tex = _tex(TEX_BOAT_FALLBACK)
	var hull_h := 110.0
	if boat_tex:
		var spr := Sprite2D.new()
		spr.name = "Hull"
		spr.texture = boat_tex
		spr.centered = true
		var th := float(boat_tex.get_height())
		var s := hull_h / maxf(th, 1.0)
		spr.scale = Vector2(s, s)
		root.add_child(spr)
	else:
		var hull := ColorRect.new()
		hull.name = "Hull"
		hull.color = Color("F5F5F5")
		hull.position = Vector2(-28, -48)
		hull.size = Vector2(56, 96)
		_ignore_mouse(hull)
		root.add_child(hull)

	## Top-down standing rod planted on stern deck
	_add_standing_rod(root)


func _stand_rod_texture_path() -> String:
	match str(GameState.equipped_rod):
		"rod_carbon":
			return "res://assets/world/gear/rod_carbon_stand.png"
		"rod_legend":
			return "res://assets/world/gear/rod_legend_stand.png"
		_:
			return "res://assets/world/gear/rod_bamboo_stand.png"


func _add_standing_rod(root: Node2D) -> void:
	## Dedicated top-down stand art so the rod reads as upright on deck.
	var rod_tex := _tex(_stand_rod_texture_path())
	if rod_tex == null:
		rod_tex = _tex(GameState.get_rod_texture())
	if rod_tex == null:
		return

	var mount := Node2D.new()
	mount.name = "RodMount"
	## Stern starboard near grate/crates
	mount.position = Vector2(14, 28)
	mount.z_index = 2
	root.add_child(mount)

	var socket := _circle_poly(6.0, Color(0.16, 0.14, 0.12, 0.9))
	socket.name = "Socket"
	mount.add_child(socket)

	var rod := Sprite2D.new()
	rod.name = "Rod"
	rod.texture = rod_tex
	rod.centered = true
	var rw := float(rod_tex.get_width())
	var rh := float(rod_tex.get_height())
	## Pivot near handle/reel at bottom of stand art
	var handle := Vector2(rw * 0.42, rh * 0.78)
	var center := Vector2(rw * 0.5, rh * 0.5)
	rod.offset = center - handle
	var rs := 78.0 / maxf(rh, 1.0)
	rod.scale = Vector2(rs, rs)
	## Slight outboard lean
	rod.rotation = deg_to_rad(18.0)
	mount.add_child(rod)


func _circle_poly(radius: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	var pts := PackedVector2Array()
	var n := 14
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	return poly
