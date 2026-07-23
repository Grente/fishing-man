extends Node

## Shared world layout constants

const SIZE := Vector2(2880, 2560)
const WIDTH := 2880.0
const HEIGHT := 2560.0

## Shore band restored to original ~510px land height
const LAND_HEIGHT := 510.0
const SHORE_Y := 2050.0
const FOAM_Y := 2038.0

const MARGIN := 40.0
const CENTER_X := 1440.0
## Pier / dock shifted a bit left of map center
const DOCK_X := 1100.0
## Pier sprite target height used when placing berth relative to tip
const PIER_TOP_Y := SHORE_Y - 220.0
## Boat parks just north of pier tip, slightly right of center (outside planks)
const DOCK_BERTH := Vector2(1145, 1760)
const DEFAULT_SEA_DEST := Vector2(1145, 1700)


func map_x(old_x: float) -> float:
	return old_x * (WIDTH / 1440.0)


func clamp_water(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, MARGIN, WIDTH - MARGIN),
		clampf(pos.y, MARGIN, SHORE_Y - 10.0)
	)


func clamp_boat(pos: Vector2) -> Vector2:
	## Boat stays on water only, never onto the shore band
	return clamp_water(pos)


func is_open_water(pos: Vector2) -> bool:
	if pos.y >= SHORE_Y:
		return false
	if pos.x < MARGIN or pos.x > WIDTH - MARGIN:
		return false
	if pos.y < MARGIN:
		return false
	return true
