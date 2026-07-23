extends Node

## 鱼类静态数据库

const DATA_PATH := "res://data/fish.json"
const RARITY_WEIGHT := {"common": 1.0, "rare": 0.35, "legend": 0.08}
const ZONE_NAMES := {"near": "近海", "mid": "中海", "far": "远海"}
const RARITY_NAMES := {"common": "常见", "rare": "稀有", "legend": "传说"}

var fish_list: Array = []
var fish_by_id: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if not f:
		push_error("无法读取鱼类数据: %s" % DATA_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	fish_list = parsed.get("fish", [])
	fish_by_id.clear()
	for item in fish_list:
		fish_by_id[item.id] = item


func get_fish(id: String) -> Dictionary:
	return fish_by_id.get(id, {})


func get_all() -> Array:
	return fish_list


func zone_display(zone: String) -> String:
	return ZONE_NAMES.get(zone, zone)


func rarity_display(rarity: String) -> String:
	return RARITY_NAMES.get(rarity, rarity)


func get_color_for_fish(id: String) -> Color:
	## Fallback color when texture missing
	var palette := {
		"sardine": Color("6EC6FF"),
		"mackerel": Color("3A7D6A"),
		"sea_bream": Color("F4A261"),
		"clownfish": Color("FF8C42"),
		"pufferfish": Color("8ECAE6"),
		"butterflyfish": Color("FFD166"),
		"tuna": Color("1D3557"),
		"sailfish": Color("457B9D"),
		"mahi": Color("2A9D8F"),
		"snapper": Color("E63946"),
		"grouper": Color("6D6875"),
		"king_mackerel": Color("E9C46A"),
	}
	return palette.get(id, Color.WHITE)


func get_texture_path(id: String) -> String:
	return "res://assets/fish/%s.png" % id


func get_texture(id: String) -> Texture2D:
	var path := get_texture_path(id)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## kg range per species (min, max). JSON may override with weight_min / weight_max.
const WEIGHT_RANGE := {
	"sardine": Vector2(0.2, 0.6),
	"mackerel": Vector2(0.5, 1.4),
	"sea_bream": Vector2(0.8, 2.2),
	"clownfish": Vector2(0.15, 0.45),
	"pufferfish": Vector2(0.6, 1.8),
	"butterflyfish": Vector2(0.2, 0.7),
	"tuna": Vector2(3.0, 8.0),
	"sailfish": Vector2(4.0, 12.0),
	"mahi": Vector2(2.5, 7.5),
	"snapper": Vector2(1.5, 4.5),
	"grouper": Vector2(3.5, 10.0),
	"king_mackerel": Vector2(6.0, 16.0),
}


func get_weight_range(fish_id: String) -> Vector2:
	var fish := get_fish(fish_id)
	if fish.has("weight_min") and fish.has("weight_max"):
		return Vector2(float(fish.weight_min), float(fish.weight_max))
	if WEIGHT_RANGE.has(fish_id):
		return WEIGHT_RANGE[fish_id]
	match str(fish.get("rarity", "common")):
		"legend":
			return Vector2(6.0, 16.0)
		"rare":
			return Vector2(2.0, 8.0)
		_:
			return Vector2(0.3, 2.0)


func get_standard_weight(fish_id: String) -> float:
	var r := get_weight_range(fish_id)
	return (r.x + r.y) * 0.5


func get_tags(fish_id: String) -> Array:
	var fish := get_fish(fish_id)
	var tags = fish.get("tags", [])
	if typeof(tags) != TYPE_ARRAY:
		return []
	return tags


func has_tag(fish_id: String, tag: String) -> bool:
	return get_tags(fish_id).has(tag)


## Pull curve for tension reel: steady / burst / slippery
func get_pull_curve(fish_id: String) -> String:
	var fish := get_fish(fish_id)
	var curve := str(fish.get("pull_curve", ""))
	if curve == "steady" or curve == "burst" or curve == "slippery":
		return curve
	## Fallback from tags
	if has_tag(fish_id, "aggressive"):
		return "burst"
	if has_tag(fish_id, "large"):
		return "burst"
	if has_tag(fish_id, "small"):
		return "steady"
	return "steady"


func pull_curve_display(curve: String) -> String:
	match curve:
		"burst":
			return "\u7206\u53d1\u578b"
		"slippery":
			return "\u6ed1\u5934\u578b"
		_:
			return "\u6301\u7eed\u578b"


func roll_weight(fish_id: String, bait_id: String = "") -> float:
	var r := get_weight_range(fish_id)
	var lo := r.x
	var hi := r.y
	var bid := bait_id if not bait_id.is_empty() else str(GameState.equipped_bait)
	var bait_def: Dictionary = GameState.get_bait_def(bid)
	var bias := str(bait_def.get("weight_bias", "none"))
	if bias == "large":
		if has_tag(fish_id, "large"):
			lo = lerpf(r.x, r.y, 0.15)
		elif has_tag(fish_id, "small"):
			hi = lerpf(r.x, r.y, 0.85)
	elif bias == "small":
		if has_tag(fish_id, "small"):
			lo = lerpf(r.x, r.y, 0.05)
			hi = lerpf(r.x, r.y, 0.9)
		elif has_tag(fish_id, "large"):
			hi = lerpf(r.x, r.y, 0.88)
	return snappedf(randf_range(lo, hi), 0.1)


func roll_fish(zone: String, rod_level: int, tide_rare_mul: float, bait_id: String = "") -> String:
	var bait := bait_id if not bait_id.is_empty() else str(GameState.equipped_bait)
	var bait_def: Dictionary = GameState.get_bait_def(bait)
	var candidates: Array = []
	var weights: Array = []
	for item in fish_list:
		if item.zone != zone:
			continue
		var w: float = RARITY_WEIGHT.get(item.rarity, 0.1)
		w *= tide_rare_mul
		if item.rarity != "common":
			w *= 1.0 + 0.15 * float(rod_level - 1)
		w *= _bait_mul(item, bait_def)
		candidates.append(item.id)
		weights.append(maxf(w, 0.001))
	if candidates.is_empty():
		return "sardine"
	var total := 0.0
	for w in weights:
		total += w
	var r := randf() * total
	var acc := 0.0
	for i in candidates.size():
		acc += weights[i]
		if r <= acc:
			return candidates[i]
	return candidates[0]


func _bait_mul(item: Dictionary, bait_def: Dictionary) -> float:
	var mul := 1.0
	if bait_def.is_empty():
		return mul
	var tags: Array = item.get("tags", [])
	if typeof(tags) != TYPE_ARRAY:
		tags = []
	var rarity := str(item.get("rarity", "common"))
	var tag_mul: Dictionary = bait_def.get("tag_mul", {})
	for t in tags:
		if tag_mul.has(t):
			mul *= float(tag_mul[t])
	var rarity_mul: Dictionary = bait_def.get("rarity_mul", {})
	if rarity_mul.has(rarity):
		mul *= float(rarity_mul[rarity])
	return mul
