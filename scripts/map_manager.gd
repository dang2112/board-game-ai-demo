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

func get_tile(pos: Vector2i) -> Tile:
	return tiles.get(pos, null)

func get_random_spawn(team: int) -> Vector2i:
	var teamspawns = [] #Vector2i
	for pos in tiles:
		if tiles[pos].terrain_type < 0 && (0 - (tiles[pos].terrain_type)) % (team + 1) == 0:
			#terrain_type is an int, if it is negative AND when flipped it divides with the team
			#(e.g -1 for team 0, -2 for team 1)
			#then it is a spawn of the team
			teamspawns.append(pos)
	return teamspawns.pick_random()
