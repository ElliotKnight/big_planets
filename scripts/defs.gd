class_name Defs
extends RefCounted
## Static game data: terrain, resources, units, techs, level rewards.

enum Terrain { FIELD, FOREST, MOUNTAIN, SHALLOW, DEEP }
enum Res { NONE, FRUIT, ANIMAL, FISH, METAL, CROP }
enum Improvement { NONE, FARM, MINE, LUMBER_HUT }
enum Mode { DOMINATION, PERFECTION }

const PERFECTION_TURNS: int = 30
const STARTING_STARS: int = 3
const VETERAN_KILLS: int = 3
const VETERAN_HP_BONUS: int = 5
const HEAL_HOME: int = 4
const HEAL_AWAY: int = 2

const TERRAIN_NAMES: Dictionary = {
	Terrain.FIELD: "Field",
	Terrain.FOREST: "Forest",
	Terrain.MOUNTAIN: "Mountain",
	Terrain.SHALLOW: "Shallow water",
	Terrain.DEEP: "Deep water",
}

const TERRAIN_COLORS: Dictionary = {
	Terrain.FIELD: Color(0.58, 0.76, 0.40),
	Terrain.FOREST: Color(0.33, 0.55, 0.30),
	Terrain.MOUNTAIN: Color(0.58, 0.56, 0.52),
	Terrain.SHALLOW: Color(0.38, 0.65, 0.88),
	Terrain.DEEP: Color(0.16, 0.34, 0.62),
}

const RES_NAMES: Dictionary = {
	Res.NONE: "",
	Res.FRUIT: "Fruit",
	Res.ANIMAL: "Animals",
	Res.FISH: "Fish",
	Res.METAL: "Metal",
	Res.CROP: "Crops",
}

const IMPROVEMENT_NAMES: Dictionary = {
	Improvement.NONE: "",
	Improvement.FARM: "Farm",
	Improvement.MINE: "Mine",
	Improvement.LUMBER_HUT: "Lumber hut",
}

const PLAYER_COLORS: Array = [
	Color(0.25, 0.55, 1.00),
	Color(0.92, 0.32, 0.30),
	Color(0.35, 0.80, 0.40),
	Color(0.95, 0.72, 0.20),
]
const TRIBE_NAMES: Array = ["Aurora", "Ember", "Verdant", "Dune"]

## Unit stats. "boat" and "ship" are the forms land units take while embarked.
const UNITS: Dictionary = {
	"warrior": {"name": "Warrior", "cost": 2, "atk": 2.0, "def": 2.0, "hp": 10, "move": 1, "range": 1, "tech": "", "letter": "W", "desc": "Cheap melee infantry."},
	"archer": {"name": "Archer", "cost": 3, "atk": 2.0, "def": 1.0, "hp": 10, "move": 1, "range": 2, "tech": "archery", "letter": "A", "desc": "Ranged. Strikes from 2 tiles away without retaliation."},
	"rider": {"name": "Rider", "cost": 3, "atk": 2.0, "def": 1.0, "hp": 10, "move": 2, "range": 1, "tech": "riding", "letter": "R", "desc": "Fast cavalry, good for scouting and capturing."},
	"defender": {"name": "Defender", "cost": 3, "atk": 1.0, "def": 3.0, "hp": 15, "move": 1, "range": 1, "tech": "shields", "letter": "D", "desc": "Tough garrison unit."},
	"swordsman": {"name": "Swordsman", "cost": 5, "atk": 3.0, "def": 3.0, "hp": 15, "move": 1, "range": 1, "tech": "smithery", "letter": "S", "desc": "Strong all-round melee unit."},
	"knight": {"name": "Knight", "cost": 8, "atk": 3.5, "def": 1.0, "hp": 10, "move": 3, "range": 1, "tech": "chivalry", "letter": "K", "desc": "Very fast heavy cavalry."},
	"catapult": {"name": "Catapult", "cost": 8, "atk": 4.0, "def": 0.0, "hp": 10, "move": 1, "range": 3, "tech": "construction", "letter": "C", "desc": "Siege engine. Devastating at range, helpless up close."},
	"giant": {"name": "Giant", "cost": 0, "atk": 5.0, "def": 4.0, "hp": 40, "move": 1, "range": 1, "tech": "__reward__", "letter": "G", "desc": "Super unit granted by a city level-up."},
	"boat": {"name": "Boat", "cost": 0, "atk": 1.0, "def": 1.0, "hp": 0, "move": 2, "range": 2, "tech": "sailing", "letter": "B", "desc": "Embarked unit on shallow water."},
	"ship": {"name": "Ship", "cost": 0, "atk": 2.0, "def": 2.0, "hp": 0, "move": 3, "range": 2, "tech": "navigation", "letter": "H", "desc": "Embarked unit able to cross deep water."},
}

const TRAINABLE: Array = ["warrior", "archer", "rider", "defender", "swordsman", "knight", "catapult"]

## Tech tree: five branches, three tiers each. Cost = 4 + tier * number of cities.
const TECHS: Dictionary = {
	"organization": {"name": "Organization", "tier": 1, "requires": "", "desc": "Harvest fruit on fields (+1 pop)."},
	"farming": {"name": "Farming", "tier": 2, "requires": "organization", "desc": "Build farms on crops (+2 pop)."},
	"construction": {"name": "Construction", "tier": 3, "requires": "farming", "desc": "Unlocks the Catapult siege unit."},
	"hunting": {"name": "Hunting", "tier": 1, "requires": "", "desc": "Hunt animals in forests (+1 pop)."},
	"archery": {"name": "Archery", "tier": 2, "requires": "hunting", "desc": "Unlocks Archers. Units defend better in forests."},
	"forestry": {"name": "Forestry", "tier": 3, "requires": "archery", "desc": "Clear forests for stars, build lumber huts (+1 pop), grow forests."},
	"fishing": {"name": "Fishing", "tier": 1, "requires": "", "desc": "Catch fish in shallow water (+1 pop)."},
	"sailing": {"name": "Sailing", "tier": 2, "requires": "fishing", "desc": "Units can embark onto shallow water as Boats."},
	"navigation": {"name": "Navigation", "tier": 3, "requires": "sailing", "desc": "Cross deep water. Embarked units become Ships."},
	"climbing": {"name": "Climbing", "tier": 1, "requires": "", "desc": "Units can enter mountains and defend better there."},
	"mining": {"name": "Mining", "tier": 2, "requires": "climbing", "desc": "Mine metal in mountains (+2 pop)."},
	"smithery": {"name": "Smithery", "tier": 3, "requires": "mining", "desc": "Unlocks Swordsmen."},
	"riding": {"name": "Riding", "tier": 1, "requires": "", "desc": "Unlocks Riders."},
	"shields": {"name": "Shields", "tier": 2, "requires": "riding", "desc": "Unlocks Defenders."},
	"chivalry": {"name": "Chivalry", "tier": 3, "requires": "shields", "desc": "Unlocks Knights."},
}

const BRANCHES: Array = [
	["organization", "farming", "construction"],
	["hunting", "archery", "forestry"],
	["fishing", "sailing", "navigation"],
	["climbing", "mining", "smithery"],
	["riding", "shields", "chivalry"],
]


static func tech_cost(tech_id: String, num_cities: int) -> int:
	return 4 + int(TECHS[tech_id]["tier"]) * maxi(num_cities, 1)


## Two reward options offered when a city reaches the given level.
static func level_rewards(level: int) -> Array:
	match level:
		2:
			return [
				{"id": "workshop", "name": "Workshop", "desc": "+1 star per turn from this city."},
				{"id": "explorer", "name": "Explorer", "desc": "Reveal a wide area around the city."},
			]
		3:
			return [
				{"id": "walls", "name": "City Wall", "desc": "Units in the city get a 4x defense bonus."},
				{"id": "resources", "name": "Resources", "desc": "+5 stars immediately."},
			]
		4:
			return [
				{"id": "border_growth", "name": "Border Growth", "desc": "Claim tiles two steps from the city."},
				{"id": "pop_growth", "name": "Population Growth", "desc": "+3 population."},
			]
		_:
			return [
				{"id": "park", "name": "Park", "desc": "+250 score."},
				{"id": "giant", "name": "Giant", "desc": "A 40 HP super unit appears in the city."},
			]
