extends Node

## Global player state: gold, cargo, fuel, upgrades, shop gear, encyclopedia

signal resources_changed
signal cargo_changed
signal discovered_changed
signal gear_changed
signal toast(message: String)

const SAVE_PATH := "user://save.json"

const BOAT_CATALOG := [
	{
		"id": "boat_basic",
		"name": "\u6728\u58f3\u6e14\u8239",
		"desc": "\u5165\u95e8\u6728\u8239\uff0c\u7a33\u5065\u8010\u7528",
		"price": 0,
		"cargo": 4,
		"fuel": 95,
		"speed": 220,
		"texture": "res://assets/world/gear/boat_basic.png",
	},
	{
		"id": "boat_speed",
		"name": "\u8fd1\u6d77\u5feb\u8247",
		"desc": "\u8f7b\u5feb\u7075\u5de7\uff0c\u9002\u5408\u8ffd\u6f6e",
		"price": 680,
		"cargo": 5,
		"fuel": 110,
		"speed": 300,
		"texture": "res://assets/world/gear/boat_speed.png",
	},
	{
		"id": "boat_cargo",
		"name": "\u8fd0\u8d27\u6e14\u8239",
		"desc": "\u5927\u8d27\u8231\uff0c\u4e00\u8d9f\u88c5\u66f4\u591a",
		"price": 980,
		"cargo": 8,
		"fuel": 140,
		"speed": 200,
		"texture": "res://assets/world/gear/boat_cargo.png",
	},
]

const ROD_CATALOG := [
	{
		"id": "rod_bamboo",
		"name": "\u7af9\u5236\u9493\u7aff",
		"desc": "\u7ecf\u5178\u7af9\u7aff\uff0c\u5165\u95e8\u4e4b\u9009",
		"price": 0,
		"level": 1,
		"texture": "res://assets/world/gear/rod_bamboo.png",
	},
	{
		"id": "rod_carbon",
		"name": "\u78b3\u7d20\u9493\u7aff",
		"desc": "\u8f7b\u91cf\u654f\u9510\uff0c\u63d0\u5347\u4e2d\u9c7c\u7387",
		"price": 420,
		"level": 3,
		"texture": "res://assets/world/gear/rod_carbon.png",
	},
	{
		"id": "rod_legend",
		"name": "\u4f20\u8bf4\u6d77\u7aff",
		"desc": "\u6df1\u6d77\u4e13\u7528\uff0c\u7a00\u6709\u9c7c\u66f4\u6613\u51fa",
		"price": 1100,
		"level": 5,
		"texture": "res://assets/world/gear/rod_legend.png",
	},
]

## Consumable bait (buy packs in tool shop). bait_plain is infinite starter bait.
const BAIT_CATALOG := [
	{
		"id": "bait_plain",
		"name": "\u666e\u901a\u9975",
		"desc": "\u5165\u95e8\u9975\u6599\uff0c\u6c38\u4e0d\u8017\u5c3d",
		"price": 0,
		"pack": 0,
		"infinite": true,
		"tag_mul": {},
		"rarity_mul": {},
		"weight_bias": "none",
		"texture": "res://assets/world/gear/bait_plain.png",
	},
	{
		"id": "bait_stink",
		"name": "\u8165\u9975",
		"desc": "\u5438\u5f15\u5e95\u5c42\u9c7c\uff0c\u8fd1\u6d77\u7a33\u8d5a",
		"price": 80,
		"pack": 5,
		"infinite": false,
		"tag_mul": {"bottom": 1.85},
		"rarity_mul": {},
		"weight_bias": "none",
		"texture": "res://assets/world/gear/bait_stink.png",
	},
	{
		"id": "bait_flash",
		"name": "\u4eae\u9975",
		"desc": "\u5438\u5f15\u653b\u51fb\u6027/\u7a00\u6709\u9c7c",
		"price": 120,
		"pack": 5,
		"infinite": false,
		"tag_mul": {"aggressive": 1.7, "large": 1.15},
		"rarity_mul": {"rare": 1.35, "legend": 1.5},
		"weight_bias": "large",
		"texture": "res://assets/world/gear/bait_flash.png",
	},
	{
		"id": "bait_lure",
		"name": "\u62df\u9975",
		"desc": "\u5f3a\u5316\u91d1\u67aa/\u65d7\u9c7c/\u9c9b\u738b",
		"price": 150,
		"pack": 5,
		"infinite": false,
		"tag_mul": {"lure": 2.2, "large": 1.2},
		"rarity_mul": {},
		"weight_bias": "large",
		"texture": "res://assets/world/gear/bait_lure.png",
	},
]

var gold: int = 480
var fuel: float = 95.0
var fuel_max: float = 95.0
var cargo_capacity: int = 4
var boat_level: int = 1
var rod_level: int = 1
var boat_upgrade_cost: int = 180
var rod_upgrade_cost: int = 150
var boat_speed: float = 220.0
## Hull integrity 0..100 (100 = mint). Wear rises while sailing; storm wears faster.
var boat_hull: float = 100.0
var boat_hull_max: float = 100.0
var _hull_wear_unsaved: float = 0.0

var at_harbor: bool = true
var owned_boats: Array = ["boat_basic"]
var owned_rods: Array = ["rod_bamboo"]
var equipped_boat: String = "boat_basic"
var equipped_rod: String = "rod_bamboo"
var equipped_bait: String = "bait_plain"
var bait_inv: Dictionary = {}

## Cargo entry: { "id": String, "perfect": bool, "weight": float }
var cargo: Array = []
var discovered: Dictionary = {}


func _ready() -> void:
	load_game()
	_apply_equipped_gear(false)


func get_cargo_count() -> int:
	return cargo.size()


func is_cargo_full() -> bool:
	return cargo.size() >= cargo_capacity


func get_discovered_count() -> int:
	return discovered.size()


func add_gold(amount: int) -> void:
	gold = max(0, gold + amount)
	resources_changed.emit()
	save_game()


func spend_gold(amount: int) -> bool:
	if gold < amount:
		toast.emit("\u91d1\u5e01\u4e0d\u8db3")
		Sfx.play("fail", 1.0, -5.0)
		return false
	gold -= amount
	resources_changed.emit()
	save_game()
	return true


func consume_fuel(amount: float) -> void:
	fuel = clampf(fuel - amount, 0.0, fuel_max)
	resources_changed.emit()


func refill_fuel() -> void:
	fuel = fuel_max
	resources_changed.emit()
	save_game()


func get_hull_ratio() -> float:
	return clampf(boat_hull / maxf(boat_hull_max, 1.0), 0.0, 1.0)


func get_hull_speed_mul() -> float:
	## Heavily worn boats crawl; below 15% hull crawl hard
	var r := get_hull_ratio()
	if r >= 0.7:
		return 1.0
	if r >= 0.35:
		return lerpf(0.72, 1.0, (r - 0.35) / 0.35)
	return lerpf(0.35, 0.72, r / 0.35)


func get_repair_cost() -> int:
	var missing := boat_hull_max - boat_hull
	if missing <= 0.5:
		return 0
	## ~2 gold per hull point, min 20 when damaged
	return maxi(20, int(ceil(missing * 2.0)))


func apply_boat_wear(amount: float) -> void:
	if amount <= 0.0:
		return
	var before := boat_hull
	boat_hull = clampf(boat_hull - amount, 0.0, boat_hull_max)
	_hull_wear_unsaved += before - boat_hull
	if int(before) != int(boat_hull):
		resources_changed.emit()
	if before > 5.0 and boat_hull <= 5.0:
		toast.emit("\u8239\u4f53\u4e25\u91cd\u6469\u635f\uff01\u8bf7\u56de\u7801\u5934\u7ef4\u4fee")
	elif before > 30.0 and boat_hull <= 30.0:
		toast.emit("\u8239\u4f53\u6469\u635f\u8f83\u591a\uff0c\u901f\u5ea6\u4e0b\u964d")
	if _hull_wear_unsaved >= 5.0:
		_hull_wear_unsaved = 0.0
		save_game()


func repair_boat() -> bool:
	var cost := get_repair_cost()
	if cost <= 0:
		toast.emit("\u8239\u4f53\u72b6\u51b5\u826f\u597d\uff0c\u65e0\u9700\u7ef4\u4fee")
		return false
	if not at_harbor:
		toast.emit("\u8bf7\u5728\u7801\u5934\u7ef4\u4fee\u8239\u4f53")
		return false
	if not spend_gold(cost):
		return false
	boat_hull = boat_hull_max
	toast.emit("\u8239\u4f53\u5df2\u4fee\u590d")
	Sfx.upgrade()
	resources_changed.emit()
	gear_changed.emit()
	save_game()
	return true


func add_to_cargo(fish_id: String, perfect: bool = false, weight: float = -1.0) -> bool:
	if is_cargo_full():
		toast.emit("\u8d27\u8231\u5df2\u6ee1\uff0c\u8bf7\u56de\u7801\u5934\u5356\u51fa")
		return false
	var w := weight
	if w <= 0.0:
		w = FishDB.roll_weight(fish_id)
	cargo.append({"id": fish_id, "perfect": perfect, "weight": w})
	var is_new := not discovered.has(fish_id)
	discovered[fish_id] = true
	cargo_changed.emit()
	if is_new:
		discovered_changed.emit()
	resources_changed.emit()
	save_game()
	return true


func sell_cargo() -> int:
	if cargo.is_empty():
		toast.emit("\u8d27\u8231\u662f\u7a7a\u7684")
		Sfx.play("fail", 1.0, -6.0)
		return 0
	## Market buys cargo: same-species dump drops price during + after sale
	var total: int = Market.buy_from_player(cargo)
	cargo.clear()
	add_gold(total)
	cargo_changed.emit()
	if total > 0:
		toast.emit("\u5356\u51fa\u8d27\u8231 +%d \u91d1\u5e01" % total)
		Sfx.coin()
	else:
		toast.emit("\u8d27\u8231\u662f\u7a7a\u7684")
		Sfx.play("fail", 1.0, -6.0)
	save_game()
	return total


func upgrade_boat() -> bool:
	if not spend_gold(boat_upgrade_cost):
		return false
	boat_level += 1
	cargo_capacity = mini(8, cargo_capacity + 1)
	fuel_max += 10.0
	fuel = fuel_max
	boat_upgrade_cost = int(round(boat_upgrade_cost * 1.5))
	toast.emit("\u8239\u53ea\u5347\u7ea7\u6210\u529f\uff01\u8d27\u8231 %d" % cargo_capacity)
	Sfx.upgrade()
	resources_changed.emit()
	gear_changed.emit()
	save_game()
	return true


func upgrade_rod() -> bool:
	if not spend_gold(rod_upgrade_cost):
		return false
	rod_level += 1
	rod_upgrade_cost = int(round(rod_upgrade_cost * 1.5))
	toast.emit("\u9493\u7aff\u5347\u7ea7\u6210\u529f\uff01\u7b49\u7ea7 %d" % rod_level)
	Sfx.upgrade()
	resources_changed.emit()
	gear_changed.emit()
	save_game()
	return true


func owns_boat(id: String) -> bool:
	return owned_boats.has(id)


func owns_rod(id: String) -> bool:
	return owned_rods.has(id)


func get_boat_def(id: String) -> Dictionary:
	for b in BOAT_CATALOG:
		if str(b.id) == id:
			return b as Dictionary
	return {}


func get_rod_def(id: String) -> Dictionary:
	for r in ROD_CATALOG:
		if str(r.id) == id:
			return r as Dictionary
	return {}


func get_bait_def(id: String) -> Dictionary:
	for b in BAIT_CATALOG:
		if str(b.id) == id:
			return b as Dictionary
	return {}


func is_bait_infinite(id: String) -> bool:
	var def: Dictionary = get_bait_def(id)
	return bool(def.get("infinite", false))


func get_bait_count(id: String) -> int:
	if is_bait_infinite(id):
		return 9999
	return int(bait_inv.get(id, 0))


func get_bait_texture(id: String = "") -> String:
	var bid := equipped_bait if id.is_empty() else id
	var def: Dictionary = get_bait_def(bid)
	if def.is_empty():
		return "res://assets/world/gear/bait_plain.png"
	return str(def.get("texture", "res://assets/world/gear/bait_plain.png"))


func buy_bait(id: String) -> bool:
	var def: Dictionary = get_bait_def(id)
	if def.is_empty():
		return false
	if bool(def.get("infinite", false)):
		toast.emit("\u666e\u901a\u9975\u6c38\u4e0d\u8017\u5c3d\uff0c\u65e0\u9700\u8d2d\u4e70")
		return false
	if not spend_gold(int(def.price)):
		return false
	var pack := int(def.get("pack", 5))
	bait_inv[id] = get_bait_count(id) + pack
	toast.emit("\u8d2d\u4e70%s x%d" % [str(def.name), pack])
	Sfx.coin()
	resources_changed.emit()
	gear_changed.emit()
	save_game()
	return true


func set_equipped_bait(id: String) -> void:
	if id.is_empty():
		equipped_bait = "bait_plain"
		gear_changed.emit()
		save_game()
		return
	if not is_bait_infinite(id) and get_bait_count(id) <= 0:
		toast.emit("\u9975\u6599\u4e0d\u8db3")
		return
	equipped_bait = id
	gear_changed.emit()
	save_game()


func consume_bait() -> bool:
	## Infinite plain bait never depletes. Empty -> treat as plain.
	if equipped_bait.is_empty():
		equipped_bait = "bait_plain"
	if is_bait_infinite(equipped_bait):
		return true
	var n := get_bait_count(equipped_bait)
	if n <= 0:
		equipped_bait = "bait_plain"
		toast.emit("\u9975\u6599\u5df2\u7528\u5b8c\uff0c\u5207\u56de\u666e\u901a\u9975")
		gear_changed.emit()
		save_game()
		return true
	bait_inv[equipped_bait] = n - 1
	if get_bait_count(equipped_bait) <= 0:
		bait_inv.erase(equipped_bait)
		equipped_bait = "bait_plain"
		toast.emit("\u9975\u6599\u5df2\u7528\u5b8c\uff0c\u5207\u56de\u666e\u901a\u9975")
	resources_changed.emit()
	gear_changed.emit()
	save_game()
	return true


func buy_boat(id: String) -> bool:
	if owns_boat(id):
		toast.emit("\u5df2\u62e5\u6709\u8be5\u6e14\u8239")
		return false
	var def: Dictionary = get_boat_def(id)
	if def.is_empty():
		return false
	if not spend_gold(int(def.price)):
		return false
	owned_boats.append(id)
	if at_harbor:
		equip_boat(id)
	else:
		toast.emit("\u8d2d\u4e70\u6210\u529f\uff1a%s\uff08\u56de\u7801\u5934\u53ef\u88c5\u5907\uff09" % str(def.name))
		Sfx.coin()
		save_game()
		return true
	toast.emit("\u8d2d\u4e70\u6210\u529f\uff1a%s" % str(def.name))
	Sfx.coin()
	return true


func buy_rod(id: String) -> bool:
	if owns_rod(id):
		toast.emit("\u5df2\u62e5\u6709\u8be5\u9493\u7aff")
		return false
	var def: Dictionary = get_rod_def(id)
	if def.is_empty():
		return false
	if not spend_gold(int(def.price)):
		return false
	owned_rods.append(id)
	equip_rod(id)
	toast.emit("\u8d2d\u4e70\u6210\u529f\uff1a%s" % str(def.name))
	Sfx.coin()
	return true


func equip_boat(id: String) -> void:
	if not at_harbor:
		toast.emit("\u8bf7\u5728\u7801\u5934\u66f4\u6362\u6e14\u8239")
		return
	if not owns_boat(id):
		return
	equipped_boat = id
	_apply_equipped_gear(true)
	var def: Dictionary = get_boat_def(id)
	toast.emit("\u5df2\u88c5\u5907\uff1a%s" % str(def.get("name", "\u6e14\u8239")))
	save_game()


func equip_rod(id: String) -> void:
	if not owns_rod(id):
		return
	## Direct replace current rod (no unequip step)
	equipped_rod = id
	_apply_equipped_gear(true)
	var def: Dictionary = get_rod_def(id)
	toast.emit("\u5df2\u88c5\u5907\uff1a%s" % str(def.get("name", "\u9493\u7aff")))
	save_game()



func unequip_boat() -> void:
	## Fall back to starter boat
	if not at_harbor:
		toast.emit("\u8bf7\u5728\u7801\u5934\u66f4\u6362\u6e14\u8239")
		return
	if owns_boat("boat_basic"):
		equipped_boat = "boat_basic"
		_apply_equipped_gear(true)
		toast.emit("\u5df2\u6362\u56de\u5165\u95e8\u8239")
		save_game()
	else:
		toast.emit("\u65e0\u6cd5\u5378\u4e0b")


func unequip_rod() -> void:
	if owns_rod("rod_bamboo"):
		equipped_rod = "rod_bamboo"
		_apply_equipped_gear(true)
		toast.emit("\u5df2\u6362\u56de\u5165\u95e8\u7aff")
		save_game()
	else:
		toast.emit("\u65e0\u6cd5\u5378\u4e0b")


func get_boat_texture(id: String = "") -> String:
	var bid := equipped_boat if id.is_empty() else id
	var def: Dictionary = get_boat_def(bid)
	if def.is_empty():
		return "res://assets/world/gear/boat_basic.png"
	return str(def.get("texture", "res://assets/world/gear/boat_basic.png"))


func get_rod_texture(id: String = "") -> String:
	var rid := equipped_rod if id.is_empty() else id
	var def: Dictionary = get_rod_def(rid)
	if def.is_empty():
		return "res://assets/world/gear/rod_bamboo.png"
	return str(def.get("texture", "res://assets/world/gear/rod_bamboo.png"))


func _apply_equipped_gear(_emit_toast_skip: bool = true) -> void:
	var bdef: Dictionary = get_boat_def(equipped_boat)
	if not bdef.is_empty():
		## Switching boats replaces dock vessel stats from catalog
		cargo_capacity = maxi(int(bdef.cargo), boat_level + 3)
		fuel_max = maxf(float(bdef.fuel), 85.0 + float(boat_level - 1) * 10.0)
		boat_speed = float(bdef.speed)
		fuel = minf(fuel, fuel_max)
	var rdef: Dictionary = get_rod_def(equipped_rod)
	if not rdef.is_empty():
		rod_level = maxi(int(rdef.level), rod_level)
	resources_changed.emit()
	gear_changed.emit()


func is_discovered(fish_id: String) -> bool:
	return discovered.has(fish_id)


func save_game() -> void:
	var data := {
		"gold": gold,
		"fuel": fuel,
		"fuel_max": fuel_max,
		"cargo_capacity": cargo_capacity,
		"boat_level": boat_level,
		"rod_level": rod_level,
		"boat_upgrade_cost": boat_upgrade_cost,
		"rod_upgrade_cost": rod_upgrade_cost,
		"boat_speed": boat_speed,
		"boat_hull": boat_hull,
		"boat_hull_max": boat_hull_max,
		"owned_boats": owned_boats,
		"owned_rods": owned_rods,
		"equipped_boat": equipped_boat,
		"equipped_rod": equipped_rod,
		"equipped_bait": equipped_bait,
		"bait_inv": bait_inv,
		"cargo": cargo,
		"discovered": discovered.keys(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	gold = int(parsed.get("gold", gold))
	fuel = float(parsed.get("fuel", fuel))
	fuel_max = float(parsed.get("fuel_max", fuel_max))
	cargo_capacity = int(parsed.get("cargo_capacity", cargo_capacity))
	boat_level = int(parsed.get("boat_level", boat_level))
	rod_level = int(parsed.get("rod_level", rod_level))
	boat_upgrade_cost = int(parsed.get("boat_upgrade_cost", boat_upgrade_cost))
	rod_upgrade_cost = int(parsed.get("rod_upgrade_cost", rod_upgrade_cost))
	boat_speed = float(parsed.get("boat_speed", boat_speed))
	boat_hull = float(parsed.get("boat_hull", boat_hull))
	boat_hull_max = float(parsed.get("boat_hull_max", boat_hull_max))
	boat_hull = clampf(boat_hull, 0.0, boat_hull_max)
	owned_boats = parsed.get("owned_boats", owned_boats)
	owned_rods = parsed.get("owned_rods", owned_rods)
	equipped_boat = str(parsed.get("equipped_boat", equipped_boat))
	equipped_rod = str(parsed.get("equipped_rod", equipped_rod))
	equipped_bait = str(parsed.get("equipped_bait", equipped_bait))
	var inv = parsed.get("bait_inv", bait_inv)
	if typeof(inv) == TYPE_DICTIONARY:
		bait_inv = {}
		for k in inv.keys():
			bait_inv[str(k)] = int(inv[k])
	## Migrate old line-set saves into bait inventory once
	var old_line := str(parsed.get("equipped_line", ""))
	var _line_to_bait := {
		"line_basic": "bait_plain",
		"line_bottom": "bait_stink",
		"line_flash": "bait_flash",
		"line_lure": "bait_lure",
		"line_thin": "bait_plain",
		"line_thick": "bait_flash",
	}
	if equipped_bait.is_empty() and _line_to_bait.has(old_line):
		equipped_bait = str(_line_to_bait[old_line])
	## Plain bait is infinite - drop legacy inventory stacks
	if bait_inv.has("bait_plain"):
		bait_inv.erase("bait_plain")
	if equipped_bait.is_empty() or get_bait_def(equipped_bait).is_empty():
		equipped_bait = "bait_plain"
	elif not is_bait_infinite(equipped_bait) and get_bait_count(equipped_bait) <= 0:
		equipped_bait = "bait_plain"
	cargo = parsed.get("cargo", [])
	discovered.clear()
	for id in parsed.get("discovered", []):
		discovered[str(id)] = true
