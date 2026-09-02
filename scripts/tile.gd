class_name Tile
extends RefCounted
## One map cell.

var x: int
var y: int
var terrain: int = Defs.Terrain.FIELD
var resource: int = Defs.Res.NONE
var improvement: int = Defs.Improvement.NONE
var city: City = null        # city centred on this tile (owner_id == -1 for a neutral village)
var owner_city: City = null  # city whose territory this tile belongs to
var unit: Unit = null
var explored: Array[bool] = []


func _init(px: int, py: int) -> void:
	x = px
	y = py


func pos() -> Vector2i:
	return Vector2i(x, y)


func owner_id() -> int:
	return owner_city.owner_id if owner_city != null else -1


func is_water() -> bool:
	return terrain == Defs.Terrain.SHALLOW or terrain == Defs.Terrain.DEEP


func is_land() -> bool:
	return not is_water()


func describe() -> String:
	var s: String = Defs.TERRAIN_NAMES[terrain]
	if resource != Defs.Res.NONE:
		s += " (" + Defs.RES_NAMES[resource] + ")"
	if improvement != Defs.Improvement.NONE:
		s += " - " + Defs.IMPROVEMENT_NAMES[improvement]
	return s
