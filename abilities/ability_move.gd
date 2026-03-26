extends Ability

var range := 3

func execute(user: Unit, target_pos: Vector2i) -> bool:
	var distance = user.position_on_grid.distance_to(target_pos)
	
	if distance > range:
		return false
	
	user.position_on_grid = target_pos
	
	return true
