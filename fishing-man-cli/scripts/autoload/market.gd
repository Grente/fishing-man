extends Node

## Seafood market: daily prices react to player dumping supply

signal prices_changed

const REFRESH_SEC := 90.0
const SAVE_PATH := "user://market.json"
## Per extra same-species fish in one sell batch
const BATCH_DUMP_STEP := 0.08
const BATCH_DUMP_CAP := 0.35
## Lasting supply shock after a sale (per fish sold)
const SHOCK_PER_FISH := 0.07
const SHOCK_CAP := 0.55
const PRESSURE_DECAY := 0.28
const PRICE_FLOOR_RATIO := 0.38

var prices: Dictionary = {} ## id -> today price
var changes: Dictionary = {} ## id -> percent change vs previous quote
var supply_pressure: Dictionary = {} ## id -> 0..SHOCK_CAP (sold a lot lately)
var sentiment: String = "\u4e70\u6c14\u5e73\u7a33"
var up_count: int = 0
var down_count: int = 0

var _timer: float = 0.0


func _ready() -> void:
	_load_state()
	refresh_prices(true)


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= REFRESH_SEC:
		_timer = 0.0
		refresh_prices(false)


func refresh_prices(initial: bool = false) -> void:
	up_count = 0
	down_count = 0
	var bias := Tide.get_market_bias()
	for item in FishDB.get_all():
		var id: String = str(item.id)
		var base: int = int(item.base_price)
		## Pressure slowly fades when you stop dumping
		var pressure: float = float(supply_pressure.get(id, 0.0))
		if not initial:
			pressure = maxf(0.0, pressure * (1.0 - PRESSURE_DECAY))
			supply_pressure[id] = pressure
		var delta_pct := randf_range(-0.14, 0.18) + bias
		## Oversupply pulls quotes down
		delta_pct -= pressure * 0.85
		delta_pct = clampf(delta_pct, -0.35, 0.28)
		var target := maxi(_floor_price(base), int(round(float(base) * (1.0 + delta_pct))))
		## Soft blend toward target so one refresh does not erase dump impact
		var price: int = target
		if not initial and prices.has(id):
			var oldp: int = int(prices[id])
			price = maxi(_floor_price(base), int(round(lerpf(float(oldp), float(target), 0.55))))
			if oldp > 0:
				delta_pct = float(price - oldp) / float(oldp)
		prices[id] = price
		changes[id] = delta_pct
		if delta_pct >= 0.0:
			up_count += 1
		else:
			down_count += 1
	_update_sentiment()
	prices_changed.emit()
	_save_state()


func _floor_price(base: int) -> int:
	return maxi(1, int(round(float(base) * PRICE_FLOOR_RATIO)))


func _update_sentiment() -> void:
	if up_count >= down_count + 2:
		sentiment = "\u4e70\u6c14\u65fa\u76db"
	elif down_count >= up_count + 2:
		sentiment = "\u4e70\u6c14\u6e05\u6de1"
	else:
		sentiment = "\u4e70\u6c14\u5e73\u7a33"


func get_price(fish_id: String) -> int:
	if prices.has(fish_id):
		return int(prices[fish_id])
	var fish := FishDB.get_fish(fish_id)
	return int(fish.get("base_price", 1))


func get_change(fish_id: String) -> float:
	return float(changes.get(fish_id, 0.0))


func get_supply_pressure(fish_id: String) -> float:
	return float(supply_pressure.get(fish_id, 0.0))


func get_sell_price(fish_id: String, weight: float = -1.0, perfect: bool = false, batch_index: int = 0) -> int:
	## batch_index: how many of this species already sold in the same cargo dump
	var unit := float(get_price(fish_id))
	var dump := minf(float(batch_index) * BATCH_DUMP_STEP, BATCH_DUMP_CAP)
	unit *= (1.0 - dump)
	var std := FishDB.get_standard_weight(fish_id)
	var w := weight
	if w <= 0.0:
		w = std
	var factor := 1.0
	if std > 0.0:
		factor = clampf(w / std, 0.55, 1.65)
	var price := maxi(1, int(round(unit * factor)))
	if perfect:
		price = maxi(1, int(round(float(price) * 1.1)))
	return price


func buy_from_player(cargo: Array) -> int:
	## Settle sale at current quotes (with in-batch dump), then shock the board
	var counts: Dictionary = {}
	var total := 0
	for item in cargo:
		var id := str(item.id)
		var n: int = int(counts.get(id, 0))
		total += get_sell_price(
			id,
			float(item.get("weight", -1.0)),
			bool(item.get("perfect", false)),
			n
		)
		counts[id] = n + 1
	if not counts.is_empty():
		_apply_supply_shock(counts)
	return total


func _apply_supply_shock(counts: Dictionary) -> void:
	up_count = 0
	down_count = 0
	for id in counts.keys():
		var n: int = int(counts[id])
		if n <= 0:
			continue
		var fish: Dictionary = FishDB.get_fish(str(id))
		var base: int = int(fish.get("base_price", 1))
		var shock: float = minf(float(n) * SHOCK_PER_FISH, SHOCK_CAP)
		var pressure: float = minf(float(supply_pressure.get(id, 0.0)) + shock, SHOCK_CAP)
		supply_pressure[id] = pressure
		var oldp: int = get_price(str(id))
		var newp: int = maxi(_floor_price(base), int(round(float(oldp) * (1.0 - shock))))
		prices[id] = newp
		var delta_pct := 0.0
		if oldp > 0:
			delta_pct = float(newp - oldp) / float(oldp)
		changes[id] = delta_pct
	## Recount board sentiment from current changes
	up_count = 0
	down_count = 0
	for item in FishDB.get_all():
		var d: float = float(changes.get(item.id, 0.0))
		if d >= 0.0:
			up_count += 1
		else:
			down_count += 1
	_update_sentiment()
	prices_changed.emit()
	_save_state()


func _save_state() -> void:
	var data := {
		"prices": prices,
		"changes": changes,
		"supply_pressure": supply_pressure,
		"sentiment": sentiment,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var p = parsed.get("prices", {})
	var c = parsed.get("changes", {})
	var s = parsed.get("supply_pressure", {})
	if typeof(p) == TYPE_DICTIONARY:
		prices = {}
		for k in p.keys():
			prices[str(k)] = int(p[k])
	if typeof(c) == TYPE_DICTIONARY:
		changes = {}
		for k in c.keys():
			changes[str(k)] = float(c[k])
	if typeof(s) == TYPE_DICTIONARY:
		supply_pressure = {}
		for k in s.keys():
			supply_pressure[str(k)] = float(s[k])
	sentiment = str(parsed.get("sentiment", sentiment))
