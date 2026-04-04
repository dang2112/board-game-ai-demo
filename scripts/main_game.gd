extends Control

@onready var UnitManager = $UnitManager
@onready var MapManager = $MapManager


var unit_pool = [
	{"scene": "res://scenes/rifleman.tscn", "cost": 3}, #TODO TODO
	{"scene": "res://scenes/sniper.tscn", "cost": 5}
]

var current_team = 0
var team_no = 2 #in the future maybe more than 2 teams
var selected_unit = null

func generate_army(points: int, team: int):
	var remaining = points
	
	var lowest_cost = INF
	var lowest_unit = {}
	for unit in unit_pool:
		if unit["cost"] < lowest_cost:
			lowest_cost = unit["cost"]
			lowest_unit = unit
	
	while remaining > lowest_cost:
		var choice = unit_pool.pick_random()
		#form of {"scene":, "cost":}
		
		if choice.cost <= remaining:
			var pos = $MapManager.get_random_spawn(team)
			UnitManager.spawn_unit(choice.scene, pos, team)
			remaining -= choice.cost

func _input(event):
	if event is InputEventMouseButton:
		var grid_pos = event.position
		
		if selected_unit == null:
			#selected_unit = get_unit_at(grid_pos) TODO
			return
		else:
			selected_unit.perform_ability(
				selected_unit.abilities[0],
				grid_pos
			)
			selected_unit = null

func start_turn():
	for unit in UnitManager.get_units_for_team(current_team):
		unit.action_points = 1

func end_turn():
	current_team = (current_team + 1) % team_no #next team, wrap if last team
	start_turn()

func _ready() -> void:
	MapManager.load_map("res://resources/example_map.gd")
	generate_army(20, 0)
	generate_army(20, 1)
