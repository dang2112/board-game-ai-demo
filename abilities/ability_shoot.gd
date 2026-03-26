extends Ability

var range := 5
var damage := 3

func execute(user: Unit, target: Unit) -> bool:
	if user.position_on_grid.distance_to(target.position_on_grid) > range:
		return false
	
	target.health -= damage
	
	if target.health <= 0:
		target.queue_free() #death
	
	return true
