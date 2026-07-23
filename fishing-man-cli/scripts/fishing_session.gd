extends Node

## Fishing session: CASTING -> TIMING (hook window) -> REELING (tension tug)

signal state_changed(state: String)
signal bite_progress(remain: float)
signal timing_tick(t: float)
signal tension_tick(tension: float, progress: float, safe_lo: float, safe_hi: float)
signal catch_result(fish_id: String, perfect: bool, is_new: bool, weight: float)
signal failed(reason: String)

enum State { IDLE, CASTING, TIMING, REELING }

## Tension tuning - hold raises, release always lowers (even during fish spikes)
const HOLD_TENSION_RATE := 0.38
const RELEASE_DECAY := 1.05
const PROGRESS_HOLD := 0.34
const PROGRESS_SAFE_IDLE := 0.07
const OVERLOAD_BUFFER := 0.22
const SLACK_TIME := 0.95
const PERFECT_PROGRESS_BONUS := 0.10

var state: State = State.IDLE
var current_zone: String = "near"
var wait_remain: float = 0.0
var timing_pos: float = 0.0
var timing_speed: float = 0.55
var green_start: float = 0.45
var green_end: float = 0.72
var perfect_start: float = 0.54
var perfect_end: float = 0.64
var _pending_fish: String = ""
var _pending_weight: float = 0.0
var _pending_perfect: bool = false

## Reeling
var tension: float = 0.45
var reel_progress: float = 0.0
var safe_lo: float = 0.24
var safe_hi: float = 0.76
var _holding: bool = false
var _overload_timer: float = 0.0
var _slack_timer: float = 0.0
var _pull_curve: String = "steady"
var _pull_mul: float = 1.0
var _curve_t: float = 0.0
var _burst_active: bool = false
var _burst_timer: float = 0.0


func is_busy() -> bool:
	return state != State.IDLE


func is_reeling() -> bool:
	return state == State.REELING


func get_pull_curve() -> String:
	return _pull_curve


func start_cast(zone: String) -> bool:
	if state != State.IDLE:
		return false
	if GameState.is_cargo_full():
		failed.emit("\u8d27\u8231\u5df2\u6ee1")
		return false
	current_zone = zone
	_pending_fish = FishDB.roll_fish(
		zone,
		GameState.rod_level,
		Tide.get_rare_mul() * _storm_rare_mul(),
		GameState.equipped_bait
	)
	_pending_weight = FishDB.roll_weight(_pending_fish, GameState.equipped_bait)
	GameState.consume_bait()
	_setup_windows()
	wait_remain = randf_range(1.0, 3.0)
	state = State.CASTING
	state_changed.emit("casting")
	return true


func _storm_rare_mul() -> float:
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat and boat.get("current_storm") != null:
		var storm: Node = boat.current_storm
		if storm and storm.has_method("get_rare_mul"):
			return float(storm.get_rare_mul())
	return 1.0


func _setup_windows() -> void:
	var widen := 0.02 * float(GameState.rod_level - 1)
	green_start = 0.45 - widen
	green_end = 0.72 + widen
	perfect_start = 0.54
	perfect_end = 0.64
	timing_speed = 0.50 + 0.03 * float(GameState.rod_level)


func _process(delta: float) -> void:
	match state:
		State.CASTING:
			wait_remain -= delta
			bite_progress.emit(wait_remain)
			if wait_remain <= 0.0:
				timing_pos = 0.0
				state = State.TIMING
				state_changed.emit("timing")
		State.TIMING:
			timing_pos += timing_speed * delta
			timing_tick.emit(timing_pos)
			if timing_pos >= 1.0:
				_fail("\u9c7c\u8dd1\u4e86\u2026\u518d\u8bd5\u4e00\u6b21")
		State.REELING:
			_process_reeling(delta)


func try_reel() -> void:
	if state == State.CASTING:
		return
	if state != State.TIMING:
		return
	var perfect := timing_pos >= perfect_start and timing_pos <= perfect_end
	var ok := timing_pos >= green_start and timing_pos <= green_end
	if ok:
		## Press that hooked the fish starts as hold into the tug phase
		_begin_reeling(perfect, true)
	else:
		_fail("\u6536\u7ebf\u504f\u4e86\uff0c\u9c7c\u8dd1\u4e86")


func set_reel_holding(holding: bool) -> void:
	if state != State.REELING:
		_holding = false
		return
	_holding = holding


func cancel() -> void:
	_holding = false
	state = State.IDLE
	state_changed.emit("idle")


func _begin_reeling(perfect: bool, start_holding: bool = false) -> void:
	_pending_perfect = perfect
	_holding = start_holding
	_curve_t = 0.0
	_burst_active = false
	_burst_timer = 0.0
	_overload_timer = 0.0
	_slack_timer = 0.0
	_pull_curve = FishDB.get_pull_curve(_pending_fish)
	_pull_mul = _calc_pull_mul()
	var widen := 0.025 * float(GameState.rod_level - 1)
	safe_lo = clampf(0.26 - widen * 0.4, 0.12, 0.35)
	safe_hi = clampf(0.74 + widen, 0.65, 0.90)
	tension = 0.40 + randf_range(-0.04, 0.04)
	reel_progress = PERFECT_PROGRESS_BONUS if perfect else 0.0
	state = State.REELING
	state_changed.emit("reeling")
	tension_tick.emit(tension, reel_progress, safe_lo, safe_hi)


func _calc_pull_mul() -> float:
	var mul := 1.0
	var fish: Dictionary = FishDB.get_fish(_pending_fish)
	match str(fish.get("rarity", "common")):
		"rare":
			mul = 1.18
		"legend":
			mul = 1.38
		_:
			mul = 1.0
	if FishDB.has_tag(_pending_fish, "large"):
		mul *= 1.12
	if FishDB.has_tag(_pending_fish, "small"):
		mul *= 0.88
	## Heavier fish pull harder
	var std := FishDB.get_standard_weight(_pending_fish)
	if std > 0.01:
		mul *= clampf(_pending_weight / std, 0.85, 1.25)
	return mul


func _process_reeling(delta: float) -> void:
	_curve_t += delta
	## Fish pull is always >= 0 (never yanks tension backward / "left")
	var fish_pull: float = maxf(0.0, _sample_fish_pull(delta) * _pull_mul)
	var player: float = HOLD_TENSION_RATE if _holding else -RELEASE_DECAY
	tension = clampf(tension + (fish_pull + player) * delta, 0.0, 1.0)

	var in_safe := tension >= safe_lo and tension <= safe_hi
	if in_safe:
		_overload_timer = 0.0
		_slack_timer = 0.0
		if _holding:
			reel_progress += PROGRESS_HOLD * delta
		else:
			reel_progress += PROGRESS_SAFE_IDLE * delta
	elif tension > safe_hi:
		_overload_timer += delta
		_slack_timer = 0.0
		if _overload_timer >= OVERLOAD_BUFFER:
			_fail("\u65ad\u7ebf\u4e86\uff01\u5f20\u529b\u8fc7\u8f7d")
			return
	else:
		_slack_timer += delta
		_overload_timer = 0.0
		if _slack_timer >= SLACK_TIME:
			_fail("\u8131\u94a9\u4e86\u2026\u653e\u7ebf\u592a\u4e45")
			return

	if reel_progress >= 1.0:
		reel_progress = 1.0
		tension_tick.emit(tension, reel_progress, safe_lo, safe_hi)
		_success(_pending_perfect)
		return

	tension_tick.emit(tension, reel_progress, safe_lo, safe_hi)


func _sample_fish_pull(delta: float) -> float:
	match _pull_curve:
		"burst":
			if _burst_active:
				_burst_timer -= delta
				if _burst_timer <= 0.0:
					_burst_active = false
				## Spike  -  release to bleed tension
				return 0.78 + randf_range(0.0, 0.16)
			if randf() < 0.48 * delta:
				_burst_active = true
				_burst_timer = randf_range(0.35, 0.7)
			## Quiet but still positive pull
			return 0.12 + 0.06 * (0.5 + 0.5 * sin(_curve_t * 2.0))
		"slippery":
			## Rhythm varies strength only (0.12..0.72), never reverses
			var wave: float = 0.5 + 0.5 * sin(_curve_t * 2.6)
			var wave2: float = 0.5 + 0.5 * sin(_curve_t * 1.1)
			return 0.12 + 0.60 * wave * (0.55 + 0.45 * wave2)
		_:
			## Steady positive pressure with light sway
			return 0.22 + 0.06 * (0.5 + 0.5 * sin(_curve_t * 1.5))


func _success(perfect: bool) -> void:
	var fish_id := _pending_fish
	var weight := _pending_weight
	var is_new := not GameState.is_discovered(fish_id)
	_holding = false
	if not GameState.add_to_cargo(fish_id, perfect, weight):
		_fail("\u8d27\u8231\u5df2\u6ee1")
		return
	state = State.IDLE
	state_changed.emit("idle")
	catch_result.emit(fish_id, perfect, is_new, weight)


func _fail(reason: String) -> void:
	_holding = false
	state = State.IDLE
	state_changed.emit("idle")
	failed.emit(reason)
