extends Node

## 潮汐：影响咬钩速度、稀有权重、市场倾向

signal tide_changed(tide_id: String)

enum TideLevel { LOW, MID, HIGH }

const CYCLE := [
	{"id": "low", "duration": 180.0, "bite_mul": 1.3, "rare_mul": 0.7, "bias": -0.04},
	{"id": "mid", "duration": 240.0, "bite_mul": 1.0, "rare_mul": 1.0, "bias": 0.0},
	{"id": "high", "duration": 180.0, "bite_mul": 0.7, "rare_mul": 1.4, "bias": 0.05},
	{"id": "mid", "duration": 240.0, "bite_mul": 1.0, "rare_mul": 1.0, "bias": 0.0},
]

var _index: int = 1
var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	var cur: Dictionary = CYCLE[_index]
	if _elapsed >= float(cur.duration):
		_elapsed = 0.0
		_index = (_index + 1) % CYCLE.size()
		tide_changed.emit(get_tide_id())


func get_tide_id() -> String:
	return str(CYCLE[_index].id)


func get_tide_display() -> String:
	match get_tide_id():
		"low":
			return "低潮"
		"high":
			return "高潮"
		_:
			return "平潮"


func get_bite_mul() -> float:
	return float(CYCLE[_index].bite_mul)


func get_rare_mul() -> float:
	return float(CYCLE[_index].rare_mul)


func get_market_bias() -> float:
	return float(CYCLE[_index].bias)
