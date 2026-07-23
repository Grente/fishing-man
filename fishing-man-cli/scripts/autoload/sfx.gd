extends Node

## Global SFX / ambient. Kenney UI (CC0) + Freesound water/boat/fishing clips.

signal muted_changed(muted: bool)

const PATHS := {
	"ui_click": "res://assets/audio/sfx/ui_click.ogg",
	"ui_open": "res://assets/audio/sfx/ui_open.ogg",
	"ui_close": "res://assets/audio/sfx/ui_close.ogg",
	"select": "res://assets/audio/sfx/select.ogg",
	"success": "res://assets/audio/sfx/success.ogg",
	"fail": "res://assets/audio/sfx/fail.ogg",
	"coin": "res://assets/audio/sfx/coin.ogg",
	"upgrade": "res://assets/audio/sfx/upgrade.ogg",
	"fanfare": "res://assets/audio/sfx/fanfare.ogg",
	"drop": "res://assets/audio/sfx/drop.ogg",
	"tick": "res://assets/audio/sfx/tick.ogg",
	"pluck": "res://assets/audio/sfx/pluck.ogg",
	"cast": "res://assets/audio/sfx/cast.ogg",
	"splash": "res://assets/audio/sfx/splash.ogg",
	"reel": "res://assets/audio/sfx/reel.ogg",
	"bite": "res://assets/audio/sfx/bite.ogg",
	"ambient_sea": "res://assets/audio/sfx/ambient_sea.ogg",
	"boat_hum": "res://assets/audio/sfx/boat_hum.ogg",
	"storm_rain": "res://assets/audio/sfx/storm_rain.wav",
	"storm_thunder": "res://assets/audio/sfx/storm_thunder.wav",
}

const POOL_SIZE := 8

var muted: bool = false
var _streams: Dictionary = {}
var _pool: Array = []
var _pool_i: int = 0
var _ambient: AudioStreamPlayer
var _boat: AudioStreamPlayer
var _storm: AudioStreamPlayer
var _boat_wanted: bool = false
var _storm_wanted: bool = false
var _storm_large: bool = false


func _ready() -> void:
	_load_streams()
	_build_pool()
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "AmbientSea"
	_ambient.volume_db = -16.0
	add_child(_ambient)
	_boat = AudioStreamPlayer.new()
	_boat.name = "BoatHum"
	_boat.volume_db = -18.0
	add_child(_boat)
	_storm = AudioStreamPlayer.new()
	_storm.name = "StormAmbience"
	_storm.volume_db = -14.0
	add_child(_storm)
	if _streams.has("ambient_sea"):
		_ambient.stream = _streams["ambient_sea"]
		if not _ambient.finished.is_connected(_on_ambient_finished):
			_ambient.finished.connect(_on_ambient_finished)
		if not muted:
			_ambient.play()
	if _streams.has("boat_hum"):
		_boat.stream = _streams["boat_hum"]
		if not _boat.finished.is_connected(_on_boat_finished):
			_boat.finished.connect(_on_boat_finished)
	if not _storm.finished.is_connected(_on_storm_finished):
		_storm.finished.connect(_on_storm_finished)


func _on_ambient_finished() -> void:
	if not muted and _ambient.stream:
		_ambient.play()


func _on_boat_finished() -> void:
	if not muted and _boat_wanted and _boat.stream:
		_boat.play()


func _on_storm_finished() -> void:
	if not muted and _storm_wanted and _storm.stream:
		_storm.play()


func _load_streams() -> void:
	for id in PATHS.keys():
		var path: String = PATHS[id]
		if ResourceLoader.exists(path):
			var s: Resource = load(path)
			if s is AudioStream:
				if id in ["ambient_sea", "boat_hum"] and s is AudioStreamOggVorbis:
					(s as AudioStreamOggVorbis).loop = true
				if id in ["storm_rain", "storm_thunder"] and s is AudioStreamWAV:
					(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
				_streams[id] = s


func _build_pool() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPool_%d" % i
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func set_muted(v: bool) -> void:
	muted = v
	muted_changed.emit(muted)
	if muted:
		_ambient.stop()
		_boat.stop()
		if _storm:
			_storm.stop()
	else:
		if _ambient.stream and not _ambient.playing:
			_ambient.play()
		_refresh_boat()
		_refresh_storm()


func play(id: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if muted:
		return
	if not _streams.has(id):
		return
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stop()
	p.stream = _streams[id]
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.volume_db = volume_db
	p.play()


func ui_click() -> void:
	play("ui_click", randf_range(0.96, 1.04), -4.0)


func ui_open() -> void:
	play("ui_open", 1.0, -6.0)


func ui_close() -> void:
	play("ui_close", 1.0, -6.0)


func cast() -> void:
	play("cast", 1.0, -4.0)
	## Splash after the cast whoosh lands
	get_tree().create_timer(0.55).timeout.connect(func(): play("splash", randf_range(0.94, 1.06), -2.0))


func bite() -> void:
	play("bite", randf_range(0.95, 1.08), -3.0)


func reel() -> void:
	play("reel", 1.0, -6.0)


func drop() -> void:
	play("drop", 1.0, -4.0)


func catch_ok(is_new: bool = false, perfect: bool = false) -> void:
	if is_new:
		play("fanfare", 1.0, -3.0)
	elif perfect:
		play("success", 1.08, -2.0)
	else:
		play("success", 1.0, -3.0)


func catch_fail() -> void:
	play("fail", 1.0, -4.0)


func coin() -> void:
	play("coin", 1.0, -2.0)


func upgrade() -> void:
	play("upgrade", 1.0, -3.0)


func select() -> void:
	play("select", 1.0, -5.0)


func set_boat_moving(moving: bool) -> void:
	_boat_wanted = moving
	_refresh_boat()


func storm_enter(large: bool = false) -> void:
	_storm_wanted = true
	_storm_large = large
	_refresh_storm()


func storm_leave() -> void:
	_storm_wanted = false
	_refresh_storm()


func _refresh_storm() -> void:
	if muted or _storm == null:
		if _storm:
			_storm.stop()
		return
	if not _storm_wanted:
		_storm.stop()
		return
	var id := "storm_thunder" if _storm_large else "storm_rain"
	if not _streams.has(id):
		id = "storm_rain" if _streams.has("storm_rain") else ""
	if id.is_empty():
		return
	_storm.stream = _streams[id]
	_storm.volume_db = -10.0 if _storm_large else -14.0
	if not _storm.playing:
		_storm.play()


func _refresh_boat() -> void:
	if muted or _boat.stream == null:
		_boat.stop()
		return
	if _boat_wanted:
		if not _boat.playing:
			_boat.play()
	else:
		_boat.stop()
