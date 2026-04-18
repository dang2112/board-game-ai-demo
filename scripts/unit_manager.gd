extends Node2D

var units = []

func cleanup_units():
	units = units.filter(func(u): return is_instance_valid(u))

func spawn_unit(unit_data, grid_pos, team):
	var unit_scene: PackedScene = load(unit_data) #unit_data is form "res://rifleman.tscn"
	var unit = unit_scene.instantiate()
	
	unit.scene_path = unit_data
	unit.team = team
	unit.position_on_grid = grid_pos
	unit.z_index = 10
	
	add_child(unit)
	units.append(unit)
	
	return unit

func to_dict() -> Dictionary:
	cleanup_units()
	var unit_list := []
	for unit in units:
		if unit != null:
			unit_list.append(unit.to_dict())
	return {
		"units": unit_list,
	}

func from_dict(data: Dictionary) -> void:
	for unit in units:
		if unit != null:
			unit.queue_free()
	units.clear()

	if data.has("units") and data["units"] is Array:
		for unit_data in data["units"]:
			if unit_data is Dictionary:
				var unit = Unit.new_from_dict(unit_data)
				if unit != null:
					add_child(unit)
					units.append(unit)

func get_units_for_team(team):
	cleanup_units()
	return units.filter(func(u): return u.team == team)

func _just_make_all_units_negative():
	cleanup_units()
	for unit in units:
		if unit.team == 1:
			unit.team = -1

func get_unit_at(grid_pos: Vector2i):
	cleanup_units()
	for unit in units:
		if unit.position_on_grid == grid_pos:
			return unit

	return null
