extends Node2D

var grid_size: Vector2i
var tiles = {} #Dictionary<Vector2i, Tile>

#MAP DATA RULE: negative values are spawns
#if there are more players than the map can support then some teams share spawns

func load_map(map_data):
	var newmap = load(map_data)
	var mapmaker = newmap.new()
	grid_size = mapmaker.my_map.size
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var tile = preload("res://scenes/tile.tscn").instantiate()
			tile.grid_pos = Vector2i(x, y)
			tile.terrain_type = mapmaker.my_map.tiles[y][x]
			
			add_child(tile)
			tiles[tile.grid_pos] = tile

func to_dict() -> Dictionary:
	var tile_list := []
	for pos in tiles:
		var tile: Tile = tiles[pos]
		if tile != null:
			tile_list.append(tile.to_dict())
	return {
		"grid_size": [grid_size.x, grid_size.y],
		"tiles": tile_list,
	}

func from_dict(data: Dictionary) -> void:
	# Remove any existing tiles first
	for pos in tiles:
		if tiles[pos] != null:
			tiles[pos].queue_free()
	tiles.clear()

	if data.has("grid_size"):
		var size = data["grid_size"]
		if size is Array and size.size() == 2:
			grid_size = Vector2i(int(size[0]), int(size[1]))

	if data.has("tiles") and data["tiles"] is Array:
		for tile_data in data["tiles"]:
			if tile_data is Dictionary:
				var tile = preload("res://scenes/tile.tscn").instantiate()
				tile.from_dict(tile_data)
				add_child(tile)
				tiles[tile.grid_pos] = tile

func get_tile(pos: Vector2i) -> Tile:
	return tiles.get(pos, null)

func get_all_victory_tiles() -> Array[Vector2i]:
	var vt: Array[Vector2i] = [] #Vector2i
	for pos in tiles:
		if tiles[pos].terrain_type == 4:
			vt.append(pos)
	return vt

func get_random_spawn(team: int, unit_manager) -> Vector2i:
	var teamspawns = [] #Vector2i
	var spawn_id: int
	if team == 2:
		spawn_id = -2 #joiner uses AI's spawn tiles
	else:
		spawn_id = -(team + 1)
	for pos in tiles:
		if tiles[pos].terrain_type == spawn_id and unit_manager.get_unit_at(pos) == null:
			#team 0 uses -1, team 1 uses -2, team 2 uses -2 (AI spawns)
			teamspawns.append(pos)

	if teamspawns.is_empty():
		return Vector2i(-1, -1)

	return teamspawns.pick_random()
