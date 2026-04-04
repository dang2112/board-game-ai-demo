extends GameMap
#this is loaded as map_data in map manager
func _init() -> void:
	my_map = {
		"size": Vector2i(8, 8),
		"tiles": [
			[0,0,0,0,-2,-2,-2,0],
			[0,0,0,1,1,0,0,0],
			[0,0,0,1,1,4,0,0],
			[0,0,0,1,1,0,0,0],
			[0,4,0,0,3,0,2,2],
			[0,0,0,0,3,3,2,2],
			[0,0,0,0,0,0,0,0],
			[0,0,-1,-1,-1,0,0,0]
		] 
	}
