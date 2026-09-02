class_name Unit
extends RefCounted
## A single unit on the map.

var id: int = 0
var type: String = "warrior"
var owner_id: int = 0
var x: int = 0
var y: int = 0
var hp: int = 10
var max_hp: int = 10
var kills: int = 0
var veteran: bool = false
var moved: bool = false
var attacked: bool = false
var home_city: City = null
var embarked: bool = false
var vessel: String = "boat"


func pos() -> Vector2i:
	return Vector2i(x, y)


func stats() -> Dictionary:
	return Defs.UNITS[vessel] if embarked else Defs.UNITS[type]


func display_name() -> String:
	var n: String = Defs.UNITS[type]["name"]
	if embarked:
		n += " (" + str(Defs.UNITS[vessel]["name"]) + ")"
	if veteran:
		n = "Veteran " + n
	return n


func atk() -> float:
	return float(stats()["atk"])


func defense() -> float:
	return float(stats()["defense"]) if stats().has("defense") else float(stats()["def"])


func move_points() -> int:
	return int(stats()["move"])


func attack_range() -> int:
	return int(stats()["range"])


func letter() -> String:
	return str(stats()["letter"])


func is_done() -> bool:
	return attacked
