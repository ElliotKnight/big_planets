class_name Player
extends RefCounted
## A tribe, human or AI.

var id: int = 0
var tribe_name: String = "Tribe"
var color: Color = Color.WHITE
var is_ai: bool = false
var stars: int = Defs.STARTING_STARS
var techs: Array[String] = []
var alive: bool = true


func has_tech(t: String) -> bool:
	return t == "" or techs.has(t)
