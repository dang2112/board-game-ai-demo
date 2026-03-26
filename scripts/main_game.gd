extends Control

var unit_pool = [
	#add scenes of the units in here and add their costs e.g
	#{"scene": "res://rifleman.tscn", "cost": 3},
	#{"scene": "res://sniper.tscn", "cost": 5}
]

func generate_army(points: int, team: int):
	var remaining = points
	
	while remaining > 0:
		var choice = unit_pool.pick_random()
		
		if choice.cost <= remaining:
			#var pos = get_random_spawn(team)
			#UnitManager.spawn_unit(choice, pos, team)
			remaining -= choice.cost
