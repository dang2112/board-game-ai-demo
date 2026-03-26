extends Node2D

var units = []

func spawn_unit(unit_data, grid_pos, team):
	var unit = preload("res://scenes/unit.tscn").instantiate()
	
	unit.team = team
	unit.position_on_grid = grid_pos
	
	add_child(unit)
	units.append(unit)
	
	return unit

func get_units_for_team(team):
	return units.filter(func(u): return u.team == team)
