class_name City
extends RefCounted
## A city or neutral village. Villages have owner_id == -1.

var x: int
var y: int
var city_name: String = "City"
var owner_id: int = -1
var level: int = 1
var pop: int = 0
var is_capital: bool = false
var has_walls: bool = false
var has_workshop: bool = false
var parks: int = 0
var border_radius: int = 1


func pos() -> Vector2i:
	return Vector2i(x, y)


func is_village() -> bool:
	return owner_id < 0


func pop_needed() -> int:
	return level + 1


func income() -> int:
	var s := level
	if has_workshop:
		s += 1
	if is_capital:
		s += 1
	return s


func unit_cap() -> int:
	return level + 1
